import { Router } from 'express';
import {
  db, getUser, getUserBy, getProfile, updateProfile, getRank, getAllRanks,
  getDeposit, getDeposits, createDeposit,
  getWithdrawals, createWithdrawal,
  getCopyTrades, countCopyTrades, createCopyTrade,
  getLastDailyReward, createDailyReward,
  getPromoCodeByCode, getPromoRedemption, createPromoRedemption,
  incrementPromoUsageIfBelowLimit, decrementPromoUsage,
  getNotifications, markNotificationsRead, markNotificationRead,
  getProfileByReferralCode, getProfilesByReferredBy, getReferrals,
  createNotification, createAuditLog,
} from '../config/data.js';
import { authMiddleware } from '../middleware/auth.js';
import { toNum, isSameDay, getMidnightWAT, normalizePromoCode, randomPromoBonus } from '../utils/helpers.js';
import {
  walletAssignmentExpiresAt,
  approvedLockExpiresAt,
  processUserDepositsExpiry,
  resolveReferrerUserId,
} from '../services/depositExpiry.js';
import { NETWORKS, assignWallet, getAssignment, releaseAssignment } from '../utils/wallets.js';
import { paystackInit, paystackVerify, convertNGNtoUSD } from '../utils/paystack.js';
import { payReferralCommission } from '../services/referralCommission.js';

const router = Router();
router.use(authMiddleware);

const MIN_DEPOSIT = 7;
const MIN_WITHDRAWAL = 10;
const DAILY_REWARD_AMOUNT = 0.1;
const PAIRS = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'BNB/USDT', 'XRP/USDT', 'DOGE/USDT', 'ADA/USDT', 'AVAX/USDT'];

function refereeHasApprovedDeposit(deposits) {
  return deposits.some((d) => d.status === 'approved' && d.network !== 'Referral Bonus');
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
    profilePicture: p?.profile_picture || null,
    lastDailyRewardAt: p?.last_daily_reward_at || null,
    lastDailyProfitAt: p?.last_daily_profit_at || null,
    rank: rank ? {
      id: rank.id, name: rank.name,
      minBalance: toNum(rank.min_balance), maxBalance: rankMax(rank),
      dailyProfitPct: toNum(rank.daily_profit_pct),
      copyTradesLimit: rank.copy_trades_limit, color: rank.color,
    } : null,
  };
}

