const express = require('express');
const cors = require('cors');
require('dotenv').config();

const db = require('./config/database');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
// Mendukung payload besar dari scraper Lua (hingga 10MB)
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logger sederhana untuk monitoring feed masuk
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  if (req.path.startsWith('/api')) {
    console.log(`[${timestamp}] ${req.method} ${req.originalUrl}`);
  }
  next();
});

// Routing API
app.use('/api', apiRoutes);

// Health check & Server Status
app.get('/', (req, res) => {
  res.json({
    project: 'Blade Ball Market & RAP Tracker API',
    status: 'ONLINE',
    version: '1.0.0',
    endpoints: {
      boothFeed: 'POST /api/booth-feed (Menerima batch/single data dari Lua)',
      updateItem: 'POST /api/update-item (Update spesifik item)',
      listItems: 'GET /api/items (Search autocomplete & filter)',
      itemDetails: 'GET /api/items/:name (Detail item & riwayat 5 transaksi)',
      marketStats: 'GET /api/market/stats (Statistik pasar & item projected)',
      tradeCalculator: 'POST /api/trade/evaluate (Evaluasi trade dua sisi)'
    },
    systemTime: new Date().toISOString()
  });
});

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: `Route ${req.method} ${req.url} tidak ditemukan.`
  });
});

// Error Handler
app.use((err, req, res, next) => {
  console.error('[Unhandled Server Error]:', err);
  res.status(500).json({
    success: false,
    error: 'Terjadi kegagalan server.',
    details: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Start Server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`====================================================`);
  console.log(`⚔️  Blade Ball Market Tracker API Server Berjalan!`);
  console.log(`📡 URL Lokal:   http://localhost:${PORT}`);
  console.log(`📱 URL Jaringan: http://0.0.0.0:${PORT} (Bisa diakses dari HP/Emulator)`);
  console.log(`⚡ Siap menerima feed dari Solara / Delta Scraper`);
  console.log(`====================================================`);
});

// Graceful Shutdown
function gracefulShutdown(signal) {
  console.log(`\n[Shutdown] Menerima sinyal ${signal}, menutup koneksi database...`);
  try {
    db.close();
    console.log('[Shutdown] Database SQLite berhasil ditutup.');
  } catch (err) {
    console.error('[Shutdown Error]:', err.message);
  }
  server.close(() => {
    console.log('[Shutdown] HTTP Server dihentikan.');
    process.exit(0);
  });
}

process.on('SIGINT', () => gracefulShutdown('SIGINT'));
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
