const express = require('express');
const { identify } = require('../utils/identity');
const { seed } = require('../utils/seed');
const { seedFleet } = require('../utils/seedFleet');

const router = express.Router();
router.use(express.json());

router.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', process.env.CORS_ORIGIN || '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

// Who is calling? (token -> user from your users collection)
router.use(async (req, res, next) => {
  try { req.me = await identify(req); } catch (e) { req.me = { invalid: true }; }
  if (req.me.invalid) return res.status(401).json({ message: 'Session expired. Please log in again.' });
  next();
});

// demo data on first request (set SEED_DEMO_DATA=false in production)
let seeded = false;
router.use(async (req, res, next) => {
  if (!seeded && process.env.SEED_DEMO_DATA !== 'false') {
    seeded = true;
    try { await seed(); await seedFleet(); console.log('AgriSphere demo data ready'); }
    catch (e) { seeded = false; console.error('Seed failed:', e.message); }
  }
  next();
});

['profile', 'farmer', 'marketplace', 'offers', 'orders', 'expert', 'supplier', 'admin', 'machinery', 'warehouse', 'uploads', 'social', 'ai'].forEach(m => {
  router.use(require('./modules/' + m));
});

module.exports = router;
