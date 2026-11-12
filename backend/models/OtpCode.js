const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema({
  phone: { type: String, required: true, unique: true },
  codeHash: { type: String, required: true },
  attempts: { type: Number, default: 0 },
  expiresAt: { type: Date, required: true, index: { expires: 0 } }, // auto-deleted by MongoDB
});

module.exports = mongoose.model('OtpCode', otpSchema);