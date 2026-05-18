import {
  getProfile,
  updateProfile,
  createDeposit,
  createReferral,
  getReferralByDepositId,
  getReferrals,
} from '../config/data.js';
import { approvedLockExpiresAt } from './depositExpiry.js';
import { toNum } from '../utils/helpers.js';

export const REFERRAL_PCT = 0.08;

/**
 * Pay 8% referral commission for an approved referee deposit.
 * Idempotent per deposit_id — safe for admin approve + Paystack verify/callback retries.
 */
export async function payReferralCommission({
  referrerId,
  refereeId,
  depositId,
  depositAmount,
  walletNetwork = 'Crypto',
}) {
  if (!referrerId || !refereeId || referrerId === refereeId || !depositId) {
    return { paid: false, reason: 'invalid_args' };
  }

  const existing = await getReferralByDepositId(depositId).catch(() => null);
  if (existing) {
    return { paid: false, reason: 'duplicate_deposit', referralId: existing.id };
  }

  const amt = toNum(depositAmount);
  if (amt <= 0) return { paid: false, reason: 'zero_amount' };

  const refProfile = await getProfile(referrerId);
  if (!refProfile) return { paid: false, reason: 'referrer_not_found' };

  const priorForReferee = await getReferrals({
    referrer_id: referrerId,
    referee_id: refereeId,
  }).catch(() => []);
  const isFirstDepositFromReferee = priorForReferee.length === 0;

  const bonus = amt * REFERRAL_PCT;
  const refApprovedAt = new Date();

  const profileUpdate = {
    locked_balance: toNum(refProfile.locked_balance) + bonus,
    referral_earnings: toNum(refProfile.referral_earnings) + bonus,
  };
  if (isFirstDepositFromReferee) {
    profileUpdate.valid_referrals = (refProfile.valid_referrals || 0) + 1;
  }

  await updateProfile(referrerId, profileUpdate);

  await createDeposit({
    user_id: referrerId,
    amount: bonus,
    network: 'Referral Bonus',
    wallet_address: walletNetwork,
    status: 'approved',
    approved_at: refApprovedAt,
    expires_at: approvedLockExpiresAt(refApprovedAt),
    referrer_id: refereeId,
  });

  const referralRow = await createReferral({
    referrer_id: referrerId,
    referee_id: refereeId,
    bonus_amount: bonus,
    deposit_id: depositId,
  });

  return {
    paid: true,
    bonus,
    referralId: referralRow?.id,
    firstDepositFromReferee: isFirstDepositFromReferee,
  };
}