router.get('/me', async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    res.json({
      user: { id: req.user.id, username: req.user.username, email: req.user.email, role: req.user.role, isFlagged: req.user.is_flagged, isBanned: req.user.is_banned },
      profile: profileToJson(profile, rank),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.put('/profile', async (req, res) => {
  try {
    const { profilePicture, email } = req.body;
    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });
    const updates = {};
    if (profilePicture != null) updates.profile_picture = String(profilePicture).slice(0, 100000);
    if (Object.keys(updates).length) await updateProfile(req.user.id, updates);
    if (email != null && email.trim()) await updateProfile(req.user.id, { email: email.trim() });
    const updated = await getProfile(req.user.id);
    const rank = updated ? await getRank(updated.rank_id) : null;
    res.json({ profile: profileToJson(updated, rank), user: { id: req.user.id, username: req.user.username, email: req.user.email } });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/dashboard', async (req, res) => {
  try {
    await updateUserRank(req.user.id);
    await processUserDepositsExpiry(
      req.user.id,
      req.ip || req.connection.remoteAddress || '',
    );
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    const limit = rank?.copy_trades_limit ?? 1;

    const [trades, pendingDepositsList, lastReward, ranks] = await Promise.all([
      getCopyTrades(req.user.id, Math.max(limit, 20)),
      getDeposits({ user_id: req.user.id, status: 'pending' }),
      getLastDailyReward(req.user.id),
      getAllRanks(),
    ]);

    const canClaimDaily = !lastReward || !isSameDay(new Date(lastReward.claimed_at), new Date());
    const total = toNum(profile?.locked_balance) + toNum(profile?.withdrawable_balance);
    let currentRankId = null;
    if (total > 0) {
      for (const r of ranks) {
        if (total >= toNum(r.min_balance)) {
          if (r.max_balance === null || total <= toNum(r.max_balance)) {
            currentRankId = r.id;
            break;
          }
        }
      }
    }

    res.json({
      profile: profileToJson(profile, rank),
      copyTrades: trades.map((t) => ({ id: t.id, pair: t.pair, action: t.action, amount: toNum(t.amount), profit: toNum(t.profit), status: t.status, createdAt: t.created_at })),
      copyTradesLimit: limit,
      pendingDeposits: pendingDepositsList.map((d) => ({
        id: d.id, amount: toNum(d.amount), network: d.network,
        walletAddress: d.wallet_address, status: d.status,
        createdAt: d.created_at, expiresAt: d.expires_at,
      })),
      canClaimDaily, dailyRewardAmount: DAILY_REWARD_AMOUNT,
      ranks: ranks.map((r) => ({ id: r.id, name: r.name, minBalance: toNum(r.min_balance), maxBalance: rankMax(r), dailyProfitPct: toNum(r.daily_profit_pct), copyTradesLimit: r.copy_trades_limit, color: r.color, isCurrent: r.id === currentRankId })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/daily-reward', async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const last = await getLastDailyReward(req.user.id);
    if (last && new Date(last.claimed_at) >= getMidnightWAT()) {
      return res.status(400).json({ error: 'Already claimed today — resets at 12AM WAT' });
    }

    const add = DAILY_REWARD_AMOUNT;
    await updateProfile(req.user.id, {
      withdrawable_balance: toNum(profile.withdrawable_balance) + add,
      last_daily_reward_at: new Date(),
    });
    await createDailyReward({ user_id: req.user.id, amount: add, claimed_at: new Date() });
    await updateUserRank(req.user.id);

    createAuditLog({
      user_id: req.user.id, action: 'daily_reward.claim',
      description: `User claimed $${add} daily reward`,
      metadata: JSON.stringify({ amount: add }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    const updated = await getProfile(req.user.id);
    const rank = updated ? await getRank(updated.rank_id) : null;
    res.json({ ok: true, amount: add, profile: profileToJson(updated, rank) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/finance', async (req, res) => {
  try {
    await processUserDepositsExpiry(
      req.user.id,
      req.ip || req.connection.remoteAddress || '',
    );
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;

    const [deposits, withdrawals] = await Promise.all([
      getDeposits({ user_id: req.user.id }),
      getWithdrawals({ user_id: req.user.id }),
    ]);

    const totalDeposits = deposits.filter((d) => d.status === 'approved').reduce((s, d) => s + toNum(d.amount), 0);
    const pendingDeposits = deposits.filter((d) => d.status === 'pending').reduce((s, d) => s + toNum(d.amount), 0);
    const totalWithdrawals = withdrawals.filter((w) => w.status === 'approved').reduce((s, w) => s + toNum(w.amount), 0);
    const referralBonus = toNum(profile?.referral_earnings) ?? 0;

    const { data: dailyRows } = await db.from('daily_rewards').select('amount').eq('user_id', req.user.id);
    const dailyRewards = (dailyRows || []).reduce((s, r) => s + toNum(r.amount), 0);

    res.json({
      profile: profileToJson(profile, rank),
      overview: { totalDeposits, pendingDeposits, totalWithdrawals, referralBonuses: referralBonus, dailyRewards },
      deposits: deposits.map((d) => ({ id: d.id, amount: toNum(d.amount), network: d.network, walletAddress: d.wallet_address, status: d.status, createdAt: d.created_at, expiresAt: d.expires_at })),
      withdrawals: withdrawals.map((w) => ({ id: w.id, amount: toNum(w.amount), network: w.network, walletAddress: w.wallet_address, status: w.status, createdAt: w.created_at })),
      networks: NETWORKS, minDeposit: MIN_DEPOSIT, minWithdrawal: MIN_WITHDRAWAL,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/deposits', async (req, res) => {
  try {
    const { amount, network, referrerCode } = req.body;
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt < MIN_DEPOSIT) return res.status(400).json({ error: `Minimum deposit $${MIN_DEPOSIT}` });
    if (!NETWORKS.includes(network)) return res.status(400).json({ error: 'Invalid network' });

    const wallet = assignWallet(network, null);
    if (!wallet) return res.status(500).json({ error: 'No wallet available for this network' });

    let referrerId = null;
    if (referrerCode) {
      const refProfile = await getProfileByReferralCode(referrerCode.trim());
      if (refProfile && refProfile.user_id !== req.user.id) referrerId = refProfile.user_id;
    }
    if (!referrerId) {
      const profile = await getProfile(req.user.id);
      if (profile && profile.referred_by) referrerId = profile.referred_by;
    }

    const createdAt = new Date();
    const d = await createDeposit({
      user_id: req.user.id, amount: amt, network,
      wallet_address: wallet,
      expires_at: null,
      referrer_id: referrerId,
    });
    assignWallet(network, d.id);

    createNotification(req.user.id, 'Deposit Pending', 'Your deposit is currently being reviewed and will be credited to your tradable balance once approved.', 'info').catch(() => {});

    createAuditLog({
      user_id: req.user.id, action: 'deposit.create', entity_type: 'deposit', entity_id: d.id,
      description: `User created $${amt} deposit on ${network}`,
      metadata: JSON.stringify({ amount: amt, network }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    const walletExpiresAt = walletAssignmentExpiresAt(createdAt);
    res.status(201).json({
      id: d.id, amount: amt, network, walletAddress: wallet, status: 'pending',
      createdAt: d.created_at,
      expiresAt: null,
      walletExpiresAt,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/withdrawals', async (req, res) => {
  try {
    if (req.user.is_flagged) return res.status(403).json({ error: 'Withdrawals disabled for flagged accounts' });
    const { amount, network, walletAddress } = req.body;
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt < MIN_WITHDRAWAL) return res.status(400).json({ error: `Minimum withdrawal $${MIN_WITHDRAWAL}` });
    if (!NETWORKS.includes(network)) return res.status(400).json({ error: 'Invalid network' });

    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });
    if (amt > toNum(profile.withdrawable_balance)) return res.status(400).json({ error: 'Insufficient withdrawable balance' });

    const deposits = await getDeposits({ user_id: req.user.id, status: 'approved' });
    if (deposits.length === 0) {
      return res.status(400).json({ error: 'At least one approved deposit required to withdraw' });
    }

    const withdrawals = await getWithdrawals({ user_id: req.user.id });
    const last = withdrawals[0];
    if (last && last.created_at && Date.now() - new Date(last.created_at).getTime() < 86400000) {
      return res.status(400).json({ error: 'One withdrawal per 24 hours' });
    }

    await updateProfile(req.user.id, {
      withdrawable_balance: toNum(profile.withdrawable_balance) - amt,
      last_withdrawal_at: new Date(),
    });
    await updateUserRank(req.user.id);
    const w = await createWithdrawal({ user_id: req.user.id, amount: amt, network, wallet_address: walletAddress || '' });

    createNotification(
      req.user.id,
      'Withdrawal Submitted',
      `Your withdrawal of $${amt.toFixed(2)} to ${network} is pending admin payout. Funds were reserved from your withdrawable balance.`,
      'info',
    ).catch(() => {});

    createAuditLog({
      user_id: req.user.id, action: 'withdrawal.create', entity_type: 'withdrawal', entity_id: w.id,
      description: `User created $${amt} withdrawal on ${network}`,
      metadata: JSON.stringify({ amount: amt, network, walletAddress }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.status(201).json({ id: w.id, amount: amt, network, walletAddress: w.wallet_address, status: 'pending', createdAt: w.created_at });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/copy-trades', async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    const limit = Math.max(rank?.copy_trades_limit ?? 1, 20);
    const trades = await getCopyTrades(req.user.id, limit);
    res.json({
      copyTrades: trades.map((t) => ({ id: t.id, pair: t.pair, action: t.action, amount: toNum(t.amount), profit: toNum(t.profit), status: t.status, createdAt: t.created_at })),
      copyTradesLimit: rank?.copy_trades_limit ?? 1,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/copy-trades/simulate', async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    if (toNum(profile.locked_balance) <= 0) {
      return res.status(400).json({ error: 'Locked balance required for copy trading' });
    }

    const rank = await getRank(profile.rank_id);
    const limit = rank?.copy_trades_limit ?? 1;

    const existing = await countCopyTrades(req.user.id);
    if (existing >= limit) return res.status(400).json({ error: 'Copy trade limit reached for rank — resets at 12AM WAT' });

    const total = toNum(profile.locked_balance) + toNum(profile.withdrawable_balance);
    let lotSize;
    if (total < 100) lotSize = +(0.01 + Math.random() * 0.49).toFixed(2);
    else if (total < 500) lotSize = +(0.5 + Math.random() * 1.5).toFixed(2);
    else if (total < 2000) lotSize = +(2 + Math.random() * 3).toFixed(2);
    else lotSize = +(5 + Math.random() * 5).toFixed(2);
    lotSize = Math.min(lotSize, 10);

    const pair = PAIRS[Math.floor(Math.random() * PAIRS.length)];
    const action = Math.random() > 0.5 ? 'buy' : 'sell';
    const pctReturn = (Math.random() * 13 - 5) / 100;
    const profit = Math.round(lotSize * pctReturn * 100) / 100;

    const trade = await createCopyTrade({ user_id: req.user.id, pair, action, amount: lotSize, profit, status: 'completed' });

    createAuditLog({
      user_id: req.user.id, action: 'copy_trade.simulate', entity_type: 'copy_trade', entity_id: trade.id,
      description: `User simulated ${action} ${pair} trade`,
      metadata: JSON.stringify({ pair, action, amount: lotSize, profit }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    const dailyPct = toNum(rank?.daily_profit_pct) / 100 || 0.02;
    const dailyProfit = total * dailyPct;
    await updateProfile(req.user.id, {
      withdrawable_balance: toNum(profile.withdrawable_balance) + dailyProfit + Math.max(profit, 0),
    });
    const newRank = await updateUserRank(req.user.id);

    res.status(201).json({
      copyTrade: { id: 'simulated', pair, action, amount: lotSize, profit, status: 'completed', createdAt: new Date() },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/promo/redeem', async (req, res) => {
  try {
    const { code } = req.body;
    if (!code || !String(code).trim()) return res.status(400).json({ error: 'Code required' });

    const promo = await getPromoCodeByCode(normalizePromoCode(code));
    if (!promo) return res.status(400).json({ error: 'Invalid or expired promo code' });
    if (promo.status !== 'active') return res.status(400).json({ error: 'Promo code not active' });
    if (promo.expiration && new Date(promo.expiration) < new Date()) {
      return res.status(400).json({ error: 'Promo code expired' });
    }

    const usageCount = promo.usage_count || 0;
    if (promo.usage_limit != null && usageCount >= promo.usage_limit) {
      return res.status(400).json({ error: 'Promo code usage limit reached' });
    }

    const already = await getPromoRedemption(req.user.id, promo.id);
    if (already) return res.status(400).json({ error: 'Already redeemed this promo' });

    const bonus = randomPromoBonus(promo.bonus_min, promo.bonus_max);
    const nextUsageCount = usageCount + 1;

    const reserved = await incrementPromoUsageIfBelowLimit(promo.id, usageCount, promo.usage_limit);
    if (!reserved) {
      return res.status(400).json({ error: 'Promo code usage limit reached' });
    }

    let redemption;
    try {
      redemption = await createPromoRedemption({
        user_id: req.user.id,
        promo_code_id: promo.id,
        bonus_amount: bonus,
      });
    } catch (insertErr) {
      await decrementPromoUsage(promo.id, nextUsageCount);
      const msg = String(insertErr?.message ?? '').toLowerCase();
      if (insertErr?.code === '23505' || msg.includes('duplicate') || msg.includes('unique')) {
        return res.status(400).json({ error: 'Already redeemed this promo' });
      }
      throw insertErr;
    }

    const profile = await getProfile(req.user.id);
    if (!profile) {
      return res.status(404).json({ error: 'Profile not found' });
    }

    await updateProfile(req.user.id, { locked_balance: toNum(profile.locked_balance) + bonus });
    const promoApprovedAt = new Date();
    await createDeposit({
      user_id: req.user.id,
      amount: bonus,
      network: 'Promo Bonus',
      wallet_address: 'Promo',
      status: 'approved',
      approved_at: promoApprovedAt,
      expires_at: approvedLockExpiresAt(promoApprovedAt),
    });
    await updateUserRank(req.user.id);

    createAuditLog({
      user_id: req.user.id,
      action: 'promo.redeem',
      entity_type: 'promo_redemption',
      entity_id: redemption.id,
      description: `User redeemed promo code "${promo.code}"`,
      metadata: JSON.stringify({ code: promo.code, bonus }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    const updated = await getProfile(req.user.id);
    const rank = updated ? await getRank(updated.rank_id) : null;
    res.json({ success: true, bonus, profile: profileToJson(updated, rank) });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/referral', async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    const refereeProfiles = await getProfilesByReferredBy(req.user.id);

    const referrals = await Promise.all(refereeProfiles.map(async (p) => {
      const referee = await getUser(p.user_id).catch(() => null);
      const deposits = await getDeposits({ user_id: p.user_id });
      const commissionRows = await getReferrals({
        referrer_id: req.user.id,
        referee_id: p.user_id,
      });
      const totalCommission = commissionRows.reduce((s, r) => s + toNum(r.bonus_amount), 0);
      const isValid = refereeHasApprovedDeposit(deposits);
      return {
        userId: p.user_id,
        username: referee?.username ?? 'Unknown',
        joinedAt: p.created_at,
        status: isValid ? 'VALID' : 'PENDING',
        totalCommissionEarned: totalCommission,
      };
    }));

    const totalReferrals = refereeProfiles.length;
    const validReferrals = referrals.filter((r) => r.status === 'VALID').length;

    res.json({
      profile: profileToJson(profile, rank),
      referralCode: profile?.referral_code,
      referralEarnings: toNum(profile?.referral_earnings),
      totalReferrals,
      validReferrals,
      referrals,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/paystack/initialize', async (req, res) => {
  try {
    const email = req.user?.email || req.body.email || 'customer@bloomfx.com';
    const amountUSD = parseFloat(req.body.amount);
    if (isNaN(amountUSD) || amountUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: `Minimum deposit $${MIN_DEPOSIT}` });
    }
    const result = await paystackInit(email, amountUSD);
    if (!result.status) return res.status(502).json({ error: result.message || 'Paystack init failed' });
    res.status(201).json({
      reference: result.data.reference,
      authorization_url: result.data.authorization_url,
      usd_amount: amountUSD,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/paystack/verify', async (req, res) => {
  try {
    const { reference } = req.body;
    if (!reference) return res.status(400).json({ error: 'Reference required' });

    const result = await paystackVerify(reference);
    if (!result.status || result.data.status !== 'success') {
      return res.json({ status: 'failed', reference, message: 'Payment not completed' });
    }

    const amountInNGN = result.data.amount / 100;
    const amountInUSD = convertNGNtoUSD(amountInNGN);
    if (amountInUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: 'Payment amount below minimum deposit' });
    }

    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const existingDeposits = await getDeposits({ user_id: req.user.id, status: 'approved' });
    const alreadyCredited = existingDeposits.some((d) => d.network === 'Paystack' && toNum(d.amount) === amountInUSD);
    if (alreadyCredited) {
      return res.json({ status: 'already_credited', reference, message: 'Payment already processed' });
    }

    const wallet = assignWallet('USDT BEP20', null) || 'Paystack';
    const paystackApprovedAt = new Date();
    const paystackDeposit = await createDeposit({
      user_id: req.user.id, amount: amountInUSD, network: 'Paystack',
      wallet_address: wallet, status: 'approved', approved_at: paystackApprovedAt,
      expires_at: approvedLockExpiresAt(paystackApprovedAt),
    });

    await updateProfile(req.user.id, { locked_balance: toNum(profile.locked_balance) + amountInUSD });
    await updateUserRank(req.user.id);

    const referrerId = await resolveReferrerUserId(profile.referred_by);
    if (referrerId && referrerId !== req.user.id) {
      const commission = await payReferralCommission({
        referrerId,
        refereeId: req.user.id,
        depositId: paystackDeposit.id,
        depositAmount: amountInUSD,
        walletNetwork: 'Paystack',
      });
      if (commission.paid) await updateUserRank(referrerId);
    }

    createNotification(req.user.id, 'Deposit Approved', 'Your deposit has been approved and credited to your tradable balance. You can now start copy trading.', 'success').catch(() => {});

    createAuditLog({
      user_id: req.user.id, action: 'payment.paystack',
      description: `Paystack payment $${amountInUSD} verified and credited`,
      metadata: JSON.stringify({ amount: amountInUSD, reference }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ status: 'success', reference, usd_amount: amountInUSD, message: `Payment verified and credited $${amountInUSD}` });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Deposit status polling endpoint — called every 3s from Flutter deposit modal
router.get('/deposits/:id/status', async (req, res) => {
  try {
    const d = await getDeposit(req.params.id);
    if (!d) return res.status(404).json({ error: 'Deposit not found' });
    if (d.user_id !== req.user.id) return res.status(403).json({ error: 'Forbidden' });

    const walletExpiresAt = d.created_at
      ? walletAssignmentExpiresAt(d.created_at)
      : null;

    res.json({
      id: d.id,
      status: d.status,
      createdAt: d.created_at,
      expiresAt: d.expires_at,
      walletExpiresAt,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Paystack webhook callback — receives charge.success events
router.post('/paystack/callback', async (req, res) => {
  try {
    const event = req.body;
    if (!event || event.event !== 'charge.success') {
      return res.status(200).json({ status: 'ignored' });
    }

    const reference = event.data?.reference;
    if (!reference) return res.status(200).json({ status: 'ignored' });

    const result = await paystackVerify(reference);
    if (!result.status || result.data.status !== 'success') {
      return res.status(200).json({ status: 'ignored' });
    }

    const amountInNGN = result.data.amount / 100;
    const amountInUSD = convertNGNtoUSD(amountInNGN);
    if (amountInUSD < MIN_DEPOSIT) {
      return res.status(200).json({ status: 'below_minimum' });
    }

    // Find user by email from paystack data
    const email = event.data?.customer?.email;
    if (!email) return res.status(200).json({ status: 'no_email' });

    const user = await getUserBy('email', email).catch(() => null);
    if (!user) return res.status(200).json({ status: 'user_not_found' });

    const profile = await getProfile(user.id);
    if (!profile) return res.status(200).json({ status: 'no_profile' });

    const existingDeposits = await getDeposits({ user_id: user.id, status: 'approved' });
    const alreadyCredited = existingDeposits.some((d) => d.network === 'Paystack' && toNum(d.amount) === amountInUSD);
    if (alreadyCredited) {
      return res.status(200).json({ status: 'already_credited' });
    }

    const callbackApprovedAt = new Date();
    const paystackDeposit = await createDeposit({
      user_id: user.id, amount: amountInUSD, network: 'Paystack',
      wallet_address: 'Paystack', status: 'approved', approved_at: callbackApprovedAt,
      expires_at: approvedLockExpiresAt(callbackApprovedAt),
      reference,
    });

    await updateProfile(user.id, { locked_balance: toNum(profile.locked_balance) + amountInUSD });
    await updateUserRank(user.id);

    const referrerId = await resolveReferrerUserId(profile.referred_by);
    if (referrerId && referrerId !== user.id) {
      const commission = await payReferralCommission({
        referrerId,
        refereeId: user.id,
        depositId: paystackDeposit.id,
        depositAmount: amountInUSD,
        walletNetwork: 'Paystack',
      });
      if (commission.paid) await updateUserRank(referrerId);
    }

    createNotification(user.id, 'Deposit Approved', 'Your deposit has been approved and credited to your tradable balance. You can now start copy trading.', 'success').catch(() => {});

    res.status(200).json({ status: 'success', usd_amount: amountInUSD });
  } catch (e) {
    res.status(200).json({ status: 'error', message: e.message });
  }
});

router.get('/notifications', async (req, res) => {
  try {
    const notifications = await getNotifications(req.user.id);
    res.json({
      notifications: notifications.map((n) => ({
        id: n.id, title: n.title, message: n.body, body: n.body,
        notification_type: n.type || 'info',
        isRead: n.is_read, is_read: n.is_read,
        createdAt: n.created_at, created_at: n.created_at,
      })),
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/notifications/mark-read', async (req, res) => {
  try {
    const { id } = req.body || {};
    if (id) {
      await markNotificationRead(req.user.id, String(id));
    } else {
      await markNotificationsRead(req.user.id);
    }
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
