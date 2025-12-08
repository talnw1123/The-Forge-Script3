local Shared = _G.Shared

-- QUEST 18: Smart Teleport to Forgotten Kingdom
-- ✅ Checks if player is on Island1
-- ✅ If on Island1 → Teleport to Forgotten Kingdom (Island2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest18Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "Smart Teleport",
    REQUIRED_LEVEL = 10,
    ISLAND_NAME = "Forgotten Kingdom",
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PORTAL_RF = nil
pcall(function()
    PORTAL_RF = SERVICES:WaitForChild("PortalService", 5):WaitForChild("RF", 3):WaitForChild("TeleportToIsland", 3)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")

if PORTAL_RF then print("✅ Portal Remote Ready!") else warn("⚠️ Portal Remote not found") end

----------------------------------------------------------------
-- LEVEL SYSTEM
----------------------------------------------------------------
local function getPlayerLevel()
    local levelLabel = playerGui:FindFirstChild("Main")
                      and playerGui.Main:FindFirstChild("Screen")
                      and playerGui.Main.Screen:FindFirstChild("Hud")
                      and playerGui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    return level
end

local function hasRequiredLevel()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ Cannot determine level!")
        return false
    end
    
    if level >= QUEST_CONFIG.REQUIRED_LEVEL then
        print(string.format("   ✅ Level %d >= %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return true
    else
        print(string.format("   ⏸️  Level %d < %d", level, QUEST_CONFIG.REQUIRED_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- ISLAND DETECTION
----------------------------------------------------------------
local function getCurrentIsland()
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            if string.match(child.Name, "Island%d+") then
                return child.Name
            end
        end
    end
    return nil
end

local function needsTeleport()
    local currentIsland = getCurrentIsland()
    
    if not currentIsland then
        return true
    end
    
    if currentIsland == "Island1" then
        print(string.format("   ✅ On %s → Need teleport!", currentIsland))
        return true
    elseif currentIsland == "Island2" then
        print(string.format("   ✅ On %s → Already on target!", currentIsland))
        return false
    else
        warn(string.format("   ⚠️ Unknown: %s", currentIsland))
        return true
    end
end

----------------------------------------------------------------
-- TELEPORT SYSTEM
----------------------------------------------------------------
local function teleportToIsland(islandName)
    if not PORTAL_RF then
        warn("   ❌ Portal Remote not available!")
        return false
    end
    
    print(string.format("   🌀 Teleporting to: %s", islandName))
    
    local args = {islandName}
    
    local success, result = pcall(function()
        return PORTAL_RF:InvokeServer(unpack(args))
    end)
    
    if success then
        print(string.format("   ✅ Teleported to: %s", islandName))
        return true
    else
        warn(string.format("   ❌ Failed: %s", tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 18: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Teleport to Forgotten Kingdom")
print(string.rep("=", 50))

-- Check Level
print("\n🔍 Pre-check: Verifying level requirement...")
if not hasRequiredLevel() then
    print("\n❌ Level requirement not met!")
    print(string.rep("=", 50))
    return
end

-- Check if teleport needed
print("\n🔍 Checking Location...")
if needsTeleport() then
    print("   ⚠️ Not on target island!")
    local success = teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    
    if success then
        print("\n" .. string.rep("=", 50))
        print("✅ Quest 18 Complete! Teleported to Forgotten Kingdom!")
        print(string.rep("=", 50))
    else
        print("\n" .. string.rep("=", 50))
        print("❌ Quest 18 Failed! Could not teleport!")
        print(string.rep("=", 50))
    end
else
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 18 Complete! Already on target island!")
    print(string.rep("=", 50))
end

Quest18Active = false
