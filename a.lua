-- Wait for the game to fully load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Isolate the entire script to prevent name conflicts
do
    --================================================================================--
    --                         Services & Player Setup
    --================================================================================--
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")
    local Workspace = game:GetService("Workspace")

    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local Backpack = LocalPlayer:WaitForChild("Backpack")
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

    local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
    local CraftingService = GameEvents:WaitForChild("CraftingGlobalObjectService")
    local PetEggService = GameEvents:WaitForChild("PetEggService")

    --================================================================================--
    --                         Configuration & State
    --================================================================================--
    local CONFIG_FILE_NAME = "CombinedAutoFarmConfig_v5_Priority.json"
    local isEnabled = false
    local mainThread = nil
    local knownReadyEggs = {}
    local placedPositions = {}

    local PLACEMENT_ATTRIBUTE_NAME = "h"
    local PLACEMENT_ATTRIBUTE_VALUE = "Primal Egg"
    local PLACEMENT_COUNT = 10
    local MINIMUM_DISTANCE = 5
    local corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344)
    local corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)

    --================================================================================--
    --                         Configuration Save/Load
    --================================================================================--
    local function UniqueFarm_SaveConfig()
        if typeof(writefile) ~= "function" then return end
        local uuidArrayToSave = {}
        for uuid, _ in pairs(knownReadyEggs) do table.insert(uuidArrayToSave, uuid) end
        local configData = { enabled = isEnabled, readyEggUUIDs = uuidArrayToSave }
        pcall(function() writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(configData)) end)
    end

    local function UniqueFarm_LoadConfig()
        if typeof(readfile) ~= "function" then return end
        local success, fileData = pcall(readfile, CONFIG_FILE_NAME)
        if success and fileData then
            local success2, configData = pcall(HttpService.JSONDecode, HttpService, fileData)
            if success2 and typeof(configData) == "table" then
                isEnabled = configData.enabled or false
                if configData.readyEggUUIDs and typeof(configData.readyEggUUIDs) == "table" then
                    for _, uuid in ipairs(configData.readyEggUUIDs) do knownReadyEggs[uuid] = true end
                end
            end
        end
    end

    --================================================================================--
    --                         Helper Functions
    --================================================================================--
    local function UniqueFarm_FindFarmByLocation()
        local rootPart = Character:WaitForChild("HumanoidRootPart")
        local farmsFolder = Workspace:WaitForChild("Farm")
        local closestFarm, minDistance = nil, math.huge
        for _, farmPlot in ipairs(farmsFolder:GetChildren()) do
            local centerPoint = farmPlot:FindFirstChild("Center_Point")
            if centerPoint then
                local distance = (rootPart.Position - centerPoint.Position).Magnitude
                if distance < minDistance then minDistance = distance; closestFarm = farmPlot end
            end
        end
        return closestFarm
    end

    local function UniqueFarm_FindPlacementTool()
        for _, item in ipairs(Character:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(PLACEMENT_ATTRIBUTE_NAME) == PLACEMENT_ATTRIBUTE_VALUE then return item, "equipped" end
        end
        for _, item in ipairs(Backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(PLACEMENT_ATTRIBUTE_NAME) == PLACEMENT_ATTRIBUTE_VALUE then return item, "backpack" end
        end
        return nil, nil
    end

    local function UniqueFarm_PlaceOneEgg()
        local randomPosition, isValidPosition, attempts = nil, false, 0
        repeat
            local minX = math.min(corner1.X, corner2.X); local maxX = math.max(corner1.X, corner2.X)
            local minZ = math.min(corner1.Z, corner2.Z); local maxZ = math.max(corner1.Z, corner2.Z)
            local randomX = math.random() * (maxX - minX) + minX
            local randomZ = math.random() * (maxZ - minZ) + minZ
            randomPosition = Vector3.new(randomX, corner1.Y, randomZ)
            isValidPosition = true
            for _, placedPos in ipairs(placedPositions) do
                if (randomPosition - placedPos).Magnitude < MINIMUM_DISTANCE then isValidPosition = false; break end
            end
            attempts = attempts + 1
        until isValidPosition or attempts >= 50
        if isValidPosition then
            PetEggService:FireServer(unpack({ "CreateEgg", randomPosition }))
            table.insert(placedPositions, randomPosition)
        end
    end

    local UniqueFarm_RunMasterLoop -- Forward declaration

    --================================================================================--
    --                         GUI & Master Loop
    --================================================================================--
    local screenGui = Instance.new("ScreenGui", PlayerGui); screenGui.Name = "CombinedFarmCraftGui"; screenGui.ResetOnSpawn = false
    local button = Instance.new("TextButton", screenGui); button.Name = "ToggleButton"; button.TextSize = 20; button.Font = Enum.Font.SourceSansBold; button.TextColor3 = Color3.fromRGB(255, 255, 255); button.Size = UDim2.new(0, 180, 0, 50); button.Position = UDim2.new(1, -200, 1, -70)
    local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 8)

    local function UniqueFarm_UpdateButtonState(statusText)
        if isEnabled then
            button.Text = "AutoFarm: " .. (statusText or "ON"); button.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
        else
            button.Text = "AutoFarm: OFF"; button.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
        end
    end

    local function UniqueFarm_PerformOneCraftCycle()
        local success, err = pcall(function()
            UniqueFarm_UpdateButtonState("Crafting...")
            local DinoEvent = Workspace:FindFirstChild("DinoEvent") or ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
            if DinoEvent and DinoEvent:IsDescendantOf(ReplicatedStorage) then DinoEvent.Parent = Workspace end
            local DinoTable = Workspace:WaitForChild("DinoEvent"):WaitForChild("DinoCraftingTable")
            CraftingService:FireServer("SetRecipe", DinoTable, "DinoEventWorkbench", "Primal Egg")
            task.wait(0.3)
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("h") == "Dinosaur Egg" then
                    tool.Parent = Character; task.wait(0.3)
                    if tool:GetAttribute("c") then CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 1, { ItemType = "PetEgg", ItemData = { UUID = tool:GetAttribute("c") } }) end
                    tool.Parent = Backpack; break
                end
            end
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                    for _, t in ipairs(Character:GetChildren()) do if t:IsA("Tool") then t.Parent = Backpack end end
                    tool.Parent = Character; task.wait(0.3)
                    if tool:GetAttribute("c") then CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 2, { ItemType = "Holdable", ItemData = { UUID = tool:GetAttribute("c") } }) end
                    tool.Parent = Backpack; break
                end
            end
            task.wait(0.3)
            CraftingService:FireServer("Craft", DinoTable, "DinoEventWorkbench")
            task.wait(1)
            TeleportService:Teleport(game.PlaceId)
        end)
        if not success then warn("AutoCraft Error:", err, "-- Turning off."); isEnabled = false; UniqueFarm_UpdateButtonState(); UniqueFarm_SaveConfig() end
    end

    UniqueFarm_RunMasterLoop = function()
        while isEnabled do
            -- PHASE 1: FIND FARM
            UniqueFarm_UpdateButtonState("Finding Farm")
            local myFarm = UniqueFarm_FindFarmByLocation()
            if not myFarm then warn("Could not find farm, retrying..."); task.wait(5); continue end
            local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
            if not objectsFolder then warn("Could not find Objects_Physical folder, retrying..."); task.wait(5); continue end
            
            -- PHASE 2: CHECK FOR HATCHING
            UniqueFarm_UpdateButtonState("Checking Eggs")
            local allEggs, readyCount, eggsToHatch = objectsFolder:GetChildren(), 0, {}
            for _, egg in ipairs(allEggs) do
                local uuid = egg:GetAttribute("c")
                if uuid and not knownReadyEggs[uuid] and egg:GetAttribute("READY") == true then knownReadyEggs[uuid] = true end
            end
            for _, egg in ipairs(allEggs) do
                local uuid = egg:GetAttribute("c")
                if uuid and knownReadyEggs[uuid] then readyCount = readyCount + 1; table.insert(eggsToHatch, egg) end
            end
            
            if #allEggs >= 8 and readyCount == #allEggs then
                UniqueFarm_UpdateButtonState("Hatching " .. #eggsToHatch)
                for _, eggToHatch in ipairs(eggsToHatch) do
                    if not isEnabled then break end
                    local uuid = eggToHatch:GetAttribute("c")
                    local prompt = eggToHatch:FindFirstChild("ProximityPrompt", true)
                    if prompt then fireproximityprompt(prompt); if uuid then knownReadyEggs[uuid] = nil end; task.wait(0.2) end
                end
                task.wait(3)
                UniqueFarm_SaveConfig()
                continue -- Restart the loop to re-evaluate the farm's state
            end
            
            -- PHASE 3: CHECK FOR PLACEMENT
            allEggs = objectsFolder:GetChildren()
            if #allEggs < 4 then
                UniqueFarm_UpdateButtonState("Placing Eggs")
                local toolInstance, location = UniqueFarm_FindPlacementTool()
                if location then
                    if location == "backpack" then
                        local humanoid = Character:WaitForChild("Humanoid")
                        if humanoid then humanoid:EquipTool(toolInstance); task.wait(0.5) end
                    end
                    for i = 1, PLACEMENT_COUNT do
                        if not isEnabled then break end
                        UniqueFarm_PlaceOneEgg(); task.wait(0.5)
                    end
                    task.wait(1)
                    UniqueFarm_SaveConfig()
                    continue -- Restart the loop to re-evaluate
                else
                    warn("Cannot place eggs: Primal Egg tool not found.")
                end
            end
            
            -- PHASE 4: DEFAULT TO CRAFTING
            UniqueFarm_SaveConfig()
            UniqueFarm_PerformOneCraftCycle()
            
            task.wait(5) -- Failsafe in case teleport fails
        end
        UniqueFarm_SaveConfig()
        UniqueFarm_UpdateButtonState()
    end

    button.MouseButton1Click:Connect(function()
        isEnabled = not isEnabled
        UniqueFarm_UpdateButtonState()
        if isEnabled then mainThread = task.spawn(UniqueFarm_RunMasterLoop)
        else
            if mainThread then task.cancel(mainThread); mainThread = nil end
            UniqueFarm_SaveConfig()
        end
    end)

    UniqueFarm_LoadConfig()
    UniqueFarm_UpdateButtonState()
    if isEnabled then mainThread = task.spawn(UniqueFarm_RunMasterLoop) end

    print("Combined Auto-Farm & Crafter (Priority Logic) loaded.")
end
