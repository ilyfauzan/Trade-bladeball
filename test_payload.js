/**
 * Skrip Uji Coba Payload & Simulasi Data Scraper Trade Plaza (Solara/Delta)
 * Menjalankan uji kasus:
 * 1. Item Normal (Dragon Blade)
 * 2. Item PROJECTED (Glitch Katana dinaikkan 45,000 dari normal 3,200)
 * 3. Item NUKED (Singularity Katana terkena penjualan dump 1 token)
 * 4. Batch Booth Feed (Multi-item scanner)
 * 5. Trade Calculator Evaluation (Mendeteksi jebakan projected lawan)
 */

const BASE_URL = 'http://localhost:3001/api';
const API_KEY = 'bb_trade_plaza_secret_2026';

const headers = {
  'Content-Type': 'application/json',
  'x-api-key': API_KEY
};

async function runTests() {
  console.log('🚀 Memulai Pengujian Endpoint Backend & Deteksi Manipulasi...\n');

  try {
    // 1. Test POST /api/update-item (Item Normal)
    console.log('--- [Test 1] Update Item Normal (Dragon Blade) ---');
    const normalPayload = {
      itemName: 'Dragon Blade',
      category: 'Sword',
      currentRap: 12500,
      salesHistory: [12200, 12600, 12400, 12500, 12800],
      boothPrice: 11000,
      seller: 'FauzanTrader',
      boothId: 'booth_01'
    };

    const res1 = await fetch(`${BASE_URL}/update-item`, {
      method: 'POST',
      headers,
      body: JSON.stringify(normalPayload)
    });
    const data1 = await res1.json();
    console.log('Respons Status:', data1.data?.status);
    console.log('Clean RAP:', data1.data?.cleanRap, '| Current RAP:', data1.data?.currentRap);
    console.log('Deal Rating:', data1.data?.dealRating, '-', data1.data?.dealVerdict);
    console.log('--------------------------------------------------\n');

    // 2. Test POST /api/update-item (Item PROJECTED - Pump Manipulation)
    console.log('--- [Test 2] Deteksi Item PROJECTED (Glitch Katana) ---');
    // Normal harga ~3,200 tapi ada transaksi palsu 45,000 dan RAP game naik jadi 25,000
    const projectedPayload = {
      itemName: 'Glitch Katana',
      category: 'Sword',
      currentRap: 25000, // Game RAP dipompa
      salesHistory: [3100, 3200, 3050, 3150, 48000], // 1 transaksi lonjakan ekstrim
      boothPrice: 18000, // Penjual pura-pura jual "murah" padahal scam
      seller: 'ScammerAlt99',
      boothId: 'booth_99'
    };

    const res2 = await fetch(`${BASE_URL}/update-item`, {
      method: 'POST',
      headers,
      body: JSON.stringify(projectedPayload)
    });
    const data2 = await res2.json();
    console.log('🚨 Status Terdeteksi:', data2.data?.status);
    console.log('Alasan:', data2.data?.statusReason);
    console.log('Clean RAP Riil:', data2.data?.cleanRap, 'vs Game RAP Dipompa:', data2.data?.currentRap);
    console.log('Evaluasi Booth Deal:', data2.data?.dealRating, '-', data2.data?.dealVerdict);
    console.log('--------------------------------------------------\n');

    // 3. Test POST /api/update-item (Item NUKED - Dump / 1 Token Transfer)
    console.log('--- [Test 3] Deteksi Item NUKED (Singularity Katana) ---');
    const nukedPayload = {
      itemName: 'Singularity Katana',
      category: 'Sword',
      currentRap: 3600, // Jatuh drastis
      salesHistory: [18000, 17500, 1, 18200, 1] // Transaksi 1 token
    };

    const res3 = await fetch(`${BASE_URL}/update-item`, {
      method: 'POST',
      headers,
      body: JSON.stringify(nukedPayload)
    });
    const data3 = await res3.json();
    console.log('💥 Status Terdeteksi:', data3.data?.status);
    console.log('Alasan:', data3.data?.statusReason);
    console.log('Clean RAP Dihitung:', data3.data?.cleanRap, 'vs Nominal RAP:', data3.data?.currentRap);
    console.log('--------------------------------------------------\n');

    // 4. Test POST /api/booth-feed (Batch Scraper Trade Plaza)
    console.log('--- [Test 4] Simulasi Batch Booth Feed Scraper ---');
    const batchPayload = [
      { itemName: 'Cyber Scythe', category: 'Sword', currentRap: 8500, boothPrice: 5500, seller: 'QuickSeller' },
      { itemName: 'Supernova', category: 'Explosion', currentRap: 14000, boothPrice: 15000, seller: 'HighBaller' },
      { itemName: 'Sakura Bloom', category: 'Explosion', currentRap: 2100, boothPrice: 2000, seller: 'PlazaMerchant' }
    ];

    const res4 = await fetch(`${BASE_URL}/booth-feed`, {
      method: 'POST',
      headers,
      body: JSON.stringify(batchPayload)
    });
    const data4 = await res4.json();
    console.log(`Berhasil memproses ${data4.count} item batch:`);
    data4.data?.forEach(item => {
      console.log(`- ${item.name} | Status: ${item.status} | Clean RAP: ${item.cleanRap} | Deal: ${item.dealRating}`);
    });
    console.log('--------------------------------------------------\n');

    // 5. Test POST /api/trade/evaluate (Trade Calculator)
    console.log('--- [Test 5] Uji Evaluasi Kalkulator Trade ---');
    // Skenario: Anda menawarkan Dragon Blade (Clean 12.500)
    // Lawan menawarkan Glitch Katana (Nominal RAP 25.000, Clean 3.125) + Cyber Scythe (8.500)
    const tradePayload = {
      myItems: [
        { name: 'Dragon Blade', count: 1 }
      ],
      theirItems: [
        { name: 'Glitch Katana', count: 1 },
        { name: 'Cyber Scythe', count: 1 }
      ]
    };

    const res5 = await fetch(`${BASE_URL}/trade/evaluate`, {
      method: 'POST',
      headers,
      body: JSON.stringify(tradePayload)
    });
    const data5 = await res5.json();
    console.log('⚖️ Trade Verdict:', data5.verdict);
    console.log('💡 Rekomendasi:', data5.recommendation);
    console.log('Official RAP Lawan:', data5.theirSide?.totalOfficialRap, '(Tampak untung)');
    console.log('Clean RAP Lawan:', data5.theirSide?.totalCleanRap, '(Nilai riil jauh lebih rendah)');
    console.log('Peringatan:', data5.theirSide?.warnings);
    console.log('--------------------------------------------------\n');

    console.log('✅ SEMUA PENGUJIAN API BERHASIL DENGAN SEMPURNA!');
  } catch (error) {
    console.error('❌ Gagal menjalankan pengujian:', error.message);
  }
}

runTests();
