-- ================================================
-- APPLICATIONS/TELEPORT.LUA — Premium Monochrome + Purple Accent Teleport App
-- Features: Player List, Tap to Teleport, Spectator Mode
-- ================================================

local Services = _G.Services
local T = _G.T or {}
local Helpers = _G.Helpers or {}
local LocalPlayer = _G.LocalPlayer
local Storage = _G.Storage
local Firebase = _G.Firebase

-- ==================== CONSTANTS ====================
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(15, 15, 20)
local LIGHT_GRAY = Color3.fromRGB(247, 246, 250)
local MID_GRAY = Color3.fromRGB(200, 200, 210)
local DARK_GRAY = Color3.fromRGB(120, 118, 132)
local ACCENT = Color3.fromRGB(24, 22, 32)
local PURPLE = Color3.fromRGB(124, 58, 237)
local PURPLE_LIGHT = Color3.fromRGB(167, 120, 244)
local PURPLE_SOFT = Color3.fromRGB(237, 231, 250)
local GREEN = Color3.fromRGB(0, 200, 100)
local RED = Color3.fromRGB(255, 80, 80)

-- ==================== STATE ====================
local currentFilter = "all" -- all, friends, staff
local searchQuery = ""
local selectedPlayer = nil
local isSpectating = false
local spectateConnection = nil
local teleportHistory = {} -- {userId, displayName, name, placeId, jobId, timestamp}
local maxHistory = 20

-- ==================== HELPER FUNCTIONS ====================
local function getPlayerList()
    local players = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(players, player)
        end
    end
    return players
end

local function isFriend(userId)
    if Firebase and Firebase.IsFriend then
        local ok, result = pcall(function()
            return Firebase.IsFriend(LocalPlayer.UserId, userId)
        end)
        return ok and result or false
    end
    return false
end

local function getPlayerEmoji(player)
    -- Simple status indicator
    return "●"
end

