const express = require('express');
const { Warehouse, Labour, StorageBooking, STORAGE_TYPES, FACILITIES } = require('../../models/warehouse');
const { h, bad, esc, out } = require('../../utils/http');
const { requireRole, loggedIn, notify } = require('../../utils/identity');
const { cleanPhotos, readProof } = require('../../utils/uploads');
const { applyDistance } = require('../../utils/geo');
const { requirePhone } = require('../../utils/phone');
const { Profile } = require('../../models/agri');

const router = express.Router();
const owner = requireRole('warehouse_owner');
const HOLDING = ['approved', 'stored'];            // statuses that use up space
const num = (v, d = 0) => (v === undefined || v === null || v === '' ? d : Number(v));
const money = (n) => Math.round(Number(n) || 0);
const text = (v, max = 300) => String(v === undefined || v === null ? '' : v).trim().slice(0, max);
const push = (b, status, note) => b.history.push({ status, at: new Date(), note: note || '' });
const DAY = 24 * 3600 * 1000;

const { nextNumber: seq } = require('../../utils/counter');
const nextNumber = () => seq('storage-booking', StorageBooking, 2000);

async function usedMap(ids) {
  const rows = await StorageBooking.aggregate([
    { $match: { warehouse: { $in: ids }, status: { $in: HOLDING } } },
    { $group: { _id: '$warehouse', tons: { $sum: { $cond: [{ $eq: ['$status', 'stored'] }, '$currentTons', '$quantityTons'] } } } }
  ]);
  const m = {};
  rows.forEach(r => { m[String(r._id)] = r.tons; });
  return m;
}

function whOut(w, used) {
  const x = out(w);
  x.usedTons = Math.round((used[x.id] || 0) * 100) / 100;
  x.availableTons = Math.max(0, Math.round((x.capacityTons - x.usedTons) * 100) / 100);
  x.occupancy = x.capacityTons ? Math.min(100, Math.round((x.usedTons / x.capacityTons) * 100)) : 0;
  return x;
}

function bkOut(b) {
  const x = out(b);
  x.balance = Math.max(0, x.total - (x.paidAmount || 0));
  x.pendingAmount = (x.payments || []).filter(p => p.status === 'under_review').reduce((a, p) => a + p.amount, 0);
  x.canCancel = ['requested', 'approved'].includes(x.status);
  return x;
}

function recalc(b) {
  b.handlingCost = (b.tasks || []).reduce((a, t) => a + (t.charge || 0), 0);
  b.total = money(b.storageCost + b.handlingCost);
}

function whBody(b, partial) {
  const o = {};
  const set = (k, v) => { if (!partial || b[k] !== undefined) o[k] = v; };
  set('name', text(b.name, 80));
  set('city', text(b.city, 60));
  set('address', text(b.address, 160));
  set('capacityTons', num(b.capacityTons));
  set('ratePerTonDay', money(b.ratePerTonDay));
  set('minTons', Math.max(0.1, num(b.minTons, 1)));
  set('description', text(b.description, 600));
  if (!partial || b.storageTypes !== undefined) o.storageTypes = (Array.isArray(b.storageTypes) ? b.storageTypes : []).filter(x => STORAGE_TYPES.includes(x));
  if (!partial || b.facilities !== undefined) o.facilities = (Array.isArray(b.facilities) ? b.facilities : []).map(x => text(x, 40)).filter(Boolean).slice(0, 12);
  if (!partial || b.lat !== undefined) o.lat = b.lat === '' || b.lat == null ? undefined : num(b.lat);
  if (!partial || b.lng !== undefined) o.lng = b.lng === '' || b.lng == null ? undefined : num(b.lng);
  if (!partial || b.photos !== undefined) o.photos = cleanPhotos(b.photos);
  if (b.status === 'active' || b.status === 'paused') o.status = b.status;
  return o;
}

