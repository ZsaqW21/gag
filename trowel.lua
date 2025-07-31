--[[
    Plant Logger & CFrame Saver with Automatic Plant Moving
    - Logs plants for 25 seconds
    - Saves CFrame positions
    - Automatically moves plants one-by-one to saved position
    - Waits for each plant to be in position before moving next
]]

-- Singleton check
if _G.MyPlantLoggerIsRunning then
    print("Plant Logger script is already running.")
    return
end
_G.MyPlantLoggerIsRunning = true

-- Wait for game to load
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(1)

print("Plant Logger & CFrame Saver loaded.")

--================================================================================--
--                         Services & Player Setup
--================================================================================--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

repeat task.wait() until Character and Character:FindFirstChild("HumanoidRootPart")

--================================================================================--
--                         Configuration & State
--================================================================================--
local loggedPlants = {}
local savedCFrame = nil
local LOGGING_DURATION = 25
local isMovingPlants = false
local currentPlantIndex = 1
local plantsArray = {} -- Array version of logged plants for sequential access

-- Remote
local TrowelRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("TrowelRemote")

--================================================================================--
--                         GUI Creation
--================================================================================--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlantLoggerGui"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 120)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BackgroundTransparency = 0.2
local corner = Instance.new("UICorner", mainFrame); corner.CornerRadius = UDim.new(0, 6)

local saveButton = Instance.new("TextButton")
saveButton.Name = "SaveCFrameButton"
saveButton.Text = "Save Current Position"
saveButton.TextSize = 14
saveButton.Font = Enum.Font.SourceSansBold
saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
saveButton.Size = UDim2.new(0, 200, 0, 30)
saveButton.Position = UDim2.new(0, 10, 0, 10)
local saveCorner = Instance.new("UICorner", saveButton); saveCorner.CornerRadius = UDim.new(0, 4)

local trowelButton = Instance.new("TextButton")
trowelButton.Name = "TrowelButton"
trowelButton.Text = "Start Moving Plants (0)"
trowelButton.TextSize = 14
trowelButton.Font = Enum.Font.SourceSansBold
trowelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
trowelButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
trowelButton.Size = UDim2.new(0, 200, 0, 30)
trowelButton.Position = UDim2.new(0, 10, 0, 50)
local trowelCorner = Instance.new("UICorner", trowelButton); trowelCorner.CornerRadius = UDim.new(0, 4)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Text = "Status: Ready"
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.BackgroundTransparency = 1
statusLabel.Size = UDim2.new(0, 200, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 90)

saveButton.Parent = mainFrame
trowelButton.Parent = mainFrame
statusLabel.Parent = mainFrame
mainFrame.Parent = screenGui
screenGui.Parent = PlayerGui

--================================================================================--
--                         Core Functions
--================================================================================--

