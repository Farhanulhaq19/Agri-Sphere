const mongoose = require('mongoose');
const S = mongoose.Schema;
const model = (name, schema) => mongoose.models[name] || mongoose.model(name, schema);

// Saved / favourite items (marketplace listing, machine or warehouse). Keeps a small snapshot for the Saved list.
const favSchema = new S({
  user: { type: String, index: true },
  kind: { type: String, enum: ['listing', 'machine', 'warehouse'] },
  ref: String,
  title: String,
  sub: String,
  price: String,
  photo: String
}, { timestamps: true });
favSchema.index({ user: 1, kind: 1, ref: 1 }, { unique: true });
const Favorite = model('AgriFavorite', favSchema);

// One chat between two people, optionally about a listing / machine / warehouse.
const Conversation = model('AgriConversation', new S({
  members: { type: [String], index: true },
  names: { type: Map, of: String, default: {} },
  topic: { kind: String, ref: String, title: String },
  lastText: String,
  lastAt: Date,
  lastBy: String,
  unread: { type: Map, of: Number, default: {} }
}, { timestamps: true }));

const Message = model('AgriMessage', new S({
  conv: { type: S.Types.ObjectId, index: true },
  from: String,
  fromName: String,
  text: String
}, { timestamps: true }));

// A buyer's review of one product after the order was delivered (one per order + product).
const reviewSchema = new S({
  listing: { type: S.Types.ObjectId, index: true },
  order: S.Types.ObjectId,
  user: String,
  name: String,
  rating: { type: Number, min: 1, max: 5 },
  text: String
}, { timestamps: true });
reviewSchema.index({ order: 1, listing: 1 }, { unique: true });
const Review = model('AgriReview', reviewSchema);

module.exports = { Favorite, Conversation, Message, Review };
