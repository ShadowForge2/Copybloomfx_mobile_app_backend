const RewardDeposit = require('../models/RewardDeposit');
const ClaimLog = require('../models/ClaimLog');
const logger = require('../utils/logger');

/* ─── Protocol constants (immutable) ─────────────────────────────────── */
const MAX_PROFIT_PCT = parseFloat(process.env.MAX_PROFIT_PCT) || 0.05; // 5%
const LOCK_DAYS = parseInt(process.env.LOCK_DAYS, 10) || 30;
const COOLDOWN_HOURS = 24;
const RANK_LIMITS = { 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6 };

/* ─── Rank ladder (mirrors InvestmentLogic.defaultRanks) ────────── */
const RANK_LADDER = [
  { id: 1, name: 'Green Horn', minBalance: 7, maxBalance: 49 },
  { id: 2, name: 'Student Form', minBalance: 50, maxBalance: 100 },
  { id: 3, name: 'Market Maven', minBalance: 100, maxBalance: 500 },
  { id: 4, name: 'Gunslinger', minBalance: 500, maxBalance: 1500 },
  { id: 5, name: 'Whale', minBalance: 1500, maxBalance: 5000 },
  { id: 6, name: 'Market Wizard', minBalance: 5000, maxBalance: Infinity },
];

/**
 * Derive rank from deposit amount using the rank ladder.
 * @param {number} amount
 * @returns {number} rank id (1-6)
 */
function rankForAmount(amount) {
  for (const r of RANK_LADDER) {
    if (amount >= r.minBalance && amount <= r.maxBalance) {
      return r.id;
    }
  }
  return 6; // fallback: Market Wizard for anything above 5000
}

/* ─── 1. createDeposit() ──────────────────────────────────────────────── */

/**
 * Create a reward deposit record. Rank is auto-derived from amount.
 * @param {string}  userId
 * @param {number}  amount     – deposit amount (>= 7)
 * @returns {Promise<Object>}  saved RewardDeposit document
 */
async function createDeposit(userId, amount) {
  if (amount < 7) throw new Error('Minimum deposit is $7');
  const rank = rankForAmount(amount);

  const payoutCap = amount * MAX_PROFIT_PCT; // 5%
  const expiresAt = new Date(Date.now() + LOCK_DAYS * 24 * 60 * 60 * 1000);

  const deposit = await RewardDeposit.create({
    userId,
    depositAmount: amount,
    lockedBalance: amount,
    rank,
    payoutCap,
    expiresAt,
    status: 'active',
  });

  logger.info(`Deposit created: userId=${userId} amount=${amount} rank=${rank} cap=${payoutCap}`);
  return deposit;
}

/* ─── 2. calculateReward() ────────────────────────────────────────────── */

/**
 * Calculate reward per single claim (pure function, no side effects).
 * @param {Object} deposit – RewardDeposit document (or plain object)
 * @returns {number}       reward amount for one claim
 */
function calculateReward(deposit) {
  // reward_per_claim = (deposit * 0.05) / (30 * rank)
  const raw = (deposit.depositAmount * MAX_PROFIT_PCT) / (LOCK_DAYS * deposit.rank);
  return Math.round(raw * 100) / 100; // round to cents
}

/* ─── 3. claimReward() ────────────────────────────────────────────────── */

/**
 * Claim a single reward.  Validates cooldown + payout cap + expiry.
 * @param {string} depositId
 * @param {Object} [meta]     – { ip, userAgent } for audit trail
 * @returns {Promise<{ claimed: number, runningTotal: number, isCapped: boolean }>}
 */
