const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { Profile, Notification } = require('../models/agri');

const ROLES = ['farmer', 'buyer', 'expert', 'supplier', 'admin'];

// Finds the users collection created by your existing auth code
function userModel() {
  if (mongoose.models.User) return mongoose.models.User;
  const n = mongoose.modelNames().find(x => /user/i.test(x) && !/^Agri/.test(x));
  return n ? mongoose.models[n] : null;
}

function adminEmails() {
  return (process.env.ADMIN_EMAILS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
}

function normRole(r, email) {
  let role = String(r || 'farmer').toLowerCase().replace(/[\s-]+/g, '_');
  if (role === 'agri_expert') role = 'expert';
  if (!ROLES.includes(role)) role = 'farmer';
  const admins = adminEmails();
  const e = String(email || '').toLowerCase();
  if (e && admins.includes(e)) return 'admin';
  // nobody can make themselves admin at signup when ADMIN_EMAILS is configured
  if (role === 'admin' && admins.length > 0) return 'farmer';
  return role;
}

// Token -> user (from your users collection). No token = demo farmer.
async function identify(req) {
  const demo = { id: 'demo', name: 'Ali Khan', role: 'farmer', email: '', demo: true };
  const t = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!t) return demo;
  let d;
  try {
    d = jwt.verify(t, process.env.JWT_SECRET || 'secret');
  } catch (e) {
    return { invalid: true };
  }
  const id = String(d.id || d._id || d.userId || d.sub || '');
  if (!id) return { invalid: true };
  let u = null;
  const U = userModel();
  if (U) {
    try { u = await U.findById(id).lean(); } catch (e) { u = null; }
  }
  const email = (u && u.email) || d.email || '';
  const name = (u && (u.name || u.fullName || u.username)) || d.name || (email ? email.split('@')[0] : 'User');
  const role = normRole((u && (u.role || u.userType)) || d.role, email);
  return { id, name, email, role, phone: (u && (u.phone || u.phoneNumber)) || '', demo: false };
}

// strict: needs a real logged-in user with one of the roles
const requireRole = (...roles) => (req, res, next) => {
  if (req.me.demo) return res.status(401).json({ message: 'Please log in first' });
  if (!roles.includes(req.me.role)) return res.status(403).json({ message: 'This area is only for ' + roles.join(' / ') + ' accounts' });
  next();
};

// soft: also allows the demo user (whose role is farmer)
const roleIn = (...roles) => (req, res, next) =>
  roles.includes(req.me.role) ? next() : res.status(403).json({ message: 'Not available for ' + req.me.role + ' accounts' });

async function ensureProfile(me) {
  let p = await Profile.findOne({ user: me.id });
  if (!p) {
    try {
      p = await Profile.create({
        user: me.id, role: me.role, name: me.name, email: me.email, phone: me.phone || '',
        businessName: me.role === 'supplier' ? me.name + ' Agro Supplies' : ''
      });
    } catch (e) {
      p = await Profile.findOne({ user: me.id });
    }
  }
  if (p && p.role !== me.role) { p.role = me.role; await p.save(); }
  return p;
}

async function notify(user, title, body, type, ref) {
  try { await Notification.create({ user: String(user), title, body, type: type || 'info', ref: ref || '' }); } catch (e) { /* ignore */ }
}

module.exports = { identify, requireRole, roleIn, ensureProfile, notify, userModel, normRole };