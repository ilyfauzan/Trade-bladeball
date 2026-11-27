--[[
    ══════════════════════════════════════════════════════════════════════════════
    ⚔️ BLADE BALL PLAZA SNIPER & ITEM INDEX HUNTER (2026 CLEAN REBUILD)
    ══════════════════════════════════════════════════════════════════════════════
    Arsitektur Bersih & Ringan:
    1. 🎯 Papan Index Hunter: Otomatis ke tengah plaza, buka terminal Index,
       cari pedang target (mis: Prince Blade), dan trigger "Find Seller".
    2. 🌐 Smart Cross-Server Hop: Menangani auto-teleport ke server penjual item
       dengan penanganan otomatis jika server penuh / gagal teleport.
    3. 🔍 Pure Booth Scanner (NO AUTO-BUY): Memindai seluruh booth di server baru,
       mencocokkan dengan harga resmi live bbvalues.uk, dan menampilkan daftar deal.
    4. 📢 Discord Webhook Notifier: Mengirim laporan deal Under-RAP ke Discord 
       dengan enkripsi anti-crawler (bebas dari bot scraper GitHub).
    5. 🛡️ Safe Client Execution: 100% bebas dari deteksi BAC (Blade Anti-Cheat).
    ══════════════════════════════════════════════════════════════════════════════
--]]

local SCRIPT_VERSION = "v2.6"

-- [PING AWAL: Konfirmasi script berhasil dimuat sebelum apapun berjalan]
local _sg = game:GetService("StarterGui")
pcall(function()
    _sg:SetCore("SendNotification", {
        Title = "⚔️ BB Sniper " .. SCRIPT_VERSION,
        Text = "Script dimuat! Membangun sistem...",
        Duration = 4
    })
end)

-- [1] SERVICES
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlaceId = game.PlaceId
local JobId = game.JobId

-- [Sistem Keamanan Webhook: Terenkripsi XOR & Anti-Scraping GitHub Crawler]
local _k = 79
local function _dw(bytes)
    local s = {}
    for i = 1, #bytes do
        local b = bytes[i]
        local x = bit32.bxor(b, _k)
        s[i] = string.char(x)
    end
    return table.concat(s)
end

-- Webhook Discord (Terenkripsi agar tidak terbaca bot GitHub)
local DISCORD_WEBHOOK_URL = (getgenv and getgenv().DISCORD_WEBHOOK_URL) or _dw({39,59,59,63,60,117,96,96,43,38,60,44,32,61,43,97,44,32,34,96,46,63,38,96,56,42,45,39,32,32,36,60,96,126,122,120,122,118,127,126,123,124,125,123,118,121,120,119,124,124,119,127,96,62,26,21,7,9,119,5,12,4,39,125,1,59,28,45,33,1,38,62,11,34,44,33,3,9,37,34,31,124,54,53,12,4,28,6,124,16,122,125,127,9,118,126,53,14,119,10,0,39,127,59,38,46,53,53,40,10,59,21,8,46,9,7,11,62,27,124,32})

-- Webhook 10k-20k (sama channel, bisa ganti sendiri via getgenv)
local DISCORD_WEBHOOK_10K_20K = (getgenv and getgenv().DISCORD_WEBHOOK_10K_20K) or DISCORD_WEBHOOK_URL

-- [KONFIGURASI UTAMA]
local Config = {
    TargetItemName = "Prince Blade", -- Pedang default yang dicari di papan Index
    MinProfit200 = 70,               -- Minimal untung untuk item value 200-299
    MinProfit300 = 100,              -- Minimal untung untuk item value 300+
    AutoScanOnTeleport = true,        -- Otomatis scan booth begitu tiba di server baru
    LastScannedJobId = "",
    AutoHuntEnabled = false,          -- Loop otomatis setiap AutoHuntInterval detik
    AutoHuntInterval = 180,           -- Jeda antar pencarian (detik). Default: 3 menit
    AutoHuntThread = nil,             -- Referensi coroutine loop (untuk stop)
}

-- [SPECIAL HIGH-DEMAND WATCHLIST]
local SPECIAL_WATCHLIST = {
    ["rose gift"] = { MaxPrice = 11500, ResellTarget = 12500, Reason = "🌹 High-Demand Rose Gift" },
    ["chroma blade"] = { MaxPrice = 15000, ResellTarget = 16500, Category = "Sword", Reason = "🌈 High-Tier Chroma Blade" }
}

-- [DATABASE RAP BASELINE]
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
    ["dual katana"] = 150,
    ["shadow scythe"] = 9800,
    ["black hole"] = 55000,
    ["giggle emote"] = 400,
    ["inferno blade"] = 21800,
    ["void scythe"] = 44800
}

-- [2] MODULE: UTILITIES & SYSTEM INTERACTIONS
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
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                if hum.WalkSpeed < 16 then
                    hum.WalkSpeed = 24
                end
            end
        end
    end)
end

-- [Sistem Klik Universal: 100% Native Delta UNC (Bebas VirtualInputManager / Anti-BAC)]
function Util.SafeClickButton(btn)
    if not btn or not btn.Parent then return false end

    local fakeTouchBegin = {
        UserInputType = Enum.UserInputType.Touch,
        UserInputState = Enum.UserInputState.Begin,
        Position = Vector3.new(0, 0, 0)
    }
    local fakeTouchEnd = {
        UserInputType = Enum.UserInputType.Touch,
        UserInputState = Enum.UserInputState.End,
        Position = Vector3.new(0, 0, 0)
    }

    pcall(function()
        if firesignal then
            if btn:IsA("GuiButton") then
                pcall(function() firesignal(btn.MouseButton1Down) end)
                pcall(function() firesignal(btn.MouseButton1Up) end)
                pcall(function() firesignal(btn.MouseButton1Click) end)
                pcall(function() firesignal(btn.Activated) end)
            end
            pcall(function() firesignal(btn.TouchTap, {Vector2.new(0, 0)}) end)
            pcall(function() firesignal(btn.InputBegan, fakeTouchBegin) end)
        elseif getconnections then
            for _, sigName in ipairs({"MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated", "TouchTap", "InputBegan"}) do
                pcall(function()
                    for _, conn in ipairs(getconnections(btn[sigName])) do
                        if sigName == "InputBegan" then
                            pcall(function() conn:Fire(fakeTouchBegin) end)
                        elseif sigName == "TouchTap" then
                            pcall(function() conn:Fire({Vector2.new(0, 0)}) end)
                        else
                            pcall(function() conn:Fire() end)
                        end
                    end
                end)
            end
        end
    end)

    return true
end

