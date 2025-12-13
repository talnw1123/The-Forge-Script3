--[[
    🚀 FPS BOOSTER SCRIPT
    📊 Reduces lag and improves game performance
    
    ⚠️ หมายเหตุ: บาง settings อาจทำให้กราฟิกดูแย่ลงแต่ FPS จะดีขึ้นมาก
--]]

----------------------------------------------------------------
-- ⚙️ SETTINGS (ปรับได้ตามต้องการ)
----------------------------------------------------------------
local Settings = {
    -- ====== GRAPHICS ======
    LowerQuality = true,           -- ลดคุณภาพกราฟิกรวม
    DisableShadows = true,         -- ปิดเงา
    DisableParticles = true,       -- ปิด Particles/Effects
    DisableDecals = true,          -- ปิด Decals
    DisableTextures = true,        -- ปิด Textures (ทำให้ดูแย่มาก)
    Disable3DRendering = true,     -- ปิด 3D Rendering (สุดขีด)
    BlackScreenMode = true,        -- เปิดหน้าจอดำ (ประหยัด GPU + CPU)
    
    -- ====== LIGHTING ======
    DisableGlobalShadows = true,   -- ปิด Global Shadows
    DisableBloom = true,           -- ปิด Bloom effect
    DisableBlur = true,            -- ปิด Blur/DepthOfField
    DisableSunRays = true,         -- ปิด Sun Rays
    DisableColorCorrection = true, -- ปิด Color Correction
    
    -- ====== TERRAIN ======
    LowerTerrainQuality = true,    -- ลดคุณภาพ Terrain
    DisableWater = true,           -- ปิด Water rendering
    
    -- ====== CHARACTER ======
    DisablePlayerNames = false,    -- ซ่อนชื่อ Player
    SimplifyCharacters = true,     -- ลด Character complexity
    DisableAccessories = true,     -- ซ่อน Accessories
    
    -- ====== MISC ======
    DisableSounds = false,         -- ปิดเสียง
    LimitFPS = false,              -- จำกัด FPS (ช่วยประหยัด CPU)
    TargetFPS = 60,                -- FPS เป้าหมาย (ถ้าเปิด LimitFPS)
    GarbageCollect = true,         -- ทำ Garbage Collection
    GCInterval = 60,               -- ทำ GC ทุกกี่วินาที
    
    -- ====== DESYNC ======
    EnableDesync = true,           -- เปิด Desync (คนอื่นเห็นคุณค้างอยู่ที่เดิม)
    DesyncAutoRespawn = true,      -- Auto respawn เพื่อ activate Desync
}

----------------------------------------------------------------
-- 📦 SERVICES
----------------------------------------------------------------
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Global reference for Black Screen toggle
local BlackScreenOverlay = nil
local BlackScreenEnabled = true

----------------------------------------------------------------
-- 🎨 GRAPHICS QUALITY
----------------------------------------------------------------
local function setGraphicsQuality()
    if not Settings.LowerQuality then return end
    
    print("🎨 Lowering Graphics Quality...")
    
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    
    pcall(function()
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.DistanceBased
    end)
end

----------------------------------------------------------------
-- 💡 LIGHTING EFFECTS
----------------------------------------------------------------
local function disableLightingEffects()
    print("💡 Disabling Lighting Effects...")
    
    if Settings.DisableGlobalShadows then
        pcall(function() Lighting.GlobalShadows = false end)
    end
    
    for _, effect in ipairs(Lighting:GetChildren()) do
        pcall(function()
            if effect:IsA("BloomEffect") and Settings.DisableBloom then
                effect.Enabled = false
            elseif effect:IsA("BlurEffect") and Settings.DisableBlur then
                effect.Enabled = false
            elseif effect:IsA("DepthOfFieldEffect") and Settings.DisableBlur then
                effect.Enabled = false
            elseif effect:IsA("SunRaysEffect") and Settings.DisableSunRays then
                effect.Enabled = false
            elseif effect:IsA("ColorCorrectionEffect") and Settings.DisableColorCorrection then
                effect.Enabled = false
            end
        end)
    end
    
    print("   ✅ Lighting effects disabled")
