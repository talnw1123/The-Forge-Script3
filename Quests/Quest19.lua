local Shared = _G.Shared

-- QUEST 19: Mining + Auto Sell & Auto Buy
-- ✅ Priority 1: Auto Sell Init (One-time setup)
-- ✅ Priority 2: Background Tasks (Auto Sell + Auto Buy - Always running)
-- ✅ Priority 3: Mining (Basalt Rock / Basalt Core)

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
local Quest19Active = true
local IsMiningActive = false
local DEBUG_MODE = true

local QUEST_CONFIG = {
    QUEST_NAME = "Mining + Auto Sell & Buy",
    REQUIRED_LEVEL = 10,

    -- Priority 1: Auto Sell (Ores)
    AUTO_SELL_ENABLED = true,
    AUTO_SELL_INTERVAL = 10,
    AUTO_SELL_NPC_NAME = "Greedy Cey",

    -- Priority 2: Auto Buy Cobalt Pickaxe (Background)
    AUTO_BUY_ENABLED = true,
    AUTO_BUY_INTERVAL = 15,
    TARGET_PICKAXE = "Cobalt Pickaxe",
    MIN_GOLD_TO_BUY = 10000,
    SHOP_POSITION = Vector3.new(-165, 22, -111.7),

    -- Priority 2.5: Auto Buy Magma Pickaxe (Gold >= 150k)
    MAGMA_PICKAXE_CONFIG = {
        ENABLED = true,   -- � ENABLED + Monster Killing Mode
        TARGET_PICKAXE = "Magma Pickaxe",
        MIN_GOLD_TO_BUY = 150000,
        SELL_SHOP_POSITION = Vector3.new(-115.1, 22.3, -92.3),  -- ขาย Weapon/Armor
        BUY_SHOP_POSITION = Vector3.new(378, 88.6, 109.6),       -- ซื้อ Magma Pickaxe
    },

    -- Priority 2.4: Auto Buy Arcane Pickaxe (Gold >= 128k) - Before Magma
    ARCANE_PICKAXE_CONFIG = {
        ENABLED = true,
        TARGET_PICKAXE = "Arcane Pickaxe",
        MIN_GOLD_TO_BUY = 128000,
        BUY_POSITION = Vector3.new(235.24, -13.43, -335.97),
        TELEPORT_TO_BUY = "Stonewake's Cross",   -- Island1 (to buy Arcane)
        TELEPORT_BACK = "Forgotten Kingdom",      -- Island2 (return after purchase)
    },

    -- Priority 2.5: Arcane Mode (Monster Killing after Arcane Pickaxe - NO Ore/Forge)
    ARCANE_MODE_CONFIG = {
        ENABLED = true,
        MONSTER_PATTERNS = {"^Axe Skeleton%d+$", "^Bomber%d+$", "^Deathaxe Skeleton%d+$", "^Skeleton Rogue%d+$"},
        MONSTER_UNDERGROUND_OFFSET = 8,
        MONSTER_MAX_DISTANCE = 50,
    },

    -- Priority 2.7: Magma Mode (Monster Killing after Magma Pickaxe - NO Ore/Forge)
    MAGMA_MODE_CONFIG = {
        ENABLED = true,
        MONSTER_PATTERNS = {"^Axe Skeleton%d+$", "^Bomber%d+$", "^Deathaxe Skeleton%d+$", "^Skeleton Rogue%d+$"},
        MONSTER_UNDERGROUND_OFFSET = 8,
        MONSTER_MAX_DISTANCE = 50,
    },

    -- Priority 2.8: Stash Capacity Check
    STASH_CHECK_CONFIG = {
        ENABLED = true,
        CHECK_INTERVAL = 20, -- Seconds
        FULL_COOLDOWN = 60,  -- Minutes cooldown after clearing (will be treated as seconds in code, user said 1 min = 60s)
        SHOP_POSITION = Vector3.new(-165, 22, -111.7),
        NPC_NAME = "Greedy Cey",
    },

    -- Priority 3: Mining (Default: Basalt Rock)
    ROCK_NAME = "Basalt Rock",
    UNDERGROUND_OFFSET = 4,
    LAYING_ANGLE = 90,
    MOVE_SPEED = 50,  
    STOP_DISTANCE = 2,

    MINING_PATHS = {
        "Island2CaveStart",
        "Island2CaveDanger1",
        "Island2CaveDanger2",
        "Island2CaveDanger3",
        "Island2CaveDanger4",
        "Island2CaveDangerClosed",
        "Island2CaveDeep",
        "Island2CaveLavaClosed",
        "Island2CaveMid",
    },

    -- Tier 2: Basalt Core (If have Cobalt Pickaxe)
    BASALT_CORE_CONFIG = {
        ROCK_NAME = "Basalt Core",
        MINING_PATHS = {
            "Island2CaveStart",
            "Island2CaveDanger1",
            "Island2CaveDanger2",
            "Island2CaveDanger3",
            "Island2CaveDanger4",
            "Island2CaveDangerClosed",
            "Island2CaveDeep",
            "Island2CaveLavaClosed",
            "Island2CaveMid",
        },
    },

    -- Tier 3: Basalt Vein (If have Magma Pickaxe)
    BASALT_VEIN_CONFIG = {
        ROCK_NAME = "Basalt Core",
        MINING_PATHS = {
            "Island2CaveStart",
            "Island2CaveDanger1",
            "Island2CaveDanger2",
            "Island2CaveDanger3",
            "Island2CaveDanger4",
            "Island2CaveDangerClosed",
            "Island2CaveDeep",
            "Island2CaveLavaClosed",
            "Island2CaveMid",
        },
    },

    -- Priority 2.6: Cobalt Mode (Ore Collection + Forge + Monster Kill)
    COBALT_MODE_CONFIG = {
        ENABLED = true,

        -- Required ores to collect before forging
        REQUIRED_ORES = {
            Diamond = 10,
            Quartz = 10,
            Amethyst = 10,
        },

        -- These ores will NOT be sold by Auto Sell
        PROTECTED_ORES = {"Diamond", "Quartz", "Amethyst"},

        -- Forge settings
        FORGE_POSITION = Vector3.new(13.5, 25.0, -70.8),
        FORGE_TYPE = "Weapon",
        SELL_SHOP_POSITION = Vector3.new(-115.1, 22.3, -92.3), -- Sell items before forge

        -- Rare weapon detection (ImageColor3)
        RARE_WEAPON_COLOR = Color3.fromRGB(123, 189, 246),
        COLOR_TOLERANCE = 5, -- RGB tolerance for color matching

        -- Monster killing after rare weapon equipped
        MONSTER_PATTERNS = {
            "^Axe Skeleton%d+$",
            "^Bomber%d+$",
            "^Deathaxe Skeleton%d+$",
            "^Skeleton Rogue%d+$",
        },
        MONSTER_UNDERGROUND_OFFSET = 8,
        MONSTER_MAX_DISTANCE = 50,
    },

    WAYPOINTS = {
        Vector3.new(-154.5, 39.1, 138.8),
        Vector3.new(11, 46.5, 124.2),
        Vector3.new(65, 74.2, -44),
    },

    WAYPOINT_STOP_DISTANCE = 5,
    MAX_ROCKS_TO_MINE = 99999999999999,
    HOLD_POSITION_AFTER_MINE = true,
}

----------------------------------------------------------------
-- KNIT SETUP
----------------------------------------------------------------
local KnitPackage = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit")
local Knit = require(KnitPackage)

if not Knit.OnStart then 
    pcall(function() Knit.Start():await() end)
end

local CharacterService = nil
local PlayerController = nil

pcall(function()
    CharacterService = Knit.GetService("CharacterService")
    PlayerController = Knit.GetController("PlayerController")
end)

-- Services for selling (Quest04 pattern)
local ProximityService = nil
local DialogueService = nil
pcall(function()
    ProximityService = Knit.GetService("ProximityService")
    DialogueService = Knit.GetService("DialogueService")
end)

local ToolController = nil
local ToolActivatedFunc = nil

pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Name") == "ToolController" and rawget(v, "ToolActivated") then
                ToolController = v
                ToolActivatedFunc = v.ToolActivated
                break
            end
        end
    end
end)

local SERVICES = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")

local PORTAL_RF = nil
pcall(function()
    PORTAL_RF = SERVICES:WaitForChild("PortalService", 5):WaitForChild("RF", 3):WaitForChild("TeleportToIsland", 3)
end)

local CHAR_RF = nil
pcall(function()
    CHAR_RF = SERVICES:WaitForChild("CharacterService", 5):WaitForChild("RF", 3):WaitForChild("EquipItem", 3)
end)

local TOOL_RF_BACKUP = nil
pcall(function()
    TOOL_RF_BACKUP = SERVICES:WaitForChild("ToolService", 5):WaitForChild("RF", 3):WaitForChild("ToolActivated", 3)
end)

local DIALOGUE_RF = nil
local DialogueRE = nil
pcall(function()
    local dialogueService = SERVICES:WaitForChild("DialogueService", 5)
    DIALOGUE_RF = dialogueService:WaitForChild("RF", 3):WaitForChild("RunCommand", 3)
    DialogueRE = dialogueService:WaitForChild("RE", 3):WaitForChild("DialogueEvent", 3)
end)

local ProximityDialogueRF = nil
local PURCHASE_RF = nil
pcall(function()
    local proximityService = SERVICES:WaitForChild("ProximityService", 5)
    ProximityDialogueRF = proximityService:WaitForChild("RF", 3):WaitForChild("Dialogue", 3)
    PURCHASE_RF = proximityService:WaitForChild("RF", 3):WaitForChild("Purchase", 3)
end)

-- Forge Service (for Cobalt Mode)
local ForgeService = nil
local ForgeController = nil
pcall(function()
    ForgeService = Knit.GetService("ForgeService")
    ForgeController = Knit.GetController("ForgeController")
end)

local FORGE_OBJECT = nil
local PROXIMITY_RF = nil
pcall(function()
    FORGE_OBJECT = Workspace:WaitForChild("Proximity"):WaitForChild("Forge", 5)
    PROXIMITY_RF = SERVICES:WaitForChild("ProximityService", 5):WaitForChild("RF", 3):WaitForChild("Forge", 3)
end)

-- Living folder for Monster Killing
local LIVING_FOLDER = nil
pcall(function()
    LIVING_FOLDER = Workspace:WaitForChild("Living", 5)
end)

local FORGES_FOLDER = Workspace:WaitForChild("Forges")
local MINING_FOLDER_PATH = Workspace:WaitForChild("Rocks")

