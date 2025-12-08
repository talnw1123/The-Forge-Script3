local Shared = _G.Shared

-- QUEST 7: "Forging Under Pressure!" - SMART SYSTEM (FIXED VERSION)
-- ✅ Priority: Purchase → Kill → Mine → Forge
-- ✅ Sell System: Check from UI (supports Pickaxe Name + Weapon/Armor GUID)
-- ✅ Sell everything not Equipped (including Pickaxe)
-- ✅ FIXED: Close Forge UI after Forge is complete (like Quest 3)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest7Active = true
local IsMiningActive = false
local IsKillingActive = false
local IsForgingActive = false

local QUEST_CONFIG = {
    QUEST_NAME = "Forging Under Pressure",
    PICKAXE_NAME = "Iron Pickaxe",
    PICKAXE_AMOUNT = 1,
    NPC_POSITION = Vector3.new(-81.03, 28.51, 84.68),
    ZOMBIE_UNDERGROUND_OFFSET = 6,
    ZOMBIE_MAX_DISTANCE = 50,
    REQUIRED_ORE_COUNT = 3,
    ITEM_TYPE = "Armor",
    FORGE_DELAY = 2,
    FORGE_POSITION = Vector3.new(-192.3, 29.5, 168.1),
    ROCK_NAME = "Pebble",
    UNDERGROUND_OFFSET = 4,
    MIN_ORES_FOR_FORGE = 10,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    SELL_NPC_NAME = "Marbles",
    SELL_NPC_POSITION = Vector3.new(49.84, 29.17, 85.84),
    PRIORITY_ORDER = {"Purchase", "Kill", "Mine", "Forge"},
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CharacterService = nil
local PlayerController = nil
local ProximityService = nil
local ForgeService = nil
local DialogueService = nil
local UIController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    ForgeService = Knit.GetService("ForgeService")
    DialogueService = Knit.GetService("DialogueService")
end)

local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
                break
            end
        end
    end
