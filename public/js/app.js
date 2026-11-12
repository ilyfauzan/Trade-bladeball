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
  checkSolaraStatus();

  // Periodically refresh market stats & check Solara connection
  setInterval(fetchMarketStats, 15000);
  setInterval(checkSolaraStatus, 3000);
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
// 1. TRADE CALCULATOR & QUICK SWORD INSPECTOR
// ==========================================================================
let currentInspectedItem = null;

function initTradeCalculator() {
  setupAutocomplete('my');
  setupAutocomplete('their');
  initQuickInspector();

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

// Quick Sword Inspector Controller
function initQuickInspector() {
  const searchInput = document.getElementById('inspector-search-input');
  const searchBtn = document.getElementById('btn-inspector-search');
  const dropdown = document.getElementById('dropdown-inspector');

  const doInspectorSearch = debounce(async (query) => {
    if (!query || query.trim().length < 1) {
      dropdown.style.display = 'none';
      return;
    }

    try {
      const res = await fetch(`/api/items?search=${encodeURIComponent(query.trim())}&limit=6`);
      const data = await res.json();

      if (data.success && data.items.length > 0) {
        dropdown.innerHTML = data.items.map(item => {
          const statusUpper = (item.status || 'NORMAL').toUpperCase();
          let icon = statusUpper === 'NUKED' ? '💥' : (statusUpper === 'BOOSTED' ? '⚡' : (statusUpper === 'PROJECTED' ? '🚨' : '🟢'));
          return `
            <div class="dropdown-item" data-name="${item.name}">
              <div>
                <div class="d-title">${item.name}</div>
                <div class="d-meta">${item.category} • ${item.rarity}</div>
              </div>
              <div class="d-rap">
                <span class="status-badge badge-${item.status.toLowerCase()}">${icon} ${item.status}</span>
                <div style="font-size: 0.75rem; color: #94a3b8; margin-top: 2px;">
                  RAP: ${formatNum(item.current_rap)} | Clean: ${formatNum(item.clean_rap)}
                </div>
              </div>
            </div>
          `;
        }).join('');

        dropdown.style.display = 'block';

        dropdown.querySelectorAll('.dropdown-item').forEach(el => {
          el.addEventListener('click', () => {
            const name = el.dataset.name;
            searchInput.value = name;
            dropdown.style.display = 'none';
            inspectSword(name);
          });
        });
      } else {
        dropdown.innerHTML = `<div style="padding: 12px; text-align: center; color: #64748b; font-size: 0.85rem;">Item tidak ditemukan di katalog</div>`;
        dropdown.style.display = 'block';
      }
    } catch (e) {
      console.error(e);
    }
  }, 200);

  searchInput.addEventListener('input', (e) => doInspectorSearch(e.target.value));

  searchBtn.addEventListener('click', () => {
    const q = searchInput.value.trim();
    if (q) inspectSword(q);
  });

  searchInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      dropdown.style.display = 'none';
      const q = searchInput.value.trim();
      if (q) inspectSword(q);
    }
  });

  document.addEventListener('click', (e) => {
    if (!searchInput.contains(e.target) && !dropdown.contains(e.target)) {
      dropdown.style.display = 'none';
    }
  });

  // Manual update modal wiring
  const updateModal = document.getElementById('modal-update');
  const openModalBtn = document.getElementById('btn-open-manual-update');
  const closeModalBtn = document.getElementById('btn-close-update-modal');
  const updateForm = document.getElementById('form-update-item');

  if (openModalBtn) {
    openModalBtn.addEventListener('click', () => {
      if (currentInspectedItem) {
        document.getElementById('up-item-name').value = currentInspectedItem.name;
        document.getElementById('up-current-rap').value = currentInspectedItem.current_rap || '';
        if (currentInspectedItem.salesHistory && currentInspectedItem.salesHistory.length > 0) {
          document.getElementById('up-sales-history').value = currentInspectedItem.salesHistory.map(s => s.price).join(', ');
        }
      }
      updateModal.style.display = 'flex';
    });
  }

  if (closeModalBtn) {
    closeModalBtn.addEventListener('click', () => {
      updateModal.style.display = 'none';
    });
  }

  if (updateModal) {
    updateModal.addEventListener('click', (e) => {
      if (e.target.id === 'modal-update') updateModal.style.display = 'none';
    });
  }

  if (updateForm) {
    updateForm.addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('up-item-name').value.trim();
      const rap = parseInt(document.getElementById('up-current-rap').value.trim(), 10);
      const rawSales = document.getElementById('up-sales-history').value;
      const sales = rawSales.split(',').map(s => parseInt(s.trim(), 10)).filter(n => !isNaN(n));

      if (!name) return alert('Nama sword wajib diisi!');
      if (isNaN(rap)) return alert('Nominal RAP wajib diisi angka!');

      const btnSubmit = document.getElementById('btn-submit-update');
      btnSubmit.disabled = true;
      btnSubmit.textContent = 'Menyimpan...';

      try {
        const res = await fetch('/api/update-item', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            itemName: name,
            currentRap: rap,
            salesHistory: sales
          })
        });
        const data = await res.json();
        if (data.success) {
          alert(`✅ Sukses! ${data.message}`);
          updateModal.style.display = 'none';
          searchInput.value = name;
          inspectSword(name);
          fetchMarketStats();
        } else {
          alert(`❌ Gagal: ${data.error}`);
        }
      } catch (err) {
        alert(`❌ Terjadi error: ${err.message}`);
      } finally {
        btnSubmit.disabled = false;
        btnSubmit.textContent = '💾 Simpan & Analisis Manipulasi';
      }
    });
  }
}

