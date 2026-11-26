const { Listing, Profile } = require('../models/agri');
const { bad } = require('./http');
const { cleanPhotos } = require('./uploads');
const { num } = require('./geo');
const { requirePhone, cleanPhone, PK_MOBILE } = require('./phone');

// Used by farmers (produce) and suppliers (farm inputs)
async function createListing(me, b) {
  if (!b.title || !String(b.title).trim()) throw bad('Enter the product / produce name');
  const qty = Number(b.quantityKg);
  const price = Number(b.pricePerKg);
  if (!Number.isFinite(qty) || qty <= 0 || qty > 1e8) throw bad('Enter a valid quantity');
  if (!Number.isFinite(price) || price <= 0 || price > 1e7) throw bad('Enter a valid price');
  const profile = me.demo ? null : await Profile.findOne({ user: me.id });
  const supplier = me.role === 'supplier';
  const sellerPhone = await requirePhone(me, b.phone, profile);
  return Listing.create({
    sellerPhone,
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
    photos: cleanPhotos(b.photos),
    lat: num(b.lat),
    lng: num(b.lng),
    address: String(b.address || '').slice(0, 160),
    verified: supplier ? !!(profile && profile.verified) : true,
    rating: 0,
    reviews: 0
  });
}

// fields a seller may change later
function applyListingEdit(l, b) {
  if (b.title !== undefined && String(b.title).trim()) l.title = String(b.title).trim();
  if (b.category !== undefined) l.category = b.category;
  if (b.grade !== undefined) l.grade = b.grade;
  if (b.pricePerKg !== undefined) {
    const v = Number(b.pricePerKg);
    if (!Number.isFinite(v) || v <= 0 || v > 1e7) throw bad('Enter a valid price');
    l.pricePerKg = v;
  }
  if (b.quantityKg !== undefined) {
    const v = Number(b.quantityKg);
    if (!Number.isFinite(v) || v < 0 || v > 1e8) throw bad('Enter a valid quantity');
    l.quantityKg = v;
  }
  if (b.status && ['active', 'paused'].includes(b.status)) l.status = b.status;
  if (b.description !== undefined) l.description = b.description;
  if (b.brand !== undefined) l.brand = b.brand;
  if (b.photos !== undefined) l.photos = cleanPhotos(b.photos);
  if (b.phone !== undefined) {
    const p = cleanPhone(b.phone);
    if (!PK_MOBILE.test(p)) throw bad('Enter a valid mobile number, e.g. 03001234567');
    l.sellerPhone = p;
  }
  if (b.location !== undefined) l.location = b.location;
  if (b.address !== undefined) l.address = String(b.address).slice(0, 160);
  if (b.lat !== undefined) l.lat = num(b.lat);
  if (b.lng !== undefined) l.lng = num(b.lng);
}

module.exports = { createListing, applyListingEdit };