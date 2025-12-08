local Shared = _G.Shared

-- QUEST 16: Auto Buy Pickaxe (Gold-based)
-- ✅ Check Gold > 3340
-- ✅ Move to Shop (-32.6, -2.0, -269.3)
-- ✅ Buy "Stonewake's Pickaxe" x1
-- ✅ Auto Purchase

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest16Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Auto Buy Pickaxe",
    MIN_GOLD = 3340,  -- Must have Gold >= 3340
    
    -- Shop Location
    SHOP_POSITION = Vector3.new(-32.6, -2.0, -269.3),
    
    -- Purchase Item
    ITEM_NAME = "Stonewake's Pickaxe",
    ITEM_QUANTITY = 1,
    
    MOVE_SPEED = 25,  
    STOP_DISTANCE = 5,
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

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PURCHASE_RF = nil
pcall(function()
    PURCHASE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end

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
-- LEVEL SYSTEM
----------------------------------------------------------------
local function getPlayerLevel()
    print("   🔍 Checking player level...")

    -- Path: PlayerGui.Main.Screen.Hud.Level
    local levelLabel = playerGui:FindFirstChild("Main")
                    and playerGui.Main:FindFirstChild("Screen")
                    and playerGui.Main.Screen:FindFirstChild("Hud")
                    and playerGui.Main.Screen.Hud:FindFirstChild("Level")

    if not levelLabel then
        warn("   ❌ Level Label not found!")
        return nil
    end

    if not levelLabel:IsA("TextLabel") then
        warn("   ❌ Level is not a TextLabel!")
        return nil
    end

    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    
    if level then
        print(string.format("   ✅ Player Level: %d", level))
        return level
    else
        warn("   ❌ Failed to parse level from text!")
        return nil
    end
end

----------------------------------------------------------------
-- GOLD SYSTEM
----------------------------------------------------------------
local function getPlayerGold()
    print("   🔍 Checking player gold...")
    
    -- Path: PlayerGui.Main.Screen.Hud.Gold
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")
    
    if not goldLabel then
        warn("   ❌ Gold Label not found!")
        return nil
    end
    
    if not goldLabel:IsA("TextLabel") then
        warn("   ❌ Gold is not a TextLabel!")
        return nil
    end
    
    local goldText = goldLabel.Text
    
    -- Extract Gold from text (e.g., "$3,722.72" → 3722.72)
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)
    
    if gold then
        print(string.format("   ✅ Player Gold: $%.2f", gold))
        return gold
    else
        warn("   ❌ Failed to parse gold from text!")
        return nil
    end
end

