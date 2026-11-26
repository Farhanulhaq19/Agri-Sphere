// AI features:
//   AgriChatBot  - farming assistant anyone can ask, any time (English / Urdu)
//   Crop Doctor  - diagnose crop problems from a photo (structured result)
//
// FREE by default. The server picks the first one available (or set AI_PROVIDER in backend/.env):
//   1. ollama    - free AI running on this computer (https://ollama.com). No account, no internet. DEFAULT.
//   2. groq      - free online AI (GROQ_API_KEY from console.groq.com, no card needed).
//   3. anthropic - Claude (paid, optional): ANTHROPIC_API_KEY.
//   4. offline   - built-in farming guide (always works, no AI).
const express = require('express');
const mongoose = require('mongoose');
const { z } = require('zod');
const { h, bad, out } = require('../../utils/http');
const { saveImage } = require('../../utils/uploads');
const { rateLimit } = require('../../utils/rateLimit');
const kb = require('../../utils/farmKB');
const { safe } = require('../../utils/safeLog');

const router = express.Router();

const OLLAMA_URL = () => (process.env.OLLAMA_URL || 'http://127.0.0.1:11434').replace(/\/$/, '');
const OLLAMA_MODEL = () => process.env.OLLAMA_MODEL || 'gemma3:4b'; // small, reads photos, runs on a normal laptop
const GROQ_MODEL = () => process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
const GROQ_VISION_MODEL = () => process.env.GROQ_VISION_MODEL || 'meta-llama/llama-4-scout-17b-16e-instruct';
const CLAUDE_MODEL = 'claude-opus-5-5';

// ---------------------------------------------------------------- storage
const S = mongoose.Schema;
const AiChat = mongoose.models.AgriAiChat || mongoose.model('AgriAiChat', new S({
  user: { type: String, unique: true },
  messages: [{ role: { type: String, enum: ['user', 'assistant'] }, content: String, at: Date, source: String }]
}, { timestamps: true }));

const Diagnosis = mongoose.models.AgriDiagnosis || mongoose.model('AgriDiagnosis', new S({
  user: { type: String, index: true },
  crop: String,
  note: String,
  photo: String,
  source: String,
  result: S.Types.Mixed
}, { timestamps: true }));

// ---------------------------------------------------------------- which AI is available?
let ollamaOk = null; // cache the check for 60 s
let ollamaAt = 0;
async function ollamaUp() {
  if (ollamaOk !== null && Date.now() - ollamaAt < 60000) return ollamaOk;
  try {
    const r = await fetch(OLLAMA_URL() + '/api/tags', { signal: AbortSignal.timeout(2000) });
    const j = r.ok ? await r.json() : { models: [] };
    const want = OLLAMA_MODEL().split(':')[0];
    ollamaOk = (j.models || []).some(m => String(m.name || '').startsWith(want));
  } catch (e) {
    ollamaOk = false;
  }
  ollamaAt = Date.now();
  return ollamaOk;
}

async function provider() {
  const forced = String(process.env.AI_PROVIDER || '').toLowerCase();
  if (forced === 'offline') return 'offline';
  if (forced === 'ollama') return (await ollamaUp()) ? 'ollama' : 'offline';
  if (forced === 'groq') return process.env.GROQ_API_KEY ? 'groq' : 'offline';
  if (forced === 'anthropic') return process.env.ANTHROPIC_API_KEY ? 'anthropic' : 'offline';
  if (await ollamaUp()) return 'ollama';
  if (process.env.GROQ_API_KEY) return 'groq';
  if (process.env.ANTHROPIC_API_KEY) return 'anthropic';
  return 'offline';
}

// ---------------------------------------------------------------- one function per provider
async function ollamaChat(messages, { images, schema } = {}) {
  const msgs = messages.map(m => ({ ...m }));
  if (images && images.length) msgs[msgs.length - 1].images = images; // base64 without the data: prefix
  const r = await fetch(OLLAMA_URL() + '/api/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: OLLAMA_MODEL(), messages: msgs, stream: false, keep_alive: '30m',
      options: { temperature: 0.3, num_ctx: 4096 },
      ...(schema ? { format: schema } : {})
    }),
    signal: AbortSignal.timeout(180000) // a laptop CPU can take a while for photos
  });
  if (!r.ok) throw new Error('Ollama error ' + r.status + ': ' + (await r.text()).slice(0, 200));
  const j = await r.json();
  return String((j.message && j.message.content) || '').trim();
}