end

----------------------------------------------------------------
-- ✨ PARTICLES & EFFECTS
----------------------------------------------------------------
local function disableParticles()
    if not Settings.DisableParticles then return end
    
    print("✨ Disabling Particles...")
    
    local count = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if desc:IsA("ParticleEmitter") or 
               desc:IsA("Fire") or 
               desc:IsA("Smoke") or 
               desc:IsA("Sparkles") or
               desc:IsA("Trail") or
               desc:IsA("Beam") then
                desc.Enabled = false
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ Disabled %d particle effects", count))
end

----------------------------------------------------------------
-- 🖼️ DECALS & TEXTURES
----------------------------------------------------------------
local function disableDecalsAndTextures()
    print("🖼️ Processing Decals/Textures...")
    
    local decalCount, textureCount = 0, 0
    
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if Settings.DisableDecals and desc:IsA("Decal") then
                desc.Transparency = 1
                decalCount = decalCount + 1
            end
            
            if Settings.DisableTextures and desc:IsA("Texture") then
                desc.Transparency = 1
                textureCount = textureCount + 1
            end
        end)
    end
    
    if Settings.DisableDecals then
        print(string.format("   ✅ Hidden %d decals", decalCount))
    end
    if Settings.DisableTextures then
        print(string.format("   ✅ Hidden %d textures", textureCount))
    end
end

----------------------------------------------------------------
-- 🌊 TERRAIN
----------------------------------------------------------------
local function optimizeTerrain()
    if not Settings.LowerTerrainQuality then return end
    
    print("🌊 Optimizing Terrain...")
    
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        pcall(function()
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            terrain.Decoration = false
        end)
        
        if Settings.DisableWater then
            pcall(function()
                terrain.WaterColor = Color3.new(0, 0, 0)
                terrain.WaterTransparency = 1
            end)
        end
    end
    
    print("   ✅ Terrain optimized")
end

----------------------------------------------------------------
-- 🫥 SHADOWS
----------------------------------------------------------------
local function disableShadows()
    if not Settings.DisableShadows then return end
    
    print("🫥 Disabling Shadows...")
    
    local count = 0
    for _, desc in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if desc:IsA("BasePart") then
                desc.CastShadow = false
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ Disabled shadows on %d parts", count))
end

----------------------------------------------------------------
-- 👤 CHARACTER OPTIMIZATION
----------------------------------------------------------------
local function optimizeCharacters()
    print("👤 Optimizing Characters...")
    
    local function optimizeChar(char)
        if not char then return end
        
        for _, desc in ipairs(char:GetDescendants()) do
            pcall(function()
                if Settings.DisableAccessories and desc:IsA("Accessory") then
                    desc:Destroy()
                end
                
                if Settings.DisableParticles then
                    if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
                        desc.Enabled = false
                    end
                end
                
                if Settings.SimplifyCharacters and desc:IsA("BasePart") then
                    desc.CastShadow = false
                end
            end)
        end
    end
    
    if player.Character then
        optimizeChar(player.Character)
    end
    
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            optimizeChar(otherPlayer.Character)
        end
    end
    
    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function(char)
            task.wait(1)
            optimizeChar(char)
        end)
    end)
    
    print("   ✅ Characters optimized")
end

----------------------------------------------------------------
-- 🔊 SOUNDS
----------------------------------------------------------------
local function disableSounds()
    if not Settings.DisableSounds then return end
    
    print("🔊 Disabling Sounds...")
    
    local count = 0
    for _, desc in ipairs(game:GetDescendants()) do
        pcall(function()
            if desc:IsA("Sound") then
                desc.Volume = 0
                count = count + 1
            end
        end)
    end
    
    print(string.format("   ✅ Muted %d sounds", count))
end

