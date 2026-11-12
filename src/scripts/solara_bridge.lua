--[[
    =================================================================================
    ⚔️ BLADE BALL PLAZA SNIPER - UNDER RAP & SERVER HOPPER (2026 EDITION)
    =================================================================================
    Arsitektur baru dibangun dari nol, khusus untuk Roblox Delta di Emulator PC.
    
    Tujuan Utama:
    1. Scan seluruh booth di Trade Plaza untuk mencari item UNDER RAP (Harga < RAP).
    2. Tampilkan daftar deal lengkap dengan estimasi profit & diskon persen.
    3. 1-Tap Teleport ke depan booth penjual untuk langsung beli sebelum orang lain.
    4. Cari pedang spesifik (misal: Prince Blade) & auto-hop jika tidak ada di server ini.
    5. Server Hopper instan (Acak / Ramai / Sepi) + Auto-Hop jika server sepi deal.
    =================================================================================
--]]

-- [1] SERVICES
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- [2] DATABASE NILAI RAP BASELINE (PEDANG & EXPLOSION POPULER)
local RAP_DATABASE = {
    ["wavelight"] = 360,
    ["wavelight greatblade"] = 360,
    ["prince blade"] = 3018,
    ["dark blade"] = 1000,
    ["base sword"] = 50,
    ["dragon blade"] = 12500,
    ["cyber scythe"] = 8500,
    ["supernova"] = 14000,
    ["sakura bloom"] = 2100,
    ["singularity katana"] = 18000,
    ["aetherial azure katana"] = 12000,
    ["abyssal blade"] = 2500,
    ["astral seraph blade"] = 3600,
    ["arachne blade"] = 400,
    ["bone"] = 120,
    ["pickaxe"] = 250,
    ["melon slice"] = 350,
    ["kitchen knife"] = 400,
    ["tanto"] = 600,
    ["battle axe"] = 750,
    ["baseball bat"] = 800,
    ["emerald warden blade"] = 1800,
    ["massive lollipop"] = 2200,
    ["rapier"] = 3200,
    ["bonsai tree"] = 4500,
    ["blocky sword"] = 5000,
    ["infinity katana"] = 45000,
    ["glitch katana"] = 3200,
    ["aetheria"] = 62000,
    ["dual katana"] = 150,
    ["shadow scythe"] = 9800,
    ["black hole"] = 55000,
    ["giggle emote"] = 400,
    ["inferno blade"] = 21800,
    ["void scythe"] = 44800
}

-- [3] MODULE: UTILITIES
local Util = {}

function Util.FormatNumber(val)
    local n = tonumber(val) or 0
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

function Util.ParsePrice(text)
    if not text then return 0 end
    local str = tostring(text):lower():gsub(",", ""):gsub("%s+", "")
    local num, suffix = str:match("(%d+%.?%d*)([km]?)")
    if not num then return 0 end
    local val = tonumber(num) or 0
    if suffix == "k" then val = val * 1000
    elseif suffix == "m" then val = val * 1000000 end
    return math.floor(val)
end

function Util.Notify(title, message, isSpecial)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = message,
            Duration = isSpecial and 6 or 4
        })
    end)
end

function Util.PlayChime()
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://6895079853"
        s.Volume = 1
        s.Parent = SoundService
        s:Play()
        task.delay(2, function() s:Destroy() end)
    end)
end

function Util.UnfreezePlayer()
    pcall(function()
        local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
        PlayerModule:GetControls():Enable()
    end)
end

