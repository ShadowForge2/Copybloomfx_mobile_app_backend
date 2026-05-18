-- Safe additive migration: one redemption per user per promo code.
-- Run in Supabase SQL Editor. Fails if duplicate rows already exist (clean those first).

CREATE UNIQUE INDEX IF NOT EXISTS idx_promo_redemptions_user_promo
  ON promo_redemptions(user_id, promo_code_id);
