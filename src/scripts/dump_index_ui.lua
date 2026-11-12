--[[
    =================================================================================
    DUMP INDEX & RAP HISTORY UI
    =================================================================================
    Script ini khusus mendeteksi jendela INDEX & RAP History di layar Anda
    dan menyimpan nama semua Frame, TextLabel, Button, dan Attributes ke:
      bb_index_dump.txt (di folder workspace Solara)
    =================================================================================
--]]

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local pGui = lp and lp:FindFirstChild("PlayerGui")

local lines = {}
local function log(msg)
    print(msg)
    table.insert(lines, tostring(msg))
end

local function dump(obj, depth)
    if depth > 8 then return end
    local indent = string.rep("  ", depth)
    local line = indent .. "[" .. obj.ClassName .. "] " .. obj.Name

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        local t = tostring(obj.Text or "")
        if #t > 0 then line = line .. ' | TEXT="' .. t .. '"' end
    end

    local attrs = {}
    pcall(function()
        for k, v in pairs(obj:GetAttributes()) do
            table.insert(attrs, k .. "=" .. tostring(v))
        end
    end)
    if #attrs > 0 then
        line = line .. " | ATTRS: " .. table.concat(attrs, ", ")
    end

    log(line)
    for _, c in ipairs(obj:GetChildren()) do
        dump(c, depth + 1)
    end
end

log("==================================================")
log("DUMP UI INDEX & RAP HISTORY - " .. tostring(tick()))
log("==================================================")

if pGui then
    for _, gui in ipairs(pGui:GetChildren()) do
        local n = gui.Name:lower()
        -- Cari ScreenGui yang berisi Index atau History atau Menus
        local found = false
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text and (d.Text:lower():find("rap history") or d.Text:lower():find("prince blade") or d.Text:lower():find("index")) then
                found = true
                break
            end
        end

        if found or n:find("index") or n:find("rap") or n:find("trading") then
            log(">>> DITEMUKAN SCREEN GUI: " .. gui.Name)
            dump(gui, 1)
        end
    end
else
    log("[!] PlayerGui tidak ditemukan")
end

local content = table.concat(lines, "\n")
local ok, err = pcall(function()
    writefile("bb_index_dump.txt", content)
end)

if ok then
    log("=== SELESAI! TERSIMPAN DI: bb_index_dump.txt ===")
else
    log("=== GAGAL SIMPAN FILE, CEK CONSOLE ===")
end
