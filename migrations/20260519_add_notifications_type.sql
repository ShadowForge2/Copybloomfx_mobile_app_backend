-- Migration: add `type` column to notifications if missing
-- Safe to run multiple times; uses IF NOT EXISTS
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'info';
