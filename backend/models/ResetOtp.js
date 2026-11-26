const mongoose = require('mongoose');

// One-time code for "forgot password". Separate from EmailOtp (signup) so the two flows never collide.
const resetOtpSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true },
    codeHash: { type: String, required: true },
    attempts: { type: Number, default: 0 },
    expiresAt: { type: Date, required: true, index: { expires: 0 } }, // MongoDB deletes it when expired
  },
  { timestamps: true }
);

module.exports = mongoose.models.ResetOtp || mongoose.model('ResetOtp', resetOtpSchema);
