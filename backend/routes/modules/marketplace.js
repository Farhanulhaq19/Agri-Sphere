const express = require('express');
const { Listing, Order } = require('../../models/agri');
const { h, bad, esc, out } = require('../../utils/http');
const { roleIn } = require('../../utils/identity');
const { createListing, applyListingEdit } = require('../../utils/listings');
const { applyDistance } = require('../../utils/geo');

const router = express.Router();

router.get('/listings', h(async (req, res) => {
  const f = { quantityKg: { $gt: 0 }, status: { $nin: ['paused', 'removed'] } };
  if (req.query.category && req.query.category !== 'All') f.category = new RegExp('^' + esc(req.query.category) + '$', 'i');
  if (req.query.kind) f.kind = req.query.kind;
  if (req.query.q) {
    const r = new RegExp(esc(req.query.q), 'i');
    f.$or = [{ title: r }, { sellerName: r }, { category: r }, { brand: r }];
  }
  if (req.query.mine === '1') f.seller = req.me.id;
  if (req.query.city) f.location = new RegExp(esc(req.query.city), 'i');
  if (req.query.minPrice || req.query.maxPrice) {
    f.pricePerKg = {};
    if (req.query.minPrice) f.pricePerKg.$gte = Number(req.query.minPrice);
    if (req.query.maxPrice) f.pricePerKg.$lte = Number(req.query.maxPrice);
  }
  if (req.query.verified === '1') f.verified = true;
  let sort = { createdAt: -1 };
  if (req.query.sort === 'price') sort = { pricePerKg: 1 };
  if (req.query.sort === 'rating') sort = { rating: -1 };
  // paging: ?page=1&limit=30 ("near me" sorts by distance, so it loads one bigger page)
  const near = req.query.sort === 'near';
  const limit = near ? 120 : Math.min(60, Math.max(1, Number(req.query.limit) || 30));
  const page = near ? 1 : Math.max(1, Number(req.query.page) || 1);
  const list = await Listing.find(f).sort(sort).skip((page - 1) * limit).limit(limit + 1);
  const hasMore = list.length > limit;
  const items = list.slice(0, limit).map(l => {
    const x = out(l);
    x.isNew = Date.now() - new Date(x.createdAt).getTime() < 7 * 864e5;
    x.mine = x.seller === req.me.id;
    return x;
  });
  res.json({ items: applyDistance(items, req.query), page, hasMore });
}));

// Marketplace home: every section in one call (fast + works well offline from the cache)
router.get('/market-home', h(async (req, res) => {
  const live = { quantityKg: { $gt: 0 }, status: { $nin: ['paused', 'removed'] } };
  const DAY = 864e5;
  const [all, cats] = await Promise.all([
    Listing.find(live).sort({ createdAt: -1 }).limit(120),
    Listing.aggregate([{ $match: live }, { $group: { _id: '$category', n: { $sum: 1 }, avg: { $avg: '$pricePerKg' } } }])
  ]);
  const avg = {};
  cats.forEach(c => { avg[c._id] = c.avg; });
  let items = all.map(l => {
    const x = out(l);
    const a = avg[x.category];
    // "deal" = at least 10% cheaper than the category average
    if (a && x.pricePerKg <= a * 0.9) x.dealPct = Math.round((1 - x.pricePerKg / a) * 100);
    x.isNew = Date.now() - new Date(x.createdAt).getTime() < 7 * DAY;
    x.mine = x.seller === req.me.id;
    return x;
  });
  items = applyDistance(items, req.query);
  const others = items.filter(i => !i.mine);
  const near = others.filter(i => i.distanceKm !== undefined).sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 10);
  res.json({
    categories: cats.map(c => ({ name: c._id, count: c.n, avgPrice: Math.round(c.avg) })).sort((a, b) => b.count - a.count),
    deals: others.filter(i => i.dealPct).sort((a, b) => b.dealPct - a.dealPct).slice(0, 10),
    near,
    topRated: others.slice().sort((a, b) => (b.rating || 0) - (a.rating || 0) || (b.sales || 0) - (a.sales || 0)).slice(0, 10),
    fresh: others.filter(i => i.isNew).slice(0, 10),
    inputs: others.filter(i => i.kind === 'input').slice(0, 10),
    total: others.length
  });
}));

