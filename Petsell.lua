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
    FarmModule.CONFIG_FILE_NAME = "CombinedFarmAndSeller_v15_Recipes.json"
    FarmModule.isEnabled = false
    FarmModule.mainThread = nil
    FarmModule.placedPositions = {}
    FarmModule.config = {
        maxWeightToSell = 4,
        targetEggCount = 3,
        activeRecipe = "Primal Egg",
        sellablePets = {},
        placementPriority = {
            "Primal Egg", "Dinosaur Egg", "Zen Egg", "Paradise Egg", "Bug Egg", "Mythical Egg"
        }
    }

    FarmModule.petCategories = {}

    -- NEW: Recipe Database
    FarmModule.Recipes = {
        ["Primal Egg"] = {
            Workbench = "DinoEventWorkbench",
            Ingredients = {
                { AttributeName = "h", AttributeValue = "Dinosaur Egg", ItemType = "PetEgg" },
                { AttributeName = "f", AttributeValue = "Bone Blossom", ItemType = "Holdable" }
            }
        },
        ["Dinosaur Egg"] = {
            Workbench = "DinoEventWorkbench",
            Ingredients = {
                { AttributeName = "h", AttributeValue = "Common Egg", ItemType = "PetEgg" },
                { AttributeName = "f", AttributeValue = "Bone Blossom", ItemType = "Holdable" }
            }
        },
        ["Ancient Seed Pack"] = {
            Workbench = "DinoEventWorkbench",
            Ingredients = {
                { AttributeName = "h", AttributeValue = "Dinosaur Egg", ItemType = "PetEgg" }
            }
        },
        ["SKIP_CRAFT"] = {
            Skip = true
        }
    }

    FarmModule.EGG_UUID_ATTRIBUTE = "OBJECT_UUID"
    FarmModule.PLACEMENT_ATTRIBUTE_NAME = "h"
    FarmModule.MINIMUM_DISTANCE = 5
    FarmModule.corner1 = Vector3.new(-2.5596256256103516, 0.13552704453468323, 47.833213806152344)
    FarmModule.corner2 = Vector3.new(26.806381225585938, 0.13552704453468323, 106.00519561767578)

    function FarmModule:PerformOneCraftCycle()
        local success, err = pcall(function()
            local activeRecipeName = self.config.activeRecipe
            local recipeData = self.Recipes[activeRecipeName]
            if not recipeData then
                error("Active recipe '" .. activeRecipeName .. "' not found.")
            end

            if recipeData.Skip then
                self:UpdateButtonState("Waiting for Eggs")
                self.needsEggCheck = true
                task.wait(5)
                return
            end

            self:UpdateButtonState("Crafting...")

            local DinoEvent = self.Workspace:FindFirstChild("DinoEvent") or self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
            if DinoEvent and DinoEvent:IsDescendantOf(self.ReplicatedStorage) then
                DinoEvent.Parent = self.Workspace
            end

            local DinoTable = self.Workspace:WaitForChild("DinoEvent", 5):WaitForChild("DinoCraftingTable", 5)
            if not DinoTable then error("Could not find DinoCraftingTable. Aborting craft cycle.") end

            self.CraftingService:FireServer("SetRecipe", DinoTable, recipeData.Workbench, activeRecipeName)
            task.wait(0.3)

            for i, ingredient in ipairs(recipeData.Ingredients) do
                for _, tool in ipairs(self.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool:GetAttribute(ingredient.AttributeName) == ingredient.AttributeValue then
                        for _, t in ipairs(self.Character:GetChildren()) do
                            if t:IsA("Tool") then t.Parent = self.Backpack end
                        end
                        tool.Parent = self.Character
                        task.wait(0.3)
                        local uuid = tool:GetAttribute("c")
                        if uuid then
                            self.CraftingService:FireServer("InputItem", DinoTable, recipeData.Workbench, i, { ItemType = ingredient.ItemType, ItemData = { UUID = uuid } })
                        end
                        tool.Parent = self.Backpack
                        break
                    end
                end
            end

            task.wait(0.3)
            self.CraftingService:FireServer("Craft", DinoTable, recipeData.Workbench)
            task.wait(1)
            self.TeleportService:Teleport(game.PlaceId)
        end)
        if not success then
            warn("AutoCraft Error:", err, "-- Turning off.")
            self.isEnabled = false
            self:UpdateButtonState()
            self:SaveConfig()
        end
    end

    function FarmModule:RunMasterLoop()
        while self.isEnabled do
            if self.needsEggCheck then
                local myFarm = self:FindFarmByLocation()
                if not myFarm then task.wait(5); continue end
                local objectsFolder = myFarm:FindFirstChild("Important", true) and myFarm.Important:FindFirstChild("Objects_Physical")
                if not objectsFolder then task.wait(5); continue end

                local allEggs = {}
                for _, obj in ipairs(objectsFolder:GetChildren()) do
                    if obj:IsA("Model") and obj:GetAttribute(self.EGG_UUID_ATTRIBUTE) then
                        table.insert(allEggs, obj)
                    end
                end

                local readyCount = 0
                for _, egg in ipairs(allEggs) do
                    if egg:GetAttribute("TimeToHatch") == 0 then
                        readyCount += 1
                    end
                end

                if #allEggs >= self.config.targetEggCount and readyCount == #allEggs then
                    for _, eggToHatch in ipairs(allEggs) do
                        if not self.isEnabled then break end
                        self:HatchOneEgg(eggToHatch)
                        task.wait(0.2)
                    end
                    task.wait(3)
                    continue
                end

                if #allEggs < self.config.targetEggCount then
                    local humanoid = self.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:UnequipTools()
                        task.wait(0.2)
                        local toolInstance = self:FindPlacementTool()
                        if toolInstance then
                            humanoid:EquipTool(toolInstance)
                            task.wait(0.5)
                            self.placedPositions = {}
                            for i = 1, (self.config.targetEggCount - #allEggs) do
                                if not self.isEnabled then break end
                                self:PlaceOneEgg()
                                task.wait(0.5)
                            end
                            task.wait(1)
                            self:RunAutoSeller()
                            continue
                        end
                    end
                end

                if #allEggs > 0 and readyCount < #allEggs then
                    self.needsEggCheck = false
                end
            end

            self:PerformOneCraftCycle()
            task.wait(3)
        end
    end

    FarmModule:LoadConfig()
    FarmModule:CreateGUI()
    FarmModule:UpdateButtonState()
    FarmModule:UpdateGUIVisibility()
    if FarmModule.isEnabled then
        FarmModule.mainThread = task.spawn(function()
            FarmModule:RunMasterLoop()
        end)
    end

    print("Combined Auto-Farm & Crafter (with Recipes) loaded.")
end
