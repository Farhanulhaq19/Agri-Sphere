const express = require('express');
const { Favorite, Conversation, Message } = require('../../models/social');
const { Listing } = require('../../models/agri');
const { Machine } = require('../../models/machinery');
const { Warehouse } = require('../../models/warehouse');
const { h, bad, out } = require('../../utils/http');
const { notify } = require('../../utils/identity');
const { emitTo } = require('../../utils/realtime');
const { saveToken, removeToken } = require('../../utils/push');

const router = express.Router();
const needUser = (req) => { if (req.me.demo) throw bad('Please log in first', 401); };
const text = (v, max) => String(v == null ? '' : v).trim().slice(0, max);

// ================================================================ FAVOURITES
async function snapshot(kind, id) {
  if (kind === 'listing') {
    const l = await Listing.findById(id);
    if (!l) throw bad('Item not found', 404);
    return { title: l.title, sub: (l.location || '') + ' · ' + (l.sellerName || ''), price: 'Rs ' + l.pricePerKg + '/' + (l.unit || 'kg'), photo: (l.photos || [])[0] || '' };
  }
  if (kind === 'machine') {
    const m = await Machine.findById(id);
    if (!m) throw bad('Machine not found', 404);
    const price = m.forRent && m.rentPerHour ? 'Rs ' + m.rentPerHour + '/hr' : m.forRent && m.rentPerDay ? 'Rs ' + m.rentPerDay + '/day' : 'Rs ' + (m.salePrice || 0);
    return { title: m.name, sub: m.category + ' · ' + (m.city || ''), price, photo: (m.photos || [])[0] || '' };
  }
  if (kind === 'warehouse') {
    const w = await Warehouse.findById(id);
    if (!w) throw bad('Warehouse not found', 404);
    return { title: w.name, sub: (w.city || '') + ' · ' + w.capacityTons + ' t', price: 'Rs ' + w.ratePerTonDay + '/t/day', photo: (w.photos || [])[0] || '' };
  }
  throw bad('Unknown item type');
}

router.get('/favorites', h(async (req, res) => {
  const f = { user: req.me.id };
  if (req.query.kind) f.kind = req.query.kind;
  const list = await Favorite.find(f).sort({ createdAt: -1 }).limit(200);
  res.json({ items: list.map(out) });
}));

router.get('/favorites/ids', h(async (req, res) => {
  const list = await Favorite.find({ user: req.me.id }, { kind: 1, ref: 1 });
  res.json({ ids: list.map(f => f.kind + ':' + f.ref) });
}));

router.post('/favorites/toggle', h(async (req, res) => {
  needUser(req);
  const b = req.body || {};
  const kind = String(b.kind || '');
  const ref = String(b.id || '');
  const existing = await Favorite.findOne({ user: req.me.id, kind, ref });
  if (existing) {
    await existing.deleteOne();
    return res.json({ saved: false });
  }
  const snap = await snapshot(kind, ref);
  await Favorite.create({ user: req.me.id, kind, ref, ...snap });
  res.status(201).json({ saved: true });
}));

// ================================================================ CHAT
function convOut(c, me) {
  const x = out(c);
  const other = (c.members || []).find(m => m !== me) || '';
  x.otherId = other;
  x.otherName = (c.names && c.names.get(other)) || 'User';
  x.unread = (c.unread && c.unread.get(me)) || 0;
  delete x.names;
  return x;
}

