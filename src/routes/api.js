const express = require('express');
const router = express.Router();
const itemService = require('../services/itemService');
const { parseNumber } = require('../services/analyzer');

// Middleware Opsional: Validasi API Key (hanya memproteksi penulisan feed dari scraper luar)
function verifyApiKey(req, res, next) {
  const configuredKey = process.env.API_KEY;
  if (!configuredKey) return next(); // Jika tidak dikonfigurasi, lewati

  // Izinkan request publik: semua GET dan kalkulator trade
  if (req.method === 'GET' || req.path === '/trade/evaluate') {
    return next();
  }

  const providedKey = req.headers['x-api-key'] || req.query.api_key;
  if (providedKey && providedKey === configuredKey) {
    return next();
  }

  return res.status(401).json({
    success: false,
    error: 'Akses ditolak: Header x-api-key tidak valid atau tidak disertakan.'
  });
}

router.use(verifyApiKey);

/**
 * POST /api/booth-feed
 * Menerima payload batch atau satuan dari script Lua Trade Plaza (Solara/Delta)
 */
router.post('/booth-feed', (req, res) => {
  try {
    const payload = req.body;
    let itemsToProcess = [];

    if (Array.isArray(payload)) {
      itemsToProcess = payload;
    } else if (payload && Array.isArray(payload.items)) {
      itemsToProcess = payload.items;
    } else if (payload && (payload.name || payload.itemName)) {
      itemsToProcess = [payload];
    } else {
      return res.status(400).json({
        success: false,
        error: 'Format payload tidak valid. Harap kirimkan array item atau object dengan properti items.'
      });
    }

    if (itemsToProcess.length === 0) {
      return res.json({ success: true, message: 'Tidak ada item untuk diproses', processed: 0 });
    }

    const results = itemService.processBatchBoothFeed(itemsToProcess);

    return res.json({
      success: true,
      message: `Berhasil memproses ${results.length} item dari booth feed.`,
      count: results.length,
      data: results
    });
  } catch (error) {
    console.error('[API Error /booth-feed]:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Terjadi kesalahan internal server saat memproses booth feed.'
    });
  }
});

/**
 * POST /api/update-item
 * Update spesifik 1 item (manual atau dari scraper fokus)
 */
router.post('/update-item', (req, res) => {
  try {
    const itemData = req.body;
    if (!itemData || (!itemData.name && !itemData.itemName)) {
      return res.status(400).json({
        success: false,
        error: 'Data item dan nama (name/itemName) wajib diisi.'
      });
    }

    const result = itemService.processSingleItem(itemData);

    return res.json({
      success: true,
      message: `Item ${result.name} berhasil diperbarui. Status: ${result.status}`,
      data: result
    });
  } catch (error) {
    console.error('[API Error /update-item]:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'Gagal memperbarui item.'
    });
  }
});

/**
 * GET /api/items
 * Pencarian, Autocomplete A-Z, & Filter berdasarkan Kategori / Status
 */
