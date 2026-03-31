-- globalstats.xyz | Universal Script (Enhanced)
-- K = Open/Close Menu | F = Toggle Flight
-- Aimbot: Hold Right Mouse Button
-- ESP includes nametag + red outline
-- Modern GUI with user avatar and username
-- NEW: Black background, toggle buttons: purple (off) / pink (on)
-- FIXED: Speed boost now works correctly
-- REMOVED: Teleport to coordinates
-- ADDED: Admin alerts toggle now shows a toast notification

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualInput = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ========== CONFIGURATION ==========
getgenv().UniversalHub = {
    InfiniteJump = false,
    Aimbot = false,
    Flight = false,
    FlySpeed = 130,
    MenuVisible = true,
    -- Trolling features
    TeleportToPlayer = false,
    ExplodePlayer = false,
    LoopKill = false,
    -- Team check for aimbot
    TeamCheck = true,
    -- New features
    NoClip = false,
    SpeedBoost = false,
    SpeedValue = 32,
    AntiAFK = false,
    TriggerBot = false,
    AimbotFOV = 90,
    FOVCircle = true,
    AdminAlerts = true,
    -- FOV circle color
    FOVCircleColor = Color3.fromRGB(128, 0, 128), -- Purple
    -- ESP
    ESP = false,
    ESPMode = "Highlight", -- StickFigure support removed for simplicity
    ESPMaxDistance = math.huge -- Infinite distance for ESP rendering
}

local flightToggleBtn = nil
local espToggleBtn = nil

-- Player list & teleport section storage
local playerListEntries = {}
local playerListContainer = nil
local selectedPlayer = nil
local lastPlayerListUpdate = 0
local updatingPlayerList = false

-- ========== UTILITY FUNCTIONS ==========
local function Notify(Title, Text, Duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = Text,
            Duration = Duration or 5
        })
    end)
end

local function getPlayerHealth(plr)
    if plr and plr.Character then
        local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            return math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)
        end
    end
    return 0, 0
end

local function teleportToPlayer(plr)
    if not plr or not plr.Character or not LocalPlayer.Character then 
        print("[DEBUG] Teleport failed: Missing player or character")
        return false 
    end
    local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then
        print("[DEBUG] Teleport failed: Missing HumanoidRootPart for", plr.Name, "or local player")
        return false
    end
    print("[DEBUG] Teleporting to", plr.Name, "from", myRoot.Position, "to", targetRoot.Position)
    myRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
    print("[DEBUG] Teleport successful to", plr.Name)
    return true
end

-- ========== MODERN UI CREATION ==========
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- FOV circle overlay (aimbot)
local fovGui = Instance.new("Frame")
fovGui.Name = "FOVCircle"
fovGui.AnchorPoint = Vector2.new(0.5, 0.5)
fovGui.Position = UDim2.new(0.5, 0, 0.5, 0)
fovGui.Size = UDim2.new(0, 0, 0, 0)
fovGui.BackgroundTransparency = 1
fovGui.BorderSizePixel = 0
fovGui.Visible = false
fovGui.Parent = ScreenGui

local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 2
fovStroke.Color = getgenv().UniversalHub.FOVCircleColor
fovStroke.Transparency = 0.3
fovStroke.Parent = fovGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovGui

local function updateFOVCircle()
    if not getgenv().UniversalHub.FOVCircle then
        fovGui.Visible = false
        return
    end

    local cam = Camera
    local fov = getgenv().UniversalHub.AimbotFOV or 90
    fov = math.clamp(fov, 1, 360) -- Support values down to 1 degree and up to full circle

    local screenWidth = cam.ViewportSize.X
    local circleRadius = math.tan(math.rad(fov / 2)) / math.tan(math.rad(cam.FieldOfView / 2)) * (screenWidth / 2)

    fovGui.Visible = true
    fovGui.Size = UDim2.new(0, circleRadius * 2, 0, circleRadius * 2)
    fovGui.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovStroke.Color = getgenv().UniversalHub.FOVCircleColor
end

-- ESP system
local espHighlights = {}
local espNametags = {}
local espStickFigures = {}

local function createNametag(player)
    if espNametags[player] then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = ScreenGui

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = player.Name
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.TextSize = 16
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextStrokeTransparency = 0.5
    textLabel.Parent = billboard

    espNametags[player] = billboard
end

