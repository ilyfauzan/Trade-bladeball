--[[
    =================================================================================
    BLADE BALL BOOTH AUTO-SCANNER v4 - FULLY AUTOMATIC
    =================================================================================
    Script ini otomatis:
    1. Loop semua 32 Stand di Workspace.Spawn.Hub.Stands
    2. Fire ProximityPrompt setiap booth yang aktif (ada Owner)
    3. Baca semua item + harga dari UI PlayersBooth
    4. Kirim ke dashboard
    5. Tutup booth, lanjut ke berikutnya
    6. Ulangi setiap 3 menit (auto-refresh)

    CARA PAKAI: Run script ini di Solara, lalu biarkan saja!
    =================================================================================
--]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local SERVER_URL = "http://127.0.0.1:3001/api"
local API_KEY = "bb_trade_plaza_secret_2026"
local SCAN_INTERVAL = 180  -- scan ulang setiap 3 menit

local sendHttpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
if not sendHttpRequest then
    warn("[BB] Executor tidak support HTTP request!")
    return
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = 5
        })
    end)
end

local function parsePrice(text)
    if not text then return 0 end
    local str = tostring(text):lower():gsub(",", ""):gsub("%s+", "")
    local num, suffix = str:match("(%d+%.?%d*)([km]?)")
    if not num then return 0 end
    local val = tonumber(num) or 0
    if suffix == "k" then val = val * 1000
    elseif suffix == "m" then val = val * 1000000 end
    return math.floor(val)
end

local function postData(dataTable)
    local ok, json = pcall(function()
        return HttpService:JSONEncode(dataTable)
    end)
    if not ok then return false end
    local res = sendHttpRequest({
        Url = SERVER_URL .. "/booth-feed",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = API_KEY },
        Body = json
    })
    return res and (res.StatusCode == 200 or res.StatusCode == 201)
end

-- ============================================================
-- BACA BOOTH UI (PlayerGui.Booth.PlayersBooth)
-- ============================================================
local function readBoothUI(playersBooth)
    local items = {}
    local sellerName = "Unknown"

    local topFrame = playersBooth:FindFirstChild("Top")
    if topFrame then
        local lbl = topFrame:FindFirstChild("PlayerName")
        if lbl then
            sellerName = lbl.Text:gsub("'s Booth", ""):match("^%s*(.-)%s*$") or "Unknown"
            local preview = lbl:GetAttribute("TextPreview")
            if preview and #preview > 0 then sellerName = preview end
        end
    end

    local scrollList = playersBooth:FindFirstChild("ScrollingList")
    if not scrollList then return items, sellerName end

    for _, frame in ipairs(scrollList:GetChildren()) do
        if frame:IsA("Frame") and frame.Name ~= "Frame" then
            local itemName, price = "", 0

            local itemBtn = frame:FindFirstChild("Frame")
            if itemBtn and itemBtn:IsA("ImageButton") then
                local lbl = itemBtn:FindFirstChild("ItemName")
                if lbl then itemName = lbl.Text or "" end
            end

            local buyBtn = frame:FindFirstChild("BuyButton")
            if buyBtn then
                local list = buyBtn:FindFirstChild("List")
                if list then
                    local amt = list:FindFirstChild("Amount")
                    if amt then price = parsePrice(amt.Text) end
                end
            end

            if #itemName > 0 and itemName ~= "ItemName" then
                table.insert(items, {
                    itemName = itemName,
                    category = "Unknown",
                    boothPrice = price,
                    currentRap = 0,
                    seller = sellerName,
                    boothId = sellerName .. "_booth"
                })
            end
        end
    end

    return items, sellerName
end

-- ============================================================
-- FIRE PROXIMITY PROMPT (executor function)
-- ============================================================
local function firePrompt(prompt)
    -- Coba berbagai cara yang didukung executor
    local ok = false
    ok = pcall(function() fireproximityprompt(prompt) end)
    if not ok then
        ok = pcall(function() prompt:InputHoldBegin() task.wait(0.2) prompt:InputHoldEnd() end)
    end
    return ok
end

-- ============================================================
-- CLOSE BOOTH UI
-- ============================================================
local function closeBooth(playersBooth)
    pcall(function()
        local closeBtn = playersBooth:FindFirstChild("Close")
        if closeBtn and closeBtn:IsA("ImageButton") then
            closeBtn.MouseButton1Click:Fire()
        end
    end)
end

-- ============================================================
-- AUTO-SCAN SEMUA BOOTH
-- ============================================================
local isScanning = false

