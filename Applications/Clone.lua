-- ================================================
-- CLONE APP - Fixed Frame Drop + Upgraded UI
-- Fix #1: getItems() dipindah ke task.spawn (tidak blocking UI thread)
-- Fix #2: Render card di-stagger (task.wait per beberapa card, bukan 20 sekaligus)
-- Fix #3: Loading state yang jelas selama fetch data
-- Fix #4: Cache dibersihkan otomatis (expired entry di-GC)
-- Upgrade: card lebih modern, animasi masuk halus, empty/error state lebih baik
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players = Services.Players
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage
local T = _G.T
local Helpers = _G.Helpers
local Config = _G.Config

local appContent = _G.appContent

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local tween   = Helpers.tween
local pressFX = Helpers.pressFX

-- ==================== THEME (upgraded) ====================
local colors = {
    bg          = Color3.fromRGB(14, 14, 18),
    card        = Color3.fromRGB(23, 23, 30),
    card2       = Color3.fromRGB(30, 30, 38),
    gridBg      = Color3.fromRGB(17, 17, 22),
    accent      = Color3.fromRGB(120, 190, 255),
    accentDark  = Color3.fromRGB(0, 0, 0),
    text        = Color3.fromRGB(245, 245, 250),
    text2       = Color3.fromRGB(165, 165, 178),
    text3       = Color3.fromRGB(95, 95, 108),
    border      = Color3.fromRGB(42, 42, 52),
    green       = Color3.fromRGB(90, 220, 140),
    tabActive   = Color3.fromRGB(255, 255, 255),
    tabInactive = Color3.fromRGB(30, 30, 38),
}

-- ==================== CACHE (dengan auto-cleanup) ====================
local itemCache = {}
local CACHE_TTL = 60

local function cleanExpiredCache()
    local now = os.time()
    for key, entry in pairs(itemCache) do
        if (now - entry.timestamp) > CACHE_TTL * 3 then
            itemCache[key] = nil
        end
    end
end
-- Bersihkan cache lama setiap 2 menit, supaya memory tidak menumpuk
task.spawn(function()
    while true do
        task.wait(120)
        pcall(cleanExpiredCache)
    end
end)

-- ==================== LIFECYCLE ====================
local CloneLifecycle = {
    active = false,
    currentTab = "ALL",
    isCloning = false,
    selectedItems = {},
    selectAllVisible = true,
    loadToken = 0, -- dipakai buat batalkan render lama kalau app ditutup/dibuka ulang cepat
}

local function cleanupClone()
    CloneLifecycle.active = false
    CloneLifecycle.isCloning = false
    CloneLifecycle.selectedItems = {}
    CloneLifecycle.loadToken = CloneLifecycle.loadToken + 1
end

_G.AvatarCloneCleanupTasks = _G.AvatarCloneCleanupTasks or {}
table.insert(_G.AvatarCloneCleanupTasks, cleanupClone)

-- ==================== HTTP REQUEST (dengan cache) ====================
local function httpGet(url)
    if itemCache[url] and (os.time() - itemCache[url].timestamp) < CACHE_TTL then
        return itemCache[url].data
    end

    if syn and syn.request then
        local ok, result = pcall(function()
            return syn.request({Url = url, Method = "GET"})
        end)
        if ok and result and result.StatusCode == 200 and result.Body then
            itemCache[url] = {data = result.Body, timestamp = os.time()}
            return result.Body
        end
    end

    if http_request then
        local ok, result = pcall(function()
            return http_request({Url = url, Method = "GET"})
        end)
        if ok and result and result.StatusCode == 200 and result.Body then
            itemCache[url] = {data = result.Body, timestamp = os.time()}
            return result.Body
        end
    end

    if request then
        local ok, result = pcall(function()
            return request({Url = url, Method = "GET"})
        end)
        if ok and result then
            local body = result.Body or result
            if body and body ~= "" then
                itemCache[url] = {data = body, timestamp = os.time()}
                return body
            end
        end
    end

    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and result and result ~= "" then
        itemCache[url] = {data = result, timestamp = os.time()}
        return result
    end

    return nil
end

