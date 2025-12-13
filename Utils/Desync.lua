--[[
================================================================================
    🔄 DESYNC MODULE - FFlags + Auto Death
    
    💡 วิธีการ:
    1. Set FFlags ทันที
    2. Teleport ตกใต้แผนที่เพื่อตาย
    3. หลัง respawn → Desync ใช้งานได้!
================================================================================
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local DesyncState = {
    fflagsApplied = false,
    isReady = false,
}

local DEBUG = true

local function log(...)
    if DEBUG then
        print("[DESYNC]", ...)
    end
end

----------------------------------------------------------------
-- CHECK SETFFLAG
----------------------------------------------------------------
local function hasSetFFlag()
    local available = false
    pcall(function()
        if typeof(setfflag) == "function" then
            available = true
        end
    end)
    return available
end

----------------------------------------------------------------
-- APPLY ALL FFLAGS
----------------------------------------------------------------
local function applyAllFFlags()
    if not hasSetFFlag() then
        log("❌ setfflag not available!")
        return false
    end
    
    if DesyncState.fflagsApplied then
        log("⚠️ FFlags already applied")
        return true
    end
    
    log("🔧 Applying ALL FFlags...")
    
    -- GameNet PV Headers
    pcall(function()
        setfflag("GameNetPVHeaderRotationalVelocityZeroCutoffExponent", "-5000")
        setfflag("GameNetPVHeaderLinearVelocityZeroCutoffExponent", "-5000")
    end)
    
    -- LargeReplicator
    pcall(function()
        setfflag("LargeReplicatorWrite5", "true")
        setfflag("LargeReplicatorEnabled9", "true")
        setfflag("LargeReplicatorRead5", "true")
        setfflag("LargeReplicatorSerializeRead3", "true")
        setfflag("LargeReplicatorSerializeWrite4", "true")
    end)
    
    -- NextGenReplicator
    pcall(function()
        setfflag("NextGenReplicatorEnabledWrite4", "true")
    end)
    
    -- Timestep
    pcall(function()
        setfflag("MaxTimestepMultiplierContstraint", "2147483647")
        setfflag("MaxTimestepMultiplierBuoyancy", "2147483647")
        setfflag("MaxTimestepMultiplierAcceleration", "2147483647")
        setfflag("SimExplicitlyCappedTimestepMultiplier", "2147483646")
    end)
    
    -- TimestepArbiter
    pcall(function()
        setfflag("TimestepArbiterVelocityCriteriaThresholdTwoDt", "2147483646")
        setfflag("TimestepArbiterHumanoidLinearVelThreshold", "1")
        setfflag("TimestepArbiterHumanoidTurningVelThreshold", "1")
        setfflag("TimestepArbiterOmegaThou", "1073741823")
    end)
    
    -- Physics/Network
    pcall(function()
        setfflag("S2PhysicsSenderRate", "15000")
        setfflag("PhysicsSenderMaxBandwidthBps", "20000")
        setfflag("MaxDataPacketPerSend", "2147483647")
        setfflag("ServerMaxBandwith", "52")
    end)
    
    -- CheckPV
    pcall(function()
        setfflag("CheckPVCachedVelThresholdPercent", "10")
        setfflag("CheckPVCachedRotVelThresholdPercent", "10")
        setfflag("CheckPVLinearVelocityIntegrateVsDeltaPositionThresholdPercent", "1")
        setfflag("CheckPVDifferencesForInterpolationMinVelThresholdStudsPerSecHundredth", "1")
        setfflag("CheckPVDifferencesForInterpolationMinRotVelThresholdRadsPerSecHundredth", "1")
    end)
    
    -- Interpolation
    pcall(function()
        setfflag("InterpolationFrameVelocityThresholdMillionth", "5")
        setfflag("InterpolationFrameRotVelocityThresholdMillionth", "5")
        setfflag("InterpolationFramePositionThresholdMillionth", "5")
    end)
    
    -- Streaming
    pcall(function()
        setfflag("StreamJobNOUVolumeLengthCap", "2147483647")
        setfflag("StreamJobNOUVolumeCap", "2147483647")
        setfflag("SimOwnedNOUCountThresholdMillionth", "2147483647")
        setfflag("ReplicationFocusNouExtentsSizeCutoffForPauseStuds", "2147483647")
    end)
    
    -- Misc
    pcall(function()
        setfflag("MaxMissedWorldStepsRemembered", "-2147483648")
        setfflag("DebugSendDistInSteps", "-2147483648")
        setfflag("GameNetDontSendRedundantNumTimes", "1")
        setfflag("GameNetDontSendRedundantDeltaPositionMillionth", "1")
        setfflag("MaxAcceptableUpdateDelay", "1")
        setfflag("AngularVelociryLimit", "360")
        setfflag("WorldStepMax", "30")
        setfflag("DisableDPIScale", "true")
    end)
    
    DesyncState.fflagsApplied = true
    log("✅ All 40+ FFlags applied!")
    return true
end

----------------------------------------------------------------
-- DISABLE FFLAGS
----------------------------------------------------------------
local function disableFFlags()
    if not hasSetFFlag() then return end
    
    log("🔧 Restoring FFlags...")
    
    pcall(function()
        setfflag("GameNetPVHeaderRotationalVelocityZeroCutoffExponent", "0")
        setfflag("GameNetPVHeaderLinearVelocityZeroCutoffExponent", "0")
        setfflag("LargeReplicatorWrite5", "false")
        setfflag("LargeReplicatorEnabled9", "false")
        setfflag("NextGenReplicatorEnabledWrite4", "false")
        setfflag("DisableDPIScale", "false")
    end)
    
    DesyncState.fflagsApplied = false
    DesyncState.isReady = false
    log("✅ FFlags restored")
end

----------------------------------------------------------------
-- FORCE DEATH - All IY Methods Combined
----------------------------------------------------------------
local function forceDeath()
    log("💀 Triggering death (All IY Methods)...")
    
    local character = LocalPlayer.Character
    if not character then
        log("❌ No character!")
        return false
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    -- Save position for after respawn
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local savedPos = hrp and hrp.CFrame or nil
    
    -- Method 1: replicatesignal (most reliable if available)
    local hasReplicateSignal = false
    pcall(function()
        if typeof(replicatesignal) == "function" then
            hasReplicateSignal = true
        end
    end)
    
    if hasReplicateSignal then
        log("💀 Method 1: replicatesignal(Kill)...")
        pcall(function()
            replicatesignal(LocalPlayer.Kill)
        end)
        task.wait(0.5)
    end
    
    -- Check if still alive after method 1
    local stillAlive = LocalPlayer.Character and 
                       LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and
                       LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
    
    -- Method 2: ChangeState to Dead
    if stillAlive and humanoid then
        log("💀 Method 2: ChangeState(Dead)...")
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Dead)
        end)
        task.wait(0.5)
    end
    
    -- Check again
    stillAlive = LocalPlayer.Character and 
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
    
    -- Method 3: BreakJoints
    if stillAlive then
        log("💀 Method 3: BreakJoints()...")
        pcall(function()
            LocalPlayer.Character:BreakJoints()
        end)
        task.wait(0.5)
    end
    
    -- Check again
    stillAlive = LocalPlayer.Character and 
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
    
    -- Method 4: Destroy Humanoid + Swap Character (IY respawn method)
    if stillAlive then
        log("💀 Method 4: Destroy Humanoid + Swap...")
        pcall(function()
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:Destroy() end
        end)
        
        pcall(function()
            local char = LocalPlayer.Character
            local newChar = Instance.new("Model")
            newChar.Parent = workspace
            LocalPlayer.Character = newChar
            task.wait()
            LocalPlayer.Character = char
            newChar:Destroy()
        end)
        task.wait(0.5)
    end
    
    -- Method 5: CharacterService:Reset() as final fallback
    stillAlive = LocalPlayer.Character and 
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and
                 LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health > 0
    
    if stillAlive then
        log("💀 Method 5: CharacterService:Reset()...")
        pcall(function()
            local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
            local CharacterService = Knit.GetService("CharacterService")
            CharacterService:Reset()
        end)
    end
    
    log("✅ Death methods executed!")
    
    -- Wait for respawn and restore position
    task.spawn(function()
        local newChar = LocalPlayer.CharacterAdded:Wait()
        if savedPos then
            local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
            if newHrp then
                task.wait(0.5)
                newHrp.CFrame = savedPos
                log("📍 Position restored!")
            end
        end
    end)
    
    return true
