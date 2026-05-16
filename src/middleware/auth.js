import jwt from 'jsonwebtoken';
import { getUser } from '../config/data.js';

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('FATAL: JWT_SECRET environment variable is not set');
  process.exit(1);
}

export function signToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role, username: user.username },
    JWT_SECRET,
    { expiresIn: '7d' }
  );
}

export async function authMiddleware(req, res, next) {
  try {
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'No token provided' });
    }
    const token = header.split(' ')[1];

    // Dev-only bypass: only accepted when USE_SQLITE=true AND NODE_ENV !== 'production'
    if (process.env.NODE_ENV !== 'production' && process.env.USE_SQLITE === 'true' && token === 'admin_demo_token') {
      console.warn('[AUTH] WARNING: admin_demo_token used — dev only, should not appear in production');
      req.user = { id: 'admin', username: 'admin', email: 'admin@bloomfx.com', role: 'admin', is_flagged: false, is_banned: false };
      return next();
    }

    const decoded = jwt.verify(token, JWT_SECRET);

    let user;
    if (decoded.role === 'admin') {
      user = { id: decoded.id, username: decoded.username, email: decoded.email || '', role: 'admin', is_flagged: false, is_banned: false };
    } else {
      user = await getUser(decoded.id);
      if (!user) return res.status(401).json({ error: 'User not found' });
    }
    if (user.is_banned) return res.status(403).json({ error: 'Account banned' });

    req.user = user;
    next();
  } catch (e) {
    if (e.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}

export function adminOnly(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin only' });
  }
  next();
}
