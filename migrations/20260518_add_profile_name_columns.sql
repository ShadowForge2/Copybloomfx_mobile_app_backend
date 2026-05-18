-- Migration: Add first_name, last_name, and referred_by columns to profiles table
-- Run this in Supabase SQL Editor if these columns are missing
-- This migration is safe to run multiple times (uses IF NOT EXISTS)

-- Add first_name column if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'first_name'
  ) THEN
    ALTER TABLE profiles ADD COLUMN first_name TEXT;
    RAISE NOTICE 'Added first_name column to profiles table';
  ELSE
    RAISE NOTICE 'Column first_name already exists in profiles table';
  END IF;
END $$;

-- Add last_name column if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'last_name'
  ) THEN
    ALTER TABLE profiles ADD COLUMN last_name TEXT;
    RAISE NOTICE 'Added last_name column to profiles table';
  ELSE
    RAISE NOTICE 'Column last_name already exists in profiles table';
  END IF;
END $$;

-- Add referred_by column if it doesn't exist
DO $$ 
BEGIN 
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = 'referred_by'
  ) THEN
    ALTER TABLE profiles ADD COLUMN referred_by TEXT;
    RAISE NOTICE 'Added referred_by column to profiles table';
  ELSE
    RAISE NOTICE 'Column referred_by already exists in profiles table';
  END IF;
END $$;

-- Verify the schema
DO $$ 
DECLARE
  missing_cols TEXT[];
BEGIN
  SELECT ARRAY_AGG(column_name)
  INTO missing_cols
  FROM (
    SELECT 'first_name' AS column_name
    UNION ALL SELECT 'last_name'
    UNION ALL SELECT 'referred_by'
  ) AS required
  WHERE NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'profiles' AND column_name = required.column_name
  );
  
  IF missing_cols IS NOT NULL THEN
    RAISE EXCEPTION 'Missing columns in profiles table: %', array_to_string(missing_cols, ', ');
  ELSE
    RAISE NOTICE 'Profiles table schema verified - all required columns present';
  END IF;
END $$;