router.get('/items', (req, res) => {
  try {
    const { search, category, status, limit, page } = req.query;
    const result = itemService.searchItems({
      search,
      category,
      status,
      limit,
      page
    });

    return res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('[API Error /items]:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/items/:name
 * Mendapatkan detail lengkap item, riwayat transaksi, & breakdown Clean RAP
 */
router.get('/items/:name', (req, res) => {
  try {
    const { name } = req.params;
    const item = itemService.getItemDetails(name);

    if (!item) {
      return res.status(404).json({
        success: false,
        error: `Item "${name}" tidak ditemukan di database.`
      });
    }

    return res.json({
      success: true,
      data: item
    });
  } catch (error) {
    console.error('[API Error /items/:name]:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * GET /api/market/stats
 * Statistik umum pasar (total item, item projected, item nuked)
 */
router.get('/market/stats', (req, res) => {
  try {
    const stats = itemService.getMarketStatistics();
    return res.json({
      success: true,
      data: stats
    });
  } catch (error) {
    console.error('[API Error /market/stats]:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

/**
 * POST /api/trade/evaluate
 * Kalkulator Trade Real-Time: Membandingkan 'My Items' vs 'Their Items'
 * Mengkalkulasi selisih nominal RAP vs Clean RAP dan memberi peringatan scam projected
 */
router.post('/trade/evaluate', (req, res) => {
  try {
    const { myItems = [], theirItems = [] } = req.body;

    const evaluateSide = (itemsList) => {
      let totalOfficialRap = 0;
      let totalCleanRap = 0;
      const analyzedList = [];
      const warnings = [];

      itemsList.forEach((entry) => {
        const itemName = typeof entry === 'string' ? entry : entry.name;
        const count = typeof entry === 'object' && entry.count ? parseInt(entry.count, 10) : 1;
        const item = itemService.getItemDetails(itemName);

        if (item) {
          const offRap = (item.current_rap || 0) * count;
          const clnRap = (item.clean_rap || item.current_rap || 0) * count;

          totalOfficialRap += offRap;
          totalCleanRap += clnRap;

          if (item.status === 'PROJECTED') {
            warnings.push(`⚠️ PERINGATAN: "${item.name}" adalah item PROJECTED! RAP nominal ${item.current_rap.toLocaleString()} padahal nilai riil hanya ${item.clean_rap.toLocaleString()}`);
          } else if (item.status === 'BOOSTED') {
            warnings.push(`⚡ PERINGATAN: "${item.name}" berstatus BOOSTED.`);
          } else if (item.status === 'NUKED') {
            warnings.push(`💥 INFO: "${item.name}" berstatus NUKED (RAP nominal anjlok).`);
          }

          analyzedList.push({
            name: item.name,
            count,
            category: item.category,
            currentRap: item.current_rap,
            cleanRap: item.clean_rap,
            subtotalOfficialRap: offRap,
            subtotalCleanRap: clnRap,
            status: item.status
          });
        } else {
          analyzedList.push({
            name: itemName,
            count,
            unknown: true,
            currentRap: 0,
            cleanRap: 0,
            status: 'UNKNOWN'
          });
          warnings.push(`❓ Item "${itemName}" belum ada di database.`);
        }
      });

      return {
        totalOfficialRap,
        totalCleanRap,
        items: analyzedList,
        warnings
      };
    };

    const myEvaluation = evaluateSide(myItems);
    const theirEvaluation = evaluateSide(theirItems);

    // Hitung margin keuntungan berdasarkan Clean Value
    const netCleanGain = theirEvaluation.totalCleanRap - myEvaluation.totalCleanRap;
    const netOfficialGain = theirEvaluation.totalOfficialRap - myEvaluation.totalOfficialRap;

    let tradeVerdict = 'FAIR TRADE';
    let recommendation = 'Trade ini berimbang.';

    if (theirEvaluation.warnings.some(w => w.includes('PROJECTED'))) {
      tradeVerdict = 'SCAM / LOSE (PROJECTED DETECTED)';
      recommendation = 'JANGAN TERIMA! Pihak lawan menyertakan item PROJECTED untuk menggelembungkan nilai trade.';
    } else if (netCleanGain > myEvaluation.totalCleanRap * 0.15) {
      tradeVerdict = 'BIG WIN / PROFITABLE';
      recommendation = `Trade sangat menguntungkan! Anda surplus +${netCleanGain.toLocaleString()} Clean RAP.`;
    } else if (netCleanGain > 0) {
      tradeVerdict = 'SLIGHT WIN';
      recommendation = `Trade sedikit menguntungkan (+${netCleanGain.toLocaleString()} Clean RAP).`;
    } else if (netCleanGain < - (myEvaluation.totalCleanRap * 0.15)) {
      tradeVerdict = 'BIG LOSE / UNDERPAY';
      recommendation = `Trade merugikan! Anda defisit ${netCleanGain.toLocaleString()} Clean RAP.`;
    } else if (netCleanGain < 0) {
      tradeVerdict = 'SLIGHT LOSE';
      recommendation = `Trade sedikit rugi (${netCleanGain.toLocaleString()} Clean RAP).`;
    }

    return res.json({
      success: true,
      verdict: tradeVerdict,
      recommendation,
      cleanDifference: netCleanGain,
      officialDifference: netOfficialGain,
      mySide: myEvaluation,
      theirSide: theirEvaluation
    });
  } catch (error) {
    console.error('[API Error /trade/evaluate]:', error);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

module.exports = router;