if PORTAL_RF then print("✅ Portal Remote Ready!") else warn("⚠️ Portal Remote not found") end
if PlayerController then print("✅ PlayerController Ready!") else warn("⚠️ PlayerController not found") end
if ToolController then print("✅ ToolController Ready!") else warn("⚠️ ToolController not found") end
if DIALOGUE_RF then print("✅ Dialogue Remote Ready!") else warn("⚠️ Dialogue Remote not found") end
if PURCHASE_RF then print("✅ Purchase Remote Ready!") else warn("⚠️ Purchase Remote not found") end
if ForgeService then print("✅ ForgeService Ready!") else warn("⚠️ ForgeService not found") end
if FORGE_OBJECT then print("✅ Forge Object Ready!") else warn("⚠️ Forge Object not found") end
if LIVING_FOLDER then print("✅ Living Folder Ready!") else warn("⚠️ Living Folder not found") end

----------------------------------------------------------------
-- STATE MANAGEMENT
----------------------------------------------------------------
local State = {
    currentTarget = nil,
    targetDestroyed = false,
    hpWatchConn = nil,
    noclipConn = nil,
    moveConn = nil,
    positionLockConn = nil,
    bodyVelocity = nil,
    bodyGyro = nil,

    autoSellTask = nil,
    autoBuyTask = nil,
    isPaused = false,

    -- Cobalt Mode State
    cobaltModeActive = false,
    forgeComplete = false,
    rareWeaponFound = false,
    rareWeaponGUID = nil,
}

-- Activity flags
local IsKillingActive = false

-- 🛡️ BLACKLIST for rocks that someone else is mining
-- Format: { [rockModel] = expireTime }
local OccupiedRocks = {}
local OCCUPIED_TIMEOUT = 10  -- Remove from blacklist after 10 seconds

local function isRockOccupied(rock)
    if not rock then return false end
    local expireTime = OccupiedRocks[rock]
    if not expireTime then return false end

    if tick() > expireTime then
        OccupiedRocks[rock] = nil
        return false
    end
    return true
end

local function markRockAsOccupied(rock)
    if not rock then return end
    OccupiedRocks[rock] = tick() + OCCUPIED_TIMEOUT
    print(string.format("   🚫 Added to blacklist for %d seconds: %s", OCCUPIED_TIMEOUT, rock.Name))
end

local function cleanupExpiredBlacklist()
    local now = tick()
    for rock, expireTime in pairs(OccupiedRocks) do
        if now > expireTime or not rock.Parent then
            OccupiedRocks[rock] = nil
        end
    end
end

-- Use _G to persist across script reloads (Loader runs Quest 19 in loop)
_G.Quest19AutoSellInitialized = _G.Quest19AutoSellInitialized or false
local AutoSellInitialized = _G.Quest19AutoSellInitialized

local function cleanupState()
    if State.hpWatchConn then State.hpWatchConn:Disconnect() State.hpWatchConn = nil end
    if State.noclipConn then State.noclipConn:Disconnect() State.noclipConn = nil end
    if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
    if State.positionLockConn then State.positionLockConn:Disconnect() State.positionLockConn = nil end
    if State.bodyVelocity then State.bodyVelocity:Destroy() State.bodyVelocity = nil end
    if State.bodyGyro then State.bodyGyro:Destroy() State.bodyGyro = nil end

    State.currentTarget = nil
    State.targetDestroyed = false

    if ToolController then
        ToolController.holdingM1 = false
    end
end

----------------------------------------------------------------
-- GOLD SYSTEM
----------------------------------------------------------------
local function getGold()
    local goldLabel = playerGui:FindFirstChild("Main")
                     and playerGui.Main:FindFirstChild("Screen")
                     and playerGui.Main.Screen:FindFirstChild("Hud")
                     and playerGui.Main.Screen.Hud:FindFirstChild("Gold")

    if not goldLabel or not goldLabel:IsA("TextLabel") then
        return 0
    end

    local goldText = goldLabel.Text
    local goldString = string.gsub(goldText, "[$,]", "")
    local gold = tonumber(goldString)

    return gold or 0
end

----------------------------------------------------------------
-- COBALT MODE: ORE INVENTORY SYSTEM
----------------------------------------------------------------
local function getPlayerInventory()
    if not PlayerController or not PlayerController.Replica then
        return {}
    end

    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory then
        return {}
    end

    local inventory = {}
    for itemName, amount in pairs(replica.Data.Inventory) do
        if type(amount) == "number" and amount > 0 then
            inventory[itemName] = amount
        end
    end

    return inventory
end

local function getRequiredOreCount()
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    if not config or not config.ENABLED then
        return {}, false
    end

    local inventory = getPlayerInventory()
    local requiredOres = config.REQUIRED_ORES
    local oreStatus = {}
    local allComplete = true

    for oreName, requiredCount in pairs(requiredOres) do
        local currentCount = inventory[oreName] or 0
        oreStatus[oreName] = {
            current = currentCount,
            required = requiredCount,
            complete = currentCount >= requiredCount
        }
        if currentCount < requiredCount then
            allComplete = false
        end
    end

    return oreStatus, allComplete
end

local function printOreStatus()
    local oreStatus, allComplete = getRequiredOreCount()

    print("💎 Cobalt Mode Ore Status:")
    for oreName, status in pairs(oreStatus) do
        local icon = status.complete and "✅" or "⏳"
        print(string.format("   %s %s: %d/%d", icon, oreName, status.current, status.required))
    end

    if allComplete then
        print("   🎉 All ores collected!")
    end

    return allComplete
end

----------------------------------------------------------------
-- INVENTORY CHECK (MUST be before isOreProtected)
----------------------------------------------------------------
local function hasPickaxe(pickaxeName)
    -- Check UI: PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then
        if DEBUG_MODE then
            warn("[Q19] Menu not found → treat as NO pickaxe")
        end
        return false
    end

    local ok, toolsFrame = pcall(function()
        local f1    = menu:FindFirstChild("Frame")
        local f2    = f1 and f1:FindFirstChild("Frame")
        local menus = f2 and f2:FindFirstChild("Menus")
        local tools = menus and menus:FindFirstChild("Tools")
        local frame = tools and tools:FindFirstChild("Frame")
        return frame
    end)

    if not ok or not toolsFrame then
        if DEBUG_MODE then
            warn("[Q19] Tools.Frame not found → treat as NO pickaxe")
        end
        return false
    end

    -- Children in Frame are like "Iron Pickaxe", "Stone Pickaxe", "Cobalt Pickaxe"
    local gui = toolsFrame:FindFirstChild(pickaxeName)
    if gui then
        if DEBUG_MODE then
            local visible = gui:IsA("GuiObject") and gui.Visible or "N/A"
            print(string.format("[Q19] ✅ UI pickaxe '%s' found (Visible=%s)", pickaxeName, tostring(visible)))
        end
        return true
    end

    if DEBUG_MODE then
        print(string.format("[Q19] ⚠️ UI pickaxe '%s' NOT found", pickaxeName))
    end
    return false
end

----------------------------------------------------------------
-- PICKAXE PRIORITY & EQUIP SYSTEM (Magma > Cobalt)
----------------------------------------------------------------
local function isPickaxeEquipped(pickaxeName)
    -- Check UI: PlayerGui.Menu.Frame.Frame.Menus.Tools.Frame.[PickaxeName].Equip.TextLabel
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return false, false end

    local ok, pickaxeGui = pcall(function()
        return menu.Frame.Frame.Menus.Tools.Frame:FindFirstChild(pickaxeName)
    end)

    if not ok or not pickaxeGui then
        return false, false -- ไม่มี Pickaxe นี้
    end

    -- เช็ค Equip button -> TextLabel ข้างใน
    local equipBtn = pickaxeGui:FindFirstChild("Equip")
    if equipBtn then
        -- Text อยู่ใน TextLabel ข้างใน Equip button
        local textLabel = equipBtn:FindFirstChild("TextLabel")
        local buttonText = ""
        
        if textLabel and textLabel:IsA("TextLabel") then
            buttonText = textLabel.Text
        elseif equipBtn:IsA("TextButton") then
            buttonText = equipBtn.Text
        end
        
        -- "Unequip" = กำลังใช้งาน, "Equip" = ยังไม่ใช้
        local isEquipped = (buttonText == "Unequip")
        if DEBUG_MODE then
            print(string.format("[Q19] Pickaxe '%s' - hasIt: true, isEquipped: %s (Button: %s)", 
                pickaxeName, tostring(isEquipped), buttonText))
        end
        return true, isEquipped -- hasPickaxe, isEquipped
    end

    return true, false -- มี แต่ไม่รู้ status
end

local function equipPickaxeByName(pickaxeName)
    -- Check if already equipped first!
    local hasIt, isEquipped = isPickaxeEquipped(pickaxeName)
    
    if not hasIt then
        warn(string.format("[Q19] Cannot equip %s - not found!", pickaxeName))
        return false
    end
    
    -- ถ้า equipped อยู่แล้ว (UI แสดง "Unequip") → ไม่ต้องเรียก remote
    if isEquipped then
        print(string.format("   ⚡ %s already equipped (skipping remote)", pickaxeName))
        return true
    end
    
    -- ยังไม่ equipped → เรียก remote
    if not CHAR_RF then
        warn("[Q19] CHAR_RF not available for equip!")
        return false
    end

    local args = {
        {
            Runes = {
                {IsEmpty = true},
                {IsEmpty = true}
            },
            Name = pickaxeName
        }
    }

    local success, result = pcall(function()
        return CHAR_RF:InvokeServer(unpack(args))
    end)

    if success then
        print(string.format("   ⚡ Equipped %s", pickaxeName))
        return true
    else
        warn(string.format("   ❌ Failed to equip %s: %s", pickaxeName, tostring(result)))
        return false
    end
end

local function getBestPickaxe()
    -- Priority: Magma > Arcane > Cobalt
    local pickaxePriority = {
        {name = "Magma Pickaxe", tier = 3},
        {name = "Arcane Pickaxe", tier = 2.5},
        {name = "Cobalt Pickaxe", tier = 2},
    }

    for _, pickaxe in ipairs(pickaxePriority) do
        local hasIt, isEquipped = isPickaxeEquipped(pickaxe.name)
        if hasIt then
            if DEBUG_MODE then
                print(string.format("[Q19] 🏆 Best Pickaxe: %s (Tier %d, Equipped: %s)", 
                    pickaxe.name, pickaxe.tier, tostring(isEquipped)))
            end
            return pickaxe.name, hasIt, isEquipped, pickaxe.tier
        end
    end

    return nil, false, false, 0
end

local function ensureBestPickaxeEquipped()
    local bestName, hasIt, isEquipped, tier = getBestPickaxe()
    
    if not hasIt then
        if DEBUG_MODE then
            print("[Q19] ⚠️ No priority pickaxe found (Magma/Cobalt)")
        end
        return nil, false
    end

    if not isEquipped then
        print(string.format("   🔄 Auto-equipping best pickaxe: %s", bestName))
        equipPickaxeByName(bestName)
        task.wait(0.5)
        
        -- Verify
        local _, nowEquipped = isPickaxeEquipped(bestName)
        return bestName, nowEquipped
    end

    return bestName, true
end

