-- ================================================
-- SERVERLIST.LUA — Server Browser (Fastest Ping / Lowest / Max Players)
-- Ambil daftar server publik dari game yang SAMA (game.PlaceId),
-- lalu join langsung lewat TeleportService.
-- ================================================

local Services       = _G.Services
local LocalPlayer    = _G.LocalPlayer
local TeleportService = Services.TeleportService
local Helpers        = _G.Helpers or {}
local appContent     = _G.appContent
local HttpService    = game:GetService("HttpService")

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local pressFX = Helpers.pressFX

local C = {
    bg      = Color3.fromRGB(10, 12, 20),
    card    = Color3.fromRGB(16, 18, 28),
    card2   = Color3.fromRGB(22, 24, 36),
    border  = Color3.fromRGB(40, 60, 100),
    text    = Color3.fromRGB(240, 240, 250),
    text2   = Color3.fromRGB(150, 155, 175),
    text3   = Color3.fromRGB(90, 95, 115),
    accent  = Color3.fromRGB(60, 130, 255),
    green   = Color3.fromRGB(60, 190, 110),
    red     = Color3.fromRGB(255, 90, 100),
}

-- ==================== STATE ====================
local currentSort = "ping" -- "ping" | "lowest" | "max"
local allServers  = {}
local isLoading   = false

-- ==================== FETCH SERVER LIST ====================
-- Endpoint publik resmi Roblox untuk list server suatu place.
-- Ini domain Roblox (games.roblox.com), bukan API pihak ketiga.
local function fetchServerPage(cursor)
    local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
        .. "/servers/Public?sortOrder=Asc&limit=100"
    if cursor and cursor ~= "" then
        url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
    end

    local ok, result = pcall(function()
        local opts = {Url = url, Method = "GET"}
        if syn and syn.request then return syn.request(opts)
        elseif http_request then return http_request(opts)
        elseif request then return request(opts)
        else return {Body = game:HttpGet(url)} end
    end)

    if not ok or not result then return nil end
    local body = result.Body or result.body
    if not body then return nil end

    local dok, data = pcall(function() return HttpService:JSONDecode(body) end)
    return dok and data or nil
end

-- Ambil beberapa halaman sekaligus (Roblox API dibatasi 100 server per halaman)
local function fetchAllServers(maxPages)
    local servers = {}
    local cursor = nil
    local pages = 0
    maxPages = maxPages or 3 -- ambil sampai ~300 server, cukup untuk kebanyakan game

    repeat
        local page = fetchServerPage(cursor)
        if not page or not page.data then break end

        for _, srv in ipairs(page.data) do
            table.insert(servers, {
                id        = srv.id,
                playing   = srv.playing or 0,
                maxPlayers = srv.maxPlayers or 0,
                ping      = srv.ping or 999,
                fps       = srv.fps,
                region    = srv.playerTokens and "Unknown" or "Unknown", -- Roblox API publik tidak selalu kasih region asli
            })
        end

        cursor = page.nextPageCursor
        pages = pages + 1
    until not cursor or cursor == "" or pages >= maxPages

    return servers
end

-- ==================== SORT ====================
local function sortServers(list, mode)
    local sorted = {}
    for _, s in ipairs(list) do table.insert(sorted, s) end

    if mode == "ping" then
        table.sort(sorted, function(a,b) return a.ping < b.ping end)
    elseif mode == "lowest" then
        table.sort(sorted, function(a,b) return a.playing < b.playing end)
    elseif mode == "max" then
        table.sort(sorted, function(a,b) return a.playing > b.playing end)
    end

    return sorted
end

-- ==================== JOIN SERVER ====================
local function joinServer(jobId)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
    if not ok and _G.showDynamicNotification then
        _G.showDynamicNotification("Gagal join server: " .. tostring(err), C.red)
    end
end

