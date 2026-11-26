const express = require('express');
const { Listing, CartItem, Order, Profile } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');
const { notify } = require('../../utils/identity');
const { readProof, payAccount } = require('../../utils/uploads');
const { nextNumber } = require('../../utils/counter');

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
router.get('/cart/count', h(async (req, res) => { res.json({ count: await CartItem.countDocuments({ owner: req.me.id }) }); }));

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
function isAdmin(me) { return me.role === 'admin' || (me.roles || []).includes('admin'); }
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
  if (!canSee(o, req.me.id) && !isAdmin(req.me)) throw bad('Not allowed', 403);
  const x = orderOut(o);
  x.isBuyer = o.owner === req.me.id;
  x.isSeller = isSeller(o, req.me.id);
  x.canVerify = x.isSeller || isAdmin(req.me);
  // older orders: look up the seller's number from the listing / profile
  if (!x.sellerPhone) {
    const l = o.items[0] && o.items[0].listing ? await Listing.findById(o.items[0].listing, { sellerPhone: 1 }) : null;
    const p = l && l.sellerPhone ? null : await Profile.findOne({ user: o.seller }, { phone: 1 });
    x.sellerPhone = (l && l.sellerPhone) || (p && p.phone) || '';
  }
  // what the seller can do next
  const i = STEPS.indexOf(o.status);
  const waitingPay = ['awaiting_proof', 'under_review', 'rejected'].includes(o.paymentStatus);
  x.nextStep = x.isSeller && i >= 0 && i < STEPS.length - 1 ? { status: STEPS[i + 1], label: LABELS[i + 1], blocked: STEPS[i + 1] === 'confirmed' && waitingPay } : null;
  x.canCancelAsSeller = x.isSeller && !['delivered', 'cancelled'].includes(o.status);
  x.canCancelAsBuyer = x.isBuyer && o.status === 'placed' && !['under_review', 'paid'].includes(o.paymentStatus);
  res.json(x);
}));

// ---------------- payment ----------------
// Online payments (Easypaisa / card through Easypaisa) are sent manually to this account,
// then the buyer uploads a screenshot and the seller or an admin verifies it.
const DELIVERY = { standard: { fee: DELIVERY_PER_SELLER, eta: '2 - 3 days' }, express: { fee: 900, eta: 'Tomorrow 4:00 - 6:00 PM' } };

router.get('/payment-info', h(async (req, res) => {
  res.json({ account: payAccount(), delivery: DELIVERY, methods: ['Cash', 'Easypaisa', 'Card'] });
}));

// buyer uploads the payment screenshot (applies to every order from the same checkout)
router.post('/orders/:id/payment-proof', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (o.owner !== req.me.id) throw bad('Not your order', 403);
  if (o.payment === 'Cash') throw bad('This order is Cash on Delivery');
  if (!['awaiting_proof', 'rejected'].includes(o.paymentStatus)) throw bad('Payment is already ' + o.paymentStatus.replace('_', ' '));
  const { ref, url } = readProof(req.body);
  const group = o.checkoutId ? await Order.find({ checkoutId: o.checkoutId, owner: o.owner }) : [o];
  for (const g of group) {
    g.paymentProof = url;
    g.paymentRef = ref;
    g.paymentStatus = 'under_review';
    g.paymentNote = '';
    await g.save();
    await notify(g.seller, 'Payment proof for order #' + g.number, g.buyerName + ' uploaded a payment screenshot. Please verify it.', 'order', String(g._id));
  }
  res.json(orderOut(group.find(g => String(g._id) === String(o._id)) || o));
}));

