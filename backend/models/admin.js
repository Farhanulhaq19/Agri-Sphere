const mongoose = require('mongoose');
const S = mongoose.Schema;

// Every admin decision is recorded: who did what, to what, and when (accountability for payments and moderation).
const AdminLog = mongoose.models.AgriAdminLog || mongoose.model('AgriAdminLog', new S({
  admin: { type: String, index: true },
  adminName: String,
  action: String,       // e.g. "payment.approve", "user.verify", "listing.removed"
  target: String,       // id of the order / user / listing
  detail: String
}, { timestamps: true }));

async function logAdmin(me, action, target, detail) {
  try {
    await AdminLog.create({ admin: me.id, adminName: me.name, action, target: String(target || ''), detail: String(detail || '').slice(0, 300) });
  } catch (e) { /* logging must never break the action */ }
}

module.exports = { AdminLog, logAdmin };