async function groqChat(messages, { imageDataUrl, json } = {}) {
  const msgs = messages.map(m => ({ ...m }));
  if (imageDataUrl) {
    const last = msgs[msgs.length - 1];
    last.content = [{ type: 'text', text: last.content }, { type: 'image_url', image_url: { url: imageDataUrl } }];
  }
  const r = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + process.env.GROQ_API_KEY },
    body: JSON.stringify({
      model: imageDataUrl ? GROQ_VISION_MODEL() : GROQ_MODEL(), messages: msgs, temperature: 0.3, max_tokens: 2000,
      ...(json ? { response_format: { type: 'json_object' } } : {})
    }),
    signal: AbortSignal.timeout(60000)
  });
  if (r.status === 429) throw bad('The free AI limit was reached for a moment. Please try again in a minute.', 429);
  if (!r.ok) throw new Error('Groq error ' + r.status + ': ' + (await r.text()).slice(0, 200));
  const j = await r.json();
  return String((j.choices && j.choices[0] && j.choices[0].message && j.choices[0].message.content) || '').trim();
}

// Claude (optional, paid). Loaded only when used.
async function claudeChat(system, messages) {
  const Anthropic = require('@anthropic-ai/sdk');
  const client = new Anthropic();
  const res = await client.beta.messages.create({
    model: CLAUDE_MODEL, max_tokens: 4000,
    betas: ['server-side-fallback-2026-07-01'], fallbacks: 'default',
    output_config: { effort: 'low' }, system, messages
  });
  if (res.stop_reason === 'refusal') return '';
  return res.content.filter(b => b.type === 'text').map(b => b.text).join('\n').trim();
}

async function claudeDiagnose(system, mediaType, data, text) {
  const Anthropic = require('@anthropic-ai/sdk');
  const { zodOutputFormat } = require('@anthropic-ai/sdk/helpers/zod');
  const client = new Anthropic();
  const res = await client.messages.parse({
    model: CLAUDE_MODEL, max_tokens: 16000,
    output_config: { effort: 'medium', format: zodOutputFormat(DiagnosisSchema) },
    system,
    messages: [{ role: 'user', content: [{ type: 'image', source: { type: 'base64', media_type: mediaType, data } }, { type: 'text', text }] }]
  });
  return res.stop_reason === 'refusal' ? null : res.parsed_output;
}

const needUser = (req) => { if (req.me.demo) throw bad('Please log in to use AgriChatBot', 401); };
const chatLimit = rateLimit({ windowMs: 15 * 60 * 1000, max: 40, message: 'Too many questions in a short time. Please wait a few minutes.' });
const doctorLimit = rateLimit({ windowMs: 15 * 60 * 1000, max: 10, message: 'Too many photos in a short time. Please wait a few minutes.' });

// ---------------------------------------------------------------- AgriChatBot
const CHAT_SYSTEM = `You are AgriChatBot, the farming assistant inside AgriSphere, an app for farmers, buyers, suppliers, machinery and warehouse owners in Pakistan.

Who you help: small and medium farmers, many with basic literacy, often on a phone in the field. Answer like a friendly, experienced agronomist from Punjab / Sindh / KPK.

How to answer:
- Be practical and short: a direct answer first, then at most 3-6 short bullet points or steps. Use simple words.
- Use local context: Pakistani crops (wheat, rice, cotton, sugarcane, maize, potato, citrus/kinnow, mango, vegetables), local seasons (Rabi / Kharif), local units (acre, maund = 40 kg, bag = 50 kg) and prices in Rs.
- For pesticides and fertilizers give the common active ingredient and typical dose per acre, and always add: read the label, wear protection, respect the waiting period before harvest.
- If a question needs a photo, a soil test, or a site visit, say so and suggest the Crop Doctor (photo diagnosis) or "Ask an Expert" in the app.
- If you are not sure, say so honestly instead of guessing. Never invent prices, laws or brand claims; for current market rates point to the AgriSphere marketplace or local mandi.
- You can also explain how to use AgriSphere: selling produce, checkout with Cash / Easypaisa / card, renting machinery, booking warehouse space, chatting with sellers.
- Stay on farming, food, livestock, rural business and the app. Politely decline unrelated requests.
- Reply in the same language as the user. If the user writes in Urdu or Roman Urdu, reply in simple Urdu.`;

