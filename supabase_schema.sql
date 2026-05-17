-- =============================================
-- BloomFX Complete Schema for Supabase
-- Fully synced with SQLite Sequelize models
-- Run this in Supabase SQL Editor
-- =============================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. RANKS
CREATE TABLE IF NOT EXISTS ranks (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  min_balance NUMERIC DEFAULT 0,
  max_balance NUMERIC,
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
  password_hash TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),
  is_flagged BOOLEAN DEFAULT FALSE,
  is_banned BOOLEAN DEFAULT FALSE,
  last_login_ip TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. PROFILES
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name TEXT,
  last_name TEXT,
  phone TEXT,
  email TEXT,
  country TEXT,
  referral_code TEXT UNIQUE,
  referred_by TEXT,
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

-- 4. DEPOSITS
CREATE TABLE IF NOT EXISTS deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  network TEXT,
  wallet_address TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
  reference TEXT,
  referrer_id UUID,
  expires_at TIMESTAMPTZ,
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. WITHDRAWALS
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

-- 6. COPY_TRADES
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

-- 7. DAILY_REWARDS
CREATE TABLE IF NOT EXISTS daily_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC DEFAULT 0,
  claimed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. REFERRALS
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  referee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bonus_amount NUMERIC DEFAULT 0,
  deposit_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. PROMO_CODES
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

-- 10. PROMO_REDEMPTIONS
CREATE TABLE IF NOT EXISTS promo_redemptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  bonus_amount NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 11. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT,
  body TEXT,
  type TEXT DEFAULT 'info',
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 12. TRANSACTIONS
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

-- 13. AUDIT_LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  target_user_id TEXT,
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id TEXT,
  description TEXT,
  metadata TEXT,
  ip_address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 14. SESSIONS
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  ip_address TEXT,
  user_agent TEXT,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_accessed_at TIMESTAMPTZ DEFAULT NOW()
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
CREATE INDEX IF NOT EXISTS idx_deposits_expires_at ON deposits(expires_at);
CREATE INDEX IF NOT EXISTS idx_deposits_status_expires ON deposits(status, expires_at);

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

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);

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
-- SEED DATA: ranks (synced with SQLite RANK_SEED)
-- =============================================
INSERT INTO ranks (name, min_balance, max_balance, daily_profit_pct, copy_trades_limit, color) VALUES
  ('Green Horn',      7,     49,    1.67, 1, '#4CAF50'),
  ('Student Form',    50,    100,   2.0,  2, '#2196F3'),
  ('Market Maven',    100,   500,   2.0,  3, '#9C27B0'),
  ('Gunslinger',      500,   1500,  2.2,  4, '#FF9800'),
  ('Whale',           1500,  5000,  2.5,  5, '#FFC107'),
  ('Market Wizard',   5000,  NULL,  2.7,  6, '#FFD700')
ON CONFLICT DO NOTHING;

-- =============================================
-- SEED DATA: admin user
-- =============================================
INSERT INTO users (id, username, email, role, status) VALUES
  ('00000000-0000-0000-0000-000000000000', 'admin', 'bashirabdulganiyy9@gmail.com', 'admin', 'active')
ON CONFLICT (id) DO NOTHING;

-- =============================================
-- DISABLE RLS (service_role bypasses anyway)
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
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE sessions DISABLE ROW LEVEL SECURITY;
