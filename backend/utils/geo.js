// Distance helpers for "near me" sorting (no external API needed)
function km(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const rad = d => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// Adds distanceKm to every item that has lat/lng. With ?lat&lng&sort=near it sorts nearest first,
// with ?maxKm it drops items further away.
function applyDistance(items, q) {
  const lat = Number(q.lat);
  const lng = Number(q.lng);
  if (!q.lat || !q.lng || Number.isNaN(lat) || Number.isNaN(lng)) return items;
  items.forEach(i => {
    if (typeof i.lat === 'number' && typeof i.lng === 'number') i.distanceKm = Math.round(km(lat, lng, i.lat, i.lng) * 10) / 10;
  });
  let out = items;
  if (q.maxKm) out = out.filter(i => i.distanceKm !== undefined && i.distanceKm <= Number(q.maxKm));
  if (q.sort === 'near') out = out.slice().sort((a, b) => (a.distanceKm ?? 1e9) - (b.distanceKm ?? 1e9));
  return out;
}

const num = v => (v === '' || v === undefined || v === null || Number.isNaN(Number(v)) ? undefined : Number(v));

module.exports = { km, applyDistance, num };