end)

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

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_RF = nil
pcall(function()
    PURCHASE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local PROXIMITY_RF = nil
pcall(function()
    PROXIMITY_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Forge", 3)
end)

local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")
local LIVING_FOLDER = Workspace:WaitForChild("Living")

local FORGE_OBJECT = nil
pcall(function()
    FORGE_OBJECT = Workspace:WaitForChild("Proximity", 5):WaitForChild("Forge", 3)
end)

if CharacterService then print("✅ CharacterService Ready!") else warn("⚠️ CharacterService not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ToolController then print("✅ ToolController Ready!") else warn("⚠️ ToolController not found") end
if ForgeService then print("✅ ForgeService Ready!") else warn("⚠️ ForgeService not found") end
if DialogueService then print("✅ DialogueService Ready!") else warn("⚠️ DialogueService not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if UIController then print("✅ UIController Ready!") else warn("⚠️ UIController not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end
if FORGE_OBJECT then print("✅ Forge Object Ready!") else warn("⚠️ Forge Object not found") end

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
    currentObjectiveFrame = nil,
}

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    State.currentTarget = nil
    State.targetDestroyed = false
    
    if ToolController then
        ToolController.holdingM1 = false
    end
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

local function isObjectiveComplete(item)
    if not item then return false end
    local check = item:FindFirstChild("Main") and item.Main:FindFirstChild("Frame") and item.Main.Frame:FindFirstChild("Check")
    return check and check.Visible
end

local function getObjectiveText(item)
    local lbl = item:FindFirstChild("Main") and item.Main:FindFirstChild("TextLabel")
    return lbl and lbl.Text or ""
end

local function isQuest7StillActive()
    if not Quest7Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest7Active = false
        return false
    end
    
    return true
end

local function isCurrentObjectiveComplete()
    if State.currentObjectiveFrame then
        return isObjectiveComplete(State.currentObjectiveFrame)
    end
    return false
end

local function getObjectiveType(text)
    if string.find(text, "Purchase") or string.find(text, "Buy") or string.find(text, "Pickaxe") then
        return "Purchase"
    elseif string.find(text, "Kill") or string.find(text, "Zombie") or string.find(text, "Defeat") then
        return "Kill"
    elseif string.find(text, "Get Ore") or string.find(text, "Mine") or string.find(text, "Pebble") then
        return "Mine"
    elseif string.find(text, "Forge") or string.find(text, "forge") or string.find(text, "Item") then
        return "Forge"
    else
        return "Unknown"
    end
end

----------------------------------------------------------------
-- INVENTORY SYSTEM
----------------------------------------------------------------
local function getPlayerInventory()
    local inventory = {}
    
    if not PlayerController or not PlayerController.Replica then
        warn("PlayerController/Replica not available!")
        return inventory
    end
    
    local replica = PlayerController.Replica
    if replica and replica.Data and replica.Data.Inventory then
        for itemName, amount in pairs(replica.Data.Inventory) do
            if type(amount) == "number" and amount > 0 then
                inventory[itemName] = amount
            end
        end
    end
    
    return inventory
end

local function getAvailableOres()
    local inventory = getPlayerInventory()
    local ores = {}
    
    local oreTypes = {"Copper", "Stone", "Iron", "Sand Stone", "Tin", "Cardboardite", "Silver", "Gold", "Bananite", "Mushroomite", "Platinum", "Aite","Poopite"}
    
    for _, oreName in ipairs(oreTypes) do
        if inventory[oreName] and inventory[oreName] > 0 then
            table.insert(ores, {Name = oreName, Amount = inventory[oreName]})
        end
    end
    
    if #ores == 0 then
        for itemName, amount in pairs(inventory) do
            if string.find(itemName, "Ore") or string.find(itemName, "ore") then
                table.insert(ores, {Name = itemName, Amount = amount})
            end
        end
    end
    
    return ores
end

function getTotalOreCount()
    local ores = getAvailableOres()
    local total = 0
    for _, ore in ipairs(ores) do
        total = total + ore.Amount
    end
    return total
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
    print("📦 INVENTORY CHECK:")
    local ores = getAvailableOres()
    
    if #ores == 0 then
        warn("   ❌ No ores found in inventory!")
        local inv = getPlayerInventory()
        if next(inv) then
            print("   📋 All items in inventory:")
            for item, amount in pairs(inv) do
                print(string.format("      - %s: %d", item, amount))
            end
        else
            warn("   ⚠️ Inventory is completely empty!")
        end
        return
    end
    
    print("   💎 Available Ores:")
    local total = 0
    for _, ore in ipairs(ores) do
        print(string.format("      - %s: %d", ore.Name, ore.Amount))
        total = total + ore.Amount
    end
    print(string.format("   📊 Total: %d ores", total))
    print("   " .. string.rep("-", 28))
end

local function canDoObjective(objType)
    if objType == "Forge" then
        local totalOres = getTotalOreCount()
        if totalOres < QUEST_CONFIG.REQUIRED_ORE_COUNT then
            print(string.format("⏸️  Cannot Forge: Only %d/%d ores available", totalOres, QUEST_CONFIG.REQUIRED_ORE_COUNT))
            return false
        end
    end
    return true
end

----------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero
}

local function pressKey(keyCode)
    if not keyCode then return end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function findPickaxeSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and string.find(label.Text, "Pickaxe") then
                return HOTKEY_MAP[slotFrame.Name]
            end
        end
    end
    
    return nil
end

local function findWeaponSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local hotbar = gui:FindFirstChild("BackpackGui") and gui.BackpackGui:FindFirstChild("Backpack") and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and not string.find(label.Text, "Pickaxe") and label.Text ~= "" then
                return HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end
    
    return nil, nil
end

local function checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local notif = gui:FindFirstChild("Notifications")
    if notif and notif:FindFirstChild("Screen") and notif.Screen:FindFirstChild("NotificationsFrame") then
        for _, child in ipairs(notif.Screen.NotificationsFrame:GetChildren()) do
            local lbl = child:FindFirstChild("TextLabel", true)
            if lbl and string.find(lbl.Text, "Someone else is already mining") then
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- ROCK HELPERS
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then return nil end
    
    local pivotCFrame = nil
    pcall(function()
        if rockModel.GetPivot then
            pivotCFrame = rockModel:GetPivot()
        elseif rockModel.WorldPivot then
            pivotCFrame = rockModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getRockHP(rock)
    if not rock or not rock.Parent then return 0 end
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then return false end
    if not rock:FindFirstChildWhichIsA("BasePart") then return false end
    local hp = getRockHP(rock)
    return hp > 0
end

local function findNearestRock()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetRock, minDist = nil, math.huge
    
    for _, folder in ipairs(MINING_FOLDER_PATH:GetChildren()) do
        if folder:IsA("Folder") or folder:IsA("Model") then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(QUEST_CONFIG.ROCK_NAME)
                    if isTargetValid(rock) then
                        local pos = getRockUndergroundPosition(rock)
                        if pos then
                            local dist = (pos - hrp.Position).Magnitude
                            if dist < minDist then
                                minDist = dist
                                targetRock = rock
                            end
                        end
                    end
                end
            end
        end
    end
    
    return targetRock, minDist
end

local function watchRockHP(rock)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        print(string.format("💥 HP Changed! New HP: %d", hp))
        if hp == 0 then
            print("✅ HP = 0 detected! Switching target...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            Shared.SoftUnlockPosition()
        end
    end)
end

----------------------------------------------------------------
-- ZOMBIE HELPERS
----------------------------------------------------------------
local function getZombieUndergroundPosition(zombieModel)
    if not zombieModel or not zombieModel.Parent then return nil end
    
    local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.ZOMBIE_UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

local function getZombieHP(zombie)
    if not zombie or not zombie.Parent then return 0 end
    local humanoid = zombie:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.Health or 0
    end
    return 0
end

local function isZombieValid(zombie)
    if not zombie or not zombie.Parent then return false end
    return getZombieHP(zombie) > 0
end

local function findNearestZombie()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetZombie, minDist = nil, math.huge
    
    for _, child in ipairs(LIVING_FOLDER:GetChildren()) do
        -- ✅ เอาเฉพาะชื่อแนว "Zombie1234" เท่านั้น (ไม่เอา EliteZombie)
        if string.match(child.Name, "^Zombie%d+$") then
            if isZombieValid(child) then
                local pos = getZombieUndergroundPosition(child)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetZombie = child
                    end
                end
            end
        end
    end
    
    return targetZombie, minDist
end


local function watchZombieHP(zombie)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not zombie then return end
    
    local humanoid = zombie:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    State.hpWatchConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local hp = humanoid.Health or 0
        print(string.format("💥 HP Changed! New HP: %.1f", hp))
        if hp == 0 then
            print("✅ Zombie died! Switching target...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            Shared.SoftUnlockPosition()
        end
    end)
end

local function getBestWeapon()
    if not PlayerController or not PlayerController.Replica then return nil end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        return nil
    end
    
    local equipments = replica.Data.Inventory.Equipments
    local bestWeapon = nil
    local highestDmg = 0
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type then
            if not string.find(item.Type, "Pickaxe") then
                local dmg = item.Dmg or 0
                if dmg > highestDmg then
                    highestDmg = dmg
                    bestWeapon = item
                end
            end
        end
    end
    
    return bestWeapon
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
    Shared.restoreCollisions()
end

local function smoothMoveTo(targetPos, callback)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    enableNoclip()
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    State.bodyVelocity = bv
    
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
        
        local speed = math.min(QUEST_CONFIG.MOVE_SPEED, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- POSITION LOCK
----------------------------------------------------------------
local function lockPositionLayingDown(targetPos)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    print("🔒 Position locked (laying down)")
end

local function lockPositionFollowTarget(targetModel)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetModel then return end
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        if not targetModel or not targetModel.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end
        
        local targetPos = getZombieUndergroundPosition(targetModel)
        if targetPos then
            local baseCFrame = CFrame.new(targetPos)
            local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
            
            hrp.CFrame = layingCFrame
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    
    print("🔒 Position locked (following target)")
end

local function unlockPosition()
    Shared.SoftUnlockPosition()
end

----------------------------------------------------------------
-- SELL SYSTEM (FIXED - เช็คจาก UI แทน Replica)
----------------------------------------------------------------
local function getEquippedItemsFromUI()
    local equipped = {}
    
    print("   🔍 Checking equipped items from UI...")
    
    -- เช็คจาก PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame
    local menuUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Tools")
                   and playerGui.Menu.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not menuUI then
        warn("   ⚠️ Menu UI not found!")
        return equipped
    end
    
    for _, child in ipairs(menuUI:GetChildren()) do
        local equipButton = child:FindFirstChild("Equip")
        local equipLabel = equipButton and equipButton:FindFirstChild("TextLabel")
        
        if equipLabel and equipLabel:IsA("TextLabel") then
            local isEquipped = (equipLabel.Text == "Unequip")
            
            if isEquipped then
                -- child.Name อาจเป็น GUID หรือ ชื่อ Pickaxe
                local identifier = child.Name
                equipped[identifier] = true
                
                print(string.format("      ✅ Equipped: %s (UI)", identifier))
            end
        end
    end
    
    return equipped
end

local function getSellableItems()
    if not PlayerController or not PlayerController.Replica then
        return {}
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        return {}
    end
    
    local sellable = {}
    
    -- ✅ เช็ค Equipped จาก UI แทน Replica
    local equippedItems = getEquippedItemsFromUI()
    
    for id, item in pairs(replica.Data.Inventory.Equipments) do
        if type(item) == "table" and item.Type then
            local isPickaxe = string.find(item.Type, "Pickaxe")
            
            -- ✅ เช็คจาก UI (ทั้ง GUID และ Type/Name)
            local isEquipped = false
            
            -- 1. เช็คจาก GUID
            if item.GUID and equippedItems[item.GUID] then
                isEquipped = true
            end
            
            -- 2. เช็คจาก Type (สำหรับ Pickaxe ที่ใช้ชื่อแทน GUID)
            if equippedItems[item.Type] then
                isEquipped = true
            end
            
            -- 3. เช็คจาก Name
            if item.Name and equippedItems[item.Name] then
                isEquipped = true
            end
            
            -- ✅ ขายทุกอย่างที่ไม่ได้ Equipped (รวม Pickaxe ด้วย)
            if not isEquipped then
                -- Identifier: Pickaxe ใช้ Type, อื่นๆใช้ GUID
                local identifier = isPickaxe and item.Type or item.GUID
                
                table.insert(sellable, {
                    ID = id,
                    Identifier = identifier,
                    Type = item.Type,
                    Name = item.Name or item.Type,
                    Dmg = item.Dmg or 0,
                    IsPickaxe = isPickaxe
                })
            end
        end
    end
    
    return sellable
end

local function doSellUnequippedItems()
    print("💰 Selling Unequipped Items...")
    
    local sellableItems = getSellableItems()
    
    if #sellableItems == 0 then
        print("   ✅ No items to sell (all equipped)")
        return true
    end
    
    print(string.format("   📋 Found %d unequipped items to sell:", #sellableItems))
    for i, item in ipairs(sellableItems) do
        local idType = item.IsPickaxe and "Name" or "GUID"
        print(string.format("      %d. %s (%s: %s, Dmg: %d)", 
            i, item.Name, idType, item.Identifier, item.Dmg))
    end
    
    -- หา Sell NPC
    local proximity = Workspace:FindFirstChild("Proximity")
    local npc = proximity and (proximity:FindFirstChild(QUEST_CONFIG.SELL_NPC_NAME) or proximity:FindFirstChild("Greedy Cey"))
    
    if not npc then
        warn("   ❌ Sell NPC not found!")
        return false
    end
    
    if not ProximityService or not DialogueService then
        warn("   ❌ Required services not available!")
        return false
    end
    
    local soldCount = 0
    
    for _, item in ipairs(sellableItems) do
        print(string.format("   💰 Selling %s...", item.Name))
        
        -- 1. เปิด Dialogue
        local success1 = pcall(function()
            ProximityService:ForceDialogue(npc, "SellConfirm")
        end)
        
        if not success1 then
            warn("      ❌ Failed to open dialogue")
            continue
        end
        
        task.wait(0.2)
        
        -- 2. ส่ง Basket (ใช้ Identifier)
        local basket = {[item.Identifier] = true}
        
        local success2 = pcall(function()
            DialogueService:RunCommand("SellConfirm", {Basket = basket})
        end)
        
        if success2 then
            soldCount = soldCount + 1
            print(string.format("      ✅ Sold!"))
            task.wait(0.3)
        else
            warn(string.format("      ❌ Failed to sell %s", item.Name))
        end
        
        -- 3. Force restore UI
        pcall(function()
            local char = player.Character
            if char then
                local status = char:FindFirstChild("Status")
                if status then
                    for _, tag in ipairs(status:GetChildren()) do
                        if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                            tag:Destroy()
                        end
                    end
                end
            end
            
            local gui = player:FindFirstChild("PlayerGui")
            if gui then
                local dUI = gui:FindFirstChild("DialogueUI")
                if dUI then dUI.Enabled = false end
            end
        end)
        
        task.wait(0.5)
    end
    
    print(string.format("   ✅ Sell complete! Sold %d/%d items", soldCount, #sellableItems))
    
    -- Final restore
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    return true
end

----------------------------------------------------------------
-- UI MANAGEMENT
----------------------------------------------------------------
local function closeForgeUI()
    print("🔧 Closing Forge UI...")
    
    local closed = false
    
    if UIController and UIController.Close then
        pcall(function()
            if UIController.Modules and UIController.Modules.Forge then
                UIController:Close("Forge")
                print("   ✅ Closed via UIController")
                closed = true
            end
        end)
    end
    
    if not closed then
        pcall(function()
            local forgeGui = playerGui:FindFirstChild("Forge") or playerGui:FindFirstChild("ForgeUI")
            if forgeGui then
                forgeGui.Enabled = false
                print("   ✅ Closed via PlayerGui")
                closed = true
            end
        end)
    end
    
    if not closed then
        warn("   ⚠️ Could not close Forge UI (may already be closed)")
    end
    
    task.wait(0.3)
end

local function restoreUI()
    print("🔧 Restoring UI State...")
    
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    pcall(function() tag:Destroy() end)
                end
            end
        end
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
        
        local dialogueUI = gui:FindFirstChild("DialogueUI")
        if dialogueUI then dialogueUI.Enabled = false end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
    end
    
    print("✅ UI State restored!")
end

----------------------------------------------------------------
-- FORGE SYSTEM
----------------------------------------------------------------
getgenv().ForgeHookActive = getgenv().ForgeHookActive or false

local function setupForgeHook()
    if getgenv().ForgeHookActive then
        print("⚙️  Forge Hook already active")
        return
    end
    
    if not ForgeService then
        warn("❌ ForgeService not available!")
        return
    end
    
    print("🔧 Installing Forge Hook...")
    
    local originalChangeSequence = ForgeService.ChangeSequence
    
    ForgeService.ChangeSequence = function(self, sequenceName, args)
        print("🔨 Sequence: " .. sequenceName)
        
        local success, result = pcall(originalChangeSequence, self, sequenceName, args)
        
        task.spawn(function()
            if sequenceName == "Melt" then
                print("   ⏳ Auto Pouring in 8s...")
                task.wait(8)
                self:ChangeSequence("Pour", {ClientTime = 8.5, InContact = true})
            elseif sequenceName == "Pour" then
                print("   ⏳ Auto Hammering in 5s...")
                task.wait(5)
                self:ChangeSequence("Hammer", {ClientTime = 5.2})
            elseif sequenceName == "Hammer" then
                print("   ⏳ Auto Watering in 6s...")
                task.wait(6)
                self:ChangeSequence("Water", {ClientTime = 6.5})
            elseif sequenceName == "Water" then
                print("   ⏳ Auto Showcasing in 3s...")
                task.wait(3)
                self:ChangeSequence("Showcase", {})
            elseif sequenceName == "Showcase" then
                print("   ✅ Forge completed!")
                -- ✅ ไม่ปิด UI ที่นี่ (ให้ doForge() จัดการ)
            end
        end)
        
        return success, result
    end
    
    getgenv().ForgeHookActive = true
    print("✅ Forge Hook installed!")
end

local function moveToForge()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local forgePos = QUEST_CONFIG.FORGE_POSITION
    local currentDist = (forgePos - hrp.Position).Magnitude

    print(string.format("🚶 Moving to Forge at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
        forgePos.X, forgePos.Y, forgePos.Z, currentDist))

    -- 🆕 Unlock position before moving
    unlockPosition()

    local moveComplete = false
    smoothMoveTo(forgePos, function()
        moveComplete = true
    end)

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

    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end

    print("✅ Reached Forge!")
    print("   ⏳ Waiting 1.5s before opening Forge UI...")
    task.wait(1.5)

    return true
end


local function startForge(oreSelection)
    print("🔨 Starting Forge with:")
    for oreName, amount in pairs(oreSelection) do
        print(string.format("   - %s x%d", oreName, amount))
    end

    if not FORGE_OBJECT then
        warn("❌ Forge Object not found!")
        return false
    end

    pcall(function()
        PROXIMITY_RF:InvokeServer(FORGE_OBJECT)
    end)

    task.wait(1)

    if not ForgeService then return false end

    local forgeSuccess = pcall(function()
        ForgeService:ChangeSequence("Melt", {
            Ores = oreSelection,
            ItemType = QUEST_CONFIG.ITEM_TYPE,
            FastForge = false
        })
    end)

    if forgeSuccess then
        print("✅ Forge Melt started!")
        return true
    else
        return false
    end
end
----------------------------------------------------------------
-- OBJECTIVES
----------------------------------------------------------------
local function doPurchaseIronPickaxe()
    print("🛒 Objective 1: Purchasing Iron Pickaxe...")
    
    if not PURCHASE_RF then
        warn("   ❌ Purchase Remote not available!")
        return false
    end
    
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local npcPos = QUEST_CONFIG.NPC_POSITION
        local currentDist = (npcPos - hrp.Position).Magnitude
        
        print(string.format("   🚶 Moving to NPC at (%.2f, %.2f, %.2f) (%.1f studs away)...", 
            npcPos.X, npcPos.Y, npcPos.Z, currentDist))
        
        -- 🆕 Unlock position before moving
        unlockPosition()
        
        local moveComplete = false
        smoothMoveTo(npcPos, function()
            moveComplete = true
        end)
        
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
        
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        
        print("   ✅ Reached NPC!")
        print("   ⏳ Waiting 1.5s before purchase...")
        task.wait(1.5)
    end
    
    print(string.format("   💰 Purchasing %s (Amount: %d)", QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT))
    
    local args = {QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT}
    local success, result = pcall(function()
        return PURCHASE_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print("   ✅ Purchase successful!")
        return true
    else
        warn("   ❌ Purchase failed: " .. tostring(result))
        return false
    end
end

local function doMinePebble()
    print("⛏️  Objective 4: Mining Pebble...")
    
    IsMiningActive = true
    
    print("   " .. string.rep("-", 30))
    print("   🔄 Starting Pebble mining loop...")
    print("   " .. string.rep("-", 30))
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ Waiting for character...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetRock, dist = findNearestRock()
        if not targetRock then
            warn("   ⚠️ No Pebble found, waiting...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        if not targetPos then
            warn("   ⚠️ Cannot get pebble position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        print(string.format("   🎯 Target: %s (dist: %d, HP: %d)", targetRock.Parent.Name, math.floor(dist), currentHP))
        
        watchRockHP(targetRock)
        
        -- 🆕 Unlock position before moving
        unlockPosition()
        
        local moveStarted = false
        smoothMoveTo(targetPos, function()
            lockPositionLayingDown(targetPos)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        if not moveStarted then
            lockPositionLayingDown(targetPos)
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest7StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   ⚠️ Character died!")
                break
            end
            
            if not targetRock or not targetRock.Parent then
                print("   ⚠️ Target removed!")
                State.targetDestroyed = true
                break
            end
            
            if checkMiningError() then
                print("   ⚠️ Someone else mining!")
                State.targetDestroyed = true
                if ToolController then ToolController.holdingM1 = false end
                break
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")
            
            if not isPickaxeHeld then
                if ToolController then ToolController.holdingM1 = false end
                
                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        CHAR_RF:InvokeServer({Runes = {}}, {Name = QUEST_CONFIG.PICKAXE_NAME})
                    end)
                    task.wait(0.5)
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("   ✅ Objective 4 (Mine Pebble) Complete!")
            break
        end
        
        print("   🔄 Finding next target...")
        task.wait(0.5)
    end
    
    print("   ⛏️  Mining ended")
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doKillZombies()
    print("⚔️  Objective 2: Killing Zombies...")
    
    IsKillingActive = true
    
    print("   " .. string.rep("-", 30))
    print("   🔄 Starting Zombie hunting loop...")
    print("   " .. string.rep("-", 30))
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            warn("   ⚠️ Waiting for character...")
            task.wait(2)
            continue
        end
        
        cleanupState()
        
        local targetZombie, dist = findNearestZombie()
        if not targetZombie then
            warn("   ⚠️ No Zombies found, waiting...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetZombie
        State.targetDestroyed = false
        
        local targetPos = getZombieUndergroundPosition(targetZombie)
        if not targetPos then
            warn("   ⚠️ Cannot get zombie position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getZombieHP(targetZombie)
        print(string.format("   🎯 Target: %s (dist: %d, HP: %.1f)", targetZombie.Name, math.floor(dist), currentHP))
        
        watchZombieHP(targetZombie)
        
        -- 🆕 Unlock position before moving
        unlockPosition()
        
        local moveStarted = false
        smoothMoveTo(targetPos, function()
            lockPositionFollowTarget(targetZombie)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        -- ❌ อย่า hard-lock ถ้าไม่เคยเดินถึงเป้าหมาย
        if not moveStarted then
            warn("   ⚠️ Move timeout, skip this zombie to avoid teleport")
            State.targetDestroyed = true
            unlockPosition()
            continue
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest7StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   ⚠️ Character died!")
                break
            end
            
            if not targetZombie or not targetZombie.Parent or not isZombieValid(targetZombie) then
                print("   ⚠️ Target removed or died!")
                State.targetDestroyed = true
                unlockPosition()  
                break
            end
            
            local currentZombiePos = getZombieUndergroundPosition(targetZombie)
            if currentZombiePos and hrp then
                local distToZombie = (currentZombiePos - hrp.Position).Magnitude
                if distToZombie > QUEST_CONFIG.ZOMBIE_MAX_DISTANCE then
                    print(string.format("   ⚠️ Zombie moved too far! (%.1f studs) Switching target...", distToZombie))
                    State.targetDestroyed = true
                    unlockPosition()
                    break
                end
            end
            
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isWeaponHeld = toolInHand and not string.find(toolInHand.Name, "Pickaxe")
            
            if not isWeaponHeld then
                if ToolController then ToolController.holdingM1 = false end
                
                local bestWeapon = getBestWeapon()
                if bestWeapon then
                    print(string.format("   ⚔️  Equipping weapon: %s", bestWeapon.Type))
                    pcall(function()
                        CharacterService:EquipItem(bestWeapon)
                    end)
                    task.wait(0.5)
                else
                    local key, weaponName = findWeaponSlotKey()
                    if key then
                        print(string.format("   ⚔️  Equipping via hotkey: %s", weaponName))
                        pressKey(key)
                        task.wait(0.3)
                    else
                        warn("   ❌ No weapon found!")
                        task.wait(1)
                    end
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("   ✅ Objective 2 (Kill Zombies) Complete!")
            break
        end
        
        print("   🔄 Finding next target...")
        task.wait(0.5)
    end
    
    print("   ⚔️  Zombie hunting ended")
    IsKillingActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doForge()
    print("🔨 Objective 3: Forging Armor...")
    
    IsForgingActive = true
    
    print("\n" .. string.rep("=", 50))
    print("📋 Step 1: Selling Unequipped Items")
    print(string.rep("=", 50))
    
    doSellUnequippedItems()
    
    print("\n" .. string.rep("=", 50))
    print("🔨 Step 2: Starting Forge")
    print(string.rep("=", 50))
    
    setupForgeHook()
    moveToForge()
    
    local forgeAttempts = 0
    
    while isQuest7StillActive() and not isCurrentObjectiveComplete() do
        forgeAttempts = forgeAttempts + 1
        print(string.format("\n🔨 Forge Attempt #%d", forgeAttempts))
        
        printInventorySummary()
        
        local totalOres = getTotalOreCount()
        if totalOres < QUEST_CONFIG.REQUIRED_ORE_COUNT then
            warn(string.format("❌ Not enough ores! Have %d, need %d", totalOres, QUEST_CONFIG.REQUIRED_ORE_COUNT))
            warn("⚠️ This shouldn't happen - Mine objective should be done first!")
            break
        end
        
        local oreSelection, errorMsg = selectRandomOres(QUEST_CONFIG.REQUIRED_ORE_COUNT)
        if not oreSelection then
            warn(string.format("❌ ERROR: %s", errorMsg))
            break
        end
        
        local success = startForge(oreSelection)
        if success then
            print("   ⏳ Waiting for forge to complete...")
            task.wait(27)
        else
            warn("   ❌ Forge failed, retrying in 3s...")
            task.wait(3)
        end
        
        if isCurrentObjectiveComplete() then
            print("   ✅ Objective 3 (Forge) Complete!")
            break
        end
        
        print(string.format("   ⏸️  Cooling down for %ds...", QUEST_CONFIG.FORGE_DELAY))
        task.wait(QUEST_CONFIG.FORGE_DELAY)
    end
    
    -- ✅ FIXED: เพิ่มการปิด UI (เหมือน Quest 3)
    print("\n🚪 Closing Forge UI...")
    closeForgeUI()
    task.wait(0.5)
    restoreUI()
    
    print("   🔨 Forging ended")
    IsForgingActive = false
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 7: " .. QUEST_CONFIG.QUEST_NAME)
print("⚙️  SMART SYSTEM: Priority-based + Flexible")
print("📋 Priority Order: Purchase → Kill → Mine → Forge")
print("💰 Sell System: เช็คจาก UI (Pickaxe Name + Weapon/Armor GUID)")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest7Active = false
    return
end

print("✅ Quest found (ID: " .. questID .. ")\n")

local objectives = {}
for _, item in ipairs(objList:GetChildren()) do
    if item:IsA("Frame") and tonumber(item.Name) then
        local text = getObjectiveText(item)
        local objType = getObjectiveType(text)
        table.insert(objectives, {
            order = tonumber(item.Name),
            frame = item,
            text = text,
            type = objType
        })
    end
end

table.sort(objectives, function(a, b)
    local function getPriority(type)
        for i, priorityType in ipairs(QUEST_CONFIG.PRIORITY_ORDER) do
            if string.find(type, priorityType) then
                return i
            end
        end
        return 999
    end
    return getPriority(a.type) < getPriority(b.type)
end)

print(string.rep("=", 50))
print("📋 Quest Objectives (Priority Order):")
for i, obj in ipairs(objectives) do
    local complete = isObjectiveComplete(obj.frame)
    print(string.format("   %d. [%s] %s %s", i, obj.type, obj.text, complete and "✅" or "⏳"))
end
print(string.rep("=", 50))


-- 🆕 helper: เช็คว่ามี Purchase ที่ยังไม่ complete อยู่ไหม
local function hasIncompletePurchase()
    for _, obj in ipairs(objectives) do
        if obj.type == "Purchase" and not isObjectiveComplete(obj.frame) then
            return true
        end
    end
    return false
end

local maxAttempts = 10
local attempt = 0

while isQuest7StillActive() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Quest Cycle #%d", attempt))
    
    local allComplete = true
    local didSomething = false
    local purchasePending = hasIncompletePurchase()
    
    for _, obj in ipairs(objectives) do
        if not isQuest7StillActive() then
            print("🛑 Quest disappeared!")
            break
        end
        
        local complete = isObjectiveComplete(obj.frame)
        
        if not complete then
            allComplete = false

            -- ⛔ ถ้า Purchase ยังไม่เสร็จ → ห้ามทำ Kill / Mine / Forge
            if purchasePending and obj.type ~= "Purchase" then
                print(string.format("⏭️  Skipping [%s] (waiting for Purchase to finish)", obj.type))
                continue
            end
            
            if not canDoObjective(obj.type) then
                print(string.format("⏸️  Skipping [%s] - Cannot do right now", obj.type))
                continue
            end
            
            State.currentObjectiveFrame = obj.frame
            
            print(string.format("\n▶️  Processing [%s]: %s", obj.type, obj.text))
            
            if obj.type == "Purchase" then
                doPurchaseIronPickaxe()
                didSomething = true
                task.wait(2)
                
                -- 🆕 Re-check if Purchase is complete after running
                if isObjectiveComplete(obj.frame) then
                    purchasePending = false
                    print("   ✅ Purchase objective complete! Continuing to other objectives...")
                end
            elseif obj.type == "Kill" then
                doKillZombies()
                didSomething = true
                task.wait(1)
            elseif obj.type == "Mine" then
                doMinePebble()
                didSomething = true
                task.wait(1)
            elseif obj.type == "Forge" then
                doForge()
                didSomething = true
                task.wait(1)
            else
                warn("❌ Unknown objective type: " .. obj.type)
            end
            
            task.wait(1)
            
            if isObjectiveComplete(obj.frame) then
                print(string.format("✅ [%s] Complete!", obj.type))
            else
                print(string.format("⏳ [%s] Still in progress", obj.type))
            end
        end
    end
    
    if allComplete then
        print("\n🎉 All objectives complete!")
        break
    end
    
    if not didSomething then
        warn("⚠️ No objectives could be completed this cycle!")
        print("   ⏳ Waiting 3s before retry...")
        task.wait(3)
    end
end

task.wait(2)

local allComplete = true
for _, obj in ipairs(objectives) do
    if not isObjectiveComplete(obj.frame) then
        allComplete = false
        warn(string.format("❌ [%s] incomplete: %s", obj.type, obj.text))
    end
end

if allComplete then
    print("\n" .. string.rep("=", 50))
    print("🏆 Quest 7 Complete!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 7 incomplete after " .. attempt .. " cycles")
    warn(string.rep("=", 50))
end

Quest7Active = false
IsMiningActive = false
IsKillingActive = false
IsForgingActive = false
unlockPosition()
disableNoclip()
cleanupState()
