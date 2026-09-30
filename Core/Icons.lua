-- Core/Icons.lua

local T = _G.T
local Helpers = _G.Helpers

local iconBuilders = {}

-- ==================== PALET MONOKROM ====================
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

-- ==================== HELPER: BASE TILE ====================
-- Dipakai di SEMUA icon supaya seragam: kotak gelap rounded dengan outline
-- putih tipis transparan, jadi terasa satu set ikon yang konsisten.
local function baseTile(p, size, cornerRadius)
    size = size or 30
    cornerRadius = cornerRadius or 10
    local tile = Instance.new("Frame", p)
    tile.Size = UDim2.new(0, size, 0, size)
    tile.AnchorPoint = Vector2.new(0.5, 0.5)
    tile.Position = UDim2.new(0.5, 0, 0.42, 0)
    tile.BackgroundColor3 = BLACK
    tile.ZIndex = 1
    Helpers.corner(tile, cornerRadius)
    Helpers.stroke(tile, WHITE, 1, 0.75)
    return tile
end

-- Kotak putih solid, posisi relatif terhadap parent (tile), anchor tengah.
local function glyphRect(parent, w, h, offX, offY, radius)
    local r = Instance.new("Frame", parent)
    r.Size = UDim2.new(0, w, 0, h)
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.Position = UDim2.new(0.5, offX, 0.5, offY)
    r.BackgroundColor3 = WHITE
    r.ZIndex = 2
    Helpers.corner(r, radius or 2)
    return r
end

local function glyphCircleOutline(parent, size, offX, offY, thickness)
    local ring = Instance.new("Frame", parent)
    ring.Size = UDim2.new(0, size, 0, size)
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.new(0.5, offX, 0.5, offY)
    ring.BackgroundTransparency = 1
    ring.ZIndex = 2
    Helpers.corner(ring, 100)
    Helpers.stroke(ring, WHITE, thickness or 2, 0)
    return ring
end

local function glyphText(parent, text, size, offX, offY, fontSize)
    local t = Instance.new("TextLabel", parent)
    t.Size = UDim2.new(0, size, 0, size)
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.Position = UDim2.new(0.5, offX, 0.5, offY)
    t.BackgroundTransparency = 1
    t.Text = text
    t.TextColor3 = WHITE
    t.Font = Enum.Font.GothamBlack
    t.TextSize = fontSize or 14
    t.ZIndex = 2
    return t
end

-- ================================================================
-- 1. PLAYERS — silhouette orang
-- ================================================================
iconBuilders.Players = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 10, 10, 0, -7, 100) -- kepala
    glyphRect(tile, 18, 9, 0, 4, 5)     -- badan
end

-- ================================================================
-- 2. CLONE — dua kotak bertumpuk (kesan duplikat)
-- ================================================================
iconBuilders.Clone = function(p, c)
    local tile = baseTile(p)
    local back = Instance.new("Frame", tile)
    back.Size = UDim2.new(0, 15, 0, 15)
    back.AnchorPoint = Vector2.new(0.5, 0.5)
    back.Position = UDim2.new(0.5, -4, 0.5, -4)
    back.BackgroundTransparency = 1
    back.ZIndex = 2
    Helpers.corner(back, 4)
    Helpers.stroke(back, WHITE, 1.5, 0.35)
    glyphRect(tile, 15, 15, 4, 4, 4)
end

-- ================================================================
-- 3. PRESET — kotak penyimpanan dengan lid
-- ================================================================
iconBuilders.Preset = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 18, 13, 0, 3, 3)
    glyphRect(tile, 10, 4, 0, -5, 2)
end

-- ================================================================
-- 4. FAVS — tanda plus
-- ================================================================
iconBuilders.Favs = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 16, 3, 0, 0, 2)
    glyphRect(tile, 3, 16, 0, 0, 2)
end