// seller (or admin) approves / rejects the payment
router.patch('/orders/:id/payment', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (!isSeller(o, req.me.id) && !isAdmin(req.me)) throw bad('Only the seller or an admin can verify payments', 403);
  if (o.paymentStatus !== 'under_review') throw bad('There is no payment waiting for review');
  const b = req.body || {};
  const ok = b.action === 'approve';
  o.paymentStatus = ok ? 'paid' : 'rejected';
  o.paymentNote = ok ? '' : String(b.reason || 'Payment could not be verified').slice(0, 200);
  await o.save();
  if (isAdmin(req.me) && !isSeller(o, req.me.id)) {
    await require('../../models/admin').logAdmin(req.me, ok ? 'payment.approve' : 'payment.reject', o._id, 'Order #' + o.number + ' Rs ' + o.total + (ok ? '' : ' - ' + o.paymentNote));
  }
  await notify(o.owner,
    ok ? 'Payment verified for order #' + o.number : 'Payment rejected for order #' + o.number,
    ok ? 'Thank you! Your payment was received.' : o.paymentNote + '. Please upload a correct screenshot.',
    'order', String(o._id));
  res.json(orderOut(o));
}));

// checkout: one order per seller, so each farmer / supplier manages their own order
router.post('/orders', h(async (req, res) => {
  const me = req.me;
  const b = req.body || {};
  const payment = ['Cash', 'Easypaisa', 'Card'].includes(b.payment) ? b.payment : 'Cash';
  const deliveryType = DELIVERY[b.deliveryType] ? b.deliveryType : 'standard';
  const fee = DELIVERY[deliveryType].fee;
  const receiverName = String(b.name || me.name || '').trim();
  const phone = String(b.phone || '').replace(/[\s-]/g, '');
  const city = String(b.city || '').trim();
  const address = String(b.address || '').trim();
  if (receiverName.length < 3) throw bad('Enter the receiver name');
  if (!/^(\+92|0)3\d{9}$/.test(phone)) throw bad('Enter a valid mobile number, e.g. 03001234567');
  if (!city) throw bad('Select your city');
  if (address.length < 10) throw bad('Enter the full delivery address');
  const checkoutId = 'CO' + Date.now().toString(36).toUpperCase() + Math.random().toString(36).slice(2, 6).toUpperCase();
  const rows = (await CartItem.find({ owner: me.id }).populate('listing')).filter(r => r.listing);
  if (!rows.length) throw bad('Your cart is empty');
  for (const r of rows) {
    if (r.listing.seller === me.id && !me.demo) throw bad('You cannot buy your own listing: ' + r.listing.title);
    if (r.qtyKg > r.listing.quantityKg) throw bad('Only ' + r.listing.quantityKg + ' left of ' + r.listing.title);
  }
  // Reserve the stock first with an atomic "only if enough is left" update. If two buyers
  // check out the last stock at the same moment, only one succeeds and the other gets a clear message.
  const reserved = [];
  const release = async () => {
    for (const r of reserved) await Listing.updateOne({ _id: r.listing._id }, { $inc: { quantityKg: r.qtyKg, sales: -1 } });
  };
  for (const r of rows) {
    const ok = await Listing.updateOne(
      { _id: r.listing._id, quantityKg: { $gte: r.qtyKg } },
      { $inc: { quantityKg: -r.qtyKg, sales: 1 } }
    );
    if (!ok.modifiedCount) {
      await release();
      throw bad('Sorry, ' + r.listing.title + ' just sold out or has less stock now. Please update your cart.', 409);
    }
    reserved.push(r);
  }
  const groups = {};
  rows.forEach(r => { (groups[r.listing.seller] = groups[r.listing.seller] || []).push(r); });
  const created = [];
  try {
  for (const sellerId of Object.keys(groups)) {
    const g = groups[sellerId];
    const items = g.map(r => ({
      listing: r.listing._id, title: r.listing.title, sellerId: r.listing.seller,
      sellerName: r.listing.sellerName, qtyKg: r.qtyKg, pricePerKg: r.listing.pricePerKg
    }));
    const subtotal = items.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0);
    const order = await Order.create({
      sellerPhone: g[0].listing.sellerPhone || '',
      number: await nextNumber('order', Order, 1040), owner: me.id, buyerName: me.name,
      seller: sellerId, sellerName: g[0].listing.sellerName, sellerRole: g[0].listing.sellerRole,
      items, subtotal, delivery: fee, total: subtotal + fee, payment,
      paymentStatus: payment === 'Cash' ? 'cod_pending' : 'awaiting_proof', checkoutId,
      receiverName, phone, city, deliveryType, note: String(b.note || '').slice(0, 300),
      address: address + ', ' + city, status: 'placed', history: [{ status: 'placed', at: new Date() }],
      courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: DELIVERY[deliveryType].eta
    });
    created.push(order);
    await notify(sellerId, 'New order #' + order.number, me.name + ' ordered ' + items.map(i => i.title + ' ' + i.qtyKg).join(', '), 'order', String(order._id));
  }
  } catch (e) {
    // something failed half way: undo the orders and give the stock back
    await Order.deleteMany({ _id: { $in: created.map(o => o._id) } });
    await release();
    throw e;
  }
  await CartItem.deleteMany({ owner: me.id });
  const first = orderOut(created[0]);
  first.orders = created.map(orderOut);
  first.orderCount = created.length;
  first.grandTotal = created.reduce((a, o) => a + o.total, 0);
  first.account = payAccount();
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
  if (to === 'confirmed' && ['awaiting_proof', 'under_review', 'rejected'].includes(o.paymentStatus)) {
    throw bad('Verify the payment before confirming this order');
  }
  if (to === 'delivered') {
    o.eta = 'Delivered';
    if (o.paymentStatus === 'cod_pending') o.paymentStatus = 'paid'; // cash collected on delivery
    await Profile.updateOne({ user: o.seller }, { $inc: { completed: 1 } });
  }
  await o.save();
  await notify(o.owner, 'Order #' + o.number + ': ' + LABELS[STEPS.indexOf(to)], 'Your order status changed.', 'order', String(o._id));
  res.json(orderOut(o));
}));