local function createHighlight(player)
    if espHighlights[player] then return end
    local char = player.Character
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = char
    highlight.FillColor = Color3.new(1, 0, 0)
    highlight.OutlineColor = Color3.new(1, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = char

    espHighlights[player] = highlight
end

local function createStickFigure(player)
    if espStickFigures[player] then return end
    local char = player.Character
    if not char then return end

    -- Check if Drawing API is available (requires exploit environment)
    if not Drawing then
        Notify("Stick Figure ESP", "Stick Figure mode requires an exploit with Drawing API support. Switching to Highlight mode.", 5)
        getgenv().UniversalHub.ESPMode = "Highlight"
        return
    end

    local parts = {
        Head = char:FindFirstChild("Head"),
        HumanoidRootPart = char:FindFirstChild("HumanoidRootPart"),
        LeftArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm"),
        RightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm"),
        LeftLeg = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg"),
        RightLeg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg"),
        Torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    }

    local lines = {}
    -- Body
    if parts.Torso and parts.HumanoidRootPart then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end
    -- Arms
    if parts.Torso and parts.LeftArm then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end
    if parts.Torso and parts.RightArm then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end
    -- Legs
    if parts.HumanoidRootPart and parts.LeftLeg then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end
    if parts.HumanoidRootPart and parts.RightLeg then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end
    -- Head
    if parts.Torso and parts.Head then
        local line = Drawing.new("Line")
        line.Color = Color3.new(1, 0, 0)
        line.Thickness = 2
        line.Transparency = 1
        lines[#lines+1] = line
    end

    espStickFigures[player] = {parts = parts, lines = lines}
end

local function updateESP()
    if not getgenv().UniversalHub.ESP then
        -- Remove all ESP
        for player, billboard in pairs(espNametags) do
            billboard:Destroy()
        end
        espNametags = {}
        for player, highlight in pairs(espHighlights) do
            highlight:Destroy()
        end
        espHighlights = {}
        for player, data in pairs(espStickFigures) do
            for _, line in ipairs(data.lines) do
                line:Remove()
            end
        end
        espStickFigures = {}
        return
    end

    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if not playerRoot or (playerRoot.Position - localRoot.Position).Magnitude > getgenv().UniversalHub.ESPMaxDistance then
                -- Remove ESP if out of range or no root
                if espNametags[player] then
                    espNametags[player]:Destroy()
                    espNametags[player] = nil
                end
                if espHighlights[player] then
                    espHighlights[player]:Destroy()
                    espHighlights[player] = nil
                end
                if espStickFigures[player] then
                    for _, line in ipairs(espStickFigures[player].lines) do
                        line:Remove()
                    end
                    espStickFigures[player] = nil
                end
            else
                createNametag(player)
                if getgenv().UniversalHub.ESPMode == "Highlight" then
                    createHighlight(player)
                    -- Remove stick figure if exists
                    if espStickFigures[player] then
                        for _, line in ipairs(espStickFigures[player].lines) do
                            line:Remove()
                        end
                        espStickFigures[player] = nil
                    end
                elseif getgenv().UniversalHub.ESPMode == "StickFigure" then
                    createStickFigure(player)
                    -- Remove highlight if exists
                    if espHighlights[player] then
                        espHighlights[player]:Destroy()
                        espHighlights[player] = nil
                    end
                end
            end
        end
    end
end

local function updateStickFigurePositions()
    for player, data in pairs(espStickFigures) do
        if player.Character then
            local parts = data.parts
            local lines = data.lines
            local index = 1
            -- Body
            if parts.Torso and parts.HumanoidRootPart and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.Torso.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.HumanoidRootPart.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
            -- Left Arm
            if parts.Torso and parts.LeftArm and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.Torso.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.LeftArm.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
            -- Right Arm
            if parts.Torso and parts.RightArm and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.Torso.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.RightArm.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
            -- Left Leg
            if parts.HumanoidRootPart and parts.LeftLeg and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.HumanoidRootPart.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.LeftLeg.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
            -- Right Leg
            if parts.HumanoidRootPart and parts.RightLeg and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.HumanoidRootPart.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.RightLeg.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
            -- Head
            if parts.Torso and parts.Head and lines[index] then
                local pos1 = Camera:WorldToViewportPoint(parts.Torso.Position)
                local pos2 = Camera:WorldToViewportPoint(parts.Head.Position)
                lines[index].From = Vector2.new(pos1.X, pos1.Y)
                lines[index].To = Vector2.new(pos2.X, pos2.Y)
                lines[index].Visible = true
                index = index + 1
            end
        else
            -- Hide lines if character gone
            for _, line in ipairs(data.lines) do
                line.Visible = false
            end
        end
    end
end

-- Hub teleport anchor (tap mode)
local hubAnchorCFrame = nil
local function updateHubAnchor()
    local char = LocalPlayer.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            hubAnchorCFrame = root.CFrame
            return
        end
    end
    hubAnchorCFrame = workspace:FindFirstChild("SpawnLocation") and workspace.SpawnLocation.CFrame or hubAnchorCFrame
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateHubAnchor()
end)

if LocalPlayer.Character then
    updateHubAnchor()
end

-- Main frame (resizable) – background black
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 620, 0, 540)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -270)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- black
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

