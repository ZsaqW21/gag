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
    FarmModule.CONFIG_FILE_NAME = "CombinedAutoFarmConfig_v12_UnequipFix.json"
    FarmModule.isEnabled = false
    FarmModule.mainThread = nil
    FarmModule.knownReadyEggs = {}
    FarmModule.placedPositions = {}

    FarmModule.EGG_UUID_ATTRIBUTE = "OBJECT_UUID" 
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
        -- This function now only needs to check the backpack
        for _, item in ipairs(self.Backpack:GetChildren()) do
            if item:IsA("Tool") and item:GetAttribute(self.PLACEMENT_ATTRIBUTE_NAME) == self.PLACEMENT_ATTRIBUTE_VALUE then return item end
        end
        return nil
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
    local mainButton = Instance.new("TextButton", screenGui); mainButton.Name = "ToggleButton"; mainButton.TextSize = 20; mainButton.Font = Enum.Font.SourceSansBold; mainButton.TextColor3 = Color3.fromRGB