----------------------------------------------------------------
-- ORE PROTECTION CHECK (checks EQUIPPED pickaxe, not just owned)
----------------------------------------------------------------
local function isOreProtected(oreName)
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    if not config or not config.ENABLED then
        return false
    end

    -- Only protect ores when Cobalt Pickaxe is EQUIPPED (not Magma)
    local _, cobaltEquipped = isPickaxeEquipped(QUEST_CONFIG.TARGET_PICKAXE)
    if not cobaltEquipped then
        return false
    end

    for _, protectedOre in ipairs(config.PROTECTED_ORES) do
        if oreName == protectedOre then
            return true
        end
    end

    return false
end

----------------------------------------------------------------
-- HOTKEY HELPER (for weapon/pickaxe equipping)
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero
}

local function pressKey(keyCode)
    if not keyCode then return end
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function findWeaponSlotKey()
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
                return HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end
    
    return nil, nil
end

----------------------------------------------------------------
-- FORCE CLOSE DIALOG
----------------------------------------------------------------
local function ForceEndDialogueAndRestore()
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

    if DialogueRE then
        pcall(function()
            DialogueRE:FireServer("Closed")
        end)
    end
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
    -- restoreCollisions() -- Not defined in this scope, assuming handled by game or not needed
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

    if DEBUG_MODE then
        print(string.format("   🚀 Moving to (%.1f, %.1f, %.1f)...", targetPos.X, targetPos.Y, targetPos.Z))
    end

    local reachedTarget = false
    local phase = 1 -- 1 = Y-axis first, 2 = XZ-axis
    local Y_THRESHOLD = 3 -- Close enough for Y
    local XZ_THRESHOLD = QUEST_CONFIG.STOP_DISTANCE or 2

    State.moveConn = RunService.Heartbeat:Connect(function()
        if reachedTarget then return end

        -- Check if character or BodyVelocity is destroyed
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.moveConn then State.moveConn:Disconnect() State.moveConn = nil end
            if bv and bv.Parent then bv:Destroy() end
            if bg and bg.Parent then bg:Destroy() end
            State.bodyVelocity = nil
            State.bodyGyro = nil
            return
        end

        -- Check if BodyVelocity was destroyed by game/other script
        if not bv or not bv.Parent then
            warn("   ⚠️ BodyVelocity destroyed! Recreating...")
            bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = hrp
            State.bodyVelocity = bv
        end

        if not bg or not bg.Parent then
            bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 10000
            bg.D = 500
            bg.Parent = hrp
            State.bodyGyro = bg
        end

        local currentPos = hrp.Position

        if phase == 1 then
            -- Phase 1: Move Y first (vertical)
            local yDiff = math.abs(targetPos.Y - currentPos.Y)
            
            if yDiff < Y_THRESHOLD then
                -- Y is close enough, move to phase 2
                phase = 2
                if DEBUG_MODE then
                    print("   ✅ Y-axis reached, moving to XZ...")
                end
            else
                -- Move vertically only
                local yDirection = Vector3.new(0, targetPos.Y - currentPos.Y, 0)
                local speed = math.min(QUEST_CONFIG.MOVE_SPEED, yDiff * 10)
                bv.Velocity = yDirection.Unit * speed
                -- Keep looking forward towards target
                bg.CFrame = CFrame.lookAt(currentPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))
            end
        else
            -- Phase 2: Move XZ (horizontal) and fine-tune Y
            local direction = (targetPos - currentPos)
            local distance = direction.Magnitude

            if distance < XZ_THRESHOLD then
                if DEBUG_MODE then
                    print(string.format("   ✅ Reached! (%.1f)", distance))
                end

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

            local speed = math.min(QUEST_CONFIG.MOVE_SPEED, distance * 10)
            local velocity = direction.Unit * speed

            bv.Velocity = velocity
            bg.CFrame = CFrame.lookAt(currentPos, targetPos)
        end
    end)

    return true
end

----------------------------------------------------------------
-- AUTO SELL SYSTEM
----------------------------------------------------------------
local function getSellNPC()
    local prox = Workspace:FindFirstChild("Proximity")
    return prox and prox:FindFirstChild(QUEST_CONFIG.AUTO_SELL_NPC_NAME) or nil
end

local function getSellNPCPos()
    local npc = getSellNPC()
    if not npc then return nil end
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function getStashBackground()
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return nil end
    local f1 = menu:FindFirstChild("Frame")
    if not f1 then return nil end
    local f2 = f1:FindFirstChild("Frame")
    if not f2 then return nil end
    local menus = f2:FindFirstChild("Menus")
    if not menus then return nil end
    local stash = menus:FindFirstChild("Stash")
    if not stash then return nil end
    return stash:FindFirstChild("Background")
end

local function parseQty(text)
    if not text or text == "" then return 1 end
    local n = string.match(text, "x?(%d+)")
    return tonumber(n) or 1
end

local function getStashItemsUI()
    local bg = getStashBackground()
    if not bg then return {} end

    local basket = {}
    for _, child in ipairs(bg:GetChildren()) do
        if child:IsA("GuiObject") and not string.match(child.Name, "^UI") then
            local qty = 1
            local main = child:FindFirstChild("Main")
            if main then
                local q = main:FindFirstChild("Quantity")
                if q and q:IsA("TextLabel") and q.Visible then
                    qty = parseQty(q.Text)
                end
            end
            basket[child.Name] = qty
        end
    end
    return basket
end

local function initAutoSellWithNPC()
    if AutoSellInitialized then return true end

    print("\n" .. string.rep("=", 60))
    print("🔧 INITIALIZING AUTO SELL (ONE-TIME)")
    print(string.rep("=", 60))

    local npcPos = getSellNPCPos()
    if not npcPos then
        warn("   ❌ NPC not found: " .. QUEST_CONFIG.AUTO_SELL_NPC_NAME)
        return false
    end

    print(string.format("   ✅ Found %s at (%.1f, %.1f, %.1f)", 
        QUEST_CONFIG.AUTO_SELL_NPC_NAME, npcPos.X, npcPos.Y, npcPos.Z))

    print("   🚶 Moving to NPC...")

    local done = false
    smoothMoveTo(npcPos, function() done = true end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ❌ Failed to reach NPC (timeout)")
        return false
    end

    print("   ✅ Reached NPC!")
    task.wait(1)

    local npc = getSellNPC()
    if npc and ProximityDialogueRF then
        print("   💬 Opening dialog...")
        pcall(function()
            ProximityDialogueRF:InvokeServer(npc)
        end)
    end

    task.wait(2)

    print("   🚪 Closing dialog...")
    ForceEndDialogueAndRestore()

    task.wait(1)

    AutoSellInitialized = true
    _G.Quest19AutoSellInitialized = true  -- Persist across script reloads

    print("\n" .. string.rep("=", 60))
    print("✅ AUTO SELL INITIALIZED!")
    print(string.rep("=", 60))

    return true
end

local function sellAllFromUI()
    if not DIALOGUE_RF then return end
    if not AutoSellInitialized then return end

    local basket = getStashItemsUI()

    -- 🛡️ Cobalt Mode: Skip protected ores (Diamond, Quartz, Amethyst)
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    local hasCobaltPickaxe = hasPickaxe(QUEST_CONFIG.TARGET_PICKAXE)

    if hasCobaltPickaxe and config and config.ENABLED then
        for _, protectedOre in ipairs(config.PROTECTED_ORES) do
            if basket[protectedOre] and basket[protectedOre] > 0 then
                if DEBUG_MODE then
                    print(string.format("   🛡️ Protected ore skipped: %s (x%d)", protectedOre, basket[protectedOre]))
                end
                basket[protectedOre] = nil
            end
        end
    end

    local hasItem = false
    for _, v in pairs(basket) do
        if v > 0 then hasItem = true break end
    end

    if not hasItem then
        if DEBUG_MODE then print("AutoSell: no items (after filtering protected ores)") end
        return
    end

    local args = { "SellConfirm", { Basket = basket } }
    local ok, res = pcall(function()
        return DIALOGUE_RF:InvokeServer(unpack(args))
    end)

    if ok then
        print("💰 AutoSell: sold items!")
    else
        warn("AutoSell failed:", res)
    end
end

local function startAutoSellTask()
    if not QUEST_CONFIG.AUTO_SELL_ENABLED or not DIALOGUE_RF then
        return
    end

    print("🤖 Auto Sell Background Task Started!")

    State.autoSellTask = task.spawn(function()
        while Quest19Active do
            task.wait(QUEST_CONFIG.AUTO_SELL_INTERVAL)

            if not State.isPaused then
                pcall(sellAllFromUI)
            end
        end
    end)
end

----------------------------------------------------------------
-- AUTO BUY SYSTEM (Background)
----------------------------------------------------------------
local function purchasePickaxe(pickaxeName)
    if not PURCHASE_RF then
        warn("Purchase RF missing")
        return false
    end

    print(string.format("   🛒 Purchasing: %s", pickaxeName))

    local ok, res = pcall(function()
        return PURCHASE_RF:InvokeServer(pickaxeName, 1)
    end)

    if ok then
        print(string.format("   ✅ Purchased: %s!", pickaxeName))
        return true
    else
        warn(string.format("   ❌ Failed: %s", tostring(res)))
        return false
    end
end

local function unlockPosition()
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
        if DEBUG_MODE then
            print("   🔓 Position unlocked")
        end
    end

    -- Also cleanup body movers to prevent conflict with smoothMoveTo
    if State.moveConn then
        State.moveConn:Disconnect()
        State.moveConn = nil
    end
    if State.bodyVelocity and State.bodyVelocity.Parent then
        State.bodyVelocity:Destroy()
        State.bodyVelocity = nil
    end
    if State.bodyGyro and State.bodyGyro.Parent then
        State.bodyGyro:Destroy()
        State.bodyGyro = nil
    end
end

local function tryBuyPickaxe()
    local pickaxeName = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"

    -- 1) Check if already have Pickaxe
    if hasPickaxe(pickaxeName) then
        if DEBUG_MODE then
            print(string.format("[Q18] ✅ Already have %s - skip auto buy", pickaxeName))
        end
        return true
    end

    -- 2) Check Gold
    local gold = getGold()
    gold = gold or 0

    if gold < QUEST_CONFIG.MIN_GOLD_TO_BUY then
        if DEBUG_MODE then
            print(string.format(
                "[Q18] ⏸ Gold not enough for %s (have %d, need > %d)",
                pickaxeName,
                gold,
                QUEST_CONFIG.MIN_GOLD_TO_BUY
            ))
        end
        return false
    end

    -- 3) Pause mining and go to Shop
    print(string.format("\n🛒 [Q18] Auto Buy: Need %s! (Gold: %d)", pickaxeName, gold))

    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  Pausing mining...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 4) Move to Shop
    local shopPos = QUEST_CONFIG.SHOP_POSITION
    print(string.format("   🚶 Going to shop (%.1f, %.1f, %.1f)...",
        shopPos.X, shopPos.Y, shopPos.Z))

    local done = false
    smoothMoveTo(shopPos, function()
        done = true
    end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ Failed to reach shop!")
        if wasMining then
            State.isPaused = false
        end
        return false
    end

    print("   ✅ Arrived at shop!")
    task.wait(1)

    -- 5) Purchase
    local purchased = purchasePickaxe(pickaxeName)

    if purchased then
        print("   ✅ Purchase complete!")
        task.wait(2)
    else
        warn("   ❌ Purchase failed!")
    end

    -- 6) Resume Mining
    if wasMining then
        print("   ▶️  Resuming mining...")
        State.isPaused = false
    end

    return purchased
