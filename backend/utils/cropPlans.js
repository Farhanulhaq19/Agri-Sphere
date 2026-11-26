// Smart crop calendar: a standard plan per crop (Pakistan conditions). Each task has a day
// counted from sowing, so real due dates are generated when a farmer adds a crop.
// Values are typical extension-service guidance; farmers can tick tasks off or ignore them.
const PLANS = {
  wheat: {
    days: 150, yieldPerAcre: 1300, seasons: 'Rabi: sow Nov 1 - Nov 30, harvest Apr - May',
    tasks: [
      [0, 'Sowing with DAP (1 bag/acre)', 'fertilizer', 'Sowing'],
      [21, 'First irrigation (crown root stage)', 'irrigation', 'Sprout'],
      [25, 'Urea 1st dose (1 bag/acre)', 'fertilizer', 'Sprout'],
      [35, 'Weed control spray (broadleaf + grassy)', 'spray', 'Tillering'],
      [45, 'Second irrigation (tillering)', 'irrigation', 'Tillering'],
      [55, 'Urea 2nd dose (0.5-1 bag/acre)', 'fertilizer', 'Tillering'],
      [70, 'Check for yellow rust and aphids', 'scout', 'Heading'],
      [80, 'Third irrigation (booting / heading)', 'irrigation', 'Heading'],
      [100, 'Fourth irrigation (grain filling)', 'irrigation', 'Heading'],
      [140, 'Stop irrigation, plan harvester booking', 'harvest', 'Harvest'],
      [150, 'Harvest and dry grain to 10% moisture', 'harvest', 'Harvest']
    ]
  },
  rice: {
    days: 130, yieldPerAcre: 1500, seasons: 'Kharif: nursery May - Jun, transplant Jun - Jul, harvest Oct - Nov',
    tasks: [
      [0, 'Transplant nursery seedlings (30-35 days old)', 'sowing', 'Sowing'],
      [3, 'Herbicide within 3-5 days of transplanting', 'spray', 'Sowing'],
      [7, 'Keep 2-3 inch standing water', 'irrigation', 'Sprout'],
      [15, 'Urea 1st dose + zinc sulphate', 'fertilizer', 'Sprout'],
      [35, 'Urea 2nd dose', 'fertilizer', 'Tillering'],
      [45, 'Check for stem borer and leaf folder', 'scout', 'Tillering'],
      [75, 'Check for blast and bacterial blight', 'scout', 'Heading'],
      [110, 'Drain field 10 days before harvest', 'irrigation', 'Harvest'],
      [130, 'Harvest at 20-22% grain moisture', 'harvest', 'Harvest']
    ]
  },
  cotton: {
    days: 180, yieldPerAcre: 900, seasons: 'Kharif: sow Apr - May, pick Sep - Nov',
    tasks: [
      [0, 'Sowing on beds with DAP', 'fertilizer', 'Sowing'],
      [30, 'First irrigation + thinning', 'irrigation', 'Sprout'],
      [35, 'Scout for whitefly and jassid', 'scout', 'Sprout'],
      [45, 'Urea 1st dose', 'fertilizer', 'Tillering'],
      [60, 'Install pheromone traps for pink bollworm', 'scout', 'Tillering'],
      [75, 'Urea 2nd dose at flowering', 'fertilizer', 'Heading'],
      [90, 'Irrigation every 10-12 days in heat', 'irrigation', 'Heading'],
      [120, 'Check bolls for pink bollworm', 'scout', 'Heading'],
      [150, 'First picking', 'harvest', 'Harvest'],
      [180, 'Final picking, destroy crop residue', 'harvest', 'Harvest']
    ]
  },
  maize: {
    days: 110, yieldPerAcre: 3000, seasons: 'Spring: Feb - Mar, Autumn: Jul - Aug',
    tasks: [
      [0, 'Sowing with DAP (1 bag/acre)', 'fertilizer', 'Sowing'],
      [12, 'First irrigation', 'irrigation', 'Sprout'],
      [20, 'Weed control + earthing up', 'spray', 'Sprout'],
      [25, 'Urea 1st dose', 'fertilizer', 'Tillering'],
      [30, 'Check for fall armyworm', 'scout', 'Tillering'],
      [45, 'Urea 2nd dose (knee height)', 'fertilizer', 'Tillering'],
      [60, 'Irrigation at tasseling (critical)', 'irrigation', 'Heading'],
      [75, 'Irrigation at grain filling', 'irrigation', 'Heading'],
      [110, 'Harvest when husks turn brown', 'harvest', 'Harvest']
    ]
  },
  potato: {
    days: 100, yieldPerAcre: 9000, seasons: 'Autumn: Oct, harvest Jan - Feb',
    tasks: [
      [0, 'Plant seed tubers with DAP + SOP', 'fertilizer', 'Sowing'],
      [7, 'Light irrigation', 'irrigation', 'Sowing'],
      [25, 'Earthing up + urea', 'fertilizer', 'Sprout'],
      [35, 'Preventive spray for late blight', 'spray', 'Tillering'],
      [50, 'Check for late blight after fog / rain', 'scout', 'Tillering'],
      [60, 'Irrigation every 8-10 days', 'irrigation', 'Heading'],
      [85, 'Stop irrigation 10-15 days before harvest', 'irrigation', 'Harvest'],
      [100, 'Harvest and cure, book cold storage', 'harvest', 'Harvest']
    ]
  },
  sugarcane: {
    days: 330, yieldPerAcre: 30000, seasons: 'Spring: Feb - Mar, Autumn: Sep',
    tasks: [
      [0, 'Plant setts in trenches with DAP', 'fertilizer', 'Sowing'],
      [20, 'First irrigation', 'irrigation', 'Sprout'],
      [45, 'Weed control', 'spray', 'Sprout'],
      [60, 'Urea 1st dose + earthing up', 'fertilizer', 'Tillering'],
      [90, 'Check for borers', 'scout', 'Tillering'],
      [120, 'Urea 2nd dose + earthing up', 'fertilizer', 'Tillering'],
      [180, 'Irrigation every 2 weeks in summer', 'irrigation', 'Heading'],
      [300, 'Stop irrigation before harvest', 'irrigation', 'Harvest'],
      [330, 'Harvest and send to mill', 'harvest', 'Harvest']
    ]
  },
  tomato: {
    days: 120, yieldPerAcre: 10000, seasons: 'Nursery Sep / Jan, transplant after 30 days',
    tasks: [
      [0, 'Transplant seedlings', 'sowing', 'Sowing'],
      [5, 'Light irrigation', 'irrigation', 'Sowing'],
      [20, 'Staking and urea', 'fertilizer', 'Sprout'],
      [35, 'Check for early blight and whitefly', 'scout', 'Tillering'],
      [50, 'Potash + calcium for fruit set', 'fertilizer', 'Heading'],
      [70, 'First picking', 'harvest', 'Harvest'],
      [120, 'Last picking', 'harvest', 'Harvest']
    ]
  },
  onion: {
    days: 130, yieldPerAcre: 8000, seasons: 'Transplant Dec - Jan, harvest Apr - May',
    tasks: [
      [0, 'Transplant seedlings with DAP', 'fertilizer', 'Sowing'],
      [10, 'Irrigation', 'irrigation', 'Sprout'],
      [30, 'Weeding + urea', 'fertilizer', 'Sprout'],
      [60, 'Check for thrips and purple blotch', 'scout', 'Tillering'],
      [100, 'Stop irrigation when tops fall', 'irrigation', 'Harvest'],
      [130, 'Harvest and dry bulbs in shade', 'harvest', 'Harvest']
    ]
  }
};