// Public seller page: who they are, their products and what buyers said
router.get('/sellers/:id', h(async (req, res) => {
  const { Profile } = require('../../models/agri');
  const { Review } = require('../../models/social');
  const { userModel } = require('../../utils/identity');
  const id = String(req.params.id);
  const U = userModel();
  let user = null;
  if (U && /^[a-f0-9]{24}$/i.test(id)) user = await U.findById(id, { name: 1, createdAt: 1, location: 1 }).lean();
  const [profile, items] = await Promise.all([
    Profile.findOne({ user: id }).lean(),
    Listing.find({ seller: id, status: { $nin: ['removed'] } }).sort({ createdAt: -1 }).limit(60)
  ]);
  if (!user && !profile && !items.length) throw bad('Seller not found', 404);
  const reviews = await Review.find({ listing: { $in: items.map(i => i._id) } }).sort({ createdAt: -1 }).limit(15);
  const rated = items.filter(i => (i.reviews || 0) > 0);
  const totalReviews = rated.reduce((a, i) => a + i.reviews, 0);
  res.json({
    id,
    name: (profile && (profile.businessName || profile.name)) || (user && user.name) || (items[0] && items[0].sellerName) || 'Seller',
    role: (profile && profile.role) || (items[0] && items[0].sellerRole) || 'farmer',
    city: (profile && profile.city) || (user && user.location) || (items[0] && items[0].location) || '',
    bio: (profile && profile.bio) || '',
    verified: !!((profile && profile.verified) || items.some(i => i.verified)),
    memberSince: (user && user.createdAt) || (profile && profile.createdAt) || null,
    stats: {
      products: items.filter(i => i.status !== 'paused' && i.quantityKg > 0).length,
      sales: items.reduce((a, i) => a + (i.sales || 0), 0),
      rating: totalReviews ? Math.round((rated.reduce((a, i) => a + i.rating * i.reviews, 0) / totalReviews) * 10) / 10 : 0,
      reviews: totalReviews
    },
    items: items.filter(i => i.status !== 'paused' && i.quantityKg > 0).map(l => ({ ...out(l), mine: l.seller === req.me.id })),
    reviews: reviews.map(r => {
      const l = items.find(i => String(i._id) === String(r.listing));
      return { name: r.name, rating: r.rating, text: r.text, at: r.createdAt, product: l ? l.title : '' };
    })
  });
}));

router.get('/listings/:id', h(async (req, res) => {
  const l = await Listing.findById(req.params.id);
  if (!l) throw bad('Listing not found', 404);
  const x = out(l);
  const [similar, sellerItems, peers] = await Promise.all([
    Listing.find({ _id: { $ne: l._id }, category: l.category, quantityKg: { $gt: 0 }, status: { $nin: ['paused', 'removed'] } }).sort({ rating: -1 }).limit(8),
    Listing.find({ seller: l.seller, status: { $nin: ['removed'] } }, { sales: 1, rating: 1 }),
    Listing.find({ title: new RegExp(esc(String(l.title).split(' ')[0]), 'i'), quantityKg: { $gt: 0 } }, { pricePerKg: 1 })
  ]);
  x.similar = similar.map(out);
  x.sellerStats = {
    listings: sellerItems.length,
    sales: sellerItems.reduce((a, i) => a + (i.sales || 0), 0),
    rating: sellerItems.length ? Math.round((sellerItems.reduce((a, i) => a + (i.rating || 0), 0) / sellerItems.length) * 10) / 10 : 0
  };
  const { Review } = require('../../models/social');
  const reviews = await Review.find({ listing: l._id }).sort({ createdAt: -1 }).limit(20);
  x.reviewList = reviews.map(r => ({ name: r.name, rating: r.rating, text: r.text, at: r.createdAt }));
  x.marketAvg = peers.length > 1 ? Math.round(peers.reduce((a, p) => a + p.pricePerKg, 0) / peers.length) : 0;
  x.mine = l.seller === req.me.id;
  res.json(x);
}));

router.post('/listings', roleIn('farmer', 'supplier'), h(async (req, res) => {
  const l = await createListing(req.me, req.body || {});
  res.status(201).json(out(l));
}));

router.patch('/listings/:id', roleIn('farmer', 'supplier'), h(async (req, res) => {
  const l = await Listing.findOne({ _id: req.params.id, seller: req.me.id });
  if (!l) throw bad('Listing not found', 404);
  applyListingEdit(l, req.body || {});
  await l.save();
  res.json(out(l));
}));

router.delete('/listings/:id', h(async (req, res) => {
  await Listing.deleteOne({ _id: req.params.id, seller: req.me.id });
  res.json({ ok: true });
}));

// Price trend + simple forecast for a product, from AgriSphere listings and orders (last 90 days),
// plus the usual Pakistani seasonal pattern. Not financial advice: an indication to plan selling.
const SEASON = {
  wheat: { low: [4, 5], high: [11, 12, 1, 2], tip: 'Prices are usually lowest at harvest (Apr-May) and highest in Nov-Feb.' },
  rice: { low: [10, 11], high: [5, 6, 7], tip: 'New rice arrives Oct-Nov, so prices dip; they usually recover by summer.' },
  cotton: { low: [9, 10], high: [2, 3, 4], tip: 'Picking season Sep-Nov brings lower prices; ginners pay more early in the year.' },
  maize: { low: [7, 11], high: [3, 4, 9], tip: 'Prices drop at each harvest (summer and autumn).' },
  potato: { low: [1, 2, 3], high: [8, 9, 10], tip: 'Main harvest Jan-Mar; cold-stored potatoes sell for more in Aug-Oct.' },
  onion: { low: [4, 5], high: [10, 11, 12], tip: 'Prices usually rise towards the end of the year.' },
  tomato: { low: [1, 2, 3], high: [6, 7, 11], tip: 'Prices swing a lot with weather and supply from Sindh.' },
  kinnow: { low: [1, 2], high: [11, 12], tip: 'Early-season kinnow (Nov-Dec) usually gets the best price.' },
  sugarcane: { low: [], high: [], tip: 'Mill rates are fixed each season by the government.' }
};

