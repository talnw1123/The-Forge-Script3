-- Standalone Client Anti-TP Test Script
-- Based on User's provided logic + Crash Fixes

local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

if not hookmetamethod then
    warn("Incompatible Exploit: missing hookmetamethod")
    return
end

local oldhmmi
local oldhmmnc

warn("🔄 Activating Client Anti-TP...")

-- HOOK 1: __index
oldhmmi = hookmetamethod(game, "__index", newcclosure(function(self, method)
    if self == TeleportService then
        -- SAFETY CHECK: Ensure method is a string before calling :lower()
        -- This prevents the "argument #1 expects a string" crash
        if type(method) == "string" then
            if method:lower() == "teleport" then
                return error("Expected ':' not '.' calling member function Teleport", 2)
            elseif method == "TeleportToPlaceInstance" then
                return error("Expected ':' not '.' calling member function TeleportToPlaceInstance", 2)
            end
        end
    end
    return oldhmmi(self, method)
end))

-- HOOK 2: __namecall (Function/Remote calls)
oldhmmnc = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if not checkcaller() then
        -- [A] BLOCK TELEPORTSERVICE (Client-Sided TPs)
        if self == TeleportService then
            if type(method) == "string" then
                local low = method:lower()
                if low == "teleport" or low == "teleporttoplaceinstance" then
                    warn("⛔ BLOCKED Client Teleport: " .. method)
                    return nil
                end
            end
        end

        -- [B] BLOCK PORTAL REMOTES (Server-Sided TPs triggered by Client)
        -- Quest18 uses: PortalService.RF.TeleportToIsland:InvokeServer(islandName)
        if type(method) == "string" and (method == "InvokeServer" or method == "FireServer") then
            -- Specific Check: Block "TeleportToIsland" Remote
            if self.Name == "TeleportToIsland" then
                -- Check args for Island 1
                for _, arg in pairs(args) do
                    if type(arg) == "string" then
                        local s = arg:lower()
                        if string.find(s, "stonewake") or string.find(s, "island1") then
                            warn("🛡️ BLOCKED Portal Request: " .. tostring(arg))
                            return nil -- Block the request to the server!
                        end
                    end
                end
            end
            
            -- General arg check (Backup)
            for _, arg in pairs(args) do
                if type(arg) == "string" then
                    local s = arg:lower()
                    if string.find(s, "stonewake") or string.find(s, "island1") then
                        warn("🛡️ BLOCKED General Remote: " .. tostring(arg))
                        return nil
                    end
                end
            end
        end
    end
    
    return oldhmmnc(self, ...)
end))

-- Notification
pcall(function()
    StarterGui:SetCore('SendNotification', {Title = 'Client AntiTP', Text = 'Global Block Active'})
end)

warn("✅ Client Anti-TP Active! (Global Block)")
