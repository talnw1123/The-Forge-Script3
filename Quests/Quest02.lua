--[[
    ⚔️ QUEST 02: First Pickaxe!
    📋 Open Equipments → Equip Stone Pickaxe → Mine Pebbles
    📍 Extracted from 0.lua (lines 592-1548)
--]]

-- QUEST 2: "First Pickaxe!" (SMART SYSTEM: Priority-based + Flexible + smoothMoveTo)
-- Priority Order: 1) Open Equipments → 2) Equip Pickaxe → 3) Mine Pebbles

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
local Quest2Active = true
local QUEST_CONFIG = {
    QUEST_NAME = "First Pickaxe!",
    PICKAXE_NAME = "Stone Pickaxe",
    MINING_START_POSITION = Vector3.new(43.203, -3.717, -106.628),
    UNDERGROUND_OFFSET = 4,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 25,
    STOP_DISTANCE = 2,
    PRIORITY_ORDER = {
        "Open",
        "Equip",
        "Mine",
    },
}

----------------------------------------------------------------
-- SERVICES & REMOTES
----------------------------------------------------------------
local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
local CHAR_RF = SERVICES:WaitForChild("CharacterService"):WaitForChild("RF"):WaitForChild("EquipItem")
local TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService"):WaitForChild("RF"):WaitForChild("ToolActivated")

local MINING_FOLDER_PATH = nil
do
    local ok, rocks = pcall(function()
        return Workspace:FindFirstChild("Rocks")
    end)
    if ok and rocks then
        MINING_FOLDER_PATH = rocks:FindFirstChild("Island1CaveStart")
    end
    if not MINING_FOLDER_PATH then
        warn("[Quest2] Rocks/Island1CaveStart not found – skipping Quest 2 on this map.")
        return
    end
end

----------------------------------------------------------------
-- HOOK CONTROLLERS
----------------------------------------------------------------
local UIController = nil
local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Open") and rawget(v, "Modules") then
                UIController = v
            end
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
            end
        end
    end
end)

if UIController then print("✅ UIController Hooked!") else warn("⚠️ UIController not found") end
if ToolController then print("✅ ToolController Hooked!") else warn("⚠️ ToolController not found (using backup)") end

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    moveConn = nil,
    hpWatchConn = nil,
    noclipConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
    positionLockConn = nil, 
    currentObjectiveFrame = nil,
}

local function restoreCollisions()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

local function cleanupState()
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    State.currentTarget = nil
    State.targetDestroyed = false
    if ToolController then ToolController.holdingM1 = false end
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

local function isQuest2StillActive()
    if not Quest2Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' disappeared!")
        Quest2Active = false
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
    if string.find(text, "Open Equipments") or string.find(text, "Open") then
        return "Open"
    elseif string.find(text, "Equip") and string.find(text, "Pickaxe") then
        return "Equip"
    elseif string.find(text, "Get Ore") or string.find(text, "Mine") or string.find(text, "Pebble") then
        return "Mine"
    else
        return "Unknown"
    end
end

local function canDoObjective(objType)
    return true
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
    restoreCollisions()
end

