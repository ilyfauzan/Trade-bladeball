/**
 * Service Analisis & Deteksi Manipulasi Harga Roblox Blade Ball
 * Menghitung Clean RAP, mendeteksi status PROJECTED, BOOSTED, NUKED, NORMAL,
 * serta mengevaluasi kelayakan beli (underpay / deal rating) pada booth Trade Plaza.
 */

// Sanitasi angka (menangani number, string berkoma, 1.5k, 2m, dll)
function parseNumber(value) {
  if (value === null || value === undefined) return 0;
  if (typeof value === 'number') return Math.max(0, Math.floor(value));

  let str = String(value).trim().toLowerCase().replace(/,/g, '');
  if (str.endsWith('k')) {
    return Math.floor(parseFloat(str) * 1000) || 0;
  }
  if (str.endsWith('m')) {
    return Math.floor(parseFloat(str) * 1000000) || 0;
  }
  return Math.max(0, parseInt(str, 10)) || 0;
}

// Menghitung Median dari array angka
function calculateMedian(arr) {
  if (!arr || arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  if (sorted.length % 2 === 0) {
    return Math.round((sorted[mid - 1] + sorted[mid]) / 2);
  }
  return sorted[mid];
}

/**
 * Menganalisis riwayat transaksi (sales history) & RAP game client
 * @param {number} currentRap - RAP yang terbaca dari game client
 * @param {Array<number>} rawSalesHistory - Riwayat 5 transaksi terakhir dari client
 * @param {number} previousCleanRap - Nilai clean RAP sebelumnya di database (jika ada)
 */
function analyzeItemPrice(currentRap, rawSalesHistory = [], previousCleanRap = 0) {
  const sanitizedCurrentRap = parseNumber(currentRap);
  const sanitizedSales = Array.isArray(rawSalesHistory)
    ? rawSalesHistory.map(parseNumber).filter(n => n >= 0)
    : [];

  let status = 'NORMAL';
  let statusReason = 'Harga pasar stabil dan wajar.';
  let cleanRap = sanitizedCurrentRap;
  const outlierIndices = [];

  // 1. Analisis jika tersedia Sales History
  if (sanitizedSales.length > 0) {
    const median = calculateMedian(sanitizedSales);

    // Tandai transaksi outlier
    const cleanSales = [];
    let hasNukedSale = false;
    let hasProjectedSale = false;

    sanitizedSales.forEach((price, idx) => {
      // Penjualan Nuked: <= 10 (biasanya 1 token/gem transfer) atau jatuh < 0.2 * median
      const isNukedOutlier = (price <= 10 && median > 50) || (median > 0 && price < 0.2 * median);
      
      // Penjualan Boosted/Projected: melonjak > 2.5 * median
      const isProjectedOutlier = median > 0 && price > 2.5 * median;

      if (isNukedOutlier) {
        hasNukedSale = true;
        outlierIndices.push({ index: idx, price, type: 'NUKED_OUTLIER' });
      } else if (isProjectedOutlier) {
        hasProjectedSale = true;
        outlierIndices.push({ index: idx, price, type: 'PROJECTED_OUTLIER' });
      } else {
        cleanSales.push(price);
      }
    });

    // Hitung Clean RAP dari data yang bebas manipulasi
    if (cleanSales.length > 0) {
      const sum = cleanSales.reduce((a, b) => a + b, 0);
      cleanRap = Math.round(sum / cleanSales.length);
    } else if (median > 0) {
      cleanRap = median;
    } else if (previousCleanRap > 0) {
      cleanRap = previousCleanRap;
    }

    // Evaluasi Flag Status berdasarkan riwayat transaksi
    if (hasNukedSale && sanitizedCurrentRap < (cleanRap * 0.4)) {
      status = 'NUKED';
      statusReason = `Terdeteksi penjualan dump/transfer ekstrim (misal 1 token). RAP nominal jatuh jauh di bawah nilai wajar.`;
    }
  } else if (previousCleanRap > 0) {
    cleanRap = previousCleanRap;
  }

  // 2. Evaluasi Rasio Current RAP vs Clean RAP
  if (cleanRap > 0) {
    const ratio = sanitizedCurrentRap / cleanRap;

    if (ratio >= 2.5) {
      status = 'PROJECTED';
      statusReason = `Lonjakan harga ekstrem (${ratio.toFixed(2)}x dari harga normal). Manipulasi pump terdeteksi! Hindari menerima senilai RAP.`;
    } else if (ratio >= 1.45 && status !== 'PROJECTED') {
      status = 'BOOSTED';
      statusReason = `Kenaikan harga tidak wajar (${ratio.toFixed(2)}x dari clean RAP). Waspadai penurunan harga tiba-tiba.`;
    } else if (ratio <= 0.35 && status !== 'PROJECTED') {
      status = 'NUKED';
      statusReason = `RAP resmi turun drastis (${ratio.toFixed(2)}x dari harga normal) akibat transaksi dump buatan.`;
    }
  }

  // Pastikan cleanRap tidak 0 jika currentRap ada
  if (cleanRap <= 0 && sanitizedCurrentRap > 0) {
    cleanRap = sanitizedCurrentRap;
  }

  return {
    currentRap: sanitizedCurrentRap,
    cleanRap,
    status,
    statusReason,
    sanitizedSales,
    outlierIndices
  };
}

/**
 * Evaluasi penawaran booth Trade Plaza (Deal Rating)
 * @param {number} boothPrice - Harga jual di booth
 * @param {number} cleanRap - Harga pasar bersih
 * @param {string} status - Status item (NORMAL, PROJECTED, BOOSTED, NUKED)
 */
function evaluateBoothDeal(boothPrice, cleanRap, status) {
  const price = parseNumber(boothPrice);
  if (!price || !cleanRap || cleanRap <= 0) {
    return {
      dealRating: 'UNKNOWN',
      marginPercent: 0,
      verdict: 'Data harga belum cukup untuk evaluasi.'
    };
  }

  const ratio = price / cleanRap;
  const discountPercent = Math.round((1 - ratio) * 100);

  // Jika item PROJECTED / BOOSTED:
  if (status === 'PROJECTED') {
    return {
      dealRating: 'AVOID_PROJECTED',
      discountPercent,
      verdict: '⚠️ JANGAN BELI! Item ini PROJECTED. Penjual kemungkinan mematok harga diskon dari RAP palsu padahal di atas harga riil.'
    };
  }

  if (status === 'BOOSTED' && ratio > 0.9) {
    return {
      dealRating: 'RISKY',
      discountPercent,
      verdict: '⚠️ RISIKO TINGGI: Item sedang BOOSTED, harga berisiko turun setelah tren manipulasi selesai.'
    };
  }

  // Evaluasi normal
  if (ratio <= 0.65) {
    return {
      dealRating: 'STEAL',
      discountPercent,
      verdict: `🔥 STEAL DEAL! Diskon ${discountPercent}% dari Clean RAP. Sangat layak beli untuk flip/resell!`
    };
  }
  if (ratio <= 0.85) {
    return {
      dealRating: 'UNDERPAY',
      discountPercent,
      verdict: `✨ UNDERPAY (Diskon ${discountPercent}%). Bagus untuk dibeli.`
    };
  }
  if (ratio <= 1.05) {
    return {
      dealRating: 'FAIR',
      discountPercent,
      verdict: `⚖️ FAIR PRICE. Harga sebanding dengan nilai pasar wajar.`
    };
  }

  return {
    dealRating: 'OVERPAY',
    discountPercent,
    verdict: `❌ OVERPAY (+${Math.abs(discountPercent)}%). Harga di atas nilai wajar.`
  };
}

module.exports = {
  parseNumber,
  calculateMedian,
  analyzeItemPrice,
  evaluateBoothDeal
};
