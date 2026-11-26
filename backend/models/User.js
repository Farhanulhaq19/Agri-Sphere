const mongoose = require('mongoose');

// Every role a person can hold on AgriSphere. A user can hold several at once
// (for example Farmer + MachineryOwner) and switches between them in the app.
const ROLES = ['Farmer', 'Buyer', 'Expert', 'Supplier', 'MachineryOwner', 'WarehouseOwner', 'Admin'];

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true, unique: true },
    phone: { type: String, default: '', trim: true },
    passwordHash: { type: String },
    googleId: { type: String },
    // `role` is the ACTIVE role (kept for older code); `roles` is everything the user owns.
    role: { type: String, enum: ROLES, default: 'Farmer' },
    roles: { type: [{ type: String, enum: ROLES }], default: undefined },
    emailVerified: { type: Boolean, default: false },
    location: { type: String, default: '' },
    passwordChangedAt: { type: Date },
  },
  { timestamps: true }
);

// Mongoose 9: pre hooks no longer receive `next` — just return (or throw) instead.
userSchema.pre('validate', function () {
  if (!this.roles || this.roles.length === 0) this.roles = [this.role || 'Farmer'];
  const admins = (process.env.ADMIN_EMAILS || '').toLowerCase().split(',').map((x) => x.trim());
  const adminHere = this.role === 'Admin' && admins.includes(this.email);
  if (!this.roles.includes(this.role) && !adminHere) this.role = this.roles[0];
});

const User = mongoose.models.User || mongoose.model('User', userSchema);
User.ROLES = ROLES;
module.exports = User;
