if not game:IsLoaded() then game.Loaded:Wait() end; task.wait(1)
do
local M = {}
M.HttpService = game:GetService("HttpService"); M.Players = game:GetService("Players"); M.ReplicatedStorage = game:GetService("ReplicatedStorage"); M.TeleportService = game:GetService("TeleportService"); M.Workspace = game:GetService("Workspace")
M.LocalPlayer = M.Players.LocalPlayer or M.Players.PlayerAdded:Wait(); M.PlayerGui = M.LocalPlayer:WaitForChild("PlayerGui"); M.Character = M.LocalPlayer.Character or M.LocalPlayer.CharacterAdded:Wait(); M.Backpack = M.LocalPlayer:WaitForChild("Backpack")
M.GameEvents = M.ReplicatedStorage:WaitForChild("GameEvents"); M.CraftingService = M.GameEvents:WaitForChild("CraftingGlobalObjectService"); M.PetEggService = M.GameEvents:WaitForChild("PetEggService"); M.SellPetRemote = M.GameEvents:WaitForChild("SellPet_RE")

M.CFG_FILE = "CombinedFarmAndSeller_v15_PersistentFailsafe.json"; M.enabled = false; M.thread = nil; M.placed = {}; M.checkEggs = true
M.cfg = {
    maxWeight = 4, targetCount = 3, hatchFailsafeActive = false, -- Added failsafe flag
    sell = {
        ["Parasaurolophus"]=false,["Iguanodon"]=false,["Pachycephalosaurus"]=false,["Dilophosaurus"]=false,["Ankylosaurus"]=false,
        ["Raptor"]=false,["Triceratops"]=false,["Stegosaurus"]=false,["Pterodactyl"]=false,["Shiba Inu"]=false,["Nihonzaru"]=false,
        ["Tanuki"]=false,["Tanchozuru"]=false,["Kappa"]=false,["Ostrich"]=false,["Peacock"]=false,["Capybara"]=false,
        ["Scarlet Macaw"]=false,["Caterpillar"]=false,["Snail"]=false,["Giant Ant"]=false,["Praying Mantis"]=false,
        ["Grey Mouse"]=false,["Brown Mouse"]=false,["Squirrel"]=false,["Red Giant Ant"]=false,
    },
    priority = {"Primal Egg","Dinosaur Egg","Zen Egg","Paradise Egg","Bug Egg","Mythical Egg"}
}
M.petCats = {
    ["Primal"]={"Parasaurolophus","Iguanodon","Pachycephalosaurus","Dilophosaurus","Ankylosaurus"},
    ["Dino"]={"Raptor","Triceratops","Stegosaurus","Pterodactyl"},
    ["Zen"]={"Shiba Inu","Nihonzaru","Tanuki","Tanchozuru","Kappa"},
    ["Paradise"]={"Ostrich","Peacock","Capybara","Scarlet Macaw"},
    ["Bug"]={"Caterpillar","Snail","Giant Ant","Praying Mantis"},
    ["Mythical"]={"Grey Mouse","Brown Mouse","Squirrel","Red Giant Ant"}
}
M.EGG_UUID = "OBJECT_UUID"; M.PLACE_ATTR = "h"; M.MIN_DIST = 5
M.c1 = Vector3.new(-2.55, 0.13, 47.83); M.c2 = Vector3.new(26.80, 0.13, 106.00)

function M:Save()
    if typeof(writefile)~="function" then return end
    local s={enabled=self.enabled,maxWeight=self.cfg.maxWeight,sell=self.cfg.sell,priority=self.cfg.priority,targetCount=self.cfg.targetCount, hatchFailsafeActive=self.cfg.hatchFailsafeActive}
    pcall(function() writefile(self.CFG_FILE, self.HttpService:JSONEncode(s)) end)
