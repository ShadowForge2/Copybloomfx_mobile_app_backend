import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.error('FATAL: SUPABASE_URL and SUPABASE_ANON_KEY env vars required');
  process.exit(1);
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export const db = supabaseServiceKey
  ? createClient(supabaseUrl, supabaseServiceKey)
  : supabase;

// ------------------------------------------------
//  Generic helpers (used internally by data.js)
// ------------------------------------------------

export function single(result) {
  const { data, error } = result;
  if (error) throw error;
  return data;
}

export function many(result) {
  const { data, error } = result;
  if (error) throw error;
  return data || [];
}
