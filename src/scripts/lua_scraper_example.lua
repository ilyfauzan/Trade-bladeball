--[[
    =================================================================================
    ⚔️ BLADE BALL TRADE PLAZA - REAL-TIME BOOTH SCRAPER (VERIFIED FOR HUB.STANDS)
    =================================================================================
    Struktur Folder Game: Workspace.Spawn.Hub.Stands
    Target API: http://127.0.0.1:3001/api
    =================================================================================
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

-- Menggunakan IP 127.0.0.1 (terbukti sukses terhubung dengan Solara di log server)
local SERVER_URL = "http://127.0.0.1:3001/api"
local API_KEY = "bb_trade_plaza_secret_2026"

local sendHttpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
if not sendHttpRequest then
    warn("❌ Executor Anda tidak mendukung fungsi HTTP request!")
    return
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5
        })
    end)
end

local function postData(endpoint, dataTable)
    local success, jsonPayload = pcall(function()
        return HttpService:JSONEncode(dataTable)
    end)
    if not success then return nil end

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

-- Parser angka / harga
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

-- =================================================================================
-- FUNGSI SCAN SEMUA BOOTH DI WORKSPACE.SPAWN.HUB.STANDS
-- =================================================================================
local function scanAllBooths()
    print("\n[BB Bridge] 🔍 MEMULAI PEMINDAIAN BOOTH DI Workspace.Spawn.Hub.Stands...")

    local standsFolder = workspace:FindFirstChild("Spawn") 
        and workspace.Spawn:FindFirstChild("Hub") 
        and workspace.Spawn.Hub:FindFirstChild("Stands")

    if not standsFolder then
        -- Fallback pencarian fleksibel
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "Stands" and obj:IsA("Folder") or obj:IsA("Model") then
                standsFolder = obj
                break
            end
        end
    end

    if not standsFolder then
        warn("[BB Bridge] ❌ Folder Stands tidak ditemukan di Workspace!")
        return
    end

    local stands = standsFolder:GetChildren()
    print(string.format("[BB Bridge] 📌 Ditemukan %d Stand di Trade Plaza!", #stands))

    local scannedItems = {}

    for index, stand in ipairs(stands) do
        pcall(function()
            local ownerName = "Unknown"
            local itemName = ""
            local boothPrice = 0
            local currentRap = 0

            -- 1. Cek Attributes pada Stand, Booth, atau Root
            local attrs = stand:GetAttributes()
            for k, v in pairs(attrs) do
                local kl = k:lower()
                if kl:find("owner") or kl:find("player") or kl:find("user") then ownerName = tostring(v)
                elseif kl:find("item") or kl:find("sword") or kl:find("name") then itemName = tostring(v)
                elseif kl:find("price") or kl:find("token") or kl:find("cost") then boothPrice = parsePrice(v)
                elseif kl:find("rap") then currentRap = parsePrice(v) end
            end

            -- 2. Cek semua TextLabel dan Value di dalam Stand (BillboardGui, SurfaceGui, dsb)
            for _, desc in ipairs(stand:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text and #desc.Text > 0 then
                    local t = desc.Text
                    local tl = t:lower()

                    -- Deteksi Pemilik
                    if tl:find("'s booth") or tl:find("booth of") then
                        ownerName = t:gsub("'s booth", ""):gsub("Booth of", ""):gsub("%s+", "")
                    -- Deteksi RAP
                    elseif tl:find("rap") then
                        currentRap = parsePrice(t)
                    -- Deteksi Harga
                    elseif tl:find("price") or tl:find("tokens") or tl:find("gems") or t:find("^%d+[,%d]*$") then
                        local p = parsePrice(t)
                        if p > 0 and boothPrice == 0 then boothPrice = p end
                    -- Deteksi Nama Item (panjang teks > 2 dan bukan sekadar angka murni)
                    elseif not t:find("^%d+$") and not tl:find("claim") and not tl:find("stand") and not tl:find("prompt") then
                        if #t > 2 and itemName == "" then
                            itemName = t:gsub("%[.-%]", ""):match("^%s*(.-)%s*$")
                        end
                    end
                elseif desc:IsA("StringValue") then
                    if desc.Name:lower():find("item") then itemName = desc.Value
                    elseif desc.Name:lower():find("owner") then ownerName = desc.Value end
                elseif desc:IsA("NumberValue") or desc:IsA("IntValue") then
                    if desc.Name:lower():find("price") then boothPrice = desc.Value
                    elseif desc.Name:lower():find("rap") then currentRap = desc.Value end
                end
            end

            -- Jika ditemukan item atau harga valid di booth ini
            if (#itemName > 2 or boothPrice > 0) and ownerName ~= "Unknown" then
                if itemName == "" then itemName = "Booth Item #" .. tostring(index) end
                print(string.format("  [Booth %d] Penjual: %s | Item: %s | Harga: %d | RAP: %d", index, ownerName, itemName, boothPrice, currentRap))
                table.insert(scannedItems, {
                    itemName = itemName,
                    category = "Sword",
                    boothPrice = boothPrice > 0 and boothPrice or currentRap,
                    currentRap = currentRap,
                    seller = ownerName,
                    boothId = stand.Name
                })
            end
        end)
    end

    print(string.format("[BB Bridge] 📊 Total item booth berhasil dibaca: %d", #scannedItems))

    if #scannedItems > 0 then
        local res = postData("/booth-feed", scannedItems)
        if res and res.success then
            notify("✅ Sync Berhasil!", "Mengirim " .. tostring(res.count) .. " item ke Web Tracker!")
            print("==========================================================")
            print("🚀 SUKSES MENGIRIM " .. tostring(res.count) .. " BOOTH KE DASHBOARD WEB!")
            print("==========================================================")
        end
    else
        -- Jika pembacaan textlabel belum menemukan teks spesifik, mari dump 1 booth agar kita lihat isinya
        print("[BB Bridge] ⚠️ Belum ada booth aktif yang terbaca teksnya. Mari bedah isi Stand pertama:")
        if stands[1] then
            for _, d in ipairs(stands[1]:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ValueBase") then
                    print("   -> " .. d.ClassName .. ": " .. d.Name .. (d:IsA("TextLabel") and (" [Text: " .. d.Text .. "]") or ""))
                end
            end
        end
    end
end

-- =================================================================================
-- TOMBOL SCREEN GUI CEPAT
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
    scanBtn.Size = UDim2.new(0, 150, 0, 44)
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

createMiniScreenButton()
notify("⚔️ BB Tracker Ready", "Terhubung ke " .. SERVER_URL)
scanAllBooths()

_G.BBTracker = { Scan = scanAllBooths }
print("✅ SCRIPT BOOTH SCRAPER AKTIF!")
