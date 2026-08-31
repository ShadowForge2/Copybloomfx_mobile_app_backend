/**
 * Deposit lifecycle:
 * - Crypto pending: stays pending until admin approves/rejects. If the wallet
 *   payment window lapses without the user confirming payment, the deposit is
 *   kept pending but flagged as timed out (reference='timeout') so the admin
 *   can still approve a late real payment. If the user taps "I have made
 *   payment", it is flagged ready (reference='paid').
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

export const WALLET_ASSIGNMENT_MINUTES = 10;
export const LOCK_DAYS = 30;

export const WALLET_ASSIGNMENT_MS = WALLET_ASSIGNMENT_MINUTES * 60 * 1000;

/** UI-only: in-memory wallet pool TTL (wallets.js). Not deposit status. */
export function walletAssignmentExpiresAt(createdAt = new Date()) {
  return addMinutes(new Date(createdAt), WALLET_ASSIGNMENT_MINUTES);
}

export function approvedLockExpiresAt(approvedAt = new Date()) {
  return addDays(new Date(approvedAt), LOCK_DAYS);
}

const MAXELPAY_PENDING_MINUTES = 15; /** auto-reject MaxelPay pending after 15 min — user has 15 min to complete payment */

/**
 * Payment-status flags stored in the deposit `reference` column (only for
 * crypto pending deposits — Paystack/MaxelPay/Card use it for real refs).
 */
export const PAYMENT_CONFIRMED = 'paid';
export const PAYMENT_TIMEOUT = 'timeout';

/** Is the user past the wallet payment window without confirming payment? */
export function isCryptoWalletExpired(deposit, now = new Date()) {
  if (deposit.status !== 'pending') return false;
  if (deposit.network === 'MaxelPay') return false; // own 15-min window below
  if (!deposit.created_at) return false;
  return walletAssignmentExpiresAt(deposit.created_at) < now;
}

export function isPaymentConfirmed(deposit) {
  return deposit.reference === PAYMENT_CONFIRMED;
}

/**
 * The wallet payment window lapsed and the user never confirmed payment.
 * The deposit STAYS pending (so the admin can still approve a late real
 * payment) but is flagged as timed out so the admin sees it clearly.
 * Never downgrades a deposit the user already flagged as paid.
 */
export async function markCryptoWalletTimeout(deposit) {
  if (!isCryptoWalletExpired(deposit)) return false;
  if (isPaymentConfirmed(deposit) || deposit.reference === PAYMENT_TIMEOUT) return false;
  const updated = await updateDepositIfStatus(deposit.id, 'pending', { reference: PAYMENT_TIMEOUT }).catch(() => null);
  return !!updated;
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
  let rejectedCount = 0;
  let expiredCount = 0;
  for (const d of deposits) {
    if (d.status === 'approved' && isApprovedLockExpired(d, now)) {
      if (await expireApprovedDeposit(d, { ip, reason: 'user_refresh' })) approvedCount++;
    }
    // Auto-reject MaxelPay pending deposits older than 15 min (webhook didn't arrive)
    if (d.status === 'pending' && d.network === 'MaxelPay' && d.created_at) {
      const ageMs = now.getTime() - new Date(d.created_at).getTime();
      if (ageMs > MAXELPAY_PENDING_MINUTES * 60 * 1000) {
        await updateDepositIfStatus(d.id, 'pending', { status: 'rejected' }).catch(() => {});
        rejectedCount++;
      }
    }
    // Crypto pending: wallet payment window lapsed → flag as timed out (user's
    // fault) but keep pending so the admin can still approve a late payment.
    if (isCryptoWalletExpired(d, now) && !isPaymentConfirmed(d)) {
      expiredCount++;
    }
    await markCryptoWalletTimeout(d);
  }
  return { pendingCount: 0, approvedCount, rejectedCount, expiredCount };
}

/** Flag any crypto pending deposit whose wallet payment window lapsed (admin/global pass). */
export async function processAllCryptoWalletExpiry() {
  const pending = await getDeposits({ status: 'pending' }).catch(() => []);
  const now = new Date();
  let expiredCount = 0;
  for (const d of pending) {
    if (isCryptoWalletExpired(d, now) && !isPaymentConfirmed(d)) {
      expiredCount++;
    }
    await markCryptoWalletTimeout(d);
  }
  return expiredCount;
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