// buyer rates the order after delivery: one review for every product in it
router.post('/orders/:id/review', h(async (req, res) => {
  const { Review } = require('../../models/social');
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (o.owner !== req.me.id) throw bad('Not your order', 403);
  if (o.status !== 'delivered') throw bad('You can rate after the order is delivered');
  if (o.reviewed) throw bad('You already rated this order');
  const b = req.body || {};
  const rating = Math.round(Number(b.rating));
  if (!(rating >= 1 && rating <= 5)) throw bad('Choose 1 to 5 stars');
  const text = String(b.text || '').trim().slice(0, 500);
  for (const it of o.items) {
    if (!it.listing) continue;
    try {
      await Review.create({ listing: it.listing, order: o._id, user: req.me.id, name: req.me.name, rating, text });
    } catch (e) {
      if (e.code === 11000) continue; // already reviewed
      throw e;
    }
    // running average, so older ratings keep their weight
    const l = await Listing.findById(it.listing);
    if (l) {
      const n = l.reviews || 0;
      l.rating = Math.round((((l.rating || 0) * n + rating) / (n + 1)) * 10) / 10;
      l.reviews = n + 1;
      await l.save();
    }
  }
  o.reviewed = true;
  o.myRating = rating;
  await o.save();
  await notify(o.seller, 'New ' + rating + '-star review', req.me.name + ' rated order #' + o.number + (text ? ': ' + text.slice(0, 60) : ''), 'order', String(o._id));
  res.json(orderOut(o));
}));

// buyer cancels a pending order
router.post('/orders/:id/cancel', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (o.owner !== req.me.id) throw bad('Not your order', 403);
  if (o.status !== 'placed') throw bad('Only pending orders can be cancelled');
  if (['under_review', 'paid'].includes(o.paymentStatus)) throw bad('You have already paid. Please chat with the seller to cancel and get a refund.');
  await cancelOrder(o);
  await notify(o.seller, 'Order #' + o.number + ' cancelled', o.buyerName + ' cancelled the order.', 'order', String(o._id));
  res.json(orderOut(o));
}));

// (the old 'advance' demo shortcut was removed: only the seller moves an order forward, via /orders/:id/status)

module.exports = router;