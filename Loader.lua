--[[
    ████████╗██╗  ██╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
       ██║   ███████║█████╗      █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  
       ██║   ██╔══██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  
       ██║   ██║  ██║███████╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
       ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    
    🔥 MODULAR QUEST LOADER
    📦 Auto-loads quests from GitHub based on active quest detection
    
    Usage: loadstring(game:HttpGet("YOUR_GITHUB_RAW_URL/Loader.lua"))()
--]]

repeat task.wait(1) until game:IsLoaded()

----------------------------------------------------------------
-- ⚙️ CONFIGURATION
----------------------------------------------------------------
local CONFIG = {
    -- 🔗 GitHub Raw URL (เปลี่ยนเป็น URL ของคุณ)
    GITHUB_BASE_URL = "https://raw.githubusercontent.com/talnw1123/The-Forge-Script3/refs/heads/main/",
    
    -- ⏱️ Timing
    INITIAL_WAIT = 20,          -- รอเริ่มต้น (วินาที)
    QUEST_CHECK_INTERVAL = 2,    -- เช็ค Quest ใหม่ทุกกี่วินาที
    
    -- 🎮 Quest Range
    MIN_QUEST = 1,
    MAX_QUEST = 19,  -- Updated: 1-18 for Island1, 19 for Island2
    
    -- 🔧 Debug
    DEBUG_MODE = true,
    
    -- 🚀 Optimization
    LOAD_FPS_BOOSTER = true,
    
    -- 🛡️ Anti-AFK
    ANTI_AFK_ENABLED = true,
    ANTI_AFK_INTERVAL = 120,   -- ทุกๆ 2 นาที
    ANTI_AFK_CLICK_COUNT = 5,  -- จำนวนคลิกต่อรอบ
}

----------------------------------------------------------------
-- 📦 LOAD SHARED UTILITIES
----------------------------------------------------------------
print("=" .. string.rep("=", 59))
print("🔥 THE FORGE - MODULAR QUEST LOADER")
print("=" .. string.rep("=", 59))

print("\n⏳ Initial wait: " .. CONFIG.INITIAL_WAIT .. " seconds...")
task.wait(CONFIG.INITIAL_WAIT)

print("\n📦 Loading Shared Utilities...")
local sharedUrl = CONFIG.GITHUB_BASE_URL .. "Shared.lua"
local sharedSuccess, sharedError = pcall(function()
    loadstring(game:HttpGet(sharedUrl))()
end)

if not sharedSuccess then
    warn("❌ Failed to load Shared.lua: " .. tostring(sharedError))
    warn("💡 Make sure the URL is correct: " .. sharedUrl)
    return
end

print("✅ Shared utilities loaded!")

-- ตรวจสอบว่า Shared โหลดสำเร็จ
if not _G.Shared then
    warn("❌ _G.Shared not found after loading Shared.lua")
    return
end

local Shared = _G.Shared

----------------------------------------------------------------
-- 🔍 QUEST DETECTION SYSTEM
----------------------------------------------------------------
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Workspace = game:GetService("Workspace")

-- 🌍 ISLAND DETECTION
local FORGES_FOLDER = Workspace:WaitForChild("Forges", 10)

local function getCurrentIsland()
    if not FORGES_FOLDER then
        return nil
    end
    
    for _, child in ipairs(FORGES_FOLDER:GetChildren()) do
        if child:IsA("Folder") or child:IsA("Model") then
            local islandMatch = string.match(child.Name, "Island(%d+)")
            if islandMatch then
                return "Island" .. islandMatch
            end
        end
    end
    return nil
end


