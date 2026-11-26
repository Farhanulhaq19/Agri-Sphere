// Creates ready-to-use demo accounts with realistic data for the FYP demo.
// Run from the backend folder:   npm run seed:demo
// Safe to run again: it updates the demo users and rebuilds only THEIR data.
// Logins and the password are listed in docs/DEMO.md.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const User = require('../models/User');
const { Profile, Listing, Order, Crop, Query, Notification, CartItem } = require('../models/agri');
const { Machine, MachineBooking, Technician } = require('../models/machinery');
const { Warehouse, StorageBooking, Labour } = require('../models/warehouse');
const { Conversation, Message, Review, Favorite } = require('../models/social');
const { nextNumber } = require('../utils/counter');

const PASSWORD = process.env.DEMO_PASSWORD || 'Demo@12345';
const DAY = 864e5;
const ago = (d) => new Date(Date.now() - d * DAY);
const ahead = (d) => new Date(Date.now() + d * DAY);

const PEOPLE = [
  { key: 'farmer', name: 'Ali Raza', email: 'farmer.demo@agrisphere.test', phone: '03001112233', roles: ['Farmer'], city: 'Faisalabad', lat: 31.4504, lng: 73.1350 },
  { key: 'farmer2', name: 'Sana Bibi', email: 'farmer2.demo@agrisphere.test', phone: '03004445566', roles: ['Farmer'], city: 'Sahiwal', lat: 30.6682, lng: 73.1114 },
  { key: 'buyer', name: 'Bilal Traders', email: 'buyer.demo@agrisphere.test', phone: '03217778899', roles: ['Buyer'], city: 'Lahore', lat: 31.5204, lng: 74.3587 },
  { key: 'supplier', name: 'Green Agro Supplies', email: 'supplier.demo@agrisphere.test', phone: '03331234567', roles: ['Supplier'], city: 'Multan', lat: 30.1575, lng: 71.5249 },
  { key: 'expert', name: 'Dr. Ayesha Khan', email: 'expert.demo@agrisphere.test', phone: '03451239876', roles: ['Expert'], city: 'Islamabad', lat: 33.6844, lng: 73.0479 },
  { key: 'machinery', name: 'Kamran Tractors', email: 'machinery.demo@agrisphere.test', phone: '03019876543', roles: ['MachineryOwner'], city: 'Faisalabad', lat: 31.4180, lng: 73.0790 },
  { key: 'warehouse', name: 'Punjab Cold Storage', email: 'warehouse.demo@agrisphere.test', phone: '03127654321', roles: ['WarehouseOwner'], city: 'Okara', lat: 30.8138, lng: 73.4534 },
  { key: 'admin', name: 'AgriSphere Admin', email: 'admin.demo@agrisphere.test', phone: '03000000001', roles: ['Admin'], city: 'Islamabad', lat: 33.7, lng: 73.05 }
];
const roleKey = { Farmer: 'farmer', Buyer: 'buyer', Supplier: 'supplier', Expert: 'expert', MachineryOwner: 'machinery_owner', WarehouseOwner: 'warehouse_owner', Admin: 'admin' };