end
function M:Load()
    if typeof(readfile)~="function" then return end
    local s, f = pcall(readfile, self.CFG_FILE)
    if s and f then
        local s2, d = pcall(self.HttpService.JSONDecode, self.HttpService, f)
        if s2 and typeof(d)=="table" then
            self.enabled=d.enabled or false; self.cfg.maxWeight=d.maxWeight or self.cfg.maxWeight; self.cfg.targetCount=d.targetCount or self.cfg.targetCount; self.cfg.hatchFailsafeActive=d.hatchFailsafeActive or false
            if typeof(d.sell)=="table" then for n,_ in pairs(self.cfg.sell) do if d.sell[n]~=nil then self.cfg.sell[n]=d.sell[n] end end end
            if typeof(d.priority)=="table" then self.cfg.priority=d.priority end
        end
    end
end

function M:FindFarm()
    local rp=self.Character:WaitForChild("HumanoidRootPart") if not rp then return nil end
    local ff,cf,md=self.Workspace:WaitForChild("Farm"),nil,math.huge
    for _,p in ipairs(ff:GetChildren()) do
        local cp=p:FindFirstChild("Center_Point")
        if cp then local d=(rp.Position-cp.Position).Magnitude; if d<md then md=d; cf=p end end
    end
    return cf
end
function M:FindTool()
    for _,n in ipairs(self.cfg.priority) do
        for _,i in ipairs(self.Backpack:GetChildren()) do if i:IsA("Tool") and i:GetAttribute(self.PLACE_ATTR)==n then return i end end
    end
    return nil
end
function M:PlaceEgg()
    local r,iv,a=nil,false,0
    repeat
        r=Vector3.new(math.random()*(math.max(self.c1.X,self.c2.X)-math.min(self.c1.X,self.c2.X))+math.min(self.c1.X,self.c2.X),self.c1.Y,math.random()*(math.max(self.c1.Z,self.c2.Z)-math.min(self.c1.Z,self.c2.Z))+math.min(self.c1.Z,self.c2.Z))
        iv=true; for _,p in ipairs(self.placed) do if (r-p).Magnitude<self.MIN_DIST then iv=false; break end end; a=a+1
    until iv or a>=100
    if iv then self.PetEggService:FireServer("CreateEgg",r); table.insert(self.placed,r) end
end
function M:HatchEgg(e)
    local p=e:FindFirstChild("ProximityPrompt",true) if not p then return end
    local d,los=p.MaxActivationDistance,p.RequiresLineOfSight; p.MaxActivationDistance=math.huge; p.RequiresLineOfSight=false
    fireproximityprompt(p); p.MaxActivationDistance=d; p.RequiresLineOfSight=los
end

local gui,btn,rst,petBtn
function M:UpdateState(s)
    if btn then if self.enabled then btn.Text="AutoFarm: "..(s or "ON"); btn.BackgroundColor3=Color3.fromRGB(20,140,70) else btn.Text="AutoFarm: OFF"; btn.BackgroundColor3=Color3.fromRGB(190,40,40) end end
end
function M:UpdateVis() if petBtn then petBtn.Visible=not self.enabled end end
function M:SellPets()
    self:UpdateState("Selling Pets"); local sold=0
    while true do
        local soldPass=false
        for _,i in ipairs(self.Backpack:GetChildren()) do
            if i:IsA("Tool") then
                for n,s in pairs(self.cfg.sell) do
                    if s and i.Name:find(n,1,true) then
                        local wS=i.Name:match("%[(%d+%.?%d*)%s*KG%]")
                        if wS then
                            local w=tonumber(wS)
                            if w<self.cfg.maxWeight then
                                local h=self.Character:FindFirstChildOfClass("Humanoid")
                                if h then h:EquipTool(i); task.wait(0.5)
                                    if i.Parent==self.Character then self.SellPetRemote:FireServer(i); sold=sold+1; soldPass=true; task.wait(1); break
                                    else if i.Parent~=self.Backpack then i.Parent=self.Backpack end end
                                end
                            end
                        end
                    end
                end
            end
            if soldPass then break end
        end
        if not soldPass then break end
    end
    print("Sold "..sold.." pet(s).")
