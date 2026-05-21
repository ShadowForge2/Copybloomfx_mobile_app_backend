const mongoose = require('mongoose');

/**
 * Tracks individual reward claim events for audit trail.
 */
const claimLogSchema = new mongoose.Schema(
  {
    depositId: { type: mongoose.Schema.Types.ObjectId, ref: 'RewardDeposit', required: true, index: true },
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    rank: { type: Number, required: true },
    claimNumber: { type: Number, required: true },
    amount: { type: Number, required: true },
    runningTotal: { type: Number, required: true },
    ip: { type: String, default: null },
    userAgent: { type: String, default: null },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: false }
);

claimLogSchema.index({ depositId: 1, createdAt: -1 });
claimLogSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('ClaimLog', claimLogSchema);