// Check Solara Bridge status in real time
let isSolaraOnline = false;

async function checkSolaraStatus() {
  try {
    const res = await fetch('/api/bridge/status');
    const json = await res.json();
    isSolaraOnline = json.connected;

    const dot = document.getElementById('bridge-pulse-dot');
    const txt = document.getElementById('bridge-status-text');

    if (dot && txt) {
      if (json.connected) {
        dot.style.backgroundColor = '#10b981';
        dot.style.boxShadow = '0 0 8px #10b981';
        txt.textContent = '🟢 Terhubung di Game';
        txt.style.color = '#34d399';
      } else {
        dot.style.backgroundColor = '#64748b';
        dot.style.boxShadow = 'none';
        txt.textContent = '⚪ Belum Jalan';
        txt.style.color = '#94a3b8';
      }
    }
  } catch (e) {}
}

// Inspect single sword: sends command to Solara in Blade Ball -> Solara returns live RAP & 5 Sales!
async function inspectSword(itemName) {
  const resultCard = document.getElementById('inspector-result-card');
  resultCard.style.display = 'block';

  if (isSolaraOnline) {
    resultCard.innerHTML = `
      <div class="loading-spinner" style="padding: 1.5rem;">
        <span style="font-size: 1.2rem;">⚡</span> Mengirim perintah ke Solara di Blade Ball...
        <br><small style="color: #38bdf8;">Menunggu Solara menarik RAP & 5 Sales langsung dari game...</small>
      </div>
    `;
  } else {
    resultCard.innerHTML = `<div class="loading-spinner" style="padding: 1.5rem;">Mencari data untuk "${itemName}"...</div>`;
  }

  try {
    const res = await fetch('/api/bridge/query', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ itemName: itemName.trim() })
    });
    const data = await res.json();

    if (!data.success || !data.data) {
      resultCard.innerHTML = `
        <div style="padding: 1.5rem; text-align: center; color: #94a3b8;">
          <p style="font-weight: 700; color: #f43f5e; margin-bottom: 0.5rem;">${data.error || `Item "${itemName}" tidak ditemukan.`}</p>
          <small>Jalankan script <code>solara_bridge.lua</code> di Solara saat berada di game Blade Ball untuk auto-fetch live.</small>
        </div>
      `;
      return;
    }

    const item = data.data;
    currentInspectedItem = item;

    const statusUpper = (item.status || 'NORMAL').toUpperCase();
    let statusIcon = '🟢';
    let statusBadgeClass = 'badge-normal';
    let diagBoxClass = '';

    if (statusUpper === 'NUKED') {
      statusIcon = '💥';
      statusBadgeClass = 'badge-nuked';
      diagBoxClass = 'nuked';
    } else if (statusUpper === 'BOOSTED') {
      statusIcon = '⚡';
      statusBadgeClass = 'badge-boosted';
      diagBoxClass = 'boosted';
    } else if (statusUpper === 'PROJECTED') {
      statusIcon = '🚨';
      statusBadgeClass = 'badge-projected';
      diagBoxClass = 'projected';
    }

    const ratio = item.clean_rap > 0 ? (item.current_rap / item.clean_rap).toFixed(2) : '1.00';

    let dataSourcePill = '';
    if (data.source === 'LIVE_BLADEBALL_SOLARA') {
      dataSourcePill = `<span style="background: rgba(16,185,129,0.2); color: #34d399; border: 1px solid rgba(16,185,129,0.4); padding: 2px 8px; border-radius: 4px; font-size: 0.72rem; font-weight: 700; margin-left: 8px;">⚡ LIVE DARI GAME (SOLARA)</span>`;
    } else if (data.source === 'DATABASE_CACHE') {
      dataSourcePill = `<span style="background: rgba(99,102,241,0.2); color: #818cf8; border: 1px solid rgba(99,102,241,0.4); padding: 2px 8px; border-radius: 4px; font-size: 0.72rem; font-weight: 700; margin-left: 8px;">💾 DATABASE LOKAL</span>`;
    }

    // 5 Sales Chips
    let salesChipsHtml = '<div style="color: #64748b; font-size: 0.8rem; padding: 4px 0;">Belum ada 5 transaksi tersimpan.</div>';
    const salesArr = item.salesHistory || item.recentSales || [];
    if (salesArr && salesArr.length > 0) {
      salesChipsHtml = salesArr.slice(0, 5).map((s, idx) => {
        const p = typeof s === 'object' ? s.price : s;
        const isOutlier = typeof s === 'object' ? s.is_outlier : false;
        let chipClass = 'sale-chip';
        let outlierBadge = '';
        if (isOutlier) {
          if (statusUpper === 'NUKED' || p <= 10) {
            chipClass += ' outlier-nuked';
            outlierBadge = '<span style="font-size: 0.68rem; font-weight: 800; color: #f59e0b;">💥 OUTLIER (DUMP)</span>';
          } else {
            chipClass += ' outlier-projected';
            outlierBadge = '<span style="font-size: 0.68rem; font-weight: 800; color: #f43f5e;">⚡ OUTLIER (PUMP)</span>';
          }
        }
        return `
          <div class="${chipClass}">
            <span class="chip-idx">#${idx + 1}</span>
            <span><strong>${formatNum(p)}</strong></span>
            ${outlierBadge}
          </div>
        `;
      }).join('');
    }

    resultCard.innerHTML = `
      <div class="res-card-top">
        <div>
          <div class="res-meta-line">${item.category} • ${item.rarity} ${dataSourcePill}</div>
          <h2 class="res-name">${item.name}</h2>
        </div>
        <div class="res-status-wrap">
          <span class="status-badge ${statusBadgeClass}" style="font-size: 0.85rem; padding: 4px 10px;">
            ${statusIcon} ${item.status}
          </span>
        </div>
      </div>

      <div class="res-rap-grid">
        <div class="res-rap-box clean">
          <span class="res-box-label">Clean RAP (Nilai Riil Bersih):</span>
          <span class="res-box-val highlight-cyan">${formatNum(item.clean_rap)}</span>
          <small class="res-box-sub">Bebas dari transaksi palsu / dump</small>
        </div>
        <div class="res-rap-box official">
          <span class="res-box-label">Official RAP (Nominal Game):</span>
          <span class="res-box-val">${formatNum(item.current_rap)}</span>
          <small class="res-box-sub">Rasio Game/Clean: <strong>${ratio}x</strong></small>
        </div>
      </div>

      <div class="res-sales-section">
        <div class="res-sales-header">
          <span class="res-sales-title">📊 5 Riwayat Transaksi Terakhir (Sales History):</span>
          <span class="res-sales-hint">Deteksi transaksi dump 1 token atau pump buatan</span>
        </div>
        <div class="res-sales-chips">
          ${salesChipsHtml}
        </div>
      </div>

      <div class="res-diagnosis-box ${diagBoxClass}">
        <div class="diag-title">💡 Diagnosis Manipulasi:</div>
        <div class="diag-desc">${item.status_reason || 'Harga stabil tanpa indikasi transaksi abnormal.'}</div>
        <div style="font-size: 0.8rem; color: #a5b4fc; margin-top: 4px;">
          <strong>Rekomendasi Trade:</strong> ${item.tradeRecommendation || 'Aman ditrade.'}
        </div>
      </div>

      <div class="res-actions-bar">
        <button class="btn-add-trade my" id="btn-inspect-add-my">+ Tambah ke Sisi Anda</button>
        <button class="btn-add-trade their" id="btn-inspect-add-their">+ Tambah ke Sisi Lawan</button>
      </div>
    `;

    document.getElementById('btn-inspect-add-my')?.addEventListener('click', () => {
      addItemToTrade('my', item);
    });
    document.getElementById('btn-inspect-add-their')?.addEventListener('click', () => {
      addItemToTrade('their', item);
    });

  } catch (err) {
    resultCard.innerHTML = `<div style="padding: 1.5rem; text-align: center; color: #f43f5e;">Gagal menghubungi server bridge: ${err.message}</div>`;
  }
}

