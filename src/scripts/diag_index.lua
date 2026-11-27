-- Jalankan saat papan INDEX terbuka dan item (mis: Prince Blade / Rose Gift) terlihat di kotak hasil
local lp = game:GetService("Players").LocalPlayer
local sg = game:GetService("StarterGui")
local pGui = lp:WaitForChild("PlayerGui")

local function notif(t, m)
    pcall(function() sg:SetCore("SendNotification", { Title = t, Text = m, Duration = 8 }) end)
end

local found = false
for _, gui in ipairs(pGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "BBSniperCleanV1" then
        for _, desc in ipairs(gui:GetDescendants()) do
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and desc.Visible then
                local txt = (desc.Text or ""):lower()
                if txt:find("prince blade") or txt:find("rose gift") or txt:find("base sword") then
                    found = true
                    local p1 = desc.Parent
                    local p2 = p1 and p1.Parent
                    local info = string.format("%s (%s) | P1:%s(%s) | P2:%s(%s)",
                        desc.Name, desc.ClassName,
                        p1 and p1.Name or "nil", p1 and p1.ClassName or "-",
                        p2 and p2.Name or "nil", p2 and p2.ClassName or "-"
                    )
                    notif("CARD STRUCTURE", info)

                    -- Cek semua tombol & connection di sekitar kartu
                    local targets = {desc, p1, p2}
                    for _, c in ipairs(p1 and p1:GetDescendants() or {}) do
                        if c:IsA("GuiButton") or c:IsA("ImageLabel") or c:IsA("Frame") then
                            table.insert(targets, c)
                        end
                    end

                    local sigReport = {}
                    if getconnections then
                        for _, t in ipairs(targets) do
                            for _, sName in ipairs({"MouseButton1Click", "Activated", "MouseButton1Down", "InputBegan", "TouchTap"}) do
                                pcall(function()
                                    local conns = getconnections(t[sName])
                                    if #conns > 0 then
                                        table.insert(sigReport, t.Name .. "." .. sName .. "(" .. #conns .. ")")
                                    end
                                end)
                            end
                        end
                    end
                    notif("SIGNALS FOUND", #sigReport > 0 and table.concat(sigReport, ", ") or "Tidak ada signal terdeteksi")
                    break
                end
            end
        end
    end
    if found then break end
end

if not found then
    notif("DIAG INDEX", "Tidak menemukan teks item di UI Index!")
end