end

local function startAutoBuyTask()
    if not QUEST_CONFIG.AUTO_BUY_ENABLED or not PURCHASE_RF then
        return
    end

    print("🤖 Auto Buy Background Task Started!")

    State.autoBuyTask = task.spawn(function()
        while Quest19Active do
            task.wait(QUEST_CONFIG.AUTO_BUY_INTERVAL)

            if State.isPaused then
                continue
            end

            pcall(function()
                tryBuyPickaxe()
            end)
        end
    end)
end

----------------------------------------------------------------
-- MAGMA PICKAXE AUTO BUY SYSTEM (With Sell Weapons/Armor)
----------------------------------------------------------------
local UIController = nil
pcall(function()
    for _, v in pairs(getgc(true)) do
        if type(v) == "table" then
            if rawget(v, "Open") and rawget(v, "Close") and rawget(v, "Modules") then
                UIController = v
                break
            end
        end
    end
end)

local function openToolsMenu()
    if not UIController then return false end

    if UIController.Modules["Menu"] then
        pcall(function() UIController:Open("Menu") end)
        task.wait(0.5)

        local menuModule = UIController.Modules["Menu"]
        if menuModule.OpenTab then
            pcall(function() menuModule:OpenTab("Tools") end)
        elseif menuModule.SwitchTab then
            pcall(function() menuModule:SwitchTab("Tools") end)
        end

        task.wait(0.5)
        return true
    end

    return false
end

local function closeToolsMenu()
    if UIController and UIController.Close then
        pcall(function() UIController:Close("Menu") end)
        task.wait(0.3)
    end
end

-- Check if item is equipped (has "Unequip" button)
local function isItemEquippedFromUI(guid)
    local menuGui = playerGui:FindFirstChild("Menu")
    if not menuGui then return false end

    local toolsFrame = menuGui:FindFirstChild("Frame") and menuGui.Frame:FindFirstChild("Frame") 
                    and menuGui.Frame.Frame:FindFirstChild("Menus") 
                    and menuGui.Frame.Frame.Menus:FindFirstChild("Tools")
                    and menuGui.Frame.Frame.Menus.Tools:FindFirstChild("Frame")

    if not toolsFrame then return false end

    local itemFrame = toolsFrame:FindFirstChild(guid)
    if not itemFrame then return false end

    local equipButton = itemFrame:FindFirstChild("Equip")
    if not equipButton then return false end

    local textLabel = equipButton:FindFirstChild("TextLabel")
    if not textLabel or not textLabel:IsA("TextLabel") then return false end

    return textLabel.Text == "Unequip"
end

-- Get all non-equipped weapons and armor
local function getNonEquippedItems()
    if not PlayerController or not PlayerController.Replica then
        warn("   ⚠️ Replica not available!")
        return {}
    end

    local replica = PlayerController.Replica

    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ⚠️ Equipments not found in Replica!")
        return {}
    end

    print("   📂 Opening Tools menu to check equipped items...")
    openToolsMenu()
    task.wait(0.5)

    local equipments = replica.Data.Inventory.Equipments
    local items = {}

    for id, item in pairs(equipments) do
        if type(item) == "table" and item.Type and item.GUID then
            -- Skip Pickaxe (don't sell pickaxes)
            if string.find(item.Type, "Pickaxe") then
                continue
            end

            local guid = item.GUID
            local isEquipped = isItemEquippedFromUI(guid)

            if not isEquipped then
                table.insert(items, {
                    ID = id,
                    GUID = guid,
                    Type = item.Type,
                    Name = item.Name or item.Type,
                })
                print(string.format("      💰 Can sell: %s (GUID: %s)", item.Type, guid))
            else
                print(string.format("      ⚡ Equipped (skip): %s", item.Type))
            end
        end
    end

    closeToolsMenu()

    return items
end

local function getProximityNPC(name)
    local proximity = Workspace:FindFirstChild("Proximity")
    if not proximity then return nil end
    return proximity:FindFirstChild(name)
end

-- Sell all non-equipped weapons and armor (Quest04 pattern using Wu NPC)
local function sellAllNonEquippedItems()
    print("\n💰 Selling all non-equipped Weapons/Armor...")

    local items = getNonEquippedItems()

    if #items == 0 then
        print("   ⏭️  No items to sell!")
        return true
    end

    print(string.format("   📦 Found %d items to sell", #items))

    -- Build basket with all GUIDs
    local basket = {}
    for _, item in ipairs(items) do
        basket[item.GUID] = true
        print(string.format("      - %s", item.Type))
    end

    -- Sell using Quest04 pattern with Wu NPC
    local npc = getProximityNPC("Wu") or getProximityNPC("Marbles") or getProximityNPC("Greedy Cey")
    
    if not npc then
        warn("   ❌ Sell NPC not found!")
        return false
    end

    if not ProximityService or not DialogueService then
        warn("   ❌ ProximityService or DialogueService not available!")
        -- Fallback to old method
        if DIALOGUE_RF then
            pcall(function()
                DIALOGUE_RF:InvokeServer("SellConfirm", { Basket = basket })
            end)
            ForceEndDialogueAndRestore()
        end
        return true
    end

    -- 1. Open dialogue with NPC using ForceDialogue (Quest04 pattern)
    print("   🔌 Opening dialogue with Wu...")
    local success1 = pcall(function()
        ProximityService:ForceDialogue(npc, "SellConfirm")
    end)

    if not success1 then
        warn("   ❌ Failed to open dialogue")
        return false
    end

    task.wait(0.2)

    -- 2. Sell items using RunCommand (Quest04 pattern)
    print("   💸 Selling items...")
    local success2 = pcall(function()
        DialogueService:RunCommand("SellConfirm", { Basket = basket })
    end)

    if success2 then
        print("   ✅ Sold all items successfully!")
        task.wait(0.1)
        ForceEndDialogueAndRestore()
        return true
    else
        warn("   ⚠️ Sell may have partially failed")
        ForceEndDialogueAndRestore()
        return true -- Continue anyway
    end
end



-- Try to buy Magma Pickaxe (with sell items first)
local function tryBuyMagmaPickaxe()
    local config = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG
    if not config or not config.ENABLED then return false end

    local pickaxeName = config.TARGET_PICKAXE or "Magma Pickaxe"

    -- 1) Check if already have Magma Pickaxe
    if hasPickaxe(pickaxeName) then
        if DEBUG_MODE then
            print(string.format("[Q19] ✅ Already have %s - skip auto buy", pickaxeName))
        end
        return true
    end

    -- 2) Check Gold
    local gold = getGold()
    gold = gold or 0

    if gold < config.MIN_GOLD_TO_BUY then
        if DEBUG_MODE then
            print(string.format(
                "[Q19] ⏸ Gold not enough for %s (have %d, need > %d)",
                pickaxeName,
                gold,
                config.MIN_GOLD_TO_BUY
            ))
        end
        return false
    end

    -- 3) Pause mining
    print(string.format("\n🛒 [Q19] Auto Buy Magma: Need %s! (Gold: %d)", pickaxeName, gold))

    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  Pausing mining...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 4) Move to Sell Shop and sell all weapons/armor
    local sellShopPos = config.SELL_SHOP_POSITION
    print(string.format("   🚶 Going to sell shop (%.1f, %.1f, %.1f)...",
        sellShopPos.X, sellShopPos.Y, sellShopPos.Z))

    local done = false
    smoothMoveTo(sellShopPos, function()
        done = true
    end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ Failed to reach sell shop!")
        if wasMining then State.isPaused = false end
        return false
    end

    print("   ✅ Arrived at sell shop!")
    task.wait(1)

    -- Sell all non-equipped items
    sellAllNonEquippedItems()
    task.wait(1)

    -- 5) Move to Buy Shop
    local buyShopPos = config.BUY_SHOP_POSITION
    print(string.format("   🚶 Going to Magma shop (%.1f, %.1f, %.1f)...",
        buyShopPos.X, buyShopPos.Y, buyShopPos.Z))

    done = false
    smoothMoveTo(buyShopPos, function()
        done = true
    end)

    t0 = tick()
    while not done and tick() - t0 < 60 do
        task.wait(0.1)
    end

    if not done then
        warn("   ⚠️ Failed to reach Magma shop!")
        if wasMining then State.isPaused = false end
        return false
    end

    print("   ✅ Arrived at Magma shop!")
    task.wait(1)

    -- 6) Purchase Magma Pickaxe
    local purchased = purchasePickaxe(pickaxeName)

    if purchased then
        print("   ✅ Magma Pickaxe purchased!")
        print("   🔄 Switching to Basalt Vein mining...")
        task.wait(2)
    else
        warn("   ❌ Purchase failed!")
    end

    -- 7) Resume Mining
    if wasMining then
        print("   ▶️  Resuming mining...")
        State.isPaused = false
    end

    return purchased
end

-- Background task for Magma Pickaxe
local function startMagmaBuyTask()
    local config = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG
    if not config or not config.ENABLED or not PURCHASE_RF then
        return
    end

    print("🤖 Magma Pickaxe Auto Buy Task Started!")

    State.magmaBuyTask = task.spawn(function()
        while Quest19Active do
            task.wait(30) -- Check every 30 seconds

            if State.isPaused then
                continue
            end

            -- Only try if we have Cobalt Pickaxe already
            if hasPickaxe(QUEST_CONFIG.TARGET_PICKAXE) then
                pcall(function()
                    tryBuyMagmaPickaxe()
                end)
            end
        end
    end)
end

----------------------------------------------------------------
-- STASH CAPACITY CHECK SYSTEM
----------------------------------------------------------------
local function getStashCapacity()
    -- Path: PlayerGui.Menu.Frame.Frame.Menus.Stash.Capacity.Text
    local menu = playerGui:FindFirstChild("Menu")
    if not menu then return 0, 0 end

    local capacityLabel = menu:FindFirstChild("Frame") 
                      and menu.Frame:FindFirstChild("Frame") 
                      and menu.Frame.Frame:FindFirstChild("Menus") 
                      and menu.Frame.Frame.Menus:FindFirstChild("Stash") 
                      and menu.Frame.Frame.Menus.Stash:FindFirstChild("Capacity")

    if not capacityLabel or not capacityLabel:IsA("TextLabel") then
        return 0, 0
    end

    -- Format: "Stash Capacity: 145/218"
    local text = capacityLabel.Text
    local current, max = string.match(text, "(%d+)/(%d+)")

    return tonumber(current) or 0, tonumber(max) or 0
