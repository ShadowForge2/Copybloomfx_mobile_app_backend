import { Router } from 'express';
import {
  db, getUser, getProfile, getRank, getAllRanks,
  updateProfile, updateUser,
  getDeposit, updateDeposit, getDeposits,
  getWithdrawal, updateWithdrawal, getWithdrawals,
  getPromoCode, getPromoCodeByCode, getAllPromoCodes, createPromoCode, updatePromoCode,
  getAllRedemptions,
  countUsers, sumDeposits, sumWithdrawals,
  getProfileByReferralCode, getUsersForAdmin,
} from '../config/supabase.js';
import { authMiddleware, adminOnly } from '../middleware/auth.js';
import { toNum, addDays } from '../utils/helpers.js';

const router = Router();
router.use(authMiddleware);
router.use(adminOnly);

const REFERRAL_PCT = 0.08;
const LOCK_DAYS = 30;

function profileToJson(p, rank) {
  return {
    lockedBalance: toNum(p?.locked_balance),
    withdrawableBalance: toNum(p?.withdrawable_balance),
    totalBalance: toNum(p?.locked_balance) + toNum(p?.withdrawable_balance),
    referralCode: p?.referral_code,
    totalReferrals: p?.total_referrals ?? 0,
    validReferrals: p?.valid_referrals ?? 0,
    referralEarnings: toNum(p?.referral_earnings),
    rank: rank ? { id: rank.id, name: rank.name, color: rank.color, copyTradesLimit: rank.copy_trades_limit } : null,
  };
}

async function updateUserRank(userId) {
  const profile = await getProfile(userId);
  if (!profile) return null;
  const total = toNum(profile.locked_balance) + toNum(profile.withdrawable_balance);
  const ranks = await getAllRanks();
  let newRankId = profile.rank_id;
  for (const r of ranks) {
    if (total >= toNum(r.min_balance) && total <= toNum(r.max_balance)) { newRankId = r.id; break; }
    if (total >= toNum(r.min_balance)) newRankId = r.id;
  }
  if (newRankId !== profile.rank_id) await updateProfile(userId, { rank_id: newRankId });
  return getRank(newRankId);
}

// ============ DASHBOARD ============

router.get('/dashboard', async (req, res) => {
  try {
    const [totalUsers, totalDeposits, totalWithdrawals, pendingDeposits, pendingWithdrawals] = await Promise.all([
      countUsers(),
      sumDeposits({ status: 'approved' }),
      sumWithdrawals({ status: 'approved' }),
      countUsers(), // placeholder - real pending deposit count below
      countUsers(), // placeholder
    ]);

    // actual pending counts
    const pendingDeps = await getDeposits({ status: 'pending' });
    const pendingWiths = await getWithdrawals({ status: 'pending' });

    res.json({
      totalUsers, totalDeposits, totalWithdrawals,
      pendingDeposits: pendingDeps.length,
      pendingWithdrawals: pendingWiths.length,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============ DEPOSITS ============

router.get('/deposits', async (req, res) => {
  try {
    const where = {};
    if (req.query.status) where.status = req.query.status;
    const deposits = await getDeposits(where);

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
    const expiresAt = d.expires_at || addDays(new Date(), LOCK_DAYS);
    await updateDeposit(d.id, { status: 'approved', approved_at: new Date(), expires_at: expiresAt });

    if (d.referrer_id && d.referrer_id !== d.user_id) {
      const bonus = amt * REFERRAL_PCT;
      const refProfile = await getProfile(d.referrer_id);
      if (refProfile) {
        await updateProfile(d.referrer_id, {
          locked_balance: toNum(refProfile.locked_balance) + bonus,
          total_referrals: (refProfile.total_referrals || 0) + 1,
          valid_referrals: (refProfile.valid_referrals || 0) + 1,
          referral_earnings: toNum(refProfile.referral_earnings) + bonus,
        });
        await db.from('referrals').insert({
          referrer_id: d.referrer_id, referee_id: d.user_id,
          bonus_amount: bonus, deposit_id: d.id,
        }).then();
      }
    }
    await updateUserRank(d.user_id);
    if (d.referrer_id) await updateUserRank(d.referrer_id);

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
    const withdrawals = await getWithdrawals(where);

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
    res.json({ ok: true, withdrawal: { id: w.id, status: 'rejected' } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ============ PROMOS ============

router.get('/promos', async (req, res) => {
  try {
    const promos = await getAllPromoCodes();
    const redemptions = await getAllRedemptions();

    const withDetails = await Promise.all(redemptions.map(async (r) => {
      let user = null;
      let promo = null;
      try { user = await getUser(r.user_id); } catch (_) {}
      try { promo = await db.from('promo_codes').select('code').eq('id', r.promo_code_id).single().then(d => d.data); } catch (_) {}
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
    res.status(500).json({ error: e.message });
  }
});

router.post('/promos', async (req, res) => {
  try {
    const { code, bonusMin, bonusMax, expiration, usageLimit } = req.body;
    if (!code || !String(code).trim()) return res.status(400).json({ error: 'Code required' });

    const existing = await getPromoCodeByCode(String(code).trim()).catch(() => null);
    if (existing) return res.status(400).json({ error: 'Code already exists' });

    const p = await createPromoCode({
      code: String(code).trim(), bonus_min: parseFloat(bonusMin) || 0, bonus_max: parseFloat(bonusMax) || 0,
      expiration: expiration ? new Date(expiration) : null,
      usage_limit: usageLimit != null ? parseInt(usageLimit, 10) : null,
      status: 'active',
    });
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

    const users = await getUsersForAdmin(where);

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
    const { data, error } = await db.from('transactions').insert({
      user_id, type, amount: parseFloat(amount), description,
      status: 'completed', processed_at: new Date(),
    }).select().single();
    if (error) return res.status(500).json({ error: error.message });
    res.status(201).json(data);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/users/:id/transactions', async (req, res) => {
  try {
    const { data, error } = await db.from('transactions').select('*')
      .eq('user_id', req.params.id).order('created_at', { ascending: false }).limit(50);
    if (error) return res.status(500).json({ error: error.message });
    res.json({ transactions: data || [] });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