-- Shadow
local shadow = Instance.new("Frame", MainFrame)
shadow.Size = UDim2.new(1, 4, 1, 4)
shadow.Position = UDim2.new(0, -2, 0, -2)
shadow.BackgroundColor3 = Color3.new(0,0,0)
shadow.BackgroundTransparency = 0.7
shadow.ZIndex = -1
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 16)

-- Resize grip (bottom-right corner)
local ResizeGrip = Instance.new("Frame")
ResizeGrip.Size = UDim2.new(0, 20, 0, 20)
ResizeGrip.Position = UDim2.new(1, -20, 1, -20)
ResizeGrip.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
ResizeGrip.BackgroundTransparency = 0.6
ResizeGrip.Parent = MainFrame
Instance.new("UICorner", ResizeGrip).CornerRadius = UDim.new(0, 4)

local isResizing = false
local startMouse, startSize, startPos

ResizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isResizing = true
        startMouse = input.Position
        startSize = MainFrame.Size
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - startMouse
        local newWidth = math.clamp(startSize.X.Offset + delta.X, 400, 1000)
        local newHeight = math.clamp(startSize.Y.Offset + delta.Y, 400, 800)
        MainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
        -- Adjust position to keep top-left corner fixed
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        isResizing = false
    end
end)

-- Top bar – black
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 85)
TopBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- black
TopBar.BackgroundTransparency = 0.2
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 16)

-- Avatar image
local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 60, 0, 60)
avatarImage.Position = UDim2.new(0, 15, 0, 12.5)
avatarImage.BackgroundTransparency = 1
avatarImage.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
avatarImage.Parent = TopBar
Instance.new("UICorner", avatarImage).CornerRadius = UDim.new(1, 0)

-- Username and status
local userNameLabel = Instance.new("TextLabel")
userNameLabel.Size = UDim2.new(0.6, 0, 0, 30)
userNameLabel.Position = UDim2.new(0, 90, 0, 15)
userNameLabel.BackgroundTransparency = 1
userNameLabel.Text = LocalPlayer.Name
userNameLabel.TextColor3 = Color3.new(1,1,1)
userNameLabel.TextSize = 20
userNameLabel.Font = Enum.Font.GothamBold
userNameLabel.TextXAlignment = Enum.TextXAlignment.Left
userNameLabel.Parent = TopBar

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.6, 0, 0, 25)
statusLabel.Position = UDim2.new(0, 90, 0, 48)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Online"
statusLabel.TextColor3 = Color3.fromRGB(0, 200, 100)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = TopBar

-- Minimize button (replaces close button)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 38, 0, 38)
MinimizeBtn.Position = UDim2.new(1, -48, 0, 23)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.new(1,1,1)
MinimizeBtn.TextSize = 24
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.Parent = TopBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 10)

MinimizeBtn.MouseButton1Click:Connect(function()
    getgenv().UniversalHub.MenuVisible = false
    MainFrame.Visible = false
end)

-- Tabs container
local TabsFrame = Instance.new("Frame")
TabsFrame.Size = UDim2.new(1, 0, 0, 48)
TabsFrame.Position = UDim2.new(0, 0, 0, 85)
TabsFrame.BackgroundTransparency = 1
TabsFrame.Parent = MainFrame