local function hasEnoughGold()
    local gold = getPlayerGold()
    
    if not gold then
        warn("   ❌ Cannot determine player gold!")
        return false
    end
    
    if gold >= QUEST_CONFIG.MIN_GOLD then
        print(string.format("   ✅ Gold $%.2f >= $%d - Can purchase!", gold, QUEST_CONFIG.MIN_GOLD))
        return true
    else
        print(string.format("   ⏸️  Gold $%.2f < $%d - Not enough gold", gold, QUEST_CONFIG.MIN_GOLD))
        return false
    end
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
        
        if distance < QUEST_CONFIG.STOP_DISTANCE then
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
-- PURCHASE SYSTEM
----------------------------------------------------------------
local function purchaseItem(itemName, quantity)
    if not PURCHASE_RF then
        warn("   ❌ Purchase Remote not available!")
        return false
    end
    
    print(string.format("   🛒 Purchasing: %s x%d", itemName, quantity))
    
    local success, result = pcall(function()
        return PURCHASE_RF:InvokeServer(itemName, quantity)
    end)
    
    if success then
        print(string.format("   ✅ Purchased: %s x%d", itemName, quantity))
        return true
    else
        warn(string.format("   ❌ Failed to purchase %s: %s", itemName, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- INVENTORY CHECK
----------------------------------------------------------------
local function hasPickaxe(pickaxeName)
    if not PlayerController or not PlayerController.Replica then
        warn("   ❌ PlayerController/Replica not available!")
        return false
    end
    
    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ❌ Equipments not found in Replica!")
        return false
    end
    
    local equipments = replica.Data.Inventory.Equipments
    
    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type then
            if item.Type == pickaxeName then
                print(string.format("   ✅ Already have: %s", pickaxeName))
                return true
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doBuyPickaxe()
    print("🛒 Objective: Buy Pickaxe...")
    
    -- 1. Check Gold
    print("\n💰 Checking gold...")
    if not hasEnoughGold() then
        warn("   ❌ Not enough gold to purchase!")
        return false
    end
    
    -- 2. Check Inventory
    print("\n🔍 Checking inventory...")
    if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
        print("   ✅ Already have the pickaxe!")
        return true
    end
    
    -- 3. Move to Shop
    local shopPos = QUEST_CONFIG.SHOP_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (shopPos - hrp.Position).Magnitude
        print(string.format("   🚶 Moving to Shop at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
            shopPos.X, shopPos.Y, shopPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(shopPos, function()
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
        warn("   ⚠️ Failed to reach Shop")
        return false
    end
    
    print("   ✅ Reached Shop!")
    task.wait(1)
    
    -- 4. Purchase Pickaxe
    print("\n🛒 Purchasing pickaxe...")
    local purchaseSuccess = purchaseItem(QUEST_CONFIG.ITEM_NAME, QUEST_CONFIG.ITEM_QUANTITY)
    
    if not purchaseSuccess then
        warn("   ❌ Failed to purchase pickaxe")
        return false
    end
    
    print("   ✅ Purchase complete!")
    
    -- 5. Check Gold after purchase
    task.wait(1)
    local newGold = getPlayerGold()
    if newGold then
        print(string.format("\n💰 Gold after purchase: $%.2f", newGold))
    end
    
    -- 6. Check Inventory again
    task.wait(1)
    if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
        print(string.format("   ✅ Successfully obtained: %s", QUEST_CONFIG.ITEM_NAME))
        return true
    else
        warn("   ⚠️ Purchase successful but item not found in inventory")
        return true  -- Assume success if remote worked
    end
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 16: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Buy Pickaxe")
print("✅ Strategy: Check Gold → Move to Shop → Purchase")
print(string.rep("=", 50))

-- Pre-check: Gold >= 3340 AND Level < 10
print("\n🔍 Pre-check: Verifying gold and level requirement...")

-- 1) Check Gold >= MIN_GOLD
local goldOk = hasEnoughGold()

-- 2) Check Level < 10
local level = getPlayerLevel()
if not level then
    warn("\n❌ Cannot determine player level – skipping Quest 16")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

if (not goldOk) or level >= 10 then
    print(string.format(
        "\n❌ Condition not met (Gold ≥ %d AND Level < 10). Current: GoldOK=%s, Level=%d",
        QUEST_CONFIG.MIN_GOLD,
        tostring(goldOk),
        level
    ))
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

print(string.format(
    "   ✅ Condition passed! Gold ≥ %d AND Level < 10 (Level = %d)",
    QUEST_CONFIG.MIN_GOLD,
    level
))

-- Check if already have Pickaxe
print("\n🔍 Pre-check: Checking if already have pickaxe...")
if hasPickaxe(QUEST_CONFIG.ITEM_NAME) then
    print("\n✅ Already have the pickaxe!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

print("   ❌ Don't have pickaxe yet – proceeding to purchase...")

-- Purchase Pickaxe
local buySuccess = doBuyPickaxe()

if buySuccess then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 16 Complete! Pickaxe purchased successfully!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("❌ Quest 16 Failed! Could not purchase pickaxe.")
    warn(string.rep("=", 50))
end

Quest16Active = false
cleanupState()
disableNoclip()