----------------------------------------------------------------
-- 🚀 LOAD FPS BOOSTER
----------------------------------------------------------------
if CONFIG.LOAD_FPS_BOOSTER then
    print("\n🚀 Loading FPS Booster...")
    local fpsUrl = CONFIG.GITHUB_BASE_URL .. "Utils/FPSBooster.lua?t=" .. tostring(tick())
    local fpsSuccess, fpsError = pcall(function()
        local code = game:HttpGet(fpsUrl)
        local func, syntaxErr = loadstring(code)
        if func then
            func()
        else
            error("Syntax error in FPSBooster: " .. tostring(syntaxErr))
        end
    end)
    
    if fpsSuccess then
        print("✅ FPS Booster loaded!")
        
        -- 🔄 WAIT FOR DESYNC RESPAWN TO COMPLETE
        if _G.DesyncEnabled then
            print("\n🔄 Waiting for Desync to activate...")
            
            -- Wait for Desync to be ready (max 20 seconds)
            local desyncWaitStart = tick()
            while not _G.DesyncReady and (tick() - desyncWaitStart) < 20 do
                task.wait(0.5)
            end
            
            if _G.DesyncReady then
                print("✅ Desync activated!")
                print("⏳ Waiting 15 seconds before starting quests...")
                task.wait(15)
                print("✅ Wait complete! Starting quest system...")
            else
                print("⚠️ Desync timeout, continuing anyway...")
            end
        end
    else
        warn("⚠️ Failed to load FPS Booster: " .. tostring(fpsError))
        warn("   URL: " .. fpsUrl)
    end
end

----------------------------------------------------------------
-- 🛡️ ANTI-AFK SYSTEM
----------------------------------------------------------------
if CONFIG.ANTI_AFK_ENABLED then
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local GuiService = game:GetService("GuiService")
    local camera = workspace.CurrentCamera
    
    local function performAntiAfkClicks()
        local viewportSize = camera.ViewportSize
        local guiInset = GuiService:GetGuiInset()
        local centerX = viewportSize.X / 2
        local centerY = (viewportSize.Y / 2) + guiInset.Y
        
        print("🛡️ [ANTI-AFK] Performing " .. CONFIG.ANTI_AFK_CLICK_COUNT .. " virtual clicks...")
        
        for i = 1, CONFIG.ANTI_AFK_CLICK_COUNT do
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1)
            task.wait(0.05)
            VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1)
            
            if i < CONFIG.ANTI_AFK_CLICK_COUNT then
                task.wait(0.5)
            end
        end
        
        print("🛡️ [ANTI-AFK] Clicks complete! Next in " .. CONFIG.ANTI_AFK_INTERVAL .. " seconds.")
    end
    
    task.spawn(function()
        print("🛡️ [ANTI-AFK] System started! Clicking every " .. CONFIG.ANTI_AFK_INTERVAL .. " seconds.")
        while true do
            task.wait(CONFIG.ANTI_AFK_INTERVAL)
            pcall(performAntiAfkClicks)
        end
    end)
end


----------------------------------------------------------------
-- 📊 LEVEL CHECK SYSTEM
----------------------------------------------------------------
local function getPlayerLevel()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local levelLabel = gui:FindFirstChild("Main")
                      and gui.Main:FindFirstChild("Screen")
                      and gui.Main.Screen:FindFirstChild("Hud")
                      and gui.Main.Screen.Hud:FindFirstChild("Level")
    
    if not levelLabel or not levelLabel:IsA("TextLabel") then
        return nil
    end
    
    local levelText = levelLabel.Text
    local level = tonumber(string.match(levelText, "%d+"))
    return level
end


----------------------------------------------------------------
-- 📋 QUEST LIST EMPTY CHECK
----------------------------------------------------------------
local function isQuestListEmpty()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return false end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return false end
    
    -- Check if list only has UIListLayout and UIPadding (no actual quests)
    for _, child in ipairs(list:GetChildren()) do
        if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            return false  -- Found a quest item!
        end
    end
    
    return true  -- Only UIListLayout and UIPadding = empty!
end