local function formatDistance(seconds)
    if seconds < 60 then
        return string.format("%ds", seconds)
    elseif seconds < 3600 then
        return string.format("%dm", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%dh", math.floor(seconds / 3600))
    else
        return string.format("%dd", math.floor(seconds / 86400))
    end
end

local function getLastSeen(player)
    if Firebase and Firebase.GetLastSeen then
        local ok, lastSeen = pcall(function()
            return Firebase.GetLastSeen(player.UserId)
        end)
        if ok and lastSeen then
            local diff = os.time() - lastSeen
            return formatDistance(diff)
        end
    end
    return "Online"
end

-- ==================== SPECTATOR SYSTEM ====================
local function stopSpectating()
    if isSpectating then
        isSpectating = false
        if spectateConnection then
            spectateConnection:Disconnect()
            spectateConnection = nil
        end
        
        -- Restore camera to local player
        local camera = Services.Workspace.CurrentCamera
        if camera then
            camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") or LocalPlayer.Character
        end
        
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Spectator Off", RED)
        end
    end
end

local function startSpectating(targetPlayer)
    -- Stop previous spectating
    stopSpectating()
    
    if not targetPlayer or targetPlayer == LocalPlayer then return end
    
    isSpectating = true
    selectedPlayer = targetPlayer
    
    -- Set camera subject to target
    local camera = Services.Workspace.CurrentCamera
    if camera then
        local targetHumanoid = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
        if targetHumanoid then
            camera.CameraSubject = targetHumanoid
        end
    end
    
    -- Watch for target character changes
    spectateConnection = targetPlayer.CharacterAdded:Connect(function(character)
        if isSpectating and selectedPlayer == targetPlayer then
            local camera = Services.Workspace.CurrentCamera
            if camera then
                local humanoid = character:WaitForChild("Humanoid", 5)
                if humanoid then
                    camera.CameraSubject = humanoid
                end
            end
        end
    end)
    
    -- Watch for target leaving
    Services.Players.PlayerRemoving:Connect(function(player)
        if player == targetPlayer and isSpectating then
            stopSpectating()
        end
    end)
    
    if _G.showDynamicNotification then
        _G.showDynamicNotification("Spectating: " .. targetPlayer.DisplayName, GREEN)
    end
end

-- ==================== TELEPORT SYSTEM ====================
local function teleportToPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == LocalPlayer then return end
    
    -- Save to history
    table.insert(teleportHistory, {
        userId = targetPlayer.UserId,
        displayName = targetPlayer.DisplayName,
        name = targetPlayer.Name,
        placeId = game.PlaceId,
        jobId = game.JobId,
        timestamp = os.time()
    })
    
    -- Limit history
    while #teleportHistory > maxHistory do
        table.remove(teleportHistory, 1)
    end
    
    -- Save history to storage
    if Storage and Storage.appSettings then
        Storage.appSettings.teleportHistory = teleportHistory
        pcall(function()
            if Storage.persistSettings then Storage.persistSettings() end
        end)
    end
    
    -- Teleport to player's character
    local targetCharacter = targetPlayer.Character
    if not targetCharacter then
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Player not in game!", RED)
        end
        return
    end
    
    local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetHRP then
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Cannot find player position!", RED)
        end
        return
    end
    
    -- Teleport local player
    local localCharacter = LocalPlayer.Character
    local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    
    if localHRP then
        localHRP.CFrame = targetHRP.CFrame + Vector3.new(0, 3, 0)
        
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Teleported to " .. targetPlayer.DisplayName, GREEN)
        end
    else
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Your character not ready!", RED)
        end
    end
end

-- ==================== UI COMPONENTS ====================
local function createSearchBar(parent)
    local searchFrame = Instance.new("Frame", parent)
    searchFrame.Size = UDim2.new(1, 0, 0, 40)
    searchFrame.BackgroundColor3 = LIGHT_GRAY
    searchFrame.BorderSizePixel = 0
    searchFrame.LayoutOrder = 1
    Helpers.corner(searchFrame, 14)
    Helpers.stroke(searchFrame, PURPLE_SOFT, 1.5, 0.1)

    -- FIX BUG: TextBox tanpa clip bisa bikin teks placeholder/isi nongol
    -- keluar batas frame kalau font metric aneh. Clip memastikan teks
    -- selalu terkurung rapi di dalam search bar.
    searchFrame.ClipsDescendants = true
    
    local searchIcon = Instance.new("TextLabel", searchFrame)
    searchIcon.Size = UDim2.new(0, 30, 1, 0)
    searchIcon.Position = UDim2.new(0, 6, 0, 0)
    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "⌕"
    searchIcon.TextColor3 = PURPLE
    searchIcon.Font = Enum.Font.GothamBold
    searchIcon.TextSize = 18
    searchIcon.TextXAlignment = Enum.TextXAlignment.Center
    searchIcon.TextYAlignment = Enum.TextYAlignment.Center
    
    local searchBox = Instance.new("TextBox", searchFrame)
    searchBox.Size = UDim2.new(1, -70, 1, 0)
    searchBox.Position = UDim2.new(0, 34, 0, 0)
    searchBox.AnchorPoint = Vector2.new(0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText = "Search players..."
    searchBox.PlaceholderColor3 = DARK_GRAY
    searchBox.Text = searchQuery
    searchBox.TextColor3 = BLACK
    searchBox.Font = Enum.Font.Gotham
    searchBox.TextSize = 13
    searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    -- FIX BUG UTAMA: pastikan alignment vertikal benar-benar center dan
    -- TextBox setinggi penuh search bar (1,1 relative) supaya teks yang
    -- diketik/placeholder tidak pernah jatuh ke bawah frame.
    searchBox.TextYAlignment = Enum.TextYAlignment.Center
    searchBox.TextTruncate = Enum.TextTruncate.AtEnd
    
    local clearBtn = Instance.new("TextButton", searchFrame)
    clearBtn.Size = UDim2.new(0, 20, 0, 20)
    clearBtn.Position = UDim2.new(1, -26, 0.5, 0)
    clearBtn.AnchorPoint = Vector2.new(0, 0.5)
    clearBtn.BackgroundTransparency = 1
    clearBtn.Text = "×"
    clearBtn.TextColor3 = DARK_GRAY
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 16
    clearBtn.AutoButtonColor = false
    clearBtn.Visible = false
    clearBtn.MouseButton1Click:Connect(function()
        searchBox.Text = ""
    end)
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = searchBox.Text
        clearBtn.Visible = searchQuery ~= ""
        if _G.refreshCurr then
            _G.refreshCurr()
        end
    end)

    -- Subtle focus glow (polish ringan, tidak mengubah ukuran/posisi)
    searchBox.Focused:Connect(function()
        Helpers.tween(searchFrame, {BackgroundColor3 = WHITE}, 0.15)
        Helpers.stroke(searchFrame, PURPLE, 1.5, 0)
    end)
    searchBox.FocusLost:Connect(function()
        Helpers.tween(searchFrame, {BackgroundColor3 = LIGHT_GRAY}, 0.15)
    end)
    
    return searchFrame
end

local function createFilterTabs(parent)
    local tabFrame = Instance.new("Frame", parent)
    tabFrame.Size = UDim2.new(1, 0, 0, 36)
    tabFrame.BackgroundTransparency = 1
    tabFrame.LayoutOrder = 2
    
    local tabLayout = Instance.new("UIListLayout", tabFrame)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 6)
    
    local tabs = {
        {name = "All", filter = "all"},
        {name = "Friends", filter = "friends"},
        {name = "History", filter = "history", icon = "🕐"},
    }
    
    local tabButtons = {}
    
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(0, 80, 1, 0)
        btn.BackgroundColor3 = currentFilter == tab.filter and ACCENT or WHITE
        btn.Text = tab.icon and (tab.icon .. " " .. tab.name) or tab.name
        btn.TextColor3 = currentFilter == tab.filter and WHITE or BLACK
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        Helpers.corner(btn, 10)
        Helpers.stroke(btn, currentFilter == tab.filter and PURPLE or PURPLE_SOFT, 1, currentFilter == tab.filter and 0.2 or 0.4)

        if currentFilter == tab.filter then
            local g = Instance.new("UIGradient", btn)
            g.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 30, 65)),
                ColorSequenceKeypoint.new(1, ACCENT)
            }
            g.Rotation = 90
        end
        
        btn.MouseButton1Click:Connect(function()
            currentFilter = tab.filter
            -- Update visuals
            for _, b in ipairs(tabButtons) do
                for _, ch in ipairs(b:GetChildren()) do
                    if ch:IsA("UIGradient") then ch:Destroy() end
                end
                Helpers.tween(b, {
                    BackgroundColor3 = WHITE,
                    TextColor3 = BLACK
                }, 0.15)
            end
            Helpers.tween(btn, {
                BackgroundColor3 = ACCENT,
                TextColor3 = WHITE
            }, 0.15)
            
            if _G.refreshCurr then
                _G.refreshCurr()
            end
        end)
        
        table.insert(tabButtons, btn)
    end
    
    return tabFrame