-- ================================================================
-- 5. VOLUME — speaker + ring gelombang
-- ================================================================
iconBuilders.Volume = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 6, 8, -6, 0, 2)
    local cone = Instance.new("Frame", tile)
    cone.Size = UDim2.new(0, 8, 0, 12)
    cone.AnchorPoint = Vector2.new(0.5, 0.5)
    cone.Position = UDim2.new(0.5, -1, 0.5, 0)
    cone.BackgroundColor3 = WHITE
    cone.ZIndex = 2
    Helpers.corner(cone, 2)
    glyphCircleOutline(tile, 14, 6, 0, 1.5)
end

-- ================================================================
-- 6. ITEMS — kartu ID
-- ================================================================
iconBuilders.Items = function(p, c)
    local tile = baseTile(p)
    local card = Instance.new("Frame", tile)
    card.Size = UDim2.new(0, 22, 0, 16)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundTransparency = 1
    card.ZIndex = 2
    Helpers.corner(card, 3)
    Helpers.stroke(card, WHITE, 1.5, 0)
    glyphText(tile, "ID", 20, 0, 0, 10)
end

-- ================================================================
-- 7. PROFILE — kepala + bahu
-- ================================================================
iconBuilders.Profile = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 11, 11, 0, -6, 100)
    glyphRect(tile, 19, 10, 0, 5, 6)
end

-- ================================================================
-- 8. RESET — huruf R
-- ================================================================
iconBuilders.Reset = function(p, c)
    local tile = baseTile(p)
    glyphText(tile, "R", 20, 0, 0, 15)
end

-- ================================================================
-- 9. SIZE — huruf S
-- ================================================================
iconBuilders.Size = function(p, c)
    local tile = baseTile(p)
    glyphText(tile, "S", 20, 0, 0, 14)
end

-- ================================================================
-- 10. FRIENDS — dua silhouette berdampingan
-- ================================================================
iconBuilders.Friends = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 8, 8, -7, -5, 100)
    glyphRect(tile, 13, 8, -7, 5, 5)
    glyphRect(tile, 8, 8, 7, -5, 100)
    glyphRect(tile, 13, 8, 7, 5, 5)
end

-- ================================================================
-- 11. SERVER — rak server + 3 lampu indikator
-- FIX BUG LAMA: posisi lampu dulu pakai UDim2.new(0.5-9+6*i, 0, 0.55, 0)
-- yaitu operasi matematika langsung di KOMPONEN SCALE UDim2. Itu salah
-- karena 0.5-9 menghasilkan scale -8.5 (jauh di luar frame), bukan offset
-- piksel. Sekarang pakai AnchorPoint tengah + offset piksel murni (i*6),
-- jadi PASTI simetris dan tidak pernah melenceng dari tile.
-- ================================================================
iconBuilders.Server = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 22, 15, 0, 0, 3)
    for i = -1, 1 do
        local dot = Instance.new("Frame", tile)
        dot.Size = UDim2.new(0, 4, 0, 4)
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.new(0.5, i * 6, 0.5, 3)
        dot.BackgroundColor3 = BLACK
        dot.ZIndex = 3
        Helpers.corner(dot, 100)
    end
end

-- ================================================================
-- 12. TELEPORT — label "TP"
-- ================================================================
iconBuilders.Teleport = function(p, c)
    local tile = baseTile(p)
    glyphText(tile, "TP", 22, 0, 0, 11)
end

-- ================================================================
-- 13. SETTINGS — gear glyph
-- ================================================================
iconBuilders.Settings = function(p, c)
    local tile = baseTile(p)
    glyphText(tile, "⚙", 24, 0, 0, 20)
end

-- ================================================================
-- 14. COMMAND — jendela terminal + kursor kedip
-- ================================================================
iconBuilders.Command = function(p, c)
    local tile = baseTile(p)
    local window = Instance.new("Frame", tile)
    window.Size = UDim2.new(0, 22, 0, 16)
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.new(0.5, 0, 0.5, 0)
    window.BackgroundTransparency = 1
    window.ZIndex = 2
    Helpers.corner(window, 3)
    Helpers.stroke(window, WHITE, 1.5, 0)

    glyphText(window, ">", 10, -5, 0, 9)
    local cursor = glyphRect(window, 2, 7, 3, 0, 1)
    task.spawn(function()
        while cursor.Parent do
            for _, t in ipairs({0, 1, 0}) do
                if not cursor.Parent then break end
                cursor.BackgroundTransparency = t
                task.wait(0.45)
            end
        end
    end)