// tiny placeholder receipt so the payment-review screen has something to show
function demoReceipt() {
  const dir = path.join(__dirname, '..', 'uploads', 'payments');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'demo-receipt.png');
  const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
  if (!fs.existsSync(file)) fs.writeFileSync(file, Buffer.from(png, 'base64'));
  return '/uploads/payments/demo-receipt.png';
}

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected. Creating demo accounts...');
  const hash = await bcrypt.hash(PASSWORD, 10);
  const u = {};
  for (const p of PEOPLE) {
    let doc = await User.findOne({ email: p.email });
    if (!doc) doc = new User({ email: p.email });
    Object.assign(doc, { name: p.name, phone: p.phone, passwordHash: hash, roles: p.roles, role: p.roles[0], emailVerified: true, location: p.city });
    await doc.save();
    u[p.key] = { ...p, id: String(doc._id) };
    await Profile.updateOne(
      { user: String(doc._id) },
      { $set: { role: roleKey[p.roles[0]], name: p.name, email: p.email, phone: p.phone, city: p.city, verified: true,
        businessName: ['supplier', 'machinery', 'warehouse'].includes(p.key) ? p.name : '',
        specialization: p.key === 'expert' ? ['Plant diseases', 'Soil health', 'Wheat', 'Cotton'] : [],
        experienceYears: p.key === 'expert' ? 12 : 5, bio: p.key === 'expert' ? 'Agronomist, PhD Plant Pathology (UAF).' : '' } },
      { upsert: true }
    );
  }
  const ids = Object.values(u).map(x => x.id);

  // ---------------------------------------------------------------- wipe old demo data (only the demo users')
  const oldListings = await Listing.find({ seller: { $in: ids } }, { _id: 1 });
  await Promise.all([
    Listing.deleteMany({ seller: { $in: ids } }),
    Order.deleteMany({ $or: [{ owner: { $in: ids } }, { seller: { $in: ids } }] }),
    Review.deleteMany({ listing: { $in: oldListings.map(l => l._id) } }),
    Crop.deleteMany({ owner: { $in: ids } }),
    Query.deleteMany({ owner: { $in: ids } }),
    Notification.deleteMany({ user: { $in: ids } }),
    CartItem.deleteMany({ owner: { $in: ids } }),
    Machine.deleteMany({ owner: { $in: ids } }),
    MachineBooking.deleteMany({ $or: [{ owner: { $in: ids } }, { farmer: { $in: ids } }] }),
    Technician.deleteMany({ owner: { $in: ids } }),
    Warehouse.deleteMany({ owner: { $in: ids } }),
    StorageBooking.deleteMany({ $or: [{ owner: { $in: ids } }, { farmer: { $in: ids } }] }),
    Labour.deleteMany({ owner: { $in: ids } }),
    Favorite.deleteMany({ user: { $in: ids } })
  ]);
  const convs = await Conversation.find({ members: { $in: ids } }, { _id: 1 });
  await Message.deleteMany({ conv: { $in: convs.map(c => c._id) } });
  await Conversation.deleteMany({ _id: { $in: convs.map(c => c._id) } });

  // ---------------------------------------------------------------- listings
  const L = (who, kind, title, category, price, qty, extra) => ({
    seller: u[who].id, sellerName: u[who].name, sellerRole: kind === 'input' ? 'supplier' : 'farmer', kind,
    location: u[who].city, sellerPhone: u[who].phone, lat: u[who].lat + (Math.random() - 0.5) * 0.04, lng: u[who].lng + (Math.random() - 0.5) * 0.04,
    title, category, pricePerKg: price, quantityKg: qty, grade: 'Grade A', verified: true, rating: 0, reviews: 0, sales: 0,
    availableUntil: ahead(20), status: 'active', ...extra
  });
  const listings = await Listing.insertMany([
    L('farmer', 'produce', 'Sehar Wheat (new crop)', 'Grains', 118, 3000, { description: 'Freshly harvested, sun-dried, 10% moisture. Cleaned and bagged in 50 kg bags.', createdAt: ago(2) }),
    L('farmer', 'produce', 'Super Basmati Rice', 'Grains', 245, 1500, { description: 'Aged 1 year, long grain, aromatic. Ideal for export quality buyers.', createdAt: ago(9) }),
    L('farmer', 'produce', 'Fresh Potatoes', 'Veggies', 55, 2500, { grade: 'Grade B', description: 'Washed table potatoes, medium size, from our Faisalabad farm.', createdAt: ago(1) }),
    L('farmer2', 'produce', 'Kinnow Oranges', 'Fruits', 140, 1200, { description: 'Sweet and juicy Sargodha-variety kinnow. Packed in crates.', createdAt: ago(3) }),
    L('farmer2', 'produce', 'Red Onions', 'Veggies', 72, 1800, { description: 'Dry red onions, good shelf life.', createdAt: ago(12) }),
    L('farmer2', 'produce', 'Organic Tomatoes', 'Veggies', 95, 600, { description: 'Pesticide-free tomatoes picked daily.', createdAt: ago(0) }),
    L('supplier', 'input', 'DAP Fertilizer (50 kg bag)', 'Seeds', 12500, 200, { unit: 'bag', brand: 'Engro', description: 'Di-ammonium phosphate for sowing. Original, sealed bags.' }),
    L('supplier', 'input', 'Hybrid Maize Seed (10 kg)', 'Seeds', 6500, 120, { unit: 'bag', brand: 'Pioneer', description: 'High-yield hybrid maize for spring sowing.' }),
    L('supplier', 'input', 'Knapsack Sprayer 16L', 'Tools', 4200, 60, { unit: 'piece', brand: 'Agro', description: 'Manual sprayer with adjustable nozzle.' })
  ]);
  const byTitle = (t) => listings.find(l => l.title.startsWith(t));

  // ---------------------------------------------------------------- orders + reviews
  const receipt = demoReceipt();
  const mkOrder = async (listing, qty, payment, paymentStatus, status, daysAgo, extra = {}) => {
    const steps = ['placed', 'confirmed', 'picked_up', 'out_for_delivery', 'delivered'];
    const upto = steps.indexOf(status);
    const o = await Order.create({
      number: await nextNumber('order', Order, 1040), owner: u.buyer.id, buyerName: u.buyer.name,
      seller: listing.seller, sellerName: listing.sellerName, sellerRole: listing.sellerRole, sellerPhone: listing.sellerPhone,
      items: [{ listing: listing._id, title: listing.title, sellerId: listing.seller, sellerName: listing.sellerName, qtyKg: qty, pricePerKg: listing.pricePerKg }],
      subtotal: qty * listing.pricePerKg, delivery: 500, total: qty * listing.pricePerKg + 500, payment, paymentStatus,
      receiverName: u.buyer.name, phone: u.buyer.phone, city: 'Lahore', deliveryType: 'standard',
      address: 'Shop 14, Akbari Mandi, Lahore', status,
      history: steps.slice(0, upto + 1).map((s, i) => ({ status: s, at: ago(daysAgo - i * 0.5) })),
      courier: { name: 'Usman', vehicle: 'Suzuki Bolan - LEA-2481' }, eta: status === 'delivered' ? 'Delivered' : '2 - 3 days',
      createdAt: ago(daysAgo), ...extra
    });
    await Listing.updateOne({ _id: listing._id }, { $inc: { sales: 1 } });
    return o;
  };
  const o1 = await mkOrder(byTitle('Super Basmati'), 200, 'Cash', 'paid', 'delivered', 8);
  const o2 = await mkOrder(byTitle('Kinnow'), 150, 'Easypaisa', 'paid', 'delivered', 6, { paymentRef: '24851937562', paymentProof: receipt });
  await mkOrder(byTitle('Sehar Wheat'), 500, 'Easypaisa', 'under_review', 'placed', 0.2, { paymentRef: '30918274651', paymentProof: receipt });
  await mkOrder(byTitle('Fresh Potatoes'), 300, 'Cash', 'cod_pending', 'out_for_delivery', 1);
  const review = async (o, rating, text) => {
    await Review.create({ listing: o.items[0].listing, order: o._id, user: u.buyer.id, name: u.buyer.name, rating, text });
    await Listing.updateOne({ _id: o.items[0].listing }, { $set: { rating, reviews: 1 } });
    await Order.updateOne({ _id: o._id }, { reviewed: true, myRating: rating });
  };
  await review(o1, 5, 'Excellent quality rice, exactly as described. Fast delivery.');
  await review(o2, 4, 'Very sweet kinnow, a few were small but overall great.');

  // ---------------------------------------------------------------- crops with tasks
  const sow = ago(40);
  await Crop.create([
    { owner: u.farmer.id, name: 'Wheat', variety: 'Sehar 2006', field: 'Field A', areaAcres: 12, sowingDate: sow, durationDays: 150, status: 'Growing', progress: 30, health: 88, estYieldKg: 12 * 1300, location: 'Faisalabad', lat: u.farmer.lat, lng: u.farmer.lng,
      tasks: [
        { title: 'Second irrigation', when: 'Tomorrow', field: 'Field A', type: 'irrigation', due: ahead(1) },
        { title: 'Urea top dressing (1 bag/acre)', when: 'In 4 days', field: 'Field A', type: 'fertilizer', due: ahead(4) },
        { title: 'Weed spray (broadleaf)', when: 'Done', field: 'Field A', type: 'spray', done: true, due: ago(5) }
      ] },
    { owner: u.farmer.id, name: 'Potato', variety: 'Cardinal', field: 'Field B', areaAcres: 4, sowingDate: ago(70), durationDays: 100, status: 'Growing', progress: 70, health: 76, estYieldKg: 4 * 9000, location: 'Faisalabad',
      tasks: [{ title: 'Check for late blight', when: 'Today', field: 'Field B', type: 'spray', due: ahead(0) }] }
  ]);

  // ---------------------------------------------------------------- expert questions
  await Query.create([
    { owner: u.farmer.id, ownerName: u.farmer.name, category: 'Disease', subject: 'Yellow stripes on wheat leaves', details: 'Yellow powder-like stripes appeared on leaves of Field A after fog.', status: 'answered',
      answer: 'This looks like yellow (stripe) rust. Spray a triazole fungicide (e.g. tebuconazole) at the label dose and avoid excess nitrogen. Re-check after 10 days.', expert: u.expert.id, expertName: u.expert.name, answeredAt: ago(1) },
    { owner: u.farmer2.id, ownerName: u.farmer2.name, category: 'Soil', subject: 'Best fertilizer for kinnow orchard?', details: 'Trees are 6 years old, soil is sandy loam.', status: 'open' }
  ]);

  // ---------------------------------------------------------------- machinery
  const [tractor] = await Machine.insertMany([
    { owner: u.machinery.id, ownerName: u.machinery.name, ownerPhone: u.machinery.phone, name: 'Massey Ferguson 385', category: 'Tractor', brand: 'Massey Ferguson', modelName: '385', year: 2021, horsepower: 85, forRent: true, rentPerHour: 1800, rentPerDay: 12000, minHours: 2, operatorAvailable: true, operatorRatePerHour: 400, city: 'Faisalabad', address: 'Jhang Road', lat: u.machinery.lat, lng: u.machinery.lng, description: 'Well-maintained tractor with rotavator and cultivator.', features: ['Rotavator', 'Cultivator', 'Trolley hitch'], rating: 4.7, ratingCount: 18, totalBookings: 22 },
    { owner: u.machinery.id, ownerName: u.machinery.name, ownerPhone: u.machinery.phone, name: 'Kubota Combine Harvester', category: 'Harvester', brand: 'Kubota', year: 2019, horsepower: 70, forRent: true, rentPerHour: 6500, rentPerDay: 45000, minHours: 3, operatorAvailable: true, operatorRatePerHour: 600, city: 'Faisalabad', lat: u.machinery.lat + 0.02, lng: u.machinery.lng + 0.03, description: 'Wheat and rice harvesting with grain tank.', rating: 4.5, ratingCount: 9, totalBookings: 11 },
    { owner: u.machinery.id, ownerName: u.machinery.name, ownerPhone: u.machinery.phone, name: 'Boom Sprayer 600L', category: 'Sprayer', forRent: true, rentPerHour: 900, rentPerDay: 6000, city: 'Faisalabad', lat: u.machinery.lat - 0.02, lng: u.machinery.lng, forSale: true, salePrice: 350000, condition: 'used' }
  ]);
  const { nextNumber: seq } = require('../utils/counter');
  await MachineBooking.create({
    number: await seq('machine-booking', MachineBooking, 1000), machine: tractor._id, machineName: tractor.name, category: 'Tractor',
    owner: u.machinery.id, ownerName: u.machinery.name, farmer: u.farmer.id, farmerName: u.farmer.name, farmerPhone: u.farmer.phone,
    type: 'rent', startAt: ahead(2), endAt: new Date(ahead(2).getTime() + 6 * 3600e3), rateUnit: 'hour', quantity: 6,
    withTechnician: true, techHours: 6, rentCost: 10800, techCost: 2400, total: 13200, fieldLocation: 'Chak 45, Field A',
    fieldLat: u.farmer.lat, fieldLng: u.farmer.lng, status: 'accepted', paymentStatus: 'unpaid', history: [{ status: 'requested', at: ago(1) }, { status: 'accepted', at: ago(0.5) }]
  });
  await Technician.create({ owner: u.machinery.id, name: 'Usman Ali', phone: '03111234567', skill: 'Tractor Operator', experienceYears: 7, hourlyRate: 400 });

  // ---------------------------------------------------------------- warehouse
  const [wh] = await Warehouse.insertMany([
    { owner: u.warehouse.id, ownerName: u.warehouse.name, ownerPhone: u.warehouse.phone, name: 'Punjab Cold Storage - Okara', city: 'Okara', address: 'GT Road', lat: u.warehouse.lat, lng: u.warehouse.lng, capacityTons: 800, storageTypes: ['Cold Storage', 'Dry Store'], facilities: ['CCTV', 'Power backup', 'Loading dock', 'Security guard'], ratePerTonDay: 35, minTons: 1, description: 'Temperature-controlled storage for potatoes, fruit and vegetables.', rating: 4.6, ratingCount: 14 },
    { owner: u.warehouse.id, ownerName: u.warehouse.name, ownerPhone: u.warehouse.phone, name: 'Grain Silo - Sahiwal', city: 'Sahiwal', lat: 30.67, lng: 73.12, capacityTons: 1500, storageTypes: ['Grain Silo'], facilities: ['Fumigation', 'Weighbridge'], ratePerTonDay: 18, minTons: 5 }
  ]);
  await StorageBooking.create({
    number: await seq('storage-booking', StorageBooking, 2000), warehouse: wh._id, warehouseName: wh.name, city: wh.city, owner: u.warehouse.id, ownerName: u.warehouse.name,
    farmer: u.farmer.id, farmerName: u.farmer.name, farmerPhone: u.farmer.phone, crop: 'Potato', quantityTons: 20, currentTons: 20, storageType: 'Cold Storage',
    startDate: ago(10), days: 60, endDate: ahead(50), rate: 35, storageCost: 42000, handlingCost: 3000, total: 45000, paidAmount: 20000,
    payments: [{ amount: 20000, method: 'Cash', at: ago(9), note: 'Received by owner', status: 'approved' }], status: 'stored',
    readings: [{ at: ago(2), temperature: 4, humidity: 88, note: 'Stable' }, { at: ago(0.2), temperature: 4.5, humidity: 86, note: 'Stable' }],
    history: [{ status: 'requested', at: ago(12) }, { status: 'approved', at: ago(11) }, { status: 'stored', at: ago(10) }]
  });
  await Labour.create({ owner: u.warehouse.id, name: 'Rashid', phone: '03221231231', role: 'Loader', dailyWage: 1500 });

  // ---------------------------------------------------------------- chat
  const conv = await Conversation.create({
    members: [u.buyer.id, u.farmer.id], names: { [u.buyer.id]: u.buyer.name, [u.farmer.id]: u.farmer.name },
    topic: { kind: 'listing', ref: String(byTitle('Sehar Wheat')._id), title: 'Sehar Wheat (new crop)' }, lastAt: new Date(), unread: { [u.farmer.id]: 1 }
  });
  const msgs = [
    [u.buyer, 'Assalam o Alaikum, is the wheat still available? I need 500 kg.'],
    [u.farmer, 'Walaikum Assalam, yes. Fresh crop, 10% moisture.'],
    [u.buyer, 'Great, I placed the order and paid by Easypaisa. Please verify.']
  ];
  for (const [who, text] of msgs) {
    const m = await Message.create({ conv: conv._id, from: who.id, fromName: who.name, text });
    conv.lastText = text;
    conv.lastAt = m.createdAt;
    conv.lastBy = who.id;
  }
  await conv.save();

  // ---------------------------------------------------------------- notifications + favourites
  await Notification.create([
    { user: u.farmer.id, title: 'New order #' + (o1.number + 2), body: 'Bilal Traders ordered Sehar Wheat 500 kg', type: 'order' },
    { user: u.farmer.id, title: 'Your question was answered', body: 'Dr. Ayesha Khan answered: Yellow stripes on wheat leaves', type: 'query' },
    { user: u.buyer.id, title: 'Order delivered', body: 'Your Super Basmati Rice order was delivered', type: 'order' }
  ]);
  await Favorite.create({ user: u.buyer.id, kind: 'listing', ref: String(byTitle('Organic Tomatoes')._id), title: 'Organic Tomatoes', sub: 'Sahiwal · Sana Bibi', price: 'Rs 95/kg' });

  console.log('\nDemo data ready. Accounts (password in docs/DEMO.md):');
  PEOPLE.forEach(p => console.log('  ' + p.key.padEnd(10) + p.email));
  if (!(process.env.ADMIN_EMAILS || '').toLowerCase().includes('admin.demo@agrisphere.test') && (process.env.ADMIN_EMAILS || '').trim()) {
    console.log('\nNOTE: add admin.demo@agrisphere.test to ADMIN_EMAILS in backend/.env so the demo admin can open the admin console.');
  }
  await mongoose.disconnect();
}

main().catch(async (e) => {
  console.error('Seeding failed:', e.message);
  await mongoose.disconnect();
  process.exit(1);
});
