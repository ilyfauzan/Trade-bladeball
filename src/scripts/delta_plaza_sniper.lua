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

-- Discord Webhook untuk notifikasi hasil scan Under-RAP
local DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/1570338415722102866/0Hpi4LO0C-ZLvovBhsGG96Tb-td2nlrLQZGXor1J8pffFKJXzPqkVxxD91aC5eE0pf3d"

-- ==============================================================================
-- [SPECIAL HIGH-DEMAND WATCHLIST / OVER-RAP BUY DEALS]
-- Item tertentu yang permintaannya sangat tinggi (hype/liquid) sehingga tetap
-- SANGAT WORTH IT DIBELI meskipun harganya sedikit di atas RAP resmi bbvalues.
-- Format:
--   ["nama item"] = { MaxPrice = batas_beli_max, ResellTarget = target_jual, Category = "Sword", Reason = "alasan" }
-- Anda bisa bebas menambahkan item lain ke tabel ini kapan saja!
-- ==============================================================================
local SPECIAL_WATCHLIST = {
    ["rose gift"] = {
        MaxPrice = 11500,     -- Tampilkan jika harga <= 11.500 (kisaran 11k - 11.5k)
        ResellTarget = 12500, -- Estimasi nilai jual pasar riil
        Reason = "🌹 High-Demand Rose Gift (Worth It Di Atas RAP)"
    },
    ["chroma blade"] = {
        MaxPrice = 15000,     -- Tampilkan jika harga <= 15.000 (kisaran 13k - 15k)
        ResellTarget = 16500, -- Estimasi nilai jual pasar riil
        Category = "Sword",   -- Wajib jenis Sword (bukan emote/explo)
        Reason = "🌈 Hype High-Tier Chroma Blade (Worth It s/d 15k)"
    }
}

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

-- [Safe Anti-Idle Protection - Bebas Deteksi BAC Anti-Cheat]
pcall(function()
    LocalPlayer.Idled:Connect(function()
        -- Jika idle terdeteksi, lakukan server hop bersih tanpa menyentuh VirtualUser
        if Navigator and Navigator.ServerHop then
            Navigator.ServerHop(6, 26)
        end
    end)
end)


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
                            local rawName = tostring(it.n)
                            local baseCat = tostring(it.c or "Sword")
                            local cat = baseCat
                            if it.tg and type(it.tg) == "string" and #it.tg > 0 then
                                cat = baseCat .. " (" .. it.tg .. ")"
                            end
                            local catLower = baseCat:lower()

                            local kSpaced = rawName:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
                            local kClean = rawName:lower():gsub("%s+", "")

                            for _, k in ipairs({ kSpaced, kClean }) do
                                -- Key spesifik kategori dasar
                                RAP_DATABASE[k .. "#" .. catLower] = val

                                -- Simpan dalam struktur tabel multi-kategori
                                if type(RAP_DATABASE[k]) ~= "table" then
                                    local oldVal = tonumber(RAP_DATABASE[k])
                                    RAP_DATABASE[k] = {}
                                    if oldVal and oldVal > 0 then
                                        RAP_DATABASE[k]["Sword"] = oldVal
                                    end
                                end

                                -- Hindari overwrite jika ada varian berbeda tanpa tag
                                local variantKey = cat
                                if RAP_DATABASE[k][variantKey] and RAP_DATABASE[k][variantKey] ~= val then
                                    local c = 2
                                    while RAP_DATABASE[k][variantKey .. " #" .. c] do
                                        c = c + 1
                                    end
                                    variantKey = variantKey .. " #" .. c
                                end

                                RAP_DATABASE[k][variantKey] = val
                            end
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
                        local kSpaced = tostring(k):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
                        local kClean = tostring(k):lower():gsub("%s+", "")
                        for _, key in ipairs({ kSpaced, kClean }) do
                            if type(v) == "table" then
                                RAP_DATABASE[key] = v
                            else
                                local num = tonumber(v) or 0
                                if num > 0 then
                                    RAP_DATABASE[key] = num
                                end
                            end
                        end
                        count = count + 1
                    end
                    Util.Notify("📊 Cloud Database", string.format("Memuat %s varian resmi!", Util.FormatNumber(count)))
                end
            end
        end)
    end
