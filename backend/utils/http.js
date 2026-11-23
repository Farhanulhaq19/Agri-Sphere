const h = fn => (req, res) => Promise.resolve(fn(req, res)).catch(e => {
  console.error('API error:', e.message);
  if (e.name === 'CastError') return res.status(404).json({ message: 'Not found' });
  res.status(e.status || 500).json({ message: e.message || 'Server error' });
});

const bad = (msg, status) => {
  const e = new Error(msg);
  e.status = status || 400;
  return e;
};

const esc = s => String(s).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

function out(doc) {
  const o = doc && doc.toObject ? doc.toObject() : doc;
  o.id = String(o._id);
  return o;
}

module.exports = { h, bad, esc, out };