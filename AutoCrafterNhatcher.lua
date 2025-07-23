-- Wait for the game to fully load
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(1) -- Add a small extra delay for safety

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
    FarmModule.SellPetRemote = FarmModule.GameEvents:WaitForChild("SellPet_RE")

    --================================================================================--
    --                         Configuration & State
    --================================================================================--
    FarmModule.CONFIG_FILE_NAME = "CombinedFarmAndSeller_v14_WithHarvest.json"
    FarmModule.isEnabled = false
    FarmModule.mainThread = nil
    FarmModule.placedPositions = {}
    FarmModule.needsEggCheck = true
    FarmModule.config = {
        maxWeightToSell = 4,
        targetEggCount = 3,
        sellablePets = {
            ["Parasaurolophus"] = false, ["Iguanodon"] = false, ["Pachycephalosaurus"] = false, ["Dilophosaurus"] = false, ["Ankylosaurus"] = false,
            ["Raptor"] = false, ["Triceratops"] = false, ["Stegosaurus"] = false, ["Pterodactyl"] = false,
            ["Shiba Inu"] = false, ["Nihonzaru"] = false, ["Tanuki"] = false, ["Tanchozuru"] = false, ["Kappa"] = false,
            ["Ostrich"] = false, ["Peacock"] = false, ["Capybara"] = false, ["Scarlet Macaw"] = false,
            ["Caterpillar"] = false, ["Snail"] = false, ["Giant Ant"] = false, ["Praying Mantis"] = false,
            ["Grey Mouse"] = false, ["Brown Mouse"] = false, ["Squirrel"] = false, ["Red Giant Ant"] = false,
        },
        placementPriority = {
            "Primal Egg", "Dinosaur Egg", "Zen Egg", "Paradise Egg", "Bug Egg", "Mythical Egg"
        }
    }
    
    FarmModule.petCategories = {
        ["Primal Egg Pets"] = {"Parasaurolophus", "Iguanodon", "Pachycephalosaurus", "Dilophosaurus", "Ankylosaurus"},
        ["Dinosaur Egg Pets"] = {"Raptor", "Triceratops", "Stegosaurus", "Pterodactyl"},
        ["Zen Egg Pets"] = {"Shiba Inu", "Nihonzaru", "Tanuki", "Tanchozuru", "Kappa"},
        ["Paradise Egg Pets"] = {"Ostrich", "Peacock", "Capybara", "Scarlet Macaw"},
        ["Bug Egg Pets"] = {"Caterpillar", "Snail", "Giant Ant", "Praying Mantis"},
        ["Mythical Egg Pets"] = {"Grey Mouse", "Brown Mouse", "Squirrel", "Red Giant Ant"}
    }

    FarmModule.EGG_UUID_ATTRIBUTE = "OBJECT_UUID"
    FarmModule.PLACEMENT_ATTRIBUTE_NAME = "h"
    FarmModule.MINIMUM_DISTANCE = 5
    FarmModule.corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344)
    FarmModule.corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)

    --================================================================================--
    --                         Configuration Save/Load
    --================================================================================--
    function FarmModule:SaveConfig()
        if typeof(writefile) ~= "function" then return end
        local configToSave = {
            enabled = self.isEnabled,
            maxWeightToSell = self.config.maxWeightToSell,
            sellablePets = self.config.sellablePets,
            placementPriority = self.config.placementPriority,
            targetEggCount = self.config.targetEggCount
        }
        pcall(function() writefile(self.CONFIG_FILE_NAME, self.HttpService:JSONEncode(configToSave)) end)
    end

    function FarmModule:LoadConfig()
        if typeof(readfile) ~= "function" then return end
        local success, fileData = pcall(readfile, self.CONFIG_FILE_NAME)
        if success and fileData then
            local success2, decodedData = pcall(self.HttpService.JSONDecode, self.HttpService, fileData)
            if success2 and typeof(decodedData) == "table" then
                self.isEnabled = decodedData.enabled or false
                self.config.maxWeightToSell = decodedData.maxWeightToSell or self.config.maxWeightToSell
                self.config.targetEggCount = decodedData.targetEggCount or self.config.targetEggCount
                if typeof(decodedData.sellablePets) == "table" then
                    for petName, _ in pairs(self.config.sellablePets) do
                        if decodedData.sellablePets[petName] ~= nil then
                            self.config.sellablePets[petName] = decodedData.sellablePets[petName]
                        end
                    end
                end
                if typeof(decodedData.placementPriority) == "table" then
                    self.config.placementPriority = decodedData.placementPriority
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
                local d = (rootPart.Position - centerPoint.Position).Magnitude
                if d < minDistance then minDistance = d; closestFarm = farmPlot end
            end
        end
        return closestFarm
    end

    function FarmModule:FindPlacementTool()
        for _, eggName in ipairs(self.config.placementPriority) do
            for _, item in ipairs(self.Backpack:GetChildren()) do
                if item:IsA("Tool") and item:GetAttribute(self.PLACEMENT_ATTRIBUTE_NAME) == eggName then
                    print("Found priority egg to place: " .. eggName)
                    return item
                end
            end
        end
        warn("Could not find any of the prioritized placement eggs in the backpack.")
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
        until iv or a >= 100
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
    local screenGui, mainButton, resetButton, PetSettingsButton

    function FarmModule:UpdateButtonState(statusText)
        if mainButton then
            if self.isEnabled then
                mainButton.Text = "AutoFarm: " .. (statusText or "ON"); mainButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
            else
                mainButton.Text = "AutoFarm: OFF"; mainButton.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
            end
        end
    end
    
    function FarmModule:UpdateGUIVisibility()
        if PetSettingsButton then
            PetSettingsButton.Visible = not self.isEnabled
        end
    end

    function FarmModule:RunAutoSeller()
        self:UpdateButtonState("Selling Pets")
        local totalPetsSold = 0
        while true do
            local petSoldThisPass = false
            for _, item in ipairs(self.Backpack:GetChildren()) do
                if item:IsA("Tool") then
                    for petName, shouldSell in pairs(self.config.sellablePets) do
                        if shouldSell and item.Name:find(petName, 1, true) then
                            local weightString = item.Name:match("%[(%d+%.?%d*)%s*KG%]")
                            if weightString then
                                local weight = tonumber(weightString)
                                if weight < self.config.maxWeightToSell then
                                    local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
                                    if humanoid then
                                        humanoid:EquipTool(item)
                                        task.wait(0.5)
                                        if item.Parent == self.Character then
                                            self.SellPetRemote:FireServer(item)
                                            totalPetsSold = totalPetsSold + 1
                                            petSoldThisPass = true
                                            task.wait(1)
                                            break
                                        else
                                            if item.Parent ~= self.Backpack then item.Parent = self.Backpack end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if petSoldThisPass then break end
            end
            if not petSoldThisPass then break end
        end
        print("Auto-sell finished. Sold " .. totalPetsSold .. " pet(s).")
    end

    -- NEW: Auto-Harvesting Functions
    local function CountBoneBlossoms()
        local count = 0
        for _, tool in ipairs(FarmModule.Backpack:GetChildren()) do
            if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                count = count + 1
            end
        end
        return count
    end

    local function RunAutoHarvester(plantsFolder)
        local function scanAndHarvest(folder)
            for _, item in ipairs(folder:GetChildren()) do
                local prompt = item:FindFirstChild("ProximityPrompt", true)
                if prompt and prompt.Enabled then
                    fireproximityprompt(prompt)
                    task.wait(0.1)
                end
                local fruitsFolder = item:FindFirstChild("Fruits")
                if fruitsFolder then
                    scanAndHarvest(fruitsFolder)
                end
            end
        end
        scanAndHarvest(plantsFolder)
    end

    function FarmModule:PerformOneCraftCycle()
        local success, err = pcall(function()
            self:UpdateButtonState("Crafting...")
            
            local DinoEvent = self.Workspace:FindFirstChild("DinoEvent") or self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
            if DinoEvent and DinoEvent:IsDescendantOf(self.ReplicatedStorage) then DinoEvent.Parent = self.Workspace end
            
            local DinoTable = self.Workspace:WaitForChild("DinoEvent", 5):WaitForChild("DinoCraftingTable", 5)
            if not DinoTable then error("Could not find DinoCraftingTable. Aborting craft cycle.") end

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
            if self.needsEggCheck then
                self:UpdateButtonState("Finding Farm")
                local myFarm = self:FindFarmByLocation()
                if not myFarm then task.wait(5); continue end
                local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
                local plantsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Plants_Physical")
                if not objectsFolder or not plantsFolder then task.wait(5); continue end
                
                self:UpdateButtonState("Checking Eggs")
                local allEggs = {}; for _, obj in ipairs(objectsFolder:GetChildren()) do if obj:IsA("Model") and obj:GetAttribute(self.EGG_UUID_ATTRIBUTE) then table.insert(allEggs, obj) end end
                local readyCount = 0; for _, egg in ipairs(allEggs) do if egg:GetAttribute("TimeToHatch") == 0 then readyCount = readyCount + 1 end end
                
                if #allEggs >= 8 and readyCount == #allEggs then
                    self:UpdateButtonState("Hatching " .. readyCount)
                    for _, eggToHatch in ipairs(allEggs) do
                        if not self.isEnabled then break end
                        self:HatchOneEgg(eggToHatch); task.wait(0.2)
                    end
                    task.wait(3); continue
                end
                
                if #allEggs < self.config.targetEggCount then
                    self:UpdateButtonState("Placing Eggs")
                    local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:UnequipTools(); task.wait(0.2)
                        local toolInstance = self:FindPlacementTool()
                        if toolInstance then
                            humanoid:EquipTool(toolInstance); task.wait(0.5)
                            self.placedPositions = {}
                            local eggsToPlace = self.config.targetEggCount - #allEggs
                            for i = 1, eggsToPlace do
                                if not self.isEnabled then break end
                                self:PlaceOneEgg(); task.wait(0.5)
                            end
                            task.wait(1)
                            self:RunAutoSeller()
                            
                            -- NEW: Harvest loop
                            while CountBoneBlossoms() < 100 and self.isEnabled do
                                self:UpdateButtonState("Harvesting (" .. CountBoneBlossoms() .. "/100)")
                                RunAutoHarvester(plantsFolder)
                                task.wait(5) -- Wait between harvest scans
                            end

                            continue
                        end
                    end
                end

                if #allEggs > 0 and readyCount < #allEggs then
                    print("Eggs are not ready. Entering fast crafting loop.")
                    self.needsEggCheck = false
                end
            end
            
            self:PerformOneCraftCycle()
            task.wait(3)
        end
        self:SaveConfig()
        self:UpdateButtonState()
    end

    function FarmModule:CreateGUI()
        if self.PlayerGui:FindFirstChild("CombinedFarmCraftGui") then
            self.PlayerGui.CombinedFarmCraftGui:Destroy()
        end
        
        screenGui = Instance.new("ScreenGui", self.PlayerGui); screenGui.Name = "CombinedFarmCraftGui"; screenGui.ResetOnSpawn = false
        mainButton = Instance.new("TextButton", screenGui); mainButton.Name = "ToggleButton"; mainButton.TextSize = 20; mainButton.Font = Enum.Font.SourceSansBold; mainButton.TextColor3 = Color3.fromRGB(255, 255, 255); mainButton.Size = UDim2.new(0, 180, 0, 50); mainButton.Position = UDim2.new(1, -200, 0, 10)
        local corner = Instance.new("UICorner", mainButton); corner.CornerRadius = UDim.new(0, 8)
        resetButton = Instance.new("TextButton", screenGui); resetButton.Name = "ResetButton"; resetButton.Text = "Reset Config"; resetButton.TextSize = 14; resetButton.Font = Enum.Font.SourceSansBold; resetButton.TextColor3 = Color3.fromRGB(255, 255, 255); resetButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40); resetButton.Size = UDim2.new(0, 100, 0, 30); resetButton.Position = UDim2.new(1, -310, 0, 20)
        local corner2 = Instance.new("UICorner", resetButton); corner2.CornerRadius = UDim.new(0, 6)
        
        PetSettingsButton = Instance.new("TextButton", screenGui)
        PetSettingsButton.Name = "PetSettingsButton"; PetSettingsButton.Text = "Pet Sell Settings"; PetSettingsButton.TextSize = 14; PetSettingsButton.Font = Enum.Font.SourceSansBold; PetSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255); PetSettingsButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); PetSettingsButton.Size = UDim2.new(0, 120, 0, 40); PetSettingsButton.Position = UDim2.new(1, -440, 0, 15)
        local corner_pet = Instance.new("UICorner", PetSettingsButton); corner_pet.CornerRadius = UDim.new(0, 6)
        
        local SettingsFrame = Instance.new("Frame", screenGui)
        SettingsFrame.Size = UDim2.new(0, 220, 0, 220); SettingsFrame.Position = UDim2.new(0.5, -110, 0.5, -110)
        SettingsFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); SettingsFrame.BorderColor3 = Color3.fromRGB(150, 150, 150); SettingsFrame.BorderSizePixel = 2
        SettingsFrame.Visible = false
        local corner_settings = Instance.new("UICorner", SettingsFrame); corner_settings.CornerRadius = UDim.new(0, 8)

        local SettingsTitle = Instance.new("TextLabel", SettingsFrame)
        SettingsTitle.Size = UDim2.new(1, 0, 0, 30); SettingsTitle.Text = "Main Settings"
        SettingsTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255); SettingsTitle.Font = Enum.Font.SourceSansBold; SettingsTitle.TextSize = 16

        local listLayout = Instance.new("UIListLayout", SettingsFrame); listLayout.Padding = UDim.new(0, 10); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local MaxWeightLabel = Instance.new("TextLabel", SettingsFrame); MaxWeightLabel.Size = UDim2.new(0.9, 0, 0, 20); MaxWeightLabel.Text = "Sell pets UNDER this KG:"; MaxWeightLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55); MaxWeightLabel.TextColor3 = Color3.fromRGB(220, 220, 220); MaxWeightLabel.Font = Enum.Font.SourceSans; MaxWeightLabel.TextSize = 14; MaxWeightLabel.LayoutOrder = 1; MaxWeightLabel.TextXAlignment = Enum.TextXAlignment.Left
        local MaxWeightInput = Instance.new("TextBox", SettingsFrame); MaxWeightInput.Size = UDim2.new(0.9, 0, 0, 30); MaxWeightInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40); MaxWeightInput.TextColor3 = Color3.fromRGB(255, 255, 255); MaxWeightInput.Font = Enum.Font.SourceSansBold; MaxWeightInput.TextSize = 14; MaxWeightInput.Text = tostring(self.config.maxWeightToSell); MaxWeightInput.LayoutOrder = 2
        
        local SelectPetsButton = Instance.new("TextButton", SettingsFrame); SelectPetsButton.Size = UDim2.new(0.9, 0, 0, 35); SelectPetsButton.BackgroundColor3 = Color3.fromRGB(70, 90, 180); SelectPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255); SelectPetsButton.Font = Enum.Font.SourceSansBold; SelectPetsButton.Text = "Select Pets to Sell"; SelectPetsButton.TextSize = 16; SelectPetsButton.LayoutOrder = 3
        local corner4 = Instance.new("UICorner", SelectPetsButton); corner4.CornerRadius = UDim.new(0, 6)

        local EggSettingsButton = Instance.new("TextButton", SettingsFrame); EggSettingsButton.Size = UDim2.new(0.9, 0, 0, 35); EggSettingsButton.BackgroundColor3 = Color3.fromRGB(70, 90, 180); EggSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255); EggSettingsButton.Font = Enum.Font.SourceSansBold; EggSettingsButton.Text = "Egg Placement Priority"; EggSettingsButton.TextSize = 16; EggSettingsButton.LayoutOrder = 4
        local corner_egg = Instance.new("UICorner", EggSettingsButton); corner_egg.CornerRadius = UDim.new(0, 6)

        local SaveButton = Instance.new("TextButton", SettingsFrame); SaveButton.Size = UDim2.new(0.9, 0, 0, 35); SaveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); SaveButton.TextColor3 = Color3.fromRGB(255, 255, 255); SaveButton.Font = Enum.Font.SourceSansBold; SaveButton.Text = "Save & Close"; SaveButton.TextSize = 16; SaveButton.LayoutOrder = 5
        local corner_save = Instance.new("UICorner", SaveButton); corner_save.CornerRadius = UDim.new(0, 6)

        local PetCategoryMenu = Instance.new("Frame", screenGui); PetCategoryMenu.Size = UDim2.new(0, 200, 0, 250); PetCategoryMenu.Position = UDim2.new(0.5, -100, 0.5, -125); PetCategoryMenu.BackgroundColor3 = Color3.fromRGB(55, 55, 55); PetCategoryMenu.BorderColor3 = Color3.fromRGB(150, 150, 150); PetCategoryMenu.BorderSizePixel = 2; PetCategoryMenu.Visible = false
        local PetCategoryTitle = Instance.new("TextLabel", PetCategoryMenu); PetCategoryTitle.Size = UDim2.new(1, 0, 0, 30); PetCategoryTitle.Text = "Pet Categories"; PetCategoryTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); PetCategoryTitle.TextColor3 = Color3.fromRGB(255, 255, 255); PetCategoryTitle.Font = Enum.Font.SourceSansBold; PetCategoryTitle.TextSize = 16
        local PetCategoryScroll = Instance.new("ScrollingFrame", PetCategoryMenu); PetCategoryScroll.Size = UDim2.new(1, 0, 1, -75); PetCategoryScroll.Position = UDim2.new(0, 0, 0, 30); PetCategoryScroll.BackgroundColor3 = Color3.fromRGB(55, 55, 55); PetCategoryScroll.BorderSizePixel = 0; PetCategoryScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120); PetCategoryScroll.ScrollBarThickness = 6
        local PetCategoryLayout = Instance.new("UIListLayout", PetCategoryScroll); PetCategoryLayout.Padding = UDim.new(0, 5); PetCategoryLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local subMenus = {}
        for categoryName, petList in pairs(FarmModule.petCategories) do
            local frame = Instance.new("Frame", screenGui); frame.Size = UDim2.new(0, 200, 0, 250); frame.Position = UDim2.new(0.5, -100, 0.5, -125); frame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); frame.BorderColor3 = Color3.fromRGB(150, 150, 150); frame.BorderSizePixel = 2; frame.Visible = false
            local title = Instance.new("TextLabel", frame); title.Size = UDim2.new(1, 0, 0, 30); title.Text = categoryName; title.BackgroundColor3 = Color3.fromRGB(70, 70, 70); title.TextColor3 = Color3.fromRGB(255, 255, 255); title.Font = Enum.Font.SourceSansBold; title.TextSize = 16
            local scroll = Instance.new("ScrollingFrame", frame); scroll.Size = UDim2.new(1, 0, 1, -75); scroll.Position = UDim2.new(0, 0, 0, 30); scroll.BackgroundColor3 = Color3.fromRGB(55, 55, 55); scroll.BorderSizePixel = 0; scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120); scroll.ScrollBarThickness = 6
            local layout = Instance.new("UIListLayout", scroll); layout.Padding = UDim.new(0, 5); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            local contentH = 5
            for _, petName in ipairs(petList) do
                local btn = Instance.new("TextButton", scroll); btn.Size = UDim2.new(0.9, 0, 0, 28); btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 14
                local function update() if config.sellablePets[petName] then btn.Text = petName .. ": ON"; btn.BackgroundColor3 = Color3.fromRGB(20, 140, 70) else btn.Text = petName .. ": OFF"; btn.BackgroundColor3 = Color3.fromRGB(190, 40, 40) end end
                btn.MouseButton1Click:Connect(function() config.sellablePets[petName] = not config.sellablePets[petName]; update() end)
                update(); contentH = contentH + 33
            end
            scroll.CanvasSize = UDim2.new(0, 0, 0, contentH)
            local backBtn = Instance.new("TextButton", frame); backBtn.Size = UDim2.new(0.9, 0, 0, 35); backBtn.Position = UDim2.new(0.05, 0, 1, -40); backBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100); backBtn.TextColor3 = Color3.fromRGB(255, 255, 255); backBtn.Font = Enum.Font.SourceSansBold; backBtn.Text = "Back"; backBtn.TextSize = 16
            backBtn.MouseButton1Click:Connect(function() frame.Visible = false; PetCategoryMenu.Visible = true end)
            subMenus[categoryName] = frame
        end
        
        for categoryName, _ in pairs(FarmModule.petCategories) do
            local catButton = Instance.new("TextButton", PetCategoryScroll)
            catButton.Size = UDim2.new(0.9, 0, 0, 30); catButton.Text = categoryName; catButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            catButton.MouseButton1Click:Connect(function() PetCategoryMenu.Visible = false; subMenus[categoryName].Visible = true end)
        end
        local catBackBtn = Instance.new("TextButton", PetCategoryMenu); catBackBtn.Size = UDim2.new(0.9, 0, 0, 35); catBackBtn.Position = UDim2.new(0.05, 0, 1, -40); catBackBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100); catBackBtn.TextColor3 = Color3.fromRGB(255, 255, 255); catBackBtn.Font = Enum.Font.SourceSansBold; catBackBtn.Text = "Back"; catBackBtn.TextSize = 16
        catBackBtn.MouseButton1Click:Connect(function() PetCategoryMenu.Visible = false; SettingsFrame.Visible = true end)

        local EggFrame = Instance.new("Frame", screenGui); EggFrame.Size = UDim2.new(0, 220, 0, 320); EggFrame.Position = UDim2.new(0.5, -110, 0.5, -160); EggFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); EggFrame.BorderColor3 = Color3.fromRGB(150, 150, 150); EggFrame.BorderSizePixel = 2; EggFrame.Visible = false
        local EggTitle = Instance.new("TextLabel", EggFrame); EggTitle.Size = UDim2.new(1, 0, 0, 30); EggTitle.Text = "Egg Placement Priority"; EggTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); EggTitle.TextColor3 = Color3.fromRGB(255, 255, 255); EggTitle.Font = Enum.Font.SourceSansBold; EggTitle.TextSize = 16
        
        local TargetCountLabel = Instance.new("TextLabel", EggFrame); TargetCountLabel.Size = UDim2.new(0.9, 0, 0, 20); TargetCountLabel.Position = UDim2.new(0.05, 0, 0, 35); TargetCountLabel.Text = "Target Egg Count:"; TargetCountLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55); TargetCountLabel.TextColor3 = Color3.fromRGB(220, 220, 220); TargetCountLabel.Font = Enum.Font.SourceSans; TargetCountLabel.TextSize = 14; TargetCountLabel.TextXAlignment = Enum.TextXAlignment.Left
        local TargetCountInput = Instance.new("TextBox", EggFrame); TargetCountInput.Size = UDim2.new(0.9, 0, 0, 30); TargetCountInput.Position = UDim2.new(0.05, 0, 0, 55); TargetCountInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40); TargetCountInput.TextColor3 = Color3.fromRGB(255, 255, 255); TargetCountInput.Font = Enum.Font.SourceSansBold; TargetCountInput.TextSize = 14; TargetCountInput.Text = tostring(config.targetEggCount);
        
        local EggListScroll = Instance.new("ScrollingFrame", EggFrame); EggListScroll.Size = UDim2.new(1, 0, 1, -130); EggListScroll.Position = UDim2.new(0, 0, 0, 90); EggListScroll.BackgroundColor3 = Color3.fromRGB(55, 55, 55); EggListScroll.BorderSizePixel = 0; EggListScroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 120); EggListScroll.ScrollBarThickness = 6
        local eggListLayout = Instance.new("UIListLayout", EggListScroll); eggListLayout.Padding = UDim.new(0, 5); eggListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        
        local function redrawEggPriorityList()
            for _, v in ipairs(EggListScroll:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
            local eggContentHeight = 5
            for i, eggName in ipairs(config.placementPriority) do
                local itemFrame = Instance.new("Frame", EggListScroll); itemFrame.Size = UDim2.new(0.9, 0, 0, 30); itemFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                local eggLabel = Instance.new("TextLabel", itemFrame); eggLabel.Size = UDim2.new(1, -60, 1, 0); eggLabel.Text = i .. ". " .. eggName; eggLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40); eggLabel.TextColor3 = Color3.fromRGB(255, 255, 255); eggLabel.Font = Enum.Font.SourceSans; eggLabel.TextSize = 14; eggLabel.TextXAlignment = Enum.TextXAlignment.Left
                local upButton = Instance.new("TextButton", itemFrame); upButton.Size = UDim2.new(0, 25, 1, 0); upButton.Position = UDim2.new(1, -55, 0, 0); upButton.Text = "▲"; upButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                local downButton = Instance.new("TextButton", itemFrame); downButton.Size = UDim2.new(0, 25, 1, 0); downButton.Position = UDim2.new(1, -25, 0, 0); downButton.Text = "▼"; downButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                upButton.MouseButton1Click:Connect(function() if i > 1 then local temp = config.placementPriority[i]; config.placementPriority[i] = config.placementPriority[i-1]; config.placementPriority[i-1] = temp; redrawEggPriorityList() end end)
                downButton.MouseButton1Click:Connect(function() if i < #config.placementPriority then local temp = config.placementPriority[i]; config.placementPriority[i] = config.placementPriority[i+1]; config.placementPriority[i+1] = temp; redrawEggPriorityList() end end)
                eggContentHeight = eggContentHeight + 35
            end
            EggListScroll.CanvasSize = UDim2.new(0, 0, 0, eggContentHeight)
        end
        local EggSaveButton = Instance.new("TextButton", EggFrame); EggSaveButton.Size = UDim2.new(0.9, 0, 0, 35); EggSaveButton.Position = UDim2.new(0.05, 0, 1, -40); EggSaveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); EggSaveButton.TextColor3 = Color3.fromRGB(255, 255, 255); EggSaveButton.Font = Enum.Font.SourceSansBold; EggSaveButton.Text = "Save & Close"; EggSaveButton.TextSize = 16
        EggSaveButton.MouseButton1Click:Connect(function() local newCount = tonumber(TargetCountInput.Text); if newCount then config.targetEggCount = newCount end; SaveConfig(); EggFrame.Visible = false; SettingsFrame.Visible = true; needsEggCheck = true end)

        PetSettingsButton.MouseButton1Click:Connect(function() SettingsFrame.Visible = not SettingsFrame.Visible end)
        SaveButton.MouseButton1Click:Connect(function() local newWeight = tonumber(MaxWeightInput.Text); if newWeight then config.maxWeightToSell = newWeight end; SaveConfig(); SettingsFrame.Visible = false; RunAutoSeller() end)
        SelectPetsButton.MouseButton1Click:Connect(function() SettingsFrame.Visible = false; PetCategoryMenu.Visible = true end)
        EggSettingsButton.MouseButton1Click:Connect(function() SettingsFrame.Visible = false; redrawEggPriorityList(); EggFrame.Visible = true end)
        
        mainButton.MouseButton1Click:Connect(function() Toggle() end)
        resetButton.MouseButton1Click:Connect(function() ResetConfig() end)
    end

    Toggle = function()
        isEnabled = not isEnabled
        UpdateButtonState()
        UpdateGUIVisibility()
        if isEnabled then SaveConfig(); mainThread = task.spawn(RunMasterLoop)
        else
            if mainThread then task.cancel(mainThread); mainThread = nil end
            SaveConfig()
        end
    end
    
    ResetConfig = function()
        print("Resetting config file...")
        pcall(function() writefile(CONFIG_FILE_NAME, HttpService:JSONEncode({})) end)
        print("✅ Config cleared. Please restart the script or toggle the main button.")
        if isEnabled then
            isEnabled = false
            if mainThread then task.cancel(mainThread); mainThread = nil end
            UpdateButtonState()
            UpdateGUIVisibility()
        end
    end
    
    if PlayerGui:FindFirstChild("CombinedFarmCraftGui") then
        PlayerGui.CombinedFarmCraftGui:Destroy()
    end
    LoadConfig()
    CreateGUI()
    UpdateButtonState()
    UpdateGUIVisibility()
    if isEnabled then
        mainThread = task.spawn(RunMasterLoop)
    end

    print("Combined Auto-Farm & Crafter (Final) loaded.")
end
