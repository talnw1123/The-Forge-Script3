--[[
    🔧 SHARED UTILITIES
    📦 ใช้ร่วมกันทุก Quest
    
    Usage: ถูกโหลดโดย Loader.lua อัตโนมัติ
    Access: _G.Shared.functionName()
--]]

----------------------------------------------------------------
-- 📦 GLOBAL SHARED TABLE
----------------------------------------------------------------
_G.Shared = _G.Shared or {}
local Shared = _G.Shared

----------------------------------------------------------------
-- 🎮 SERVICES
----------------------------------------------------------------
Shared.Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    GuiService = game:GetService("GuiService"),
    Workspace = game:GetService("Workspace"),
}

local Services = Shared.Services
local player = Services.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

----------------------------------------------------------------
-- 🔧 STATE MANAGEMENT
----------------------------------------------------------------
Shared.State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,
}

function Shared.cleanupState()
    local State = Shared.State
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    State.currentTarget = nil
    State.targetDestroyed = false
end

----------------------------------------------------------------
-- 🔓 COLLISION RESTORE
----------------------------------------------------------------
function Shared.restoreCollisions()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

----------------------------------------------------------------
-- 👻 NOCLIP SYSTEM
----------------------------------------------------------------
function Shared.enableNoclip()
    local State = Shared.State
    if State.noclipConn then return end
    
    local char = player.Character
    if not char then return end
    
    State.noclipConn = Services.RunService.Stepped:Connect(function()
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

function Shared.disableNoclip()
    local State = Shared.State
    if State.noclipConn then
        State.noclipConn:Disconnect()
        State.noclipConn = nil
    end
    Shared.restoreCollisions()
end

----------------------------------------------------------------
-- 🚀 SMOOTH MOVEMENT (BodyVelocity + BodyGyro)
----------------------------------------------------------------
function Shared.smoothMoveTo(targetPos, stopDistance, moveSpeed, callback)
    local State = Shared.State
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    stopDistance = stopDistance or 2
    moveSpeed = moveSpeed or 25
    
    -- Cleanup previous movement
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end
    
    Shared.enableNoclip()
    
    -- Create BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp
    State.bodyVelocity = bv
    
    -- Create BodyGyro
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 10000
    bg.D = 500
    bg.Parent = hrp
    State.bodyGyro = bg
    
    print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    
    local reachedTarget = false
    
    State.moveConn = Services.RunService.Heartbeat:Connect(function()
        if reachedTarget then return end
        
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end
        
        local currentPos = hrp.Position
        local direction = (targetPos - currentPos)
        local distance = direction.Magnitude
        
        if distance < stopDistance then
            print(string.format("   ✅ Reached target! (%.1f studs)", distance))
            
            reachedTarget = true
            
            bv.Velocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            
            task.wait(0.1)
            
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            
            if callback then callback() end
            return
        end
        
        local speed = math.min(moveSpeed, distance * 10)
        local velocity = direction.Unit * speed
        
        bv.Velocity = velocity
        bg.CFrame = CFrame.lookAt(currentPos, targetPos)
    end)
    
    return true
end

----------------------------------------------------------------
-- 🔒 POSITION LOCK (Laying Down)
----------------------------------------------------------------
function Shared.lockPositionLayingDown(targetPos, layingAngle)
    local State = Shared.State
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    layingAngle = layingAngle or 90
    
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end
    
    local angle = math.rad(layingAngle)
    local baseCFrame = CFrame.new(targetPos)
    local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)
    
    State.positionLockConn = Services.RunService.Heartbeat:Connect(function()
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

function Shared.unlockPosition()
    local State = Shared.State
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        print("   🔓 Position unlocked")
    end
end

function Shared.SoftUnlockPosition()
    Shared.unlockPosition()
end

----------------------------------------------------------------
-- ⌨️ KEYBOARD INPUT
----------------------------------------------------------------
Shared.HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four, ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven, ["8"] = Enum.KeyCode.Eight, ["9"] = Enum.KeyCode.Nine, 
    ["0"] = Enum.KeyCode.Zero
}

function Shared.pressKey(keyCode)
    if not keyCode then return end
    Services.VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    Services.VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

----------------------------------------------------------------
-- 🔧 TOOL HELPERS
----------------------------------------------------------------
function Shared.findPickaxeSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    local hotbar = gui:FindFirstChild("BackpackGui") 
        and gui.BackpackGui:FindFirstChild("Backpack") 
        and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and string.find(label.Text, "Pickaxe") then
                return Shared.HOTKEY_MAP[slotFrame.Name]
            end
        end
    end
    return nil
end