end

local function executeFullStashRoutine()
    print("\n🚨 STASH ACTION REQUIRED: Stash Full!")

    -- 1. Pause everything
    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️  Pausing mining (Stash Full)...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 2. Move to Shop
    local shopPos = QUEST_CONFIG.STASH_CHECK_CONFIG.SHOP_POSITION
    print(string.format("   🚶 Walking to Shop for stash clear (%.1f, %.1f, %.1f)...",
        shopPos.X, shopPos.Y, shopPos.Z))

    local done = false
    smoothMoveTo(shopPos, function() done = true end)

    local t0 = tick()
    while not done and tick() - t0 < 45 do
        task.wait(0.1)
    end

    if not done then
        warn("   ❌ Failed to reach shop (Stash Routine)")
        if wasMining then State.isPaused = false end
        return
    end

    print("   ✅ Arrived at Shop!")
    task.wait(1)

    -- 3. Talk to NPC
    local npcName = QUEST_CONFIG.STASH_CHECK_CONFIG.NPC_NAME
    local npc = Workspace:WaitForChild("Proximity"):FindFirstChild(npcName)

    if npc and ProximityDialogueRF then
        print(string.format("   💬 Talking to %s...", npcName))
        pcall(function()
            ProximityDialogueRF:InvokeServer(npc)
        end)
        task.wait(2)
        print("   🚪 Closing dialog...")
        ForceEndDialogueAndRestore()
    else
        warn("   ❌ NPC not found for stash clear!")
    end

    task.wait(1)

    -- 4. Resume
    if wasMining then
        print("   ▶️  Resuming mining after Stash Check...")
        State.isPaused = false
    end
end

local function startStashCheckTask()
    local config = QUEST_CONFIG.STASH_CHECK_CONFIG
    if not config or not config.ENABLED then return end

    print("🤖 Stash Capacity Check Task Started!")

    task.spawn(function()
        local lastFullActionTime = 0

        while Quest19Active do
            task.wait(config.CHECK_INTERVAL)

            if State.isPaused then continue end

            -- Check cooldown
            if tick() - lastFullActionTime < config.FULL_COOLDOWN then
                continue
            end

            local current, max = getStashCapacity()

            if max > 0 and current >= max then
                print(string.format("   ⚠️ Stash Full Detected: %d/%d", current, max))

                lastFullActionTime = tick()
                executeFullStashRoutine()
            end
        end
    end)
end

----------------------------------------------------------------
-- COBALT MODE: FORGE SYSTEM
----------------------------------------------------------------
getgenv().ForgeHookActive = getgenv().ForgeHookActive or false

local function setupForgeHook()
    if getgenv().ForgeHookActive then
        print("⚙️  Forge Hook already active")
        return
    end

    if not ForgeService then
        warn("❌ ForgeService not available!")
        return
    end

    print("🔧 Installing Forge Hook (Quest03 pattern)...")

    local originalChangeSequence = ForgeService.ChangeSequence

    ForgeService.ChangeSequence = function(self, sequenceName, args)
        print(string.format("   🔄 Forge Sequence: %s", sequenceName or "nil"))

        local success, result = pcall(originalChangeSequence, self, sequenceName, args)

        task.spawn(function()
            if sequenceName == "Melt" then
                print("      ⏩ Auto: Pouring in 8s...")
                task.wait(8)
                self:ChangeSequence("Pour", {ClientTime = 8.5, InContact = true})
                
            elseif sequenceName == "Pour" then
                print("      ⏩ Auto: Hammering in 5s...")
                task.wait(5)
                self:ChangeSequence("Hammer", {ClientTime = 5.2})
                
            elseif sequenceName == "Hammer" then
                print("      ⏩ Auto: Watering in 6s...")
                task.wait(6)
                self:ChangeSequence("Water", {ClientTime = 6.5})
                
            elseif sequenceName == "Water" then
                print("      ⏩ Auto: Showcasing in 3s...")
                task.wait(3)
                self:ChangeSequence("Showcase", {})
                
            elseif sequenceName == "Showcase" then
                print("      ✅ Forge completed!")
                State.forgeComplete = true
            end
        end)

        return success, result
    end

    getgenv().ForgeHookActive = true
    print("✅ Forge Hook installed!")
end


local function closeForgeUI()
    print("   🚪 Closing Forge UI...")
    
    if UIController and UIController.Close then
        pcall(function()
            if UIController.Modules and UIController.Modules["Forge"] then
                UIController:Close("Forge")
            end
        end)
    end
    
    if ForgeController then
        pcall(function()
            if ForgeController.Close then ForgeController:Close()
            elseif ForgeController.CloseForge then ForgeController:CloseForge() end
        end)
    end
    
    pcall(function()
        local forgeGui = playerGui:FindFirstChild("Forge") or playerGui:FindFirstChild("ForgeUI")
        if forgeGui then forgeGui.Enabled = false end
    end)
    
    task.wait(0.5)
end

local function moveToForge()
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    local forgePos = config.FORGE_POSITION

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local distance = (forgePos - hrp.Position).Magnitude

    print(string.format("🚶 Moving to Forge at (%.1f, %.1f, %.1f) (%.1f studs away)...", 
        forgePos.X, forgePos.Y, forgePos.Z, distance))

    local done = false
    smoothMoveTo(forgePos, function() done = true end)

    local t0 = tick()
    while not done and tick() - t0 < 60 do
        task.wait(0.1)
    end

    if not done then
        warn("   ❌ Failed to reach Forge!")
        return false
    end

    print("✅ Reached Forge!")
    task.wait(1)
    return true
end

local function startForge(oreSelection)
    print("🔨 Starting Forge with:")
    for oreName, count in pairs(oreSelection) do
        print(string.format("   - %s: %d", oreName, count))
    end

    if not FORGE_OBJECT then
        warn("❌ Forge Object not found!")
        return false
    end

    if not ForgeService then return false end

    -- 1. Invoke Proximity (Server interaction)
    print("   🔌 Invoking Forge Proximity...")
    local proxSuccess = pcall(function()
        PROXIMITY_RF:InvokeServer(FORGE_OBJECT)
    end)
    
    if not proxSuccess then
        warn("   ❌ Failed to invoke Forge remote (Proximity)")
        return false
    end
    
    -- 2. Wait for UI/Server
    task.wait(1.5)
    
    -- 3. Start Client Sequence
    print("   🔥 Starting Melt Sequence...")
    local success = pcall(function()
        ForgeService:ChangeSequence("Melt", {
            Object = FORGE_OBJECT,
            Ores = oreSelection,
            ItemType = "Weapon", -- Explicitly set to Weapon
            FastForge = false
        })
    end)

    if success then
        print("✅ Forge Melt started!")
        return true
    else
        warn("❌ Forge Melt failed!")
        return false
    end
end

----------------------------------------------------------------
-- COBALT MODE: RARE WEAPON DETECTION
----------------------------------------------------------------
local function openToolsMenu()
    if not UIController then return false end

    if UIController.Modules["Menu"] then
        pcall(function() UIController:Open("Menu") end)
        task.wait(0.5)

        local menuModule = UIController.Modules["Menu"]
        if menuModule.OpenTab then
            pcall(function() menuModule:OpenTab("Tools") end)
        elseif menuModule.SwitchTab then
            pcall(function() menuModule:SwitchTab("Tools") end)
        end

        task.wait(0.5)
        return true
    end

    return false
end

local function closeToolsMenu()
    if UIController and UIController.Close then
        pcall(function() UIController:Close("Menu") end)
        task.wait(0.3)
    end
end

local function findRareWeaponByColor()
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    local targetColor = config.RARE_WEAPON_COLOR
    local tolerance = config.COLOR_TOLERANCE or 5

    print("🔍 Searching for Rare Weapon (Color: 123, 189, 246)...")

    -- Open Tools menu to check items
    openToolsMenu()
    task.wait(0.5)

    local toolsFrame = playerGui:FindFirstChild("Menu")
        and playerGui.Menu:FindFirstChild("Frame")
        and playerGui.Menu.Frame:FindFirstChild("Frame")
        and playerGui.Menu.Frame.Frame:FindFirstChild("Menus")
        and playerGui.Menu.Frame.Frame.Menus:FindFirstChild("Tools")
        and playerGui.Menu.Frame.Frame.Menus.Tools:FindFirstChild("Frame")

    if not toolsFrame then
        warn("   ❌ Tools Frame not found!")
        closeToolsMenu()
        return nil
    end

    for _, child in ipairs(toolsFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            -- Skip Pickaxe
            if string.find(child.Name, "Pickaxe") then continue end

            local glowImage = child:FindFirstChild("GlowImage")
            if glowImage and glowImage:IsA("ImageLabel") then
                local color = glowImage.ImageColor3
                local r, g, b = color.R * 255, color.G * 255, color.B * 255

                -- Compare colors with tolerance
                if math.abs(r - 123) < tolerance 
                    and math.abs(g - 189) < tolerance 
                    and math.abs(b - 246) < tolerance then

                    -- ✅ Check OreName to exclude Mushroomite items
                    local oreName = child:FindFirstChild("OreName")
                    if oreName and oreName:IsA("TextLabel") then
                        local oreText = oreName.Text or ""
                        if string.find(oreText, "Mushroomite") then
                            print(string.format("   ⏭️ Skipping Mushroomite item: %s (Color matches but OreName = %s)", 
                                child.Name, oreText))
                            continue -- Not a rare weapon, skip to next item
                        end
                    end

                    print(string.format("   🌟 RARE WEAPON FOUND! GUID: %s (Color: %.0f, %.0f, %.0f)", 
                        child.Name, r, g, b))
                    closeToolsMenu()
                    return child.Name -- GUID
                end
            end
        end
    end

    print("   ⚠️ No rare weapon found")
    closeToolsMenu()
    return nil
end

local function equipWeaponByGUID(guid)
    print(string.format("⚡ Equipping weapon: %s", guid))

    -- ✅ Check if weapon is already equipped (prevents unequipping bug)
    openToolsMenu()
    task.wait(0.3)
    
    local alreadyEquipped = isItemEquippedFromUI(guid)
    closeToolsMenu()
    
    if alreadyEquipped then
        print("   ✅ Weapon is already equipped! (skipping remote call)")
        return true
    end

    if not PlayerController or not PlayerController.Replica then
        warn("   ❌ PlayerController not available!")
        return false
    end

    local replica = PlayerController.Replica
    if not replica.Data or not replica.Data.Inventory or not replica.Data.Inventory.Equipments then
        warn("   ❌ Equipments not found!")
        return false
    end

    local equipments = replica.Data.Inventory.Equipments

    for id, item in pairs(equipments) do
        if type(item) == "table" and item.GUID == guid then
            print(string.format("   📦 Found item: %s (%s)", item.Type or "Unknown", guid))

            local success = pcall(function()
                CHAR_RF:InvokeServer(item)
            end)

            if success then
                print("   ✅ Weapon equipped!")
                return true
            else
                warn("   ❌ Failed to equip weapon!")
                return false
            end
        end
    end

    warn("   ❌ Item not found in inventory!")
    return false
end

----------------------------------------------------------------
-- COBALT MODE: MONSTER KILLING SYSTEM
----------------------------------------------------------------
local function getMonsterUndergroundPosition(monsterModel)
    if not monsterModel or not monsterModel.Parent then return nil end

    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    local offset = config.MONSTER_UNDERGROUND_OFFSET or 3

    local hrp = monsterModel:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        return Vector3.new(pos.X, pos.Y - offset, pos.Z)
    end

    return nil
end

local function getMonsterHP(monster)
    if not monster or not monster.Parent then return 0 end
    local humanoid = monster:FindFirstChild("Humanoid")
    if humanoid then
        return humanoid.Health or 0
    end
    return 0
end

local function isMonsterValid(monster)
    if not monster or not monster.Parent then return false end
    return getMonsterHP(monster) > 0
end

local function findNearestMonster()
    if not LIVING_FOLDER then 
        warn("   ❌ LIVING_FOLDER is nil!")
        return nil 
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    -- Monster name prefixes to look for (without numbers)
    local monsterPrefixes = {
        "Axe Skeleton",
        "Bomber",
        "Deathaxe Skeleton",
        "Skeleton Rogue",
    }

    local targetMonster, minDist = nil, math.huge
    local totalChildren = 0
    local matchedCount = 0
    local validCount = 0

    for _, child in ipairs(LIVING_FOLDER:GetChildren()) do
        totalChildren = totalChildren + 1
        
        -- Check if child name starts with any of our target prefixes
        for _, prefix in ipairs(monsterPrefixes) do
            if string.find(child.Name, "^" .. prefix) then
                matchedCount = matchedCount + 1
                
                -- Check if monster is valid (has HP > 0)
                if isMonsterValid(child) then
                    local pos = getMonsterUndergroundPosition(child)
                    if pos then
                        local dist = (pos - hrp.Position).Magnitude
                        validCount = validCount + 1
                        if dist < minDist then
                            minDist = dist
                            targetMonster = child
                        end
                    end
                end
                break
            end
        end
    end

    -- Debug output
    if not targetMonster then
        print(string.format("   📊 Debug: %d children, %d matched, %d valid", 
            totalChildren, matchedCount, validCount))
    end

    return targetMonster, minDist
end

local function watchMonsterHP(monster)
    if State.hpWatchConn then State.hpWatchConn:Disconnect() end
    if not monster then return end

    local humanoid = monster:FindFirstChild("Humanoid")
    if not humanoid then return end

    State.hpWatchConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
        local hp = humanoid.Health or 0
        if hp <= 0 then
            print("   ✅ Monster killed!")
            State.targetDestroyed = true
            if ToolController then ToolController.holdingM1 = false end
        end
    end)
