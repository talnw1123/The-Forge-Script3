local Shared = _G.Shared

-- QUEST 14: "Lost Guitar" (FIXED - Change Quest Viewing)
-- ✅ Move to Guitar (-46.2, -26.6, -63.4)
-- ✅ Collect Guitar via Functionals Remote
-- ✅ Move back to Bard NPC (-130.9, 27.8, 109.8)
-- ✅ Talk to NPC → CheckQuest → FinishQuest
-- ✅ Auto Complete Quest

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest14Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Lost Guitar!",
    QUEST_ID = "BardQuest",  -- Use instead of Introduction{N}
    
    -- Guitar Location
    GUITAR_OBJECT_NAME = "BardGuitar",
    GUITAR_POSITION = Vector3.new(-46.2, -26.6, -63.4),
    
    -- Bard NPC
    NPC_NAME = "Bard",
    NPC_POSITION = Vector3.new(-130.9, 27.8, 109.8),
    
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
local DialogueService = nil

pcall(function()
    PlayerController = Knit.GetController("PlayerController")
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local DIALOGUE_RF = nil
pcall(function()
    DIALOGUE_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
end)

local FUNCTIONALS_RF = nil
pcall(function()
    FUNCTIONALS_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Functionals", 3)
end)

local DIALOGUE_COMMAND_RF = nil
pcall(function()
    DIALOGUE_COMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if DialogueService then print("✅ DialogueService Ready!") else warn("⚠️ DialogueService not found") end
if DIALOGUE_RF then print("✅ Dialogue Remote Ready!") else warn("⚠️ Dialogue Remote not found") end
if FUNCTIONALS_RF then print("✅ Functionals Remote Ready!") else warn("⚠️ Functionals Remote not found") end
if DIALOGUE_COMMAND_RF then print("✅ DialogueCommand Remote Ready!") else warn("⚠️ DialogueCommand Remote not found") end

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
-- QUEST SYSTEM (FIXED - No Introduction{N})
----------------------------------------------------------------
local function getQuestObjectives(questID)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") and gui.Main:FindFirstChild("Screen") 
                 and gui.Main.Screen:FindFirstChild("Quests") and gui.Main.Screen.Quests:FindFirstChild("List")
    if not list then return nil, nil end
    
    -- Find Title (e.g. "BardQuestTitle")
    local titleFrame = list:FindFirstChild(questID .. "Title")
    if not titleFrame then
        if DEBUG_MODE then
            warn(string.format("   ❌ Quest Title not found: %sTitle", questID))
        end
        return nil, nil
    end
    
    -- Check if Title matches Quest Name
    if titleFrame:FindFirstChild("Frame") and titleFrame.Frame:FindFirstChild("TextLabel") then
        local questName = titleFrame.Frame.TextLabel.Text
        if DEBUG_MODE then
            print(string.format("   ✅ Found Quest: %s", questName))
        end
    end
    
    -- Find List (e.g. "BardQuestList")
    local objList = list:FindFirstChild(questID .. "List")
    if not objList then
        if DEBUG_MODE then
            warn(string.format("   ❌ Quest List not found: %sList", questID))
        end
        return nil, nil
    end
    
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

local function isQuest14StillActive()
    if not Quest14Active then return false end
    
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)
    if not questID or not objList then
        print("🛑 Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
        Quest14Active = false
        return false
    end
    
    return true
end

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)
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
-- OBJECT HELPERS
----------------------------------------------------------------
local function getProximityObject(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

----------------------------------------------------------------
-- GUITAR PICKUP
----------------------------------------------------------------
local function pickupGuitar()
    if not FUNCTIONALS_RF then
        warn("   ❌ Functionals Remote not available!")
        return false
    end
    
    local guitarObject = getProximityObject(QUEST_CONFIG.GUITAR_OBJECT_NAME)
    if not guitarObject then
        warn("   ❌ Guitar object not found: " .. QUEST_CONFIG.GUITAR_OBJECT_NAME)
        return false
    end
    
    print("   🎸 Picking up guitar...")
    
    local success, result = pcall(function()
        return FUNCTIONALS_RF:InvokeServer(guitarObject)
    end)
    
    if success then
        print("   ✅ Guitar picked up!")
        return true
    else
        warn("   ❌ Failed to pickup guitar: " .. tostring(result))
        return false
    end
end

----------------------------------------------------------------
-- NPC INTERACTION
----------------------------------------------------------------
local function openDialogue(npcModel)
    if not DIALOGUE_RF then
        warn("   ❌ Dialogue Remote not available!")
        return false
    end
    
    print("   📞 Opening Dialogue with " .. QUEST_CONFIG.NPC_NAME .. "...")
    
    local success = pcall(function()
        DIALOGUE_RF:InvokeServer(npcModel)
    end)
    
    if success then
        print("   ✅ Dialogue opened!")
        return true
    else
        warn("   ❌ Failed to open dialogue")
        return false
    end
end

local function runDialogueCommand(command)
    if not DIALOGUE_COMMAND_RF then
        warn("   ❌ DialogueCommand Remote not available!")
        return false
    end
    
    print(string.format("   💬 Running command: '%s'", command))
    
    local success, result = pcall(function()
        return DIALOGUE_COMMAND_RF:InvokeServer(command)
    end)
    
    if success then
        print(string.format("   ✅ Command '%s' executed successfully!", command))
        if DEBUG_MODE and result then
            print(string.format("   📊 Result: %s", tostring(result)))
        end
        return true
    else
        warn(string.format("   ❌ Failed to execute command '%s': %s", command, tostring(result)))
        return false
    end
end

----------------------------------------------------------------
-- UI RESTORE
----------------------------------------------------------------
local function forceRestoreUI()
    print("🔧 Forcing UI Restore...")
    
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
    
    if gui then
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
    end
    
    print("✅ UI Restore Complete")
end

----------------------------------------------------------------
-- MAIN QUEST EXECUTION
----------------------------------------------------------------
local function doCollectGuitar()
    print("🎸 Step 1: Collecting Guitar...")
    
    -- 1. Move to Guitar
    local guitarPos = QUEST_CONFIG.GUITAR_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (guitarPos - hrp.Position).Magnitude
        print(string.format("   🚶 Moving to Guitar at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
            guitarPos.X, guitarPos.Y, guitarPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(guitarPos, function()
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
        warn("   ⚠️ Failed to reach Guitar")
        return false
    end
    
    print("   ✅ Reached Guitar!")
    task.wait(1)
    
    -- 2. Pickup Guitar
    local pickupSuccess = pickupGuitar()
    
    if not pickupSuccess then
        warn("   ❌ Failed to pickup guitar")
        return false
    end
    
    task.wait(1)
    return true
end

local function doReturnGuitar()
    print("\n🎸 Step 2: Returning Guitar to Bard...")
    
    -- 1. Move to Bard NPC
    local npcPos = QUEST_CONFIG.NPC_POSITION
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if hrp then
        local currentDist = (npcPos - hrp.Position).Magnitude
        print(string.format("   🚶 Moving to %s at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
            QUEST_CONFIG.NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z, currentDist))
    end
    
    local moveComplete = false
    smoothMoveTo(npcPos, function()
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
        warn("   ⚠️ Failed to reach NPC")
        return false
    end
    
    print("   ✅ Reached NPC!")
    task.wait(1)
    
    -- 2. Find NPC Model
    local npcModel = getProximityObject(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    -- 3. Open Dialogue
    print("\n📞 Opening Dialogue...")
    local dialogueOpened = openDialogue(npcModel)
    
    if not dialogueOpened then
        warn("   ❌ Failed to open dialogue")
        return false
    end
    
    task.wait(1.5)
    
    -- 4. CheckQuest
    print("\n🔍 Checking quest status...")
    local checkSuccess = runDialogueCommand("CheckQuest")
    
    if not checkSuccess then
        warn("   ❌ Failed to check quest")
        return false
    end
    
    task.wait(1)
    
    -- 5. FinishQuest (Return Guitar)
    print("\n✅ Returning guitar to Bard...")
    local finishSuccess = runDialogueCommand("FinishQuest")
    
    if not finishSuccess then
        warn("   ❌ Failed to finish quest")
        return false
    end
    
    print("   ✅ Quest completed!")
    
    -- 6. Restore UI
    task.wait(1)
    forceRestoreUI()
    
    return true
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 14: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Find and Return Guitar to Bard")
print("✅ Strategy: Collect Guitar → Return to NPC → Finish Quest")
print(string.rep("=", 50))

local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_ID)

if not questID then
    warn("❌ Quest '" .. QUEST_CONFIG.QUEST_NAME .. "' not found!")
    warn(string.format("   💡 Looking for: %sTitle", QUEST_CONFIG.QUEST_ID))
    Quest14Active = false
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

while isQuest14StillActive() and not areAllObjectivesComplete() and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    -- Step 1: Collect Guitar
    local collectSuccess = doCollectGuitar()
    
    if not collectSuccess then
        warn("   ❌ Failed to collect guitar, retrying in 3s...")
        task.wait(3)
        continue
    end
    
    -- Step 2: Return Guitar
    local returnSuccess = doReturnGuitar()
    
    if returnSuccess then
        print("   ✅ Quest completed successfully!")
        task.wait(2)
        
        if areAllObjectivesComplete() then
            print("\n🎉 All objectives complete!")
            break
        else
            print("   ⚠️ Quest not marked complete, retrying...")
            task.wait(2)
        end
    else
        warn("   ❌ Failed to return guitar, retrying in 3s...")
        task.wait(3)
    end
end

task.wait(1)

if areAllObjectivesComplete() then
    print("\n" .. string.rep("=", 50))
    print("✅ Quest 14 Complete!")
    print(string.rep("=", 50))
else
    warn("\n" .. string.rep("=", 50))
    warn("⚠️ Quest 14 incomplete after " .. attempt .. " attempts")
    warn(string.rep("=", 50))
end

Quest14Active = false
cleanupState()
disableNoclip()
