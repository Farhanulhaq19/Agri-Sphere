const express = require('express');
const { h, bad } = require('../../utils/http');
const { saveImage, payAccount } = require('../../utils/uploads');

const router = express.Router();

// Upload one photo: { image: "data:image/jpeg;base64,...", folder: "listings" | "machines" | "warehouses" | "crops" | "profiles" }
router.post('/uploads', h(async (req, res) => {
  if (req.me.demo) throw bad('Please log in to upload photos', 401);
  const b = req.body || {};
  if (b.folder === 'payments') throw bad('Use the payment screen to upload receipts');
  const url = saveImage(b.image, b.folder, String(req.me.id).slice(-6));
  res.status(201).json({ url });
}));

// A payment screenshot, only for the buyer, the seller / owner, or an admin.
router.get('/receipt', h(async (req, res) => {
  const p = String(req.query.p || '');
  if (!/^\/uploads\/payments\/[\w.-]+$/.test(p)) throw bad('Not found', 404);
  const me = req.me.id;
  const admin = req.me.role === 'admin' || (req.me.roles || []).includes('admin');
  const { Order } = require('../../models/agri');
  const { MachineBooking } = require('../../models/machinery');
  const { StorageBooking } = require('../../models/warehouse');
  const o = await Order.findOne({ paymentProof: p });
  const m = o ? null : await MachineBooking.findOne({ paymentProof: p });
  const s = o || m ? null : await StorageBooking.findOne({ 'payments.proof': p });
  const allowed = admin ||
    (o && (o.owner === me || o.seller === me || o.items.some(i => i.sellerId === me))) ||
    (m && (m.farmer === me || m.owner === me)) ||
    (s && (s.farmer === me || s.owner === me));
  if (!allowed) throw bad('Not allowed', 403);
  res.set('Cache-Control', 'private, max-age=3600');
  res.sendFile(require('path').join(__dirname, '..', '..', p));
}));

// Account that online payments (Easypaisa / card via Easypaisa) are sent to
router.get('/payment-account', h(async (req, res) => { res.json(payAccount()); }));

module.exports = router;
