local Shared = _G.Shared

-- QUEST 9: "The First Upgrade!" (Auto Enhance to +3)
-- ✅ No need to Move to NPC
-- ✅ Use Enhance Equipment Remote directly
-- ✅ Loop Enhance until Quest is complete

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest9Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "The First Upgrade",
    TARGET_UPGRADE_LEVEL = 3,  -- Must enhance to +3
    ENHANCE_DELAY = 1.0,       -- Wait 1s between enhances
    MAX_ENHANCE_ATTEMPTS = 50, -- Prevent infinite loop
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
local EnhanceService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    EnhanceService = Knit.GetService("EnhanceService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local ENHANCE_RF = nil
pcall(function()
    ENHANCE_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("EnhanceEquipment", 3)
end)

local FIND_EQUIPMENT_RF = nil
pcall(function()
    FIND_EQUIPMENT_RF = SERVICES:WaitForChild("EnhanceService", 5):WaitForChild("RF", 3):WaitForChild("FindEquipmentByGUID", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if EnhanceService then print("✅ EnhanceService Ready!") else warn("⚠️ EnhanceService not found") end
if ENHANCE_RF then print("✅ Enhance Remote Ready!") else warn("⚠️ Enhance Remote not found") end
if FIND_EQUIPMENT_RF then print("✅ FindEquipment Remote Ready!") else warn("⚠️ FindEquipment Remote not found") end

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

local function isQuest9StillActive()
    if not Quest9Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest9Active = false
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
-- UI CONTROLLER (from Quest04)
----------------------------------------------------------------
local UIController = nil
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

if UIController then print("✅ UIController Ready!") else warn("⚠️ UIController not found") end

local function openToolsMenu()
    if not UIController then return false end
    
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

----------------------------------------------------------------
-- FIND EQUIPPED WEAPON (via UI "Unequip" text)
----------------------------------------------------------------
local function findEquippedWeapon()
    print("   📂 Opening Tools menu to find equipped weapon...")
    openToolsMenu()
    task.wait(0.5)
    
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then 
        warn("   ❌ Menu GUI not found!")
        closeToolsMenu()
        return nil, "Menu GUI not found"
    end
    
    local toolsFrame = menuGui:FindFirstChild("Frame") 
                    and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")
    
    if not toolsFrame then 
        warn("   ❌ Tools Frame not found!")
        closeToolsMenu()
        return nil, "Tools Frame not found"
    end
    
    print("   🔍 Scanning for equipped weapon (Unequip button)...")
    
    local equippedWeapon = nil
    
    -- Scan all items in Tools frame
    for _, weaponFrame in ipairs(toolsFrame:GetChildren()) do
        if weaponFrame:IsA("Frame") then
            local equipButton = weaponFrame:FindFirstChild("Equip")
            if equipButton then
                local textLabel = equipButton:FindFirstChild("TextLabel")
                if textLabel and textLabel:IsA("TextLabel") then
                    -- Check if text is "Unequip" = currently equipped
                    if textLabel.Text == "Unequip" then
                        local guid = weaponFrame.Name
                        
                        -- Skip Pickaxe
                        local itemName = weaponFrame:FindFirstChild("TextLabel")
                        local itemType = itemName and itemName.Text or ""
                        
                        if string.find(itemType, "Pickaxe") then
                            print(string.format("      ⏭️  Skipping Pickaxe: %s", itemType))
                            continue
                        end
                        
                        -- Get Upgrade level from UI
                        local upgradeLevel = 0
                        local stats = weaponFrame:FindFirstChild("Stats")
                        if stats then
                            -- Try to find upgrade text
                            for _, stat in ipairs(stats:GetChildren()) do
                                if stat:IsA("TextLabel") then
                                    local upgradeMatch = string.match(stat.Text, "%+(%d+)")
                                    if upgradeMatch then
                                        upgradeLevel = tonumber(upgradeMatch) or 0
                                    end
                                end
                            end
                        end
                        
                        equippedWeapon = {
                            GUID = guid,
                            Name = itemType,
                            Type = itemType,
                            Upgrade = upgradeLevel,
                        }
                        
                        print(string.format("      ✅ Found equipped weapon: %s (GUID: %s, +%d)", 
                            itemType, guid, upgradeLevel))
                        break
                    end
                end
            end
        end
    end
    
    closeToolsMenu()
    
    if not equippedWeapon then
        return nil, "No equipped weapon found (no Unequip button)"
    end
    
    return equippedWeapon, nil
end

local function getItemCurrentUpgrade(guid)
    if not FIND_EQUIPMENT_RF then return nil end
    
    local success, result = pcall(function()
        return FIND_EQUIPMENT_RF:InvokeServer(guid)
    end)
    
    if success and result and type(result) == "table" then
        return result.Upgrade or 0
    end
    
    return nil
end

----------------------------------------------------------------
-- ENHANCE SYSTEM
----------------------------------------------------------------
local function enhanceItem(guid)
    if not ENHANCE_RF then
        warn("   ❌ Enhance Remote not available!")
        return false, "Remote not available"
    end
    
    local success, result = pcall(function()
        return ENHANCE_RF:InvokeServer(guid)
    end)
    
    if success then
        if result == true or (type(result) == "table" and result.Success) then
            return true, "Success"
        elseif type(result) == "table" and result.Error then
            return false, result.Error
        else
            return false, "Unknown result"
        end
    else
        return false, tostring(result)
    end
end

local function printItemInfo(item)
    print(string.format("   🎯 Selected Item: %s", item.Name or item.Type))
    print(string.format("      - Type: %s", item.Type or "Unknown"))
    print(string.format("      - Current Upgrade: +%d", item.Upgrade or 0))
    print(string.format("      - GUID: %s", item.GUID))
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doEnhanceToPlus3()
    print("⚡ Objective: Enhance EQUIPPED weapon to +3...")
    
    -- Find currently equipped weapon (not lowest upgrade)
    local targetItem, errorMsg = findEquippedWeapon()
    
    if not targetItem then
        warn("   ❌ ERROR: " .. errorMsg)
        return false
    end
    
    printItemInfo(targetItem)
    
    if targetItem.Upgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
        print(string.format("   ✅ Item already at +%d or higher!", targetItem.Upgrade))
        return true
    end
    
    print(string.format("\n   🔨 Starting Enhancement Loop (Target: +%d)...\n", QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
    
    local enhanceCount = 0
    local successCount = 0
    local failCount = 0
    
    while isQuest9StillActive() and not areAllObjectivesComplete() do
        enhanceCount = enhanceCount + 1
        
        if enhanceCount > QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS then
            warn(string.format("   ⚠️ Max attempts reached (%d)! Stopping...", QUEST_CONFIG.MAX_ENHANCE_ATTEMPTS))
            break
        end
        
        -- Check current level
        local currentUpgrade = getItemCurrentUpgrade(targetItem.GUID)
        
        if currentUpgrade then
            print(string.format("   📊 Current Status: +%d / +%d", currentUpgrade, QUEST_CONFIG.TARGET_UPGRADE_LEVEL))
            
            if currentUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
                print(string.format("   🎉 Target reached! Item is now +%d", currentUpgrade))
                break
            end
        end
        
        -- Try Enhance
        print(string.format("   ⚡ Enhance Attempt #%d...", enhanceCount))
        
        local success, result = enhanceItem(targetItem.GUID)
        
        if success then
            successCount = successCount + 1
            print(string.format("      ✅ Enhancement SUCCESS! (+%d successful)", successCount))
        else
            failCount = failCount + 1
            print(string.format("      ❌ Enhancement FAILED! (%s) (+%d failed)", result, failCount))
        end
        
        -- Check if quest is complete
        task.wait(0.5)
        if areAllObjectivesComplete() then
            print("\n   🎉 Quest objective completed!")
            break
        end
        
        -- Wait before next attempt
        print(string.format("   ⏸️  Waiting %.1fs before next attempt...\n", QUEST_CONFIG.ENHANCE_DELAY))
        task.wait(QUEST_CONFIG.ENHANCE_DELAY)
    end
    
    print("\n   📊 Enhancement Summary:")
    print(string.format("      - Total Attempts: %d", enhanceCount))
    print(string.format("      - Successful: %d", successCount))
    print(string.format("      - Failed: %d", failCount))
    
    -- Check final level
    local finalUpgrade = getItemCurrentUpgrade(targetItem.GUID)
    if finalUpgrade then
        print(string.format("      - Final Upgrade: +%d", finalUpgrade))
        
        if finalUpgrade >= QUEST_CONFIG.TARGET_UPGRADE_LEVEL then
            print("   ✅ Enhancement complete!")
            return true
        else
            warn(string.format("   ⚠️ Failed to reach +%d (current: +%d)", QUEST_CONFIG.TARGET_UPGRADE_LEVEL, finalUpgrade))
            return false
        end
    end
    
    return false
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 9: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Enhance Item to +" .. QUEST_CONFIG.TARGET_UPGRADE_LEVEL)
print("✅ Strategy: Remote-based Enhancement (No Movement)")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest9Active = false
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
    return
end

print("\n" .. string.rep("=", 50))
print("⚡ Starting Enhancement Process...")
print(string.rep("=", 50))

local success = doEnhanceToPlus3()

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 9 Complete!")
    print(string.rep("=", 50))
else
    if success then
        print("\n   ⚠️ Enhancement complete but quest not marked done")
        print("   💡 Try checking quest status manually")
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ Quest 9 incomplete - Enhancement failed")
        warn(string.rep("=", 50))
    end
end

Quest9Active = false