----------------------------------------------------------------
-- 🗑️ GARBAGE COLLECTION
----------------------------------------------------------------
local function startGarbageCollection()
    if not Settings.GarbageCollect then return end
    
    print("🗑️ Starting Garbage Collection routine...")
    
    task.spawn(function()
        while true do
            task.wait(Settings.GCInterval)
            pcall(function()
                gcinfo()
                collectgarbage("collect")
            end)
        end
    end)
    
    print(string.format("   ✅ GC will run every %d seconds", Settings.GCInterval))
end

----------------------------------------------------------------
-- ⏱️ FPS LIMITER (ประหยัด CPU)
----------------------------------------------------------------
local function startFPSLimiter()
    if not Settings.LimitFPS then return end
    
    print("⏱️ Starting FPS Limiter...")
    
    local targetFrameTime = 1 / Settings.TargetFPS
    
    RunService.RenderStepped:Connect(function()
        local startTime = tick()
        while tick() - startTime < targetFrameTime do
            -- busy wait
        end
    end)
    
    print(string.format("   ✅ FPS limited to %d", Settings.TargetFPS))
end

----------------------------------------------------------------
-- 🖥️ 3D RENDERING & BLACK SCREEN (EXTREME)
----------------------------------------------------------------
local function enableBlackScreen()
    if not Settings.BlackScreenMode then return end
    
    print("🖤 Enabling Black Screen Mode...")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BlackScreenOverlay"
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 1000
    screenGui.ResetOnSpawn = false  -- ป้องกันไม่ให้ถูกลบเมื่อ Respawn
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(0, 0, 0)
    frame.BorderSizePixel = 0
    frame.ZIndex = 1000
    frame.Parent = screenGui
    
    local text = Instance.new("TextLabel")
    text.Text = "🌑 AFK MODE: SAVING RESOURCES 🌑"
    text.Size = UDim2.new(1, 0, 0, 50)
    text.Position = UDim2.new(0, 0, 0.4, -25)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Font = Enum.Font.RobotoMono
    text.TextSize = 24
    text.ZIndex = 1001
    text.Parent = frame
    
    -- ชื่อตัวละครตัวใหญ่
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text = player.Name or "Unknown"
    nameLabel.Size = UDim2.new(1, 0, 0, 80)
    nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 20
    nameLabel.ZIndex = 1001
    nameLabel.Parent = frame
    
    -- แสดง Gold
    local goldLabel = Instance.new("TextLabel")
    goldLabel.Text = "💰 Gold: Loading..."
    goldLabel.Size = UDim2.new(1, 0, 0, 60)
    goldLabel.Position = UDim2.new(0, 0, 0.6, 20)
    goldLabel.BackgroundTransparency = 1
    goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
    goldLabel.Font = Enum.Font.FredokaOne
    goldLabel.TextSize = 32
    goldLabel.ZIndex = 1001
    goldLabel.Parent = frame
    
    -- อัปเดต Gold ทุก 2 วินาที
    task.spawn(function()
        while screenGui and screenGui.Parent do
            local goldUI = player:FindFirstChild("PlayerGui")
                          and player.PlayerGui:FindFirstChild("Main")
                          and player.PlayerGui.Main:FindFirstChild("Screen")
                          and player.PlayerGui.Main.Screen:FindFirstChild("Hud")
                          and player.PlayerGui.Main.Screen.Hud:FindFirstChild("Gold")
            
            if goldUI and goldUI:IsA("TextLabel") then
                goldLabel.Text = "💰 " .. goldUI.Text
            else
                goldLabel.Text = "💰 Gold: --"
            end
            
            task.wait(2)
        end
    end)
    
    print("   ✅ Black Screen Overlay Active")
    print("   🎮 Press F2 to Toggle!")
    
    BlackScreenOverlay = screenGui
end

-- Toggle Black Screen Function (F2)
local function toggleBlackScreen()
    if not BlackScreenOverlay then
        print("⚠️ Black Screen not initialized!")
        return
    end
    
    BlackScreenEnabled = not BlackScreenEnabled
    BlackScreenOverlay.Enabled = BlackScreenEnabled
    
    if BlackScreenEnabled then
        print("🖤 Black Screen: ON")
    else
        print("🔆 Black Screen: OFF (UI visible)")
    end
