// Creates the small *_t.jpg copies for photos uploaded before thumbnails existed.
// Run:  node scripts/make-thumbs.js
const fs = require('fs');
const path = require('path');
const { makeThumb, thumbName } = require('../utils/uploads');

(async () => {
  const root = path.join(__dirname, '..', 'uploads');
  let n = 0;
  for (const dir of fs.existsSync(root) ? fs.readdirSync(root) : []) {
    if (dir === 'payments') continue;
    const d = path.join(root, dir);
    if (!fs.statSync(d).isDirectory()) continue;
    for (const f of fs.readdirSync(d)) {
      if (/_t\.jpg$/.test(f) || !/\.(png|jpe?g|webp)$/i.test(f)) continue;
      const file = path.join(d, f);
      if (!fs.existsSync(thumbName(file))) { await makeThumb(file); n++; }
    }
  }
  console.log('Thumbnails created:', n);
})().catch((e) => {
  console.error('Thumbnail script failed:', e.message);
  process.exit(1);
});