end
function M:Craft()
    local s,e=pcall(function()
        self:UpdateState("Crafting")
        local de=self.Workspace:FindFirstChild("DinoEvent") or self.ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
        if de and de:IsDescendantOf(self.ReplicatedStorage) then de.Parent=self.Workspace end
        local dt=self.Workspace:WaitForChild("DinoEvent",5):WaitForChild("DinoCraftingTable",5)
        if not dt then error("No crafting table") end
        self.CraftingService:FireServer("SetRecipe",dt,"DinoEventWorkbench","Primal Egg"); task.wait(0.3)
        for _,t in ipairs(self.Backpack:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("h")=="Dinosaur Egg" then t.Parent=self.Character; task.wait(0.3); if t:GetAttribute("c") then self.CraftingService:FireServer("InputItem",dt,"DinoEventWorkbench",1,{ItemType="PetEgg",ItemData={UUID=t:GetAttribute("c")}}) end; t.Parent=self.Backpack; break end end
        for _,t in ipairs(self.Backpack:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("f")=="Bone Blossom" then for _,c in ipairs(self.Character:GetChildren()) do if c:IsA("Tool") then c.Parent=self.Backpack end end; t.Parent=self.Character; task.wait(0.3); if t:GetAttribute("c") then self.CraftingService:FireServer("InputItem",dt,"DinoEventWorkbench",2,{ItemType="Holdable",ItemData={UUID=t:GetAttribute("c")}}) end; t.Parent=self.Backpack; break end end
        task.wait(0.3); self.CraftingService:FireServer("Craft",dt,"DinoEventWorkbench"); task.wait(1); self.TeleportService:Teleport(game.PlaceId)
    end)
    if not s then warn("Craft Error:",e,"-- Off."); self.enabled=false; self:UpdateState(); self:Save() end
end
function M:Loop()
    while self.enabled do
        if self.checkEggs then
            if self.cfg.hatchFailsafeActive then
                print("Hatching failsafe is active. Skipping egg checks.")
                self.checkEggs = false
            else
                self:UpdateState("Finding Farm"); local f=self:FindFarm(); if not f then task.wait(5); continue end
                local of=f:FindFirstChild("Important",true) and f.Important:FindFirstChild("Objects_Physical") if not of then task.wait(5); continue end
                self:UpdateState("Checking Eggs"); local all,rdy={},0; for _,o in ipairs(of:GetChildren()) do if o:IsA("Model") and o:GetAttribute(self.EGG_UUID) then table.insert(all,o) end end; for _,e in ipairs(all) do if e:GetAttribute("TimeToHatch")==0 then rdy=rdy+1 end end
                if #all>=self.cfg.targetCount and rdy==#all then
                    self:UpdateState("Hatching "..rdy); local b4=#all; for _,e in ipairs(all) do if not self.enabled then break end; self:HatchEgg(e); task.wait(0.2) end; task.wait(3)
                    local after={}; for _,o in ipairs(of:GetChildren()) do if o:IsA("Model") and o:GetAttribute(self.EGG_UUID) then table.insert(after,o) end end
                    if #after>=b4 then
                        warn("Hatch fail (inv full?). Activating failsafe."); self.checkEggs=false; self.cfg.hatchFailsafeActive=true; self:Save()
                    end; continue
                end
                if #all<self.cfg.targetCount then
                    self:UpdateState("Placing Eggs"); local h=self.Character:FindFirstChildOfClass("Humanoid")
                    if h then h:UnequipTools(); task.wait(0.2); local t=self:FindTool()
                        if t then h:EquipTool(t); task.wait(0.5); self.placed={}; local num=self.cfg.targetCount-#all
                            for i=1,num do if not self.enabled then break end; self:PlaceEgg(); task.wait(0.5) end; task.wait(1); self:SellPets(); continue
                        end
                    end
                end
                if #all>0 and rdy<#all then print("Eggs not ready. Fast crafting."); self.checkEggs=false end
            end
        end
        self:Craft(); task.wait(3)
    end
    self:Save(); self:UpdateState()
end
function M:Create()
    if self.PlayerGui:FindFirstChild("CombinedFarmCraftGui") then self.PlayerGui.CombinedFarmCraftGui:Destroy() end
    gui=Instance.new("ScreenGui",self.PlayerGui); gui.Name="CombinedFarmCraftGui"; gui.ResetOnSpawn=false
    btn=Instance.new("TextButton",gui); btn.Name="ToggleButton"; btn.TextSize=20; btn.Font=Enum.Font.SourceSansBold; btn.TextColor3=Color3.fromRGB(255,255,255); btn.Size=UDim2.new(0,180,0,50); btn.Position=UDim2.new(1,-200,0,10); local c1=Instance.new("UICorner",btn); c1.CornerRadius=UDim.new(0,8)
    rst=Instance.new("TextButton",gui); rst.Name="ResetButton"; rst.Text="Reset Config"; rst.TextSize=14; rst.Font=Enum.Font.SourceSansBold; rst.TextColor3=Color3.fromRGB(255,255,255); rst.BackgroundColor3=Color3.fromRGB(150,40,40); rst.Size=UDim2.new(0,100,0,30); rst.Position=UDim2.new(1,-310,0,20); local c2=Instance.new("UICorner",rst); c2.CornerRadius=UDim.new(0,6)
    petBtn=Instance.new("TextButton",gui); petBtn.Name="PetSettingsButton"; petBtn.Text="Pet Sell Settings"; petBtn.TextSize=14; petBtn.Font=Enum.Font.SourceSansBold; petBtn.TextColor3=Color3.fromRGB(255,255,255); petBtn.BackgroundColor3=Color3.fromRGB(80,120,200); petBtn.Size=UDim2.new(0,120,0,40); petBtn.Position=UDim2.new(1,-440,0,15); local c3=Instance.new("UICorner",petBtn); c3.CornerRadius=UDim.new(0,6)
    local sf=Instance.new("Frame",gui); sf.Size=UDim2.new(0,220,0,220); sf.Position=UDim2.new(0.5,-110,0.5,-110); sf.BackgroundColor3=Color3.fromRGB(55,55,55); sf.BorderColor3=Color3.fromRGB(150,150,150); sf.BorderSizePixel=2; sf.Visible=false; local c4=Instance.new("UICorner",sf); c4.CornerRadius=UDim.new(0,8)
    local st=Instance.new("TextLabel",sf); st.Size=UDim2.new(1,0,0,30); st.Text="Main Settings"; st.BackgroundColor3=Color3.fromRGB(70,70,70); st.TextColor3=Color3.fromRGB(255,255,255); st.Font=Enum.Font.SourceSansBold; st.TextSize=16
    local ll=Instance.new("UIListLayout",sf); ll.Padding=UDim.new(0,10); ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local wl=Instance.new("TextLabel",sf); wl.Size=UDim2.new(0.9,0,0,20); wl.Text="Sell pets UNDER this KG:"; wl.BackgroundColor3=Color3.fromRGB(55,55,55); wl.TextColor3=Color3.fromRGB(220,220,220); wl.Font=Enum.Font.SourceSans; wl.TextSize=14; wl.LayoutOrder=1; wl.TextXAlignment=Enum.TextXAlignment.Left
    local wi=Instance.new("TextBox",sf); wi.Size=UDim2.new(0.9,0,0,30); wi.BackgroundColor3=Color3.fromRGB(40,40,40); wi.TextColor3=Color3.fromRGB(255,255,255); wi.Font=Enum.Font.SourceSansBold; wi.TextSize=14; wi.Text=tostring(M.cfg.maxWeight); wi.LayoutOrder=2
    local spb=Instance.new("TextButton",sf); spb.Size=UDim2.new(0.9,0,0,35); spb.BackgroundColor3=Color3.fromRGB(70,90,180); spb.TextColor3=Color3.fromRGB(255,255,255); spb.Font=Enum.Font.SourceSansBold; spb.Text="Select Pets to Sell"; spb.TextSize=16; spb.LayoutOrder=3; local c5=Instance.new("UICorner",spb); c5.CornerRadius=UDim.new(0,6)
    local esb=Instance.new("TextButton",sf); esb.Size=UDim2.new(0.9,0,0,35); esb.BackgroundColor3=Color3.fromRGB(70,90,180); esb.TextColor3=Color3.fromRGB(255,255,255); esb.Font=Enum.Font.SourceSansBold; esb.Text="Egg Placement Priority"; esb.TextSize=16; esb.LayoutOrder=4; local c6=Instance.new("UICorner",esb); c6.CornerRadius=UDim.new(0,6)
    local svb=Instance.new("TextButton",sf); svb.Size=UDim2.new(0.9,0,0,35); svb.BackgroundColor3=Color3.fromRGB(80,120,200); svb.TextColor3=Color3.fromRGB(255,255,255); svb.Font=Enum.Font.SourceSansBold; svb.Text="Save & Close"; svb.TextSize=16; svb.LayoutOrder=5; local c7=Instance.new("UICorner",svb); c7.CornerRadius=UDim.new(0,6)
    local pcm=Instance.new("Frame",gui); pcm.Size=UDim2.new(0,200,0,250); pcm.Position=UDim2.new(0.5,-100,0.5,-125); pcm.BackgroundColor3=Color3.fromRGB(55,55,55); pcm.BorderColor3=Color3.fromRGB(150,150,150); pcm.BorderSizePixel=2; pcm.Visible=false
    local pct=Instance.new("TextLabel",pcm); pct.Size=UDim2.new(1,0,0,30); pct.Text="Pet Categories"; pct.BackgroundColor3=Color3.fromRGB(70,70,70); pct.TextColor3=Color3.fromRGB(255,255,255); pct.Font=Enum.Font.SourceSansBold; pct.TextSize=16
    local pcs=Instance.new("ScrollingFrame",pcm); pcs.Size=UDim2.new(1,0,1,-75); pcs.Position=UDim2.new(0,0,0,30); pcs.BackgroundColor3=Color3.fromRGB(55,55,55); pcs.BorderSizePixel=0; pcs.ScrollBarImageColor3=Color3.fromRGB(120,120,120); pcs.ScrollBarThickness=6
    local pcl=Instance.new("UIListLayout",pcs); pcl.Padding=UDim.new(0,5); pcl.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local sm={}; for n,l in pairs(M.petCats) do
        local f=Instance.new("Frame",gui); f.Size=UDim2.new(0,200,0,250); f.Position=UDim2.new(0.5,-100,0.5,-125); f.BackgroundColor3=Color3.fromRGB(55,55,55); f.BorderColor3=Color3.fromRGB(150,150,150); f.BorderSizePixel=2; f.Visible=false
        local t=Instance.new("TextLabel",f); t.Size=UDim2.new(1,0,0,30); t.Text=n; t.BackgroundColor3=Color3.fromRGB(70,70,70); t.TextColor3=Color3.fromRGB(255,255,255); t.Font=Enum.Font.SourceSansBold; t.TextSize=16
        local s=Instance.new("ScrollingFrame",f); s.Size=UDim2.new(1,0,1,-75); s.Position=UDim2.new(0,0,0,30); s.BackgroundColor3=Color3.fromRGB(55,55,55); s.BorderSizePixel=0; s.ScrollBarImageColor3=Color3.fromRGB(120,120,120); s.ScrollBarThickness=6
        local sl=Instance.new("UIListLayout",s); sl.Padding=UDim.new(0,5); sl.SortOrder=Enum.SortOrder.LayoutOrder; sl.HorizontalAlignment=Enum.HorizontalAlignment.Center
        local ch=5; for _,pn in ipairs(l) do
            local b=Instance.new("TextButton",s); b.Size=UDim2.new(0.9,0,0,28); b.Font=Enum.Font.SourceSansBold; b.TextSize=14
            local function u() if M.cfg.sell[pn] then b.Text=pn..": ON"; b.BackgroundColor3=Color3.fromRGB(20,140,70) else b.Text=pn..": OFF"; b.BackgroundColor3=Color3.fromRGB(190,40,40) end end
            b.MouseButton1Click:Connect(function() M.cfg.sell[pn]=not M.cfg.sell[pn]; u() end); u(); ch=ch+33
        end; s.CanvasSize=UDim2.new(0,0,0,ch)
        local bb=Instance.new("TextButton",f); bb.Size=UDim2.new(0.9,0,0,35); bb.Position=UDim2.new(0.05,0,1,-40); bb.BackgroundColor3=Color3.fromRGB(100,100,100); bb.TextColor3=Color3.fromRGB(255,255,255); bb.Font=Enum.Font.SourceSansBold; bb.Text="Back"; bb.TextSize=16
        bb.MouseButton1Click:Connect(function() f.Visible=false; pcm.Visible=true end); sm[n]=f
    end
    for n,_ in pairs(M.petCats) do local b=Instance.new("TextButton",pcs); b.Size=UDim2.new(0.9,0,0,30); b.Text=n; b.BackgroundColor3=Color3.fromRGB(80,80,80); b.MouseButton1Click:Connect(function() pcm.Visible=false; sm[n].Visible=true end) end
    local cbb=Instance.new("TextButton",pcm); cbb.Size=UDim2.new(0.9,0,0,35); cbb.Position=UDim2.new(0.05,0,1,-40); cbb.BackgroundColor3=Color3.fromRGB(100,100,100); cbb.TextColor3=Color3.fromRGB(255,255,255); cbb.Font=Enum.Font.SourceSansBold; cbb.Text="Back"; cbb.TextSize=16
    cbb.MouseButton1Click:Connect(function() pcm.Visible=false; sf.Visible=true end)
    local ef=Instance.new("Frame",gui); ef.Size=UDim2.new(0,220,0,320); ef.Position=UDim2.new(0.5,-110,0.5,-160); ef.BackgroundColor3=Color3.fromRGB(55,55,55); ef.BorderColor3=Color3.fromRGB(150,150,150); ef.BorderSizePixel=2; ef.Visible=false
    local et=Instance.new("TextLabel",ef); et.Size=UDim2.new(1,0,0,30); et.Text="Egg Placement Priority"; et.BackgroundColor3=Color3.fromRGB(70,70,70); et.TextColor3=Color3.fromRGB(255,255,255); et.Font=Enum.Font.SourceSansBold; et.TextSize=16
    local tcl=Instance.new("TextLabel",ef); tcl.Size=UDim2.new(0.9,0,0,20); tcl.Position=UDim2.new(0.05,0,0,35); tcl.Text="Target Egg Count:"; tcl.BackgroundColor3=Color3.fromRGB(55,55,55); tcl.TextColor3=Color3.fromRGB(220,220,220); tcl.Font=Enum.Font.SourceSans; tcl.TextSize=14; tcl.TextXAlignment=Enum.TextXAlignment.Left
    local tci=Instance.new("TextBox",ef); tci.Size=UDim2.new(0.9,0,0,30); tci.Position=UDim2.new(0.05,0,0,55); tci.BackgroundColor3=Color3.fromRGB(40,40,40); tci.TextColor3=Color3.fromRGB(255,255,255); tci.Font=Enum.Font.SourceSansBold; tci.TextSize=14; tci.Text=tostring(M.cfg.targetCount)
    local es=Instance.new("ScrollingFrame",ef); es.Size=UDim2.new(1,0,1,-130); es.Position=UDim2.new(0,0,0,90); es.BackgroundColor3=Color3.fromRGB(55,55,55); es.BorderSizePixel=0; es.ScrollBarImageColor3=Color3.fromRGB(120,120,120); es.ScrollBarThickness=6
    local el=Instance.new("UIListLayout",es); el.Padding=UDim.new(0,5); el.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local function redraw() for _,v in ipairs(es:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end; local h=5
        for i,n in ipairs(M.cfg.priority) do
            local f=Instance.new("Frame",es); f.Size=UDim2.new(0.9,0,0,30); f.BackgroundColor3=Color3.fromRGB(40,40,40)
            local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-60,1,0); l.Text=i..". "..n; l.BackgroundColor3=Color3.fromRGB(40,40,40); l.TextColor3=Color3.fromRGB(255,255,255); l.Font=Enum.Font.SourceSans; l.TextSize=14; l.TextXAlignment=Enum.TextXAlignment.Left
            local u=Instance.new("TextButton",f); u.Size=UDim2.new(0,25,1,0); u.Position=UDim2.new(1,-55,0,0); u.Text="▲"; u.BackgroundColor3=Color3.fromRGB(80,80,80)
            local d=Instance.new("TextButton",f); d.Size=UDim2.new(0,25,1,0); d.Position=UDim2.new(1,-25,0,0); d.Text="▼"; d.BackgroundColor3=Color3.fromRGB(80,80,80)
            u.MouseButton1Click:Connect(function() if i>1 then local t=M.cfg.priority[i]; M.cfg.priority[i]=M.cfg.priority[i-1]; M.cfg.priority[i-1]=t; redraw() end end)
            d.MouseButton1Click:Connect(function() if i<#M.cfg.priority then local t=M.cfg.priority[i]; M.cfg.priority[i]=M.cfg.priority[i+1]; M.cfg.priority[i+1]=t; redraw() end end)
            h=h+35
        end; es.CanvasSize=UDim2.new(0,0,0,h)
    end
    local esv=Instance.new("TextButton",ef); esv.Size=UDim2.new(0.9,0,0,35); esv.Position=UDim2.new(0.05,0,1,-40); esv.BackgroundColor3=Color3.fromRGB(80,120,200); esv.TextColor3=Color3.fromRGB(255,255,255); esv.Font=Enum.Font.SourceSansBold; esv.Text="Save & Close"; esv.TextSize=16
    esv.MouseButton1Click:Connect(function() local n=tonumber(tci.Text); if n then M.cfg.targetCount=n end; M:Save(); ef.Visible=false; sf.Visible=true; M.checkEggs=true end)
    petBtn.MouseButton1Click:Connect(function() sf.Visible=not sf.Visible end)
    svb.MouseButton1Click:Connect(function() local n=tonumber(wi.Text); if n then M.cfg.maxWeight=n end; M:Save(); sf.Visible=false; M:SellPets() end)
    spb.MouseButton1Click:Connect(function() sf.Visible=false; pcm.Visible=true end)
    esb.MouseButton1Click:Connect(function() sf.Visible=false; redraw(); ef.Visible=true end)
    btn.MouseButton1Click:Connect(function() M:Toggle() end)
    rst.MouseButton1Click:Connect(function() M:ResetConfig() end)
end
function M:Toggle()
    self.enabled=not self.enabled; self:UpdateState(); self:UpdateVis()
    if self.enabled then self:Save(); self.thread=task.spawn(function() self:Loop() end)
    else if self.thread then task.cancel(self.thread); self.thread=nil end; self:Save() end
end
function M:ResetConfig()
    print("Resetting config file...")
    pcall(function() writefile(self.CFG_FILE,self.HttpService:JSONEncode({})) end)
    print("✅ Config cleared. Please restart or toggle.")
    if self.enabled then self.enabled=false; if self.thread then task.cancel(self.thread); self.thread=nil end; self:UpdateState(); self:UpdateVis() end
end
if M.PlayerGui:FindFirstChild("CombinedFarmCraftGui") then M.PlayerGui.CombinedFarmCraftGui:Destroy() end
M:Load()
M:Create()
M:UpdateState()
M:UpdateVis()
if M.enabled then M.thread=task.spawn(function() M:Loop() end) end
print("Combined Auto-Farm & Crafter (Final) loaded.")
end
