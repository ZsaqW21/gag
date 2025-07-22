-- Wait for the game to fully load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Isolate the entire script to prevent name conflicts
do
    -- Create a self-contained module to hold all functions and state
    local FarmModule = {}

    --================================================================================--
    --                         Services & Player Setup
    --================================================================================--
    FarmModule.HttpService = game:GetService("HttpService")
    FarmModule.Players = game:GetService("Players")
    FarmModule.ReplicatedStorage = game:GetService("ReplicatedStorage")
    FarmModule.TeleportService = game:GetService("TeleportService")
    FarmModule.Workspace = game:GetService("Workspace")

    FarmModule.LocalPlayer = FarmModule.Players.LocalPlayer
    FarmModule.PlayerGui = FarmModule.LocalPlayer:WaitForChild("PlayerGui")
    FarmModule.Backpack = FarmModule.LocalPlayer:WaitForChild("Backpack")
    FarmModule.Character = FarmModule.LocalPlayer.Character or FarmModule.LocalPlayer.CharacterAdded:Wait()

    FarmModule.GameEvents = FarmModule.ReplicatedStorage:WaitForChild("GameEvents")
    FarmModule.CraftingService = FarmModule.GameEvents:WaitForChild("CraftingGlobalObjectService")
    FarmModule.PetEggService = FarmModule.GameEvents:WaitForChild("PetEggService")

    --================================================================================--
    --                         Configuration & State
    --================================================================================--
    FarmModule.CONFIG_FILE_NAME = "CombinedAutoFarmConfig_v10_Final.json"
    FarmModule.isEnabled = false
    FarmModule.mainThread = nil
    FarmModule.knownReadyEggs = {}
    FarmModule.placedPositions = {}

    FarmModule.PLACEMENT_ATTRIBUTE_NAME = "h"
    FarmModule.PLACEMENT_ATTRIBUTE_VALUE = "Primal Egg"
    FarmModule.PLACEMENT_COUNT = 10
    FarmModule.MINIMUM_DISTANCE = 5
    FarmModule.corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344)
    FarmModule.corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)

    --================================================================================--
    --                         Configuration Save/Load
    --================================================================================--
    function FarmModule:SaveConfig()
        if typeof(writefile) ~= "function" then return end
        local uuidArrayToSave = {}
        for uuid, _ in pairs(self.knownReadyEggs) do table.insert(uuidArrayToSave, uuid) end
        local configData = { enabled = self.isEnabled, readyEggUUIDs = uuidArrayToSave }
        pcall(function() writefile(self.CONFIG_FILE_NAME, self.HttpService:JSONEncode(configData)) end)
    end

    function FarmModule:LoadConfig()
        if typeof(readfile) ~= "function" then return end
        local success, fileData = pcall(readfile, self.CONFIG_FILE_NAME)
        if success and fileData then
            local success2, configData = pcall(self.HttpService.JSONDecode, self.HttpService, fileData)
            if success2 and typeof(configData) == "table" then
                self.isEnabled = configData.enabled or false
                if configData.readyEggUUIDs and typeof(configData.readyEggUUIDs) == "table" then
                    for _, uuid in ipairs(configData.readyEggUUIDs) do self.knownReadyEggs[uuid] = true end
                end
            end
        end
    end

    --================================================================================--
    --                         Helper Functions
    --================================================================================--
    function FarmModule:FindFarmByLocation()
        local rootPart = self.Character:WaitForChild("HumanoidRootPart")
        local farmsFolder = self.Workspace:WaitForChild("Farm")
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

    function FarmModule:FindPlacementTool()
        for _, item in ipairs(self.Character:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(self.PLACEMENT_ATTRIBUTE_NAME) == self.PLACEMENT_ATTRIBUTE_VALUE then return item, "equipped" end
        end
        for _, item in ipairs(self.Backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(self.PLACEMENT_ATTRIBUTE_NAME) == self.PLACEMENT_ATTRIBUTE_VALUE then return item, "backpack" end
        end
        return nil, nil
    end

    function FarmModule:PlaceOneEgg()
        local randomPosition, isValidPosition, attempts = nil, false, 0
        repeat
            local minX = math.min(self.corner1.X, self.corner2.X); local maxX = math.max(self.corner1.X, self.corner2.X)
            local minZ = math.min(self.corner1.Z, self.corner2.Z); local maxZ = math.max(self.corner1.Z, self.corner2.Z)
            local randomX = math.random() * (maxX - minX) + minX
            local randomZ = math.random() * (maxZ - minZ) + minZ
            randomPosition = Vector3.new(randomX, self.corner1.Y, randomZ)
            isValidPosition = true
            for _, placedPos in ipairs(self.placedPositions) do
                if (randomPosition - placedPos).Magnitude < self.MINIMUM_DISTANCE then isValidPosition = false; break end
            end
            attempts = attempts + 1
        until isValidPosition or attempts >= 50
        if isValidPosition then
            self.PetEggService:FireServer(unpack({ "CreateEgg", randomPosition }))
            table.insert(self.placedPositions, randomPosition)
        end
    end

    --================================================================================--
    --                         GUI & Master Loop
    --================================================================================--
    local screenGui = Instance.new("ScreenGui", FarmModule.PlayerGui); screenGui.Name = "CombinedFarmCraftGui"; screenGui.ResetOnSpawn = false
    local mainButton = Instance.new("TextButton", screenGui); mainButton.Name = "ToggleButton"; mainButton.TextSize = 20; mainButton.Font = Enum.Font.SourceSansBold; mainButton.TextColor3 = Color3.fromRGB(255, 255, 255); mainButton.Size = UDim2.new(0, 180, 0, 50); mainButton.Position = UDim2.new(1, -200, 1, -70)
    local corner = Instance.new("UICorner", mainButton); corner.CornerRadius = UDim.new(0, 8)
    local resetButton = Instance.new("TextButton", screenGui); resetButton.Name = "ResetButton"; resetButton.Text = "Reset Memory"; resetButton.TextSize = 14; resetButton.Font = Enum.Font.SourceSansBold; resetButton.TextColor3 = Color3.fromRGB(255, 255, 255); resetButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40); resetButton.Size = UDim2.new(0, 100, 0, 30); resetButton.Position = UDim2.new(1, -310, 1, -60)
    local corner2 = Instance.new("UICorner", resetButton); corner2.CornerRadius = UDim.new(0, 6)

    function FarmModule:UpdateButtonState(statusText)
        if self.isEnabled then
            mainButton.Text = "AutoFarm: " .. (statusText or "ON"); mainButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
        else
            mainButton.Text = "AutoFarm: OFF"; mainButton.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
        end
    end

    function FarmModule:PerformOneCraftCycle()
        local success, err = pcall(function()
            self:UpdateButtonState("Crafting...")
            local DinoEvent = self.Workspace:FindFirstChild("DinoEvent") or self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
            if DinoEvent and DinoEvent:IsDescendantOf(self.ReplicatedStorage) then DinoEvent.Parent = self.Workspace end
            local DinoTable = self.Workspace:WaitForChild("DinoEvent"):WaitForChild("DinoCraftingTable")
            self.CraftingService:FireServer("SetRecipe", DinoTable, "DinoEventWorkbench", "Primal Egg")
            task.wait(0.3)
            for _, tool in ipairs(self.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("h") == "Dinosaur Egg" then
                    tool.Parent = self.Character; task.wait(0.3)
                    if tool:GetAttribute("c") then self.CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 1, { ItemType = "PetEgg", ItemData = { UUID = tool:GetAttribute("c") } }) end
                    tool.Parent = self.Backpack; break
                end
            end
            for _, tool in ipairs(self.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                    for _, t in ipairs(self.Character:GetChildren()) do if t:IsA("Tool") then t.Parent = self.Backpack end end
                    tool.Parent = self.Character; task.wait(0.3)
                    if tool:GetAttribute("c") then self.CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 2, { ItemType = "Holdable", ItemData = { UUID = tool:GetAttribute("c") } }) end
                    tool.Parent = self.Backpack; break
                end
            end
            task.wait(0.3)
            self.CraftingService:FireServer("Craft", DinoTable, "DinoEventWorkbench")
            task.wait(1)
            self.TeleportService:Teleport(game.PlaceId)
        end)
        if not success then warn("AutoCraft Error:", err, "-- Turning off."); self.isEnabled = false; self:UpdateButtonState(); self:SaveConfig() end
    end

    function FarmModule:RunMasterLoop()
        while self.isEnabled do
            self:UpdateButtonState("Finding Farm")
            local myFarm = self:FindFarmByLocation()
            if not myFarm then warn("Could not find farm, retrying..."); task.wait(5); continue end
            local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
            if not objectsFolder then warn("Could not find Objects_Physical folder, retrying..."); task.wait(5); continue end
            
            self:UpdateButtonState("Checking Eggs")
            
            -- CORRECTED LOGIC: Perform one clean, filtered scan at the start of the cycle.
            local allEggs = {}
            for _, obj in ipairs(objectsFolder:GetChildren()) do
                if obj:IsA("Model") and obj:GetAttribute("c") then table.insert(allEggs, obj) end
            end

            for _, egg in ipairs(allEggs) do
                if not self.knownReadyEggs[egg:GetAttribute("c")] and egg:GetAttribute("READY") == true then self.knownReadyEggs[egg:GetAttribute("c")] = true end
            end

            local readyCount, eggsToHatch = 0, {}
            for _, egg in ipairs(allEggs) do
                if self.knownReadyEggs[egg:GetAttribute("c")] then readyCount = readyCount + 1; table.insert(eggsToHatch, egg) end
            end
            
            print("--- Farm Status Update ---\nTotal Valid Eggs Found: " .. #allEggs .. "\nReady Eggs (from memory): " .. readyCount .. "\n--------------------------")
            
            -- PRIORITY 1: HATCHING
            if #allEggs >= 8 and readyCount == #allEggs then
                self:UpdateButtonState("Hatching " .. #eggsToHatch)
                for _, eggToHatch in ipairs(eggsToHatch) do
                    if not self.isEnabled then break end
                    local uuid = eggToHatch:GetAttribute("c")
                    local prompt = eggToHatch:FindFirstChild("ProximityPrompt", true)
                    if prompt then fireproximityprompt(prompt); if uuid then self.knownReadyEggs[uuid] = nil end; task.wait(0.2) end
                end
                task.wait(3); self:SaveConfig(); continue
            end
            
            -- PRIORITY 2: PLACEMENT
            if #allEggs < 4 then
                self:UpdateButtonState("Placing Eggs")
                local toolInstance, location = self:FindPlacementTool()
                if location then
                    if location == "backpack" then
                        local humanoid = self.Character:WaitForChild("Humanoid")
                        if humanoid then humanoid:EquipTool(toolInstance); task.wait(0.5) end
                    end
                    for i = 1, self.PLACEMENT_COUNT do
                        if not self.isEnabled then break end
                        self:PlaceOneEgg(); task.wait(0.5)
                    end
                    task.wait(1); self:SaveConfig(); continue
                else
                    warn("Cannot place eggs: Primal Egg tool not found.")
                end
            end
            
            -- PRIORITY 3: CRAFTING
            self:SaveConfig()
            self:PerformOneCraftCycle()
            task.wait(5) 
        end
        self:SaveConfig()
        self:UpdateButtonState()
    end

    function FarmModule:Toggle()
        self.isEnabled = not self.isEnabled
        self:UpdateButtonState()
        if self.isEnabled then self:SaveConfig(); self.mainThread = task.spawn(function() self:RunMasterLoop() end)
        else
            if self.mainThread then task.cancel(self.mainThread); self.mainThread = nil end
            self:SaveConfig()
        end
    end
    
    function FarmModule:ResetMemory()
        print("Resetting saved egg memory...")
        self.knownReadyEggs = {}
        self:SaveConfig()
        print("✅ Memory cleared. Please toggle the main button OFF and then ON to restart the cycle.")
        if self.isEnabled then
            self.isEnabled = false
            if self.mainThread then task.cancel(self.mainThread); self.mainThread = nil end
            self:UpdateButtonState()
        end
    end
    
    mainButton.MouseButton1Click:Connect(function() FarmModule:Toggle() end)
    resetButton.MouseButton1Click:Connect(function() FarmModule:ResetMemory() end)

    FarmModule:LoadConfig()
    FarmModule:UpdateButtonState()
    if FarmModule.isEnabled then
        FarmModule.mainThread = task.spawn(function() FarmModule:RunMasterLoop() end)
    end

    print("Combined Auto-Farm & Crafter (Final Logic) loaded.")
end