local function smoothMoveTo(targetPos, stopDistance, callback)
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
    
    State.moveConn = RunService.Heartbeat:Connect(function()
        if State.targetDestroyed or not Quest2Active then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv then bv.Velocity = Vector3.zero bv:Destroy() end
            if bg then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
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
        
        if distance < stopDistance then
            bv.Velocity = Vector3.zero
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
-- HELPER FUNCTIONS
----------------------------------------------------------------
local function getPebbleUndergroundPosition(pebbleModel)
    if not pebbleModel or not pebbleModel.Parent then 
        return nil 
    end
    
    local pivotCFrame = nil
    pcall(function()
        if pebbleModel.GetPivot then
            pivotCFrame = pebbleModel:GetPivot()
        elseif pebbleModel.WorldPivot then
            pivotCFrame = pebbleModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    if pebbleModel.PrimaryPart then
        local pos = pebbleModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    local part = pebbleModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end
    
    return nil
end

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

local function getPebblePosition(pebbleModel)
    if not pebbleModel or not pebbleModel.Parent then 
        return nil 
    end
    
    if pebbleModel.PrimaryPart then
        return pebbleModel.PrimaryPart.Position
    end
    
    local part = pebbleModel:FindFirstChildWhichIsA("BasePart")
    return part and part.Position or nil
end

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
    
    print("   🔒 Position locked (laying down)")
end

local function unlockPosition()
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        print("   🔓 Position unlocked")
    end
end

----------------------------------------------------------------
-- HP CHECKER
----------------------------------------------------------------
local function getPebbleHP(pebble)
    if not pebble or not pebble.Parent then return 0 end
    
    local success, result = pcall(function()
        return pebble:GetAttribute("Health") or 0
    end)
    
    return success and result or 0
end

local function isTargetValid(pebble)
    if not pebble or not pebble.Parent then return false end
    if not pebble:FindFirstChildWhichIsA("BasePart") then return false end
    
    local hp = getPebbleHP(pebble)
    return hp > 0
end

----------------------------------------------------------------
-- VIRTUAL CLICK
----------------------------------------------------------------
local function VirtualClick(guiObject)
    if not guiObject then 
        warn("❌ GUI Object not found!")
        return false 
    end
    
    local clickSuccess = pcall(function()
        local conns = getconnections(guiObject.MouseButton1Click)
        for _, conn in pairs(conns) do
            conn:Fire()
        end
    end)
    
    local activatedSuccess = pcall(function()
        local conns = getconnections(guiObject.Activated)
        for _, conn in pairs(conns) do
            conn:Fire()
        end
    end)
    
    if clickSuccess or activatedSuccess then
        print("   ✅ Click executed")
        return true
    end
    return false
end

----------------------------------------------------------------
-- TARGET FINDER
----------------------------------------------------------------
local function findNearestPebble()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local targetPebble, minDist = nil, math.huge
    
    for _, child in ipairs(MINING_FOLDER_PATH:GetChildren()) do
        if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
            local pebble = child:FindFirstChild("Pebble")
            if isTargetValid(pebble) then
                local pos = getPebblePosition(pebble)
                if pos then
                    local dist = (pos - hrp.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        targetPebble = pebble
                    end
                end
            end
        end
    end
    
    return targetPebble, minDist
end

----------------------------------------------------------------
-- MOVE TO STARTING POSITION
----------------------------------------------------------------
local function moveToStartPosition()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local currentDist = (QUEST_CONFIG.MINING_START_POSITION - hrp.Position).Magnitude
    
    if currentDist > 50 then
        print(string.format("📍 Moving to starting position (%.1f studs away)...", currentDist))
        
        local moveComplete = false
        smoothMoveTo(QUEST_CONFIG.MINING_START_POSITION, 5, function()
            moveComplete = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveComplete and tick() - startTime < timeout do
            if not hrp or not hrp.Parent then break end
            local dist = (QUEST_CONFIG.MINING_START_POSITION - hrp.Position).Magnitude
            if dist < 8 then
                moveComplete = true
                break
            end
            task.wait(0.1)
        end
        
        if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
        if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
        if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
        
        print("   ✅ Reached starting position!")
        task.wait(0.3)
    else
        print("   ✅ Already near starting position!")
    end
    
    return true
end

----------------------------------------------------------------
-- WATCH HP
----------------------------------------------------------------
local function watchPebbleHP(pebble)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not pebble then return end
    
    State.hpWatchConn = pebble:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = pebble:GetAttribute("Health") or 0
        print(string.format("   ⚡ [HP Changed!] New HP: %d", hp))
        
        if hp <= 0 then
            print("   💥 HP = 0 detected! Switching target...")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
        end
    end)
end

----------------------------------------------------------------
-- ACTIONS
----------------------------------------------------------------
local function doOpenEquipments()
    print("📦 Objective: Opening Equipments...")
    
    if not UIController then
        warn("   ❌ UIController not available")
        return false
    end
    
    if UIController.Modules["Inventory"] then
        pcall(function() UIController:Open("Inventory") end)
    end
    
    if UIController.Modules["Menu"] then
        pcall(function() UIController:Open("Menu") end)
        
        local menuModule = UIController.Modules["Menu"]
        if menuModule.OpenTab then
            pcall(function() menuModule:OpenTab("Inventory") end)
            pcall(function() menuModule:OpenTab("Equipments") end)
        elseif menuModule.SwitchTab then
            pcall(function() menuModule:SwitchTab("Inventory") end)
        end
    end
    
    print("   ⏳ Waiting for Menu...")
    task.wait(1)
    
    local toolsButton = nil
    pcall(function()
        toolsButton = playerGui.Menu.Frame.Frame.BottomBar.Buttons.Buttons.Tools
    end)
    
    if toolsButton then
        print("   🖱️ Clicking Tools...")
        VirtualClick(toolsButton)
        task.wait(0.5)
        
        print("   🚪 Closing Menu...")
        if UIController and UIController.Close then
            pcall(function() UIController:Close("Menu") end)
        end
        task.wait(0.3)
        return true
    else
        warn("   ❌ Tools button not found")
        return false
    end
end

local function doEquipPickaxe()
    print("⛏️ Objective: Equipping Stone Pickaxe...")
    
    local key = findPickaxeSlotKey()
    if key then
        print("   🔢 Using hotkey...")
        pressKey(key)
        task.wait(0.5)
    else
        print("   📡 Using remote...")
        pcall(function() 
            CHAR_RF:InvokeServer({Runes = {}, Name = QUEST_CONFIG.PICKAXE_NAME}) 
        end)
        task.wait(0.5)
    end
    
    local char = player.Character
    local tool = char and char:FindFirstChildWhichIsA("Tool")
    if tool and string.find(tool.Name, "Pickaxe") then
        print("   ✅ Pickaxe equipped!")
        return true
    else
        warn("   ⚠️ Pickaxe not in hand yet")
        return false
    end
end

local function doMinePebbles()
    print("🪨 Objective: Mining Pebbles...")
    print("\n" .. string.rep("-", 30))
    print("🚶 Step 1: Moving to starting position...")
    print(string.rep("-", 30))
    
    moveToStartPosition()
    
    print("\n" .. string.rep("-", 30))
    print("⛏️  Step 2: Starting mining loop...")
    print(string.rep("-", 30))
    
    while isQuest2StillActive() and not isCurrentObjectiveComplete() do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            task.wait(1)
            continue
        end
        
        cleanupState()
        
        local targetPebble, dist = findNearestPebble()
        
        if not targetPebble then
            warn("   ❌ No Pebbles found, waiting...")
            task.wait(2)
            continue
        end
        
        State.currentTarget = targetPebble
        State.targetDestroyed = false
        
        local targetPos = getPebbleUndergroundPosition(targetPebble)
        if not targetPos then
            warn("   ❌ Cannot get pebble underground position!")
            task.wait(1)
            continue
        end
        
        local currentHP = getPebbleHP(targetPebble)
        local targetName = "Unknown"
        pcall(function()
            if targetPebble.Parent then
                targetName = targetPebble.Parent.Name or "Unknown"
            end
        end)

        print(string.format("   🎯 Target: %s (dist: %d, HP: %d)", 
            targetName, math.floor(dist), currentHP))
        
        watchPebbleHP(targetPebble)
        
        local moveStarted = false
        smoothMoveTo(targetPos, QUEST_CONFIG.STOP_DISTANCE, function()
            lockPositionLayingDown(targetPos)
            moveStarted = true
        end)
        
        local timeout = 60
        local startTime = tick()
        while not moveStarted and (tick() - startTime) < timeout do
            task.wait(0.1)
        end
        
        if not moveStarted then
            lockPositionLayingDown(targetPos)
        end
        
        task.wait(0.5)
        
        while not State.targetDestroyed and isQuest2StillActive() and not isCurrentObjectiveComplete() do
            if not char or not char.Parent then
                print("   💀 Character died!")
                break
            end
            
            if not targetPebble or not targetPebble.Parent then
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
                    pcall(function() CHAR_RF:InvokeServer({Runes = {}}, {Name = QUEST_CONFIG.PICKAXE_NAME}) end)
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
        
        if isCurrentObjectiveComplete() then
            print("✅ Objective (Mine Pebbles) Complete!")
            break
        end
        
        print("   🔄 Finding next target...")
        task.wait(0.5)
    end
    
    print("\n🛑 Mining ended")
    unlockPosition()
    cleanupState()
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
local function RunQuest2_Smart()
    print(string.rep("=", 50))
    print("🚀 QUEST 2: " .. QUEST_CONFIG.QUEST_NAME)
    print("🎯 SMART SYSTEM: Priority-based + Flexible")
    print("📋 Priority Order: Open → Equip → Mine")
    print("🛡️  Noclip + smoothMoveTo enabled")
    print(string.rep("=", 50))
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    
    if not questID then
        warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not active")
        Quest2Active = false
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
    
    local maxAttempts = 5
    local attempt = 0
    
    while isQuest2StillActive() and attempt < maxAttempts do
        attempt = attempt + 1
        print(string.format("\n🔄 Quest Cycle #%d", attempt))
        
        local allComplete = true
        local didSomething = false
        
        for _, obj in ipairs(objectives) do
            if not isQuest2StillActive() then
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
                
                State.currentObjectiveFrame = obj.frame
                
                print(string.format("\n📋 Processing [%s]: %s", obj.type, obj.text))
                
                local success = false
                
                if obj.type == "Open" then
                    success = doOpenEquipments()
                    didSomething = true
                    task.wait(1)
                    
                elseif obj.type == "Equip" then
                    success = doEquipPickaxe()
                    didSomething = true
                    task.wait(1)
                    
                elseif obj.type == "Mine" then
                    doMinePebbles()
                    didSomething = true
                    
                else
                    warn("   ⚠️ Unknown objective type: " .. obj.type)
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
        print("✅ Quest 2 Complete!")
        print(string.rep("=", 50))
    else
        warn("\n" .. string.rep("=", 50))
        warn("⚠️ Quest 2 incomplete after " .. attempt .. " cycles")
        warn(string.rep("=", 50))
    end
    
    Quest2Active = false
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- START
----------------------------------------------------------------
RunQuest2_Smart()
