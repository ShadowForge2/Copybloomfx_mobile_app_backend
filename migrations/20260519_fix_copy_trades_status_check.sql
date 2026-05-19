-- Migration: ensure copy_trades.status CHECK allows expected values
-- Drops common constraint names if present, then adds a normalized check.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'copy_trades_status_check') THEN
    ALTER TABLE copy_trades DROP CONSTRAINT copy_trades_status_check;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'copytrades_status_check') THEN
    ALTER TABLE copy_trades DROP CONSTRAINT copytrades_status_check;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'copy_trades_status_check_constraint') THEN
    ALTER TABLE copy_trades DROP CONSTRAINT copy_trades_status_check_constraint;
  END IF;
  -- Add a permissive status check covering the values used by the app.
  -- Adjust the set if you prefer fewer allowed values.
  ALTER TABLE copy_trades
    ADD CONSTRAINT copy_trades_status_check CHECK (status IN ('pending','completed','active','approved','rejected'));
END$$;
