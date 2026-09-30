-- ================================================
-- SHADER.LUA — Visual Effects Panel (nama bisa diganti sendiri)
-- Tiap toggle benar-benar memodifikasi Lighting service Roblox,
-- efeknya nyata dan reversible (bisa dimatikan lagi kapan saja).
--
-- FIX: Atmosphere TIDAK PUNYA properti .Enabled (beda dari BloomEffect/
-- ColorCorrectionEffect/SunRaysEffect yang punya). Atmosphere cuma
-- dikendalikan lewat nilai property-nya sendiri (Density, Haze, dll).
-- "Mematikan" Atmosphere = set Density & Haze ke 0, BUKAN set .Enabled.
-- ================================================

local Services    = _G.Services
local LocalPlayer = _G.LocalPlayer
local Lighting    = game:GetService("Lighting")
local Helpers     = _G.Helpers or {}
local appContent  = _G.appContent
local Storage     = _G.Storage or {}

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local tween   = Helpers.tween or function(o, p, t)
    game:GetService("TweenService"):Create(o, TweenInfo.new(t or 0.2), p):Play()
end

local C = {
    bg      = Color3.fromRGB(12, 10, 20),
    card    = Color3.fromRGB(20, 18, 32),
    border  = Color3.fromRGB(60, 55, 100),
    text    = Color3.fromRGB(240, 238, 250),
    text2   = Color3.fromRGB(165, 158, 190),
    accent  = Color3.fromRGB(120, 140, 255),
}

-- ==================== DEFINISI EFEK ====================
local originalLighting = {
    Brightness = Lighting.Brightness,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    ColorShift_Top = Lighting.ColorShift_Top,
    ExposureCompensation = Lighting.ExposureCompensation,
    FogColor = Lighting.FogColor,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    ClockTime = Lighting.ClockTime,
}

local function resetLightingToDefault()
    for prop, val in pairs(originalLighting) do
        pcall(function() Lighting[prop] = val end)
    end
end

local function getOrCreate(className, name)
    local existing = Lighting:FindFirstChild(name)
    if existing then return existing end
    local inst = Instance.new(className)
    inst.Name = name
    inst.Parent = Lighting
    return inst
end

local bloomEffect      = getOrCreate("BloomEffect", "ShaderBloom")
local colorCorrection  = getOrCreate("ColorCorrectionEffect", "ShaderColorCorrection")
local atmosphereEffect = getOrCreate("Atmosphere", "ShaderAtmosphere")
local sunRaysEffect    = getOrCreate("SunRaysEffect", "ShaderSunRays")

-- Hanya set .Enabled untuk instance yang MEMANG PUNYA property itu.
bloomEffect.Enabled = false
colorCorrection.Enabled = false
sunRaysEffect.Enabled = false

-- Atmosphere di-nol-kan lewat nilainya sendiri, bukan .Enabled.
atmosphereEffect.Density = 0
atmosphereEffect.Offset = 0
atmosphereEffect.Color = Color3.fromRGB(255,255,255)
atmosphereEffect.Decay = Color3.fromRGB(255,255,255)
atmosphereEffect.Glare = 0
atmosphereEffect.Haze = 0

-- Helper: "matikan" Atmosphere dengan aman (dipakai di banyak tempat)
local function disableAtmosphere()
    atmosphereEffect.Density = 0
    atmosphereEffect.Glare = 0
    atmosphereEffect.Haze = 0
end