function Shared.findWeaponSlotKey()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    local hotbar = gui:FindFirstChild("BackpackGui") 
        and gui.BackpackGui:FindFirstChild("Backpack") 
        and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")
    if hotbar then
        for _, slotFrame in ipairs(hotbar:GetChildren()) do
            local frame = slotFrame:FindFirstChild("Frame")
            local label = frame and frame:FindFirstChild("ToolName")
            if label and label:IsA("TextLabel") and not string.find(label.Text, "Pickaxe") and label.Text ~= "" then
                return Shared.HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end
    return nil, nil
end

----------------------------------------------------------------
-- 📊 HP HELPERS
----------------------------------------------------------------
function Shared.getRockHP(rock)
    if not rock or not rock.Parent then return 0 end
    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)
    return success and result or 0
end

function Shared.isRockValid(rock)
    if not rock or not rock.Parent then return false end
    if not rock:FindFirstChildWhichIsA("BasePart") then return false end
    return Shared.getRockHP(rock) > 0
end

function Shared.getZombieHP(zombie)
    if not zombie or not zombie.Parent then return 0 end
    local humanoid = zombie:FindFirstChild("Humanoid")
    if humanoid then return humanoid.Health or 0 end
    return 0
end

function Shared.isZombieValid(zombie)
    if not zombie or not zombie.Parent then return false end
    return Shared.getZombieHP(zombie) > 0
end

----------------------------------------------------------------
-- 📍 POSITION HELPERS
----------------------------------------------------------------
function Shared.getRockUndergroundPosition(rockModel, offset)
    offset = offset or 4
    if not rockModel or not rockModel.Parent then return nil end
    
    local pivotCFrame = nil
    pcall(function()
        if rockModel.GetPivot then
            pivotCFrame = rockModel:GetPivot()
        elseif rockModel.WorldPivot then
            pivotCFrame = rockModel.WorldPivot
        end
    end)
    
    if pivotCFrame then
        local pos = pivotCFrame.Position
        return Vector3.new(pos.X, pos.Y - offset, pos.Z)
    end
    
    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - offset, pos.Z)
    end
    
    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - offset, pos.Z)
    end
    
    return nil
end

function Shared.getZombieUndergroundPosition(zombieModel, offset)
    offset = offset or 5
    if not zombieModel or not zombieModel.Parent then return nil end
    
    local hrp = zombieModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - offset, pos.Z)
    end
    
    return nil
end

----------------------------------------------------------------
-- ⚠️ ERROR CHECKING
----------------------------------------------------------------
function Shared.checkMiningError()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local notif = gui:FindFirstChild("Notifications")
    if not notif then return false end
    
    local screen = notif:FindFirstChild("Screen")
    if not screen then return false end
    
    local notifFrame = screen:FindFirstChild("NotificationsFrame")
    if not notifFrame then return false end
    
    -- Loop ALL TextFrame children in NotificationsFrame
    -- Path: NotificationsFrame → TextFrame → TextFrame → TextLabel
    for _, textFrame1 in ipairs(notifFrame:GetChildren()) do
        if textFrame1.Name == "TextFrame" and textFrame1:IsA("Frame") then
            local textFrame2 = textFrame1:FindFirstChild("TextFrame")
            if textFrame2 then
                local textLabel = textFrame2:FindFirstChild("TextLabel")
                if textLabel and textLabel:IsA("TextLabel") then
                    if string.find(textLabel.Text, "Someone else is already mining") then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

----------------------------------------------------------------
-- 📋 QUEST HELPERS
----------------------------------------------------------------
function Shared.getQuestObjectives(questName)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil, nil end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
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

function Shared.isObjectiveComplete(item)
    if not item then return false end
    local check = item:FindFirstChild("Main") 
        and item.Main:FindFirstChild("Frame") 
        and item.Main.Frame:FindFirstChild("Check")
    return check and check.Visible
end

function Shared.getObjectiveText(item)
    local lbl = item:FindFirstChild("Main") and item.Main:FindFirstChild("TextLabel")
    return lbl and lbl.Text or ""
end

function Shared.isQuestComplete(questName)
    local questID, objList = Shared.getQuestObjectives(questName)
    if not questID or not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            if not Shared.isObjectiveComplete(item) then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- 🎭 DIALOGUE HELPERS
----------------------------------------------------------------
function Shared.invokeDialogueStart(npcModel)
    local remote = Services.ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("ProximityService")
        :WaitForChild("RF"):WaitForChild("Dialogue")
    if remote then
        remote:InvokeServer(npcModel)
        print("📡 Started Dialogue")
    end
end

function Shared.invokeRunCommand(commandName)
    local remote = Services.ReplicatedStorage:WaitForChild("Shared")
        :WaitForChild("Packages"):WaitForChild("Knit")
        :WaitForChild("Services"):WaitForChild("DialogueService")
        :WaitForChild("RF"):WaitForChild("RunCommand")
    if remote then
        print("📡 Selecting Option: " .. commandName)
        pcall(function() remote:InvokeServer(commandName) end)
    end
end

