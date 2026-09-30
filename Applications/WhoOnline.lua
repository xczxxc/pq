-- ================================================
-- WHO'S ONLINE APP - Dark Theme
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players = Services.Players
local HttpService = Services.HttpService
local TeleportService = Services.TeleportService
local T = _G.T
local Helpers = _G.Helpers
local Firebase = _G.Firebase
local Config = _G.Config

local appContent = _G.appContent
local appTitle = _G.appTitle

local corner = Helpers.corner
local stroke = Helpers.stroke
local tween = Helpers.tween
local pressFX = Helpers.pressFX

-- ==================== DARK THEME ====================
local colors = {
    card = Color3.fromRGB(25, 25, 32),
    card2 = Color3.fromRGB(30, 30, 38),
    cardHover = Color3.fromRGB(35, 35, 45),
    accent = Color3.fromRGB(255, 255, 255),
    accent2 = Color3.fromRGB(0, 200, 255),
    gold = Color3.fromRGB(255, 180, 50),
    green = Color3.fromRGB(0, 230, 118),
    red = Color3.fromRGB(255, 82, 82),
    text = Color3.fromRGB(255, 255, 255),
    text2 = Color3.fromRGB(170, 170, 180),
    text3 = Color3.fromRGB(100, 100, 115),
    border = Color3.fromRGB(45, 45, 55),
    blue = Color3.fromRGB(80, 150, 255),
    orange = Color3.fromRGB(255, 140, 20),
}

local IS_DEV = (Config.DEVELOPER_USER_ID and tostring(Config.DEVELOPER_USER_ID) == tostring(LocalPlayer.UserId))

-- ==================== LIFECYCLE ====================
local WhoOnlineLifecycle = {
    active = false,
    tasks = {},
    connections = {},
}

local function cleanupWhoOnline()
    WhoOnlineLifecycle.active = false
    for _, task in ipairs(WhoOnlineLifecycle.tasks) do
        pcall(function() task.cancel() end)
    end
    WhoOnlineLifecycle.tasks = {}
    for _, conn in ipairs(WhoOnlineLifecycle.connections) do
        pcall(function() conn:Disconnect() end)
    end
    WhoOnlineLifecycle.connections = {}
end

table.insert(_G.AvatarCloneCleanupTasks or {}, cleanupWhoOnline)

-- ==================== FIREBASE HELPERS ====================
local function firebaseGet(path)
    if Firebase and Firebase.GetData then
        return Firebase.GetData(path)
    end
    return nil
end

