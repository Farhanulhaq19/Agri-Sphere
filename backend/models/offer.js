const mongoose = require('mongoose');
const S = mongoose.Schema;

// A price offer on a produce listing ("Make an Offer" / "Negotiate a Price")
const Offer = mongoose.models.AgriOffer || mongoose.model('AgriOffer', new S({
  listing: { type: S.Types.ObjectId, ref: 'AgriListing', index: true },
  listingTitle: String,
  listPrice: Number,
  seller: { type: String, index: true },
  sellerName: String,
  buyer: { type: String, index: true },
  buyerName: String,
  qtyKg: Number,
  pricePerKg: Number,
  address: String,
  status: { type: String, enum: ['pending', 'countered', 'accepted', 'rejected', 'cancelled'], default: 'pending', index: true },
  // who has to answer next: 'seller' (pending) or 'buyer' (countered)
  rounds: [{ by: String, pricePerKg: Number, note: String, at: Date }],
  order: String
}, { timestamps: true }));

module.exports = { Offer };
