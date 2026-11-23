const express = require('express');
const { Profile, Listing, Order, Query } = require('../../models/agri');
const { h, bad, esc, out } = require('../../utils/http');
const { requireRole, notify, userModel } = require('../../utils/identity');

const router = express.Router();
const only = requireRole('admin');

router.get('/admin/stats', only, h(async (req, res) => {
  const U = userModel();
  const users = { total: 0, byRole: {} };
  if (U) {
    const rows = await U.aggregate([{ $group: { _id: '$role', n: { $sum: 1 } } }]);
    rows.forEach(r => {
      const k = String(r._id || 'unknown').toLowerCase();
      users.byRole[k] = (users.byRole[k] || 0) + r.n;
      users.total += r.n;
    });
  }
  const g = await Order.aggregate([
    { $match: { status: { $ne: 'cancelled' } } },
    { $group: { _id: null, gmv: { $sum: '$total' }, n: { $sum: 1 } } }
  ]);
  res.json({
    users,
    suppliersPending: await Profile.countDocuments({ role: 'supplier', verified: false }),
    listings: await Listing.countDocuments(),
    orders: g.length ? g[0].n : 0,
    gmv: g.length ? g[0].gmv : 0,
    openQueries: await Query.countDocuments({ status: 'open' })
  });
}));

router.get('/admin/users', only, h(async (req, res) => {
  const U = userModel();
  if (!U) return res.json({ items: [] });
  const f = {};
  if (req.query.role) f.role = new RegExp('^' + esc(req.query.role) + '$', 'i');
  const users = await U.find(f).sort({ createdAt: -1 }).limit(100).lean();
  const profiles = await Profile.find({ user: { $in: users.map(u => String(u._id)) } });
  const pm = {};
  profiles.forEach(p => { pm[p.user] = p; });
  res.json({
    items: users.map(u => ({
      id: String(u._id),
      name: u.name || u.fullName || u.username || '',
      email: u.email || '',
      role: String(u.role || u.userType || '').toLowerCase(),
      verified: !!(pm[String(u._id)] && pm[String(u._id)].verified),
      businessName: pm[String(u._id)] ? pm[String(u._id)].businessName : '',
      createdAt: u.createdAt
    }))
  });
}));

// approve / un-approve a supplier or expert; their listings get the verified badge
router.patch('/admin/verify/:userId', only, h(async (req, res) => {
  const v = !!(req.body || {}).verified;
  await Profile.updateOne({ user: req.params.userId }, { $set: { verified: v }, $setOnInsert: { role: 'supplier' } }, { upsert: true });
  await Listing.updateMany({ seller: req.params.userId }, { $set: { verified: v } });
  await notify(req.params.userId, v ? 'Your account is verified' : 'Verification removed', v ? 'Buyers now see the verified badge on your products.' : 'An admin removed your verified badge.', 'account');
  res.json({ ok: true, verified: v });
}));

router.patch('/admin/listings/:id', only, h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l) throw bad('Listing not found', 404);
  const s = (req.body || {}).status;
  if (!['active', 'paused', 'removed'].includes(s)) throw bad('Invalid status');
  l.status = s;
  await l.save();
  res.json(out(l));
}));

module.exports = router;