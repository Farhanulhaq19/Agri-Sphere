const { Crop, Listing, Order } = require('../models/agri');

const STEPS = ['placed', 'confirmed', 'picked_up', 'out_for_delivery', 'delivered'];

async function seed() {
  await Listing.updateMany(
    { sellerRole: { $exists: false }, category: { $in: ['Seeds', 'Tools'] } },
    { $set: { sellerRole: 'supplier', kind: 'input' } }
  );
  await Listing.updateMany(
    { sellerRole: { $exists: false } },
    { $set: { sellerRole: 'farmer', kind: 'produce' } }
  );

  if ((await Listing.countDocuments()) === 0) {
    const until = new Date(Date.now() + 14 * 864e5);
    const L = (seller, sellerName, sellerRole, kind, location, title, category, price, qty, rating, reviews, sales, verified, description, extra) =>
      Object.assign({
        seller, sellerName, sellerRole, kind, location, title, category, grade: 'Grade A',
        pricePerKg: price, quantityKg: qty, availableUntil: until, rating, reviews, sales, verified, description
      }, extra || {});
    await Listing.insertMany([
      L('demo', 'Ali Khan', 'farmer', 'produce', 'Harpur, KPK', 'Sehar 2006 Wheat', 'Grains', 120, 2000, 4.8, 124, 48, true,
        'Freshly harvested, sun-dried wheat. Low moisture, cleaned and ready for milling.'),
      L('blair', 'Blair Farm', 'farmer', 'produce', 'Rawalpindi', 'Fresh Tomato', 'Veggies', 90, 800, 4.8, 61, 30, true,
        'Farm-fresh red tomatoes picked this morning.'),
      L('usman', 'Usman Farms', 'farmer', 'produce', 'Sheikhupura', 'Super Basmati Rice', 'Grains', 210, 3000, 4.9, 203, 120, true,
        'Long grain aged Super Basmati. Aromatic and non-sticky.'),
      L('sahiwal', 'Sahiwal Orchards', 'farmer', 'produce', 'Sahiwal', 'Kinnow Oranges', 'Fruits', 150, 1200, 4.4, 54, 40, true,
        'Sweet and juicy Kinnow.', { grade: 'Grade B' }),
      L('khan', 'Khan Agro', 'supplier', 'input', 'Faisalabad', 'Hybrid Maize Seed', 'Seeds', 340, 500, 4.6, 38, 22, false,
        'High-yield hybrid maize seed, treated and certified.', { brand: 'Pioneer' }),
      L('agrotools', 'AgroTools PK', 'supplier', 'input', 'Lahore', 'Hand Sprayer 16L', 'Tools', 4500, 40, 4.3, 19, 11, true,
        'Knapsack sprayer, 16 litre capacity.', { unit: 'piece' }),
      L('agrotools', 'AgroTools PK', 'supplier', 'input', 'Lahore', 'DAP Fertilizer', 'Fertilizer', 260, 2500, 4.5, 33, 60, true,
        'Di-ammonium phosphate for sowing time.')
    ]);
  }

  if ((await Crop.countDocuments({ owner: 'demo' })) === 0) {
    const days = n => new Date(Date.now() - n * 864e5);
    const C = (name, variety, field, acres, ago, dur, harvest, status, progress, health, yieldKg, tasks) =>
      ({ owner: 'demo', name, variety, field, areaAcres: acres, sowingDate: days(ago), durationDays: dur,
        expectedHarvest: harvest, status, progress, health, estYieldKg: yieldKg, tasks });
    await Crop.insertMany([
      C('Wheat', 'Sehar 2006', 'Field A', 4, 72, 110, 'April 2027', 'Growing', 68, 86, 1520, [
        { title: 'Irrigation', when: 'Tomorrow', field: 'Field A', type: 'irrigation' },
        { title: 'Urea top dressing', when: 'In 5 days', field: 'Field A', type: 'fertilizer' }]),
      C('Rice', 'Super Basmati', 'Field B', 6, 120, 120, 'Ready now', 'Ready', 100, 92, 3600, []),
      C('Maize', 'Hybrid 6525', 'Field C', 2.5, 45, 100, 'January 2027', 'Growing', 45, 80, 1250, [
        { title: 'Irrigation', when: 'In 3 days', field: 'Field C', type: 'irrigation' }]),
      C('Potato', 'Cardinal', 'Field D', 1.5, 18, 90, 'February 2027', 'Growing', 20, 88, 900, [])
    ]);
  }

  if ((await Order.countDocuments()) === 0) {
    const wheat = await Listing.findOne({ title: /Sehar/ });
    const tomato = await Listing.findOne({ title: /Tomato/ });
    const hist = n => STEPS.slice(0, n + 1).map((s, i) => ({ status: s, at: new Date(Date.now() - (n - i + 1) * 18e6) }));
    const courier = { name: 'Usman', vehicle: 'Suzuki Bolan - ICT-2481' };
    const item = (l, title, sellerId, sellerName, qtyKg, pricePerKg) => ({ listing: l._id, title, sellerId, sellerName, qtyKg, pricePerKg });
    const O = (number, owner, buyerName, seller, sellerName, items, delivery, status, h, eta, address) => {
      const subtotal = items.reduce((a, i) => a + i.qtyKg * i.pricePerKg, 0);
      return { number, owner, buyerName, seller, sellerName, sellerRole: 'farmer', items, subtotal, delivery,
        total: subtotal + delivery, payment: 'Cash', address, status, history: hist(h), courier, eta };
    };
    await Order.insertMany([
      O(1038, 'fresh-mart', 'Fresh Mart', 'demo', 'Ali Khan', [item(wheat, 'Sehar 2006 Wheat', 'demo', 'Ali Khan', 400, 146)], 0, 'delivered', 4, 'Delivered', 'Blue Area, Islamabad'),
      O(1042, 'fresh-mart', 'Fresh Mart', 'demo', 'Ali Khan', [item(wheat, 'Sehar 2006 Wheat', 'demo', 'Ali Khan', 200, 120)], 0, 'placed', 0, 'Tomorrow 4:00 - 6:00 PM', 'Blue Area, Islamabad'),
      O(1041, 'demo', 'Ali Khan', 'blair', 'Blair Farm', [item(tomato, 'Fresh Tomato', 'blair', 'Blair Farm', 50, 90)], 500, 'out_for_delivery', 3, 'Tomorrow 4:00 - 6:00 PM', 'House 12, Street 5, G-11/3, Islamabad')
    ]);
  }
}

module.exports = { seed };