local TabButtons = {}
local TabContents = {}
local tabs = {"Main", "Aimbot", "Trolling", "Utility", "Support"}

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1/#tabs, 0, 1, 0)
    btn.Position = UDim2.new((i-1)/#tabs, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    btn.Text = tabName
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamSemibold
    btn.Parent = TabsFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    TabButtons[i] = btn

    local content = Instance.new("ScrollingFrame")
    content.Size = UDim2.new(1, -20, 1, -145)
    content.Position = UDim2.new(0, 10, 0, 135)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 6
    content.Visible = (i == 1)
    content.Parent = MainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    TabContents[i] = content
end

local function switchTab(index)
    for i, content in ipairs(TabContents) do
        content.Visible = (i == index)
        TabButtons[i].BackgroundColor3 = (i == index) and Color3.fromRGB(0, 140, 255) or Color3.fromRGB(35, 35, 42)
    end
end

for i, btn in ipairs(TabButtons) do
    btn.MouseButton1Click:Connect(function()
        switchTab(i)
    end)
end

-- Helper to create toggle row with purple (off) and pink (on)
local function CreateToggle(parent, text, default, callback, isFlight)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 55)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.68, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "  " .. text
    label.TextColor3 = Color3.new(1,1,1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 17
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 100, 0, 40)
    btn.Position = UDim2.new(0.74, 0, 0.5, -20)
    -- new colors: off = purple, on = pink
    btn.BackgroundColor3 = default and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(128, 0, 128)
    btn.Text = default and "ON" or "OFF"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 17
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local enabled = default
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        btn.Text = enabled and "ON" or "OFF"
        btn.BackgroundColor3 = enabled and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(128, 0, 128)
        callback(enabled)
    end)

    if isFlight then flightToggleBtn = btn end
    return btn
end

-- Helper to create slider row (value + textbox)
local function CreateSlider(parent, labelText, minVal, maxVal, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 65)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "  " .. labelText .. ": " .. defaultValue
    label.TextColor3 = Color3.new(1,1,1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 17
    label.Font = Enum.Font.Gotham
    label.Parent = frame

    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(0, 120, 0, 40)
    textBox.Position = UDim2.new(0.75, 0, 0.5, -20)
    textBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    textBox.Text = tostring(defaultValue)
    textBox.TextColor3 = Color3.new(1,1,1)
    textBox.TextSize = 16
    textBox.Font = Enum.Font.Gotham
    textBox.Parent = frame
    Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 8)

    textBox.FocusLost:Connect(function()
        local val = tonumber(textBox.Text)
        if val then
            val = math.clamp(val, minVal, maxVal)
            callback(val)
            label.Text = "  " .. labelText .. ": " .. val
            textBox.Text = tostring(val)
        else
            textBox.Text = tostring(defaultValue)
        end
    end)

    return textBox
end

-- ========== POPULATE TABS ==========
-- Main tab (1)
local mainTab = TabContents[1]
CreateToggle(mainTab, "👁️ ESP (Nametag + Outline)", false, function(s) getgenv().UniversalHub.ESP = s; updateESP() end)
CreateToggle(mainTab, "🦘 Infinite Jump", false, function(s) getgenv().UniversalHub.InfiniteJump = s end)
CreateToggle(mainTab, "✈️ Flight", false, function(s) getgenv().UniversalHub.Flight = s end, true)
CreateToggle(mainTab, "🌀 NoClip", false, function(s) getgenv().UniversalHub.NoClip = s end)
CreateToggle(mainTab, "⚡ Speed Boost", false, function(s) getgenv().UniversalHub.SpeedBoost = s end)
CreateToggle(mainTab, "💤 Anti-AFK", false, function(s) getgenv().UniversalHub.AntiAFK = s end)

-- Fly speed slider
CreateSlider(mainTab, "✈️ Fly Speed", 20, 500, getgenv().UniversalHub.FlySpeed, function(val)
    getgenv().UniversalHub.FlySpeed = val
end)

-- Speed boost slider
CreateSlider(mainTab, "🏃 Walk Speed", 16, 250, getgenv().UniversalHub.SpeedValue, function(val)
    getgenv().UniversalHub.SpeedValue = val
end)

-- Teleport to coordinates section REMOVED as requested

-- Aimbot tab (2)
local aimbotTab = TabContents[2]
CreateToggle(aimbotTab, "🎯 Aimbot (Hold Right Mouse)", false, function(s) getgenv().UniversalHub.Aimbot = s end)
CreateToggle(aimbotTab, "👥 Team Check (avoid teammates)", true, function(s) getgenv().UniversalHub.TeamCheck = s end)
CreateToggle(aimbotTab, "FOV Circle", true, function(s) getgenv().UniversalHub.FOVCircle = s end)
CreateSlider(aimbotTab, "🎯 Aimbot FOV", 1, 360, getgenv().UniversalHub.AimbotFOV, function(val) 
    getgenv().UniversalHub.AimbotFOV = val
    maxAimFOV = val
end)

