const mongoose = require('mongoose');

// Safe running numbers (order #1041, booking #1001...). One atomic $inc per number,
// so two requests at the same moment can never get the same number.
const Counter = mongoose.models.AgriCounter || mongoose.model('AgriCounter', new mongoose.Schema({
  _id: String,
  seq: { type: Number, default: 0 }
}));

async function nextNumber(key, Model, start) {
  const inc = () => Counter.findOneAndUpdate({ _id: key }, { $inc: { seq: 1 } }, { returnDocument: 'after' });
  let c = await inc();
  if (!c) {
    // first time: continue after the highest number already in the database
    const last = await Model.findOne({ number: { $exists: true } }, { number: 1 }).sort({ number: -1 });
    const base = Math.max(start, (last && last.number) || 0);
    try {
      await Counter.create({ _id: key, seq: base });
    } catch (e) {
      if (e.code !== 11000) throw e; // another request created it first: fine
    }
    c = await inc();
  }
  return c.seq;
}

module.exports = { nextNumber, Counter };
