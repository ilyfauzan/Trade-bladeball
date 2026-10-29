/**
 * BLADE BALL TRADE PLAZA TRACKER - FRONTEND CONTROLLER
 */

// Application State
const state = {
  activeTab: 'tab-calculator',
  myItems: [],
  theirItems: [],
  catalog: {
    search: '',
    category: '',
    status: '',
    page: 1,
    limit: 24,
    totalPages: 1
  },
  stats: null
};

// Utilities
const formatNum = (num) => (num || 0).toLocaleString('en-US');

// Debounce helper
function debounce(fn, delay = 250) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

// ==========================================================================
// INITIALIZATION
// ==========================================================================
document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  initTradeCalculator();
  initCatalog();
  initRadar();
  fetchMarketStats();

  // Periodically refresh market stats
  setInterval(fetchMarketStats, 15000);
});

// Tab Navigation
function initTabs() {
  const tabs = document.querySelectorAll('.nav-tab');
  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      tabs.forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const targetId = tab.dataset.tab;
      document.getElementById(targetId)?.classList.add('active');
      state.activeTab = targetId;

      if (targetId === 'tab-catalog') {
        loadCatalogItems();
      } else if (targetId === 'tab-booths') {
        loadBoothDeals();
      }
    });
  });
}

// Fetch Quick Stats for Header Ticker
async function fetchMarketStats() {
  try {
    const res = await fetch('/api/market/stats');
    const json = await res.json();
    if (json.success && json.data) {
      state.stats = json.data;
      document.getElementById('ticker-total').textContent = formatNum(json.data.total_items);
      document.getElementById('ticker-projected').textContent = formatNum(json.data.projected_count || 0);
      document.getElementById('ticker-nuked').textContent = formatNum(json.data.nuked_count || 0);
      
      const indicator = document.getElementById('status-indicator');
      const statusText = document.getElementById('status-text');
      if (indicator && statusText) {
        indicator.className = 'status-indicator online';
        statusText.textContent = 'Server Online';
      }
    }
  } catch (err) {
    console.warn('[Stats Error]: Server offline atau gangguan koneksi');
    const indicator = document.getElementById('status-indicator');
    const statusText = document.getElementById('status-text');
    if (indicator && statusText) {
      indicator.className = 'status-indicator';
      indicator.style.backgroundColor = '#ef4444';
      indicator.style.boxShadow = '0 0 8px #ef4444';
      statusText.textContent = 'Terputus';
    }
  }
}

// ==========================================================================
// 1. TRADE CALCULATOR CONTROLLER
// ==========================================================================
function initTradeCalculator() {
  setupAutocomplete('my');
  setupAutocomplete('their');

  document.getElementById('btn-clear-my').addEventListener('click', () => {
    state.myItems = [];
    renderTradeList('my');
    evaluateTrade();
  });

  document.getElementById('btn-clear-their').addEventListener('click', () => {
    state.theirItems = [];
    renderTradeList('their');
    evaluateTrade();
  });
}

