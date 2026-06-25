import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import {
  db, getUser, getUserBy, getProfile, updateProfile, getRank, getAllRanks,
  getDeposit, getDeposits, createDeposit, updateDeposit, sumDeposits,
  getWithdrawals, createWithdrawal, sumWithdrawals,
  getCopyTrades, countCopyTrades, getTodayCopyTradesSum, createCopyTrade,
  processMatureCopyTrades,
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
import { createPaymentSession, verifyWebhookSignature } from '../utils/maxelpay.js';
import { payReferralCommission } from '../services/referralCommission.js';

const router = Router();
router.use(authMiddleware);

const paymentInitLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many payment init requests. Please wait a moment.' },
});

const paymentVerifyLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many verification attempts. Please wait.' },
});

const MIN_DEPOSIT = 7;
const MIN_WITHDRAWAL = 1.5;
const DAILY_REWARD_AMOUNT = 0.1;
const PAIRS = ['BTC/USDT', 'ETH/USDT', 'SOL/USDT', 'BNB/USDT', 'XRP/USDT', 'DOGE/USDT', 'ADA/USDT', 'AVAX/USDT'];

function refereeHasApprovedDeposit(deposits) {
  return deposits.some((d) => d.status === 'approved' && d.network !== 'Referral Bonus');
}