function Shared.forceEndDialogue()
    print("🔧 Forcing Dialogue Cleanup...")
    
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local dUI = gui:FindFirstChild("DialogueUI")
        if dUI then
            dUI.Enabled = false
            local bb = dUI:FindFirstChild("ResponseBillboard")
            if bb then bb.Visible = false end
        end
    end
    
    local cam = Services.Workspace.CurrentCamera
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
                    tag:Destroy()
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
        if main then main.Enabled = true end
        
        local backpack = gui:FindFirstChild("BackpackGui")
        if backpack then backpack.Enabled = true end
    end
    
    local dialogueRE = Services.ReplicatedStorage:FindFirstChild("Shared")
        and Services.ReplicatedStorage.Shared:FindFirstChild("Packages")
        and Services.ReplicatedStorage.Shared.Packages:FindFirstChild("Knit")
        and Services.ReplicatedStorage.Shared.Packages.Knit:FindFirstChild("Services")
        and Services.ReplicatedStorage.Shared.Packages.Knit.Services:FindFirstChild("DialogueService")
        and Services.ReplicatedStorage.Shared.Packages.Knit.Services.DialogueService:FindFirstChild("RE")
        and Services.ReplicatedStorage.Shared.Packages.Knit.Services.DialogueService.RE:FindFirstChild("DialogueEvent")
    
    if dialogueRE then
        dialogueRE:FireServer("Closed")
    end
    
    print("✅ Dialogue cleanup complete")
end

----------------------------------------------------------------
-- 🖱️ VIRTUAL CLICK
----------------------------------------------------------------
function Shared.virtualClick(guiObject)
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
-- 🛡️ ANTI-AFK
----------------------------------------------------------------
function Shared.startAntiAfk(interval, clickCount)
    interval = interval or 120
    clickCount = clickCount or 5
    
    task.spawn(function()
        print("🛡️ [ANTI-AFK] Started! Clicking every " .. interval .. " seconds.")
        while true do
            task.wait(interval)
            pcall(function()
                local camera = Services.Workspace.CurrentCamera
                local viewportSize = camera.ViewportSize
                local guiInset = Services.GuiService:GetGuiInset()
                local centerX = viewportSize.X / 2
                local centerY = (viewportSize.Y / 2) + guiInset.Y
                
                for i = 1, clickCount do
                    Services.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
                    task.wait(0.05)
                    Services.VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
                    task.wait(0.5)
                end
            end)
        end
    end)
end

----------------------------------------------------------------
-- 🔗 KNIT SERVICES (Lazy Loading)
----------------------------------------------------------------
Shared.Knit = nil
Shared.KnitServices = {}
Shared.KnitControllers = {}

function Shared.getKnit()
    if Shared.Knit then return Shared.Knit end
    
    pcall(function()
        local KnitPackage = Services.ReplicatedStorage:WaitForChild("Shared")
            :WaitForChild("Packages"):WaitForChild("Knit")
        Shared.Knit = require(KnitPackage)
        
        if not Shared.Knit.OnStart then 
            pcall(function() Shared.Knit.Start():await() end)
        end
    end)
    
    return Shared.Knit
end

function Shared.getService(serviceName)
    if Shared.KnitServices[serviceName] then
        return Shared.KnitServices[serviceName]
    end
    
    local Knit = Shared.getKnit()
    if Knit then
        pcall(function()
            Shared.KnitServices[serviceName] = Knit.GetService(serviceName)
        end)
    end
    
    return Shared.KnitServices[serviceName]
end

function Shared.getController(controllerName)
    if Shared.KnitControllers[controllerName] then
        return Shared.KnitControllers[controllerName]
    end
    
    local Knit = Shared.getKnit()
    if Knit then
        pcall(function()
            Shared.KnitControllers[controllerName] = Knit.GetController(controllerName)
        end)
    end
    
    return Shared.KnitControllers[controllerName]
end

----------------------------------------------------------------
-- 🔧 TOOL CONTROLLER (from getgc)
----------------------------------------------------------------
Shared.ToolController = nil
Shared.ToolActivatedFunc = nil
Shared.UIController = nil

function Shared.hookControllers()
    pcall(function()
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" then
                if rawget(v, "Open") and rawget(v, "Modules") then
                    Shared.UIController = v
                end
                if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                    Shared.ToolController = v
                    Shared.ToolActivatedFunc = v.ToolActivated
                end
            end
        end
    end)
    
    if Shared.UIController then print("✅ UIController Hooked!") end
    if Shared.ToolController then print("✅ ToolController Hooked!") end
end

-- Auto hook on load
Shared.hookControllers()

----------------------------------------------------------------
-- ✅ INITIALIZATION COMPLETE
----------------------------------------------------------------
print("✅ Shared.lua loaded successfully!")
print("   📦 Available: _G.Shared")

return Shared
