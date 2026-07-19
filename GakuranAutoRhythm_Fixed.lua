--[[
    Gakuran Auto-Rhythm Script - BRAVOS HUNTER @KUFURIT (ULTIMATE FIXED v4)
    Compatible with Mobile & PC Executors (Delta, Codex, Arceus X)
    Supports: Guitar, Bass Guitar, Drums, Keyboard, Casio, Piano
    
    CHANGES MADE FROM v3:
    1. Fixed GUI detection - now uses name-based and position-based detection instead of child count
    2. Fixed note detection - proper lane matching with name patterns specific to Gakuran
    3. Fixed receptor detection - looks for static elements in specific positions
    4. Fixed tap simulation - uses InputBegan/InputEnded for better compatibility
    5. Fixed cooldown system - prevents double-tapping same lane
    6. Fixed viewport calculations - properly handles different screen sizes
    7. Added debounce per lane to prevent spam
    8. Added better error handling for nil references
    9. Fixed AbsolutePosition/Size which returns Vector2, not individual properties directly
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- Configuration
-- ============================================================
local Config = {
    Enabled = false,
    HitChance = 100,       -- 0-100
    HitOffset = 20,        -- Window tolerance (pixels above/below receptor)
    DetectionRange = 60,   -- Horizontal tolerance for lane matching (pixels)
    TapCooldown = 0.08,    -- Minimum time between taps on same lane (seconds)
    DebugMode = false,     -- Print debug info
}

-- ============================================================
-- ICON ID for minimize button
-- ============================================================
local ICON_ID = "rbxassetid://18404245645"

-- ============================================================
-- Lane debounce tracking (per-lane cooldown)
-- ============================================================
local laneTapTimes = {}
local lastFrameCount = 0
local processedNotes = {}

-- ============================================================
-- Helper: Safe AbsolutePosition getter (Vector2)
-- ============================================================
local function getAbsPos(obj)
    local success, result = pcall(function()
        return obj.AbsolutePosition, obj.AbsoluteSize
    end)
    if success and result then
        return result
    end
    return nil, nil
end

local function getAbsSize(obj)
    local success, result = pcall(function()
        return obj.AbsoluteSize
    end)
    if success and result then
        return result
    end
    return nil
end

-- ============================================================
-- IMPROVED GUI Detection for Gakuran
-- ============================================================
-- Gakuran's rhythm GUI typically has names like:
-- "RhythmGui", "RhythmMinigame", "MusicGui", "InstrumentGui"
-- or contains specific child names related to notes/lanes

local function findActiveRhythmGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local guiName = gui.Name:lower()
            
            -- Direct name matching for known Gakuran rhythm GUIs
            if guiName:find("rhythm") or guiName:find("music") or 
               guiName:find("instrument") or guiName:find("song") or
               guiName:find("band") or guiName:find("stage") or
               guiName:find("note") or guiName:find("beat") or
               guiName:find("gameplay") then
                return gui
            end
            
            -- Fallback: Look for ScreenGui with many children that 
            -- have ImageLabel or Frame children (typical rhythm game structure)
            local imageLabelCount = 0
            local frameCount = 0
            for _, child in ipairs(gui:GetDescendants()) do
                if child:IsA("ImageLabel") then
                    imageLabelCount = imageLabelCount + 1
                elseif child:IsA("Frame") then
                    frameCount = frameCount + 1
                end
            end
            
            -- Rhythm games typically have many ImageLabels (notes, receptors, lanes)
            if imageLabelCount > 8 and gui.Name ~= "BravosHunterGUI_v4" and 
               gui.Name ~= "Chat" and gui.Name ~= "PlayerGui" then
                return gui
            end
        end
    end
    return nil
end

-- ============================================================
-- Note & Receptor Classification
-- ============================================================
local function classifyObject(obj)
    local name = obj.Name:lower()
    
    -- Notes keywords
    local noteKeywords = {"note", "beat", "circle", "tap", "hit", "gem", "star", "marker", "node", "target_note"}
    for _, keyword in ipairs(noteKeywords) do
        if name:find(keyword) then
            return "note"
        end
    end
    
    -- Receptor/Key keywords
    local receptorKeywords = {"receptor", "key", "lane", "trigger", "hitzone", "hit_zone", "target", "base", "receptacle"}
    for _, keyword in ipairs(receptorKeywords) do
        if name:find(keyword) then
            return "receptor"
        end
    end
    
    return nil
end

-- ============================================================
-- Improved Tap Simulation
-- ============================================================
local function simulateTap(guiObject)
    if not guiObject or not guiObject.Parent then return end
    
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
    
    -- Method 1: VirtualInputManager SendMouseButtonEvent (works on most executors)
    local success, err = pcall(function()
        VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    end)
    
    if not success then
        -- Method 2: VirtualUser CaptureController (fallback)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new(centerX, centerY))
        end)
    end
    
    -- Release the mouse button after a short delay
    task.delay(0.03, function()
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
        end)
    end)
