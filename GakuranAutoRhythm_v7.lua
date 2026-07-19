--[[
    Gakuran Auto-Rhythm Script - BRAVOS HUNTER @KUFURIT (ULTIMATE FIXED v7)
    Compatible with Mobile & PC Executors (Delta, Codex, Arceus X)
    
    RECONSTRUCTION LOG v7:
    1. RESTORED ORIGINAL GUI: Exactly as provided in the first message.
    2. RECEPTOR FOCUS: Targeting the 6 white circles at the bottom.
    3. HOLD DETECTION: Identifies "Note" objects that have a "Tail" or "Bar" child/property.
    4. PRECISE CLICKING: Uses AbsolutePosition + (AbsoluteSize / 2) for exact centering.
    5. DYNAMIC RELEASE: Releases only when the tail of the hold note passes the receptor center.
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
    HitOffset = 25,      -- Pixels tolerance for hitting
    DetectionRange = 45, -- Horizontal lane tolerance
}

-- Asset ID for the minimize icon
local ICON_ID = "rbxassetid://18404245645" 

-- State Tracking
local activeHolds = {} -- { [laneKey] = { receptor = obj, note = obj } }
local processedNotes = {}

-- ============================================================
-- Helper: Find Rhythm GUI
-- ============================================================
local function findActiveRhythmGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            -- Gakuran rhythm GUIs typically contain many ImageLabels or Frames for notes
            local children = gui:GetDescendants()
            local guiName = gui.Name:lower()
            
            if guiName:find("rhythm") or guiName:find("music") or guiName:find("instrument") then
                return gui
            end
            
            if #children > 20 and gui.Name ~= "BravosHunterGUI_v3" and gui.Name ~= "Chat" then
                return gui
            end
        end
    end
    return nil
end

-- ============================================================
-- Interaction: Click & Hold
-- ============================================================
local function simulateClick(obj, state)
    local success, pos = pcall(function() return obj.AbsolutePosition end)
    local success2, size = pcall(function() return obj.AbsoluteSize end)
    
    if success and success2 then
        local cx = pos.X + (size.X / 2)
        local cy = pos.Y + (size.Y / 2)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, state, game, 1)
    end
end

-- ============================================================
-- Main Logic Loop
-- ============================================================
local connection
local function startAutoRhythm()
    if connection then connection:Disconnect() end
    
    connection = RunService.Heartbeat:Connect(function()
        if not Config.Enabled then 
            -- Release all holds if disabled
            for k, v in pairs(activeHolds) do
                simulateClick(v.receptor, false)
                activeHolds[k] = nil
            end
            return 
        end
        
        local rhythmGui = findActiveRhythmGui()
        if not rhythmGui then return end
        
        local receptors = {}
        local notes = {}
        local screenH = workspace.CurrentCamera.ViewportSize.Y
        
        -- 1. Scan for Receptors and Notes
        for _, obj in ipairs(rhythmGui:GetDescendants()) do
            if not obj:IsA("GuiObject") or not obj.Visible then continue end
            
            local success, pos = pcall(function() return obj.AbsolutePosition end)
            local success2, size = pcall(function() return obj.AbsoluteSize end)
            if not success or not success2 then continue end
            
            local name = obj.Name:lower()
            
            -- RECEPTORS: The 6 circles at the bottom
            if pos.Y > (screenH * 0.6) and size.X > 15 and size.X < 100 then
                if name:find("circle") or name:find("receptor") or name:find("key") or name:find("button") then
                    table.insert(receptors, {obj = obj, pos = pos, size = size})
                end
            end
            
            -- NOTES: Falling elements
            if pos.Y < (screenH * 0.95) and size.X > 5 then
                if name:find("note") or name:find("beat") or name:find("bar") or obj:IsA("ImageLabel") then
                    -- Filter out receptors from notes list
                    local isRec = false
                    if pos.Y > (screenH * 0.6) then
                        for _, r in ipairs(receptors) do if r.obj == obj then isRec = true break end end
                    end
                    if not isRec then
                        table.insert(notes, {obj = obj, pos = pos, size = size})
                    end
                end
            end
        end
        
        -- 2. Handle Active Holds
        for laneKey, data in pairs(activeHolds) do
            local stillExists = false
            -- Check if the specific note being held still has a part above the receptor
            if data.note and data.note.Parent and data.note.Visible then
                local nPos, nSize = data.note.AbsolutePosition, data.note.AbsoluteSize
                local rPos, rSize = data.receptor.AbsolutePosition, data.receptor.AbsoluteSize
                
                local recCenterY = rPos.Y + (rSize.Y / 2)
                local noteTopY = nPos.Y
                local noteBottomY = nPos.Y + nSize.Y
                
                -- Keep holding if any part of the note (especially the tail) is still over the receptor
                if noteTopY < recCenterY and noteBottomY > (recCenterY - 10) then
                    stillExists = true
                end
            end
            
            if not stillExists then
                simulateClick(data.receptor, false)
                activeHolds[laneKey] = nil
            end
        end
        
        -- 3. Detect New Hits
        for _, note in ipairs(notes) do
            if processedNotes[note.obj] then continue end
            
            for _, receptor in ipairs(receptors) do
                local xDiff = math.abs(note.pos.X - receptor.pos.X)
                if xDiff < Config.DetectionRange then
                    local noteBottomY = note.pos.Y + note.size.Y
                    local recCenterY = receptor.pos.Y + (receptor.size.Y / 2)
                    
                    -- If the bottom of the note hits the receptor
                    if math.abs(noteBottomY - recCenterY) <= Config.HitOffset then
                        local laneKey = tostring(receptor.obj:GetFullName())
                        
                        if not activeHolds[laneKey] then
                            if math.random(1, 100) <= Config.HitChance then
                                simulateClick(receptor.obj, true)
                                processedNotes[note.obj] = true
                                
                                -- Detect Hold: Is it a long note?
                                -- In Gakuran, hold notes are either elongated ImageLabels or have a tail child
                                local isHold = (note.size.Y > 50) or (note.obj:FindFirstChild("Tail") or note.obj:FindFirstChild("Bar"))
                                
                                if isHold then
                                    activeHolds[laneKey] = { receptor = receptor.obj, note = note.obj }
                                else
                                    -- Simple tap: release after a tiny delay
                                    task.delay(0.05, function()
                                        simulateClick(receptor.obj, false)
                                    end)
                                end
                                
                                -- Cleanup processed table
                                task.delay(0.5, function() processedNotes[note.obj] = nil end)
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
-- GUI (RESTORED v3 ORIGINAL)
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
                local g = findActiveRhythmGui()
                if g then
                    Status.Text = "Status: Jogo Detectado! (" .. g.Name .. ")"
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
-- Start
-- ============================================================
createUI()
startAutoRhythm()
print("BRAVOS HUNTER @KUFURIT v7 Final Injetado!")
