-- Wait for the game to fully load before running anything
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- Player
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Configuration
local CONFIG_FILE_NAME = "AutoCraftDinoEventConfig.json"

-- Toggle State (will be updated by loadConfig)
local isEnabled = false 
local mainLoopThread = nil

--================================================================================--
--                         Configuration Save/Load
--================================================================================--

local function saveConfig()
    -- Only try to save if the 'writefile' function is available
    if typeof(writefile) ~= "function" then return end

    local configData = {
        enabled = isEnabled
    }
    local success, encodedData = pcall(HttpService.JSONEncode, HttpService, configData)
    if success then
        writefile(CONFIG_FILE_NAME, encodedData)
    end
end

local function loadConfig()
    -- Only try to load if 'readfile' is available
    if typeof(readfile) ~= "function" then return end

    local success, fileData = pcall(readfile, CONFIG_FILE_NAME)
    if not success or not fileData then return end

    local success2, configData = pcall(HttpService.JSONDecode, HttpService, fileData)
    if success2 and typeof(configData) == "table" and configData.enabled ~= nil then
        -- Set the initial state from the config file
        isEnabled = configData.enabled
    end
end


--================================================================================--
--                         GUI Button and State Management
--================================================================================--

-- Create the ScreenGui that will hold the button
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CraftingToggleGui"
screenGui.ResetOnSpawn = false

-- Create the TextButton
local button = Instance.new("TextButton")
button.Name = "CraftButton"
button.TextSize = 20
button.Font = Enum.Font.SourceSansBold
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Size = UDim2.new(0, 160, 0, 50)
button.Position = UDim2.new(1, -180, 1, -70)
button.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = button

-- Function to update the button's appearance
local function updateButtonState()
    if isEnabled then
        button.Text = "AutoCraft: ON"
        button.BackgroundColor3 = Color3.fromRGB(20, 140, 70) -- Green
    else
        button.Text = "AutoCraft: OFF"
        button.BackgroundColor3 = Color3.fromRGB(190, 40, 40) -- Red
    end
end

--================================================================================--
--                            Main Crafting Loop
--================================================================================--

local function executeCraftingLoop()
    while isEnabled do
        local success, err = pcall(function()
            local Backpack = LocalPlayer:WaitForChild("Backpack")
            local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local CraftingService = ReplicatedStorage.GameEvents.CraftingGlobalObjectService
            local DinoEvent = workspace:FindFirstChild("DinoEvent") or ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
            if DinoEvent and DinoEvent:IsDescendantOf(ReplicatedStorage) then
                DinoEvent.Parent = workspace
            end
            local DinoTable = workspace:WaitForChild("DinoEvent"):WaitForChild("DinoCraftingTable")

            CraftingService:FireServer("SetRecipe", DinoTable, "DinoEventWorkbench", "Primal Egg")
            task.wait(0.3)

            -- Input Dinosaur Egg
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("h") == "Dinosaur Egg" then
                    tool.Parent = Character
                    task.wait(0.3)
                    local uuid = tool:GetAttribute("c")
                    if uuid then CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 1, { ItemType = "PetEgg", ItemData = { UUID = uuid } }) end
                    tool.Parent = Backpack
                    break
                end
            end

            -- Input Bone Blossom
            for _, tool in ipairs(Backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("f") == "Bone Blossom" then
                    for _, t in ipairs(Character:GetChildren()) do if t:IsA("Tool") then t.Parent = Backpack end end
                    tool.Parent = Character
                    task.wait(0.3)
                    local uuid = tool:GetAttribute("c")
                    if uuid then CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 2, { ItemType = "Holdable", ItemData = { UUID = uuid } }) end
                    tool.Parent = Backpack
                    break
                end
            end

            task.wait(0.3)
            CraftingService:FireServer("Craft", DinoTable, "DinoEventWorkbench")
            task.wait(1)
            TeleportService:Teleport(game.PlaceId)
        end)

        if not success then
            warn("AutoCraft Error:", err, "-- Turning off to prevent spam.")
            isEnabled = false
            updateButtonState()
            saveConfig() -- Save the new "off" state
        end
        
        task.wait(3)
    end
end

--================================================================================--
--                         Connect Everything and Initialize
--================================================================================--

-- Connect the button tap/click to toggle the state
button.MouseButton1Click:Connect(function()
    isEnabled = not isEnabled
    updateButtonState()
    saveConfig() -- Save the state every time the button is clicked

    if isEnabled then
        mainLoopThread = task.spawn(executeCraftingLoop)
    else
        if mainLoopThread then
            task.cancel(mainLoopThread)
            mainLoopThread = nil
        end
    end
end)

-- Load the saved state, update the button, and start the loop if it was enabled
loadConfig()
updateButtonState()
if isEnabled then
    mainLoopThread = task.spawn(executeCraftingLoop)
end

-- Parent the GUI to the player's screen
screenGui.Parent = PlayerGui

print("AutoCraft toggle button loaded. State loaded from config.")
