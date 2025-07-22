-- Wait for the game to fully load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Isolate the entire script to prevent name conflicts
do
    -- Create a self-contained module to hold ONLY STATE
    local FarmState = {
        isEnabled = false,
        mainThread = nil,
        knownReadyEggs = {},
        placedPositions = {},
        CONFIG_FILE_NAME = "CombinedAutoFarmConfig_v9_HyperIsolated.json",
        PLACEMENT_ATTRIBUTE_NAME = "h",
        PLACEMENT_ATTRIBUTE_VALUE = "Primal Egg",
        PLACEMENT_COUNT = 10,
        MINIMUM_DISTANCE = 5,
        corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344),
        corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)
    }

    --================================================================================--
    --                         Services (defined once)
    --================================================================================--
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService = game:GetService("TeleportService")
    local Workspace = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    --================================================================================--
    --                         GUI (defined once)
    --================================================================================--
    local screenGui = Instance.new("ScreenGui", PlayerGui); screenGui.Name = "CombinedFarmCraftGui"; screenGui.ResetOnSpawn = false
    local mainButton = Instance.new("TextButton", screenGui); mainButton.Name = "ToggleButton"; mainButton.TextSize = 20; mainButton.Font = Enum.Font.SourceSansBold; mainButton.TextColor3 = Color3.fromRGB(255, 255, 255); mainButton.Size = UDim2.new(0, 180, 0, 50); mainButton.Position = UDim2.new(1, -200, 1, -70)
    local corner = Instance.new("UICorner", mainButton); corner.CornerRadius = UDim.new(0, 8)
    local resetButton = Instance.new("TextButton", screenGui); resetButton.Name = "ResetButton"; resetButton.Text = "Reset Memory"; resetButton.TextSize = 14; resetButton.Font = Enum.Font.SourceSansBold; resetButton.TextColor3 = Color3.fromRGB(255, 255, 255); resetButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40); resetButton.Size = UDim2.new(0, 100, 0, 30); resetButton.Position = UDim2.new(1, -310, 1, -60)
    local corner2 = Instance.new("UICorner", resetButton); corner2.CornerRadius = UDim.new(0, 6)

    local function UpdateButtonState_Isolated(statusText)
        if FarmState.isEnabled then
            mainButton.Text = "AutoFarm: " .. (statusText or "ON"); mainButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
        else
            mainButton.Text = "AutoFarm: OFF"; mainButton.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
        end
    end

    --================================================================================--
    --                         Main Thread Function
    --================================================================================--
    local function RunMasterLoop_Isolated()
        -- Define all functions INSIDE the new thread's scope
        local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local Backpack = LocalPlayer:WaitForChild("Backpack")
        local GameEvents = ReplicatedStorage:WaitForChild("GameEvents")
        local CraftingService = GameEvents:WaitForChild("CraftingGlobalObjectService")
        local PetEggService = GameEvents:WaitForChild("PetEggService")

        local function FindFarmByLocation_ThreadLocal()
            local rootPart = Character:WaitForChild("HumanoidRootPart")
            local farmsFolder = Workspace:WaitForChild("Farm")
            local closestFarm, minDistance = nil, math.huge
            for _, farmPlot in ipairs(farmsFolder:GetChildren()) do
                local centerPoint = farmPlot:FindFirstChild("Center_Point")
                if centerPoint then
                    if (rootPart.Position - centerPoint.Position).Magnitude < minDistance then
                        minDistance = (rootPart.Position - centerPoint.Position).Magnitude
                        closestFarm = farmPlot
                    end
                end
            end
            return closestFarm
        end

        local function PerformOneCraftCycle_ThreadLocal()
            -- Crafting logic...
            pcall(function()
                UpdateButtonState_Isolated("Crafting...")
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
        end

        -- The actual master loop
        while FarmState.isEnabled do
            UpdateButtonState_Isolated("Finding Farm")
            local myFarm = FindFarmByLocation_ThreadLocal()
            if not myFarm then warn("Could not find farm, retrying..."); task.wait(5); continue end
            local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
            if not objectsFolder then warn("Could not find Objects_Physical folder, retrying..."); task.wait(5); continue end
            
            -- HATCHING LOGIC
            UpdateButtonState_Isolated("Checking Eggs")
            local allEggs = {}; for _, obj in ipairs(objectsFolder:GetChildren()) do if obj:IsA("Model") and obj:GetAttribute("c") then table.insert(allEggs, obj) end end
            for _, egg in ipairs(allEggs) do if not FarmState.knownReadyEggs[egg:GetAttribute("c")] and egg:GetAttribute("READY") == true then FarmState.knownReadyEggs[egg:GetAttribute("c")] = true end end
            local readyCount, eggsToHatch = 0, {}
            for _, egg in ipairs(allEggs) do if FarmState.knownReadyEggs[egg:GetAttribute("c")] then readyCount = readyCount + 1; table.insert(eggsToHatch, egg) end end

            if #allEggs >= 8 and readyCount == #allEggs then
                UpdateButtonState_Isolated("Hatching " .. #eggsToHatch)
                for _, eggToHatch in ipairs(eggsToHatch) do
                    if not FarmState.isEnabled then break end
                    local uuid = eggToHatch:GetAttribute("c")
                    local prompt = eggToHatch:FindFirstChild("ProximityPrompt", true)
                    if prompt then fireproximityprompt(prompt); if uuid then FarmState.knownReadyEggs[uuid] = nil end; task.wait(0.2) end
                end
                task.wait(3); continue
            end
            
            -- PLACEMENT LOGIC
            allEggs = {}; for _, obj in ipairs(objectsFolder:GetChildren()) do if obj:IsA("Model") and obj:GetAttribute("c") then table.insert(allEggs, obj) end end
            if #allEggs < 4 then
                UpdateButtonState_Isolated("Placing Eggs")
                local function FindPlacementTool_ThreadLocal()
                    for _, item in ipairs(Character:GetChildren()) do if item:IsA("Tool") and item:GetAttribute(FarmState.PLACEMENT_ATTRIBUTE_NAME) == FarmState.PLACEMENT_ATTRIBUTE_VALUE then return item, "equipped" end end
                    for _, item in ipairs(Backpack:GetChildren()) do if item:IsA("Tool") and item:GetAttribute(FarmState.PLACEMENT_ATTRIBUTE_NAME) == FarmState.PLACEMENT_ATTRIBUTE_VALUE then return item, "backpack" end end
                    return nil, nil
                end
                local toolInstance, location = FindPlacementTool_ThreadLocal()
                if location then
                    if location == "backpack" then if Character:FindFirstChildOfClass("Humanoid") then Character.Humanoid:EquipTool(toolInstance); task.wait(0.5) end end
                    for i = 1, FarmState.PLACEMENT_COUNT do
                        if not FarmState.isEnabled then break end
                        local randomPosition, isValidPosition, attempts = nil, false, 0
                        repeat
                            local minX = math.min(FarmState.corner1.X, FarmState.corner2.X); local maxX = math.max(FarmState.corner1.X, FarmState.corner2.X)
                            local minZ = math.min(FarmState.corner1.Z, FarmState.corner2.Z); local maxZ = math.max(FarmState.corner1.Z, FarmState.corner2.Z)
                            randomPosition = Vector3.new(math.random() * (maxX - minX) + minX, FarmState.corner1.Y, math.random() * (maxZ - minZ) + minZ)
                            isValidPosition = true
                            for _, placedPos in ipairs(FarmState.placedPositions) do if (randomPosition - placedPos).Magnitude < FarmState.MINIMUM_DISTANCE then isValidPosition = false; break end end
                            attempts = attempts + 1
                        until isValidPosition or attempts >= 50
                        if isValidPosition then PetEggService:FireServer(unpack({ "CreateEgg", randomPosition })); table.insert(FarmState.placedPositions, randomPosition) end
                        task.wait(0.5)
                    end
                    task.wait(1); continue
                end
            end
            
            -- CRAFTING LOGIC
            PerformOneCraftCycle_ThreadLocal()
            task.wait(5) 
        end
    end

    --================================================================================--
    --                         Initialization & Connections
    --================================================================================--
    local function SaveConfig_Isolated()
        if typeof(writefile) ~= "function" then return end
        local uuidArrayToSave = {}
        for uuid, _ in pairs(FarmState.knownReadyEggs) do table.insert(uuidArrayToSave, uuid) end
        local configData = { enabled = FarmState.isEnabled, readyEggUUIDs = uuidArrayToSave }
        pcall(function() writefile(FarmState.CONFIG_FILE_NAME, HttpService:JSONEncode(configData)) end)
    end
    
    local function LoadConfig_Isolated()
        if typeof(readfile) ~= "function" then return end
        local s1, f1 = pcall(readfile, FarmState.CONFIG_FILE_NAME)
        if s1 and f1 then
            local s2, c2 = pcall(HttpService.JSONDecode, HttpService, f1)
            if s2 and typeof(c2) == "table" then
                FarmState.isEnabled = c2.enabled or false
                if c2.readyEggUUIDs then for _, u in ipairs(c2.readyEggUUIDs) do FarmState.knownReadyEggs[u] = true end end
            end
        end
    end

    mainButton.MouseButton1Click:Connect(function()
        FarmState.isEnabled = not FarmState.isEnabled
        UpdateButtonState_Isolated()
        if FarmState.isEnabled then
            SaveConfig_Isolated()
            FarmState.mainThread = task.spawn(RunMasterLoop_Isolated)
        else
            if FarmState.mainThread then task.cancel(FarmState.mainThread); FarmState.mainThread = nil end
            SaveConfig_Isolated()
        end
    end)
    
    resetButton.MouseButton1Click:Connect(function()
        FarmState.knownReadyEggs = {}
        SaveConfig_Isolated()
        if FarmState.isEnabled then
            FarmState.isEnabled = false
            if FarmState.mainThread then task.cancel(FarmState.mainThread); FarmState.mainThread = nil end
        end
        UpdateButtonState_Isolated()
    end)

    LoadConfig_Isolated()
    UpdateButtonState_Isolated()
    if FarmState.isEnabled then
        FarmState.mainThread = task.spawn(RunMasterLoop_Isolated)
    end

    print("Combined Auto-Farm & Crafter (Hyper-Isolated) loaded.")
end
