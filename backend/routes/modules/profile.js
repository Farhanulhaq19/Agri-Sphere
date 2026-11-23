const express = require('express');
const { Notification } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');
const { ensureProfile } = require('../../utils/identity');

const router = express.Router();

// Call this right after login: creates the role profile (supplier, expert...) if it does not exist yet
router.get('/me', h(async (req, res) => {
  const me = req.me;
  let profile = null;
  let unread = 0;
  if (!me.demo) {
    profile = await ensureProfile(me);
    unread = await Notification.countDocuments({ user: me.id, read: false });
  }
  res.json({ id: me.id, name: me.name, email: me.email, role: me.role, demo: !!me.demo, profile: profile ? out(profile) : null, unread });
}));

const EDITABLE = ['name', 'phone', 'businessName', 'city', 'address', 'licenseNo', 'categories', 'specialization', 'experienceYears', 'bio', 'farmLocation'];

router.put('/profile', h(async (req, res) => {
  if (req.me.demo) throw bad('Log in to edit your profile', 401);
  const p = await ensureProfile(req.me);
  const b = req.body || {};
  EDITABLE.forEach(k => { if (b[k] !== undefined) p[k] = b[k]; });
  await p.save();
  res.json(out(p));
}));

router.get('/notifications', h(async (req, res) => {
  const items = await Notification.find({ user: req.me.id }).sort({ createdAt: -1 }).limit(50);
  res.json({ unread: items.filter(n => !n.read).length, items: items.map(out) });
}));

router.post('/notifications/read', h(async (req, res) => {
  await Notification.updateMany({ user: req.me.id, read: false }, { read: true });
  res.json({ ok: true });
}));

module.exports = router;