const express = require('express');
const { Profile, Listing, Order, Query } = require('../../models/agri');
const { Machine, MachineBooking } = require('../../models/machinery');
const { Warehouse, StorageBooking } = require('../../models/warehouse');
const { AdminLog, logAdmin } = require('../../models/admin');
const { h, bad, esc, out } = require('../../utils/http');
const { requireRole, notify, userModel } = require('../../utils/identity');

const router = express.Router();
const only = requireRole('admin');
const DAY = 864e5;
const PAY_STATUS = { under_review: 'under_review', paid: 'paid', rejected: 'rejected' };
const LISTING_STATUS = { active: 'active', paused: 'paused', removed: 'removed' };

// ---------------------------------------------------------------- overview with charts
router.get('/admin/overview', only, h(async (req, res) => {
  const U = userModel();
  const since14 = new Date(Date.now() - 13 * DAY);
  since14.setHours(0, 0, 0, 0);
  const [byRole, newUsers, listings, active, gmv, daily, byStatus, top, pending, queries, machines, warehouses, mb, sb] = await Promise.all([
    U ? U.aggregate([{ $group: { _id: '$role', n: { $sum: 1 } } }]) : [],
    U ? U.countDocuments({ createdAt: { $gte: new Date(Date.now() - 7 * DAY) } }) : 0,
    Listing.countDocuments(),
    Listing.countDocuments({ status: { $nin: ['paused', 'removed'] }, quantityKg: { $gt: 0 } }),
    Order.aggregate([{ $match: { status: { $ne: 'cancelled' } } }, { $group: { _id: null, gmv: { $sum: '$total' }, n: { $sum: 1 } } }]),
    Order.aggregate([
      { $match: { status: { $ne: 'cancelled' }, createdAt: { $gte: since14 } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, amount: { $sum: '$total' }, n: { $sum: 1 } } }
    ]),
    Order.aggregate([{ $group: { _id: '$status', n: { $sum: 1 } } }]),
    Listing.find({}, { title: 1, sales: 1, rating: 1, category: 1, sellerName: 1 }).sort({ sales: -1 }).limit(5),
    Order.countDocuments({ paymentStatus: 'under_review' }),
    Query.countDocuments({ status: 'open' }),
    Machine.countDocuments(),
    Warehouse.countDocuments(),
    MachineBooking.countDocuments(),
    StorageBooking.countDocuments()
  ]);
  const users = { total: 0, byRole: {} };
  byRole.forEach(r => {
    const k = String(r._id || 'unknown').toLowerCase();
    users.byRole[k] = (users.byRole[k] || 0) + r.n;
    users.total += r.n;
  });
  const days = Array.from({ length: 14 }, (_, i) => {
    const d = new Date(since14.getTime() + i * DAY).toISOString().slice(0, 10);
    const hit = daily.find(x => x._id === d);
    return { date: d, amount: hit ? hit.amount : 0, orders: hit ? hit.n : 0 };
  });
  res.json({
    users, newUsers7d: newUsers,
    listings, activeListings: active,
    orders: gmv.length ? gmv[0].n : 0, gmv: gmv.length ? gmv[0].gmv : 0,
    revenue14d: days,
    ordersByStatus: Object.fromEntries(byStatus.map(s => [s._id, s.n])),
    topProducts: top.map(out),
    pendingPayments: pending, openQueries: queries,
    machines, warehouses, bookings: mb + sb,
    suppliersPending: await Profile.countDocuments({ role: 'supplier', verified: false })
  });
}));

// kept for the older screen
router.get('/admin/stats', only, h(async (req, res) => {
  const U = userModel();
  const users = { total: 0, byRole: {} };
  if (U) {
    (await U.aggregate([{ $group: { _id: '$role', n: { $sum: 1 } } }])).forEach(r => {
      const k = String(r._id || 'unknown').toLowerCase();
      users.byRole[k] = (users.byRole[k] || 0) + r.n;
      users.total += r.n;
    });
  }
  const g = await Order.aggregate([{ $match: { status: { $ne: 'cancelled' } } }, { $group: { _id: null, gmv: { $sum: '$total' }, n: { $sum: 1 } } }]);
  res.json({
    users,
    suppliersPending: await Profile.countDocuments({ role: 'supplier', verified: false }),
    listings: await Listing.countDocuments(),
    orders: g.length ? g[0].n : 0,
    gmv: g.length ? g[0].gmv : 0,
    openQueries: await Query.countDocuments({ status: 'open' })
  });
}));

