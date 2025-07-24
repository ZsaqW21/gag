--[[
    Proximity Harvester
    - When enabled via the GUI, automatically collects the 12 closest
      harvestable fruits/plants on your farm.
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
local autoHarvestEnabled = false
local HARVEST_LIMIT = 12 -- How many of the closest items to collect per scan

--================================================================================--
--                         GUI Creation
--================================================================================--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoHarvestToggleGui"
screenGui.ResetOnSpawn = false

local button = Instance.new("TextButton")
button.Name = "HarvestToggleButton"
button.TextSize = 16
button.Font = Enum.Font.SourceSansBold
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Size = UDim2.new(0, 150, 0, 40)
button.Position = UDim2.new(1, -160, 0, 10) -- Top right corner
local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 6)

local function updateButtonState()
    if autoHarvestEnabled then
        button.Text = "Auto Harvest: ON"
        button.BackgroundColor3 = Color3.fromRGB(20, 140, 70) -- Green
    else
        button.Text = "Auto Harvest: OFF"
        button.BackgroundColor3 = Color3.fromRGB(190, 40, 40) -- Red
    end
end

button.MouseButton1Click:Connect(function()
    autoHarvestEnabled = not autoHarvestEnabled
    updateButtonState()
end)

updateButtonState()
button.Parent = screenGui
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

task.spawn(function()
    print("Auto-Harvest thread started.")
    local myFarm = FindFarmByLocation()
    if not myFarm then
        warn("Harvester: Could not find your farm. Please stand on your plot and re-run.")
        return
    end
    local plantsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Plants_Physical")
    if not plantsFolder then
        warn("Harvester: Could not find 'Plants_Physical' folder.")
        return
    end
    
    print("Harvester: Farm found. Ready to harvest when enabled.")

    while true do
        if autoHarvestEnabled then
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
                for i = 1, math.min(HARVEST_LIMIT, #promptsWithDist) do
                    local promptData = promptsWithDist[i]
                    if promptData.Prompt and promptData.Prompt.Enabled then
                        fireproximityprompt(promptData.Prompt)
                        collected = collected + 1
                        task.wait(0.1)
                    end
                end
                
                if collected > 0 then
                    print("Harvested " .. collected .. " closest items.")
                end
            end
        end
        task.wait(1.5) -- Wait between each scan
    end
end)
