local Shared = _G.Shared

-- QUEST 5: "New Pickaxe!" (SMART SYSTEM: Priority-based + Flexible + Dynamic Zombie Tracking)
-- Priority Order: 1) Purchase → 2) Kill Zombies → 3) Mine Rocks

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
local Quest5Active = true
local IsMiningActive = false
local IsKillingActive = false

local QUEST_CONFIG = {
    QUEST_NAME = "New Pickaxe!",
    PICKAXE_NAME = "Bronze Pickaxe",
    PICKAXE_AMOUNT = 1,
    NPC_POSITION = Vector3.new(-81.03, 28.51, 84.68),
    MINING_PATH = "Island1CaveMid",
    ROCK_NAME = "Rock",
    STARTING_POSITION = Vector3.new(50, -10, -200),
    UNDERGROUND_OFFSET = 4,
    ZOMBIE_UNDERGROUND_OFFSET = 5,
    ZOMBIE_MAX_DISTANCE = 50,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,  
    
    -- 🔥 NEW: Priority Order
    PRIORITY_ORDER = {
        "Purchase",   -- 1. ซื้อ Pickaxe ก่อน
        "Kill",       -- 2. ฆ่า Zombie
        "Mine",       -- 3. ขุดแร่ (สุดท้าย)
    }
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

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
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

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local PURCHASE_RF = SERVICES:WaitForChild("ProximityService"):WaitForChild("RF"):WaitForChild("Purchase")
local CHAR_RF = SERVICES:WaitForChild("CharacterService"):WaitForChild("RF"):WaitForChild("EquipItem")
local TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService"):WaitForChild("RF"):WaitForChild("ToolActivated")

local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")
local LIVING_FOLDER = Workspace:WaitForChild("Living")

if CharacterService then print("✅ CharacterService Ready!") else warn("⚠️ CharacterService not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if ToolController then print("✅ ToolController Ready!") else warn("⚠️ ToolController not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end

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
    if ToolController then ToolController.holdingM1 = false end
end

----------------------------------------------------------------
-- RESPAWN HANDLER
----------------------------------------------------------------
local function setupRespawnHandler()
    player.CharacterAdded:Connect(function(character)
        print("💀 Character respawned!")
        
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if not hrp then return end
        
        task.wait(1)
        
        if (IsMiningActive or IsKillingActive) and Quest5Active then
            print("🔄 Returning to action after respawn...")
            task.wait(2)
        end
    end)
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

local function isQuest5StillActive()
    if not Quest5Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest5Active = false
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

-- 🔥 NEW: Classify objective type
local function getObjectiveType(text)
    if string.find(text, "Purchase") or string.find(text, "Buy") or string.find(text, "Pickaxe") then
        return "Purchase"
    elseif string.find(text, "Kill") or string.find(text, "Zombie") or string.find(text, "Defeat") then
        return "Kill"
    elseif string.find(text, "Get Ore") or string.find(text, "Mine") or string.find(text, "Rock") then
        return "Mine"
    else
        return "Unknown"
    end
end

-- 🔥 NEW: Check if objective can be done now (Quest 5 has no dependencies)
local function canDoObjective(objType)
    -- Quest 5 ไม่มี dependency เหมือน Quest 7 (Forge ต้องการแร่)
    -- ทุก objective ทำได้เลย
    return true
end

----------------------------------------------------------------
-- HELPER FUNCTIONS
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four, ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven, ["8"] = Enum.KeyCode.Eight, ["9"] = Enum.KeyCode.Nine, ["0"] = Enum.KeyCode.Zero
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
            if lbl and string.find(lbl.Text, "Someone else is already mining") then return true end
        end
    end
    return false
end

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

local function getZombieUndergroundPosition(zombieModel)
    if not zombieModel or not zombieModel.Parent then return nil end
    
    local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.ZOMBIE_UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

----------------------------------------------------------------
-- HP CHECKER
----------------------------------------------------------------
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

local function getZombieHP(zombie)
    if not zombie or not zombie.Parent then return 0 end
    local humanoid = zombie:FindFirstChild("Humanoid")
    if humanoid then return humanoid.Health or 0 end
    return 0
end

local function isZombieValid(zombie)
    if not zombie or not zombie.Parent then return false end
    return getZombieHP(zombie) > 0
end

----------------------------------------------------------------
-- TARGET FINDER
----------------------------------------------------------------
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

local function findNearestZombie()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetZombie, minDist = nil, math.huge
    
    for _, child in ipairs(LIVING_FOLDER:GetChildren()) do
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

----------------------------------------------------------------
-- NOCLIP
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

----------------------------------------------------------------
-- SMOOTH BODY VELOCITY MOVEMENT
----------------------------------------------------------------
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
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < 2 then
            print("   ✅ Reached target!")
            
            bv.Velocity = Vector3.zero
            task.wait(0.1)
            
            bv:Destroy()
            bg:Destroy()
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
    
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
            return
        end
        
        hrp.CFrame = layingCFrame
        hrp.Velocity = Vector3.zero
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)
    
    print("   🛏️ Position locked (laying down)")
end

local function lockPositionFollowTarget(targetModel)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetModel then return end
    
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    
    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)
    
    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
            return
        end
        
        if not targetModel or not targetModel.Parent then
            if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
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
    
    print("   🎯 Position locked (following target)")
