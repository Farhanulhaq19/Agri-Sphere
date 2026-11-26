const express = require('express');
const { Machine, Technician, MachineBooking, Maintenance, CATEGORIES } = require('../../models/machinery');
const { h, bad, esc, out } = require('../../utils/http');
const { requireRole, loggedIn, notify } = require('../../utils/identity');
const { cleanPhotos, readProof, payAccount } = require('../../utils/uploads');
const { applyDistance } = require('../../utils/geo');
const { requirePhone } = require('../../utils/phone');
const { Profile } = require('../../models/agri');

const router = express.Router();
const owner = requireRole('machinery_owner');
const ACTIVE = ['accepted', 'in_progress'];
const num = (v, d = 0) => (v === undefined || v === null || v === '' ? d : Number(v));
const money = (n) => Math.round(Number(n) || 0);
const text = (v, max = 300) => String(v === undefined || v === null ? '' : v).trim().slice(0, max);
const push = (b, status, note) => b.history.push({ status, at: new Date(), note: note || '' });

const { nextNumber: seq } = require('../../utils/counter');
const nextNumber = () => seq('machine-booking', MachineBooking, 1000);

function machineBody(b, partial) {
  const o = {};
  const set = (k, v) => { if (!partial || b[k] !== undefined) o[k] = v; };
  set('name', text(b.name, 80));
  set('category', CATEGORIES.includes(b.category) ? b.category : 'Other');
  set('brand', text(b.brand, 60));
  set('modelName', text(b.modelName, 60));
  set('year', b.year ? num(b.year) : undefined);
  set('horsepower', b.horsepower ? num(b.horsepower) : undefined);
  set('condition', b.condition === 'new' ? 'new' : 'used');
  set('forRent', !!b.forRent);
  set('forSale', !!b.forSale);
  set('rentPerHour', money(b.rentPerHour));
  set('rentPerDay', money(b.rentPerDay));
  set('salePrice', money(b.salePrice));
  set('minHours', Math.max(1, num(b.minHours, 1)));
  set('operatorAvailable', !!b.operatorAvailable);
  set('operatorRatePerHour', money(b.operatorRatePerHour));
  set('city', text(b.city, 60));
  set('address', text(b.address, 160));
  set('description', text(b.description, 600));
  if (!partial || b.features !== undefined) o.features = Array.isArray(b.features) ? b.features.map(x => text(x, 40)).filter(Boolean).slice(0, 12) : [];
  if (!partial || b.lat !== undefined) o.lat = b.lat === '' || b.lat == null ? undefined : num(b.lat);
  if (!partial || b.lng !== undefined) o.lng = b.lng === '' || b.lng == null ? undefined : num(b.lng);
  if (!partial || b.photos !== undefined) o.photos = cleanPhotos(b.photos);
  return o;
}

function validateMachine(m) {
  if (!m.name || m.name.length < 2) throw bad('Enter the machine name');
  if (!m.forRent && !m.forSale) throw bad('Choose at least one: rent it out or sell it');
  if (m.forRent && !m.rentPerHour && !m.rentPerDay) throw bad('Enter a rent per hour or per day');
  if (m.forSale && !m.salePrice) throw bad('Enter the sale price');
  if (m.operatorAvailable && !m.operatorRatePerHour) throw bad('Enter the technician charge per hour');
}

// Works out the price of a rental. A technician is charged per HOUR worked (techHours).
function quote(m, b) {
  const unit = b.rateUnit === 'day' ? 'day' : 'hour';
  const qty = num(b.quantity);
  if (!qty || qty <= 0) throw bad('Enter how long you need the machine');
  let rentCost;
  let span;
  if (unit === 'hour') {
    if (!m.rentPerHour) throw bad('This machine is not rented by the hour');
    if (qty < m.minHours) throw bad('Minimum booking is ' + m.minHours + ' hour(s)');
    if (qty > 240) throw bad('Maximum 240 hours per booking');
    rentCost = qty * m.rentPerHour;
    span = qty;
  } else {
    if (!m.rentPerDay) throw bad('This machine is not rented by the day');
    if (qty > 60) throw bad('Maximum 60 days per booking');
    rentCost = qty * m.rentPerDay;
    span = qty * 24;
  }
  let techHours = 0;
  let techCost = 0;
  if (b.withTechnician) {
    if (!m.operatorAvailable) throw bad('This owner does not provide a technician for this machine');
    techHours = num(b.techHours) || (unit === 'hour' ? qty : qty * 8);
    if (techHours < 1 || techHours > span) throw bad('Technician hours must be between 1 and ' + span);
    techCost = techHours * m.operatorRatePerHour;
  }
  return { unit, qty, span, rentCost: money(rentCost), techHours, techCost: money(techCost), total: money(rentCost + techCost) };
}