end

local function createPlayerCard(parent, player, order)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, 0, 0, 72)
    card.BackgroundColor3 = WHITE
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.ClipsDescendants = true
    Helpers.corner(card, 16)
    Helpers.stroke(card, PURPLE_SOFT, 1, 0.35)

    -- Bayangan halus (drop shadow) — polish premium, tidak mengubah layout
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxasset://textures/ui/InGameChatNotifications/BackgroundGradient.png"
    shadow.ImageTransparency = 0.92
    shadow.ImageColor3 = BLACK
    shadow.Size = UDim2.new(1, 8, 1, 8)
    shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.ZIndex = card.ZIndex - 1
    shadow.Parent = card.Parent
    card:GetPropertyChangedSignal("Parent"):Connect(function()
        if not card.Parent then shadow:Destroy() end
    end)
    
    -- Avatar thumbnail
    local avatarWrap = Instance.new("Frame", card)
    avatarWrap.Size = UDim2.new(0, 50, 0, 50)
    avatarWrap.Position = UDim2.new(0, 10, 0.5, -25)
    avatarWrap.AnchorPoint = Vector2.new(0, 0.5)
    avatarWrap.BackgroundColor3 = LIGHT_GRAY
    avatarWrap.BorderSizePixel = 0
    Helpers.corner(avatarWrap, 25)
    Helpers.stroke(avatarWrap, PURPLE_LIGHT, 1.5, 0.15)
    
    local avatar = Instance.new("ImageLabel", avatarWrap)
    avatar.Size = UDim2.new(1, 0, 1, 0)
    avatar.BackgroundTransparency = 1
    avatar.Image = Services.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
    avatar.ScaleType = Enum.ScaleType.Crop
    Helpers.corner(avatar, 25)
    
    -- Player info
    local infoFrame = Instance.new("Frame", card)
    infoFrame.Size = UDim2.new(1, -150, 1, -16)
    infoFrame.Position = UDim2.new(0, 70, 0, 8)
    infoFrame.BackgroundTransparency = 1
    
    local nameLabel = Instance.new("TextLabel", infoFrame)
    nameLabel.Size = UDim2.new(1, 0, 0, 22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName
    nameLabel.TextColor3 = BLACK
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local usernameLabel = Instance.new("TextLabel", infoFrame)
    usernameLabel.Size = UDim2.new(1, 0, 0, 18)
    usernameLabel.Position = UDim2.new(0, 0, 0, 22)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@" .. player.Name
    usernameLabel.TextColor3 = DARK_GRAY
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextSize = 10
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local statusLabel = Instance.new("TextLabel", infoFrame)
    statusLabel.Size = UDim2.new(1, 0, 0, 16)
    statusLabel.Position = UDim2.new(0, 0, 0, 40)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "● Online"
    statusLabel.TextColor3 = GREEN
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 9
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Action buttons
    local teleportBtn = Instance.new("TextButton", card)
    teleportBtn.Size = UDim2.new(0, 34, 0, 34)
    teleportBtn.Position = UDim2.new(1, -80, 0.5, -17)
    teleportBtn.AnchorPoint = Vector2.new(0, 0.5)
    teleportBtn.BackgroundColor3 = ACCENT
    teleportBtn.Text = "➤"
    teleportBtn.TextColor3 = WHITE
    teleportBtn.Font = Enum.Font.GothamBold
    teleportBtn.TextSize = 16
    teleportBtn.AutoButtonColor = false
    Helpers.corner(teleportBtn, 10)
    local teleGradient = Instance.new("UIGradient", teleportBtn)
    teleGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 34, 75)),
        ColorSequenceKeypoint.new(1, ACCENT)
    }
    teleGradient.Rotation = 90
    Helpers.pressFX(teleportBtn)
    
    local spectateBtn = Instance.new("TextButton", card)
    spectateBtn.Size = UDim2.new(0, 34, 0, 34)
    spectateBtn.Position = UDim2.new(1, -42, 0.5, -17)
    spectateBtn.AnchorPoint = Vector2.new(0, 0.5)
    spectateBtn.BackgroundColor3 = WHITE
    spectateBtn.Text = "👁"
    spectateBtn.TextColor3 = PURPLE
    spectateBtn.Font = Enum.Font.GothamBold
    spectateBtn.TextSize = 16
    spectateBtn.AutoButtonColor = false
    Helpers.corner(spectateBtn, 10)
    Helpers.stroke(spectateBtn, PURPLE_SOFT, 1, 0.2)
    Helpers.pressFX(spectateBtn)
    
    -- Connections
    teleportBtn.MouseButton1Click:Connect(function()
        teleportToPlayer(player)
    end)

    -- Hover/press feel ringan (tidak mengubah fungsi, cuma micro-feedback)
    teleportBtn.MouseEnter:Connect(function()
        Helpers.tween(teleportBtn, {BackgroundColor3 = Color3.fromRGB(45, 30, 65)}, 0.1)
    end)
    teleportBtn.MouseLeave:Connect(function()
        Helpers.tween(teleportBtn, {BackgroundColor3 = ACCENT}, 0.1)
    end)
    
    spectateBtn.MouseButton1Click:Connect(function()
        if isSpectating and selectedPlayer == player then
            stopSpectating()
            Helpers.tween(spectateBtn, {BackgroundColor3 = WHITE}, 0.15)
            spectateBtn.TextColor3 = PURPLE
        else
            startSpectating(player)
            Helpers.tween(spectateBtn, {BackgroundColor3 = GREEN}, 0.15)
            spectateBtn.TextColor3 = WHITE
        end
    end)
    
    return card
