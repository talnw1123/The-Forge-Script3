local Shared = _G.Shared

-- QUEST 6 ONLY: "Preparing For Battle!" (FIXED: smoothMoveTo + Lock Position)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest6Active = true

local FORGE_CONFIG = {
    REQUIRED_ORE_COUNT = 3,
    ITEM_TYPE = "Armor",
    FORGE_DELAY = 2,
    FORGE_POSITION = Vector3.new(-192.3, 29.5, 168.1),  -- 🆕 Fixed position
    MOVE_SPEED = 25,  
}

----------------------------------------------------------------
-- SERVICES & REMOTES
----------------------------------------------------------------
local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local PROXIMITY_RF = SERVICES:WaitForChild("ProximityService"):WaitForChild("RF"):WaitForChild("Forge")

local FORGE_OBJECT = Workspace:WaitForChild("Proximity"):WaitForChild("Forge")

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local ForgeController = nil
local ForgeService = nil
local PlayerController = nil
local UIController = nil

pcall(function()
    ForgeController = Knit.GetController("ForgeController")
    ForgeService = Knit.GetService("ForgeService")
    PlayerController = Knit.GetController("PlayerController")
end)

-- Hook UIController from getgc
pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Open") and rawget(v, "Close") and rawget(v, "Modules") then
                UIController = v
                break
            end
        end
    end
end)

