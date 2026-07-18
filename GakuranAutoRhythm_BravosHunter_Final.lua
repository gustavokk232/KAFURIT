--[[
    Gakuran Auto-Rhythm Script - Bravos Hunter GUI
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
    Enabled = true,
    HitChance = 100, -- Porcentagem de acertos (0-100)
    HitOffset = 5,   -- Margem de erro em pixels para o acerto
}

-- Image ID for Minimize Button (Provided by user)
-- Note: In Roblox, you need to use "rbxassetid://" followed by the ID. 
-- Since the user provided an image file, I'll use a placeholder or suggest how to upload it to Roblox.
-- For this script, I'll use a generic ID or leave it as a variable for the user to fill if they have the ID.
local ICON_ID = "rbxassetid://123456789" -- PLACEHOLDER: User should replace with their uploaded Image ID

-- Note detection logic
local function findRhythmGui()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and (gui.Name:lower():find("rhythm") or gui.Name:lower():find("music") or gui.Name:lower():find("minigame")) then
            return gui
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
        
        local receptors = {}
        for _, rec in ipairs(rhythmGui:GetDescendants()) do
            if rec:IsA("GuiObject") and (rec.Name:lower():find("receptor") or rec.Name:lower():find("target") or rec.Name:lower():find("hitbox")) then
                table.insert(receptors, rec)
            end
        end
        
        for _, desc in ipairs(rhythmGui:GetDescendants()) do
            if desc:IsA("GuiObject") and desc.Name:lower():find("note") and not desc.Name:lower():find("receptor") then
                if desc.Visible then
                    for _, receptor in ipairs(receptors) do
                        if math.abs(desc.AbsolutePosition.X - receptor.AbsolutePosition.X) < 20 then
                            local noteY = desc.AbsolutePosition.Y
                            local recY = receptor.AbsolutePosition.Y
                            
                            if math.abs(noteY - recY) <= Config.HitOffset then
                                if math.random(1, 100) <= Config.HitChance then
                                    simulateTouch(receptor)
                                    desc.Visible = false 
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- GUI Construction
local function createBravosHunterUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BravosHunterGUI"
    ScreenGui.Parent = game:GetService("CoreGui") or PlayerGui
    if syn and syn.protect_gui then syn.protect_gui(ScreenGui) end

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.Size = UDim2.new(0, 400, 0, 280)
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.BorderSizePixel = 0

    local UICorner_Main = Instance.new("UICorner")
    UICorner_Main.CornerRadius = UDim.new(0, 8)
    UICorner_Main.Parent = MainFrame

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Parent = MainFrame
    Header.BackgroundColor3 = Color3.fromRGB(160, 32, 240) -- Bright Purple
    Header.Size = UDim2.new(1, 0, 0, 35)
    Header.BorderSizePixel = 0

    local UICorner_Header = Instance.new("UICorner")
    UICorner_Header.CornerRadius = UDim.new(0, 8)
    UICorner_Header.Parent = Header

    -- Cover bottom corners of header to make it look flat on bottom
    local HeaderFlat = Instance.new("Frame")
    HeaderFlat.Parent = Header
    HeaderFlat.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    HeaderFlat.Position = UDim2.new(0, 0, 0.5, 0)
    HeaderFlat.Size = UDim2.new(1, 0, 0.5, 0)
    HeaderFlat.BorderSizePixel = 0

    local Title = Instance.new("TextLabel")
    Title.Parent = Header
    Title.BackgroundTransparency = 1
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
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
    
    -- Minimize Logic
    local Minimized = false
    local MiniFrame = Instance.new("ImageButton") -- Using ImageButton for the Delta-style square
    MiniFrame.Name = "MiniFrame"
    MiniFrame.Parent = ScreenGui
    MiniFrame.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    MiniFrame.Size = UDim2.new(0, 50, 0, 50)
    MiniFrame.Position = UDim2.new(0, 10, 0.5, -25)
    MiniFrame.Visible = false
    MiniFrame.BorderSizePixel = 0
    MiniFrame.Image = "rbxassetid://18404245645" -- This is a common ID for user images if uploaded, or use the placeholder
    -- If the user provides a specific ID, they can replace it here.
    
    local UICorner_Mini = Instance.new("UICorner")
    UICorner_Mini.CornerRadius = UDim.new(0, 10)
    UICorner_Mini.Parent = MiniFrame

    MinBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        MiniFrame.Visible = true
    end)

    MiniFrame.MouseButton1Click:Connect(function()
        MainFrame.Visible = true
        MiniFrame.Visible = false
    end)

    -- Side Bar
    local SideBar = Instance.new("Frame")
    SideBar.Parent = MainFrame
    SideBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    SideBar.Position = UDim2.new(0, 5, 0, 40)
    SideBar.Size = UDim2.new(0, 60, 1, -45)
    SideBar.BorderSizePixel = 0

    local UICorner_Side = Instance.new("UICorner")
    UICorner_Side.Parent = SideBar

    -- Side Buttons (Tabs)
    local function createTabBtn(pos, icon)
        local btn = Instance.new("TextButton")
        btn.Parent = SideBar
        btn.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
        btn.Size = UDim2.new(0, 40, 0, 40)
        btn.Position = UDim2.new(0.5, -20, 0, pos)
        btn.Text = icon
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 20
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn
        return btn
    end

    local Tab1 = createTabBtn(10, "🎵") -- Music Tab
    local Tab2 = createTabBtn(60, "👁️") -- Visuals
    local Tab3 = createTabBtn(110, "⚙️") -- Settings
    local Tab4 = createTabBtn(160, "👤") -- Profile

    -- Main Content Area
    local Container = Instance.new("Frame")
    Container.Parent = MainFrame
    Container.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Container.Position = UDim2.new(0, 70, 0, 40)
    Container.Size = UDim2.new(1, -75, 1, -45)
    Container.BorderSizePixel = 0
    
    local UICorner_Cont = Instance.new("UICorner")
    UICorner_Cont.Parent = Container

    -- Auto Rhythm Toggle
    local Toggle = Instance.new("TextButton")
    Toggle.Parent = Container
    Toggle.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
    Toggle.Position = UDim2.new(0.05, 0, 0.05, 0)
    Toggle.Size = UDim2.new(0.9, 0, 0, 40)
    Toggle.Font = Enum.Font.GothamBold
    Toggle.Text = "Auto Rhythm: ON"
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 14
    
    local UICorner_Tog = Instance.new("UICorner")
    UICorner_Tog.Parent = Toggle

    Toggle.MouseButton1Click:Connect(function()
        Config.Enabled = not Config.Enabled
        if Config.Enabled then
            Toggle.Text = "Auto Rhythm: ON"
            Toggle.BackgroundColor3 = Color3.fromRGB(160, 32, 240)
        else
            Toggle.Text = "Auto Rhythm: OFF"
            Toggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)

    -- Status Label
    local Status = Instance.new("TextLabel")
    Status.Parent = Container
    Status.BackgroundTransparency = 1
    Status.Position = UDim2.new(0.05, 0, 0.25, 0)
    Status.Size = UDim2.new(0.9, 0, 0, 20)
    Status.Font = Enum.Font.Gotham
    Status.Text = "Status: Aguardando Minigame..."
    Status.TextColor3 = Color3.fromRGB(200, 200, 200)
    Status.TextSize = 12
    Status.TextXAlignment = Enum.TextXAlignment.Left

    -- Update status label in loop
    task.spawn(function()
        while task.wait(1) do
            if findRhythmGui() then
                Status.Text = "Status: Minigame Detectado! Tocando..."
                Status.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                Status.Text = "Status: Aguardando Minigame..."
                Status.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end)

    return ScreenGui
end

createBravosHunterUI()
startAutoRhythm()
print("BRAVOS HUNTER @KUFURIT Injetado com Sucesso!")
