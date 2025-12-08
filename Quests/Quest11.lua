local Shared = _G.Shared

-- QUEST 11: "End of the Beginning!" (Report to Sensei Moro - Final Quest)
-- ✅ Body Move to Sensei Moro
-- ✅ Dialogue + CheckQuest
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
local Quest11Active = true

local QUEST_CONFIG = {
    QUEST_NAME = "End of the Beginning",
    NPC_NAME = "Sensei Moro",
    QUEST_OPTION_ARG = "CheckQuest",
    MOVE_SPEED = 25,  
    NPC_STOP_DISTANCE = 5,
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local ProximityService = nil
local DialogueService = nil

pcall(function()
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local DIALOGUE_RF = nil
pcall(function()
    DIALOGUE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
end)

local RUNCOMMAND_RF = nil
pcall(function()
    RUNCOMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

local DIALOGUE_RE = nil
pcall(function()
    DIALOGUE_RE = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RE", 3):WaitForChild("DialogueEvent", 3)
end)

if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if DialogueService then print("✅ DialogueService Ready!") else warn("⚠️ DialogueService not found") end
if DIALOGUE_RF then print("✅ Dialogue Remote Ready!") else warn("⚠️ Dialogue Remote not found") end
if RUNCOMMAND_RF then print("✅ RunCommand Remote Ready!") else warn("⚠️ RunCommand Remote not found") end

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

local function isQuest11StillActive()
    if not Quest11Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest11Active = false
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

local function getNpcPosition(npcModel)
    if not npcModel then return nil end
    
    local targetPart = npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
    if not targetPart then return nil end
    
    return targetPart.Position
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
-- UI RESTORE
----------------------------------------------------------------
local function forceRestoreUI()
    print("🔧 Forcing UI Restore...")
    
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
        
        local humanoid = char:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            humanoid.JumpPower = 50
        end
    end
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
        
        local main = gui:FindFirstChild("Main")
        if main then 
            main.Enabled = true 
            print("   - Main UI Restored")
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
    
    local cam = Workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        cam.FieldOfView = 70
    end
    
    if DIALOGUE_RE then
        pcall(function() DIALOGUE_RE:FireServer("Closed") end)
    end
    
    print("✅ UI Restore Complete")
end

----------------------------------------------------------------
-- DIALOGUE SYSTEM
----------------------------------------------------------------
local function startDialogue(npcModel)
    if not DIALOGUE_RF then
        warn("   ❌ Dialogue Remote not available!")
        return false
    end
    
    print("📞 Starting Dialogue with " .. QUEST_CONFIG.NPC_NAME .. "...")
    
    local success = pcall(function()
        DIALOGUE_RF:InvokeServer(npcModel)
    end)
    
    if success then
        print("   ✅ Dialogue started!")
        return true
    else
        warn("   ❌ Failed to start dialogue")
        return false
    end
end

local function selectQuestOption(optionName)
    if not RUNCOMMAND_RF then
        warn("   ❌ RunCommand Remote not available!")
        return false
    end
    
    print("✅ Selecting Option: " .. optionName)
    
    local success = pcall(function()
        RUNCOMMAND_RF:InvokeServer(optionName)
    end)
    
    if success then
        print("   ✅ Option selected!")
        return true
    else
        warn("   ❌ Failed to select option")
        return false
    end
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doReportToSenseiMoro()
    print("📋 Objective: Report to Sensei Moro (Final Quest)...")
    
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    local targetPos = getNpcPosition(npcModel)
    if not targetPos then
        warn("   ❌ Cannot get NPC position!")
        return false
    end
    
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
        warn("   ❌ Failed to reach NPC (timeout)")
        return false
    end
    
    print("\n📞 Interacting with Sensei Moro...")
    task.wait(0.5)
    
    local dialogueSuccess = startDialogue(npcModel)
    if not dialogueSuccess then
        warn("   ❌ Dialogue failed!")
        return false
    end
    
    print("   ⏳ Waiting for dialogue to open...")
    task.wait(1.5)
    
    local optionSuccess = selectQuestOption(QUEST_CONFIG.QUEST_OPTION_ARG)
    if not optionSuccess then
        warn("   ❌ Option selection failed!")
    end
    
    print("   ⏳ Processing...")
    task.wait(1)
    
    forceRestoreUI()
    
    print("   ✅ Dialogue complete!")
    return true
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 11: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Report to Sensei Moro (FINAL QUEST)")
print("🏆 Completing Introduction Quest Line!")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    Quest11Active = false
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

while isQuest11StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    local success = doReportToSenseiMoro()
    
    if success then
        print("   ✅ Reporting complete!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 All objectives complete!")
            break
        else
            print("   ⚠️ Quest not marked complete, retrying...")
            task.wait(2)
        end
    else
        warn("   ❌ Reporting failed, retrying in 3s...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("🏆 QUEST 11 COMPLETE!")
    print("🎉 INTRODUCTION QUEST LINE FINISHED!")
    print("✨ Congratulations!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 11 incomplete after " .. attempt .. " attempts")
    warn(string.rep("=", 50))
end

Quest11Active = false
cleanupState()
disableNoclip()