if ForgeService then print("✅ ForgeService Ready!") else warn("⚠️ ForgeService not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if UIController then print("✅ UIController Ready!") else warn("⚠️ UIController not found") end

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    moveConn = nil,
    noclipConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function cleanupState()
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
end

----------------------------------------------------------------
-- NOCLIP & MOVEMENT
----------------------------------------------------------------
local function enableNoclip()
    if State.noclipConn then return end
    
    local char = player.Character
    if not char then return end
    
    State.noclipConn = RunService.Stepped:Connect(function()
        if not char or not char.Parent then
            if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
            return
        end
        
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    -- ✅ ปิด noclip แล้วคืนการชนให้ตัวละคร
    Shared.restoreCollisions()
end

-- 🆕 smoothMoveTo with BodyVelocity + BodyGyro
local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- Cleanup previous movement
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    -- Enable noclip
    enableNoclip()
    
    -- Create BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    -- Create BodyGyro
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    State.bodyGyro = bg
    
    print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
    local reachedTarget = false
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end
        
        -- Check if character or BodyVelocity is destroyed
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        -- Check if BodyVelocity was destroyed by game/other script
        if not bv or not bv.Parent then
            warn("   ⚠️ BodyVelocity destroyed! Recreating...")
            
            -- Recreate BodyVelocity
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            State.bodyVelocity = bv
        end
        
        if not bg or not bg.Parent then
            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.D = 500
            bg.Parent = hrp
            State.bodyGyro = bg
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 2 then
            print("   ✅ Reached target!")
            
            reachedTarget = true
            
            bv.Velocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            task.wait(0.1)
            
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(FORGE_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- UI MANAGEMENT
----------------------------------------------------------------
local function closeForgeUI()
    print("\n   🚪 Closing Forge UI...")
    
    local closed = false
    
    -- Method 1: UIController.Close
    if UIController and UIController.Close then
        pcall(function()
            if UIController.Modules and UIController.Modules["Forge"] then
                UIController:Close("Forge")
                print("      ✅ Closed via UIController")
                closed = true
            end
        end)
    end
    
    -- Method 2: ForgeController
    if not closed and ForgeController then
        pcall(function()
            if ForgeController.Close then
                ForgeController:Close()
                print("      ✅ Closed via ForgeController")
                closed = true
            elseif ForgeController.CloseForge then
                ForgeController:CloseForge()
                print("      ✅ Closed via ForgeController.CloseForge")
                closed = true
            end
        end)
    end
    
    -- Method 3: PlayerGui (direct UI close)
    if not closed then
        pcall(function()
            local forgeGui = playerGui:FindFirstChild("Forge") or playerGui:FindFirstChild("ForgeUI")
            if forgeGui then
                forgeGui.Enabled = false
                print("      ✅ Closed via PlayerGui")
                closed = true
            end
        end)
    end
    
    if not closed then
        warn("      ⚠️ Could not close Forge UI (may already be closed)")
    end
    
    task.wait(0.5)
end

----------------------------------------------------------------
-- QUEST SYSTEM
----------------------------------------------------------------
local function getQuestObjectives(questName)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil, nil end
    
    local questID = nil
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            if child.Frame.TextLabel.Text == questName then
                questID = id
                break
            end
        end
    end
    
    if not questID then return nil, nil end
    
    local objList = list:FindFirstChild("Introduction" .. questID .. "List")
    return questID, objList
end

local function isQuestComplete(questName)
    local questID, objList = getQuestObjectives(questName)
    
    if not questID or not objList then
        return true
    end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local check = item:FindFirstChild("Main") and item.Main:FindFirstChild("Frame") and item.Main.Frame:FindFirstChild("Check")
            if check and not check.Visible then
                return false
            end
        end
    end
    
    return true
end

local function isQuest6StillActive()
    if not Quest6Active then return false end
    
    if isQuestComplete("Preparing For Battle") then  -- ✅ แก้แล้ว
        print("🛑 Quest 'Preparing For Battle' completed!")  -- ✅ แก้แล้ว
        Quest6Active = false
        return false
    end
    
    local questID, objList = getQuestObjectives("Preparing For Battle")  -- ✅ แก้แล้ว
    if not questID or not objList then
        print("🛑 Quest 'Preparing For Battle' not found!")  -- ✅ แก้แล้ว
        Quest6Active = false
        return false
    end
    
    return true
end

----------------------------------------------------------------
-- INVENTORY SYSTEM
----------------------------------------------------------------
local function getPlayerInventory()
    local inventory = {}
    
    if not PlayerController then
        warn("   ⚠️ PlayerController not available!")
        return inventory
    end
    
    if not PlayerController.Replica then
        print("   ⏳ Waiting for Replica...")
        task.wait(2)
    end
    
    if not PlayerController.Replica then
        warn("   ❌ Replica still not available!")
        return inventory
    end
    
    local replica = PlayerController.Replica
    
    if replica and replica.Data and replica.Data.Inventory then
        print("   ✅ Reading from Replica.Data.Inventory")
        
        for itemName, amount in pairs(replica.Data.Inventory) do
            if type(amount) == "number" and amount > 0 then
                inventory[itemName] = amount
            end
        end
    else
        warn("   ❌ Replica.Data.Inventory not found!")
        
        if replica and replica.Data then
            print("   🔍 Available keys in Replica.Data:")
            for k, v in pairs(replica.Data) do
                print("      • " .. tostring(k) .. " = " .. tostring(type(v)))
            end
        end
    end
    
    return inventory
end

local function getAvailableOres()
    local inventory = getPlayerInventory()
    local ores = {}
    
    local oreTypes = {"Copper","Stone", "Iron","Sand Stone", "Tin", "Cardboardite", "Silver", "Gold", "Bananite", "Mushroomite", "Platinum","Aite","Poopite"}
    
    for _, oreName in ipairs(oreTypes) do
        if inventory[oreName] and inventory[oreName] > 0 then
            table.insert(ores, {Name = oreName, Amount = inventory[oreName]})
        end
    end
    
    if #ores == 0 then
        print("   🔍 Scanning all items for ores...")
        for itemName, amount in pairs(inventory) do
            if string.find(itemName, "Ore") or string.find(itemName, "ore") then
                table.insert(ores, {Name = itemName, Amount = amount})
            end
        end
    end
    
    return ores
end

local function selectRandomOres(count)
    local availableOres = getAvailableOres()
    
    if #availableOres == 0 then
        return nil, "No ores found in inventory!"
    end
    
    local totalOres = 0
    for _, ore in ipairs(availableOres) do
        totalOres = totalOres + ore.Amount
    end
    
    if totalOres < count then
        return nil, string.format("Not enough ores! Need %d, have %d", count, totalOres)
    end
    
    local orePool = {}
    for _, ore in ipairs(availableOres) do
        for i = 1, ore.Amount do
            table.insert(orePool, ore.Name)
        end
    end
    
    local selected = {}
    for i = 1, count do
        if #orePool == 0 then break end
        
        local randomIndex = math.random(1, #orePool)
        local oreName = table.remove(orePool, randomIndex)
        
        selected[oreName] = (selected[oreName] or 0) + 1
    end
    
    return selected, nil
end

local function printInventorySummary()
    print("\n   📦 === INVENTORY CHECK ===")
    
    local ores = getAvailableOres()
    
    if #ores == 0 then
        warn("   ❌ No ores found in inventory!")
        
        local inv = getPlayerInventory()
        if next(inv) then
            print("   📋 All items in inventory:")
            for item, amount in pairs(inv) do
                print(string.format("      • %s: %d", item, amount))
            end
        else
            warn("   ⚠️ Inventory is completely empty!")
        end
        return
    end
    
    print("   ✅ Available Ores:")
    local total = 0
    for _, ore in ipairs(ores) do
        print(string.format("      • %s: %d", ore.Name, ore.Amount))
        total = total + ore.Amount
    end
    print(string.format("      📊 Total: %d ores", total))
    print("   " .. string.rep("=", 28) .. "\n")
end

----------------------------------------------------------------
-- FORGE SYSTEM
----------------------------------------------------------------
getgenv().ForgeHookActive = getgenv().ForgeHookActive or false

local function setupForgeHook()
    if getgenv().ForgeHookActive then
        print("   ⚠️ Forge Hook already active")
        return
    end
    
    if not ForgeService then
        warn("   ❌ ForgeService not available!")
        return
    end
    
    print("   🪝 Installing Forge Hook...")
    local originalChangeSequence = ForgeService.ChangeSequence
    
    ForgeService.ChangeSequence = function(self, sequenceName, args)
        print("      🔄 Sequence: " .. sequenceName)
        
        local success, result = pcall(originalChangeSequence, self, sequenceName, args)
        
        task.spawn(function()
            if sequenceName == "Melt" then
                print("      ⏩ Auto: Pouring in 8s...")
                task.wait(8)
                self:ChangeSequence("Pour", {ClientTime = 8.5, InContact = true})
                
            elseif sequenceName == "Pour" then
                print("      ⏩ Auto: Hammering in 5s...")
                task.wait(5)
                self:ChangeSequence("Hammer", {ClientTime = 5.2})
                
            elseif sequenceName == "Hammer" then
                print("      ⏩ Auto: Watering in 6s...")
                task.wait(6)
                self:ChangeSequence("Water", {ClientTime = 6.5})
                
            elseif sequenceName == "Water" then
                print("      ⏩ Auto: Showcasing in 3s...")
                task.wait(3)
                self:ChangeSequence("Showcase", {})
                
            elseif sequenceName == "Showcase" then
                print("      ✅ Forge completed!")
            end
        end)
        
        return success, result
    end
    
    getgenv().ForgeHookActive = true
    print("   ✅ Forge Hook installed!")
end

-- 🆕 IMPROVED: Use smoothMoveTo with fixed position
local function moveToForge()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local forgePos = FORGE_CONFIG.FORGE_POSITION
    local currentDist = (forgePos - hrp.Position).Magnitude
    
    print(string.format("   🚶 Moving to Forge at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
        forgePos.X, forgePos.Y, forgePos.Z, currentDist))
    
    -- 🆕 Unlock position before moving
    Shared.SoftUnlockPosition()
    
    -- Use smoothMoveTo with noclip + lock position
    local moveComplete = false
    smoothMoveTo(forgePos, function()
        moveComplete = true
    end)
    
    -- Wait for movement to complete
    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ Move timed out! Retrying...")
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        return false
    end
    
    -- Cleanup movement
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    print("   ✅ Reached Forge!")
    
    -- Wait 1.5 seconds before opening UI
    print("   ⏸️  Waiting 1.5s before opening Forge UI...")
    task.wait(1.5)
    
    return true
end

local function startForge(oreSelection)
    print("   🔥 Starting Forge with:")
    for oreName, amount in pairs(oreSelection) do
        print(string.format("      • %s x%d", oreName, amount))
    end
    
    local success = pcall(function()
        PROXIMITY_RF:InvokeServer(FORGE_OBJECT)
    end)
    
    if not success then
        warn("   ❌ Failed to invoke Forge remote")
        return false
    end
    
    task.wait(1)
    
    if not ForgeService then
        warn("   ❌ ForgeService not available!")
        return false
    end
    
    local forgeSuccess = pcall(function()
        ForgeService:ChangeSequence("Melt", {
            Ores = oreSelection,
            ItemType = FORGE_CONFIG.ITEM_TYPE,
            FastForge = false
        })
    end)
    
    if forgeSuccess then
        print("   ✅ Forge Melt started!")
        return true
    else
        warn("   ⚠️ Could not start forge melt")
        return false
    end
end

local function doForgeLoop()
    print("🔥 Action: Auto Forging...")
    
    setupForgeHook()
    
    setupForgeHook()
    
    -- 🆕 Retry movement until successful
    while not moveToForge() do
        warn("   ⚠️ Failed to reach Forge, retrying in 2s...")
        task.wait(2)
    end
    
    local forgeCount = 0
    local consecutiveFailures = 0
    
    while isQuest6StillActive() do
        forgeCount = forgeCount + 1
        print(string.format("\n   🔨 Forge Attempt #%d", forgeCount))
        
        printInventorySummary()
        
        local oreSelection, errorMsg = selectRandomOres(FORGE_CONFIG.REQUIRED_ORE_COUNT)
        
        if not oreSelection then
            warn(string.format("\n❌ ERROR: %s", errorMsg))
            consecutiveFailures = consecutiveFailures + 1
            
            if consecutiveFailures >= 3 then
                warn("❌ Failed 3 times in a row. Cannot continue forging!")
                warn("💡 Please mine more ores and try again.")
                Quest6Active = false
                break
            end
            
            warn(string.format("⏳ Waiting 5s before retry... (%d/3 failures)", consecutiveFailures))
            task.wait(5)
            continue
        end
        
        consecutiveFailures = 0
        
        local success = startForge(oreSelection)
        
        if success then
            print("   ⏳ Waiting for forge to complete...")
            task.wait(25)
        else
            warn("   ⚠️ Forge failed, retrying in 3s...")
            task.wait(3)
        end
        
        if not isQuest6StillActive() then
            print("   ✅ Quest complete!")
            break
        end
        
        print(string.format("   ⏸️ Cooling down for %ds...", FORGE_CONFIG.FORGE_DELAY))
        task.wait(FORGE_CONFIG.FORGE_DELAY)
    end
    
    print("\n🛑 Quest 6 forging ended")
end

----------------------------------------------------------------
-- MAIN RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 6: Preparing For Battle")  -- ✅ เอา ! ออก
print(string.rep("=", 50))

local questID, objList = getQuestObjectives("Preparing For Battle")  -- ✅ แก้แล้ว

if not questID then
    warn("❌ Quest 'Preparing For Battle' not found!")  -- ✅ แก้แล้ว

    warn("💡 Make sure the quest is active in your quest log.")
    Quest6Active = false
    return
end

print("✅ Quest found (ID: " .. questID .. ")")

print("\n" .. string.rep("=", 50))
print("🔥 Starting Forge Sequence...")
print(string.rep("=", 50))

doForgeLoop()

closeForgeUI()

if Quest6Active == false and not isQuestComplete("Preparing For Battle!") then
    warn("\n" .. string.rep("=", 50))
    warn("❌ Quest 6 Failed!")
    warn("Reason: Not enough ores to continue")
    warn(string.rep("=", 50))
else
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 6 Complete!")
    print(string.rep("=", 50))
end

Quest6Active = false
disableNoclip()
cleanupState()
