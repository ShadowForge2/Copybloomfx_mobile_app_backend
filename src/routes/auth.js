import { Router } from 'express';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { getUser, getUserBy, updateUser, getProfile, createUser, createProfile, getRank, getUsers, createNotification, createAuditLog, createSession, getProfileByReferralCode } from '../config/data.js';
import bcrypt from 'bcryptjs';
import { signToken, authMiddleware, adminOnly } from '../middleware/auth.js';
import { generateReferralCode } from '../utils/referral.js';
import { toNum } from '../utils/helpers.js';

const USE_SQLITE = process.env.USE_SQLITE === 'true';

async function autoFlagSameIp(ip, excludeUserId) {
  if (!ip || ip === '::1' || ip === '127.0.0.1' || ip === '::ffff:127.0.0.1') return;
  const users = await getUsers({ last_login_ip: ip }).catch(() => []);
  if (users.length >= 2) {
    for (const u of users) {
      if (!u.is_flagged && u.id !== excludeUserId) {
        await updateUser(u.id, { is_flagged: true }).catch(() => {});
        await createNotification(u.id, 'Account Flagged', `Your account has been flagged due to multiple accounts sharing the same IP address (${ip}). If you believe this is an error, please contact support.`, 'warning').catch(() => {});
      }
    }
  }
}

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'bashirabdulganiyy9@gmail.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || '1234567890';

const router = Router();

function profileResponse(p, rank) {
  return {
    lockedBalance: toNum(p?.locked_balance),
    withdrawableBalance: toNum(p?.withdrawable_balance),
    referralCode: p?.referral_code,
    totalReferrals: p?.total_referrals || 0,
    validReferrals: p?.valid_referrals || 0,
    referralEarnings: toNum(p?.referral_earnings),
    rank: rank ? {
      id: rank.id, name: rank.name, color: rank.color,
      copyTradesLimit: rank.copy_trades_limit,
    } : null,
  };
}

router.post('/signup', async (req, res) => {
  try {
    const { username, email, password, referrerCode } = req.body;
    console.log('[SIGNUP REQ]', JSON.stringify({ username, hasEmail: !!email, hasPassword: !!password }));
    if (!username || !password) {
      console.log('[SIGNUP FAIL] missing_fields');
      return res.status(400).json({ error: 'Username and password required' });
    }
    if (username.length < 3) {
      console.log('[SIGNUP FAIL] username_short');
      return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }
    if (password.length < 6) {
      console.log('[SIGNUP FAIL] password_short');
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await getUserBy('username', username.trim()).catch(() => null);
    if (existing) { console.log('[SIGNUP FAIL] username_taken'); return res.status(400).json({ error: 'Username already taken' }); }

    if (email) {
      const existingEmail = await getUserBy('email', email.trim()).catch(() => null);
      if (existingEmail) { console.log('[SIGNUP FAIL] email_taken'); return res.status(400).json({ error: 'Email already taken' }); }
    }

    const clientIp = req.ip || req.connection.remoteAddress || '';

    const hash = await bcrypt.hash(password, 10);
    const user = await createUser({
      username: username.trim(),
      email: email ? email.trim() : null,
      role: 'user',
      status: 'active',
      password_hash: hash,
      last_login_ip: clientIp,
    });

    let refCode = generateReferralCode();
    const existingRef = await getProfile(refCode).catch(() => null);
    if (existingRef) refCode = generateReferralCode();

    let referredBy = null;
    if (referrerCode) {
      const refProfile = await getProfileByReferralCode(referrerCode.trim()).catch(() => null);
      if (refProfile && refProfile.user_id !== user.id) referredBy = refProfile.user_id;
    }

    const profile = await createProfile({
      user_id: user.id,
      rank_id: null,
      referral_code: refCode,
      referred_by: referredBy,
    });

    const rank = await getRank(profile.rank_id);
    await autoFlagSameIp(clientIp, user.id);

    const token = signToken(user);

    createAuditLog({
      user_id: user.id, action: 'auth.signup',
      description: `User "${user.username}" signed up`,
      metadata: JSON.stringify({ username: user.username, email, referrerCode: referrerCode || null }),
      ip_address: clientIp,
    }).catch(() => {});

    res.status(201).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        isFlagged: user.is_flagged,
        profile: profileResponse(profile, rank),
      },
    });
  } catch (e) {
    console.error('[SIGNUP ERROR]', e);
    res.status(500).json({ error: e.message || 'Signup failed' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Look up admin in DB by email or username (supports multiple admins)
    let adminDbUser = await getUserBy('username', username.trim()).catch(() => null);
    if (!adminDbUser) {
      adminDbUser = await getUserBy('email', username.trim()).catch(() => null);
    }
    if (adminDbUser && adminDbUser.role !== 'admin') adminDbUser = null;

    const isAdminEmail = username.trim().toLowerCase() === ADMIN_EMAIL;

    if (isAdminEmail || adminDbUser) {
      const clientIp = req.ip || req.connection.remoteAddress || '';

      // Password verification: try DB first, then env fallback
      let passwordValid = false;
      if (adminDbUser && adminDbUser.password_hash) {
        passwordValid = await bcrypt.compare(password, adminDbUser.password_hash);
      }
      if (!passwordValid) {
        passwordValid = (password === ADMIN_PASSWORD);
      }
      if (!passwordValid) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }

      const adminUser = {
        id: adminDbUser ? adminDbUser.id : '00000000-0000-0000-0000-000000000000',
        username: adminDbUser ? adminDbUser.username : 'admin',
        email: adminDbUser ? adminDbUser.email : ADMIN_EMAIL,
        role: 'admin',
        is_flagged: adminDbUser ? adminDbUser.is_flagged || false : false,
        is_banned: adminDbUser ? adminDbUser.is_banned || false : false,
      };

      const token = signToken(adminUser);

      // NO session creation — allows multi-device admin login

      createAuditLog({
        user_id: adminUser.id, action: 'auth.login',
        description: 'Admin logged in',
        metadata: JSON.stringify({ username: adminUser.username, role: 'admin' }),
        ip_address: clientIp,
      }).catch(() => {});

      return res.json({
        token,
        user: {
          id: adminUser.id,
          username: adminUser.username,
          email: adminUser.email,
          role: 'admin',
          status: adminDbUser ? adminDbUser.status : 'active',
          isFlagged: adminUser.is_flagged,
          isBanned: adminUser.is_banned,
          createdAt: adminDbUser ? adminDbUser.created_at : new Date().toISOString(),
        },
      });
    }

    const user = await getUserBy('username', username.trim()).catch(() => null);
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });
    if (user.is_banned) return res.status(403).json({ error: 'Account banned' });

    const clientIp = req.ip || req.connection.remoteAddress || '';
    await updateUser(user.id, { last_login_ip: clientIp }).catch(() => {});
    await autoFlagSameIp(clientIp, user.id);

    const valid = await bcrypt.compare(password, user.password_hash || '');
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });
    let profile = await getProfile(user.id);
    if (!profile) {
      let refCode = generateReferralCode();
      const existingRef = await getProfile(refCode).catch(() => null);
      if (existingRef) refCode = generateReferralCode();
      profile = await createProfile({
        user_id: user.id,
        rank_id: null,
        referral_code: refCode,
      });
    }
    const rank = profile ? await getRank(profile.rank_id) : null;
    const token = signToken(user);

    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    createSession({
      user_id: user.id, token_hash: tokenHash,
      ip_address: clientIp, user_agent: req.headers['user-agent'] || null,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    }).catch(() => {});

    createAuditLog({
      user_id: user.id, action: 'auth.login',
      description: `User "${user.username}" logged in`,
      metadata: JSON.stringify({ username: user.username, role: user.role }),
      ip_address: clientIp,
    }).catch(() => {});

    res.json({
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        isFlagged: user.is_flagged,
        profile: profileResponse(profile, rank),
      },
    });
  } catch (e) {
    console.error('[LOGIN ERROR]', e);
    res.status(500).json({ error: e.message || 'Login failed' });
  }
});

