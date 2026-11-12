--[[
    ================================================================
    BLADE BALL BOOTH STRUCTURE DIAGNOSTICS v2
    ================================================================
    Output akan disimpan ke file:
      C:\Users\Public\bb_diagnostic.txt
    (atau cek di folder Solara workspace jika path tidak support)
    ================================================================
--]]

local SAVE_PATH = "bb_diagnostic.txt"  -- disimpan di folder workspace Solara
local lines = {}

local function log(msg)
    print(msg)
    table.insert(lines, tostring(msg))
end

local function save()
    local content = table.concat(lines, "\n")
    local ok, err = pcall(function()
        writefile(SAVE_PATH, content)
    end)
    if ok then
        print("=== FILE TERSIMPAN: " .. SAVE_PATH .. " ===")
        print("Buka file itu dan kirim isinya ke AI!")
    else
        -- Fallback: coba path lain
        local ok2, err2 = pcall(function()
            writefile("workspace/" .. SAVE_PATH, content)
        end)
        if ok2 then
            print("=== FILE TERSIMPAN: workspace/" .. SAVE_PATH .. " ===")
        else
            print("=== GAGAL SIMPAN FILE, silahkan copy output console ===")
            print("Error: " .. tostring(err) .. " | " .. tostring(err2))
        end
    end
end

local function dumpChildren(obj, prefix, depth)
    if depth > 7 then return end
    local ok, err = pcall(function()
        for _, child in ipairs(obj:GetChildren()) do
            local info = prefix .. "[" .. child.ClassName .. "] " .. child.Name
            -- TextLabel / TextButton
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                local t = tostring(child.Text or "")
                if #t > 0 and #t < 200 then
                    info = info .. ' | TEXT="' .. t .. '"'
                end
            -- ValueBase
            elseif child:IsA("ValueBase") then
                info = info .. " | VALUE=" .. tostring(child.Value)
            end
            -- Attributes
            local attrList = {}
            pcall(function()
                for k, v in pairs(child:GetAttributes()) do
                    table.insert(attrList, k .. "=" .. tostring(v))
                end
            end)
            if #attrList > 0 then
                info = info .. " | ATTRS: " .. table.concat(attrList, ", ")
            end
            log(info)
            dumpChildren(child, prefix .. "  ", depth + 1)
        end
    end)
    if not ok then log(prefix .. "[ERROR]: " .. tostring(err)) end
end

-- ================================================================
-- START
-- ================================================================
log("================================================================")
log("BLADE BALL BOOTH DIAGNOSTIC v2 - " .. tostring(tick()))
log("================================================================")

-- 1. Dump isi Workspace.Spawn
log("")
log("[1] CEK WORKSPACE.SPAWN")
local spawn = workspace:FindFirstChild("Spawn")
if spawn then
    log("  Ditemukan! Type: " .. spawn.ClassName)
    for _, c in ipairs(spawn:GetChildren()) do
        log("  - [" .. c.ClassName .. "] " .. c.Name)
        for _, cc in ipairs(c:GetChildren()) do
            log("      - [" .. cc.ClassName .. "] " .. cc.Name)
        end
    end
else
    log("  [!] Workspace.Spawn TIDAK ADA")
end

-- 2. Cari 'Stands' di seluruh workspace
log("")
log("[2] CARI 'Stands' DI WORKSPACE")
local foundStands = 0
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name == "Stands" then
        foundStands = foundStands + 1
        log("  DITEMUKAN: " .. obj:GetFullName() .. " | " .. obj.ClassName)
        local kids = obj:GetChildren()
        log("  Total children: " .. #kids)
        -- Dump 3 stand pertama secara lengkap
        for i = 1, math.min(3, #kids) do
            local stand = kids[i]
            log("")
            log("  === STAND #" .. i .. " [" .. stand.ClassName .. "] " .. stand.Name .. " ===")
            -- Attributes
            local attrCount = 0
            pcall(function()
                for k, v in pairs(stand:GetAttributes()) do
                    log("    ATTR " .. k .. " = " .. tostring(v))
                    attrCount = attrCount + 1
                end
            end)
            if attrCount == 0 then log("    (tidak ada attributes)") end
            -- Semua descendants
            dumpChildren(stand, "    ", 0)
        end
    end
end
if foundStands == 0 then
    log("  [!] Tidak ditemukan 'Stands'. Cari kata kunci lain...")
    for _, obj in ipairs(workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if n:find("trade") or n:find("booth") or n:find("market") or n:find("plaza") or n:find("hub") or n:find("stand") then
            log("  KANDIDAT: [" .. obj.ClassName .. "] " .. obj:GetFullName())
        end
    end
end

-- 3. Cek PlayerGui untuk UI Trading
log("")
log("[3] CEK PLAYER GUI")
local lp = game:GetService("Players").LocalPlayer
local pGui = lp and lp:FindFirstChild("PlayerGui")
if pGui then
    for _, c in ipairs(pGui:GetChildren()) do
        log("  [" .. c.ClassName .. "] " .. c.Name)
        local n = c.Name:lower()
        if n:find("trade") or n:find("booth") or n:find("hub") or n:find("store") or n:find("market") or n:find("plaza") or n:find("lobby") then
            log("  ** KANDIDAT UI TRADING! DUMP LENGKAP:")
            dumpChildren(c, "    ", 0)
        end
    end
end

-- 4. Cek ReplicatedStorage.Shared.Trading
log("")
log("[4] CEK REPLICATEDSTORAGE")
local RS = game:GetService("ReplicatedStorage")
local shared = RS:FindFirstChild("Shared")
if shared then
    local trading = shared:FindFirstChild("Trading")
    if trading then
        log("  Trading folder: ADA")
        for _, c in ipairs(trading:GetChildren()) do
            log("  - [" .. c.ClassName .. "] " .. c.Name)
        end
    else
        log("  [!] Trading folder tidak ada")
    end
    -- Cari juga di root RS
    for _, c in ipairs(RS:GetChildren()) do
        local n = c.Name:lower()
        if n:find("trade") or n:find("booth") or n:find("stand") or n:find("market") then
            log("  RS KANDIDAT: [" .. c.ClassName .. "] " .. c.Name)
            dumpChildren(c, "    ", 0)
        end
    end
end

-- 5. Cek LocalPlayer character untuk item yang dipegang
log("")
log("[5] CEK CHARACTER PLAYER")
local char = lp and lp.Character
if char then
    log("  Character ada: " .. char.Name)
    for _, c in ipairs(char:GetChildren()) do
        local n = c.Name:lower()
        if n:find("tool") or n:find("sword") or n:find("weapon") or c:IsA("Tool") then
            log("  Tool/weapon: [" .. c.ClassName .. "] " .. c.Name)
        end
    end
end

log("")
log("================================================================")
log("SELESAI! FILE DISIMPAN KE: " .. SAVE_PATH)
log("================================================================")

-- Simpan ke file
save()
