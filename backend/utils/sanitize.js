// Protects every route from NoSQL-injection style input (e.g. {"email": {"$ne": ""}})
// and from absurd payloads: keys starting with "$" or containing "." are dropped,
// strings are capped, and objects can't be nested too deep.
const MAX_STRING = 10 * 1024 * 1024; // big enough for a base64 photo, nothing more
const MAX_DEPTH = 8;

function clean(v, depth = 0) {
  if (depth > MAX_DEPTH) return undefined;
  if (typeof v === 'string') return v.length > MAX_STRING ? v.slice(0, MAX_STRING) : v;
  if (Array.isArray(v)) return v.slice(0, 500).map(x => clean(x, depth + 1));
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) {
      if (k.startsWith('$') || k.includes('.') || k === '__proto__' || k === 'constructor' || k === 'prototype') continue;
      out[k] = clean(val, depth + 1);
    }
    return out;
  }
  return v;
}

// Query values must be plain strings (Express can turn ?a[$ne]=1 into an object)
function cleanQuery(q) {
  const out = {};
  for (const [k, v] of Object.entries(q || {})) {
    if (k.startsWith('$') || k.includes('.')) continue;
    out[k] = Array.isArray(v) ? String(v[0]) : typeof v === 'object' && v !== null ? '' : v;
  }
  return out;
}

function sanitize(req, res, next) {
  if (req.body && typeof req.body === 'object') req.body = clean(req.body);
  // Express 5: req.query is a getter, so replace it with a cleaned copy
  const q = cleanQuery(req.query);
  Object.defineProperty(req, 'query', { value: q, writable: true, configurable: true });
  next();
}

module.exports = { sanitize, clean, cleanQuery };
