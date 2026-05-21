/**
 * JWT / session auth middleware (stub — integrate with your existing auth).
 * Assumes req.user = { id, rank } after verification.
 */
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-prod';

function authMiddleware(req, res, next) {
  // For development, inject a test user when no token is present.
  if (process.env.NODE_ENV === 'development' && !req.headers.authorization) {
    req.user = { id: 'dev_user_123', rank: 3 };
    return next();
  }

  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ success: false, error: 'Missing or invalid token' });
  }

  try {
    const token = header.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch {
    return res.status(401).json({ success: false, error: 'Token invalid or expired' });
  }
}

module.exports = authMiddleware;
