const express = require('express');
const { Listing, CartItem, Order, Profile } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');
const { notify } = require('../../utils/identity');

const router = express.Router();
const STEPS = ['placed', 'confirmed', 'picked_up', 'out_for_delivery', 'delivered'];
const LABELS = ['Order placed', 'Confirmed by seller', 'Picked up', 'Out for delivery', 'Delivered'];
const DELIVERY_PER_SELLER = 500;

// ---------------- cart ----------------
async function cartOut(owner) {
  const rows = await CartItem.find({ owner }).populate('listing');
  const items = rows.filter(r => r.listing).map(r => ({
    id: String(r._id), listingId: String(r.listing._id), title: r.listing.title, category: r.listing.category,
    sellerId: r.listing.seller, sellerName: r.listing.sellerName, pricePerKg: r.listing.pricePerKg, qtyKg: r.qtyKg,
    maxKg: r.listing.quantityKg, amount: r.qtyKg * r.listing.pricePerKg
  }));
  const subtotal = items.reduce((a, i) => a + i.amount, 0);
  const sellers = new Set(items.map(i => i.sellerId)).size;
  const delivery = DELIVERY_PER_SELLER * sellers;
  return { items, subtotal, delivery, total: subtotal + delivery, farmers: sellers };
}

router.get('/cart', h(async (req, res) => { res.json(await cartOut(req.me.id)); }));

router.post('/cart', h(async (req, res) => {
  const body = req.body || {};
  const qty = Math.max(1, Number(body.qtyKg) || 10);
  const l = await Listing.findById(body.listingId);
  if (!l) throw bad('Listing not found', 404);
  if (l.seller === req.me.id && !req.me.demo) throw bad('You cannot buy your own listing');
  let row = await CartItem.findOne({ owner: req.me.id, listing: l._id });
  if (row) row.qtyKg = Math.min(l.quantityKg, row.qtyKg + qty);
  else row = new CartItem({ owner: req.me.id, listing: l._id, qtyKg: Math.min(l.quantityKg, qty) });
  await row.save();
  res.status(201).json(await cartOut(req.me.id));
}));

router.patch('/cart/:id', h(async (req, res) => {
  const row = await CartItem.findOne({ _id: req.params.id, owner: req.me.id }).populate('listing');
  if (!row) throw bad('Cart item not found', 404);
  const q = Number((req.body || {}).qtyKg);
  if (!q || q < 10) throw bad('Minimum quantity is 10');
  row.qtyKg = Math.min(q, row.listing ? row.listing.quantityKg : q);
  await row.save();
  res.json(await cartOut(req.me.id));
}));

router.delete('/cart/:id', h(async (req, res) => {
  await CartItem.deleteOne({ _id: req.params.id, owner: req.me.id });
  res.json(await cartOut(req.me.id));
}));

// ---------------- orders ----------------
function orderOut(o) {
  const x = out(o);
  const cancelled = x.status === 'cancelled';
  const idx = cancelled ? 0 : Math.max(0, STEPS.indexOf(x.status));
  x.statusIndex = idx;
  x.steps = STEPS.map((s, i) => {
    const hi = (x.history || []).find(z => z.status === s);
    return { key: s, label: LABELS[i], done: i <= idx, at: hi ? hi.at : null };
  });
  x.summary = (x.items || []).map(i => i.title + ' ' + i.qtyKg + ' kg').join(', ');
  return x;
}

const isSeller = (o, id) => o.seller === id || o.items.some(i => i.sellerId === id);
const canSee = (o, id) => o.owner === id || isSeller(o, id);

async function cancelOrder(o) {
  if (['delivered', 'cancelled'].includes(o.status)) throw bad('This order can no longer be cancelled');
  for (const it of o.items) {
    if (it.listing) await Listing.updateOne({ _id: it.listing }, { $inc: { quantityKg: it.qtyKg } });
  }
  o.status = 'cancelled';
  o.eta = 'Cancelled';
  o.history.push({ status: 'cancelled', at: new Date() });
  await o.save();
}

// my purchases
router.get('/orders', h(async (req, res) => {
  const list = await Order.find({ owner: req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(orderOut) });
}));

// my sales (farmers and suppliers)
router.get('/orders/sales', h(async (req, res) => {
  const list = await Order.find({ 'items.sellerId': req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(orderOut) });
}));

router.get('/orders/:id', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (!canSee(o, req.me.id)) throw bad('Not allowed', 403);
  res.json(orderOut(o));
}));

