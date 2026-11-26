const express = require('express');
const { Crop, Order } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');

const { cleanPhotos } = require('../../utils/uploads');
const { num } = require('../../utils/geo');
const { planFor, buildTasks, whenText } = require('../../utils/cropPlans');
const router = express.Router();
const STAGES = ['Sowing', 'Sprout', 'Tillering', 'Heading', 'Harvest'];

const DAY = 864e5;

router.get('/dashboard', h(async (req, res) => {
  const me = req.me;
  const { Notification } = require('../../models/agri');
  const { Offer } = require('../../models/offer');
  const { MachineBooking } = require('../../models/machinery');
  const { StorageBooking } = require('../../models/warehouse');
  const now = Date.now();

  const [crops, sold, bought, offersToAnswer, machineActive, stored, unread] = await Promise.all([
    Crop.find({ owner: me.id }).sort({ createdAt: -1 }),
    Order.find({ 'items.sellerId': me.id, status: { $ne: 'cancelled' } }).sort({ createdAt: -1 }),
    Order.find({ owner: me.id, status: { $nin: ['cancelled', 'delivered'] } }).sort({ createdAt: -1 }),
    Offer.countDocuments({ $or: [{ seller: me.id, status: 'pending' }, { buyer: me.id, status: 'countered' }] }),
    MachineBooking.find({ farmer: me.id, status: { $in: ['requested', 'accepted', 'in_progress'] } }).sort({ startAt: 1 }),
    StorageBooking.find({ farmer: me.id, status: { $in: ['approved', 'stored'] } }),
    me.demo ? 0 : Notification.countDocuments({ user: me.id, read: false })
  ]);

  // ---- earnings: total, last 30 days vs the 30 before, and a 7-day chart
  const mine = o => o.items.filter(i => i.sellerId === me.id).reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0);
  let earnings = 0, last30 = 0, prev30 = 0;
  const week = Array.from({ length: 7 }, (_, i) => {
    const d = new Date(now - (6 - i) * DAY);
    return { day: d.toLocaleDateString('en-US', { weekday: 'short' }), date: d.toISOString().slice(0, 10), amount: 0 };
  });
  sold.forEach(o => {
    const amt = mine(o);
    const age = now - new Date(o.createdAt).getTime();
    earnings += amt;
    if (age < 30 * DAY) last30 += amt;
    else if (age < 60 * DAY) prev30 += amt;
    const w = week.find(x => x.date === new Date(o.createdAt).toISOString().slice(0, 10));
    if (w) w.amount += amt;
  });
  const changePct = prev30 > 0 ? Math.round(((last30 - prev30) / prev30) * 1000) / 10 : null;

  // ---- crops and the next open tasks
  const health = crops.length ? Math.round(crops.reduce((a, c) => a + (c.health || 0), 0) / crops.length) : 0;
  const tasks = [];
  crops.forEach(c => c.tasks.forEach(t => {
    if (!t.done) tasks.push({ cropId: String(c._id), taskId: String(t._id), crop: c.name, title: t.title, when: t.due ? whenText(t.due) : t.when, due: t.due || null, type: t.type, field: t.field });
  }));
  // nearest first; tasks far in the past (overdue > 2 weeks) are dropped from the dashboard
  const soon = Date.now() + 14 * 864e5;
  tasks.sort((a, b) => (a.due ? new Date(a.due) : soon) - (b.due ? new Date(b.due) : soon));
  for (let i = tasks.length - 1; i >= 0; i--) if (tasks[i].due && new Date(tasks[i].due) < Date.now() - 14 * 864e5) tasks.splice(i, 1);
  const nextIrrigation = (tasks.find(t => /irrigat/i.test(t.title)) || {}).when || 'None';
  const cropCards = crops.slice(0, 6).map(c => {
    const x = cropOut(c);
    return { id: x.id, name: x.name, variety: x.variety, stage: x.stage, progress: x.progress, health: x.health, photo: (x.photos || [])[0] || '', dayNumber: x.dayNumber, totalDays: x.totalDays };
  });

  // ---- things waiting for this user
  const attention = [];
  bought.filter(o => ['awaiting_proof', 'rejected'].includes(o.paymentStatus)).slice(0, 3).forEach(o => attention.push({
    kind: 'order', id: String(o._id), icon: 'payment',
    title: o.paymentStatus === 'rejected' ? 'Payment rejected for order #' + o.number : 'Pay for order #' + o.number,
    sub: 'Rs ' + o.total + ' · upload the Easypaisa screenshot'
  }));
  sold.filter(o => o.paymentStatus === 'under_review').slice(0, 3).forEach(o => attention.push({
    kind: 'order', id: String(o._id), icon: 'verify',
    title: 'Verify payment for order #' + o.number, sub: o.buyerName + ' uploaded a screenshot'
  }));
  sold.filter(o => o.status === 'placed' && o.paymentStatus !== 'under_review').slice(0, 3).forEach(o => attention.push({
    kind: 'order', id: String(o._id), icon: 'order',
    title: 'New order #' + o.number + ' to confirm', sub: o.buyerName + ' · Rs ' + mine(o)
  }));
  if (offersToAnswer) attention.push({ kind: 'offers', id: '', icon: 'offer', title: offersToAnswer + ' offer(s) waiting for your reply', sub: 'Accept, reject or counter' });
  machineActive.filter(b => b.status === 'accepted' && b.paymentStatus !== 'paid' && b.paymentStatus !== 'under_review').slice(0, 2).forEach(b => attention.push({
    kind: 'machine', id: String(b._id), icon: 'payment', title: 'Pay for ' + b.machineName, sub: 'Booking #' + b.number + ' was accepted'
  }));
  const nextMachine = machineActive.find(b => b.status !== 'requested' && b.startAt && new Date(b.startAt).getTime() > now - DAY);

  res.json({
    name: me.name, earnings, last30, changePct, week, cropHealth: health, nextIrrigation,
    counts: { crops: crops.length, tasks: tasks.length, bookings: machineActive.length, stored: stored.length, offers: offersToAnswer, purchases: bought.length, unread },
    storedTons: Math.round(stored.reduce((a, b) => a + (b.status === 'stored' ? b.currentTons : b.quantityTons), 0) * 10) / 10,
    nextMachine: nextMachine ? { id: String(nextMachine._id), name: nextMachine.machineName, startAt: nextMachine.startAt, status: nextMachine.status } : null,
    crops: cropCards, tasks: tasks.slice(0, 5), attention: attention.slice(0, 6),
    recentOrders: sold.slice(0, 3).map(o => {
      const its = o.items.filter(i => i.sellerId === me.id);
      return {
        id: String(o._id), number: o.number, buyer: o.buyerName,
        summary: its.map(i => i.title + ' ' + i.qtyKg + ' kg').join(', '),
        total: its.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0), status: o.status, paymentStatus: o.paymentStatus
      };
    })
  });
}));

