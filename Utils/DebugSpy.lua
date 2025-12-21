-- [[ 🕵️ DEBUG SPY: REMOTE & DATA INSPECTOR ]]
-- Logs both OUTGOING (Client -> Server) and INCOMING (Server -> Client) traffic
-- Specifically targets ReplicaService data processing

local function activate_spy()
    if not hookmetamethod then 
        warn("❌ hookmetamethod not supported!")
        return 
    end

    local oldhmmi
    local oldhmmnc
    
    print("\n==================================")
    print("🕵️ REMOTE SPY STARTED - WATCHING REPLICA DATA...")
    print("==================================\n")

    -- HELPER: Table to String (Recursive with limit)
    local function dumpParams(t, depth)
        if not depth then depth = 1 end
        if depth > 3 then return "{...}" end
        
        if type(t) == "table" then
            local s = "{"
            local count = 0
            for k, v in pairs(t) do
                count = count + 1
                if count > 10 then s = s .. ", ..."; break end -- Limit keys
                
                local key = tostring(k)
                local value = tostring(v)
                
                if type(v) == "table" then value = dumpParams(v, depth + 1) end
                
                -- Highlight suspicious keys
                if string.find(string.lower(key), "island") or string.find(string.lower(key), "location") then
                    key = "🚨" .. key .. "🚨"
                end
                if string.find(string.lower(value), "island") or string.find(string.lower(value), "stonewake") then
                    value = "🚨" .. value .. "🚨"
                end
                
                s = s .. "[" .. key .. "] = " .. value .. ", "
            end
            return s .. "}"
        else
            return tostring(t)
        end
    end

    -- [[ HOOK 1: INCOMING DATA (OnClientEvent) ]]
    -- We hook '__index' to trap when the game script tries to Connect to OnClientEvent
    oldhmmi = hookmetamethod(game, "__index", newcclosure(function(self, index)
        -- Check if accessing "OnClientEvent" of a RemoteEvent
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("RemoteEvent") and index == "OnClientEvent" then
            
            -- Filter for Replica/Portal Remotes
            local name = self.Name
            if string.find(name, "Replica") or string.find(name, "Portal") then
                -- Return a Fake Signal helper
                local signal = oldhmmi(self, index)
                
                return {
                    Connect = function(_, callback)
                        -- Intercept the callback!
                        local hookedCallback = function(...)
                            local args = {...}
                            print(string.format("📥 [INCOMING] %s | Data: %s", name, dumpParams(args)))
                            return callback(...)
                        end
                        return signal:Connect(hookedCallback)
                    end,
                    connect = function(_, callback) -- Lowercase support
                        local hookedCallback = function(...)
                            local args = {...}
                            print(string.format("📥 [INCOMING] %s | Data: %s", name, dumpParams(args)))
                            return callback(...)
                        end
                        return signal:Connect(hookedCallback)
                    end
                }
            end
        end
        return oldhmmi(self, index)
    end))

    -- [[ HOOK 2: OUTGOING CALLS (FireServer/InvokeServer) ]]
    oldhmmnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if type(method) == "string" and (method == "InvokeServer" or method == "FireServer") then
            local selfName = self.Name
            
            -- Log everything for now to find the trigger
            if string.find(selfName, "Replica") or string.find(selfName, "Portal") or string.find(selfName, "Teleport") or string.find(selfName, "Cmdr") or string.find(selfName, "Equipment") then
                 print(string.format("📤 [OUTGOING] %s | Args: %s", selfName, dumpParams(args)))
            end
        end

        return oldhmmnc(self, ...)
    end))
    
    warn("✅ Spy Active! Check Console (F9) for 'INCOMING' Replica data.")
end

activate_spy()
