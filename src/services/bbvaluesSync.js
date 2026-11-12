const fs = require('fs');
const path = require('path');
const https = require('https');

const BBV_URL = 'https://bbvalues.uk/api/items';
const OUTPUT_JSON = path.join(__dirname, '..', 'data', 'rap_database.json');
const DB_PATH = path.join(__dirname, '..', '..', 'data', 'trading_bb.db');

async function fetchBbValues() {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'x-bbv-handshake': 'v1-secure-request',
        'Accept': 'application/json',
        'Referer': 'https://bbvalues.uk/values/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      }
    };

    https.get(BBV_URL, options, (res) => {
      if (res.statusCode !== 200) {
        return reject(new Error(`HTTP ${res.statusCode}: Failed to fetch bbvalues.uk`));
      }
      let raw = '';
      res.on('data', chunk => raw += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(raw);
          resolve(json);
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject);
  });
}

async function sync() {
  console.log('[BBValues Sync] Mengambil data terbaru dari bbvalues.uk/values/...');
  let items;

  try {
    items = await fetchBbValues();
    console.log(`[BBValues Sync] Berhasil download online: ${items.length} item.`);
  } catch (netErr) {
    console.warn('[BBValues Sync] Gagal download online:', netErr.message);
    const localScratch = path.join(__dirname, '..', '..', 'scratch_bbv_items.json');
    if (fs.existsSync(localScratch)) {
      try {
        items = JSON.parse(fs.readFileSync(localScratch, 'utf8'));
        console.log(`[BBValues Sync] Membaca dari cache lokal: ${items.length} item.`);
      } catch (_) {}
    }
  }

  if (!items || !Array.isArray(items)) {
    throw new Error('Tidak ada data item yang dapat diproses!');
  }

  const catMap = {};

  for (const item of items) {
    const name = item.n;
    if (!name || typeof name !== 'string') continue;
    
    // Gunakan currentPrice (item.p) atau avgPrice (item.a) jika p = 0
    const value = Number(item.p) > 0 ? Number(item.p) : (Number(item.a) || 0);
    if (value <= 0) continue;

    // Simpan dengan key normalized
    const cleanKey = name.toLowerCase().replace(/\s+/g, ' ').trim();
    const category = (item.c || 'Sword').trim();

    if (!catMap[cleanKey]) catMap[cleanKey] = {};
    catMap[cleanKey][category] = value;
  }

  const rapDatabase = {};
  let validCount = 0;

  for (const [name, cats] of Object.entries(catMap)) {
    const catList = Object.keys(cats);
    if (catList.length === 1) {
      rapDatabase[name] = cats[catList[0]];
    } else {
      rapDatabase[name] = cats;
    }

    // Simpan key eksplisit kategori: "higanbana katana#sword", "higanbana katana#emote"
    for (const [catName, val] of Object.entries(cats)) {
      rapDatabase[`${name}#${catName.toLowerCase()}`] = val;
      validCount++;
    }
  }

  // Tulis ke rap_database.json
  fs.writeFileSync(OUTPUT_JSON, JSON.stringify(rapDatabase, null, 2), 'utf8');
  console.log(`[BBValues Sync] Sukses menyimpan ${validCount} varian item ke ${OUTPUT_JSON}!`);

  // Update ke database SQLite lokal jika ada
  if (fs.existsSync(DB_PATH)) {
    try {
      const Database = require('better-sqlite3');
      const db = new Database(DB_PATH);
      
      const insertOrUpdate = db.prepare(`
        INSERT INTO items (name, category, rarity, current_rap, clean_rap, status)
        VALUES (@name, @category, @rarity, @current_rap, @clean_rap, 'NORMAL')
        ON CONFLICT(name) DO UPDATE SET
          current_rap = excluded.current_rap,
          clean_rap = excluded.clean_rap,
          category = COALESCE(excluded.category, items.category),
          updated_at = CURRENT_TIMESTAMP
      `);

      const updateTx = db.transaction((itemList) => {
        let dbCount = 0;
        for (const it of itemList) {
          const val = Number(it.p) > 0 ? Number(it.p) : (Number(it.a) || 0);
          if (!it.n || val <= 0) continue;
          insertOrUpdate.run({
            name: it.n.trim(),
            category: it.c || 'Sword',
            rarity: it.r || 'Normal',
            current_rap: val,
            clean_rap: val
          });
          dbCount++;
        }
        return dbCount;
      });

      const updated = updateTx(items);
      console.log(`[BBValues Sync] Sukses update ${updated} item di database SQLite lokal!`);
      db.close();
    } catch (dbErr) {
      console.warn(`[BBValues Sync] Gagal update SQLite (abaikan jika tidak kritis):`, dbErr.message);
    }
  }

  return { validCount };
}

if (require.main === module) {
  sync().catch(err => {
    console.error('[BBValues Sync Error]:', err);
    process.exit(1);
  });
}

module.exports = { sync, fetchBbValues };