router.post('/refresh', async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'Token required' });

    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET, { ignoreExpiration: true });
    } catch (e) {
      return res.status(401).json({ error: 'Invalid token' });
    }

    let user;

    if (decoded.role === 'admin') {
      user = { id: decoded.id, username: decoded.username, email: decoded.email || '', role: 'admin' };
    } else {
      user = await getUser(decoded.id);
      if (!user) return res.status(404).json({ error: 'User not found' });
      if (user.is_banned) return res.status(403).json({ error: 'Account banned' });
    }

    const newToken = signToken(user);

    // Skip session for admin (multi-device support)
    if (decoded.role !== 'admin') {
      const tokenHash = crypto.createHash('sha256').update(newToken).digest('hex');
      await createSession({
        user_id: decoded.id,
        token_hash: tokenHash,
        ip_address: req.ip || req.connection.remoteAddress || '',
        user_agent: req.headers['user-agent'] || null,
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      }).catch(() => {});
    }

    createAuditLog({
      user_id: user.id, action: 'auth.token_refresh',
      description: `Token refreshed for "${user.username}"`,
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});

    res.json({ token: newToken, user: { id: user.id, username: user.username, email: user.email, role: user.role } });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Refresh failed' });
  }
});

router.post('/logout', (req, res) => {
  createAuditLog({
    user_id: req.user?.id, action: 'auth.logout',
    description: req.user ? `User "${req.user.username}" logged out` : 'User logged out',
    ip_address: req.ip || req.connection.remoteAddress || '',
  }).catch(() => {});
  res.json({ ok: true });
});

router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const profile = await getProfile(req.user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    res.json({
      user: {
        id: req.user.id,
        username: req.user.username,
        email: req.user.email,
        role: req.user.role,
        isFlagged: req.user.is_flagged,
      },
      profile: profile ? profileResponse(profile, rank) : null,
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/admin/reset-password', authMiddleware, adminOnly, async (req, res) => {
  try {
    const { userId, newPassword } = req.body;
    if (!userId || !newPassword) {
      return res.status(400).json({ error: 'userId and newPassword required' });
    }

    const target = await getUser(userId).catch(() => null);
    if (!target) return res.status(404).json({ error: 'User not found' });

    const hash = await bcrypt.hash(newPassword, 10);
    await updateUser(userId, { password_hash: hash });

    createAuditLog({
      user_id: req.user.id, target_user_id: userId, action: 'admin.password_reset',
      description: `Admin reset password for user "${target.username}"`,
      ip_address: req.ip || req.connection.remoteAddress || '',
    }).catch(() => {});
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Reset failed' });
  }
});

export default router;