// ---------------------------------------------------------------- payment verification queue (money goes to the platform's Easypaisa)
router.get('/admin/payments', only, h(async (req, res) => {
  // look the value up in a fixed table so only known constants reach the database query
  const status = PAY_STATUS[String(req.query.status)] || 'under_review';
  const list = await Order.find({ paymentStatus: status, payment: { $ne: 'Cash' } }).sort({ updatedAt: -1 }).limit(100);
  res.json({ items: list.map(o => ({ ...out(o), canVerify: status === 'under_review' })) });
}));

// ---------------------------------------------------------------- users
router.get('/admin/users', only, h(async (req, res) => {
  const U = userModel();
  if (!U) return res.json({ items: [] });
  const f = {};
  if (req.query.role && req.query.role !== 'all') f.$or = [{ role: new RegExp('^' + esc(req.query.role) + '$', 'i') }, { roles: new RegExp('^' + esc(req.query.role) + '$', 'i') }];
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$and = [{ $or: [{ name: r }, { email: r }, { phone: r }] }];
  }
  const users = await U.find(f).sort({ createdAt: -1 }).limit(150).lean();
  const profiles = await Profile.find({ user: { $in: users.map(u => String(u._id)) } });
  const pm = {};
  profiles.forEach(p => { pm[p.user] = p; });
  res.json({
    items: users.map(u => ({
      id: String(u._id),
      name: u.name || '',
      email: u.email || '',
      phone: u.phone || '',
      role: String(u.role || '').toLowerCase(),
      roles: (u.roles || []).map(r => String(r).toLowerCase()),
      verified: !!(pm[String(u._id)] && pm[String(u._id)].verified),
      businessName: pm[String(u._id)] ? pm[String(u._id)].businessName : '',
      createdAt: u.createdAt
    }))
  });
}));

// approve / un-approve a seller; their listings get the verified badge
router.patch('/admin/verify/:userId', only, h(async (req, res) => {
  const v = !!(req.body || {}).verified;
  await Profile.updateOne({ user: req.params.userId }, { $set: { verified: v }, $setOnInsert: { role: 'supplier' } }, { upsert: true });
  await Listing.updateMany({ seller: req.params.userId }, { $set: { verified: v } });
  await notify(req.params.userId, v ? 'Your account is verified' : 'Verification removed', v ? 'Buyers now see the verified badge on your products.' : 'An admin removed your verified badge.', 'account');
  await logAdmin(req.me, v ? 'user.verify' : 'user.unverify', req.params.userId, '');
  res.json({ ok: true, verified: v });
}));

// ---------------------------------------------------------------- listing moderation
router.get('/admin/listings', only, h(async (req, res) => {
  const f = {};
  const st = LISTING_STATUS[String(req.query.status)];
  if (st) f.status = st;
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$or = [{ title: r }, { sellerName: r }, { category: r }];
  }
  const list = await Listing.find(f).sort({ createdAt: -1 }).limit(150);
  res.json({ items: list.map(out) });
}));

router.patch('/admin/listings/:id', only, h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l) throw bad('Listing not found', 404);
  const b = req.body || {};
  if (!['active', 'paused', 'removed'].includes(b.status)) throw bad('Invalid status');
  l.status = b.status;
  await l.save();
  const reason = String(b.reason || '').slice(0, 200);
  if (b.status !== 'active') {
    await notify(l.seller, 'Listing ' + b.status + ' by admin', l.title + (reason ? ': ' + reason : ''), 'listing', String(l._id));
  }
  await logAdmin(req.me, 'listing.' + b.status, l._id, l.title + (reason ? ' - ' + reason : ''));
  res.json(out(l));
}));

// ---------------------------------------------------------------- activity log
router.get('/admin/logs', only, h(async (req, res) => {
  const list = await AdminLog.find().sort({ createdAt: -1 }).limit(200);
  res.json({ items: list.map(out) });
}));

module.exports = router;
