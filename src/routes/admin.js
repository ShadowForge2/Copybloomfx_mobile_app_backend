import { Router } from 'express';
import {
  getUser, getProfile, getRank, getAllRanks,
  updateProfile, updateUser,
  getDeposit, updateDeposit, getDeposits,
  getWithdrawal, updateWithdrawal, getWithdrawals,
  getPromoCode, getPromoCodeByCode, getAllPromoCodes, createPromoCode, updatePromoCode,
  getAllRedemptions,
  countUsers, sumDeposits, sumWithdrawals,
  getProfileByReferralCode, getUsersForAdmin, getUserBy, getUsers,
  getUserByUsernameInsensitive,
  createNotification, createAuditLog, createTransaction, getTransactions,
  createDeposit,
} from '../config/data.js';
import { authMiddleware, adminOnly } from '../middleware/auth.js';
import { toNum, normalizePromoCode, roundMoney } from '../utils/helpers.js';
import { releaseAssignment } from '../utils/wallets.js';
import { approvedLockExpiresAt } from '../services/depositExpiry.js';
import { payReferralCommission } from '../services/referralCommission.js';

const router = Router();
router.use(authMiddleware);
router.use(adminOnly);

function rankMax(r) {
  return r.max_balance !== null && r.max_balance !== undefined ? toNum(r.max_balance) : 999999;
}

function profileToJson(p, rank) {
  return {
    lockedBalance: toNum(p?.locked_balance),
    withdrawableBalance: toNum(p?.withdrawable_balance),
    totalBalance: toNum(p?.locked_balance) + toNum(p?.withdrawable_balance),
    referralCode: p?.referral_code,
    totalReferrals: p?.total_referrals ?? 0,
    validReferrals: p?.valid_referrals ?? 0,
    referralEarnings: toNum(p?.referral_earnings),
    rank: rank ? { id: rank.id, name: rank.name, maxBalance: rankMax(rank), color: rank.color, copyTradesLimit: rank.copy_trades_limit } : null,
  };
}

