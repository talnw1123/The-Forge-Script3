local Shared = _G.Shared

-- QUEST 13: Bard Quest (Level-based Auto Quest)
-- ✅ Check Level from PlayerGui.Main.Screen.Hud.Level
-- ✅ If Level < 10 → Move to Bard NPC
-- ✅ Open Dialogue → CheckQuest → GiveBardQuest
-- ✅ Auto accept quest and complete it

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local Quest13Active = true
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Bard Quest",  -- Quest Name (if not found, check Level)
    NPC_NAME = "Bard",
    NPC_POSITION = Vector3.new(-130.9, 27.8, 109.8),
    MIN_LEVEL = 10,  -- Minimum level required (actually max level for this quest?)
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

local DIALOGUE_COMMAND_RF = nil
pcall(function()
    DIALOGUE_COMMAND_RF = SERVICES:WaitForChild("DialogueService", 5):WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
end)

if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ProximityService then print("✅ ProximityService Ready!") else warn("⚠️ ProximityService not found") end
if DialogueService then print("✅ DialogueService Ready!") else warn("⚠️ DialogueService not found") end
if DIALOGUE_RF then print("✅ Dialogue Remote Ready!") else warn("⚠️ Dialogue Remote not found") end
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
        warn("   💡 Path: PlayerGui.Main.Screen.Hud.Level")
        return nil
    end
    
    if not levelLabel:IsA("TextLabel") then
        warn("   ❌ Level is not a TextLabel!")
        return nil
    end
    
    local levelText = levelLabel.Text
    print(string.format("   📊 Level Text: '%s'", levelText))
    
    -- Extract Level from text (e.g., "Level 7" → 7)
    local level = tonumber(string.match(levelText, "%d+"))
    
    if level then
        print(string.format("   ✅ Player Level: %d", level))
        return level
    else
        warn("   ❌ Failed to parse level from text!")
        return nil
    end
end

local function shouldDoQuest()
    local level = getPlayerLevel()
    
    if not level then
        warn("   ❌ Cannot determine player level!")
        return false
    end
    
    if level < QUEST_CONFIG.MIN_LEVEL then
        print(string.format("   ✅ Level %d < %d - Quest available!", level, QUEST_CONFIG.MIN_LEVEL))
        return true
    else
        print(string.format("   ⏸️  Level %d >= %d - Quest not available", level, QUEST_CONFIG.MIN_LEVEL))
        return false
    end
end

----------------------------------------------------------------
-- QUEST SYSTEM (Fallback - if quest name exists)
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

local function areAllObjectivesComplete()
    local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
    if not questID or not objList then return false end
    
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
        
        if distance < QUEST_CONFIG.NPC_STOP_DISTANCE then
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
-- NPC INTERACTION
----------------------------------------------------------------
local function getNpcModel(name)
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(name)
end

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
local function doAcceptQuest()
    print("📜 Objective: Accept Bard Quest...")
    
    -- 1. Check Level
    print("\n🔍 Checking if quest is available...")
    if not shouldDoQuest() then
        warn("   ❌ Quest not available (Level too high)")
        return false
    end
    
    -- 2. Find NPC
    local npcModel = getNpcModel(QUEST_CONFIG.NPC_NAME)
    if not npcModel then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.NPC_NAME)
        return false
    end
    
    -- 3. Move to NPC
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
    
    -- 4. Open Dialogue
    print("\n📞 Opening Dialogue...")
    local dialogueOpened = openDialogue(npcModel)
    
    if not dialogueOpened then
        warn("   ❌ Failed to open dialogue")
        return false
    end
    
    task.wait(1.5)
    
    -- 5. Check Quest (CheckQuest)
    print("\n🔍 Checking quest availability...")
    local checkSuccess = runDialogueCommand("CheckQuest")
    
    if not checkSuccess then
        warn("   ❌ Failed to check quest")
        return false
    end
    
    task.wait(1)
    
    -- 6. Accept Quest (GiveBardQuest)
    print("\n✅ Accepting quest...")
    local giveSuccess = runDialogueCommand("GiveBardQuest")
    
    if not giveSuccess then
        warn("   ❌ Failed to accept quest")
        return false
    end
    
    print("   ✅ Quest accepted!")
    
    -- 7. Restore UI
    task.wait(1)
    forceRestoreUI()
    
    return true
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 13: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Accept Bard Quest (Level-based)")
print(string.format("✅ Strategy: Check Level → Move to NPC → Accept Quest"))
print(string.rep("=", 50))

-- Check Level First
print("\n🔍 Pre-check: Verifying level requirement...")
if not shouldDoQuest() then
    print("\n✅ Quest not available (Level too high)")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

local maxAttempts = 3
local attempt = 0

while Quest13Active and attempt < maxAttempts do
    attempt = attempt + 1
    print(string.format("\n🔄 Attempt #%d", attempt))
    
    local success = doAcceptQuest()
    
    if success then
        print("   ✅ Quest accepted successfully!")
        task.wait(2)
        
        -- Check if quest is in UI
        local questID, objList = getQuestObjectives(QUEST_CONFIG.QUEST_NAME)
        if questID then
            print("\n🎉 Quest found in Quest Log!")
            
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
            
            break
        else
            print("   ⚠️ Quest not found in Quest Log, but accepted")
            break
        end
    else
        warn("   ❌ Failed to accept quest, retrying in 3s...")
        task.wait(3)
    end
end

task.wait(1)

print("\n" .. string.rep("=", 50))
print("✅ Quest 13 Complete!")
print(string.rep("=", 50))

Quest13Active = false
cleanupState()
disableNoclip()