function Util.SyncBbValues()
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    local loadedLive = false

    -- [Metode 1]: Tarik LIVE langsung dari API bbvalues.uk via executor
    if req then
        pcall(function()
            local res = req({
                Url = "https://bbvalues.uk/api/items",
                Method = "GET",
                Headers = {
                    ["x-bbv-handshake"] = "v1-secure-request",
                    ["Accept"] = "application/json",
                    ["Referer"] = "https://bbvalues.uk/values/",
                    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
                }
            })
            if res and (res.StatusCode == 200 or res.Status == 200) and res.Body then
                local items = HttpService:JSONDecode(res.Body)
                if type(items) == "table" and #items > 500 then
                    local count = 0
                    for _, it in ipairs(items) do
                        local val = (it.p and tonumber(it.p) > 0) and tonumber(it.p) or (tonumber(it.a) or 0)
                        if it.n and val > 0 then
                            local cleanKey = tostring(it.n):lower():gsub("%s+", "")
                            RAP_DATABASE[cleanKey] = val
                            count = count + 1
                        end
                    end
                    loadedLive = true
                    Util.Notify("⚡ LIVE bbvalues.uk", string.format("Langsung sinkron %s item real-time!", Util.FormatNumber(count)))
                end
            end
        end)
    end

    -- [Metode 2]: Fallback Cloud Database GitHub jika direct request diblokir
    if not loadedLive then
        pcall(function()
            local rawJson = game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/data/rap_database.json")
            if rawJson and #rawJson > 10 then
                local parsed = HttpService:JSONDecode(rawJson)
                if type(parsed) == "table" then
                    local count = 0
                    for k, v in pairs(parsed) do
                        local cleanKey = tostring(k):lower():gsub("%s+", "")
                        RAP_DATABASE[cleanKey] = tonumber(v) or 0
                        count = count + 1
                    end
                    Util.Notify("📊 Cloud Database", string.format("Memuat %s item pasar resmi!", Util.FormatNumber(count)))
                end
            end
        end)
    end
end

-- Jalankan sinkronisasi nilai otomatis saat script aktif
task.spawn(Util.SyncBbValues)

-- [4] MODULE: TELEPORT & SERVER HOPPING
local Navigator = {}

function Navigator.TeleportToStand(standInstance)
    if not standInstance then return false end
    local root = standInstance:FindFirstChild("Root") or standInstance:FindFirstChildWhichIsA("BasePart")
    if root and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = root.CFrame * CFrame.new(0, 3, 5)
        Util.Notify("🚀 Teleport", "Karakter dipindahkan ke depan booth penjual!")
        return true
    end
    return false
end

