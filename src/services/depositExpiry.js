/**
 * Deposit lifecycle:
 * - Crypto pending: stays pending until admin approves/rejects (no auto-expire).
 * - Paystack: auto-approved on verify (not pending).
 * - Approved rows (crypto, promo, referral, Paystack): 30-day lock then principal consumed.
 */
import {
  getDeposit,
  getDeposits,
  updateDepositIfStatus,
  getProfile,
  updateProfile,
  getAllRanks,
  getRank,
  createAuditLog,
} from '../config/data.js';
import { toNum, addDays, addMinutes } from '../utils/helpers.js';

export const WALLET_ASSIGNMENT_MINUTES = 5;
export const LOCK_DAYS = 30;

export const WALLET_ASSIGNMENT_MS = WALLET_ASSIGNMENT_MINUTES * 60 * 1000;

/** UI-only: in-memory wallet pool TTL (wallets.js). Not deposit status. */
export function walletAssignmentExpiresAt(createdAt = new Date()) {
  return addMinutes(new Date(createdAt), WALLET_ASSIGNMENT_MINUTES);
}

export function approvedLockExpiresAt(approvedAt = new Date()) {
  return addDays(new Date(approvedAt), LOCK_DAYS);
}

/** Crypto pending deposits are never auto-expired by cron or polling. */
export function isPendingPaymentExpired() {
  return false;
}

export function isApprovedLockExpired(deposit, now = new Date()) {
  if (deposit.status !== 'approved') return false;
  if (!deposit.expires_at) return false;
  return new Date(deposit.expires_at) < now;
}

async function updateUserRank(userId) {
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

/**
 * Expire one approved deposit and reverse its principal from locked_balance.
 * Idempotent: only runs when row is still approved (atomic status check).
 */
export async function expireApprovedDeposit(deposit, { ip = 'system', reason = 'server' } = {}) {
  const fresh = await getDeposit(deposit.id).catch(() => null);
  if (!fresh || fresh.status !== 'approved') return false;
  if (!isApprovedLockExpired(fresh)) return false;

  const updated = await updateDepositIfStatus(fresh.id, 'approved', { status: 'expired' });
  if (!updated) return false;

  const amt = toNum(fresh.amount);
  const profile = await getProfile(fresh.user_id).catch(() => null);
  if (profile) {
    const locked = toNum(profile.locked_balance);
    await updateProfile(fresh.user_id, {
      locked_balance: Math.max(0, locked - amt),
    });
    await updateUserRank(fresh.user_id);
  }

  await createAuditLog({
    user_id: fresh.user_id,
    action: 'deposit.expire',
    entity_type: 'deposit',
    entity_id: fresh.id,
    description: `Deposit $${amt} expired after ${LOCK_DAYS}-day lock — principal consumed (${reason})`,
    metadata: JSON.stringify({
      amount: amt,
      network: fresh.network,
      expiredAt: fresh.expires_at,
      approvedAt: fresh.approved_at,
    }),
    ip_address: ip,
  }).catch(() => {});

  return true;
}

/** Approved deposits only (promo, referral, Paystack, admin-approved crypto). */
export async function processApprovedDepositsExpiry() {
  const approved = await getDeposits({ status: 'approved' }).catch(() => []);
  const now = new Date();
  let count = 0;
  for (const d of approved) {
    if (isApprovedLockExpired(d, now)) {
      if (await expireApprovedDeposit(d, { reason: 'cron' })) count++;
    }
  }
  return count;
}

/** Expire due approved deposits when user opens dashboard/finance. */
export async function processUserDepositsExpiry(userId, ip = '') {
  const deposits = await getDeposits({ user_id: userId }).catch(() => []);
  const now = new Date();
  let approvedCount = 0;
  for (const d of deposits) {
    if (d.status === 'approved' && isApprovedLockExpired(d, now)) {
      if (await expireApprovedDeposit(d, { ip, reason: 'user_refresh' })) approvedCount++;
    }
  }
  return { pendingCount: 0, approvedCount };
}

export async function auditUserBalanceConsistency(userId) {
  const profile = await getProfile(userId).catch(() => null);
  if (!profile) return { ok: false, reason: 'no_profile' };

  const deposits = await getDeposits({ user_id: userId }).catch(() => []);
  const now = new Date();
  const activeApproved = deposits.filter(
    (d) => d.status === 'approved' && !isApprovedLockExpired(d, now),
  );
  const sumActive = activeApproved.reduce((s, d) => s + toNum(d.amount), 0);
  const locked = toNum(profile.locked_balance);
  const expiredStillApproved = deposits.filter(
    (d) => d.status === 'approved' && isApprovedLockExpired(d, now),
  );

  const issues = [];
  if (sumActive > locked + 0.01) {
    issues.push(`active_deposits_sum_${sumActive}_exceeds_locked_${locked}`);
  }
  if (expiredStillApproved.length > 0) {
    issues.push(`${expiredStillApproved.length}_approved_past_expires_at_awaiting_cron`);
  }

  if (issues.length > 0) {
    console.warn(`[AUDIT] user=${userId} ${issues.join('; ')}`);
  }

  return {
    ok: issues.length === 0,
    locked,
    sumActiveApproved: sumActive,
    activeDepositCount: activeApproved.length,
    issues,
  };
}

export async function resolveReferrerUserId(referredBy) {
  if (!referredBy) return null;
  const byId = await getProfile(referredBy).catch(() => null);
  if (byId?.user_id) return byId.user_id;
  return referredBy;
}
