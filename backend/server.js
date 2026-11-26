require('dotenv').config();
const http = require('http');
const path = require('path');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const mongoose = require('mongoose');
const { sanitize } = require('./utils/sanitize');

// refuse to start with a missing / weak secret: anyone could forge logins otherwise
if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 16 || /change-me/i.test(process.env.JWT_SECRET)) {
  console.error('JWT_SECRET in backend/.env is missing or too weak. Set it to a long random text (at least 16 characters).');
  process.exit(1);
}
if (!process.env.MONGO_URI) {
  console.error('MONGO_URI is missing in backend/.env');
  process.exit(1);
}

const app = express();
app.set('trust proxy', 1); // correct client IPs behind Render / other hosting proxies (rate limits)
// security headers; images must stay loadable from the web app on another origin
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: false }));
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json({ limit: '8mb' })); // photos / payment screenshots are sent as base64
app.use(sanitize); // blocks NoSQL-injection style input on every route

// payment screenshots are private (served through /api/agri/receipt with a login check)
app.use('/uploads/payments', (req, res) => res.status(403).json({ message: 'Private file' }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), { maxAge: '7d' }));
app.use('/api/agri', require('./routes/agri'));

app.get('/', (req, res) => res.send('AgriSphere API is running'));
// quick check used by the app, the hosting platform and the demo: is the API up and is MongoDB connected?
app.get('/api/health', async (req, res) => res.json({
  ok: true,
  db: ['disconnected', 'connected', 'connecting', 'disconnecting'][mongoose.connection.readyState] || 'unknown',
  ai: await require('./routes/modules/ai').provider(), // ollama | groq | anthropic | offline
  push: !!(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT_JSON),
  time: new Date()
}));
app.use('/api/auth', require('./routes/auth'));

// any error that escaped a route: answer in JSON (the app shows the message) instead of an HTML page
app.use((err, req, res, next) => {
  if (err.type === 'entity.too.large') return res.status(413).json({ message: 'File is too large. Please use a smaller photo.' });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ message: 'Invalid request data' });
  console.error('Unhandled error:', err.message);
  res.status(500).json({ message: 'Something went wrong. Please try again.' });
});
app.use((req, res) => res.status(404).json({ message: 'Not found' }));

process.on('unhandledRejection', (e) => console.error('Unhandled promise rejection:', e && e.message));

const PORT = process.env.PORT || 5000;
const server = http.createServer(app);
require('./utils/realtime').initRealtime(server); // live chat + notifications
let started = false;

// keep trying to reach MongoDB instead of exiting (e.g. if the MongoDB service starts after the API)
async function connect(attempt = 1) {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 8000 });
    console.log('MongoDB connected');
    require('./utils/indexes').ensureIndexes();
    if (!started) {
      started = true;
      server.listen(PORT, '0.0.0.0', () => console.log('API running on port ' + PORT));
    }
  } catch (e) {
    const wait = Math.min(30, attempt * 5);
    console.error(`MongoDB connection failed (${e.message}). Retrying in ${wait}s...`);
    setTimeout(() => connect(attempt + 1), wait * 1000);
  }
}
mongoose.connection.on('disconnected', () => console.warn('MongoDB disconnected - mongoose will reconnect automatically'));
connect();

module.exports = { app };
