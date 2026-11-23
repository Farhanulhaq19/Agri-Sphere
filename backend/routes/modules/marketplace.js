const express = require('express');
const { Listing } = require('../../models/agri');
const { h, bad, esc, out } = require('../../utils/http');
const { roleIn } = require('../../utils/identity');
const { createListing } = require('../../utils/listings');

const router = express.Router();

router.get('/listings', h(async (req, res) => {
  const f = { quantityKg: { $gt: 0 }, status: { $nin: ['paused', 'removed'] } };
  if (req.query.category && req.query.category !== 'All') f.category = new RegExp('^' + esc(req.query.category) + '$', 'i');
  if (req.query.kind) f.kind = req.query.kind;
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$or = [{ title: r }, { sellerName: r }, { category: r }, { brand: r }];
  }
  if (req.query.mine === '1') f.seller = req.me.id;
  const list = await Listing.find(f).sort({ createdAt: -1 }).limit(60);
  res.json({ items: list.map(out) });
}));

router.get('/listings/:id', h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l) throw bad('Listing not found', 404);
  res.json(out(l));
}));

router.post('/listings', roleIn('farmer', 'supplier'), h(async (req, res) => {
  const l = await createListing(req.me, req.body || {});
  res.status(201).json(out(l));
}));

router.patch('/listings/:id', roleIn('farmer', 'supplier'), h(async (req, res) => {
  const l = await Listing.findOne({ _id: req.params.id, seller: req.me.id });
  if (!l) throw bad('Listing not found', 404);
  const b = req.body || {};
  if (b.pricePerKg !== undefined) l.pricePerKg = Number(b.pricePerKg);
  if (b.quantityKg !== undefined) l.quantityKg = Number(b.quantityKg);
  if (b.status && ['active', 'paused'].includes(b.status)) l.status = b.status;
  if (b.description !== undefined) l.description = b.description;
  if (b.brand !== undefined) l.brand = b.brand;
  await l.save();
  res.json(out(l));
}));

router.delete('/listings/:id', h(async (req, res) => {
  await Listing.deleteOne({ _id: req.params.id, seller: req.me.id });
  res.json({ ok: true });
}));

router.get('/market-average', h(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 3) return res.json({ average: 0, count: 0 });
  const list = await Listing.find({ title: new RegExp(esc(q.split(' ')[0]), 'i') });
  const avg = list.length ? Math.round(list.reduce((a, l) => a + l.pricePerKg, 0) / list.length) : 0;
  res.json({ average: avg, count: list.length });
}));

module.exports = router;