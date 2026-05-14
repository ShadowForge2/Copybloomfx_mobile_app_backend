-- =============================================
-- BloomFX Complete Schema for Supabase
-- Run this in Supabase SQL Editor
-- =============================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. RANKS (standalone, no FK dependencies)
CREATE TABLE IF NOT EXISTS ranks (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  min_balance NUMERIC DEFAULT 0,
  max_balance NUMERIC DEFAULT 999999,
  daily_profit_pct NUMERIC DEFAULT 0,
  copy_trades_limit INTEGER DEFAULT 1,
  color TEXT DEFAULT '#6366f1',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. USERS
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id TEXT UNIQUE,
  username TEXT UNIQUE NOT NULL,
  email TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),
  is_flagged BOOLEAN DEFAULT FALSE,
  is_banned BOOLEAN DEFAULT FALSE,
  last_login_ip TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PROFILES (depends on users, ranks)
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  country TEXT,
  referral_code TEXT UNIQUE,
  total_referrals INTEGER DEFAULT 0,
  valid_referrals INTEGER DEFAULT 0,
  referral_earnings NUMERIC DEFAULT 0,
  avatar_url TEXT,
  profile_picture TEXT,
  locked_balance NUMERIC DEFAULT 0,
  withdrawable_balance NUMERIC DEFAULT 0,
  rank_id INTEGER DEFAULT 1 REFERENCES ranks(id),
  last_daily_reward_at TIMESTAMPTZ,
  last_withdrawal_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. DEPOSITS (depends on users)
CREATE TABLE IF NOT EXISTS deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  network TEXT,
  wallet_address TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reference TEXT,
  referrer_id UUID,
  expires_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. WITHDRAWALS (depends on users)
CREATE TABLE IF NOT EXISTS withdrawals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  network TEXT,
  wallet_address TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);

-- 6. COPY_TRADES (depends on users)
CREATE TABLE IF NOT EXISTS copy_trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pair TEXT,
  action TEXT CHECK (action IN ('buy', 'sell')),
  amount NUMERIC DEFAULT 0,
  profit NUMERIC DEFAULT 0,
  status TEXT DEFAULT 'completed',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. DAILY_REWARDS (depends on users)
CREATE TABLE IF NOT EXISTS daily_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC DEFAULT 0,
  claimed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. REFERRALS (depends on users)
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bonus_amount NUMERIC DEFAULT 0,
  deposit_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. PROMO_CODES (standalone)
CREATE TABLE IF NOT EXISTS promo_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  bonus_min NUMERIC DEFAULT 0,
  bonus_max NUMERIC DEFAULT 0,
  expiration TIMESTAMPTZ,
  usage_limit INTEGER,
  usage_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'disabled', 'expired')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. PROMO_REDEMPTIONS (depends on users, promo_codes)
CREATE TABLE IF NOT EXISTS promo_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  bonus_amount NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. NOTIFICATIONS (depends on users)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  body TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. TRANSACTIONS (depends on users)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  amount NUMERIC NOT NULL,
  status TEXT DEFAULT 'completed',
  description TEXT,
  reference TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX IF NOT EXISTS idx_users_auth_user_id ON users(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_flagged ON users(is_flagged);
CREATE INDEX IF NOT EXISTS idx_users_is_banned ON users(is_banned);

CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code);
CREATE INDEX IF NOT EXISTS idx_profiles_rank_id ON profiles(rank_id);

CREATE INDEX IF NOT EXISTS idx_deposits_user_id ON deposits(user_id);
CREATE INDEX IF NOT EXISTS idx_deposits_status ON deposits(status);
CREATE INDEX IF NOT EXISTS idx_deposits_referrer_id ON deposits(referrer_id);

CREATE INDEX IF NOT EXISTS idx_withdrawals_user_id ON withdrawals(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status ON withdrawals(status);

CREATE INDEX IF NOT EXISTS idx_copy_trades_user_id ON copy_trades(user_id);

CREATE INDEX IF NOT EXISTS idx_daily_rewards_user_id ON daily_rewards(user_id);

CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee_id ON referrals(referee_id);

CREATE INDEX IF NOT EXISTS idx_promo_codes_code ON promo_codes(code);

CREATE INDEX IF NOT EXISTS idx_promo_redemptions_user_id ON promo_redemptions(user_id);
CREATE INDEX IF NOT EXISTS idx_promo_redemptions_promo_code_id ON promo_redemptions(promo_code_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);

-- =============================================
-- RPC FUNCTION: sum_daily_rewards
-- =============================================
CREATE OR REPLACE FUNCTION sum_daily_rewards(p_user_id UUID)
RETURNS NUMERIC
LANGUAGE SQL
STABLE
AS $$
  SELECT COALESCE(SUM(amount), 0) FROM daily_rewards WHERE user_id = p_user_id;
$$;

-- =============================================
-- SEED DATA: ranks
-- =============================================
INSERT INTO ranks (name, min_balance, max_balance, daily_profit_pct, copy_trades_limit, color) VALUES
  ('Starter',   0,      99,    0.5,  1, '#94a3b8'),
  ('Bronze',    100,    499,   0.8,  2, '#cd7f32'),
  ('Silver',    500,    1999,  1.0,  3, '#c0c0c0'),
  ('Gold',      2000,   4999,  1.5,  5, '#ffd700'),
  ('Platinum',  5000,   9999,  2.0,  8, '#e5e4e2'),
  ('Diamond',   10000,  49999, 3.0,  12, '#b9f2ff'),
  ('Elite',     50000,  999999999, 5.0, 20, '#ff6b6b')
ON CONFLICT DO NOTHING;

-- =============================================
-- DISABLE RLS on all tables (service_role bypasses anyway)
-- =============================================
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE ranks DISABLE ROW LEVEL SECURITY;
ALTER TABLE deposits DISABLE ROW LEVEL SECURITY;
ALTER TABLE withdrawals DISABLE ROW LEVEL SECURITY;
ALTER TABLE copy_trades DISABLE ROW LEVEL SECURITY;
ALTER TABLE daily_rewards DISABLE ROW LEVEL SECURITY;
ALTER TABLE referrals DISABLE ROW LEVEL SECURITY;
ALTER TABLE promo_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE promo_redemptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE transactions DISABLE ROW LEVEL SECURITY;
