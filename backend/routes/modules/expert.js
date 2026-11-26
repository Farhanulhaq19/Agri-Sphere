const express = require('express');
const { Profile, Query } = require('../../models/agri');
const { h, bad, out } = require('../../utils/http');
const { requireRole, notify } = require('../../utils/identity');

const router = express.Router();

// ----- farmer / buyer side -----
router.get('/queries', h(async (req, res) => {
  const list = await Query.find({ owner: req.me.id }).sort({ createdAt: -1 }).limit(20);
  const online = await Profile.countDocuments({ role: 'expert' });
  res.json({ expertsOnline: online, avgReplyHours: 2, items: list.map(out) });
}));

router.post('/queries', h(async (req, res) => {
  const b = req.body || {};
  if (!b.subject || !String(b.subject).trim()) throw bad('Enter a subject');
  if (!b.details || String(b.details).trim().length < 10) throw bad('Describe the problem (at least 10 characters)');
  const q = await Query.create({
    owner: req.me.id, ownerName: req.me.name, category: b.category || 'Crop disease',
    subject: String(b.subject).trim(), details: String(b.details).trim()
  });
  const experts = await Profile.find({ role: 'expert' }).limit(100);
  for (const e of experts) await notify(e.user, 'New question: ' + q.subject, req.me.name + ' asked about ' + q.category, 'query', String(q._id));
  res.status(201).json(out(q));
}));

// ----- expert side -----
router.get('/expert/queries', requireRole('expert', 'admin'), h(async (req, res) => {
  const tab = req.query.status === 'answered' ? 'answered' : 'open';
  const filter = tab === 'open' ? { status: 'open' } : { expert: req.me.id };
  const list = await Query.find(filter).sort({ createdAt: -1 }).limit(50);
  res.json({
    stats: { open: await Query.countDocuments({ status: 'open' }), answered: await Query.countDocuments({ expert: req.me.id }) },
    items: list.map(out)
  });
}));

router.post('/expert/queries/:id/answer', requireRole('expert', 'admin'), h(async (req, res) => {
  const q = await Query.findById(req.params.id);
  if (!q) throw bad('Question not found', 404);
  const answer = String((req.body || {}).answer || '').trim();
  if (answer.length < 5) throw bad('Write a proper answer');
  q.answer = answer;
  q.status = 'answered';
  q.expert = req.me.id;
  q.expertName = req.me.name;
  q.answeredAt = new Date();
  await q.save();
  await Profile.updateOne({ user: req.me.id }, { $inc: { completed: 1 } });
  await notify(q.owner, 'Your question was answered', req.me.name + ' replied to: ' + q.subject, 'query', String(q._id));
  res.json(out(q));
}));

module.exports = router;