--[[
    ⚔️ QUEST 04: Getting Equipped!
    📋 Equip Best Weapon → Sell Weakest Weapon
    📍 Extracted from 0.lua (lines 2245-3010)
--]]

-- QUEST 4: "Getting Equipped!" (SMART SYSTEM: Priority-based + Flexible + UI Damage Reading)
-- Priority Order: 1) Equip Best Weapon → 2) Sell Weakest Weapon

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest4Active = true

-- Weapon Types (ALL WEAPONS IN GAME - 23 Types)
local WEAPON_TYPES = {
    "Dagger", "Falchion Knife", "Gladius Dagger", "Hook",
    "Crusaders Sword", "Long Sword", "Falchion Sword", "Gladius Sword",
    "Cutlass", "Rapier", "Great Sword", "Uchigatana", "Tachi",
    "Double Battle Axe", "Hammer", "Skull Crusher", "Scythe",
    "Dragon Slayer", "Comically Large Spoon", "Chaos", "Ironhand",
    "Boxing Gloves", "Relevator"
}

-- Sell Config
local SELL_CONFIG = {
    NPC_NAME = "Marbles",
    KEEP_BEST_COUNT = 1
}

-- Priority Order
local PRIORITY_ORDER = {
    "Equip",   -- 1. ใส่อาวุธดีที่สุดก่อน
    "Sell",    -- 2. แล้วค่อยขายอาวุธแย่ที่สุด
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
local DialogueService = nil
local UIController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
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

if CharacterService then print("✅ CharacterService Ready!") else warn("⚠️ CharacterService not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if DialogueService then print("✅ DialogueService Ready!") else warn("⚠️ DialogueService not found") end
if UIController then print("✅ UIController Ready!") else warn("⚠️ UIController not found") end

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

local function isQuest4StillActive()
    if not Quest4Active then return false end
    
    local questID, objList = getQuestObjectives("Getting Equipped!")
    if not questID or not objList then
        print("🛑 Quest 'Getting Equipped!' not found!")
        Quest4Active = false
        return false
    end
    
    return true
end

local function getObjectiveType(text)
    if string.find(text, "Equip") and string.find(text, "Weapon") then
        return "Equip"
    elseif string.find(text, "Sell") and string.find(text, "Weapon") then
        return "Sell"
    else
        return "Unknown"
    end
end

----------------------------------------------------------------
-- UI MANAGEMENT
----------------------------------------------------------------
local function openToolsMenu()
    if not UIController then
        warn("   ⚠️ UIController not available, using fallback...")
        return false
    end
    
    if UIController.Modules["Menu"] then
        pcall(function() UIController:Open("Menu") end)
        task.wait(0.5)
        
        local menuModule = UIController.Modules["Menu"]
        if menuModule.OpenTab then
            pcall(function() menuModule:OpenTab("Tools") end)
        elseif menuModule.SwitchTab then
            pcall(function() menuModule:SwitchTab("Tools") end)
        end
        
        task.wait(0.5)
        return true
    end
    
    return false
end

local function closeToolsMenu()
    if UIController and UIController.Close then
        pcall(function() UIController:Close("Menu") end)
        task.wait(0.3)
    end
end

local function getDamageFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return 0 end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                       and menuGui.Frame.Frame:FindFirstChild("Menus") 
                       and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                       and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then return 0 end
    
    local weaponFrame = toolsFrame:FindFirstChild(guid)
    if not weaponFrame then return 0 end
    
    local stats = weaponFrame:FindFirstChild("Stats")
    if not stats then return 0 end
    
    local dmgLabel = stats:FindFirstChild("DMG")
    if not dmgLabel or not dmgLabel:IsA("TextLabel") then return 0 end
    
    local text = dmgLabel.Text
    local damageValue = tonumber(string.match(text, "([%d%.]+)"))
    
    return damageValue or 0
end

----------------------------------------------------------------
-- WEAPON MANAGEMENT
----------------------------------------------------------------
local function isWeaponType(itemType)
    for _, weaponType in ipairs(WEAPON_TYPES) do
        if itemType == weaponType then
            return true
        end
    end
    return false
end

local function isWeaponEquippedFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return false end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then return false end
    
    local weaponFrame = toolsFrame:FindFirstChild(guid)
    if not weaponFrame then return false end
    
    local equipButton = weaponFrame:FindFirstChild("Equip")
    if not equipButton then return false end
    
    local textLabel = equipButton:FindFirstChild("TextLabel")
    if not textLabel or not textLabel:IsA("TextLabel") then return false end
    
    return textLabel.Text == "Unequip"
end

local function getPlayerWeapons()
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ Replica not available!")
        return {}
    end
    
    local replica = PlayerController.Replica
    
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ Equipments not found in Replica!")
        return {}
    end
    
    print("   📂 Opening Tools menu to read damage...")
    openToolsMenu()
    
    local equipments = replica.Data.Inventory.Equipments
    local weapons = {}
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and isWeaponType(item.Type) then
            local guid = item.GUID
            local quality = item.Quality or 0
            local damage = getDamageFromUI(guid)
            local isEquipped = isWeaponEquippedFromUI(guid)
            
            table.insert(weapons, {
                ID = id,
                Type = item.Type,
                Damage = damage,
                Quality = quality,
                GUID = guid,
                Data = item,
                IsEquipped = isEquipped
            })
            
            print(string.format("      - %s | Dmg: %.2f | GUID: %s | Equipped: %s", 
                item.Type, damage, guid, tostring(isEquipped)))
        end
    end
    
    closeToolsMenu()
    
    return weapons
end

local function findBestWeapon()
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        return nil, "No weapons found in inventory!"
    end
    
    local bestWeapon = weapons[1]
    
    for _, weapon in ipairs(weapons) do
        if weapon.Damage > bestWeapon.Damage then
            bestWeapon = weapon
        elseif weapon.Damage == bestWeapon.Damage and weapon.Quality > bestWeapon.Quality then
            bestWeapon = weapon
        end
    end
    
    return bestWeapon, nil
end

local function findWeakestWeapon()
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        return nil, "No weapons found in inventory!"
    end
    
    if #weapons <= SELL_CONFIG.KEEP_BEST_COUNT then
        return nil, "Not enough weapons to sell!"
    end
    
    print("\n🔍 Finding weakest weapon to sell...")
    
    local weakestWeapon = nil
    for _, weapon in ipairs(weapons) do
        if not weapon.IsEquipped then
            if not weakestWeapon then
                weakestWeapon = weapon
            elseif weapon.Damage < weakestWeapon.Damage then
                weakestWeapon = weapon
            elseif weapon.Damage == weakestWeapon.Damage and weapon.Quality < weakestWeapon.Quality then
                weakestWeapon = weapon
            end
        else
            print(string.format("   ⚠️ Skipping equipped weapon: %s (Dmg: %.2f, Quality: %.1f)", 
                weapon.Type, weapon.Damage, weapon.Quality))
        end
    end
    
    if weakestWeapon then
        print(string.format("   ✅ Selected weakest (not equipped): %s | Dmg: %.2f | GUID: %s", 
            weakestWeapon.Type, weakestWeapon.Damage, weakestWeapon.GUID))
        return weakestWeapon, nil
    end
    
    print("   ⚠️ [FALLBACK] Weakest weapon is equipped! Selecting any sellable weapon...")
    for _, weapon in ipairs(weapons) do
        if not weapon.IsEquipped then
            print(string.format("   → Selected fallback: %s | Dmg: %.2f | GUID: %s", 
                weapon.Type, weapon.Damage, weapon.GUID))
            return weapon, nil
        end
    end
    
    return nil, "All weapons are equipped or no valid weapon to sell!"
end

local function canDoObjective(objType)
    if objType == "Sell" then
        local weapons = getPlayerWeapons()
        if #weapons <= 1 then
            print("   ⚠️ Cannot Sell: Need at least 2 weapons (have " .. #weapons .. ")")
            return false
        end
    end
    return true
end

local function printWeaponsSummary()
    print("\n   ⚔️  === WEAPONS INVENTORY ===")
    
    local weapons = getPlayerWeapons()
    
    if #weapons == 0 then
        warn("   ❌ No weapons found!")
        return
    end
    
    print(string.format("   ✅ Found %d weapon(s):", #weapons))
    
    table.sort(weapons, function(a, b)
        if a.Damage ~= b.Damage then
            return a.Damage > b.Damage
        else
            return a.Quality > b.Quality
        end
    end)
    
    for i, weapon in ipairs(weapons) do
        local marker = ""
        if i == 1 then marker = " 👑 BEST" end
        if i == #weapons and #weapons > 1 and not weapon.IsEquipped then 
            marker = " 🗑️ WORST" 
        end
        if weapon.IsEquipped then 
            marker = marker .. " ⚡ EQUIPPED" 
        end
        
        print(string.format("      %d. %s - Dmg: %.2f | Quality: %.1f%s", 
            i, weapon.Type, weapon.Damage, weapon.Quality, marker))
    end
    
    print("   " .. string.rep("=", 30) .. "\n")
end

----------------------------------------------------------------
-- FORCE RESTORE STATE
----------------------------------------------------------------
local function forceRestoreState()
    print("   🔧 Restoring Player State...")
    
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
        
        if char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = 16
            char.Humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then dUI.Enabled = false end
        
        local main = gui:FindFirstChild("Main")
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
    end
    
    pcall(function()
        local dialogueRE = ReplicatedStorage.Shared.Packages.Knit.Services.DialogueService.RE.DialogueEvent
        dialogueRE:FireServer("Closed")
    end)
    
    print("   ✅ State restored!")
end

----------------------------------------------------------------
-- ACTIONS
----------------------------------------------------------------
local function doEquipBestWeapon()
    print("⚔️  Objective: Equipping Best Weapon...")
    
    printWeaponsSummary()
    
    local bestWeapon, errorMsg = findBestWeapon()
    
    if not bestWeapon then
        warn(string.format("   ❌ ERROR: %s", errorMsg))
        return false
    end
    
    print(string.format("   🎯 Selected: %s (Dmg: %.2f | Quality: %.1f)", bestWeapon.Type, bestWeapon.Damage, bestWeapon.Quality))
    
    if not CharacterService then
        warn("   ❌ CharacterService not available!")
        return false
    end
    
    local success, err = pcall(function()
        CharacterService:EquipItem(bestWeapon.Data)
    end)
    
    if success then
        print("   ✅ Equipped successfully!")
        return true
    else
        warn("   ❌ Failed to equip: " .. tostring(err))
        return false
    end
end

local function doSellWeakestWeapon()
    print("💰 Objective: Selling Weakest Weapon...")
    
    printWeaponsSummary()
    
    local weakestWeapon, errorMsg = findWeakestWeapon()
    
    if not weakestWeapon then
        warn(string.format("   ❌ ERROR: %s", errorMsg))
        return false
    end
    
    print(string.format("   🎯 Selected: %s (Dmg: %.2f | Quality: %.1f)", weakestWeapon.Type, weakestWeapon.Damage, weakestWeapon.Quality))
    
    local basket = {}
    basket[weakestWeapon.GUID] = true
    
    local proximity = Workspace:FindFirstChild("Proximity")
    local npc = proximity and (proximity:FindFirstChild(SELL_CONFIG.NPC_NAME) or proximity:FindFirstChild("Greedy Cey"))
    
    if not npc then
        warn("   ❌ NPC not found!")
        return false
    end
    
    if not ProximityService or not DialogueService then
        warn("   ❌ Services not available!")
        return false
    end
    
    print("   🔌 Opening dialogue...")
    local success1 = pcall(function()
        ProximityService:ForceDialogue(npc, "SellConfirm")
    end)
    
    if not success1 then
        warn("   ❌ Failed to open dialogue")
        return false
    end
    
    task.wait(0.2)
    
    print("   💸 Selling weapon...")
    local success2 = pcall(function()
        DialogueService:RunCommand("SellConfirm", { Basket = basket })
    end)
    
    if success2 then
        print("   ✅ Sold successfully!")
        task.wait(0.1)
        forceRestoreState()
        return true
    else
        warn("   ❌ Sell failed")
        forceRestoreState()
        return false
    end
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
local function RunQuest4_Smart()
    print(string.rep("=", 50))
    print("🚀 QUEST 4: Getting Equipped!")
    print("🎯 SMART SYSTEM: Priority-based + Flexible")
    print("📋 Priority Order: Equip → Sell")
    print(string.rep("=", 50))
    
    local questID, objList = getQuestObjectives("Getting Equipped!")
    
    if not questID then
        warn("❌ Quest 'Getting Equipped!' not found!")
        Quest4Active = false
        return
    end
    
    print("✅ Quest found (ID: " .. questID .. ")")
    
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
            for i, priorityType in ipairs(PRIORITY_ORDER) do
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
    
    local maxAttempts = 5
    local attempt = 0
    
    while isQuest4StillActive() and attempt < maxAttempts do
        attempt = attempt + 1
        print(string.format("\n🔄 Quest Cycle #%d", attempt))
        
        local allComplete = true
        local didSomething = false
        
        for _, obj in ipairs(objectives) do
            if not isQuest4StillActive() then
                print("🛑 Quest disappeared!")
                break
            end
            
            local complete = isObjectiveComplete(obj.frame)
            
            if not complete then
                allComplete = false
                
                if not canDoObjective(obj.type) then
                    print(string.format("   ⏭️  Skipping [%s] - Cannot do right now", obj.type))
                    continue
                end
                
                print(string.format("\n📋 Processing [%s]: %s", obj.type, obj.text))
                
                local success = false
                
                if obj.type == "Equip" then
                    success = doEquipBestWeapon()
                    didSomething = true
                    task.wait(1.5)
                    
                elseif obj.type == "Sell" then
                    success = doSellWeakestWeapon()
                    didSomething = true
                    task.wait(1.5)
                    
                else
                    warn("   ⚠️ Unknown objective type: " .. obj.type)
                end
                
                if success then
                    print(string.format("   ✅ Action completed!"))
                else
                    warn(string.format("   ⚠️ Action failed, will retry"))
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
            warn("\n⚠️ No objectives could be completed this cycle!")
            print("   Waiting 2s before retry...")
            task.wait(2)
        end
    end
    
    task.wait(1)
    
    local allComplete = true
    for _, obj in ipairs(objectives) do
        if not isObjectiveComplete(obj.frame) then
            allComplete = false
            warn(string.format("   ⚠️ [%s] incomplete: %s", obj.type, obj.text))
        end
    end
    
    if allComplete then
        print("\n" .. string.rep("=", 50))
        print("✅ Quest 4 Complete!")
        print(string.rep("=", 50))
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ Quest 4 incomplete after " .. attempt .. " cycles")
        warn(string.rep("=", 50))
    end
    
    Quest4Active = false
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
RunQuest4_Smart()