local function getActiveQuestNumber()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return nil end
    
    -- หา Quest ที่ active อยู่
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            local questName = child.Frame.TextLabel.Text
            local questNum = tonumber(id) + 1
            
            if questNum and questName ~= "" then
                -- เช็คว่า quest ยังไม่เสร็จ
                local objList = list:FindFirstChild("Introduction" .. id .. "List")
                if objList then
                    for _, item in ipairs(objList:GetChildren()) do
                        if item:IsA("Frame") and tonumber(item.Name) then
                            local check = item:FindFirstChild("Main") 
                                and item.Main:FindFirstChild("Frame") 
                                and item.Main.Frame:FindFirstChild("Check")
                            if check and not check.Visible then
                                -- พบ objective ที่ยังไม่เสร็จ
                                return questNum, questName
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

local function isQuestComplete(questNum)
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return true end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return true end
    
    -- Convert 1-based QuestNum back to 0-based UI ID
    local uiID = questNum - 1
    local objList = list:FindFirstChild("Introduction" .. uiID .. "List")
    if not objList then return true end
    
    for _, item in ipairs(objList:GetChildren()) do
        if item:IsA("Frame") and tonumber(item.Name) then
            local check = item:FindFirstChild("Main") 
                and item.Main:FindFirstChild("Frame") 
                and item.Main.Frame:FindFirstChild("Check")
            if check and not check.Visible then
                return false
            end
        end
    end
    
    return true
end

----------------------------------------------------------------
-- 📥 QUEST LOADER
----------------------------------------------------------------
local loadedQuests = {}

local function loadQuest(questNum)
    local questFile = string.format("Quest%02d.lua", questNum)
    local questUrl = CONFIG.GITHUB_BASE_URL .. "Quests/" .. questFile .. "?t=" .. tostring(tick())
    
    -- Skip verbose logging for Quest 15 (runs in background frequently)
    local showLogs = (questNum ~= 15)
    
    if showLogs then
        print(string.format("\n📥 Loading %s from GitHub...", questFile))
        print("   URL: " .. questUrl)
    end
    
    local success, result = pcall(function()
        local code = game:HttpGet(questUrl)
        local func, syntaxErr = loadstring(code)
        if func then
            return func()
        else
            error("Failed to compile quest code: " .. tostring(syntaxErr))
        end
    end)
    
    if success then
        if showLogs then
            print(string.format("✅ %s loaded successfully!", questFile))
        end
        loadedQuests[questNum] = true
        return true
    else
        warn(string.format("❌ Failed to load %s: %s", questFile, tostring(result)))
        return false
    end
end



----------------------------------------------------------------
-- � QUEST 15 BACKGROUND (Auto Claim Index)
----------------------------------------------------------------
-- Start immediately, run every 2 seconds
local quest15Running = false

local function startQuest15Background()
    if quest15Running then return end
    quest15Running = true
    
    task.spawn(function()
        -- Silent startup (no spam in console)
        while quest15Running do
            pcall(function()
                loadQuest(15)
            end)
            
            task.wait(2)  -- Run every 10 seconds
        end
    end)
end

-- Start Quest 15 Background immediately
startQuest15Background()


