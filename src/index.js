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
import { processApprovedDepositsExpiry, LOCK_DAYS } from './services/depositExpiry.js';

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

async function runDepositExpiryJobs() {
  try {
    const approvedCount = await processApprovedDepositsExpiry();
    if (approvedCount > 0) {
      console.log(`[CRON] Expired ${approvedCount} approved deposit(s) after ${LOCK_DAYS}-day lock`);
    }
  } catch (e) {
    console.error('[CRON] Deposit expiry error:', e.message);
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

  runDepositExpiryJobs();
  setInterval(runDepositExpiryJobs, EXPIRY_CHECK_INTERVAL);
  console.log(
    `[CRON] Deposit expiry active every ${EXPIRY_CHECK_INTERVAL / 60000} minutes ` +
      `(crypto pending=admin only, approved lock=${LOCK_DAYS} days)`,
  );
});
