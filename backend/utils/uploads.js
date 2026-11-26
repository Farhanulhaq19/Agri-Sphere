const fs = require('fs');
const path = require('path');
const { bad } = require('./http');

const ROOT = path.join(__dirname, '..', 'uploads');
const FOLDERS = ['listings', 'machines', 'warehouses', 'crops', 'payments', 'profiles'];

// Save a base64 data URL ("data:image/png;base64,...") and return its public path (/uploads/<folder>/<file>)
function saveImage(dataUrl, folder, prefix) {
  const m = /^data:image\/(png|jpe?g|webp);base64,(.+)$/i.exec(String(dataUrl || ''));
  if (!m) throw bad('Please attach a PNG, JPG or WEBP image');
  const buf = Buffer.from(m[2], 'base64');
  if (buf.length > 5 * 1024 * 1024) throw bad('Image is too large (max 5 MB)');
  const dir = FOLDERS.includes(folder) ? folder : 'listings';
  fs.mkdirSync(path.join(ROOT, dir), { recursive: true });
  const ext = m[1].toLowerCase().replace('jpeg', 'jpg');
  const name = (prefix || dir) + '-' + Date.now() + '-' + Math.random().toString(36).slice(2, 7) + '.' + ext;
  fs.writeFileSync(path.join(ROOT, dir, name), buf);
  if (dir !== 'payments' && !process.env.NO_THUMBS) makeThumb(path.join(ROOT, dir, name)); // in the background
  return '/uploads/' + dir + '/' + name;
}

// photo.jpg -> photo_t.jpg (400px wide). Lists load these, so they use far less mobile data.
const thumbName = (file) => file.replace(/\.(png|jpe?g|webp)$/i, '_t.jpg');
function makeThumb(file) {
  try {
    const sharp = require('sharp');
    return sharp(file).rotate().resize({ width: 400, withoutEnlargement: true }).jpeg({ quality: 72 }).toFile(thumbName(file))
      .catch(e => console.warn('Thumbnail failed:', e.message));
  } catch (e) {
    return Promise.resolve();
  }
}

// Only keep photo paths we uploaded ourselves (or normal https links), max 6
function cleanPhotos(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map(x => String(x || '').trim())
    .filter(x => /^\/uploads\/[a-z]+\/[\w.-]+$/i.test(x) || /^https:\/\/[^\s]+$/i.test(x))
    .slice(0, 6);
}

// Payment proof shared by orders, machinery and storage bookings
function readProof(body) {
  const b = body || {};
  const ref = String(b.ref || '').trim().slice(0, 40);
  if (ref.length < 6) throw bad('Enter the transaction ID from your Easypaisa receipt');
  return { ref, url: saveImage(b.image, 'payments', 'pay') };
}

const payAccount = () => ({
  method: 'Easypaisa',
  number: process.env.EASYPAISA_NUMBER || '03195082175',
  name: process.env.EASYPAISA_NAME || 'Farhanulhaq'
});

module.exports = { saveImage, cleanPhotos, readProof, payAccount, makeThumb, thumbName };