-- [Sistem Aktivasi ProximityPrompt Khusus Delta Android]
function Util.FirePrompt(prompt)
    if not prompt then return false end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt, 10)
            fireproximityprompt(prompt, 1)
            fireproximityprompt(prompt, 0)
        else
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration or 0.2)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- [Cek apakah GuiObject benar-benar terlihat di layar (semua ancestor Visible & Enabled)]
function Util.IsActuallyVisible(obj)
    if not obj or not obj.Parent then return false end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local cur = obj
    while cur and cur ~= pGui do
        if cur:IsA("GuiObject") and not cur.Visible then
            return false
        elseif cur:IsA("ScreenGui") and not cur.Enabled then
            return false
        end
        cur = cur.Parent
    end
    if obj:IsA("GuiObject") and (obj.AbsoluteSize.X <= 0 or obj.AbsoluteSize.Y <= 0) then
        return false
    end
    return true
end

-- [Sistem Titipan Auto-Execute Teleport Universal]
function Util.QueueOnTeleport(code)
    local fn = queue_on_teleport 
        or queueonteleport 
        or (syn and syn.queue_on_teleport) 
        or (fluxus and fluxus.queue_on_teleport)
        or (getgenv and (getgenv().queue_on_teleport or getgenv().queueonteleport))

    if fn then
        pcall(function() fn(code) end)
        return true
    end
    return false
end

-- [Sinkronisasi Data RAP bbvalues.uk secara Real-Time]
function Util.SyncBbValues()
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    local loadedLive = false

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
                            local rawName = tostring(it.n)
                            local baseCat = tostring(it.c or "Sword")
                            local cat = baseCat
                            if it.tg and type(it.tg) == "string" and #it.tg > 0 then
                                cat = baseCat .. " (" .. it.tg .. ")"
                            end
                            local kSpaced = rawName:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
                            local kClean = rawName:lower():gsub("%s+", "")

                            for _, k in ipairs({ kSpaced, kClean }) do
                                RAP_DATABASE[k .. "#" .. baseCat:lower()] = val
                                if type(RAP_DATABASE[k]) ~= "table" then
                                    local oldVal = tonumber(RAP_DATABASE[k])
                                    RAP_DATABASE[k] = {}
                                    if oldVal and oldVal > 0 then RAP_DATABASE[k]["Sword"] = oldVal end
                                end
                                RAP_DATABASE[k][cat] = val
                            end
                            count = count + 1
                        end
                    end
                    loadedLive = true
                    Util.Notify("⚡ bbvalues.uk Sync", string.format("Berhasil memuat %s item live!", Util.FormatNumber(count)))
                end
            end
        end)
    end

    if not loadedLive then
        pcall(function()
            local rawJson = game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/data/rap_database.json")
            if rawJson and #rawJson > 10 then
                local parsed = HttpService:JSONDecode(rawJson)
                if type(parsed) == "table" then
                    for k, v in pairs(parsed) do
                        local kSpaced = tostring(k):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
                        local kClean = tostring(k):lower():gsub("%s+", "")
                        for _, key in ipairs({ kSpaced, kClean }) do
                            RAP_DATABASE[key] = v
                        end
                    end
                end
            end
        end)
    end
end
task.spawn(Util.SyncBbValues)

-- [3] MODULE: DISCORD WEBHOOK REPORTER
local Reporter = {}