-- Trolling tab (3)
local trollingTab = TabContents[3]
CreateToggle(trollingTab, "🌀 Teleport to Player (click target)", false, function(s) getgenv().UniversalHub.TeleportToPlayer = s end)
CreateToggle(trollingTab, "💥 Explode Player (click target)", false, function(s) getgenv().UniversalHub.ExplodePlayer = s end)
CreateToggle(trollingTab, "🔁 Loop Kill (click target)", false, function(s) getgenv().UniversalHub.LoopKill = s end)

-- Utility tab (4)
local utilityTab = TabContents[4]
-- Admin Alerts toggle with notification
CreateToggle(utilityTab, "🔔 Admin Alerts", true, function(s)
    getgenv().UniversalHub.AdminAlerts = s
    Notify("Admin Alerts", s and "Enabled" or "Disabled", 3)
end)

-- Player List panel (universal)
local playerListSection = Instance.new("Frame")
playerListSection.Size = UDim2.new(1, 0, 0, 240)
playerListSection.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
playerListSection.Parent = utilityTab
Instance.new("UICorner", playerListSection).CornerRadius = UDim.new(0, 12)

local playerListTitle = Instance.new("TextLabel")
playerListTitle.Size = UDim2.new(1, -20, 0, 30)
playerListTitle.Position = UDim2.new(0, 10, 0, 10)
playerListTitle.BackgroundTransparency = 1
playerListTitle.Text = "👥 Player List (Name | Team | HP)"
playerListTitle.TextColor3 = Color3.new(1, 1, 1)
playerListTitle.TextSize = 14
playerListTitle.Font = Enum.Font.GothamBold
playerListTitle.TextXAlignment = Enum.TextXAlignment.Left
playerListTitle.Parent = playerListSection

playerListContainer = Instance.new("ScrollingFrame")
playerListContainer.Size = UDim2.new(1, -20, 1, -50)
playerListContainer.Position = UDim2.new(0, 10, 0, 40)
playerListContainer.BackgroundTransparency = 1
playerListContainer.ScrollBarThickness = 6
playerListContainer.Parent = playerListSection

local playerListLayout = Instance.new("UIListLayout", playerListContainer)
playerListLayout.Padding = UDim.new(0, 6)
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local refreshButton = Instance.new("TextButton")
refreshButton.Size = UDim2.new(0.4, 0, 0, 30)
refreshButton.Position = UDim2.new(0.55, 0, 0, 10)
refreshButton.BackgroundColor3 = Color3.fromRGB(0, 180, 140)
refreshButton.TextColor3 = Color3.new(1, 1, 1)
refreshButton.TextSize = 14
refreshButton.Font = Enum.Font.GothamSemibold
refreshButton.Text = "Refresh Players"
refreshButton.Parent = playerListSection

refreshButton.MouseButton1Click:Connect(updatePlayerListUI)

-- Support tab (5)
local supportTab = TabContents[5]
local supportFrame = Instance.new("Frame", supportTab)
supportFrame.Size = UDim2.new(1, 0, 0, 160)
supportFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
Instance.new("UICorner", supportFrame).CornerRadius = UDim.new(0, 12)
local supportText = Instance.new("TextLabel", supportFrame)
supportText.Size = UDim2.new(1, -20, 1, -20)
supportText.Position = UDim2.new(0, 10, 0, 10)
supportText.BackgroundTransparency = 1
supportText.Text = "📢 Support\n\nDiscord Username: hbkvxncent\nDiscord Server: https://discord.globalstats.xyz\n\nThank you for using globalstats.xyz!"
supportText.TextColor3 = Color3.new(1,1,1)
supportText.TextSize = 15
supportText.Font = Enum.Font.Gotham
supportText.TextWrapped = true
supportText.TextXAlignment = Enum.TextXAlignment.Left

-- Initialize FOV circle
updateFOVCircle()

-- ========== FLOATING BUTTON ==========
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 60, 0, 60)
ToggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
ToggleBtn.Text = "🚔"
ToggleBtn.TextSize = 28
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
ToggleBtn.MouseButton1Click:Connect(function()
    getgenv().UniversalHub.MenuVisible = not getgenv().UniversalHub.MenuVisible
    MainFrame.Visible = getgenv().UniversalHub.MenuVisible
end)