function validateWh(w) {
  if (!w.name || w.name.length < 2) throw bad('Enter the warehouse name');
  if (!w.city) throw bad('Enter the city');
  if (!w.capacityTons || w.capacityTons <= 0) throw bad('Enter the capacity in tons');
  if (!w.ratePerTonDay || w.ratePerTonDay <= 0) throw bad('Enter the rate per ton per day');
  if (!w.storageTypes || !w.storageTypes.length) throw bad('Select at least one storage type');
}

// ================================================================ BROWSE
router.get('/warehouses/options', h(async (req, res) => { res.json({ storageTypes: STORAGE_TYPES, facilities: FACILITIES }); }));

router.get('/warehouses', h(async (req, res) => {
  const f = { status: 'active' };
  if (req.query.city) f.city = new RegExp(esc(req.query.city), 'i');
  if (req.query.type && req.query.type !== 'All') f.storageTypes = req.query.type;
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$or = [{ name: r }, { city: r }, { address: r }];
  }
  if (!req.me.demo) f.owner = { $ne: req.me.id };
  let sort = { createdAt: -1 };
  if (req.query.sort === 'price') sort = { ratePerTonDay: 1 };
  if (req.query.sort === 'rating') sort = { rating: -1 };
  const list = await Warehouse.find(f).sort(sort).limit(60);
  const used = await usedMap(list.map(w => w._id));
  let items = list.map(w => whOut(w, used));
  if (req.query.minTons) items = items.filter(i => i.availableTons >= num(req.query.minTons));
  res.json({ items: applyDistance(items, req.query) });
}));

router.get('/warehouses/:id', h(async (req, res) => {
  const w = await Warehouse.findById(req.params.id);
  if (!w) throw bad('Warehouse not found', 404);
  const used = await usedMap([w._id]);
  const x = whOut(w, used);
  x.isMine = !req.me.demo && w.owner === req.me.id;
  res.json(x);
}));

// ================================================================ REQUEST SPACE (any logged-in user)
router.post('/warehouses/:id/request', loggedIn, h(async (req, res) => {
  const w = await Warehouse.findById(req.params.id);
  if (!w) throw bad('Warehouse not found', 404);
  if (w.owner === req.me.id) throw bad('This is your own warehouse');
  if (w.status !== 'active') throw bad('This warehouse is not taking bookings right now');
  const b = req.body || {};
  const crop = text(b.crop, 60);
  const tons = num(b.quantityTons);
  const days = Math.round(num(b.days));
  const start = new Date(b.startDate);
  if (!crop) throw bad('Enter the crop you want to store');
  if (!tons || tons < w.minTons) throw bad('Minimum quantity is ' + w.minTons + ' ton(s)');
  if (days < 1 || days > 365) throw bad('Storage period must be 1 to 365 days');
  if (isNaN(start.getTime())) throw bad('Pick the date you will bring the crop');
  if (start.getTime() < Date.now() - DAY) throw bad('Start date is in the past');
  const storageType = w.storageTypes.includes(b.storageType) ? b.storageType : w.storageTypes[0];
  const used = await usedMap([w._id]);
  const free = w.capacityTons - (used[String(w._id)] || 0);
  if (tons > free) throw bad('Only ' + Math.max(0, Math.round(free * 100) / 100) + ' tons of space are free');
  const bk = new StorageBooking({
    number: await nextNumber(), warehouse: w._id, warehouseName: w.name, city: w.city, owner: w.owner, ownerName: w.ownerName,
    farmer: req.me.id, farmerName: req.me.name, farmerPhone: text(b.phone, 20) || req.me.phone || '',
    crop, quantityTons: tons, storageType, startDate: start, days, endDate: new Date(start.getTime() + days * DAY),
    rate: w.ratePerTonDay, storageCost: money(tons * days * w.ratePerTonDay), needLoading: !!b.needLoading,
    notes: text(b.notes, 300), status: 'requested', history: []
  });
  recalc(bk);
  push(bk, 'requested');
  await bk.save();
  await notify(w.owner, 'New storage request', `${req.me.name} wants to store ${tons} t of ${crop} in ${w.name}`, 'warehouse', String(bk._id));
  res.status(201).json(bkOut(bk));
}));

