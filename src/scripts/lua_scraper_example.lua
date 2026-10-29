--[[
    =================================================================================
    ⚔️ BLADE BALL TRADE PLAZA - REAL-TIME MARKET BRIDGE (Solara / Delta Universal)
    =================================================================================
    Script ini otomatis:
    1. Memindai (scan) seluruh Booth yang aktif di Trade Plaza Blade Ball.
    2. Mendeteksi RAP nominal, harga jual listing, nama penjual, dan riwayat transaksi.
    3. Mengirimkan data via HTTP POST ke Backend Node.js Anda (http://localhost:3001).
    4. Memberikan NOTIFIKASI POPUP IN-GAME jika terdeteksi item PROJECTED (Scam Pump)!
    =================================================================================
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- =================================================================================
-- 1. KONFIGURASI ALAMAT SERVER
-- =================================================================================
-- Gunakan "http://localhost:3001/api" jika Solara berjalan di PC yang sama dengan server.
-- Gunakan "http://192.168.100.6:3001/api" jika Delta berjalan di HP / Cloud Phone (Wi-Fi LAN).
local SERVER_URL = "http://localhost:3001/api"
local API_KEY = "bb_trade_plaza_secret_2026"

-- Deteksi Fungsi HTTP Request Universal Executor
local sendHttpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

if not sendHttpRequest then
    warn("[BB Bridge] ❌ Executor Anda tidak mendukung fungsi HTTP request!")
    return
end

-- Helper: In-Game Notification
local function notify(title, text, isWarning)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = isWarning and 6 or 3,
            Icon = isWarning and "rbxassetid://10888375286" or "rbxassetid://10888375178"
        })
    end)
end

-- Helper: HTTP POST request ke Backend API
local function postData(endpoint, dataTable)
    local success, jsonPayload = pcall(function()
        return HttpService:JSONEncode(dataTable)
    end)

    if not success then
        warn("[BB Bridge] Gagal Encode JSON:", jsonPayload)
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
        warn("[BB Bridge] HTTP Error (" .. tostring(response and response.StatusCode) .. "):", response and response.Body)
        return nil
    end
end

-- =================================================================================
-- 2. PARSER HARGA & RAP DARI TEKS GAME (Sanitasi Angka)
-- =================================================================================
local function parsePrice(text)
    if not text then return 0 end
    local str = tostring(text):lower():gsub(",", ""):gsub("%s+", "")
    -- Ambil hanya digit atau k/m
    local num, suffix = str:match("(%d+%.?%d*)([km]?)")
    if not num then return 0 end
    local val = tonumber(num) or 0
    if suffix == "k" then val = val * 1000
    elseif suffix == "m" then val = val * 1000000 end
    return math.floor(val)
end

