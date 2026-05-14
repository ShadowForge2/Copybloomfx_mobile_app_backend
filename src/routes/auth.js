import { Router } from 'express';
import { db, getUser, getUserBy, getProfile, createUser, createProfile, getRank } from '../config/supabase.js';
import { signToken, authMiddleware, adminOnly } from '../middleware/auth.js';
import { generateReferralCode } from '../utils/referral.js';
import { toNum } from '../utils/helpers.js';

const ADMIN_EMAIL = 'bashirabdulganiyy9@gmail.com';
const ADMIN_PASSWORD = '1234567890';

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
    const { username, email, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }
    if (username.length < 3) {
      return res.status(400).json({ error: 'Username must be at least 3 characters' });
    }
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await getUserBy('username', username.trim()).catch(() => null);
    if (existing) return res.status(400).json({ error: 'Username already taken' });

    if (email) {
      const existingEmail = await getUserBy('email', email.trim()).catch(() => null);
      if (existingEmail) return res.status(400).json({ error: 'Email already taken' });
    }

    const { data: authData, error: authErr } = await db.auth.signUp({
      email: email || `${username}@bloomfx.app`,
      password,
      options: { data: { username: username.trim() } },
    });
    if (authErr) return res.status(400).json({ error: authErr.message });
    if (!authData.user) return res.status(400).json({ error: 'Sign up failed' });

    let refCode = generateReferralCode();
    const existingRef = await getProfile(refCode).catch(() => null);
    if (existingRef) refCode = generateReferralCode();

    const user = await createUser({
      auth_user_id: authData.user.id,
      username: username.trim(),
      email: email ? email.trim() : null,
      role: 'user',
      status: 'active',
    });

    const profile = await createProfile({
      user_id: user.id,
      rank_id: 1,
      referral_code: refCode,
    });

    const rank = await getRank(profile.rank_id);
    const token = signToken(user);

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
    res.status(500).json({ error: e.message || 'Signup failed' });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    const isAdminLogin = username.trim().toLowerCase() === ADMIN_EMAIL;
    if (isAdminLogin) {
      if (password !== ADMIN_PASSWORD) {
        return res.status(401).json({ error: 'Invalid credentials' });
      }
      const adminUser = {
        id: 'admin',
        username: 'admin',
        email: ADMIN_EMAIL,
        role: 'admin',
        is_flagged: false,
        is_banned: false,
      };
      const token = signToken(adminUser);
      return res.json({
        token,
        user: {
          id: adminUser.id,
          username: adminUser.username,
          email: adminUser.email,
          role: 'admin',
          isFlagged: false,
          isBanned: false,
          profile: null,
        },
      });
    }

    const user = await getUserBy('username', username.trim()).catch(() => null);
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });
    if (user.is_banned) return res.status(403).json({ error: 'Account banned' });

    const { data: authData, error: authErr } = await db.auth.signInWithPassword({
      email: user.email || `${username.trim()}@bloomfx.app`,
      password,
    });
    if (authErr) return res.status(401).json({ error: 'Invalid credentials' });

    const profile = await getProfile(user.id);
    const rank = profile ? await getRank(profile.rank_id) : null;
    const token = signToken(user);

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
    res.status(500).json({ error: e.message || 'Login failed' });
  }
});

router.post('/logout', (_req, res) => {
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

    const { error: authErr } = await db.auth.admin.updateUserById(
      target.auth_user_id,
      { password: newPassword }
    );
    if (authErr) return res.status(500).json({ error: authErr.message });

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message || 'Reset failed' });
  }
});

export default router;
