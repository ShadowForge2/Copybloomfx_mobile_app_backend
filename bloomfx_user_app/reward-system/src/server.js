require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const mongoose = require('mongoose');
const cron = require('node-cron');
const rewardRoutes = require('./routes/rewards');
const { expireDeposits } = require('./services/rewardEngine');
const logger = require('./utils/logger');

const app = express();

/* ─── Middleware ────────────────────────────────────────────────────── */
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10kb' }));

/* ─── Database ──────────────────────────────────────────────────────── */
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/bloomfx_rewards';

mongoose
  .connect(MONGODB_URI)
  .then(() => logger.info('MongoDB connected'))
  .catch((err) => {
    logger.error('MongoDB connection failed', err);
    process.exit(1);
  });

/* ─── Routes ────────────────────────────────────────────────────────── */
app.use('/api/rewards', rewardRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

/* ─── Global error handler ──────────────────────────────────────────── */
app.use((err, req, res, _next) => {
  logger.error('Unhandled error', { error: err.message, stack: err.stack });
  const status = err.status || 500;
  res.status(status).json({
    success: false,
    error: err.message || 'Internal server error',
  });
});

/* ─── Cron: daily expiry sweep (midnight) ───────────────────────────── */
cron.schedule('0 0 * * *', async () => {
  logger.info('Cron: running deposit expiry sweep');
  try {
    await expireDeposits();
  } catch (err) {
    logger.error('Cron: expiry sweep failed', err);
  }
});

/* ─── Start ─────────────────────────────────────────────────────────── */
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  logger.info(`Reward engine running on port ${PORT}`);

  // Run expiry on startup too
  expireDeposits().catch((err) => logger.error('Startup expiry failed', err));
});

module.exports = app;