end

-- ================================================================
-- 15. BUNDLE — kotak hadiah dengan pita
-- ================================================================
iconBuilders.Bundle = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 20, 16, 0, 2, 3)
    glyphRect(tile, 20, 4, 0, -6, 1)
    glyphRect(tile, 4, 20, 0, 2, 1)
end

-- ================================================================
-- 17. WHO ONLINE — ring + dot status
-- ================================================================
iconBuilders.WhoOnline = function(p, c)
    local tile = baseTile(p)
    glyphCircleOutline(tile, 20, 0, -2, 2)
    local dot = Instance.new("Frame", tile)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.new(0.5, 7, 0.5, 6)
    dot.BackgroundColor3 = WHITE
    dot.ZIndex = 3
    Helpers.corner(dot, 100)
    Helpers.stroke(dot, BLACK, 1.5, 0)
end

-- ================================================================
-- 18. MESSAGE — bubble chat dengan ekor
-- ================================================================
iconBuilders.Message = function(p, c)
    local tile = baseTile(p)
    glyphRect(tile, 22, 15, 0, -2, 5)
    local tail = Instance.new("Frame", tile)
    tail.Size = UDim2.new(0, 6, 0, 6)
    tail.AnchorPoint = Vector2.new(0.5, 0.5)
    tail.Position = UDim2.new(0.5, -6, 0.5, 7)
    tail.BackgroundColor3 = WHITE
    tail.Rotation = 45
    tail.ZIndex = 1
    Helpers.corner(tail, 1)
    for _, i in ipairs({-1, 0, 1}) do
        local d = Instance.new("Frame", tile)
        d.Size = UDim2.new(0, 3, 0, 3)
        d.AnchorPoint = Vector2.new(0.5, 0.5)
        d.Position = UDim2.new(0.5, i * 6, 0.5, -2)
        d.BackgroundColor3 = BLACK
        d.ZIndex = 3
        Helpers.corner(d, 100)
    end
end

-- ================================================================
-- 19. PREMIUM — mahkota, dikonversi total ke monokrom
-- ================================================================
iconBuilders.Premium = function(p, c)
    local tile = baseTile(p)

    glyphRect(tile, 16, 3, 0, 5, 1) -- alas

    local function crownPeak(offsetX, offsetY)
        local peak = Instance.new("Frame", tile)
        peak.Size = UDim2.new(0, 6, 0, 6)
        peak.AnchorPoint = Vector2.new(0.5, 0.5)
        peak.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
        peak.BackgroundColor3 = WHITE
        peak.Rotation = 45
        peak.ZIndex = 2
        Helpers.corner(peak, 1)
        return peak
    end
    crownPeak(-7, -3)
    crownPeak(0, -6)
    crownPeak(7, -3)

    task.spawn(function()
        local hasAccess = _G.hasPremiumAccess and _G.hasPremiumAccess()
        if not hasAccess then
            local lockBadge = Instance.new("Frame", p)
            lockBadge.Size = UDim2.new(0, 16, 0, 16)
            lockBadge.AnchorPoint = Vector2.new(0.5, 0.5)
            lockBadge.Position = UDim2.new(0.82, 0, 0.22, 0)
            lockBadge.BackgroundColor3 = WHITE
            lockBadge.ZIndex = 5
            Helpers.corner(lockBadge, 100)
            Helpers.stroke(lockBadge, BLACK, 1.5, 0)

            local lockIcon = Instance.new("TextLabel", lockBadge)
            lockIcon.Size = UDim2.new(1, 0, 1, 0)
            lockIcon.BackgroundTransparency = 1
            lockIcon.Text = "🔒"
            lockIcon.TextSize = 8
            lockIcon.ZIndex = 6
        end
    end)
