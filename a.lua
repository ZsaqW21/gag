-- Wait for the game to fully load
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Isolate the entire script to prevent name conflicts
do
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
    FarmModule.CONFIG_FILE_NAME = "CombinedAutoFarmConfig_v15_CraftFix.json"
    FarmModule.isEnabled = false
    FarmModule.mainThread = nil
    FarmModule.placedPositions = {}
    FarmModule.EGG_UUID_ATTRIBUTE = "OBJECT_UUID"
    FarmModule.PLACEMENT_ATTRIBUTE_NAME = "h"
    FarmModule.PLACEMENT_ATTRIBUTE_VALUE = "Primal Egg"
    FarmModule.PLACEMENT_COUNT = 10
    FarmModule.MINIMUM_DISTANCE = 5
    FarmModule.corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344)
    FarmModule.corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)
    
    function FarmModule:SaveConfig()
        if typeof(writefile) ~= "function" then return end
        pcall(function() writefile(self.CONFIG_FILE_NAME, self.HttpService:JSONEncode({ enabled = self.isEnabled })) end)
    end
    function FarmModule:LoadConfig()
        if typeof(readfile) ~= "function" then return end
        local s, f = pcall(readfile, self.CONFIG_FILE_NAME)
        if s and f then
            local s2, c = pcall(self.HttpService.JSONDecode, self.HttpService, f)
            if s2 and typeof(c) == "table" then self.isEnabled = c.enabled or false end
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
                local d = (rootPart.Position - centerPoint.Position).Magnitude
                if d < minDistance then minDistance = d; closestFarm = farmPlot end
            end
        end
        return closestFarm
    end

    function FarmModule:FindPlacementTool()
        for _, item in ipairs(self.Backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(self.PLACEMENT_ATTRIBUTE_NAME) == self.PLACEMENT_ATTRIBUTE_VALUE then return item end
        end
        return nil
    end

    function FarmModule:PlaceOneEgg()
        local r, iv, a = nil, false, 0
        repeat
            local minX = math.min(self.corner1.X, self.corner2.X); local maxX = math.max(self.corner1.X, self.corner2.X)
            local minZ = math.min(self.corner1.Z, self.corner2.Z); local maxZ = math.max(self.corner1.Z, self.corner2.Z)
            r = Vector3.new(math.random() * (maxX - minX) + minX, self.corner1.Y, math.random() * (maxZ - minZ) + minZ)
            iv = true
            for _, p in ipairs(self.placedPositions) do if (r - p).Magnitude < self.MINIMUM_DISTANCE then iv = false; break end end
            a = a + 1
        until iv or a >= 50
        if iv then self.PetEggService:FireServer("CreateEgg", r); table.insert(self.placedPositions, r) end
    end
    
    function FarmModule:HatchOneEgg(eggModel)
        local prompt = eggModel:FindFirstChild("ProximityPrompt", true)
        if not prompt then return end
        local originalDistance = prompt.MaxActivationDistance
        local originalLineOfSight = prompt.RequiresLineOfSight
        prompt.MaxActivationDistance = math.huge
        prompt.RequiresLineOfSight = false
        fireproximityprompt(prompt)
        prompt.MaxActivationDistance = originalDistance
        prompt.RequiresLineOfSight = originalLineOfSight
    end

    --================================================================================--
    --                         GUI & Master Loop
    --================================================================================--
    local screenGui = Instance.new("ScreenGui", FarmModule.PlayerGui); screenGui.Name = "CombinedFarmCraftGui"; screenGui.ResetOnSpawn = false
    local mainButton = Instance.new("TextButton", screenGui); mainButton.Name = "ToggleButton"; mainButton.TextSize = 20; mainButton.Font = Enum.Font.SourceSansBold; mainButton.TextColor3 = Color3.fromRGB(255, 255, 255); mainButton.Size = UDim2.new(0, 180, 0, 50); mainButton.Position = UDim2.new(1, -200, 1, -70)
    local corner = Instance.new("UICorner", mainButton); corner.CornerRadius = UDim.new(0, 8)
    local resetButton = Instance.new("TextButton", screenGui); resetButton.Name = "ResetButton"; resetButton.Text = "Reset Config"; resetButton.TextSize = 14; resetButton.Font = Enum.Font.SourceSansBold; resetButton.TextColor3 = Color3.fromRGB(255, 255, 255); resetButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40); resetButton.Size = UDim2.new(0, 100, 0, 30); resetButton.Position = UDim2.new(1, -310, 1, -60)
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
            
            -- CORRECTED LOGIC: Find the DinoEvent folder and move it to the workspace if it's not there.
            local DinoEvent = self.Workspace:FindFirstChild("DinoEvent")
            if not DinoEvent then
                DinoEvent = self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
                if DinoEvent then
                    DinoEvent.Parent = self.Workspace
                end
            end
            
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
            task.wait(0.3); self.CraftingService:FireServer("Craft", DinoTable, "DinoEventWorkbench"); task.wait(1); self.TeleportService:Teleport(game.PlaceId)
        end)
        if not success then warn("AutoCraft Error:", err, "-- Turning off."); self.isEnabled = false; self:UpdateButtonState(); self:SaveConfig() end
    end

    function FarmModule:RunMasterLoop()
        while self.isEnabled do
            self:UpdateButtonState("Finding Farm")
            local myFarm = self:FindFarmByLocation()
            if not myFarm then task.wait(5); continue end
            local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
            if not objectsFolder then task.wait(5); continue end
            
            self:UpdateButtonState("Checking Eggs")
            local allEggs = {}; for _, obj in ipairs(objectsFolder:GetChildren()) do if obj:IsA("Model") and obj:GetAttribute(self.EGG_UUID_ATTRIBUTE) then table.insert(allEggs, obj) end end
            local readyCount = 0; for _, egg in ipairs(allEggs) do if egg:GetAttribute("TimeToHatch") == 0 then readyCount = readyCount + 1 end end
            
            -- PRIORITY 1: HATCHING
            if #allEggs >= 8 and readyCount == #allEggs then
                self:UpdateButtonState("Hatching " .. readyCount)
                for _, eggToHatch in ipairs(allEggs) do
                    if not self.isEnabled then break end
                    self:HatchOneEgg(eggToHatch); task.wait(0.2)
                end
                task.wait(3); continue
            end
            
            -- PRIORITY 2: PLACEMENT
            if #allEggs < 4 then
                self:UpdateButtonState("Preparing to Place")
                local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:UnequipTools(); task.wait(0.2)
                    local toolInstance = self:FindPlacementTool()
                    if toolInstance then
                        humanoid:EquipTool(toolInstance); task.wait(0.5)
                        self:UpdateButtonState("Placing Eggs")
                        self.placedPositions = {}
                        for i = 1, self.PLACEMENT_COUNT do
                            if not self.isEnabled then break end
                            self:PlaceOneEgg(); task.wait(0.5)
                        end
                        task.wait(1); continue
                    else
                        warn("Cannot place eggs: Primal Egg tool not found.")
                    end
                end
            end
            
            -- PRIORITY 3: CRAFTING
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
    
    function FarmModule:ResetConfig()
        print("Resetting config file...")
        pcall(function() writefile(self.CONFIG_FILE_NAME, self.HttpService:JSONEncode({})) end)
        print("✅ Config cleared. Please toggle the main button OFF and then ON again.")
        if self.isEnabled then
            self.isEnabled = false
            if self.mainThread then task.cancel(self.mainThread); self.mainThread = nil end
            self:UpdateButtonState()
        end
    end
    
    mainButton.MouseButton1Click:Connect(function() FarmModule:Toggle() end)
    resetButton.MouseButton1Click:Connect(function() FarmModule:ResetConfig() end)

    FarmModule:LoadConfig()
    FarmModule:UpdateButtonState()
    if FarmModule.isEnabled then
        FarmModule.mainThread = task.spawn(function() FarmModule:RunMasterLoop() end)
    end

    print("Combined Auto-Farm & Crafter (Crafting Fix) loaded.")
end