local EFFECTS = {
    {
        id = "rtx",
        label = "RTX Shader",
        color = Color3.fromRGB(90, 150, 255),
        apply = function()
            bloomEffect.Enabled = true
            bloomEffect.Intensity = 1.4
            bloomEffect.Size = 24
            bloomEffect.Threshold = 0.9

            colorCorrection.Enabled = true
            colorCorrection.Contrast = 0.15
            colorCorrection.Saturation = 0.1
            colorCorrection.TintColor = Color3.fromRGB(255, 250, 245)

            atmosphereEffect.Density = 0.25
            atmosphereEffect.Glare = 0.3
            atmosphereEffect.Haze = 1.2

            Lighting.ExposureCompensation = 0.2
        end,
    },
    {
        id = "fullfps",
        label = "Shader Full Max FPS",
        color = Color3.fromRGB(110, 230, 150),
        apply = function()
            bloomEffect.Enabled = false
            colorCorrection.Enabled = false
            sunRaysEffect.Enabled = false
            disableAtmosphere()
            Lighting.GlobalShadows = false
            Lighting.ExposureCompensation = 0
        end,
    },
    {
        id = "realistic",
        label = "Realistic Shader",
        color = Color3.fromRGB(255, 180, 90),
        apply = function()
            bloomEffect.Enabled = true
            bloomEffect.Intensity = 0.6
            bloomEffect.Size = 12
            bloomEffect.Threshold = 1.2

            colorCorrection.Enabled = true
            colorCorrection.Contrast = 0.08
            colorCorrection.Saturation = -0.05
            colorCorrection.TintColor = Color3.fromRGB(250, 248, 245)

            atmosphereEffect.Density = 0.15
            atmosphereEffect.Haze = 0.8

            Lighting.GlobalShadows = true
        end,
    },
    {
        id = "ultra",
        label = "Ultra Graphics",
        color = Color3.fromRGB(180, 130, 255),
        apply = function()
            bloomEffect.Enabled = true
            bloomEffect.Intensity = 1.8
            bloomEffect.Size = 32
            bloomEffect.Threshold = 0.7

            colorCorrection.Enabled = true
            colorCorrection.Contrast = 0.2
            colorCorrection.Saturation = 0.25
            colorCorrection.Brightness = 0.05

            atmosphereEffect.Density = 0.3
            atmosphereEffect.Glare = 0.4
            atmosphereEffect.Haze = 1.5

            sunRaysEffect.Enabled = true
            sunRaysEffect.Intensity = 0.25
            sunRaysEffect.Spread = 0.5

            Lighting.GlobalShadows = true
            Lighting.ExposureCompensation = 0.3
        end,
    },
    {
        id = "cinematic",
        label = "Cinematic Shader",
        color = Color3.fromRGB(255, 100, 120),
        apply = function()
            bloomEffect.Enabled = true
            bloomEffect.Intensity = 1.0
            bloomEffect.Size = 20
            bloomEffect.Threshold = 0.85

            colorCorrection.Enabled = true
            colorCorrection.Contrast = 0.25
            colorCorrection.Saturation = -0.15
            colorCorrection.TintColor = Color3.fromRGB(255, 230, 210)

            atmosphereEffect.Density = 0.2
            atmosphereEffect.Haze = 1.0

            Lighting.ExposureCompensation = 0.15
        end,
    },
    {
        id = "night",
        label = "Night Shaders",
        color = Color3.fromRGB(90, 100, 200),
        apply = function()
            colorCorrection.Enabled = true
            colorCorrection.Brightness = -0.15
            colorCorrection.Contrast = 0.1
            colorCorrection.Saturation = -0.2
            colorCorrection.TintColor = Color3.fromRGB(180, 190, 255)

            atmosphereEffect.Density = 0.35
            atmosphereEffect.Color = Color3.fromRGB(40, 40, 80)

            Lighting.ClockTime = 22
            bloomEffect.Enabled = true
            bloomEffect.Intensity = 0.5
        end,
    },
    {
        id = "retro",
        label = "8 Bit Shaders",
        color = Color3.fromRGB(255, 210, 60),
        apply = function()
            colorCorrection.Enabled = true
            colorCorrection.Saturation = 0.6
            colorCorrection.Contrast = 0.4
            colorCorrection.Brightness = 0.1

            bloomEffect.Enabled = false
            sunRaysEffect.Enabled = false
            disableAtmosphere()
        end,
    },
}

local activeEffectId = nil

local function turnOffAll()
    bloomEffect.Enabled = false
    colorCorrection.Enabled = false
    sunRaysEffect.Enabled = false
    disableAtmosphere()
    resetLightingToDefault()
    activeEffectId = nil
end