async function busyMap(ids) {
  const now = new Date();
  const rows = await MachineBooking.find({ machine: { $in: ids }, type: 'rent', status: { $in: ACTIVE }, endAt: { $gt: now } }).sort({ startAt: 1 });
  const m = {};
  rows.forEach(r => { (m[String(r.machine)] = m[String(r.machine)] || []).push(r); });
  return m;
}

function machineOut(m, busy) {
  const x = out(m);
  const list = (busy && busy[x.id]) || [];
  const now = new Date();
  const current = list.find(r => r.startAt <= now && r.endAt > now);
  x.availableNow = x.status === 'available' && !current;
  x.busyUntil = current ? current.endAt : null;
  x.nextBooking = list.find(r => r.startAt > now) ? list.find(r => r.startAt > now).startAt : null;
  return x;
}

function bookingOut(b) {
  const x = out(b);
  x.canCancel = ['requested', 'accepted'].includes(x.status);
  return x;
}

// ================================================================ BROWSE (farmers, warehouse owners, anyone)
router.get('/machinery/categories', h(async (req, res) => { res.json({ items: CATEGORIES, account: payAccount() }); }));

router.get('/machinery', h(async (req, res) => {
  const f = { status: { $in: ['available', 'maintenance'] } };
  if (req.query.category && req.query.category !== 'All') f.category = req.query.category;
  if (req.query.mode === 'rent') f.forRent = true;
  if (req.query.mode === 'sale') f.forSale = true;
  if (req.query.operator === '1') f.operatorAvailable = true;
  if (req.query.city) f.city = new RegExp(esc(req.query.city), 'i');
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$or = [{ name: r }, { brand: r }, { category: r }, { city: r }, { modelName: r }];
  }
  if (!req.me.demo) f.owner = { $ne: req.me.id };
  let sort = { createdAt: -1 };
  if (req.query.sort === 'price') sort = { rentPerHour: 1 };
  if (req.query.sort === 'rating') sort = { rating: -1 };
  const list = await Machine.find(f).sort(sort).limit(80);
  const busy = await busyMap(list.map(m => m._id));
  let items = list.map(m => machineOut(m, busy));
  if (req.query.availableNow === '1') items = items.filter(i => i.availableNow);
  res.json({ items: applyDistance(items, req.query) });
}));

router.get('/machinery/:id', h(async (req, res) => {
  const m = await Machine.findById(req.params.id);
  if (!m) throw bad('Machine not found', 404);
  const busy = await busyMap([m._id]);
  const x = machineOut(m, busy);
  x.bookedSlots = ((busy[x.id]) || []).map(r => ({ startAt: r.startAt, endAt: r.endAt }));
  const reviews = await MachineBooking.find({ machine: m._id, rating: { $gt: 0 } }).sort({ updatedAt: -1 }).limit(10);
  x.reviews = reviews.map(r => ({ farmerName: r.farmerName, rating: r.rating, review: r.review || '', at: r.updatedAt }));
  x.isMine = !req.me.demo && m.owner === req.me.id;
  res.json(x);
}));