local function fireHat(ids)
    if #ids == 0 then return end
    local remote = ReplicatedStorage
    for _, part in ipairs(Config.REMOTE_PATH:split(".")) do
        remote = remote:FindFirstChild(part)
        if not remote then return end
    end
    pcall(function() remote:FireServer("hat", {"hat", unpack(ids)}) end)
end

-- ==================== GET ITEMS (dengan cache, tetap blocking di sisi pemanggil) ====================
-- CATATAN: fungsi ini masih synchronous (HTTP request menunggu response),
-- tapi sekarang SELALU dipanggil dari dalam task.spawn oleh openCloneApp,
-- jadi tidak lagi membekukan render thread utama.
local function getItems(player)
    local items = {}
    if not player then return items end

    local cacheKey = "avatar_" .. player.UserId
    if itemCache[cacheKey] and (os.time() - itemCache[cacheKey].timestamp) < CACHE_TTL then
        return itemCache[cacheKey].items
    end

    local raw = httpGet("https://avatar.roblox.com/v1/users/" .. player.UserId .. "/avatar")
    if not raw then return items end

    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or not data or not data.assets then return items end

    for _, asset in ipairs(data.assets) do
        if asset and asset.id then
            local assetId = tonumber(asset.id)
            if assetId and assetId > 0 then
                local assetType = "ACC"
                local typeName = ""
                if type(asset.assetType) == "table" then
                    typeName = string.lower(asset.assetType.name or "")
                elseif asset.assetType then
                    typeName = string.lower(tostring(asset.assetType))
                end
                if typeName:find("body") or typeName:find("torso") or typeName:find("leg") or typeName:find("head") or typeName:find("arm") then
                    assetType = "BODY"
                end

                table.insert(items, {
                    Value = tostring(assetId),
                    Label = asset.name or "Item " .. assetId,
                    Type = assetType,
                })
            end
        end
    end

    itemCache[cacheKey] = {items = items, timestamp = os.time()}
    return items
end

