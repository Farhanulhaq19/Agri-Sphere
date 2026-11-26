// Tiny in-memory limiter (no extra package). Good enough for one server instance.
const buckets = new Map();

function rateLimit({ windowMs = 15 * 60 * 1000, max = 20, message = 'Too many attempts. Please try again later.' } = {}) {
  return (req, res, next) => {
    const key = (req.ip || 'ip') + '|' + req.baseUrl + req.path;
    const now = Date.now();
    let b = buckets.get(key);
    if (!b || b.reset < now) b = { count: 0, reset: now + windowMs };
    b.count += 1;
    buckets.set(key, b);
    if (b.count > max) {
      res.set('Retry-After', String(Math.ceil((b.reset - now) / 1000)));
      return res.status(429).json({ success: false, message });
    }
    next();
  };
}

setInterval(() => {
  const now = Date.now();
  for (const [k, b] of buckets) if (b.reset < now) buckets.delete(k);
}, 10 * 60 * 1000).unref();

module.exports = { rateLimit };