function alternate(list) {
  const outList = [];
  for (const m of list) {
    const last = outList[outList.length - 1];
    if (last && last.role === m.role) last.content += '\n\n' + m.content;
    else outList.push({ role: m.role, content: m.content });
  }
  while (outList.length && outList[0].role !== 'user') outList.shift();
  return outList;
}

router.get('/ai/chat', h(async (req, res) => {
  needUser(req);
  const c = await AiChat.findOne({ user: req.me.id });
  const p = await provider();
  res.json({ items: c ? c.messages.slice(-60).map(m => ({ role: m.role, content: m.content, at: m.at, source: m.source })) : [], ready: true, provider: p });
}));

router.delete('/ai/chat', h(async (req, res) => {
  needUser(req);
  await AiChat.deleteOne({ user: req.me.id });
  res.json({ ok: true });
}));

router.post('/ai/chat', chatLimit, h(async (req, res) => {
  needUser(req);
  const text = String((req.body || {}).text || '').trim().slice(0, 2000);
  if (!text) throw bad('Type your question');
  const urdu = (req.body || {}).lang === 'ur';
  const c = (await AiChat.findOne({ user: req.me.id })) || new AiChat({ user: req.me.id, messages: [] });
  const history = alternate([...c.messages.slice(-12).map(m => ({ role: m.role, content: m.content })), { role: 'user', content: text }]);
  const system = CHAT_SYSTEM + (urdu ? '\n\nThe app is set to Urdu: reply in simple Urdu script.' : '') + `\n\nThe user's name is ${req.me.name}.`;

  let p = await provider();
  let reply = '';
  try {
    if (p === 'ollama') reply = await ollamaChat([{ role: 'system', content: system }, ...history]);
    else if (p === 'groq') reply = await groqChat([{ role: 'system', content: system }, ...history]);
    else if (p === 'anthropic') reply = await claudeChat(system, history);
  } catch (e) {
    if (e.status === 429) throw e;
    console.warn('AI provider failed, using built-in guide:', safe(e.message));
    ollamaOk = null; // re-check next time
    p = 'offline';
  }
  if (!reply) {
    p = 'offline';
    reply = kb.answer(text, urdu);
  }
  c.messages.push({ role: 'user', content: text, at: new Date() }, { role: 'assistant', content: reply, at: new Date(), source: p });
  if (c.messages.length > 100) c.messages = c.messages.slice(-100);
  await c.save();
  res.json({ reply, at: new Date(), source: p });
}));

// ---------------------------------------------------------------- Crop Doctor
const DiagnosisSchema = z.object({
  isPlantPhoto: z.boolean().describe('false if the photo does not show a plant, crop, leaf, fruit or soil'),
  crop: z.string().describe('crop / plant identified, e.g. "Wheat"'),
  healthy: z.boolean(),
  problem: z.string().describe('most likely disease, pest or deficiency, e.g. "Yellow (stripe) rust"; "None" if healthy'),
  problemType: z.enum(['disease', 'pest', 'nutrient', 'water', 'weather', 'healthy', 'unknown']),
  confidence: z.enum(['low', 'medium', 'high']),
  severity: z.enum(['none', 'mild', 'moderate', 'severe']),
  symptoms: z.array(z.string()).describe('what is visible in the photo'),
  cause: z.string().describe('short explanation of why this happens'),
  treatment: z.array(z.string()).describe('steps to take now, with common active ingredients and per-acre doses where relevant'),
  organic: z.array(z.string()).describe('low-cost / organic options'),
  prevention: z.array(z.string()),
  askExpert: z.boolean().describe('true when a human expert should confirm (low confidence, severe, or spreading)'),
  urduSummary: z.string().describe('2-3 simple sentences in Urdu script summarising the problem and first step')
});
const DIAGNOSIS_JSON = z.toJSONSchema(DiagnosisSchema);

const DOCTOR_SYSTEM = `You are the Crop Doctor in AgriSphere, an app for farmers in Pakistan. You look at one photo of a crop, leaf, fruit or field and give a careful, practical diagnosis.

Rules:
- Base the diagnosis on what is actually visible. If the photo is blurry, too far away, or not a plant, say so (isPlantPhoto=false or confidence=low) and explain what photo to take instead in the symptoms list.
- Prefer common problems in Pakistan (rusts, blights, leaf spots, aphids, whitefly, pink bollworm, stem borer, nutrient deficiencies, heat / frost / water stress).
- Treatment: give active ingredients (not only brand names) and typical doses per acre, and include safety: read the label, protective clothing, pre-harvest interval.
- Be honest about uncertainty. Set askExpert=true when confidence is low, severity is severe, or the problem can spread quickly.
- Keep every list item short (one sentence).
- Answer ONLY with a JSON object with exactly these fields: isPlantPhoto, crop, healthy, problem, problemType, confidence, severity, symptoms, cause, treatment, organic, prevention, askExpert, urduSummary.`;

