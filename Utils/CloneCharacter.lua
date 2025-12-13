--[[
    Clone Character - Simple standalone function
    
    วิธีใช้:
    - กด F8 เพื่อ clone ตัวละคร ณ ตำแหน่งปัจจุบัน
    - กด F9 เพื่อลบ clone ทั้งหมด
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local clones = {} -- เก็บ clones ทั้งหมด

----------------------------------------------------------------
-- CLONE CHARACTER FUNCTION
----------------------------------------------------------------
local function cloneCharacter()
    local char = player.Character
    if not char then 
        print("[CLONE] ❌ No character found!")
        return nil 
    end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        print("[CLONE] ❌ No HumanoidRootPart!")
        return nil
    end
    
    -- สร้าง clone model
    local clone = Instance.new("Model")
    clone.Name = "CharacterClone_" .. #clones + 1
    
    -- Clone ทุก part ที่มองเห็นได้ (ยกเว้น HumanoidRootPart)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local newPart = part:Clone()
            newPart.Anchored = true
            newPart.CanCollide = false
            newPart.CanTouch = false
            newPart.CanQuery = false
            newPart.Massless = true
            
            -- ลบ Welds และ constraints ที่อาจจะเชื่อมต่อกับตัวจริง
            for _, child in ipairs(newPart:GetChildren()) do
                if child:IsA("Weld") or child:IsA("WeldConstraint") or 
                   child:IsA("Motor6D") or child:IsA("Attachment") or
                   child:IsA("Constraint") then
                    child:Destroy()
                end
            end
            
            newPart.Parent = clone
        elseif part:IsA("Decal") or part:IsA("Texture") then
            -- Clone decals (face, etc.)
            local parent = part.Parent
            if parent and parent:IsA("BasePart") and parent.Name ~= "HumanoidRootPart" then
                local clonePart = clone:FindFirstChild(parent.Name)
                if clonePart then
                    local newDecal = part:Clone()
                    newDecal.Parent = clonePart
                end
            end
        elseif part:IsA("Accessory") then
            -- Clone accessories
            local accessoryClone = part:Clone()
            for _, accPart in ipairs(accessoryClone:GetDescendants()) do
                if accPart:IsA("BasePart") then
                    accPart.Anchored = true
                    accPart.CanCollide = false
                    accPart.CanTouch = false
                    accPart.CanQuery = false
                    accPart.Massless = true
                end
                -- ลบ welds/constraints
                if accPart:IsA("Weld") or accPart:IsA("WeldConstraint") or 
                   accPart:IsA("Motor6D") or accPart:IsA("Attachment") or
                   accPart:IsA("Constraint") then
                    accPart:Destroy()
                end
            end
            accessoryClone.Parent = clone
        end
    end
    
    clone.Parent = Workspace
    table.insert(clones, clone)
    
    print("[CLONE] ✅ Clone created at:", hrp.Position)
    print("[CLONE] Total clones:", #clones)
    
    return clone
end

----------------------------------------------------------------
-- DELETE ALL CLONES
----------------------------------------------------------------
local function deleteAllClones()
    local count = #clones
    
    for _, clone in ipairs(clones) do
        if clone and clone.Parent then
            clone:Destroy()
        end
    end
    
    clones = {}
    print("[CLONE] 🗑️ Deleted", count, "clone(s)")
end

----------------------------------------------------------------
-- DELETE LAST CLONE
----------------------------------------------------------------
local function deleteLastClone()
    if #clones == 0 then
        print("[CLONE] ❌ No clones to delete!")
        return
    end
    
    local lastClone = table.remove(clones)
    if lastClone and lastClone.Parent then
        lastClone:Destroy()
    end
    
    print("[CLONE] 🗑️ Deleted last clone. Remaining:", #clones)
end

----------------------------------------------------------------
-- INPUT HANDLING
----------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F8 then
        cloneCharacter()
    elseif input.KeyCode == Enum.KeyCode.F9 then
        deleteAllClones()
    end
end)

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------
print("[CLONE] Character Clone Module Loaded!")
print("[CLONE] F8 = Create clone, F9 = Delete all clones")

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------
return {
    Clone = cloneCharacter,
    DeleteAll = deleteAllClones,
    DeleteLast = deleteLastClone,
    GetClones = function() return clones end,
    GetCloneCount = function() return #clones end,
}
