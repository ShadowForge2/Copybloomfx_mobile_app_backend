-- Prevent duplicate referral commission for the same referee deposit.
-- Safe to run multiple times (IF NOT EXISTS).
CREATE UNIQUE INDEX IF NOT EXISTS referrals_deposit_id_unique
  ON referrals (deposit_id)
  WHERE deposit_id IS NOT NULL;
