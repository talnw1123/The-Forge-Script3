local Shared = _G.Shared

-- QUEST 12: "Everything starts now!" (Talk to Wizard - Auto Complete)
-- ✅ Smooth Body Move to Wizard
-- ✅ Auto Dialogue → CheckQuest → FinishQuest
-- ✅ Force Restore UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest12Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "Everything starts now.",
    NPC_NAME = "Wizard",
    NPC_POSITION = Vector3.new(-24.1, 80.9, -358.5),
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
}

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

local function isQuest12StillActive()
    if not Quest12Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest12Active = false
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
-- NPC HELPERS
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
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
-- REMOTE FUNCTIONS
----------------------------------------------------------------
local function invokeDialogueStart(npcModel)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("ProximityService")
        :WaitForChild("RF"):WaitForChild("Dialogue")
    if remote then
        pcall(function() remote:InvokeServer(npcModel) end)
        print("📡 1. Started Dialogue")
    end
end

local function invokeRunCommand(commandName)
    local remote = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RF"):WaitForChild("RunCommand")
    if remote then
        print("📡 2. Executing Command: " .. commandName)
        pcall(function() remote:InvokeServer(commandName) end)
    end
end

----------------------------------------------------------------
-- UI RESTORE
----------------------------------------------------------------
local function forceEndDialogueAndRestore()
    print("🔧 3. Forcing Cleanup & UI Restore...")
    
    -- A. Close Dialogue & Fix Camera
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
    end
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end
    
    -- B. Remove Status Tags
    local char = player.Character
    if char then
        local status = char:FindFirstChild("Status")
        if status then
            for _, tag in ipairs(status:GetChildren()) do
                if tag.Name == "DisableBackpack" or tag.Name == "NoMovement" or tag.Name == "Talking" then
                    pcall(function() tag:Destroy() end)
                    print("   - Removed Status Tag: " .. tag.Name)
                end
            end
        end
        
        -- Restore Humanoid
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    -- C. Restore Main UI
    if gui then
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - Main UI (Quest) Restored")
        end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then 
            backpack.Enabled = true 
            print("   - Backpack Restored")
        end
        
        local compass = gui:FindFirstChild("Compass")
        if compass then compass.Enabled = true end
        
        local mobile = gui:FindFirstChild("MobileButtons")
        if mobile then mobile.Enabled = true end
    end
    
    -- D. Tell Server Closed
    local dialogueEvent = ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RE"):WaitForChild("DialogueEvent")
    if dialogueEvent then
        pcall(function() dialogueEvent:FireServer("Closed") end)
    end
    
    print("✅ Restore Complete")
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doTalkToWizard()
    print("📋 Objective: Talk to Wizard...")
    
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.NPC_NAME)
        warn("   💡 Trying to use static position instead...")
    end
    
    local targetPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (targetPos - hrp.Position).Magnitude
        print(string.format("   🚶 Moving to %s at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
            QUEST_CONFIG.NPC_NAME, targetPos.X, targetPos.Y, targetPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(targetPos, function()
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
        warn("   ⚠️ Failed to reach NPC, continuing anyway...")
    end
    
    -- Check NPC again
    if not npcModel then
        npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    end
    
    if not npcModel then
        warn("   ❌ Cannot find NPC model!")
        return false
    end
    
    print("\n📞 Starting Dialogue with Wizard...")
    task.wait(0.5)
    invokeDialogueStart(npcModel)
    
    print("⏳ Waiting for dialogue to open...")
    task.wait(1.5)
    
    print("✅ Selecting CheckQuest option...")
    invokeRunCommand("CheckQuest")
    
    print("⏳ Processing CheckQuest...")
    task.wait(0.8)
    
    print("✅ Sending FinishQuest command...")
    invokeRunCommand("FinishQuest")
    
    print("⏳ Processing FinishQuest...")
    task.wait(0.5)
    
    forceEndDialogueAndRestore()
    
    print("   ✅ Quest dialogue complete!")
    return true
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 12: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Talk to Wizard")
print("✅ Strategy: Auto CheckQuest + FinishQuest")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest12Active = false
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

while isQuest12StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    local success = doTalkToWizard()
    
    if success then
        print("   ✅ Dialogue sequence complete!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 All objectives complete!")
            break
        else
            print("   ⚠️ Quest not marked complete, retrying...")
            task.wait(2)
        end
    else
        warn("   ❌ Dialogue failed, retrying in 3s...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 12 Complete!")
    print("🎉 Everything Starts Now!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 12 incomplete after " .. attempt .. " attempts")
    warn(string.rep("=", 50))
end

Quest12Active = false
cleanupState()
disableNoclip()
