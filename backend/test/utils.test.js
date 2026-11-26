// Unit tests for the backend helpers. Run with:  npm test
// They use Node's built-in test runner and need no database.
process.env.NO_THUMBS = '1'; // no background thumbnail work during tests
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const { km, applyDistance, num } = require('../utils/geo');
const { cleanPhotos, saveImage, readProof, payAccount } = require('../utils/uploads');

test('km(): distance between Islamabad and Lahore is about 270 km', () => {
  const d = km(33.6844, 73.0479, 31.5204, 74.3587);
  assert.ok(d > 250 && d < 290, `got ${d}`);
});

test('km(): same point is 0 km', () => {
  assert.equal(km(30, 70, 30, 70), 0);
});

test('applyDistance(): adds distanceKm and sorts nearest first', () => {
  const items = [
    { id: 'far', lat: 31.52, lng: 74.35 },   // Lahore
    { id: 'near', lat: 33.6, lng: 73.0 },    // Islamabad
    { id: 'none' }                            // no location
  ];
  const out = applyDistance(items, { lat: '33.68', lng: '73.04', sort: 'near' });
  assert.equal(out[0].id, 'near');
  assert.equal(out[1].id, 'far');
  assert.equal(out[2].id, 'none');
  assert.equal(out[2].distanceKm, undefined);
});

test('applyDistance(): maxKm drops items that are too far or have no location', () => {
  const items = [{ id: 'a', lat: 33.6, lng: 73.0 }, { id: 'b', lat: 31.52, lng: 74.35 }, { id: 'c' }];
  const out = applyDistance(items, { lat: '33.68', lng: '73.04', maxKm: '50' });
  assert.deepEqual(out.map(i => i.id), ['a']);
});

test('applyDistance(): without lat/lng the list is unchanged', () => {
  const items = [{ id: 'x', lat: 1, lng: 1 }];
  assert.deepEqual(applyDistance(items, {}), items);
});

test('num(): turns form values into numbers or undefined', () => {
  assert.equal(num('12.5'), 12.5);
  assert.equal(num(''), undefined);
  assert.equal(num(null), undefined);
  assert.equal(num('abc'), undefined);
});

test('cleanPhotos(): keeps our own uploads and https links only, max 6', () => {
  const list = [
    '/uploads/listings/a.jpg',
    'https://example.com/b.png',
    'http://insecure.com/c.png',      // not https
    '/etc/passwd',                     // not an upload path
    '/uploads/../../secret.txt',       // path trick
    'javascript:alert(1)',
    '/uploads/machines/1.jpg', '/uploads/machines/2.jpg', '/uploads/machines/3.jpg',
    '/uploads/machines/4.jpg', '/uploads/machines/5.jpg'
  ];
  const out = cleanPhotos(list);
  assert.equal(out.length, 6);
  assert.ok(out.includes('/uploads/listings/a.jpg'));
  assert.ok(out.includes('https://example.com/b.png'));
  assert.ok(!out.some(p => p.includes('insecure') || p.includes('passwd') || p.includes('..') || p.startsWith('javascript')));
});

test('cleanPhotos(): non-array input gives an empty list', () => {
  assert.deepEqual(cleanPhotos('oops'), []);
  assert.deepEqual(cleanPhotos(undefined), []);
});

test('saveImage(): rejects anything that is not a PNG / JPG / WEBP data URL', () => {
  assert.throws(() => saveImage('hello', 'listings'), /PNG, JPG or WEBP/);
  assert.throws(() => saveImage('data:text/html;base64,PGgxPg==', 'listings'), /PNG, JPG or WEBP/);
});

test('saveImage(): rejects images over 5 MB', () => {
  const big = 'data:image/png;base64,' + Buffer.alloc(5 * 1024 * 1024 + 10).toString('base64');
  assert.throws(() => saveImage(big, 'listings'), /too large/);
});

test('saveImage(): saves a small PNG and returns its public path', () => {
  // 1x1 transparent PNG
  const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  const p = saveImage(png, 'listings', 'test');
  assert.match(p, /^\/uploads\/listings\/test-\d+-[a-z0-9]+\.png$/);
  const file = path.join(__dirname, '..', p);
  assert.ok(fs.existsSync(file));
  fs.unlinkSync(file); // clean up
});

test('saveImage(): unknown folders fall back to "listings" (no writing outside uploads)', () => {
  const png = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  const p = saveImage(png, '../../evil', 'test');
  assert.match(p, /^\/uploads\/listings\//);
  fs.unlinkSync(path.join(__dirname, '..', p));
});

test('readProof(): needs a transaction ID of at least 6 characters', () => {
  assert.throws(() => readProof({ ref: '123', image: 'x' }), /transaction ID/);
});

test('payAccount(): returns the Easypaisa number and name', () => {
  const a = payAccount();
  assert.equal(a.method, 'Easypaisa');
  assert.match(a.number, /^03\d{9}$/);
  assert.ok(a.name.length > 0);
});

// ---------------------------------------------------------------- crop calendar
const { buildTasks, whenText, planFor } = require('../utils/cropPlans');

test('planFor(): finds the right plan, also for alternative names', () => {
  assert.equal(planFor('Wheat Sehar').key, 'wheat');
  assert.equal(planFor('Basmati paddy').key, 'rice');
  assert.equal(planFor('Sweet corn').key, 'maize');
  assert.equal(planFor('Dragon fruit').key, 'default');
});

test('buildTasks(): wheat plan has dated tasks in order, starting on the sowing day', () => {
  const sow = new Date('2026-11-10T00:00:00Z');
  const t = buildTasks('Wheat', sow, 'Field B');
  assert.ok(t.length >= 8);
  assert.equal(new Date(t[0].due).getTime(), sow.getTime());
  assert.ok(t.every((x, i) => i === 0 || new Date(x.due) >= new Date(t[i - 1].due)));
  assert.ok(t.every(x => x.field === 'Field B' && x.done === false));
  assert.ok(t.some(x => x.type === 'irrigation') && t.some(x => x.type === 'harvest'));
});

test('whenText(): human friendly due dates', () => {
  const day = 864e5;
  assert.equal(whenText(new Date()), 'Today');
  assert.equal(whenText(new Date(Date.now() + day)), 'Tomorrow');
  assert.equal(whenText(new Date(Date.now() + 5 * day)), 'In 5 days');
  assert.equal(whenText(new Date(Date.now() - 3 * day)), '3 days ago');
});

// ---------------------------------------------------------------- input sanitizing
const { clean, cleanQuery } = require('../utils/sanitize');

test('clean(): removes MongoDB operators and prototype tricks from request bodies', () => {
  const out = clean({ email: { $ne: '' }, name: 'Ali', 'a.b': 1, __proto__: { admin: true }, nested: { $where: 'x', ok: 1 } });
  assert.deepEqual(out.email, {});
  assert.equal(out.name, 'Ali');
  assert.equal(out['a.b'], undefined);
  assert.equal(out.admin, undefined);
  assert.deepEqual(out.nested, { ok: 1 });
});

test('cleanQuery(): query values become plain strings', () => {
  const q = cleanQuery({ q: 'wheat', price: { $gt: '0' }, list: ['a', 'b'], $where: '1' });
  assert.equal(q.q, 'wheat');
  assert.equal(q.price, '');
  assert.equal(q.list, 'a');
  assert.equal(q.$where, undefined);
});
