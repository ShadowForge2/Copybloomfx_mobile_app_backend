const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;
const USD_TO_NGN_RATE = parseFloat(process.env.USD_TO_NGN_RATE) || 1500;

export function convertUSDtoNGN(amountUSD) {
  return Math.round(amountUSD * USD_TO_NGN_RATE);
}

export function convertNGNtoUSD(amountNGN) {
  return Math.round((amountNGN / USD_TO_NGN_RATE) * 100) / 100;
}

export async function paystackInit(email, amountUSD, channels = ['bank_transfer']) {
  const amountInNGN = convertUSDtoNGN(amountUSD);
  const amountInKobo = amountInNGN * 100;
  const res = await fetch('https://api.paystack.co/transaction/initialize', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: email || 'customer@bloomfx.com',
      amount: amountInKobo,
      channels: channels,
    }),
  });
  return res.json();
}

export async function paystackVerify(reference) {
  const res = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
    headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
  });
  return res.json();
}