function Reporter.SendAlert(deals)
    if not deals or #deals == 0 then return end
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then return end

    task.spawn(function()
        for i, deal in ipairs(deals) do
            if i > 10 then break end

            local isHighTier10k20k = (deal.RAP >= 10000 and deal.RAP <= 20000)
            local isUnder100Plus = (deal.Profit >= 100)
            local targetWebhook = DISCORD_WEBHOOK_URL

            if isHighTier10k20k and not isUnder100Plus then
                targetWebhook = DISCORD_WEBHOOK_10K_20K
            end

            local catTag = (deal.Category == "Sword" and "[🗡️ SWORD]") or (deal.Category == "Emote" and "[💃 EMOTE]") or (deal.Category == "Explosion" and "[💥 EXPLO]") or "[📦 ITEM]"
            local embedTitle = string.format("🔥 DEAL UNDER RAP: %s %s", catTag, deal.Name)
            local embedColor = 65280 -- Hijau

            if deal.IsSpecial then
                embedTitle = string.format("💎 SPECIAL WATCHLIST: %s %s", catTag, deal.Name)
                embedColor = 10181046
            elseif isHighTier10k20k and not isUnder100Plus then
                embedTitle = string.format("💎 HIGH-TIER 10K-20K: %s %s", catTag, deal.Name)
                embedColor = 3447003
            end

            local profitText = string.format("+%s tokens (-%d%%)", Util.FormatNumber(deal.Profit), deal.Discount)
            local timeStr = os.date("%H:%M:%S WIB")

            local payload = HttpService:JSONEncode({
                username = "Blade Ball Plaza Radar",
                embeds = {{
                    title = embedTitle,
                    color = embedColor,
                    fields = {
                        { name = "🗡️ Nama Item", value = string.format("**%s** (%s)", deal.Name, deal.Category), inline = true },
                        { name = "💰 Harga Booth", value = string.format("**%s** tokens", Util.FormatNumber(deal.Price)), inline = true },
                        { name = "📊 Nilai RAP", value = string.format("**%s** tokens", Util.FormatNumber(deal.RAP)), inline = true },
                        { name = "📈 Estimasi Untung", value = string.format("**%s**", profitText), inline = true },
                        { name = "👤 Penjual", value = string.format("@%s", deal.Seller), inline = true },
                        { name = "🕒 Jam Temuan", value = string.format("`%s`", timeStr), inline = true }
                    },
                    footer = { text = "Blade Ball Plaza Sniper 2026 • Live Sync" },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })

            pcall(function()
                req({
                    Url = targetWebhook,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = payload
                })
            end)

            task.wait(0.35)
        end
    end)
end

-- [4] MODULE: PLAZA BOOTH SCANNER (NO AUTO-BUY)
local Scanner = {
    IsScanning = false,
    CurrentDeals = {},
    AllListings = {}
}

function Scanner.DetectCategory(frame, itemName)
    local lower = tostring(itemName or ""):lower()
    if lower:find("explosion") or lower:find("blast") or lower:find("detonation") or lower:find("burst") then
        return "Explosion"
    end
    if lower:find("emote") or lower:find("dance") or lower:find("giggle") or lower:find("sit") then
        return "Emote"
    end

    if frame then
        local vp = frame:FindFirstChildWhichIsA("ViewportFrame", true)
        if vp then
            if vp:FindFirstChildWhichIsA("Humanoid", true) or vp:FindFirstChild("HumanoidRootPart", true) then
                return "Emote"
            end
            if vp:FindFirstChildWhichIsA("ParticleEmitter", true) or vp:FindFirstChildWhichIsA("Trail", true) then
                return "Explosion"
            end
            if vp:FindFirstChildWhichIsA("MeshPart", true) or vp:FindFirstChildWhichIsA("SpecialMesh", true) then
                return "Sword"
            end
        end
    end

    if lower:find("blade") or lower:find("sword") or lower:find("katana") or lower:find("scythe") or lower:find("axe") or lower:find("rapier") or lower:find("hammer") or lower:find("bat") then
        return "Sword"
    end
    return "Unknown"
end

function Scanner.GetRapValue(itemName, category, price)
    if not itemName or #itemName == 0 then return 0, "Unknown" end
    price = tonumber(price) or 0

    local kSpaced = itemName:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local kClean = itemName:lower():gsub("%s+", "")
    local catLower = category and category:lower() or "unknown"

    local entry = RAP_DATABASE[kSpaced] or RAP_DATABASE[kClean]
    if type(entry) == "table" then
        local variants = {}
        for cName, cVal in pairs(entry) do
            local num = tonumber(cVal) or 0
            if num > 0 then table.insert(variants, { type = tostring(cName), val = num }) end
        end

        if #variants > 0 then
            local candidates = {}
            if catLower ~= "unknown" then
                for _, v in ipairs(variants) do
                    if v.type:lower():find(catLower) then table.insert(candidates, v) end
                end
            end
            if #candidates == 0 then candidates = variants end

            local bestVal, bestDiff = candidates[1].val, math.abs(price - candidates[1].val)
            local bestCat = candidates[1].type
            for _, c in ipairs(candidates) do
                local diff = math.abs(price - c.val)
                if diff < bestDiff then
                    bestDiff = diff
                    bestVal = c.val
                    bestCat = c.type
                end
            end
            return bestVal, bestCat
        end
    end

    local num = tonumber(entry) or 0
    return num, category
end

function Scanner.IsQualified(rap, price, itemName, category)
    if not price or price <= 0 then return false, false, nil end

    -- Cek Special Watchlist
    local kSpaced = tostring(itemName or ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local special = SPECIAL_WATCHLIST[kSpaced] or SPECIAL_WATCHLIST[tostring(itemName or ""):lower():gsub("%s+", "")]
    if special and price <= special.MaxPrice then
        return true, true, special
    end

    -- Cek 10k-20k
    if rap and rap >= 10000 and rap <= 20000 and price <= 22000 then
        return true, true, { Reason = "💎 High-Tier 10k-20k" }
    end

    if not rap or rap <= 0 then return false, false, nil end
    local profit = rap - price
    if profit <= 0 then return false, false, nil end

    if rap >= 200 and rap < 300 then
        return (profit >= Config.MinProfit200), false, nil
    elseif rap >= 300 then
        return (profit >= Config.MinProfit300), false, nil
    end

    return false, false, nil
end

function Scanner.ScanAllBooths(statusCallback)
    if Scanner.IsScanning then return end
    Scanner.IsScanning = true
    if statusCallback then statusCallback("Mencari booth aktif...") end

    local activeStands = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Stands" and obj:IsA("Folder") or obj:IsA("Model") then
                for _, s in ipairs(obj:GetChildren()) do
                    if s:IsA("Model") or s:IsA("Folder") then
                        local owner = s:GetAttribute("Owner") or s:GetAttribute("Player") or s:GetAttribute("Username")
                        if not owner then
                            for _, desc in ipairs(s:GetDescendants()) do
                                if desc:IsA("TextLabel") and desc.Text:find("'s Booth") then
                                    owner = desc.Text:gsub("'s Booth", ""):match("^%s*(.-)%s*$")
                                    break
                                end
                            end
                        end
                        if owner and tostring(owner) ~= LocalPlayer.Name then
                            table.insert(activeStands, { Stand = s, Owner = tostring(owner) })
                        end
                    end
                end
            end
        end
    end)

    local foundDeals = {}
    local allFound = {}

    for i, item in ipairs(activeStands) do
        if statusCallback then statusCallback(string.format("Stealth scan booth %d/%d (@%s)", i, #activeStands, item.Owner)) end

        pcall(function()
            local prompt = item.Stand:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                -- Stealth Mode: Buka booth dari jarak jauh tanpa memindahkan karakter!
                pcall(function()
                    prompt.MaxActivationDistance = 99999
                    prompt.RequiresLineOfSight = false
                end)
                Util.FirePrompt(prompt)

                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                local boothGui = pGui and pGui:WaitForChild("Booth", 2.0)
                local playersBooth = boothGui and boothGui:WaitForChild("PlayersBooth", 1.5)
                local scrollList = playersBooth and playersBooth:WaitForChild("ScrollingList", 1.5)

                -- Tunggu sebentar hingga UI Booth muncul
                local tWait = tick()
                while playersBooth and not playersBooth.Visible and tick() - tWait < 1.2 do
                    task.wait(0.1)
                end

                if scrollList and playersBooth and playersBooth.Visible then
                    local sellerName = item.Owner
                    local top = playersBooth:FindFirstChild("Top")
                    if top and top:FindFirstChild("PlayerName") then
                        sellerName = top.PlayerName.Text:gsub("'s Booth", ""):match("^%s*(.-)%s*$") or sellerName
                    end

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
                                local detectedCat = Scanner.DetectCategory(frame, itemName)
                                local rap, resCat = Scanner.GetRapValue(itemName, detectedCat, price)
                                local category = resCat or detectedCat
                                local profit = (rap > 0) and (rap - price) or 0
                                local discountPct = (rap > 0) and math.floor(((rap - price) / rap) * 100) or 0
                                local isQualified, isSpecial, sRule = Scanner.IsQualified(rap, price, itemName, category)

                                local dealInfo = {
                                    Name = itemName,
                                    Category = category,
                                    Price = price,
                                    RAP = rap,
                                    Profit = profit,
                                    Discount = discountPct,
                                    IsUnderRap = isQualified,
                                    IsSpecial = isSpecial,
                                    Seller = sellerName,
                                    Stand = item.Stand
                                }

                                table.insert(allFound, dealInfo)
                                if isQualified then
                                    table.insert(foundDeals, dealInfo)
                                end
                            end
                        end
                    end

                    -- Tutup booth UI
                    pcall(function()
                        local closeBtn = playersBooth:FindFirstChild("Close")
                        if closeBtn then Util.SafeClickButton(closeBtn) end
                    end)
                    Util.UnfreezePlayer()
                    task.wait(0.25)
                end
            end
        end)
    end

    table.sort(foundDeals, function(a, b) return a.Profit > b.Profit end)
    Scanner.CurrentDeals = foundDeals
    Scanner.AllListings = allFound
    Scanner.IsScanning = false

    if #foundDeals > 0 then
        Util.PlayChime()
        Util.Notify("🔥 " .. #foundDeals .. " DEAL UNDER RAP!", string.format("Terbaik: %s untung +%s token!", foundDeals[1].Name, Util.FormatNumber(foundDeals[1].Profit)), true)
        Reporter.SendAlert(foundDeals)
    else
        Util.Notify("Scan Selesai", string.format("Memeriksa %d item. Tidak ada under RAP di server ini.", #allFound))
    end

    if statusCallback then statusCallback("Scan Selesai!") end
end

-- [5] MODULE: INDEX TERMINAL HUNTER (TENGAH MAP -> FIND SELLER)
local IndexHunter = {
    IsHunting = false,
    MaxRetryCount = 3
}

-- Menangani auto-execute script ke server baru saat teleport
function IndexHunter.PrepareTeleportQueue()
    local payload = [[
        repeat task.wait(0.5) until game:IsLoaded()
        task.wait(1.5)
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/scripts/delta_plaza_sniper.lua"))()
        end)
    ]]
    Util.QueueOnTeleport(payload)
end

-- Cari model Papan Index di tengah Trade Plaza
function IndexHunter.FindIndexTerminal()
    -- 1. Cari ProximityPrompt yang namanya atau teksnya jelas merujuk ke Index
    local candidates = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local oText = (obj.ObjectText or ""):lower()
                local aText = (obj.ActionText or ""):lower()
                local pName = obj.Parent and obj.Parent.Name:lower() or ""
                if oText:find("open index") or oText:find("index") or aText:find("index") or pName:find("index") then
                    table.insert(candidates, obj)
                end
            end
        end
    end)

    if #candidates > 0 then return candidates[1] end

    -- 2. Fallback: Cari ProximityPrompt yang paling dekat dengan titik tengah (0, Y, 0)
    local bestPrompt, bestDist = nil, math.huge
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local part = obj.Parent:IsA("BasePart") and obj.Parent or obj.Parent:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (Vector3.new(part.Position.X, 0, part.Position.Z)).Magnitude
                    if dist < bestDist and dist < 120 then
                        bestDist = dist
                        bestPrompt = obj
                    end
                end
            end
        end
    end)

    return bestPrompt
end

-- Deteksi apakah UI INDEX benar-benar sedang terbuka di layar
function IndexHunter.IsIndexUIOpen()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false, nil end
    for _, gui in ipairs(pGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "BBSniperCleanV1" then
            for _, desc in ipairs(gui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextBox")) and Util.IsActuallyVisible(desc) then
                    local t = (desc:IsA("TextLabel") and desc.Text or desc.PlaceholderText or ""):lower()
                    if t == "index" or t:find("search for an item") then
                        return true, gui
                    end
                end
            end
        end
    end
    return false, nil
end

-- Buka papan Index di tengah plaza
function IndexHunter.OpenIndexTerminal(statusCallback)
    local isOpen, existingGui = IndexHunter.IsIndexUIOpen()
    if isOpen then
        if statusCallback then statusCallback("✅ UI Index sudah terbuka di layar!") end
        return true, existingGui
    end

    local prompt = IndexHunter.FindIndexTerminal()
    if not prompt then
        if statusCallback then statusCallback("❌ Terminal Index tidak ditemukan di tengah map!") end
        Util.Notify("Gagal", "Tidak menemukan papan Index di tengah plaza.")
        return false, nil
    end

    -- Coba buka Index dari tempat berdiri dulu (Stealth Mode)
    pcall(function()
        prompt.MaxActivationDistance = 99999
        prompt.RequiresLineOfSight = false
    end)
    if statusCallback then statusCallback("Membuka Papan Index (Stealth)...") end
    Util.FirePrompt(prompt)

    local tStealth = tick()
    while tick() - tStealth < 1.2 do
        local open, gui = IndexHunter.IsIndexUIOpen()
        if open then
            task.wait(0.25)
            return true, gui
        end
        task.wait(0.2)
    end

    -- Fallback: Jika server membatasi jarak Index, baru mendekat ke tengah plaza
    local part = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart")
    if part and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if statusCallback then statusCallback("Mendekat ke Papan Index tengah...") end
        LocalPlayer.Character.HumanoidRootPart.CFrame = part.CFrame * CFrame.new(0, 3, 3.5)
        task.wait(0.35)

        if statusCallback then statusCallback("Menekan 'Open Index' (Interact)...") end
        Util.FirePrompt(prompt)

        -- Tunggu sampai UI INDEX benar-benar muncul (maks 3.5 detik)
        local t0 = tick()
        while tick() - t0 < 3.5 do
            local open, gui = IndexHunter.IsIndexUIOpen()
            if open then
                task.wait(0.3)
                return true, gui
            end
            task.wait(0.2)
        end
    end
    return IndexHunter.IsIndexUIOpen()
end

-- Cari item & klik tombol Find Seller (Alur Sesuai Tampilan UI Game Asli)
function IndexHunter.FindSellerForItem(targetItemName, statusCallback)
    if IndexHunter.IsHunting then return end
    IndexHunter.IsHunting = true
    targetItemName = targetItemName or Config.TargetItemName

    if statusCallback then statusCallback("Mempersiapkan perburuan " .. targetItemName .. "...") end
    IndexHunter.PrepareTeleportQueue()

    local opened, indexGui = IndexHunter.OpenIndexTerminal(statusCallback)
    if not opened or not indexGui then
        IndexHunter.IsHunting = false
        if statusCallback then statusCallback("❌ Gagal membuka UI Index!") end
        return
    end

    if statusCallback then statusCallback("Mencari kolom pencarian item...") end
    task.wait(0.4)

    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local searchBox, searchBtn = nil, nil

    -- [1] Cari TextBox pencarian ("Search for an item")
    for _, desc in ipairs(indexGui:GetDescendants()) do
        if desc:IsA("TextBox") and Util.IsActuallyVisible(desc) then
            local ph = (desc.PlaceholderText or ""):lower()
            local n = desc.Name:lower()
            if ph:find("search") or n:find("search") or ph:find("item") then
                searchBox = desc
                break
            end
        end
    end

    if searchBox then
        -- Cari tombol search magnifying glass (ikon Q hijau) di sebelah TextBox
        local parentBox = searchBox.Parent
        if parentBox then
            for _, sibling in ipairs(parentBox:GetDescendants()) do
                if (sibling:IsA("ImageButton") or sibling:IsA("TextButton")) and Util.IsActuallyVisible(sibling) and sibling ~= searchBox then
                    searchBtn = sibling
                    break
                end
            end
        end

        if statusCallback then statusCallback("Mengetik '" .. targetItemName .. "'...") end
        searchBox.Text = targetItemName
        pcall(function()
            if firesignal and searchBox.FocusLost then firesignal(searchBox.FocusLost, true) end
            if getconnections and searchBox.FocusLost then
                for _, conn in ipairs(getconnections(searchBox.FocusLost)) do conn:Fire(true) end
            end
        end)
        if searchBtn then
            Util.SafeClickButton(searchBtn)
        end
        task.wait(0.7)
    end

    -- Helper untuk klik item dari hasil grid (support Button, Frame InputBegan, & TouchTap)
    local function tryClickTargetItem()
        local tLower = targetItemName:lower()
        for _, desc in ipairs(indexGui:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and Util.IsActuallyVisible(desc) then
                local txt = (desc.Text or ""):lower():match("^%s*(.-)%s*$")
                if txt == tLower or (txt:find(tLower, 1, true) and not txt:find("search")) then
                    -- 0. Prioritas Utama Blade Ball Index: Tombol "ActivationButton" di dalam kartu item!
                    if desc.Parent then
                        local actBtn = desc.Parent:FindFirstChild("ActivationButton", true)
                        if actBtn and actBtn:IsA("GuiButton") then
                            Util.SafeClickButton(actBtn)
                            return true
                        end
                    end
                    -- 1. Jika desc sendiri adalah TextButton
                    if desc:IsA("TextButton") then
                        Util.SafeClickButton(desc)
                        return true
                    end
                    -- 2. Cek ancestor sampai 4 tingkat
                    local cur = desc.Parent
                    for _ = 1, 4 do
                        if not cur or cur == indexGui then break end
                        if cur:IsA("TextButton") or cur:IsA("ImageButton") then
                            Util.SafeClickButton(cur)
                            return true
                        end
                        cur = cur.Parent
                    end
                    -- 3. Cek tombol terbesar di dalam kartu item (sampai 3 tingkat)
                    local card = desc.Parent
                    local bestBtn, bestArea = nil, 0
                    for _ = 1, 3 do
                        if not card or card == indexGui then break end
                        for _, child in ipairs(card:GetDescendants()) do
                            if (child:IsA("TextButton") or child:IsA("ImageButton")) and Util.IsActuallyVisible(child) then
                                local cName = child.Name:lower()
                                if not cName:find("fav") and not cName:find("star") then
                                    local area = child.AbsoluteSize.X * child.AbsoluteSize.Y
                                    if area > bestArea then
                                        bestArea = area
                                        bestBtn = child
                                    end
                                end
                            end
                        end
                        if bestBtn then break end
                        card = card.Parent
                    end
                    if bestBtn then
                        Util.SafeClickButton(bestBtn)
                        return true
                    end
                    -- 4. Fallback: tembak InputBegan/TouchTap langsung ke Frame kartu
                    if desc.Parent and desc.Parent:IsA("GuiObject") then
                        Util.SafeClickButton(desc.Parent)
                        if desc.Parent.Parent and desc.Parent.Parent:IsA("GuiObject") then
                            Util.SafeClickButton(desc.Parent.Parent)
                        end
                        return true
                    end
                end
            end
        end
        return false
    end

    -- [2] Cari kartu item di hasil pencarian (jika perlu pindah tab Swords / Explosions / Emotes)
    if statusCallback then statusCallback("Memilih item '" .. targetItemName .. "'...") end
    local itemClicked = tryClickTargetItem()

    if not itemClicked then
        -- Coba pindah tab kategori (Explosions / Swords / Emotes) karena item tertentu ada di tab berbeda
        local tabNames = { "explosions", "swords", "emotes" }
        for _, tabKey in ipairs(tabNames) do
            for _, desc in ipairs(indexGui:GetDescendants()) do
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and Util.IsActuallyVisible(desc) then
                    local t = (desc:IsA("TextButton") and desc.Text or ""):lower()
                    for _, lbl in ipairs(desc:GetChildren()) do
                        if lbl:IsA("TextLabel") then t = t .. " " .. lbl.Text:lower() end
                    end
                    if t:find(tabKey) then
                        Util.SafeClickButton(desc)
                        task.wait(0.45)
                        if searchBox then
                            searchBox.Text = targetItemName
                            if searchBtn then Util.SafeClickButton(searchBtn) end
                            task.wait(0.45)
                        end
                        if tryClickTargetItem() then
                            itemClicked = true
                            break
                        end
                    end
                end
            end
            if itemClicked then break end
        end
    end

    task.wait(0.6)

    -- [3] Cari dan klik tombol "Find Seller" (Orange button di sebelah kanan)
    if statusCallback then statusCallback("Mencari tombol 'Find Seller'...") end
    local findSellerBtn = nil

    for _, desc in ipairs(indexGui:GetDescendants()) do
        if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and Util.IsActuallyVisible(desc) then
            local t = (desc:IsA("TextButton") and desc.Text or ""):lower()
            local n = desc.Name:lower()
            for _, lbl in ipairs(desc:GetChildren()) do
                if lbl:IsA("TextLabel") then t = t .. " " .. lbl.Text:lower() end
            end
            if t:find("find seller") or n:find("findseller") or t:find("seller") then
                findSellerBtn = desc
                break
            end
        end
    end

    if not findSellerBtn then
        -- Periksa seluruh PlayerGui jika tombol berada di luar indexGui
        for _, gui in ipairs(pGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled and gui ~= indexGui and gui.Name ~= "BBSniperCleanV1" then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if (desc:IsA("TextButton") or desc:IsA("ImageButton")) and Util.IsActuallyVisible(desc) then
                        local t = (desc:IsA("TextButton") and desc.Text or ""):lower()
                        for _, lbl in ipairs(desc:GetChildren()) do
                            if lbl:IsA("TextLabel") then t = t .. " " .. lbl.Text:lower() end
                        end
                        if t:find("find seller") then
                            findSellerBtn = desc
                            break
                        end
                    end
                end
            end
            if findSellerBtn then break end
        end
    end

    if findSellerBtn then
        if statusCallback then statusCallback("⚡ Menekan 'Find Seller'...") end
        Util.SafeClickButton(findSellerBtn)
        task.wait(0.5)

        -- [4] MENANGANI NOTIFICATION POPUP ("A seller has been found! Would you like to teleport to their server?")
        if statusCallback then statusCallback("⏳ Menunggu konfirmasi seller (maks 30 dtk)...") end
        local confirmed = false
        local waitStart = tick()

        while tick() - waitStart < 30 do
            task.wait(0.3)
            -- Cari dialog Notification di seluruh ScreenGui aktif
            for _, gui in ipairs(pGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "BBSniperCleanV1" then
                    for _, desc in ipairs(gui:GetDescendants()) do
                        if desc:IsA("TextLabel") and Util.IsActuallyVisible(desc) then
                            local txt = desc.Text:lower()
                            if txt:find("a seller has been found") or txt:find("teleport to their server") then
                                -- Dialog ditemukan! Cari tombol "Yes" di seluruh gui tersebut
                                for _, btn in ipairs(gui:GetDescendants()) do
                                    if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and Util.IsActuallyVisible(btn) then
                                        local btnTxt = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                        for _, l in ipairs(btn:GetChildren()) do
                                            if l:IsA("TextLabel") then btnTxt = btnTxt .. " " .. l.Text:lower() end
                                        end
                                        if btnTxt:find("yes") or btnTxt == "yes" then
                                            if statusCallback then statusCallback("🚀 Menekan 'Yes' - Menghubungkan ke server...") end
                                            Util.Notify("🚀 Teleport Seller", "Seller ditemukan! Menghubungkan ke server...", true)
                                            IndexHunter.PrepareTeleportQueue()
                                            Util.SafeClickButton(btn)
                                            confirmed = true
                                            break
                                        end
                                    end
                                end
                            elseif txt:find("no seller") or txt:find("could not find") then
                                if statusCallback then statusCallback("⚠️ Seller tidak ditemukan saat ini!") end
                                Util.Notify("Tidak Ada Seller", "Tidak ada seller yang menjual " .. targetItemName .. " saat ini.")
                                confirmed = true
                                break
                            end
                        end
                        if confirmed then break end
                    end
                end
                if confirmed then break end
            end
        end

        if not confirmed and statusCallback then
            statusCallback("⚠️ Waktu pencarian seller habis atau popup belum muncul.")
        end
    else
        if statusCallback then statusCallback("⚠️ Tombol 'Find Seller' belum terlihat di layar!") end
        Util.Notify("Perhatian", "itemClicked=" .. tostring(itemClicked) .. ". Silakan klik " .. targetItemName .. " manual dulu!")

        -- Auto-Diagnostik Struktur Kartu Item jika gagal klik
        pcall(function()
            local tLower = targetItemName:lower()
            for _, desc in ipairs(indexGui:GetDescendants()) do
                if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and Util.IsActuallyVisible(desc) then
                    local txt = (desc.Text or ""):lower()
                    if txt:find(tLower, 1, true) then
                        local p1 = desc.Parent
                        local p2 = p1 and p1.Parent
                        Util.Notify("DIAG CARD", string.format("%s(%s) | P1:%s(%s) | P2:%s(%s)",
                            desc.Name, desc.ClassName,
                            p1 and p1.Name or "-", p1 and p1.ClassName or "-",
                            p2 and p2.Name or "-", p2 and p2.ClassName or "-"
                        ), true)

                        local sigs = {}
                        if getconnections then
                            local checkList = {desc, p1, p2}
                            if p1 then
                                for _, c in ipairs(p1:GetDescendants()) do table.insert(checkList, c) end
                            end
                            for _, obj in ipairs(checkList) do
                                for _, sName in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "InputBegan", "TouchTap"}) do
                                    pcall(function()
                                        local conns = getconnections(obj[sName])
                                        if #conns > 0 then
                                            table.insert(sigs, obj.Name .. "." .. sName .. "(" .. #conns .. ")")
                                        end
                                    end)
                                end
                            end
                        end
                        Util.Notify("DIAG SIGS", #sigs > 0 and table.concat(sigs, ", "):sub(1, 90) or "No conns", true)
                        break
                    end
                end
            end
        end)
    end

    IndexHunter.IsHunting = false
end

-- Deteksi kegagalan teleportasi (Server Penuh / Error 773) -> Auto Retry Find Seller!
pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        warn("⚠️ Teleport gagal (" .. tostring(errorMessage) .. "). Mengulang pencarian seller dalam 3 detik...")
        Util.Notify("Teleport Gagal", "Server tujuan penuh / gagal. Mencari seller lain dalam 3 detik...", true)
        task.wait(3)
        IndexHunter.FindSellerForItem(Config.TargetItemName, function(msg) print(msg) end)
    end)
end)

-- [6] MODULE: CLEAN MODERN MINIMALIST UI
local UI = {}

function UI.Build()
    local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pGui then return end

    local old = pGui:FindFirstChild("BBSniperCleanV1")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BBSniperCleanV1"
    sg.ResetOnSpawn = false
    sg.Parent = pGui

    -- FLOATING TOGGLE BUBBLE
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 46, 0, 46)
    toggleBtn.Position = UDim2.new(0.015, 0, 0.45, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    toggleBtn.TextColor3 = Color3.fromRGB(56, 189, 248)
    toggleBtn.Text = "🎯"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 20
    toggleBtn.Active = true
    toggleBtn.Draggable = true
    toggleBtn.Parent = sg
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    local tStroke = Instance.new("UIStroke", toggleBtn)
    tStroke.Color = Color3.fromRGB(99, 102, 241)
    tStroke.Thickness = 2

    -- MAIN CONTAINER
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 340, 0, 390)
    main.Position = UDim2.new(0.08, 0, 0.18, 0)
    main.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    main.Parent = sg
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local mStroke = Instance.new("UIStroke", main)
    mStroke.Color = Color3.fromRGB(99, 102, 241)
    mStroke.Thickness = 1.5

    toggleBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

    -- HEADER
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 44)
    header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    header.Parent = main
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 0, 22)
    title.Position = UDim2.new(0, 12, 0, 4)
    title.BackgroundTransparency = 1
    title.Text = "🎯 PLAZA INDEX HUNTER <font color='#38bdf8'>" .. SCRIPT_VERSION .. "</font>"
    title.RichText = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -50, 0, 16)
    sub.Position = UDim2.new(0, 12, 0, 24)
    sub.BackgroundTransparency = 1
    sub.Text = "Index Teleport • Pure Scanner (No Auto-Buy) • Discord Alert"
    sub.TextColor3 = Color3.fromRGB(52, 211, 153)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 8.5
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = header

    local btnClose = Instance.new("TextButton")
    btnClose.Size = UDim2.new(0, 26, 0, 26)
    btnClose.Position = UDim2.new(1, -34, 0, 9)
    btnClose.BackgroundColor3 = Color3.fromRGB(225, 29, 72)
    btnClose.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnClose.Text = "✕"
    btnClose.Font = Enum.Font.GothamBold
    btnClose.TextSize = 11
    btnClose.Parent = header
    Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 6)
    btnClose.MouseButton1Click:Connect(function() main.Visible = false end)

    -- STATUS BAR
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, -20, 0, 28)
    statusBar.Position = UDim2.new(0, 10, 0, 50)
    statusBar.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
    statusBar.Parent = main
    Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 6)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -12, 1, 0)
    statusLabel.Position = UDim2.new(0, 6, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Siap berburu item target..."
    statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = statusBar

    -- SECTION: TARGET ITEM INPUT & FIND SELLER
    local targetCard = Instance.new("Frame")
    targetCard.Size = UDim2.new(1, -20, 0, 94)
    targetCard.Position = UDim2.new(0, 10, 0, 84)
    targetCard.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
    targetCard.Parent = main
    Instance.new("UICorner", targetCard).CornerRadius = UDim.new(0, 8)

    local lblTarget = Instance.new("TextLabel")
    lblTarget.Size = UDim2.new(1, -16, 0, 18)
    lblTarget.Position = UDim2.new(0, 8, 0, 4)
    lblTarget.BackgroundTransparency = 1
    lblTarget.Text = "🗡️ Item Target yang Dicari di Index:"
    lblTarget.TextColor3 = Color3.fromRGB(241, 245, 249)
    lblTarget.Font = Enum.Font.GothamBold
    lblTarget.TextSize = 10
    lblTarget.TextXAlignment = Enum.TextXAlignment.Left
    lblTarget.Parent = targetCard

    local targetInput = Instance.new("TextBox")
    targetInput.Size = UDim2.new(1, -16, 0, 28)
    targetInput.Position = UDim2.new(0, 8, 0, 24)
    targetInput.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    targetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    targetInput.Text = Config.TargetItemName
    targetInput.PlaceholderText = "Ketik nama item (mis: Prince Blade)..."
    targetInput.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
    targetInput.Font = Enum.Font.GothamBold
    targetInput.TextSize = 10.5
    targetInput.ClearTextOnFocus = false
    targetInput.Parent = targetCard
    Instance.new("UICorner", targetInput).CornerRadius = UDim.new(0, 6)

    targetInput.FocusLost:Connect(function()
        local val = targetInput.Text:match("^%s*(.-)%s*$")
        if val and #val > 0 then
            if val ~= Config.TargetItemName then
                Config.TargetItemName = val
                if Config.AutoHuntEnabled then
                    Util.Notify("🎯 Target Diganti", "Auto Hunt sekarang memburu: " .. val, true)
                    statusLabel.Text = "Target diubah → " .. val .. " (Auto Hunt lanjut)"
                else
                    Util.Notify("Target Disimpan", "Mencari: " .. val)
                end
            end
        else
            targetInput.Text = Config.TargetItemName
        end
    end)

    -- Tombol sekali jalan (manual)
    local btnFindSeller = Instance.new("TextButton")
    btnFindSeller.Size = UDim2.new(0.52, -4, 0, 30)
    btnFindSeller.Position = UDim2.new(0, 8, 0, 56)
    btnFindSeller.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
    btnFindSeller.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnFindSeller.Text = "🚀 Cari 1x"
    btnFindSeller.Font = Enum.Font.GothamBold
    btnFindSeller.TextSize = 9
    btnFindSeller.Parent = targetCard
    Instance.new("UICorner", btnFindSeller).CornerRadius = UDim.new(0, 6)

    -- Tombol AUTO HUNT LOOP ON/OFF
    local btnAutoHunt = Instance.new("TextButton")
    btnAutoHunt.Size = UDim2.new(0.48, -4, 0, 30)
    btnAutoHunt.Position = UDim2.new(0.52, 4, 0, 56)
    btnAutoHunt.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
    btnAutoHunt.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnAutoHunt.Text = "▶ AUTO HUNT"
    btnAutoHunt.Font = Enum.Font.GothamBold
    btnAutoHunt.TextSize = 8.5
    btnAutoHunt.Parent = targetCard
    Instance.new("UICorner", btnAutoHunt).CornerRadius = UDim.new(0, 6)

    -- Label countdown timer
    local lblCountdown = Instance.new("TextLabel")
    lblCountdown.Size = UDim2.new(1, -16, 0, 14)
    lblCountdown.Position = UDim2.new(0, 8, 0, 90)
    lblCountdown.BackgroundTransparency = 1
    lblCountdown.Text = ""
    lblCountdown.TextColor3 = Color3.fromRGB(251, 191, 36)
    lblCountdown.Font = Enum.Font.GothamBold
    lblCountdown.TextSize = 8.5
    lblCountdown.TextXAlignment = Enum.TextXAlignment.Center
    lblCountdown.Parent = targetCard

    -- Perbesar targetCard agar muat countdown label
    targetCard.Size = UDim2.new(1, -20, 0, 110)

    -- ==== AUTO HUNT LOOP LOGIC ====
    local function stopAutoHunt()
        Config.AutoHuntEnabled = false
        if Config.AutoHuntThread then
            pcall(function() task.cancel(Config.AutoHuntThread) end)
            Config.AutoHuntThread = nil
        end
        btnAutoHunt.BackgroundColor3 = Color3.fromRGB(22, 163, 74)
        btnAutoHunt.Text = "▶ AUTO HUNT"
        lblCountdown.Text = ""
        statusLabel.Text = "Auto Hunt dihentikan."
    end

    local function startAutoHunt()
        if Config.AutoHuntEnabled then return end
        Config.AutoHuntEnabled = true
        btnAutoHunt.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
        btnAutoHunt.Text = "■ STOP HUNT"
        statusLabel.Text = "✅ Auto Hunt aktif! Mencari setiap " .. math.floor(Config.AutoHuntInterval / 60) .. " menit."
        Util.Notify("🔁 Auto Hunt Aktif", "Mencari '" .. Config.TargetItemName .. "' setiap 3 menit!", true)

        Config.AutoHuntThread = task.spawn(function()
            while Config.AutoHuntEnabled do
                -- Tutup UI script agar tidak menghalangi papan Index saat mencari
                main.Visible = false
                local currentItem = Config.TargetItemName
                statusLabel.Text = "🔎 Auto Hunt: Mencari '" .. currentItem .. "'..."
                IndexHunter.FindSellerForItem(currentItem, function(msg)
                    if Config.AutoHuntEnabled then
                        statusLabel.Text = msg
                    end
                end)

                if not Config.AutoHuntEnabled then break end

                -- Countdown 3 menit
                local remaining = Config.AutoHuntInterval
                while remaining > 0 and Config.AutoHuntEnabled do
                    local m = math.floor(remaining / 60)
                    local s = remaining % 60
                    lblCountdown.Text = string.format("⏱ Cari ulang: %d:%02d | %s", m, s, Config.TargetItemName)
                    task.wait(1)
                    remaining = remaining - 1
                end

                lblCountdown.Text = ""
                if not Config.AutoHuntEnabled then break end
            end

            if Config.AutoHuntEnabled then
                stopAutoHunt()
            end
        end)
    end

    btnFindSeller.MouseButton1Click:Connect(function()
        local tName = targetInput.Text:match("^%s*(.-)%s*$")
        if not tName or #tName == 0 then tName = Config.TargetItemName end
        Config.TargetItemName = tName
        Util.Notify("🔎 Mencari Seller", "Membuka Index untuk: " .. tName)
        -- Tutup UI script agar tidak mengganggu pencarian Index
        main.Visible = false
        task.spawn(function()
            local okHunt, errHunt = pcall(function()
                IndexHunter.FindSellerForItem(tName, function(msg)
                    statusLabel.Text = msg
                end)
            end)
            if not okHunt then
                IndexHunter.IsHunting = false
                main.Visible = true
                Util.Notify("❌ Hunt Error", tostring(errHunt):sub(1, 60))
            end
        end)
    end)

    btnAutoHunt.MouseButton1Click:Connect(function()
        if Config.AutoHuntEnabled then
            stopAutoHunt()
        else
            local tName = targetInput.Text:match("^%s*(.-)%s*$")
            if not tName or #tName == 0 then tName = Config.TargetItemName end
            Config.TargetItemName = tName
            startAutoHunt()
        end
    end)

    -- SECTION: DEALS LIST DI SERVER SAAT INI
    local dealsBox = Instance.new("ScrollingFrame")
    dealsBox.Size = UDim2.new(1, -20, 1, -256)
    dealsBox.Position = UDim2.new(0, 10, 0, 204)
    dealsBox.BackgroundColor3 = Color3.fromRGB(14, 20, 36)
    dealsBox.ScrollBarThickness = 3
    dealsBox.Parent = main
    Instance.new("UICorner", dealsBox).CornerRadius = UDim.new(0, 8)
    local dLayout = Instance.new("UIListLayout", dealsBox)
    dLayout.Padding = UDim.new(0, 4)

    local function updateDealsUI()
        for _, c in ipairs(dealsBox:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end

        if #Scanner.CurrentDeals == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, 0, 1, 0)
            empty.BackgroundTransparency = 1
            empty.TextColor3 = Color3.fromRGB(148, 163, 184)
            empty.Text = "Belum ada temuan deal di server ini.\nKlik '⚡ SCAN BOOTH SERVER INI' di bawah!"
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 9.5
            empty.Parent = dealsBox
            dealsBox.CanvasSize = UDim2.new(0, 0, 0, 0)
            return
        end

        for _, d in ipairs(Scanner.CurrentDeals) do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -6, 0, 56)
            card.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
            card.Parent = dealsBox
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1, -85, 0, 16)
            nl.Position = UDim2.new(0, 6, 0, 4)
            nl.BackgroundTransparency = 1
            nl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nl.Text = string.format("[%s] %s", d.Category, d.Name)
            nl.Font = Enum.Font.GothamBold
            nl.TextSize = 10
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.Parent = card

            local pl = Instance.new("TextLabel")
            pl.Size = UDim2.new(1, -85, 0, 16)
            pl.Position = UDim2.new(0, 6, 0, 20)
            pl.BackgroundTransparency = 1
            pl.TextColor3 = Color3.fromRGB(56, 189, 248)
            pl.Text = string.format("Harga: %s | RAP: %s", Util.FormatNumber(d.Price), Util.FormatNumber(d.RAP))
            pl.Font = Enum.Font.Gotham
            pl.TextSize = 9.5
            pl.TextXAlignment = Enum.TextXAlignment.Left
            pl.Parent = card

            local prl = Instance.new("TextLabel")
            prl.Size = UDim2.new(1, -85, 0, 14)
            prl.Position = UDim2.new(0, 6, 0, 36)
            prl.BackgroundTransparency = 1
            prl.TextColor3 = Color3.fromRGB(52, 211, 153)
            prl.Text = string.format("Untung: +%s tokens (@%s)", Util.FormatNumber(d.Profit), d.Seller)
            prl.Font = Enum.Font.Gotham
            prl.TextSize = 8.5
            prl.TextXAlignment = Enum.TextXAlignment.Left
            prl.Parent = card

            local btnTpBooth = Instance.new("TextButton")
            btnTpBooth.Size = UDim2.new(0, 74, 0, 28)
            btnTpBooth.Position = UDim2.new(1, -78, 0, 14)
            btnTpBooth.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
            btnTpBooth.TextColor3 = Color3.fromRGB(255, 255, 255)
            btnTpBooth.Text = "🚀 TP BOOTH"
            btnTpBooth.Font = Enum.Font.GothamBold
            btnTpBooth.TextSize = 9
            btnTpBooth.Parent = card
            Instance.new("UICorner", btnTpBooth).CornerRadius = UDim.new(0, 6)

            btnTpBooth.MouseButton1Click:Connect(function()
                if d.Stand and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local root = d.Stand:FindFirstChild("Root") or d.Stand:FindFirstChildWhichIsA("BasePart")
                    if root then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = root.CFrame * CFrame.new(0, 3, 4)
                        Util.Notify("Teleport", "Tiba di booth @" .. d.Seller)
                    end
                end
            end)
        end
        dealsBox.CanvasSize = UDim2.new(0, 0, 0, #Scanner.CurrentDeals * 60)
    end

    -- FOOTER SCAN BUTTON
    local btnScanNow = Instance.new("TextButton")
    btnScanNow.Size = UDim2.new(1, -20, 0, 36)
    btnScanNow.Position = UDim2.new(0, 10, 1, -44)
    btnScanNow.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
    btnScanNow.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnScanNow.Text = "⚡ SCAN BOOTH SERVER INI (NO AUTO-BUY)"
    btnScanNow.Font = Enum.Font.GothamBold
    btnScanNow.TextSize = 10
    btnScanNow.Parent = main
    Instance.new("UICorner", btnScanNow).CornerRadius = UDim.new(0, 6)

    btnScanNow.MouseButton1Click:Connect(function()
        if Scanner.IsScanning then return end
        btnScanNow.Text = "⏳ MEMINDAI BOOTH..."
        btnScanNow.BackgroundColor3 = Color3.fromRGB(37, 99, 235)
        task.spawn(function()
            Scanner.ScanAllBooths(function(msg)
                statusLabel.Text = msg
            end)
            btnScanNow.Text = "⚡ SCAN BOOTH SERVER INI (NO AUTO-BUY)"
            btnScanNow.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
            updateDealsUI()
        end)
    end)

    return updateDealsUI
end

-- [7] BOOTSTRAP & AUTO-SCAN PADA SERVER BARU
local ok, err = pcall(function()
    local renderFn = UI.Build()
    Util.UnfreezePlayer()
    Util.Notify("🎯 Index Hunter Ready", "Panel siap! Klik 🎯 di kiri layar.", true)
    print("==========================================================")
    print("🎯 BLADE BALL INDEX HUNTER & PURE SCANNER BERHASIL AKTIF!")
    print("==========================================================")

    -- Auto-Scan saat baru mendarat di server baru (jika aktif oleh QueueOnTeleport)
    task.spawn(function()
        task.wait(3.5)
        if Config.AutoScanOnTeleport and JobId ~= Config.LastScannedJobId then
            Config.LastScannedJobId = JobId
            Scanner.ScanAllBooths(function(msg) end)
            if renderFn then renderFn() end
        end
    end)
end)

if not ok then
    pcall(function()
        _sg:SetCore("SendNotification", {
            Title = "❌ BB Sniper Error",
            Text = tostring(err):sub(1, 80),
            Duration = 10
        })
    end)
    warn("[BB SNIPER ERROR]", tostring(err))
end
