const express = require('express');
const jwt = require('jsonwebtoken');
const { Crop, Listing, CartItem, Order, Query } = require('../models/agri');

const router = express.Router();
router.use(express.json());

// CORS (needed when the app runs in Chrome)
router.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Who is calling? Uses your existing JWT if sent, otherwise a demo user.
function who(req) {
  try {
    const t = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    if (!t) throw new Error('none');
    const d = jwt.verify(t, process.env.JWT_SECRET || 'secret');
    return { id: String(d.id || d._id || d.userId || d.sub || 'demo'), name: d.name || 'Farmer' };
  } catch (e) {
    return { id: 'demo', name: 'Ali Khan' };
  }
}
router.use((req, res, next) => { req.me = who(req); next(); });

const STEPS = ['placed', 'confirmed', 'picked_up', 'out_for_delivery', 'delivered'];
const STEP_LABELS = ['Order placed', 'Confirmed by farmer', 'Picked up', 'Out for delivery', 'Delivered'];
const STAGES = ['Sowing', 'Sprout', 'Tillering', 'Heading', 'Harvest'];

const h = fn => (req, res) => fn(req, res).catch(e => {
  console.error('API error:', e.message);
  if (e.name === 'CastError') return res.status(404).json({ message: 'Not found' });
  res.status(e.status || 500).json({ message: e.message || 'Server error' });
});
const bad = (msg, status) => { const e = new Error(msg); e.status = status || 400; return e; };
const esc = s => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function out(doc) {
  const o = doc.toObject ? doc.toObject() : doc;
  o.id = String(o._id);
  return o;
}

