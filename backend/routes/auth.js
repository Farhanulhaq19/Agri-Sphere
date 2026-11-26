const express = require('express');
const { safe } = require('../utils/safeLog');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const EmailOtp = require('../models/EmailOtp');
const ResetOtp = require('../models/ResetOtp');
const { rateLimit } = require('../utils/rateLimit');

const router = express.Router();
const googleClient = new OAuth2Client();

const ROLES = User.ROLES; // Farmer, Buyer, Expert, Supplier, MachineryOwner, WarehouseOwner, Admin
const SELF_ROLES = ROLES.filter((r) => r !== 'Admin'); // nobody can pick Admin themselves
const NAME_RE = /^\p{L}+(?: \p{L}+)*$/u;
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/;
const PHONE_RE = /^\+?[0-9]{10,14}$/;

const cleanName = (n) => String(n || '').trim().replace(/\s+/g, ' ');
const cleanEmail = (e) => String(e || '').trim().toLowerCase();
const hashCode = (email, code) => crypto.createHash('sha256').update(email + ':' + code).digest('hex');
const signToken = (user) => jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
const adminEmails = () =>
  (process.env.ADMIN_EMAILS || '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);

const rolesOf = (u) => {
  const list = u.roles && u.roles.length ? [...u.roles] : [u.role || 'Farmer'];
  if (adminEmails().includes(u.email) && !list.includes('Admin')) list.push('Admin');
  return list;
};
const activeRoleOf = (u) => {
  const list = rolesOf(u);
  if (u.roles && u.roles.length) return list.includes(u.role) ? u.role : list[0];
  return adminEmails().includes(u.email) ? 'Admin' : u.role || 'Farmer';
};
const publicUser = (u, token) => ({
  id: u._id,
  name: u.name,
  email: u.email || '',
  phone: u.phone || '',
  role: activeRoleOf(u),
  roles: rolesOf(u),
  hasPassword: !!u.passwordHash,
  token,
});
const ok = (res, message, data) => res.json({ success: true, message, data });
const fail = (res, message, status = 400, data) => res.status(status).json({ success: false, message, data });

function parseRoles(body) {
  let list = [];
  if (Array.isArray(body.roles)) list = body.roles;
  else if (body.role) list = [body.role];
  list = [...new Set(list.map((r) => String(r).replace(/[\s_-]+/g, '')))];
  const map = {
    farmer: 'Farmer', buyer: 'Buyer', marketperson: 'Buyer', expert: 'Expert', agriexpert: 'Expert',
    supplier: 'Supplier', fertilizersupplier: 'Supplier', machineryowner: 'MachineryOwner',
    warehouseowner: 'WarehouseOwner',
  };
  const out = [];
  for (const r of list) {
    const m = map[r.toLowerCase()];
    if (m && SELF_ROLES.includes(m) && !out.includes(m)) out.push(m);
  }
  return out.length ? out : ['Farmer'];
}

function checkName(name) {
  if (!name) return 'Enter your full name';
  if (name.length < 2 || name.length > 50) return 'Name must be 2 to 50 letters';
  if (!NAME_RE.test(name)) return 'Name can contain letters only (no numbers or symbols)';
  return null;
}
function checkEmail(email) {
  if (!email || email.length > 254 || !EMAIL_RE.test(email)) return 'Enter a valid email address';
  return null;
}
function checkPassword(pw) {
  if (pw.length < 8) return 'Password must be at least 8 characters';
  if (pw.length > 72) return 'Password is too long';
  if (!/[A-Za-z]/.test(pw) || !/[0-9]/.test(pw)) return 'Use letters and at least one number';
  return null;
}

// ---------------------------------------------------------------- email sending
let transporter = null;
function getTransporter() {
  if (transporter) return transporter;
  if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) return null;
  transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
  });
  return transporter;
}

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