// small models sometimes return slightly different JSON: keep what is usable, fill the rest
function normalise(raw, crop) {
  let o = raw;
  if (typeof raw === 'string') {
    const m = raw.match(/\{[\s\S]*\}/);
    try { o = m ? JSON.parse(m[0]) : null; } catch (e) { o = null; }
  }
  if (!o || typeof o !== 'object') return null;
  const ok = DiagnosisSchema.safeParse(o);
  if (ok.success) return ok.data;
  const list = (v) => (Array.isArray(v) ? v.map(String).filter(Boolean).slice(0, 8) : v ? [String(v)] : []);
  const pick = (v, allowed, d) => (allowed.includes(String(v).toLowerCase()) ? String(v).toLowerCase() : d);
  return {
    isPlantPhoto: o.isPlantPhoto !== false,
    crop: String(o.crop || crop || 'Unknown'),
    healthy: o.healthy === true,
    problem: String(o.problem || 'Unclear from the photo'),
    problemType: pick(o.problemType, ['disease', 'pest', 'nutrient', 'water', 'weather', 'healthy', 'unknown'], 'unknown'),
    confidence: pick(o.confidence, ['low', 'medium', 'high'], 'low'),
    severity: pick(o.severity, ['none', 'mild', 'moderate', 'severe'], 'mild'),
    symptoms: list(o.symptoms),
    cause: String(o.cause || ''),
    treatment: list(o.treatment),
    organic: list(o.organic),
    prevention: list(o.prevention),
    askExpert: o.askExpert !== false,
    urduSummary: String(o.urduSummary || '')
  };
}

router.post('/ai/diagnose', doctorLimit, h(async (req, res) => {
  needUser(req);
  const b = req.body || {};
  const m = /^data:(image\/(?:png|jpe?g|webp));base64,(.+)$/i.exec(String(b.image || ''));
  if (!m) throw bad('Attach a clear photo of the crop (PNG or JPG)');
  const mediaType = m[1].toLowerCase().replace('jpg', 'jpeg');
  const crop = String(b.crop || '').trim().slice(0, 40);
  const note = String(b.note || '').trim().slice(0, 300);
  const photo = saveImage(b.image, 'crops', 'doctor'); // also validates type and size
  const ask = `Crop (from the farmer): ${crop || 'not given'}\nFarmer's note: ${note || 'none'}\nDiagnose this photo.`;

  let p = await provider();
  let result = null;
  try {
    if (p === 'ollama') result = normalise(await ollamaChat([{ role: 'system', content: DOCTOR_SYSTEM }, { role: 'user', content: ask }], { images: [m[2]], schema: DIAGNOSIS_JSON }), crop);
    else if (p === 'groq') result = normalise(await groqChat([{ role: 'system', content: DOCTOR_SYSTEM }, { role: 'user', content: ask + '\nReply in JSON.' }], { imageDataUrl: b.image, json: true }), crop);
    else if (p === 'anthropic') result = await claudeDiagnose(DOCTOR_SYSTEM, mediaType, m[2], ask);
  } catch (e) {
    if (e.status === 429) throw e;
    console.warn('AI provider failed, using built-in guide:', safe(e.message));
    ollamaOk = null;
  }
  if (!result) {
    p = 'offline';
    result = kb.offlineDiagnosis(crop);
  }
  const d = await Diagnosis.create({ user: req.me.id, crop: crop || result.crop, note, photo, result, source: p });
  res.status(201).json(out(d));
}));

router.get('/ai/diagnoses', h(async (req, res) => {
  needUser(req);
  const list = await Diagnosis.find({ user: req.me.id }).sort({ createdAt: -1 }).limit(30);
  res.json({ items: list.map(out) });
}));

router.get('/ai/status', h(async (req, res) => {
  const p = await provider();
  res.json({ provider: p, model: p === 'ollama' ? OLLAMA_MODEL() : p === 'groq' ? GROQ_MODEL() : p === 'anthropic' ? CLAUDE_MODEL : 'built-in guide' });
}));

router.provider = provider; // used by /api/health
module.exports = router;
