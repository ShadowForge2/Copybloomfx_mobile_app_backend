export function toNum(v) {
  const n = parseFloat(v);
  return isNaN(n) ? 0 : n;
}

export function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

export function isSameDay(d1, d2) {
  if (!d1 || !d2) return false;
  return d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate();
}

// Midnight West African Time (WAT = UTC+1) as UTC Date
export function getMidnightWAT() {
  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  const watOffset = 60 * 60000; // WAT is UTC+1 = +60 minutes
  const nowWAT = new Date(utc + watOffset);
  const todayWAT = new Date(Date.UTC(nowWAT.getUTCFullYear(), nowWAT.getUTCMonth(), nowWAT.getUTCDate()));
  return new Date(todayWAT.getTime() - watOffset);
}
