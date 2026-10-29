const db = require('../config/database');
const { analyzeItemPrice, evaluateBoothDeal, parseNumber } = require('./analyzer');

// Prepared Statements untuk performa maksimal
const queries = {
  findItemByName: db.prepare(`SELECT * FROM items WHERE name = ? COLLATE NOCASE`),
  
  upsertItem: db.prepare(`
    INSERT INTO items (
      name, category, rarity, current_rap, clean_rap, 
      status, status_reason, last_deal_rating, last_seen_price, 
      sales_sample_count, last_seen_at, updated_at
    ) VALUES (
      @name, @category, @rarity, @current_rap, @clean_rap,
      @status, @status_reason, @last_deal_rating, @last_seen_price,
      @sales_sample_count, datetime('now'), datetime('now')
    )
    ON CONFLICT(name) DO UPDATE SET
      category = COALESCE(excluded.category, items.category),
      rarity = COALESCE(excluded.rarity, items.rarity),
      current_rap = CASE WHEN excluded.current_rap > 0 THEN excluded.current_rap ELSE items.current_rap END,
      clean_rap = excluded.clean_rap,
      status = excluded.status,
      status_reason = excluded.status_reason,
      last_deal_rating = excluded.last_deal_rating,
      last_seen_price = CASE WHEN excluded.last_seen_price > 0 THEN excluded.last_seen_price ELSE items.last_seen_price END,
      sales_sample_count = items.sales_sample_count + excluded.sales_sample_count,
      last_seen_at = datetime('now'),
      updated_at = datetime('now')
  `),

  insertSaleHistory: db.prepare(`
    INSERT INTO sales_history (item_name, price, is_outlier, recorded_at)
    VALUES (?, ?, ?, datetime('now'))
  `),

  getRecentSales: db.prepare(`
    SELECT price, is_outlier, recorded_at 
    FROM sales_history 
    WHERE item_name = ? COLLATE NOCASE
    ORDER BY id DESC LIMIT 10
  `),

  insertBoothSnapshot: db.prepare(`
    INSERT INTO booth_snapshots (item_name, price, seller_name, booth_id, deal_rating, created_at)
    VALUES (?, ?, ?, ?, ?, datetime('now'))
  `),

  getRecentBoothListings: db.prepare(`
    SELECT price, seller_name, booth_id, deal_rating, created_at 
    FROM booth_snapshots 
    WHERE item_name = ? COLLATE NOCASE
    ORDER BY id DESC LIMIT 5
  `),

  searchItems: db.prepare(`
    SELECT * FROM items 
    WHERE (@search IS NULL OR name LIKE '%' || @search || '%')
      AND (@category IS NULL OR category = @category COLLATE NOCASE)
      AND (@status IS NULL OR status = @status COLLATE NOCASE)
    ORDER BY 
      CASE WHEN status = 'PROJECTED' THEN 1 WHEN status = 'BOOSTED' THEN 2 WHEN status = 'NUKED' THEN 3 ELSE 4 END,
      current_rap DESC
    LIMIT @limit OFFSET @offset
  `),

  importMasterStmt: db.prepare(`
    INSERT INTO items (name, category, rarity, current_rap, clean_rap, status)
    VALUES (@name, @category, @rarity, @current_rap, @clean_rap, 'NORMAL')
    ON CONFLICT(name) DO UPDATE SET
      category = COALESCE(excluded.category, items.category),
      rarity = COALESCE(excluded.rarity, items.rarity)
  `),

  countItems: db.prepare(`
    SELECT COUNT(*) as total FROM items 
    WHERE (@search IS NULL OR name LIKE '%' || @search || '%')
      AND (@category IS NULL OR category = @category COLLATE NOCASE)
      AND (@status IS NULL OR status = @status COLLATE NOCASE)
  `),

  getStats: db.prepare(`
    SELECT 
      COUNT(*) as total_items,
      SUM(CASE WHEN status = 'PROJECTED' THEN 1 ELSE 0 END) as projected_count,
      SUM(CASE WHEN status = 'BOOSTED' THEN 1 ELSE 0 END) as boosted_count,
      SUM(CASE WHEN status = 'NUKED' THEN 1 ELSE 0 END) as nuked_count,
      SUM(CASE WHEN status = 'NORMAL' THEN 1 ELSE 0 END) as normal_count,
      SUM(CASE WHEN current_rap > 0 THEN 1 ELSE 0 END) as items_with_rap
    FROM items
  `)
};

/**
 * Memproses 1 item dari feed/payload
 */
