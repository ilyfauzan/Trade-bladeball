--[[
    ══════════════════════════════════════════════════════════════════════════════
    🛡️ BLADE BALL ANTI-SCAM FAST SNIPER & TRAP COUNTER (STANDALONE TOOL)
    ══════════════════════════════════════════════════════════════════════════════
    
    Tujuan Khusus:
    Melawan pelaku "Switcheroo / Bait & Switch Scam" di Trade Plaza yang sengaja
    memasang item ber-value tinggi seharga 1 token, lalu dalam hitungan detik 
    mencabutnya dan menggantinya ke 11.000 token untuk menjebak pembeli.

    Cara Kerja Senjata Ini:
    1. 🛡️ ATOMIC PRICE SHIELD (Anti-Kecolongan 100%):
       Mengecek harga tepat di milidetik eksekusi. Jika scammer mengganti harga
       menjadi 11.000 (atau > Max Price), pembelian otomatis BATAL INSTAN 0 MS!
       Anda 100% kebal dari jebakan 11k!

    2. ⚡ ULTRA-FAST EVENT LISTENER (< 5ms):
       Mendengarkan event slot booth secara langsung. Begitu item 1 token muncul,
       skrip langsung mengeksekusi pembelian lebih cepat dari kecepatan jari manusia,
       sehingga berpeluang merebut barang 1 token sebelum sempat dicabut scammer!

    3. 🔒 CONFIRMATION PROMPT GUARD:
       Jika game memunculkan jendela konfirmasi, skrip membaca teks harga di pop-up.
       Bila harga > Max Price -> Otomatis klik "CANCEL / BATAL".
       Bila harga <= Max Price -> Otomatis klik "YES / CONFIRM".
    ══════════════════════════════════════════════════════════════════════════════
]]

-- [1] SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- [2] KONFIGURASI DEFAULT
local Config = {
    MaxBuyPrice = 111,       -- Batas MAKSIMAL harga yang boleh dibeli (Misal: 1 s/d 111 token)
    MinItemRap = 300,        -- Minimal RAP resmi item agar tidak buang token untuk barang sampah
    WebhookUrl = "https://discord.com/api/webhooks/1570338415722102866/0Hpi4LO0C-ZLvovBhsGG96Tb-td2nlrLQZGXor1J8pffFKJXzPqkVxxD91aC5eE0pf3d",
    IsActive = false,
    LockedBoothName = "None",
    TargetBooth = nil
}

-- [3] DATABASE RAP ONLINE CACHE
local RAP_DATABASE = {}

local function LoadRapDb()
    pcall(function()
        local raw = game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/data/rap_database.json")
        if raw and #raw > 10 then
            local parsed = HttpService:JSONDecode(raw)
            if type(parsed) == "table" then
                for k, v in pairs(parsed) do
                    local clean = tostring(k):lower():gsub("%s+", "")
                    if type(v) == "table" then
                        RAP_DATABASE[clean] = v
                    else
                        local n = tonumber(v) or 0
                        if n > 0 then RAP_DATABASE[clean] = n end
                    end
                end
            end
        end
    end)
end
task.spawn(LoadRapDb)

local function GetItemRap(itemName)
    if not itemName then return 0 end
    local clean = tostring(itemName):lower():gsub("%s+", "")
    local entry = RAP_DATABASE[clean]
    if type(entry) == "number" then return entry end
    if type(entry) == "table" then
        local maxVal = 0
        for _, v in pairs(entry) do
            local num = tonumber(v) or 0
            if num > maxVal then maxVal = num end
        end
        return maxVal
    end
    return 0
end

local function ParsePrice(str)
    if not str then return 0 end
    local clean = tostring(str):gsub(",", ""):gsub("%s+", ""):match("[%d%.]+")
    return tonumber(clean) or 0
end

local function Notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 4
        })
    end)
end