async function updateUserRank(userId, preFetchedProfile = null, preFetchedRanks = null) {
  const profile = preFetchedProfile || await getProfile(userId);
  if (!profile) return null;
  const total = toNum(profile.locked_balance);
  if (total <= 0) {
    if (profile.rank_id !== null) {
      await updateProfile(userId, { rank_id: null });
      if (preFetchedProfile) preFetchedProfile.rank_id = null;
    }
    return null;
  }
  const ranks = preFetchedRanks || await getAllRanks();
  let newRankId = null;
  for (const r of ranks) {
    if (total >= toNum(r.min_balance)) {
      if (r.max_balance === null || total <= toNum(r.max_balance)) {
        newRankId = r.id;
        break;
      }
    }
  }
  if (newRankId !== profile.rank_id) {
    await updateProfile(userId, { rank_id: newRankId });
    if (preFetchedProfile) preFetchedProfile.rank_id = newRankId;
  }
  return newRankId ? ranks.find(r => r.id === newRankId) : null;
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
    await Promise.all([
      processUserDepositsExpiry(req.user.id, req.ip || req.connection.remoteAddress || ''),
      processMatureCopyTrades(req.user.id)
    ]);

    const [profile, ranks, lastReward, pendingDepositsList] = await Promise.all([
      getProfile(req.user.id),
      getAllRanks(),
      getLastDailyReward(req.user.id),
      getDeposits({ user_id: req.user.id, status: 'pending' })
    ]);

    await updateUserRank(req.user.id, profile, ranks);

    const rank = profile ? ranks.find(r => r.id === profile.rank_id) : null;
    const limit = rank?.copy_trades_limit ?? 1;
    const trades = await getCopyTrades(req.user.id, Math.max(limit, 20));

    const canClaimDaily = !lastReward || !isSameDay(new Date(lastReward.claimed_at), new Date());
    const currentRankId = profile ? profile.rank_id : null;

    res.json({
      profile: profileToJson(profile, rank),
      copyTrades: trades.map((t) => ({
        id: t.id,
        pair: t.pair,
        action: t.action,
        amount: toNum(t.amount),
        profit: toNum(t.profit),
        status: t.status,
        createdAt: t.created_at,
        closeAt: t.close_at,
      })),
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

    const [profile, deposits, withdrawals, totalDeposits, pendingDeposits, totalWithdrawals, dailyRows, ranks] = await Promise.all([
      getProfile(req.user.id),
      getDeposits({ user_id: req.user.id }, { limit: 100 }),
      getWithdrawals({ user_id: req.user.id }, { limit: 100 }),
      sumDeposits({ user_id: req.user.id, status: 'approved' }),
      sumDeposits({ user_id: req.user.id, status: 'pending' }),
      sumWithdrawals({ user_id: req.user.id, status: 'approved' }),
      db.from('daily_rewards').select('amount').eq('user_id', req.user.id),
      getAllRanks(),
    ]);

    const rank = profile ? ranks.find(r => r.id === profile.rank_id) : null;
    const referralBonus = toNum(profile?.referral_earnings) ?? 0;
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

// Manual crypto wallet deposit replaced by MaxelPay (auto-approved).
// router.post('/deposits', async (req, res) => {
//   try {
//     const { amount, network, referrerCode } = req.body;
//     const amt = parseFloat(amount);
//     if (isNaN(amt) || amt < MIN_DEPOSIT) return res.status(400).json({ error: `Minimum deposit $${MIN_DEPOSIT}` });
//     if (!NETWORKS.includes(network)) return res.status(400).json({ error: 'Invalid network' });
//
//     const wallet = assignWallet(network, null);
//     if (!wallet) return res.status(500).json({ error: 'No wallet available for this network' });
//
//     const [refProfile, profile] = await Promise.all([
//       referrerCode ? getProfileByReferralCode(referrerCode.trim()) : Promise.resolve(null),
//       getProfile(req.user.id)
//     ]);
//
//     let referrerId = null;
//     if (refProfile && refProfile.user_id !== req.user.id) {
//       referrerId = refProfile.user_id;
//     } else if (profile && profile.referred_by) {
//       referrerId = profile.referred_by;
//     }
//
//     const createdAt = new Date();
//     const d = await createDeposit({
//       user_id: req.user.id, amount: amt, network,
//       wallet_address: wallet,
//       expires_at: null,
//       referrer_id: referrerId,
//     });
//     assignWallet(network, d.id);
//
//     createNotification(req.user.id, 'Deposit Pending', `Your deposit of $${amt.toFixed(2)} is currently being reviewed and will be credited to your tradable balance once approved.`, 'info').catch(() => {});
//
//     createAuditLog({
//       user_id: req.user.id, action: 'deposit.create', entity_type: 'deposit', entity_id: d.id,
//       description: `User created $${amt} deposit on ${network}`,
//       metadata: JSON.stringify({ amount: amt, network }),
//       ip_address: req.ip || req.connection.remoteAddress || '',
//     }).catch(() => {});
//
//     const walletExpiresAt = walletAssignmentExpiresAt(createdAt);
//     res.status(201).json({
//       id: d.id, amount: amt, network, walletAddress: wallet, status: 'pending',
//       createdAt: d.created_at,
//       expiresAt: null,
//       walletExpiresAt,
//     });
//   } catch (e) {
//     res.status(500).json({ error: e.message });
//   }
// });

router.post('/withdrawals', async (req, res) => {
  try {
    if (req.user.is_flagged) return res.status(403).json({ error: 'Withdrawals disabled for flagged accounts' });
    const { amount, network, walletAddress } = req.body;
    const amt = parseFloat(amount);
    if (isNaN(amt) || amt < MIN_WITHDRAWAL) return res.status(400).json({ error: `Minimum withdrawal $${MIN_WITHDRAWAL}` });
    if (!NETWORKS.includes(network)) return res.status(400).json({ error: 'Invalid network' });

    const [profile, deposits, withdrawals] = await Promise.all([
      getProfile(req.user.id),
      getDeposits({ user_id: req.user.id, status: 'approved' }, { limit: 1 }),
      getWithdrawals({ user_id: req.user.id }, { limit: 20 })
    ]);

    if (!profile) return res.status(404).json({ error: 'Profile not found' });
    if (amt > toNum(profile.withdrawable_balance)) return res.status(400).json({ error: 'Insufficient withdrawable balance' });

    if (deposits.length === 0) {
      return res.status(400).json({ error: 'At least one approved deposit required to withdraw' });
    }

    const last = withdrawals.find(w => w.status !== 'rejected');
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
    await processMatureCopyTrades(req.user.id);
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    const limit = Math.max(rank?.copy_trades_limit ?? 1, 20);
    const trades = await getCopyTrades(req.user.id, limit);
    res.json({
      copyTrades: trades.map((t) => ({
        id: t.id,
        pair: t.pair,
        action: t.action,
        amount: toNum(t.amount),
        profit: toNum(t.profit),
        status: t.status,
        createdAt: t.created_at,
        closeAt: t.close_at,
      })),
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
      return res.status(400).json({ error: 'Tradable balance required. Please make a deposit.' });
    }

    const rank = await getRank(profile.rank_id);
    const limit = rank?.copy_trades_limit ?? 1;

    const existing = await countCopyTrades(req.user.id);
    if (existing >= limit) return res.status(400).json({ error: 'Copy trade limit reached for rank — resets at 12AM WAT' });

    const total = toNum(profile.locked_balance);
    const cutoff = getMidnightWAT();
    const dateKey = cutoff.getTime();
    let flexHash = 0;
    const idStr = String(req.user.id);
    for (let i = 0; i < idStr.length; i++) {
      flexHash = ((flexHash << 5) - flexHash) + idStr.charCodeAt(i);
      flexHash |= 0;
    }
    const dailyFlex = ((Math.abs(flexHash + dateKey) % 1001) / 10000) - 0.05;
    const dailyProfit = Math.max(0, total * (toNum(rank?.daily_profit_pct) / 100) + dailyFlex);
    const basePerClick = dailyProfit / limit;
    const todayProfitSum = await getTodayCopyTradesSum(req.user.id);
    const isLastClick = existing + 1 >= limit;

    const variance = (Math.random() * 0.2) - 0.1;
    let profit = +(basePerClick + variance).toFixed(2);

    if (isLastClick) {
      const correction = +(dailyProfit - (todayProfitSum + profit)).toFixed(2);
      profit = +(profit + correction).toFixed(2);
    }

    let lotSize;
    if (total < 100) lotSize = +(0.01 + Math.random() * 0.49).toFixed(2);
    else if (total < 500) lotSize = +(0.5 + Math.random() * 1.5).toFixed(2);
    else if (total < 2000) lotSize = +(2 + Math.random() * 3).toFixed(2);
    else lotSize = +(5 + Math.random() * 5).toFixed(2);
    lotSize = Math.min(lotSize, 10);

    const pair = PAIRS[Math.floor(Math.random() * PAIRS.length)];
    const action = Math.random() > 0.5 ? 'buy' : 'sell';

    const closeAt = new Date(Date.now() + (120 + Math.floor(Math.random() * 181)) * 1000);
    const trade = await createCopyTrade({
      user_id: req.user.id,
      pair,
      action,
      amount: lotSize,
      profit,
      status: 'pending',
      close_at: closeAt,
    });

    createAuditLog({
      user_id: req.user.id, action: 'copy_trade.simulate', entity_type: 'copy_trade', entity_id: trade.id,
      description: `User simulated ${action} ${pair} trade`,
      metadata: JSON.stringify({ pair, action, amount: lotSize, profit, closeAt }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.status(201).json({
      copyTrade: { id: trade.id, pair, action, amount: lotSize, profit, status: 'pending', createdAt: trade.created_at, closeAt },
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
      return res.status(400).json({ error: 'Promo code expired' });
    }

    const already = await getPromoRedemption(req.user.id, promo.id);
    if (already) return res.status(400).json({ error: 'Already redeemed this promo' });

    const bonus = randomPromoBonus(promo.bonus_min, promo.bonus_max);
    const nextUsageCount = usageCount + 1;

    const reserved = await incrementPromoUsageIfBelowLimit(promo.id, usageCount, promo.usage_limit);
    if (!reserved) {
      return res.status(400).json({ error: 'Promo code expired' });
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

router.post('/paystack/initialize', paymentInitLimiter, async (req, res) => {
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

router.post('/paystack/verify', paymentVerifyLimiter, async (req, res) => {
  try {
    const { reference } = req.body;
    if (!reference) return res.status(400).json({ error: 'Reference required' });

    const [result, profile, existingDeposits] = await Promise.all([
      paystackVerify(reference),
      getProfile(req.user.id),
      getDeposits({ user_id: req.user.id, network: 'Paystack', reference })
    ]);

    if (!result.status || result.data.status !== 'success') {
      return res.json({ status: 'failed', reference, message: 'Payment not completed' });
    }

    const amountInNGN = result.data.amount / 100;
    const amountInUSD = convertNGNtoUSD(amountInNGN);
    if (amountInUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: 'Payment amount below minimum deposit' });
    }

    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const alreadyCredited = existingDeposits.length > 0;
    if (alreadyCredited) {
      return res.json({ status: 'already_credited', reference, message: 'Payment already processed' });
    }

    const wallet = assignWallet('USDT BEP20', null) || 'Paystack';
    const paystackApprovedAt = new Date();
    
    const [paystackDeposit] = await Promise.all([
      createDeposit({
        user_id: req.user.id, amount: amountInUSD, network: 'Paystack',
        wallet_address: wallet, status: 'approved', approved_at: paystackApprovedAt,
        expires_at: approvedLockExpiresAt(paystackApprovedAt),
        reference,
      }),
      updateProfile(req.user.id, { locked_balance: toNum(profile.locked_balance) + amountInUSD })
    ]);

    res.json({ status: 'success', reference, usd_amount: amountInUSD, message: `Payment verified and credited $${amountInUSD}` });

    Promise.resolve().then(async () => {
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

      createNotification(req.user.id, 'Deposit Approved', `Your deposit of $${amountInUSD.toFixed(2)} has been approved and credited to your tradable balance. You can now start copy trading.`, 'success').catch(() => {});

      createAuditLog({
        user_id: req.user.id, action: 'payment.paystack',
        description: `Paystack payment $${amountInUSD} verified and credited`,
        metadata: JSON.stringify({ amount: amountInUSD, reference }),
        ip_address: req.ip || req.connection.remoteAddress || '',
      }).catch(() => {});
    }).catch((err) => console.error('Background processing error in /paystack/verify:', err));
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

// --- Card Deposit (Paystack) — auto-approved, no admin needed ---

router.post('/card/initialize', paymentInitLimiter, async (req, res) => {
  try {
    const email = req.user?.email || req.body.email || 'customer@bloomfx.com';
    const amountUSD = parseFloat(req.body.amount);
    if (isNaN(amountUSD) || amountUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: `Minimum deposit $${MIN_DEPOSIT}` });
    }
    const result = await paystackInit(email, amountUSD, ['card']);
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

router.post('/card/verify', paymentVerifyLimiter, async (req, res) => {
  try {
    const { reference } = req.body;
    if (!reference) return res.status(400).json({ error: 'Reference required' });

    const [result, profile, existingDeposits] = await Promise.all([
      paystackVerify(reference),
      getProfile(req.user.id),
      getDeposits({ user_id: req.user.id, network: 'Card', reference })
    ]);

    if (!result.status || result.data.status !== 'success') {
      return res.json({ status: 'failed', reference, message: 'Payment not completed' });
    }

    const amountInNGN = result.data.amount / 100;
    const amountInUSD = convertNGNtoUSD(amountInNGN);
    if (amountInUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: 'Payment amount below minimum deposit' });
    }

    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const alreadyCredited = existingDeposits.length > 0;
    if (alreadyCredited) {
      return res.json({ status: 'already_credited', reference, message: 'Payment already processed' });
    }

    const cardApprovedAt = new Date();
    const [cardDeposit] = await Promise.all([
      createDeposit({
        user_id: req.user.id, amount: amountInUSD, network: 'Card',
        wallet_address: 'Paystack', status: 'approved', approved_at: cardApprovedAt,
        expires_at: approvedLockExpiresAt(cardApprovedAt),
        reference,
      }),
      updateProfile(req.user.id, { locked_balance: toNum(profile.locked_balance) + amountInUSD })
    ]);

    res.json({ status: 'success', reference, usd_amount: amountInUSD, message: `Card payment verified and credited $${amountInUSD}` });

    Promise.resolve().then(async () => {
      await updateUserRank(req.user.id);
      const referrerId = await resolveReferrerUserId(profile.referred_by);
      if (referrerId && referrerId !== req.user.id) {
        const commission = await payReferralCommission({
          referrerId,
          refereeId: req.user.id,
          depositId: cardDeposit.id,
          depositAmount: amountInUSD,
          walletNetwork: 'Card',
        });
        if (commission.paid) await updateUserRank(referrerId);
      }

      createNotification(req.user.id, 'Deposit Approved', `Your card deposit of $${amountInUSD.toFixed(2)} has been approved and credited to your tradable balance.`, 'success').catch(() => {});

      createAuditLog({
        user_id: req.user.id, action: 'payment.card',
        description: `Card payment $${amountInUSD} verified and credited`,
        metadata: JSON.stringify({ amount: amountInUSD, reference }),
        ip_address: req.ip || req.connection.remoteAddress || '',
      }).catch(() => {});
    }).catch((err) => console.error('Background processing error in /card/verify:', err));
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- MaxelPay Crypto Deposit — auto-approved via webhook, no admin needed ---

router.post('/maxelpay/initialize', paymentInitLimiter, async (req, res) => {
  try {
    const amountUSD = parseFloat(req.body.amount);
    if (isNaN(amountUSD) || amountUSD < MIN_DEPOSIT) {
      return res.status(400).json({ error: `Minimum deposit $${MIN_DEPOSIT}` });
    }

    const profile = await getProfile(req.user.id);
    if (!profile) return res.status(404).json({ error: 'Profile not found' });

    const orderId = `MP-${req.user.id}-${Date.now()}`;
    const callbackUrl = `${req.protocol}://${req.get('host')}/api/user/maxelpay/webhook`;
    const successUrl = `${req.protocol}://${req.get('host')}/api/user/maxelpay/success?orderId=${orderId}`;
    const cancelUrl = `${req.protocol}://${req.get('host')}/api/user/maxelpay/cancel`;

    const result = await createPaymentSession({
      orderId,
      amount: amountUSD,
      currency: 'USD',
      description: `Deposit $${amountUSD} to BloomFX`,
      callbackUrl,
      successUrl,
      cancelUrl,
      metadata: { userId: req.user.id },
    });

    if (!result.sessionId && !result.checkoutUrl && !result.url) {
      return res.status(502).json({ error: 'MaxelPay session creation failed' });
    }

    const sessionId = result.sessionId || result.id;
    const checkoutUrl = result.checkoutUrl || result.url || result.checkout_url;

    const createdAt = new Date();
    const deposit = await createDeposit({
      user_id: req.user.id, amount: amountUSD, network: 'MaxelPay',
      wallet_address: 'MaxelPay', status: 'pending',
      reference: sessionId || orderId,
    });

    createNotification(req.user.id, 'Deposit Pending', `Your MaxelPay deposit of $${amountUSD.toFixed(2)} is pending payment confirmation.`, 'info').catch(() => {});

    createAuditLog({
      user_id: req.user.id, action: 'maxelpay.initialize',
      entity_type: 'deposit', entity_id: deposit.id,
      description: `User initiated $${amountUSD} MaxelPay deposit`,
      metadata: JSON.stringify({ amount: amountUSD, orderId, sessionId }),
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.status(201).json({
      id: deposit.id,
      amount: amountUSD,
      network: 'MaxelPay',
      status: 'pending',
      checkoutUrl,
      sessionId: sessionId || orderId,
      createdAt: deposit.created_at,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// MaxelPay webhook callback — receives payment.completed / payment.failed events
router.post('/maxelpay/webhook', async (req, res) => {
  try {
    const signature = req.headers['x-maxelpay-signature'];
    if (!signature || !verifyWebhookSignature(req.body, signature)) {
      return res.status(401).json({ error: 'Invalid signature' });
    }

    const { event, data } = req.body;
    if (event !== 'payment.completed' && event !== 'payment.partial' && event !== 'payment.overpaid') {
      return res.status(200).json({ received: true, status: 'ignored' });
    }

    const orderId = data.orderId;
    if (!orderId) return res.status(200).json({ received: true, status: 'no_order_id' });

    const sessionId = data.sessionId;
    const reference = sessionId || orderId;

    const deposits = await getDeposits({ reference, network: 'MaxelPay' });
    if (!deposits.length) return res.status(200).json({ received: true, status: 'deposit_not_found' });

    const deposit = deposits[0];
    if (deposit.status !== 'pending') return res.status(200).json({ received: true, status: 'already_processed' });

    const paidAmount = data.totalPaidUsd || data.paidAmount || data.amount || toNum(deposit.amount);
    const approvedAt = new Date();

    await updateDeposit(deposit.id, {
      status: 'approved',
      approved_at: approvedAt,
      expires_at: approvedLockExpiresAt(approvedAt),
    });

    const profile = await getProfile(deposit.user_id);
    if (profile) {
      await updateProfile(deposit.user_id, {
        locked_balance: toNum(profile.locked_balance) + paidAmount,
      });
    }

    await updateUserRank(deposit.user_id);

    const referrerId = await resolveReferrerUserId(deposit.user_id);
    if (referrerId && referrerId !== deposit.user_id) {
      const commission = await payReferralCommission({
        referrerId,
        refereeId: deposit.user_id,
        depositId: deposit.id,
        depositAmount: paidAmount,
        walletNetwork: 'MaxelPay',
      });
      if (commission.paid) await updateUserRank(referrerId);
    }

    createNotification(deposit.user_id, 'Deposit Approved', `Your MaxelPay deposit of $${paidAmount.toFixed(2)} has been confirmed and credited to your tradable balance.`, 'success').catch(() => {});

    res.status(200).json({ received: true, status: 'success' });
  } catch (e) {
    console.error('MaxelPay webhook error:', e);
    res.status(200).json({ received: true, status: 'error', message: e.message });
  }
});

// MaxelPay success redirect landing — updates deposit if webhook hasn't arrived yet
router.get('/maxelpay/success', async (req, res) => {
  const { orderId } = req.query;
  if (orderId) {
    const deposits = await getDeposits({ reference: orderId, network: 'MaxelPay' }).catch(() => []);
    if (deposits.length && deposits[0].status === 'pending') {
      const approvedAt = new Date();
      await updateDeposit(deposits[0].id, {
        status: 'approved',
        approved_at: approvedAt,
        expires_at: approvedLockExpiresAt(approvedAt),
      }).catch(() => {});
      const profile = await getProfile(deposits[0].user_id).catch(() => null);
      if (profile) {
        await updateProfile(deposits[0].user_id, {
          locked_balance: toNum(profile.locked_balance) + toNum(deposits[0].amount),
        }).catch(() => {});
      }
    }
  }
  res.redirect(`${process.env.CORS_ORIGIN || ''}/finance?payment=success`);
});

router.get('/maxelpay/cancel', (req, res) => {
  res.redirect(`${process.env.CORS_ORIGIN || ''}/finance?payment=cancelled`);
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

    const existingDeposits = await getDeposits({ user_id: user.id, network: 'Paystack', reference });
    const alreadyCredited = existingDeposits.length > 0;
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

    createNotification(user.id, 'Deposit Approved', `Your deposit of $${amountInUSD.toFixed(2)} has been approved and credited to your tradable balance. You can now start copy trading.`, 'success').catch(() => {});

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