-- ==================== BUKA APP ====================
function _G.openServerListApp()
    -- ===== HEADER =====
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,0)
    header.AutomaticSize = Enum.AutomaticSize.Y
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 14)
    stroke(header, C.accent, 1.5, 0.3)

    local hPad = Instance.new("UIPadding", header)
    hPad.PaddingTop = UDim.new(0,10); hPad.PaddingBottom = UDim.new(0,10)
    hPad.PaddingLeft = UDim.new(0,14); hPad.PaddingRight = UDim.new(0,44)

    local hLayout = Instance.new("UIListLayout", header)
    hLayout.Padding = UDim.new(0,10)

    -- Baris judul + close (X sudah otomatis disediakan sistem app kamu, jadi cukup judul)
    local titleRow = Instance.new("TextLabel", header)
    titleRow.Size = UDim2.new(1,0,0,20)
    titleRow.BackgroundTransparency = 1
    titleRow.Text = "Current Game: SERVER LIST"
    titleRow.TextColor3 = C.text
    titleRow.Font = Enum.Font.GothamBlack
    titleRow.TextSize = 14
    titleRow.LayoutOrder = 0

    -- Baris tombol sort
    local sortRow = Instance.new("Frame", header)
    sortRow.Size = UDim2.new(1,0,0,32)
    sortRow.BackgroundTransparency = 1
    sortRow.LayoutOrder = 1

    local sortLayout = Instance.new("UIListLayout", sortRow)
    sortLayout.FillDirection = Enum.FillDirection.Horizontal
    sortLayout.Padding = UDim.new(0,6)

    local sortButtons = {}
    local function refreshSortButtonStyle()
        for mode, btn in pairs(sortButtons) do
            local active = (mode == currentSort)
            btn.BackgroundColor3 = active and C.accent or C.card2
            btn.TextColor3 = active and Color3.new(1,1,1) or C.text2
        end
    end

    local function makeSortBtn(label, mode)
        local btn = Instance.new("TextButton", sortRow)
        btn.Size = UDim2.new(0, 0, 1, 0)
        btn.AutomaticSize = Enum.AutomaticSize.X
        btn.BackgroundColor3 = C.card2
        btn.Text = ""
        btn.AutoButtonColor = false
        corner(btn, 8)

        local pad = Instance.new("UIPadding", btn)
        pad.PaddingLeft = UDim.new(0,14); pad.PaddingRight = UDim.new(0,14)

        local lbl = Instance.new("TextLabel", btn)
        lbl.Size = UDim2.new(0,0,1,0)
        lbl.AutomaticSize = Enum.AutomaticSize.X
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = C.text2
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11

        sortButtons[mode] = btn
        pressFX(btn)
        return btn, lbl
    end

    -- ===== INFO BAR (jumlah server + refresh) =====
    local infoRow = Instance.new("Frame", header)
    infoRow.Size = UDim2.new(1,0,0,24)
    infoRow.BackgroundTransparency = 1
    infoRow.LayoutOrder = 2

    local infoLbl = Instance.new("TextLabel", infoRow)
    infoLbl.Size = UDim2.new(1,-90,1,0)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Text = "Memuat server..."
    infoLbl.TextColor3 = C.text3
    infoLbl.Font = Enum.Font.Gotham
    infoLbl.TextSize = 10
    infoLbl.TextXAlignment = Enum.TextXAlignment.Left

    local refreshBtn = Instance.new("TextButton", infoRow)
    refreshBtn.Size = UDim2.new(0,80,1,0)
    refreshBtn.Position = UDim2.new(1,-80,0,0)
    refreshBtn.BackgroundColor3 = C.card2
    refreshBtn.Text = "🔄 Refresh"
    refreshBtn.TextColor3 = C.text2
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 10
    refreshBtn.AutoButtonColor = false
    corner(refreshBtn, 8)
    pressFX(refreshBtn)

    -- ===== LIST SERVER =====
    local listScroll = Instance.new("ScrollingFrame", appContent)
    listScroll.Size = UDim2.new(1,0,0,340)
    listScroll.BackgroundColor3 = C.bg
    listScroll.BorderSizePixel = 0
    listScroll.CanvasSize = UDim2.new(0,0,0,0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ScrollBarThickness = 3
    listScroll.ScrollBarImageColor3 = C.accent
    listScroll.LayoutOrder = 1
    corner(listScroll, 14)
    stroke(listScroll, C.accent, 1.5, 0.3)

    local listPad = Instance.new("UIPadding", listScroll)
    listPad.PaddingTop = UDim.new(0,8); listPad.PaddingBottom = UDim.new(0,8)
    listPad.PaddingLeft = UDim.new(0,8); listPad.PaddingRight = UDim.new(0,8)

    local listLayout = Instance.new("UIListLayout", listScroll)
    listLayout.Padding = UDim.new(0,6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- ===== RENDER SATU BARIS SERVER =====
    local function renderServerRow(srv, order)
        local row = Instance.new("Frame", listScroll)
        row.Size = UDim2.new(1,0,0,52)
        row.BackgroundColor3 = C.card
        row.LayoutOrder = order
        corner(row, 10)
        stroke(row, C.border, 1, 0.4)

        local numLbl = Instance.new("TextLabel", row)
        numLbl.Size = UDim2.new(0,26,1,0)
        numLbl.Position = UDim2.new(0,8,0,0)
        numLbl.BackgroundTransparency = 1
        numLbl.Text = tostring(order)
        numLbl.TextColor3 = C.text3
        numLbl.Font = Enum.Font.GothamBold
        numLbl.TextSize = 11
        numLbl.TextXAlignment = Enum.TextXAlignment.Left

        local playersLbl = Instance.new("TextLabel", row)
        playersLbl.Size = UDim2.new(0,70,0,18)
        playersLbl.Position = UDim2.new(0,36,0,7)
        playersLbl.BackgroundTransparency = 1
        playersLbl.Text = srv.playing .. "/" .. srv.maxPlayers
        playersLbl.TextColor3 = C.text
        playersLbl.Font = Enum.Font.GothamBold
        playersLbl.TextSize = 12
        playersLbl.TextXAlignment = Enum.TextXAlignment.Left

        local pingColor = srv.ping < 100 and C.green or (srv.ping < 250 and Color3.fromRGB(255,190,60) or C.red)
        local pingLbl = Instance.new("TextLabel", row)
        pingLbl.Size = UDim2.new(0,70,0,14)
        pingLbl.Position = UDim2.new(0,36,0,27)
        pingLbl.BackgroundTransparency = 1
        pingLbl.Text = "Ping: " .. tostring(srv.ping)
        pingLbl.TextColor3 = pingColor
        pingLbl.Font = Enum.Font.Gotham
        pingLbl.TextSize = 9
        pingLbl.TextXAlignment = Enum.TextXAlignment.Left

        local joinBtn = Instance.new("TextButton", row)
        joinBtn.Size = UDim2.new(0,64,0,32)
        joinBtn.Position = UDim2.new(1,-72,0.5,-16)
        joinBtn.BackgroundColor3 = C.green
        joinBtn.Text = "Join"
        joinBtn.TextColor3 = Color3.new(1,1,1)
        joinBtn.Font = Enum.Font.GothamBlack
        joinBtn.TextSize = 12
        joinBtn.AutoButtonColor = false
        corner(joinBtn, 9)
        pressFX(joinBtn)
        joinBtn.MouseButton1Click:Connect(function()
            joinBtn.Text = "..."
            joinServer(srv.id)
        end)
    end

    local function renderList()
        for _, c in ipairs(listScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end

        local sorted = sortServers(allServers, currentSort)
        infoLbl.Text = "Loaded " .. #sorted .. " servers."

        for i, srv in ipairs(sorted) do
            renderServerRow(srv, i)
            if i >= 60 then break end -- batasi render biar tidak berat di UI
        end
    end

    local function loadServers()
        if isLoading then return end
        isLoading = true
        infoLbl.Text = "Memuat server..."
        refreshBtn.Text = "..."

        task.spawn(function()
            allServers = fetchAllServers(3)
            isLoading = false
            refreshBtn.Text = "🔄 Refresh"
            renderList()
        end)
    end

    -- Sort buttons
    local pingBtn = makeSortBtn("Fastest Ping", "ping")
    local lowestBtn = makeSortBtn("Lowest Players", "lowest")
    local maxBtn = makeSortBtn("Max Players", "max")

    local function setSort(mode)
        currentSort = mode
        refreshSortButtonStyle()
        renderList()
    end

    pingBtn.MouseButton1Click:Connect(function() setSort("ping") end)
    lowestBtn.MouseButton1Click:Connect(function() setSort("lowest") end)
    maxBtn.MouseButton1Click:Connect(function() setSort("max") end)
    refreshBtn.MouseButton1Click:Connect(loadServers)

    refreshSortButtonStyle()
    loadServers()
end

print("[ServerList] Loaded!")