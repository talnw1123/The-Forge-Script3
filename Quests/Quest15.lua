local Shared = _G.Shared
-- Silent load (no console spam)

-- QUEST 15: Auto Claim Index (Codex System)
-- ✅ Scans UI for claimable items (Matches TestClaim.lua logic)
-- ✅ Claims Ores, Enemies, Equipments
-- ✅ Only claims items that have Claim button

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest15Active = true
local DEBUG_MODE = false -- Set to true for verbose output

local QUEST_CONFIG = {
    QUEST_NAME = "Auto Claim Index",
    CLAIM_DELAY = 0.3,
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local CLAIM_ORE_RF = nil
pcall(function()
    CLAIM_ORE_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimOre", 3)
end)

local CLAIM_ENEMY_RF = nil
pcall(function()
    CLAIM_ENEMY_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEnemy", 3)
end)

local CLAIM_EQUIPMENT_RF = nil
pcall(function()
    CLAIM_EQUIPMENT_RF = SERVICES:WaitForChild("CodexService", 5):WaitForChild("RF", 3):WaitForChild("ClaimEquipment", 3)
end)

if DEBUG_MODE then
    print("📡 ClaimOre: " .. (CLAIM_ORE_RF and "✅" or "❌"))
    print("📡 ClaimEnemy: " .. (CLAIM_ENEMY_RF and "✅" or "❌"))
    print("📡 ClaimEquipment: " .. (CLAIM_EQUIPMENT_RF and "✅" or "❌"))
end

----------------------------------------------------------------
-- GET INDEX UI
----------------------------------------------------------------
local function getIndexUI()
    local indexUI = playerGui:FindFirstChild("Menu")
                   and playerGui.Menu:FindFirstChild("Frame")
                   and playerGui.Menu.Frame:FindFirstChild("Frame")
                   and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
                   and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Index")
    
    if indexUI then
        return indexUI
    else
        -- Fallback check (from TestClaim.lua)
        if DEBUG_MODE then
            print("   ❌ Index UI NOT FOUND! Checking path...")
            local menu = playerGui:FindFirstChild("Menu")
            print("   - Menu: " .. (menu and "✅" or "❌"))
            if menu then
                local frame1 = menu:FindFirstChild("Frame")
                print("   - Menu.Frame: " .. (frame1 and "✅" or "❌"))
                if frame1 then
                    local frame2 = frame1:FindFirstChild("Frame")
                    print("   - Menu.Frame.Frame: " .. (frame2 and "✅" or "❌"))
                    if frame2 then
                        local menus = frame2:FindFirstChild("Menus")
                        print("   - Menu.Frame.Frame.Menus: " .. (menus and "✅" or "❌"))
                        if menus then
                            local index = menus:FindFirstChild("Index")
                            print("   - Menu.Frame.Frame.Menus.Index: " .. (index and "✅" or "❌"))
                        end
                    end
                end
            end
        end
        return nil
    end
end

----------------------------------------------------------------
-- CLAIM FUNCTIONS
----------------------------------------------------------------
local function claimOre(oreName)
    if not CLAIM_ORE_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ORE_RF:InvokeServer(oreName)
    end)
    
    if success then
        print(string.format("   🪨 Claimed: %s | Result: %s", oreName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", oreName, tostring(result)))
    end
    return false
end

local function claimEnemy(enemyName)
    if not CLAIM_ENEMY_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_ENEMY_RF:InvokeServer(enemyName)
    end)
    
    if success then
        print(string.format("   👹 Claimed: %s | Result: %s", enemyName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", enemyName, tostring(result)))
    end
    return false
end

local function claimEquipment(equipmentName)
    if not CLAIM_EQUIPMENT_RF then return false end
    
    local success, result = pcall(function()
        return CLAIM_EQUIPMENT_RF:InvokeServer(equipmentName)
    end)
    
    if success then
        print(string.format("   ⚔️ Claimed: %s | Result: %s", equipmentName, tostring(result)))
        return true
    else
        warn(string.format("   ❌ Failed to claim %s: %s", equipmentName, tostring(result)))
    end
    return false
end

----------------------------------------------------------------
-- MAIN CLAIM FUNCTION (UI SCANNING)
----------------------------------------------------------------
local function claimAllIndex()
    local totalClaimed = 0
    
    local indexUI = getIndexUI()
    if not indexUI then
        if DEBUG_MODE then warn("❌ Index UI not found!") end
        return false
    end
    
    local pages = indexUI:FindFirstChild("Pages")
    if not pages then
        if DEBUG_MODE then warn("❌ Pages not found!") end
        return false
    end
    
    if DEBUG_MODE then
        print("\n📂 PAGES FOUND:")
        for _, page in ipairs(pages:GetChildren()) do
            print("   - " .. page.Name)
        end
    end
    
    -- 1. CLAIM ORES
    local oresPage = pages:FindFirstChild("Ores")
    if oresPage then
        if DEBUG_MODE then print("\n🪨 CHECKING ORES PAGE...") end
        local oreCount = 0
        for _, child in ipairs(oresPage:GetChildren()) do
            if string.find(child.Name, "List$") then
                for _, oreItem in ipairs(child:GetChildren()) do
                    if oreItem:IsA("Frame") or oreItem:IsA("GuiObject") then
                        oreCount = oreCount + 1
                        local main = oreItem:FindFirstChild("Main")
                        if main then
                            local claim = main:FindFirstChild("Claim")
                            if claim then
                                if DEBUG_MODE then print("      ✅ CLAIMABLE: " .. oreItem.Name) end
                                if claimOre(oreItem.Name) then
                                    totalClaimed = totalClaimed + 1
                                end
                                task.wait(QUEST_CONFIG.CLAIM_DELAY)
                            end
                        end
                    end
                end
            end
        end
        if DEBUG_MODE then print("   📊 Scanned " .. oreCount .. " ores.") end
    else
        if DEBUG_MODE then warn("   ❌ Ores Page NOT found") end
    end
    
    -- 2. CLAIM ENEMIES
    local enemiesPage = pages:FindFirstChild("Enemies")
    if enemiesPage then
        local scrollFrame = enemiesPage:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            if DEBUG_MODE then print("\n👹 CHECKING ENEMIES PAGE...") end
            local enemyCount = 0
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if string.find(child.Name, "List$") then
                    for _, enemyItem in ipairs(child:GetChildren()) do
                        if enemyItem:IsA("Frame") or enemyItem:IsA("GuiObject") then
                            enemyCount = enemyCount + 1
                            local main = enemyItem:FindFirstChild("Main")
                            if main then
                                local claim = main:FindFirstChild("Claim")
                                if claim then
                                    if DEBUG_MODE then print("      ✅ CLAIMABLE: " .. enemyItem.Name) end
                                    if claimEnemy(enemyItem.Name) then
                                        totalClaimed = totalClaimed + 1
                                    end
                                    task.wait(QUEST_CONFIG.CLAIM_DELAY)
                                end
                            end
                        end
                    end
                end
            end
            if DEBUG_MODE then print("   📊 Scanned " .. enemyCount .. " enemies.") end
        else
             if DEBUG_MODE then warn("   ❌ Enemies ScrollingFrame NOT found") end
        end
    else
        if DEBUG_MODE then warn("   ❌ Enemies Page NOT found") end
    end
    
    -- 3. CLAIM EQUIPMENTS
    local equipPage = pages:FindFirstChild("Equipments")
    if equipPage then
        local scrollFrame = equipPage:FindFirstChild("ScrollingFrame")
        if scrollFrame then
            if DEBUG_MODE then print("\n⚔️ CHECKING EQUIPMENTS PAGE...") end
            local equipCount = 0
            for _, child in ipairs(scrollFrame:GetChildren()) do
                if string.find(child.Name, "List$") then
                    for _, equipItem in ipairs(child:GetChildren()) do
                        if equipItem:IsA("Frame") or equipItem:IsA("GuiObject") then
                            equipCount = equipCount + 1
                            local main = equipItem:FindFirstChild("Main")
                            if main then
                                local claim = main:FindFirstChild("Claim")
                                if claim then
                                    if DEBUG_MODE then print("      ✅ CLAIMABLE: " .. equipItem.Name) end
                                    if claimEquipment(equipItem.Name) then
                                        totalClaimed = totalClaimed + 1
                                    end
                                    task.wait(QUEST_CONFIG.CLAIM_DELAY)
                                end
                            end
                        end
                    end
                end
            end
            if DEBUG_MODE then print("   📊 Scanned " .. equipCount .. " equipments.") end
        else
            if DEBUG_MODE then warn("   ❌ Equipments ScrollingFrame NOT found") end
        end
    else
        if DEBUG_MODE then warn("   ❌ Equipments Page NOT found") end
    end
    
    return totalClaimed > 0
end

----------------------------------------------------------------
-- EXECUTE
----------------------------------------------------------------
-- Execute silently (no console spam)
local success = claimAllIndex()
Quest15Active = false