function processSingleItem(itemData) {
  const name = String(itemData.name || itemData.itemName || '').trim();
  if (!name) {
    throw new Error('Nama item (name/itemName) wajib disertakan');
  }

  const category = itemData.category || 'Sword';
  const rarity = itemData.rarity || 'Common';
  const incomingRap = parseNumber(itemData.rap || itemData.currentRap || itemData.price || 0);
  const boothPrice = parseNumber(itemData.boothPrice || itemData.listingPrice || 0);
  const rawSales = Array.isArray(itemData.salesHistory || itemData.recentSales) 
    ? (itemData.salesHistory || itemData.recentSales) 
    : [];

  // Ambil record yang sudah ada (jika ada)
  const existingItem = queries.findItemByName.get(name);
  const previousCleanRap = existingItem ? existingItem.clean_rap : 0;

  // Analisis harga & manipulasi
  const analysis = analyzeItemPrice(incomingRap, rawSales, previousCleanRap);

  // Evaluasi jika ini listing di booth
  let dealEvaluation = { dealRating: 'UNKNOWN', verdict: '' };
  if (boothPrice > 0) {
    dealEvaluation = evaluateBoothDeal(boothPrice, analysis.cleanRap, analysis.status);
  }

  // Simpan/Update item
  queries.upsertItem.run({
    name,
    category,
    rarity,
    current_rap: analysis.currentRap,
    clean_rap: analysis.cleanRap,
    status: analysis.status,
    status_reason: analysis.statusReason,
    last_deal_rating: dealEvaluation.dealRating,
    last_seen_price: boothPrice > 0 ? boothPrice : analysis.currentRap,
    sales_sample_count: rawSales.length
  });

  // Catat riwayat penjualan jika ada
  if (analysis.sanitizedSales.length > 0) {
    const outlierSet = new Set(analysis.outlierIndices.map(o => o.index));
    analysis.sanitizedSales.forEach((salePrice, idx) => {
      const isOutlier = outlierSet.has(idx) ? 1 : 0;
      queries.insertSaleHistory.run(name, salePrice, isOutlier);
    });
  }

  // Catat riwayat booth jika ada harga listing
  if (boothPrice > 0) {
    queries.insertBoothSnapshot.run(
      name,
      boothPrice,
      itemData.seller || itemData.sellerName || 'Anonymous',
      itemData.boothId || null,
      dealEvaluation.dealRating
    );
  }

  return {
    name,
    category,
    rarity,
    currentRap: analysis.currentRap,
    cleanRap: analysis.cleanRap,
    status: analysis.status,
    statusReason: analysis.statusReason,
    boothPrice: boothPrice > 0 ? boothPrice : null,
    dealRating: dealEvaluation.dealRating,
    dealVerdict: dealEvaluation.verdict,
    recentSalesRecorded: analysis.sanitizedSales.length
  };
}

/**
 * Batch Process Feed dari Script Lua Trade Plaza (menggunakan SQLite Transaction)
 */
const processBatchBoothFeed = db.transaction((feedItems) => {
  const results = [];
  for (const item of feedItems) {
    try {
      const processed = processSingleItem(item);
      results.push(processed);
    } catch (err) {
      console.error(`[Feed Error] Gagal memproses ${item.name}: ${err.message}`);
    }
  }
  return results;
});

/**
 * Mendapatkan detail item lengkap (termasuk riwayat & analitik)
 */
function getItemDetails(name) {
  const item = queries.findItemByName.get(name);
  if (!item) return null;

  const salesHistory = queries.getRecentSales.all(name);
  const boothListings = queries.getRecentBoothListings.all(name);

  // Kalkulasi rekomendasi trade
  let tradeRecommendation = 'AMAN';
  if (item.status === 'PROJECTED') {
    tradeRecommendation = 'BAHAYA: Jangan terima senilai nominal RAP! Nilai riil hanya sekitar ' + item.clean_rap.toLocaleString();
  } else if (item.status === 'BOOSTED') {
    tradeRecommendation = 'WASPADA: Harga sedang dipompa tinggi di atas tren normal.';
  } else if (item.status === 'NUKED') {
    tradeRecommendation = 'PELUANG / DISTORSI: RAP resmi hancur karena transaksi 1 token, nilai riil barang sekitar ' + item.clean_rap.toLocaleString();
  }

  return {
    ...item,
    tradeRecommendation,
    salesHistory,
    boothListings
  };
}

/**
 * Mencari item dengan filter dan pagination
 */
function searchItems({ search, category, status, limit = 50, page = 1 }) {
  const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200);
  const parsedPage = Math.max(parseInt(page, 10) || 1, 1);
  const offset = (parsedPage - 1) * parsedLimit;

  const params = {
    search: search ? search.trim() : null,
    category: category ? category.trim() : null,
    status: status ? status.trim().toUpperCase() : null,
    limit: parsedLimit,
    offset
  };

  const items = queries.searchItems.all(params);
  const { total } = queries.countItems.get({
    search: params.search,
    category: params.category,
    status: params.status
  });

  return {
    items,
    pagination: {
      total,
      page: parsedPage,
      limit: parsedLimit,
      totalPages: Math.ceil(total / parsedLimit)
    }
  };
}

/**
 * Mendapatkan ringkasan statistik pasar
 */
function getMarketStatistics() {
  const stats = queries.getStats.get();
  
  // Ambil daftar item yang sedang PROJECTED
  const projectedItems = db.prepare(`
    SELECT name, category, current_rap, clean_rap, status_reason 
    FROM items 
    WHERE status = 'PROJECTED' 
    ORDER BY current_rap DESC LIMIT 10
  `).all();

  // Ambil daftar item yang sedang NUKED
  const nukedItems = db.prepare(`
    SELECT name, category, current_rap, clean_rap, status_reason 
    FROM items 
    WHERE status = 'NUKED' 
    ORDER BY clean_rap DESC LIMIT 10
  `).all();

  return {
    ...stats,
    projectedItems,
    nukedItems
  };
}

/**
 * Batch import data master katalog (>1.600 item)
 */
const importMasterCatalog = db.transaction((itemList) => {
  let count = 0;
  for (const item of itemList) {
    const itemName = typeof item === 'string' ? item.trim() : (item.name || item.itemName || '').trim();
    if (!itemName) continue;

    const category = (typeof item === 'object' && item.category) ? item.category : 'Sword';
    const rarity = (typeof item === 'object' && item.rarity) ? item.rarity : 'Common';
    const baseRap = (typeof item === 'object' && (item.baseRap || item.rap || item.currentRap)) 
      ? parseInt(item.baseRap || item.rap || item.currentRap, 10) 
      : 0;

    queries.importMasterStmt.run({
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

module.exports = {
  processSingleItem,
  processBatchBoothFeed,
  getItemDetails,
  searchItems,
  getMarketStatistics,
  importMasterCatalog
};

