const express = require('express');
const { Listing, Order } = require('../../models/agri');
const { Offer } = require('../../models/offer');
const { h, bad, out } = require('../../utils/http');
const { loggedIn, notify } = require('../../utils/identity');

const router = express.Router();
const DELIVERY = 500;
const MAX_ROUNDS = 8;
const num = (v) => Number(v) || 0;
const text = (v, max = 200) => String(v === undefined || v === null ? '' : v).trim().slice(0, max);

function offerOut(o, me) {
  const x = out(o);
  x.total = Math.round(x.qtyKg * x.pricePerKg);
  x.iAmSeller = x.seller === me;
  x.waitingFor = x.status === 'pending' ? 'seller' : (x.status === 'countered' ? 'buyer' : '');
  x.canAnswer = (x.status === 'pending' && x.seller === me) || (x.status === 'countered' && x.buyer === me);
  return x;
}

async function makeOrder(o) {
  const l = await Listing.findById(o.listing);
  if (!l || l.status === 'removed') throw bad('This listing is no longer available');
  if (l.quantityKg < o.qtyKg) throw bad('Only ' + l.quantityKg + ' kg is left. Counter with a smaller quantity.');
  const last = await Order.findOne().sort({ number: -1 });
  const number = (last && last.number ? last.number : 1040) + 1;
  const subtotal = Math.round(o.qtyKg * o.pricePerKg);
  const order = await Order.create({
    number, owner: o.buyer, buyerName: o.buyerName, seller: o.seller, sellerName: o.sellerName, sellerRole: l.sellerRole,
    items: [{ listing: l._id, title: l.title, sellerId: o.seller, sellerName: o.sellerName, qtyKg: o.qtyKg, pricePerKg: o.pricePerKg }],
    subtotal, delivery: DELIVERY, total: subtotal + DELIVERY, payment: 'Cash', address: o.address || 'Islamabad',
    status: 'confirmed', history: [{ status: 'placed', at: new Date() }, { status: 'confirmed', at: new Date() }],
    courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Pickup to be arranged'
  });
  await Listing.updateOne({ _id: l._id }, { $inc: { quantityKg: -o.qtyKg, sales: 1 } });
  o.status = 'accepted';
  o.order = String(order._id);
  return order;
}

// buyer makes an offer
router.post('/listings/:id/offers', loggedIn, h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l || l.status !== 'active') throw bad('Listing not found', 404);
  if (l.kind !== 'produce') throw bad('Offers are only for farmer produce');
  if (l.seller === req.me.id) throw bad('You cannot make an offer on your own listing');
  const b = req.body || {};
  const price = num(b.pricePerKg);
  const qty = num(b.qtyKg);
  if (price <= 0) throw bad('Enter your offer price per kg');
  if (qty < 10) throw bad('Minimum quantity is 10 kg');
  if (qty > l.quantityKg) throw bad('Only ' + l.quantityKg + ' kg is available');
  const dup = await Offer.findOne({ listing: l._id, buyer: req.me.id, status: { $in: ['pending', 'countered'] } });
  if (dup) throw bad('You already have an open offer on this listing');
  const o = await Offer.create({
    listing: l._id, listingTitle: l.title, listPrice: l.pricePerKg, seller: l.seller, sellerName: l.sellerName,
    buyer: req.me.id, buyerName: req.me.name, qtyKg: qty, pricePerKg: price, address: text(b.address, 160),
    status: 'pending', rounds: [{ by: 'buyer', pricePerKg: price, note: text(b.message), at: new Date() }]
  });
  await notify(l.seller, 'New offer', `${req.me.name} offered Rs ${price}/kg for ${qty} kg of ${l.title}`, 'offer', String(o._id));
  res.status(201).json(offerOut(o, req.me.id));
}));

router.get('/offers', loggedIn, h(async (req, res) => {
  const me = req.me.id;
  const f = req.query.box === 'received' ? { seller: me } : { buyer: me };
  if (req.query.status === 'open') f.status = { $in: ['pending', 'countered'] };
  const list = await Offer.find(f).sort({ updatedAt: -1 }).limit(80);
  res.json({ items: list.map(o => offerOut(o, me)) });
}));

router.get('/offers/:id', loggedIn, h(async (req, res) => {
  const o = await Offer.findById(req.params.id);
  if (!o || (o.seller !== req.me.id && o.buyer !== req.me.id)) throw bad('Offer not found', 404);
  res.json(offerOut(o, req.me.id));
}));

// seller or buyer answers (whoever the offer is waiting for)
router.patch('/offers/:id/respond', loggedIn, h(async (req, res) => {
  const o = await Offer.findById(req.params.id);
  if (!o) throw bad('Offer not found', 404);
  const me = req.me.id;
  const isSeller = o.seller === me;
  const isBuyer = o.buyer === me;
  if (!isSeller && !isBuyer) throw bad('Offer not found', 404);
  const turn = o.status === 'pending' ? 'seller' : (o.status === 'countered' ? 'buyer' : '');
  if (!turn) throw bad('This offer is already closed');
  if ((turn === 'seller' && !isSeller) || (turn === 'buyer' && !isBuyer)) throw bad('Waiting for the other side to answer');
  const b = req.body || {};
  const other = isSeller ? o.buyer : o.seller;

  if (b.action === 'accept') {
    const order = await makeOrder(o);
    await o.save();
    await notify(other, 'Offer accepted', `Deal agreed for ${o.listingTitle} at Rs ${o.pricePerKg}/kg. Order #${order.number} created`, 'offer', String(o._id));
    return res.json(offerOut(o, me));
  }
  if (b.action === 'reject') {
    o.status = 'rejected';
    o.rounds.push({ by: isSeller ? 'seller' : 'buyer', pricePerKg: o.pricePerKg, note: text(b.note) || 'Rejected', at: new Date() });
    await o.save();
    await notify(other, 'Offer declined', `Offer on ${o.listingTitle} was declined`, 'offer', String(o._id));
    return res.json(offerOut(o, me));
  }
  if (b.action === 'counter') {
    const price = num(b.pricePerKg);
    if (price <= 0) throw bad('Enter your counter price per kg');
    if (o.rounds.length >= MAX_ROUNDS) throw bad('Too many rounds. Please accept or decline.');
    const qty = b.qtyKg ? num(b.qtyKg) : o.qtyKg;
    if (qty < 10) throw bad('Minimum quantity is 10 kg');
    o.pricePerKg = price;
    o.qtyKg = qty;
    o.status = isSeller ? 'countered' : 'pending';
    o.rounds.push({ by: isSeller ? 'seller' : 'buyer', pricePerKg: price, note: text(b.note), at: new Date() });
    await o.save();
    await notify(other, 'Counter offer', `${req.me.name} proposed Rs ${price}/kg for ${o.listingTitle}`, 'offer', String(o._id));
    return res.json(offerOut(o, me));
  }
  throw bad('Choose accept, counter or reject');
}));

router.patch('/offers/:id/cancel', loggedIn, h(async (req, res) => {
  const o = await Offer.findOne({ _id: req.params.id, buyer: req.me.id });
  if (!o) throw bad('Offer not found', 404);
  if (!['pending', 'countered'].includes(o.status)) throw bad('This offer is already closed');
  o.status = 'cancelled';
  o.rounds.push({ by: 'buyer', pricePerKg: o.pricePerKg, note: 'Withdrawn', at: new Date() });
  await o.save();
  await notify(o.seller, 'Offer withdrawn', `${o.buyerName} withdrew the offer on ${o.listingTitle}`, 'offer', String(o._id));
  res.json(offerOut(o, req.me.id));
}));

module.exports = router;
