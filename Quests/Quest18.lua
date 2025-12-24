local Shared = _G.Shared

-- QUEST 18: Smart Teleport to Forgotten Kingdom
-- ✅ Checks if player is on Island1
-- ✅ Try to Buy Arcane Pickaxe (Open Door -> Buy)
-- ✅ If on Island1 -> Teleport to Forgotten Kingdom (Island2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest18Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "Smart Teleport & Arcane Buy",
    REQUIRED_LEVEL = 10,
    ISLAND_NAME = "Forgotten Kingdom",
    
    -- 🌐 SERVER HOP CONFIG (Join low-player server on Island2)
    ISLAND2_PLACE_ID = 129009554587176,  -- Forgotten Kingdom PlaceID
    MAX_PLAYERS_PREFERRED = 3,            -- Prefer servers with <= 3 players
    SERVER_HOP_ENABLED = true,           -- Enable server hop to low-player server
}

-- 💜 ARCANE PICKAXE CONFIG
local ARCANE_CONFIG = {
    ENABLED = true,
    TARGET_PICKAXE = "Arcane Pickaxe",
    MIN_GOLD = 128000,
    DOOR_POSITION = Vector3.new(237.66, -13.87, -259.91),  -- Position to open door
    BUY_POSITION = Vector3.new(235.24, -13.43, -335.97),   -- Position to buy
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

local PURCHASE_RF = nil
pcall(function()
    PURCHASE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

local FUNCTIONALS_RF = nil
pcall(function()
    FUNCTIONALS_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Functionals", 3)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")

if PORTAL_RF then print("✅ Portal Remote Ready!") else warn("⚠️ Portal Remote not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end
if FUNCTIONALS_RF then print("✅ Functionals Remote Ready!") else warn("⚠️ Functionals Remote not found") end

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
-- GOLD & PICKAXE HELPERS (for Arcane Purchase)
----------------------------------------------------------------
local function getGold()
    -- Wait for playerGui
    local gui = player:WaitForChild("PlayerGui", 5)
    if not gui then 
        print("   [DEBUG] PlayerGui not found!")
        return 0 
    end

    -- Use same path as Quest19: playerGui.Main.Screen.Hud.Gold
    local goldLabel = nil
    for i = 1, 10 do  -- Retry up to 10 times
        goldLabel = gui:FindFirstChild("Main")
                    and gui.Main:FindFirstChild("Screen")
                    and gui.Main.Screen:FindFirstChild("Hud")
                    and gui.Main.Screen.Hud:FindFirstChild("Gold")
        
        if goldLabel then break end
        if i % 2 == 0 then print(string.format("   [DEBUG] Waiting for Gold UI... (%d/10)", i)) end
        task.wait(0.5)
    end

    if goldLabel and goldLabel:IsA("TextLabel") then
        local goldText = goldLabel.Text
        local goldString = string.gsub(goldText, "[$,]", "")
        local gold = tonumber(goldString) or 0
        print(string.format("   [DEBUG] Gold read: %d", gold))
        return gold
    end
    
    print("   [DEBUG] Gold label not found!")
    return 0
end

local function hasPickaxe(pickaxeName)
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return false end

    local ok, toolsFrame = pcall(function()
        return menu.Frame.Frame.Menus.Tools.Frame
    end)

    if not ok or not toolsFrame then return false end

    local gui = toolsFrame:FindFirstChild(pickaxeName)
    return gui ~= nil
end

----------------------------------------------------------------
-- MOVEMENT SYSTEM (for Arcane Shop)
----------------------------------------------------------------
local moveConn = nil
local noclipConn = nil
local bodyVelocity = nil
local bodyGyro = nil
local positionLockConn = nil

local MOVE_SPEED = 80
local Y_THRESHOLD = 3
local XZ_THRESHOLD = 3

local function enableNoclip()
    if noclipConn then return end
    
    local char = player.Character
    if not char then return end
    
    noclipConn = RunService.Stepped:Connect(function()
        local c = player.Character
        if not c or not c.Parent then
            if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            return
        end
        
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function disableNoclip()
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
end

local function smoothMoveTo(targetPos, onComplete)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then 
        if onComplete then onComplete() end
        return 
    end

    -- Cleanup previous
    if moveConn then moveConn:Disconnect() moveConn = nil end
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if positionLockConn then positionLockConn:Disconnect() positionLockConn = nil end

    enableNoclip()

    -- Create BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Parent = hrp
    bodyVelocity = bv

    -- Create BodyGyro
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    bodyGyro = bg

    print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))

    local reachedTarget = false
    local phase = 1 -- 1 = Y-axis first, 2 = XZ-axis

    moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end

        char = player.Character 
        hrp = char and char:FindFirstChild("HumanoidRootPart")

        -- Check if character or BodyVelocity is destroyed
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if moveConn then moveConn:Disconnect() moveConn = nil end
            return
        end

        -- Recreate BodyVelocity if destroyed
        if not bv or not bv.Parent then
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            bodyVelocity = bv
        end

        -- Recreate BodyGyro if destroyed
        if not bg or not bg.Parent then
            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.D = 500
            bg.Parent = hrp
            bodyGyro = bg
        end

        local currentPos = hrp.Position

        if phase == 1 then
            -- Phase 1: Move Y first (vertical)
            local yDiff = math.abs(targetPos.Y - currentPos.Y)
            
            if yDiff < Y_THRESHOLD then
                phase = 2
                -- print("   ✅ Y-axis reached, moving to XZ...")
            else
                local yDirection = Vector3.new(0, targetPos.Y - currentPos.Y, 0)
                local speed = math.min(MOVE_SPEED, yDiff * 10)
                bv.Velocity = yDirection.Unit * speed
                bg.CFrame = CFrame.lookAt(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))
            end
        else
            -- Phase 2: Move XZ (horizontal) and fine-tune Y
            local direction = (targetPos - currentPos)
            local distance = direction.Magnitude

            if distance < XZ_THRESHOLD then
                print("   ✅ Reached destination!")

                reachedTarget = true

                bv.Velocity = Vector3.zero
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero

                task.wait(0.1)

                if bv and bv.Parent then bv:Destroy() end
                if bg and bg.Parent then bg:Destroy() end
                bodyVelocity = nil
                bodyGyro = nil

                if moveConn then moveConn:Disconnect() moveConn = nil end
                disableNoclip()

                if onComplete then onComplete() end
                return
            end

            local speed = math.min(MOVE_SPEED, distance * 10)
            local velocity = direction.Unit * speed

            bv.Velocity = velocity
            bg.CFrame = CFrame.lookAt(currentPos, targetPos)
        end
    end)
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
-- 🌐 SERVER HOP TO ISLAND2 (Low Player Server)
----------------------------------------------------------------
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local function getBestServer(placeId, maxPlayers)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
        placeId
    )
    
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    
    if not success then
        warn("   ❌ Failed to fetch servers: " .. tostring(response))
        return nil
    end
    
    local data = HttpService:JSONDecode(response)
    
    if not data or not data.data then
        warn("   ❌ Invalid server data")
        return nil
    end
    
    -- Find server with lowest player count
    local bestServer = nil
    local lowestPlayers = math.huge
    
    for _, server in ipairs(data.data) do
        if server.playing and server.playing < lowestPlayers and server.playing < server.maxPlayers then
            -- Prefer servers with <= maxPlayers
            if server.playing <= maxPlayers then
                lowestPlayers = server.playing
                bestServer = server
            elseif not bestServer then
                lowestPlayers = server.playing
                bestServer = server
            end
        end
    end
    
    return bestServer