end

-- Toggle 3D Rendering Function (F1)
local Rendering3DEnabled = false  -- เริ่มต้นปิด (เพราะ Settings.Disable3DRendering = true)
local function toggle3DRendering()
    Rendering3DEnabled = not Rendering3DEnabled
    
    pcall(function()
        RunService:Set3dRenderingEnabled(Rendering3DEnabled)
    end)
    
    if Rendering3DEnabled then
        print("🎮 3D Rendering: ON")
    else
        print("�️ 3D Rendering: OFF")
    end
end

-- Global functions for external access
_G.ToggleBlackScreen = toggleBlackScreen
_G.Toggle3DRendering = toggle3DRendering

-- Keybinds: F1 = 3D Rendering, F2 = Black Screen
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        toggle3DRendering()
    elseif input.KeyCode == Enum.KeyCode.F2 then
        toggleBlackScreen()
    end
end)

local function disable3DRendering()
    if not Settings.Disable3DRendering then return end
    
    print("🖥️ Disabling 3D Rendering (EXTREME)...")
    
    local s1, _ = pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
    
    if s1 then
        print("   ✅ Set3dRenderingEnabled(false) Success!")
    else
        print("   ⚠️ Set3dRenderingEnabled not supported, using Black Screen fallback...")
    end
end

----------------------------------------------------------------
-- 📊 FPS COUNTER
----------------------------------------------------------------
local function createFPSCounter()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FPSCounter"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 1001
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Name = "FPSLabel"
    fpsLabel.Size = UDim2.new(0, 100, 0, 30)
    fpsLabel.Position = UDim2.new(0, 10, 0, 10)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.BackgroundTransparency = 0.5
    fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    fpsLabel.Font = Enum.Font.Code
    fpsLabel.TextSize = 14
    fpsLabel.Text = "FPS: --"
    fpsLabel.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = fpsLabel
    
    local frameCount = 0
    local lastTime = tick()
    
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local currentTime = tick()
        
        if currentTime - lastTime >= 1 then
            local fps = math.floor(frameCount / (currentTime - lastTime))
            fpsLabel.Text = string.format("FPS: %d", fps)
            
            if fps >= 50 then
                fpsLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            elseif fps >= 30 then
                fpsLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            else
                fpsLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
            
            frameCount = 0
            lastTime = currentTime
        end
    end)
    
    print("📊 FPS Counter created!")
end

----------------------------------------------------------------
-- 🚀 RUN ALL OPTIMIZATIONS
----------------------------------------------------------------
local function runAllOptimizations()
    print("\n" .. string.rep("=", 50))
    print("🚀 FPS BOOSTER - Starting Optimizations")
    print(string.rep("=", 50) .. "\n")
    
    setGraphicsQuality()
    disableLightingEffects()
    disableParticles()
    disableDecalsAndTextures()
    disableShadows()
    optimizeTerrain()
    optimizeCharacters()
    disableSounds()
    startGarbageCollection()
    startFPSLimiter()
    enableBlackScreen()
    disable3DRendering()
    createFPSCounter()
    
    print("\n" .. string.rep("=", 50))
    print("✅ FPS BOOSTER - All Optimizations Applied!")
    print(string.rep("=", 50) .. "\n")
end

-- RUN
runAllOptimizations()

-- Re-apply when new objects are added
Workspace.DescendantAdded:Connect(function(desc)
    task.defer(function()
        pcall(function()
            if Settings.DisableParticles then
                if desc:IsA("ParticleEmitter") or desc:IsA("Fire") or desc:IsA("Smoke") then
                    desc.Enabled = false
                end
            end
            if Settings.DisableShadows and desc:IsA("BasePart") then
                desc.CastShadow = false
            end
        end)
    end)
end)