// open (or reuse) a chat with another user, e.g. from a product / machine / warehouse page
router.post('/chats/start', h(async (req, res) => {
  needUser(req);
  const b = req.body || {};
  const to = text(b.to, 80);
  if (!to) throw bad('Who do you want to chat with?');
  if (to === req.me.id) throw bad('This is your own item');
  const topic = { kind: text(b.kind, 20), ref: text(b.refId, 40), title: text(b.title, 100) };
  // you can only open a chat about a real item, with the person who owns it
  const ownerOf = { listing: async id => (await Listing.findById(id) || {}).seller, machine: async id => (await Machine.findById(id) || {}).owner, warehouse: async id => (await Warehouse.findById(id) || {}).owner };
  if (!ownerOf[topic.kind] || !topic.ref) throw bad('Open the chat from a product, machine or warehouse page');
  const realOwner = await ownerOf[topic.kind](topic.ref);
  if (!realOwner || String(realOwner) !== to) throw bad('This person is not the seller of that item', 403);
  let c = await Conversation.findOne({ members: { $all: [req.me.id, to], $size: 2 }, 'topic.ref': topic.ref || { $in: [null, ''] } });
  if (!c) {
    c = await Conversation.create({
      members: [req.me.id, to],
      names: { [req.me.id]: req.me.name, [to]: text(b.toName, 60) || 'Seller' },
      topic, lastAt: new Date(), unread: {}
    });
  }
  res.status(201).json(convOut(c, req.me.id));
}));

router.get('/chats', h(async (req, res) => {
  const list = await Conversation.find({ members: req.me.id }).sort({ lastAt: -1 }).limit(100);
  res.json({ items: list.map(c => convOut(c, req.me.id)) });
}));

router.get('/chats/unread', h(async (req, res) => {
  const list = await Conversation.find({ members: req.me.id }, { unread: 1 });
  res.json({ count: list.reduce((a, c) => a + ((c.unread && c.unread.get(req.me.id)) || 0), 0) });
}));

async function myConv(req) {
  const c = await Conversation.findById(req.params.id);
  if (!c || !c.members.includes(req.me.id)) throw bad('Chat not found', 404);
  return c;
}

// messages (newest last). ?after=<iso date> returns only new ones, used for polling.
router.get('/chats/:id/messages', h(async (req, res) => {
  const c = await myConv(req);
  const f = { conv: c._id };
  if (req.query.after) f.createdAt = { $gt: new Date(req.query.after) };
  const list = await Message.find(f).sort({ createdAt: 1 }).limit(300);
  if ((c.unread && c.unread.get(req.me.id)) > 0) {
    c.unread.set(req.me.id, 0);
    await c.save();
  }
  res.json({ chat: convOut(c, req.me.id), items: list.map(out) });
}));

router.post('/chats/:id/messages', h(async (req, res) => {
  const c = await myConv(req);
  const t = text((req.body || {}).text, 1000);
  if (!t) throw bad('Type a message');
  const m = await Message.create({ conv: c._id, from: req.me.id, fromName: req.me.name, text: t });
  const other = c.members.find(x => x !== req.me.id);
  const before = (c.unread && c.unread.get(other)) || 0;
  c.unread.set(other, before + 1);
  c.names.set(req.me.id, req.me.name);
  c.lastText = t;
  c.lastAt = m.createdAt;
  c.lastBy = req.me.id;
  await c.save();
  // live delivery to both people's open apps (the sender may have the chat open on another device)
  const payload = { chatId: String(c._id), message: out(m), fromName: req.me.name };
  emitTo(other, 'chat:message', payload);
  emitTo(req.me.id, 'chat:message', payload);
  // one notification (and phone push) per burst of messages, not one per message
  if (before === 0) await notify(other, 'New message from ' + req.me.name, t.slice(0, 80), 'chat', String(c._id));
  res.status(201).json(out(m));
}));

// ================================================================ phone push tokens
router.post('/devices', h(async (req, res) => {
  needUser(req);
  const token = text((req.body || {}).token, 400);
  if (!token) throw bad('Missing device token');
  await saveToken(req.me.id, token, text((req.body || {}).platform, 20));
  res.json({ ok: true });
}));

router.delete('/devices', h(async (req, res) => {
  await removeToken(text((req.body || {}).token || req.query.token, 400));
  res.json({ ok: true });
}));

module.exports = router;
