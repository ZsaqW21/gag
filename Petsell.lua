--[[
    Auto Pet Seller with Config Menu
    - Sells selected pets that are under a user-defined weight.
    - Features a toggleable GUI to configure settings.
    - Saves your settings for future use.
    - Includes a startup delay to prevent conflicts with game scripts.
]]

-- CORRECTED: Use a more reliable method to wait for the game to fully load.
if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(1) -- Add a small extra delay for safety

-- Isolate the entire script in a do...end block to prevent global conflicts
do
    --================================================================================--
    --                         Services & Player Setup
    --================================================================================--
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local backpack = LocalPlayer:WaitForChild("Backpack")
    local humanoid = character:WaitForChild("Humanoid")
    local sellPetRemote = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("SellPet_RE")

    --================================================================================--
    --                         Configuration & State
    --================================================================================--
    local CONFIG_FILE_NAME = "AutoPetSellerConfig_v7_LoadedWait.json"
    local config = {
        maxWeightToSell = 4,
        sellablePets = {
            ["Iguanodon"] = true,
            ["Pachycephalosaurus"] = false,
            ["Parasaurolophus"] = false,
            ["Stegosaurus"] = false,
            ["Raptor"] = false,
        }
    }
    local OutputBox -- Forward declare for the logger

    --================================================================================--
    --                         Configuration Save/Load
    --================================================================================--
    local function saveConfig()
        if typeof(writefile) ~= "function" then return end
        pcall(function()
            writefile(CONFIG_FILE_NAME, HttpService:JSONEncode(config))
        end)
    end

    local function loadConfig()
        if typeof(readfile) ~= "function" then return end
        local success, fileData = pcall(readfile, CONFIG_FILE_NAME)
        if success and fileData then
            local success2, decodedData = pcall(HttpService.JSONDecode, HttpService, fileData)
            if success2 and typeof(decodedData) == "table" then
                config.maxWeightToSell = decodedData.maxWeightToSell or config.maxWeightToSell
                if typeof(decodedData.sellablePets) == "table" then
                    for petName, _ in pairs(config.sellablePets) do
                        if decodedData.sellablePets[petName] ~= nil then
                            config.sellablePets[petName] = decodedData.sellablePets[petName]
                        end
                    end
                end
            end
        end
    end

    --================================================================================--
    --                         GUI Creation & Management
    --================================================================================--
    local function createGUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "PetSellerGUI"
        ScreenGui.ResetOnSpawn = false

        local LogFrame = Instance.new("Frame", ScreenGui)
        LogFrame.Size = UDim2.new(0.8, 0, 0.7, 0); LogFrame.Position = UDim2.new(0.1, 0, 0.15, 0)
        LogFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45); LogFrame.BorderColor3 = Color3.fromRGB(120, 120, 120); LogFrame.BorderSizePixel = 2

        local LogTitle = Instance.new("TextLabel", LogFrame)
        LogTitle.Size = UDim2.new(1, 0, 0, 30); LogTitle.Text = "Pet Seller Log - Long-press to copy"
        LogTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60); LogTitle.TextColor3 = Color3.fromRGB(255, 255, 255); LogTitle.Font = Enum.Font.SourceSans; LogTitle.TextSize = 18

        OutputBox = Instance.new("TextBox", LogFrame)
        OutputBox.Size = UDim2.new(1, -20, 1, -80); OutputBox.Position = UDim2.new(0, 10, 0, 40)
        OutputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30); OutputBox.TextColor3 = Color3.fromRGB(240, 240, 240); OutputBox.Font = Enum.Font.Code
        OutputBox.TextSize = 14; OutputBox.MultiLine = true; OutputBox.TextEditable = false; OutputBox.ClearTextOnFocus = false
        OutputBox.TextXAlignment = Enum.TextXAlignment.Left; OutputBox.TextYAlignment = Enum.TextYAlignment.Top
        
        local SettingsButton = Instance.new("TextButton", LogFrame)
        SettingsButton.Size = UDim2.new(0, 100, 0, 30); SettingsButton.Position = UDim2.new(1, -115, 1, -35)
        SettingsButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); SettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SettingsButton.Font = Enum.Font.SourceSansBold; SettingsButton.Text = "Settings"; SettingsButton.TextSize = 18
        local corner1 = Instance.new("UICorner", SettingsButton); corner1.CornerRadius = UDim.new(0, 6)

        local CloseButton = Instance.new("TextButton", LogFrame)
        CloseButton.Size = UDim2.new(0, 100, 0, 30); CloseButton.Position = UDim2.new(0, 10, 1, -35)
        CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.Font = Enum.Font.SourceSansBold; CloseButton.Text = "Close"; CloseButton.TextSize = 18
        local corner2 = Instance.new("UICorner", CloseButton); corner2.CornerRadius = UDim.new(0, 6)

        local SettingsFrame = Instance.new("Frame", ScreenGui)
        SettingsFrame.Size = UDim2.new(0, 300, 0, 350); SettingsFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
        SettingsFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); SettingsFrame.BorderColor3 = Color3.fromRGB(150, 150, 150); SettingsFrame.BorderSizePixel = 2
        SettingsFrame.Visible = false
        local corner3 = Instance.new("UICorner", SettingsFrame); corner3.CornerRadius = UDim.new(0, 8)

        local SettingsTitle = Instance.new("TextLabel", SettingsFrame)
        SettingsTitle.Size = UDim2.new(1, 0, 0, 30); SettingsTitle.Text = "Auto-Sell Settings"
        SettingsTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255); SettingsTitle.Font = Enum.Font.SourceSansBold; SettingsTitle.TextSize = 18

        local listLayout = Instance.new("UIListLayout", SettingsFrame)
        listLayout.Padding = UDim.new(0, 5); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        listLayout.StartCorner = Enum.StartCorner.TopLeft; listLayout.Padding = UDim.new(0, 10)

        local MaxWeightLabel = Instance.new("TextLabel", SettingsFrame)
        MaxWeightLabel.Size = UDim2.new(0.9, 0, 0, 20); MaxWeightLabel.Text = "Sell pets UNDER this KG:"
        MaxWeightLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55); MaxWeightLabel.TextColor3 = Color3.fromRGB(220, 220, 220); MaxWeightLabel.Font = Enum.Font.SourceSans; MaxWeightLabel.TextSize = 16
        MaxWeightLabel.LayoutOrder = 1; MaxWeightLabel.TextXAlignment = Enum.TextXAlignment.Left

        local MaxWeightInput = Instance.new("TextBox", SettingsFrame)
        MaxWeightInput.Size = UDim2.new(0.9, 0, 0, 30); MaxWeightInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40); MaxWeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        MaxWeightInput.Font = Enum.Font.SourceSansBold; MaxWeightInput.TextSize = 16
        MaxWeightInput.Text = tostring(config.maxWeightToSell)
        MaxWeightInput.LayoutOrder = 2

        local PetTogglesLabel = Instance.new("TextLabel", SettingsFrame)
        PetTogglesLabel.Size = UDim2.new(0.9, 0, 0, 20); PetTogglesLabel.Text = "Select pets to sell:"
        PetTogglesLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55); PetTogglesLabel.TextColor3 = Color3.fromRGB(220, 220, 220); PetTogglesLabel.Font = Enum.Font.SourceSans; PetTogglesLabel.TextSize = 16
        PetTogglesLabel.LayoutOrder = 3; PetTogglesLabel.TextXAlignment = Enum.TextXAlignment.Left

        local layoutOrder = 4
        for petName, isEnabled in pairs(config.sellablePets) do
            local toggleButton = Instance.new("TextButton", SettingsFrame)
            toggleButton.Size = UDim2.new(0.9, 0, 0, 30); toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextSize = 16
            toggleButton.LayoutOrder = layoutOrder
            
            local function updateToggleState()
                if config.sellablePets[petName] then
                    toggleButton.Text = petName .. ": ON"; toggleButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70)
                else
                    toggleButton.Text = petName .. ": OFF"; toggleButton.BackgroundColor3 = Color3.fromRGB(190, 40, 40)
                end
            end
            
            toggleButton.MouseButton1Click:Connect(function()
                config.sellablePets[petName] = not config.sellablePets[petName]
                updateToggleState()
            end)
            updateToggleState()
            layoutOrder = layoutOrder + 1
        end

        local SaveButton = Instance.new("TextButton", SettingsFrame)
        SaveButton.Size = UDim2.new(0.9, 0, 0, 40); SaveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); SaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SaveButton.Font = Enum.Font.SourceSansBold; SaveButton.Text = "Save & Close"; SaveButton.TextSize = 18
        SaveButton.LayoutOrder = layoutOrder
        local corner4 = Instance.new("UICorner", SaveButton); corner4.CornerRadius = UDim.new(0, 6)

        CloseButton.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
        SettingsButton.MouseButton1Click:Connect(function() SettingsFrame.Visible = not SettingsFrame.Visible end)
        SaveButton.MouseButton1Click:Connect(function()
            local newWeight = tonumber(MaxWeightInput.Text)
            if newWeight then config.maxWeightToSell = newWeight end
            saveConfig()
            SettingsFrame.Visible = false
        end)

        ScreenGui.Parent = PlayerGui
    end

    local function logToGui(message)
        if OutputBox then
            OutputBox.Text = OutputBox.Text .. message .. "\n"
        end
    end

    --================================================================================--
    --                         Pet Finding & Selling Logic
    --================================================================================--
    local function runAutoSeller()
        loadConfig()
        logToGui("🦕 Starting auto-seller with loaded settings...")
        logToGui("   -> Selling pets under " .. config.maxWeightToSell .. " KG")

        local totalPetsSold = 0
        while true do
            local petSoldThisPass = false
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    for petName, shouldSell in pairs(config.sellablePets) do
                        if shouldSell and item.Name:find(petName, 1, true) then
                            logToGui("Checking item: '" .. item.Name .. "'")
                            local weightString = item.Name:match("%[(%d+%.?%d*)%s*KG%]")
                            if weightString then
                                local weight = tonumber(weightString)
                                if weight < config.maxWeightToSell then
                                    logToGui("✅ Found '" .. item.Name .. "' ("..weight.."KG). Equipping to sell...")
                                    humanoid:EquipTool(item)
                                    task.wait(0.5)
                                    local equippedPet = character:FindFirstChild(item.Name)
                                    if equippedPet then
                                        sellPetRemote:FireServer(equippedPet)
                                        totalPetsSold = totalPetsSold + 1
                                        petSoldThisPass = true
                                        task.wait(1)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                if petSoldThisPass then
                    break
                end
            end
            
            if not petSoldThisPass then
                break
            end
        end

        if totalPetsSold > 0 then
            logToGui("👍 Sell process completed. Sold " .. totalPetsSold .. " pet(s).")
        else
            logToGui("❌ No pets matching your criteria were found to sell.")
        end
    end

    --================================================================================--
    --                         Initialization
    --================================================================================--
    createGUI()
    runAutoSeller()
end