// ================================================================ MY STORAGE (farmer side: monitor stock)
router.get('/storage-bookings/mine', loggedIn, h(async (req, res) => {
  const f = { farmer: req.me.id };
  if (req.query.status === 'active') f.status = { $in: ['requested', 'approved', 'stored'] };
  if (req.query.status === 'past') f.status = { $in: ['released', 'rejected', 'cancelled'] };
  const list = await StorageBooking.find(f).sort({ createdAt: -1 }).limit(80);
  res.json({ items: list.map(bkOut) });
}));

router.get('/storage-bookings/:id', loggedIn, h(async (req, res) => {
  const b = await StorageBooking.findById(req.params.id);
  if (!b || (b.farmer !== req.me.id && b.owner !== req.me.id)) throw bad('Booking not found', 404);
  res.json(bkOut(b));
}));

router.patch('/storage-bookings/:id/cancel', loggedIn, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (!['requested', 'approved'].includes(b.status)) throw bad('This booking can no longer be cancelled');
  if (b.paidAmount > 0) throw bad('You have already paid. Contact the warehouse owner.');
  b.status = 'cancelled';
  push(b, 'cancelled', 'Cancelled by farmer');
  await b.save();
  await notify(b.owner, 'Storage request cancelled', `${b.farmerName} cancelled the request for ${b.warehouseName}`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

router.post('/storage-bookings/:id/pay', loggedIn, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (!['approved', 'stored', 'released'].includes(b.status)) throw bad('You can pay once the warehouse approves');
  const pending = b.payments.filter(p => p.status === 'under_review').reduce((a, p) => a + p.amount, 0);
  const balance = b.total - b.paidAmount - pending;
  if (balance <= 0) throw bad(pending ? 'Your payment is being verified by the owner' : 'Nothing left to pay');
  const amount = Math.min(balance, money((req.body || {}).amount) || balance);
  if (amount <= 0) throw bad('Enter a valid amount');
  const method = ['Cash', 'Easypaisa', 'Card'].includes((req.body || {}).method) ? req.body.method : 'Cash';
  if (method === 'Cash') {
    await notify(b.owner, 'Cash payment', `${b.farmerName} will pay Rs ${amount} in cash for ${b.warehouseName}`, 'warehouse', String(b._id));
    return res.json(bkOut(b));
  }
  const p = readProof(req.body);
  b.payments.push({ amount, method, at: new Date(), note: '', status: 'under_review', proof: p.url, ref: p.ref });
  await b.save();
  await notify(b.owner, 'Payment proof received', `${b.farmerName} sent Rs ${amount} via ${method} for ${b.warehouseName}. Please verify.`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

// owner approves / rejects one online payment
router.patch('/storage-bookings/:id/payments/:pid', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  const p = b.payments.id(req.params.pid);
  if (!p || p.status !== 'under_review') throw bad('There is no payment waiting for review');
  const ok = (req.body || {}).action === 'approve';
  p.status = ok ? 'approved' : 'rejected';
  p.note = ok ? 'Verified by owner' : text((req.body || {}).reason, 200) || 'Payment could not be verified';
  if (ok) b.paidAmount += p.amount;
  await b.save();
  await notify(b.farmer, ok ? 'Payment verified' : 'Payment rejected',
    ok ? `Rs ${p.amount} for ${b.warehouseName} was verified` : `${p.note}. Please upload a correct screenshot.`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

router.post('/storage-bookings/:id/rate', loggedIn, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'released') throw bad('You can rate after your crop is released');
  if (b.rating) throw bad('You already rated this booking');
  const r = Math.round(num((req.body || {}).rating));
  if (r < 1 || r > 5) throw bad('Rating must be 1 to 5');
  b.rating = r;
  b.review = text((req.body || {}).review, 300);
  await b.save();
  const w = await Warehouse.findById(b.warehouse);
  if (w) {
    w.rating = Math.round(((w.rating * w.ratingCount + r) / (w.ratingCount + 1)) * 10) / 10;
    w.ratingCount += 1;
    await w.save();
  }
  res.json(bkOut(b));
}));

// ================================================================ OWNER: dashboard & warehouses
router.get('/warehouse-owner/dashboard', owner, h(async (req, res) => {
  const id = req.me.id;
  const [whs, labour, bookings] = await Promise.all([
    Warehouse.find({ owner: id }), Labour.countDocuments({ owner: id }), StorageBooking.find({ owner: id }).sort({ createdAt: -1 })
  ]);
  const used = await usedMap(whs.map(w => w._id));
  const cap = whs.reduce((a, w) => a + w.capacityTons, 0);
  const usedT = whs.reduce((a, w) => a + (used[String(w._id)] || 0), 0);
  const earned = bookings.reduce((a, b) => a + (b.paidAmount || 0), 0);
  const due = bookings.filter(b => ['approved', 'stored', 'released'].includes(b.status)).reduce((a, b) => a + Math.max(0, b.total - b.paidAmount), 0);
  res.json({
    name: req.me.name,
    warehouses: whs.length,
    capacityTons: cap,
    usedTons: Math.round(usedT * 100) / 100,
    occupancy: cap ? Math.min(100, Math.round((usedT / cap) * 100)) : 0,
    labour,
    pendingRequests: bookings.filter(b => b.status === 'requested').length,
    storedLots: bookings.filter(b => b.status === 'stored').length,
    pendingTasks: bookings.reduce((a, b) => a + (b.tasks || []).filter(t => t.status === 'scheduled').length, 0),
    earnings: earned, outstanding: due,
    recent: bookings.slice(0, 4).map(bkOut)
  });
}));

router.get('/warehouse-owner/warehouses', owner, h(async (req, res) => {
  const list = await Warehouse.find({ owner: req.me.id }).sort({ createdAt: -1 });
  const used = await usedMap(list.map(w => w._id));
  res.json({ items: list.map(w => whOut(w, used)) });
}));

router.post('/warehouse-owner/warehouses', owner, h(async (req, res) => {
  const data = whBody(req.body || {}, false);
  validateWh(data);
  const ownerPhone = await requirePhone(req.me, req.body.phone || req.body.ownerPhone, await Profile.findOne({ user: req.me.id }));
  const w = await Warehouse.create({ ...data, owner: req.me.id, ownerName: req.me.name, ownerPhone });
  res.status(201).json(whOut(w, {}));
}));

router.put('/warehouse-owner/warehouses/:id', owner, h(async (req, res) => {
  const w = await Warehouse.findOne({ _id: req.params.id, owner: req.me.id });
  if (!w) throw bad('Warehouse not found', 404);
  Object.assign(w, whBody(req.body || {}, true));
  if (req.body && (req.body.phone || req.body.ownerPhone)) w.ownerPhone = await requirePhone(req.me, req.body.phone || req.body.ownerPhone);
  validateWh(w);
  const used = await usedMap([w._id]);
  if (w.capacityTons < (used[String(w._id)] || 0)) throw bad('Capacity cannot be less than the stock stored now');
  await w.save();
  res.json(whOut(w, used));
}));

router.delete('/warehouse-owner/warehouses/:id', owner, h(async (req, res) => {
  const w = await Warehouse.findOne({ _id: req.params.id, owner: req.me.id });
  if (!w) throw bad('Warehouse not found', 404);
  const open = await StorageBooking.countDocuments({ warehouse: w._id, status: { $in: ['requested', ...HOLDING] } });
  if (open) throw bad('This warehouse has open bookings or stored stock');
  await Warehouse.deleteOne({ _id: w._id });
  res.json({ ok: true });
}));

// ================================================================ OWNER: labour
router.get('/warehouse-owner/labour', owner, h(async (req, res) => {
  const list = await Labour.find({ owner: req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(out) });
}));

function labourBody(b) {
  const name = text(b.name, 60);
  if (name.length < 2) throw bad('Enter the worker name');
  const phone = text(b.phone, 20).replace(/[\s-]/g, '');
  if (phone && !/^\+?[0-9]{10,14}$/.test(phone)) throw bad('Enter a valid phone number');
  return {
    name, phone, role: ['Loader', 'Unloader', 'Supervisor', 'Driver', 'Guard'].includes(b.role) ? b.role : 'Loader',
    dailyWage: money(b.dailyWage), ...(['available', 'busy', 'off'].includes(b.status) ? { status: b.status } : {})
  };
}

router.post('/warehouse-owner/labour', owner, h(async (req, res) => {
  const l = await Labour.create({ ...labourBody(req.body || {}), owner: req.me.id });
  res.status(201).json(out(l));
}));

router.put('/warehouse-owner/labour/:id', owner, h(async (req, res) => {
  const l = await Labour.findOne({ _id: req.params.id, owner: req.me.id });
  if (!l) throw bad('Worker not found', 404);
  Object.assign(l, labourBody({ ...l.toObject(), ...(req.body || {}) }));
  await l.save();
  res.json(out(l));
}));

router.delete('/warehouse-owner/labour/:id', owner, h(async (req, res) => {
  await Labour.deleteOne({ _id: req.params.id, owner: req.me.id });
  res.json({ ok: true });
}));

// ================================================================ OWNER: requests & stock
router.get('/warehouse-owner/bookings', owner, h(async (req, res) => {
  const f = { owner: req.me.id };
  const s = req.query.status;
  if (s === 'requests') f.status = 'requested';
  else if (s === 'stored') f.status = { $in: ['approved', 'stored'] };
  else if (s === 'history') f.status = { $in: ['released', 'rejected', 'cancelled'] };
  const list = await StorageBooking.find(f).sort({ createdAt: -1 }).limit(100);
  res.json({ items: list.map(bkOut) });
}));

router.patch('/storage-bookings/:id/respond', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'requested') throw bad('This request was already answered');
  const body = req.body || {};
  if (body.action === 'reject') {
    b.status = 'rejected';
    b.ownerNote = text(body.note, 200);
    push(b, 'rejected', b.ownerNote);
    await b.save();
    await notify(b.farmer, 'Storage request declined', `${b.warehouseName} declined your request`, 'warehouse', String(b._id));
    return res.json(bkOut(b));
  }
  if (body.action !== 'approve') throw bad('Choose approve or reject');
  const w = await Warehouse.findById(b.warehouse);
  const used = await usedMap([b.warehouse]);
  const free = (w ? w.capacityTons : 0) - (used[String(b.warehouse)] || 0);
  if (b.quantityTons > free) throw bad('Not enough free space (' + Math.max(0, Math.round(free * 100) / 100) + ' t free)');
  b.status = 'approved';
  b.ownerNote = text(body.note, 200);
  push(b, 'approved', b.ownerNote);
  await b.save();
  await notify(b.farmer, 'Storage approved', `${b.warehouseName} approved ${b.quantityTons} t. Total Rs ${b.total}`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

// crop arrived and was weighed in
router.patch('/storage-bookings/:id/stored', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'approved') throw bad('Only an approved booking can be marked as stored');
  const tons = num((req.body || {}).tons, b.quantityTons);
  if (tons <= 0 || tons > b.quantityTons * 1.1) throw bad('Enter the weighed quantity in tons');
  b.currentTons = tons;
  b.status = 'stored';
  b.startDate = new Date();
  b.endDate = new Date(Date.now() + b.days * DAY);
  push(b, 'stored', tons + ' t received');
  await b.save();
  await notify(b.farmer, 'Crop received', `${tons} t of ${b.crop} is now stored in ${b.warehouseName}`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

// partial or full release
router.patch('/storage-bookings/:id/release', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'stored') throw bad('Nothing is stored for this booking');
  const tons = num((req.body || {}).tons, b.currentTons);
  if (tons <= 0 || tons > b.currentTons + 0.0001) throw bad('Enter a quantity up to ' + b.currentTons + ' t');
  b.currentTons = Math.round((b.currentTons - tons) * 1000) / 1000;
  if (b.currentTons <= 0.0001) {
    b.currentTons = 0;
    b.status = 'released';
    push(b, 'released', 'All stock released');
  } else push(b, 'stored', tons + ' t released, ' + b.currentTons + ' t left');
  await b.save();
  await notify(b.farmer, 'Stock released', `${tons} t of ${b.crop} released from ${b.warehouseName}`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

// temperature / humidity readings the farmer can monitor
router.post('/storage-bookings/:id/readings', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'stored') throw bad('Readings can be added while stock is stored');
  const x = req.body || {};
  const row = { at: new Date(), temperature: x.temperature === undefined || x.temperature === '' ? undefined : num(x.temperature), humidity: x.humidity === undefined || x.humidity === '' ? undefined : num(x.humidity), note: text(x.note, 160) };
  if (row.temperature === undefined && row.humidity === undefined && !row.note) throw bad('Enter a temperature, humidity or note');
  b.readings.push(row);
  if (b.readings.length > 60) b.readings = b.readings.slice(-60);
  await b.save();
  res.status(201).json(bkOut(b));
}));

// loading / unloading jobs with labour
router.post('/storage-bookings/:id/tasks', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (!['approved', 'stored'].includes(b.status)) throw bad('Approve the booking first');
  const x = req.body || {};
  const kind = x.kind === 'unloading' ? 'unloading' : 'loading';
  const ids = Array.isArray(x.labourIds) ? x.labourIds : [];
  const workers = ids.length ? await Labour.find({ _id: { $in: ids }, owner: req.me.id }) : [];
  if (!workers.length) throw bad('Choose at least one worker');
  const when = new Date(x.scheduledAt);
  if (isNaN(when.getTime())) throw bad('Pick the date and time');
  const charge = x.charge !== undefined && x.charge !== '' ? money(x.charge) : workers.reduce((a, w) => a + w.dailyWage, 0);
  b.tasks.push({ kind, labour: workers.map(w => String(w._id)), labourNames: workers.map(w => w.name), scheduledAt: when, charge, status: 'scheduled' });
  recalc(b);
  await b.save();
  await notify(b.farmer, 'Handling scheduled', `${kind} of ${b.crop} is scheduled. Handling charge Rs ${charge}`, 'warehouse', String(b._id));
  res.status(201).json(bkOut(b));
}));

router.patch('/storage-bookings/:id/tasks/:taskId', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  const t = b.tasks.id(req.params.taskId);
  if (!t) throw bad('Task not found', 404);
  t.status = 'done';
  t.doneAt = new Date();
  await b.save();
  res.json(bkOut(b));
}));

router.get('/warehouse-owner/payments', owner, h(async (req, res) => {
  const list = await StorageBooking.find({ owner: req.me.id, status: { $in: ['approved', 'stored', 'released'] } }).sort({ updatedAt: -1 });
  const received = list.reduce((a, b) => a + b.paidAmount, 0);
  const due = list.reduce((a, b) => a + Math.max(0, b.total - b.paidAmount), 0);
  res.json({ received, due, items: list.map(bkOut) });
}));

router.post('/storage-bookings/:id/mark-paid', owner, h(async (req, res) => {
  const b = await StorageBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  const balance = b.total - b.paidAmount;
  if (balance <= 0) throw bad('Nothing left to collect');
  const amount = Math.min(balance, money((req.body || {}).amount) || balance);
  b.payments.push({ amount, method: 'Cash', at: new Date(), note: 'Received by owner' });
  b.paidAmount += amount;
  await b.save();
  await notify(b.farmer, 'Payment confirmed', `Rs ${amount} received by ${b.warehouseName}`, 'warehouse', String(b._id));
  res.json(bkOut(b));
}));

module.exports = router;
