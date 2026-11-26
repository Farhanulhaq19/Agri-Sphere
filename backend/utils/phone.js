const { bad } = require('./http');

// Pakistani mobile number: 03XXXXXXXXX or +923XXXXXXXXX (spaces / dashes allowed)
const PK_MOBILE = /^(\+92|0)3\d{9}$/;

function cleanPhone(v) {
  return String(v || '').replace(/[\s-]/g, '');
}

// Every post (produce, product, machine, warehouse) needs a contact number.
// Uses the number sent with the form, else the one saved on the profile / account.
async function requirePhone(me, given, profile) {
  const phone = cleanPhone(given) || cleanPhone(profile && profile.phone) || cleanPhone(me.phone);
  if (!phone) throw bad('Enter your mobile number so buyers can contact you');
  if (!PK_MOBILE.test(phone)) throw bad('Enter a valid mobile number, e.g. 03001234567');
  // remember it on the profile so the next form is filled in automatically
  if (!me.demo) {
    const { Profile } = require('../models/agri');
    await Profile.updateOne({ user: me.id, $or: [{ phone: { $exists: false } }, { phone: '' }] }, { $set: { phone } });
  }
  return phone;
}

module.exports = { requirePhone, cleanPhone, PK_MOBILE };
