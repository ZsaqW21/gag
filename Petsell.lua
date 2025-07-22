function FarmModule:PerformOneCraftCycle()
    local success, err = pcall(function()
        self:UpdateButtonState("Crafting...")
        
        local activeRecipeName = self.config.activeRecipe
        local recipeData = self.Recipes[activeRecipeName]
        if not recipeData then
            error("Active recipe '"..activeRecipeName.."' not found in database.")
        end

        -- Handle the "None (Rejoin Only)" case
        if activeRecipeName == "None (Rejoin Only)" then
            self.TeleportService:Teleport(game.PlaceId)
            task.wait(3)
            return
        end

        local DinoEvent = self.Workspace:FindFirstChild("DinoEvent") or self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
        if DinoEvent and DinoEvent:IsDescendantOf(self.ReplicatedStorage) then DinoEvent.Parent = self.Workspace end
        
        local DinoTable = self.Workspace:WaitForChild("DinoEvent", 5):WaitForChild("DinoCraftingTable", 5)
        if not DinoTable then error("Could not find DinoCraftingTable. Aborting craft cycle.") end

        self.CraftingService:FireServer("SetRecipe", DinoTable, recipeData.Workbench, activeRecipeName)
        task.wait(0.3)
        
        for i, ingredient in ipairs(recipeData.Ingredients) do
            for _, tool in ipairs(self.Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute(ingredient.AttributeName) == ingredient.AttributeValue then
                    -- Unequip anything currently held
                    for _, t in ipairs(self.Character:GetChildren()) do if t:IsA("Tool") then t.Parent = self.Backpack end end
                    tool.Parent = self.Character; task.wait(0.3)
                    local uuid = tool:GetAttribute("c")
                    if uuid then self.CraftingService:FireServer("InputItem", DinoTable, recipeData.Workbench, i, { ItemType = ingredient.ItemType, ItemData = { UUID = uuid } }) end
                    tool.Parent = self.Backpack; break
                end
            end
        end

        task.wait(0.3); self.CraftingService:FireServer("Craft", DinoTable, recipeData.Workbench); task.wait(1); self.TeleportService:Teleport(game.PlaceId)
    end)
    if not success then warn("AutoCraft Error:", err, "-- Turning off."); self.isEnabled = false; self:UpdateButtonState(); self:SaveConfig() end
end
