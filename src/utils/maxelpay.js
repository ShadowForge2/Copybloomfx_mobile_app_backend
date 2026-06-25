import crypto from 'crypto';

const MAXELPAY_API_KEY = process.env.MAXELPAY_API_KEY || '';
const MAXELPAY_SECRET_KEY = process.env.MAXELPAY_SECRET_KEY || '';
const MAXELPAY_BASE_URL = 'https://api.maxelpay.com/api/v1';

export async function createPaymentSession({ orderId, amount, currency, description, callbackUrl, successUrl, cancelUrl, metadata }) {
  const res = await fetch(`${MAXELPAY_BASE_URL}/payments/sessions`, {
    method: 'POST',
    headers: {
      'X-API-KEY': MAXELPAY_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      orderId,
      amount,
      currency: currency || 'USD',
      description,
      successUrl: successUrl || `${process.env.CORS_ORIGIN || 'http://localhost:4000'}/payment/success`,
      cancelUrl: cancelUrl || `${process.env.CORS_ORIGIN || 'http://localhost:4000'}/payment/cancel`,
      callbackUrl,
      metadata,
    }),
  });
  return res.json();
}

export function verifyWebhookSignature(payload, signature) {
  const expectedSignature = crypto
    .createHmac('sha256', MAXELPAY_SECRET_KEY)
    .update(JSON.stringify(payload))
    .digest('hex');
  try {
    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  } catch {
    return false;
  }
}
