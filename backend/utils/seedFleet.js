const { Machine } = require('../models/machinery');
const { Warehouse } = require('../models/warehouse');

// Demo machines and warehouses so the farmer screens are not empty on a fresh database.
// Owner id "seed" has no login, so these are browse-only examples. Turn off with SEED_DEMO_DATA=false.
async function seedFleet() {
  if (!(await Machine.countDocuments({ owner: 'seed' }))) {
    await Machine.insertMany([
      { owner: 'seed', ownerName: 'Green Valley Rentals', ownerPhone: '03001234567', name: 'Massey Ferguson 385', category: 'Tractor', brand: 'Massey Ferguson', modelName: '385', year: 2021, horsepower: 85, condition: 'used', forRent: true, forSale: false, rentPerHour: 1800, rentPerDay: 12000, operatorAvailable: true, operatorRatePerHour: 400, city: 'Faisalabad', description: 'Reliable 85 HP tractor for ploughing and haulage.', features: ['4WD', 'Power steering'], rating: 4.6, ratingCount: 18, totalBookings: 42 },
      { owner: 'seed', ownerName: 'Green Valley Rentals', ownerPhone: '03001234567', name: 'Combine Harvester CLAAS', category: 'Harvester', brand: 'CLAAS', modelName: 'Crop Tiger', year: 2019, condition: 'used', forRent: true, forSale: true, rentPerHour: 6500, rentPerDay: 48000, salePrice: 8500000, operatorAvailable: true, operatorRatePerHour: 700, city: 'Multan', description: 'Wheat and rice combine harvester with driver.', features: ['Grain tank 4000 L'], rating: 4.8, ratingCount: 9, totalBookings: 15 },
      { owner: 'seed', ownerName: 'Punjab Agro Machinery', ownerPhone: '03217654321', name: 'Fiat 480 Tractor (New)', category: 'Tractor', brand: 'Fiat', modelName: '480', year: 2026, horsepower: 50, condition: 'new', forRent: false, forSale: true, salePrice: 3150000, city: 'Lahore', description: 'Brand new, one-year dealer warranty.', features: ['Warranty'], rating: 4.5, ratingCount: 4, totalBookings: 0 },
      { owner: 'seed', ownerName: 'Punjab Agro Machinery', ownerPhone: '03217654321', name: 'Boom Sprayer 600L', category: 'Sprayer', brand: 'Aqua', year: 2022, condition: 'used', forRent: true, rentPerHour: 900, rentPerDay: 6000, operatorAvailable: false, city: 'Sahiwal', description: 'Tractor-mounted sprayer for pesticide and fertilizer.', features: ['600 L tank', '12 m boom'], rating: 4.2, ratingCount: 7, totalBookings: 21 },
      { owner: 'seed', ownerName: 'Indus Farm Tools', ownerPhone: '03331112233', name: 'Rotavator 7 ft', category: 'Plough', brand: 'Millat', year: 2023, condition: 'used', forRent: true, rentPerHour: 700, rentPerDay: 4500, operatorAvailable: true, operatorRatePerHour: 300, city: 'Islamabad', description: 'Seed-bed preparation, fits 60+ HP tractors.', features: ['7 ft'], rating: 4.4, ratingCount: 11, totalBookings: 30 }
    ]);
  }
  if (!(await Warehouse.countDocuments({ owner: 'seed' }))) {
    await Warehouse.insertMany([
      { owner: 'seed', ownerName: 'Al-Rehman Storage', ownerPhone: '03004445566', name: 'Al-Rehman Grain Store', city: 'Faisalabad', address: 'Jhang Road', capacityTons: 800, storageTypes: ['Dry Store', 'Grain Silo'], facilities: ['Security guard', 'CCTV', 'Fumigation', 'Loading dock', 'Weighbridge'], ratePerTonDay: 35, minTons: 2, description: 'Dry grain storage with fumigation.', rating: 4.6, ratingCount: 22 },
      { owner: 'seed', ownerName: 'FreshChain Pakistan', ownerPhone: '03112223344', name: 'FreshChain Cold Storage', city: 'Lahore', address: 'Multan Road', capacityTons: 300, storageTypes: ['Cold Storage'], facilities: ['Power backup', 'CCTV', 'Insurance'], ratePerTonDay: 120, minTons: 1, description: 'Temperature-controlled storage for fruit and vegetables.', rating: 4.7, ratingCount: 13 },
      { owner: 'seed', ownerName: 'Kisan Godown', ownerPhone: '03455556677', name: 'Kisan Godown', city: 'Multan', address: 'Bosan Road', capacityTons: 500, storageTypes: ['Dry Store', 'Open Yard'], facilities: ['Security guard', 'Loading dock'], ratePerTonDay: 22, minTons: 5, description: 'Affordable bulk storage for wheat and cotton.', rating: 4.1, ratingCount: 8 }
    ]);
  }
}

module.exports = { seedFleet };