-- ========== HOTKEYS ==========
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        getgenv().UniversalHub.MenuVisible = not getgenv().UniversalHub.MenuVisible
        MainFrame.Visible = getgenv().UniversalHub.MenuVisible
    end
    if input.KeyCode == Enum.KeyCode.F then
        getgenv().UniversalHub.Flight = not getgenv().UniversalHub.Flight
        if flightToggleBtn then
            local isOn = getgenv().UniversalHub.Flight
            flightToggleBtn.Text = isOn and "ON" or "OFF"
            -- update to new colors
            flightToggleBtn.BackgroundColor3 = isOn and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(128, 0, 128)
        end
    end
end)

-- ========== INFINITE JUMP ==========
UserInputService.JumpRequest:Connect(function()
    if getgenv().UniversalHub.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ========== NO CLIP / SPEED / ANTI-AFK / FLIGHT STATE ENGINE ==========
local lastAntiAFK = tick()
local antiAFKInterval = 60
local defaultWalkSpeed = 16
local vel, gyro = nil, nil
local flying = false

local function updateNoClip()
    local char = LocalPlayer.Character
    if not char then return end
    local noClip = getgenv().UniversalHub.NoClip
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noClip
        end
    end
end

local function updateSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if getgenv().UniversalHub.SpeedBoost then
            hum.WalkSpeed = getgenv().UniversalHub.SpeedValue
        else
            if hum.WalkSpeed ~= defaultWalkSpeed then
                hum.WalkSpeed = defaultWalkSpeed
            end
        end
    end
end

local function updateAntiAFK()
    if not getgenv().UniversalHub.AntiAFK then
        lastAntiAFK = tick()
        return
    end
    if tick() - lastAntiAFK < antiAFKInterval then return end
    lastAntiAFK = tick()
    pcall(function()
        if typeof(VirtualInput.SendKeyEvent) == "function" then
            VirtualInput:SendKeyEvent(true, Enum.KeyCode.W, false, game)
            task.wait(0.08)
            VirtualInput:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        end
    end)
end

local function updateFlight(dt)
    local character = LocalPlayer.Character
    if not character then
        if flying then
            flying = false
        end
        return
    end

    local root = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChild("Humanoid")
    if getgenv().UniversalHub.Flight and root and hum then
        if hum then hum.PlatformStand = true end
        local move = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0, 1, 0) end

        if move.Magnitude < 0.1 then
            move = Vector3.new(0, 0.5, 0)
        else
            move = move.Unit * getgenv().UniversalHub.FlySpeed
        end

        if not vel then
            vel = Instance.new("BodyVelocity")
            gyro = Instance.new("BodyGyro")
            vel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
            gyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            vel.Parent = root
            gyro.Parent = root
        end

        vel.Velocity = move
        gyro.CFrame = Camera.CFrame
        flying = true
    elseif flying then
        if vel then vel:Destroy() end
        if gyro then gyro:Destroy() end
        vel, gyro = nil, nil
        if hum then hum.PlatformStand = false end
        flying = false
    end
end