end

local function unlockPosition()
    Shared.SoftUnlockPosition()
end

----------------------------------------------------------------
-- WATCH HP
----------------------------------------------------------------
local function watchRockHP(rock)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not rock then return end
    
    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0
        print(string.format("   ⚡ [HP Changed!] New HP: %d", hp))
        
        if hp <= 0 then
            print("   💥 HP = 0 detected! Switching target...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            unlockPosition()
        end
    end)
end

local function watchZombieHP(zombie)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not zombie then return end
    
    local humanoid = zombie:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    State.hpWatchConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local hp = humanoid.Health or 0
        print(string.format("   ⚡ [HP Changed!] New HP: %.1f", hp))
        
        if hp <= 0 then
            print("   💀 Zombie died! Switching target...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
            unlockPosition()
        end
    end)
end

----------------------------------------------------------------
-- WEAPON MANAGEMENT
----------------------------------------------------------------
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
-- ACTIONS
----------------------------------------------------------------
local function doPurchaseBronzePickaxe()
    print("🛒 Objective: Purchasing Bronze Pickaxe...")
    
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
        
        local moveComplete = false
        smoothMoveTo(npcPos, function()
            moveComplete = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveComplete and tick() - startTime < timeout do
            task.wait(0.1)
        end
        
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        
        print("   ✅ Reached NPC!")
        print("   ⏸️  Waiting 1.5s before purchase...")
        task.wait(1.5)
    end
    
    print(string.format("   💰 Purchasing: %s (Amount: %d)", QUEST_CONFIG.PICKAXE_NAME, QUEST_CONFIG.PICKAXE_AMOUNT))
    
    local args = {
        QUEST_CONFIG.PICKAXE_NAME,
        QUEST_CONFIG.PICKAXE_AMOUNT
    }
    
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

local function doMineRocks()
    print("⛏️ Objective: Mining Rocks...")
    
    IsMiningActive = true
    
    print("\n" .. string.rep("-", 30))
    print("⛏️ Starting underground mining loop...")
    print(string.rep("-", 30))
    
    while isQuest5StillActive() and not isCurrentObjectiveComplete() do
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
            warn("   ❌ No Rocks found, waiting...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetRock
        State.targetDestroyed = false
        
        local targetPos = getRockUndergroundPosition(targetRock)
        if not targetPos then
            warn("   ❌ Cannot get rock position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getRockHP(targetRock)
        print(string.format("   🎯 Target: %s (dist: %d, HP: %d)", 
            targetRock.Parent.Name, math.floor(dist), currentHP))
        
        watchRockHP(targetRock)
        
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
            warn("   ⚠️ Move timeout, skip this rock to avoid teleport")
            State.targetDestroyed = true
            unlockPosition()
            -- ไม่ต้อง lockPositionLayingDown ที่นี่
            continue
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest5StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   💀 Character died!")
                break
            end
            
            if not targetRock or not targetRock.Parent then
                print("   💥 Target removed!")
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
                    pcall(function() CHAR_RF:InvokeServer({Runes = {}, Name = QUEST_CONFIG.PICKAXE_NAME}) end)
                    task.wait(0.5) 
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function() ToolActivatedFunc(ToolController, toolInHand) end)
                else
                    pcall(function() TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true) end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("✅ Objective (Mine Rocks) Complete!")
            break
        end
        
        print("   🔄 Finding next target...")
        task.wait(0.5)
    end
    
    print("\n🛑 Mining ended")
    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

local function doKillZombies()
    print("⚔️ Objective: Killing Zombies (Dynamic Tracking)...")
    
    IsKillingActive = true
    
    print("\n" .. string.rep("-", 30))
    print("⚔️ Starting zombie hunting with dynamic tracking...")
    print(string.rep("-", 30))
    
    while isQuest5StillActive() and not isCurrentObjectiveComplete() do
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
            warn("   ❌ No Zombies found, waiting...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetZombie
        State.targetDestroyed = false
        
        local targetPos = getZombieUndergroundPosition(targetZombie)
        if not targetPos then
            warn("   ❌ Cannot get zombie position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getZombieHP(targetZombie)
        print(string.format("   🎯 Target: %s (dist: %d, HP: %.1f)", 
            targetZombie.Name, math.floor(dist), currentHP))
        
        watchZombieHP(targetZombie)
        
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
        
        while not State.targetDestroyed and isQuest5StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   💀 Character died!")
                break
            end
            
            if not targetZombie or not targetZombie.Parent or not isZombieValid(targetZombie) then
                print("   💀 Zombie died or removed!")
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
                    print(string.format("   🗡️ Equipping weapon: %s", bestWeapon.Type))
                    pcall(function() 
                        CharacterService:EquipItem(bestWeapon)
                    end)
                    task.wait(0.5)
                else
                    local key, weaponName = findWeaponSlotKey()
                    if key then
                        print(string.format("   🗡️ Equipping via hotkey: %s", weaponName))
                        pressKey(key)
                        task.wait(0.3)
                    else
                        warn("   ⚠️ No weapon found!")
                        task.wait(1)
                    end
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function() ToolActivatedFunc(ToolController, toolInHand) end)
                else
                    pcall(function() TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true) end)
                end
            end
            
            task.wait(0.15)
        end
        
        --unlockPosition()
        
        if isCurrentObjectiveComplete() then
            print("✅ Objective (Kill Zombies) Complete!")
            break
        end
        
        print("   🔄 Finding next target...")
        task.wait(0.5)
    end
    
    print("\n🛑 Zombie hunting ended")
    IsKillingActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- 🔥 SMART QUEST RUNNER (Priority-based + Flexible)
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 5: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 SMART SYSTEM: Priority-based + Flexible")
print("📋 Priority Order: Purchase → Kill → Mine")
print(string.rep("=", 50))

setupRespawnHandler()

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest5Active = false
    return
end

print("✅ Quest found (ID: " .. questID .. ")")

-- Collect all objectives
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

-- 🔥 Sort by priority instead of original order
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

print("\n" .. string.rep("=", 50))
print("⚙️  Quest Objectives (Priority Order):")
for i, obj in ipairs(objectives) do
    local complete = isObjectiveComplete(obj.frame)
    print(string.format("   %d. [%s] %s [%s]", i, obj.type, obj.text, complete and "✅" or "⏳"))
end
print(string.rep("=", 50))

local function hasIncompletePurchase()
    for _, obj in ipairs(objectives) do
        if obj.type == "Purchase" and not isObjectiveComplete(obj.frame) then
            return true
        end
    end
    return false
end

-- 🔥 Main loop: Process objectives by priority
local maxAttempts = 10
local attempt = 0

while isQuest5StillActive() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Quest Cycle #%d", attempt))
    
    local allComplete = true
    local didSomething = false
    local purchasePending = hasIncompletePurchase()
    
    for _, obj in ipairs(objectives) do
        if not isQuest5StillActive() then
            print("🛑 Quest disappeared!")
            break
        end
        
        local complete = isObjectiveComplete(obj.frame)
        
        if not complete then
            allComplete = false

            -- ⛔ ถ้ายังมี Purchase ที่ไม่เสร็จ → ห้ามทำ objective อื่น
            if purchasePending and obj.type ~= "Purchase" then
                print(string.format("   ⏭️  Skipping [%s] (waiting for Purchase to finish)", obj.type))
                continue
            end
            
            -- 🔥 Check if we can do this objective now
            if not canDoObjective(obj.type) then
                print(string.format("   ⏭️  Skipping [%s] - Cannot do right now", obj.type))
                continue
            end
            
            State.currentObjectiveFrame = obj.frame
            
            print(string.format("\n📋 Processing [%s]: %s", obj.type, obj.text))
            
            -- Execute objective
            if obj.type == "Purchase" then
                doPurchaseBronzePickaxe()
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
                doMineRocks()
                didSomething = true
                task.wait(1)
                
            else
                warn("   ⚠️ Unknown objective type: " .. obj.type)
            end
            
            -- Check if complete
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
        warn("\n⚠️ No objectives could be completed this cycle!")
        print("   Waiting 3s before retry...")
        task.wait(3)
    end
end

-- Final check
task.wait(2)

local allComplete = true
for _, obj in ipairs(objectives) do
    if not isObjectiveComplete(obj.frame) then
        allComplete = false
        warn(string.format("   ⚠️ [%s] incomplete: %s", obj.type, obj.text))
    end
end

if allComplete then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 5 Complete!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 5 incomplete after " .. attempt .. " cycles")
    warn(string.rep("=", 50))
end

Quest5Active = false
IsMiningActive = false
IsKillingActive = false
unlockPosition()
disableNoclip()
cleanupState()