// ---------- seed demo data (first request only) ----------
let seeded = false;
async function seed() {
  if ((await Listing.countDocuments()) === 0) {
    const until = new Date(Date.now() + 14 * 864e5);
    await Listing.insertMany([
      { seller: 'demo', sellerName: 'Ali Khan', location: 'Harpur, KPK', title: 'Sehar 2006 Wheat', category: 'Grains', grade: 'Grade A', pricePerKg: 120, quantityKg: 2000, availableUntil: until, rating: 4.8, reviews: 124, sales: 48, verified: true, description: 'Freshly harvested, sun-dried wheat. Low moisture, cleaned and ready for milling. Pickup or doorstep delivery.' },
      { seller: 'blair', sellerName: 'Blair Farm', location: 'Murree Road, Rawalpindi', title: 'Fresh Tomato', category: 'Veggies', grade: 'Grade A', pricePerKg: 90, quantityKg: 800, availableUntil: until, rating: 4.8, reviews: 61, sales: 30, verified: true, description: 'Farm-fresh red tomatoes picked this morning. Firm and juicy.' },
      { seller: 'usman', sellerName: 'Usman Farms', location: 'Sheikhupura', title: 'Super Basmati Rice', category: 'Grains', grade: 'Grade A', pricePerKg: 210, quantityKg: 3000, availableUntil: until, rating: 4.9, reviews: 203, sales: 120, verified: true, description: 'Long grain aged Super Basmati. Aromatic and non-sticky.' },
      { seller: 'khan', sellerName: 'Khan Agro', location: 'Faisalabad', title: 'Hybrid Maize Seed', category: 'Seeds', grade: 'Grade A', pricePerKg: 340, quantityKg: 500, availableUntil: until, rating: 4.6, reviews: 38, sales: 22, verified: false, description: 'High-yield hybrid maize seed, treated and certified.' },
      { seller: 'sahiwal', sellerName: 'Sahiwal Orchards', location: 'Sahiwal', title: 'Kinnow Oranges', category: 'Fruits', grade: 'Grade B', pricePerKg: 150, quantityKg: 1200, availableUntil: until, rating: 4.4, reviews: 54, sales: 40, verified: true, description: 'Sweet and juicy Kinnow, ideal for juice or direct sale.' },
      { seller: 'agrotools', sellerName: 'AgroTools PK', location: 'Lahore', title: 'Hand Sprayer 16L', category: 'Tools', grade: 'Grade A', pricePerKg: 4500, quantityKg: 40, availableUntil: until, rating: 4.3, reviews: 19, sales: 11, verified: true, description: 'Knapsack sprayer, 16 litre capacity. Price shown per unit.' }
    ]);
  }
  if ((await Crop.countDocuments({ owner: 'demo' })) === 0) {
    const days = n => new Date(Date.now() - n * 864e5);
    await Crop.insertMany([
      { owner: 'demo', name: 'Wheat', variety: 'Sehar 2006', field: 'Field A', areaAcres: 4, sowingDate: days(72), durationDays: 110, expectedHarvest: 'April 2027', status: 'Growing', progress: 68, health: 86, estYieldKg: 1520, tasks: [
        { title: 'Irrigation', when: 'Tomorrow', field: 'Field A', type: 'irrigation' },
        { title: 'Urea top dressing', when: 'In 5 days', field: 'Field A', type: 'fertilizer' } ] },
      { owner: 'demo', name: 'Rice', variety: 'Super Basmati', field: 'Field B', areaAcres: 6, sowingDate: days(120), durationDays: 120, expectedHarvest: 'Ready now', status: 'Ready', progress: 100, health: 92, estYieldKg: 3600, tasks: [] },
      { owner: 'demo', name: 'Maize', variety: 'Hybrid 6525', field: 'Field C', areaAcres: 2.5, sowingDate: days(45), durationDays: 100, expectedHarvest: 'January 2027', status: 'Growing', progress: 45, health: 80, estYieldKg: 1250, tasks: [
        { title: 'Irrigation', when: 'In 3 days', field: 'Field C', type: 'irrigation' } ] },
      { owner: 'demo', name: 'Potato', variety: 'Cardinal', field: 'Field D', areaAcres: 1.5, sowingDate: days(18), durationDays: 90, expectedHarvest: 'February 2027', status: 'Growing', progress: 20, health: 88, estYieldKg: 900, tasks: [] }
    ]);
  }
  if ((await Order.countDocuments()) === 0) {
    const wheat = await Listing.findOne({ title: /Sehar/ });
    const tomato = await Listing.findOne({ title: /Tomato/ });
    const hist = n => STEPS.slice(0, n + 1).map((s, i) => ({ status: s, at: new Date(Date.now() - (n - i + 1) * 36e5 * 5) }));
    await Order.insertMany([
      { number: 1038, owner: 'fresh-mart', buyerName: 'Fresh Mart', items: [{ listing: wheat._id, title: 'Sehar 2006 Wheat', sellerId: 'demo', sellerName: 'Ali Khan', qtyKg: 400, pricePerKg: 146 }], subtotal: 58400, delivery: 0, total: 58400, payment: 'Cash', address: 'Blue Area, Islamabad', status: 'delivered', history: hist(4), courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Delivered' },
      { number: 1042, owner: 'fresh-mart', buyerName: 'Fresh Mart', items: [{ listing: wheat._id, title: 'Sehar 2006 Wheat', sellerId: 'demo', sellerName: 'Ali Khan', qtyKg: 200, pricePerKg: 120 }], subtotal: 24000, delivery: 0, total: 24000, payment: 'Cash', address: 'Blue Area, Islamabad', status: 'placed', history: hist(0), courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Tomorrow 4:00 - 6:00 PM' },
      { number: 1041, owner: 'demo', buyerName: 'Ali Khan', items: [{ listing: tomato._id, title: 'Fresh Tomato', sellerId: 'blair', sellerName: 'Blair Farm', qtyKg: 50, pricePerKg: 90 }], subtotal: 4500, delivery: 500, total: 5000, payment: 'Cash', address: 'House 12, Street 5, G-11/3, Islamabad', status: 'out_for_delivery', history: hist(3), courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Tomorrow 4:00 - 6:00 PM' }
    ]);
  }
}
router.use(async (req, res, next) => {
  if (!seeded) {
    seeded = true;
    try { await seed(); console.log('AgriSphere demo data ready'); }
    catch (e) { seeded = false; console.error('Seed failed:', e.message); }
  }
  next();
});

// ---------- dashboard ----------
router.get('/dashboard', h(async (req, res) => {
  const me = req.me;
  const crops = await Crop.find({ owner: me.id });
  const sold = await Order.find({ 'items.sellerId': me.id, status: { $ne: 'cancelled' } }).sort({ createdAt: -1 });
  let earnings = 0;
  sold.forEach(o => o.items.forEach(i => { if (i.sellerId === me.id) earnings += i.qtyKg * i.pricePerKg; }));
  const health = crops.length ? Math.round(crops.reduce((a, c) => a + (c.health || 0), 0) / crops.length) : 0;
  let nextIrrigation = 'None';
  crops.forEach(c => c.tasks.forEach(t => { if (!t.done && /irrigat/i.test(t.title) && nextIrrigation === 'None') nextIrrigation = t.when; }));
  const recentOrders = sold.slice(0, 3).map(o => {
    const mine = o.items.filter(i => i.sellerId === me.id);
    return {
      id: String(o._id), number: o.number, buyer: o.buyerName,
      summary: mine.map(i => i.title + ' ' + i.qtyKg + ' kg').join(', '),
      total: mine.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0), status: o.status
    };
  });
  res.json({ name: me.name, earnings, changePct: 12.4, cropHealth: health, nextIrrigation, recentOrders });
}));

// ---------- crops ----------
function cropOut(c) {
  const o = out(c);
  const idx = Math.min(4, Math.floor((o.progress || 0) / 20));
  o.stageIndex = idx;
  o.stage = STAGES[idx];
  o.stages = STAGES;
  o.totalDays = o.durationDays || 110;
  o.dayNumber = o.sowingDate ? Math.max(0, Math.floor((Date.now() - new Date(o.sowingDate).getTime()) / 864e5)) : 0;
  o.tasks = (o.tasks || []).map(t => ({ id: String(t._id), title: t.title, when: t.when, field: t.field, type: t.type, done: !!t.done }));
  return o;
}

router.get('/crops', h(async (req, res) => {
  const list = await Crop.find({ owner: req.me.id }).sort({ createdAt: -1 });
  res.json({
    stats: { total: list.length, growing: list.filter(c => c.status === 'Growing').length, ready: list.filter(c => c.status === 'Ready').length },
    items: list.map(cropOut)
  });
}));

router.get('/crops/:id', h(async (req, res) => {
  const c = await Crop.findOne({ _id: req.params.id, owner: req.me.id });
  if (!c) throw bad('Crop not found', 404);
  res.json(cropOut(c));
}));

router.post('/crops', h(async (req, res) => {
  const b = req.body || {};
  if (!b.name || !String(b.name).trim()) throw bad('Crop name is required');
  const area = Number(b.areaAcres);
  if (!area || area <= 0) throw bad('Enter land area in acres');
  const field = b.field || 'Field A';
  const crop = await Crop.create({
    owner: req.me.id, name: String(b.name).trim(), variety: b.variety || '', field, areaAcres: area,
    sowingDate: b.sowingDate ? new Date(b.sowingDate) : new Date(), expectedHarvest: b.expectedHarvest || '',
    status: 'Growing', progress: 0, health: 100, estYieldKg: Math.round(area * 380),
    tasks: [
      { title: 'Irrigation', when: 'In 3 days', field, type: 'irrigation' },
      { title: 'Fertilizer application', when: 'In 15 days', field, type: 'fertilizer' }
    ]
  });
  res.status(201).json(cropOut(crop));
}));

router.patch('/crops/:id', h(async (req, res) => {
  const c = await Crop.findOne({ _id: req.params.id, owner: req.me.id });
  if (!c) throw bad('Crop not found', 404);
  const b = req.body || {};
  if (b.progress !== undefined) c.progress = Math.max(0, Math.min(100, Number(b.progress)));
  if (b.health !== undefined) c.health = Math.max(0, Math.min(100, Number(b.health)));
  if (b.status) c.status = b.status;
  if (c.progress >= 100 && c.status === 'Growing') c.status = 'Ready';
  await c.save();
  res.json(cropOut(c));
}));

router.post('/crops/:id/tasks/:tid/toggle', h(async (req, res) => {
  const c = await Crop.findOne({ _id: req.params.id, owner: req.me.id });
  if (!c) throw bad('Crop not found', 404);
  const t = c.tasks.id(req.params.tid);
  if (!t) throw bad('Task not found', 404);
  t.done = !t.done;
  await c.save();
  res.json(cropOut(c));
}));

router.delete('/crops/:id', h(async (req, res) => {
  await Crop.deleteOne({ _id: req.params.id, owner: req.me.id });
  res.json({ ok: true });
}));

// ---------- marketplace ----------
router.get('/listings', h(async (req, res) => {
  const f = { quantityKg: { $gt: 0 } };
  if (req.query.category && req.query.category !== 'All') f.category = new RegExp('^' + esc(req.query.category) + '$', 'i');
  if (req.query.q) { const r = new RegExp(esc(req.query.q), 'i'); f.$or = [{ title: r }, { sellerName: r }, { category: r }]; }
  if (req.query.mine === '1') f.seller = req.me.id;
  const list = await Listing.find(f).sort({ createdAt: -1 }).limit(60);
  res.json({ items: list.map(out) });
}));

router.get('/listings/:id', h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l) throw bad('Listing not found', 404);
  res.json(out(l));
}));