end

-- ================================================================
-- 20. ALFREAD AI — bintang/sparkle
-- ================================================================
iconBuilders.AlfreadAI = function(p, c)
    local tile = baseTile(p)
    glyphText(tile, "✦", 24, 0, 0, 20)
end

-- ================================================================
-- 21. SHADER — diamond outline
-- ================================================================
iconBuilders.Shader = function(p, c)
    local tile = baseTile(p)
    local diamond = Instance.new("Frame", tile)
    diamond.Size = UDim2.new(0, 16, 0, 16)
    diamond.AnchorPoint = Vector2.new(0.5, 0.5)
    diamond.Position = UDim2.new(0.5, 0, 0.5, 0)
    diamond.BackgroundTransparency = 1
    diamond.Rotation = 45
    diamond.ZIndex = 2
    Helpers.corner(diamond, 3)
    Helpers.stroke(diamond, WHITE, 2, 0)
end

iconBuilders.Games = function(p, c)
    local bg = Instance.new("Frame", p)
    bg.Size = UDim2.new(0, 26, 0, 26)
    bg.Position = UDim2.new(0.5, -13, 0.28, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Helpers.corner(bg, 8)

    local icon = Instance.new("TextLabel", bg)
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "🎮"
    icon.TextSize = 15
end

iconBuilders.Emote = function(p, c)
    -- Tile dasar (kotak gelap rounded)
    local tile = Instance.new("Frame", p)
    tile.Size = UDim2.new(0, 30, 0, 30)
    tile.AnchorPoint = Vector2.new(0.5, 0.5)
    tile.Position = UDim2.new(0.5, 0, 0.42, 0)
    tile.BackgroundColor3 = Color3.new(0, 0, 0)
    tile.ZIndex = 1
    _G.Helpers.corner(tile, 10)
    _G.Helpers.stroke(tile, Color3.new(1, 1, 1), 1, 0.75)

    -- Mata (dua lingkaran putih)
    local function eye(offX, offY)
        local e = Instance.new("Frame", tile)
        e.Size = UDim2.new(0, 5, 0, 5)
        e.AnchorPoint = Vector2.new(0.5, 0.5)
        e.Position = UDim2.new(0.5, offX, 0.5, offY)
        e.BackgroundColor3 = Color3.new(1, 1, 1)
        e.ZIndex = 2
        _G.Helpers.corner(e, 100)
        return e
    end
    eye(-6, -4)
    eye(6, -4)

    -- Senyum (lengkungan putih)
    local smile = Instance.new("Frame", tile)
    smile.Size = UDim2.new(0, 10, 0, 5)
    smile.AnchorPoint = Vector2.new(0.5, 0.5)
    smile.Position = UDim2.new(0.5, 0, 0.5, 3)
    smile.BackgroundTransparency = 1
    smile.ZIndex = 2
    _G.Helpers.corner(smile, 100)
    _G.Helpers.stroke(smile, Color3.new(1, 1, 1), 2, 0)
    -- Ubah bentuk menjadi setengah lingkaran bawah
    -- Dengan clipping agar hanya bagian bawah terlihat
    local clip = Instance.new("Frame", smile)
    clip.Size = UDim2.new(1, 0, 0.5, 0)
    clip.Position = UDim2.new(0, 0, 0.5, 0)
    clip.BackgroundColor3 = Color3.new(0, 0, 0)  -- warna tile
    clip.ZIndex = 3
    -- Tambahkan juga outline di bagian bawah? Sudah cukup.
end

iconBuilders.MyClone = function(p, c)
    -- Base tile gelap dengan outline putih (sama seperti icon lain)
    local tile = baseTile(p, 30, 10)

    -- ---- DUA SILUET ORANG (clone) ----
    -- Orang kiri (clone pertama)
    glyphRect(tile, 5, 5, -7, -5, 100) -- kepala (lingkaran)
    glyphRect(tile, 9, 5, -7, 2, 4)    -- badan (persegi panjang)

    -- Orang kanan (clone kedua)
    glyphRect(tile, 5, 5, 7, -5, 100)  -- kepala
    glyphRect(tile, 9, 5, 7, 2, 4)     -- badan

    -- ---- RING LINGKAR (menandakan mode edit / transformasi) ----
    glyphCircleOutline(tile, 24, 0, 0, 1.5)

    -- ---- PANAH MELINGKAR (↻) di bawah ----
    local arrow = Instance.new("TextLabel", tile)
    arrow.Size = UDim2.new(0, 16, 0, 16)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(0.5, 0, 0.5, 10) -- posisi di bawah ring
    arrow.BackgroundTransparency = 1
    arrow.Text = "↻"
    arrow.TextColor3 = WHITE
    arrow.Font = Enum.Font.GothamBlack
    arrow.TextSize = 12
    arrow.ZIndex = 2
end

-- ================================================================
-- 23. MODEL 3D — Dua kotak bertumpuk (Wireframe 3D) dengan node origin
-- ================================================================
iconBuilders.Model3D = function(p, c)
    -- Base tile kotak gelap rounded standar
    local tile = baseTile(p, 30, 10)
    
    -- Kotak Belakang (Kedalaman / Depth)
    local backBox = Instance.new("Frame", tile)
    backBox.Size = UDim2.new(0, 10, 0, 10)
    backBox.AnchorPoint = Vector2.new(0.5, 0.5)
    backBox.Position = UDim2.new(0.5, 3, 0.5, -4)
    backBox.BackgroundTransparency = 1
    backBox.ZIndex = 1
    Helpers.corner(backBox, 1)
    Helpers.stroke(backBox, WHITE, 1, 0.6) -- Stroke lebih transparan memberi efek jauh
    
    -- Kotak Depan (Wajah utama)
    local frontBox = Instance.new("Frame", tile)
    frontBox.Size = UDim2.new(0, 12, 0, 12)
    frontBox.AnchorPoint = Vector2.new(0.5, 0.5)
    frontBox.Position = UDim2.new(0.5, -2, 0.5, 1)
    frontBox.BackgroundTransparency = 1
    frontBox.ZIndex = 2
    Helpers.corner(frontBox, 1)
    Helpers.stroke(frontBox, WHITE, 1.5, 0) -- Stroke solid memberi efek dekat
    
    -- Garis penghubung (Memberi ilusi kubus 3D isometrik)
    local connect = Instance.new("Frame", tile)
    connect.Size = UDim2.new(0, 1.5, 0, 6)
    connect.AnchorPoint = Vector2.new(0.5, 0.5)
    connect.Position = UDim2.new(0.5, 0.5, 0.5, -1.5)
    connect.BackgroundColor3 = WHITE
    connect.BackgroundTransparency = 0.5
    connect.Rotation = -45
    connect.ZIndex = 1
    
    -- Node origin (Titik tengah / merepresentasikan Anchor point gizmo)
    local origin = Instance.new("Frame", tile)
    origin.Size = UDim2.new(0, 3, 0, 3)
    origin.AnchorPoint = Vector2.new(0.5, 0.5)
    origin.Position = UDim2.new(0.5, -2, 0.5, 1)
    origin.BackgroundColor3 = WHITE
    origin.ZIndex = 3
    Helpers.corner(origin, 100)
end

iconBuilders.Dashboard = function(p,c) local tile=baseTile(p); glyphRect(tile,18,18,0,0,4); glyphRect(tile,5,5,-5,-5,2); glyphRect(tile,5,5,5,-5,2); glyphRect(tile,5,5,-5,5,2); glyphRect(tile,5,5,5,5,2) end
iconBuilders.Appearance = function(p,c) local tile=baseTile(p); glyphCircleOutline(tile,19,0,0,2); glyphCircleOutline(tile,7,0,0,2) end

return iconBuilders
