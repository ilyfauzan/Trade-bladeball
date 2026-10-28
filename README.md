# Blade Ball Trade Plaza - Market Tracker & RAP Manipulation Detector ⚔️

Sistem pemantau pasar real-time, kalkulator fair-value trade, dan pendeteksi manipulasi harga (**Projected / Boosted / Nuked**) untuk game Roblox **Blade Ball (Trade Plaza)**.

---

## 🚀 Fitur Utama Backend

1. **Clean RAP Calculation & Sanitizer**:
   - Membersihkan distorsi rata-rata akibat transaksi ekstrem (misal penjualan 1 token atau transaksi palsu puluhan ribu).
   - Menghitung **Clean RAP** berbasis algoritma Median dan Outlier Trimming (IQR-based).
2. **Deteksi Manipulasi Otomatis (Status Classifier)**:
   - `PROJECTED`: Kenaikan harga ekstrem $\ge 2.5\times$ dari Clean RAP (skema pump untuk menipu trade).
   - `BOOSTED`: Kenaikan tidak wajar $1.45\times - 2.5\times$ dari Clean RAP.
   - `NUKED`: Terdeteksi transaksi dump/crash buatan $\le 10$ token/gem atau ratio $\le 0.35\times$.
   - `NORMAL`: Harga pasar stabil dan wajar.
3. **Trade Plaza Booth Deal Evaluator**:
   - Menilai apakah harga listing booth tergolong `STEAL`, `UNDERPAY`, `FAIR`, `OVERPAY`, atau `AVOID_PROJECTED`.
4. **Kalkulator Trade Evaluator Real-Time (`POST /api/trade/evaluate`)**:
   - Menghitung perbandingan *My Items* vs *Their Items* berdasarkan **Clean RAP riil** (bukan sekadar RAP nominal game).
   - Memberikan peringatan instan jika pihak lawan mencoba menyelipkan item projected.
5. **Database SQLite High-Performance (WAL Mode)**:
   - Zero-lock, kecepatan transaksi instan (mampu memproses ratusan item dalam beberapa milidetik).

---

## 📂 Struktur Direktori Proyek

```
trading_bb/
├── data/
│   └── trading_bb.db          # Database SQLite (auto-generated)
├── src/
│   ├── config/
│   │   └── database.js        # Konfigurasi SQLite, PRAGMA WAL, & skema tabel
│   ├── services/
│   │   ├── analyzer.js        # Logika Clean RAP & deteksi Projected/Boosted/Nuked
│   │   └── itemService.js     # Query prepared statements, batch transaction, trade evaluator
│   ├── routes/
│   │   └── api.js             # Endpoint REST API (booth-feed, update-item, items, stats)
│   ├── scripts/
│   │   ├── seed_master.js     # Skrip import katalog master (>1.600 pedang & explosions)
│   │   └── lua_scraper_example.lua # Template universal Lua untuk Solara & Delta
│   ├── data/
│   │   └── sample_master.json # Contoh data awal
│   └── index.js               # Main Express Server
├── test_payload.js            # Uji coba end-to-end 5 skenario payload
├── .env                       # Konfigurasi PORT & API_KEY
└── package.json
```

---

## 🛠️ Cara Menjalankan

### 1. Menjalankan Server
```bash
# Menjalankan server standar
npm start

# Mode development (auto-reload saat ada perubahan kode)
npm run dev
```
Server akan aktif di `http://localhost:3001` (dan dapat diakses dari jaringan lokal/HP melalui IP LAN komputer Anda).

### 2. Mengimpor Katalog Master (>1.600 Pedang & Explosions Anda)
Anda dapat langsung memasukkan file JSON hasil ekstraksi client game Anda:
```bash
node src/scripts/seed_master.js path/ke/file_master_anda.json
```
*Format yang didukung: array string `["Pedang A", "Pedang B"]` atau array objek `[{ "name": "Pedang A", "category": "Sword" }]`.*

### 3. Menguji Sistem
Jalankan skrip tes untuk memverifikasi logika deteksi manipulasi harga:
```bash
npm run test:feed
```

---

## 📡 Dokumentasi Endpoint API

| Method | Endpoint | Deskripsi |
|---|---|---|
| `POST` | `/api/booth-feed` | Menerima data batch scanner booth dari Solara / Delta |
| `POST` | `/api/update-item` | Update 1 item spesifik beserta riwayat 5 transaksi terakhir |
| `GET` | `/api/items` | Pencarian A-Z, autocomplete, filter kategori & status |
| `GET` | `/api/items/:name` | Detail item, riwayat transaksi, & breakdown Clean RAP |
| `GET` | `/api/market/stats` | Statistik pasar, jumlah item projected & nuked |
| `POST` | `/api/trade/evaluate` | Kalkulator evaluasi trade (My Items vs Their Items) |

---

## 📱 Integrasi Lua (Solara / Delta)

Gunakan script [lua_scraper_example.lua](file:///c:/Users/FAUZAN/Documents/trading_bb/src/scripts/lua_scraper_example.lua) pada executor Anda. Cukup arahkan URL ke server lokal atau cloud VPS Anda:

```lua
local payload = {
    itemName = "Dragon Blade",
    category = "Sword",
    currentRap = 12500,
    salesHistory = { 12200, 12600, 12400, 12500, 12800 },
    boothPrice = 11000,
    seller = "PlayerName"
}
_G.BBTracker.SendSingle(payload)
```
