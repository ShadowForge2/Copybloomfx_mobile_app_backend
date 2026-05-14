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
//  Generic helpers
// ------------------------------------------------

function single(result) {
  const { data, error } = result;
  if (error) throw error;
  return data;
}

function many(result) {
  const { data, error } = result;
  if (error) throw error;
  return data || [];
}

// ------------------------------------------------
//  users
// ------------------------------------------------

export async function getUser(id) {
  return single(await db.from('users').select('*').eq('id', id).single());
}

export async function getUserBy(field, value) {
  return single(await db.from('users').select('*').eq(field, value).single());
}

export async function getUsers(where = {}, opts = {}) {
  let q = db.from('users').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  if (opts.order) q = q.order(opts.order, { ascending: opts.asc ?? false });
  if (opts.limit) q = q.limit(opts.limit);
  return many(await q);
}

export async function createUser(data) {
  return single(await db.from('users').insert(data).select().single());
}

export async function updateUser(id, data) {
  return single(await db.from('users').update(data).eq('id', id).select().single());
}

// ------------------------------------------------
//  profiles
// ------------------------------------------------

export async function getProfile(userId) {
  const { data, error } = await db
    .from('profiles')
    .select('*')
    .eq('user_id', userId)
    .single();
  if (error && error.code === 'PGRST116') return null; // not found
  if (error) throw error;
  return data;
}

export async function createProfile(data) {
  return single(await db.from('profiles').insert(data).select().single());
}

export async function updateProfile(userId, data) {
  return single(await db.from('profiles').update(data).eq('user_id', userId).select().single());
}

// ------------------------------------------------
//  ranks
// ------------------------------------------------

export async function getRank(id) {
  return single(await db.from('ranks').select('*').eq('id', id).single());
}

export async function getAllRanks() {
  return many(await db.from('ranks').select('*').order('min_balance', { ascending: true }));
}

// ------------------------------------------------
//  deposits
// ------------------------------------------------

export async function getDeposit(id) {
  return single(await db.from('deposits').select('*').eq('id', id).single());
}

export async function getDeposits(where = {}) {
  let q = db.from('deposits').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  return many(await q.order('created_at', { ascending: false }));
}

export async function createDeposit(data) {
  return single(await db.from('deposits').insert(data).select().single());
}

export async function updateDeposit(id, data) {
  return single(await db.from('deposits').update(data).eq('id', id).select().single());
}

// ------------------------------------------------
//  withdrawals
// ------------------------------------------------

export async function getWithdrawal(id) {
  return single(await db.from('withdrawals').select('*').eq('id', id).single());
}

export async function getWithdrawals(where = {}) {
  let q = db.from('withdrawals').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  return many(await q.order('created_at', { ascending: false }));
}

export async function createWithdrawal(data) {
  return single(await db.from('withdrawals').insert(data).select().single());
}

export async function updateWithdrawal(id, data) {
  return single(await db.from('withdrawals').update(data).eq('id', id).select().single());
}

// ------------------------------------------------
//  copy_trades
// ------------------------------------------------

export async function getCopyTrades(userId, limit = 20) {
  return many(
    await db.from('copy_trades').select('*').eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(limit)
  );
}

export async function countCopyTrades(userId) {
  const { count, error } = await db.from('copy_trades')
    .select('*', { count: 'exact', head: true }).eq('user_id', userId);
  if (error) throw error;
  return count || 0;
}

export async function createCopyTrade(data) {
  return single(await db.from('copy_trades').insert(data).select().single());
}

// ------------------------------------------------
//  daily_rewards
// ------------------------------------------------

export async function getLastDailyReward(userId) {
  const { data, error } = await db.from('daily_rewards').select('*')
    .eq('user_id', userId).order('claimed_at', { ascending: false }).limit(1).single();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function createDailyReward(data) {
  return single(await db.from('daily_rewards').insert(data).select().single());
}

export async function sumDailyRewards(userId) {
  const { data, error } = await db.rpc('sum_daily_rewards', { p_user_id: userId });
  if (error) return 0;
  return data || 0;
}

// ------------------------------------------------
//  referrals
// ------------------------------------------------

export async function createReferral(data) {
  return single(await db.from('referrals').insert(data).select().single());
}

// ------------------------------------------------
//  promo_codes
// ------------------------------------------------

export async function getPromoCode(id) {
  const { data, error } = await db.from('promo_codes').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data;
}

export async function getPromoCodeByCode(code) {
  const { data, error } = await db.from('promo_codes').select('*').eq('code', code).single();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function getAllPromoCodes() {
  return many(await db.from('promo_codes').select('*').order('created_at', { ascending: false }));
}

export async function createPromoCode(data) {
  return single(await db.from('promo_codes').insert(data).select().single());
}

export async function updatePromoCode(id, data) {
  return single(await db.from('promo_codes').update(data).eq('id', id).select().single());
}

// ------------------------------------------------
//  promo_redemptions
// ------------------------------------------------

export async function getPromoRedemption(userId, promoCodeId) {
  const { data, error } = await db.from('promo_redemptions').select('*')
    .eq('user_id', userId).eq('promo_code_id', promoCodeId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function createPromoRedemption(data) {
  return single(await db.from('promo_redemptions').insert(data).select().single());
}

export async function getAllRedemptions() {
  return many(
    await db.from('promo_redemptions').select('*').order('created_at', { ascending: false }).limit(100)
  );
}

// ------------------------------------------------
//  notifications
// ------------------------------------------------

export async function getNotifications(userId) {
  return many(
    await db.from('notifications').select('*').eq('user_id', userId)
      .order('created_at', { ascending: false }).limit(50)
  );
}

export async function markNotificationsRead(userId) {
  const { error } = await db.from('notifications')
    .update({ is_read: true }).eq('user_id', userId).eq('is_read', false);
  if (error) throw error;
}

// ------------------------------------------------
//  transactions
// ------------------------------------------------

export async function createTransaction(data) {
  return single(await db.from('transactions').insert(data).select().single());
}

// ------------------------------------------------
//  Counts & aggregates (admin dashboard)
// ------------------------------------------------

export async function countUsers(where = {}) {
  let q = db.from('users').select('*', { count: 'exact', head: true });
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { count, error } = await q;
  if (error) throw error;
  return count || 0;
}

export async function sumDeposits(where = {}) {
  let q = db.from('deposits').select('amount', { count: 'exact', head: false });
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return (data || []).reduce((s, r) => s + parseFloat(r.amount || 0), 0);
}

export async function sumWithdrawals(where = {}) {
  let q = db.from('withdrawals').select('amount', { count: 'exact', head: false });
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return (data || []).reduce((s, r) => s + parseFloat(r.amount || 0), 0);
}

// ------------------------------------------------
//  Admin-specific: include user data with records
// ------------------------------------------------

export async function getProfileByReferralCode(code) {
  const { data, error } = await db.from('profiles').select('*').eq('referral_code', code).maybeSingle();
  if (error) throw error;
  return data;
}

export async function getDepositWithUser(id) {
  const { data, error } = await db.from('deposits').select(`
    *,
    users!inner(id, username, email, is_flagged, is_banned, last_login_ip)
  `).eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getWithdrawalWithUser(id) {
  const { data, error } = await db.from('withdrawals').select(`
    *,
    users!inner(id, username, email, is_flagged, is_banned)
  `).eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getUsersForAdmin(where = {}) {
  let q = db.from('users').select('*').order('created_at', { ascending: false }).limit(200);
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  return many(await q);
}
