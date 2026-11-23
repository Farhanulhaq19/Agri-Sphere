const mongoose = require('mongoose');
const S = mongoose.Schema;

function model(name, schema) {
  return mongoose.models[name] || mongoose.model(name, schema);
}

// One profile per user, for every role (farmer, buyer, expert, supplier, admin)
const Profile = model('AgriProfile', new S({
  user: { type: String, unique: true, required: true },
  role: String,
  name: String,
  email: String,
  phone: String,
  businessName: String,
  city: String,
  address: String,
  licenseNo: String,
  categories: [String],
  specialization: [String],
  experienceYears: Number,
  bio: String,
  farmLocation: String,
  verified: { type: Boolean, default: false },
  rating: { type: Number, default: 4.5 },
  completed: { type: Number, default: 0 }
}, { timestamps: true }));

const Notification = model('AgriNotification', new S({
  user: { type: String, index: true },
  title: String,
  body: String,
  type: String,
  ref: String,
  read: { type: Boolean, default: false }
}, { timestamps: true }));

const Crop = model('AgriCrop', new S({
  owner: { type: String, default: 'demo', index: true },
  name: { type: String, required: true },
  variety: String,
  field: String,
  areaAcres: Number,
  sowingDate: Date,
  expectedHarvest: String,
  durationDays: { type: Number, default: 110 },
  status: { type: String, default: 'Growing' },
  progress: { type: Number, default: 0 },
  health: { type: Number, default: 90 },
  estYieldKg: { type: Number, default: 0 },
  location: { type: String, default: 'Harpur' },
  tasks: [{
    title: String,
    when: String,
    field: String,
    type: { type: String },
    done: { type: Boolean, default: false }
  }]
}, { timestamps: true }));

// Produce from farmers (kind: produce) and farm inputs from suppliers (kind: input)
const Listing = model('AgriListing', new S({
  seller: { type: String, default: 'demo', index: true },
  sellerName: String,
  sellerRole: { type: String, default: 'farmer' },
  kind: { type: String, default: 'produce' },
  location: String,
  title: { type: String, required: true },
  category: { type: String, default: 'Grains' },
  brand: String,
  unit: { type: String, default: 'kg' },
  grade: { type: String, default: 'Grade A' },
  pricePerKg: { type: Number, required: true },
  quantityKg: { type: Number, required: true },
  availableUntil: Date,
  description: String,
  status: { type: String, default: 'active' },
  rating: { type: Number, default: 4.5 },
  reviews: { type: Number, default: 0 },
  sales: { type: Number, default: 0 },
  verified: { type: Boolean, default: false }
}, { timestamps: true }));

const CartItem = model('AgriCartItem', new S({
  owner: { type: String, index: true },
  listing: { type: S.Types.ObjectId, ref: 'AgriListing' },
  qtyKg: { type: Number, default: 10 }
}, { timestamps: true }));

// One order per seller
const Order = model('AgriOrder', new S({
  number: Number,
  owner: { type: String, index: true },
  buyerName: String,
  seller: { type: String, index: true },
  sellerName: String,
  sellerRole: String,
  items: [{
    listing: S.Types.ObjectId,
    title: String,
    sellerId: String,
    sellerName: String,
    qtyKg: Number,
    pricePerKg: Number
  }],
  subtotal: Number,
  delivery: Number,
  total: Number,
  payment: { type: String, default: 'Cash' },
  address: String,
  status: { type: String, default: 'placed' },
  history: [{ status: String, at: Date }],
  courier: { name: String, vehicle: String },
  eta: String
}, { timestamps: true }));

const Query = model('AgriQuery', new S({
  owner: { type: String, index: true },
  ownerName: String,
  category: String,
  subject: String,
  details: String,
  status: { type: String, default: 'open' },
  answer: String,
  expert: String,
  expertName: String,
  answeredAt: Date
}, { timestamps: true }));

module.exports = { Profile, Notification, Crop, Listing, CartItem, Order, Query };