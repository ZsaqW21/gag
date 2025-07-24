--[[
    Proximity Harvester
    - When the button is pressed, automatically collects a user-defined
      amount of the closest harvestable fruits/plants on your farm.
]]

--================================================================================--
--                         Services & Player Setup
--================================================================================--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

--================================================================================--
--                         Configuration & State
--================================================================================--
local harvestLimit = 12 -- Default value
local isHarvesting = false -- Debounce to prevent spamming

--================================================================================--
--                         GUI Creation
--================================================================================--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoHarvestGui"
screenGui.ResetOnSpawn = false

-- Main Harvest Button
local harvestButton = Instance.new("TextButton")
harvestButton.Name = "HarvestButton"
harvestButton.Text = "Harvest Closest"
harvestButton.TextSize = 16
harvestButton.Font = Enum.Font.SourceSansBold
harvestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
harvestButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
harvestButton.Size = UDim2.new(0, 150, 0, 40)
harvestButton.Position = UDim2.new(1, -160, 0, 10) -- Top right corner
local corner = Instance.new("UICorner", harvestButton); corner.CornerRadius = UDim.new(0, 6)

-- Amount Input TextBox
local amountInput = Instance.new("TextBox")
amountInput.Name = "AmountInput"
amountInput.Text = tostring(harvestLimit)
amountInput.PlaceholderText = "Amount"
amountInput.TextSize = 14
amountInput.Font = Enum.Font.SourceSans
amountInput.TextColor3 = Color3.fromRGB(240, 240, 240)
amountInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
amountInput.Size = UDim2.new(0, 60, 0, 30)
amountInput.Position = UDim2.new(1, -230, 0, 15)
local corner2 = Instance.new("UICorner", amountInput); corner2.CornerRadius = UDim.new(0, 4)

-- Label for the TextBox
local amountLabel = Instance.new("TextLabel")
amountLabel.Name = "AmountLabel"
amountLabel.Text = "Amount:"
amountLabel.TextSize = 14
amountLabel.Font = Enum.Font.SourceSans
amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
amountLabel.BackgroundTransparency = 1
amountLabel.TextXAlignment = Enum.TextXAlignment.Right
amountLabel.Size = UDim2.new(0, 60, 0, 30)
amountLabel.Position = UDim2.new(1, -295, 0, 15)

harvestButton.Parent = screenGui
amountInput.Parent = screenGui
amountLabel.Parent = screenGui
screenGui.Parent = PlayerGui

--================================================================================--
--                         Auto-Harvest Logic
--================================================================================--
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

local function getAllPrompts(folder, promptList)
    for _, item in ipairs(folder:GetChildren()) do
        local prompt = item:FindFirstChild("ProximityPrompt", true)
        if prompt and prompt.Enabled then
            table.insert(promptList, prompt)
        end
        local fruitsFolder = item:FindFirstChild("Fruits")
        if fruitsFolder then
            getAllPrompts(fruitsFolder, promptList)
        end
    end
end

local function runHarvestCycle()
    if isHarvesting then return end -- Prevent spamming
    isHarvesting = true
    harvestButton.Text = "Harvesting..."
    harvestButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)

    local myFarm = FindFarmByLocation()
    if not myFarm then
        warn("Harvester: Could not find your farm. Please stand on your plot and re-run.")
        isHarvesting = false; return
    end
    local plantsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Plants_Physical")
    if not plantsFolder then
        warn("Harvester: Could not find 'Plants_Physical' folder.")
        isHarvesting = false; return
    end
    
    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        local allPrompts = {}
        getAllPrompts(plantsFolder, allPrompts)

        local promptsWithDist = {}
        for _, prompt in ipairs(allPrompts) do
            if prompt.Parent and prompt.Parent.Parent and prompt.Parent.Parent:GetPivot() then
                local distance = (rootPart.Position - prompt.Parent.Parent:GetPivot().Position).Magnitude
                table.insert(promptsWithDist, {Prompt = prompt, Distance = distance})
            end
        end

        table.sort(promptsWithDist, function(a, b)
            return a.Distance < b.Distance
        end)

        local collected = 0
        local limit = tonumber(amountInput.Text) or harvestLimit
        for i = 1, math.min(limit, #promptsWithDist) do
            local promptData = promptsWithDist[i]
            if promptData.Prompt and promptData.Prompt.Enabled then
                fireproximityprompt(promptData.Prompt)
                collected = collected + 1
                task.wait(0.1)
            end
        end
        
        if collected > 0 then
            print("Harvested " .. collected .. " closest items.")
        else
            print("No harvestable items found.")
        end
    end

    task.wait(1) -- Cooldown
    isHarvesting = false
    harvestButton.Text = "Harvest Closest"
    harvestButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
end

-- Connect the button to the harvest function
harvestButton.MouseButton1Click:Connect(runHarvestCycle)

print("Proximity Harvester loaded.")
