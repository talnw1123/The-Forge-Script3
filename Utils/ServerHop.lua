--[[
    🚀 SMART SERVER HOP
    📊 หา Server ที่มีคนน้อยๆ อัตโนมัติ
    
    📌 วิธีใช้:
    1. รัน script นี้
    2. script จะหา server ที่มีคน 1-5 คน แล้ว hop ไปอัตโนมัติ
    
    ⚙️ ปรับ MIN_PLAYERS / MAX_PLAYERS ตามต้องการ
--]]

----------------------------------------------------------------
-- ⚙️ CONFIG
----------------------------------------------------------------
local CONFIG = {
    MIN_PLAYERS = 1,        -- จำนวนคนขั้นต่ำ
    MAX_PLAYERS = 5,        -- จำนวนคนสูงสุด
    EXCLUDE_SELF = true,    -- ไม่ hop ไป server เดิม
    TARGET_PLACE_ID = 129009554587176, -- Place ID เป้าหมาย
    REJECT_ISLAND = "Stonewake's Cross" -- ชื่อเกาะที่ต้องการบล็อก (Island1)
}

----------------------------------------------------------------
-- 📦 SERVICES
----------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local CurrentPlaceId = game.PlaceId
local TargetPlaceId = CONFIG.TARGET_PLACE_ID -- ใช้ Place ID ที่กำหนด
local JobId = game.JobId
local Player = Players.LocalPlayer