end

local function lockPositionFollowMonster(targetMonster)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetMonster then return end

    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end

    local angle = math.rad(QUEST_CONFIG.LAYING_ANGLE)

    State.positionLockConn = RunService.Heartbeat:Connect(function()
        if not char or not char.Parent or not hrp or not hrp.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end

        if not targetMonster or not targetMonster.Parent then
            if State.positionLockConn then
                State.positionLockConn:Disconnect()
                State.positionLockConn = nil
            end
            return
        end

        local targetPos = getMonsterUndergroundPosition(targetMonster)
        if targetPos then
            local baseCFrame = CFrame.new(targetPos)
            local layingCFrame = baseCFrame * CFrame.Angles(angle, 0, 0)

            hrp.CFrame = layingCFrame
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)

    print("   🔒 Following monster...")
end

local function doKillMonsters()
    print("\n" .. string.rep("=", 60))
    print("⚔️ COBALT MODE: MONSTER KILLING")
    print(string.rep("=", 60))

    IsKillingActive = true
    enableNoclip()

    while Quest19Active and not State.isPaused do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            warn("   ⚠️ Waiting for character...")
            task.wait(2)
            continue
        end

        -- Find nearest monster
        local targetMonster, dist = findNearestMonster()

        if not targetMonster then
            print("   ⏳ No monsters found, waiting...")
            unlockPosition()
            task.wait(3)
            continue
        end

        State.currentTarget = targetMonster
        State.targetDestroyed = false

        local targetPos = getMonsterUndergroundPosition(targetMonster)
        if not targetPos then
            warn("   ❌ Cannot get monster position!")
            task.wait(1)
            continue
        end

        local currentHP = getMonsterHP(targetMonster)
        print(string.format("   🎯 Target: %s (HP: %.0f, Dist: %.0f)", 
            targetMonster.Name, currentHP, dist))

        -- Move to monster and lock position
        watchMonsterHP(targetMonster)

        local moveComplete = false
        smoothMoveTo(targetPos, function()
            lockPositionFollowMonster(targetMonster)
            moveComplete = true
        end)

        local t0 = tick()
        while not moveComplete and tick() - t0 < 30 do
            task.wait(0.1)
        end

        if not moveComplete then
            warn("   ⚠️ Move timeout, skip monster")
            State.targetDestroyed = true
            continue
        end

        task.wait(0.3)

        -- Attack loop
        while not State.targetDestroyed and Quest19Active and not State.isPaused do
            if not char or not char.Parent then break end

            -- ✅ Check HP directly - switch immediately when HP = 0
            local monsterHP = 0
            if targetMonster and targetMonster.Parent then
                local humanoid = targetMonster:FindFirstChild("Humanoid")
                if humanoid then
                    monsterHP = humanoid.Health or 0
                end
            end

            -- If monster HP = 0 or monster is gone, switch to next target immediately
            if monsterHP <= 0 or not targetMonster or not targetMonster.Parent then
                print("   ✅ Monster killed (HP: 0)! Switching to next target...")
                State.targetDestroyed = true
                if ToolController then ToolController.holdingM1 = false end
                -- ❌ Don't unlock here - will move directly to next target
                break
            end

            -- Check if monster too far
            local currentMonsterPos = getMonsterUndergroundPosition(targetMonster)
            if currentMonsterPos and hrp then
                local distToMonster = (currentMonsterPos - hrp.Position).Magnitude
                if distToMonster > QUEST_CONFIG.COBALT_MODE_CONFIG.MONSTER_MAX_DISTANCE then
                    print("   ⚠️ Monster moved too far! Switching target...")
                    State.targetDestroyed = true
                    break
                end
            end

            -- Equip and attack with weapon
            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isWeaponHeld = toolInHand and not string.find(toolInHand.Name, "Pickaxe")

            if not isWeaponHeld then
                if ToolController then ToolController.holdingM1 = false end

                -- Find and equip weapon from hotbar
                local key, weaponName = findWeaponSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    -- Try to equip rare weapon
                    if State.rareWeaponGUID then
                        equipWeaponByGUID(State.rareWeaponGUID)
                        task.wait(0.5)
                    end
                end
            else
                -- Attack
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end

            task.wait(0.4)
        end

        -- ✅ Don't unlock between monsters - smoothMoveTo will handle transition
        -- Just disconnect the position lock connection, smoothMoveTo will create new one
        if State.positionLockConn then
            State.positionLockConn:Disconnect()
            State.positionLockConn = nil
        end
        
        print("   🔄 Finding next monster...")
        task.wait(0.1) -- Minimal wait - move to next target immediately
    end

    print("\n⚔️ Monster killing ended")
    IsKillingActive = false
    unlockPosition() -- Only unlock when completely done
    disableNoclip()
end

----------------------------------------------------------------
-- COBALT MODE: MAIN ROUTINE (Priority: Check Rare Weapon FIRST)
----------------------------------------------------------------
local function doCobaltModeRoutine()
    local config = QUEST_CONFIG.COBALT_MODE_CONFIG
    if not config or not config.ENABLED then return false end

    -- Check if we have Cobalt Pickaxe
    if not hasPickaxe(QUEST_CONFIG.TARGET_PICKAXE) then
        return false
    end

    print("\n" .. string.rep("=", 60))
    print("🎯 COBALT MODE: Checking for Rare Weapon...")
    print(string.rep("=", 60))

    -- ⭐ PRIORITY 1: Check if we already have Rare Weapon
    print("\n🔍 Step 1: Checking inventory for Rare Weapon...")
    local existingRareGUID = findRareWeaponByColor()

    if existingRareGUID then
        print("\n🌟 RARE WEAPON FOUND IN INVENTORY!")
        State.rareWeaponFound = true
        State.rareWeaponGUID = existingRareGUID

        -- Equip and go kill monsters immediately!
        print("\n⚡ Equipping Rare Weapon...")
        equipWeaponByGUID(existingRareGUID)
        task.wait(1)

        print("\n🎉 Rare weapon equipped! Switching to Monster Killing mode...")
        State.isPaused = false
        State.cobaltModeActive = false
        doKillMonsters()
        return true
    end

    print("   ⚠️ No Rare Weapon found, need to forge...")

    -- ⭐ PRIORITY 2: Check if we have enough ores to forge
    local oreStatus, haveOres = getRequiredOreCount()
    printOreStatus()

    if not haveOres then
        print("\n⛏️ Not enough ores! Need to mine more...")
        return false -- Go back to mining
    end

    -- We have ores! Start forge sequence
    print("\n" .. string.rep("=", 60))
    print("🔨 COBALT MODE: Starting Forge Sequence...")
    print(string.rep("=", 60))

    State.cobaltModeActive = true

    -- 1. Pause mining
    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️ Pausing mining for Cobalt Mode...")

        if ToolController then
            ToolController.holdingM1 = false
        end

        unlockPosition()
        task.wait(1)
    end

    -- 2. Sell all non-equipped items first
    print("\n📦 Step 2: Selling non-equipped items...")
    local sellShopPos = config.SELL_SHOP_POSITION

    local done = false
    smoothMoveTo(sellShopPos, function() done = true end)

    local t0 = tick()
    while not done and tick() - t0 < 30 do
        task.wait(0.1)
    end

    if done then
        print("   ✅ Arrived at sell shop!")
        task.wait(1)
        sellAllNonEquippedItems()
        task.wait(1)
    else
        warn("   ⚠️ Failed to reach sell shop, continuing...")
    end

    -- 3. Move to Forge
    print("\n⚒️ Step 3: Moving to Forge...")
    setupForgeHook()

    if not moveToForge() then
        warn("   ⚠️ Failed to reach Forge!")
        State.isPaused = false
        State.cobaltModeActive = false
        return false
    end

    -- 4. Forge with specific ores
    State.forgeComplete = false
    local oreSelection = {}
    for oreName, count in pairs(config.REQUIRED_ORES) do
        oreSelection[oreName] = count
    end

    local forgeSuccess = startForge(oreSelection)

    if forgeSuccess then
        print("   ⏳ Waiting for forge to complete (27 seconds)...")
        task.wait(27)
        
        -- Close Forge UI before checking inventory
        closeForgeUI()
    else
        warn("   ❌ Forge failed!")
        State.isPaused = false
        State.cobaltModeActive = false
        return false
    end

    task.wait(2)

    -- 5. Check for rare weapon after forging
    print("\n🔍 Step 4: Checking for Rare Weapon after forge...")
    local rareGUID = findRareWeaponByColor()

    if rareGUID then
        State.rareWeaponFound = true
        State.rareWeaponGUID = rareGUID

        -- 6. Equip rare weapon
        print("\n⚡ Step 5: Equipping Rare Weapon...")
        equipWeaponByGUID(rareGUID)
        task.wait(1)

        -- 7. Switch to Monster Killing mode
        print("\n🎉 Rare weapon equipped! Switching to Monster Killing mode...")
        
        -- Reset paused state so monster killing can work
        State.isPaused = false
        State.cobaltModeActive = false
        
        doKillMonsters()
        return true
    else
        print("   🔄 No rare weapon from this forge, need more ores...")
        State.isPaused = false
        State.cobaltModeActive = false
        return false -- Go back to mining for more ores
    end