end

function Util.SendDiscordAlert(deals)
    if not deals or #deals == 0 or not DISCORD_WEBHOOK_URL or #DISCORD_WEBHOOK_URL == 0 then return end
    
    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if not req then return end

    task.spawn(function()
        -- Kirim SATU PER SATU per item deal dengan format ringkas & simpel
        for i, d in ipairs(deals) do
            if i > 15 then break end

            pcall(function()
                local cat = d.Category or "Sword"
                local catIcon = (cat == "Sword" and "🗡️") 
                    or (cat == "Emote" and "💃") 
                    or (cat == "Explosion" and "💥") 
                    or "📦"

                local isOver = (d.Profit < 0)
                local isEven = (d.Profit == 0)
                local estUntung = (d.Profit > 0) and string.format("**+%s** tokens", Util.FormatNumber(d.Profit))
                    or isEven and "**Pas RAP** (0 tokens)"
                    or string.format("**-%s** tokens", Util.FormatNumber(math.abs(d.Profit)))

                local embedColor = isOver and 16763904
                    or isEven and 3901686
                    or d.IsSpecial and 10181046 
                    or ((d.Profit >= 1000) and 16098851 or 5763719)

                local embed = {
                    title = string.format("%s %s", catIcon, d.Name),
                    color = embedColor,
                    fields = {
                        {
                            name = "💰 Harga Booth",
                            value = string.format("**%s** tokens", Util.FormatNumber(d.Price)),
                            inline = true
                        },
                        {
                            name = "📊 Value (RAP)",
                            value = string.format("**%s** tokens", Util.FormatNumber(d.RAP)),
                            inline = true
                        },
                        {
                            name = isOver and "📉 Selisih Harga" or "📈 Estimasi Untung",
                            value = estUntung,
                            inline = true
                        },
                        {
                            name = "👤 Pemilik",
                            value = string.format("@%s", d.Seller),
                            inline = true
                        },
                        {
                            name = "🏷️ Tipe",
                            value = string.format("%s", cat),
                            inline = true
                        }
                    },
                    footer = {
                        text = string.format("Job ID: %s", tostring(JobId))
                    }
                }

                local payload = HttpService:JSONEncode({
                    username = "Blade Ball Sniper",
                    embeds = { embed }
                })

                req({
                    Url = DISCORD_WEBHOOK_URL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = payload
                })
            end)

            task.wait(0.35)
        end
    end)
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

    -- [DELTA AUTO-EXECUTE]: Titipkan script ke executor agar otomatis berjalan di server baru!
    local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if queue then
        pcall(function()
            queue('loadstring(game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/scripts/delta_plaza_sniper.lua"))()')
        end)
    end

    local req = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
    if req then
        -- Riwayat server yang sudah dikunjungi (biar server selalu ganti & tidak balik ke server lama)
        local visited = {}
        pcall(function()
            if isfile and readfile and isfile("bb_visited_servers.json") then
                local raw = readfile("bb_visited_servers.json")
                if raw and #raw > 5 then
                    local parsed = HttpService:JSONDecode(raw)
                    local now = os.time()
                    for sId, t in pairs(parsed) do
                        if (now - (tonumber(t) or 0)) < 1800 then -- bersihkan cache di atas 30 menit
                            visited[sId] = t
                        end
                    end
                end
            end
        end)
        visited[JobId] = os.time()

        local url = string.format("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Desc&limit=100", tostring(PlaceId))
        local ok, res = pcall(function() return req({ Url = url, Method = "GET" }) end)
        if ok and res and res.StatusCode == 200 then
            local data = HttpService:JSONDecode(res.Body)
            if data and data.data then
                local candidates = {}
                local fallbackCandidates = {}

                for _, s in ipairs(data.data) do
                    if type(s) == "table" and s.id ~= JobId and s.playing and s.maxPlayers then
                        local p = tonumber(s.playing) or 0
                        local m = tonumber(s.maxPlayers) or 30
                        if (m - p >= 2) and (p >= minPlayers and p <= maxPlayers) then
                            table.insert(fallbackCandidates, s.id)
                            if not visited[s.id] then
                                table.insert(candidates, s.id)
                            end
                        end
                    end
                end

                local targetList = (#candidates > 0) and candidates or fallbackCandidates
                if #targetList > 0 then
                    local targetServer = targetList[math.random(1, #targetList)]
                    visited[targetServer] = os.time()
                    pcall(function()
                        if writefile then
                            writefile("bb_visited_servers.json", HttpService:JSONEncode(visited))
                        end
                    end)

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
    AutoHopWhenEmpty = false,
    AutoHop5Min = true,           -- Default ON untuk bot AFK 24/7 Redfinger
    HopIntervalSeconds = 300,     -- 5 Menit = 300 detik
    RemainingHopSeconds = 300
}

function PlazaEngine.IsQualifiedDeal(rap, price, itemName, category)
    if not price or price <= 0 then return false, false, nil end

    -- [A] CEK SPECIAL WATCHLIST (Pengecualian Over-RAP untuk Item Hype / High-Demand)
    local kSpaced = tostring(itemName or ""):lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local kClean = tostring(itemName or ""):lower():gsub("%s+", "")
    local special = SPECIAL_WATCHLIST[kSpaced] or SPECIAL_WATCHLIST[kClean]

    if special then
        local catOk = true
        if special.Category and category then
            if tostring(category):lower() ~= tostring(special.Category):lower() then
                catOk = false
            end
        end

        if catOk and price <= special.MaxPrice then
            return true, true, special -- isQualified, isSpecial, specialRule
        end
    end

    -- [B] Item High-Tier 10k - 20k: Tampilkan juga walaupun TIDAK under RAP!
    -- Kriteria: Value (RAP) berada di rentang 10.000 s/d 20.000, harga booth tidak melebihi batas 22.000
    if rap and rap >= 10000 and rap <= 20000 then
        if price <= 22000 then
            local highRule = {
                Reason = "💎 High-Tier 10k-20k"
            }
            return true, true, highRule
        end
    end

    -- [C] Kriteria Standar Under-RAP
    if not rap or rap <= 0 then return false, false, nil end
    local profit = rap - price
    if profit <= 0 then return false, false, nil end

    -- [Kriteria 1]: Item Value 200 - 299 -> Tampilkan jika under 70 keatas (profit >= 70)
    if rap >= 200 and rap < 300 then
        return (profit >= 70), false, nil
    end

    -- [Kriteria 2]: Item Value 300 s/d Infinity -> Tampilkan jika under 100 keatas (profit >= 100)
    if rap >= 300 then
        return (profit >= 100), false, nil
    end

    return false, false, nil
end

function PlazaEngine.DetectCategory(frame, itemName)
    local lowerName = tostring(itemName or ""):lower():match("^%s*(.-)%s*$")
    local cleanName = lowerName:gsub("%s+", "")

    -- 1. CEK SUFFIX NAMA LANGSUNG (Jika nama item eksplisit di booth)
    if lowerName:find("explosion") or lowerName:find("blast") or lowerName:find("detonation") or lowerName:find("burst") or lowerName:find("nova") or lowerName:find("drop") then
        return "Explosion"
    end
    if lowerName:find("emote") or lowerName:find("dance") or lowerName:find("giggle") or lowerName:find("sit") or lowerName:find("pose") then
        return "Emote"
    end

    -- 2. CEK VIEWPORTFRAME (Model 3D Item di Booth)
    -- Ini SANGAT KRUSIAL untuk item set dengan nama sama persis (misal: "Higanbana Katana" atau "Crimson Kagune")
    if frame then
        local vp = frame:FindFirstChildWhichIsA("ViewportFrame", true)
        if vp then
            -- [EMOTE DETECTION]:
            -- Emote di Blade Ball SELALU menggunakan model dummy karakter Roblox (Humanoid / Body parts)
            local hasHumanoid = vp:FindFirstChildWhichIsA("Humanoid", true) 
                or vp:FindFirstChild("HumanoidRootPart", true)
                or vp:FindFirstChild("Head", true)
                or vp:FindFirstChild("UpperTorso", true)
                or vp:FindFirstChild("Torso", true)
                or vp:FindFirstChild("LowerTorso", true)
            if hasHumanoid then
                return "Emote"
            end

            -- [EXPLOSION DETECTION]:
            -- Explosion memiliki efek partikel (ParticleEmitter, Beam, Trail) atau nama objek bertema ledakan
            local hasParticles = vp:FindFirstChildWhichIsA("ParticleEmitter", true)
                or vp:FindFirstChildWhichIsA("Beam", true)
                or vp:FindFirstChildWhichIsA("Trail", true)
            if hasParticles then
                return "Explosion"
            end

            for _, obj in ipairs(vp:GetDescendants()) do
                local on = obj.Name:lower()
                if on:find("explosion") or on:find("vfx") or on:find("effect") or on:find("burst") or on:find("sphere") or on:find("ball") then
                    return "Explosion"
                end
            end

            -- [SWORD DETECTION via ViewportFrame]:
            -- Jika ada nama pedang atau jika terdapat MeshPart/Model tanpa Humanoid dan tanpa partikel,
            -- maka ini 100% adalah SWORD!
            for _, obj in ipairs(vp:GetDescendants()) do
                local on = obj.Name:lower()
                if on:find("sword") or on:find("katana") or on:find("blade") or on:find("scythe") or on:find("handle") or on:find("weapon") then
                    return "Sword"
                end
            end

            local hasMesh = vp:FindFirstChildWhichIsA("MeshPart", true)
                or vp:FindFirstChildWhichIsA("SpecialMesh", true)
                or vp:FindFirstChildWhichIsA("Part", true)
                or vp:FindFirstChildWhichIsA("Model", true)
            if hasMesh then
                return "Sword"
            end
        end

        -- 3. CEK ATTRIBUTES ATAU BADGE PADA FRAME BOOTH
        local attrType = frame:GetAttribute("Type") or frame:GetAttribute("ItemType") or frame:GetAttribute("Category")
        local itemBtn = frame:FindFirstChild("Frame")
        if not attrType and itemBtn then
            attrType = itemBtn:GetAttribute("Type") or itemBtn:GetAttribute("ItemType") or itemBtn:GetAttribute("Category")
        end
        if attrType then
            local a = tostring(attrType):lower()
            if a:find("sword") or a:find("weapon") then return "Sword"
            elseif a:find("emote") then return "Emote"
            elseif a:find("explo") then return "Explosion"
            end
        end

        for _, img in ipairs(frame:GetDescendants()) do
            if img:IsA("ImageLabel") and img.Visible then
                local iname = img.Name:lower()
                if iname:find("sword") then return "Sword"
                elseif iname:find("emote") then return "Emote"
                elseif iname:find("explo") then return "Explosion"
                end
            end
        end
    end

    -- 4. CEK REPLICATEDSTORAGE BLADE BALL (Aset internal game)
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        local exploDirs = {
            rs:FindFirstChild("Explosions"),
            rs:FindFirstChild("Misc") and rs.Misc:FindFirstChild("DataExplosions"),
            rs:FindFirstChild("Shared") and rs.Shared:FindFirstChild("Explosions")
        }
        for _, dir in ipairs(exploDirs) do
            if dir then
                for _, ch in ipairs(dir:GetChildren()) do
                    local cn = ch.Name:lower():gsub("%s+", "")
                    if cn == cleanName or cn == cleanName .. "explosion" or cleanName == cn .. "explosion" then
                        return "Explosion"
                    end
                end
            end
        end

        local emoteDirs = {
            rs:FindFirstChild("Emotes"),
            rs:FindFirstChild("Misc") and rs.Misc:FindFirstChild("Emotes"),
            rs:FindFirstChild("Shared") and rs.Shared:FindFirstChild("Emotes")
        }
        for _, dir in ipairs(emoteDirs) do
            if dir then
                for _, ch in ipairs(dir:GetChildren()) do
                    local cn = ch.Name:lower():gsub("%s+", "")
                    if cn == cleanName or cn == cleanName .. "emote" or cleanName == cn .. "emote" then
                        return "Emote"
                    end
                end
            end
        end
    end)

    -- 5. CEK APAKAH NAMA INI DIKETAHUI MEMILIKI VARIAN EXPLOSION / EMOTE
    local entry = RAP_DATABASE[lowerName] or RAP_DATABASE[cleanName]
    if type(entry) == "table" and (entry.Explosion or entry.Emote) then
        return "Unknown"
    end

    -- 6. KEYWORD SENJATA UNTUK ITEM TUNGGAL
    if lowerName:find("blade") or lowerName:find("sword") or lowerName:find("katana") or lowerName:find("scythe") or lowerName:find("spear") or lowerName:find("dagger") or lowerName:find("axe") or lowerName:find("rapier") or lowerName:find("hammer") or lowerName:find("bat") or lowerName:find("staff") or lowerName:find("greatblade") or lowerName:find("thorn") or lowerName:find("wrath") or lowerName:find("tanto") or lowerName:find("bow") or lowerName:find("slicer") or lowerName:find("fang") or lowerName:find("cutter") or lowerName:find("cleaver") then
        return "Sword"
    end

    return "Unknown"
end

function PlazaEngine.GetRapValue(itemName, category, price)
    if not itemName or #itemName == 0 then return 0, "Unknown" end
    price = tonumber(price) or 0

    local kSpaced = itemName:lower():gsub("%s+", " "):match("^%s*(.-)%s*$")
    local kClean = itemName:lower():gsub("%s+", "")
    local catLower = category and category:lower() or "unknown"

    -- 1. Ambil entry dari database (cek dengan spasi maupun tanpa spasi)
    local entry = RAP_DATABASE[kSpaced] or RAP_DATABASE[kClean]

    -- JIKA ITEM MEMILIKI MULTI-KATEGORI (Tabel { Sword = ..., Explosion = ..., Emote = ... })
    if type(entry) == "table" then
        local variants = {}
        for cName, cVal in pairs(entry) do
            local num = tonumber(cVal) or 0
            if num > 0 then
                table.insert(variants, { type = tostring(cName), val = num })
            end
        end

        if #variants > 0 then
            -- Saring varian jika kategori spesifik (Emote vs Sword vs Explosion) sudah terdeteksi di booth
            local candidates = {}
            if catLower ~= "unknown" then
                for _, v in ipairs(variants) do
                    if v.type:lower():find(catLower) then
                        table.insert(candidates, v)
                    end
                end
            end
            if #candidates == 0 then
                candidates = variants
            end

            -- [LOGIKA HARGA TERDEKAT / NEAREST ABSOLUTE VALUE UNTUK SEMUA ITEM]:
            -- Bandingkan harga booth ke semua nilai di website, dan pilih yang SELISIHNYA PALING KECIL!
            -- Contoh Kasus:
            -- 1. Reindeer: Value 38.498 vs 55.929.
            --    Harga Booth: 39.500
            --    Selisih ke 38.498 = |39.500 - 38.498| = 1.002
            --    Selisih ke 55.929 = |39.500 - 55.929| = 16.429
            --    => Otomatis pilih 38.498 (selisih 1.002).
            --    Karena 39.500 > 38.498 (rugi -1.002), deal otomatis dibuang dan TIDAK dikirim!
            -- 2. Sea Turtle: Value 928 vs 10.821 (Explosion terpisah: 1.533).
            --    Harga Booth: 1.222 => Selisih ke 928 = 294 => Pilih 928 => Dibuang.
            -- 3. Event Horizon: Value 7 vs 591.
            --    Harga Booth: 8 => Selisih ke 7 = 1 => Pilih 7 => Dibuang.
            table.sort(candidates, function(a, b) return a.val < b.val end)
            local chosen = candidates[1]
            local minDiff = math.huge

            if price > 0 then
                for _, v in ipairs(candidates) do
                    local diff = math.abs(price - v.val)
                    if diff < minDiff then
                        minDiff = diff
                        chosen = v
                    end
                end
            end

            return chosen.val, chosen.type
        end
    end

    -- 2. Cek key eksplisit spesifik: misalnya "higanbana katana#emote"
    if catLower ~= "unknown" then
        local specificVal = RAP_DATABASE[kSpaced .. "#" .. catLower] or RAP_DATABASE[kClean .. "#" .. catLower]
        if specificVal and tonumber(specificVal) and tonumber(specificVal) > 0 then
            local properCat = (catLower == "sword" and "Sword") or (catLower == "emote" and "Emote") or (catLower == "explosion" and "Explosion") or "Unknown"
            return tonumber(specificVal), properCat
        end
    end

    -- 3. Entry berupa single number (item unik tanpa varian ganda)
    if type(entry) == "number" and entry > 0 then
        return entry, (catLower ~= "unknown" and category or "Sword")
    end

    return 0, "Unknown"
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

                -- Buka booth (panggil fungsi aman executor)
                pcall(function() fireproximityprompt(prompt) end)

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
                                local detectedCategory = PlazaEngine.DetectCategory(frame, itemName)
                                local rap, resolvedCategory = PlazaEngine.GetRapValue(itemName, detectedCategory, price)
                                local category = resolvedCategory or detectedCategory
                                local profit = (rap > 0) and (rap - price) or 0
                                local discountPct = (rap > 0) and math.floor(((rap - price) / rap) * 100) or 0
                                local isQualified, isSpecial, sRule = PlazaEngine.IsQualifiedDeal(rap, price, itemName, category)

                                local effectiveRap = rap
                                local specialReason = nil
                                if isSpecial and sRule then
                                    specialReason = sRule.Reason
                                    if sRule.ResellTarget and sRule.ResellTarget > price then
                                        profit = sRule.ResellTarget - price
                                        effectiveRap = sRule.ResellTarget
                                        discountPct = math.floor(((sRule.ResellTarget - price) / sRule.ResellTarget) * 100)
                                    else
                                        profit = (rap > 0) and (rap - price) or 0
                                    end
                                end

                                local listing = {
                                    Name = itemName,
                                    Category = category,
                                    Price = price,
                                    RAP = rap,
                                    EffectiveRAP = effectiveRap,
                                    Profit = profit,
                                    Discount = discountPct,
                                    IsUnderRap = isQualified,
                                    IsSpecial = isSpecial,
                                    SpecialReason = specialReason,
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
                task.wait(0.35)
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
        Util.SendDiscordAlert(deals)
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
    sub.Text = "🎯 Val 200-299 (Under ≥70) | 300+ (Under ≥100)"
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
            empty.Text = "Belum ada deal sesuai kriteria filter:\n• Value 200 - 299 (Under ≥ 70)\n• Value 300+ (Under ≥ 100)\n\nTekan '⚡ SCAN SEMUA BOOTH' di bawah!"
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
            local cat = d.Category or "Item"
            local catBadge = (cat == "Sword" and "[🗡️ SWORD] ") or (cat == "Emote" and "[💃 EMOTE] ") or (cat == "Explosion" and "[💥 EXPLO] ") or ""
            nl.Text = catBadge .. d.Name
            nl.Font = Enum.Font.GothamBold
            nl.TextSize = 11
            nl.TextXAlignment = Enum.TextXAlignment.Left
            nl.Parent = card

            local tag = Instance.new("TextLabel")
            tag.Size = UDim2.new(0, 80, 0, 18)
            tag.Position = UDim2.new(1, -86, 0, 4)
            tag.BackgroundColor3 = d.IsSpecial and Color3.fromRGB(147, 51, 234) or Color3.fromRGB(5, 150, 105)
            tag.TextColor3 = Color3.fromRGB(255, 255, 255)
            tag.Text = d.IsSpecial and "💎 WORTH IT" or string.format("🔥 -%d%% OFF", d.Discount)
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

    -- Box 1: Auto-Hop Tiap 5 Menit (AFK 24/7 Redfinger Mode)
    local autoHop5MinBox = Instance.new("Frame")
    autoHop5MinBox.Size = UDim2.new(1, 0, 0, 50)
    autoHop5MinBox.Position = UDim2.new(0, 0, 0, 146)
    autoHop5MinBox.BackgroundColor3 = Color3.fromRGB(18, 26, 46)
    autoHop5MinBox.Parent = paneHop
    Instance.new("UICorner", autoHop5MinBox).CornerRadius = UDim.new(0, 8)

    local autoHop5MinTxt = Instance.new("TextLabel")
    autoHop5MinTxt.Size = UDim2.new(1, -70, 0, 22)
    autoHop5MinTxt.Position = UDim2.new(0, 10, 0, 4)
    autoHop5MinTxt.BackgroundTransparency = 1
    autoHop5MinTxt.TextColor3 = Color3.fromRGB(241, 245, 249)
    autoHop5MinTxt.Text = "⏱️ Auto-Hop Tiap 5 Menit (AFK):"
    autoHop5MinTxt.Font = Enum.Font.GothamBold
    autoHop5MinTxt.TextSize = 10
    autoHop5MinTxt.TextXAlignment = Enum.TextXAlignment.Left
    autoHop5MinTxt.Parent = autoHop5MinBox

    local autoHop5MinSub = Instance.new("TextLabel")
    autoHop5MinSub.Size = UDim2.new(1, -70, 0, 20)
    autoHop5MinSub.Position = UDim2.new(0, 10, 0, 26)
    autoHop5MinSub.BackgroundTransparency = 1
    autoHop5MinSub.TextColor3 = Color3.fromRGB(56, 189, 248)
    autoHop5MinSub.Text = "Hop Server dalam: 05:00"
    autoHop5MinSub.Font = Enum.Font.Gotham
    autoHop5MinSub.TextSize = 9.5
    autoHop5MinSub.TextXAlignment = Enum.TextXAlignment.Left
    autoHop5MinSub.Parent = autoHop5MinBox

    local btnToggleHop5 = Instance.new("TextButton")
    btnToggleHop5.Size = UDim2.new(0, 52, 0, 30)
    btnToggleHop5.Position = UDim2.new(1, -60, 0, 10)
    btnToggleHop5.BackgroundColor3 = PlazaEngine.AutoHop5Min and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(51, 65, 85)
    btnToggleHop5.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnToggleHop5.Text = PlazaEngine.AutoHop5Min and "ON" or "OFF"
    btnToggleHop5.Font = Enum.Font.GothamBold
    btnToggleHop5.TextSize = 10
    btnToggleHop5.Parent = autoHop5MinBox
    Instance.new("UICorner", btnToggleHop5).CornerRadius = UDim.new(0, 6)

    btnToggleHop5.MouseButton1Click:Connect(function()
        PlazaEngine.AutoHop5Min = not PlazaEngine.AutoHop5Min
        btnToggleHop5.Text = PlazaEngine.AutoHop5Min and "ON" or "OFF"
        btnToggleHop5.BackgroundColor3 = PlazaEngine.AutoHop5Min and Color3.fromRGB(16, 185, 129) or Color3.fromRGB(51, 65, 85)
        Util.Notify("Auto-Hop 5 Menit", PlazaEngine.AutoHop5Min and "Diaktifkan! Server hop setiap 5 menit." or "Dimatikan.")
    end)

    -- Box 2: Auto-Hop jika kosong deal
    local autoHopBox = Instance.new("Frame")
    autoHopBox.Size = UDim2.new(1, 0, 0, 44)
    autoHopBox.Position = UDim2.new(0, 0, 0, 202)
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
    btnToggleHop.Size = UDim2.new(0, 52, 0, 26)
    btnToggleHop.Position = UDim2.new(1, -60, 0, 9)
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

    -- Update label timer secara realtime
    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                if autoHop5MinSub and autoHop5MinSub.Parent then
                    if PlazaEngine.AutoHop5Min then
                        local rem = PlazaEngine.RemainingHopSeconds or 0
                        local mins = math.floor(rem / 60)
                        local secs = rem % 60
                        autoHop5MinSub.Text = string.format("Hop Server dalam: %02d:%02d", mins, secs)
                    else
                        autoHop5MinSub.Text = "Auto-Hop Dimatikan (Manual)"
                    end
                end
            end)
        end
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

-- [1] Scan otomatis setelah tiba di server baru
task.spawn(function()
    task.wait(3)
    PlazaEngine.ScanAllBooths(function(msg) end)
    if renderFn then renderFn() end
end)

-- [2] Loop Auto-Hop Tiap 5 Menit (AFK 24/7 Redfinger Mode)
task.spawn(function()
    while true do
        task.wait(1)
        if PlazaEngine.AutoHop5Min then
            PlazaEngine.RemainingHopSeconds = (PlazaEngine.RemainingHopSeconds or 300) - 1
            if PlazaEngine.RemainingHopSeconds <= 0 then
                Util.Notify("🌐 Auto-Hop (5 Menit)", "Waktu 5 menit tercapai! Melompat ke server Trade Plaza baru...", true)
                task.wait(2)
                Navigator.ServerHop(6, 26)
                break
            end
        end
    end
end)
