import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import { syncDatabase } from './models/index.js';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/user.js';
import adminRoutes from './routes/admin.js';
import supabaseRoutes from './routes/supabase.js';
import { getDeposits, updateDeposit, createAuditLog, getProfile, updateProfile } from './config/data.js';

const app = express();
const PORT = process.env.PORT || 4000;

app.set('trust proxy', 1);

app.use(helmet());

app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

const corsOrigin = process.env.CORS_ORIGIN;
if (corsOrigin) {
  app.use(cors({ origin: corsOrigin.split(',').map((s) => s.trim()), credentials: true }));
} else {
  app.use(cors({ origin: true, credentials: true }));
}

app.use(express.json({ limit: '1mb' }));

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});

const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please try again later' },
});

app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/user', apiLimiter, userRoutes);
app.use('/api/admin', apiLimiter, adminRoutes);
app.use('/api/supabase', apiLimiter, supabaseRoutes);

app.get('/api/health', (_, res) => res.json({ ok: true, uptime: process.uptime() }));

app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ----- Server-side scheduled tasks -----

const EXPIRY_CHECK_INTERVAL = 5 * 60 * 1000; // every 5 minutes

async function autoExpireDeposits() {
  try {
    const pending = await getDeposits({ status: 'pending' }).catch(() => []);
    const now = new Date();
    let expiredCount = 0;
    for (const d of pending) {
      if (d.expires_at && new Date(d.expires_at) < now) {
        await updateDeposit(d.id, { status: 'expired' }).catch(() => {});
        await createAuditLog({
          user_id: d.user_id, action: 'deposit.auto_expire',
          entity_type: 'deposit', entity_id: d.id,
          description: `Deposit $${parseFloat(d.amount) || 0} auto-expired (server cron)`,
          metadata: JSON.stringify({ amount: parseFloat(d.amount) || 0, expiredAt: d.expires_at }),
          ip_address: 'system',
        }).catch(() => {});
        expiredCount++;
      }
    }
    if (expiredCount > 0) {
      console.log(`[CRON] Auto-expired ${expiredCount} deposit(s)`);
    }
  } catch (e) {
    console.error('[CRON] Auto-expiry error:', e.message);
  }
}

async function unlockApprovedDeposits() {
  try {
    const approved = await getDeposits({ status: 'approved' }).catch(() => []);
    const now = new Date();
    let unlockedCount = 0;
    for (const d of approved) {
      if (d.expires_at && new Date(d.expires_at) < now) {
        const amt = parseFloat(d.amount) || 0;
        await updateDeposit(d.id, { status: 'unlocked' }).catch(() => {});
        const profile = await getProfile(d.user_id).catch(() => null);
        if (profile) {
          const locked = parseFloat(profile.locked_balance) || 0;
          const withdrawable = parseFloat(profile.withdrawable_balance) || 0;
          const move = Math.min(amt, locked);
          await updateProfile(d.user_id, {
            locked_balance: locked - move,
            withdrawable_balance: withdrawable + move,
          });
        }
        await createAuditLog({
          user_id: d.user_id, action: 'deposit.unlock',
          entity_type: 'deposit', entity_id: d.id,
          description: `Deposit $${amt} unlocked — moved from locked to withdrawable`,
          metadata: JSON.stringify({ amount: amt, expiredAt: d.expires_at }),
          ip_address: 'system',
        }).catch(() => {});
        unlockedCount++;
      }
    }
    if (unlockedCount > 0) {
      console.log(`[CRON] Unlocked ${unlockedCount} deposit(s) for withdrawal`);
    }
  } catch (e) {
    console.error('[CRON] Unlock error:', e.message);
  }
}

if (process.env.USE_SQLITE === 'true') {
  syncDatabase().then(() => {
    console.log(`[DB] SQLite ready at ../persistent_database/bloomfx_dev.db`);
  });
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`BloomFX API running at http://localhost:${PORT}`);
  if (process.env.USE_SQLITE === 'true') console.log('[DB] Using SQLite (local)');
  else console.log('[DB] Using Supabase (remote)');

  // Start background tasks after server is running
  autoExpireDeposits(); // run immediately on startup
  setInterval(autoExpireDeposits, EXPIRY_CHECK_INTERVAL);
  unlockApprovedDeposits(); // run immediately on startup
  setInterval(unlockApprovedDeposits, EXPIRY_CHECK_INTERVAL);
  console.log(`[CRON] Deposit expiry + unlock checker active every ${EXPIRY_CHECK_INTERVAL / 60000} minutes`);
});