// ================================================================ BOOK / BUY (any logged-in user)
router.post('/machinery/:id/book', loggedIn, h(async (req, res) => {
  const m = await Machine.findById(req.params.id);
  if (!m) throw bad('Machine not found', 404);
  if (m.owner === req.me.id) throw bad('This is your own machine');
  if (m.status !== 'available') throw bad('This machine is not available right now');
  const b = req.body || {};
  const type = b.type === 'buy' ? 'buy' : 'rent';
  const doc = {
    number: await nextNumber(), machine: m._id, machineName: m.name, category: m.category,
    owner: m.owner, ownerName: m.ownerName, farmer: req.me.id, farmerName: req.me.name,
    farmerPhone: text(b.phone, 20) || req.me.phone || '', type,
    fieldLocation: text(b.fieldLocation, 160), fieldLat: b.fieldLat == null ? undefined : num(b.fieldLat),
    fieldLng: b.fieldLng == null ? undefined : num(b.fieldLng), notes: text(b.notes, 300), status: 'requested', history: []
  };
  if (type === 'buy') {
    if (!m.forSale) throw bad('This machine is not for sale');
    const now = new Date();
    Object.assign(doc, { startAt: now, endAt: now, rateUnit: 'hour', quantity: 1, rentCost: m.salePrice, total: m.salePrice });
  } else {
    if (!m.forRent) throw bad('This machine is not for rent');
    const startAt = new Date(b.startAt);
    if (isNaN(startAt.getTime())) throw bad('Pick the date and time you need it');
    if (startAt.getTime() < Date.now() - 5 * 60 * 1000) throw bad('Start time is in the past');
    const q = quote(m, b);
    const endAt = new Date(startAt.getTime() + q.span * 3600 * 1000);
    const clash = await MachineBooking.findOne({ machine: m._id, type: 'rent', status: { $in: ACTIVE }, startAt: { $lt: endAt }, endAt: { $gt: startAt } });
    if (clash) throw bad('That time is already booked. Pick another slot (see the booked times on the machine page).', 409);
    Object.assign(doc, {
      startAt, endAt, rateUnit: q.unit, quantity: q.qty, withTechnician: !!b.withTechnician,
      techHours: q.techHours, rentCost: q.rentCost, techCost: q.techCost, total: q.total
    });
  }
  const bk = new MachineBooking(doc);
  push(bk, 'requested');
  await bk.save();
  await notify(m.owner, type === 'buy' ? 'New purchase request' : 'New booking request',
    `${req.me.name} wants to ${type === 'buy' ? 'buy' : 'rent'} ${m.name}`, 'machinery', String(bk._id));
  res.status(201).json(bookingOut(bk));
}));

// ================================================================ MY BOOKINGS (renter side)
router.get('/machinery-bookings/mine', loggedIn, h(async (req, res) => {
  const f = { farmer: req.me.id };
  if (req.query.status === 'active') f.status = { $in: ['requested', 'accepted', 'in_progress'] };
  if (req.query.status === 'past') f.status = { $in: ['completed', 'declined', 'cancelled'] };
  const list = await MachineBooking.find(f).sort({ createdAt: -1 }).limit(80);
  res.json({ items: list.map(bookingOut) });
}));

router.get('/machinery-bookings/:id', loggedIn, h(async (req, res) => {
  const b = await MachineBooking.findById(req.params.id);
  if (!b || (b.farmer !== req.me.id && b.owner !== req.me.id)) throw bad('Booking not found', 404);
  res.json(bookingOut(b));
}));

