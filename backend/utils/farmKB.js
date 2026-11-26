// Built-in farming guide: AgriChatBot falls back to these answers when no AI model is available
// (no internet, Ollama not running, no key). Short, practical guidance for common questions in Pakistan.
// Doses are typical extension-service values; the answer always reminds to read the label.

const KB = [
  { k: ['yellow', 'rust', 'stripe', 'wheat'], min: 2, a: `This sounds like **yellow (stripe) rust** on wheat.
- Spray a triazole fungicide (e.g. tebuconazole or propiconazole) at the label dose, about 200 ml per acre in 100 litres of water.
- Spray on a dry, calm day; repeat after 10-15 days if it spreads.
- Avoid extra urea until the disease is under control.
- Next season, sow a rust-resistant variety (e.g. Akbar-2019, Dilkash-2020).` },
  { k: ['aphid', 'tela', 'wheat'], min: 1, a: `**Aphids (tela)** suck sap and spread fast in cool, cloudy weather.
- Check 10 plants per acre; spray if you find more than 10-15 aphids per tiller.
- Use imidacloprid or thiamethoxam at the label dose, or a soap-water spray for small areas.
- Ladybird beetles eat aphids, so avoid unnecessary sprays.` },
  { k: ['whitefly', 'cotton'], min: 1, a: `**Whitefly on cotton:**
- Hang yellow sticky traps (10 per acre) to monitor.
- Spray when there are more than 5 adults per leaf: pyriproxyfen, spirotetramat or flonicamid (rotate products).
- Remove weeds around the field; they host whitefly.
- Avoid too much nitrogen and spray in the evening.` },
  { k: ['pink', 'bollworm', 'cotton'], min: 2, a: `**Pink bollworm** is the most damaging cotton pest.
- Install pheromone traps (2-3 per acre) from 45 days after sowing.
- Spray when 8 or more moths per trap per 3 nights: emamectin benzoate, chlorantraniliprole or spinetoram.
- Destroy cotton sticks and opened bolls after the season; do not store infested seed cotton.` },
  { k: ['irrigat', 'water', 'wheat'], min: 2, a: `**Wheat irrigation schedule** (4-5 irrigations in total):
1. Crown root stage: 20-25 days after sowing (most important).
2. Tillering: 40-50 days.
3. Booting / heading: 75-85 days.
4. Grain filling: 95-105 days.
- Skip or delay if good rain falls. Do not irrigate in strong wind (crop falls).` },
  { k: ['fertilizer', 'urea', 'dap', 'wheat'], min: 2, a: `**Fertilizer for wheat (per acre):**
- At sowing: 1 bag DAP (+ half bag potash on sandy soils).
- 1st irrigation: 1 bag urea.
- 2nd irrigation: half to 1 bag urea.
- A soil test gives the most accurate dose; do not broadcast urea on wet leaves.` },
  { k: ['maize', 'corn', 'fertilizer'], min: 2, a: `**Fertilizer for maize (per acre):**
- At sowing: 1.5 bags DAP + 1 bag SOP (potash).
- At knee height: 1.5 bags urea, split in 2 doses with irrigation.
- Zinc sulphate 5 kg per acre if leaves show white stripes.` },
  { k: ['rice', 'paddy', 'fertilizer'], min: 2, a: `**Fertilizer for rice (per acre):**
- At transplanting: 1 bag DAP + 5 kg zinc sulphate.
- 15 and 35 days after transplanting: 1 bag urea each time.
- Keep 2-3 inches of water for the first month.` },
  { k: ['blight', 'potato'], min: 1, a: `**Late blight on potato** spreads fast after fog or rain.
- Spray preventively every 7-10 days in foggy weather: mancozeb; if spots appear use a systemic like metalaxyl + mancozeb or cymoxanil.
- Remove and bury badly infected plants.
- Avoid evening irrigation; keep leaves dry.` },
  { k: ['sow', 'time', 'wheat'], min: 2, a: `**Best sowing time for wheat:** 1-30 November in Punjab and Sindh (up to 15 December with late varieties).
- Seed rate: 40-50 kg per acre.
- Late sowing loses about 15-20 kg yield per acre for each day after 20 November.` },
  { k: ['sow', 'time', 'potato'], min: 2, a: `**Potato sowing:** autumn crop 1-31 October in Punjab plains; spring crop January-February.
- Seed: 1,000-1,200 kg per acre of healthy, sprouted tubers.
- Plant on ridges 75 cm apart.` },
  { k: ['sow', 'cotton'], min: 2, a: `**Cotton sowing:** 1 April - 31 May in Punjab (earlier in Sindh).
- Sow on beds or ridges; 6-8 kg delinted seed per acre.
- Use Bt varieties approved for your area.` },
  { k: ['tomato', 'leaf', 'spot', 'curl'], min: 2, a: `**Tomato leaf problems:**
- Brown spots with rings = early blight: spray mancozeb or chlorothalonil.
- Curled, yellow leaves = leaf curl virus (spread by whitefly): remove sick plants, control whitefly, use resistant varieties.
- Stake plants and avoid wetting the leaves.` },
  { k: ['mango', 'hopper', 'mildew'], min: 1, a: `**Mango care:**
- Powdery mildew on flowers: sulphur or a triazole spray at flowering.
- Mango hopper: spray imidacloprid when flowers start.
- Avoid irrigation during flowering; resume at fruit set.` },
  { k: ['kinnow', 'citrus', 'orange'], min: 1, a: `**Kinnow / citrus:**
- Fertilizer per mature tree per year: 1.5-2 kg urea, 1 kg DAP, 1 kg SOP, split Feb / Jun / Sep.
- Fruit drop: give regular light irrigation, avoid water stress in summer.
- Citrus psylla and leaf miner: spray on new flush.` },
  { k: ['soil', 'test'], min: 1, a: `**Soil testing** tells you exactly how much fertilizer you need and saves money.
- Take 10-15 small samples from 6 inches deep across the field, mix, and send 0.5 kg to your district soil testing lab (Agriculture Department) - it is free or very cheap.
- Test every 2-3 years, before sowing.` },
  { k: ['weed', 'herbicide'], min: 1, a: `**Weed control:**
- Wheat: spray a broadleaf + grassy-weed herbicide 30-40 days after sowing, after the first irrigation, when soil is moist.
- Use flat-fan nozzles, spray on a calm day, and do not spray twice on the same strip.` },
  { k: ['sell', 'list', 'produce', 'marketplace'], min: 1, a: `**How to sell on AgriSphere:**
1. Open **Marketplace** → tap **+ Sell**.
2. Add photos, name, quantity, price per kg and your pickup point on the map.
3. Tap **Publish listing**. Buyers can buy, make offers or chat with you.
- Use **Price trends** to decide whether to sell now or hold.` },
  { k: ['pay', 'easypaisa', 'checkout', 'card', 'cash'], min: 1, a: `**Paying on AgriSphere:**
- **Cash on Delivery:** pay the rider when the order arrives.
- **Easypaisa / card:** send the amount to the Easypaisa account shown at checkout, then upload the screenshot and transaction ID. The order is confirmed after the payment is verified.` },
  { k: ['rent', 'tractor', 'harvester', 'machine'], min: 1, a: `**Renting machinery:**
1. Open **Rent machine**, tap **Near me** to see the closest tractors and harvesters.
2. Choose hours or days, add a technician if needed, and pin your field on the map.
3. The owner accepts, and you can track the machine and pay by cash or Easypaisa.` },
  { k: ['store', 'warehouse', 'cold', 'storage'], min: 1, a: `**Storing your crop:**
1. Open **Store crop** → choose a warehouse (see free space, price per ton per day, facilities).
2. Request space for your quantity and dates.
3. After approval, bring the crop; you can see temperature and humidity readings in the app.` },
  { k: ['weather', 'rain', 'forecast'], min: 1, a: `The **dashboard** shows today's weather and a 4-day forecast for your location, with a farming tip (e.g. skip irrigation when rain is likely). Allow location access for the most accurate forecast.` },
  { k: ['price', 'rate', 'mandi'], min: 1, a: `For current prices, open **Price trends** in AgriSphere: it shows the last 90 days of prices on the platform and a short forecast. Always compare with your local mandi rate before selling.` },
  { k: ['expert', 'doctor', 'help'], min: 1, a: `For a detailed answer from a person, use **Ask an Expert**. For a sick plant, use the **Crop Doctor**: take a clear photo of the affected leaves and get possible causes and treatment.` }
];

