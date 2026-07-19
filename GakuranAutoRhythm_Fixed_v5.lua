--[[
    Gakuran Auto-Rhythm Script - BRAVOS HUNTER @KUFURIT (ULTIMATE FIXED v5)
    Compatible with Mobile & PC Executors (Delta, Codex, Arceus X)
    Supports: Guitar, Bass Guitar, Drums, Keyboard, Casio, Piano
    
    NEW FEATURES IN v5:
    1. HOLD NOTES SUPPORT - Detects elongated notes and holds the tap until the end of the note.
    2. PRECISE RECEPTOR TAPPING - Ensures clicks happen exactly in the center of the receptor circles.
    3. IMPROVED DETECTION - Uses AbsoluteSize.Y to distinguish between regular notes and hold notes.
    4. LANE TRACKING - Manages multiple lanes simultaneously, even with overlapping hold notes.
    5. DYNAMIC RELEASE - Releases the hold as soon as the top of the note passes the receptor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- Configuration
-- ============================================================
local Config = {
    Enabled = false,
    HitChance = 100,       -- 0-100
    HitOffset = 25,        -- Window tolerance (pixels above/below receptor)
    DetectionRange = 50,   -- Horizontal tolerance for lane matching (pixels)
    HoldThreshold = 60,    -- AbsoluteSize.Y threshold to consider a note as a "Hold Note"
    DebugMode = false,
}

-- ============================================================
-- State Tracking
-- ============================================================
local activeHolds = {} -- Tracking which lanes are currently being held: { [laneKey] = { endTime = number, receptor = Instance } }
local processedNotes = {} -- To prevent re-triggering the same note object

-- ============================================================
-- Helper: Safe Property Access
-- ============================================================
local function getGuiProperties(obj)
    local success, pos = pcall(function() return obj.AbsolutePosition end)
    local success2, size = pcall(function() return obj.AbsoluteSize end)
    if success and success2 then
        return pos, size
    end
    return nil, nil
end

-- ============================================================
-- GUI Detection
-- ============================================================
local function findActiveRhythmGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local name = gui.Name:lower()
            if name:find("rhythm") or name:find("music") or name:find("instrument") or name:find("gameplay") then
                return gui
            end
            
            -- Fallback by child count/type
            local count = 0
            for _, child in ipairs(gui:GetDescendants()) do
                if child:IsA("ImageLabel") or child:IsA("Frame") then
                    count = count + 1
                end
            end
            if count > 15 and gui.Name ~= "BravosHunterGUI_v5" and gui.Name ~= "Chat" then
                return gui
            end
        end
    end
    return nil
end

-- ============================================================
-- Tap & Hold Simulation
-- ============================================================
local function pressLane(receptor)
    local pos, size = getGuiProperties(receptor)
    if not pos then return end
    
    local centerX = pos.X + (size.X / 2)
    local centerY = pos.Y + (size.Y / 2)
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
end

local function releaseLane(receptor)
    local pos, size = getGuiProperties(receptor)
    if not pos then return end
    
    local centerX = pos.X + (size.X / 2)
    local centerY = pos.Y + (size.Y / 2)
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
end

-- ============================================================
-- Main Logic
-- ============================================================
local connection
connection = RunService.Heartbeat:Connect(function()
    if not Config.Enabled then 
        -- Ensure everything is released if disabled
        for laneKey, data in pairs(activeHolds) do
            releaseLane(data.receptor)
            activeHolds[laneKey] = nil
        end
        return 
    end
    
    local rhythmGui = findActiveRhythmGui()
    if not rhythmGui then return end
    
    local receptors = {}
    local notes = {}
    
    local viewportSize = workspace.CurrentCamera.ViewportSize
    
    -- 1. Identify Receptors and Notes
    for _, obj in ipairs(rhythmGui:GetDescendants()) do
        if not obj:IsA("GuiObject") or not obj.Visible then continue end
        
        local pos, size = getGuiProperties(obj)
        if not pos then continue end
        
        local name = obj.Name:lower()
        
        -- Receptor Detection (Circles at the bottom)
        if (name:find("receptor") or name:find("circle") or name:find("button") or name:find("key")) 
           and pos.Y > (viewportSize.Y * 0.6) then
            table.insert(receptors, {obj = obj, pos = pos, size = size})
        
        -- Note Detection (Falling objects)
        elseif (name:find("note") or name:find("beat") or name:find("bar") or obj:IsA("ImageLabel"))
               and pos.Y < (viewportSize.Y * 0.9) then
            -- Exclude things that are clearly not notes (too small or huge)
            if size.X > 10 and size.Y > 5 then
                table.insert(notes, {obj = obj, pos = pos, size = size})
            end
        end
    end
    
    -- 2. Process active holds (Check if it's time to release)
    for laneKey, data in pairs(activeHolds) do
        local stillHolding = false
        
        -- Check if the note being held is still over the receptor
        -- We look for the note in this lane that is currently "passing" the receptor
        for _, note in ipairs(notes) do
            local xDiff = math.abs(note.pos.X - data.receptor.AbsolutePosition.X)
            if xDiff < Config.DetectionRange then
                local noteBottom = note.pos.Y + note.size.Y
                local noteTop = note.pos.Y
                local recCenter = data.receptor.AbsolutePosition.Y + (data.receptor.AbsoluteSize.Y / 2)
                
                -- If any part of the note is still over or above the receptor center, keep holding
                if noteTop < recCenter and noteBottom > (recCenter - Config.HitOffset) then
                    stillHolding = true
                    break
                end
            end
        end
        
        if not stillHolding then
            releaseLane(data.receptor)
            activeHolds[laneKey] = nil
            if Config.DebugMode then print("Released lane:", laneKey) end
        end
    end
    
    -- 3. Detect new hits
    for _, note in ipairs(notes) do
        if processedNotes[note.obj] then continue end
        
        for _, receptor in ipairs(receptors) do
            local xDiff = math.abs(note.pos.X - receptor.pos.X)
            
            if xDiff < Config.DetectionRange then
                local noteBottom = note.pos.Y + note.size.Y
                local recCenter = receptor.pos.Y + (receptor.size.Y / 2)
                
                -- When the bottom of the note hits the receptor center
                if math.abs(noteBottom - recCenter) < Config.HitOffset then
                    local laneKey = tostring(receptor.obj:GetFullName())
                    
                    if not activeHolds[laneKey] then
                        if math.random(1, 100) <= Config.HitChance then
                            pressLane(receptor.obj)
                            processedNotes[note.obj] = true
                            
                            -- If it's a long note (Hold Note), add to activeHolds
                            if note.size.Y > Config.HoldThreshold then
                                activeHolds[laneKey] = { receptor = receptor.obj }
                                if Config.DebugMode then print("Started HOLD on lane:", laneKey) end
                            else
                                -- Regular note: release quickly
                                task.delay(0.05, function()
                                    releaseLane(receptor.obj)
                                end)
                                if Config.DebugMode then print("Tapped lane:", laneKey) end
                            end
                            
                            -- Cleanup processed notes table
                            task.delay(1, function() processedNotes[note.obj] = nil end)
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- GUI Interface
-- ============================================================
local function createUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BravosHunterGUI_v5"
    ScreenGui.Parent = game:GetService("CoreGui") or PlayerGui
    
    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Main.Position = UDim2.new(0.5, -150, 0.5, -100)
    Main.Size = UDim2.new(0, 300, 0, 200)
    Main.Active = true
    Main.Draggable = true
    Instance.new("UICorner", Main)

    local Title = Instance.new("TextLabel")
    Title.Parent = Main
    Title.Size = UDim2.new(1, 0, 0, 40)
    Title.Text = "GAKURAN AUTO-RHYTHM v5"
    Title.TextColor3 = Color3.fromRGB(160, 32, 240)
    Title.Font = Enum.Font.GothamBold
    Title.BackgroundTransparency = 1

    local Toggle = Instance.new("TextButton")
    Toggle.Parent = Main
    Toggle.Position = UDim2.new(0.1, 0, 0.3, 0)
    Toggle.Size = UDim2.new(0.8, 0, 0, 40)
    Toggle.Text = "Status: OFF"
    Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", Toggle)

    Toggle.MouseButton1Click:Connect(function()
        Config.Enabled = not Config.Enabled
        Toggle.Text = Config.Enabled and "Status: ON" or "Status: OFF"
        Toggle.BackgroundColor3 = Config.Enabled and Color3.fromRGB(160, 32, 240) or Color3.fromRGB(40, 40, 40)
    end)

    local DebugBtn = Instance.new("TextButton")
    DebugBtn.Parent = Main
    DebugBtn.Position = UDim2.new(0.1, 0, 0.6, 0)
    DebugBtn.Size = UDim2.new(0.8, 0, 0, 30)
    DebugBtn.Text = "Debug Mode: OFF"
    DebugBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    DebugBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
    Instance.new("UICorner", DebugBtn)

    DebugBtn.MouseButton1Click:Connect(function()
        Config.DebugMode = not Config.DebugMode
        DebugBtn.Text = Config.DebugMode and "Debug Mode: ON" or "Debug Mode: OFF"
    end)
    
    local Credits = Instance.new("TextLabel")
    Credits.Parent = Main
    Credits.Position = UDim2.new(0, 0, 0.85, 0)
    Credits.Size = UDim2.new(1, 0, 0, 20)
    Credits.Text = "Created by BRAVOS HUNTER @KUFURIT"
    Credits.TextColor3 = Color3.fromRGB(100, 100, 100)
    Credits.TextSize = 10
    Credits.BackgroundTransparency = 1
end

createUI()
print("Gakuran Auto-Rhythm v5 Loaded!")
