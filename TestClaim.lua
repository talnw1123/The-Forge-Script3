-- TEST CLAIM ONLY (Debug Version)
-- Run this in executor to test Index claiming

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("=" .. string.rep("=", 59))
print("🧪 TEST: Index Claim Debug")
print("=" .. string.rep("=", 59))

----------------------------------------------------------------
-- SETUP REMOTES
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

print("\n📡 REMOTE STATUS:")
print("   ClaimOre: " .. (CLAIM_ORE_RF and "✅ Ready" or "❌ Not found"))
print("   ClaimEnemy: " .. (CLAIM_ENEMY_RF and "✅ Ready" or "❌ Not found"))
print("   ClaimEquipment: " .. (CLAIM_EQUIPMENT_RF and "✅ Ready" or "❌ Not found"))

----------------------------------------------------------------
-- GET INDEX UI
----------------------------------------------------------------
print("\n🔍 CHECKING INDEX UI...")

local indexUI = playerGui:FindFirstChild("Menu")
               and playerGui.Menu:FindFirstChild("Frame")
               and playerGui.Menu.Frame:FindFirstChild("Frame")
               and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
               and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Index")

if indexUI then
    print("   ✅ Index UI Found!")
    print("   Path: PlayerGui.Menu.Frame.Frame.Menus.Index")
else
    print("   ❌ Index UI NOT FOUND!")
    print("   Checking each step...")
    
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
    return
end

----------------------------------------------------------------
-- SCAN PAGES
----------------------------------------------------------------
local pages = indexUI:FindFirstChild("Pages")
if not pages then
    print("   ❌ Pages not found!")
    return
end

print("\n📂 PAGES FOUND:")
for _, page in ipairs(pages:GetChildren()) do
    print("   - " .. page.Name)
end

----------------------------------------------------------------
-- SCAN ORES
----------------------------------------------------------------
print("\n🪨 ORES:")
local oresPage = pages:FindFirstChild("Ores")
if oresPage then
    print("   Path: Index.Pages.Ores")
    local oreCount = 0
    
    for _, child in ipairs(oresPage:GetChildren()) do
        if string.find(child.Name, "List$") then
            print("   📁 " .. child.Name)
            
            for _, oreItem in ipairs(child:GetChildren()) do
                if oreItem:IsA("Frame") or oreItem:IsA("GuiObject") then
                    local main = oreItem:FindFirstChild("Main")
                    if main then
                        local claim = main:FindFirstChild("Claim")
                        if claim then
                            print("      ✅ CLAIMABLE: " .. oreItem.Name)
                            oreCount = oreCount + 1
                            
                            -- TRY CLAIM
                            if CLAIM_ORE_RF then
                                local ok, result = pcall(function()
                                    return CLAIM_ORE_RF:InvokeServer(oreItem.Name)
                                end)
                                print("         → Claim result: " .. tostring(result))
                            end
                        end
                    end
                end
            end
        end
    end
    
    print("   📊 Total claimable ores: " .. oreCount)
else
    print("   ❌ Ores page not found!")
end

----------------------------------------------------------------
-- SCAN ENEMIES
----------------------------------------------------------------
print("\n👹 ENEMIES:")
local enemiesPage = pages:FindFirstChild("Enemies")
if enemiesPage then
    local scrollFrame = enemiesPage:FindFirstChild("ScrollingFrame")
    if scrollFrame then
        print("   Path: Index.Pages.Enemies.ScrollingFrame")
        local enemyCount = 0
        
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if string.find(child.Name, "List$") then
                print("   📁 " .. child.Name)
                
                for _, enemyItem in ipairs(child:GetChildren()) do
                    if enemyItem:IsA("Frame") or enemyItem:IsA("GuiObject") then
                        local main = enemyItem:FindFirstChild("Main")
                        if main then
                            local claim = main:FindFirstChild("Claim")
                            if claim then
                                print("      ✅ CLAIMABLE: " .. enemyItem.Name)
                                enemyCount = enemyCount + 1
                                
                                -- TRY CLAIM
                                if CLAIM_ENEMY_RF then
                                    local ok, result = pcall(function()
                                        return CLAIM_ENEMY_RF:InvokeServer(enemyItem.Name)
                                    end)
                                    print("         → Claim result: " .. tostring(result))
                                end
                            end
                        end
                    end
                end
            end
        end
        
        print("   📊 Total claimable enemies: " .. enemyCount)
    else
        print("   ❌ ScrollingFrame not found!")
    end
else
    print("   ❌ Enemies page not found!")
end

----------------------------------------------------------------
-- SCAN EQUIPMENTS
----------------------------------------------------------------
print("\n⚔️ EQUIPMENTS:")
local equipPage = pages:FindFirstChild("Equipments")
if equipPage then
    local scrollFrame = equipPage:FindFirstChild("ScrollingFrame")
    if scrollFrame then
        print("   Path: Index.Pages.Equipments.ScrollingFrame")
        local equipCount = 0
        
        for _, child in ipairs(scrollFrame:GetChildren()) do
            if string.find(child.Name, "List$") then
                print("   📁 " .. child.Name)
                
                for _, equipItem in ipairs(child:GetChildren()) do
                    if equipItem:IsA("Frame") or equipItem:IsA("GuiObject") then
                        local main = equipItem:FindFirstChild("Main")
                        if main then
                            local claim = main:FindFirstChild("Claim")
                            if claim then
                                print("      ✅ CLAIMABLE: " .. equipItem.Name)
                                equipCount = equipCount + 1
                                
                                -- TRY CLAIM
                                if CLAIM_EQUIPMENT_RF then
                                    local ok, result = pcall(function()
                                        return CLAIM_EQUIPMENT_RF:InvokeServer(equipItem.Name)
                                    end)
                                    print("         → Claim result: " .. tostring(result))
                                end
                            end
                        end
                    end
                end
            end
        end
        
        print("   📊 Total claimable equipments: " .. equipCount)
    else
        print("   ❌ ScrollingFrame not found!")
    end
else
    print("   ❌ Equipments page not found!")
end

print("\n" .. string.rep("=", 60))
print("🧪 TEST COMPLETE!")
print(string.rep("=", 60))
