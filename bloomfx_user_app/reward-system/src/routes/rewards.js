const express = require('express');
const rateLimit = require('express-rate-limit');
const rewardEngine = require('../services/rewardEngine');
const authMiddleware = require('../middleware/auth');
const asyncWrap = require('../utils/asyncWrap');
const logger = require('../utils/logger');

const router = express.Router();

/* ─── Rate limiting: 10 claims / minute per IP ────────────────────── */
const claimLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { error: 'Too many requests — slow down' },
  standardHeaders: true,
  legacyHeaders: false,
});

/* ─── POST /api/rewards/deposit ───────────────────────────────────── */
router.post(
  '/deposit',
  authMiddleware,
  asyncWrap(async (req, res) => {
    const { amount } = req.body;
    const deposit = await rewardEngine.createDeposit(req.user.id, amount);
    res.status(201).json({
      success: true,
      data: {
        id: deposit._id,
        depositAmount: deposit.depositAmount,
        lockedBalance: deposit.lockedBalance,
        rank: deposit.rank,
        payoutCap: deposit.payoutCap,
        rewardPerClaim: deposit.rewardPerClaim,
        expiresAt: deposit.expiresAt,
        status: deposit.status,
      },
    });
  })
);

/* ─── POST /api/rewards/claim ─────────────────────────────────────── */
router.post(
  '/claim',
  authMiddleware,
  claimLimiter,
  asyncWrap(async (req, res) => {
    const { depositId } = req.body;
    if (!depositId) {
      return res.status(400).json({ success: false, error: 'depositId required' });
    }
    const result = await rewardEngine.claimReward(depositId, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });
    res.json({ success: true, data: result });
  })
);

/* ─── GET /api/rewards/status/:depositId ──────────────────────────── */
router.get(
  '/status/:depositId',
  authMiddleware,
  asyncWrap(async (req, res) => {
    const deposit = await require('../models/RewardDeposit').findById(req.params.depositId);
    if (!deposit) {
      return res.status(404).json({ success: false, error: 'Deposit not found' });
    }
    const cooldown = await rewardEngine.checkCooldown(deposit);
    const cap = rewardEngine.checkPayoutCap(deposit);
    res.json({
      success: true,
      data: {
        id: deposit._id,
        depositAmount: deposit.depositAmount,
        lockedBalance: deposit.lockedBalance,
        accumulatedRewards: deposit.accumulatedRewards,
        rank: deposit.rank,
        totalClaims: deposit.totalClaims,
        rewardPerClaim: deposit.rewardPerClaim,
        payoutCap: deposit.payoutCap,
        status: deposit.status,
        expiresAt: deposit.expiresAt,
        cooldown,
        cap,
      },
    });
  })
);

/* ─── GET /api/rewards/history/:depositId ─────────────────────────── */
router.get(
  '/history/:depositId',
  authMiddleware,
  asyncWrap(async (req, res) => {
    const logs = await require('../models/ClaimLog')
      .find({ depositId: req.params.depositId })
      .sort({ createdAt: -1 })
      .limit(200)
      .lean();
    res.json({ success: true, data: logs });
  })
);

/* ─── GET /api/rewards/user ───────────────────────────────────────── */
router.get(
  '/user',
  authMiddleware,
  asyncWrap(async (req, res) => {
    const deposits = await require('../models/RewardDeposit')
      .find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .lean();
    res.json({ success: true, data: deposits });
  })
);

/* ─── Admin: force cap ────────────────────────────────────────────── */
router.post(
  '/admin/force-cap/:depositId',
  authMiddleware,
  asyncWrap(async (req, res) => {
    const deposit = await rewardEngine.forceCapDeposit(req.params.depositId);
    res.json({ success: true, data: deposit });
  })
);

module.exports = router;