end

-- ==================== MAIN APP FUNCTION ====================
function _G.openTeleportApp()
    local appContent = _G.appContent
    if not appContent then return end
    
    -- Clear existing content
    local existingLayout = appContent:FindFirstChildOfClass("UIListLayout")
    for _, child in ipairs(appContent:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    
    -- Search bar
    createSearchBar(appContent)
    
    -- Filter tabs
    createFilterTabs(appContent)
    
    -- Spectator status bar
    local specStatus = Instance.new("Frame", appContent)
    specStatus.Size = UDim2.new(1, 0, 0, 32)
    specStatus.BackgroundColor3 = PURPLE_SOFT
    specStatus.BorderSizePixel = 0
    specStatus.LayoutOrder = 3
    Helpers.corner(specStatus, 10)
    
    local specLabel = Instance.new("TextLabel", specStatus)
    specLabel.Size = UDim2.new(1, -16, 1, 0)
    specLabel.Position = UDim2.new(0, 8, 0, 0)
    specLabel.BackgroundTransparency = 1
    specLabel.Text = isSpectating and "👁 Spectating: " .. (selectedPlayer and selectedPlayer.DisplayName or "None") or "👁 Tap 👁 to spectate a player"
    specLabel.TextColor3 = isSpectating and GREEN or PURPLE
    specLabel.Font = Enum.Font.GothamBold
    specLabel.TextSize = 10
    specLabel.TextXAlignment = Enum.TextXAlignment.Left
    specLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Player list container
    local playerContainer = Instance.new("Frame", appContent)
    playerContainer.Size = UDim2.new(1, 0, 1, -180)
    playerContainer.BackgroundTransparency = 1
    playerContainer.LayoutOrder = 4
    
    local playerLayout = Instance.new("UIListLayout", playerContainer)
    playerLayout.Padding = UDim.new(0, 8)
    playerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- Get and filter players
    local players = getPlayerList()
    local filteredPlayers = {}
    
    if currentFilter == "friends" then
        for _, player in ipairs(players) do
            if isFriend(player.UserId) then
                table.insert(filteredPlayers, player)
            end
        end
    elseif currentFilter == "history" then
        -- Show teleport history
        for _, historyItem in ipairs(teleportHistory) do
            local historyCard = Instance.new("Frame", playerContainer)
            historyCard.Size = UDim2.new(1, 0, 0, 56)
            historyCard.BackgroundColor3 = WHITE
            historyCard.BorderSizePixel = 0
            Helpers.corner(historyCard, 14)
            Helpers.stroke(historyCard, PURPLE_SOFT, 1, 0.3)
            
            local historyName = Instance.new("TextLabel", historyCard)
            historyName.Size = UDim2.new(1, -16, 0, 28)
            historyName.Position = UDim2.new(0, 8, 0, 4)
            historyName.BackgroundTransparency = 1
            historyName.Text = historyItem.displayName
            historyName.TextColor3 = BLACK
            historyName.Font = Enum.Font.GothamBold
            historyName.TextSize = 13
            historyName.TextXAlignment = Enum.TextXAlignment.Left
            
            local historyTime = Instance.new("TextLabel", historyCard)
            historyTime.Size = UDim2.new(1, -16, 0, 16)
            historyTime.Position = UDim2.new(0, 8, 0, 32)
            historyTime.BackgroundTransparency = 1
            historyTime.Text = formatDistance(os.time() - historyItem.timestamp) .. " ago"
            historyTime.TextColor3 = DARK_GRAY
            historyTime.Font = Enum.Font.Gotham
            historyTime.TextSize = 9
            historyTime.TextXAlignment = Enum.TextXAlignment.Left
        end
    else
        -- All players with search filter
        for _, player in ipairs(players) do
            if searchQuery == "" or 
               player.DisplayName:lower():find(searchQuery:lower(), 1, true) or
               player.Name:lower():find(searchQuery:lower(), 1, true) then
                table.insert(filteredPlayers, player)
            end
        end
    end
    
    -- Sort players (friends first, then alphabetically)
    table.sort(filteredPlayers, function(a, b)
        local aFriend = isFriend(a.UserId)
        local bFriend = isFriend(b.UserId)
        if aFriend ~= bFriend then
            return aFriend
        end
        return a.DisplayName:lower() < b.DisplayName:lower()
    end)
    
    -- Create player cards
    for i, player in ipairs(filteredPlayers) do
        createPlayerCard(playerContainer, player, i)
    end
    
    -- Empty state
    if #filteredPlayers == 0 and currentFilter ~= "history" then
        local emptyState = Instance.new("Frame", playerContainer)
        emptyState.Size = UDim2.new(1, 0, 0, 100)
        emptyState.BackgroundTransparency = 1
        emptyState.LayoutOrder = 999
        
        local emptyText = Instance.new("TextLabel", emptyState)
        emptyText.Size = UDim2.new(1, 0, 0, 30)
        emptyText.Position = UDim2.new(0, 0, 0.5, -15)
        emptyText.AnchorPoint = Vector2.new(0, 0.5)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "No players found"
        emptyText.TextColor3 = DARK_GRAY
        emptyText.Font = Enum.Font.GothamBold
        emptyText.TextSize = 14
    end
end

-- ==================== INITIALIZATION ====================
-- Load teleport history from storage
if Storage and Storage.appSettings and Storage.appSettings.teleportHistory then
    teleportHistory = Storage.appSettings.teleportHistory
end

-- Auto-refresh player list periodically
task.spawn(function()
    while true do
        task.wait(30)
        if _G.refreshCurr and _G.appTitle and _G.appTitle.Text == "Save & Teleport" then
            _G.refreshCurr()
        end
    end
end)

print("[Teleport] Premium Monochrome + Purple Accent Teleport App Loaded!")