----------------------------------------------------------------
-- 🎮 MAIN QUEST RUNNER
----------------------------------------------------------------
local function runQuestLoop()
    print("\n" .. string.rep("=", 60))
    print("🎮 STARTING AUTO QUEST RUNNER")
    print(string.rep("=", 60))
    
    -- ✅ RECOVERY CHECK: Quest List is empty?
    if isQuestListEmpty() then
        print("\n" .. string.rep("!", 50))
        print("⚠️ QUEST LIST IS EMPTY!")
        print("   → No quests in PlayerGui.Main.Screen.Quests.List")
        print("   → Player may have disconnected during Quest 1 dialogue")
        print("   → Force loading Quest 1 for recovery...")
        print(string.rep("!", 50))
        
        loadQuest(1)
        task.wait(5)
        
        print("✅ Quest 1 recovery attempted. Continuing...")
    end
    
    local maxAttempts = 3
    local reachedQuest18 = false
    local quest13Run = false  -- Track Quest 13 execution
    
    -- 🌍 ISLAND-BASED QUEST ROUTING
    local currentIsland = getCurrentIsland()
    print(string.format("\n🌍 Current Island: %s", currentIsland or "Unknown"))
    
    if currentIsland == "Island2" then
        -- ============================================
        -- 🌋 ISLAND 2 DETECTED
        -- ============================================
        
        -- 🌐 AUTO SERVER HOP CONFIG
        local AUTO_HOP_CONFIG = {
            ENABLED = true,
            MAX_PLAYERS = 4,                    -- Server hop if players > 4
            ISLAND2_PLACE_ID = 129009554587176, -- Forgotten Kingdom PlaceID
            MAX_PLAYERS_PREFERRED = 3,          -- Prefer servers with <= 3 players
            CHECK_INTERVAL = 10,                -- Check every 10 seconds
        }
        
        -- 🌐 CHECK PLAYER COUNT AND SERVER HOP IF NEEDED
        if AUTO_HOP_CONFIG.ENABLED then
            local playerCount = #Players:GetPlayers()
            print(string.format("\\n👥 Current Player Count: %d (Max: %d)", playerCount, AUTO_HOP_CONFIG.MAX_PLAYERS))
            
            if playerCount > AUTO_HOP_CONFIG.MAX_PLAYERS then
                print("\\n" .. string.rep("=", 60))
                print("🌐 TOO MANY PLAYERS! Starting Server Hop...")
                print(string.rep("=", 60))
                
                -- 📡 GET BEST SERVER FUNCTION
                local HttpService = game:GetService("HttpService")
                local TeleportService = game:GetService("TeleportService")
                
                local function getBestServer(placeId, maxPlayers)
                    local url = string.format(
                        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                        placeId
                    )
                    
                    local success, response = pcall(function()
                        return game:HttpGet(url)
                    end)
                    
                    if not success then
                        warn("   ❌ Failed to fetch servers: " .. tostring(response))
                        return nil
                    end
                    
                    local data = HttpService:JSONDecode(response)
                    
                    if not data or not data.data then
                        warn("   ❌ Invalid server data")
                        return nil
                    end
                    
                    -- Find server with lowest player count
                    local bestServer = nil
                    local lowestPlayers = math.hwuge
                    
                    for _, server in ipairs(data.data) do
                        if server.playing and server.playing < lowestPlayers and server.playing < server.maxPlayers then
                            -- Prefer servers with <= maxPlayers
                            if server.playing <= maxPlayers then
                                lowestPlayers = server.playing
                                bestServer = server
                            elseif not bestServer then
                                lowestPlayers = server.playing
                                bestServer = server
                            end
                        end
                    end
                    
                    return bestServer
                end
                
                -- 🚀 FIND AND TELEPORT TO LOW PLAYER SERVER
                local bestServer = getBestServer(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, AUTO_HOP_CONFIG.MAX_PLAYERS_PREFERRED)
                
                if bestServer then
                    print(string.format("   ✅ Found server: %d/%d players", bestServer.playing, bestServer.maxPlayers))
                    print(string.format("   🆔 Server ID: %s", tostring(bestServer.id)))
                    
                    -- Queue Haze Loader anti-teleport script
                    if queue_on_teleport then
                        local queueScript = [[
                            -- [[ HAZE LOADER TELEPORT STOPPER 
                            local stoppedTp = false
                            local attempts = 0
                            while not stoppedTp and attempts < 100 do
                                attempts = attempts + 1
                                local tpService = cloneref and cloneref(game:GetService("TeleportService")) or game:GetService("TeleportService")
                                pcall(function() tpService:SetTeleportGui(tpService) end)
                                
                                local logService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")
                                pcall(function()
                                    for i, v in logService:GetLogHistory() do
                                        if v.message:find("cannot be cloned") then
                                            stoppedTp = true
                                            warn("✅ Teleport STOPPED!")
                                            break
                                        end
                                    end
                                end)
                                
                                task.wait()
                                pcall(function() tpService:TeleportCancel() end)
                                pcall(function() tpService:SetTeleportGui(nil) end)
                            end
                            warn("🎉 Anti-teleport completed!")
                        ]]
                        
                        queue_on_teleport(queueScript)
                        print("   📜 Queued anti-teleport script")
                    end
                    
                    -- Teleport!
                    print(string.format("   🚀 Teleporting to low-player server..."))
                    print(string.format("   🆔 Trying server with %d players...", bestServer.playing))
                    
                    -- Try TeleportToPlaceInstance first, fallback to Teleport
                    local success, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, bestServer.id)
                    end)
                    
                    if not success then
                        warn("   ⚠️ TeleportToPlaceInstance failed: " .. tostring(err))
                        print("   🔄 Trying fallback Teleport (random server)...")
                        
                        -- Fallback: Just teleport to any Island2 server
                        local success2, err2 = pcall(function()
                            TeleportService:Teleport(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID)
                        end)
                        
                        if success2 then
                            print("   ✅ Fallback teleport initiated!")
                            while true do task.wait(1) end
                        else
                            warn("   ❌ Fallback teleport failed: " .. tostring(err2))
                            print("   ⚠️ Continuing with current server...")
                        end
                    else
                        print("   ✅ Teleport initiated!")
                        -- Wait forever since we're teleporting
                        while true do task.wait(1) end
                    end
                else
                    warn("   ❌ No suitable low-player server found")
                    print("   ⚠️ Continuing with current server...")
                end
            else
                print("   ✅ Player count OK! No server hop needed.")
            end
        end
        
        -- 🔄 BACKGROUND PLAYER COUNT MONITORING (every 10 seconds)
        if AUTO_HOP_CONFIG.ENABLED then
            task.spawn(function()
                print("🔄 [AUTO-HOP] Background monitoring started (every " .. AUTO_HOP_CONFIG.CHECK_INTERVAL .. "s)")
                
                while true do
                    task.wait(AUTO_HOP_CONFIG.CHECK_INTERVAL)
                    
                    local currentPlayers = #Players:GetPlayers()
                    
                    if currentPlayers > AUTO_HOP_CONFIG.MAX_PLAYERS then
                        print(string.format("\n👥 [AUTO-HOP] Player count: %d > %d, initiating server hop...", 
                            currentPlayers, AUTO_HOP_CONFIG.MAX_PLAYERS))
                        
                        -- Re-use the getBestServer function (need to define it outside the if block)
                        local HttpService = game:GetService("HttpService")
                        local TeleportService = game:GetService("TeleportService")
                        
                        local url = string.format(
                            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
                            AUTO_HOP_CONFIG.ISLAND2_PLACE_ID
                        )
                        
                        local success, response = pcall(function()
                            return game:HttpGet(url)
                        end)
                        
                        if success then
                            local data = HttpService:JSONDecode(response)
                            if data and data.data then
                                local bestServer = nil
                                local lowestPlayers = math.huge
                                
                                for _, server in ipairs(data.data) do
                                    if server.playing and server.playing < lowestPlayers and server.playing < server.maxPlayers then
                                        if server.playing <= AUTO_HOP_CONFIG.MAX_PLAYERS_PREFERRED then
                                            lowestPlayers = server.playing
                                            bestServer = server
                                        end
                                    end
                                end
                                
                                if bestServer then
                                    print(string.format("   ✅ Found server: %d/%d players", bestServer.playing, bestServer.maxPlayers))
                                    
                                    local success = pcall(function()
                                        TeleportService:TeleportToPlaceInstance(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, bestServer.id)
                                    end)
                                    
                                    if not success then
                                        -- Fallback to random server
                                        print("   🔄 Fallback to random Island2 server...")
                                        pcall(function()
                                            TeleportService:Teleport(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID)
                                        end)
                                    end
                                    
                                    while true do task.wait(1) end
                                end
                            end
                        end
                    end
                end
            end)
        end
        
        -- 🌋 START QUEST 19
        print("\n" .. string.rep("=", 60))
        print("🌋 ISLAND 2 - QUEST 19 MODE")
        print("   ⛏️ Starting Mining + Auto Sell & Buy...")
        print(string.rep("=", 60))
        
        -- Run Quest 19 ONCE - it has its own internal infinite loop
        loadQuest(19)
        
        -- Quest 19 will run its mining loop internally
        -- This return is reached only if Quest 19 ends (which it shouldn't)
        return
    end
    
    -- ============================================
    -- 🏝️ ISLAND 1: RUN QUESTS 1-18 (Normal Flow)
    -- ============================================
    print("\n🏝️ ISLAND 1 MODE - Running Quests 1-18...")
    
    local currentQuest = CONFIG.MIN_QUEST
    
    -- เช็คว่าเริ่มที่ Quest 18 หรือยัง
    local activeNum, _ = getActiveQuestNumber()
    if activeNum and activeNum >= 18 then
        reachedQuest18 = true
        print("\n🌋 Quest 18 detected! Skipping Quest 1-17 checks...")
    end
    
    while currentQuest <= 18 do  -- Island 1: max = 18
        -- ถ้าถึง Quest 18 แล้ว ให้ skip ไป Quest 18 เลย
        if reachedQuest18 and currentQuest < 18 then
            currentQuest = 18
            continue
        end
        
        -- ============================================
        -- 🛠️ CUSTOM QUEST LOGIC (13, 14, 15, 16, 17, 18)
        -- ไม่เช็ค UI, รันตาม internal logic
        -- ============================================
        if currentQuest == 13 then
            -- Quest 13: Run once per session
            if not quest13Run then
                print("\n🎵 Loading Quest 13 (Bard Quest) [Run Once Per Session]...")
                loadQuest(13)
                quest13Run = true
            else
                print("   ⏭️ Quest 13 already ran this session, skipping.")
            end
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 14 then
            -- Quest 14: Lost Guitar (internal check, uses BardQuest not Introduction{N})
            print("\n🎸 Loading Quest 14 (Lost Guitar)...")
            loadQuest(14)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 15 then
            -- Quest 15: Skip UI check, already running in background
            -- (Silent skip - no console spam)
            currentQuest = currentQuest + 1
            task.wait(1)
            continue
            
        elseif currentQuest == 16 then
            -- Quest 16: Auto Buy Pickaxe (Gold >= 3340 AND Level < 10, no UI check)
            print("\n🛒 Loading Quest 16 (Auto Buy Pickaxe)...")
            loadQuest(16)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 17 then
            -- Quest 17: Auto mining until level 10 (internal check)
            print("\n⛏️ Loading Quest 17 (Auto Mining Until Level 10)...")
            loadQuest(17)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 18 then
            -- Quest 18: Smart mining (internal check)
            print("\n🌋 Loading Quest 18 (Smart Mining)...")
            loadQuest(18)
            break  -- Quest 18 is infinite loop
        end
        
        -- ============================================
        -- 📋 STANDARD UI-BASED QUEST LOGIC (1-12)
        -- ============================================
        print(string.format("\n🔍 Checking Quest %d...", currentQuest))
        
        -- เช็คว่า Quest นี้ active หรือยัง
        activeNum, activeName = getActiveQuestNumber()
        
        if activeNum then
            print(string.format("   📋 Active Quest: #%d - %s", activeNum, activeName or "Unknown"))
            
            -- ถ้าถึง Quest 18 ให้ mark ว่าไม่ต้องเช็ค Quest เก่าอีก
            if activeNum >= 18 then
                reachedQuest18 = true
            end
            
            -- โหลดและรัน Quest
            local attempts = 0
            while attempts < maxAttempts do
                attempts = attempts + 1
                print(string.format("\n🚀 Running Quest %d (Attempt %d/%d)...", activeNum, attempts, maxAttempts))
                
                local success = loadQuest(activeNum)
                
                if success then
                    -- รอให้ Quest เสร็จ
                    print("   ⏳ Waiting for quest to complete...")
                    
                    local timeout = 600  -- 10 นาที timeout
                    local startTime = tick()
                    
                    while not isQuestComplete(activeNum) and (tick() - startTime) < timeout do
                        task.wait(CONFIG.QUEST_CHECK_INTERVAL)
                    end
                    
                    if isQuestComplete(activeNum) then
                        print(string.format("✅ Quest %d Complete!", activeNum))
                        break
                    else
                        warn(string.format("⏰ Quest %d timed out!", activeNum))
                    end
                else
                    warn(string.format("❌ Failed to load Quest %d", activeNum))
                    task.wait(5)
                end
            end
            
            currentQuest = activeNum + 1
        else
            -- ⚠️ NO ACTIVE QUEST FOUND
            print("   ⚠️ No active quest found!")
            
            local playerLevel = getPlayerLevel()
            print(string.format("   📊 Player Level: %s", tostring(playerLevel)))
            
            -- 🩹 RECOVERY: If we're checking Quest 1 and no UI found
            -- This means player likely disconnected during Quest 1 dialogue
            if currentQuest == 1 then
                print("\n" .. string.rep("!", 50))
                print("⚠️ RECOVERY MODE: No Quest 1 UI found!")
                print("   → May have disconnected during Quest 1 dialogue")
                print("   → Force loading Quest 1...")
                print(string.rep("!", 50))
                
                loadQuest(1)  -- Quest 1 has its own logic to handle this
                task.wait(5)
                
                -- Move to Quest 2 regardless (Quest 1 script handles completion)
                currentQuest = 2
            else
                -- Normal case: skip to next quest
                currentQuest = currentQuest + 1
            end
        end
        
        task.wait(2)
    end
    
    -- ============================================
    -- 🌋 QUEST 18 INFINITE LOOP MODE
    -- ============================================
    if reachedQuest18 then
        print("\n" .. string.rep("=", 60))
        print("🌋 QUEST 18 - INFINITE FARMING MODE")
        print("   ⚠️ Will NOT check Quest 1-17 anymore")
        print(string.rep("=", 60))
        
        local loopCount = 0
        
        while true do
            loopCount = loopCount + 1
            print(string.format("\n🔄 Quest 18 Loop #%d", loopCount))
            
            -- รัน Quest 18
            local success = loadQuest(18)
            
            if success then
                -- รอให้ Quest 18 เสร็จ (ถ้าเสร็จได้)
                local timeout = 300  -- 5 นาที
                local startTime = tick()
                
                while not isQuestComplete(18) and (tick() - startTime) < timeout do
                    task.wait(5)
                end
            end
            
            -- รอก่อน loop ใหม่
            task.wait(5)
        end
    else
        print("\n" .. string.rep("=", 60))
        print("🎉 ALL QUESTS COMPLETED!")
        print(string.rep("=", 60))
    end
end

----------------------------------------------------------------
-- 🚀 START
----------------------------------------------------------------
-- Wait for UI to load
print("\n⏳ Waiting for Quest UI to load...")
local uiReady = false
for i = 1, 5 do
    local activeNum = getActiveQuestNumber()
    if activeNum then
        uiReady = true
        print(string.format("✅ Quest UI ready! Active Quest: #%d", activeNum))
        break
    end
    task.wait(1)
end

if not uiReady then
    warn("⚠️ Quest UI not detected, starting anyway...")
end

-- Start quest loop
runQuestLoop()
