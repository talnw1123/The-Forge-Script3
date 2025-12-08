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
    DisableTextures = false,       -- ปิด Textures (ทำให้ดูแย่มาก)
    Disable3DRendering = false,    -- ปิด 3D Rendering (สุดขีด)
    
    -- ====== LIGHTING ======
    DisableGlobalShadows = true,   -- ปิด Global Shadows
    DisableBloom = true,           -- ปิด Bloom effect
    DisableBlur = true,            -- ปิด Blur/DepthOfField
    DisableSunRays = true,         -- ปิด Sun Rays
    DisableColorCorrection = true, -- ปิด Color Correction
    
    -- ====== TERRAIN ======
    LowerTerrainQuality = true,    -- ลดคุณภาพ Terrain
    DisableWater = true,          -- ปิด Water rendering
    
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
}

----------------------------------------------------------------
-- 📦 SERVICES
----------------------------------------------------------------
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- 🎨 GRAPHICS QUALITY
----------------------------------------------------------------
local function setGraphicsQuality()
    if not Settings.LowerQuality then return end
    
    print("🎨 Lowering Graphics Quality...")
    
    -- ลด Quality Level ใน Settings
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    
    -- ลด MeshPartDetail
    pcall(function()
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.DistanceBased
    end)
end

----------------------------------------------------------------
-- 💡 LIGHTING EFFECTS
----------------------------------------------------------------
local function disableLightingEffects()
    print("💡 Disabling Lighting Effects...")
    
    -- Global Shadows
    if Settings.DisableGlobalShadows then
        pcall(function() Lighting.GlobalShadows = false end)
    end
    
    -- ปิด Post-Processing Effects
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
                -- ซ่อน Accessories
                if Settings.DisableAccessories and desc:IsA("Accessory") then
                    desc:Destroy()
                end
                
                -- ปิด Particles บน Character
                if Settings.DisableParticles then
                    if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
                        desc.Enabled = false
                    end
                end
                
                -- Simplify by disabling shadows
                if Settings.SimplifyCharacters and desc:IsA("BasePart") then
                    desc.CastShadow = false
                end
            end)
        end
    end
    
    -- Optimize local player
    if player.Character then
        optimizeChar(player.Character)
    end
    
    -- Optimize other players
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            optimizeChar(otherPlayer.Character)
        end
    end
    
    -- Connect for new characters
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
                -- เคลียร์ memory
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
-- 🖥️ 3D RENDERING (EXTREME)
----------------------------------------------------------------
local function disable3DRendering()
    if not Settings.Disable3DRendering then return end
    
    print("🖥️ Disabling 3D Rendering (EXTREME)...")
    
    pcall(function()
        RunService:Set3dRenderingEnabled(false)
    end)
    
    print("   ⚠️ 3D Rendering disabled!")
end

----------------------------------------------------------------
-- 📊 FPS COUNTER
----------------------------------------------------------------
local function createFPSCounter()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "FPSCounter"
    screenGui.ResetOnSpawn = false
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
            
            -- เปลี่ยนสีตาม FPS
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
