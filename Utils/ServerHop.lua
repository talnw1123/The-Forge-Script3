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
    MIN_PLAYERS = 1,     -- จำนวนคนขั้นต่ำ
    MAX_PLAYERS = 5,     -- จำนวนคนสูงสุด
    EXCLUDE_SELF = true, -- ไม่ hop ไป server เดิม
}

----------------------------------------------------------------
-- 📦 SERVICES
----------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

local PlaceId = game.PlaceId
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
    
    while attempts < maxAttempts do
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PlaceId,
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
    
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceId, server.id, Player)
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
        
        for _, server in ipairs(servers) do
            local playerCount = server.playing or 0
            if playerCount < CONFIG.MAX_PLAYERS and server.id ~= JobId then
                bestServer = {
                    id = server.id,
                    players = playerCount,
                    maxPlayers = server.maxPlayers or 12,
                }
                break
            end
        end
    end
    
    -- Teleport
    teleportToServer(bestServer)
end

-- RUN
main()
