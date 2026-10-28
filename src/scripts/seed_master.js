const fs = require('fs');
const path = require('path');
const db = require('../config/database');

/**
 * Script untuk mengimpor daftar master item (Swords, Explosions, Emotes)
 * Penggunaan:
 *   node src/scripts/seed_master.js [path/ke/file_master.json]
 */
function seedMasterCatalog() {
  const customPath = process.argv[2];
  let targetFile = '';

  if (customPath && fs.existsSync(customPath)) {
    targetFile = path.resolve(customPath);
  } else if (fs.existsSync('./data/master_items.json')) {
    targetFile = path.resolve('./data/master_items.json');
  } else if (fs.existsSync('./data/master_swords.json')) {
    targetFile = path.resolve('./data/master_swords.json');
  } else {
    targetFile = path.resolve(__dirname, '../data/sample_master.json');
  }

  console.log(`[Seed] Membaca file master katalog dari: ${targetFile}`);

  const rawData = fs.readFileSync(targetFile, 'utf8');
  let items = [];

  try {
    items = JSON.parse(rawData);
  } catch (err) {
    console.error('[Seed Error] Gagal membaca JSON:', err.message);
    process.exit(1);
  }

  if (!Array.isArray(items)) {
    console.error('[Seed Error] Data harus berupa Array JSON [{ name: "..." }, ...]');
    process.exit(1);
  }

  console.log(`[Seed] Ditemukan ${items.length} item. Memulai import ke SQLite...`);

  const insertStmt = db.prepare(`
    INSERT INTO items (name, category, rarity, current_rap, clean_rap, status)
    VALUES (@name, @category, @rarity, @current_rap, @clean_rap, 'NORMAL')
    ON CONFLICT(name) DO UPDATE SET
      category = COALESCE(excluded.category, items.category),
      rarity = COALESCE(excluded.rarity, items.rarity)
  `);

  const startTime = Date.now();

  const insertAll = db.transaction((itemList) => {
    let count = 0;
    for (const item of itemList) {
      // Menangani format array string ["Item A", "Item B"] atau array objek [{ name: "Item A" }]
      const itemName = typeof item === 'string' ? item.trim() : (item.name || item.itemName || '').trim();
      if (!itemName) continue;

      const category = (typeof item === 'object' && item.category) ? item.category : 'Sword';
      const rarity = (typeof item === 'object' && item.rarity) ? item.rarity : 'Common';
      const baseRap = (typeof item === 'object' && (item.baseRap || item.rap || item.currentRap)) ? parseInt(item.baseRap || item.rap || item.currentRap, 10) : 0;

      insertStmt.run({
        name: itemName,
        category,
        rarity,
        current_rap: baseRap,
        clean_rap: baseRap
      });
      count++;
    }
    return count;
  });

  const insertedCount = insertAll(items);
  const duration = Date.now() - startTime;

  console.log(`✅ [Seed Selesai] Berhasil menyimpan/memperbarui ${insertedCount} item dalam ${duration}ms!`);
}

seedMasterCatalog();