// Setup Autocomplete for adding items into trade sides
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
        dropdown.innerHTML = data.items.map(item => {
          const statusUpper = (item.status || 'NORMAL').toUpperCase();
          let icon = statusUpper === 'NUKED' ? '💥' : (statusUpper === 'BOOSTED' ? '⚡' : (statusUpper === 'PROJECTED' ? '🚨' : '🟢'));
          return `
            <div class="dropdown-item" data-name="${item.name}">
              <div>
                <div class="d-title">${item.name}</div>
                <div class="d-meta">${item.category} • ${item.rarity}</div>
              </div>
              <div class="d-rap">
                <span class="status-badge badge-${item.status.toLowerCase()}">${icon} ${item.status}</span>
                <div style="font-size: 0.75rem; color: #94a3b8; margin-top: 2px;">
                  RAP: ${formatNum(item.current_rap)} | Clean: ${formatNum(item.clean_rap)}
                </div>
              </div>
            </div>
          `;
        }).join('');

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

  document.addEventListener('click', (e) => {
    if (!input.contains(e.target) && !dropdown.contains(e.target)) {
      dropdown.style.display = 'none';
    }
  });
}

// Add Item to a Trade Side
async function addItemToTrade(side, item) {
  const list = side === 'my' ? state.myItems : state.theirItems;
  const existing = list.find(i => i.name.toLowerCase() === item.name.toLowerCase());

  if (existing) {
    existing.count += 1;
    renderTradeList(side);
    evaluateTrade();
    return;
  }

  let fullItem = item;
  if (!item.recentSales && !item.salesHistory) {
    try {
      const res = await fetch(`/api/items/${encodeURIComponent(item.name)}`);
      const data = await res.json();
      if (data.success && data.data) {
        fullItem = data.data;
      }
    } catch (e) {
      console.warn('Could not fetch full details for', item.name);
    }
  }

  const sales = fullItem.recentSales || fullItem.salesHistory || [];

  list.push({
    name: fullItem.name,
    category: fullItem.category || 'Sword',
    rarity: fullItem.rarity || 'Common',
    cleanRap: fullItem.clean_rap !== undefined ? fullItem.clean_rap : fullItem.cleanRap,
    currentRap: fullItem.current_rap !== undefined ? fullItem.current_rap : fullItem.currentRap,
    status: fullItem.status || 'NORMAL',
    statusReason: fullItem.status_reason || fullItem.statusReason || '',
    recentSales: sales.slice(0, 5),
    count: 1
  });

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
        <small>${side === 'my' ? 'Gunakan bilah cari di atas untuk memilih pedang Anda' : 'Cari item tawaran lawan untuk mengecek status projected/nuked/boosted'}</small>
      </div>
    `;
    updateTotals(side, 0, 0);
    return;
  }

  let totalClean = 0;
  let totalOff = 0;

  container.innerHTML = list.map((item, index) => {
    const subClean = (item.cleanRap || 0) * item.count;
    const subOff = (item.currentRap || 0) * item.count;
    totalClean += subClean;
    totalOff += subOff;

    const statusUpper = (item.status || 'NORMAL').toUpperCase();
    let statusIcon = '🟢';
    let statusBadgeClass = 'badge-normal';
    if (statusUpper === 'NUKED') {
      statusIcon = '💥';
      statusBadgeClass = 'badge-nuked';
    } else if (statusUpper === 'BOOSTED') {
      statusIcon = '⚡';
      statusBadgeClass = 'badge-boosted';
    } else if (statusUpper === 'PROJECTED') {
      statusIcon = '🚨';
      statusBadgeClass = 'badge-projected';
    }

    // Render 5 sales pills
    let salesPillsHtml = '';
    if (item.recentSales && item.recentSales.length > 0) {
      const pills = item.recentSales.map(s => {
        const price = typeof s === 'object' ? s.price : s;
        const isOutlier = typeof s === 'object' ? s.is_outlier : false;
        let pillClass = 'mini-sale-pill';
        let outlierTag = '';
        if (isOutlier) {
          if (statusUpper === 'NUKED' || price <= 10) {
            pillClass += ' outlier-nuked';
            outlierTag = ' 💥';
          } else {
            pillClass += ' outlier';
            outlierTag = ' ⚡';
          }
        }
        return `<span class="${pillClass}" title="${isOutlier ? 'Outlier / Manipulasi' : 'Normal'}">${formatNum(price)}${outlierTag}</span>`;
      }).join('');

      salesPillsHtml = `
        <div class="trade-sales-row">
          <span class="trade-sales-label">5 Sales:</span>
          ${pills}
        </div>
      `;
    }

    const diagnosisHtml = item.statusReason ? `<div class="trade-item-diagnosis">${item.statusReason}</div>` : '';

    return `
      <div class="trade-item-row">
        <div class="trade-item-info">
          <div class="item-name-tag">
            <span>${item.name}</span>
            <span class="status-badge ${statusBadgeClass}">${statusIcon} ${item.status}</span>
          </div>
          <div class="item-rap-details">
            Clean: <strong>${formatNum(item.cleanRap)}</strong> | RAP: ${formatNum(item.currentRap)}
          </div>
          ${salesPillsHtml}
          ${diagnosisHtml}
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
  const btn = document.getElementById('btn-refresh-booths');
  if (btn) btn.addEventListener('click', loadBoothDeals);
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