router.post('/listings', h(async (req, res) => {
  const b = req.body || {};
  if (!b.title || !String(b.title).trim()) throw bad('Enter the crop / produce name');
  const qty = Number(b.quantityKg), price = Number(b.pricePerKg);
  if (!qty || qty <= 0) throw bad('Enter a valid quantity');
  if (!price || price <= 0) throw bad('Enter a valid price per kg');
  const l = await Listing.create({
    seller: req.me.id, sellerName: req.me.name, location: b.location || 'Islamabad',
    title: String(b.title).trim(), category: b.category || 'Grains', grade: b.grade || 'Grade A',
    pricePerKg: price, quantityKg: qty, availableUntil: b.availableUntil ? new Date(b.availableUntil) : undefined,
    description: b.description || '', verified: true, rating: 4.5
  });
  res.status(201).json(out(l));
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

// ---------- cart ----------
async function cartOut(owner) {
  const rows = await CartItem.find({ owner }).populate('listing');
  const items = rows.filter(r => r.listing).map(r => ({
    id: String(r._id), listingId: String(r.listing._id), title: r.listing.title, category: r.listing.category,
    sellerName: r.listing.sellerName, pricePerKg: r.listing.pricePerKg, qtyKg: r.qtyKg,
    maxKg: r.listing.quantityKg, amount: r.qtyKg * r.listing.pricePerKg
  }));
  const subtotal = items.reduce((a, i) => a + i.amount, 0);
  const delivery = items.length ? 500 : 0;
  return { items, subtotal, delivery, total: subtotal + delivery, farmers: new Set(items.map(i => i.sellerName)).size };
}

router.get('/cart', h(async (req, res) => { res.json(await cartOut(req.me.id)); }));

router.post('/cart', h(async (req, res) => {
  const { listingId } = req.body || {};
  const qty = Math.max(1, Number((req.body || {}).qtyKg) || 10);
  const l = await Listing.findById(listingId);
  if (!l) throw bad('Listing not found', 404);
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
  if (!q || q < 10) throw bad('Minimum quantity is 10 kg');
  row.qtyKg = Math.min(q, row.listing ? row.listing.quantityKg : q);
  await row.save();
  res.json(await cartOut(req.me.id));
}));

router.delete('/cart/:id', h(async (req, res) => {
  await CartItem.deleteOne({ _id: req.params.id, owner: req.me.id });
  res.json(await cartOut(req.me.id));
}));

// ---------- orders ----------
function orderOut(o) {
  const x = out(o);
  const idx = Math.max(0, STEPS.indexOf(x.status));
  x.statusIndex = idx;
  x.steps = STEPS.map((s, i) => {
    const hItem = (x.history || []).find(z => z.status === s);
    return { key: s, label: STEP_LABELS[i], done: i <= idx, at: hItem ? hItem.at : null };
  });
  x.summary = (x.items || []).map(i => i.title + ' ' + i.qtyKg + ' kg').join(', ');
  return x;
}
const canSee = (o, id) => o.owner === id || o.items.some(i => i.sellerId === id);

router.get('/orders', h(async (req, res) => {
  const list = await Order.find({ owner: req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(orderOut) });
}));

router.get('/orders/:id', h(async (req, res) => {
  const o = await Order.findById(req.params.id);
  if (!o) throw bad('Order not found', 404);
  if (!canSee(o, req.me.id)) throw bad('Not allowed', 403);
  res.json(orderOut(o));
}));

router.post('/orders', h(async (req, res) => {
  const b = req.body || {};
  const payment = ['Cash', 'Card', 'JazzCash'].includes(b.payment) ? b.payment : 'Cash';
  const rows = (await CartItem.find({ owner: req.me.id }).populate('listing')).filter(r => r.listing);
  if (!rows.length) throw bad('Your cart is empty');
  const items = rows.map(r => ({
    listing: r.listing._id, title: r.listing.title, sellerId: r.listing.seller,
    sellerName: r.listing.sellerName, qtyKg: r.qtyKg, pricePerKg: r.listing.pricePerKg
  }));
  const subtotal = items.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0);
  const delivery = 500;
  const last = await Order.findOne().sort({ number: -1 });
  const order = await Order.create({
    number: (last && last.number ? last.number : 1040) + 1, owner: req.me.id, buyerName: req.me.name, items,
    subtotal, delivery, total: subtotal + delivery, payment,
    address: b.address || 'Islamabad', status: 'placed', history: [{ status: 'placed', at: new Date() }],
    courier: { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' }, eta: 'Tomorrow 4:00 - 6:00 PM'
  });
  for (const r of rows) await Listing.updateOne({ _id: r.listing._id }, { $inc: { quantityKg: -r.qtyKg, sales: 1 } });
  await CartItem.deleteMany({ owner: req.me.id });
  res.status(201).json(orderOut(order));
}));

// demo helper: moves an order to its next status
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

// ---------- ask an expert ----------
router.get('/queries', h(async (req, res) => {
  const list = await Query.find({ owner: req.me.id }).sort({ createdAt: -1 }).limit(20);
  res.json({ expertsOnline: 12, avgReplyHours: 2, items: list.map(out) });
}));

router.post('/queries', h(async (req, res) => {
  const b = req.body || {};
  if (!b.subject || !String(b.subject).trim()) throw bad('Enter a subject');
  if (!b.details || String(b.details).trim().length < 10) throw bad('Describe the problem (at least 10 characters)');
  const q = await Query.create({ owner: req.me.id, category: b.category || 'Crop disease', subject: String(b.subject).trim(), details: String(b.details).trim() });
  res.status(201).json(out(q));
}));

module.exports = router;