local function cloneItems(items, cb)
    if not items or #items == 0 then
        if cb then cb(false) end
        return
    end

    local ids = {}
    for _, item in ipairs(items) do
        table.insert(ids, item.Value)
    end

    local batch = Config.CLONE_BATCH_SIZE or 5
    local delay = Config.CLONE_DELAY or 6
    local total = math.ceil(#ids / batch)
    local current = 0

    local function nextBatch()
        if not CloneLifecycle.active then return end

        current = current + 1
        if current > total then
            if cb then cb(true) end
            return
        end

        local startIdx = (current - 1) * batch + 1
        local endIdx = math.min(current * batch, #ids)
        local batchIds = {}

        for i = startIdx, endIdx do
            table.insert(batchIds, ids[i])
        end

        fireHat(batchIds)

        if cb then
            cb(nil, current, total)
        end

        task.delay(delay, nextBatch)
    end

    nextBatch()
end

-- ==================== UI HELPER: LOADING SPINNER ====================
local function buildLoadingState(parent)
    local wrap = Instance.new("Frame", parent)
    wrap.Name = "LoadingState"
    wrap.Size = UDim2.new(1, 0, 0, 140)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = 0

    local spinner = Instance.new("Frame", wrap)
    spinner.Size = UDim2.new(0, 34, 0, 34)
    spinner.Position = UDim2.new(0.5, -17, 0, 24)
    spinner.BackgroundTransparency = 1

    local ring = Instance.new("Frame", spinner)
    ring.Size = UDim2.new(1, 0, 1, 0)
    ring.BackgroundTransparency = 1
    corner(ring, 100)
    local ringStroke = stroke(ring, colors.accent, 3, 0.2)

    -- Animasi berputar terus selama loading
    local spinning = true
    task.spawn(function()
        while spinning and spinner.Parent do
            spinner.Rotation = 0
            local tw = game:GetService("TweenService"):Create(
                spinner,
                TweenInfo.new(0.8, Enum.EasingStyle.Linear),
                {Rotation = 360}
            )
            tw:Play()
            tw.Completed:Wait()
        end
    end)

    local loadingLbl = Instance.new("TextLabel", wrap)
    loadingLbl.Size = UDim2.new(1, 0, 0, 20)
    loadingLbl.Position = UDim2.new(0, 0, 0, 68)
    loadingLbl.BackgroundTransparency = 1
    loadingLbl.Text = "Mengambil data avatar..."
    loadingLbl.TextColor3 = colors.text2
    loadingLbl.Font = Enum.Font.GothamBold
    loadingLbl.TextSize = 10

    wrap.Destroying:Connect(function() spinning = false end)

    return wrap, function() spinning = false end
end

-- ==================== OPEN CLONE APP ====================
function _G.openCloneApp()
    cleanupClone()
    CloneLifecycle.active = true
    CloneLifecycle.currentTab = "ALL"
    CloneLifecycle.isCloning = false

    local myToken = CloneLifecycle.loadToken
    local selectedPlayer = _G.PhoneState and _G.PhoneState.selectedPlayer

    if not selectedPlayer then
        local empty = Instance.new("TextLabel", appContent)
        empty.Size = UDim2.new(1, 0, 0, 80)
        empty.BackgroundTransparency = 1
        empty.Text = "⚠️  Pilih player terlebih dahulu di tab Players."
        empty.TextColor3 = colors.text3
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.TextWrapped = true
        empty.LayoutOrder = 0
        return
    end

    -- ============ TAMPILKAN LOADING STATE DULU (instan, tidak nunggu HTTP) ============
    local loadingWrap, stopSpin = buildLoadingState(appContent)

    -- ============ FIX UTAMA: fetch data di task.spawn, TIDAK block render thread ============
    task.spawn(function()
        local allItems = getItems(selectedPlayer)

        -- Kalau user sudah pindah app / buka ulang sebelum fetch selesai, batalkan render
        if myToken ~= CloneLifecycle.loadToken then return end

        stopSpin()
        pcall(function() loadingWrap:Destroy() end)

        if #allItems == 0 then
            local empty = Instance.new("TextLabel", appContent)
            empty.Size = UDim2.new(1, 0, 0, 80)
            empty.BackgroundTransparency = 1
            empty.Text = "Tidak ada item ditemukan untuk " .. selectedPlayer.DisplayName
            empty.TextColor3 = colors.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 11
            empty.TextWrapped = true
            empty.LayoutOrder = 0
            return
        end

        _G.renderCloneUI(selectedPlayer, allItems, myToken)
    end)
end

-- ==================== RENDER UI UTAMA (dipanggil setelah data siap) ====================
function _G.renderCloneUI(selectedPlayer, allItems, myToken)
    -- ==================== PLAYER HEADER ====================
    local playerFrame = Instance.new("Frame", appContent)
    playerFrame.Size = UDim2.new(1, 0, 0, 48)
    playerFrame.BackgroundColor3 = colors.card
    playerFrame.LayoutOrder = 0
    playerFrame.BackgroundTransparency = 1 -- fade in
    corner(playerFrame, 12)
    stroke(playerFrame, colors.border, 1, 0.3)

    local avatarRing = Instance.new("Frame", playerFrame)
    avatarRing.Size = UDim2.new(0, 34, 0, 34)
    avatarRing.Position = UDim2.new(0, 7, 0.5, -17)
    avatarRing.BackgroundTransparency = 1
    corner(avatarRing, 100)
    stroke(avatarRing, colors.accent, 1.5, 0.4)

    local avatar = Instance.new("ImageLabel", avatarRing)
    avatar.Size = UDim2.new(1, -4, 1, -4)
    avatar.Position = UDim2.new(0.5, 0, 0.5, 0)
    avatar.AnchorPoint = Vector2.new(0.5, 0.5)
    avatar.BackgroundColor3 = colors.card2
    avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. selectedPlayer.UserId .. "&width=100&height=100&format=png"
    corner(avatar, 100)

    local nameLbl = Instance.new("TextLabel", playerFrame)
    nameLbl.Size = UDim2.new(1, -52, 0, 18)
    nameLbl.Position = UDim2.new(0, 48, 0, 8)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = selectedPlayer.DisplayName
    nameLbl.TextColor3 = colors.text
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local countLbl = Instance.new("TextLabel", playerFrame)
    countLbl.Size = UDim2.new(1, -52, 0, 14)
    countLbl.Position = UDim2.new(0, 48, 0, 26)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = "📦 " .. #allItems .. " items ditemukan"
    countLbl.TextColor3 = colors.green
    countLbl.Font = Enum.Font.Gotham
    countLbl.TextSize = 8
    countLbl.TextXAlignment = Enum.TextXAlignment.Left

    tween(playerFrame, {BackgroundTransparency = 0}, 0.25)

    -- ==================== TAB SYSTEM ====================
    local tabFrame = Instance.new("Frame", appContent)
    tabFrame.Size = UDim2.new(1, 0, 0, 34)
    tabFrame.BackgroundColor3 = colors.card
    tabFrame.LayoutOrder = 1
    corner(tabFrame, 9)
    stroke(tabFrame, colors.border, 1, 0.3)

    local tabLayout = Instance.new("UIGridLayout", tabFrame)
    tabLayout.CellSize = UDim2.new(1/3, -4, 0, 28)
    tabLayout.CellPadding = UDim2.new(0, 4, 0, 0)

    local tabs = {
        {name = "Semua", filter = "ALL"},
        {name = "Body",  filter = "BODY"},
        {name = "Accs",  filter = "ACC"},
    }

    local tabButtons = {}

    -- ==================== GRID CONTAINER ====================
    local gridContainer = Instance.new("Frame", appContent)
    gridContainer.Size = UDim2.new(1, 0, 0, 0)
    gridContainer.AutomaticSize = Enum.AutomaticSize.Y
    gridContainer.BackgroundColor3 = colors.gridBg
    gridContainer.LayoutOrder = 2
    corner(gridContainer, 12)
    stroke(gridContainer, colors.border, 1, 0.3)

    local gridPadding = Instance.new("UIPadding", gridContainer)
    gridPadding.PaddingLeft   = UDim.new(0, 7)
    gridPadding.PaddingRight  = UDim.new(0, 7)
    gridPadding.PaddingTop    = UDim.new(0, 7)
    gridPadding.PaddingBottom = UDim.new(0, 7)

    local gridLayout = Instance.new("UIGridLayout", gridContainer)
    gridLayout.CellSize = UDim2.new(0.5, -5, 0, 150)
    gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- ==================== FILTER ====================
    local function getFilteredItems(filterType)
        if filterType == "ALL" then
            return allItems
        end

        local filtered = {}
        for _, item in ipairs(allItems) do
            if item.Type == filterType then
                table.insert(filtered, item)
            end
        end
        return filtered
    end

    -- ==================== BUILD SATU CARD ====================
    local function buildCard(item, index)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 0, 0, 150)
        card.BackgroundColor3 = colors.card
        card.BackgroundTransparency = 1 -- mulai transparan, fade-in
        card.LayoutOrder = index
        corner(card, 11)
        stroke(card, colors.border, 1, 0.3)

        local imgContainer = Instance.new("Frame", card)
        imgContainer.Size = UDim2.new(0, 60, 0, 60)
        imgContainer.Position = UDim2.new(0.5, -30, 0, 8)
        imgContainer.BackgroundColor3 = colors.card2
        corner(imgContainer, 9)

        local thumb = Instance.new("ImageLabel", imgContainer)
        thumb.Size = UDim2.new(1, -6, 1, -6)
        thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
        thumb.AnchorPoint = Vector2.new(0.5, 0.5)
        thumb.BackgroundColor3 = colors.card2
        thumb.BackgroundTransparency = 1
        thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.Value .. "&width=150&height=150&format=png"
        thumb.ScaleType = Enum.ScaleType.Fit
        corner(thumb, 7)

        local idLabel = Instance.new("TextLabel", card)
        idLabel.Size = UDim2.new(1, -12, 0, 14)
        idLabel.Position = UDim2.new(0, 6, 0, 70)
        idLabel.BackgroundTransparency = 1
        idLabel.Text = item.Value
        idLabel.TextColor3 = colors.text3
        idLabel.Font = Enum.Font.Code
        idLabel.TextSize = 8
        idLabel.TextXAlignment = Enum.TextXAlignment.Center

        local itemName = Instance.new("TextLabel", card)
        itemName.Size = UDim2.new(1, -12, 0, 14)
        itemName.Position = UDim2.new(0, 6, 0, 85)
        itemName.BackgroundTransparency = 1
        itemName.Text = item.Label
        itemName.TextColor3 = colors.text
        itemName.Font = Enum.Font.GothamBold
        itemName.TextSize = 7
        itemName.TextXAlignment = Enum.TextXAlignment.Center
        itemName.TextTruncate = Enum.TextTruncate.AtEnd

        local typeBadge = Instance.new("TextLabel", card)
        typeBadge.Size = UDim2.new(0, 34, 0, 13)
        typeBadge.Position = UDim2.new(0.5, -17, 0, 101)
        typeBadge.BackgroundColor3 = item.Type == "BODY" and colors.accent or colors.card2
        typeBadge.BackgroundTransparency = item.Type == "BODY" and 0.8 or 0
        typeBadge.Text = item.Type
        typeBadge.TextColor3 = item.Type == "BODY" and colors.accent or colors.text3
        typeBadge.Font = Enum.Font.GothamBlack
        typeBadge.TextSize = 6
        corner(typeBadge, 6)

        local copyBtn = Instance.new("TextButton", card)
        copyBtn.Size = UDim2.new(0, 47, 0, 21)
        copyBtn.Position = UDim2.new(0.5, -50, 0, 122)
        copyBtn.BackgroundColor3 = colors.card2
        copyBtn.Text = "Copy"
        copyBtn.TextColor3 = colors.text
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 7
        copyBtn.AutoButtonColor = false
        corner(copyBtn, 6)
        stroke(copyBtn, colors.border, 1, 0.3)
        pressFX(copyBtn)

        copyBtn.MouseButton1Click:Connect(function()
            pcall(function() Helpers.copyToClipboard(item.Value) end)
            if _G.showDynamicNotification then
                _G.showDynamicNotification("ID disalin: " .. item.Value, colors.accent)
            end
        end)

        local wearBtn = Instance.new("TextButton", card)
        wearBtn.Size = UDim2.new(0, 47, 0, 21)
        wearBtn.Position = UDim2.new(0.5, 3, 0, 122)
        wearBtn.BackgroundColor3 = colors.accent
        wearBtn.Text = "Wear"
        wearBtn.TextColor3 = Color3.fromRGB(10, 10, 15)
        wearBtn.Font = Enum.Font.GothamBold
        wearBtn.TextSize = 7
        wearBtn.AutoButtonColor = false
        corner(wearBtn, 6)
        pressFX(wearBtn)

        wearBtn.MouseButton1Click:Connect(function()
            fireHat({item.Value})
            if _G.showDynamicNotification then
                _G.showDynamicNotification("Memakai " .. item.Label, colors.green)
            end
        end)

        return card
    end

    -- ==================== RENDER GRID (STAGGERED — FIX FRAME DROP UTAMA) ====================
    -- Sebelumnya: 20 card (140 instance) dibuat dalam SATU frame render, bikin freeze.
    -- Sekarang: render per-batch kecil (4 card per batch) dengan task.wait() di antaranya,
    -- jadi beban dipecah ke beberapa frame dan tidak terasa nge-lag.
    local renderToken = 0

    local function renderGrid(filterType)
        renderToken = renderToken + 1
        local myRenderToken = renderToken

        for _, c in ipairs(gridContainer:GetChildren()) do
            if not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end

        local filteredItems = getFilteredItems(filterType)

        if #filteredItems == 0 then
            local empty = Instance.new("TextLabel", gridContainer)
            empty.Size = UDim2.new(1, 0, 0, 50)
            empty.BackgroundTransparency = 1
            empty.Text = "Tidak ada item di tab ini"
            empty.TextColor3 = colors.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 10
            empty.TextXAlignment = Enum.TextXAlignment.Center
            empty.LayoutOrder = 0
            return
        end

        local maxShow = math.min(20, #filteredItems)
        local BATCH_SIZE = 4 -- render 4 card per "napas", jauh lebih ringan dari 20 sekaligus

        task.spawn(function()
            local i = 1
            while i <= maxShow do
                -- Batalkan render kalau ada render baru yang menimpa (misal ganti tab cepat)
                if myRenderToken ~= renderToken then return end

                local batchEnd = math.min(i + BATCH_SIZE - 1, maxShow)
                for idx = i, batchEnd do
                    local item = filteredItems[idx]
                    local card = buildCard(item, idx)
                    card.Parent = gridContainer
                    -- Fade-in halus per card, tidak nge-block (tween async)
                    tween(card, {BackgroundTransparency = 0}, 0.18)
                end

                i = batchEnd + 1
                if i <= maxShow then
                    task.wait() -- kasih 1 frame napas sebelum lanjut batch berikutnya
                end
            end

            if #filteredItems > maxShow then
                local moreLbl = Instance.new("TextLabel", gridContainer)
                moreLbl.Size = UDim2.new(1, 0, 0, 22)
                moreLbl.BackgroundTransparency = 1
                moreLbl.Text = "+" .. (#filteredItems - maxShow) .. " item lainnya (tidak ditampilkan)"
                moreLbl.TextColor3 = colors.text3
                moreLbl.Font = Enum.Font.Gotham
                moreLbl.TextSize = 8
                moreLbl.LayoutOrder = 999
            end
        end)
    end

    -- ==================== SELECTION + CLONE CONTROLS ====================
    local selected = CloneLifecycle.selectedItems

    local controls = Instance.new("Frame", appContent)
    controls.Size = UDim2.new(1, 0, 0, 92)
    controls.BackgroundColor3 = colors.card
    controls.LayoutOrder = 3
    corner(controls, 12)
    stroke(controls, colors.border, 1, 0.25)

    local status = Instance.new("TextLabel", controls)
    status.Size = UDim2.new(1, -14, 0, 20)
    status.Position = UDim2.new(0, 7, 0, 6)
    status.BackgroundTransparency = 1
    status.TextColor3 = colors.text
    status.Font = Enum.Font.GothamBold
    status.TextSize = 9
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function selectedCount()
        local n = 0
        for _, v in pairs(selected) do if v then n += 1 end end
        return n
    end

    local function updateStatus()
        status.Text = string.format("%d / %d item dipilih", selectedCount(), #getFilteredItems(CloneLifecycle.currentTab))
    end

    local function makeControl(text, x, width)
        local b = Instance.new("TextButton", controls)
        b.Size = UDim2.new(0, width, 0, 28)
        b.Position = UDim2.new(0, x, 0, 34)
        b.BackgroundColor3 = colors.card2
        b.Text = text
        b.TextColor3 = colors.text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 8
        b.AutoButtonColor = false
        corner(b, 8)
        stroke(b, colors.border, 1, 0.25)
        pressFX(b)
        return b
    end

    local selectAllBtn = makeControl("✓ Pilih Semua", 7, 88)
    local clearBtn = makeControl("× Bersihkan", 101, 82)
    local cloneBtn = makeControl("⚡ Clone Terpilih", 189, 116)
    cloneBtn.BackgroundColor3 = colors.accent
    cloneBtn.TextColor3 = Color3.fromRGB(10, 10, 15)

    local function getFilteredItems(filterType)
        if filterType == "ALL" then return allItems end
        local filtered = {}
        for _, item in ipairs(allItems) do
            if item.Type == filterType then table.insert(filtered, item) end
        end
        return filtered
    end

    local function setSelected(item, value)
        selected[item.Value] = value
        updateStatus()
    end

    selectAllBtn.MouseButton1Click:Connect(function()
        for _, item in ipairs(getFilteredItems(CloneLifecycle.currentTab)) do
            selected[item.Value] = true
        end
        updateStatus()
        if _G.showDynamicNotification then _G.showDynamicNotification("Item dipilih", colors.accent) end
        renderGrid(CloneLifecycle.currentTab)
    end)

    clearBtn.MouseButton1Click:Connect(function()
        for _, item in ipairs(getFilteredItems(CloneLifecycle.currentTab)) do
            selected[item.Value] = nil
        end
        updateStatus()
        renderGrid(CloneLifecycle.currentTab)
    end)

    cloneBtn.MouseButton1Click:Connect(function()
        if CloneLifecycle.isCloning then return end
        local chosen = {}
        for _, item in ipairs(getFilteredItems("ALL")) do
            if selected[item.Value] then table.insert(chosen, item) end
        end
        if #chosen == 0 then
            if _G.showDynamicNotification then _G.showDynamicNotification("Pilih minimal 1 item", colors.text3) end
            return
        end
        CloneLifecycle.isCloning = true
        cloneBtn.Text = "Cloning 0/" .. #chosen
        cloneBtn.BackgroundColor3 = colors.card2
        cloneItems(chosen, function(done, batchNum, totalBatches)
            if done then
                CloneLifecycle.isCloning = false
                cloneBtn.Text = "✓ Selesai"
                cloneBtn.BackgroundColor3 = colors.green
                if _G.showDynamicNotification then _G.showDynamicNotification(#chosen .. " item berhasil diproses", colors.green) end
                task.delay(1.5, function()
                    if cloneBtn.Parent then cloneBtn.BackgroundColor3 = colors.accent; cloneBtn.Text = "⚡ Clone Terpilih" end
                end)
            else
                cloneBtn.Text = string.format("Cloning %d/%d", batchNum, totalBatches)
            end
        end)
    end)

    -- ==================== BUILD TABS ====================
    for _, tab in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton", tabFrame)
        tabBtn.Size = UDim2.new(1, 0, 0, 28)
        tabBtn.BackgroundColor3 = tab.filter == "ALL" and colors.tabActive or colors.tabInactive
        tabBtn.Text = tab.name
        tabBtn.TextColor3 = tab.filter == "ALL" and Color3.fromRGB(10, 10, 15) or colors.text2
        tabBtn.Font = Enum.Font.GothamBlack
        tabBtn.TextSize = 8
        tabBtn.AutoButtonColor = false
        corner(tabBtn, 8)
        pressFX(tabBtn)
        tabBtn.MouseButton1Click:Connect(function()
            CloneLifecycle.currentTab = tab.filter
            for _, btn in ipairs(tabButtons) do tween(btn, {BackgroundColor3 = colors.tabInactive}, 0.15); btn.TextColor3 = colors.text2 end
            tween(tabBtn, {BackgroundColor3 = colors.tabActive}, 0.15)
            tabBtn.TextColor3 = Color3.fromRGB(10, 10, 15)
            renderGrid(tab.filter)
            updateStatus()
        end)
        table.insert(tabButtons, tabBtn)
    end

    -- Initial selection state: KOSONG. User harus memilih item secara manual.
    for _, item in ipairs(allItems) do selected[item.Value] = nil end

    -- ==================== SELECTION CARD OVERLAY ====================
    -- buildCard diubah agar klik card melakukan toggle pilihan.
    -- Tombol Wear/Copy tetap tersedia.
    local oldBuildCard = buildCard
    buildCard = function(item, index)
        local card = oldBuildCard(item, index)
        local selectedMark = Instance.new("TextLabel", card)
        selectedMark.Name = "SelectedMark"
        selectedMark.Size = UDim2.new(0, 22, 0, 22)
        selectedMark.Position = UDim2.new(0, 5, 0, 5)
        selectedMark.BackgroundColor3 = colors.accent
        selectedMark.Text = "✓"
        selectedMark.TextColor3 = Color3.fromRGB(10, 10, 15)
        selectedMark.Font = Enum.Font.GothamBlack
        selectedMark.TextSize = 10
        selectedMark.Visible = selected[item.Value] == true
        corner(selectedMark, 7)

        local selectBtn = Instance.new("TextButton", card)
        selectBtn.Name = "SelectOverlay"
        selectBtn.Size = UDim2.new(1, 0, 0, 112)
        selectBtn.Position = UDim2.new(0, 0, 0, 0)
        selectBtn.BackgroundTransparency = 1
        selectBtn.Text = ""
        selectBtn.ZIndex = 5
        selectBtn.AutoButtonColor = false
        selectBtn.MouseButton1Click:Connect(function()
            setSelected(item, not selected[item.Value])
            selectedMark.Visible = selected[item.Value] == true
            tween(card, {BackgroundColor3 = selected[item.Value] and colors.card2 or colors.card}, 0.12)
        end)
        return card
    end

    updateStatus()
    -- Initial render: tidak ada item yang otomatis dipilih.
    renderGrid("ALL")
end

print("[Clone] App loaded! (frame-drop fixed, UI upgraded)")
