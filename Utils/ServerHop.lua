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

    -- [[ QUEUE ON TELEPORT: AUTO-REJOIN ISLAND ]]
    if queue_on_teleport then
        local queueScript = string.format([[
            local REJECT_ISLAND = "%s"
            
            print("🚀 [QUEUE] Script Loaded. Blocking: " .. REJECT_ISLAND)
            repeat task.wait() until game:IsLoaded()
            
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local KnitServices = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Packages"):WaitForChild("Knit"):WaitForChild("Services")
            local PortalRF = KnitServices:WaitForChild("PortalService"):WaitForChild("RF"):WaitForChild("TeleportToIsland")
            
            if not PortalRF then return end

            -- ⚠️ CRITIAL: DO NOT WAIT FOR GAME LOAD. RUN IMMEDIATELY.
            
            -- 🛡️ FINAL VERIFIED LOGIC: Global Block + Portal Blocker + REMOTE KILLER
            local function activate_hooks()
                local TeleportService = game:GetService("TeleportService")
                local StarterGui = game:GetService("StarterGui")
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                
                -- [ TRAP: DESTROY PORTAL REMOTE ]
                -- Path: ReplicatedStorage.Shared.Packages.Knit.Services.PortalService.RF.TeleportToIsland
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

                    -- Try immediately
                    pcall(destroyRemote)
                    
                    -- Try repeatedly for a few seconds (in case it loads late)
                    for i = 1, 20 do
                        pcall(destroyRemote)
                        task.wait(0.5)
                    end
                end)

                if not hookmetamethod then return end
                
                local oldhmmi
                local oldhmmnc
                
                local START_TIME = tick()
                local REPLICA_BLOCK_DURATION = 10 -- Block Replica for 10 seconds now

                -- [[ NETWORK CHOKE: LAG SWITCH ]]
                task.spawn(function()
                    if setfflag then
                        warn("📶 CHOKING NETWORK for 10s (FFlags)...")
                        -- Disable Data Sending (prevents server from confirming our location update?)
                        -- Actually, we want to prevent Server -> Client Teleport, so we might want to choke Incoming?
                        -- But FFlags controlling Incoming are rare.
                        -- Choking Outgoing might delay the "I am here" sync.
                        
                        -- Using user's suggested flags:
                        pcall(function() setfflag("DFIntDataSenderRate", "-1") end)
                        pcall(function() setfflag("DFIntS2PhysicsSenderRate", "-30") end) -- Invisible/No physics
                        
                        task.wait(10)
                        
                        warn("📶 RESTORING NETWORK...")
                        -- Restore reasonable defaults (Roblox defaults are dynamic, but these should work)
                        pcall(function() setfflag("DFIntDataSenderRate", "2000") end) 
                        pcall(function() setfflag("DFIntS2PhysicsSenderRate", "20") end)
                    else
                        warn("⚠️ setfflag not supported on this executor!")
                    end
                end)

                -- [ NEW: REPLICA DATA SPOOFING ]
                -- Intercepts incoming data and constantly lies to the client
                oldhmmi = hookmetamethod(game, "__index", newcclosure(function(self, index)
                    -- [A] BLOCK TELEPORT INDEXING
                    if self == TeleportService and type(index) == "string" then
                        -- Prevent accessing ANY TeleportService method
                        warn("⛔ BLOCKED TeleportService Index: " .. index)
                        return function() end -- Return empty function to prevent crash but do nothing
                    end

                    -- [B] DATA SPOOFING (OnClientEvent)
                    if not checkcaller() and typeof(self) == "Instance" and self:IsA("RemoteEvent") and index == "OnClientEvent" then
                        local name = self.Name
                        if string.find(name, "Replica") or string.find(name, "Portal") then
                            local signal = oldhmmi(self, index)
                            return {
                                Connect = function(_, callback)
                                    local hookedCallback = function(...)
                                        local args = {...}
                                        -- REWRITE DATA
                                        local function recursiveSpoof(t)
                                            if type(t) == "table" then
                                                for k, v in pairs(t) do
                                                    if type(v) == "table" then
                                                        recursiveSpoof(v)
                                                    elseif type(v) == "string" then
                                                        -- The Magic: Swap Island 1 -> Island 2
                                                        if string.find(v, "Stonewake") or string.find(v, "Island1") then
                                                            t[k] = "Forgotten Kingdom"
                                                            warn("🎭 SPOOFED Data: " .. v .. " -> Forgotten Kingdom")
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        
                                        pcall(function() 
                                            for i, v in ipairs(args) do recursiveSpoof(v) end 
                                        end)
                                        
                                        return callback(unpack(args))
                                    end
                                    return signal:Connect(hookedCallback)
                                end
                            }
                        end
                    end
                    
                    return oldhmmi(self, index)
                end))

                -- HOOK 2: __namecall (Function/Remote calls)
                oldhmmnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    local args = {...}

                    -- Note: accessing self.Name might crash on some Anti-Cheats, strict check first
                    local selfName = ""
                    pcall(function() selfName = self.Name end) 

                    -- [A] BLOCK TELEPORTSERVICE (Aggressive)
                    if self == TeleportService then
                         warn("⛔ BLOCKED TeleportService Namecall: " .. tostring(method))
                         return nil
                    end

                    -- [B] BLOCK PORTAL REMOTES
                    if type(method) == "string" and (method == "InvokeServer" or method == "FireServer") then
                        -- Check args for Island 1
                        for _, arg in pairs(args) do
                            if type(arg) == "string" then
                                local s = arg:lower()
                                if string.find(s, "stonewake") or string.find(s, "island1") then
                                    warn("🛡️ BLOCKED Portal Request: " .. tostring(arg))
                                    return nil
                                end
                            end
                        end
                        
                        -- Extra Specific Checks
                        if selfName == "TeleportToIsland" then return nil end
                        if selfName == "ClientLoaded" then return nil end
                        if selfName == "GetPlayerEquipmentInfo" then return nil end
                        if selfName == "CmdrFunction" then return nil end
                        
                        -- Note: We do NOT block ReplicaRequestData anymore. 
                        -- We let it flow, but we SPOOF the response in __index!
                    end
                    
                    return oldhmmnc(self, ...)
                end))
                    
                    return oldhmmnc(self, ...)
                end))
                
                -- Notification
                pcall(function()
                    StarterGui:SetCore('SendNotification', {Title = 'Security', Text = 'Anti-Teleport Active'})
                end)
                warn("✅ Anti-Teleport Active (Global + Portal Block + Remote Trap)")
            end
            
            activate_hooks() -- Run immediately
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
