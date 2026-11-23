const express = require('express');
const { Listing, Order } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');
const { requireRole, ensureProfile } = require('../../utils/identity');
const { createListing } = require('../../utils/listings');

const router = express.Router();
const only = requireRole('supplier');

function orderSummary(o, id) {
  const mine = o.items.filter(i => i.sellerId === id);
  return {
    id: String(o._id), number: o.number, buyer: o.buyerName,
    summary: mine.map(i => i.title + ' ' + i.qtyKg + ' kg').join(', '),
    total: mine.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0),
    status: o.status, address: o.address, payment: o.payment, createdAt: o.createdAt
  };
}

router.get('/supplier/dashboard', only, h(async (req, res) => {
  const me = req.me;
  const profile = await ensureProfile(me);
  const products = await Listing.find({ seller: me.id });
  const orders = await Order.find({ 'items.sellerId': me.id }).sort({ createdAt: -1 });
  const c = { placed: 0, confirmed: 0, picked_up: 0, out_for_delivery: 0, delivered: 0, cancelled: 0 };
  let earnings = 0;
  orders.forEach(o => {
    c[o.status] = (c[o.status] || 0) + 1;
    if (o.status !== 'cancelled') o.items.forEach(i => { if (i.sellerId === me.id) earnings += i.qtyKg * i.pricePerKg; });
  });
  res.json({
    name: me.name,
    businessName: profile.businessName || me.name,
    verified: !!profile.verified,
    earnings,
    products: products.length,
    activeProducts: products.filter(p => p.status !== 'paused').length,
    pending: c.placed,
    inProgress: c.confirmed + c.picked_up + c.out_for_delivery,
    delivered: c.delivered,
    lowStock: products.filter(p => p.quantityKg <= 20).map(p => ({ id: String(p._id), title: p.title, quantityKg: p.quantityKg, unit: p.unit })),
    recentOrders: orders.slice(0, 5).map(o => orderSummary(o, me.id))
  });
}));

router.get('/supplier/products', only, h(async (req, res) => {
  const list = await Listing.find({ seller: req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(out) });
}));

router.post('/supplier/products', only, h(async (req, res) => {
  const l = await createListing(req.me, req.body || {});
  res.status(201).json(out(l));
}));

router.patch('/supplier/products/:id', only, h(async (req, res) => {
  const l = await Listing.findOne({ _id: req.params.id, seller: req.me.id });
  if (!l) throw bad('Product not found', 404);
  const b = req.body || {};
  if (b.pricePerKg !== undefined) l.pricePerKg = Number(b.pricePerKg);
  if (b.quantityKg !== undefined) l.quantityKg = Number(b.quantityKg);
  if (b.status && ['active', 'paused'].includes(b.status)) l.status = b.status;
  if (b.description !== undefined) l.description = b.description;
  if (b.brand !== undefined) l.brand = b.brand;
  await l.save();
  res.json(out(l));
}));

router.delete('/supplier/products/:id', only, h(async (req, res) => {
  await Listing.deleteOne({ _id: req.params.id, seller: req.me.id });
  res.json({ ok: true });
}));

router.get('/supplier/orders', only, h(async (req, res) => {
  const list = await Order.find({ 'items.sellerId': req.me.id }).sort({ createdAt: -1 }).limit(100);
  res.json({ items: list.map(o => orderSummary(o, req.me.id)) });
}));

module.exports = router;