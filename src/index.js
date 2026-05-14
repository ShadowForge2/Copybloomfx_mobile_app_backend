import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import rateLimit from 'express-rate-limit';
import authRoutes from './routes/auth.js';
import userRoutes from './routes/user.js';
import adminRoutes from './routes/admin.js';
import supabaseRoutes from './routes/supabase.js';

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

app.listen(PORT, '0.0.0.0', () => {
  console.log(`BloomFX API running at http://localhost:${PORT}`);
});