const FALLBACK = `I could not find a ready answer for that in my built-in guide.
- Try asking about a crop and the problem, e.g. "yellow leaves on wheat" or "whitefly on cotton".
- For a sick plant, use the **Crop Doctor** with a photo.
- For anything else, **Ask an Expert** - a human agronomist will reply.`;

function answer(question, urdu) {
  const q = String(question || '').toLowerCase();
  let best = null;
  let bestScore = 0;
  for (const e of KB) {
    const hits = e.k.filter(w => q.includes(w)).length;
    if (hits >= e.min && hits > bestScore) {
      best = e;
      bestScore = hits;
    }
  }
  return best ? best.a : FALLBACK; // the app shows a 'built-in guide' label under the answer
}

// Most common problems per crop, used by the Crop Doctor when no vision model is available.
const COMMON = {
  wheat: ['Yellow (stripe) rust - yellow powdery stripes on leaves', 'Aphids - small green insects on leaves and ears', 'Nitrogen deficiency - pale yellow older leaves'],
  rice: ['Blast - eye-shaped spots on leaves', 'Bacterial leaf blight - yellow leaf edges', 'Stem borer - dead hearts and white ears'],
  cotton: ['Whitefly - tiny white insects under leaves', 'Pink bollworm - damaged bolls', 'Cotton leaf curl virus - curled, thick leaves'],
  maize: ['Fall armyworm - holes and sawdust in the whorl', 'Zinc deficiency - white stripes on leaves'],
  potato: ['Late blight - dark wet patches after fog', 'Early blight - brown spots with rings'],
  tomato: ['Early blight - brown target-like spots', 'Leaf curl virus - small curled leaves', 'Fruit borer - holes in fruit'],
  default: ['Fungal leaf spot', 'Sap-sucking insects (aphids, whitefly, jassid)', 'Nutrient deficiency (nitrogen, zinc)', 'Water stress (too much or too little water)']
};

function offlineDiagnosis(crop) {
  const key = Object.keys(COMMON).find(k => String(crop || '').toLowerCase().includes(k)) || 'default';
  return {
    isPlantPhoto: true,
    crop: crop || 'Unknown',
    healthy: false,
    problem: 'Photo check needs the AI model',
    problemType: 'unknown',
    confidence: 'low',
    severity: 'none',
    symptoms: ['The AI model is offline, so the photo could not be analysed automatically.', ...COMMON[key].map(p => 'Common in this crop: ' + p)],
    cause: 'Compare your plant with the common problems listed above, or send the photo to an expert.',
    treatment: ['Ask an expert with this photo before spraying anything.'],
    organic: ['Remove badly affected leaves or plants to slow the spread.'],
    prevention: ['Use healthy seed, balanced fertilizer and regular field checks.'],
    askExpert: true,
    urduSummary: 'اے آئی ماڈل اس وقت دستیاب نہیں۔ اوپر دی گئی عام بیماریوں سے موازنہ کریں یا یہ تصویر ماہر کو بھیجیں۔'
  };
}

module.exports = { answer, offlineDiagnosis, KB };
