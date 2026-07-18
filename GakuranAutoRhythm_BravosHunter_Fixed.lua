--[[
    Gakuran Auto-Rhythm Script - Bravos Hunter GUI (FIXED)
    Compatible with Mobile & PC Executors
    Supports: Guitar, Bass Guitar, Drums, Keyboard
    Name: BRAVOS HUNTER @KUFURIT
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Configuration
local Config = {
    Enabled = false, -- Default to false to avoid errors on start
    HitChance = 100, 
    HitOffset = 10,   -- Increased offset for better detection
}

-- Note detection logic
local function findRhythmGui()
    -- Common names for the rhythm GUI in Gakuran
    local names = {"music", "rhythm", "play", "game", "minigame", "song"}
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local lowerName = gui.Name:lower()
            for _, n in ipairs(names) do
                if lowerName:find(n) then
                    -- Check if it actually contains note-like objects
                    if gui:FindFirstChildOfClass("Frame", true) or gui:FindFirstChildOfClass("ImageLabel", true) then
                        return gui
                    end
                end
            end
        end
    end
    return nil
end

local function simulateTouch(guiObject)
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
    
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
end

-- Main loop
local connection
local function startAutoRhythm()
    if connection then connection:Disconnect() end
    
    connection = RunService.RenderStepped:Connect(function()
        if not Config.Enabled then return end
        
        local rhythmGui = findRhythmGui()
        if not rhythmGui then return end
        
        -- Identify Receptors and Notes
        -- Notes are often circular ImageLabels or Frames
        -- Receptors are static objects at the bottom
        local receptors = {}
        local notes = {}
        
        for _, obj in ipairs(rhythmGui:GetDescendants()) do
            if obj:IsA("GuiObject") and obj.Visible then
                local name = obj.Name:lower()
                -- Detect Receptors (Targets)
                if name:find("receptor") or name:find("target") or name:find("goal") or name:find("hit") then
                    table.insert(receptors, obj)
                -- Detect Notes
                elseif name:find("note") or name:find("circle") or name:find("beat") then
                    -- Filter out non-moving parts of the note if any
                    table.insert(notes, obj)
                end
            end
        end
        
        -- Fallback: If no explicit names, use position/size heuristics
        if #receptors == 0 then
            -- Receptors are usually at the bottom of the screen
            for _, obj in ipairs(rhythmGui:GetDescendants()) do
                if obj:IsA("GuiObject") and obj.Visible and obj.AbsolutePosition.Y > (workspace.CurrentCamera.ViewportSize.Y * 0.6) then
                    -- Often they are in a specific frame
                    if obj.Parent:IsA("Frame") and #obj.Parent:GetChildren() >= 2 and #obj.Parent:GetChildren() <= 5 then
                        table.insert(receptors, obj)
                    end
                end
            end
        end

        -- Process Notes
        for _, note in ipairs(notes) do
            if note.Visible and note.BackgroundTransparency < 1 or (note:IsA("ImageLabel") and note.ImageTransparency < 1) then
                for _, receptor in ipairs(receptors) do
                    -- Check if in same column
                    if math.abs(note.AbsolutePosition.X - receptor.AbsolutePosition.X) < 30 then
                        local noteY = note.AbsolutePosition.Y
                        local recY = receptor.AbsolutePosition.Y
                        
                        -- Detection for downward movement
                        if math.abs(noteY - recY) <= Config.HitOffset then
                            if math.random(1, 100) <= Config.HitChance then
                                simulateTouch(receptor)
                                -- Mark as hit to avoid multiple triggers
                                note.Visible = false 
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- GUI Construction (Bravos Hunter Style)
local function createBravosHunterUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BravosHunterGUI_Fixed"
    ScreenGui.Parent = game:GetService("CoreGui") or PlayerGui
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    MainFrame.Position = UDim2.new(0.5, -180, 0.5, -130)
    MainFrame.Size = UDim2.new(0, 360, 0, 260)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.BorderSizePixel = 0

    local UICorner_Main = Instance.new("UICorner")
    UICorner_Main.CornerRadius = UDim.new(0, 10)
    UICorner_Main.Parent = MainFrame

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = MainFrame
    Header.BackgroundColor3 = Color3.fromRGB(148, 0, 211) -- Dark Violet/Purple
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BorderSizePixel = 0

    local UICorner_Header = Instance.new("UICorner")
    UICorner_Header.CornerRadius = UDim.new(0, 10)
    UICorner_Header.Parent = Header

    local HeaderFlat = Instance.new("Frame")
    HeaderFlat.Parent = Header
    HeaderFlat.BackgroundColor3 = Color3.fromRGB(148, 0, 211)
    HeaderFlat.Position = UDim2.new(0, 0, 0.5, 0)
    HeaderFlat.Size = UDim2.new(1, 0, 0.5, 0)
    HeaderFlat.BorderSizePixel = 0

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

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Parent = Header
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Position = UDim2.new(1, -35, 0, 0)
    CloseBtn.Size = UDim2.new(0, 35, 1, 0)
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 18
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        if connection then connection:Disconnect() end
    end)

    local MinBtn = Instance.new("TextButton")
    MinBtn.Parent = Header
    MinBtn.BackgroundTransparency = 1
    MinBtn.Position = UDim2.new(1, -70, 0, 0)
    MinBtn.Size = UDim2.new(0, 35, 1, 0)
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Text = "-"
    MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize = 24
    
    -- Minimize Icon (Square like Delta)
    local MiniFrame = Instance.new("ImageButton")
    MiniFrame.Name = "MiniFrame"
    MiniFrame.Parent = ScreenGui
    MiniFrame.BackgroundColor3 = Color3.fromRGB(148, 0, 211)
    MiniFrame.Size = UDim2.new(0, 50, 0, 50)
    MiniFrame.Position = UDim2.new(0, 20, 0.5, -25)
    MiniFrame.Visible = false
    MiniFrame.BorderSizePixel = 0
    MiniFrame.Image = "rbxassetid://18404245645" -- Placeholder ID
    
    local UICorner_Mini = Instance.new("UICorner")
    UICorner_Mini.CornerRadius = UDim.new(0, 12)
    UICorner_Mini.Parent = MiniFrame

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniFrame.Visible = true
    end)

    MiniFrame.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        MiniFrame.Visible = false
    end)

    -- Sidebar
    local Sidebar = Instance.new("Frame")
    Sidebar.Parent = MainFrame
    Sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Sidebar.Position = UDim2.new(0, 5, 0, 40)
    Sidebar.Size = UDim2.new(0, 55, 1, -45)
    Sidebar.BorderSizePixel = 0
    local UICorner_Side = Instance.new("UICorner")
    UICorner_Side.Parent = Sidebar

    local function createTab(pos, icon)
        local btn = Instance.new("TextButton")
        btn.Parent = Sidebar
        btn.BackgroundColor3 = Color3.fromRGB(148, 0, 211)
        btn.Size = UDim2.new(0, 40, 0, 40)
        btn.Position = UDim2.new(0.5, -20, 0, pos)
        btn.Text = icon
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 20
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 8)
        c.Parent = btn
        return btn
    end

    createTab(10, "🎵")
    createTab(55, "👁️")
    createTab(100, "⚙️")
    createTab(145, "👤")

    -- Content
    local Content = Instance.new("Frame")
    Content.Parent = MainFrame
    Content.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    Content.Position = UDim2.new(0, 65, 0, 40)
    Content.Size = UDim2.new(1, -70, 1, -45)
    Content.BorderSizePixel = 0
    local UICorner_Content = Instance.new("UICorner")
    UICorner_Content.Parent = Content

    local Toggle = Instance.new("TextButton")
    Toggle.Parent = Content
    Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50) -- Default OFF
    Toggle.Position = UDim2.new(0.05, 0, 0.05, 0)
    Toggle.Size = UDim2.new(0.9, 0, 0, 40)
    Toggle.Font = Enum.Font.GothamBold
    Toggle.Text = "Auto Rhythm: OFF"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 14
    local UICorner_Tog = Instance.new("UICorner")
    UICorner_Tog.Parent = Toggle

    Toggle.MouseButton1Click:Connect(function()
        Config.Enabled = not Config.Enabled
        if Config.Enabled then
            Toggle.Text = "Auto Rhythm: ON"
            Toggle.BackgroundColor3 = Color3.fromRGB(148, 0, 211)
        else
            Toggle.Text = "Auto Rhythm: OFF"
            Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)

    local Status = Instance.new("TextLabel")
    Status.Parent = Content
    Status.BackgroundTransparency = 1
    Status.Position = UDim2.new(0.05, 0, 0.25, 0)
    Status.Size = UDim2.new(0.9, 0, 0, 20)
    Status.Font = Enum.Font.Gotham
    Status.Text = "Status: Aguardando Ativação..."
    Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left

    task.spawn(function()
        while task.wait(0.5) do
            if not Config.Enabled then
                Status.Text = "Status: Aguardando Ativação..."
                Status.TextColor3 = Color3.fromRGB(150, 150, 150)
            else
                if findRhythmGui() then
                    Status.Text = "Status: Minigame Ativo! Tocando..."
                    Status.TextColor3 = Color3.fromRGB(0, 255, 0)
                else
                    Status.Text = "Status: Procurando Minigame..."
                    Status.TextColor3 = Color3.fromRGB(255, 255, 0)
                end
            end
        end
    end)

    return ScreenGui
end

createBravosHunterUI()
startAutoRhythm()
print("BRAVOS HUNTER @KUFURIT (FIXED) Injetado!")