async function claimReward(depositId, meta = {}) {
  const deposit = await RewardDeposit.findById(depositId);
  if (!deposit) throw new Error('Deposit not found');

  // ── state guards ──────────────────────────────────────────────────
  if (deposit.status !== 'active') throw new Error('Deposit is not active');
  if (deposit.expiresAt < new Date()) {
    deposit.status = 'expired';
    await deposit.save();
    throw new Error('Deposit has expired');
  }
  if (deposit.accumulatedRewards >= deposit.payoutCap) {
    deposit.status = 'capped';
    await deposit.save();
    throw new Error('Payout cap reached — rewards blocked');
  }

  // ── cooldown guard ────────────────────────────────────────────────
  const rank = deposit.rank;
  const limit = RANK_LIMITS[rank];
  const since = new Date(Date.now() - COOLDOWN_HOURS * 60 * 60 * 1000);

  const claimsInWindow = await ClaimLog.countDocuments({
    depositId: deposit._id,
    createdAt: { $gte: since },
  });
  if (claimsInWindow >= limit) {
    throw new Error(
      `Rank ${rank} allows ${limit} claim(s) per ${COOLDOWN_HOURS}h — ${claimsInWindow} already used`
    );
  }

  // ── calculate & cap-check ─────────────────────────────────────────
  const rawAmount = calculateReward(deposit);
  const remaining = deposit.payoutCap - deposit.accumulatedRewards;
  const amount = Math.min(rawAmount, remaining); // never exceed cap

  if (amount <= 0) {
    deposit.status = 'capped';
    await deposit.save();
    throw new Error('Payout cap reached exactly');
  }

  // ── persist ───────────────────────────────────────────────────────
  deposit.accumulatedRewards += amount;
  deposit.totalClaims += 1;
  deposit.lastClaimAt = new Date();
  deposit.lockedBalance = deposit.depositAmount; // locked unchanged

  if (deposit.accumulatedRewards >= deposit.payoutCap) {
    deposit.status = 'capped';
  }
  await deposit.save();

  await ClaimLog.create({
    depositId: deposit._id,
    userId: deposit.userId,
    rank,
    claimNumber: deposit.totalClaims,
    amount,
    runningTotal: deposit.accumulatedRewards,
    ip: meta.ip || null,
    userAgent: meta.userAgent || null,
  });

  logger.info(
    `Claim: depositId=${depositId} rank=${rank} claim#=${deposit.totalClaims} amount=${amount} total=${deposit.accumulatedRewards}`
  );

  return {
    claimed: amount,
    runningTotal: deposit.accumulatedRewards,
    isCapped: deposit.status === 'capped',
  };
}

/* ─── 4. checkCooldown() ─────────────────────────────────────────────── */

/**
 * Check whether a deposit's cooldown has elapsed for the next claim.
 * @param {Object} deposit
 * @returns {{ canClaim: boolean, nextClaimAt: Date|null, usedInWindow: number, limit: number }}
 */
async function checkCooldown(deposit) {
  const limit = RANK_LIMITS[deposit.rank];
  const since = new Date(Date.now() - COOLDOWN_HOURS * 60 * 60 * 1000);

  const usedInWindow = await ClaimLog.countDocuments({
    depositId: deposit._id,
    createdAt: { $gte: since },
  });

  const canClaim = usedInWindow < limit;

  let nextClaimAt = null;
  if (!canClaim && usedInWindow > 0) {
    const oldest = await ClaimLog.findOne({ depositId: deposit._id, createdAt: { $gte: since } })
      .sort({ createdAt: 1 })
      .lean();
    if (oldest) {
      nextClaimAt = new Date(oldest.createdAt.getTime() + COOLDOWN_HOURS * 60 * 60 * 1000);
    }
  }

  return { canClaim, nextClaimAt, usedInWindow, limit };
}

/* ─── 5. checkPayoutCap() ────────────────────────────────────────────── */

/**
 * Check whether a deposit has reached its payout cap.
 * @param {Object} deposit
 * @returns {{ isCapped: boolean, accumulatedRewards: number, payoutCap: number, remaining: number }}
 */
function checkPayoutCap(deposit) {
  return {
    isCapped: deposit.accumulatedRewards >= deposit.payoutCap,
    accumulatedRewards: deposit.accumulatedRewards,
    payoutCap: deposit.payoutCap,
    remaining: Math.max(0, deposit.payoutCap - deposit.accumulatedRewards),
  };
}

/* ─── 6. daily expiry sweep (called by cron) ─────────────────────────── */

/**
 * Mark all deposits past expiry as 'expired'.
 * Called once per day by cron or on server start.
 */
async function expireDeposits() {
  const result = await RewardDeposit.updateMany(
    { expiresAt: { $lt: new Date() }, status: 'active' },
    { $set: { status: 'expired' } }
  );
  if (result.modifiedCount > 0) {
    logger.info(`Expired ${result.modifiedCount} deposit(s)`);
  }
  return result.modifiedCount;
}

/* ─── 7. admin: force cap (safety valve) ─────────────────────────────── */

async function forceCapDeposit(depositId) {
  const deposit = await RewardDeposit.findById(depositId);
  if (!deposit) throw new Error('Deposit not found');
  deposit.status = 'capped';
  await deposit.save();
  return deposit;
}

module.exports = {
  createDeposit,
  calculateReward,
  claimReward,
  checkCooldown,
  checkPayoutCap,
  expireDeposits,
  forceCapDeposit,
  MAX_PROFIT_PCT,
  LOCK_DAYS,
  COOLDOWN_HOURS,
  RANK_LIMITS,
};