local function updatePlayerListUI()
    if updatingPlayerList then return end
    updatingPlayerList = true

    if not playerListContainer then 
        updatingPlayerList = false
        return 
    end

    -- Clear all existing entries to prevent duplicates
    for _, child in ipairs(playerListContainer:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    playerListEntries = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local health, maxHealth = getPlayerHealth(plr)
            local text = (plr.Team and plr.Team.Name or "Neutral") .. " | " .. plr.Name .. " | " .. health .. "/" .. maxHealth

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 40)
            row.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            row.BorderSizePixel = 0
            row.Parent = playerListContainer
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local avatarImage = Instance.new("ImageLabel")
            avatarImage.Size = UDim2.new(0, 30, 0, 30)
            avatarImage.Position = UDim2.new(0.02, 0, 0.5, -15)
            avatarImage.BackgroundTransparency = 1
            pcall(function()
                local avatarUrl = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
                if avatarUrl and avatarUrl ~= "" then
                    avatarImage.Image = avatarUrl
                else
                    avatarImage.Image = "rbxassetid://0" -- fallback to transparent
                end
            end)
            avatarImage.Parent = row
            Instance.new("UICorner", avatarImage).CornerRadius = UDim.new(1, 0)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Size = UDim2.new(0.45, 0, 1, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = text
            nameLabel.TextColor3 = Color3.new(1, 1, 1)
            nameLabel.TextSize = 14
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Position = UDim2.new(0.12, 0, 0, 0)
            nameLabel.Parent = row

            local teleportBtn = Instance.new("TextButton")
            teleportBtn.Size = UDim2.new(0.2, 0, 0.7, 0)
            teleportBtn.Position = UDim2.new(0.58, 0, 0.15, 0)
            teleportBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 255)
            teleportBtn.TextColor3 = Color3.new(1, 1, 1)
            teleportBtn.TextSize = 14
            teleportBtn.Font = Enum.Font.GothamSemibold
            teleportBtn.Text = "Teleport"
            teleportBtn.Parent = row

            teleportBtn.MouseButton1Click:Connect(function()
                local ok = teleportToPlayer(plr)
                if ok then
                    Notify("Teleport", "Teleported to " .. plr.Name, 2)
                else
                    Notify("Teleport", "Failed to teleport to " .. plr.Name, 2)
                end
            end)

            local followBtn = Instance.new("TextButton")
            followBtn.Size = UDim2.new(0.15, 0, 0.7, 0)
            followBtn.Position = UDim2.new(0.80, 0, 0.15, 0)
            followBtn.BackgroundColor3 = Color3.fromRGB(255, 105, 180)
            followBtn.TextColor3 = Color3.new(1, 1, 1)
            followBtn.TextSize = 14
            followBtn.Font = Enum.Font.GothamSemibold
            followBtn.Text = "Select"
            followBtn.Parent = row

            followBtn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                Notify("Player Select", "Selected " .. plr.Name, 2)
            end)

            playerListEntries[plr] = row
        end
    end

    updatingPlayerList = false
end

RunService.Heartbeat:Connect(function(dt)
    updateNoClip()
    updateSpeed()
    updateAntiAFK()
    updateFlight(dt)
    if tick() - lastPlayerListUpdate > 1 then
        updatePlayerListUI()
        lastPlayerListUpdate = tick()
    end
    updateESP()
    updateFOVCircle()
    updateStickFigurePositions()
end)

-- Handle character changes cleanly
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    updateNoClip()
    updateSpeed()
end)

local function onPlayerRemoved(plr)
    if espNametags[plr] then
        espNametags[plr]:Destroy()
        espNametags[plr] = nil
    end
    if espHighlights[plr] then
        espHighlights[plr]:Destroy()
        espHighlights[plr] = nil
    end
    if espStickFigures[plr] then
        for _, line in ipairs(espStickFigures[plr].lines) do
            line:Remove()
        end
        espStickFigures[plr] = nil
    end
end

Players.PlayerRemoving:Connect(onPlayerRemoved)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function()
        if getgenv().UniversalHub.ESP then
            createNametag(plr)
            if getgenv().UniversalHub.ESPMode == "Highlight" then
                createHighlight(plr)
            elseif getgenv().UniversalHub.ESPMode == "StickFigure" then
                createStickFigure(plr)
            end
        end
    end)
end)

-- ========== ADMIN ALERTS & NOTIFICATION SYSTEM ==========
-- Listen for chat messages that may indicate admin activity
local function onChatMessage(msg)
    if not getgenv().UniversalHub.AdminAlerts then return end
    local lowerMsg = string.lower(msg)
    local keywords = {"kick", "ban", "admin", "owner", "moderator", "you have been kicked", "you have been banned"}
    for _, kw in ipairs(keywords) do
        if string.find(lowerMsg, kw) then
            Notify("⚠️ Admin Alert", "Possible admin action detected: " .. msg, 8)
            break
        end
    end
end

-- Listen for local player being kicked or banned
local function onPlayerRemoving(plr)
    if plr == LocalPlayer then
        Notify("❌ You have been kicked/banned!", "The server removed you.", 5)
    end
end

-- Hook into chat (universal method)
local function hookChat()
    pcall(function()
        local chatService = game:GetService("TextChatService")
        if chatService then
            local chatChannel = chatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
            chatChannel.MessageReceived:Connect(function(message)
                if message.Text then
                    onChatMessage(message.Text)
                end
            end)
        else
            -- fallback for legacy chat
            local PlayersChat = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Chat")
            if PlayersChat then
                local frame = PlayersChat:FindFirstChild("Frame")
                if frame then
                    frame.DescendantAdded:Connect(function(desc)
                        if desc:IsA("TextLabel") and desc.Name == "ChatMessage" then
                            onChatMessage(desc.Text)
                        end
                    end)
                end
            end
        end
    end)
