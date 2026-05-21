const mongoose = require('mongoose');

/**
 * Core reward deposit schema.
 * ─────────────────────────────
 * One document per deposit that tracks the full reward lifecycle.
 */
const depositSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    depositAmount: { type: Number, required: true, min: 7 },
    lockedBalance: { type: Number, required: true, default: 0 },
    accumulatedRewards: { type: Number, default: 0 },
    rank: { type: Number, enum: [1, 2, 3, 4, 5, 6], required: true },
    lastClaimAt: { type: Date, default: null },
    totalClaims: { type: Number, default: 0 },
    status: {
      type: String,
      enum: ['active', 'capped', 'expired', 'cancelled'],
      default: 'active',
    },
    payoutCap: { type: Number, required: true },
    expiresAt: { type: Date, required: true },
    createdAt: { type: Date, default: Date.now },
    updatedAt: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
  }
);

depositSchema.index({ userId: 1, status: 1 });
depositSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

/**
 * Virtual: remaining claims before payout cap is reached.
 */
depositSchema.virtual('remainingReward').get(function () {
  return Math.max(0, this.payoutCap - this.accumulatedRewards);
});

/**
 * Virtual: reward per single claim (depends on rank).
 */
depositSchema.virtual('rewardPerClaim').get(function () {
  // reward_per_claim = (deposit * 0.05) / (30 * rank)
  return (this.depositAmount * 0.05) / (30 * this.rank);
});

/**
 * Virtual: whether payout cap has been reached.
 */
depositSchema.virtual('isCapped').get(function () {
  return this.accumulatedRewards >= this.payoutCap;
});

module.exports = mongoose.model('RewardDeposit', depositSchema);
