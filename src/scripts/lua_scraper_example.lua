--[[
    =======================================================================
    BLADE BALL TRADE PLAZA - UNIVERSAL LUA FEED CLIENT (Solara / Delta)
    =======================================================================
    Script ini bertugas mengirimkan data booth / item yang dibaca dari
    game client Blade Ball ke Backend API Anda.
--]]

local HttpService = game:GetService("HttpService")

-- Konfigurasi Endpoint Backend Anda:
-- Ganti IP di bawah dengan IP Komputer Server Anda (misal: "http://192.168.1.10:3001/api")
-- Jika menggunakan Cloud VPS, gunakan domain / public IP Anda.
local SERVER_URL = "http://localhost:3001/api"
local API_KEY = "bb_trade_plaza_secret_2026"

-- Deteksi Fungsi Request Executor (Universal Solara / Delta / Fluxus / Synapse)
local sendHttpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

if not sendHttpRequest then
    warn("[BB Tracker] Executor Anda tidak mendukung fungsi HTTP Request!")
    return
end

local function postData(endpoint, dataTable)
    local success, jsonPayload = pcall(function()
        return HttpService:JSONEncode(dataTable)
    end)

    if not success then
        warn("[BB Tracker] Gagal melakukan JSON Encode:", jsonPayload)
        return nil
    end

    local response = sendHttpRequest({
        Url = SERVER_URL .. endpoint,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = API_KEY
        },
        Body = jsonPayload
    })

    if response and (response.StatusCode == 200 or response.StatusCode == 201) then
        return HttpService:JSONDecode(response.Body)
    else
        warn("[BB Tracker] HTTP Error:", response and response.StatusCode, response and response.Body)
        return nil
    end
end

-- =======================================================================
-- CONTOH 1: Mengirim Data Item Tunggal (Fokus Inspect Item / Booth Terpilih)
-- =======================================================================
local function sendSingleItemUpdate(itemName, category, rap, salesList, boothPrice, sellerName)
    local payload = {
        itemName = itemName,
        category = category or "Sword",
        currentRap = rap or 0,
        salesHistory = salesList or {},
        boothPrice = boothPrice or 0,
        seller = sellerName or "Unknown"
    }

    local res = postData("/update-item", payload)
    if res and res.success then
        print(string.format("[BB Tracker] Status %s: %s (Clean RAP: %d)", res.data.name, res.data.status, res.data.cleanRap))
        if res.data.status == "PROJECTED" then
            -- Berikan notifikasi ingame jika item berbahaya
            warn("🚨 PERINGATAN: Item " .. res.data.name .. " terdeteksi PROJECTED!")
        end
    end
end

-- =======================================================================
-- CONTOH 2: Mengirim Batch Data (Scan Seluruh Booth di Trade Plaza)
-- =======================================================================
local function sendBatchBoothFeed(scannedItemsArray)
    -- scannedItemsArray format:
    -- {
    --    { itemName = "Dragon Blade", category = "Sword", currentRap = 12500, boothPrice = 11000, seller = "Player1" },
    --    { itemName = "Glitch Katana", category = "Sword", currentRap = 25000, boothPrice = 18000, seller = "Player2" }
    -- }
    local res = postData("/booth-feed", scannedItemsArray)
    if res and res.success then
        print(string.format("[BB Tracker] Berhasil sinkronisasi %d item booth!", res.count))
    end
end

-- Export fungsi ke _G jika ingin dipanggil dari script UI reader Anda
_G.BBTracker = {
    SendSingle = sendSingleItemUpdate,
    SendBatch = sendBatchBoothFeed
}

print("[BB Tracker] Modul Scraper Client siap terhubung ke Backend API!")