async function sendCodeEmail(email, name, code, purpose) {
  const t = getTransporter();
  if (!t) return false;
  const reset = purpose === 'reset';
  const subject = reset ? 'Reset your AgriSphere password' : 'Your AgriSphere verification code';
  const intro = reset ? 'Use this code to reset your password:' : 'Your verification code is:';
  const tail = reset
    ? 'It expires in 10 minutes. If you did not ask to reset your password, ignore this email and your password stays the same.'
    : 'It expires in 10 minutes. If you did not sign up, ignore this email.';
  await t.sendMail({
    from: `"AgriSphere" <${process.env.EMAIL_USER}>`,
    to: email,
    subject,
    text: `Hi ${name},\n\n${intro} ${code}\n${tail}`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto">
      <h2 style="color:#0F5A32">AgriSphere</h2>
      <p>Hi ${esc(name)},</p>
      <p>${intro}</p>
      <p style="font-size:34px;font-weight:bold;letter-spacing:8px;color:#2E9B52">${code}</p>
      <p style="color:#6B7C72">${tail}</p>
    </div>`,
  });
  return true;
}

// creates a code, stores its hash, emails it. Returns { sent, dev, code }
async function issueCode(Model, email, name, purpose) {
  const code = String(crypto.randomInt(100000, 1000000));
  await Model.findOneAndUpdate(
    { email },
    { codeHash: hashCode(email, code), attempts: 0, expiresAt: new Date(Date.now() + 10 * 60 * 1000) },
    { upsert: true, new: true }
  );
  let sent = false;
  try {
    sent = await sendCodeEmail(email, name, code, purpose);
  } catch (e) {
    console.error('Email send failed:', e.message);
  }
  const dev = process.env.DEV_MODE === 'true';
  if (!sent) console.log(`[OTP:${safe(purpose)}] code for ${safe(email)}: ${safe(code)}`);
  return { sent, dev, code };
}

const codeMessage = (r) => (r.sent ? 'Verification code sent to your email' : `Email not configured. Dev code: ${r.code}`);

// auth middleware
async function requireAuth(req, res, next) {
  try {
    const token = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
    const { id } = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(id);
    if (!user) return fail(res, 'User not found', 401);
    req.user = user;
    next();
  } catch (e) {
    return fail(res, 'Not authorised', 401);
  }
}

const loginLimit = rateLimit({ max: 15, message: 'Too many login attempts. Try again in a few minutes.' });
const codeLimit = rateLimit({ max: 8, message: 'Too many requests. Try again in a few minutes.' });

// ---------------------------------------------------------------- SIGNUP
router.post('/signup', codeLimit, async (req, res) => {
  try {
    const name = cleanName(req.body.name);
    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || '');
    const phone = String(req.body.phone || '').replace(/[\s-]/g, '');
    const roles = parseRoles(req.body);
    const active = roles.includes(req.body.activeRole) ? req.body.activeRole : roles[0];

    const err = checkName(name) || checkEmail(email) || checkPassword(password) ||
      (phone && !PHONE_RE.test(phone) ? 'Enter a valid phone number' : null);
    if (err) return fail(res, err);

    let user = await User.findOne({ email });
    if (user && user.emailVerified) {
      return fail(res, 'An account with this email already exists. Please log in.', 409);
    }
    const passwordHash = await bcrypt.hash(password, 10);
    if (user) {
      user.name = name;
      user.passwordHash = passwordHash;
      user.roles = roles;
      user.role = active;
      if (phone) user.phone = phone;
      await user.save();
    } else {
      user = await User.create({ name, email, phone, passwordHash, roles, role: active, emailVerified: false });
    }

    const r = await issueCode(EmailOtp, email, name, 'signup');
    if (!r.sent && !r.dev) return fail(res, 'Could not send the verification email. Try again.', 502);
    return ok(res, codeMessage(r), { email, needsVerification: true });
  } catch (e) {
    console.error(e);
    if (e.code === 11000) return fail(res, 'An account with this email already exists', 409);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- RESEND SIGNUP CODE
router.post('/send-otp', codeLimit, async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    if (checkEmail(email)) return fail(res, 'Enter a valid email address');
    const user = await User.findOne({ email });
    if (!user || user.emailVerified) return fail(res, 'No pending verification for this email', 404);

    const rec = await EmailOtp.findOne({ email });
    if (rec && Date.now() - rec.updatedAt.getTime() < 30 * 1000) {
      return fail(res, 'Please wait a few seconds before requesting another code', 429);
    }
    const r = await issueCode(EmailOtp, email, user.name, 'signup');
    if (!r.sent && !r.dev) return fail(res, 'Could not send the email. Try again.', 502);
    return ok(res, codeMessage(r));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- VERIFY EMAIL
router.post('/verify-email', codeLimit, async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    const code = String(req.body.code || '').trim();
    const rec = await EmailOtp.findOne({ email });
    if (!rec) return fail(res, 'Code expired. Tap Resend to get a new one.');
    if (rec.attempts >= 5) return fail(res, 'Too many attempts. Request a new code.', 429);

    if (rec.codeHash !== hashCode(email, code)) {
      rec.attempts += 1;
      await rec.save();
      return fail(res, 'Incorrect code');
    }
    await EmailOtp.deleteOne({ email });
    const user = await User.findOneAndUpdate({ email }, { emailVerified: true }, { new: true });
    if (!user) return fail(res, 'Account not found', 404);
    return ok(res, 'Email verified', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- LOGIN
router.post('/login', loginLimit, async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || '');
    if (checkEmail(email) || !password) return fail(res, 'Enter a valid email and your password');

    const user = await User.findOne({ email });
    if (!user) return fail(res, 'Invalid email or password', 401);
    if (!user.passwordHash) {
      return fail(res, 'This account uses Google. Tap Continue with Google, or use Forgot password to set a password.', 401);
    }
    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) return fail(res, 'Invalid email or password', 401);

    if (!user.emailVerified) {
      await issueCode(EmailOtp, email, user.name, 'signup');
      return fail(res, 'Please verify your email. We sent you a new code.', 403, { needsVerification: true, email });
    }
    // optional: the login screen can ask for a particular role
    const want = req.body.role ? parseRoles({ role: req.body.role })[0] : null;
    if (want && rolesOf(user).includes(want) && user.role !== want) {
      user.role = want;
      await user.save();
    }
    return ok(res, 'Login successful', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- FORGOT / RESET PASSWORD
// Always answers the same way, so nobody can use it to find out which emails are registered.
router.post('/forgot-password', codeLimit, async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    if (checkEmail(email)) return fail(res, 'Enter a valid email address');
    const generic = 'If an account exists for this email, a reset code has been sent.';

    const user = await User.findOne({ email });
    if (!user || !user.emailVerified) return ok(res, generic);

    const rec = await ResetOtp.findOne({ email });
    if (rec && Date.now() - rec.updatedAt.getTime() < 30 * 1000) {
      return fail(res, 'Please wait a few seconds before requesting another code', 429);
    }
    const r = await issueCode(ResetOtp, email, user.name, 'reset');
    if (!r.sent && !r.dev) return fail(res, 'Could not send the email. Try again.', 502);
    return ok(res, r.sent ? generic : `Email not configured. Dev code: ${r.code}`);
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

router.post('/reset-password', codeLimit, async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    const code = String(req.body.code || '').trim();
    const password = String(req.body.password || req.body.newPassword || '');
    const pwErr = checkPassword(password);
    if (checkEmail(email)) return fail(res, 'Enter a valid email address');
    if (!/^\d{6}$/.test(code)) return fail(res, 'Enter the 6-digit code');
    if (pwErr) return fail(res, pwErr);

    const rec = await ResetOtp.findOne({ email });
    if (!rec) return fail(res, 'Code expired. Request a new one.');
    if (rec.attempts >= 5) return fail(res, 'Too many wrong attempts. Request a new code.', 429);
    if (rec.codeHash !== hashCode(email, code)) {
      rec.attempts += 1;
      await rec.save();
      return fail(res, 'Incorrect code');
    }
    const user = await User.findOne({ email });
    if (!user) return fail(res, 'Account not found', 404);

    user.passwordHash = await bcrypt.hash(password, 10);
    user.passwordChangedAt = new Date();
    user.emailVerified = true; // they proved they own the inbox
    await user.save();
    await ResetOtp.deleteOne({ email });
    return ok(res, 'Password updated. Please log in with your new password.');
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- CHANGE PASSWORD (logged in)
router.post('/change-password', requireAuth, loginLimit, async (req, res) => {
  try {
    const current = String(req.body.currentPassword || '');
    const next = String(req.body.newPassword || '');
    const user = req.user;
    if (user.passwordHash) {
      const match = await bcrypt.compare(current, user.passwordHash);
      if (!match) return fail(res, 'Current password is incorrect', 401);
    }
    const err = checkPassword(next);
    if (err) return fail(res, err);
    if (user.passwordHash && (await bcrypt.compare(next, user.passwordHash))) {
      return fail(res, 'New password must be different from the current one');
    }
    user.passwordHash = await bcrypt.hash(next, 10);
    user.passwordChangedAt = new Date();
    await user.save();
    return ok(res, 'Password changed');
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- ROLES (multi-role accounts)
router.post('/switch-role', requireAuth, async (req, res) => {
  try {
    const want = parseRoles({ role: req.body.role })[0];
    const user = req.user;
    const list = rolesOf(user);
    const target = req.body.role === 'Admin' ? 'Admin' : want;
    if (!list.includes(target)) return fail(res, 'You do not have that role yet. Add it first.', 403);
    if (!user.roles || !user.roles.length) user.roles = list.filter((r) => r !== 'Admin');
    user.role = target;
    await user.save();
    return ok(res, 'Switched role', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

router.post('/add-role', requireAuth, async (req, res) => {
  try {
    const add = parseRoles({ roles: Array.isArray(req.body.roles) ? req.body.roles : [req.body.role] });
    const user = req.user;
    const current = user.roles && user.roles.length ? [...user.roles] : [user.role || 'Farmer'];
    for (const r of add) if (!current.includes(r)) current.push(r);
    user.roles = current;
    if (req.body.makeActive && add.length) user.role = add[0];
    await user.save();
    return ok(res, 'Role added', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

router.post('/remove-role', requireAuth, async (req, res) => {
  try {
    const target = parseRoles({ role: req.body.role })[0];
    const user = req.user;
    const current = user.roles && user.roles.length ? [...user.roles] : [user.role || 'Farmer'];
    if (current.length <= 1) return fail(res, 'You need at least one role');
    if (!current.includes(target)) return fail(res, 'You do not have that role');
    user.roles = current.filter((r) => r !== target);
    if (user.role === target) user.role = user.roles[0];
    await user.save();
    return ok(res, 'Role removed', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- UPDATE ACCOUNT
router.put('/account', requireAuth, async (req, res) => {
  try {
    const user = req.user;
    if (req.body.name !== undefined) {
      const name = cleanName(req.body.name);
      const err = checkName(name);
      if (err) return fail(res, err);
      user.name = name;
    }
    if (req.body.phone !== undefined) {
      const phone = String(req.body.phone || '').replace(/[\s-]/g, '');
      if (phone && !PHONE_RE.test(phone)) return fail(res, 'Enter a valid phone number');
      user.phone = phone;
    }
    if (req.body.location !== undefined) user.location = String(req.body.location).slice(0, 120);
    await user.save();
    return ok(res, 'Account updated', publicUser(user));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- GOOGLE
router.post('/google', loginLimit, async (req, res) => {
  try {
    const { idToken, mode } = req.body;
    const roles = parseRoles(req.body);
    if (!idToken) return fail(res, 'Missing Google token');

    const ticket = await googleClient.verifyIdToken({ idToken, audience: process.env.GOOGLE_CLIENT_ID });
    const p = ticket.getPayload();
    const email = cleanEmail(p.email);
    if (!p.email_verified) return fail(res, 'Your Google email is not verified', 401);

    let user = await User.findOne({ $or: [{ googleId: p.sub }, { email }] });
    if (!user) {
      if (mode !== 'signup') {
        return fail(res, 'No account found for this Google account. Please sign up first.', 404, { noAccount: true });
      }
      const gName = cleanName(String(p.name || '').replace(/[^\p{L} ]/gu, '')) || 'User';
      user = await User.create({ name: gName, email, googleId: p.sub, roles, role: roles[0], emailVerified: true });
    } else {
      if (!user.emailVerified) user.passwordHash = undefined; // unverified signup is replaced by the real owner
      user.googleId = user.googleId || p.sub;
      user.emailVerified = true;
      await user.save();
    }
    return ok(res, 'Login successful', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Google verification failed', 401);
  }
});

// ---------------------------------------------------------------- ME
router.get('/me', requireAuth, (req, res) => ok(res, 'OK', publicUser(req.user)));

module.exports = router;
