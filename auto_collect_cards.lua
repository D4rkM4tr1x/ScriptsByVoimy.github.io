-- Auto Collect Cards Script for Build a Scam Empire!
-- Features: GUI toggle, configurable delay, auto-discovery of Server ProximityPrompts

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

-- Configuration
local MIN_DELAY = 0.1
local MAX_DELAY = 5.0
local DEFAULT_DELAY = 0.5
local SEARCH_INTERVAL = 2.0

-- State variables
local isEnabled = false
local collectDelay = DEFAULT_DELAY
local lastScanTick = 0
local cachedPrompts = {}

-- Utility functions
local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function safeWait(duration)
    local success, err = pcall(function()
        task.wait(duration)
    end)
    if not success then
        wait(duration)
    end
end

-- GUI Creation
local function createGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoCollectGui"
    screenGui.ResetOnSpawn = false
    
    -- Try to parent to CoreGui, fallback to PlayerGui
    local success = pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not success then
        screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 280, 0, 180)
    mainFrame.Position = UDim2.new(0, 20, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = mainFrame

    -- Title Bar
    local titleBar = Instance.new("TextLabel")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Font = Enum.Font.GothamBold
    titleBar.Text = "Auto Collect Cards"
    titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleBar.TextSize = 14
    titleBar.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar

    -- Toggle Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 240, 0, 35)
    toggleButton.Position = UDim2.new(0, 20, 0, 45)
    toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    toggleButton.BorderSizePixel = 0
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Text = "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 16
    toggleButton.Parent = mainFrame

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton

    -- Delay Label
    local delayLabel = Instance.new("TextLabel")
    delayLabel.Name = "DelayLabel"
    delayLabel.Size = UDim2.new(0, 100, 0, 25)
    delayLabel.Position = UDim2.new(0, 20, 0, 95)
    delayLabel.BackgroundTransparency = 1
    delayLabel.Font = Enum.Font.Gotham
    delayLabel.Text = "Delay (s):"
    delayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    delayLabel.TextSize = 12
    delayLabel.TextXAlignment = Enum.TextXAlignment.Left
    delayLabel.Parent = mainFrame

    -- Delay Input
    local delayInput = Instance.new("TextBox")
    delayInput.Name = "DelayInput"
    delayInput.Size = UDim2.new(0, 100, 0, 25)
    delayInput.Position = UDim2.new(0, 130, 0, 95)
    delayInput.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    delayInput.BorderSizePixel = 0
    delayInput.Font = Enum.Font.Gotham
    delayInput.Text = tostring(DEFAULT_DELAY)
    delayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    delayInput.TextSize = 12
    delayInput.PlaceholderText = "0.1 - 5.0"
    delayInput.Parent = mainFrame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 4)
    inputCorner.Parent = delayInput

    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(0, 240, 0, 30)
    statusLabel.Position = UDim2.new(0, 20, 0, 135)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Status: Stopped"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextSize = 11
    statusLabel.Parent = mainFrame

    return screenGui, mainFrame, toggleButton, delayInput, statusLabel, titleBar
end

-- Draggable behavior
local function makeDraggable(frame, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Discover Server ProximityPrompts
local function getServerPrompts()
    local prompts = {}
    
    pcall(function()
        for _, descendant in ipairs(Workspace:GetDescendants()) do
            if descendant:IsA("ProximityPrompt") and descendant.Enabled then
                -- Check if this prompt is for collecting (look for "Collect" in action text)
                local isCollectPrompt = false
                
                if descendant.ActionText and string.find(string.lower(descendant.ActionText), "collect") then
                    isCollectPrompt = true
                elseif descendant.ObjectText and string.find(string.lower(descendant.ObjectText), "collect") then
                    isCollectPrompt = true
                end
                
                -- Also check if parent hierarchy contains "Server" in name
                local parent = descendant.Parent
                while parent and parent ~= Workspace do
                    if string.find(string.lower(parent.Name), "server") then
                        isCollectPrompt = true
                        break
                    end
                    parent = parent.Parent
                end
                
                if isCollectPrompt then
                    table.insert(prompts, descendant)
                end
            end
        end
    end)
    
    return prompts
end

-- Fire proximity prompt safely
local function firePrompt(prompt)
    pcall(function()
        if prompt and prompt.Parent and prompt.Enabled then
            -- Try using fireproximityprompt if available
            if fireproximityprompt then
                fireproximityprompt(prompt, prompt.HoldDuration or 0)
            else
                -- Fallback: simulate keypress (less reliable)
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                safeWait(prompt.HoldDuration or 0.05)
                vim:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
        end
    end)
end

-- Collection cycle
local function collectOnce(statusLabel)
    pcall(function()
        statusLabel.Text = "Status: Collecting..."
        statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        
        local prompts = cachedPrompts
        local collected = 0
        
        for _, prompt in ipairs(prompts) do
            if prompt and prompt.Parent and prompt.Enabled then
                -- Check if player is within range (optional distance check)
                local player = Players.LocalPlayer
                if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    local rootPart = player.Character.HumanoidRootPart
                    local promptParent = prompt.Parent
                    
                    if promptParent and promptParent:IsA("BasePart") then
                        local distance = (rootPart.Position - promptParent.Position).Magnitude
                        if distance <= (prompt.MaxActivationDistance + 10) then
                            firePrompt(prompt)
                            collected = collected + 1
                            safeWait(0.03)
                        end
                    else
                        -- No distance check possible, just fire it
                        firePrompt(prompt)
                        collected = collected + 1
                        safeWait(0.03)
                    end
                else
                    -- No character, fire anyway
                    firePrompt(prompt)
                    collected = collected + 1
                    safeWait(0.03)
                end
            end
        end
        
        statusLabel.Text = "Status: Running (" .. collected .. " collected)"
        statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
end

-- Main script execution
local function main()
    -- Create GUI
    local screenGui, mainFrame, toggleButton, delayInput, statusLabel, titleBar = createGui()
    
    -- Make draggable
    makeDraggable(mainFrame, titleBar)
    
    -- Toggle button handler
    toggleButton.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        
        if isEnabled then
            toggleButton.Text = "ON"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            statusLabel.Text = "Status: Starting..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            toggleButton.Text = "OFF"
            toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            statusLabel.Text = "Status: Stopped"
            statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end)
    
    -- Delay input handler
    delayInput.FocusLost:Connect(function()
        local value = tonumber(delayInput.Text)
        if value then
            collectDelay = clamp(value, MIN_DELAY, MAX_DELAY)
            delayInput.Text = tostring(collectDelay)
        else
            delayInput.Text = tostring(collectDelay)
        end
    end)
    
    -- Main loop
    task.spawn(function()
        while true do
            if isEnabled then
                -- Rescan prompts periodically
                if tick() - lastScanTick >= SEARCH_INTERVAL then
                    cachedPrompts = getServerPrompts()
                    lastScanTick = tick()
                end
                
                -- Collect
                collectOnce(statusLabel)
                safeWait(collectDelay)
            else
                safeWait(0.2)
            end
        end
    end)
    
    print("[Auto Collect] Script loaded successfully!")
    print("[Auto Collect] Toggle the button to start collecting.")
end

-- Run the script
main()
