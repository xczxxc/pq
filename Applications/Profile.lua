-- ================================================
-- PROFILE APP - Dark Theme (Fixed & Upgraded)
--
-- BUG UTAMA (penyebab layar putih kosong):
-- 1. getItems() manggil HttpService:GetAsync() secara SYNCHRONOUS di
--    tengah proses render UI (dipanggil di baris tengah openProfileApp,
--    SETELAH card sudah setengah dibuat). GetAsync itu BLOCKING — kalau
--    request lambat/gagal, seluruh render macet di situ, dan elemen
--    setelahnya (list item, dsb) tidak pernah sempat dibuat. Hasilnya:
--    layar cuma menampilkan appContent/screen-area kosong (putih),
--    bukan dark card yang seharusnya sudah tampil.
-- 2. Config.REMOTE_PATH:split(".") — method :split() TIDAK ADA di
--    Lua/Luau string library bawaan Roblox. Ini error "missing method
--    'split'" begitu fireHat() dipanggil.
-- 3. Tidak ada pcall pembungkus di seluruh openProfileApp() — satu
--    error di manapun (Config nil, Helpers.tween nil, dst) langsung
--    menghentikan seluruh fungsi tanpa fallback visual apapun.
--
-- FIX:
-- - Render card + skeleton dulu (langsung tampil, tidak nunggu HTTP).
-- - getItems() dipanggil lewat task.spawn (non-blocking), list item
--   baru dirender begitu data selesai diambil.
-- - split(".") diganti gmatch pattern manual.
-- - Seluruh openProfileApp() dibungkus pcall dengan pesan visual kalau
--   ada yang gagal, bukan diam-diam kosong.
-- ================================================

local Services         = _G.Services
local LocalPlayer      = _G.LocalPlayer
local Players          = Services.Players
local HttpService      = Services.HttpService
local ReplicatedStorage= Services.ReplicatedStorage
local T                = _G.T or {}
local Helpers          = _G.Helpers or {}
local Config           = _G.Config or {}

local appContent       = _G.appContent