end

hookChat()
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Initialize ESP for existing players
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer and plr.Character then
        if getgenv().UniversalHub.ESP then
            createNametag(plr)
            if getgenv().UniversalHub.ESPMode == "Highlight" then
                createHighlight(plr)
            elseif getgenv().UniversalHub.ESPMode == "StickFigure" then
                createStickFigure(plr)
            end
        end
    end
end

-- ========== AIMBOT (Right Mouse) ==========
local lastTrigger = 0
local triggerInterval = 0.1
local maxAimDist = 99999
local aimConn = nil

local function getEnemyPlayers()
    local enemies = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if getgenv().UniversalHub.TeamCheck then
                local team1 = LocalPlayer.Team
                local team2 = plr.Team
                if team1 and team2 and team1 == team2 then
                    continue
                end
            end
            table.insert(enemies, plr)
        end
    end
    return enemies
end

local function performAimbot()
    local closestPart = nil
    local shortest = math.huge
    for _, plr in ipairs(getEnemyPlayers()) do
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}
        for _, partName in ipairs(parts) do
            local part = plr.Character:FindFirstChild(partName)
            if part then
                local dist = (part.Position - Camera.CFrame.Position).Magnitude
                if dist < shortest and dist < maxAimDist then
                    local direction = part.Position - Camera.CFrame.Position
                    local angle = math.deg(math.acos(math.clamp(Camera.CFrame.LookVector:Dot(direction.Unit), -1, 1)))
                    if angle <= getgenv().UniversalHub.AimbotFOV then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                        rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                        local result = workspace:Raycast(Camera.CFrame.Position, direction, rayParams)
                        if not result or (result.Instance and result.Instance:IsDescendantOf(plr.Character)) then
                            shortest = dist
                            closestPart = part
                        end
                    end
                end
            end
        end
    end
    if closestPart then
        local targetPos = closestPart.Position + (closestPart.Velocity * 0.12)
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, targetPos)
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if getgenv().UniversalHub.Aimbot and input.UserInputType == Enum.UserInputType.MouseButton2 then
        if aimConn then aimConn:Disconnect() end
        aimConn = RunService.RenderStepped:Connect(performAimbot)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 and aimConn then
        aimConn:Disconnect()
        aimConn = nil
    end
end)

-- ========== TROLLING FEATURES ==========
local selectedTarget = nil
local function getMouseTarget()
    local mouse = LocalPlayer:GetMouse()
    local hit = mouse.Target
    if hit and hit.Parent and hit.Parent:FindFirstChild("Humanoid") then
        return hit.Parent
    end
    return nil
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local targetChar = getMouseTarget()
        if targetChar then
            local plr = Players:GetPlayerFromCharacter(targetChar)
            if plr and plr ~= LocalPlayer then
                selectedTarget = plr
                if getgenv().UniversalHub.TeleportToPlayer then
                    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                    if root and targetRoot then
                        root.CFrame = targetRoot.CFrame + Vector3.new(0, 2, 0)
                    end
                elseif getgenv().UniversalHub.ExplodePlayer then
                    local part = targetChar:FindFirstChild("HumanoidRootPart")
                    if part then
                        local explosion = Instance.new("Explosion")
                        explosion.Position = part.Position
                        explosion.Parent = workspace
                        explosion.Hit:Connect(function(hitPart)
                            if hitPart.Parent == targetChar then
                                hitPart:BreakJoints()
                            end
                        end)
                    end
                elseif getgenv().UniversalHub.LoopKill then
                    local loopConn
                    loopConn = RunService.Heartbeat:Connect(function()
                        if targetChar and targetChar.Parent and targetChar:FindFirstChild("Humanoid") then
                            targetChar.Humanoid.Health = 0
                        else
                            loopConn:Disconnect()
                        end
                    end)
                end
            end
        end
    end
end)

print("✅ globalstats.xyz | Universal Script loaded!")
print("Press K → Menu | Press F → Flight")
print("Hold Right Mouse → Aimbot (team-check enabled)")
print("Minimize button in top bar → hides menu")
print("Resize by dragging bottom-right corner")