end

----------------------------------------------------------------
-- MAGMA MODE: MONSTER KILLING (NO Ore Collection / NO Forge)
----------------------------------------------------------------
local function doMagmaModeRoutine()
    local config = QUEST_CONFIG.MAGMA_MODE_CONFIG
    if not config or not config.ENABLED then return false end

    -- Check if we have Magma Pickaxe
    local magmaName = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG.TARGET_PICKAXE
    local hasIt, isEquipped = isPickaxeEquipped(magmaName)

    if not hasIt then
        return false -- No Magma Pickaxe, continue with other modes
    end

    print("\n" .. string.rep("=", 60))
    print("🔥 MAGMA MODE: Starting Monster Killing...")
    print(string.rep("=", 60))

    -- Pause mining if active
    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️ Pausing mining for Magma Mode...")
        if ToolController then
            ToolController.holdingM1 = false
        end
        unlockPosition()
        task.wait(1)
    end

    -- Equip Magma Pickaxe if not equipped (optional, for pickaxe tool switch)
    if not isEquipped then
        print("   ⚡ Equipping Magma Pickaxe...")
        equipPickaxeByName(magmaName)
        task.wait(0.5)
    end

    -- Find and equip best weapon for combat
    local weaponKey, weaponName = findWeaponSlotKey()
    if weaponKey and weaponName then
        print(string.format("   ⚔️ Switching to weapon: %s", weaponName))
        pressKey(weaponKey)
        task.wait(0.5)
    else
        print("   ⚠️ No weapon found in hotbar, will use current tool")
    end

    -- Start monster killing loop
    print("   ✅ Starting Monster Killing (Magma Mode)...")
    State.isPaused = false
    doKillMonsters()
    
    return true
end

----------------------------------------------------------------
-- ARCANE MODE: MONSTER KILLING (NO Ore Collection / NO Forge)
----------------------------------------------------------------
local function doArcaneModeRoutine()
    local config = QUEST_CONFIG.ARCANE_MODE_CONFIG
    if not config or not config.ENABLED then return false end

    -- Check if we have Arcane Pickaxe
    local arcaneName = QUEST_CONFIG.ARCANE_PICKAXE_CONFIG.TARGET_PICKAXE
    local hasIt, isEquipped = isPickaxeEquipped(arcaneName)

    if not hasIt then
        return false -- No Arcane Pickaxe, continue with other modes
    end

    print("\n" .. string.rep("=", 60))
    print("💜 ARCANE MODE: Starting Monster Killing...")
    print(string.rep("=", 60))

    -- Pause mining if active
    local wasMining = IsMiningActive
    if wasMining then
        State.isPaused = true
        print("   ⏸️ Pausing mining for Arcane Mode...")
        if ToolController then
            ToolController.holdingM1 = false
        end
        unlockPosition()
        task.wait(1)
    end

    -- Equip Arcane Pickaxe if not equipped
    if not isEquipped then
        print("   ⚡ Equipping Arcane Pickaxe...")
        equipPickaxeByName(arcaneName)
        task.wait(0.5)
    end

    -- Find and equip best weapon for combat
    local weaponKey, weaponName = findWeaponSlotKey()
    if weaponKey and weaponName then
        print(string.format("   ⚔️ Switching to weapon: %s", weaponName))
        pressKey(weaponKey)
        task.wait(0.5)
    else
        print("   ⚠️ No weapon found in hotbar, will use current tool")
    end

    -- Start monster killing loop
    print("   ✅ Starting Monster Killing (Arcane Mode)...")
    State.isPaused = false
    doKillMonsters()
    
    return true
end

----------------------------------------------------------------
-- HELPER: Find Weapon Slot Key
----------------------------------------------------------------
local function findWeaponSlotKey()
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
                return HOTKEY_MAP[slotFrame.Name], label.Text
            end
        end
    end

    return nil, nil
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
        print(string.format("   ✅ On %s → Ready to mine!", currentIsland))
        return false
    else
        warn(string.format("   ⚠️ Unknown: %s", currentIsland))
        return true
    end
