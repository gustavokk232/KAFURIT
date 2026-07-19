--[[
    Gakuran Auto-Rhythm Script - BRAVOS HUNTER @KUFURIT (ULTIMATE FIXED v10)
    FINAL COMMUNITY-BASED VERSION
    
    V10 RECONSTRUCTION:
    1. ORIGINAL GUI: Restored v3 code exactly as requested.
    2. COMMUNITY LOGIC: Based on how the most popular Gakuran scripts handle rhythm.
    3. HOLD NOTES: Detects the "Bar" or "Tail" property and maintains hold until completion.
    4. PRECISE RECEPTORS: Targets the specific 6-circle arc at the bottom.
    5. PERFORMANCE: High-frequency scanning for frame-perfect hits.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- Configuration
-- ============================================================
local Config = {
    Enabled = false, 
    HitChance = 100, 
    HitOffset = 22,      -- Calibrated for Gakuran's hit window
    DetectionRange = 45, -- Horizontal lane width
}

-- Asset ID for minimize icon
local ICON_ID = "rbxassetid://18404245645" 

-- State Tracking
local activeHolds = {} -- [laneKey] = { receptor = obj, note = obj }
local processedNotes = {}

-- ============================================================
-- INTERACTION: Precise Input
-- ============================================================
local function simulateInput(obj, state)
    local pos = obj.AbsolutePosition
    local size = obj.AbsoluteSize
    local cx = pos.X + (size.X / 2)
    local cy = pos.Y + (size.Y / 2)
    
    -- Send touch/click event to the exact center of the receptor
    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, state, game, 1)
end

-- ============================================================
-- DETECTION: Find the Rhythm Game
-- ============================================================
local function findRhythmElements()
    local gui = nil
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("ScreenGui") and g.Enabled and g.Name ~= "BravosHunterGUI_v3" then
            -- Gakuran rhythm GUIs have many children (notes/lanes)
            if #g:GetDescendants() > 20 then
                gui = g
                break
            end
        end
    end
    
    if not gui then return {}, {} end
    
    local receptors = {}
    local notes = {}
    local screenH = workspace.CurrentCamera.ViewportSize.Y
    
    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("GuiObject") and obj.Visible then
            local pos = obj.AbsolutePosition
            local size = obj.AbsoluteSize
            
            -- Identify the 6 Receptors (Bottom Arc)
            if pos.Y > (screenH * 0.55) and size.X > 15 and size.X < 90 then
                local name = obj.Name:lower()
                if name:find("circle") or name:find("receptor") or name:find("key") or name:find("button") then
                    table.insert(receptors, obj)
                end
            end
            
            -- Identify Notes (Falling objects)
            if pos.Y < (screenH * 0.95) and size.X > 10 then
                local name = obj.Name:lower()
                if name:find("note") or name:find("beat") or name:find("bar") or obj:IsA("ImageLabel") then
                    -- Filter out receptors from notes
                    local isRec = false
                    for _, r in ipairs(receptors) do if r == obj then isRec = true break end end
                    if not isRec then
                        table.insert(notes, obj)
                    end
                end
            end
        end
    end
    
    return receptors, notes
end

-- ============================================================
-- MAIN LOOP: Auto-Rhythm Logic
-- ============================================================
local connection
local function startAutoRhythm()
    if connection then connection:Disconnect() end
    
    connection = RunService.Heartbeat:Connect(function()
        if not Config.Enabled then 
            for k, v in pairs(activeHolds) do simulateInput(v.receptor, false) activeHolds[k] = nil end
            return 
        end
        
        local receptors, notes = findRhythmElements()
        if #receptors == 0 then return end
        
        -- 1. Manage Active Holds (Check for release)
        for laneKey, data in pairs(activeHolds) do
            local stillExists = false
            if data.note and data.note.Parent and data.note.Visible then
                local nPos, nSize = data.note.AbsolutePosition, data.note.AbsoluteSize
                local rPos, rSize = data.receptor.AbsolutePosition, data.receptor.AbsoluteSize
                
                local recCenterY = rPos.Y + (rSize.Y / 2)
                local noteTopY = nPos.Y
                local noteBottomY = nPos.Y + nSize.Y
                
                -- Keep holding while the note body/tail is still over the receptor
                if noteTopY < recCenterY and noteBottomY > (recCenterY - 8) then
                    stillExists = true
                end
            end
            
            if not stillExists then
                simulateInput(data.receptor, false)
                activeHolds[laneKey] = nil
            end
        end
        
        -- 2. Detect New Notes
        for _, note in ipairs(notes) do
            if processedNotes[note] then continue end
            
            for _, rec in ipairs(receptors) do
                local xDiff = math.abs(note.AbsolutePosition.X - rec.AbsolutePosition.X)
                
                if xDiff < Config.DetectionRange then
                    local noteBottomY = note.AbsolutePosition.Y + note.AbsoluteSize.Y
                    local recCenterY = rec.AbsolutePosition.Y + (rec.AbsoluteSize.Y / 2)
                    
                    -- Precision Trigger
                    if math.abs(noteBottomY - recCenterY) <= Config.HitOffset then
                        local laneKey = tostring(rec:GetFullName())
                        
                        if not activeHolds[laneKey] then
                            if math.random(1, 100) <= Config.HitChance then
                                simulateInput(rec, true)
                                processedNotes[note] = true
                                
                                -- Determine if it's a hold note
                                local isHold = (note.AbsoluteSize.Y > 50) or note.Name:lower():find("bar") or note.Name:lower():find("tail")
                                
                                if isHold then
                                    activeHolds[laneKey] = { receptor = rec, note = note }
                                else
                                    -- Quick release for simple notes
                                    task.delay(0.05, function() simulateInput(rec, false) end)
                                end
                                
                                -- Cleanup tracking
                                task.delay(0.6, function() processedNotes[note] = nil end)
                            end
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- GUI: Original v3 Design
-- ============================================================
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BravosHunterGUI_v3"
    ScreenGui.Parent = game:GetService("CoreGui") or PlayerGui
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Main.Position = UDim2.new(0.5, -180, 0.5, -130)
    Main.Size = UDim2.new(0, 360, 0, 260)
    Main.Active = true
    Main.Draggable = true
    Main.BorderSizePixel = 0
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = Main
    Header.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BorderSizePixel = 0
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

    local HeaderFill = Instance.new("Frame")
    HeaderFill.Parent = Header
    HeaderFill.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    HeaderFill.Position = UDim2.new(0, 0, 0.5, 0)
    HeaderFill.Size = UDim2.new(1, 0, 0.5, 0)
    HeaderFill.BorderSizePixel = 0

    local Title = Instance.new("TextLabel")
    Title.Parent = Header
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "BRAVOS HUNTER @KUFURIT"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local Close = Instance.new("TextButton")
    Close.Parent = Header
    Close.BackgroundTransparency = 1
    Close.Position = UDim2.new(1, -35, 0, 0)
    Close.Size = UDim2.new(0, 35, 1, 0)
    Close.Font = Enum.Font.GothamBold
    Close.Text = "X"
    Close.TextColor3 = Color3.fromRGB(255, 255, 255)
    Close.TextSize = 18
    Close.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local Mini = Instance.new("TextButton")
    Mini.Parent = Header
    Mini.BackgroundTransparency = 1
    Mini.Position = UDim2.new(1, -70, 0, 0)
    Mini.Size = UDim2.new(0, 35, 1, 0)
    Mini.Font = Enum.Font.GothamBold
    Mini.Text = "-"
    Mini.TextColor3 = Color3.fromRGB(255, 255, 255)
    Mini.TextSize = 24

    local MiniBtn = Instance.new("ImageButton")
    MiniBtn.Parent = ScreenGui
    MiniBtn.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    MiniBtn.Size = UDim2.new(0, 55, 0, 55)
    MiniBtn.Position = UDim2.new(0, 20, 0.5, -25)
    MiniBtn.Visible = false
    MiniBtn.Image = ICON_ID
    Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0, 12)

    Mini.MouseButton1Click:Connect(function() Main.Visible = false MiniBtn.Visible = true end)
    MiniBtn.MouseButton1Click:Connect(function() Main.Visible = true MiniBtn.Visible = false end)

    local Sidebar = Instance.new("Frame")
    Sidebar.Parent = Main
    Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    Sidebar.Position = UDim2.new(0, 5, 0, 40)
    Sidebar.Size = UDim2.new(0, 55, 1, -45)
    Sidebar.BorderSizePixel = 0
    Instance.new("UICorner", Sidebar)

    local function tab(pos, icon)
        local b = Instance.new("TextButton")
        b.Parent = Sidebar
        b.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
        b.Size = UDim2.new(0, 40, 0, 40)
        b.Position = UDim2.new(0.5, -20, 0, pos)
        b.Text = icon
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.TextSize = 20
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    end
    tab(10, "🎵") tab(55, "👁️") tab(100, "⚙️") tab(145, "👤")

    local Content = Instance.new("Frame")
    Content.Parent = Main
    Content.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Content.Position = UDim2.new(0, 65, 0, 40)
    Content.Size = UDim2.new(1, -70, 1, -45)
    Content.BorderSizePixel = 0
    Instance.new("UICorner", Content)

    local Toggle = Instance.new("TextButton")
    Toggle.Parent = Content
    Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Toggle.Position = UDim2.new(0.05, 0, 0.05, 0)
    Toggle.Size = UDim2.new(0.9, 0, 0, 45)
    Toggle.Font = Enum.Font.GothamBold
    Toggle.Text = "Auto Rhythm: OFF"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 14
    Instance.new("UICorner", Toggle)

    Toggle.MouseButton1Click:Connect(function()
        Config.Enabled = not Config.Enabled
        Toggle.Text = Config.Enabled and "Auto Rhythm: ON" or "Auto Rhythm: OFF"
        Toggle.BackgroundColor3 = Config.Enabled and Color3.fromRGB(160, 32, 240) or Color3.fromRGB(40, 40, 40)
    end)

    local Status = Instance.new("TextLabel")
    Status.Parent = Content
    Status.BackgroundTransparency = 1
    Status.Position = UDim2.new(0.05, 0, 0.3, 0)
    Status.Size = UDim2.new(0.9, 0, 0, 20)
    Status.Font = Enum.Font.Gotham
    Status.Text = "Status: Aguardando..."
    Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left

    task.spawn(function()
        while task.wait(0.5) do
            if not Config.Enabled then
                Status.Text = "Status: Script Desativado"
                Status.TextColor3 = Color3.fromRGB(150, 150, 150)
            else
                local recs, _ = findRhythmElements()
                if #recs > 0 then
                    Status.Text = "Status: " .. #recs .. " Receptores Prontos!"
                    Status.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    Status.Text = "Status: Procurando Minigame..."
                    Status.TextColor3 = Color3.fromRGB(255, 255, 0)
                end
            end
        end
    end)
end

-- ============================================================
-- Initialization
-- ============================================================
createUI()
startAutoRhythm()
print("BRAVOS HUNTER @KUFURIT v10 FINAL Loaded!")