-- ==================== HELPER FALLBACK ====================
-- Kalau Helpers.tween/pressFX belum ada, jangan biarkan seluruh app
-- crash karena satu fungsi nil — sediakan fallback aman.
local corner  = Helpers.corner or function(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = o
    return c
end
local stroke  = Helpers.stroke or function(o, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or Color3.fromRGB(200,200,200)
    s.Thickness = th or 1
    s.Transparency = tr or 0
    s.Parent = o
    return s
end
local tween   = Helpers.tween or function(o, props, t)
    pcall(function()
        game:GetService("TweenService"):Create(o, TweenInfo.new(t or 0.2), props):Play()
    end)
end
local pressFX = Helpers.pressFX or function(b)
    local orig = b.Size
    b.MouseButton1Down:Connect(function()
        tween(b, {Size = UDim2.new(orig.X.Scale*.96, orig.X.Offset*.96, orig.Y.Scale*.96, orig.Y.Offset*.96)}, 0.1)
    end)
    b.MouseButton1Up:Connect(function() tween(b, {Size = orig}, 0.1) end)
end
local copyToClipboard = Helpers.copyToClipboard or function(text)
    pcall(function()
        if setclipboard then setclipboard(text)
        elseif toclipboard then toclipboard(text) end
    end)
end
local notify = _G.showDynamicNotification or function() end

-- ==================== COLORS ====================
local colors = {
    bg       = Color3.fromRGB(15, 15, 20),
    card     = Color3.fromRGB(25, 25, 32),
    card2    = Color3.fromRGB(30, 30, 38),
    card3    = Color3.fromRGB(38, 38, 48),
    accent   = Color3.fromRGB(255, 255, 255),
    accent2  = Color3.fromRGB(0, 200, 255),
    purple   = Color3.fromRGB(150, 120, 255),
    gold     = Color3.fromRGB(255, 180, 50),
    green    = Color3.fromRGB(0, 230, 118),
    red      = Color3.fromRGB(255, 82, 82),
    text     = Color3.fromRGB(255, 255, 255),
    text2    = Color3.fromRGB(170, 170, 180),
    text3    = Color3.fromRGB(100, 100, 115),
    border   = Color3.fromRGB(45, 45, 55),
}

-- ==================== SPLIT HELPER (FIX) ====================
-- string:split() bukan API bawaan Roblox — ganti dengan gmatch pattern.
local function splitPath(path, sep)
    sep = sep or "%."
    local parts = {}
    for part in string.gmatch(path or "", "([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

-- ==================== FETCH ITEMS (NON-BLOCKING) ====================
-- Dipanggil lewat task.spawn dari luar, callback dipanggil setelah selesai
-- (baik sukses maupun gagal), supaya render UI tidak pernah nge-freeze.
local function fetchItems(player, callback)
    task.spawn(function()
        if not player then callback({}, "No player selected") return end

        local ok, result = pcall(function()
            return HttpService:JSONDecode(
                HttpService:GetAsync("https://avatar.roblox.com/v1/users/" .. player.UserId .. "/avatar")
            )
        end)

        if not ok or not result or not result.assets then
            callback({}, "Gagal mengambil data avatar")
            return
        end

        local items = {}
        for _, asset in ipairs(result.assets) do
            if asset.id and type(asset.id) == "number" then
                table.insert(items, {
                    Value = tostring(asset.id),
                    Label = asset.name or ("Item " .. asset.id),
                    Type  = "ACC",
                })
            end
        end

        callback(items, nil)
    end)
end

-- ==================== FIRE HAT (CLONE) ====================
local function fireHat(ids)
    if #ids == 0 then return false, "Tidak ada item untuk di-clone" end

    local remotePath = Config.REMOTE_PATH or ""
    local remote = ReplicatedStorage
    for _, part in ipairs(splitPath(remotePath)) do
        remote = remote and remote:FindFirstChild(part)
        if not remote then
            return false, "Remote tidak ditemukan: " .. remotePath
        end
    end

    local ok, err = pcall(function()
        remote:FireServer("hat", {"hat", unpack(ids)})
    end)

    if not ok then return false, "Gagal fire remote: " .. tostring(err) end
    return true, nil
end

-- ==================== UI BUILDERS ====================
local function buildItemRow(parent, item, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = colors.card2
    row.LayoutOrder = order
    corner(row, 12)
    stroke(row, colors.border, 1, 0.4)

    local thumbFrame = Instance.new("Frame", row)
    thumbFrame.Size = UDim2.new(0, 44, 0, 44)
    thumbFrame.Position = UDim2.new(0, 6, 0.5, -22)
    thumbFrame.BackgroundColor3 = colors.card3
    corner(thumbFrame, 10)

    local thumb = Instance.new("ImageLabel", thumbFrame)
    thumb.Size = UDim2.new(1, -4, 1, -4)
    thumb.Position = UDim2.new(0, 2, 0, 2)
    thumb.BackgroundTransparency = 1
    thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.Value .. "&width=100&height=100&format=png"
    thumb.ScaleType = Enum.ScaleType.Fit
    corner(thumb, 8)

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -136, 0, 18)
    nameLbl.Position = UDim2.new(0, 58, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = item.Label
    nameLbl.TextColor3 = colors.text
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local idLbl = Instance.new("TextLabel", row)
    idLbl.Size = UDim2.new(1, -136, 0, 16)
    idLbl.Position = UDim2.new(0, 58, 0, 27)
    idLbl.BackgroundTransparency = 1
    idLbl.Text = "ID " .. item.Value
    idLbl.TextColor3 = colors.accent2
    idLbl.Font = Enum.Font.Code
    idLbl.TextSize = 10
    idLbl.TextXAlignment = Enum.TextXAlignment.Left

    local copyBtn = Instance.new("TextButton", row)
    copyBtn.Size = UDim2.new(0, 58, 0, 30)
    copyBtn.Position = UDim2.new(1, -66, 0.5, -15)
    copyBtn.BackgroundColor3 = colors.accent
    copyBtn.Text = "Copy"
    copyBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 10
    copyBtn.AutoButtonColor = false
    corner(copyBtn, 8)
    pressFX(copyBtn)

    copyBtn.MouseButton1Click:Connect(function()
        copyToClipboard(item.Value)
        notify("Disalin: " .. item.Value, colors.green)
    end)

    return row
end

-- Skeleton loading row (dipakai sementara data belum datang)
local function buildSkeletonRow(parent, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = colors.card2
    row.BackgroundTransparency = 0.3
    row.LayoutOrder = order
    corner(row, 12)

    local shimmer = Instance.new("Frame", row)
    shimmer.Size = UDim2.new(0, 44, 0, 44)
    shimmer.Position = UDim2.new(0, 6, 0.5, -22)
    shimmer.BackgroundColor3 = colors.card3
    corner(shimmer, 10)

    local line1 = Instance.new("Frame", row)
    line1.Size = UDim2.new(0.5, 0, 0, 12)
    line1.Position = UDim2.new(0, 58, 0, 10)
    line1.BackgroundColor3 = colors.card3
    corner(line1, 4)

    local line2 = Instance.new("Frame", row)
    line2.Size = UDim2.new(0.3, 0, 0, 10)
    line2.Position = UDim2.new(0, 58, 0, 28)
    line2.BackgroundColor3 = colors.card3
    corner(line2, 4)

    -- Animasi pulse sederhana
    task.spawn(function()
        while row.Parent do
            tween(row, {BackgroundTransparency = 0.6}, 0.6)
            task.wait(0.6)
            if not row.Parent then break end
            tween(row, {BackgroundTransparency = 0.3}, 0.6)
            task.wait(0.6)
        end
    end)

    return row
end

-- ==================== MAIN ====================
function _G.openProfileApp()
    -- Bungkus SEMUANYA dengan pcall — kalau ada error di manapun,
    -- tampilkan pesan error yang jelas alih-alih layar kosong.
    local ok, err = pcall(function()

        local selectedPlayer = _G.PhoneState and _G.PhoneState.selectedPlayer

        if not selectedPlayer then
            local emptyCard = Instance.new("Frame", appContent)
            emptyCard.Size = UDim2.new(1, 0, 0, 120)
            emptyCard.BackgroundColor3 = colors.card2
            emptyCard.LayoutOrder = 0
            corner(emptyCard, 14)
            stroke(emptyCard, colors.border, 1, 0.4)

            local iconLbl = Instance.new("TextLabel", emptyCard)
            iconLbl.Size = UDim2.new(1, 0, 0, 40)
            iconLbl.Position = UDim2.new(0, 0, 0, 16)
            iconLbl.BackgroundTransparency = 1
            iconLbl.Text = "👤"
            iconLbl.TextSize = 28
            iconLbl.Font = Enum.Font.GothamBold

            local empty = Instance.new("TextLabel", emptyCard)
            empty.Size = UDim2.new(1, -32, 0, 40)
            empty.Position = UDim2.new(0, 16, 0, 58)
            empty.BackgroundTransparency = 1
            empty.Text = "Belum ada player dipilih.\nBuka app Players lalu pilih salah satu."
            empty.TextColor3 = colors.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 11
            empty.TextWrapped = true
            empty.TextXAlignment = Enum.TextXAlignment.Center
            return
        end

        local p = selectedPlayer

        -- ==================== PROFILE CARD ====================
        local card = Instance.new("Frame", appContent)
        card.Size = UDim2.new(1, 0, 0, 108)
        card.BackgroundColor3 = colors.card2
        card.LayoutOrder = 0
        corner(card, 16)
        stroke(card, colors.accent2, 1.5, 0.35)

        -- Subtle gradient accent di card
        local cardGrad = Instance.new("UIGradient", card)
        cardGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 45)),
            ColorSequenceKeypoint.new(1, colors.card2),
        })
        cardGrad.Rotation = 45

        local avatarFrame = Instance.new("Frame", card)
        avatarFrame.Size = UDim2.new(0, 76, 0, 76)
        avatarFrame.Position = UDim2.new(0, 14, 0.5, -38)
        avatarFrame.BackgroundColor3 = colors.card
        corner(avatarFrame, 100)
        stroke(avatarFrame, colors.accent2, 2, 0.15)

        local avatar = Instance.new("ImageLabel", avatarFrame)
        avatar.Size = UDim2.new(1, -6, 1, -6)
        avatar.Position = UDim2.new(0, 3, 0, 3)
        avatar.BackgroundTransparency = 1
        avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=150&height=150&format=png"
        corner(avatar, 100)

        -- Online indicator dot
        local onlineDot = Instance.new("Frame", avatarFrame)
        onlineDot.Size = UDim2.new(0, 14, 0, 14)
        onlineDot.Position = UDim2.new(1, -14, 1, -14)
        onlineDot.BackgroundColor3 = colors.green
        corner(onlineDot, 100)
        stroke(onlineDot, colors.card2, 2, 0)

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(1, -100, 0, 22)
        nameLbl.Position = UDim2.new(0, 98, 0, 12)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = p.DisplayName
        nameLbl.TextColor3 = colors.text
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 16
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local userLbl = Instance.new("TextLabel", card)
        userLbl.Size = UDim2.new(1, -100, 0, 16)
        userLbl.Position = UDim2.new(0, 98, 0, 35)
        userLbl.BackgroundTransparency = 1
        userLbl.Text = "@" .. p.Name
        userLbl.TextColor3 = colors.text2
        userLbl.Font = Enum.Font.Gotham
        userLbl.TextSize = 11
        userLbl.TextXAlignment = Enum.TextXAlignment.Left

        local idLbl = Instance.new("TextLabel", card)
        idLbl.Size = UDim2.new(1, -100, 0, 16)
        idLbl.Position = UDim2.new(0, 98, 0, 53)
        idLbl.BackgroundTransparency = 1
        idLbl.Text = "ID: " .. p.UserId
        idLbl.TextColor3 = colors.text3
        idLbl.Font = Enum.Font.Code
        idLbl.TextSize = 9
        idLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- Stats badge (placeholder sampai data datang)
        local statsBadge = Instance.new("Frame", card)
        statsBadge.Size = UDim2.new(0, 110, 0, 22)
        statsBadge.Position = UDim2.new(0, 98, 0, 74)
        statsBadge.BackgroundColor3 = colors.card3
        corner(statsBadge, 8)

        local statsDot = Instance.new("Frame", statsBadge)
        statsDot.Size = UDim2.new(0, 6, 0, 6)
        statsDot.Position = UDim2.new(0, 8, 0.5, -3)
        statsDot.BackgroundColor3 = colors.gold
        corner(statsDot, 100)

        local statsLbl = Instance.new("TextLabel", statsBadge)
        statsLbl.Size = UDim2.new(1, -22, 1, 0)
        statsLbl.Position = UDim2.new(0, 18, 0, 0)
        statsLbl.BackgroundTransparency = 1
        statsLbl.Text = "Memuat item..."
        statsLbl.TextColor3 = colors.text2
        statsLbl.Font = Enum.Font.GothamBold
        statsLbl.TextSize = 10
        statsLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- ==================== CLONE BUTTON ====================
        local cloneBtn = Instance.new("TextButton", appContent)
        cloneBtn.Size = UDim2.new(1, 0, 0, 48)
        cloneBtn.BackgroundColor3 = colors.accent
        cloneBtn.Text = "⧉  Clone Avatar"
        cloneBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        cloneBtn.Font = Enum.Font.GothamBlack
        cloneBtn.TextSize = 14
        cloneBtn.AutoButtonColor = false
        cloneBtn.LayoutOrder = 1
        cloneBtn.Active = false -- disabled sampai item selesai dimuat
        corner(cloneBtn, 12)
        pressFX(cloneBtn)
        cloneBtn.BackgroundTransparency = 0.4 -- kelihatan "disabled" dulu

        -- ==================== ITEMS SECTION ====================
        local itemHeaderRow = Instance.new("Frame", appContent)
        itemHeaderRow.Size = UDim2.new(1, 0, 0, 22)
        itemHeaderRow.BackgroundTransparency = 1
        itemHeaderRow.LayoutOrder = 2

        local itemLbl = Instance.new("TextLabel", itemHeaderRow)
        itemLbl.Size = UDim2.new(1, 0, 1, 0)
        itemLbl.BackgroundTransparency = 1
        itemLbl.Text = "Items · Memuat..."
        itemLbl.TextColor3 = colors.text2
        itemLbl.Font = Enum.Font.GothamBold
        itemLbl.TextSize = 11
        itemLbl.TextXAlignment = Enum.TextXAlignment.Left

        -- Container untuk item rows — dipisah supaya bisa dikosongkan & diisi ulang
        local itemContainer = Instance.new("Frame", appContent)
        itemContainer.Name = "ItemContainer"
        itemContainer.Size = UDim2.new(1, 0, 0, 0)
        itemContainer.AutomaticSize = Enum.AutomaticSize.Y
        itemContainer.BackgroundTransparency = 1
        itemContainer.LayoutOrder = 3

        local itemLayout = Instance.new("UIListLayout", itemContainer)
        itemLayout.Padding = UDim.new(0, 6)
        itemLayout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Tampilkan skeleton loading dulu (3 baris) — INI YANG MEMBUAT
        -- UI langsung kelihatan isinya walau data belum datang, jadi
        -- tidak ada lagi kesan "layar putih kosong".
        for i = 1, 3 do
            buildSkeletonRow(itemContainer, i)
        end

        -- ==================== FETCH DATA (NON-BLOCKING) ====================
        local fetchedItems = {}

        fetchItems(p, function(items, errMsg)
            -- Callback ini jalan di thread terpisah (task.spawn), jadi
            -- aman dipanggil kapan saja tanpa nge-freeze render awal.
            fetchedItems = items

            -- Bersihkan skeleton
            for _, child in ipairs(itemContainer:GetChildren()) do
                if not child:IsA("UIListLayout") then
                    child:Destroy()
                end
            end

            if errMsg then
                statsLbl.Text = "Gagal memuat"
                statsDot.BackgroundColor3 = colors.red
                itemLbl.Text = "Items · Error"

                local errRow = Instance.new("Frame", itemContainer)
                errRow.Size = UDim2.new(1, 0, 0, 70)
                errRow.BackgroundColor3 = colors.card2
                errRow.LayoutOrder = 0
                corner(errRow, 12)
                stroke(errRow, colors.red, 1, 0.5)

                local errLbl = Instance.new("TextLabel", errRow)
                errLbl.Size = UDim2.new(1, -24, 1, -16)
                errLbl.Position = UDim2.new(0, 12, 0, 8)
                errLbl.BackgroundTransparency = 1
                errLbl.Text = "⚠ " .. errMsg .. "\nCoba buka ulang profil ini."
                errLbl.TextColor3 = colors.red
                errLbl.Font = Enum.Font.Gotham
                errLbl.TextSize = 10
                errLbl.TextWrapped = true
                return
            end

            statsLbl.Text = #items .. " item ditemukan"
            statsDot.BackgroundColor3 = colors.green
            itemLbl.Text = "Items (" .. #items .. ")"

            if #items == 0 then
                local emptyRow = Instance.new("Frame", itemContainer)
                emptyRow.Size = UDim2.new(1, 0, 0, 60)
                emptyRow.BackgroundColor3 = colors.card2
                emptyRow.LayoutOrder = 0
                corner(emptyRow, 12)

                local emptyLbl = Instance.new("TextLabel", emptyRow)
                emptyLbl.Size = UDim2.new(1, -20, 1, 0)
                emptyLbl.Position = UDim2.new(0, 10, 0, 0)
                emptyLbl.BackgroundTransparency = 1
                emptyLbl.Text = "Player ini tidak memakai item accessory apapun."
                emptyLbl.TextColor3 = colors.text3
                emptyLbl.Font = Enum.Font.Gotham
                emptyLbl.TextSize = 10
                emptyLbl.TextWrapped = true
                emptyLbl.TextXAlignment = Enum.TextXAlignment.Center

                cloneBtn.Active = false
                cloneBtn.BackgroundTransparency = 0.5
                cloneBtn.Text = "Tidak ada item"
                return
            end

            for i, item in ipairs(items) do
                buildItemRow(itemContainer, item, i)
            end

            -- Aktifkan tombol Clone sekarang data sudah siap
            cloneBtn.Active = true
            cloneBtn.BackgroundTransparency = 0
            cloneBtn.Text = "⧉  Clone Avatar (" .. #items .. ")"
        end)

        -- ==================== CLONE BUTTON LOGIC ====================
        cloneBtn.MouseButton1Click:Connect(function()
            if not cloneBtn.Active then return end
            if _G.PhoneState and _G.PhoneState.isCloning then
                notify("Sedang proses cloning...", colors.gold)
                return
            end

            if #fetchedItems == 0 then
                notify("Tidak ada item untuk di-clone", colors.gold)
                return
            end

            local ids = {}
            for _, item in ipairs(fetchedItems) do
                table.insert(ids, item.Value)
            end

            if _G.PhoneState then _G.PhoneState.isCloning = true end
            cloneBtn.Text = "Cloning..."
            cloneBtn.BackgroundTransparency = 0.4

            local success, errMsg = fireHat(ids)

            if _G.PhoneState then _G.PhoneState.isCloning = false end
            cloneBtn.Text = "⧉  Clone Avatar (" .. #ids .. ")"
            cloneBtn.BackgroundTransparency = 0

            if success then
                notify("Cloning " .. #ids .. " items berhasil!", colors.green)
            else
                notify(errMsg or "Gagal cloning", colors.red)
            end
        end)

    end) -- end pcall

    -- Kalau ADA error di manapun di atas, tampilkan pesan yang jelas
    -- alih-alih membiarkan layar kosong/putih tanpa penjelasan.
    if not ok then
        local errCard = Instance.new("Frame", appContent)
        errCard.Size = UDim2.new(1, 0, 0, 100)
        errCard.BackgroundColor3 = colors.card2
        errCard.LayoutOrder = 0
        corner(errCard, 14)
        stroke(errCard, colors.red, 1.5, 0.3)

        local errTitle = Instance.new("TextLabel", errCard)
        errTitle.Size = UDim2.new(1, -24, 0, 20)
        errTitle.Position = UDim2.new(0, 12, 0, 10)
        errTitle.BackgroundTransparency = 1
        errTitle.Text = "⚠ Profile App Error"
        errTitle.TextColor3 = colors.red
        errTitle.Font = Enum.Font.GothamBlack
        errTitle.TextSize = 13
        errTitle.TextXAlignment = Enum.TextXAlignment.Left

        local errDetail = Instance.new("TextLabel", errCard)
        errDetail.Size = UDim2.new(1, -24, 0, 60)
        errDetail.Position = UDim2.new(0, 12, 0, 32)
        errDetail.BackgroundTransparency = 1
        errDetail.Text = tostring(err)
        errDetail.TextColor3 = colors.text3
        errDetail.Font = Enum.Font.Code
        errDetail.TextSize = 9
        errDetail.TextWrapped = true
        errDetail.TextXAlignment = Enum.TextXAlignment.Left
        errDetail.TextYAlignment = Enum.TextYAlignment.Top

        warn("[Profile] Error: " .. tostring(err))
    end
end

print("[Profile] App loaded! (Fixed: non-blocking fetch, split() bug, full pcall wrap)")
