const mongoose = require('mongoose');
const S = mongoose.Schema;
const model = (name, schema) => mongoose.models[name] || mongoose.model(name, schema);

const CATEGORIES = ['Tractor', 'Harvester', 'Thresher', 'Sprayer', 'Plough', 'Seeder', 'Trolley', 'Water Pump', 'Other'];

// One machine an owner lists. An owner can list many (tractor, harvester, ...).
const Machine = model('AgriMachine', new S({
  owner: { type: String, index: true },
  ownerName: String,
  ownerPhone: String,
  name: { type: String, required: true, trim: true },
  category: { type: String, default: 'Tractor' },
  brand: String,
  modelName: String,
  year: Number,
  horsepower: Number,
  condition: { type: String, enum: ['new', 'used'], default: 'used' },
  forRent: { type: Boolean, default: true },
  forSale: { type: Boolean, default: false },
  rentPerHour: { type: Number, default: 0 },
  rentPerDay: { type: Number, default: 0 },
  salePrice: { type: Number, default: 0 },
  minHours: { type: Number, default: 1 },
  operatorAvailable: { type: Boolean, default: false },   // owner can send a technician / operator
  operatorRatePerHour: { type: Number, default: 0 },
  city: String,
  address: String,
  lat: Number,
  lng: Number,
  locationNote: String,
  status: { type: String, enum: ['available', 'maintenance', 'inactive', 'sold'], default: 'available' },
  description: String,
  features: [String],
  photos: [String],
  rating: { type: Number, default: 0 },
  ratingCount: { type: Number, default: 0 },
  totalBookings: { type: Number, default: 0 }
}, { timestamps: true }));

// Operators / mechanics who work for the owner
const Technician = model('AgriTechnician', new S({
  owner: { type: String, index: true },
  name: { type: String, required: true, trim: true },
  phone: String,
  skill: { type: String, default: 'Tractor Operator' },
  experienceYears: { type: Number, default: 0 },
  hourlyRate: { type: Number, default: 0 },
  status: { type: String, enum: ['available', 'busy', 'off'], default: 'available' },
  notes: String
}, { timestamps: true }));

const MachineBooking = model('AgriMachineBooking', new S({
  number: Number,
  machine: { type: S.Types.ObjectId, ref: 'AgriMachine', index: true },
  machineName: String,
  category: String,
  owner: { type: String, index: true },
  ownerName: String,
  farmer: { type: String, index: true },
  farmerName: String,
  farmerPhone: String,
  type: { type: String, enum: ['rent', 'buy'], default: 'rent' },
  startAt: Date,
  endAt: Date,
  rateUnit: { type: String, enum: ['hour', 'day'], default: 'hour' },
  quantity: { type: Number, default: 1 },            // hours or days
  withTechnician: { type: Boolean, default: false },
  techHours: { type: Number, default: 0 },           // how many hours the technician works
  technician: String,
  technicianName: String,
  rentCost: { type: Number, default: 0 },
  techCost: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  fieldLocation: String,
  fieldLat: Number,
  fieldLng: Number,
  notes: String,
  ownerNote: String,
  status: { type: String, enum: ['requested', 'accepted', 'declined', 'in_progress', 'completed', 'cancelled'], default: 'requested', index: true },
  // unpaid -> (Easypaisa/Card proof) under_review -> paid | rejected. Cash: owner marks paid.
  paymentStatus: { type: String, enum: ['unpaid', 'under_review', 'paid', 'rejected'], default: 'unpaid' },
  payMethod: String,
  paymentProof: String,
  paymentRef: String,
  paymentNote: String,
  paidAt: Date,
  tracking: { lat: Number, lng: Number, note: String, updatedAt: Date },
  history: [{ status: String, at: Date, note: String }],
  rating: Number,
  review: String
}, { timestamps: true }));

const Maintenance = model('AgriMaintenance', new S({
  owner: { type: String, index: true },
  machine: { type: S.Types.ObjectId, ref: 'AgriMachine' },
  machineName: String,
  kind: { type: String, default: 'Service' },
  date: Date,
  cost: { type: Number, default: 0 },
  note: String,
  status: { type: String, enum: ['scheduled', 'done'], default: 'scheduled' }
}, { timestamps: true }));

module.exports = { Machine, Technician, MachineBooking, Maintenance, CATEGORIES };