// checkout: one order per seller, so each farmer / supplier manages their own order
router.post('/orders', h(async (req, res) => {
  const me = req.me;
  const b = req.body || {};
  const payment = ['Cash', 'Card', 'JazzCash'].includes(b.payment) ? b.payment : 'Cash';
  const rows = (await CartItem.find({ owner: me.id }).populate('listing')).filter(r => r.listing);
  if (!rows.length) throw bad('Your cart is empty');
  for (const r of rows) {
    if (r.qtyKg > r.listing.quantityKg) throw bad('Only ' + r.listing.quantityKg + ' left of ' + r.listing.title);
  }
  const groups = {};
  rows.forEach(r => { (groups[r.listing.seller] = groups[r.listing.seller] || []).push(r); });
  const last = await Order.findOne().sort({ number: -1 });
  let next = (last && last.number ? last.number : 1040) + 1;
  const created = [];
  for (const sellerId of Object.keys(groups)) {
    const g = groups[sellerId];
    const items = g.map(r => ({
      listing: r.listing._id, title: r.listing.title, sellerId: r.listing.seller,
      sellerName: r.listing.sellerName, qtyKg: r.qtyKg, pricePerKg: r.listing.pricePerKg
    }));
    const subtotal = items.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0);
    const order = await Order.create({
      number: next++, owner: me.id, buyerName: me.name,
      seller: sellerId, sellerName: g[0].listing.sellerName, sellerRole: g[0].listing.sellerRole,
      items, subtotal, delivery: DELIVERY_PER_SELLER, total: subtotal + DELIVERY_PER_SELLER, payment,
      address: b.address || 'Islamabad', status: 'placed', history: [{ status: 'placed', at: new Date() }],
      courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Tomorrow 4:00 - 6:00 PM'
    });
    created.push(order);
    await notify(sellerId, 'New order #' + order.number, me.name + ' ordered ' + items.map(i => i.title + ' ' + i.qtyKg).join(', '), 'order', String(order._id));
  }
  for (const r of rows) await Listing.updateOne({ _id: r.listing._id }, { $inc: { quantityKg: -r.qtyKg, sales: 1 } });
  await CartItem.deleteMany({ owner: me.id });
  const first = orderOut(created[0]);
  first.orders = created.map(orderOut);
  first.orderCount = created.length;
  first.grandTotal = created.reduce((a, o) => a + o.total, 0);
  res.status(201).json(first);
}));

// seller moves the order forward (or cancels it)
router.patch('/orders/:id/status', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (!isSeller(o, req.me.id)) throw bad('Only the seller can update this order', 403);
  const to = String((req.body || {}).status || '');
  if (to === 'cancelled') {
    await cancelOrder(o);
    await notify(o.owner, 'Order #' + o.number + ' was cancelled', 'The seller cancelled your order.', 'order', String(o._id));
    return res.json(orderOut(o));
  }
  const i = STEPS.indexOf(o.status);
  if (i < 0 || i >= STEPS.length - 1) throw bad('This order cannot be updated any more');
  if (STEPS.indexOf(to) !== i + 1) throw bad('Next status must be ' + STEPS[i + 1]);
  o.status = to;
  o.history.push({ status: to, at: new Date() });
  if (to === 'delivered') {
    o.eta = 'Delivered';
    await Profile.updateOne({ user: o.seller }, { $inc: { completed: 1 } });
  }
  await o.save();
  await notify(o.owner, 'Order #' + o.number + ': ' + LABELS[STEPS.indexOf(to)], 'Your order status changed.', 'order', String(o._id));
  res.json(orderOut(o));
}));

// buyer cancels a pending order
router.post('/orders/:id/cancel', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (o.owner !== req.me.id) throw bad('Not your order', 403);
  if (o.status !== 'placed') throw bad('Only pending orders can be cancelled');
  await cancelOrder(o);
  await notify(o.seller, 'Order #' + o.number + ' cancelled', o.buyerName + ' cancelled the order.', 'order', String(o._id));
  res.json(orderOut(o));
}));

// demo helper used by the tracking screen: buyer or seller advances one step
router.patch('/orders/:id/advance', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (!canSee(o, req.me.id)) throw bad('Not allowed', 403);
  const i = STEPS.indexOf(o.status);
  if (i < 0 || i >= STEPS.length - 1) throw bad('Order is already delivered');
  o.status = STEPS[i + 1];
  o.history.push({ status: o.status, at: new Date() });
  if (o.status === 'delivered') o.eta = 'Delivered';
  await o.save();
  res.json(orderOut(o));
}));

module.exports = router;