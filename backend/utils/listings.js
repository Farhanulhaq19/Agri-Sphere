const { Listing, Profile } = require('../models/agri');
const { bad } = require('./http');

// Used by farmers (produce) and suppliers (farm inputs)
async function createListing(me, b) {
  if (!b.title || !String(b.title).trim()) throw bad('Enter the product / produce name');
  const qty = Number(b.quantityKg);
  const price = Number(b.pricePerKg);
  if (!qty || qty <= 0) throw bad('Enter a valid quantity');
  if (!price || price <= 0) throw bad('Enter a valid price');
  const profile = me.demo ? null : await Profile.findOne({ user: me.id });
  const supplier = me.role === 'supplier';
  return Listing.create({
    seller: me.id,
    sellerName: supplier ? ((profile && profile.businessName) || me.name) : me.name,
    sellerRole: supplier ? 'supplier' : 'farmer',
    kind: supplier ? 'input' : 'produce',
    location: b.location || (profile && profile.city) || 'Islamabad',
    title: String(b.title).trim(),
    category: b.category || (supplier ? 'Seeds' : 'Grains'),
    brand: b.brand || '',
    unit: b.unit || 'kg',
    grade: b.grade || 'Grade A',
    pricePerKg: price,
    quantityKg: qty,
    availableUntil: b.availableUntil ? new Date(b.availableUntil) : undefined,
    description: b.description || '',
    verified: supplier ? !!(profile && profile.verified) : true,
    rating: 4.5
  });
}

module.exports = { createListing };