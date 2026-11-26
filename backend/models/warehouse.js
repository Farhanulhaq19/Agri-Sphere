const mongoose = require('mongoose');
const S = mongoose.Schema;
const model = (name, schema) => mongoose.models[name] || mongoose.model(name, schema);

const STORAGE_TYPES = ['Dry Store', 'Cold Storage', 'Grain Silo', 'Open Yard'];
const FACILITIES = ['Security guard', 'CCTV', 'Fumigation', 'Loading dock', 'Power backup', 'Weighbridge', 'Insurance'];

const Warehouse = model('AgriWarehouse', new S({
  owner: { type: String, index: true },
  ownerName: String,
  ownerPhone: String,
  name: { type: String, required: true, trim: true },
  city: String,
  address: String,
  lat: Number,
  lng: Number,
  capacityTons: { type: Number, default: 0 },
  storageTypes: [String],
  facilities: [String],
  photos: [String],
  ratePerTonDay: { type: Number, default: 0 },
  minTons: { type: Number, default: 1 },
  status: { type: String, enum: ['active', 'paused'], default: 'active' },
  description: String,
  rating: { type: Number, default: 0 },
  ratingCount: { type: Number, default: 0 }
}, { timestamps: true }));

// Loaders, unloaders, supervisors
const Labour = model('AgriLabour', new S({
  owner: { type: String, index: true },
  name: { type: String, required: true, trim: true },
  phone: String,
  role: { type: String, default: 'Loader' },
  dailyWage: { type: Number, default: 0 },
  status: { type: String, enum: ['available', 'busy', 'off'], default: 'available' }
}, { timestamps: true }));

const StorageBooking = model('AgriStorageBooking', new S({
  number: Number,
  warehouse: { type: S.Types.ObjectId, ref: 'AgriWarehouse', index: true },
  warehouseName: String,
  city: String,
  owner: { type: String, index: true },
  ownerName: String,
  farmer: { type: String, index: true },
  farmerName: String,
  farmerPhone: String,
  crop: String,
  quantityTons: Number,
  currentTons: { type: Number, default: 0 },
  storageType: String,
  startDate: Date,
  days: Number,
  endDate: Date,
  rate: Number,
  storageCost: { type: Number, default: 0 },
  handlingCost: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  paidAmount: { type: Number, default: 0 },
  // online payments wait as 'under_review' until the owner approves; only approved ones count in paidAmount
  payments: [{ amount: Number, method: String, at: Date, note: String, status: { type: String, default: 'approved' }, proof: String, ref: String }],
  needLoading: { type: Boolean, default: false },
  notes: String,
  ownerNote: String,
  status: { type: String, enum: ['requested', 'approved', 'rejected', 'stored', 'released', 'cancelled'], default: 'requested', index: true },
  tasks: [{
    kind: { type: String, enum: ['loading', 'unloading'] },
    labour: [String],
    labourNames: [String],
    scheduledAt: Date,
    charge: { type: Number, default: 0 },
    status: { type: String, enum: ['scheduled', 'done'], default: 'scheduled' },
    doneAt: Date
  }],
  readings: [{ at: Date, temperature: Number, humidity: Number, note: String }],
  history: [{ status: String, at: Date, note: String }],
  rating: Number,
  review: String
}, { timestamps: true }));

module.exports = { Warehouse, Labour, StorageBooking, STORAGE_TYPES, FACILITIES };
