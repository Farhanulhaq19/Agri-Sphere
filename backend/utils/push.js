// Phone push notifications with Firebase Cloud Messaging.
// Turn on by setting ONE of these in backend/.env:
//   FIREBASE_SERVICE_ACCOUNT=./firebase-service-account.json   (path to the key file)
//   FIREBASE_SERVICE_ACCOUNT_JSON={...}                        (the key file contents, for hosting)
// Without them, push is simply skipped (in-app notifications still work).
const path = require('path');
const mongoose = require('mongoose');

const DeviceToken = mongoose.models.AgriDeviceToken || mongoose.model('AgriDeviceToken', new mongoose.Schema({
  user: { type: String, index: true },
  token: { type: String, unique: true },
  platform: String
}, { timestamps: true }));

let messaging = null;
let tried = false;

function fcm() {
  if (tried) return messaging;
  tried = true;
  try {
    let cred = null;
    if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) cred = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
    else if (process.env.FIREBASE_SERVICE_ACCOUNT) cred = require(path.resolve(__dirname, '..', process.env.FIREBASE_SERVICE_ACCOUNT));
    if (!cred) return null;
    const admin = require('firebase-admin');
    if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(cred) });
    messaging = admin.messaging();
    console.log('Push notifications enabled (Firebase)');
  } catch (e) {
    console.warn('Push notifications disabled:', e.message);
  }
  return messaging;
}

async function saveToken(user, token, platform) {
  if (!token) return;
  await DeviceToken.updateOne({ token }, { $set: { user: String(user), platform: platform || 'android' } }, { upsert: true });
}

async function removeToken(token) {
  if (token) await DeviceToken.deleteOne({ token });
}

// Fire-and-forget: never throws, never slows the request down.
async function sendPush(user, title, body, data) {
  const m = fcm();
  if (!m) return;
  try {
    const tokens = (await DeviceToken.find({ user: String(user) }, { token: 1 })).map(t => t.token);
    if (!tokens.length) return;
    const res = await m.sendEachForMulticast({
      tokens,
      notification: { title: String(title).slice(0, 100), body: String(body || '').slice(0, 240) },
      data: Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v)])),
      android: { priority: 'high', notification: { channelId: 'agrisphere', color: '#16803C' } }
    });
    // forget phones that uninstalled the app
    const dead = res.responses
      .map((r, i) => (!r.success && r.error && /registration-token-not-registered|invalid-registration-token|invalid-argument/.test(r.error.code) ? tokens[i] : null))
      .filter(Boolean);
    if (dead.length) await DeviceToken.deleteMany({ token: { $in: dead } });
  } catch (e) {
    console.warn('Push failed:', e.message);
  }
}

module.exports = { sendPush, saveToken, removeToken, DeviceToken };
