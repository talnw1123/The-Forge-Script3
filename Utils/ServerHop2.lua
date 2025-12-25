--[[
    🚀 SERVER HOP 2 (Background Test Version)
    📊 ทดสอบระบบ Background Server Hop เหมือน Loader.lua
    
    📌 วิธีใช้: รัน script นี้บน Island2
    📌 จะเช็ค player count ทุก 10 วินาที
    📌 ถ้า > MAX_PLAYERS จะ hop ไป low-player server
--]]

----------------------------------------------------------------
-- ⚙️ CONFIG
----------------------------------------------------------------
local CONFIG = {
    MAX_PLAYERS = 4,                    -- Server hop if players > 4
    ISLAND2_PLACE_ID = 129009554587176, -- Forgotten Kingdom PlaceID
    MAX_PLAYERS_PREFERRED = 3,          -- Prefer servers with <= 3 players
    CHECK_INTERVAL = 10,                -- Check every 10 seconds
    RANDOM_DELAY_MAX = 15,              -- Max random delay (0-15 seconds)
}

----------------------------------------------------------------
-- 📦 SERVICES
----------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

----------------------------------------------------------------
-- 🌐 IMPROVED SERVER FINDER (Reserved Server Filter)
----------------------------------------------------------------
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
-- 🛡️ QUEUE ANTI-TELEPORT (for next server)
----------------------------------------------------------------
if queue_on_teleport then
    local queueScript = [[
        -- [[ THE KEY TRICK: Break teleport by setting invalid TeleportGui ]]
        print("🛡️ [V35] Haze Loader Anti-Teleport Starting...")
        
        local stoppedTp = false
        while not stoppedTp do
            local tpService = cloneref and cloneref(game:GetService("TeleportService")) or game:GetService("TeleportService")
            pcall(function() tpService:SetTeleportGui(tpService) end)
            
            local logService = cloneref and cloneref(game:GetService("LogService")) or game:GetService("LogService")
            pcall(function()
                for i, v in logService:GetLogHistory() do
                    if v.message:find("cannot be cloned") then
                        stoppedTp = true
                        warn("✅ [V35] Teleport STOPPED!")
                        break
                    end
                end
            end)
            
            task.wait()
            pcall(function() tpService:TeleportCancel() end)
            pcall(function() tpService:SetTeleportGui(nil) end)
        end
        warn("🎉 [V35] Anti-teleport completed!")
    ]]
    
    queue_on_teleport(queueScript)
    print("📜 Queued anti-teleport script for next server")
else
    warn("⚠️ queue_on_teleport not available!")
end

----------------------------------------------------------------
-- 🔄 BACKGROUND PLAYER COUNT MONITORING
----------------------------------------------------------------
print("\n" .. string.rep("=", 60))
print("🚀 SERVER HOP 2 - BACKGROUND TEST")
print(string.rep("=", 60))

local playerCount = #Players:GetPlayers()
print(string.format("\n👥 Current Player Count: %d (Max: %d)", playerCount, CONFIG.MAX_PLAYERS))

-- Initial check
if playerCount > CONFIG.MAX_PLAYERS then
    print("\n🌐 TOO MANY PLAYERS! Starting Server Hop...")
    
    local bestServer = getBestServer(CONFIG.ISLAND2_PLACE_ID, CONFIG.MAX_PLAYERS_PREFERRED)
    
    if bestServer then
        print(string.format("   ✅ Found: %d/%d players", bestServer.playing, bestServer.maxPlayers))
        
        local randomDelay = math.random(0, CONFIG.RANDOM_DELAY_MAX)
        print(string.format("   ⏳ Waiting %d seconds...", randomDelay))
        task.wait(randomDelay)
        
        print("   🚀 Teleporting...")
        
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(CONFIG.ISLAND2_PLACE_ID, bestServer.id)
        end)
        
        if success then
            print("   ✅ Teleport initiated!")
        else
            warn("   ❌ Teleport error: " .. tostring(err))
        end
    end
else
    print("   ✅ Player count OK! No server hop needed.")
end

-- Background monitoring loop
print("\n🔄 Starting Background Monitoring (every " .. CONFIG.CHECK_INTERVAL .. "s)...")

task.spawn(function()
    while true do
        task.wait(CONFIG.CHECK_INTERVAL)
        
        local currentPlayers = #Players:GetPlayers()
        
        if currentPlayers > CONFIG.MAX_PLAYERS then
            print(string.format("\n👥 [AUTO-HOP] %d > %d, hopping...", currentPlayers, CONFIG.MAX_PLAYERS))
            
            local bestServer = getBestServer(CONFIG.ISLAND2_PLACE_ID, CONFIG.MAX_PLAYERS_PREFERRED)
            
            if bestServer then
                print(string.format("   ✅ Found: %d/%d players", bestServer.playing, bestServer.maxPlayers))
                
                -- 🎲 Random delay to avoid rate limit
                local randomDelay = math.random(0, CONFIG.RANDOM_DELAY_MAX)
                print(string.format("   ⏳ Waiting %d seconds...", randomDelay))
                task.wait(randomDelay)
                
                print("   🚀 Teleporting...")
                
                local success, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(CONFIG.ISLAND2_PLACE_ID, bestServer.id)
                end)
                
                if success then
                    print("   ✅ Teleport initiated!")
                    while true do task.wait(1) end
                else
                    warn("   ❌ Teleport error: " .. tostring(err))
                end
            end
        else
            print(string.format("👥 [CHECK] %d <= %d, OK", currentPlayers, CONFIG.MAX_PLAYERS))
        end
    end
end)

print("✅ Background monitoring started!")
