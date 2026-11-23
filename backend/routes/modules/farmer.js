const express = require('express');
const { Crop, Order } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');

const router = express.Router();
const STAGES = ['Sowing', 'Sprout', 'Tillering', 'Heading', 'Harvest'];

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

module.exports = router;