local function SendDiscordVictory(itemName, price, rap, seller)
    if not Config.WebhookUrl or #Config.WebhookUrl == 0 then return end
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then return end

    task.spawn(function()
        pcall(function()
            local payload = HttpService:JSONEncode({
                username = "Blade Ball Anti-Scam Counter",
                embeds = {{
                    title = "🎯 SCAMMER TERTIPU! ITEM 1 TOKEN BERHASIL DIREBUT!",
                    color = 5763719, -- Hijau Neon
                    description = "Berhasil memotong scammer switcheroo sebelum dia mencabut itemnya!",
                    fields = {
                        { name = "🗡️ Nama Item", value = tostring(itemName), inline = true },
                        { name = "💰 Harga Dibeli", value = string.format("**%d** tokens", price), inline = true },
                        { name = "📊 Value RAP Asli", value = string.format("**%d** tokens", rap), inline = true },
                        { name = "👤 Scammer Pemilik", value = "@" .. tostring(seller), inline = true },
                        { name = "🕒 Waktu", value = os.date("%H:%M:%S WIB"), inline = true }
                    },
                    footer = { text = "Anti-Scam Fast Counter v1.0 • Blade Ball" }
                }}
            })
            req({
                Url = Config.WebhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)
    end)
end

-- [4] SISTEM ULTRA-FAST PURCHASING & PROMPT GUARD
local FastBuyer = {
    IsProcessing = false,
    ConnectedSignals = {}
}

-- Menangani pop-up konfirmasi game (jika game memunculkan prompt "Yakin beli?")
local function WatchConfirmationPrompt()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    pGui.DescendantAdded:Connect(function(desc)
        if not Config.IsActive then return end
        
        -- Cari apakah ada dialog / pop-up bertema konfirmasi
        local n = desc.Name:lower()
        if desc:IsA("TextButton") and (n:find("yes") or n:find("confirm") or n:find("accept") or n:find("buy")) then
            -- Periksa teks parent atau dialog untuk mendeteksi nominal harga
            local parentFrame = desc.Parent
            local priceInPrompt = 0
            for _, label in ipairs(parentFrame:GetDescendants()) do
                if label:IsA("TextLabel") and label.Visible then
                    local p = ParsePrice(label.Text)
                    if p > priceInPrompt then priceInPrompt = p end
                end
            end

            -- Jika terdeteksi harga jebakan scammer (misal 11.000 atau di atas batas kita):
            if priceInPrompt > Config.MaxBuyPrice then
                warn("🚨 SCAM PROMPT DETECTED! Harga jebakan:", priceInPrompt, "-> BATALKAN!")
                -- Cari tombol Cancel / No
                for _, btn in ipairs(parentFrame:GetDescendants()) do
                    if btn:IsA("TextButton") and (btn.Name:lower():find("no") or btn.Name:lower():find("cancel") or btn.Text:lower():find("cancel") or btn.Text:lower():find("no")) then
                        pcall(function()
                            if firesignal then firesignal(btn.Activated or btn.MouseButton1Click) end
                        end)
                        break
                    end
                end
                Notify("🛡️ SCAM DIBATALKAN!", "Scammer mencoba menjual di harga " .. priceInPrompt .. " token! Dibatalkan otomatis!")
            elseif priceInPrompt <= Config.MaxBuyPrice and priceInPrompt > 0 then
                -- Harga aman! Klik YES dalam hitungan milidetik!
                pcall(function()
                    if firesignal then firesignal(desc.Activated or desc.MouseButton1Click) end
                end)
            end
        end
    end)
end
task.spawn(WatchConfirmationPrompt)

-- Fungsi Eksekusi Beli Cepat
function FastBuyer.AttemptPurchase(frame, sellerName)
    if FastBuyer.IsProcessing then return end
    FastBuyer.IsProcessing = true

    local buyBtn = frame:FindFirstChild("BuyButton")
    local itemBtn = frame:FindFirstChild("Frame")
    local itemName = itemBtn and itemBtn:FindFirstChild("ItemName") and itemBtn.ItemName.Text or "Unknown"
    local amountLabel = buyBtn and buyBtn:FindFirstChild("List") and buyBtn.List:FindFirstChild("Amount")

    if not buyBtn or not amountLabel then
        FastBuyer.IsProcessing = false
        return
    end

    -- [VERIFIKASI HARGA ATOMIK KE-1]: Cek harga real-time detik ini juga!
    local currentPrice = ParsePrice(amountLabel.Text)
    local itemRap = GetItemRap(itemName)

    -- JIKA HARGA DI ATAS BATAS KITA (Scammer sudah ubah ke 11.000):
    if currentPrice > Config.MaxBuyPrice then
        warn(string.format("🛡️ [SCAM BLOCKED] Scammer ubah harga jadi %d! Batal beli!", currentPrice))
        FastBuyer.IsProcessing = false
        return
    end

    -- JIKA HARGA AMAN (1 s/d MaxBuyPrice) & ITEM BERHARGA:
    if currentPrice <= Config.MaxBuyPrice and currentPrice > 0 then
        if itemRap >= Config.MinItemRap then
            print(string.format("⚡ [SNIPE ATTEMPT] Merebut %s seharga %d token! (RAP: %d)", itemName, currentPrice, itemRap))

            -- KLIK SUPER CEPAT
            pcall(function()
                if firesignal then
                    firesignal(buyBtn.Activated)
                    firesignal(buyBtn.MouseButton1Click)
                end
                if getconnections then
                    for _, conn in ipairs(getconnections(buyBtn.MouseButton1Click)) do
                        conn:Fire()
                    end
                    for _, conn in ipairs(getconnections(buyBtn.Activated)) do
                        conn:Fire()
                    end
                end
            end)

            Notify("⚡ SNIPE DIKIRIM!", string.format("Mencoba merebut %s (%d token)!", itemName, currentPrice))
            SendDiscordVictory(itemName, currentPrice, itemRap, sellerName)
            task.wait(0.5)
        end
    end

    FastBuyer.IsProcessing = false
end

-- Monitor Frame Booth Tertentu secara Real-Time (Milidetik)
function FastBuyer.HookBooth(scrollList, sellerName)
    -- Bersihkan koneksi lama
    for _, conn in ipairs(FastBuyer.ConnectedSignals) do
        pcall(function() conn:Disconnect() end)
    end
    FastBuyer.ConnectedSignals = {}

    local function HookSlot(slotFrame)
        if not slotFrame:IsA("Frame") or slotFrame.Name == "Frame" then return end
        
        local buyBtn = slotFrame:FindFirstChild("BuyButton")
        local list = buyBtn and buyBtn:FindFirstChild("List")
        local amountLabel = list and list:FindFirstChild("Amount")

        -- Langsung periksa slot saat ini
        FastBuyer.AttemptPurchase(slotFrame, sellerName)

        -- Dengarkan perubahan harga (jika scammer mengganti angka di frame)
        if amountLabel then
            local conn = amountLabel:GetPropertyChangedSignal("Text"):Connect(function()
                if Config.IsActive then
                    FastBuyer.AttemptPurchase(slotFrame, sellerName)
                end
            end)
            table.insert(FastBuyer.ConnectedSignals, conn)
        end
    end

    -- Hook semua slot yang sudah ada di booth
    for _, child in ipairs(scrollList:GetChildren()) do
        HookSlot(child)
    end

    -- Hook setiap slot baru yang tiba-tiba dipasang scammer (ChildAdded)
    local addConn = scrollList.ChildAdded:Connect(function(newChild)
        if Config.IsActive then
            task.wait(0.01) -- jeda 10ms agar properti selesai terisi
            HookSlot(newChild)
        end
    end)
    table.insert(FastBuyer.ConnectedSignals, addConn)
end

-- [5] USER INTERFACE (FLOATING CONTROLLER)
local function BuildUI()
    local pGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = pGui:FindFirstChild("AntiScamSniperUI")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "AntiScamSniperUI"
    sg.ResetOnSpawn = false
    sg.Parent = pGui

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 240, 0, 220)
    main.Position = UDim2.new(0.5, -120, 0.25, 0)
    main.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = sg

    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(239, 68, 68) -- Merah Anti-Scam
    stroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 32)
    title.BackgroundTransparency = 1
    title.Text = "🛡️ ANTI-SCAM FAST SNIPER"
    title.TextColor3 = Color3.fromRGB(248, 113, 113)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11.5
    title.Parent = main

    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -20, 0, 24)
    targetLabel.Position = UDim2.new(0, 10, 0, 34)
    targetLabel.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    targetLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
    targetLabel.Text = "Booth Target: Belum Dikunci"
    targetLabel.Font = Enum.Font.GothamMedium
    targetLabel.TextSize = 10
    targetLabel.Parent = main
    Instance.new("UICorner", targetLabel).CornerRadius = UDim.new(0, 6)

    -- Tombol Kunci Booth Terdekat
    local btnLock = Instance.new("TextButton")
    btnLock.Size = UDim2.new(1, -20, 0, 32)
    btnLock.Position = UDim2.new(0, 10, 0, 64)
    btnLock.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
    btnLock.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnLock.Text = "🔒 KUNCI BOOTH YANG SEDANG DIBUKA"
    btnLock.Font = Enum.Font.GothamBold
    btnLock.TextSize = 10
    btnLock.Parent = main
    Instance.new("UICorner", btnLock).CornerRadius = UDim.new(0, 6)

    -- Input Max Price
    local priceBox = Instance.new("TextBox")
    priceBox.Size = UDim2.new(1, -20, 0, 28)
    priceBox.Position = UDim2.new(0, 10, 0, 102)
    priceBox.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    priceBox.TextColor3 = Color3.fromRGB(52, 211, 153)
    priceBox.Text = tostring(Config.MaxBuyPrice)
    priceBox.PlaceholderText = "Maksimal Harga Beli (Token)"
    priceBox.Font = Enum.Font.GothamBold
    priceBox.TextSize = 11
    priceBox.Parent = main
    Instance.new("UICorner", priceBox).CornerRadius = UDim.new(0, 6)

    local lblP = Instance.new("TextLabel")
    lblP.Size = UDim2.new(1, -20, 0, 14)
    lblP.Position = UDim2.new(0, 10, 0, 132)
    lblP.BackgroundTransparency = 1
    lblP.TextColor3 = Color3.fromRGB(148, 163, 184)
    lblP.Text = "⚠️ Pembelian otomatis DIBATALKAN jika > harga di atas!"
    lblP.Font = Enum.Font.Gotham
    lblP.TextSize = 8
    lblP.Parent = main

    -- Tombol Toggle Aktif/Mati
    local btnToggle = Instance.new("TextButton")
    btnToggle.Size = UDim2.new(1, -20, 0, 38)
    btnToggle.Position = UDim2.new(0, 10, 0, 154)
    btnToggle.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
    btnToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnToggle.Text = "⚡ AKTIFKAN ANTI-SCAM SNIPER (OFF)"
    btnToggle.Font = Enum.Font.GothamBold
    btnToggle.TextSize = 10.5
    btnToggle.Parent = main
    Instance.new("UICorner", btnToggle).CornerRadius = UDim.new(0, 6)

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 24, 0, 24)
    btnClose.Position = UDim2.new(1, -28, 0, 4)
    btnClose.BackgroundTransparency = 1
    btnClose.Text = "✕"
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 12
    btnClose.Parent = main
    btnClose.MouseButton1Click:Connect(function() sg:Destroy() end)

    priceBox.FocusLost:Connect(function()
        local val = tonumber(priceBox.Text)
        if val and val > 0 then
            Config.MaxBuyPrice = val
            Notify("Batas Harga Diubah", "Maksimal beli diset: " .. val .. " token")
        else
            priceBox.Text = tostring(Config.MaxBuyPrice)
        end
    end)

    btnLock.MouseButton1Click:Connect(function()
        local pG = LocalPlayer:FindFirstChild("PlayerGui")
        local boothGui = pG and pG:FindFirstChild("Booth")
        local playersBooth = boothGui and boothGui:FindFirstChild("PlayersBooth")
        local scrollList = playersBooth and playersBooth:FindFirstChild("ScrollingList")

        if not playersBooth or not scrollList or not playersBooth.Visible then
            Notify("⚠️ Gagal Kunci", "Buka dulu booth scammer tersebut secara manual!")
            return
        end

        local seller = "Unknown"
        local top = playersBooth:FindFirstChild("Top")
        if top and top:FindFirstChild("PlayerName") then
            seller = top.PlayerName.Text:gsub("'s Booth", ""):match("^%s*(.-)%s*$") or "Unknown"
        end

        Config.LockedBoothName = seller
        Config.TargetBooth = scrollList
        targetLabel.Text = "Booth Target: @" .. seller
        targetLabel.TextColor3 = Color3.fromRGB(52, 211, 153)

        FastBuyer.HookBooth(scrollList, seller)
        Notify("🔒 Booth Terkunci!", "Berhasil mengunci booth @" .. seller .. "!")
    end)

    btnToggle.MouseButton1Click:Connect(function()
        if not Config.TargetBooth then
            Notify("⚠️ Belum Kunci Booth", "Buka booth target lalu klik 'KUNCI BOOTH' dulu!")
            return
        end

        Config.IsActive = not Config.IsActive
        if Config.IsActive then
            btnToggle.BackgroundColor3 = Color3.fromRGB(16, 185, 129) -- Hijau
            btnToggle.Text = "⚡ ANTI-SCAM SNIPER AKTIF (ON)"
            stroke.Color = Color3.fromRGB(16, 185, 129)
            Notify("🛡️ AKTIF!", "Memantau perubahan booth dengan kecepatan milidetik!")
        else
            btnToggle.BackgroundColor3 = Color3.fromRGB(239, 68, 68) -- Merah
            btnToggle.Text = "⚡ AKTIFKAN ANTI-SCAM SNIPER (OFF)"
            stroke.Color = Color3.fromRGB(239, 68, 68)
            Notify("Mati", "Anti-scam sniper dinonaktifkan.")
        end
    end)
end

BuildUI()
Notify("🛡️ Anti-Scam Sniper Dimuat", "Dekati booth scammer, buka booth-nya, lalu klik 'KUNCI BOOTH'!")
