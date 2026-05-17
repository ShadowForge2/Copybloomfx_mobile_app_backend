-- Safe additive migration: improves expiry cron query performance.
-- Does NOT modify balances or deposit rows.
-- Run in Supabase SQL Editor if indexes are not already present.

CREATE INDEX IF NOT EXISTS idx_deposits_expires_at ON deposits(expires_at);
CREATE INDEX IF NOT EXISTS idx_deposits_status_expires ON deposits(status, expires_at);