async function updateUserRank(userId) {
  const profile = await getProfile(userId);
  if (!profile) return null;
  const total = toNum(profile.locked_balance) + toNum(profile.withdrawable_balance);
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

// ============ DASHBOARD ============

const QUERY_TIMEOUT = 15000;

async function withFallback(promise, fallback) {
  try {
    const result = await Promise.race([
      promise,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Query timeout')), QUERY_TIMEOUT)),
    ]);
    return result;
  } catch (e) {
    console.error('[DB] Query error/timeout:', e.message);
    return fallback;
  }
}

router.get('/dashboard', async (req, res) => {
  try {
    const [totalUsers, totalDepositAmount, totalWithdrawalAmount, pendingDeps, pendingWiths] = await Promise.all([
      withFallback(countUsers(), 0),
      withFallback(sumDeposits({ status: 'approved' }), 0),
      withFallback(sumWithdrawals({ status: 'approved' }), 0),
      withFallback(getDeposits({ status: 'pending' }), []),
      withFallback(getWithdrawals({ status: 'pending' }), []),
    ]);

    const flagged = await withFallback(countUsers({ is_flagged: true }), 0);
    const banned = await withFallback(countUsers({ is_banned: true }), 0);

    res.json({
      totalUsers,
      totalDepositAmount,
      totalWithdrawalAmount,
      pendingDeposits: pendingDeps.length,
      pendingWithdrawals: pendingWiths.length,
      flaggedUsers: flagged,
      bannedUsers: banned,
    });
  } catch (e) {
    console.error('[ADMIN DASHBOARD ERROR]', e.message);
    res.status(500).json({ error: e.message || 'Dashboard query failed' });
  }
});

// ============ DEPOSITS ============

router.get('/deposits', async (req, res) => {
  try {
    const where = {};
    if (req.query.status) where.status = req.query.status;
    const deposits = await withFallback(getDeposits(where), []);

    const withUsers = await Promise.all(deposits.map(async (d) => {
      let user = null;
      try { user = await getUser(d.user_id); } catch (_) {}
      return {
        id: d.id, userId: d.user_id, amount: toNum(d.amount),
        network: d.network, walletAddress: d.wallet_address, status: d.status,
        createdAt: d.created_at, expiresAt: d.expires_at, referrerId: d.referrer_id,
        user: user ? { id: user.id, username: user.username, email: user.email, isFlagged: user.is_flagged, isBanned: user.is_banned } : null,
      };
    }));

    res.json({ deposits: withUsers });
  } catch (e) {
    console.error('[ADMIN DEPOSITS ERROR]', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.post('/deposits/:id/approve', async (req, res) => {
  try {
    const d = await getDeposit(req.params.id);
    if (!d) return res.status(404).json({ error: 'Deposit not found' });
    if (d.status !== 'pending') return res.status(400).json({ error: 'Deposit not pending' });

    const user = await getUser(d.user_id).catch(() => null);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.is_banned) return res.status(400).json({ error: 'User is banned' });

    const profile = await getProfile(d.user_id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const amt = toNum(d.amount);
    await updateProfile(d.user_id, { locked_balance: toNum(profile.locked_balance) + amt });
    const approvedAt = new Date();
    const expiresAt = approvedLockExpiresAt(approvedAt);
    await updateDeposit(d.id, { status: 'approved', approved_at: approvedAt, expires_at: expiresAt });
    releaseAssignment(d.id);

    if (d.referrer_id && d.referrer_id !== d.user_id) {
      await payReferralCommission({
        referrerId: d.referrer_id,
        refereeId: d.user_id,
        depositId: d.id,
        depositAmount: amt,
        walletNetwork: d.network || 'Crypto',
      });
    }
    await updateUserRank(d.user_id);
    if (d.referrer_id) await updateUserRank(d.referrer_id);

    createNotification(d.user_id, 'Deposit Approved', 'Your deposit has been approved and credited to your tradable balance. You can now start copy trading.', 'success').catch(() => {});

    createAuditLog({
      user_id: req.user.id, target_user_id: d.user_id, action: 'deposit.approve',
      entity_type: 'deposit', entity_id: d.id,
      description: `Admin approved $${amt} deposit for user`,
      metadata: JSON.stringify({ amount: amt, userId: d.user_id }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, deposit: { id: d.id, status: 'approved' } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/deposits/:id/reject', async (req, res) => {
  try {
    const d = await getDeposit(req.params.id);
    if (!d) return res.status(404).json({ error: 'Deposit not found' });
    if (d.status !== 'pending') return res.status(400).json({ error: 'Deposit not pending' });
    await updateDeposit(d.id, { status: 'rejected' });
    releaseAssignment(d.id);

    createNotification(
      d.user_id,
      'Deposit Rejected',
      `Your $${toNum(d.amount).toFixed(2)} ${d.network || 'crypto'} deposit was not approved. Contact support if you sent payment.`,
      'warning',
    ).catch(() => {});

    createAuditLog({
      user_id: req.user.id, target_user_id: d.user_id, action: 'deposit.reject',
      entity_type: 'deposit', entity_id: d.id,
      description: `Admin rejected $${toNum(d.amount)} deposit for user`,
      metadata: JSON.stringify({ amount: toNum(d.amount), userId: d.user_id }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, deposit: { id: d.id, status: 'rejected' } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============ WITHDRAWALS ============

router.get('/withdrawals', async (req, res) => {
  try {
    const where = {};
    if (req.query.status) where.status = req.query.status;
    const withdrawals = await withFallback(getWithdrawals(where), []);

    const withUsers = await Promise.all(withdrawals.map(async (w) => {
      let user = null;
      try { user = await getUser(w.user_id); } catch (_) {}
      return {
        id: w.id, userId: w.user_id, amount: toNum(w.amount),
        network: w.network, walletAddress: w.wallet_address, status: w.status,
        createdAt: w.created_at,
        user: user ? { id: user.id, username: user.username, email: user.email, isFlagged: user.is_flagged, isBanned: user.is_banned } : null,
      };
    }));

    res.json({ withdrawals: withUsers });
  } catch (e) {
    console.error('[ADMIN WITHDRAWALS ERROR]', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.post('/withdrawals/:id/approve', async (req, res) => {
  try {
    const w = await getWithdrawal(req.params.id);
    if (!w) return res.status(404).json({ error: 'Withdrawal not found' });
    if (w.status !== 'pending') return res.status(400).json({ error: 'Withdrawal not pending' });

    const user = await getUser(w.user_id).catch(() => null);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.is_banned) return res.status(400).json({ error: 'User is banned' });
    if (user.is_flagged) return res.status(400).json({ error: 'User is flagged' });

    await updateWithdrawal(w.id, { status: 'approved', processed_at: new Date() });

    const wallet = w.wallet_address || 'your wallet';
    createNotification(
      w.user_id,
      'Withdrawal Delivered',
      `Your withdrawal of $${toNum(w.amount).toFixed(2)} has been sent to ${wallet} on ${w.network || 'crypto'}.`,
      'success',
    ).catch(() => {});

    createAuditLog({
      user_id: req.user.id, target_user_id: w.user_id, action: 'withdrawal.approve',
      entity_type: 'withdrawal', entity_id: w.id,
      description: `Admin approved $${toNum(w.amount)} withdrawal for user`,
      metadata: JSON.stringify({ amount: toNum(w.amount), userId: w.user_id }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, withdrawal: { id: w.id, status: 'approved' } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/withdrawals/:id/reject', async (req, res) => {
  try {
    const w = await getWithdrawal(req.params.id);
    if (!w) return res.status(404).json({ error: 'Withdrawal not found' });
    if (w.status !== 'pending') return res.status(400).json({ error: 'Withdrawal not pending' });

    const profile = await getProfile(w.user_id);
    if (profile) {
      await updateProfile(w.user_id, { withdrawable_balance: toNum(profile.withdrawable_balance) + toNum(w.amount) });
    }
    await updateWithdrawal(w.id, { status: 'rejected', processed_at: new Date() });

    createNotification(
      w.user_id,
      'Withdrawal Rejected',
      `Your withdrawal of $${toNum(w.amount).toFixed(2)} was rejected. The amount was returned to your withdrawable balance.`,
      'warning',
    ).catch(() => {});

    createAuditLog({
      user_id: req.user.id, target_user_id: w.user_id, action: 'withdrawal.reject',
      entity_type: 'withdrawal', entity_id: w.id,
      description: `Admin rejected $${toNum(w.amount)} withdrawal for user (refunded)`,
      metadata: JSON.stringify({ amount: toNum(w.amount), userId: w.user_id, refunded: true }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, withdrawal: { id: w.id, status: 'rejected' } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============ PROMOS ============

router.get('/promos', async (req, res) => {
  try {
    const promos = await withFallback(getAllPromoCodes(), []);
    const redemptions = await withFallback(getAllRedemptions(), []);

    const withDetails = await Promise.all(redemptions.map(async (r) => {
      let user = null;
      let promo = null;
      try { user = await getUser(r.user_id); } catch (_) {}
      try { promo = await getPromoCode(r.promo_code_id).then(p => p ? { code: p.code } : null); } catch (_) {}
      return {
        id: r.id, userId: r.user_id, username: user?.username,
        code: promo?.code, bonusAmount: toNum(r.bonus_amount), createdAt: r.created_at,
      };
    }));

    res.json({
      promos: promos.map((p) => ({
        id: p.id, code: p.code, bonusMin: toNum(p.bonus_min), bonusMax: toNum(p.bonus_max),
        expiration: p.expiration, usageLimit: p.usage_limit, usageCount: p.usage_count ?? 0,
        status: p.status, createdAt: p.created_at,
      })),
      redemptions: withDetails,
    });
  } catch (e) {
    console.error('[ADMIN PROMOS ERROR]', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.post('/promos', async (req, res) => {
  try {
    const { code, bonusMin, bonusMax, expiration, usageLimit } = req.body;
    if (!code || !String(code).trim()) return res.status(400).json({ error: 'Code required' });

    const normalizedCode = normalizePromoCode(code);
    const minReward = roundMoney(bonusMin);
    const maxReward = roundMoney(bonusMax);
    if (maxReward < minReward) {
      return res.status(400).json({ error: 'Maximum reward must be greater than or equal to minimum reward' });
    }
    if (maxReward <= 0) {
      return res.status(400).json({ error: 'Maximum reward must be greater than 0' });
    }

    const existing = await getPromoCodeByCode(normalizedCode).catch(() => null);
    if (existing) return res.status(400).json({ error: 'Code already exists' });

    const p = await createPromoCode({
      code: normalizedCode,
      bonus_min: minReward,
      bonus_max: maxReward,
      expiration: expiration ? new Date(expiration) : null,
      usage_limit: usageLimit != null ? parseInt(usageLimit, 10) : null,
      status: 'active',
    });
    createAuditLog({
      user_id: req.user.id, action: 'promo.create', entity_type: 'promo_code', entity_id: p.id,
      description: `Admin created promo code "${p.code}"`,
      metadata: JSON.stringify({ code: p.code, bonusMin: p.bonus_min, bonusMax: p.bonus_max }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.status(201).json({
      id: p.id, code: p.code, bonusMin: toNum(p.bonus_min), bonusMax: toNum(p.bonus_max),
      expiration: p.expiration, usageLimit: p.usage_limit, status: p.status,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.patch('/promos/:id', async (req, res) => {
  try {
    const promo = await getPromoCode(req.params.id);
    if (!promo) return res.status(404).json({ error: 'Promo not found' });
    const { isActive } = req.body;
    const newStatus = isActive === true ? 'active' : (isActive === false ? 'disabled' : promo.status);
    if (newStatus !== promo.status) await updatePromoCode(promo.id, { status: newStatus });

    if (newStatus !== promo.status) {
      createAuditLog({
        user_id: req.user.id, action: 'promo.toggle', entity_type: 'promo_code', entity_id: promo.id,
        description: `Admin ${newStatus === 'active' ? 'enabled' : 'disabled'} promo code "${promo.code}"`,
        metadata: JSON.stringify({ code: promo.code, status: newStatus }),
        ip_address: req.ip || req.connection.remoteAddress || '',
      }).catch(() => {});
    }

    res.json({ id: promo.id, status: newStatus });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============ USERS ============

router.get('/users', async (req, res) => {
  try {
    const { filter } = req.query;
    const where = { role: 'user' };
    if (filter === 'flagged') where.is_flagged = true;
    if (filter === 'banned') where.is_banned = true;

    const users = await withFallback(getUsersForAdmin(where), []);

    const withProfiles = await Promise.all(users.map(async (u) => {
      const profile = await getProfile(u.id).catch(() => null);
      const rank = profile ? await getRank(profile.rank_id).catch(() => null) : null;
      return {
        id: u.id, username: u.username, email: u.email,
        isFlagged: u.is_flagged, isBanned: u.is_banned, lastLoginIp: u.last_login_ip,
        profile: profile ? {
          lockedBalance: toNum(profile.locked_balance),
          withdrawableBalance: toNum(profile.withdrawable_balance),
          totalBalance: toNum(profile.locked_balance) + toNum(profile.withdrawable_balance),
          referralEarnings: toNum(profile.referral_earnings),
          rank: rank ? { id: rank.id, name: rank.name, color: rank.color, copyTradesLimit: rank.copy_trades_limit } : null,
        } : null,
        createdAt: u.created_at,
      };
    }));

    res.json({ users: withProfiles });
  } catch (e) {
    console.error('[ADMIN USERS ERROR]', e.message);
    res.status(500).json({ error: e.message });
  }
});

router.put('/users/:id', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    const { username, email } = req.body;
    const updates = {};
    if (username) updates.username = username;
    if (email !== undefined) updates.email = email;
    if (Object.keys(updates).length) await updateUser(u.id, updates);
    res.json({ ok: true, user: { id: u.id, username: updates.username || u.username, email: updates.email ?? u.email } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/flag', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    if (u.role === 'admin') return res.status(403).json({ error: 'Cannot flag admin' });
    await updateUser(u.id, { is_flagged: true });
    await createNotification(u.id, 'Account Flagged', 'Your account has been flagged for review. If you believe this is an error, please contact support.', 'warning');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.flag',
      entity_type: 'user', entity_id: u.id,
      description: `Admin flagged user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isFlagged: true } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/unflag', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    await updateUser(u.id, { is_flagged: false });
    await createNotification(u.id, 'Flag Removed', 'The flag on your account has been removed. You may continue using all platform features.', 'success');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.unflag',
      entity_type: 'user', entity_id: u.id,
      description: `Admin removed flag for user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isFlagged: false } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/ban', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    if (u.role === 'admin') return res.status(403).json({ error: 'Cannot ban admin' });
    await updateUser(u.id, { is_banned: true, is_flagged: true });
    await createNotification(u.id, 'Account Banned', 'Your account has been suspended for violating our Terms of Service. Please contact support for more information.', 'urgent');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.ban',
      entity_type: 'user', entity_id: u.id,
      description: `Admin banned user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isBanned: true } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/unban', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    await updateUser(u.id, { is_banned: false });
    await createNotification(u.id, 'Account Reinstated', 'Your account has been reinstated. You may now log in and use all platform features.', 'success');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.unban',
      entity_type: 'user', entity_id: u.id,
      description: `Admin unbanned user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isBanned: false } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/suspend', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    await updateUser(u.id, { is_banned: true });
    await createNotification(u.id, 'Account Suspended', 'Your account has been suspended. Please contact support for further information.', 'urgent');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.suspend',
      entity_type: 'user', entity_id: u.id,
      description: `Admin suspended user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isBanned: true } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/users/:id/activate', async (req, res) => {
  try {
    const u = await getUser(req.params.id).catch(() => null);
    if (!u) return res.status(404).json({ error: 'User not found' });
    await updateUser(u.id, { is_banned: false, is_flagged: false });
    await createNotification(u.id, 'Account Activated', 'Your account has been fully activated. All restrictions have been removed.', 'success');

    createAuditLog({
      user_id: req.user.id, target_user_id: u.id, action: 'user.activate',
      entity_type: 'user', entity_id: u.id,
      description: `Admin activated user "${u.username}"`,
      metadata: JSON.stringify({ targetUserId: u.id, targetUsername: u.username }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ ok: true, user: { id: u.id, isBanned: false, isFlagged: false } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Transactions
router.post('/transactions', async (req, res) => {
  try {
    const { user_id, type, amount, description } = req.body;
    if (!user_id || !type || amount == null) {
      return res.status(400).json({ error: 'user_id, type, and amount required' });
    }
    const tx = await createTransaction({
      user_id, type, amount: parseFloat(amount), description,
      status: 'completed', processed_at: new Date(),
    });
    res.status(201).json(tx);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/users/:id/transactions', async (req, res) => {
  try {
    const data = await getTransactions({ user_id: req.params.id });
    res.json({ transactions: data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Send notification to users
router.post('/send-notification', async (req, res) => {
  try {
    const { title, message, type, sendType, targetUsers } = req.body;
    if (!title || !message) return res.status(400).json({ error: 'Title and message are required' });

    const notificationType = type || 'info';
    let sent = 0;
    const notFound = [];

    if (sendType === 'targeted') {
      if (!targetUsers || !targetUsers.length) return res.status(400).json({ error: 'Target users required for targeted send' });
      for (const target of targetUsers) {
        const trimmed = target.trim();
        const u = await getUserByUsernameInsensitive(trimmed).catch(() => null)
                 || await getUserBy('email', trimmed).catch(() => null);
        if (u) {
          await createNotification(u.id, title, message, notificationType);
          sent++;
        } else {
          notFound.push(trimmed);
        }
      }
    } else {
      const users = await getUsers({ is_banned: false });
      if (!users.length) {
        return res.status(400).json({ error: 'No active users found to receive notification' });
      }
      for (const u of users) {
        await createNotification(u.id, title, message, notificationType);
        sent++;
      }
    }

    createAuditLog({
      user_id: req.user.id, action: 'notification.send',
      description: `Admin sent notification "${title}" to ${sent} user(s)`,
      metadata: JSON.stringify({ title, sendType, sentCount: sent, notFound: notFound.length }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({
      ok: true,
      sent,
      notFound: notFound.length ? notFound : undefined,
      message: `Notification sent to ${sent} user(s)${notFound.length ? `. ${notFound.length} not found: ${notFound.join(', ')}` : ''}`,
      news: { title, message, category: 'Platform Update' },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
