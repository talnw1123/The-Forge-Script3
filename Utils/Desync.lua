--[[
    Desync Module - FFlag Version
    
    ใช้ setfflag เพื่อ manipulate network replication
    
    วิธีใช้:
    - F6 = Toggle desync ON/OFF
    - F7 = Force disable
    - F8 = Test if setfflag is available
    
    Based on working scripts from ScriptBlox
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local State = {
    isDesynced = false,
    clone = nil,
    savedPosition = nil,
    savedCFrame = nil,
}

local DEBUG = true

local function log(...)
    if DEBUG then
        print("[FFLAG-DESYNC]", ...)
    end
end

----------------------------------------------------------------
-- CHECK SETFFLAG AVAILABILITY
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
-- CLONE HELPER
----------------------------------------------------------------
local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function createClone()
    local char = player.Character
    if not char then return nil end
    
    local hrp = getHRP()
    if not hrp then return nil end
    
    local clone = Instance.new("Model")
    clone.Name = "DesyncClone"
    
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local newPart = part:Clone()
            newPart.Anchored = true
            newPart.CanCollide = false
            newPart.CanTouch = false
            newPart.CanQuery = false
            newPart.Transparency = newPart.Transparency + 0.3
            
            for _, child in ipairs(newPart:GetChildren()) do
                if child:IsA("Weld") or child:IsA("WeldConstraint") or 
                   child:IsA("Motor6D") or child:IsA("Attachment") or
                   child:IsA("Constraint") then
                    child:Destroy()
                end
            end
            
            newPart.Parent = clone
            
        elseif part:IsA("Accessory") then
            local accessoryClone = part:Clone()
            for _, accPart in ipairs(accessoryClone:GetDescendants()) do
                if accPart:IsA("BasePart") then
                    accPart.Anchored = true
                    accPart.CanCollide = false
                    accPart.Transparency = accPart.Transparency + 0.3
                end
                if accPart:IsA("Weld") or accPart:IsA("WeldConstraint") or 
                   accPart:IsA("Motor6D") then
                    accPart:Destroy()
                end
            end
            accessoryClone.Parent = clone
        end
    end
    
    clone.Parent = Workspace
    return clone
end

local function deleteClone()
    if State.clone and State.clone.Parent then
        State.clone:Destroy()
        State.clone = nil
    end
end

----------------------------------------------------------------
-- FFLAG DESYNC - MAIN METHOD
----------------------------------------------------------------
local function enableDesyncFFlags()
    if not hasSetFFlag() then
        log("❌ setfflag is NOT available in this executor!")
        return false
    end
    
    log("🔧 Setting FFlags for desync...")
    
    -- Method 1: Simple desync (from first script)
    pcall(function()
        setfflag("WorldStepMax", "-99999999999999")
        log("✅ WorldStepMax set")
    end)
    
    -- Method 2: Network replication manipulation
    pcall(function()
        setfflag("GameNetPVHeaderRotationalVelocityZeroCutoffExponent", "-5000")
        log("✅ GameNetPVHeaderRotationalVelocityZeroCutoffExponent set")
    end)
    
    pcall(function()
        setfflag("GameNetPVHeaderLinearVelocityZeroCutoffExponent", "-5000")
        log("✅ GameNetPVHeaderLinearVelocityZeroCutoffExponent set")
    end)
    
    -- Method 3: Next Gen Replicator
    pcall(function()
        setfflag("NextGenReplicatorEnabledWrite4", "true")
        log("✅ NextGenReplicatorEnabledWrite4 set")
    end)
    
    pcall(function()
        setfflag("LargeReplicatorWrite5", "true")
        setfflag("LargeReplicatorEnabled9", "true")
        setfflag("LargeReplicatorRead5", "true")
        log("✅ LargeReplicator flags set")
    end)
    
    -- Method 4: Physics sender manipulation
    pcall(function()
        setfflag("S2PhysicsSenderRate", "15000")
        setfflag("PhysicsSenderMaxBandwidthBps", "20000")
        log("✅ Physics sender flags set")
    end)
    
    -- Method 5: Timestep manipulation
    pcall(function()
        setfflag("MaxTimestepMultiplierContstraint", "2147483647")
        setfflag("MaxTimestepMultiplierBuoyancy", "2147483647")
        setfflag("MaxTimestepMultiplierAcceleration", "2147483647")
        log("✅ Timestep flags set")
    end)
    
    -- Method 6: Replication focus manipulation
    pcall(function()
        setfflag("ReplicationFocusNouExtentsSizeCutoffForPauseStuds", "2147483647")
        log("✅ ReplicationFocus flags set")
    end)
    
    -- Method 7: Interpolation manipulation
    pcall(function()
        setfflag("InterpolationFrameVelocityThresholdMillionth", "5")
        setfflag("InterpolationFrameRotVelocityThresholdMillionth", "5")
        setfflag("InterpolationFramePositionThresholdMillionth", "5")
        log("✅ Interpolation flags set")
    end)
    
    -- Method 8: Max missed world steps
    pcall(function()
        setfflag("MaxMissedWorldStepsRemembered", "-2147483648")
        log("✅ MaxMissedWorldStepsRemembered set")
    end)
    
    return true
end

local function disableDesyncFFlags()
    if not hasSetFFlag() then return end
    
    log("🔧 Restoring FFlags...")
    
    -- Restore WorldStepMax
    pcall(function()
        setfflag("WorldStepMax", "30")
        log("✅ WorldStepMax restored")
    end)
    
    -- Restore other flags
    pcall(function()
        setfflag("GameNetPVHeaderRotationalVelocityZeroCutoffExponent", "0")
        setfflag("GameNetPVHeaderLinearVelocityZeroCutoffExponent", "0")
        log("✅ GameNetPV flags restored")
    end)
    
    pcall(function()
        setfflag("NextGenReplicatorEnabledWrite4", "false")
        log("✅ NextGenReplicator restored")
    end)
end

----------------------------------------------------------------
-- MAIN TOGGLE
----------------------------------------------------------------
local function enableDesync()
    local hrp = getHRP()
    if not hrp then
        log("❌ No character!")
        return false
    end
    
    -- Save position
    State.savedPosition = hrp.Position
    State.savedCFrame = hrp.CFrame
    log("📍 Saved position:", State.savedPosition)
    
    -- Create clone (visual marker)
    State.clone = createClone()
    if State.clone then
        log("✅ Clone created (visual marker)")
    end
    
    -- Enable FFlag desync
    local success = enableDesyncFFlags()
    
    if success then
        State.isDesynced = true
        log("=== DESYNC ACTIVE ===")
        log("💡 FFlags have been set!")
        log("💡 Other players should see you frozen!")
        log("💡 Press F6 or F7 to disable")
        return true
    else
        log("❌ Failed to enable desync")
        deleteClone()
        return false
    end
end

local function disableDesync()
    -- Disable FFlags
    disableDesyncFFlags()
    
    -- Delete clone
    deleteClone()
    
    State.isDesynced = false
    log("=== DESYNC DISABLED ===")
    log("✅ FFlags restored, you are synced again")
end

local function toggleDesync()
    if State.isDesynced then
        disableDesync()
    else
        enableDesync()
    end
    return State.isDesynced
end

----------------------------------------------------------------
-- TEST CAPABILITIES
----------------------------------------------------------------
local function testCapabilities()
    log("=== TESTING CAPABILITIES ===")
    
    -- Test setfflag
    if hasSetFFlag() then
        log("✅ setfflag is available!")
        
        -- Try to read current value
        pcall(function()
            if typeof(getfflag) == "function" then
                local currentWorldStep = getfflag("WorldStepMax")
                log("📊 Current WorldStepMax:", currentWorldStep)
            end
        end)
    else
        log("❌ setfflag is NOT available!")
        log("⚠️ Your executor may not support FFlags")
    end
    
    -- Test other executor functions
    pcall(function()
        if typeof(sethiddenproperty) == "function" then
            log("✅ sethiddenproperty available")
        else
            log("❌ sethiddenproperty NOT available")
        end
    end)
    
    log("=== END TEST ===")
end

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F6 then
        toggleDesync()
    elseif input.KeyCode == Enum.KeyCode.F7 then
        log("=== FORCE DISABLE ===")
        disableDesync()
    elseif input.KeyCode == Enum.KeyCode.F8 then
        testCapabilities()
    end
end)

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------
log("FFlag Desync Module Loaded!")
log("F6 = Toggle desync, F7 = Force disable, F8 = Test capabilities")

-- Auto-test on load
task.defer(testCapabilities)

----------------------------------------------------------------
-- MODULE
----------------------------------------------------------------
return {
    Toggle = toggleDesync,
    Enable = enableDesync,
    Disable = disableDesync,
    IsDesynced = function() return State.isDesynced end,
    Test = testCapabilities,
    HasSetFFlag = hasSetFFlag,
}