router.patch('/machinery-bookings/:id/cancel', loggedIn, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (!['requested', 'accepted'].includes(b.status)) throw bad('This booking can no longer be cancelled');
  if (b.paymentStatus === 'paid') throw bad('Already paid. Contact the owner to cancel.');
  b.status = 'cancelled';
  push(b, 'cancelled', 'Cancelled by renter');
  await b.save();
  await notify(b.owner, 'Booking cancelled', `${b.farmerName} cancelled ${b.machineName}`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

router.post('/machinery-bookings/:id/pay', loggedIn, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (!['accepted', 'in_progress', 'completed'].includes(b.status)) throw bad('You can pay once the owner accepts');
  if (b.paymentStatus === 'paid') throw bad('Already paid');
  if (b.paymentStatus === 'under_review') throw bad('Your payment is being verified by the owner');
  const method = ['Cash', 'Easypaisa', 'Card'].includes(req.body && req.body.method) ? req.body.method : 'Cash';
  b.payMethod = method;
  if (method === 'Cash') {
    // owner confirms with "mark paid" after collecting the cash
    await b.save();
    await notify(b.owner, 'Cash payment', `${b.farmerName} will pay Rs ${b.total} in cash for ${b.machineName}`, 'machinery', String(b._id));
    return res.json(bookingOut(b));
  }
  const p = readProof(req.body);
  b.paymentProof = p.url;
  b.paymentRef = p.ref;
  b.paymentNote = '';
  b.paymentStatus = 'under_review';
  await b.save();
  await notify(b.owner, 'Payment proof received', `${b.farmerName} sent Rs ${b.total} via ${method} for ${b.machineName}. Please verify.`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

// owner approves / rejects an Easypaisa or card payment screenshot
router.patch('/machinery-bookings/:id/payment', owner, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.paymentStatus !== 'under_review') throw bad('There is no payment waiting for review');
  const ok = (req.body || {}).action === 'approve';
  b.paymentStatus = ok ? 'paid' : 'rejected';
  b.paymentNote = ok ? '' : text((req.body || {}).reason, 200) || 'Payment could not be verified';
  if (ok) b.paidAt = new Date();
  await b.save();
  await notify(b.farmer, ok ? 'Payment verified' : 'Payment rejected',
    ok ? `Payment for ${b.machineName} was verified` : `${b.paymentNote}. Please upload a correct screenshot.`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

router.post('/machinery-bookings/:id/rate', loggedIn, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, farmer: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'completed') throw bad('You can rate after the job is completed');
  if (b.rating) throw bad('You already rated this booking');
  const r = Math.round(num(req.body && req.body.rating));
  if (r < 1 || r > 5) throw bad('Rating must be 1 to 5');
  b.rating = r;
  b.review = text(req.body.review, 300);
  await b.save();
  const m = await Machine.findById(b.machine);
  if (m) {
    m.rating = Math.round(((m.rating * m.ratingCount + r) / (m.ratingCount + 1)) * 10) / 10;
    m.ratingCount += 1;
    await m.save();
  }
  res.json(bookingOut(b));
}));

// ================================================================ OWNER: dashboard
router.get('/machinery-owner/dashboard', owner, h(async (req, res) => {
  const id = req.me.id;
  const [machines, techs, bookings] = await Promise.all([
    Machine.find({ owner: id }), Technician.countDocuments({ owner: id }), MachineBooking.find({ owner: id }).sort({ createdAt: -1 })
  ]);
  const start = new Date(); start.setDate(1); start.setHours(0, 0, 0, 0);
  const paid = bookings.filter(b => b.paymentStatus === 'paid');
  const earnings = paid.reduce((a, b) => a + b.total, 0);
  const month = paid.filter(b => b.paidAt >= start).reduce((a, b) => a + b.total, 0);
  const pending = bookings.filter(b => ['accepted', 'in_progress', 'completed'].includes(b.status) && b.paymentStatus === 'unpaid').reduce((a, b) => a + b.total, 0);
  const rated = machines.filter(m => m.ratingCount > 0);
  res.json({
    name: req.me.name,
    machines: machines.length,
    available: machines.filter(m => m.status === 'available').length,
    inMaintenance: machines.filter(m => m.status === 'maintenance').length,
    technicians: techs,
    pendingRequests: bookings.filter(b => b.status === 'requested').length,
    activeJobs: bookings.filter(b => b.status === 'in_progress').length,
    upcoming: bookings.filter(b => b.status === 'accepted').length,
    completed: bookings.filter(b => b.status === 'completed').length,
    earnings, monthEarnings: month, pendingPayments: pending,
    rating: rated.length ? Math.round((rated.reduce((a, m) => a + m.rating, 0) / rated.length) * 10) / 10 : 0,
    recent: bookings.slice(0, 4).map(bookingOut)
  });
}));

// ================================================================ OWNER: machines
router.get('/machinery-owner/machines', owner, h(async (req, res) => {
  const list = await Machine.find({ owner: req.me.id }).sort({ createdAt: -1 });
  const busy = await busyMap(list.map(m => m._id));
  res.json({ items: list.map(m => machineOut(m, busy)) });
}));

router.post('/machinery-owner/machines', owner, h(async (req, res) => {
  const data = machineBody(req.body || {}, false);
  validateMachine(data);
  const ownerPhone = await requirePhone(req.me, req.body.phone || req.body.ownerPhone, await Profile.findOne({ user: req.me.id }));
  const m = await Machine.create({ ...data, owner: req.me.id, ownerName: req.me.name, ownerPhone, status: 'available' });
  res.status(201).json(machineOut(m, {}));
}));

router.put('/machinery-owner/machines/:id', owner, h(async (req, res) => {
  const m = await Machine.findOne({ _id: req.params.id, owner: req.me.id });
  if (!m) throw bad('Machine not found', 404);
  const data = machineBody(req.body || {}, true);
  Object.assign(m, data);
  if (req.body && (req.body.phone || req.body.ownerPhone)) m.ownerPhone = await requirePhone(req.me, req.body.phone || req.body.ownerPhone);
  validateMachine(m);
  await m.save();
  res.json(machineOut(m, {}));
}));

// status ("Update Status & Location")
router.patch('/machinery-owner/machines/:id/status', owner, h(async (req, res) => {
  const m = await Machine.findOne({ _id: req.params.id, owner: req.me.id });
  if (!m) throw bad('Machine not found', 404);
  const b = req.body || {};
  if (b.status !== undefined) {
    if (!['available', 'maintenance', 'inactive'].includes(b.status)) throw bad('Invalid status');
    if (m.status === 'sold') throw bad('This machine is sold');
    m.status = b.status;
  }
  if (b.city !== undefined) m.city = text(b.city, 60);
  if (b.lat !== undefined) m.lat = b.lat === '' || b.lat === null ? undefined : num(b.lat);
  if (b.lng !== undefined) m.lng = b.lng === '' || b.lng === null ? undefined : num(b.lng);
  if (b.locationNote !== undefined) m.locationNote = text(b.locationNote, 160);
  await m.save();
  res.json(machineOut(m, {}));
}));

router.delete('/machinery-owner/machines/:id', owner, h(async (req, res) => {
  const m = await Machine.findOne({ _id: req.params.id, owner: req.me.id });
  if (!m) throw bad('Machine not found', 404);
  const open = await MachineBooking.countDocuments({ machine: m._id, status: { $in: ['requested', ...ACTIVE] } });
  if (open) throw bad('This machine has open bookings. Finish or decline them first.');
  await Machine.deleteOne({ _id: m._id });
  res.json({ ok: true });
}));

// ================================================================ OWNER: technicians
router.get('/machinery-owner/technicians', owner, h(async (req, res) => {
  const list = await Technician.find({ owner: req.me.id }).sort({ createdAt: -1 });
  res.json({ items: list.map(out) });
}));

function techBody(b) {
  const name = text(b.name, 60);
  if (name.length < 2) throw bad('Enter the technician name');
  const phone = text(b.phone, 20).replace(/[\s-]/g, '');
  if (phone && !/^\+?[0-9]{10,14}$/.test(phone)) throw bad('Enter a valid phone number');
  return {
    name, phone, skill: text(b.skill, 40) || 'Tractor Operator',
    experienceYears: Math.max(0, num(b.experienceYears)), hourlyRate: money(b.hourlyRate), notes: text(b.notes, 200),
    ...(['available', 'busy', 'off'].includes(b.status) ? { status: b.status } : {})
  };
}

router.post('/machinery-owner/technicians', owner, h(async (req, res) => {
  const t = await Technician.create({ ...techBody(req.body || {}), owner: req.me.id });
  res.status(201).json(out(t));
}));

router.put('/machinery-owner/technicians/:id', owner, h(async (req, res) => {
  const t = await Technician.findOne({ _id: req.params.id, owner: req.me.id });
  if (!t) throw bad('Technician not found', 404);
  Object.assign(t, techBody({ ...t.toObject(), ...(req.body || {}) }));
  await t.save();
  res.json(out(t));
}));

router.delete('/machinery-owner/technicians/:id', owner, h(async (req, res) => {
  const t = await Technician.findOne({ _id: req.params.id, owner: req.me.id });
  if (!t) throw bad('Technician not found', 404);
  const open = await MachineBooking.countDocuments({ technician: String(t._id), status: { $in: ACTIVE } });
  if (open) throw bad('This technician is assigned to an open booking');
  await Technician.deleteOne({ _id: t._id });
  res.json({ ok: true });
}));

// ================================================================ OWNER: requests, schedule
router.get('/machinery-owner/bookings', owner, h(async (req, res) => {
  const f = { owner: req.me.id };
  const s = req.query.status;
  if (s === 'requests') f.status = 'requested';
  else if (s === 'active') f.status = { $in: ACTIVE };
  else if (s === 'history') f.status = { $in: ['completed', 'declined', 'cancelled'] };
  const list = await MachineBooking.find(f).sort({ createdAt: -1 }).limit(100);
  res.json({ items: list.map(bookingOut) });
}));

router.get('/machinery-owner/schedule', owner, h(async (req, res) => {
  const from = new Date(); from.setHours(0, 0, 0, 0);
  const jobs = await MachineBooking.find({ owner: req.me.id, type: 'rent', status: { $in: ACTIVE }, endAt: { $gte: from } }).sort({ startAt: 1 });
  const maint = await Maintenance.find({ owner: req.me.id, status: 'scheduled', date: { $gte: from } }).sort({ date: 1 });
  res.json({ jobs: jobs.map(bookingOut), maintenance: maint.map(out) });
}));

router.patch('/machinery-bookings/:id/respond', owner, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.status !== 'requested') throw bad('This request was already answered');
  const body = req.body || {};
  if (body.action === 'decline') {
    b.status = 'declined';
    b.ownerNote = text(body.note, 200);
    push(b, 'declined', b.ownerNote);
    await b.save();
    await notify(b.farmer, 'Request declined', `${b.ownerName || 'The owner'} declined your request for ${b.machineName}`, 'machinery', String(b._id));
    return res.json(bookingOut(b));
  }
  if (body.action !== 'accept') throw bad('Choose accept or decline');
  const m = await Machine.findById(b.machine);
  if (!m || m.owner !== req.me.id) throw bad('Machine not found', 404);

  if (b.type === 'buy') {
    if (m.status === 'sold') throw bad('This machine is already sold');
    m.status = 'sold';
    await m.save();
    const others = await MachineBooking.find({ machine: m._id, type: 'buy', status: 'requested', _id: { $ne: b._id } });
    for (const o of others) {
      o.status = 'declined';
      o.ownerNote = 'Sold to another buyer';
      push(o, 'declined', o.ownerNote);
      await o.save();
      await notify(o.farmer, 'Machine sold', `${m.name} was sold to another buyer`, 'machinery', String(o._id));
    }
  } else {
    const clash = await MachineBooking.findOne({ machine: m._id, type: 'rent', status: { $in: ACTIVE }, _id: { $ne: b._id }, startAt: { $lt: b.endAt }, endAt: { $gt: b.startAt } });
    if (clash) throw bad('This time clashes with another accepted booking', 409);
  }

  if (b.withTechnician) {
    if (body.technicianId) {
      const t = await Technician.findOne({ _id: body.technicianId, owner: req.me.id });
      if (!t) throw bad('Technician not found', 404);
      const busy = await MachineBooking.findOne({ technician: String(t._id), status: { $in: ACTIVE }, _id: { $ne: b._id }, startAt: { $lt: b.endAt }, endAt: { $gt: b.startAt } });
      if (busy) throw bad(t.name + ' is already assigned at that time', 409);
      b.technician = String(t._id);
      b.technicianName = t.name;
    } else {
      b.technician = '';
      b.technicianName = 'Owner (' + (b.ownerName || 'owner') + ')';
    }
  }
  b.status = 'accepted';
  b.ownerNote = text(body.note, 200);
  push(b, 'accepted', b.ownerNote);
  await b.save();
  await notify(b.farmer, 'Request accepted', `${b.machineName} is confirmed${b.technicianName ? ' with ' + b.technicianName : ''}. Total Rs ${b.total}`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

router.patch('/machinery-bookings/:id/progress', owner, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  const to = (req.body || {}).status;
  if (to === 'in_progress') {
    if (b.status !== 'accepted') throw bad('Only an accepted booking can be started');
    if (b.type === 'buy') throw bad('Purchases are completed, not started');
    b.status = 'in_progress';
    if (b.technician) await Technician.updateOne({ _id: b.technician }, { status: 'busy' });
    push(b, 'in_progress', 'Machine on its way / work started');
  } else if (to === 'completed') {
    if (!['accepted', 'in_progress'].includes(b.status)) throw bad('This booking cannot be completed');
    if (b.type === 'buy' && b.paymentStatus !== 'paid') throw bad('Receive the payment before handing over the machine');
    b.status = 'completed';
    if (b.technician) await Technician.updateOne({ _id: b.technician }, { status: 'available' });
    await Machine.updateOne({ _id: b.machine }, { $inc: { totalBookings: 1 } });
    push(b, 'completed', b.type === 'buy' ? 'Machine handed over' : 'Job finished');
  } else throw bad('Invalid status');
  await b.save();
  await notify(b.farmer, to === 'completed' ? 'Job completed' : 'Work started', `${b.machineName}: ${to === 'completed' ? 'completed' : 'on its way / started'}`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

// live tracking: owner pushes the machine position / a note
router.patch('/machinery-bookings/:id/location', owner, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  const x = req.body || {};
  b.tracking = { lat: x.lat === undefined ? undefined : num(x.lat), lng: x.lng === undefined ? undefined : num(x.lng), note: text(x.note, 160), updatedAt: new Date() };
  await b.save();
  await Machine.updateOne({ _id: b.machine }, { lat: b.tracking.lat, lng: b.tracking.lng, locationNote: b.tracking.note });
  await notify(b.farmer, 'Machine update', `${b.machineName}: ${b.tracking.note || 'location updated'}`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

router.patch('/machinery-bookings/:id/mark-paid', owner, h(async (req, res) => {
  const b = await MachineBooking.findOne({ _id: req.params.id, owner: req.me.id });
  if (!b) throw bad('Booking not found', 404);
  if (b.paymentStatus === 'paid') throw bad('Already paid');
  if (!['accepted', 'in_progress', 'completed'].includes(b.status)) throw bad('Accept the booking first');
  b.paymentStatus = 'paid';
  b.payMethod = 'Cash';
  b.paidAt = new Date();
  await b.save();
  await notify(b.farmer, 'Payment confirmed', `Payment of Rs ${b.total} for ${b.machineName} was confirmed`, 'machinery', String(b._id));
  res.json(bookingOut(b));
}));

// ================================================================ OWNER: earnings & payments
router.get('/machinery-owner/earnings', owner, h(async (req, res) => {
  const list = await MachineBooking.find({ owner: req.me.id, status: { $in: ['accepted', 'in_progress', 'completed'] } }).sort({ updatedAt: -1 });
  const paid = list.filter(b => b.paymentStatus === 'paid');
  const unpaid = list.filter(b => b.paymentStatus !== 'paid');
  const months = [];
  const now = new Date();
  for (let i = 5; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const e = new Date(now.getFullYear(), now.getMonth() - i + 1, 1);
    months.push({
      label: d.toLocaleString('en', { month: 'short' }),
      amount: paid.filter(b => b.paidAt >= d && b.paidAt < e).reduce((a, b) => a + b.total, 0)
    });
  }
  const per = {};
  paid.forEach(b => { per[b.machineName] = (per[b.machineName] || 0) + b.total; });
  res.json({
    total: paid.reduce((a, b) => a + b.total, 0),
    pending: unpaid.reduce((a, b) => a + b.total, 0),
    technicianShare: paid.reduce((a, b) => a + (b.techCost || 0), 0),
    months,
    byMachine: Object.keys(per).map(k => ({ name: k, amount: per[k] })).sort((a, b) => b.amount - a.amount),
    payments: paid.slice(0, 30).map(bookingOut),
    unpaid: unpaid.slice(0, 30).map(bookingOut)
  });
}));

// ================================================================ OWNER: maintenance
router.get('/machinery-owner/maintenance', owner, h(async (req, res) => {
  const list = await Maintenance.find({ owner: req.me.id }).sort({ date: -1 }).limit(60);
  res.json({ items: list.map(out) });
}));

router.post('/machinery-owner/maintenance', owner, h(async (req, res) => {
  const b = req.body || {};
  const m = await Machine.findOne({ _id: b.machineId, owner: req.me.id });
  if (!m) throw bad('Choose a machine');
  const date = new Date(b.date);
  if (isNaN(date.getTime())) throw bad('Pick a date');
  const row = await Maintenance.create({
    owner: req.me.id, machine: m._id, machineName: m.name,
    kind: ['Service', 'Repair', 'Inspection', 'Tyres', 'Oil change'].includes(b.kind) ? b.kind : 'Service',
    date, cost: money(b.cost), note: text(b.note, 200), status: 'scheduled'
  });
  res.status(201).json(out(row));
}));

router.patch('/machinery-owner/maintenance/:id/done', owner, h(async (req, res) => {
  const row = await Maintenance.findOne({ _id: req.params.id, owner: req.me.id });
  if (!row) throw bad('Not found', 404);
  row.status = 'done';
  if (req.body && req.body.cost !== undefined) row.cost = money(req.body.cost);
  await row.save();
  res.json(out(row));
}));

module.exports = router;