end

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
-- HELPER FUNCTIONS
----------------------------------------------------------------
local HOTKEY_MAP = {
    ["1"] = Enum.KeyCode.One,
    ["2"] = Enum.KeyCode.Two,
    ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four,
    ["5"] = Enum.KeyCode.Five,
    ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven,
    ["8"] = Enum.KeyCode.Eight,
    ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero,
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

    local hotbar = gui:FindFirstChild("BackpackGui") 
                   and gui.BackpackGui:FindFirstChild("Backpack") 
                   and gui.BackpackGui.Backpack:FindFirstChild("Hotbar")

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
-- POSITION LOCK
----------------------------------------------------------------
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

    if DEBUG_MODE then
        print("   🔒 Position locked")
    end
end

local function transitionToNewTarget(newTargetPos)
    if State.positionLockConn then
        State.positionLockConn:Disconnect()
        State.positionLockConn = nil
    end

    local moveComplete = false
    smoothMoveTo(newTargetPos, function()
        lockPositionLayingDown(newTargetPos)
        moveComplete = true
    end)

    local timeout = 60
    local startTime = tick()
    while not moveComplete and tick() - startTime < timeout do
        task.wait(0.1)
    end

    if not moveComplete then
        warn("   ⚠️ Transition timeout!")
        return false
    end

    return true
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
-- ISLAND DETECTION (for Arcane Pickaxe purchase)
----------------------------------------------------------------
local function getCurrentIsland()
    if not FORGES_FOLDER then return nil end
    
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            if string.match(child.Name, "Island%d+") then
                return child.Name
            end
        end
    end
    return nil
end

----------------------------------------------------------------
-- ARCANE PICKAXE AUTO-BUY TASK (Teleport to Island1 only - Quest18 does the purchase)
----------------------------------------------------------------
local function startArcaneBuyTask()
    local config = QUEST_CONFIG.ARCANE_PICKAXE_CONFIG
    if not config or not config.ENABLED then return end
    
    task.spawn(function()
        while Quest19Active do
            -- Check if already have Arcane Pickaxe
            if hasPickaxe(config.TARGET_PICKAXE) then
                print("   💜 Already have Arcane Pickaxe!")
                break  -- Already have, stop task
            end
            
            local gold = getGold()
            if gold >= config.MIN_GOLD_TO_BUY then
                print("\n" .. string.rep("=", 50))
                print("💜 ARCANE PICKAXE: Need to buy! Teleporting to Island1...")
                print(string.rep("=", 50))
                
                -- Pause current activities
                State.isPaused = true
                if ToolController then
                    ToolController.holdingM1 = false
                end
                unlockPosition()
                disableNoclip()
                task.wait(1)
                
                -- Check current island
                local currentIsland = getCurrentIsland()
                print(string.format("   📍 Current Island: %s", tostring(currentIsland)))
                
                if currentIsland == "Island2" then
                    print("   🌀 Teleporting to Island1 (Stonewake's Cross)...")
                    print("   📝 Quest18 will handle the purchase and return!")
                    teleportToIsland(config.TELEPORT_TO_BUY)
                    -- Script will re-inject on Island1, Quest18 will buy Arcane
                    return  -- Stop this task, Quest18 takes over
                else
                    print("   ✅ Already on Island1")
                    State.isPaused = false
                end
            end
            
            task.wait(15)  -- Check every 15 seconds
        end
        
        print("💜 Arcane Buy Task ended")
    end)
    
    print("   💜 Arcane Buy Task started (checking every 15s)")
end

----------------------------------------------------------------
-- ROCK HELPERS
----------------------------------------------------------------
local function getRockUndergroundPosition(rockModel)
    if not rockModel or not rockModel.Parent then
        return nil
    end

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
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end

    if rockModel.PrimaryPart then
        local pos = rockModel.PrimaryPart.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end

    local part = rockModel:FindFirstChildWhichIsA("BasePart")
    if part then
        local pos = part.Position
        return Vector3.new(pos.X, pos.Y - QUEST_CONFIG.UNDERGROUND_OFFSET, pos.Z)
    end

    return nil
end

local function getRockHP(rock)
    if not rock or not rock.Parent then
        return 0
    end

    local success, result = pcall(function()
        return rock:GetAttribute("Health") or 0
    end)

    return success and result or 0
end

local function isTargetValid(rock)
    if not rock or not rock.Parent then
        return false
    end

    if not rock:FindFirstChildWhichIsA("BasePart") then
        return false
    end

    local hp = getRockHP(rock)
    return hp > 0
end

-- Get current rock name and paths based on pickaxe
local function getCurrentMiningConfig()
    local magmaPickaxe = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG and QUEST_CONFIG.MAGMA_PICKAXE_CONFIG.TARGET_PICKAXE or "Magma Pickaxe"
    local cobaltPickaxe = QUEST_CONFIG.TARGET_PICKAXE or "Cobalt Pickaxe"

    -- Tier 3: Magma Pickaxe → Basalt Core (User requested due to crowding at Vein)
    if hasPickaxe(magmaPickaxe) then
        print("   🔥 Have Magma Pickaxe → Mining Basalt Core (Crowded Vein)")
        return {
            ROCK_NAME = QUEST_CONFIG.BASALT_CORE_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.BASALT_CORE_CONFIG.MINING_PATHS,
        }
    -- Tier 2: Cobalt Pickaxe → Basalt Core
    elseif hasPickaxe(cobaltPickaxe) then
        print("   💎 Have Cobalt Pickaxe → Mining Basalt Core")
        return {
            ROCK_NAME = QUEST_CONFIG.BASALT_CORE_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.BASALT_CORE_CONFIG.MINING_PATHS,
        }
    -- Tier 1: Default → Basalt Rock
    else
        print("   ⛏️ No special Pickaxe → Mining Basalt Rock")
        return {
            ROCK_NAME = QUEST_CONFIG.ROCK_NAME,
            MINING_PATHS = QUEST_CONFIG.MINING_PATHS,
        }
    end
end

local function findNearestBasaltRock(excludeRock)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    cleanupExpiredBlacklist()

    -- Get current mining config based on pickaxe
    local miningConfig = getCurrentMiningConfig()
    local rockName = miningConfig.ROCK_NAME
    local miningPaths = miningConfig.MINING_PATHS

    local targetRock, minDist = nil, math.huge
    local skippedOccupied = 0

    for _, pathName in ipairs(miningPaths) do
        local folder = MINING_FOLDER_PATH:FindFirstChild(pathName)

        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("SpawnLocation") or child.Name == "SpawnLocation" then
                    local rock = child:FindFirstChild(rockName)

                    if rock and rock ~= excludeRock and isTargetValid(rock) then
                        if isRockOccupied(rock) then
                            skippedOccupied = skippedOccupied + 1
                        else
                            local pos = getRockUndergroundPosition(rock)
                            if pos then
                                local dist = (pos - hrp.Position).Magnitude

                                if dist < minDist then
                                    minDist = dist
                                    targetRock = rock
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if skippedOccupied > 0 then
        print(string.format("   ⏭️ Skipped %d occupied rocks (blacklisted)", skippedOccupied))
    end

    return targetRock, minDist, rockName
end

local function watchRockHP(rock)
    if State.hpWatchConn then
        State.hpWatchConn:Disconnect()
    end

    if not rock then return end

    State.hpWatchConn = rock:GetAttributeChangedSignal("Health"):Connect(function()
        local hp = rock:GetAttribute("Health") or 0

        if hp <= 0 then
            print("   ✅ Rock destroyed!")
            State.targetDestroyed = true

            if ToolController then
                ToolController.holdingM1 = false
            end
        end
    end)
end

----------------------------------------------------------------
-- MINING EXECUTION
----------------------------------------------------------------
local function doMineBasaltRock()
    -- Check pickaxe and determine rock type
    local miningConfig = getCurrentMiningConfig()
    local currentRockName = miningConfig.ROCK_NAME

    print("\n⛏️ Mining Started...")
    print(string.format("   🎯 Mining: %s", currentRockName))
    print(string.format("   Target: %d rocks", QUEST_CONFIG.MAX_ROCKS_TO_MINE))

    IsMiningActive = true

    local miningCount = 0

    print("\n" .. string.rep("=", 50))
    print(string.format("⛏️ Mining Loop (%s)...", currentRockName))
    print(string.rep("=", 50))

    while Quest19Active and miningCount < QUEST_CONFIG.MAX_ROCKS_TO_MINE do
        if State.isPaused then
            print("   ⏸️  Paused (Auto Buy running)...")
            task.wait(2)
            continue
        end

        -- 🎯 COBALT MODE: Check for Rare Weapon or Forge if have ores
        if hasPickaxe(QUEST_CONFIG.TARGET_PICKAXE) then
            -- This now checks: 1) Rare Weapon exists? 2) Have ores to forge? 3) Otherwise continue mining
            local success = doCobaltModeRoutine()
            if success then
                -- Cobalt Mode completed (rare weapon found, now killing monsters)
                break
            end
            -- If not successful (no rare weapon, no ores), continue mining
        end

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if not hrp then
            warn("   ⚠️ Waiting for character...")
            task.wait(2)
            continue
        end

        if not State.positionLockConn and not State.moveConn and not State.bodyVelocity then
            cleanupState()
        end

        local targetRock, dist, rockName = findNearestBasaltRock(State.currentTarget)

        if not targetRock then
            warn(string.format("   ❌ No %s found!", rockName or "rocks"))
            unlockPosition()
            cleanupState()
            task.wait(3)
            continue
        end

        local previousTarget = State.currentTarget
        State.currentTarget = targetRock
        State.targetDestroyed = false

        local targetPos = getRockUndergroundPosition(targetRock)

        if not targetPos then
            warn("   ❌ Cannot get position!")
            task.wait(1)
            continue
        end

        local currentHP = getRockHP(targetRock)

        print(string.format("\n🎯 Target #%d: %s (HP: %d, Dist: %.1f)", 
            miningCount + 1,
            targetRock.Parent.Parent.Name,
            currentHP, 
            dist))

        watchRockHP(targetRock)

        -- If we're locked to a DIFFERENT target, use smooth transition
        -- Otherwise, always use smoothMoveTo (even for same target after respawn)
        if State.positionLockConn and previousTarget and previousTarget ~= targetRock then
            print("   🔄 Transition to new target...")
            transitionToNewTarget(targetPos)
        else
            -- Unlock any existing position lock first
            if State.positionLockConn then
                unlockPosition()
            end

            local moveStarted = false
            smoothMoveTo(targetPos, function()
                lockPositionLayingDown(targetPos)
                moveStarted = true
            end)

            local timeout = 60
            local startTime = tick()
            while not moveStarted and tick() - startTime < timeout do
                task.wait(0.1)
            end

            if not moveStarted then
                warn("   ⚠️ Move timeout, skip this rock")
                State.targetDestroyed = true
                unlockPosition()
                continue
            end
        end

        task.wait(0.5)

        while not State.targetDestroyed and Quest19Active and not State.isPaused do
            if not char or not char.Parent then
                break
            end

            if not targetRock or not targetRock.Parent then
                State.targetDestroyed = true
                break
            end

            if checkMiningError() then
                print("   ⚠️ Someone else mining! Switching target...")
                markRockAsOccupied(targetRock)
                State.targetDestroyed = true
                if ToolController then
                    ToolController.holdingM1 = false
                end
                break
            end

            local toolInHand = char:FindFirstChildWhichIsA("Tool")
            local isPickaxeHeld = toolInHand and string.find(toolInHand.Name, "Pickaxe")

            if not isPickaxeHeld then
                if ToolController then
                    ToolController.holdingM1 = false
                end

                local key = findPickaxeSlotKey()
                if key then
                    pressKey(key)
                    task.wait(0.3)
                else
                    pcall(function()
                        if PlayerController and PlayerController.Replica then
                            local replica = PlayerController.Replica
                            if replica.Data and replica.Data.Inventory and replica.Data.Inventory.Equipments then
                                for id, item in pairs(replica.Data.Inventory.Equipments) do
                                    if type(item) == "table" and item.Type and string.find(item.Type, "Pickaxe") then
                                        CHAR_RF:InvokeServer({Runes = {}}, item)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                    task.wait(0.5)
                end
            else
                if ToolController and ToolActivatedFunc then
                    ToolController.holdingM1 = true
                    pcall(function()
                        ToolActivatedFunc(ToolController, toolInHand)
                    end)
                else
                    pcall(function()
                        TOOL_RF_BACKUP:InvokeServer(toolInHand.Name, true)
                    end)
                end
            end

            task.wait(0.15)
        end

        if State.targetDestroyed then
            miningCount = miningCount + 1
        end

        if QUEST_CONFIG.HOLD_POSITION_AFTER_MINE then
            print("   ⏸️  Holding position, searching for next target...")
        else
            unlockPosition()
        end

        task.wait(0.5)
    end

    print("\n" .. string.rep("=", 50))
    print("✅ Mining ended")
    print(string.rep("=", 50))

    IsMiningActive = false
    unlockPosition()
    disableNoclip()
    cleanupState()
end

----------------------------------------------------------------
-- SMART QUEST RUNNER
----------------------------------------------------------------
print(string.rep("=", 50))
print("🚀 QUEST 19: " .. QUEST_CONFIG.QUEST_NAME)
print("🎯 Objective: Mining + Auto Sell & Buy")
print(string.rep("=", 50))

-- Check Level
print("\n🔍 Pre-check: Verifying level requirement...")
if not hasRequiredLevel() then
    print("\n❌ Level requirement not met!")
    print(string.rep("=", 50))
    cleanupState()
    disableNoclip()
    return
end

-- Priority 1: Auto Sell Init
print("\n🔍 Priority 1: Auto Sell Initialization...")
if QUEST_CONFIG.AUTO_SELL_ENABLED then
    if not AutoSellInitialized then
        local success = initAutoSellWithNPC()
        if not success then
            warn("   ⚠️ Auto Sell Init Failed - Skipping")
        end
    else
        print("   ✅ Auto Sell already initialized")
    end
end

-- Priority 2: Background Tasks
print("\n🔍 Priority 2: Starting Background Tasks...")
startAutoSellTask()
startAutoBuyTask()
startArcaneBuyTask()  -- Arcane Pickaxe (Gold >= 128k)
startMagmaBuyTask()
startStashCheckTask()

-- Priority 3: Mode Selection (Magma Mode > Arcane Mode > Cobalt Mode > Mining)
print("\n🔍 Priority 3: Checking Mode...")

-- 🔥 Magma Mode: Monster Killing (if have Magma Pickaxe)
if QUEST_CONFIG.MAGMA_MODE_CONFIG and QUEST_CONFIG.MAGMA_MODE_CONFIG.ENABLED then
    local magmaName = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG.TARGET_PICKAXE
    local hasIt, _ = isPickaxeEquipped(magmaName)
    if hasIt then
        print("   🔥 Magma Pickaxe detected → Starting Magma Mode!")
        doMagmaModeRoutine()
        -- After Magma Mode ends, continue to mining
    end
end

-- 💜 Arcane Mode: Monster Killing (if have Arcane Pickaxe, no Magma)
if QUEST_CONFIG.ARCANE_MODE_CONFIG and QUEST_CONFIG.ARCANE_MODE_CONFIG.ENABLED then
    local arcaneName = QUEST_CONFIG.ARCANE_PICKAXE_CONFIG.TARGET_PICKAXE
    local magmaName = QUEST_CONFIG.MAGMA_PICKAXE_CONFIG.TARGET_PICKAXE
    local hasArcane, _ = isPickaxeEquipped(arcaneName)
    local hasMagma, _ = isPickaxeEquipped(magmaName)
    if hasArcane and not hasMagma then
        print("   💜 Arcane Pickaxe detected → Starting Arcane Mode!")
        doArcaneModeRoutine()
        -- After Arcane Mode ends, continue to mining
    end
end

-- 💎 Cobalt Mode: Ore Collection + Forge + Monster Killing
if QUEST_CONFIG.COBALT_MODE_CONFIG and QUEST_CONFIG.COBALT_MODE_CONFIG.ENABLED then
    local cobaltName = QUEST_CONFIG.TARGET_PICKAXE
    if hasPickaxe(cobaltName) then
        -- Check for existing rare weapon or enough ores
        local rareDone = doCobaltModeRoutine()
        if rareDone then
            print("   💎 Cobalt Mode completed!")
        end
    end
end

-- ⛏️ Mining (Basalt Rock / Basalt Core)
print("\n🔍 Starting Mining...")
doMineBasaltRock()

Quest19Active = false
cleanupState()
disableNoclip()