function cropOut(c) {
  const o = out(c);
  const idx = Math.min(4, Math.floor((o.progress || 0) / 20));
  o.stageIndex = idx;
  o.stage = STAGES[idx];
  o.stages = STAGES;
  o.totalDays = o.durationDays || 110;
  o.dayNumber = o.sowingDate ? Math.max(0, Math.floor((Date.now() - new Date(o.sowingDate).getTime()) / 864e5)) : 0;
  // growth follows the calendar automatically (a farmer can still set it higher by hand)
  const auto = Math.min(100, Math.round((o.dayNumber / o.totalDays) * 100));
  if (auto > (o.progress || 0) && o.status === 'Growing') {
    o.progress = auto;
    const i2 = Math.min(4, Math.floor(auto / 20));
    o.stageIndex = i2;
    o.stage = STAGES[i2];
  }
  const plan = planFor(o.name);
  o.season = plan.seasons;
  o.daysToHarvest = Math.max(0, o.totalDays - o.dayNumber);
  o.tasks = (o.tasks || [])
    .map(t => ({ id: String(t._id), title: t.title, when: t.due ? whenText(t.due) : t.when, due: t.due || null, stage: t.stage || '', field: t.field, type: t.type, done: !!t.done }))
    .sort((a, b) => (a.done - b.done) || ((a.due ? new Date(a.due) : 0) - (b.due ? new Date(b.due) : 0)));
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
  const name = String(b.name).trim();
  const sowing = b.sowingDate ? new Date(b.sowingDate) : new Date();
  if (isNaN(sowing.getTime())) throw bad('Pick a valid sowing date');
  const plan = planFor(name); // smart calendar: full season of tasks with real dates
  const harvest = new Date(sowing.getTime() + plan.days * 864e5);
  const crop = await Crop.create({
    owner: req.me.id, name, variety: b.variety || '', field, areaAcres: area,
    sowingDate: sowing, durationDays: plan.days,
    expectedHarvest: b.expectedHarvest || harvest.toISOString().slice(0, 10),
    status: 'Growing', progress: 0, health: 100, estYieldKg: Math.round(area * plan.yieldPerAcre),
    photos: cleanPhotos(b.photos), lat: num(b.lat), lng: num(b.lng), location: b.location || 'My farm',
    tasks: buildTasks(name, sowing, field)
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
  if (b.photos !== undefined) c.photos = cleanPhotos(b.photos);
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