end

local function serverHopToIsland2()
    if not QUEST_CONFIG.SERVER_HOP_ENABLED then
        print("   ⚠️ Server hop disabled, using normal teleport")
        return teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    end
    
    local placeId = QUEST_CONFIG.ISLAND2_PLACE_ID
    local maxPlayers = QUEST_CONFIG.MAX_PLAYERS_PREFERRED
    
    print("\n" .. string.rep("=", 50))
    print("🌐 SERVER HOP: Finding low-player server for Island2...")
    print(string.rep("=", 50))
    
    local bestServer = getBestServer(placeId, maxPlayers)
    
    if not bestServer then
        warn("   ❌ No suitable server found, using normal teleport")
        return teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    end
    
    print(string.format("   ✅ Found server: %d/%d players", bestServer.playing, bestServer.maxPlayers))
    print(string.format("   🆔 Server ID: %s", tostring(bestServer.id)))
    
    -- Queue Haze Loader anti-teleport script
    if queue_on_teleport then
        local queueScript = [[
            -- [[ HAZE LOADER TELEPORT STOPPER ]]
            local ui = Instance.new("ScreenGui")
            ui.Name = "TeleportStopper"
            ui.ResetOnSpawn = false
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 300, 0, 100)
            frame.Position = UDim2.new(0.5, -150, 0.5, -50)
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.BackgroundTransparency = 0.5
            frame.Parent = ui
            local text = Instance.new("TextLabel")
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.new(1, 1, 1)
            text.Text = "Stopping Teleport..."
            text.Parent = frame
            ui.Parent = gethui and gethui() or game:GetService("Players").PlayerGui
            task.spawn(function()
                task.wait(5)
                pcall(function() ui:Destroy() end)
            end)
            
            local stoppedTp = false
            while not stoppedTp do
                local tpService = cloneref and cloneref(game:GetService("TeleportService")) or game:GetService("TeleportService")
                pcall(function() tpService:SetTeleportGui(tpService) end)
                
                local logService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")
                pcall(function()
                    for i, v in logService:GetLogHistory() do
                        if v.message:find("cannot be cloned") then
                            stoppedTp = true
                            warn("✅ Teleport STOPPED!")
                            break
                        end
                    end
                end)
                
                task.wait()
                pcall(function() tpService:TeleportCancel() end)
                pcall(function() tpService:SetTeleportGui(nil) end)
            end
            pcall(function() ui:Destroy() end)
            warn("🎉 Anti-teleport completed!")
        ]]
        
        queue_on_teleport(queueScript)
        print("   📜 Queued anti-teleport script")
    end
    
    -- Teleport to the low-player server
    print(string.format("   🚀 Teleporting to Island2 (PlaceID: %d)...", placeId))
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, bestServer.id)
    end)
    
    if success then
        print("   ✅ Teleport initiated!")
        return true
    else
        warn("   ❌ Teleport failed: " .. tostring(err))
        -- Fallback to normal teleport
        return teleportToIsland(QUEST_CONFIG.ISLAND_NAME)
    end