-- =================================================================================
-- 3. SCANNER BOOTH TRADE PLAZA (Membaca Seluruh Booth di Map)
-- =================================================================================
local function scanAllBooths()
    print("[BB Bridge] 🔍 Memulai pemindaian booth Trade Plaza...")
    local scannedItems = {}

    -- Cari container booths di Workspace (biasanya workspace.Booths atau sejenisnya)
    local boothFolders = {
        workspace:FindFirstChild("Booths"),
        workspace:FindFirstChild("TradePlaza") and workspace.TradePlaza:FindFirstChild("Booths"),
        workspace:FindFirstChild("MarketBooths")
    }

    local targetFolder = nil
    for _, f in ipairs(boothFolders) do
        if f then targetFolder = f break end
    end

    -- Jika folder khusus tidak ditemukan, scan semua model di workspace yang memiliki kata 'booth'
    local boothsList = {}
    if targetFolder then
        boothsList = targetFolder:GetChildren()
    else
        for _, child in ipairs(workspace:GetChildren()) do
            if child:IsA("Model") and child.Name:lower():find("booth") then
                table.insert(boothsList, child)
            end
        end
    end

    for _, booth in ipairs(boothsList) do
        pcall(function()
            local ownerName = "Unknown"
            local ownerTag = booth:FindFirstChild("Owner") or booth:FindFirstChild("OwnerName")
            if ownerTag then ownerName = tostring(ownerTag.Value or ownerTag.Name) end

            -- Cari seluruh TextLabel yang ada di dalam BillboardGui / SurfaceGui booth
            for _, gui in ipairs(booth:GetDescendants()) do
                if gui:IsA("TextLabel") and gui.Visible then
                    local text = gui.Text
                    -- Jika teks menyerupai nama pedang atau ada harga
                    local itemPrice = parsePrice(text)
                    if itemPrice > 0 and text:find("%d") then
                        -- Cari label pendamping yang berisi nama item
                        local parent = gui.Parent
                        if parent then
                            for _, sibling in ipairs(parent:GetChildren()) do
                                if sibling:IsA("TextLabel") and sibling ~= gui and #sibling.Text > 2 and not sibling.Text:find("^%d+$") then
                                    local itemName = sibling.Text:gsub("%[.-%]", ""):match("^%s*(.-)%s*$")
                                    if itemName and #itemName > 2 then
                                        table.insert(scannedItems, {
                                            itemName = itemName,
                                            category = "Sword",
                                            boothPrice = itemPrice,
                                            currentRap = 0, -- akan disinkronkan dengan database master
                                            seller = ownerName,
                                            boothId = booth.Name
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    if #scannedItems > 0 then
        local res = postData("/booth-feed", scannedItems)
        if res and res.success then
            notify("✅ Sync Sukses", "Berhasil mengirim " .. tostring(res.count) .. " penawaran booth ke Web Tracker!", false)
            print("[BB Bridge] Berhasil sinkronisasi " .. tostring(res.count) .. " item booth!")
        end
    else
        print("[BB Bridge] Belum ada item booth terisi atau player belum me-load model booth.")
    end
end

-- =================================================================================
-- 4. HOOK INSPECT ITEM (Saat Anda Mengklik Item / Melihat 5 Riwayat Penjualan)
-- =================================================================================
local function hookInspectUI()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then return end

    -- Monitor UI Inspect atau Trade Frame yang baru muncul
    playerGui.DescendantAdded:Connect(function(descendant)
        pcall(function()
            -- Deteksi apakah ini frame detail item (biasanya terdapat label 'RAP' atau 'History')
            if descendant:IsA("TextLabel") and descendant.Text:lower():find("rap") then
                local frame = descendant.Parent
                if not frame then return end

                local itemName = ""
                local currentRap = 0
                local salesHistory = {}

                -- Baca semua teks di frame ini
                for _, lbl in ipairs(frame:GetDescendants()) do
                    if lbl:IsA("TextLabel") then
                        local t = lbl.Text:lower()
                        if t:find("rap:") or t:find("rap%s*%d") then
                            currentRap = parsePrice(lbl.Text)
                        elseif not t:find("%d") and #lbl.Text > 3 and not t:find("recent") then
                            itemName = lbl.Text
                        elseif lbl.Name:lower():find("sale") or lbl.Name:lower():find("price") then
                            local sPrice = parsePrice(lbl.Text)
                            if sPrice > 0 then
                                table.insert(salesHistory, sPrice)
                            end
                        end
                    end
                end

                if #itemName > 2 and currentRap > 0 then
                    local payload = {
                        itemName = itemName,
                        category = "Sword",
                        currentRap = currentRap,
                        salesHistory = salesHistory
                    }

                    local res = postData("/update-item", payload)
                    if res and res.success then
                        if res.data.status == "PROJECTED" then
                            notify("🚨 PROJECTED DETECTED!", itemName .. " dimanipulasi! Clean RAP: " .. tostring(res.data.cleanRap), true)
                        elseif res.data.status == "NUKED" then
                            notify("💥 NUKED ITEM", itemName .. " terkena dump! Clean RAP: " .. tostring(res.data.cleanRap), false)
                        else
                            notify("✅ Status Normal", itemName .. " (RAP: " .. tostring(res.data.cleanRap) .. ")", false)
                        end
                    end
                end
            end
        end)
    end)
end

-- =================================================================================
-- 5. GUI CONTROLLER KECIL DI LAYAR ROBLOX (TOMBOL SCAN CEPAT)
-- =================================================================================
local function createMiniScreenButton()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    local existing = pGui:FindFirstChild("BBTrackerGui")
    if existing then existing:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BBTrackerGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pGui

    local scanBtn = Instance.new("TextButton")
    scanBtn.Name = "ScanBtn"
    scanBtn.Size = UDim2.new(0, 140, 0, 42)
    scanBtn.Position = UDim2.new(0, 20, 0.45, 0)
    scanBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    scanBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
    scanBtn.Text = "📡 SCAN BOOTHS"
    scanBtn.Font = Enum.Font.GothamBold
    scanBtn.TextSize = 13
    scanBtn.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = scanBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(99, 102, 241)
    stroke.Thickness = 1.5
    stroke.Parent = scanBtn

    scanBtn.MouseButton1Click:Connect(function()
        scanBtn.Text = "⏳ SCANNING..."
        scanAllBooths()
        task.wait(1.5)
        scanBtn.Text = "📡 SCAN BOOTHS"
    end)
end

-- =================================================================================
-- 6. STARTUP INITIALIZATION
-- =================================================================================
notify("⚔️ BB Tracker Ready", "Terhubung ke " .. SERVER_URL, false)
hookInspectUI()
createMiniScreenButton()

-- Auto-scan otomatis saat script pertama kali dieksekusi
task.spawn(function()
    task.wait(2)
    scanAllBooths()
end)

-- Export fungsi global untuk debugging
_G.BBTracker = {
    Scan = scanAllBooths,
    Update = postData
}

print("==========================================================")
print("⚔️  BLADE BALL TRADE PLAZA TRACKER LUA CLIENT AKTIF!")
print("📡 Target API: " .. SERVER_URL)
print("==========================================================")