function Navigator.ServerHop(minPlayers, maxPlayers)
    minPlayers = minPlayers or 6
    maxPlayers = maxPlayers or 26
    Util.Notify("🌐 Server Hop", "Mencari server Trade Plaza yang aktif...", true)

    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if req then
        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(PlaceId))
        local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
        if ok and res and res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.data then
                local candidates = {}
                for _, s in ipairs(data.data) do
                    if type(s) == "table" and s.id ~= JobId and s.playing and s.maxPlayers then
                        local p = tonumber(s.playing) or 0
                        local m = tonumber(s.maxPlayers) or 30
                        if (m - p >= 2) and (p >= minPlayers and p <= maxPlayers) then
                            table.insert(candidates, s.id)
                        end
                    end
                end
                if #candidates > 0 then
                    local targetServer = candidates[math.random(1, #candidates)]
                    TeleportService:TeleportToPlaceInstance(PlaceId, targetServer, LocalPlayer)
                    return
                end
            end
        end
    end

    TeleportService:Teleport(PlaceId, LocalPlayer)
end

-- [5] MODULE: PLAZA BOOTH SCANNER & DEAL ENGINE
local PlazaEngine = {
    IsScanning = false,
    AllListings = {},
    UnderRapDeals = {},
    AutoHopWhenEmpty = false
}

function PlazaEngine.IsQualifiedDeal(rap, price)
    if not rap or rap <= 0 or not price or price <= 0 then return false end
    local profit = rap - price
    if profit <= 0 then return false end

    -- [Kriteria 1]: Item Value 400 - 1500 -> Tampilkan jika under 100 keatas (profit >= 100)
    if rap >= 400 and rap <= 1500 then
        return profit >= 100
    end

    -- [Kriteria 2]: Item Value 1600 - 5000 -> Tampilkan jika under 200 keatas (profit >= 200)
    if rap > 1500 and rap <= 5000 then
        return profit >= 200
    end

    -- [Kriteria 3]: Item Value > 5000 (High-Tier) -> Tampilkan jika under 200 keatas
    if rap > 5000 then
        return profit >= 200
    end

    -- Item value < 400 diabaikan agar radar bebas dari spam item receh
    return false
end

function PlazaEngine.GetRapValue(itemName)
    if not itemName or #itemName == 0 then return 0 end
    local clean = itemName:lower():gsub("%s+", "")
    
    -- 1. Exact direct match (Prioritas Utama)
    if RAP_DATABASE[clean] then 
        return RAP_DATABASE[clean] 
    end
    
    -- 2. Exact match against database keys (mencegah salah deteksi substring)
    for k, v in pairs(RAP_DATABASE) do
        local cleanKey = tostring(k):lower():gsub("%s+", "")
        if clean == cleanKey then
            return v
        end
    end
    
    return 0 -- Kembalikan 0 jika tidak ada di database (agar tidak terjadi false deal)
end

function PlazaEngine.ScanAllBooths(statusCallback)
    if PlazaEngine.IsScanning then return end
    PlazaEngine.IsScanning = true

    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then PlazaEngine.IsScanning = false return end

    local boothGui = pGui:FindFirstChild("Booth")
    local playersBooth = boothGui and boothGui:FindFirstChild("PlayersBooth")
    if not playersBooth then
        Util.Notify("⚠️ Perhatian", "Buka Trade Plaza dulu untuk mulai scan!")
        PlazaEngine.IsScanning = false
        if statusCallback then statusCallback("Belum di Trade Plaza!") end
        return
    end

    local standsFolder = workspace:FindFirstChild("Spawn")
        and workspace.Spawn:FindFirstChild("Hub")
        and workspace.Spawn.Hub:FindFirstChild("Stands")

    if not standsFolder then
        Util.Notify("⚠️ Error", "Folder Stands tidak ditemukan di Workspace!")
        PlazaEngine.IsScanning = false
        return
    end

    local stands = standsFolder:GetChildren()
    local activeStands = {}
    for _, st in ipairs(stands) do
        if st:GetAttribute("Owner") ~= nil then
            table.insert(activeStands, st)
        end
    end

    local foundListings = {}
    local deals = {}

    if statusCallback then
        statusCallback(string.format("Memindai %d booth aktif...", #activeStands))
    end

    for i, stand in ipairs(activeStands) do
        pcall(function()
            local root = stand:FindFirstChild("Root")
            local holder = root and root:FindFirstChild("ProximityPromptHolder")
            local prompt = holder and holder:FindFirstChildWhichIsA("ProximityPrompt")

            if prompt then
                if statusCallback then
                    statusCallback(string.format("Booth %d/%d...", i, #activeStands))
                end

                -- Buka booth
                local promptFired = pcall(function() fireproximityprompt(prompt) end)
                if not promptFired then
                    pcall(function() prompt:InputHoldBegin() task.wait(0.2) prompt:InputHoldEnd() end)
                end

                -- Tunggu ScrollingList termuat
                local waited = 0
                local scrollList = playersBooth:FindFirstChild("ScrollingList")
                while waited < 2 do
                    if scrollList then
                        local count = 0
                        for _, c in ipairs(scrollList:GetChildren()) do
                            if c:IsA("Frame") and c.Name ~= "Frame" then count = count + 1 end
                        end
                        if count > 0 then break end
                    end
                    task.wait(0.2)
                    waited = waited + 0.2
                end

                -- Ambil Nama Penjual
                local sellerName = "Unknown"
                local top = playersBooth:FindFirstChild("Top")
                if top and top:FindFirstChild("PlayerName") then
                    sellerName = top.PlayerName.Text:gsub("'s Booth", ""):match("^%s*(.-)%s*$") or "Unknown"
                end

                -- Ambil Setiap Item
                if scrollList then
                    for _, frame in ipairs(scrollList:GetChildren()) do
                        if frame:IsA("Frame") and frame.Name ~= "Frame" then
                            local itemName, price = "", 0

                            local itemBtn = frame:FindFirstChild("Frame")
                            if itemBtn and itemBtn:FindFirstChild("ItemName") then
                                itemName = itemBtn.ItemName.Text or ""
                            end

                            local buyBtn = frame:FindFirstChild("BuyButton")
                            if buyBtn and buyBtn:FindFirstChild("List") and buyBtn.List:FindFirstChild("Amount") then
                                price = Util.ParsePrice(buyBtn.List.Amount.Text)
                            end

                            if #itemName > 0 and itemName ~= "ItemName" and price > 0 then
                                local rap = PlazaEngine.GetRapValue(itemName)
                                local profit = (rap > 0) and (rap - price) or 0
                                local discountPct = (rap > 0) and math.floor(((rap - price) / rap) * 100) or 0
                                local isQualified = PlazaEngine.IsQualifiedDeal(rap, price)

                                local listing = {
                                    Name = itemName,
                                    Price = price,
                                    RAP = rap,
                                    Profit = profit,
                                    Discount = discountPct,
                                    IsUnderRap = isQualified,
                                    Seller = sellerName,
                                    Stand = stand
                                }

                                table.insert(foundListings, listing)

                                if isQualified then
                                    table.insert(deals, listing)
                                end
                            end
                        end
                    end
                end

                -- Tutup booth UI
                pcall(function()
                    local closeBtn = playersBooth:FindFirstChild("Close")
                    if closeBtn and closeBtn:IsA("ImageButton") then closeBtn.MouseButton1Click:Fire() end
                end)
                Util.UnfreezePlayer()
                task.wait(0.2)
            end
        end)
    end

    -- Urutkan dari profit tertinggi
    table.sort(deals, function(a, b) return a.Profit > b.Profit end)

    PlazaEngine.AllListings = foundListings
    PlazaEngine.UnderRapDeals = deals
    PlazaEngine.IsScanning = false

    if #deals > 0 then
        Util.PlayChime()
        local best = deals[1]
        Util.Notify(
            "🔥 " .. #deals .. " DEAL UNDER RAP!",
            string.format("%s dijual %s (RAP %s, Untung +%s!)", best.Name, Util.FormatNumber(best.Price), Util.FormatNumber(best.RAP), Util.FormatNumber(best.Profit)),
            true
        )
    else
        Util.Notify("Scan Selesai", string.format("Memeriksa %d item. Tidak ada under RAP di server ini.", #foundListings))
        if PlazaEngine.AutoHopWhenEmpty and #activeStands >= 6 then
            Util.Notify("🚀 Auto-Hop", "Server kosong deal, melompat ke server baru...", true)
            task.wait(2)
            Navigator.ServerHop()
        end
    end

    if statusCallback then statusCallback("Scan Selesai!") end
end

-- [6] MODULE: TAMPILAN MODERN DELTA TOUCH UI
local UI = {}

function UI.Build()
    local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pGui then return end

    local old = pGui:FindFirstChild("BBPlazaSniperV9")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BBPlazaSniperV9"
    sg.ResetOnSpawn = false
    sg.Parent = pGui

    -- FLOATING TOGGLE BUBBLE (UNTUK EMULATOR SENTUH)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBubble"
    toggleBtn.Size = UDim2.new(0, 48, 0, 48)
    toggleBtn.Position = UDim2.new(0.015, 0, 0.45, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    toggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
    toggleBtn.Text = "⚔️"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 22
    toggleBtn.Active = true
    toggleBtn.Draggable = true
    toggleBtn.Parent = sg
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local tStroke = Instance.new("UIStroke", toggleBtn)
    tStroke.Color = Color3.fromRGB(99, 102, 241)
    tStroke.Thickness = 2

    -- CONTAINER UTAMA
    local main = Instance.new("Frame")
    main.Name = "MainWindow"
    main.Size = UDim2.new(0, 360, 0, 430)
    main.Position = UDim2.new(0.08, 0, 0.15, 0)
    main.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

    local mStroke = Instance.new("UIStroke", main)
    mStroke.Color = Color3.fromRGB(99, 102, 241)
    mStroke.Thickness = 1.6

    toggleBtn.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    -- HEADER
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 46)
    header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 14)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 0, 24)
    title.Position = UDim2.new(0, 14, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "⚔️ PLAZA SNIPER <font color='#38bdf8'>v9.0</font>"
    title.RichText = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -60, 0, 16)
    sub.Position = UDim2.new(0, 14, 0, 24)
    sub.BackgroundTransparency = 1
    sub.Text = "🎯 Val 400-1500 (Under ≥100) | 1600+ (Under ≥200)"
    sub.TextColor3 = Color3.fromRGB(52, 211, 153)
    sub.Font = Enum.Font.GothamBold
    sub.TextSize = 8.5
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = header

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 28, 0, 28)
    btnClose.Position = UDim2.new(1, -36, 0, 9)
    btnClose.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.Text = "✕"
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 12
    btnClose.Parent = header
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)
    btnClose.MouseButton1Click:Connect(function() main.Visible = false end)

    -- TAB BAR
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 34)
    tabBar.Position = UDim2.new(0, 10, 0, 52)
    tabBar.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    tabBar.Parent = main
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 8)

    local function makeTab(txt, xPos, w)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(w, -4, 1, -4)
        b.Position = UDim2.new(xPos, 2, 0, 2)
        b.BackgroundColor3 = Color3.fromRGB(24, 32, 53)
        b.TextColor3 = Color3.fromRGB(148, 163, 184)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Parent = tabBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end

    local tabDeals = makeTab("💎 Deals (0)", 0, 0.33)
    local tabHunt = makeTab("🎯 Cari Pedang", 0.33, 0.33)
    local tabHop = makeTab("🌐 Server Hop", 0.66, 0.34)

    -- CONTAINER KONTEN
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -145)
    content.Position = UDim2.new(0, 10, 0, 92)
    content.BackgroundTransparency = 1
    content.Parent = main

    -- FOOTER
    local footer = Instance.new("Frame")
    footer.Size = UDim2.new(1, -20, 0, 42)
    footer.Position = UDim2.new(0, 10, 1, -48)
    footer.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    footer.Parent = main
    Instance.new("UICorner", footer).CornerRadius = UDim.new(0, 8)

    local btnScan = Instance.new("TextButton")
    btnScan.Size = UDim2.new(0.55, -4, 1, -8)
    btnScan.Position = UDim2.new(0, 4, 0, 4)
    btnScan.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
    btnScan.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnScan.Text = "⚡ SCAN SEMUA BOOTH"
    btnScan.Font = Enum.Font.GothamBold
    btnScan.TextSize = 10
    btnScan.Parent = footer
    Instance.new("UICorner", btnScan).CornerRadius = UDim.new(0, 6)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0.45, -6, 1, 0)
    statusLabel.Position = UDim2.new(0.55, 4, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Siap scan plaza..."
    statusLabel.TextColor3 = Color3.fromRGB(52, 211, 153)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextWrapped = true
    statusLabel.Parent = footer

    -- [PANEL 1: DAFTAR UNDER RAP DEALS]
    local paneDeals = Instance.new("ScrollingFrame")
    paneDeals.Size = UDim2.new(1, 0, 1, 0)
    paneDeals.BackgroundTransparency = 1
    paneDeals.ScrollBarThickness = 3
    paneDeals.Parent = content
    local dealsLayout = Instance.new("UIListLayout", paneDeals)
    dealsLayout.Padding = UDim.new(0, 6)

    local function updateDealsUI()
        for _, c in ipairs(paneDeals:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        tabDeals.Text = "💎 Deals (" .. #PlazaEngine.UnderRapDeals .. ")"

        if #PlazaEngine.UnderRapDeals == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 0, 140)
            empty.BackgroundTransparency = 1
            empty.TextColor3 = Color3.fromRGB(148, 163, 184)
            empty.Text = "Belum ada deal sesuai kriteria filter:\n• Value 400 - 1500 (Under ≥ 100)\n• Value 1600 - 5000 (Under ≥ 200)\n• Value > 5000 (Under ≥ 200)\n\nTekan '⚡ SCAN SEMUA BOOTH' di bawah!"
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 9.5
            empty.Parent = paneDeals
            return
        end

        for _, d in ipairs(PlazaEngine.UnderRapDeals) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -6, 0, 68)
            card.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
            card.Parent = paneDeals
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

            local cStroke = Instance.new("UIStroke", card)
            cStroke.Color = Color3.fromRGB(16, 185, 129)
            cStroke.Thickness = 1.2

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, -95, 0, 18)
            nl.Position = UDim2.new(0, 8, 0, 4)
            nl.BackgroundTransparency = 1
            nl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nl.Text = d.Name
            nl.Font = Enum.Font.GothamBold
            nl.TextSize = 11
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.Parent = card

            local tag = Instance.new("TextLabel")
            tag.Size = UDim2.new(0, 80, 0, 18)
            tag.Position = UDim2.new(1, -86, 0, 4)
            tag.BackgroundColor3 = Color3.fromRGB(5, 150, 105)
            tag.TextColor3 = Color3.fromRGB(255, 255, 255)
            tag.Text = string.format("🔥 -%d%% OFF", d.Discount)
            tag.Font = Enum.Font.GothamBold
            tag.TextSize = 9
            tag.Parent = card
            Instance.new("UICorner", tag).CornerRadius = UDim.new(0, 4)

            local pl = Instance.new("TextLabel")
            pl.Size = UDim2.new(1, -100, 0, 18)
            pl.Position = UDim2.new(0, 8, 0, 23)
            pl.BackgroundTransparency = 1
            pl.TextColor3 = Color3.fromRGB(203, 213, 225)
            pl.Text = string.format("Harga: <font color='#38bdf8'><b>%s</b></font> | RAP: <b>%s</b>", Util.FormatNumber(d.Price), Util.FormatNumber(d.RAP))
            pl.RichText = true
            pl.Font = Enum.Font.Gotham
            pl.TextSize = 10
            pl.TextXAlignment = Enum.TextXAlignment.Left
            pl.Parent = card

            local sl = Instance.new("TextLabel")
            sl.Size = UDim2.new(1, -100, 0, 16)
            sl.Position = UDim2.new(0, 8, 0, 44)
            sl.BackgroundTransparency = 1
            sl.TextColor3 = Color3.fromRGB(52, 211, 153)
            sl.Text = string.format("Profit: +%s • Penjual: @%s", Util.FormatNumber(d.Profit), d.Seller)
            sl.Font = Enum.Font.Gotham
            sl.TextSize = 9
            sl.TextXAlignment = Enum.TextXAlignment.Left
            sl.Parent = card

            local btnTp = Instance.new("TextButton")
            btnTp.Size = UDim2.new(0, 80, 0, 32)
            btnTp.Position = UDim2.new(1, -86, 0, 26)
            btnTp.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
            btnTp.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnTp.Text = "🚀 TP BOOTH"
            btnTp.Font = Enum.Font.GothamBold
            btnTp.TextSize = 9
            btnTp.Parent = card
            Instance.new("UICorner", btnTp).CornerRadius = UDim.new(0, 6)

            btnTp.MouseButton1Click:Connect(function()
                Navigator.TeleportToStand(d.Stand)
            end)
        end
        paneDeals.CanvasSize = UDim2.new(0, 0, 0, #PlazaEngine.UnderRapDeals * 74)
    end

    -- [PANEL 2: CARI PEDANG SPESIFIK]
    local paneHunt = Instance.new("Frame")
    paneHunt.Size = UDim2.new(1, 0, 1, 0)
    paneHunt.BackgroundTransparency = 1
    paneHunt.Visible = false
    paneHunt.Parent = content

    local huntInput = Instance.new("TextBox")
    huntInput.Size = UDim2.new(1, 0, 0, 34)
    huntInput.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
    huntInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    huntInput.PlaceholderText = "Ketik nama pedang target (mis: Prince Blade)..."
    huntInput.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
    huntInput.Font = Enum.Font.Gotham
    huntInput.TextSize = 10
    huntInput.ClearTextOnFocus = false
    huntInput.Parent = paneHunt
    Instance.new("UICorner", huntInput).CornerRadius = UDim.new(0, 6)

    local btnDoHunt = Instance.new("TextButton")
    btnDoHunt.Size = UDim2.new(1, 0, 0, 30)
    btnDoHunt.Position = UDim2.new(0, 0, 0, 40)
    btnDoHunt.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
    btnDoHunt.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnDoHunt.Text = "🔍 CARI DI SERVER INI"
    btnDoHunt.Font = Enum.Font.GothamBold
    btnDoHunt.TextSize = 10
    btnDoHunt.Parent = paneHunt
    Instance.new("UICorner", btnDoHunt).CornerRadius = UDim.new(0, 6)

    local huntResultBox = Instance.new("ScrollingFrame")
    huntResultBox.Size = UDim2.new(1, 0, 1, -78)
    huntResultBox.Position = UDim2.new(0, 0, 0, 76)
    huntResultBox.BackgroundTransparency = 1
    huntResultBox.ScrollBarThickness = 3
    huntResultBox.Parent = paneHunt
    Instance.new("UIListLayout", huntResultBox).Padding = UDim.new(0, 6)

    local function runSearch()
        local q = huntInput.Text:match("^%s*(.-)%s*$")
        if not q or #q == 0 then return end
        local qLower = q:lower():gsub("%s+", "")

        for _, c in ipairs(huntResultBox:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        local matches = {}
        for _, it in ipairs(PlazaEngine.AllListings) do
            if it.Name:lower():gsub("%s+", ""):find(qLower, 1, true) then
                table.insert(matches, it)
            end
        end

        if #matches == 0 then
            local empty = Instance.new("Frame")
            empty.Size = UDim2.new(1, 0, 0, 130)
            empty.BackgroundTransparency = 1
            empty.Parent = huntResultBox

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, 0, 0, 50)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = Color3.fromRGB(244, 63, 94)
            txt.Text = string.format("❌ '%s' tidak ditemukan di server ini!", q)
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 10
            txt.Parent = empty

            local btnHop = Instance.new("TextButton")
            btnHop.Size = UDim2.new(1, -20, 0, 36)
            btnHop.Position = UDim2.new(0, 10, 0, 55)
            btnHop.BackgroundColor3 = Color3.fromRGB(14, 165, 233)
            btnHop.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnHop.Text = "🌐 SERVER HOP (Cari di Server Lain)"
            btnHop.Font = Enum.Font.GothamBold
            btnHop.TextSize = 10
            btnHop.Parent = empty
            Instance.new("UICorner", btnHop).CornerRadius = UDim.new(0, 6)
            btnHop.MouseButton1Click:Connect(function() Navigator.ServerHop() end)
            return
        end

        for _, m in ipairs(matches) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -4, 0, 64)
            card.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
            card.Parent = huntResultBox
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, -90, 0, 18)
            nl.Position = UDim2.new(0, 8, 0, 4)
            nl.BackgroundTransparency = 1
            nl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nl.Text = m.Name
            nl.Font = Enum.Font.GothamBold
            nl.TextSize = 11
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.Parent = card

            local pl = Instance.new("TextLabel")
            pl.Size = UDim2.new(1, -90, 0, 18)
            pl.Position = UDim2.new(0, 8, 0, 22)
            pl.BackgroundTransparency = 1
            pl.TextColor3 = Color3.fromRGB(56, 189, 248)
            pl.Text = string.format("Harga: %s (RAP: %s)", Util.FormatNumber(m.Price), Util.FormatNumber(m.RAP))
            pl.Font = Enum.Font.Gotham
            pl.TextSize = 10
            pl.TextXAlignment = Enum.TextXAlignment.Left
            pl.Parent = card

            local sl = Instance.new("TextLabel")
            sl.Size = UDim2.new(1, -90, 0, 16)
            sl.Position = UDim2.new(0, 8, 0, 42)
            sl.BackgroundTransparency = 1
            sl.TextColor3 = m.IsUnderRap and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(148, 163, 184)
            sl.Text = m.IsUnderRap and string.format("✨ UNDER RAP (-%d%%)! Seller: @%s", m.Discount, m.Seller) or ("Penjual: @" .. m.Seller)
            sl.Font = Enum.Font.Gotham
            sl.TextSize = 9
            sl.TextXAlignment = Enum.TextXAlignment.Left
            sl.Parent = card

            local btnGo = Instance.new("TextButton")
            btnGo.Size = UDim2.new(0, 78, 0, 30)
            btnGo.Position = UDim2.new(1, -84, 0, 16)
            btnGo.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
            btnGo.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnGo.Text = "🚀 TP BOOTH"
            btnGo.Font = Enum.Font.GothamBold
            btnGo.TextSize = 9
            btnGo.Parent = card
            Instance.new("UICorner", btnGo).CornerRadius = UDim.new(0, 6)
            btnGo.MouseButton1Click:Connect(function() Navigator.TeleportToStand(m.Stand) end)
        end
        huntResultBox.CanvasSize = UDim2.new(0, 0, 0, #matches * 70)
    end

    btnDoHunt.MouseButton1Click:Connect(runSearch)
    huntInput.FocusLost:Connect(function(e) if e then runSearch() end end)

    -- [PANEL 3: SERVER HOPPER]
    local paneHop = Instance.new("Frame")
    paneHop.Size = UDim2.new(1, 0, 1, 0)
    paneHop.BackgroundTransparency = 1
    paneHop.Visible = false
    paneHop.Parent = content

    local function makeHopBtn(label, yPos, color, fn)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 38)
        b.Position = UDim2.new(0, 0, 0, yPos)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = label
        b.Font = Enum.Font.GothamBold
        b.TextSize = 10
        b.Parent = paneHop
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(fn)
    end

    makeHopBtn("🌐 HOP KE SERVER LAIN (ACAK)", 8, Color3.fromRGB(79, 70, 229), function() Navigator.ServerHop(5, 28) end)
    makeHopBtn("👥 HOP KE SERVER RAMAI (>18 Pemain)", 54, Color3.fromRGB(14, 165, 233), function() Navigator.ServerHop(18, 30) end)
    makeHopBtn("🟢 HOP KE SERVER SEPI (<12 Pemain)", 100, Color3.fromRGB(16, 185, 129), function() Navigator.ServerHop(3, 12) end)

    local autoHopBox = Instance.new("Frame")
    autoHopBox.Size = UDim2.new(1, 0, 0, 48)
    autoHopBox.Position = UDim2.new(0, 0, 0, 150)
    autoHopBox.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
    autoHopBox.Parent = paneHop
    Instance.new("UICorner", autoHopBox).CornerRadius = UDim.new(0, 8)

    local autoHopTxt = Instance.new("TextLabel")
    autoHopTxt.Size = UDim2.new(1, -70, 1, 0)
    autoHopTxt.Position = UDim2.new(0, 10, 0, 0)
    autoHopTxt.BackgroundTransparency = 1
    autoHopTxt.TextColor3 = Color3.fromRGB(203, 213, 225)
    autoHopTxt.Text = "Auto-Hop jika server ini kosong deal:"
    autoHopTxt.Font = Enum.Font.Gotham
    autoHopTxt.TextSize = 10
    autoHopTxt.TextXAlignment = Enum.TextXAlignment.Left
    autoHopTxt.Parent = autoHopBox

    local btnToggleHop = Instance.new("TextButton")
    btnToggleHop.Size = UDim2.new(0, 52, 0, 28)
    btnToggleHop.Position = UDim2.new(1, -60, 0, 10)
    btnToggleHop.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    btnToggleHop.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnToggleHop.Text = "OFF"
    btnToggleHop.Font = Enum.Font.GothamBold
    btnToggleHop.TextSize = 10
    btnToggleHop.Parent = autoHopBox
    Instance.new("UICorner", btnToggleHop).CornerRadius = UDim.new(0, 6)

    btnToggleHop.MouseButton1Click:Connect(function()
        PlazaEngine.AutoHopWhenEmpty = not PlazaEngine.AutoHopWhenEmpty
        btnToggleHop.Text = PlazaEngine.AutoHopWhenEmpty and "ON" or "OFF"
        btnToggleHop.BackgroundColor3 = PlazaEngine.AutoHopWhenEmpty and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(51, 65, 85)
        Util.Notify("Auto-Hop", PlazaEngine.AutoHopWhenEmpty and "Aktif! Otomatis hop jika tak ada deal." or "Dimatikan.")
    end)

    -- SWITCH TAB LOGIC
    local function setTab(activeBtn, targetPane)
        tabDeals.BackgroundColor3 = Color3.fromRGB(24, 32, 53)
        tabDeals.TextColor3 = Color3.fromRGB(148, 163, 184)
        tabHunt.BackgroundColor3 = Color3.fromRGB(24, 32, 53)
        tabHunt.TextColor3 = Color3.fromRGB(148, 163, 184)
        tabHop.BackgroundColor3 = Color3.fromRGB(24, 32, 53)
        tabHop.TextColor3 = Color3.fromRGB(148, 163, 184)

        paneDeals.Visible = false
        paneHunt.Visible = false
        paneHop.Visible = false

        activeBtn.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
        activeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        targetPane.Visible = true
    end

    tabDeals.MouseButton1Click:Connect(function() setTab(tabDeals, paneDeals) end)
    tabHunt.MouseButton1Click:Connect(function() setTab(tabHunt, paneHunt) end)
    tabHop.MouseButton1Click:Connect(function() setTab(tabHop, paneHop) end)
    setTab(tabDeals, paneDeals)

    -- TOMBOL SCAN HANDLER
    btnScan.MouseButton1Click:Connect(function()
        if PlazaEngine.IsScanning then return end
        btnScan.Text = "⏳ MEMINDAI..."
        btnScan.BackgroundColor3 = Color3.fromRGB(37, 99, 235)

        task.spawn(function()
            PlazaEngine.ScanAllBooths(function(msg)
                statusLabel.Text = msg
            end)
            btnScan.Text = "⚡ SCAN SEMUA BOOTH"
            btnScan.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
            updateDealsUI()
        end)
    end)

    return updateDealsUI
end

-- [7] BOOTSTRAP SCRIPT
local renderFn = UI.Build()
Util.UnfreezePlayer()

Util.Notify("⚔️ Plaza Sniper Ready", "Tekan tombol sentuh ⚔️ untuk membuka radar pasar!")
print("==========================================================")
print("⚔️ BLADE BALL PLAZA SNIPER (DELTA EMULATOR) BERHASIL AKTIF!")
print("==========================================================")

-- Scan otomatis pertama kali setelah script dieksekusi
task.spawn(function()
    task.wait(2)
    PlazaEngine.ScanAllBooths(function() end)
    if renderFn then renderFn() end
end)