----------------------------------------------------------------
-- 🔍 GET SERVERS
----------------------------------------------------------------
local function getServers()
    local servers = {}
    local cursor = ""
    local attempts = 0
    local maxAttempts = 10
    
    print(string.format("🌍 Fetching servers for Place ID: %d", TargetPlaceId))

    while attempts < maxAttempts do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            TargetPlaceId,
            cursor ~= "" and ("&cursor=" .. cursor) or ""
        )
        
        local success, response = pcall(function()
            return game:HttpGet(url)
        end)
        
        if not success then
            warn("⚠️ Failed to fetch servers: " .. tostring(response))
            break
        end
        
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in ipairs(data.data) do
                table.insert(servers, server)
            end
        end
        
        -- Check for next page
        if data and data.nextPageCursor and data.nextPageCursor ~= "" then
            cursor = data.nextPageCursor
            attempts = attempts + 1
        else
            break
        end
    end
    
    print(string.format("📊 Found %d total servers", #servers))
    return servers
end

----------------------------------------------------------------
-- 🎯 FIND LOW PLAYER SERVER
----------------------------------------------------------------
local function findBestServer(servers)
    local eligibleServers = {}
    
    for _, server in ipairs(servers) do
        local playerCount = server.playing or 0
        local maxPlayers = server.maxPlayers or 12
        local serverId = server.id
        
        -- Skip current server
        if CONFIG.EXCLUDE_SELF and serverId == JobId then
            continue
        end
        
        -- Skip full servers
        if playerCount >= maxPlayers then
            continue
        end
        
        -- Check player count range
        if playerCount >= CONFIG.MIN_PLAYERS and playerCount <= CONFIG.MAX_PLAYERS then
            table.insert(eligibleServers, {
                id = serverId,
                players = playerCount,
                maxPlayers = maxPlayers,
            })
        end
    end
    
    -- Sort by player count (lowest first)
    table.sort(eligibleServers, function(a, b)
        return a.players < b.players
    end)
    
    print(string.format("🎯 Found %d eligible servers (players: %d-%d)", 
        #eligibleServers, CONFIG.MIN_PLAYERS, CONFIG.MAX_PLAYERS))
    
    return eligibleServers[1] -- Return server with fewest players
end

----------------------------------------------------------------
-- 🌀 TELEPORT TO SERVER
----------------------------------------------------------------
local function teleportToServer(server)
    if not server then
        warn("❌ No suitable server found!")
        return false
    end
    
    print(string.format("🌀 Teleporting to server: %s (Players: %d/%d)", 
        server.id, server.players, server.maxPlayers))

    -- [[ SPOOF: FAKE PORTAL REQUEST ]]
    -- Trick server into thinking we used the portal, so it updates our Last Location to "Forgotten Kingdom"
    task.spawn(function()
        pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local services = ReplicatedStorage:FindFirstChild("Shared") 
                and ReplicatedStorage.Shared:FindFirstChild("Packages")
                and ReplicatedStorage.Shared.Packages:FindFirstChild("Knit")
                and ReplicatedStorage.Shared.Packages.Knit:FindFirstChild("Services")
            
            if services then
                local portal = services:FindFirstChild("PortalService")
                if portal then
                    local rf = portal:FindFirstChild("RF")
                    if rf then
                        local tpRemote = rf:FindFirstChild("TeleportToIsland")
                        if tpRemote then
                            print("🎭 [SPOOF] Sending Fake Portal Request: Forgotten Kingdom...")
                            tpRemote:InvokeServer("Forgotten Kingdom")
                            print("✅ [SPOOF] Request Sent!")
                        end
                    end
                end
            end
        end)
    end)
    
    print("⏳ Waiting 1s for server state update...")
    task.wait(1)

    -- [[ QUEUE ON TELEPORT: SIMPLIFIED ANTI-TELEPORT ]]
    if queue_on_teleport then
        local queueScript = string.format([[
            local REJECT_ISLAND = "%s"
            
            print("🚀 [QUEUE] Script Loaded. Blocking: " .. REJECT_ISLAND)
            
            -- DON'T wait for game to load - run hooks IMMEDIATELY
            
            local TeleportService = game:GetService("TeleportService")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local StarterGui = game:GetService("StarterGui")
            
            -- Get Island 1 PlaceID for blocking
            local ISLAND1_PLACEID = 76558904092080 -- Stonewake's Cross PlaceID
            local CURRENT_PLACEID = game.PlaceId
            
            -- [[ HAZE LOADER TELEPORT STOPPER (Exact copy) ]
            -- Create UI showing "Stopping Teleport..."
            local ui = Instance.new("ScreenGui")
            ui.Name = "TeleportStopper"
            ui.ResetOnSpawn = false
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 300, 0, 100)
            frame.Position = UDim2.new(0.5, -150, 0.5, -50)
            frame.BackgroundColor3 = Color3.new(0, 0, 0)
            frame.BackgroundTransparency = 0.5
            frame.Parent = ui
            local text = Instance.new("TextLabel")
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.TextColor3 = Color3.new(1, 1, 1)
            text.Text = "Stopping Teleport..."
            text.Parent = frame
            ui.Parent = gethui and gethui() or game:GetService("Players").PlayerGui
            task.spawn(function()
                task.wait(5)
                pcall(function() ui:Destroy() end)
            end)
            
            -- [[ THE KEY TRICK: Break teleport by setting invalid TeleportGui ]
            local stoppedTp = false
            while not stoppedTp do
                local tpService = cloneref and cloneref(game:GetService("TeleportService")) or TeleportService
                
                -- Set TeleportGui to TeleportService itself (INVALID! Causes error)
                pcall(function()
                    tpService:SetTeleportGui(tpService)
                end)
                
                -- Check LogService for "cannot be cloned" error (means teleport is broken)
                local logService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")
                pcall(function()
                    for i, v in logService:GetLogHistory() do
                        if v.message:find("cannot be cloned") then
                            stoppedTp = true
                            warn("✅ Teleport STOPPED! (Detected 'cannot be cloned' error)")
                            break
                        end
                    end
                end)
                
                task.wait()
                pcall(function() tpService:TeleportCancel() end)
                pcall(function() tpService:SetTeleportGui(nil) end)
            end
            pcall(function() ui:Destroy() end)
            warn("🎉 Haze Loader Teleport Stopper completed!")
            
            -- NOTE: Character Lock removed as per user request
            
            -- [ TRAP: DESTROY PORTAL REMOTE ]
            task.spawn(function()
                local function destroyRemote()
                    local services = ReplicatedStorage:FindFirstChild("Shared") 
                        and ReplicatedStorage.Shared:FindFirstChild("Packages")
                        and ReplicatedStorage.Shared.Packages:FindFirstChild("Knit")
                        and ReplicatedStorage.Shared.Packages.Knit:FindFirstChild("Services")
                    
                    if services then
                        local portal = services:FindFirstChild("PortalService")
                        if portal then
                            local rf = portal:FindFirstChild("RF")
                            if rf then
                                local tpRemote = rf:FindFirstChild("TeleportToIsland")
                                if tpRemote then
                                    tpRemote:Destroy()
                                    warn("💣 TRAPPED: Destroyed TeleportToIsland Remote!")
                                end
                            end
                        end
                    end
                end

                -- Keep trying for 10 seconds
                for i = 1, 20 do
                    pcall(destroyRemote)
                    task.wait(0.5)
                end
            end)
            
            -- NOTE: Network Choke removed as per user request

            if not hookmetamethod then 
                warn("⚠️ hookmetamethod not supported!")
                return 
            end
            
            local oldhmmnc
            
            -- NOTE: Removed __index hook - it was breaking game data loading
            -- Keeping only __namecall hook for blocking teleport calls
            
            -- Flag to control blocking (will be disabled after 10 seconds)
            local blockingEnabled = true
            
            -- Disable blocking after 10 seconds
            task.spawn(function()
                task.wait(10)
                blockingEnabled = false
                warn("🔓 TeleportService blocking DISABLED after 10 seconds. Normal teleport now allowed!")
            end)
            
            -- AGGRESSIVE HOOK: Block ALL TeleportService calls (while blockingEnabled)
            oldhmmnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                local selfName = ""
                pcall(function() selfName = self.Name end)

                -- [A] BLOCK ALL TELEPORTSERVICE METHODS (only while blocking is enabled)
                if blockingEnabled and self == TeleportService then
                    -- Block everything except TeleportCancel (we need that)
                    if method ~= "TeleportCancel" then
                        warn("⛔ BLOCKED TeleportService." .. tostring(method))
                        return nil
                    end
                end

                -- [B] BLOCK PORTAL REMOTES mentioning Stonewake
                if type(method) == "string" and (method == "InvokeServer" or method == "FireServer") then
                    for _, arg in pairs(args) do
                        if type(arg) == "string" then
                            local s = arg:lower()
                            if string.find(s, "stonewake") or string.find(s, "island1") then
                                warn("🛡️ BLOCKED Portal Request: " .. tostring(arg))
                                return nil
                            end
                        end
                    end
                    
                    -- Block TeleportToIsland remote specifically
                    if selfName == "TeleportToIsland" then 
                        -- Check if any arg mentions Stonewake
                        for _, arg in pairs(args) do
                            if type(arg) == "string" and string.find(arg:lower(), "stonewake") then
                                warn("🛡️ BLOCKED TeleportToIsland to Stonewake")
                                return nil
                            end
                        end
                    end
                end
                
                return oldhmmnc(self, ...)
            end))
            
            -- Notification
            pcall(function()
                StarterGui:SetCore('SendNotification', {Title = 'Security', Text = 'Anti-Teleport Active + Cancel Loop'})
            end)
            warn("✅ Anti-Teleport Active (Aggressive Mode + TeleportCancel Loop)")
        ]], CONFIG.REJECT_ISLAND)
        
        queue_on_teleport(queueScript)
        print("✅ Queued teleport script! (Anti-Island1 Active)")
    else
        warn("⚠️ 'queue_on_teleport' not supported on this executor! Auto-Teleport will not work.")
    end
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(TargetPlaceId, server.id, Player)
    end)
    
    if not success then
        warn("❌ Teleport failed: " .. tostring(err))
        return false
    end
    
    return true
end

----------------------------------------------------------------
-- 🚀 MAIN
----------------------------------------------------------------
local function main()
    print("\n" .. string.rep("=", 50))
    print("🚀 SMART SERVER HOP")
    print(string.format("🎯 Looking for server with %d-%d players...", 
        CONFIG.MIN_PLAYERS, CONFIG.MAX_PLAYERS))
    print(string.rep("=", 50))
    
    -- Get all servers
    local servers = getServers()
    
    if #servers == 0 then
        warn("❌ No servers found!")
        return
    end
    
    -- Find best server
    local bestServer = findBestServer(servers)
    
    if not bestServer then
        warn(string.format("❌ No server found with %d-%d players!", 
            CONFIG.MIN_PLAYERS, CONFIG.MAX_PLAYERS))
        
        -- Fallback: find any server with < MAX_PLAYERS
        print("🔄 Trying fallback: any server with less than " .. CONFIG.MAX_PLAYERS .. " players...")
        
        local fallbackServers = {}
        for _, server in ipairs(servers) do
            local playerCount = server.playing or 0
            if playerCount < CONFIG.MAX_PLAYERS and server.id ~= JobId then
                table.insert(fallbackServers, {
                    id = server.id,
                    players = playerCount,
                    maxPlayers = server.maxPlayers or 12,
                })
            end
        end
        
        -- Sort fallback candidates by player count
        table.sort(fallbackServers, function(a, b)
            return a.players < b.players
        end)
        
        if #fallbackServers > 0 then
            bestServer = fallbackServers[1]
            print(string.format("   ✨ Fallback chosen: %s (Players: %d)", bestServer.id, bestServer.players))
        end
    end
    
    -- Teleport
    teleportToServer(bestServer)
end

-- RUN
main()