local function updatePlantList()
    plantsArray = {}
    for plant in pairs(loggedPlants) do
        table.insert(plantsArray, plant)
    end
    trowelButton.Text = string.format("Start Moving Plants (%d)", #plantsArray)
end

local function FindFarmByLocation()
    local rootPart = Character:WaitForChild("HumanoidRootPart")
    if not rootPart then return nil end
    local farmsFolder = Workspace:WaitForChild("Farm")
    local closestFarm, minDistance = nil, math.huge
    for _, farmPlot in ipairs(farmsFolder:GetChildren()) do
        local centerPoint = farmPlot:FindFirstChild("Center_Point")
        if centerPoint then
            local distance = (rootPart.Position - centerPoint.Position).Magnitude
            if distance < minDistance then
                minDistance = distance
                closestFarm = farmPlot
            end
        end
    end
    return closestFarm
end

local function saveCurrentCFrame()
    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        savedCFrame = rootPart.CFrame
        statusLabel.Text = "Status: Position Saved!"
        print("CFrame saved successfully:", savedCFrame)
        saveButton.Text = "Position Saved!"
        task.wait(2)
        saveButton.Text = "Save Current Position"
        statusLabel.Text = "Status: Ready"
    else
        statusLabel.Text = "Status: No HumanoidRootPart!"
        warn("Could not find HumanoidRootPart to save CFrame.")
        task.wait(2)
        statusLabel.Text = "Status: Ready"
    end
end

local function startPlantLogging()
    local myFarm = FindFarmByLocation()
    if not myFarm then
        statusLabel.Text = "Status: Couldn't find farm!"
        warn("Logger: Could not find your farm. Please stand on your plot and re-run.")
        task.wait(2)
        statusLabel.Text = "Status: Ready"
        return
    end
    
    local plantsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Plants_Physical")
    if not plantsFolder then
        statusLabel.Text = "Status: No Plants_Physical!"
        warn("Logger: Could not find 'Plants_Physical' folder.")
        task.wait(2)
        statusLabel.Text = "Status: Ready"
        return
    end

    -- Clear previous logs
    loggedPlants = {}
    currentPlantIndex = 1
    plantsArray = {}
    
    statusLabel.Text = "Status: Logging plants..."
    print("Starting to log plants for " .. LOGGING_DURATION .. " seconds...")
    
    local startTime = tick()
    while tick() - startTime < LOGGING_DURATION do
        for _, plant in ipairs(plantsFolder:GetChildren()) do
            if not loggedPlants[plant] then
                loggedPlants[plant] = true
                updatePlantList()
            end
        end
        statusLabel.Text = string.format("Status: Logging (%.1fs)", LOGGING_DURATION - (tick() - startTime))
        task.wait(0.5)
    end

    print("Logging complete. Found " .. #plantsArray .. " unique plants.")
    statusLabel.Text = "Status: Ready"
end

local function plantInPosition(plant, targetCFrame)
    if not plant or not plant.Parent then return false end
    local distance = (plant:GetPivot().Position - targetCFrame.Position).Magnitude
    return distance < 1 -- Consider in position if within 1 stud
end

local function movePlantsAutomatically()
    if isMovingPlants then return end
    
    if not savedCFrame then
        statusLabel.Text = "Status: No saved position!"
        task.wait(2)
        statusLabel.Text = "Status: Ready"
        return
    end
    
    -- Get the trowel tool
    local trowel
    for _, tool in ipairs(Character:GetChildren()) do
        if tool.Name:find("Trowel") then
            trowel = tool
            break
        end
    end
    
    if not trowel then
        statusLabel.Text = "Status: No trowel equipped!"
        task.wait(2)
        statusLabel.Text = "Status: Ready"
        return
    end
    
    if #plantsArray == 0 then
        statusLabel.Text = "Status: No plants logged!"
        task.wait(2)
        statusLabel.Text = "Status: Ready"
        return
    end
    
    isMovingPlants = true
    trowelButton.Text = "Moving Plants..."
    trowelButton.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
    
    -- Convert to array if not already
    if #plantsArray == 0 then
        updatePlantList()
    end
    
    for i, plant in ipairs(plantsArray) do
        if not plant or not plant.Parent then
            loggedPlants[plant] = nil
            statusLabel.Text = string.format("Status: Plant %d missing", i)
            task.wait(1)
            goto continue
        end
        
        currentPlantIndex = i
        statusLabel.Text = string.format("Status: Moving plant %d/%d", i, #plantsArray)
        
        -- Skip if already in position
        if plantInPosition(plant, savedCFrame) then
            statusLabel.Text = string.format("Status: Plant %d already in position", i)
            task.wait(0.5)
            goto continue
        end
        
        -- Pick up the plant
        local success, err = pcall(function()
            TrowelRemote:InvokeServer("Pickup", trowel, plant)
        end)
        
        if not success then
            warn("Failed to pickup plant: " .. err)
            loggedPlants[plant] = nil
            statusLabel.Text = string.format("Status: Failed to pick up plant %d", i)
            task.wait(1)
            goto continue
        end
        
        task.wait(0.5)
        
        -- Place the plant at saved CFrame
        success, err = pcall(function()
            TrowelRemote:InvokeServer("Place", trowel, plant, savedCFrame)
        end)
        
        if not success then
            warn("Failed to place plant: " .. err)
            statusLabel.Text = string.format("Status: Failed to place plant %d", i)
            task.wait(1)
            goto continue
        end
        
        -- Wait until plant is in position
        local attempts = 0
        while not plantInPosition(plant, savedCFrame) and attempts < 20 do
            attempts = attempts + 1
            statusLabel.Text = string.format("Status: Waiting for plant %d (attempt %d/20)", i, attempts)
            task.wait(0.5)
        end
        
        if attempts >= 20 then
            statusLabel.Text = string.format("Status: Plant %d didn't move properly", i)
            task.wait(1)
        else
            statusLabel.Text = string.format("Status: Plant %d moved successfully", i)
            task.wait(0.5)
        end
        
        ::continue::
    end
    
    isMovingPlants = false
    trowelButton.Text = "Start Moving Plants (0)"
    trowelButton.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
    statusLabel.Text = "Status: All plants processed!"
    task.wait(2)
    statusLabel.Text = "Status: Ready"
end

--================================================================================--
--                         Event Connections
--================================================================================--

saveButton.MouseButton1Click:Connect(saveCurrentCFrame)
trowelButton.MouseButton1Click:Connect(movePlantsAutomatically)

-- Auto-start logging
task.spawn(startPlantLogging)

-- Cleanup
local function cleanup()
    screenGui:Destroy()
    _G.MyPlantLoggerIsRunning = false
end

script.Destroying:Connect(cleanup)
Players.PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        cleanup()
    end
end)
