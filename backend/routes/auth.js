const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const { OAuth2Client } = require('google-auth-library');
const User = require('../models/User');
const EmailOtp = require('../models/EmailOtp');

const router = express.Router();
const googleClient = new OAuth2Client();

const ROLES = ['Farmer', 'Buyer', 'Expert', 'Supplier', 'Admin'];
const NAME_RE = /^\p{L}+(?: \p{L}+)*$/u;
const EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$/;

const cleanName = (n) => String(n || '').trim().replace(/\s+/g, ' ');
const cleanEmail = (e) => String(e || '').trim().toLowerCase();
const hashCode = (email, code) =>
  crypto.createHash('sha256').update(email + ':' + code).digest('hex');
const signToken = (user) =>
  jwt.sign({ id: user._id }, process.env.JWT_SECRET, { expiresIn: '30d' });
const publicUser = (u, token) => ({
  id: u._id,
  name: u.name,
  email: u.email || '',
  role: u.role,
  token,
});
const ok = (res, message, data) => res.json({ success: true, message, data });
const fail = (res, message, status = 400, data) =>
  res.status(status).json({ success: false, message, data });

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

async function sendCodeEmail(email, name, code) {
  const t = getTransporter();
  if (!t) return false;
  await t.sendMail({
    from: `"AgriSphere" <${process.env.EMAIL_USER}>`,
    to: email,
    subject: 'Your AgriSphere verification code',
    text: `Hi ${name},\n\nYour AgriSphere verification code is ${code}.\nIt expires in 10 minutes.\n\nIf you did not sign up, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto">
      <h2 style="color:#0F5A32">AgriSphere</h2>
      <p>Hi ${name},</p>
      <p>Your verification code is:</p>
      <p style="font-size:34px;font-weight:bold;letter-spacing:8px;color:#2E9B52">${code}</p>
      <p style="color:#6B7C72">It expires in 10 minutes. If you did not sign up, ignore this email.</p>
    </div>`,
  });
  return true;
}

// creates a code, stores its hash, emails it. Returns { sent, dev, code }
async function issueCode(email, name) {
  const code = String(crypto.randomInt(100000, 1000000));
  await EmailOtp.findOneAndUpdate(
    { email },
    {
      codeHash: hashCode(email, code),
      attempts: 0,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
    },
    { upsert: true, new: true }
  );
  let sent = false;
  try {
    sent = await sendCodeEmail(email, name, code);
  } catch (e) {
    console.error('Email send failed:', e.message);
  }
  const dev = process.env.DEV_MODE === 'true';
  if (!sent) console.log(`[OTP] code for ${email}: ${code}`);
  return { sent, dev, code };
}

function codeMessage(r) {
  return r.sent ? 'Verification code sent to your email' : `Email not configured. Dev code: ${r.code}`;
}

// ---------------------------------------------------------------- SIGNUP
router.post('/signup', async (req, res) => {
  try {
    const name = cleanName(req.body.name);
    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || '');
    const role = ROLES.includes(req.body.role) ? req.body.role : 'Farmer';

    const err = checkName(name) || checkEmail(email) || checkPassword(password);
    if (err) return fail(res, err);

    let user = await User.findOne({ email });
    if (user && user.emailVerified) {
      return fail(res, 'An account with this email already exists. Please log in.', 409);
    }
    const passwordHash = await bcrypt.hash(password, 10);
    if (user) {
      user.name = name;
      user.passwordHash = passwordHash;
      user.role = role;
      await user.save();
    } else {
      user = await User.create({ name, email, passwordHash, role, emailVerified: false });
    }

    const r = await issueCode(email, name);
    if (!r.sent && !r.dev) return fail(res, 'Could not send the verification email. Try again.', 502);
    return ok(res, codeMessage(r), { email, needsVerification: true });
  } catch (e) {
    console.error(e);
    if (e.code === 11000) return fail(res, 'An account with this email already exists', 409);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- RESEND CODE
router.post('/send-otp', async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    if (checkEmail(email)) return fail(res, 'Enter a valid email address');
    const user = await User.findOne({ email });
    if (!user || user.emailVerified) return fail(res, 'No pending verification for this email', 404);

    const rec = await EmailOtp.findOne({ email });
    if (rec && Date.now() - rec.updatedAt.getTime() < 30 * 1000) {
      return fail(res, 'Please wait a few seconds before requesting another code', 429);
    }
    const r = await issueCode(email, user.name);
    if (!r.sent && !r.dev) return fail(res, 'Could not send the email. Try again.', 502);
    return ok(res, codeMessage(r));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- VERIFY EMAIL
router.post('/verify-email', async (req, res) => {
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
router.post('/login', async (req, res) => {
  try {
    const email = cleanEmail(req.body.email);
    const password = String(req.body.password || '');
    if (checkEmail(email) || !password) return fail(res, 'Enter a valid email and your password');

    const user = await User.findOne({ email });
    if (!user) return fail(res, 'Invalid email or password', 401);
    if (!user.passwordHash) return fail(res, 'This account uses Google. Tap Continue with Google.', 401);

    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) return fail(res, 'Invalid email or password', 401);

    if (!user.emailVerified) {
      await issueCode(email, user.name);
      return fail(res, 'Please verify your email. We sent you a new code.', 403, {
        needsVerification: true,
        email,
      });
    }
    return ok(res, 'Login successful', publicUser(user, signToken(user)));
  } catch (e) {
    console.error(e);
    return fail(res, 'Server error', 500);
  }
});

// ---------------------------------------------------------------- GOOGLE
router.post('/google', async (req, res) => {
  try {
    const { idToken, mode } = req.body;
    const role = ROLES.includes(req.body.role) ? req.body.role : 'Farmer';
    if (!idToken) return fail(res, 'Missing Google token');

    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const p = ticket.getPayload();
    const email = cleanEmail(p.email);
    if (!p.email_verified) return fail(res, 'Your Google email is not verified', 401);

    let user = await User.findOne({ $or: [{ googleId: p.sub }, { email }] });
    if (!user) {
      if (mode !== 'signup') {
        return fail(res, 'No account found for this Google account. Please sign up first.', 404, {
          noAccount: true,
        });
      }
      const gName = cleanName(String(p.name || '').replace(/[^\p{L} ]/gu, '')) || 'User';
      user = await User.create({ name: gName, email, googleId: p.sub, role, emailVerified: true });
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

// ---------------------------------------------------------------- ME (token test)
router.get('/me', async (req, res) => {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const { id } = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(id);
    if (!user) return fail(res, 'User not found', 404);
    return ok(res, 'OK', publicUser(user));
  } catch (e) {
    return fail(res, 'Not authorised', 401);
  }
});

module.exports = router;