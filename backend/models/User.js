const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true, unique: true },
    passwordHash: { type: String },
    googleId: { type: String },
    role: {
      type: String,
      enum: ['Farmer', 'Buyer', 'Expert', 'Supplier', 'Admin'],
      default: 'Farmer',
    },
    emailVerified: { type: Boolean, default: false },
    location: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('User', userSchema);