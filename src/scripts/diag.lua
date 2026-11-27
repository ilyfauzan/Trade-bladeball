-- DIAGNOSTIC SCRIPT - Jalankan ini dulu di Delta untuk cek apa yang bisa berjalan
local sg = game:GetService("StarterGui")
local function notif(t, m)
    pcall(function()
        sg:SetCore("SendNotification", { Title = t, Text = m, Duration = 6 })
    end)
    warn("[DIAG]", t, m)
end

-- Step 1: Basic execution
notif("DIAG 1/5", "Script dijalankan!")

-- Step 2: LocalPlayer
local lp = game:GetService("Players").LocalPlayer
if lp then
    notif("DIAG 2/5", "LocalPlayer OK: " .. lp.Name)
else
    notif("DIAG 2/5 FAIL", "LocalPlayer NIL!")
    return
end

-- Step 3: PlayerGui
local pg = lp:WaitForChild("PlayerGui", 5)
if pg then
    notif("DIAG 3/5", "PlayerGui OK!")
else
    notif("DIAG 3/5 FAIL", "PlayerGui tidak ditemukan!")
    return
end

-- Step 4: Buat UI sederhana
local ok, err = pcall(function()
    local sg2 = Instance.new("ScreenGui")
    sg2.Name = "BBDiag"
    sg2.ResetOnSpawn = false
    sg2.Parent = pg

    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 200, 0, 60)
    f.Position = UDim2.new(0.5, -100, 0.1, 0)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    f.Parent = sg2

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, 0, 1, 0)
    t.Text = "BB SNIPER DIAG OK!"
    t.TextColor3 = Color3.fromRGB(0, 255, 100)
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.Parent = f
end)

if ok then
    notif("DIAG 4/5", "UI berhasil dibuat! Cek layar!")
else
    notif("DIAG 4/5 FAIL", "UI error: " .. tostring(err):sub(1,60))
end

-- Step 5: HttpGet test
local ok2, err2 = pcall(function()
    local result = game:HttpGet("https://raw.githubusercontent.com/ilyfauzan/Trade-bladeball/main/src/scripts/delta_plaza_sniper.lua")
    notif("DIAG 5/5", "HttpGet OK! Panjang: " .. #result .. " chars")
end)

if not ok2 then
    notif("DIAG 5/5 FAIL", "HttpGet gagal: " .. tostring(err2):sub(1,60))
end