router.get('/market-insight', h(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 3) throw bad('Type a product name, e.g. wheat');
  const word = q.split(/\s+/)[0];
  const r = new RegExp(esc(word), 'i');
  const since = new Date(Date.now() - 90 * 864e5);
  const [listings, orders] = await Promise.all([
    Listing.find({ title: r, createdAt: { $gte: since } }, { pricePerKg: 1, createdAt: 1, unit: 1 }),
    Order.find({ 'items.title': r, status: { $ne: 'cancelled' }, createdAt: { $gte: since } }, { items: 1, createdAt: 1 })
  ]);
  // one point per price observation: listings (asking price) and sold items (real price, counted twice)
  const pts = listings.map(l => ({ t: l.createdAt.getTime(), p: l.pricePerKg }));
  orders.forEach(o => o.items.filter(i => r.test(i.title)).forEach(i => {
    const x = { t: o.createdAt.getTime(), p: i.pricePerKg };
    pts.push(x, x);
  }));
  const byDay = {};
  pts.forEach(x => {
    const d = new Date(x.t).toISOString().slice(0, 10);
    (byDay[d] = byDay[d] || []).push(x.p);
  });
  const series = Object.keys(byDay).sort().map(d => ({ date: d, price: Math.round(byDay[d].reduce((a, b) => a + b, 0) / byDay[d].length) }));
  const current = series.length ? series.slice(-5).reduce((a, s) => a + s.price, 0) / Math.min(5, series.length) : 0;

  // least-squares line through the daily averages
  let slope = 0, forecast7 = null, forecast14 = null, trend = 'unknown';
  if (series.length >= 4) {
    const t0 = new Date(series[0].date).getTime();
    const xs = series.map(s => (new Date(s.date).getTime() - t0) / 864e5);
    const ys = series.map(s => s.price);
    const n = xs.length;
    const mx = xs.reduce((a, b) => a + b, 0) / n;
    const my = ys.reduce((a, b) => a + b, 0) / n;
    const sxx = xs.reduce((a, x) => a + (x - mx) ** 2, 0) || 1;
    slope = xs.reduce((a, x, i) => a + (x - mx) * (ys[i] - my), 0) / sxx;
    const lastX = xs[n - 1];
    const at = (x) => Math.max(1, Math.round(my + slope * (x - mx)));
    forecast7 = at(lastX + 7);
    forecast14 = at(lastX + 14);
    const pct = my ? (slope * 14) / my : 0;
    trend = pct > 0.03 ? 'rising' : pct < -0.03 ? 'falling' : 'stable';
  }
  const key = Object.keys(SEASON).find(k => q.toLowerCase().includes(k));
  const month = new Date().getMonth() + 1;
  const season = key ? SEASON[key] : null;
  const seasonNow = season ? (season.low.includes(month) ? 'low' : season.high.includes(month) ? 'high' : 'normal') : 'unknown';
  let advice;
  if (trend === 'rising' || seasonNow === 'low') advice = 'Prices are expected to go up. If you can store safely, holding part of your crop may earn more.';
  else if (trend === 'falling' || seasonNow === 'high') advice = 'Prices are good now or falling. Selling soon is likely the better choice.';
  else if (trend === 'stable') advice = 'Prices are stable. Sell when it suits you; compare offers from several buyers.';
  else advice = 'Not enough AgriSphere data yet for a forecast. Compare with your local mandi rate.';
  res.json({
    product: word, points: pts.length, series, current: Math.round(current),
    trend, slopePerDay: Math.round(slope * 100) / 100, forecast7, forecast14,
    season: season ? { tip: season.tip, now: seasonNow } : null,
    advice, suggestStorage: trend === 'rising' || seasonNow === 'low',
    note: 'Forecast from AgriSphere prices in the last 90 days. It is an estimate, not a guarantee.'
  });
}));

router.get('/market-average', h(async (req, res) => {
  const q = String(req.query.q || '').trim();
  if (q.length < 3) return res.json({ average: 0, count: 0 });
  const list = await Listing.find({ title: new RegExp(esc(q.split(' ')[0]), 'i') });
  const avg = list.length ? Math.round(list.reduce((a, l) => a + l.pricePerKg, 0) / list.length) : 0;
  res.json({ average: avg, count: list.length });
}));

module.exports = router;