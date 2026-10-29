const fs = require('fs');
const path = require('path');
const db = require('../config/database');
const { importMasterCatalog } = require('../services/itemService');

/**
 * Universal TXT Importer untuk Blade Ball
 * Penggunaan:
 *   node src/scripts/import_txt.js "path/ke/file_sword.txt" Sword
 *   node src/scripts/import_txt.js "path/ke/file_explo.txt" Explosion
 */

function cleanItemName(rawLine) {
  if (!rawLine) return '';
  let line = rawLine.trim();

  // Buang komentar Lua (-- ...)
  if (line.startsWith('--')) return '';

  // Buang format Lua index: [1] = "Name", atau ["Name"]
  line = line.replace(/^\[\d+\]\s*=\s*/, '');
  line = line.replace(/^\d+[\.\)]\s*/, ''); // Buang nomor baris: "1. Dragon Blade"
  line = line.replace(/^-\s*/, ''); // Buang bullet point: "- Dragon Blade"

  // Buang tanda petik dan koma di awal/akhir
  line = line.replace(/^["'`\s]+|["'`,;\s]+$/g, '');

  return line.trim();
}

function parseTxtContent(content, defaultCategory = 'Sword') {
  const items = [];
  const lines = content.split(/\r?\n/);

  for (const rawLine of lines) {
    const cleaned = cleanItemName(rawLine);
    if (!cleaned) continue;

    // Abaikan baris pembuka/penutup tabel lua seperti "return {" atau "}"
    if (/^(return\s*\{|\{|\}|\);?)$/i.test(cleaned)) continue;
    if (cleaned.length < 2) continue;

    items.push({
      name: cleaned,
      category: defaultCategory,
      rarity: 'Common'
    });
  }

  return items;
}

function runImport() {
  const filePath = process.argv[2];
  let category = process.argv[3] || 'Sword';

  // Deteksi otomatis jika user menulis "explo" di nama file atau argumen
  if (/explo/i.test(category) || (filePath && /explo/i.test(filePath))) {
    category = 'Explosion';
  } else if (/emote/i.test(category) || (filePath && /emote/i.test(filePath))) {
    category = 'Emote';
  } else {
    category = 'Sword';
  }

  if (!filePath) {
    console.log(`
========================================================================
⚔️  PANDUAN IMPOR FILE TXT BLADE BALL
========================================================================
Format Perintah:
  node src/scripts/import_txt.js "<path_file.txt>" [Sword | Explosion | Emote]

Contoh:
  node src/scripts/import_txt.js "C:\\Users\\FAUZAN\\Downloads\\workspace\\katalog_master_index_swords.txt" Sword
  node src/scripts/import_txt.js "C:\\Users\\FAUZAN\\Downloads\\workspace\\master_all_explosions.txt" Explosion
========================================================================
`);
    return;
  }

  const resolvedPath = path.resolve(filePath);
  if (!fs.existsSync(resolvedPath)) {
    console.error(`❌ File tidak ditemukan di: ${resolvedPath}`);
    return;
  }

  console.log(`[Import] Membaca berkas: ${resolvedPath}`);
  console.log(`[Import] Kategori yang ditentukan: ${category}`);

  const rawContent = fs.readFileSync(resolvedPath, 'utf8');

  // Coba cek apakah isi file sebenarnya adalah JSON
  let items = [];
  try {
    const parsedJson = JSON.parse(rawContent);
    if (Array.isArray(parsedJson)) {
      items = parsedJson.map(i => {
        if (typeof i === 'string') return { name: cleanItemName(i), category };
        return { name: cleanItemName(i.name || i.itemName), category: i.category || category };
      });
    }
  } catch (e) {
    // Jika bukan JSON, parse line-by-line TXT
    items = parseTxtContent(rawContent, category);
  }

  if (items.length === 0) {
    console.warn(`⚠️ Tidak ditemukan nama item valid di dalam file tersebut.`);
    return;
  }

  console.log(`[Import] Terdeteksi ${items.length} item. Memasukkan ke SQLite Database...`);

  const startTime = Date.now();
  const count = importMasterCatalog(items);
  const duration = Date.now() - startTime;

  console.log(`
========================================================================
🎉 BERHASIL MENGIMPOR DATA MASTER!
Total Item Dimasukkan/Diperbarui: ${count} item (${category})
Waktu Eksekusi: ${duration} ms
Status: Tersimpan di database SQLite (data/trading_bb.db)
========================================================================
`);
}

runImport();
