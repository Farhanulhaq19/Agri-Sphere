const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { Profile, Notification } = require('../models/agri');

const ROLES = ['farmer', 'buyer', 'expert', 'supplier', 'machinery_owner', 'warehouse_owner', 'admin'];

// Finds the users collection created by your existing auth code
function userModel() {
  if (mongoose.models.User) return mongoose.models.User;
  const n = mongoose.modelNames().find(x => /user/i.test(x) && !/^Agri/.test(x));
  return n ? mongoose.models[n] : null;
}

function adminEmails() {
  return (process.env.ADMIN_EMAILS || '').split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
}

// "Machinery Owner", "MachineryOwner", "machinery-owner" -> machinery_owner
function normRole(r) {
  const k = String(r || 'farmer').toLowerCase().replace(/[^a-z]/g, '');
  const map = {
    farmer: 'farmer', buyer: 'buyer', marketperson: 'buyer', expert: 'expert', agriexpert: 'expert',
    supplier: 'supplier', fertilizersupplier: 'supplier', machineryowner: 'machinery_owner',
    warehouseowner: 'warehouse_owner', admin: 'admin'
  };
  return map[k] || 'farmer';
}

// Token -> user (from your users collection). No token = demo farmer.
async function identify(req) {
  const demo = { id: 'demo', name: 'Ali Khan', role: 'farmer', roles: ['farmer'], email: '', demo: true };
  const t = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!t) return demo;
  let d;
  try {
    d = jwt.verify(t, process.env.JWT_SECRET);
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
  const email = String((u && u.email) || d.email || '').toLowerCase();
  const name = (u && (u.name || u.fullName || u.username)) || d.name || (email ? email.split('@')[0] : 'User');

  const stored = (u && Array.isArray(u.roles) && u.roles.length) ? u.roles : [(u && (u.role || u.userType)) || d.role];
  const isAdminEmail = !!email && adminEmails().includes(email);
  // when ADMIN_EMAILS is configured, only those emails can ever be admin
  const lock = adminEmails().length > 0 && !isAdminEmail;
  const roles = [...new Set(stored.map(normRole).map(r => (r === 'admin' && lock ? 'farmer' : r)))];
  if (isAdminEmail && !roles.includes('admin')) roles.push('admin');

  let role = normRole((u && (u.role || u.userType)) || d.role);
  if (role === 'admin' && lock) role = 'farmer';
  // accounts created before multi-role existed: an admin email is simply the admin
  if (isAdminEmail && !(u && Array.isArray(u.roles) && u.roles.length)) role = 'admin';
  if (!roles.includes(role)) role = roles[0];

  return { id, name, email, role, roles, phone: (u && (u.phone || u.phoneNumber)) || '', demo: false };
}

// strict: needs a real logged-in user with one of the roles
const requireRole = (...roles) => (req, res, next) => {
  if (req.me.demo) return res.status(401).json({ message: 'Please log in first' });
  if (!roles.includes(req.me.role)) return res.status(403).json({ message: 'This area is only for ' + roles.join(' / ').replace(/_/g, ' ') + ' accounts. Switch your role from the Account page.' });
  next();
};

// soft: also allows the demo user (whose role is farmer)
const roleIn = (...roles) => (req, res, next) =>
  roles.includes(req.me.role) ? next() : res.status(403).json({ message: 'Not available for ' + req.me.role.replace(/_/g, ' ') + ' accounts' });

// any real, logged-in account (any role)
const loggedIn = (req, res, next) =>
  req.me.demo ? res.status(401).json({ message: 'Please log in first' }) : next();

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
  try {
    const n = await Notification.create({ user: String(user), title, body, type: type || 'info', ref: ref || '' });
    // lazy requires: realtime.js and push.js both depend on this file
    require('./realtime').emitTo(user, 'notification', { id: String(n._id), title, body, type: n.type, ref: n.ref });
    require('./push').sendPush(user, title, body, { type: n.type, ref: n.ref });
  } catch (e) { /* notifications must never break the action */ }
}

module.exports = { identify, requireRole, roleIn, loggedIn, ensureProfile, notify, userModel, normRole, ROLES };