// Setup Autocomplete for adding items
function setupAutocomplete(side) {
  const input = document.getElementById(`input-search-${side}`);
  const dropdown = document.getElementById(`dropdown-${side}`);

  const doSearch = debounce(async (query) => {
    if (!query || query.trim().length < 1) {
      dropdown.style.display = 'none';
      return;
    }

    try {
      const res = await fetch(`/api/items?search=${encodeURIComponent(query.trim())}&limit=8`);
      const data = await res.json();

      if (data.success && data.items.length > 0) {
        dropdown.innerHTML = data.items.map(item => `
          <div class="dropdown-item" data-name="${item.name}">
            <div>
              <div class="d-title">${item.name}</div>
              <div class="d-meta">${item.category} • ${item.rarity}</div>
            </div>
            <div class="d-rap">
              <span class="status-badge badge-${item.status.toLowerCase()}">${item.status}</span>
              <div style="font-size: 0.75rem; color: #94a3b8; margin-top: 2px;">
                Clean: ${formatNum(item.clean_rap)}
              </div>
            </div>
          </div>
        `).join('');

        dropdown.style.display = 'block';

        dropdown.querySelectorAll('.dropdown-item').forEach(el => {
          el.addEventListener('click', () => {
            const itemName = el.dataset.name;
            const selectedItem = data.items.find(i => i.name === itemName);
            if (selectedItem) {
              addItemToTrade(side, selectedItem);
            }
            input.value = '';
            dropdown.style.display = 'none';
          });
        });
      } else {
        dropdown.innerHTML = `<div style="padding: 12px; text-align: center; color: #64748b; font-size: 0.85rem;">Item tidak ditemukan</div>`;
        dropdown.style.display = 'block';
      }
    } catch (e) {
      console.error(e);
    }
  }, 200);

  input.addEventListener('input', (e) => doSearch(e.target.value));

  // Close dropdown on outside click
  document.addEventListener('click', (e) => {
    if (!input.contains(e.target) && !dropdown.contains(e.target)) {
      dropdown.style.display = 'none';
    }
  });
}

// Add Item to a Trade Side
function addItemToTrade(side, item) {
  const list = side === 'my' ? state.myItems : state.theirItems;
  const existing = list.find(i => i.name.toLowerCase() === item.name.toLowerCase());

  if (existing) {
    existing.count += 1;
  } else {
    list.push({
      name: item.name,
      category: item.category,
      rarity: item.rarity,
      cleanRap: item.clean_rap,
      currentRap: item.current_rap,
      status: item.status,
      count: 1
    });
  }

  renderTradeList(side);
  evaluateTrade();
}

// Render Trade Side List
function renderTradeList(side) {
  const list = side === 'my' ? state.myItems : state.theirItems;
  const container = document.getElementById(`list-${side}-items`);

  if (list.length === 0) {
    container.innerHTML = `
      <div class="empty-state">
        <p>Belum ada item ditambahkan</p>
        <small>${side === 'my' ? 'Gunakan bilah cari di atas untuk memilih pedang Anda' : 'Cari item tawaran lawan untuk mengecek status projected'}</small>
      </div>
    `;
    updateTotals(side, 0, 0);
    return;
  }

  let totalClean = 0;
  let totalOff = 0;

  container.innerHTML = list.map((item, index) => {
    const subClean = item.cleanRap * item.count;
    const subOff = item.currentRap * item.count;
    totalClean += subClean;
    totalOff += subOff;

    return `
      <div class="trade-item-row">
        <div class="trade-item-info">
          <div class="item-name-tag">
            <span>${item.name}</span>
            <span class="status-badge badge-${item.status.toLowerCase()}">${item.status}</span>
          </div>
          <div class="item-rap-details">
            Clean: <strong>${formatNum(item.cleanRap)}</strong> | RAP: ${formatNum(item.currentRap)}
          </div>
        </div>
        <div class="trade-item-actions">
          <div class="qty-control">
            <button class="btn-qty" onclick="changeTradeQty('${side}', ${index}, -1)">-</button>
            <span class="qty-val">${item.count}</span>
            <button class="btn-qty" onclick="changeTradeQty('${side}', ${index}, 1)">+</button>
          </div>
          <button class="btn-remove-item" onclick="removeTradeItem('${side}', ${index})" title="Hapus">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
      </div>
    `;
  }).join('');

  updateTotals(side, totalClean, totalOff);
}

// Update Footer Subtotals
function updateTotals(side, clean, official) {
  document.getElementById(`total-clean-${side}`).textContent = formatNum(clean);
  document.getElementById(`total-off-${side}`).textContent = formatNum(official);
}

// Change Quantity
window.changeTradeQty = function(side, index, delta) {
  const list = side === 'my' ? state.myItems : state.theirItems;
  if (!list[index]) return;

  list[index].count += delta;
  if (list[index].count <= 0) {
    list.splice(index, 1);
  }
  renderTradeList(side);
  evaluateTrade();
};