end
----------------------------------------------------------------
local function buyArcanePickaxe()
    if not ARCANE_CONFIG.ENABLED then return false end
    
    -- Check if already have Arcane
    if hasPickaxe(ARCANE_CONFIG.TARGET_PICKAXE) then
        print("   💜 Already have Arcane Pickaxe!")
        return true
    end
    
    -- Check Gold
    local gold = getGold()
    print(string.format("   💰 Current Gold: %d (Need: %d)", gold, ARCANE_CONFIG.MIN_GOLD))
    
    if gold < ARCANE_CONFIG.MIN_GOLD then
        print("   ⚠️ Not enough gold for Arcane Pickaxe")
        return false
    end
    
    print("\n" .. string.rep("=", 50))
    print("💜 ARCANE PICKAXE: Starting purchase...")
    print(string.rep("=", 50))
    
    -- 🚪 STEP 1: Move to door and open it
    print(string.format("   🚪 Moving to door (%.1f, %.1f, %.1f)...", 
        ARCANE_CONFIG.DOOR_POSITION.X, ARCANE_CONFIG.DOOR_POSITION.Y, ARCANE_CONFIG.DOOR_POSITION.Z))
    
    local doorComplete = false
    smoothMoveTo(ARCANE_CONFIG.DOOR_POSITION, function()
        doorComplete = true
    end)
    
    local t0 = tick()
    while not doorComplete and tick() - t0 < 60 do
        task.wait(0.1)
    end
    
    if not doorComplete then
        warn("   ⚠️ Move to door timeout!")
        disableNoclip()
        return false
    end
    
    print("   ✅ Arrived at door!")
    print("   ⏳ Waiting 3 seconds before opening door...")
    task.wait(3)
    
    -- Open the door
    print("   🚪 Opening FallenAngelCaveDoor...")
    pcall(function()
        local doorArgs = {Workspace:WaitForChild("Proximity"):WaitForChild("FallenAngelCaveDoor")}
        FUNCTIONALS_RF:InvokeServer(unpack(doorArgs))
    end)
    
    print("   ✅ Door opened!")
    task.wait(1)
    
    -- 🛒 STEP 2: Move to shop
    print(string.format("   🚀 Moving to shop (%.1f, %.1f, %.1f)...", 
        ARCANE_CONFIG.BUY_POSITION.X, ARCANE_CONFIG.BUY_POSITION.Y, ARCANE_CONFIG.BUY_POSITION.Z))
    
    local moveComplete = false
    smoothMoveTo(ARCANE_CONFIG.BUY_POSITION, function()
        moveComplete = true
    end)
    
    t0 = tick()
    while not moveComplete and tick() - t0 < 60 do
        task.wait(0.1)
    end
    
    if not moveComplete then
        warn("   ⚠️ Move timeout!")
        disableNoclip()
        return false
    end
    
    print("   ✅ Arrived at shop!")
    print("   ⏳ Waiting 3 seconds...")
    task.wait(3)
    
    -- Purchase
    print("   🛒 Purchasing Arcane Pickaxe...")
    local args = {ARCANE_CONFIG.TARGET_PICKAXE, 1}
    pcall(function()
        PURCHASE_RF:InvokeServer(unpack(args))
    end)
    
    task.wait(1)
    
    -- Verify
    if hasPickaxe(ARCANE_CONFIG.TARGET_PICKAXE) then
        print("   ✅ Arcane Pickaxe purchased successfully!")
        return true
    else
        warn("   ❌ Purchase may have failed!")
        return false
    end
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 18: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Buy Arcane + Teleport to Forgotten Kingdom")
print(string.rep("=", 50))

-- Check Level
print("\n🔍 Pre-check: Verifying level requirement...")
if not hasRequiredLevel() then
    print("\n❌ Level requirement not met!")
    print(string.rep("=", 50))
    return
end

-- 💜 STEP 1: Try to buy Arcane Pickaxe first
print("\n🔍 Step 1: Checking Arcane Pickaxe...")
buyArcanePickaxe()

-- 🌀 STEP 2: Teleport to Island2
print("\n🔍 Step 2: Checking Location...")
if needsTeleport() then
    print("   ⚠️ Not on target island!")
    local success = serverHopToIsland2()
    
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