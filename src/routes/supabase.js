import { Router } from 'express';
import { supabase, db, getUsers, getUserBy } from '../config/supabase.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

router.get('/health', async (_req, res) => {
  try {
    const { data, error } = await supabase.from('users').select('count', { count: 'exact', head: true });
    res.json({
      ok: true,
      connected: !error,
      userCount: error ? null : data,
      error: error ? error.message : null,
    });
  } catch (e) {
    res.status(500).json({ ok: false, connected: false, error: e.message });
  }
});

router.get('/me', authMiddleware, async (req, res) => {
  try {
    const row = await getUserBy('auth_user_id', String(req.user.id));
    if (!row) return res.status(404).json({ error: 'User not found in Supabase' });
    res.json({ user: row });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.get('/users', authMiddleware, async (_req, res) => {
  try {
    const rows = await getUsers();
    res.json({ users: rows });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/auth/signup', async (req, res) => {
  try {
    const { email, password, username } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

    const { data: authUser, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { username } },
    });

    if (authError) return res.status(400).json({ error: authError.message });
    if (!authUser.user) return res.status(400).json({ error: 'Sign up failed' });

    const { error: insertError } = await supabase.from('users').insert({
      auth_user_id: authUser.user.id,
      username: username || email.split('@')[0],
      email,
      role: 'user',
      status: 'active',
    });

    if (insertError) return res.status(500).json({ error: insertError.message });

    res.status(201).json({
      ok: true,
      user: { id: authUser.user.id, email, username },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

router.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return res.status(401).json({ error: error.message });

    const userData = await getUserBy('email', email);
    res.json({
      token: data.session?.access_token,
      user: userData || { email },
    });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

export default router;