-- ==================== OPEN WHO'S ONLINE APP ====================
function _G.openWhoOnlineApp()
    cleanupWhoOnline()
    WhoOnlineLifecycle.active = true
    
    -- ==================== HEADER ====================
    local headerCard = Instance.new("Frame", appContent)
    headerCard.Size = UDim2.new(1, 0, 0, 50)
    headerCard.BackgroundColor3 = colors.card
    headerCard.LayoutOrder = 0
    corner(headerCard, 14)
    stroke(headerCard, colors.border, 1, 0.3)

    local headerGradient = Instance.new("UIGradient", headerCard)
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 28, 42)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 24))
    })
    headerGradient.Rotation = 135

    local headerAccent = Instance.new("Frame", headerCard)
    headerAccent.Size = UDim2.new(1, 0, 0, 2)
    headerAccent.BackgroundColor3 = colors.green
    corner(headerAccent, 1)

    local headerTitle = Instance.new("TextLabel", headerCard)
    headerTitle.Size = UDim2.new(1, -24, 0, 22)
    headerTitle.Position = UDim2.new(0, 12, 0, 6)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "Who's Online"
    headerTitle.TextColor3 = colors.text
    headerTitle.Font = Enum.Font.GothamBlack
    headerTitle.TextSize = 14
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left

    local headerSub = Instance.new("TextLabel", headerCard)
    headerSub.Size = UDim2.new(1, -24, 0, 14)
    headerSub.Position = UDim2.new(0, 12, 0, 30)
    headerSub.BackgroundTransparency = 1
    headerSub.Text = IS_DEV and "DEV MODE - Pull member ke server kamu" or "Member yang sedang online"
    headerSub.TextColor3 = IS_DEV and colors.gold or colors.text2
    headerSub.Font = Enum.Font.GothamBold
    headerSub.TextSize = 8
    headerSub.TextXAlignment = Enum.TextXAlignment.Left

    -- Refresh button
    local refreshBtn = Instance.new("TextButton", headerCard)
    refreshBtn.Size = UDim2.new(0, 64, 0, 24)
    refreshBtn.Position = UDim2.new(1, -76, 0.5, -12)
    refreshBtn.BackgroundColor3 = colors.green
    refreshBtn.Text = "Refresh"
    refreshBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 10
    refreshBtn.AutoButtonColor = false
    corner(refreshBtn, 8)
    pressFX(refreshBtn)

    -- ==================== PULL ALL BUTTON (DEV ONLY) ====================
    local pullAllBtn = nil
    if IS_DEV then
        pullAllBtn = Instance.new("TextButton", appContent)
        pullAllBtn.Size = UDim2.new(1, 0, 0, 36)
        pullAllBtn.BackgroundColor3 = colors.orange
        pullAllBtn.Text = "PULL ALL MEMBERS"
        pullAllBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        pullAllBtn.Font = Enum.Font.GothamBlack
        pullAllBtn.TextSize = 12
        pullAllBtn.AutoButtonColor = false
        pullAllBtn.LayoutOrder = 0
        corner(pullAllBtn, 10)
        pressFX(pullAllBtn)
    end

    -- ==================== LIST HOLDER ====================
    local listHolder = Instance.new("Frame", appContent)
    listHolder.Size = UDim2.new(1, 0, 0, 0)
    listHolder.AutomaticSize = Enum.AutomaticSize.Y
    listHolder.BackgroundTransparency = 1
    listHolder.LayoutOrder = 1

    local listLayout = Instance.new("UIListLayout", listHolder)
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- ==================== RENDER FUNCTION ====================
    local function renderOnlinePlayers()
        for _, c in ipairs(listHolder:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        -- Loading indicator
        local loadCard = Instance.new("Frame", listHolder)
        loadCard.Size = UDim2.new(1, 0, 0, 36)
        loadCard.BackgroundColor3 = colors.card2
        loadCard.LayoutOrder = 0
        corner(loadCard, 10)

        local loadText = Instance.new("TextLabel", loadCard)
        loadText.Size = UDim2.new(1, 0, 1, 0)
        loadText.BackgroundTransparency = 1
        loadText.Text = "Fetching data..."
        loadText.TextColor3 = colors.text3
        loadText.Font = Enum.Font.Gotham
        loadText.TextSize = 10

        task.spawn(function()
            local data = firebaseGet("online")
            pcall(function() loadCard:Destroy() end)

            local now = os.time()
            local onlineList = {}

            if data and type(data) == "table" then
                for _, player in pairs(data) do
                    local lastUpdate = tonumber(player.lastUpdate) or 0
                    if (now - lastUpdate) < 120 then
                        table.insert(onlineList, player)
                    end
                end
            end

            -- Sort: dev dulu, lalu alphabetical
            table.sort(onlineList, function(a, b)
                if a.isDev ~= b.isDev then return a.isDev end
                return (a.displayName or a.name or "") < (b.displayName or b.name or "")
            end)

            -- Counter
            local counterFrame = Instance.new("Frame", listHolder)
            counterFrame.Size = UDim2.new(1, 0, 0, 22)
            counterFrame.BackgroundTransparency = 1
            counterFrame.LayoutOrder = 0

            local counterText = Instance.new("TextLabel", counterFrame)
            counterText.Size = UDim2.new(1, 0, 1, 0)
            counterText.BackgroundTransparency = 1
            counterText.Text = #onlineList .. " member online sekarang"
            counterText.TextColor3 = colors.green
            counterText.Font = Enum.Font.GothamBold
            counterText.TextSize = 10
            counterText.TextXAlignment = Enum.TextXAlignment.Left

            -- Pull All handler
            if IS_DEV and pullAllBtn then
                pullAllBtn.MouseButton1Click:Connect(function()
                    local count = 0
                    for _, player in ipairs(onlineList) do
                        local isMe = tostring(player.userId) == tostring(LocalPlayer.UserId)
                        if not isMe then
                            pcall(function() 
                                if Firebase and Firebase.SendNotification then
                                    Firebase.SendNotification(
                                        player.userId,
                                        "Pull Request",
                                        "Dev mengundangmu ke server!",
                                        LocalPlayer.DisplayName or LocalPlayer.Name
                                    )
                                end
                            end)
                            count = count + 1
                            task.wait(0.3)
                        end
                    end
                    pullAllBtn.Text = "Sent to " .. count .. " members"
                    pullAllBtn.BackgroundColor3 = colors.green
                    _G.showDynamicNotification("Pull sent to " .. count .. " members!", colors.orange)
                    task.wait(3)
                    pullAllBtn.Text = "PULL ALL MEMBERS"
                    pullAllBtn.BackgroundColor3 = colors.orange
                end)
            end

            -- Empty state
            if #onlineList == 0 then
                local emptyCard = Instance.new("Frame", listHolder)
                emptyCard.Size = UDim2.new(1, 0, 0, 90)
                emptyCard.BackgroundColor3 = colors.card
                emptyCard.LayoutOrder = 1
                corner(emptyCard, 14)
                stroke(emptyCard, colors.border, 1, 0.3)

                local emptyText = Instance.new("TextLabel", emptyCard)
                emptyText.Size = UDim2.new(1, 0, 1, 0)
                emptyText.BackgroundTransparency = 1
                emptyText.Text = "Belum ada member online\nLoad script dulu di game!"
                emptyText.TextColor3 = colors.text3
                emptyText.Font = Enum.Font.GothamBold
                emptyText.TextSize = 12
                emptyText.TextWrapped = true
                return
            end

            -- Render tiap player
            for i, player in ipairs(onlineList) do
                local isSameServer = (player.jobId == game.JobId)
                local isSamePlace = (tostring(player.placeId) == tostring(game.PlaceId))
                local isMe = (tostring(player.userId) == tostring(LocalPlayer.UserId))
                local isPlayerDev = player.isDev == true

                local cardHeight = (IS_DEV and not isMe) and 100 or 86

                local card = Instance.new("Frame", listHolder)
                card.Size = UDim2.new(1, 0, 0, cardHeight)
                card.BackgroundColor3 = colors.card
                card.LayoutOrder = i
                corner(card, 14)

                -- Border warna berdasarkan status
                if isMe then
                    stroke(card, colors.blue, 2, 0)
                elseif isSameServer then
                    stroke(card, colors.green, 2, 0)
                elseif isPlayerDev then
                    stroke(card, colors.gold, 2, 0)
                else
                    stroke(card, colors.border, 1, 0.3)
                end

                -- Avatar
                local avatarFrame = Instance.new("Frame", card)
                avatarFrame.Size = UDim2.new(0, 52, 0, 52)
                avatarFrame.Position = UDim2.new(0, 10, 0.5, -26)
                avatarFrame.BackgroundColor3 = colors.card2
                corner(avatarFrame, 100)

                local avatarImg = Instance.new("ImageLabel", avatarFrame)
                avatarImg.Size = UDim2.new(1, -4, 1, -4)
                avatarImg.Position = UDim2.new(0.5, 0, 0.5, 0)
                avatarImg.AnchorPoint = Vector2.new(0.5, 0.5)
                avatarImg.BackgroundColor3 = colors.card2
                avatarImg.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. (player.userId or 0) .. "&width=100&height=100&format=png"
                corner(avatarImg, 100)

                -- Online dot
                local dot = Instance.new("Frame", card)
                dot.Size = UDim2.new(0, 10, 0, 10)
                dot.Position = UDim2.new(0, 48, 0.5, 14)
                dot.BackgroundColor3 = colors.green
                corner(dot, 100)
                stroke(dot, colors.card, 2, 0)

                -- DEV badge
                if isPlayerDev then
                    local devTag = Instance.new("Frame", card)
                    devTag.Size = UDim2.new(0, 28, 0, 12)
                    devTag.Position = UDim2.new(0, 10, 0, 8)
                    devTag.BackgroundColor3 = colors.gold
                    devTag.BackgroundTransparency = 0.2
                    devTag.ZIndex = 5
                    corner(devTag, 6)

                    local devTagText = Instance.new("TextLabel", devTag)
                    devTagText.Size = UDim2.new(1, 0, 1, 0)
                    devTagText.BackgroundTransparency = 1
                    devTagText.Text = "DEV"
                    devTagText.TextColor3 = colors.gold
                    devTagText.Font = Enum.Font.GothamBlack
                    devTagText.TextSize = 7
                    devTagText.ZIndex = 6
                end

                -- Name
                local nameLbl = Instance.new("TextLabel", card)
                nameLbl.Size = UDim2.new(1, -180, 0, 20)
                nameLbl.Position = UDim2.new(0, 70, 0, 10)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = (isMe and "(You) " or "") .. (player.displayName or player.name or "Unknown")
                nameLbl.TextColor3 = colors.text
                nameLbl.Font = Enum.Font.GothamBlack
                nameLbl.TextSize = 13
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

                -- Username
                local userLbl = Instance.new("TextLabel", card)
                userLbl.Size = UDim2.new(1, -180, 0, 14)
                userLbl.Position = UDim2.new(0, 70, 0, 30)
                userLbl.BackgroundTransparency = 1
                userLbl.Text = "@" .. (player.name or "?")
                userLbl.TextColor3 = colors.text2
                userLbl.Font = Enum.Font.Gotham
                userLbl.TextSize = 9
                userLbl.TextXAlignment = Enum.TextXAlignment.Left

                -- Server info
                local serverLbl = Instance.new("TextLabel", card)
                serverLbl.Size = UDim2.new(1, -180, 0, 14)
                serverLbl.Position = UDim2.new(0, 70, 0, 44)
                serverLbl.BackgroundTransparency = 1
                serverLbl.Text = isSameServer and "Server sama!" or (isSamePlace and "Map sama, beda server" or (player.mapName or "Unknown map"))
                serverLbl.TextColor3 = isSameServer and colors.green or colors.text3
                serverLbl.Font = Enum.Font.GothamBold
                serverLbl.TextSize = 8
                serverLbl.TextXAlignment = Enum.TextXAlignment.Left

                -- Last seen
                local elapsed = now - (tonumber(player.lastUpdate) or now)
                local elapsedText = elapsed < 60 and (elapsed .. "s ago") or (math.floor(elapsed / 60) .. "m ago")
                local timeLbl = Instance.new("TextLabel", card)
                timeLbl.Size = UDim2.new(1, -180, 0, 12)
                timeLbl.Position = UDim2.new(0, 70, 0, 58)
                timeLbl.BackgroundTransparency = 1
                timeLbl.Text = "Updated: " .. elapsedText
                timeLbl.TextColor3 = colors.text3
                timeLbl.Font = Enum.Font.Gotham
                timeLbl.TextSize = 7
                timeLbl.TextXAlignment = Enum.TextXAlignment.Left

                -- ==================== BUTTONS ====================
                if not isMe then
                    -- JOIN button
                    if isSamePlace and not isSameServer then
                        local joinBtn = Instance.new("TextButton", card)
                        joinBtn.Size = UDim2.new(0, 65, 0, 28)
                        joinBtn.Position = UDim2.new(1, -76, 0, 10)
                        joinBtn.BackgroundColor3 = colors.green
                        joinBtn.Text = "JOIN"
                        joinBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                        joinBtn.Font = Enum.Font.GothamBlack
                        joinBtn.TextSize = 11
                        joinBtn.AutoButtonColor = false
                        corner(joinBtn, 8)
                        pressFX(joinBtn)
                        
                        joinBtn.MouseButton1Click:Connect(function()
                            joinBtn.Text = "..."
                            joinBtn.BackgroundColor3 = colors.gold
                            pcall(function()
                                TeleportService:TeleportToPlaceInstance(
                                    tonumber(player.placeId) or game.PlaceId,
                                    player.jobId
                                )
                            end)
                            task.wait(1.5)
                            joinBtn.Text = "JOIN"
                            joinBtn.BackgroundColor3 = colors.green
                        end)
                    else
                        local diffMap = Instance.new("TextLabel", card)
                        diffMap.Size = UDim2.new(0, 65, 0, 28)
                        diffMap.Position = UDim2.new(1, -76, 0, 10)
                        diffMap.BackgroundColor3 = colors.card2
                        diffMap.Text = "Beda Map"
                        diffMap.TextColor3 = colors.text3
                        diffMap.Font = Enum.Font.GothamBold
                        diffMap.TextSize = 8
                        corner(diffMap, 8)
                        stroke(diffMap, colors.border, 1, 0.3)
                    end

                    -- PULL button (dev only)
                    if IS_DEV then
                        local pullBtn = Instance.new("TextButton", card)
                        pullBtn.Size = UDim2.new(0, 65, 0, 28)
                        pullBtn.Position = UDim2.new(1, -76, 0, 46)
                        pullBtn.BackgroundColor3 = colors.orange
                        pullBtn.Text = "PULL"
                        pullBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                        pullBtn.Font = Enum.Font.GothamBlack
                        pullBtn.TextSize = 10
                        pullBtn.AutoButtonColor = false
                        corner(pullBtn, 8)
                        pressFX(pullBtn)
                        
                        pullBtn.MouseButton1Click:Connect(function()
                            pullBtn.Text = "Sent!"
                            pullBtn.BackgroundColor3 = colors.green
                            pcall(function()
                                if Firebase and Firebase.SendNotification then
                                    Firebase.SendNotification(
                                        player.userId,
                                        "Pull Request",
                                        LocalPlayer.DisplayName .. " mengundangmu ke server!",
                                        LocalPlayer.DisplayName or LocalPlayer.Name
                                    )
                                end
                            end)
                            _G.showDynamicNotification("Pull sent to " .. (player.displayName or player.name or "?"), colors.orange)
                            task.wait(2)
                            pullBtn.Text = "PULL"
                            pullBtn.BackgroundColor3 = colors.orange
                        end)
                    end
                end
            end

            -- Timestamp
            local stampFrame = Instance.new("Frame", listHolder)
            stampFrame.Size = UDim2.new(1, 0, 0, 20)
            stampFrame.BackgroundTransparency = 1
            stampFrame.LayoutOrder = 999

            local stampText = Instance.new("TextLabel", stampFrame)
            stampText.Size = UDim2.new(1, 0, 1, 0)
            stampText.BackgroundTransparency = 1
            stampText.Text = "Last refresh: " .. os.date("%H:%M:%S")
            stampText.TextColor3 = colors.text3
            stampText.Font = Enum.Font.Gotham
            stampText.TextSize = 8
            stampText.TextXAlignment = Enum.TextXAlignment.Center
        end)
    end

    -- Auto refresh
    local autoRefreshTask = task.spawn(function()
        while WhoOnlineLifecycle.active and appContent.Parent do
            task.wait(30)
            if appTitle and appTitle.Text == "Who's Online" then
                renderOnlinePlayers()
            end
        end
    end)
    table.insert(WhoOnlineLifecycle.tasks, autoRefreshTask)

    -- Refresh button
    refreshBtn.MouseButton1Click:Connect(function()
        renderOnlinePlayers()
        _G.showDynamicNotification("Refreshed!", colors.green)
    end)

    -- Initial render
    renderOnlinePlayers()
end

print("[WhoOnline] App loaded!")