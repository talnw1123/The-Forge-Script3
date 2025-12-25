--[[
    ████████╗██╗  ██╗███████╗    ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
    ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
       ██║   ███████║█████╗      █████╗  ██║   ██║██████╔╝██║  ███╗█████╗  
       ██║   ██╔══██║██╔══╝      ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝  
       ██║   ██║  ██║███████╗    ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
       ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
    
    🔥 MODULAR QUEST LOADER V2
    📦 Auto-loads quests from GitHub based on active quest detection
    🛡️ Fixed: Reserved Server Filter in Auto Hop
    
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
    INITIAL_WAIT = 40,        -- รอเริ่มต้น (วินาที)
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
print("🔥 THE FORGE - MODULAR QUEST LOADER V2")
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
        
        if _G.DesyncEnabled then
            print("\n🔄 Waiting for Desync to activate...")
            
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
    
    for _, child in ipairs(list:GetChildren()) do
        if child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            return false
        end
    end
    
    return true
end

local function getActiveQuestNumber()
    local gui = player:FindFirstChild("PlayerGui")
    if not gui then return nil end
    
    local list = gui:FindFirstChild("Main") 
        and gui.Main:FindFirstChild("Screen") 
        and gui.Main.Screen:FindFirstChild("Quests") 
        and gui.Main.Screen.Quests:FindFirstChild("List")
    
    if not list then return nil end
    
    for _, child in ipairs(list:GetChildren()) do
        local id = string.match(child.Name, "^Introduction(%d+)Title$")
        if id and child:FindFirstChild("Frame") and child.Frame:FindFirstChild("TextLabel") then
            local questName = child.Frame.TextLabel.Text
            local questNum = tonumber(id) + 1
            
            if questNum and questName ~= "" then
                local objList = list:FindFirstChild("Introduction" .. id .. "List")
                if objList then
                    for _, item in ipairs(objList:GetChildren()) do
                        if item:IsA("Frame") and tonumber(item.Name) then
                            local check = item:FindFirstChild("Main") 
                                and item.Main:FindFirstChild("Frame") 
                                and item.Main.Frame:FindFirstChild("Check")
                            if check and not check.Visible then
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
-- 🔄 QUEST 15 BACKGROUND (Auto Claim Index)
----------------------------------------------------------------
local quest15Running = false

local function startQuest15Background()
    if quest15Running then return end
    quest15Running = true
    
    task.spawn(function()
        while quest15Running do
            pcall(function()
                loadQuest(15)
            end)
            
            task.wait(2)
        end
    end)
end

startQuest15Background()

----------------------------------------------------------------
-- 🌐 IMPROVED SERVER FINDER (Reserved Server Filter)
----------------------------------------------------------------
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
    
    local validServers = {}
    
    print(string.format("   🔍 Scanning %d servers...", #data.data))
    
    for _, server in ipairs(data.data) do
        if server.id and 
           server.playing and 
           server.maxPlayers and
           server.playing < server.maxPlayers then
            
            -- ✅ กรอง Reserved/VIP Server
            local isReserved = false
            
            -- 1. เช็คว่ามี privateServerId หรือ reservedServerId
            if server.privateServerId or server.reservedServerId then
                isReserved = true
            end
            
            -- 2. Server ID ต้องเป็น UUID format
            if not isReserved then
                local serverId = tostring(server.id)
                if not string.match(serverId, "^%x+%-%x+%-%x+%-%x+%-%x+$") then
                    isReserved = true
                end
            end
            
            -- 3. เช็คว่ามี ping field
            if not isReserved and not server.ping then
                isReserved = true
            end
            
            -- ✅ เก็บเฉพาะ Public Server
            if not isReserved then
                table.insert(validServers, server)
            end
        end
    end
    
    if #validServers == 0 then
        warn("   ❌ No valid public servers found")
        return nil
    end
    
    print(string.format("   ✅ Found %d valid public servers", #validServers))
    
    -- เรียงตามจำนวนผู้เล่น
    table.sort(validServers, function(a, b)
        return a.playing < b.playing
    end)
    
    -- เลือก Server ที่มีคนน้อยที่สุด
    for _, server in ipairs(validServers) do
        if server.playing <= maxPlayers then
            print(string.format("   🎯 Selected: %d/%d players", server.playing, server.maxPlayers))
            return server
        end
    end
    
    print(string.format("   ⚠️ No server with <= %d players, using lowest: %d/%d", 
        maxPlayers, validServers[1].playing, validServers[1].maxPlayers))
    return validServers[1]
end

----------------------------------------------------------------
-- 🎮 MAIN QUEST RUNNER
----------------------------------------------------------------
local function runQuestLoop()
    print("\n" .. string.rep("=", 60))
    print("🎮 STARTING AUTO QUEST RUNNER")
    print(string.rep("=", 60))
    
    if isQuestListEmpty() then
        print("\n" .. string.rep("!", 50))
        print("⚠️ QUEST LIST IS EMPTY!")
        print("   → Force loading Quest 1 for recovery...")
        print(string.rep("!", 50))
        
        loadQuest(1)
        task.wait(5)
        
        print("✅ Quest 1 recovery attempted. Continuing...")
    end
    
    local maxAttempts = 3
    local reachedQuest18 = false
    local quest13Run = false
    
    -- 🌍 ISLAND-BASED QUEST ROUTING
    local currentIsland = getCurrentIsland()
    print(string.format("\n🌍 Current Island: %s", currentIsland or "Unknown"))
    
    if currentIsland == "Island2" then
        -- ============================================
        -- 🌋 ISLAND 2 DETECTED
        -- ============================================
        
        -- 🌐 AUTO SERVER HOP CONFIG (FIXED)
        local AUTO_HOP_CONFIG = {
            ENABLED = true,
            MAX_PLAYERS = 4,
            ISLAND2_PLACE_ID = 129009554587176,
            MAX_PLAYERS_PREFERRED = 3,
            CHECK_INTERVAL = 10,
            RANDOM_DELAY_MAX = 15,
            MAX_RETRIES = 3,
        }
        
        -- 🌐 CHECK AND HOP IF NEEDED
        if AUTO_HOP_CONFIG.ENABLED then
            local playerCount = #Players:GetPlayers()
            print(string.format("\n👥 Current Player Count: %d (Max: %d)", playerCount, AUTO_HOP_CONFIG.MAX_PLAYERS))
            
            if playerCount > AUTO_HOP_CONFIG.MAX_PLAYERS then
                print("\n" .. string.rep("=", 60))
                print("🌐 TOO MANY PLAYERS! Starting Server Hop...")
                print(string.rep("=", 60))
                
                local attempt = 1
                local hopSuccess = false
                
                while attempt <= AUTO_HOP_CONFIG.MAX_RETRIES and not hopSuccess do
                    print(string.format("\n🔍 Hop Attempt %d/%d", attempt, AUTO_HOP_CONFIG.MAX_RETRIES))
                    
                    local bestServer = getBestServer(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, AUTO_HOP_CONFIG.MAX_PLAYERS_PREFERRED)
                    
                    if bestServer then
                        print(string.format("   ✅ Found server: %d/%d players", bestServer.playing, bestServer.maxPlayers))
                        print(string.format("   🆔 Server ID: %s", tostring(bestServer.id)))
                        
                        -- Queue anti-teleport script
                        if queue_on_teleport then
                            local queueScript = [[
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
                                                break
                                            end
                                        end
                                    end)
                                    
                                    task.wait()
                                    pcall(function() tpService:TeleportCancel() end)
                                    pcall(function() tpService:SetTeleportGui(nil) end)
                                end
                            ]]
                            
                            queue_on_teleport(queueScript)
                            print("   📜 Queued anti-teleport script")
                        end
                        
                        local randomDelay = math.random(0, AUTO_HOP_CONFIG.RANDOM_DELAY_MAX)
                        print(string.format("   ⏳ Waiting %d seconds (anti-rate-limit)...", randomDelay))
                        task.wait(randomDelay)
                        
                        print("   🚀 Teleporting...")
                        
                        local success, err = pcall(function()
                            TeleportService:TeleportToPlaceInstance(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, bestServer.id)
                        end)
                        
                        if success then
                            print("   ✅ Teleport initiated!")
                            while true do task.wait(1) end
                        else
                            local errorMsg = tostring(err)
                            warn("   ❌ Teleport failed: " .. errorMsg)
                            
                            if string.find(errorMsg:lower(), "unauthorized") or 
                               string.find(errorMsg:lower(), "game 312") or
                               string.find(errorMsg:lower(), "unable to join") then
                                warn("   ⚠️ Reserved server detected, retrying...")
                                attempt = attempt + 1
                                task.wait(3)
                            else
                                break
                            end
                        end
                    else
                        warn("   ❌ No server found, retrying...")
                        attempt = attempt + 1
                        task.wait(3)
                    end
                end
                
                if not hopSuccess then
                    print("   ⚠️ Server hop failed, continuing with current server...")
                end
            else
                print("   ✅ Player count OK! No server hop needed.")
            end
        end
        
        -- 🔄 BACKGROUND MONITORING
        if AUTO_HOP_CONFIG.ENABLED then
            task.spawn(function()
                print("🔄 [AUTO-HOP] Background monitoring started")
                
                while true do
                    task.wait(AUTO_HOP_CONFIG.CHECK_INTERVAL)
                    
                    local currentPlayers = #Players:GetPlayers()
                    
                    if currentPlayers > AUTO_HOP_CONFIG.MAX_PLAYERS then
                        print(string.format("\n👥 [AUTO-HOP] %d > %d, hopping...", currentPlayers, AUTO_HOP_CONFIG.MAX_PLAYERS))
                        
                        local bestServer = getBestServer(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, AUTO_HOP_CONFIG.MAX_PLAYERS_PREFERRED)
                        
                        if bestServer then
                            print(string.format("   ✅ Found: %d/%d players", bestServer.playing, bestServer.maxPlayers))
                            
                            pcall(function()
                                TeleportService:TeleportToPlaceInstance(AUTO_HOP_CONFIG.ISLAND2_PLACE_ID, bestServer.id)
                            end)
                            
                            while true do task.wait(1) end
                        end
                    end
                end
            end)
        end
        
        -- 🛡️ ANTI-TELEPORT PROTECTION
        print("🛡️ Setting up Anti-Teleport protection...")
        
        task.spawn(function()
            local stoppedTp = false
            while not stoppedTp do
                local tpService = cloneref and cloneref(game:GetService("TeleportService")) or game:GetService("TeleportService")
                pcall(function() tpService:SetTeleportGui(tpService) end)
                
                local logService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")
                pcall(function()
                    for i, v in logService:GetLogHistory() do
                        if v.message:find("cannot be cloned") then
                            stoppedTp = true
                            break
                        end
                    end
                end)
                
                task.wait()
                pcall(function() tpService:TeleportCancel() end)
                pcall(function() tpService:SetTeleportGui(nil) end)
            end
        end)
        
        if hookmetamethod then
            local TeleportService = game:GetService("TeleportService")
            local blockingEnabled = true
            
            task.spawn(function()
                task.wait(10)
                blockingEnabled = false
            end)
            
            local oldhmmnc
            oldhmmnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                
                if blockingEnabled and self == TeleportService then
                    if method ~= "TeleportCancel" then
                        return nil
                    end
                end
                
                return oldhmmnc(self, ...)
            end))
        end
        
        -- 🌋 START QUEST 19
        print("\n" .. string.rep("=", 60))
        print("🌋 ISLAND 2 - QUEST 19 MODE")
        print(string.rep("=", 60))
        
        loadQuest(19)
        
        return
    end
    
    -- ============================================
    -- 🏝️ ISLAND 1: RUN QUESTS 1-18
    -- ============================================
    print("\n🏝️ ISLAND 1 MODE - Running Quests 1-18...")
    
    local currentQuest = CONFIG.MIN_QUEST
    
    local activeNum, _ = getActiveQuestNumber()
    if activeNum and activeNum >= 18 then
        reachedQuest18 = true
        print("\n🌋 Quest 18 detected! Skipping Quest 1-17 checks...")
    end
    
    while currentQuest <= 18 do
        if reachedQuest18 and currentQuest < 18 then
            currentQuest = 18
            continue
        end
        
        -- Custom quest logic (13-18)
        if currentQuest == 13 then
            if not quest13Run then
                print("\n🎵 Loading Quest 13...")
                loadQuest(13)
                quest13Run = true
            end
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 14 then
            print("\n🎸 Loading Quest 14...")
            loadQuest(14)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 15 then
            currentQuest = currentQuest + 1
            task.wait(1)
            continue
            
        elseif currentQuest == 16 then
            print("\n🛒 Loading Quest 16...")
            loadQuest(16)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 17 then
            print("\n⛏️ Loading Quest 17...")
            loadQuest(17)
            currentQuest = currentQuest + 1
            task.wait(2)
            continue
            
        elseif currentQuest == 18 then
            print("\n🌋 Loading Quest 18...")
            loadQuest(18)
            break
        end
        
        -- Standard UI-based logic (1-12)
        print(string.format("\n🔍 Checking Quest %d...", currentQuest))
        
        activeNum, activeName = getActiveQuestNumber()
        
        if activeNum then
            print(string.format("   📋 Active Quest: #%d - %s", activeNum, activeName or "Unknown"))
            
            if activeNum >= 18 then
                reachedQuest18 = true
            end
            
            local attempts = 0
            while attempts < maxAttempts do
                attempts = attempts + 1
                print(string.format("\n🚀 Running Quest %d (Attempt %d/%d)...", activeNum, attempts, maxAttempts))
                
                local success = loadQuest(activeNum)
                
                if success then
                    print("   ⏳ Waiting for quest to complete...")
                    
                    local timeout = 600
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
            print("   ⚠️ No active quest found!")
            
            if currentQuest == 1 then
                print("\n⚠️ RECOVERY: Loading Quest 1...")
                loadQuest(1)
                task.wait(5)
                currentQuest = 2
            else
                currentQuest = currentQuest + 1
            end
        end
        
        task.wait(2)
    end
    
    -- Quest 18 infinite loop
    if reachedQuest18 then
        print("\n" .. string.rep("=", 60))
        print("🌋 QUEST 18 - INFINITE FARMING MODE")
        print(string.rep("=", 60))
        
        local loopCount = 0
        
        while true do
            loopCount = loopCount + 1
            print(string.format("\n🔄 Quest 18 Loop #%d", loopCount))
            
            -- Run Quest 18
            local success = loadQuest(18)
            
            if success then
                -- Wait for Quest 18 to complete (if it completes)
                local timeout = 300  -- 5 minutes
                local startTime = tick()
                
                while not isQuestComplete(18) and (tick() - startTime) < timeout do
                    task.wait(5)
                end
            end
            
            -- Wait before loop again
            task.wait(5)
        end
    else
        print("\n" .. string.rep("=", 60))
        print("🎉 ALL QUESTS COMPLETED!")
        print(string.rep("=", 60))
    end
end

-----------------------------------------------------------------
--- 🚀 START
-----------------------------------------------------------------
--- Wait for UI to load
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

--- Start quest loop
runQuestLoop()