const DEFAULT = {
  days: 110, yieldPerAcre: 1000, seasons: '',
  tasks: [
    [0, 'Sowing / planting', 'sowing', 'Sowing'],
    [10, 'First irrigation', 'irrigation', 'Sprout'],
    [25, 'Fertilizer top dressing', 'fertilizer', 'Sprout'],
    [40, 'Check for pests and diseases', 'scout', 'Tillering'],
    [60, 'Irrigation', 'irrigation', 'Heading'],
    [110, 'Harvest', 'harvest', 'Harvest']
  ]
};

function planFor(name) {
  const k = String(name || '').toLowerCase();
  const key = Object.keys(PLANS).find(p => k.includes(p) || (p === 'rice' && k.includes('paddy')) || (p === 'maize' && k.includes('corn')));
  return { key: key || 'default', ...(key ? PLANS[key] : DEFAULT) };
}

// tasks with real due dates for a crop sown on `sowing`
function buildTasks(name, sowing, field) {
  const p = planFor(name);
  const start = new Date(sowing || Date.now());
  return p.tasks.map(([day, title, type, stage]) => ({
    title, type, stage, field: field || 'Field A', due: new Date(start.getTime() + day * 864e5), when: '', done: false
  }));
}

// "Today", "Tomorrow", "In 5 days", "3 days ago"
function whenText(due) {
  if (!due) return '';
  const d0 = new Date(); d0.setHours(0, 0, 0, 0);
  const d1 = new Date(due); d1.setHours(0, 0, 0, 0);
  const n = Math.round((d1 - d0) / 864e5);
  if (n === 0) return 'Today';
  if (n === 1) return 'Tomorrow';
  if (n === -1) return 'Yesterday';
  return n > 0 ? `In ${n} days` : `${-n} days ago`;
}

module.exports = { PLANS, planFor, buildTasks, whenText };
