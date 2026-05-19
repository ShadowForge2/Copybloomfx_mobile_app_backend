import { Op, fn, col, literal } from 'sequelize';
import { supabase, db } from './supabase.js';
import nodemailer from 'nodemailer';
import {
  sequelize, syncDatabase,
  User as UserModel, Profile as ProfileModel, Rank as RankModel,
  Deposit as DepositModel, Withdrawal as WithdrawalModel,
  CopyTrade as CopyTradeModel, DailyReward as DailyRewardModel,
  Referral as ReferralModel, PromoCode as PromoCodeModel,
  PromoRedemption as PromoRedemptionModel,
  Notification as NotificationModel, Transaction as TransactionModel,
  AuditLog as AuditLogModel, Session as SessionModel,
  SupportConversation as SupportConversationModel,
  SupportMessage as SupportMessageModel,
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

function toNum(value) {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  const parsed = parseFloat(value);
  return Number.isNaN(parsed) ? 0 : parsed;
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

export async function getTodayCopyTradesSum(userId) {
  const { getMidnightWAT } = await import('../utils/helpers.js');
  const cutoff = getMidnightWAT();
  if (USE_SQLITE) {
    const trades = await CopyTradeModel.findAll({
      where: { user_id: userId, created_at: { [Op.gte]: cutoff } },
    });
    return trades.reduce((s, t) => s + toNum(t.profit), 0);
  }
  const { data, error } = await supabase.from('copy_trades')
    .select('profit').eq('user_id', userId).gte('created_at', cutoff.toISOString());
  if (error) throw error;
  return (data || []).reduce((s, t) => s + toNum(t.profit), 0);
}

export async function createCopyTrade(data) {
  if (USE_SQLITE) {
    return sq(await CopyTradeModel.create(data));
  }
  // Defensive insert: some DB instances may have a stricter CHECK on `status`.
  // Normalize common status input and retry without `status` if the DB rejects it.
  const safeData = { ...data };
  if (safeData.status && typeof safeData.status === 'string') {
    // normalize common variants to 'pending' when creating
    const s = safeData.status.toLowerCase();
    if (['pending', 'approved', 'rejected', 'completed', 'active'].includes(s)) {
      safeData.status = s;
    } else {
      delete safeData.status;
    }
  }

  let insertRes = await supabase.from('copy_trades').insert(safeData).select().single();
  if (insertRes.error) {
    const msg = (insertRes.error?.message || '').toLowerCase();
    if (msg.includes('check') && msg.includes('status') && msg.includes('copy_trade')) {
      // retry without status field entirely (let DB default apply)
      const retryData = { ...safeData };
      delete retryData.status;
      const { data: r2, error: err2 } = await supabase.from('copy_trades').insert(retryData).select().single();
      if (err2) throw err2;
      return r2;
    }
    throw insertRes.error;
  }
  return insertRes.data;
}

export async function getPendingCopyTradesToClose(userId) {
  if (USE_SQLITE) {
    return mq(await CopyTradeModel.findAll({
      where: { user_id: userId, status: 'pending', close_at: { [Op.lte]: new Date() } },
      order: [['created_at', 'ASC']],
    }));
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase.from('copy_trades')
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'pending')
    .lte('close_at', now)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data || [];
}

export async function updateCopyTradesStatus(ids, status) {
  if (!ids.length) return [];
  if (USE_SQLITE) {
    await CopyTradeModel.update({ status }, { where: { id: ids } });
    return mq(await CopyTradeModel.findAll({ where: { id: ids } }));
  }
  const { data, error } = await supabase.from('copy_trades').update({ status }).in('id', ids).select();
  if (error) throw error;
  return data || [];
}

export async function updateUserRank(userId) {
  const profile = await getProfile(userId);
  if (!profile) return null;
  const total = toNum(profile.locked_balance);
  if (total <= 0) {
    if (profile.rank_id !== null) await updateProfile(userId, { rank_id: null });
    return null;
  }
  const ranks = await getAllRanks();
  let newRankId = null;
  for (const r of ranks) {
    if (total >= toNum(r.min_balance)) {
      if (r.max_balance === null || total <= toNum(r.max_balance)) {
        newRankId = r.id;
        break;
      }
    }
  }
  if (newRankId !== profile.rank_id) await updateProfile(userId, { rank_id: newRankId });
  return newRankId ? getRank(newRankId) : null;
}

export async function processMatureCopyTrades(userId) {
  const matureTrades = await getPendingCopyTradesToClose(userId);
  if (!matureTrades.length) return matureTrades;

  const totalProfit = matureTrades.reduce((sum, trade) => sum + Math.max(toNum(trade.profit), 0), 0);
  const ids = matureTrades.map((t) => t.id);
  await updateCopyTradesStatus(ids, 'completed');

  if (totalProfit > 0) {
    const profile = await getProfile(userId);
    if (profile) {
      await updateProfile(userId, { withdrawable_balance: toNum(profile.withdrawable_balance) + totalProfit });
      await updateUserRank(userId);
    }
  }

  return matureTrades;
}

export async function getPendingCopyTradesToCloseAll() {
  if (USE_SQLITE) {
    return mq(await CopyTradeModel.findAll({
      where: { user_id: { [Op.ne]: null }, status: 'pending', close_at: { [Op.lte]: new Date() } },
      order: [['created_at', 'ASC']],
    }));
  }

  const now = new Date().toISOString();
  const { data, error } = await supabase.from('copy_trades')
    .select('*')
    .eq('status', 'pending')
    .lte('close_at', now)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data || [];
}

export async function processMatureCopyTradesAll() {
  const matureTrades = await getPendingCopyTradesToCloseAll();
  if (!matureTrades.length) return 0;

  const userProfitMap = new Map();
  const ids = [];
  for (const trade of matureTrades) {
    ids.push(trade.id);
    const profit = Math.max(toNum(trade.profit), 0);
    userProfitMap.set(trade.user_id, (userProfitMap.get(trade.user_id) || 0) + profit);
  }

  await updateCopyTradesStatus(ids, 'completed');

  for (const [userId, profit] of userProfitMap.entries()) {
    if (profit <= 0) continue;
    const profile = await getProfile(userId);
    if (!profile) continue;
    await updateProfile(userId, { withdrawable_balance: toNum(profile.withdrawable_balance) + profit });
    await updateUserRank(userId);
  }

  return matureTrades.length;
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

export async function getReferralByDepositId(depositId) {
  if (!depositId) return null;
  if (USE_SQLITE) {
    return sq(await ReferralModel.findOne({ where: { deposit_id: depositId } }));
  }
  const { data, error } = await supabase.from('referrals').select('*').eq('deposit_id', depositId).maybeSingle();
  if (error && error.code === 'PGRST116') return null;
  if (error) throw error;
  return data;
}

export async function getReferrals(where = {}) {
  if (USE_SQLITE) {
    return mq(await ReferralModel.findAll({
      where,
      order: [['created_at', 'DESC']],
    }));
  }
  let q = supabase.from('referrals').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q.order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function getProfilesByReferredBy(referrerUserId) {
  if (!referrerUserId) return [];
  if (USE_SQLITE) {
    return mq(await ProfileModel.findAll({
      where: { referred_by: referrerUserId },
      order: [['created_at', 'DESC']],
    }));
  }
  const { data, error } = await supabase.from('profiles').select('*')
    .eq('referred_by', referrerUserId)
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
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
  // Try regular insert first. If the DB doesn't have a `type` column
  // (e.g. running older schema), fall back to inserting without it.
  let result;
  let insertRes = await supabase.from('notifications').insert(data).select().single();
  if (insertRes.error) {
    const msg = (insertRes.error?.message || '').toLowerCase();
    if (msg.includes('column "type"') || msg.includes('column \"type\" does not exist') || msg.includes('unknown column')) {
      const { data: r2, error: err2 } = await supabase.from('notifications')
        .insert({ user_id: userId, title, body, is_read: false }).select().single();
      if (err2) throw err2;
      result = r2;
    } else {
      throw insertRes.error;
    }
  } else {
    result = insertRes.data;
  }
  // Send an email copy if SMTP is configured and the user has an email address.
  try {
    const smtpHost = process.env.SMTP_HOST;
    if (smtpHost) {
      const user = await getUser(userId).catch(() => null);
      const to = user?.email;
      if (to) {
        const transporter = nodemailer.createTransport({
          host: smtpHost,
          port: parseInt(process.env.SMTP_PORT || '587', 10),
          secure: (process.env.SMTP_SECURE === 'true'),
          auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS } : undefined,
        });
        const mailOptions = {
          from: process.env.EMAIL_FROM || process.env.SMTP_USER || 'no-reply@bloomfx.com',
          to,
          subject: title,
          text: body,
        };
        // send but don't block the main flow
        transporter.sendMail(mailOptions).catch(() => {});
      }
    }
  } catch (_) {
    // ignore email errors
  }
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

// ---------- Support Conversations & Messages ----------

export async function getOrCreateSupportConversation(userId) {
  if (USE_SQLITE) {
    let conv = sq(await SupportConversationModel.findOne({
      where: { user_id: userId },
      order: [['created_at', 'DESC']],
    }));
    if (!conv) {
      conv = sq(await SupportConversationModel.create({
        user_id: userId,
        status: 'open',
        last_message_at: new Date(),
      }));
    }
    return conv;
  }
  let { data, error } = await supabase.from('support_conversations')
    .select('*').eq('user_id', userId).order('created_at', { ascending: false }).limit(1);
  if (error) throw error;
  if (data && data.length > 0) return data[0];
  const { data: created, error: createError } = await supabase.from('support_conversations')
    .insert({ user_id: userId, status: 'open', last_message_at: new Date().toISOString() })
    .select().single();
  if (createError) throw createError;
  return created;
}

export async function getSupportConversation(id) {
  if (USE_SQLITE) {
    return sq(await SupportConversationModel.findByPk(id));
  }
  const { data, error } = await supabase.from('support_conversations').select('*').eq('id', id).single();
  if (error) throw error;
  return data;
}

export async function getSupportConversations(where = {}) {
  if (USE_SQLITE) {
    return mq(await SupportConversationModel.findAll({
      where,
      order: [['last_message_at', 'DESC']],
    }));
  }
  let q = supabase.from('support_conversations').select('*');
  for (const [k, v] of Object.entries(where)) q = q.eq(k, v);
  const { data, error } = await q.order('last_message_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function updateSupportConversation(id, data) {
  if (USE_SQLITE) {
    await SupportConversationModel.update(data, { where: { id } });
    return sq(await SupportConversationModel.findByPk(id));
  }
  const { data: result, error } = await supabase.from('support_conversations')
    .update(data).eq('id', id).select().single();
  if (error) throw error;
  return result;
}

export async function getSupportMessages(conversationId) {
  if (USE_SQLITE) {
    return mq(await SupportMessageModel.findAll({
      where: { conversation_id: conversationId },
      order: [['created_at', 'ASC']],
    }));
  }
  const { data, error } = await supabase.from('support_messages')
    .select('*').eq('conversation_id', conversationId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data || [];
}

export async function createSupportMessage(data) {
  if (USE_SQLITE) {
    return sq(await SupportMessageModel.create(data));
  }
  const { data: result, error } = await supabase.from('support_messages')
    .insert(data).select().single();
  if (error) throw error;
  return result;
}

export async function markSupportMessageAsRead(messageId) {
  if (USE_SQLITE) {
    await SupportMessageModel.update({ is_read: true }, { where: { id: messageId } });
    return true;
  }
  const { error } = await supabase.from('support_messages')
    .update({ is_read: true }).eq('id', messageId);
  if (error) throw error;
  return true;
}

export async function countUnreadConversationMessages(conversationId) {
  if (USE_SQLITE) {
    return await SupportMessageModel.count({
      where: { conversation_id: conversationId, is_read: false },
    });
  }
  const { count, error } = await supabase.from('support_messages')
    .select('*', { count: 'exact', head: true })
    .eq('conversation_id', conversationId).eq('is_read', false);
  if (error) throw error;
  return count || 0;
}

// ---------- Export supabase raw clients for direct use ----------

export { supabase, db, syncDatabase };
