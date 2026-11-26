// Indexes for the queries the app runs most. createIndex is a no-op if the index already exists.
async function ensureIndexes() {
  const { Listing, Order, CartItem, Notification, Crop } = require('../models/agri');
  const { Machine, MachineBooking } = require('../models/machinery');
  const { Warehouse, StorageBooking } = require('../models/warehouse');
  const jobs = [
    [Listing, { status: 1, quantityKg: 1, createdAt: -1 }],
    [Listing, { category: 1, createdAt: -1 }],
    [Listing, { seller: 1 }],
    [Listing, { kind: 1, rating: -1 }],
    [Order, { owner: 1, createdAt: -1 }],
    [Order, { 'items.sellerId': 1, createdAt: -1 }],
    [Order, { checkoutId: 1 }],
    [Order, { paymentStatus: 1 }],
    [CartItem, { owner: 1 }],
    [Notification, { user: 1, read: 1, createdAt: -1 }],
    [Crop, { owner: 1 }],
    [Machine, { status: 1, category: 1 }],
    [MachineBooking, { machine: 1, status: 1, startAt: 1 }],
    [MachineBooking, { farmer: 1, createdAt: -1 }],
    [Warehouse, { status: 1, city: 1 }],
    [StorageBooking, { farmer: 1, createdAt: -1 }]
  ];
  for (const [M, keys] of jobs) {
    try { await M.collection.createIndex(keys); } catch (e) { console.warn('Index skipped:', e.message); }
  }
}
module.exports = { ensureIndexes };
