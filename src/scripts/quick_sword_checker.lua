--[[
    =================================================================================
    BLADE BALL QUICK SWORD CHECKER (Solara / Delta / Wave)
    =================================================================================
    Fitur:
    1. Ketik nama sword di textbox
    2. Tekan "🔍 CEK SWORD"
    3. Langsung tampil:
       - RAP Price (Official RAP & Clean RAP riil)
       - 5 Riwayat Sales Terakhir (dengan tanda apakah ada transaksi dump 1 token)
       - Status Manipulasi: NUKED, BOOSTED, PROJECTED, atau NORMAL
    4. Tombol 1-klik untuk langsung mengirim ke Kalkulator Web (Sisi Anda / Sisi Lawan)
    =================================================================================
--]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local SERVER_URL = "http://127.0.0.1:3001/api"
local API_KEY = "bb_trade_plaza_secret_2026"

local sendHttpRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
if not sendHttpRequest then
    warn("[BB Checker] Executor tidak support HTTP request!")
    return
end

local function notify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = 4
        })
    end)
end

local function formatNum(n)
    n = tonumber(n) or 0
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-- ============================================================
-- GUI UTAMA (Movable & Modern Dark UI)
-- ============================================================
local function createCheckerGui()
    local pGui = LocalPlayer:WaitForChild("PlayerGui", 5)
    if not pGui then return end

    local old = pGui:FindFirstChild("BBSwordChecker")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "BBSwordChecker"
    sg.ResetOnSpawn = false
    sg.Parent = pGui

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 310, 0, 260)
    frame.Position = UDim2.new(0.02, 0, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local fStroke = Instance.new("UIStroke", frame)
    fStroke.Color = Color3.fromRGB(99, 102, 241)
    fStroke.Thickness = 1.5

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Position = UDim2.new(0, 0, 0, 4)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(56, 189, 248)
    title.Text = "⚔️ BLADE BALL SWORD CHECKER"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.Parent = frame

    -- Subtitle
    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0, 14)
    sub.Position = UDim2.new(0, 0, 0, 28)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromRGB(148, 163, 184)
    sub.Text = "Cek RAP, 5 Sales & Status Nuked/Boosted"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 9
    sub.Parent = frame

    -- TextBox Input Sword Name
    local input = Instance.new("TextBox")
    input.Name = "InputName"
    input.Size = UDim2.new(1, -20, 0, 30)
    input.Position = UDim2.new(0, 10, 0, 48)
    input.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.PlaceholderText = "Ketik nama sword (mis: Singularity Katana)..."
    input.PlaceholderColor3 = Color3.fromRGB(100, 116, 139)
    input.Font = Enum.Font.Gotham
    input.TextSize = 10
    input.ClearTextOnFocus = false
    input.Parent = frame
    Instance.new("UICorner", input).CornerRadius = UDim.new(0, 6)

    -- Button Check
    local btnCheck = Instance.new("TextButton")
    btnCheck.Size = UDim2.new(1, -20, 0, 28)
    btnCheck.Position = UDim2.new(0, 10, 0, 84)
    btnCheck.BackgroundColor3 = Color3.fromRGB(79, 70, 229)
    btnCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnCheck.Text = "🔍 CEK DATA SWORD"
    btnCheck.Font = Enum.Font.GothamBold
    btnCheck.TextSize = 11
    btnCheck.Parent = frame
    Instance.new("UICorner", btnCheck).CornerRadius = UDim.new(0, 6)

    -- Result Display Box
    local resBox = Instance.new("Frame")
    resBox.Size = UDim2.new(1, -20, 0, 130)
    resBox.Position = UDim2.new(0, 10, 0, 118)
    resBox.BackgroundColor3 = Color3.fromRGB(11, 15, 25)
    resBox.Parent = frame
    Instance.new("UICorner", resBox).CornerRadius = UDim.new(0, 6)

    local resTitle = Instance.new("TextLabel")
    resTitle.Size = UDim2.new(1, -12, 0, 20)
    resTitle.Position = UDim2.new(0, 6, 0, 4)
    resTitle.BackgroundTransparency = 1
    resTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    resTitle.Text = "Status: Siap cek..."
    resTitle.Font = Enum.Font.GothamBold
    resTitle.TextSize = 10
    resTitle.TextXAlignment = Enum.TextXAlignment.Left
    resTitle.Parent = resBox

    local resRap = Instance.new("TextLabel")
    resRap.Size = UDim2.new(1, -12, 0, 18)
    resRap.Position = UDim2.new(0, 6, 0, 26)
    resRap.BackgroundTransparency = 1
    resRap.TextColor3 = Color3.fromRGB(56, 189, 248)
    resRap.Text = "Clean RAP: - | Game RAP: -"
    resRap.Font = Enum.Font.Gotham
    resRap.TextSize = 9
    resRap.TextXAlignment = Enum.TextXAlignment.Left
    resRap.Parent = resBox

    local resSales = Instance.new("TextLabel")
    resSales.Size = UDim2.new(1, -12, 0, 36)
    resSales.Position = UDim2.new(0, 6, 0, 46)
    resSales.BackgroundTransparency = 1
    resSales.TextColor3 = Color3.fromRGB(203, 213, 225)
    resSales.Text = "5 Sales Terakhir: -"
    resSales.Font = Enum.Font.Gotham
    resSales.TextSize = 8
    resSales.TextWrapped = true
    resSales.TextXAlignment = Enum.TextXAlignment.Left
    resSales.TextYAlignment = Enum.TextYAlignment.Top
    resSales.Parent = resBox

    local resDiag = Instance.new("TextLabel")
    resDiag.Size = UDim2.new(1, -12, 0, 40)
    resDiag.Position = UDim2.new(0, 6, 0, 84)
    resDiag.BackgroundTransparency = 1
    resDiag.TextColor3 = Color3.fromRGB(251, 191, 36)
    resDiag.Text = "Diagnosis: Ketik nama sword di atas lalu klik Cek Data."
    resDiag.Font = Enum.Font.Gotham
    resDiag.TextSize = 8
    resDiag.TextWrapped = true
    resDiag.TextXAlignment = Enum.TextXAlignment.Left
    resDiag.TextYAlignment = Enum.TextYAlignment.Top
    resDiag.Parent = resBox

    -- Function to execute search
    local function doCheck()
        local name = input.Text:match("^%s*(.-)%s*$")
        if not name or #name < 1 then
            resTitle.Text = "❌ Harap masukkan nama sword!"
            resTitle.TextColor3 = Color3.fromRGB(244, 63, 94)
            return
        end

        resTitle.Text = "⏳ Mencari data " .. name .. "..."
        resTitle.TextColor3 = Color3.fromRGB(148, 163, 184)

        task.spawn(function()
            local url = SERVER_URL .. "/items/" .. HttpService:UrlEncode(name)
            local res = sendHttpRequest({
                Url = url,
                Method = "GET",
                Headers = { ["Content-Type"] = "application/json" }
            })

            if not res or res.StatusCode ~= 200 then
                resTitle.Text = "❌ Item tidak ditemukan!"
                resTitle.TextColor3 = Color3.fromRGB(244, 63, 94)
                resRap.Text = "Belum ada di katalog tracker"
                resSales.Text = "5 Sales: Belum tercatat"
                resDiag.Text = "Gunakan tombol input di web dashboard untuk mendaftarkan sword ini."
                return
            end

            local ok, json = pcall(function()
                return HttpService:JSONDecode(res.Body)
            end)

            if not ok or not json or not json.data then
                resTitle.Text = "❌ Gagal decode respons server"
                return
            end

            local it = json.data
            local st = it.status or "NORMAL"
            local clean = it.clean_rap or 0
            local curRap = it.current_rap or 0

            -- Set Status Title
            if st == "NUKED" then
                resTitle.Text = "💥 NUKED DETECTED! (" .. it.name .. ")"
                resTitle.TextColor3 = Color3.fromRGB(245, 158, 11)
            elseif st == "BOOSTED" then
                resTitle.Text = "⚡ BOOSTED DETECTED! (" .. it.name .. ")"
                resTitle.TextColor3 = Color3.fromRGB(99, 102, 241)
            elseif st == "PROJECTED" then
                resTitle.Text = "🚨 PROJECTED SCAM! (" .. it.name .. ")"
                resTitle.TextColor3 = Color3.fromRGB(244, 63, 94)
            else
                resTitle.Text = "🟢 STATUS NORMAL (" .. it.name .. ")"
                resTitle.TextColor3 = Color3.fromRGB(16, 185, 129)
            end

            -- Set RAP Line
            resRap.Text = "Clean RAP: " .. formatNum(clean) .. " | Game RAP: " .. formatNum(curRap)

            -- Format 5 Sales
            local salesStr = "5 Sales Terakhir: "
            if it.salesHistory and #it.salesHistory > 0 then
                local list = {}
                for i = 1, math.min(5, #it.salesHistory) do
                    local s = it.salesHistory[i]
                    local p = s.price or 0
                    local tag = s.is_outlier == 1 and (p <= 10 and " [💥1-dump]" or " [⚡pump]") or ""
                    table.insert(list, formatNum(p) .. tag)
                end
                salesStr = salesStr .. table.concat(list, "  •  ")
            else
                salesStr = salesStr .. "Belum ada riwayat sales"
            end
            resSales.Text = salesStr

            -- Set Diagnosis
            resDiag.Text = "Diagnosis: " .. tostring(it.status_reason or "Harga normal tanpa manipulasi.")
            if st == "NUKED" then
                resDiag.TextColor3 = Color3.fromRGB(251, 191, 36)
            elseif st == "PROJECTED" then
                resDiag.TextColor3 = Color3.fromRGB(244, 63, 94)
            else
                resDiag.TextColor3 = Color3.fromRGB(148, 163, 184)
            end

            notify("⚔️ " .. it.name, "Status: " .. st .. " | Clean: " .. formatNum(clean))
        end)
    end

    btnCheck.MouseButton1Click:Connect(doCheck)
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then doCheck() end
    end)

    print("[BB Checker] GUI Siap digunakan!")
    notify("⚔️ BB Sword Checker", "GUI siap! Masukkan nama sword untuk cek status.")
end

createCheckerGui()
