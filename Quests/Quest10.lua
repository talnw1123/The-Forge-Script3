local Shared = _G.Shared

-- QUEST 10: "Runes of Power!" (FIXED - Find Rune from Stash UI)
-- ✅ Find Rune from PlayerGui.Menu.Frame.Menus.Stash.Background
-- ✅ Find ItemName = "Flame Spark" or "Blast Chip"
-- ✅ Use GUID to Attach Rune
-- ✅ No need to open Rune UI first!

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest10Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Runes of Power",
    NPC_NAME = "Runemaker",
    NPC_POSITION = Vector3.new(-271.7, 20.3, 141.9),
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
    
    -- Runes to look for (pick one)
    ALLOWED_RUNE_NAMES = {
        "Flame Spark",
        "Blast Chip",
    },
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local PlayerController = nil
local ProximityService = nil
local RuneService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    RuneService = Knit.GetService("RuneService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_ATTACH_RF = nil
pcall(function()
    PURCHASE_ATTACH_RF = SERVICES:WaitForChild("RuneService", 5):WaitForChild("RF", 3):WaitForChild("PurchaseAttach", 3)
end)

local GET_PRICE_INFO_RF = nil
pcall(function()
    GET_PRICE_INFO_RF = SERVICES:WaitForChild("RuneService", 5):WaitForChild("RF", 3):WaitForChild("GetPriceInfo", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if RuneService then print("✅ RuneService Ready!") else warn("⚠️ RuneService not found") end
if PURCHASE_ATTACH_RF then print("✅ PurchaseAttach Remote Ready!") else warn("⚠️ PurchaseAttach Remote not found") end

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    noclipConn = nil,
    moveConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

local function cleanupState()
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
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

local function isQuest10StillActive()
    if not Quest10Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest10Active = false
        return false
    end
    
    return true
end

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            if not isObjectiveComplete(item) then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- EQUIPMENT HELPERS
----------------------------------------------------------------
local function getEquippedWeaponGUID()
    print("   🔍 Checking equipped items from UI...")
    
    local menuUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Tools")
                   and playerGui.Menu.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if menuUI then
        for _, child in ipairs(menuUI:GetChildren()) do
            if string.match(child.Name, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
                local equipButton = child:FindFirstChild("Equip")
                local equipLabel = equipButton and equipButton:FindFirstChild("TextLabel")
                
                if equipLabel and equipLabel:IsA("TextLabel") then
                    local isEquipped = (equipLabel.Text == "Unequip")
                    
                    if PlayerController and PlayerController.Replica then
                        local replica = PlayerController.Replica
                        if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                            for id, item in pairs(replica.Data.Inventory.Equipments) do
                                if type(item) == "table" and item.GUID == child.Name then
                                    local isPickaxe = string.find(item.Type or "", "Pickaxe")
                                    
                                    if DEBUG_MODE then
                                        print(string.format("      - %s: UI_Equipped=%s, Pickaxe=%s, GUID=%s", 
                                            item.Type or "Unknown", 
                                            tostring(isEquipped), 
                                            tostring(isPickaxe), 
                                            item.GUID))
                                    end
                                    
                                    if not isPickaxe and isEquipped then
                                        return item.GUID, item.Type
                                    end
                                    
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        warn("   ⚠️ Menu UI not found!")
    end
    
    print("   🔍 Fallback: Checking from Replica...")
    
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ PlayerController/Replica not available!")
        return nil
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ Equipments not found in Replica!")
        return nil
    end
    
    local equipments = replica.Data.Inventory.Equipments
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and item.GUID then
            local isPickaxe = string.find(item.Type, "Pickaxe")
            local isEquipped = (item.Equipped == true)
            
            if DEBUG_MODE then
                print(string.format("      - %s: Replica_Equipped=%s, Pickaxe=%s, GUID=%s", 
                    item.Type, tostring(isEquipped), tostring(isPickaxe), item.GUID))
            end
            
            if not isPickaxe and isEquipped then
                return item.GUID, item.Type
            end
        end
    end
    
    warn("   ❌ No equipped weapon found (excluding Pickaxe)!")
    return nil
end

----------------------------------------------------------------
-- RUNE HELPERS (FIXED - Find from Stash UI)
----------------------------------------------------------------
local function getRunesFromStash()
    local runes = {}
    
    print("   🔍 Searching for Runes in Stash UI...")
    
    -- Path: PlayerGui.Menu.Frame.Frame.Menus.Stash.Background
    local stashBackground = playerGui:FindFirstChild("Menu")
                           and playerGui.Menu:FindFirstChild("Frame")
                           and playerGui.Menu.Frame:FindFirstChild("Frame")
                           and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                           and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Stash")
                           and playerGui.Menu.Frame.Frame.Menus.Stash:FindFirstChild("Background")
    
    if not stashBackground then
        warn("   ❌ Stash Background not found!")
        warn("   💡 Path: PlayerGui.Menu.Frame.Frame.Menus.Stash.Background")
        return runes
    end
    
    print("   ✅ Found Stash Background!")
    print(string.format("   📊 Total children: %d", #stashBackground:GetChildren()))
    
    -- Loop through all children to find GUIDs
    for _, child in ipairs(stashBackground:GetChildren()) do
        -- Check if name is GUID pattern (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
        if string.match(child.Name, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
            local main = child:FindFirstChild("Main")
            if main then
                local itemNameLabel = main:FindFirstChild("ItemName")
                if itemNameLabel and itemNameLabel:IsA("TextLabel") then
                    local itemName = itemNameLabel.Text
                    local itemGUID = child.Name
                    
                    if DEBUG_MODE then
                        print(string.format("      - Found Item: %s (GUID: %s)", itemName, itemGUID))
                    end
                    
                    table.insert(runes, {
                        GUID = itemGUID,
                        Name = itemName,
                        Frame = child,
                    })
                end
            end
        end
    end
    
    print(string.format("   📊 Total items found in Stash: %d", #runes))
    
    return runes
end

local function findAllowedRuneFromStash()
    local allItems = getRunesFromStash()
    
    if #allItems == 0 then
        return nil, "No items found in Stash!"
    end
    
    print(string.format("   📋 Found %d item(s) in Stash:", #allItems))
    
    -- Filter runes matching ALLOWED_RUNE_NAMES
    local allowedRunes = {}
    
    for _, item in ipairs(allItems) do
        for _, allowedName in ipairs(QUEST_CONFIG.ALLOWED_RUNE_NAMES) do
            if item.Name == allowedName then
                table.insert(allowedRunes, item)
                print(string.format("      ✅ Matched: %s (GUID: %s)", item.Name, item.GUID))
            end
        end
    end
    
    if #allowedRunes == 0 then
        warn(string.format("   ❌ No allowed runes found!"))
        warn(string.format("   💡 Looking for: %s", table.concat(QUEST_CONFIG.ALLOWED_RUNE_NAMES, ", ")))
        
        -- Debug: Show all available items
        if DEBUG_MODE then
            print("   📋 Available items in Stash:")
            for i, item in ipairs(allItems) do
                print(string.format("      %d. %s (GUID: %s)", i, item.Name, item.GUID))
            end
        end
        
        return nil, string.format("No allowed runes found! (Looking for: %s)", table.concat(QUEST_CONFIG.ALLOWED_RUNE_NAMES, ", "))
    end
    
    -- Randomly select one
    local selectedRune = allowedRunes[math.random(1, #allowedRunes)]
    
    return selectedRune, nil
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
        
        if distance < QUEST_CONFIG.NPC_STOP_DISTANCE then
            print("   ✅ Reached NPC!")
            
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
-- NPC INTERACTION
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- RUNE ATTACHMENT
----------------------------------------------------------------
local function attachRuneToWeapon(weaponGUID, runeGUID)
    if not PURCHASE_ATTACH_RF then
        warn("   ❌ PurchaseAttach Remote not available!")
        return false
    end
    
    print(string.format("🔮 Attaching Rune to Weapon..."))
    print(string.format("   - Weapon GUID: %s", weaponGUID))
    print(string.format("   - Rune GUID: %s", runeGUID))
    
    -- Call GetPriceInfo first (if available)
    if GET_PRICE_INFO_RF then
        local success = pcall(function()
            GET_PRICE_INFO_RF:InvokeServer(weaponGUID, runeGUID, "Attach")
        end)
        
        if success then
            print("   ✅ GetPriceInfo called")
        end
        
        task.wait(0.3)
    end
    
    -- Call PurchaseAttach
    local success, result = pcall(function()
        return PURCHASE_ATTACH_RF:InvokeServer(weaponGUID, runeGUID)
    end)
    
    if success then
        print("   ✅ Rune attached successfully!")
        return true
    else
        warn("   ❌ Failed to attach rune: " .. tostring(result))
        return false
    end
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doAttachRune()
    print("🔮 Objective: Attach Rune to Weapon...")
    
    -- 1. Move to NPC
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    local npcPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (npcPos - hrp.Position).Magnitude
        print(string.format("   🚶 Moving to %s at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
            QUEST_CONFIG.NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z, currentDist))
    end
    
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
    
    if not moveComplete then
        warn("   ⚠️ Failed to reach NPC")
        return false
    end
    
    print("   ✅ Reached NPC!")
    task.wait(1)
    
    -- 2. Find Equipped Weapon
    print("\n🔍 Finding equipped weapon...")
    local weaponGUID, weaponType = getEquippedWeaponGUID()
    
    if not weaponGUID then
        warn("   ❌ No weapon equipped!")
        warn("   💡 Please equip a weapon (not pickaxe) and try again")
        return false
    end
    
    print(string.format("   ✅ Found equipped weapon: %s (GUID: %s)", weaponType or "Unknown", weaponGUID))
    
    -- 3. Find Rune from Stash UI
    print("\n🔍 Finding suitable rune from Stash UI...")
    local selectedRune, errorMsg = findAllowedRuneFromStash()
    
    if not selectedRune then
        warn("   ❌ ERROR: " .. errorMsg)
        return false
    end
    
    print(string.format("   ✅ Selected Rune: %s (GUID: %s)", selectedRune.Name, selectedRune.GUID))
    
    -- 4. Attach Rune
    print("\n⚡ Attaching rune to weapon...")
    local attachSuccess = attachRuneToWeapon(weaponGUID, selectedRune.GUID)
    
    if attachSuccess then
        print("   ✅ Rune attachment complete!")
        return true
    else
        warn("   ❌ Rune attachment failed!")
        return false
    end
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 10: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Attach Rune to Weapon")
print("✅ Strategy: Move to NPC → Find Rune from Stash → Attach")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest10Active = false
    cleanupState()
    disableNoclip()
    return
end

print("✅ Quest found (ID: " .. questID .. ")")

print("\n" .. string.rep("=", 50))
print("⚙️  Quest Objectives:")
local objectiveCount = 0
for _, item in ipairs(objList:GetChildren()) do
    if item:IsA("Frame") and tonumber(item.Name) then
        objectiveCount = objectiveCount + 1
        local text = getObjectiveText(item)
        local complete = isObjectiveComplete(item)
        print(string.format("   %d. %s [%s]", objectiveCount, text, complete and "✅" or "⏳"))
    end
end
print(string.rep("=", 50))

if areAllObjectivesComplete() then
    print("\n✅ Quest already complete!")
    cleanupState()
    disableNoclip()
    return
end

local maxAttempts = 3
local attempt = 0

while isQuest10StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    local success = doAttachRune()
    
    if success then
        print("   ✅ Rune attachment complete!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 All objectives complete!")
            break
        else
            print("   ⚠️ Quest not marked complete, retrying...")
            task.wait(2)
        end
    else
        warn("   ❌ Rune attachment failed, retrying in 3s...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 10 Complete!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 10 incomplete after " .. attempt .. " attempts")
    warn(string.rep("=", 50))
end

Quest10Active = false
cleanupState()
disableNoclip()
