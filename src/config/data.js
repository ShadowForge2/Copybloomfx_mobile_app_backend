import { Op, fn, col, literal } from 'sequelize';
import { supabase, db } from './supabase.js';
import {
  sequelize, syncDatabase,
  User as UserModel, Profile as ProfileModel, Rank as RankModel,
  Deposit as DepositModel, Withdrawal as WithdrawalModel,
  CopyTrade as CopyTradeModel, DailyReward as DailyRewardModel,
  Referral as ReferralModel, PromoCode as PromoCodeModel,
  PromoRedemption as PromoRedemptionModel,
  Notification as NotificationModel, Transaction as TransactionModel,
  AuditLog as AuditLogModel, Session as SessionModel,
} from '../models/index.js';

const USE_SQLITE = process.env.USE_SQLITE === 'true';

// ---------- Helpers ----------

function sq(result) {
  if (!result) return null;
  return result.get({ plain: true });
}

function mq(results) {
  return (results || []).map(r => r.get({ plain: true }));
}

// ---------- Users ----------

export async function getUser(id) {
  if (USE_SQLITE) {
    return sq(await UserModel.findByPk(id));
  }
  const { data, error } = await supabase.from('users').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getUserBy(field, value) {
  if (USE_SQLITE) {
    return sq(await UserModel.findOne({ where: { [field]: value } }));
  }
  const { data, error } = await supabase.from('users').select('*').eq(field, value).single();
  if (error) throw error;
  return data;
}

/** Case-insensitive username lookup for admin notification targeting. */
export async function getUserByUsernameInsensitive(username) {
  const normalized = String(username ?? '').trim();
  if (!normalized) return null;
  if (USE_SQLITE) {
    return sq(await UserModel.findOne({
      where: literal(`LOWER(username) = ${sequelize.escape(normalized.toLowerCase())}`),
    }));
  }
  const { data, error } = await supabase.from('users').select('*').ilike('username', normalized).maybeSingle();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function getUsers(where = {}, opts = {}) {
  if (USE_SQLITE) {
    const q = { where };
    if (opts.order) q.order = [[opts.order, opts.asc ? 'ASC' : 'DESC']];
    if (opts.limit) q.limit = opts.limit;
    return mq(await UserModel.findAll(q));
  }
  let q = supabase.from('users').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  if (opts.order) q = q.order(opts.order, { ascending: opts.asc ?? false });
  if (opts.limit) q = q.limit(opts.limit);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

export async function createUser(data) {
  if (USE_SQLITE) {
    return sq(await UserModel.create(data));
  }
  const { data: result, error } = await supabase.from('users').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function updateUser(id, data) {
  if (USE_SQLITE) {
    await UserModel.update(data, { where: { id } });
    return sq(await UserModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('users').update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

// ---------- Profiles ----------

export async function getProfile(userId) {
  if (USE_SQLITE) {
    return sq(await ProfileModel.findOne({ where: { user_id: userId } }));
  }
  const { data, error } = await supabase.from('profiles').select('*').eq('user_id', userId).single();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function createProfile(data) {
  if (USE_SQLITE) {
    return sq(await ProfileModel.create(data));
  }
  const { data: result, error } = await supabase.from('profiles').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function updateProfile(userId, data) {
  if (USE_SQLITE) {
    await ProfileModel.update(data, { where: { user_id: userId } });
    return sq(await ProfileModel.findOne({ where: { user_id: userId } }));
  }
  const { data: result, error } = await supabase.from('profiles').update(data).eq('user_id', userId).select().single();
  if (error) throw error;
  return result;
}

// ---------- Ranks ----------

export async function getRank(id) {
  if (USE_SQLITE) {
    return sq(await RankModel.findByPk(id));
  }
  const { data, error } = await supabase.from('ranks').select('*').eq('id', id).maybeSingle();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function getAllRanks() {
  if (USE_SQLITE) {
    return mq(await RankModel.findAll({ order: [['min_balance', 'ASC']] }));
  }
  const { data, error } = await supabase.from('ranks').select('*').order('min_balance', { ascending: true });
  if (error) throw error;
  return data || [];
}

// ---------- Deposits ----------

export async function getDeposit(id) {
  if (USE_SQLITE) {
    return sq(await DepositModel.findByPk(id));
  }
  const { data, error } = await supabase.from('deposits').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getDeposits(where = {}) {
  if (USE_SQLITE) {
    return mq(await DepositModel.findAll({ where, order: [['created_at', 'DESC']] }));
  }
  let q = supabase.from('deposits').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q.order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function createDeposit(data) {
  if (USE_SQLITE) {
    return sq(await DepositModel.create(data));
  }
  const { data: result, error } = await supabase.from('deposits').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function updateDeposit(id, data) {
  if (USE_SQLITE) {
    await DepositModel.update(data, { where: { id } });
    return sq(await DepositModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('deposits').update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

/** Atomic status transition — prevents duplicate expiry / double balance reversal. */
export async function updateDepositIfStatus(id, expectedStatus, data) {
  if (USE_SQLITE) {
    const [affected] = await DepositModel.update(data, { where: { id, status: expectedStatus } });
    if (!affected) return null;
    return sq(await DepositModel.findByPk(id));
  }
  const { data: result, error } = await supabase
    .from('deposits')
    .update(data)
    .eq('id', id)
    .eq('status', expectedStatus)
    .select()
    .maybeSingle();
  if (error) throw error;
  return result;
}

// ---------- Withdrawals ----------

export async function getWithdrawal(id) {
  if (USE_SQLITE) {
    return sq(await WithdrawalModel.findByPk(id));
  }
  const { data, error } = await supabase.from('withdrawals').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getWithdrawals(where = {}) {
  if (USE_SQLITE) {
    return mq(await WithdrawalModel.findAll({ where, order: [['created_at', 'DESC']] }));
  }
  let q = supabase.from('withdrawals').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q.order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function createWithdrawal(data) {
  if (USE_SQLITE) {
    return sq(await WithdrawalModel.create(data));
  }
  const { data: result, error } = await supabase.from('withdrawals').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function updateWithdrawal(id, data) {
  if (USE_SQLITE) {
    await WithdrawalModel.update(data, { where: { id } });
    return sq(await WithdrawalModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('withdrawals').update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

// ---------- Copy Trades ----------

export async function getCopyTrades(userId, limit = 20) {
  if (USE_SQLITE) {
    return mq(await CopyTradeModel.findAll({
      where: { user_id: userId },
      order: [['created_at', 'DESC']],
      limit,
    }));
  }
  const { data, error } = await supabase.from('copy_trades').select('*').eq('user_id', userId)
    .order('created_at', { ascending: false }).limit(limit);
  if (error) throw error;
  return data || [];
}

export async function countCopyTrades(userId) {
  const { getMidnightWAT } = await import('../utils/helpers.js');
  const cutoff = getMidnightWAT();
  if (USE_SQLITE) {
    return await CopyTradeModel.count({ where: { user_id: userId, created_at: { [Op.gte]: cutoff } } });
  }
  const { count, error } = await supabase.from('copy_trades')
    .select('*', { count: 'exact', head: true }).eq('user_id', userId).gte('created_at', cutoff.toISOString());
  if (error) throw error;
  return count || 0;
}

export async function createCopyTrade(data) {
  if (USE_SQLITE) {
    return sq(await CopyTradeModel.create(data));
  }
  const { data: result, error } = await supabase.from('copy_trades').insert(data).select().single();
  if (error) throw error;
  return result;
}

// ---------- Daily Rewards ----------

export async function getLastDailyReward(userId) {
  if (USE_SQLITE) {
    const r = await DailyRewardModel.findOne({
      where: { user_id: userId },
      order: [['claimed_at', 'DESC']],
    });
    return r ? sq(r) : null;
  }
  const { data, error } = await supabase.from('daily_rewards').select('*')
    .eq('user_id', userId).order('claimed_at', { ascending: false }).limit(1);
  if (error) throw error;
  return data && data.length > 0 ? data[0] : null;
}

export async function createDailyReward(data) {
  if (USE_SQLITE) {
    return sq(await DailyRewardModel.create(data));
  }
  const { error } = await supabase.from('daily_rewards').insert(data);
  if (error) throw error;
  return data;
}

export async function sumDailyRewards(userId) {
  if (USE_SQLITE) {
    const result = await DailyRewardModel.findAll({
      where: { user_id: userId },
      attributes: [[fn('COALESCE', fn('SUM', col('amount')), 0), 'total']],
      raw: true,
    });
    return parseFloat(result[0]?.total || 0);
  }
  const { data, error } = await supabase.rpc('sum_daily_rewards', { p_user_id: userId });
  if (error) return 0;
  return data || 0;
}

// ---------- Referrals ----------

export async function createReferral(data) {
  if (USE_SQLITE) {
    return sq(await ReferralModel.create(data));
  }
  const { data: result, error } = await supabase.from('referrals').insert(data).select().single();
  if (error) throw error;
  return result;
}

// ---------- Promo Codes ----------

export async function getPromoCode(id) {
  if (USE_SQLITE) {
    return sq(await PromoCodeModel.findByPk(id));
  }
  const { data, error } = await supabase.from('promo_codes').select('*').eq('id', id).maybeSingle();
  if (error) throw error;
  return data;
}

export async function getPromoCodeByCode(code) {
  const normalized = String(code ?? '').trim().toUpperCase();
  if (!normalized) return null;
  if (USE_SQLITE) {
    return sq(await PromoCodeModel.findOne({
      where: literal(`UPPER(code) = ${sequelize.escape(normalized)}`),
    }));
  }
  const { data, error } = await supabase.from('promo_codes').select('*').ilike('code', normalized).maybeSingle();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function getAllPromoCodes() {
  if (USE_SQLITE) {
    return mq(await PromoCodeModel.findAll({ order: [['created_at', 'DESC']] }));
  }
  const { data, error } = await supabase.from('promo_codes').select('*').order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function createPromoCode(data) {
  if (USE_SQLITE) {
    return sq(await PromoCodeModel.create(data));
  }
  const { data: result, error } = await supabase.from('promo_codes').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function updatePromoCode(id, data) {
  if (USE_SQLITE) {
    await PromoCodeModel.update(data, { where: { id } });
    return sq(await PromoCodeModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('promo_codes').update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

// ---------- Promo Redemptions ----------

export async function getPromoRedemption(userId, promoCodeId) {
  if (USE_SQLITE) {
    return sq(await PromoRedemptionModel.findOne({ where: { user_id: userId, promo_code_id: promoCodeId } }));
  }
  const { data, error } = await supabase.from('promo_redemptions').select('*')
    .eq('user_id', userId).eq('promo_code_id', promoCodeId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function createPromoRedemption(data) {
  if (USE_SQLITE) {
    return sq(await PromoRedemptionModel.create(data));
  }
  const { data: result, error } = await supabase.from('promo_redemptions').insert(data).select().single();
  if (error) throw error;
  return result;
}

/** Optimistic lock: only increments when usage_count still matches expectedCount. */
export async function incrementPromoUsageIfBelowLimit(promoId, expectedCount, usageLimit) {
  const current = expectedCount ?? 0;
  if (usageLimit != null && current >= usageLimit) return false;

  if (USE_SQLITE) {
    const [affected] = await PromoCodeModel.update(
      { usage_count: current + 1 },
      { where: { id: promoId, usage_count: current } },
    );
    return affected === 1;
  }

  const { data, error } = await supabase
    .from('promo_codes')
    .update({ usage_count: current + 1 })
    .eq('id', promoId)
    .eq('usage_count', current)
    .select('id')
    .maybeSingle();
  if (error) throw error;
  return data != null;
}

/** Roll back usage increment when redemption insert fails (duplicate race). */
export async function decrementPromoUsage(promoId, expectedCountAfterIncrement) {
  const target = Math.max(0, (expectedCountAfterIncrement ?? 1) - 1);
  if (USE_SQLITE) {
    await PromoCodeModel.update(
      { usage_count: target },
      { where: { id: promoId, usage_count: expectedCountAfterIncrement } },
    );
    return;
  }
  await supabase
    .from('promo_codes')
    .update({ usage_count: target })
    .eq('id', promoId)
    .eq('usage_count', expectedCountAfterIncrement);
}

export async function getAllRedemptions() {
  if (USE_SQLITE) {
    return mq(await PromoRedemptionModel.findAll({ order: [['created_at', 'DESC']], limit: 100 }));
  }
  const { data, error } = await supabase.from('promo_redemptions').select('*').order('created_at', { ascending: false }).limit(100);
  if (error) throw error;
  return data || [];
}

// ---------- Notifications ----------

export async function getNotifications(userId) {
  if (USE_SQLITE) {
    return mq(await NotificationModel.findAll({
      where: { user_id: userId },
      order: [['created_at', 'DESC']],
      limit: 50,
    }));
  }
  const { data, error } = await supabase.from('notifications').select('*').eq('user_id', userId)
    .order('created_at', { ascending: false }).limit(50);
  if (error) throw error;
  return data || [];
}

export async function markNotificationsRead(userId) {
  if (USE_SQLITE) {
    await NotificationModel.update({ is_read: true }, { where: { user_id: userId, is_read: false } });
    return;
  }
  const { error } = await supabase.from('notifications')
    .update({ is_read: true }).eq('user_id', userId).eq('is_read', false);
  if (error) throw error;
}

export async function markNotificationRead(userId, notificationId) {
  if (!notificationId) return;
  if (USE_SQLITE) {
    await NotificationModel.update(
      { is_read: true },
      { where: { id: notificationId, user_id: userId, is_read: false } },
    );
    return;
  }
  const { error } = await supabase.from('notifications')
    .update({ is_read: true })
    .eq('id', notificationId)
    .eq('user_id', userId)
    .eq('is_read', false);
  if (error) throw error;
}

export async function createNotification(userId, title, body, type = 'info') {
  const data = { user_id: userId, title, body, type, is_read: false };
  if (USE_SQLITE) {
    return sq(await NotificationModel.create(data));
  }
  const { data: result, error } = await supabase.from('notifications').insert(data).select().single();
  if (error) throw error;
  return result;
}

// ---------- Transactions ----------

export async function createTransaction(data) {
  if (USE_SQLITE) {
    return sq(await TransactionModel.create(data));
  }
  const { data: result, error } = await supabase.from('transactions').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function getTransaction(id) {
  if (USE_SQLITE) {
    return sq(await TransactionModel.findByPk(id));
  }
  const { data, error } = await supabase.from('transactions').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getTransactions(where = {}, opts = {}) {
  if (USE_SQLITE) {
    return sq(await TransactionModel.findAll({ where, order: [['created_at', 'DESC']], limit: opts.limit || 50 }));
  }
  let q = supabase.from('transactions').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  if (opts.order) q = q.order(opts.order, { ascending: opts.asc ?? false });
  const { data, error } = await q.order('created_at', { ascending: false }).limit(opts.limit || 50);
  if (error) throw error;
  return data || [];
}

// ---------- Counts & Aggregates ----------

export async function countUsers(where = {}) {
  if (USE_SQLITE) {
    return await UserModel.count({ where });
  }
  let q = supabase.from('users').select('*', { count: 'exact', head: true });
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { count, error } = await q;
  if (error) throw error;
  return count || 0;
}

export async function sumDeposits(where = {}) {
  if (USE_SQLITE) {
    const rows = await DepositModel.findAll({ where, attributes: ['amount'], raw: true });
    return rows.reduce((s, r) => s + parseFloat(r.amount || 0), 0);
  }
  let q = supabase.from('deposits').select('amount');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return (data || []).reduce((s, r) => s + parseFloat(r.amount || 0), 0);
}

export async function sumWithdrawals(where = {}) {
  if (USE_SQLITE) {
    const rows = await WithdrawalModel.findAll({ where, attributes: ['amount'], raw: true });
    return rows.reduce((s, r) => s + parseFloat(r.amount || 0), 0);
  }
  let q = supabase.from('withdrawals').select('amount');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return (data || []).reduce((s, r) => s + parseFloat(r.amount || 0), 0);
}

// ---------- Admin Helpers ----------

export async function getProfileByReferralCode(code) {
  if (USE_SQLITE) {
    return sq(await ProfileModel.findOne({ where: { referral_code: code } }));
  }
  const { data, error } = await supabase.from('profiles').select('*').eq('referral_code', code).maybeSingle();
  if (error) throw error;
  return data;
}

export async function getDepositWithUser(id) {
  if (USE_SQLITE) {
    const d = await DepositModel.findByPk(id, {
      include: [{ model: UserModel, attributes: ['id', 'username', 'email', 'is_flagged', 'is_banned', 'last_login_ip'] }],
    });
    if (!d) return null;
    const plain = d.get({ plain: true });
    return { ...plain, users: plain.User };
  }
  const { data, error } = await supabase.from('deposits').select(`
    *, users!inner(id, username, email, is_flagged, is_banned, last_login_ip)
  `).eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getWithdrawalWithUser(id) {
  if (USE_SQLITE) {
    const w = await WithdrawalModel.findByPk(id, {
      include: [{ model: UserModel, attributes: ['id', 'username', 'email', 'is_flagged', 'is_banned'] }],
    });
    if (!w) return null;
    const plain = w.get({ plain: true });
    return { ...plain, users: plain.User };
  }
  const { data, error } = await supabase.from('withdrawals').select(`
    *, users!inner(id, username, email, is_flagged, is_banned)
  `).eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getUsersForAdmin(where = {}) {
  if (USE_SQLITE) {
    const q = { where, order: [['created_at', 'DESC']], limit: 200 };
    return mq(await UserModel.findAll(q));
  }
  let q = supabase.from('users').select('*').order('created_at', { ascending: false }).limit(200);
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

// ---------- Audit Logs ----------

export async function createAuditLog(data) {
  if (USE_SQLITE) {
    return sq(await AuditLogModel.create(data));
  }
  const { data: result, error } = await supabase.from('audit_logs').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function getAuditLogs(where = {}, limit = 200) {
  if (USE_SQLITE) {
    return mq(await AuditLogModel.findAll({ where, order: [['created_at', 'DESC']], limit }));
  }
  let q = supabase.from('audit_logs').select('*').order('created_at', { ascending: false }).limit(limit);
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q;
  if (error) throw error;
  return data || [];
}

// ---------- Sessions ----------

export async function createSession(data) {
  if (USE_SQLITE) {
    return sq(await SessionModel.create(data));
  }
  const { data: result, error } = await supabase.from('sessions').insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function getSession(id) {
  if (USE_SQLITE) {
    return sq(await SessionModel.findByPk(id));
  }
  const { data, error } = await supabase.from('sessions').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function updateSession(id, data) {
  if (USE_SQLITE) {
    await SessionModel.update(data, { where: { id } });
    return sq(await SessionModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('sessions').update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

// ---------- Export supabase raw clients for direct use ----------

export { supabase, db, syncDatabase };