local function autoScanAllBooths(statusLabel)
    if isScanning then return end
    isScanning = true

    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then isScanning = false return end

    local boothGui = pGui:FindFirstChild("Booth")
    if not boothGui then
        warn("[BB] ScreenGui 'Booth' belum ada di PlayerGui! Pastikan kamu di Trade Plaza.")
        isScanning = false
        return
    end

    local playersBooth = boothGui:FindFirstChild("PlayersBooth")
    if not playersBooth then
        warn("[BB] PlayersBooth tidak ditemukan!")
        isScanning = false
        return
    end

    -- Ambil semua Stand
    local standsFolder = workspace:FindFirstChild("Spawn")
        and workspace.Spawn:FindFirstChild("Hub")
        and workspace.Spawn.Hub:FindFirstChild("Stands")

    if not standsFolder then
        warn("[BB] Stands folder tidak ditemukan!")
        isScanning = false
        return
    end

    local stands = standsFolder:GetChildren()
    local activeStands = {}
    for _, stand in ipairs(stands) do
        if stand:GetAttribute("Owner") ~= nil then
            table.insert(activeStands, stand)
        end
    end

    print(string.format("[BB] Ditemukan %d/%d booth aktif. Memulai scan...", #activeStands, #stands))
    if statusLabel then
        statusLabel.Text = "Scanning " .. #activeStands .. " booth..."
    end
    notify("📡 Auto-Scan", "Menemukan " .. #activeStands .. " booth aktif!")

    local totalItems = 0
    local allItems = {}

    for i, stand in ipairs(activeStands) do
        pcall(function()
            -- Cari ProximityPrompt di Root
            local root = stand:FindFirstChild("Root")
            if not root then return end

            local holder = root:FindFirstChild("ProximityPromptHolder")
            if not holder then return end

            local prompt = holder:FindFirstChildWhichIsA("ProximityPrompt")
            if not prompt then return end

            if statusLabel then
                statusLabel.Text = string.format("Booth %d/%d...", i, #activeStands)
            end

            -- Fire prompt untuk buka booth
            firePrompt(prompt)

            -- Tunggu UI populate (maks 3 detik)
            local waited = 0
            local scrollList = playersBooth:FindFirstChild("ScrollingList")
            while waited < 3 do
                if scrollList then
                    local children = scrollList:GetChildren()
                    -- Cek apakah ada Frame dengan data nyata (bukan template)
                    local realFrames = 0
                    for _, c in ipairs(children) do
                        if c:IsA("Frame") and c.Name ~= "Frame" then
                            realFrames = realFrames + 1
                        end
                    end
                    if realFrames > 0 then break end
                end
                task.wait(0.3)
                waited = waited + 0.3
            end

            -- Baca data booth
            local items, seller = readBoothUI(playersBooth)

            if #items > 0 then
                print(string.format("[BB] ✅ Booth '%s': %d item", seller, #items))
                totalItems = totalItems + #items
                for _, item in ipairs(items) do
                    table.insert(allItems, item)
                end
            end

            -- Tutup booth
            closeBooth(playersBooth)
            task.wait(0.6) -- jeda antar booth
        end)
    end

    -- Kirim semua data sekaligus
    if #allItems > 0 then
        local ok = postData(allItems)
        if ok then
            print(string.format("[BB] 🚀 SUKSES! %d item dari %d booth terkirim ke dashboard!", #allItems, #activeStands))
            notify("✅ Scan Selesai!", totalItems .. " item dari " .. #activeStands .. " booth!")
            if statusLabel then
                statusLabel.Text = "✅ " .. totalItems .. " item terkirim!"
            end
        else
            notify("⚠️ Server Error", "Cek apakah Node.js server aktif!")
            if statusLabel then statusLabel.Text = "⚠️ Gagal kirim!" end
        end
    else
        print("[BB] Tidak ada item ditemukan. Booth mungkin kosong atau prompt gagal.")
        notify("ℹ️ Info", "Tidak ada item. Coba dekat ke booth dulu.")
        if statusLabel then statusLabel.Text = "Tidak ada item ditemukan." end
    end

    isScanning = false
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local function createGui()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    local old = pGui:FindFirstChild("BBTrackerGui")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BBTrackerGui"
    sg.ResetOnSpawn = false
    sg.Parent = pGui

    -- Container
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 165, 0, 90)
    frame.Position = UDim2.new(0, 12, 0.42, 0)
    frame.BackgroundColor3 = Color3.fromRGB(8, 14, 32)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local fStroke = Instance.new("UIStroke", frame)
    fStroke.Color = Color3.fromRGB(99, 102, 241)
    fStroke.Thickness = 1.5

    -- Judul
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 22)
    title.Position = UDim2.new(0, 0, 0, 6)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(56, 189, 248)
    title.Text = "⚔️ BB Auto Tracker"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.Parent = frame

    -- Status
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -8, 0, 18)
    status.Position = UDim2.new(0, 4, 0, 30)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.fromRGB(134, 239, 172)
    status.Text = "Siap scan..."
    status.Font = Enum.Font.Gotham
    status.TextSize = 10
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    -- Tombol scan
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 28)
    btn.Position = UDim2.new(0, 6, 0, 55)
    btn.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = "🔍 SCAN SEMUA BOOTH"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseButton1Click:Connect(function()
        if isScanning then return end
        btn.Text = "⏳ Scanning..."
        btn.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
        task.spawn(function()
            autoScanAllBooths(status)
            task.wait(0.5)
            btn.Text = "🔍 SCAN SEMUA BOOTH"
            btn.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
        end)
    end)

    return status
end

-- ============================================================
-- AUTO-LOOP (scan ulang tiap SCAN_INTERVAL detik)
-- ============================================================
local statusLabel = createGui()

print("[BB] ✅ BB Auto-Tracker Aktif!")
notify("⚔️ BB Tracker", "Memulai auto-scan semua booth...")

-- Scan pertama langsung
task.spawn(function()
    task.wait(2) -- tunggu karakter ready
    autoScanAllBooths(statusLabel)

    -- Loop terus-menerus
    while true do
        task.wait(SCAN_INTERVAL)
        if statusLabel then statusLabel.Text = "⏰ Auto-refresh..." end
        autoScanAllBooths(statusLabel)
    end
end)

_G.BBTracker = {
    Scan = function() task.spawn(function() autoScanAllBooths(statusLabel) end) end,
    Stop = function() isScanning = false end
}