end

-- Alternative method using replicatesignal if available
local function forceDeathAdvanced()
    log("💀 Attempting advanced death...")
    
    -- Check if replicatesignal is available
    local hasReplicateSignal = false
    pcall(function()
        if typeof(replicatesignal) == "function" then
            hasReplicateSignal = true
        end
    end)
    
    if hasReplicateSignal then
        log("✅ Using replicatesignal method...")
        pcall(function()
            replicatesignal(LocalPlayer.ConnectDiedSignalBackend)
            task.wait(Players.RespawnTime - 0.1)
            replicatesignal(LocalPlayer.Kill)
        end)
        return true
    else
        -- Use standard IY method
        return forceDeath()
    end
end



----------------------------------------------------------------
-- CHARACTER ADDED - Track respawns
----------------------------------------------------------------
local respawnCount = 0

LocalPlayer.CharacterAdded:Connect(function(character)
    respawnCount = respawnCount + 1
    
    task.wait(0.5)
    
    if DesyncState.fflagsApplied and respawnCount > 1 then
        DesyncState.isReady = true
        log("")
        log("🎉 =============================================")
        log("🎉 DESYNC ACTIVATED AFTER RESPAWN!")
        log("🎉 =============================================")
        log("")
    end
end)

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- NumPad 5 = Apply FFlags only
    if input.KeyCode == Enum.KeyCode.KeypadFive then
        applyAllFFlags()
        log("")
        log("⚠️ FFlags applied! Now press NumPad 6 to respawn")
        log("")
        
    -- NumPad 6 = Apply FFlags + Force Death
    elseif input.KeyCode == Enum.KeyCode.KeypadSix then
        applyAllFFlags()
        task.wait(0.2)
        forceDeath()
        
    -- NumPad 7 = Disable FFlags
    elseif input.KeyCode == Enum.KeyCode.KeypadSeven then
        disableFFlags()
        
    -- NumPad 0 = Status
    elseif input.KeyCode == Enum.KeyCode.KeypadZero then
        log("")
        log("========== STATUS ==========")
        log("setfflag:", hasSetFFlag() and "✅" or "❌")
        log("FFlags applied:", DesyncState.fflagsApplied and "✅" or "❌")
        log("Desync ready:", DesyncState.isReady and "✅" or "❌")
        log("============================")
        log("")
    end
end)

----------------------------------------------------------------
-- AUTO-APPLY ON LOAD
----------------------------------------------------------------
log("")
log("==========================================")
log("   🔄 DESYNC MODULE v2")
log("==========================================")
log("")
log("NumPad 5 = Apply FFlags")
log("NumPad 6 = Apply FFlags + Force Death/Respawn")
log("NumPad 7 = Disable FFlags")
log("NumPad 0 = Check Status")
log("")

if hasSetFFlag() then
    log("✅ setfflag available!")
    log("🚀 Auto-applying FFlags...")
    applyAllFFlags()
    
    if LocalPlayer.Character then
        log("")
        log("⚠️ Character exists - Press NumPad 6 to respawn!")
        log("")
    end
else
    log("❌ setfflag not available!")
end

log("==========================================")

----------------------------------------------------------------
-- MODULE
----------------------------------------------------------------
return {
    Apply = applyAllFFlags,
    Disable = disableFFlags,
    ForceDeath = forceDeath,
    IsApplied = function() return DesyncState.fflagsApplied end,
    IsReady = function() return DesyncState.isReady end,
}
