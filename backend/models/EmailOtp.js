const mongoose = require('mongoose');

const emailOtpSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true },
    codeHash: { type: String, required: true },
    attempts: { type: Number, default: 0 },
    expiresAt: { type: Date, required: true, index: { expires: 0 } }, // MongoDB auto-deletes expired codes
  },
  { timestamps: true }
);

module.exports = mongoose.model('EmailOtp', emailOtpSchema);