-- ==================== BUKA APP ====================
function _G.openShaderApp()
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,50)
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 14)
    stroke(header, C.accent, 1, 0.5)

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1,-16,0,22)
    hTitle.Position = UDim2.new(0,14,0,6)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "SHADER"
    hTitle.TextColor3 = C.accent
    hTitle.Font = Enum.Font.GothamBlack
    hTitle.TextSize = 15
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hSub = Instance.new("TextLabel", header)
    hSub.Size = UDim2.new(1,-16,0,14)
    hSub.Position = UDim2.new(0,14,0,28)
    hSub.BackgroundTransparency = 1
    hSub.Text = "Pilih Shader"
    hSub.TextColor3 = C.text2
    hSub.Font = Enum.Font.Gotham
    hSub.TextSize = 9
    hSub.TextXAlignment = Enum.TextXAlignment.Left

    local listSec = Instance.new("Frame", appContent)
    listSec.Size = UDim2.new(1,0,0,0)
    listSec.AutomaticSize = Enum.AutomaticSize.Y
    listSec.BackgroundTransparency = 1
    listSec.LayoutOrder = 1

    local listLayout = Instance.new("UIListLayout", listSec)
    listLayout.Padding = UDim.new(0,8)

    if not _G._shaderToggleRefs then _G._shaderToggleRefs = {} end

    for i, effect in ipairs(EFFECTS) do
        local row = Instance.new("Frame", listSec)
        row.Size = UDim2.new(1,0,0,44)
        row.BackgroundColor3 = C.card
        row.LayoutOrder = i
        corner(row, 12)
        stroke(row, C.border, 1, 0.4)

        local accentBar = Instance.new("Frame", row)
        accentBar.Size = UDim2.new(0,3,1,-16)
        accentBar.Position = UDim2.new(0,0,0,8)
        accentBar.BackgroundColor3 = effect.color
        corner(accentBar, 2)

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(1,-90,1,0)
        label.Position = UDim2.new(0,16,0,0)
        label.BackgroundTransparency = 1
        label.Text = effect.label:upper()
        label.TextColor3 = C.text
        label.Font = Enum.Font.GothamBold
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left

        local toggleBg = Instance.new("Frame", row)
        toggleBg.Size = UDim2.new(0,42,0,22)
        toggleBg.Position = UDim2.new(1,-58,0.5,-11)
        toggleBg.BackgroundColor3 = Color3.fromRGB(45,42,60)
        corner(toggleBg, 100)
        stroke(toggleBg, C.border, 1, 0.5)

        local toggleDot = Instance.new("Frame", toggleBg)
        toggleDot.Size = UDim2.new(0,16,0,16)
        toggleDot.Position = UDim2.new(0,3,0.5,-8)
        toggleDot.BackgroundColor3 = Color3.fromRGB(120,115,140)
        corner(toggleDot, 100)

        local stateLbl = Instance.new("TextLabel", row)
        stateLbl.Size = UDim2.new(0,30,0,14)
        stateLbl.Position = UDim2.new(1,-30,1,-16)
        stateLbl.BackgroundTransparency = 1
        stateLbl.Text = "OFF"
        stateLbl.TextColor3 = C.text2
        stateLbl.Font = Enum.Font.GothamBold
        stateLbl.TextSize = 8
        stateLbl.TextXAlignment = Enum.TextXAlignment.Right

        local function setToggleVisual(isOn)
            if isOn then
                tween(toggleBg, {BackgroundColor3 = effect.color}, 0.15)
                tween(toggleDot, {Position = UDim2.new(1,-19,0.5,-8), BackgroundColor3 = Color3.new(1,1,1)}, 0.15)
                stateLbl.Text = "ON"
                stateLbl.TextColor3 = effect.color
            else
                tween(toggleBg, {BackgroundColor3 = Color3.fromRGB(45,42,60)}, 0.15)
                tween(toggleDot, {Position = UDim2.new(0,3,0.5,-8), BackgroundColor3 = Color3.fromRGB(120,115,140)}, 0.15)
                stateLbl.Text = "OFF"
                stateLbl.TextColor3 = C.text2
            end
        end

        local toggleBtn = Instance.new("TextButton", row)
        toggleBtn.Size = UDim2.new(1,0,1,0)
        toggleBtn.BackgroundTransparency = 1
        toggleBtn.Text = ""
        toggleBtn.MouseButton1Click:Connect(function()
            if activeEffectId == effect.id then
                turnOffAll()
                setToggleVisual(false)
            else
                turnOffAll()
                local ok, err = pcall(effect.apply)
                if ok then
                    activeEffectId = effect.id
                    setToggleVisual(true)
                    if _G.showDynamicNotification then
                        _G.showDynamicNotification(effect.label .. " diaktifkan", effect.color)
                    end
                else
                    warn("[Shader] Gagal apply efek " .. effect.label .. ": " .. tostring(err))
                    if _G.showDynamicNotification then
                        _G.showDynamicNotification("Gagal aktifkan " .. effect.label, Color3.fromRGB(255,90,100))
                    end
                end
            end
            _G.refreshShaderToggles()
        end)

        _G._shaderToggleRefs[effect.id] = setToggleVisual
        setToggleVisual(activeEffectId == effect.id)
    end

    local resetBtn = Instance.new("TextButton", appContent)
    resetBtn.Size = UDim2.new(1,0,0,36)
    resetBtn.BackgroundColor3 = Color3.fromRGB(255,90,100)
    resetBtn.BackgroundTransparency = 0.85
    resetBtn.Text = "Matikan Semua Shader"
    resetBtn.TextColor3 = Color3.fromRGB(255,90,100)
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 11
    resetBtn.AutoButtonColor = false
    resetBtn.LayoutOrder = 2
    corner(resetBtn, 10)
    stroke(resetBtn, Color3.fromRGB(255,90,100), 1, 0.7)
    resetBtn.MouseButton1Click:Connect(function()
        turnOffAll()
        _G.refreshShaderToggles()
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Semua shader dimatikan", Color3.fromRGB(255,90,100))
        end
    end)
end

function _G.refreshShaderToggles()
    if not _G._shaderToggleRefs then return end
    for id, setFn in pairs(_G._shaderToggleRefs) do
        setFn(activeEffectId == id)
    end
end

print("[Shader] Loaded!")
