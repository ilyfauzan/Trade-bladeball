const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const dbPath = process.env.DATABASE_PATH || './data/trading_bb.db';
const resolvedDbPath = path.resolve(process.cwd(), dbPath);

// Pastikan folder database ada
const dbDir = path.dirname(resolvedDbPath);
if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(resolvedDbPath);

// Aktifkan WAL (Write-Ahead Logging) untuk performa tinggi & anti-lock saat scraper mengirim data cepat
db.pragma('journal_mode = WAL');
db.pragma('synchronous = NORMAL');

// Inisialisasi Skema Database
function initDatabase() {
  db.exec(`
    -- Tabel Master & Status Item Terkini
    CREATE TABLE IF NOT EXISTS items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT UNIQUE NOT NULL COLLATE NOCASE,
      category TEXT DEFAULT 'Sword',
      rarity TEXT DEFAULT 'Common',
      current_rap INTEGER DEFAULT 0,
      clean_rap INTEGER DEFAULT 0,
      status TEXT DEFAULT 'NORMAL',
      status_reason TEXT DEFAULT 'Market stable',
      last_deal_rating TEXT DEFAULT 'UNKNOWN',
      last_seen_price INTEGER DEFAULT 0,
      sales_sample_count INTEGER DEFAULT 0,
      last_seen_at DATETIME,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    -- Indeks untuk pencarian cepat A-Z & autocomplete
    CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);
    CREATE INDEX IF NOT EXISTS idx_items_category ON items(category);
    CREATE INDEX IF NOT EXISTS idx_items_status ON items(status);

    -- Tabel Riwayat Transaksi (Sales History per item)
    CREATE TABLE IF NOT EXISTS sales_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_name TEXT NOT NULL COLLATE NOCASE,
      price INTEGER NOT NULL,
      is_outlier INTEGER DEFAULT 0,
      recorded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (item_name) REFERENCES items(name) ON DELETE CASCADE
    );

    CREATE INDEX IF NOT EXISTS idx_sales_item ON sales_history(item_name);
    CREATE INDEX IF NOT EXISTS idx_sales_recorded_at ON sales_history(recorded_at);

    -- Tabel Log Listing Booth Trade Plaza
    CREATE TABLE IF NOT EXISTS booth_snapshots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_name TEXT NOT NULL COLLATE NOCASE,
      price INTEGER NOT NULL,
      seller_name TEXT,
      booth_id TEXT,
      deal_rating TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_booth_item ON booth_snapshots(item_name);
  `);

  console.log(`[Database] SQLite siap & terhubung di: ${resolvedDbPath}`);
}

initDatabase();

module.exports = db;
