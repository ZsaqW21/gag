--[[
    Auto Pet Seller with Config Menu
    - Sells selected pets that are under a user-defined weight.
    - Features a toggleable GUI to configure settings.
    - Saves your settings for future use.
    - Re-scans inventory when settings are saved.
]]

-- Use a more reliable method to wait for the game to fully load.
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
    local CONFIG_FILE_NAME = "AutoPetSellerConfig_v9_Rescan.json"
    local config = {
        maxWeightToSell = 4,
        sellablePets = {
            ["Iguanodon"] = true,
            ["Pachycephalosaurus"] = false,
            ["Parasaurolophus"] = false,
            ["Stegosaurus"] = false,
            ["Raptor"] = false,
            ["Triceratops"] = false,
            ["Pterodactyl"] = false,
        }
    }
    local OutputBox -- Forward declare for the logger
    local isScanning = false -- Prevent multiple scans at once

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

    -- Forward declare the main selling function
    local startAutoSellScan

    --================================================================================--
    --                         GUI Creation & Management
    --================================================================================--
    local function createGUI()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "PetSellerGUI"
        ScreenGui.ResetOnSpawn = false

        local LogFrame = Instance.new("Frame", ScreenGui)
        LogFrame.Size = UDim2.new(0.5, 0, 0.4, 0); LogFrame.Position = UDim2.new(0.25, 0, 0.3, 0)
        LogFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45); LogFrame.BorderColor3 = Color3.fromRGB(120, 120, 120); LogFrame.BorderSizePixel = 2

        local LogTitle = Instance.new("TextLabel", LogFrame)
        LogTitle.Size = UDim2.new(1, 0, 0, 30); LogTitle.Text = "Pet Seller Log"
        LogTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60); LogTitle.TextColor3 = Color3.fromRGB(255, 255, 255); LogTitle.Font = Enum.Font.SourceSans; LogTitle.TextSize = 16

        OutputBox = Instance.new("TextBox", LogFrame)
        OutputBox.Size = UDim2.new(1, -20, 1, -80); OutputBox.Position = UDim2.new(0, 10, 0, 40)
        OutputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30); OutputBox.TextColor3 = Color3.fromRGB(240, 240, 240); OutputBox.Font = Enum.Font.Code
        OutputBox.TextSize = 12; OutputBox.MultiLine = true; OutputBox.TextEditable = false; OutputBox.ClearTextOnFocus = false
        OutputBox.TextXAlignment = Enum.TextXAlignment.Left; OutputBox.TextYAlignment = Enum.TextYAlignment.Top
        
        local SettingsButton = Instance.new("TextButton", LogFrame)
        SettingsButton.Size = UDim2.new(0, 90, 0, 30); SettingsButton.Position = UDim2.new(1, -105, 1, -35)
        SettingsButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); SettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SettingsButton.Font = Enum.Font.SourceSansBold; SettingsButton.Text = "Settings"; SettingsButton.TextSize = 16
        local corner1 = Instance.new("UICorner", SettingsButton); corner1.CornerRadius = UDim.new(0, 6)

        local CloseButton = Instance.new("TextButton", LogFrame)
        CloseButton.Size = UDim2.new(0, 90, 0, 30); CloseButton.Position = UDim2.new(0, 10, 1, -35)
        CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.Font = Enum.Font.SourceSansBold; CloseButton.Text = "Close"; CloseButton.TextSize = 16
        local corner2 = Instance.new("UICorner", CloseButton); corner2.CornerRadius = UDim.new(0, 6)
        
        -- NEW: Start Scan Button
        local StartScanButton = Instance.new("TextButton", LogFrame)
        StartScanButton.Size = UDim2.new(0, 110, 0, 30); StartScanButton.Position = UDim2.new(0.5, -55, 1, -35)
        StartScanButton.BackgroundColor3 = Color3.fromRGB(20, 140, 70); StartScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        StartScanButton.Font = Enum.Font.SourceSansBold; StartScanButton.Text = "Start New Scan"; StartScanButton.TextSize = 14
        local corner_scan = Instance.new("UICorner", StartScanButton); corner_scan.CornerRadius = UDim.new(0, 6)

        local SettingsFrame = Instance.new("Frame", ScreenGui)
        SettingsFrame.Size = UDim2.new(0, 220, 0, 170); SettingsFrame.Position = UDim2.new(0.5, -110, 0.5, -85)
        SettingsFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); SettingsFrame.BorderColor3 = Color3.fromRGB(150, 150, 150); SettingsFrame.BorderSizePixel = 2
        SettingsFrame.Visible = false
        local corner3 = Instance.new("UICorner", SettingsFrame); corner3.CornerRadius = UDim.new(0, 8)

        local SettingsTitle = Instance.new("TextLabel", SettingsFrame)
        SettingsTitle.Size = UDim2.new(1, 0, 0, 30); SettingsTitle.Text = "Auto-Sell Settings"
        SettingsTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255); SettingsTitle.Font = Enum.Font.SourceSansBold; SettingsTitle.TextSize = 16

        local listLayout = Instance.new("UIListLayout", SettingsFrame)
        listLayout.Padding = UDim.new(0, 10); listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local MaxWeightLabel = Instance.new("TextLabel", SettingsFrame)
        MaxWeightLabel.Size = UDim2.new(0.9, 0, 0, 20); MaxWeightLabel.Text = "Sell pets UNDER this KG:"
        MaxWeightLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55); MaxWeightLabel.TextColor3 = Color3.fromRGB(220, 220, 220); MaxWeightLabel.Font = Enum.Font.SourceSans; MaxWeightLabel.TextSize = 14
        MaxWeightLabel.LayoutOrder = 1; MaxWeightLabel.TextXAlignment = Enum.TextXAlignment.Left

        local MaxWeightInput = Instance.new("TextBox", SettingsFrame)
        MaxWeightInput.Size = UDim2.new(0.9, 0, 0, 30); MaxWeightInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40); MaxWeightInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        MaxWeightInput.Font = Enum.Font.SourceSansBold; MaxWeightInput.TextSize = 14
        MaxWeightInput.Text = tostring(config.maxWeightToSell)
        MaxWeightInput.LayoutOrder = 2

        local SelectPetsButton = Instance.new("TextButton", SettingsFrame)
        SelectPetsButton.Size = UDim2.new(0.9, 0, 0, 35); SelectPetsButton.BackgroundColor3 = Color3.fromRGB(70, 90, 180); SelectPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SelectPetsButton.Font = Enum.Font.SourceSansBold; SelectPetsButton.Text = "Select Pets to Sell"; SelectPetsButton.TextSize = 16
        SelectPetsButton.LayoutOrder = 3
        local corner4 = Instance.new("UICorner", SelectPetsButton); corner4.CornerRadius = UDim.new(0, 6)

        local PetTogglesFrame = Instance.new("Frame", ScreenGui)
        PetTogglesFrame.Size = UDim2.new(0, 220, 0, 340); PetTogglesFrame.Position = UDim2.new(0.5, -110, 0.5, -170)
        PetTogglesFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55); PetTogglesFrame.BorderColor3 = Color3.fromRGB(150, 150, 150); PetTogglesFrame.BorderSizePixel = 2
        PetTogglesFrame.Visible = false
        local corner5 = Instance.new("UICorner", PetTogglesFrame); corner5.CornerRadius = UDim.new(0, 8)

        local PetTogglesTitle = Instance.new("TextLabel", PetTogglesFrame)
        PetTogglesTitle.Size = UDim2.new(1, 0, 0, 30); PetTogglesTitle.Text = "Select Pets"
        PetTogglesTitle.BackgroundColor3 = Color3.fromRGB(70, 70, 70); PetTogglesTitle.TextColor3 = Color3.fromRGB(255, 255, 255); PetTogglesTitle.Font = Enum.Font.SourceSansBold; PetTogglesTitle.TextSize = 16

        local petListLayout = Instance.new("UIListLayout", PetTogglesFrame)
        petListLayout.Padding = UDim.new(0, 10); petListLayout.SortOrder = Enum.SortOrder.LayoutOrder; petListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        local layoutOrder = 1
        for petName, isEnabled in pairs(config.sellablePets) do
            local toggleButton = Instance.new("TextButton", PetTogglesFrame)
            toggleButton.Size = UDim2.new(0.9, 0, 0, 28); toggleButton.Font = Enum.Font.SourceSansBold; toggleButton.TextSize = 14
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

        local PetSaveButton = Instance.new("TextButton", PetTogglesFrame)
        PetSaveButton.Size = UDim2.new(0.9, 0, 0, 35); PetSaveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200); PetSaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetSaveButton.Font = Enum.Font.SourceSansBold; PetSaveButton.Text = "Save & Close"; PetSaveButton.TextSize = 16
        PetSaveButton.LayoutOrder = layoutOrder
        local corner6 = Instance.new("UICorner", PetSaveButton); corner6.CornerRadius = UDim.new(0, 6)

        local function saveAndCloseSettings()
            local newWeight = tonumber(MaxWeightInput.Text)
            if newWeight then config.maxWeightToSell = newWeight end
            saveConfig()
            SettingsFrame.Visible = false
            PetTogglesFrame.Visible = false
            LogFrame.Visible = true
            -- RE-RUN SCAN: Call the main function again with new settings
            startAutoSellScan()
        end
        
        PetSaveButton.MouseButton1Click:Connect(saveAndCloseSettings)
        
        local BackButton = Instance.new("TextButton", SettingsFrame)
        BackButton.Size = UDim2.new(0.9, 0, 0, 35); BackButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100); BackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        BackButton.Font = Enum.Font.SourceSansBold; BackButton.Text = "Back to Log"; BackButton.TextSize = 16
        BackButton.LayoutOrder = 4
        local corner7 = Instance.new("UICorner", BackButton); corner7.CornerRadius = UDim.new(0, 6)
        BackButton.MouseButton1Click:Connect(saveAndCloseSettings)

        -- GUI Event Connections
        CloseButton.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
        SettingsButton.MouseButton1Click:Connect(function() SettingsFrame.Visible = true; LogFrame.Visible = false end)
        SelectPetsButton.MouseButton1Click:Connect(function() PetTogglesFrame.Visible = true; SettingsFrame.Visible = false end)
        StartScanButton.MouseButton1Click:Connect(function() startAutoSellScan() end)

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
    startAutoSellScan = function()
        if isScanning then
            logToGui("--- A scan is already in progress. ---")
            return
        end
        isScanning = true
        OutputBox.Text = "" -- Clear the log for the new scan

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
        isScanning = false
    end

    --================================================================================--
    --                         Initialization
    --================================================================================--
    createGUI()
    startAutoSellScan()
end