// Remove Item
window.removeTradeItem = function(side, index) {
  const list = side === 'my' ? state.myItems : state.theirItems;
  if (!list[index]) return;

  list.splice(index, 1);
  renderTradeList(side);
  evaluateTrade();
};

// Evaluate Trade via Backend API
async function evaluateTrade() {
  const banner = document.getElementById('verdict-banner');
  const warningsContainer = document.getElementById('trade-warnings-container');

  if (state.myItems.length === 0 && state.theirItems.length === 0) {
    banner.style.display = 'none';
    warningsContainer.style.display = 'none';
    return;
  }

  try {
    const payload = {
      myItems: state.myItems.map(i => ({ name: i.name, count: i.count })),
      theirItems: state.theirItems.map(i => ({ name: i.name, count: i.count }))
    };

    const res = await fetch('/api/trade/evaluate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const result = await res.json();

    if (!result.success) return;

    banner.style.display = 'flex';

    // Reset styles
    banner.className = 'verdict-banner';

    const titleEl = document.getElementById('verdict-title');
    const descEl = document.getElementById('verdict-desc');
    const iconEl = document.getElementById('verdict-icon');

    const cleanDiffEl = document.getElementById('metric-clean-diff');
    const offDiffEl = document.getElementById('metric-off-diff');

    const cleanGain = result.cleanDifference;
    cleanDiffEl.textContent = (cleanGain >= 0 ? '+' : '') + formatNum(cleanGain);
    cleanDiffEl.style.color = cleanGain > 0 ? '#10b981' : (cleanGain < 0 ? '#f43f5e' : '#cbd5e1');

    const offGain = result.officialDifference;
    offDiffEl.textContent = (offGain >= 0 ? '+' : '') + formatNum(offGain);

    titleEl.textContent = result.verdict;
    descEl.textContent = result.recommendation;

    if (result.verdict.includes('SCAM') || result.verdict.includes('PROJECTED')) {
      banner.classList.add('verdict-scam');
      iconEl.textContent = '🚨';
    } else if (result.verdict.includes('WIN')) {
      banner.classList.add('verdict-win');
      iconEl.textContent = '🔥';
    } else if (result.verdict.includes('LOSE')) {
      banner.classList.add('verdict-lose');
      iconEl.textContent = '❌';
    } else {
      iconEl.textContent = '⚖️';
    }

    // Display Warnings
    const allWarnings = [
      ...(result.mySide?.warnings || []),
      ...(result.theirSide?.warnings || [])
    ];

    if (allWarnings.length > 0) {
      warningsContainer.innerHTML = allWarnings.map(w => `
        <div class="warning-item">${w}</div>
      `).join('');
      warningsContainer.style.display = 'flex';
    } else {
      warningsContainer.style.display = 'none';
    }

  } catch (err) {
    console.error('[Evaluation Error]:', err);
  }
}

// ==========================================================================
// 2. CATALOG & SEARCH CONTROLLER
// ==========================================================================
function initCatalog() {
  const searchInput = document.getElementById('catalog-search-input');
  const clearBtn = document.getElementById('catalog-search-clear');
  const triggerImportBtn = document.getElementById('btn-trigger-import');
  const importFileInput = document.getElementById('input-import-file');

  // File Import Handler
  if (triggerImportBtn && importFileInput) {
    triggerImportBtn.addEventListener('click', () => {
      importFileInput.click();
    });

    importFileInput.addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;

      const reader = new FileReader();
      reader.onload = async (event) => {
        try {
          const json = JSON.parse(event.target.result);
          triggerImportBtn.disabled = true;
          triggerImportBtn.innerHTML = `<span>Mengunggah...</span>`;

          const res = await fetch('/api/import-master', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(json)
          });
          const result = await res.json();

          if (result.success) {
            alert(`🎉 Berhasil mengimpor ${result.count.toLocaleString()} item ke katalog master!`);
            fetchMarketStats();
            loadCatalogItems();
          } else {
            alert(`❌ Gagal: ${result.error}`);
          }
        } catch (parseErr) {
          alert(`❌ Format file tidak valid! Pastikan file adalah format JSON.`);
        } finally {
          triggerImportBtn.disabled = false;
          triggerImportBtn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="import-icon">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="17 8 12 3 7 8"></polyline>
              <line x1="12" y1="3" x2="12" y2="15"></line>
            </svg>
            <span>Impor JSON Master</span>
          `;
          importFileInput.value = '';
        }
      };
      reader.readAsText(file);
    });
  }

  const onSearch = debounce((val) => {
    state.catalog.search = val.trim();
    state.catalog.page = 1;
    clearBtn.style.display = state.catalog.search ? 'block' : 'none';
    loadCatalogItems();
  }, 250);

  searchInput.addEventListener('input', (e) => onSearch(e.target.value));
  clearBtn.addEventListener('click', () => {
    searchInput.value = '';
    state.catalog.search = '';
    state.catalog.page = 1;
    clearBtn.style.display = 'none';
    loadCatalogItems();
  });

  // Category filter pills
  document.querySelectorAll('#category-pills .pill').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#category-pills .pill').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.catalog.category = btn.dataset.cat;
      state.catalog.page = 1;
      loadCatalogItems();
    });
  });

  // Status filter pills
  document.querySelectorAll('#status-pills .pill').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#status-pills .pill').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      state.catalog.status = btn.dataset.status;
      state.catalog.page = 1;
      loadCatalogItems();
    });
  });

  // Pagination buttons
  document.getElementById('btn-prev-page').addEventListener('click', () => {
    if (state.catalog.page > 1) {
      state.catalog.page -= 1;
      loadCatalogItems();
    }
  });

  document.getElementById('btn-next-page').addEventListener('click', () => {
    if (state.catalog.page < state.catalog.totalPages) {
      state.catalog.page += 1;
      loadCatalogItems();
    }
  });

  // Modal Close
  document.getElementById('btn-close-modal').addEventListener('click', () => {
    document.getElementById('item-modal').style.display = 'none';
  });
  document.getElementById('item-modal').addEventListener('click', (e) => {
    if (e.target.id === 'item-modal') {
      document.getElementById('item-modal').style.display = 'none';
    }
  });
}

// Load items from API
async function loadCatalogItems() {
  const grid = document.getElementById('catalog-items-grid');
  grid.innerHTML = `<div class="loading-spinner">Memuat data item...</div>`;

  const { search, category, status, page, limit } = state.catalog;
  const params = new URLSearchParams({ page, limit });
  if (search) params.append('search', search);
  if (category) params.append('category', category);
  if (status) params.append('status', status);

  try {
    const res = await fetch(`/api/items?${params.toString()}`);
    const data = await res.json();

    if (!data.success || data.items.length === 0) {
      grid.innerHTML = `
        <div class="empty-state" style="grid-column: 1 / -1; padding: 4rem 1rem;">
          <p>Tidak ada item yang cocok dengan pencarian.</p>
          <small>Coba gunakan kata kunci lain atau reset filter Anda.</small>
        </div>
      `;
      document.getElementById('pagination-bar').style.display = 'none';
      return;
    }

    state.catalog.totalPages = data.pagination.totalPages;

    grid.innerHTML = data.items.map(item => {
      const isProjected = item.status === 'PROJECTED';
      return `
        <div class="item-card ${isProjected ? 'is-projected' : ''}">
          <div>
            <div class="card-top">
              <div>
                <h4 class="card-item-name">${item.name}</h4>
                <div class="card-category-badge">${item.category} • ${item.rarity}</div>
              </div>
              <span class="status-badge badge-${item.status.toLowerCase()}">${item.status}</span>
            </div>

            <div class="card-rap-stats">
              <div class="rap-stat-line">
                <span class="stat-label">Clean RAP (Nilai Riil):</span>
                <span class="stat-val highlight-cyan">${formatNum(item.clean_rap)}</span>
              </div>
              <div class="rap-stat-line">
                <span class="stat-label">Official RAP (Nominal):</span>
                <span class="stat-val">${formatNum(item.current_rap)}</span>
              </div>
            </div>
          </div>

          <div class="card-actions">
            <button class="btn-card-action" onclick="addFromCatalog('my', '${escapeJs(item.name)}')">
              + Sisi Saya
            </button>
            <button class="btn-card-action" onclick="addFromCatalog('their', '${escapeJs(item.name)}')">
              + Sisi Lawan
            </button>
            <button class="btn-card-details" onclick="openItemDetail('${escapeJs(item.name)}')">
              🔍 Detail & Riwayat Transaksi
            </button>
          </div>
        </div>
      `;
    }).join('');

    // Update Pagination
    const paginationBar = document.getElementById('pagination-bar');
    paginationBar.style.display = 'flex';
    document.getElementById('page-info').textContent = `Halaman ${data.pagination.page} dari ${data.pagination.totalPages || 1}`;
    document.getElementById('btn-prev-page').disabled = data.pagination.page <= 1;
    document.getElementById('btn-next-page').disabled = data.pagination.page >= data.pagination.totalPages;

  } catch (err) {
    console.error(err);
    grid.innerHTML = `<div class="empty-state" style="grid-column: 1 / -1;">Gagal memuat data dari server.</div>`;
  }
}

function escapeJs(str) {
  return (str || '').replace(/'/g, "\\'");
}

// Add item to trade calculator directly from catalog card
window.addFromCatalog = async function(side, itemName) {
  try {
    const res = await fetch(`/api/items/${encodeURIComponent(itemName)}`);
    const data = await res.json();
    if (data.success && data.data) {
      addItemToTrade(side, data.data);
      // Switch to calculator tab with toast feedback
      document.getElementById('btn-tab-calc').click();
    }
  } catch (e) {
    console.error(e);
  }
};

// Open Item Detail Modal
window.openItemDetail = async function(itemName) {
  const modal = document.getElementById('item-modal');
  const body = document.getElementById('modal-body-content');

  body.innerHTML = `<div class="loading-spinner">Mengambil riwayat transaksi...</div>`;
  modal.style.display = 'flex';

  try {
    const res = await fetch(`/api/items/${encodeURIComponent(itemName)}`);
    const data = await res.json();
    if (!data.success || !data.data) {
      body.innerHTML = `<p>Gagal memuat detail item.</p>`;
      return;
    }

    const item = data.data;
    document.getElementById('modal-item-name').textContent = item.name;
    document.getElementById('modal-item-category').textContent = `${item.category} • ${item.rarity}`;

    let salesRows = '<tr><td colspan="3" style="text-align: center; color: #64748b;">Belum ada riwayat transaksi tercatat</td></tr>';
    if (item.salesHistory && item.salesHistory.length > 0) {
      salesRows = item.salesHistory.map((s, idx) => `
        <tr>
          <td>#${idx + 1}</td>
          <td><strong>${formatNum(s.price)}</strong></td>
          <td>${s.is_outlier ? '<span style="color: #f43f5e; font-weight: 700;">⚠️ OUTLIER</span>' : '<span style="color: #10b981;">Valid</span>'}</td>
        </tr>
      `).join('');
    }

    body.innerHTML = `
      <div style="background: rgba(0,0,0,0.3); padding: 1rem; border-radius: 8px; margin-bottom: 1.25rem; border: 1px solid rgba(255,255,255,0.08);">
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <span style="color: #94a3b8;">Status Pasar:</span>
          <span class="status-badge badge-${item.status.toLowerCase()}">${item.status}</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <span style="color: #94a3b8;">Clean RAP (Nilai Bersih):</span>
          <span style="font-weight: 700; color: #06b6d4;">${formatNum(item.clean_rap)}</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 0.5rem;">
          <span style="color: #94a3b8;">Official RAP Game:</span>
          <span style="font-weight: 700;">${formatNum(item.current_rap)}</span>
        </div>
        <div style="font-size: 0.85rem; color: #cbd5e1; margin-top: 0.75rem; border-top: 1px solid rgba(255,255,255,0.08); padding-top: 0.5rem;">
          <strong>Diagnosis:</strong> ${item.status_reason}
        </div>
        <div style="font-size: 0.82rem; color: #a5b4fc; margin-top: 0.35rem;">
          <strong>Rekomendasi Trade:</strong> ${item.tradeRecommendation}
        </div>
      </div>

      <h4 style="font-size: 0.95rem; margin-bottom: 0.5rem;">Riwayat Transaksi Terbaru:</h4>
      <table class="table-sales">
        <thead>
          <tr>
            <th>No</th>
            <th>Harga Transaksi</th>
            <th>Status Analisis</th>
          </tr>
        </thead>
        <tbody>
          ${salesRows}
        </tbody>
      </table>
    `;
  } catch (err) {
    body.innerHTML = `<p>Terjadi kesalahan saat memuat data item.</p>`;
  }
};

// ==========================================================================
// 3. RADAR BOOTH & DEALS CONTROLLER
// ==========================================================================
function initRadar() {
  document.getElementById('btn-refresh-booths').addEventListener('click', loadBoothDeals);
}

async function loadBoothDeals() {
  const container = document.getElementById('booth-deals-grid');
  container.innerHTML = `<div class="loading-spinner">Mencari listing booth...</div>`;

  try {
    // Ambil data item yang memiliki harga listing booth terbaru
    const res = await fetch('/api/items?limit=50');
    const data = await res.json();

    if (!data.success || data.items.length === 0) {
      container.innerHTML = `
        <div class="empty-state" style="grid-column: 1 / -1; padding: 4rem 1rem;">
          <p>Belum ada booth yang di-scan dari Solara / Delta.</p>
          <small>Jalankan script Lua scraper di Trade Plaza untuk mulai menerima snapshot booth live.</small>
        </div>
      `;
      return;
    }

    const boothItems = data.items.filter(i => i.last_seen_price > 0 || i.last_deal_rating !== 'UNKNOWN');

    if (boothItems.length === 0) {
      container.innerHTML = `
        <div class="empty-state" style="grid-column: 1 / -1; padding: 4rem 1rem;">
          <p>Belum ada listing booth tersimpan.</p>
          <small>Jalankan script Lua di Trade Plaza untuk mengirim snapshot pasar.</small>
        </div>
      `;
      return;
    }

    container.innerHTML = boothItems.map(item => {
      const rating = item.last_deal_rating || 'FAIR';
      return `
        <div class="booth-card">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.75rem;">
            <div>
              <h4 style="font-size: 1.1rem; font-weight: 700;">${item.name}</h4>
              <div style="font-size: 0.75rem; color: #94a3b8;">${item.category}</div>
            </div>
            <span class="deal-tag ${rating}">${rating}</span>
          </div>

          <div style="background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.08); padding: 0.75rem; border-radius: 8px; margin-bottom: 0.75rem;">
            <div style="display: flex; justify-content: space-between; font-size: 0.85rem; margin-bottom: 0.3rem;">
              <span style="color: #94a3b8;">Harga Jual di Booth:</span>
              <span style="font-weight: 700; color: #38bdf8;">${formatNum(item.last_seen_price)}</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 0.85rem;">
              <span style="color: #94a3b8;">Clean RAP:</span>
              <span style="font-weight: 700; color: #06b6d4;">${formatNum(item.clean_rap)}</span>
            </div>
          </div>

          <div style="display: flex; gap: 0.5rem;">
            <button class="btn-card-action" style="flex: 1;" onclick="addFromCatalog('my', '${escapeJs(item.name)}')">+ Sisi Saya</button>
            <button class="btn-card-action" style="flex: 1;" onclick="addFromCatalog('their', '${escapeJs(item.name)}')">+ Sisi Lawan</button>
          </div>
        </div>
      `;
    }).join('');

  } catch (err) {
    container.innerHTML = `<div class="empty-state" style="grid-column: 1 / -1;">Gagal memuat feed booth.</div>`;
  }
}