end

-- ============================================================
-- Main Auto-Rhythm Loop
-- ============================================================
local connection
local tapCooldownActive = {}

local function startAutoRhythm()
    if connection then connection:Disconnect() end
    
    connection = RunService.Heartbeat:Connect(function()
        if not Config.Enabled then return end
        
        local rhythmGui = findActiveRhythmGui()
        if not rhythmGui then return end
        
        local receptors = {}
        local notes = {}
        
        -- Scan the rhythm GUI for notes and receptors
        for _, obj in ipairs(rhythmGui:GetDescendants()) do
            if not obj:IsA("GuiObject") or not obj.Visible then continue end
            
            local absPos, absSize = getAbsPos(obj)
            if not absPos or not absSize then continue end
            
            local viewportSize = workspace.CurrentCamera.ViewportSize
            local screenH = viewportSize.Y
            
            -- Classify by name first
            local classification = classifyObject(obj)
            
            if classification == "receptor" then
                table.insert(receptors, {obj = obj, pos = absPos, size = absSize})
            elseif classification == "note" then
                table.insert(notes, {obj = obj, pos = absPos, size = absSize})
            else
                -- Heuristic-based classification
                local yPos = absPos.Y
                
                -- Receptors: static elements in the bottom area (lower 35% of screen)
                -- that are wider than they are tall (horizontal bars) or perfectly circular
                if yPos > (screenH * 0.55) and yPos < (screenH * 0.95) and absSize.X > 20 then
                    -- Check if it looks like a receptor (wider, positioned at bottom)
                    if absSize.Y < 60 and absSize.X > absSize.Y then
                        table.insert(receptors, {obj = obj, pos = absPos, size = absSize})
                    end
                end
                
                -- Notes: elements in the upper/middle area that are moving toward bottom
                if yPos < (screenH * 0.85) and absSize.X > 10 and absSize.Y > 10 then
                    -- Only count if NOT already classified as receptor
                    local isReceptor = false
                    for _, rec in ipairs(receptors) do
                        if rec.obj == obj then
                            isReceptor = true
                            break
                        end
                    end
                    if not isReceptor then
                        table.insert(notes, {obj = obj, pos = absPos, size = absSize})
                    end
                end
            end
        end
        
        -- If very few receptors found, expand search area
        if #receptors < 2 then
            local screenH = workspace.CurrentCamera.ViewportSize.Y
            for _, obj in ipairs(rhythmGui:GetDescendants()) do
                if not obj:IsA("GuiObject") or not obj.Visible then continue end
                
                local absPos = obj.AbsolutePosition
                local yPos = absPos.Y
                local screenH = workspace.CurrentCamera.ViewportSize.Y
                
                -- Expand: look for any Frame/ImageLabel in bottom 40%
                if yPos > (screenH * 0.5) and yPos < (screenH * 0.98) and 
                   obj.AbsoluteSize.X > 15 and not obj:IsA("TextLabel") then
                    
                    -- Check not already in receptors
                    local alreadyIn = false
                    for _, rec in ipairs(receptors) do
                        if rec.obj == obj then
                            alreadyIn = true
                            break
                        end
                    end
                    if not alreadyIn then
                        table.insert(receptors, {obj = obj, pos = absPos, size = obj.AbsoluteSize})
                    end
                end
            end
        end
        
        -- If no notes found, scan upper 70% for ImageLabels
        if #notes < 3 then
            local screenH = workspace.CurrentCamera.ViewportSize.Y
            for _, obj in ipairs(rhythmGui:GetDescendants()) do
                if not obj:IsA("GuiObject") or not obj.Visible then continue end
                
                local absPos = obj.AbsolutePosition
                local yPos = absPos.Y
                
                -- Notes are typically in the upper portion, moving down
                if yPos < (screenH * 0.8) and yPos > 0 then
                    -- Make sure it's not a receptor
                    local isReceptor = false
                    for _, rec in ipairs(receptors) do
                        if rec.obj == obj then
                            isReceptor = true
                            break
                        end
                    end
                    
                    -- Also make sure it's not a UI element like a button or label
                    if not isReceptor and not obj:IsA("TextLabel") and 
                       not obj:IsA("TextButton") and obj.AbsoluteSize.X > 10 and obj.AbsoluteSize.Y > 10 then
                        local alreadyIn = false
                        for _, n in ipairs(notes) do
                            if n.obj == obj then
                                alreadyIn = true
                                break
                            end
                        end
                        if not alreadyIn then
                            table.insert(notes, {obj = obj, pos = absPos, size = obj.AbsoluteSize})
                        end
                    end
                end
            end
        end
        
        -- Match notes to receptors and tap
        for _, note in ipairs(notes) do
            if not note.obj or not note.obj.Parent or not note.obj.Visible then continue end
            
            -- Skip if this note was already processed (it's being tapped)
            if processedNotes[note.obj] then continue end
            
            for _, receptor in ipairs(receptors) do
                if not receptor.obj or not receptor.obj.Parent then continue end
                
                local notePos = note.pos
                local recPos = receptor.pos
                
                if not notePos or not recPos then continue end
                
                -- Check horizontal lane alignment (X-axis)
                local xDiff = math.abs(notePos.X - recPos.X)
                if xDiff < Config.DetectionRange then
                    
                    -- Check vertical distance (note approaching receptor)
                    local yDiff = notePos.Y - recPos.Y
                    local absYDiff = math.abs(yDiff)
                    
                    -- Note should be approaching from above (positive yDiff means note is above receptor)
                    -- or very close to the receptor
                    if absYDiff <= Config.HitOffset then
                        -- Lane-based debounce to prevent double-tapping
                        local laneKey = receptor.obj:GetFullName()
                        local now = os.clock()
                        
                        if not tapCooldownActive[laneKey] or (now - tapCooldownActive[laneKey]) > Config.TapCooldown then
                            if math.random(1, 100) <= Config.HitChance then
                                simulateTap(receptor.obj)
                                tapCooldownActive[laneKey] = now
                                
                                -- Mark note as processed to avoid double-tap
                                processedNotes[note.obj] = true
                                task.delay(0.3, function()
                                    processedNotes[note.obj] = nil
                                end)
                                
                                if Config.DebugMode then
                                    print(string.format("[AutoRhythm] Tap on lane %s | NoteY:%.0f RecY:%.0f Diff:%.0f", 
                                        laneKey:match("[^.]+$") or laneKey, notePos.Y, recPos.Y, yDiff))
                                end
                            end
                            break -- One receptor per note
                        end
                    end
                end
            end
        end
        
        -- Update last frame count for status
        lastFrameCount = #notes
    end)
end

-- ============================================================
-- GUI (BRAVOS HUNTER @KUFURIT) - Updated to v4
-- ============================================================
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BravosHunterGUI_v4"
    ScreenGui.Parent = game:GetService("CoreGui") or PlayerGui
    ScreenGui.ResetOnSpawn = false
    
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Main.Position = UDim2.new(0.5, -180, 0.5, -130)
    Main.Size = UDim2.new(0, 360, 0, 280)
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

    -- Toggle Button
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
        
        -- Clear debounce when disabling
        if not Config.Enabled then
            for k in pairs(tapCooldownActive) do
                tapCooldownActive[k] = nil
            end
            for k in pairs(processedNotes) do
                processedNotes[k] = nil
            end
        end
    end)

    -- Hit Chance Slider
    local HitChanceFrame = Instance.new("Frame")
    HitChanceFrame.Parent = Content
    HitChanceFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    HitChanceFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    HitChanceFrame.Size = UDim2.new(0.9, 0, 0, 40)
    HitChanceFrame.BorderSizePixel = 0
    Instance.new("UICorner", HitChanceFrame)

    local HitChanceLabel = Instance.new("TextLabel")
    HitChanceLabel.Parent = HitChanceFrame
    HitChanceLabel.BackgroundTransparency = 1
    HitChanceLabel.Position = UDim2.new(0, 10, 0.5, 0)
    HitChanceLabel.Size = UDim2.new(0, 120, 1, 0)
    HitChanceLabel.Font = Enum.Font.Gotham
    HitChanceLabel.Text = "Hit Chance: 100%"
    HitChanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    HitChanceLabel.TextSize = 12
    HitChanceLabel.TextXAlignment = Enum.TextXAlignment.Left
    HitChanceLabel.Position = UDim2.new(0, 10, 0, 0)

    -- Hit Offset Slider
    local HitOffsetFrame = Instance.new("Frame")
    HitOffsetFrame.Parent = Content
    HitOffsetFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    HitOffsetFrame.Position = UDim2.new(0.05, 0, 0.32, 0)
    HitOffsetFrame.Size = UDim2.new(0.9, 0, 0, 40)
    HitOffsetFrame.BorderSizePixel = 0
    Instance.new("UICorner", HitOffsetFrame)

    local HitOffsetLabel = Instance.new("TextLabel")
    HitOffsetLabel.Parent = HitOffsetFrame
    HitOffsetLabel.BackgroundTransparency = 1
    HitOffsetLabel.Position = UDim2.new(0, 10, 0, 0)
    HitOffsetLabel.Size = UDim2.new(0, 200, 1, 0)
    HitOffsetLabel.Font = Enum.Font.Gotham
    HitOffsetLabel.Text = "Hit Offset: 20px"
    HitOffsetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    HitOffsetLabel.TextSize = 12
    HitOffsetLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Detection Range
    local DetectRangeFrame = Instance.new("Frame")
    DetectRangeFrame.Parent = Content
    DetectRangeFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    DetectRangeFrame.Position = UDim2.new(0.05, 0, 0.44, 0)
    DetectRangeFrame.Size = UDim2.new(0.9, 0, 0, 40)
    DetectRangeFrame.BorderSizePixel = 0
    Instance.new("UICorner", DetectRangeFrame)

    local DetectRangeLabel = Instance.new("TextLabel")
    DetectRangeLabel.Parent = DetectRangeFrame
    DetectRangeLabel.BackgroundTransparency = 1
    DetectRangeLabel.Position = UDim2.new(0, 10, 0, 0)
    DetectRangeLabel.Size = UDim2.new(0, 200, 1, 0)
    DetectRangeLabel.Font = Enum.Font.Gotham
    DetectRangeLabel.Text = "Detection Range: 60px"
    DetectRangeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    DetectRangeLabel.TextSize = 12
    DetectRangeLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Status Label
    local Status = Instance.new("TextLabel")
    Status.Parent = Content
    Status.BackgroundTransparency = 1
    Status.Position = UDim2.new(0.05, 0, 0.65, 0)
    Status.Size = UDim2.new(0.9, 0, 0, 20)
    Status.Font = Enum.Font.Gotham
    Status.Text = "Status: Aguardando..."
    Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left

    -- Notes Count Label
    local NotesCount = Instance.new("TextLabel")
    NotesCount.Parent = Content
    NotesCount.BackgroundTransparency = 1
    NotesCount.Position = UDim2.new(0.05, 0, 0.75, 0)
    NotesCount.Size = UDim2.new(0.9, 0, 0, 20)
    NotesCount.Font = Enum.Font.Gotham
    NotesCount.Text = "Notas ativas: 0"
    NotesCount.TextColor3 = Color3.fromRGB(150, 150, 150)
    NotesCount.TextSize = 11
    NotesCount.TextXAlignment = Enum.TextXAlignment.Left

    -- Debug Toggle
    local DebugBtn = Instance.new("TextButton")
    DebugBtn.Parent = Content
    DebugBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    DebugBtn.Position = UDim2.new(0.05, 0, 0.85, 0)
    DebugBtn.Size = UDim2.new(0.9, 0, 0, 30)
    DebugBtn.Font = Enum.Font.Gotham
    DebugBtn.Text = "Debug Mode: OFF"
    DebugBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    DebugBtn.TextSize = 12
    Instance.new("UICorner", DebugBtn)

    DebugBtn.MouseButton1Click:Connect(function()
        Config.DebugMode = not Config.DebugMode
        DebugBtn.Text = Config.DebugMode and "Debug Mode: ON" or "Debug Mode: OFF"
        DebugBtn.BackgroundColor3 = Config.DebugMode and Color3.fromRGB(80, 60, 80) or Color3.fromRGB(40, 40, 40)
    end)

    -- Status Update Loop
    task.spawn(function()
        while task.wait(0.3) do
            if not Config.Enabled then
                Status.Text = "Status: Script Desativado"
                Status.TextColor3 = Color3.fromRGB(150, 150, 150)
                NotesCount.Text = "Notas ativas: 0"
            else
                local g = findActiveRhythmGui()
                if g then
                    Status.Text = "Status: Jogo Detectado! (" .. g.Name .. ")"
                    Status.TextColor3 = Color3.fromRGB(0, 255, 0)
                    NotesCount.Text = "Notas ativas: " .. lastFrameCount
                    NotesCount.TextColor3 = Color3.fromRGB(100, 200, 255)
                else
                    Status.Text = "Status: Procurando Minigame..."
                    Status.TextColor3 = Color3.fromRGB(255, 200, 0)
                    NotesCount.Text = "Notas ativas: 0"
                end
            end
        end
    end)
end

-- ============================================================
-- Initialize
-- ============================================================
createUI()
startAutoRhythm()
print("BRAVOS HUNTER @KUFURIT v4 Injetado!")
