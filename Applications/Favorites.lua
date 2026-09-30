-- ================================================
-- FAVORITES APP - Dark Theme Premium
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players = Services.Players
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage
local T = _G.T
local Helpers = _G.Helpers
local Config = _G.Config
local Storage = _G.Storage

local appContent = _G.appContent

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
}

local favSelectedTab = "Players"
local favSet = Storage.favSet or {}
local favItems = Storage.favItems or {}

-- ==================== LIFECYCLE ====================
local FavLifecycle = {
    active = false,
    tasks = {},
}

local function cleanupFav()
    FavLifecycle.active = false
    for _, task in ipairs(FavLifecycle.tasks) do
        pcall(function() task.cancel() end)
    end
    FavLifecycle.tasks = {}
end

table.insert(_G.AvatarCloneCleanupTasks or {}, cleanupFav)

-- ==================== HELPERS ====================
local function persistFavItems()
    if Storage.persistFavItems then
        Storage.persistFavItems()
    end
end

local function persistFavPlayers()
    if Storage.persistFav then
        Storage.persistFav()
    end
end

local function fireHat(ids)
    if #ids == 0 then return end
    
    local remote = ReplicatedStorage
    for _, part in ipairs(Config.REMOTE_PATH:split(".")) do
        remote = remote:FindFirstChild(part)
        if not remote then return end
    end
    
    pcall(function()
        remote:FireServer("hat", {"hat", unpack(ids)})
    end)
end

local function cloneItems(player, cb)
    if not player then return end
    
    local ok, result = pcall(function()
        return HttpService:JSONDecode(HttpService:GetAsync("https://avatar.roblox.com/v1/users/" .. player.UserId .. "/avatar"))
    end)
    
    if not ok or not result or not result.assets then
        if cb then cb(false) end
        return
    end
    
    local ids = {}
    for _, asset in ipairs(result.assets) do
        if asset and asset.id and type(asset.id) == "number" then
            table.insert(ids, tostring(asset.id))
        end
    end
    
    if #ids > 0 then
        fireHat(ids)
        if cb then cb(true) end
    else
        if cb then cb(false) end
    end
end

-- ==================== OPEN FAVORITES APP ====================
function _G.openFavoritesApp()
    cleanupFav()
    FavLifecycle.active = true
    
    -- ==================== HEADER BANNER ====================
    local headerBanner = Instance.new("Frame", appContent)
    headerBanner.Size = UDim2.new(1, 0, 0, 56)
    headerBanner.BackgroundColor3 = colors.card
    headerBanner.LayoutOrder = 0
    corner(headerBanner, 16)
    stroke(headerBanner, colors.border, 1, 0.3)
    
    local bannerGradient = Instance.new("UIGradient", headerBanner)
    bannerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 42)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 36)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 26))
    })
    bannerGradient.Rotation = 135
    
    -- Accent line
    local accentLine = Instance.new("Frame", headerBanner)
    accentLine.Size = UDim2.new(1, 0, 0, 2)
    accentLine.BackgroundColor3 = colors.gold
    accentLine.ZIndex = 5
    corner(accentLine, 1)
    
    -- Star icon built from frames
    local starContainer = Instance.new("Frame", headerBanner)
    starContainer.Size = UDim2.new(0, 32, 0, 32)
    starContainer.Position = UDim2.new(0, 14, 0.5, -16)
    starContainer.BackgroundTransparency = 1
    starContainer.ZIndex = 5
    
    local starH = Instance.new("Frame", starContainer)
    starH.Size = UDim2.new(0, 28, 0, 6)
    starH.Position = UDim2.new(0.5, -14, 0.5, -3)
    starH.BackgroundColor3 = colors.gold
    corner(starH, 3)
    
    local starV = Instance.new("Frame", starContainer)
    starV.Size = UDim2.new(0, 6, 0, 28)
    starV.Position = UDim2.new(0.5, -3, 0.5, -14)
    starV.BackgroundColor3 = colors.gold
    corner(starV, 3)
    
    local starD1 = Instance.new("Frame", starContainer)
    starD1.Size = UDim2.new(0, 22, 0, 5)
    starD1.Position = UDim2.new(0.5, -11, 0.5, -2)
    starD1.BackgroundColor3 = colors.gold
    starD1.Rotation = 45
    corner(starD1, 2)
    
    local starD2 = Instance.new("Frame", starContainer)
    starD2.Size = UDim2.new(0, 22, 0, 5)
    starD2.Position = UDim2.new(0.5, -11, 0.5, -2)
    starD2.BackgroundColor3 = colors.gold
    starD2.Rotation = -45
    corner(starD2, 2)
    
    -- Title
    local headerTitle = Instance.new("TextLabel", headerBanner)
    headerTitle.Size = UDim2.new(1, -60, 0, 28)
    headerTitle.Position = UDim2.new(0, 52, 0, 8)
    headerTitle.BackgroundTransparency = 1
    headerTitle.Text = "My Favorites"
    headerTitle.TextColor3 = colors.text
    headerTitle.Font = Enum.Font.GothamBlack
    headerTitle.TextSize = 17
    headerTitle.TextXAlignment = Enum.TextXAlignment.Left
    headerTitle.ZIndex = 5
    
    local headerSub = Instance.new("TextLabel", headerBanner)
    headerSub.Size = UDim2.new(1, -60, 0, 16)
    headerSub.Position = UDim2.new(0, 52, 0, 34)
    headerSub.BackgroundTransparency = 1
    headerSub.Text = "Your saved players and items"
    headerSub.TextColor3 = colors.text2
    headerSub.Font = Enum.Font.Gotham
    headerSub.TextSize = 9
    headerSub.TextXAlignment = Enum.TextXAlignment.Left
    headerSub.ZIndex = 5
    
    -- ==================== TAB NAVIGATION ====================
    local tabFrame = Instance.new("Frame", appContent)
    tabFrame.Size = UDim2.new(1, 0, 0, 42)
    tabFrame.BackgroundColor3 = colors.card2
    tabFrame.LayoutOrder = 1
    corner(tabFrame, 21)
    stroke(tabFrame, colors.border, 1, 0.3)
    
    local tabPadding = Instance.new("UIPadding", tabFrame)
    tabPadding.PaddingLeft = UDim.new(0, 4)
    tabPadding.PaddingRight = UDim.new(0, 4)
    tabPadding.PaddingTop = UDim.new(0, 4)
    tabPadding.PaddingBottom = UDim.new(0, 4)
    
    local tabs = {"Players", "Items"}
    local tabBtns = {}
    
    for i, t in ipairs(tabs) do
        local btn = Instance.new("TextButton", tabFrame)
        btn.Size = UDim2.new(0.5, -6, 1, 0)
        btn.Position = UDim2.new((i-1) * 0.5, 3, 0, 0)
        btn.Text = t
        btn.AutoButtonColor = false
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BackgroundTransparency = 1
        btn.TextColor3 = colors.text3
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        corner(btn, 17)
        
        local isSelected = (i == 1 and favSelectedTab == "Players") or (i == 2 and favSelectedTab == "Items")
        if isSelected then
            btn.BackgroundColor3 = colors.accent
            btn.BackgroundTransparency = 0
            btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        end
        
        btn.MouseButton1Click:Connect(function()
            favSelectedTab = t
            for _, b in ipairs(tabBtns) do
                b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                b.BackgroundTransparency = 1
                b.TextColor3 = colors.text3
            end
            btn.BackgroundColor3 = colors.accent
            btn.BackgroundTransparency = 0
            btn.TextColor3 = Color3.fromRGB(0, 0, 0)
            if _G.refreshCurr then
                _G.refreshCurr()
            end
        end)
        
        table.insert(tabBtns, btn)
    end
    
    -- ==================== CONTENT AREA ====================
    local listHolder = Instance.new("Frame", appContent)
    listHolder.Size = UDim2.new(1, 0, 0, 0)
    listHolder.AutomaticSize = Enum.AutomaticSize.Y
    listHolder.BackgroundTransparency = 1
    listHolder.LayoutOrder = 2
    
    -- ==================== EMPTY STATE ====================
    local function showEmptyState(message)
        local emptyFrame = Instance.new("Frame", listHolder)
        emptyFrame.Size = UDim2.new(1, 0, 0, 180)
        emptyFrame.BackgroundColor3 = colors.card
        corner(emptyFrame, 16)
        stroke(emptyFrame, colors.border, 1, 0.4)
        
        -- Icon
        local iconFrame = Instance.new("Frame", emptyFrame)
        iconFrame.Size = UDim2.new(0, 50, 0, 50)
        iconFrame.Position = UDim2.new(0.5, -25, 0, 30)
        iconFrame.BackgroundColor3 = colors.gold
        iconFrame.BackgroundTransparency = 0.85
        corner(iconFrame, 100)
        stroke(iconFrame, colors.gold, 2, 0.5)
        
        local iconText = Instance.new("TextLabel", iconFrame)
        iconText.Size = UDim2.new(1, 0, 1, 0)
        iconText.BackgroundTransparency = 1
        iconText.Text = "★"
        iconText.TextColor3 = colors.gold
        iconText.Font = Enum.Font.GothamBlack
        iconText.TextSize = 24
        
        local emptyLabel = Instance.new("TextLabel", emptyFrame)
        emptyLabel.Size = UDim2.new(1, -20, 0, 26)
        emptyLabel.Position = UDim2.new(0, 10, 0, 88)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = message
        emptyLabel.TextColor3 = colors.text2
        emptyLabel.Font = Enum.Font.GothamBold
        emptyLabel.TextSize = 13
        emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        local emptySub = Instance.new("TextLabel", emptyFrame)
        emptySub.Size = UDim2.new(1, -20, 0, 18)
        emptySub.Position = UDim2.new(0, 10, 0, 116)
        emptySub.BackgroundTransparency = 1
        emptySub.Text = "Browse and add items to see them here"
        emptySub.TextColor3 = colors.text3
        emptySub.Font = Enum.Font.Gotham
        emptySub.TextSize = 9
        emptySub.TextXAlignment = Enum.TextXAlignment.Center
    end
    
    -- ==================== RENDER FUNCTION ====================
    local function render()
        for _, c in ipairs(listHolder:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") then c:Destroy() end
        end
        
        if favSelectedTab == "Players" then
            -- Count favorites
            local favCount = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if favSet[tostring(p.UserId)] then favCount = favCount + 1 end
            end
            
            if favCount == 0 then
                showEmptyState("No favorite players yet")
                return
            end
            
            local playerList = Instance.new("UIListLayout", listHolder)
            playerList.Padding = UDim.new(0, 8)
            playerList.SortOrder = Enum.SortOrder.LayoutOrder
            
            -- Counter
            local counterFrame = Instance.new("Frame", listHolder)
            counterFrame.Size = UDim2.new(1, 0, 0, 20)
            counterFrame.BackgroundTransparency = 1
            
            local counterText = Instance.new("TextLabel", counterFrame)
            counterText.Size = UDim2.new(0, 120, 1, 0)
            counterText.BackgroundTransparency = 1
            counterText.Text = favCount .. " player" .. (favCount ~= 1 and "s" or "")
            counterText.TextColor3 = colors.text2
            counterText.Font = Enum.Font.GothamBold
            counterText.TextSize = 10
            counterText.TextXAlignment = Enum.TextXAlignment.Left
            
            for _, p in ipairs(Players:GetPlayers()) do
                if favSet[tostring(p.UserId)] then
                    -- Player card
                    local card = Instance.new("Frame", listHolder)
                    card.Size = UDim2.new(1, 0, 0, 72)
                    card.BackgroundColor3 = colors.card
                    corner(card, 14)
                    stroke(card, colors.border, 1, 0.3)
                    
                    -- Gold accent bar
                    local accentBar = Instance.new("Frame", card)
                    accentBar.Size = UDim2.new(0, 3, 1, -14)
                    accentBar.Position = UDim2.new(0, 7, 0, 7)
                    accentBar.BackgroundColor3 = colors.gold
                    corner(accentBar, 2)
                    
                    -- Avatar
                    local avatarFrame = Instance.new("Frame", card)
                    avatarFrame.Size = UDim2.new(0, 48, 0, 48)
                    avatarFrame.Position = UDim2.new(0, 16, 0.5, -24)
                    avatarFrame.BackgroundColor3 = colors.gold
                    avatarFrame.BackgroundTransparency = 0.9
                    corner(avatarFrame, 100)
                    
                    local avatar = Instance.new("ImageLabel", avatarFrame)
                    avatar.Size = UDim2.new(0, 40, 0, 40)
                    avatar.Position = UDim2.new(0.5, -20, 0.5, -20)
                    avatar.BackgroundColor3 = colors.card2
                    avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=100&height=100&format=png"
                    corner(avatar, 100)
                    stroke(avatar, colors.card, 1.5, 0)
                    
                    -- Name
                    local nameLbl = Instance.new("TextLabel", card)
                    nameLbl.Size = UDim2.new(1, -200, 0, 24)
                    nameLbl.Position = UDim2.new(0, 72, 0, 12)
                    nameLbl.BackgroundTransparency = 1
                    nameLbl.Text = p.DisplayName
                    nameLbl.TextColor3 = colors.text
                    nameLbl.Font = Enum.Font.GothamBlack
                    nameLbl.TextSize = 14
                    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                    
                    local userLbl = Instance.new("TextLabel", card)
                    userLbl.Size = UDim2.new(1, -200, 0, 16)
                    userLbl.Position = UDim2.new(0, 72, 0, 36)
                    userLbl.BackgroundTransparency = 1
                    userLbl.Text = "@" .. p.Name
                    userLbl.TextColor3 = colors.text2
                    userLbl.Font = Enum.Font.Gotham
                    userLbl.TextSize = 10
                    userLbl.TextXAlignment = Enum.TextXAlignment.Left
                    
                    -- Online dot
                    local onlineDot = Instance.new("Frame", card)
                    onlineDot.Size = UDim2.new(0, 6, 0, 6)
                    onlineDot.Position = UDim2.new(0, 72, 0, 52)
                    onlineDot.BackgroundColor3 = colors.green
                    corner(onlineDot, 100)
                    
                    -- Action buttons
                    local selBtn = Instance.new("TextButton", card)
                    selBtn.Size = UDim2.new(0, 64, 0, 28)
                    selBtn.Position = UDim2.new(1, -140, 0.5, -14)
                    selBtn.BackgroundColor3 = colors.accent
                    selBtn.Text = "Select"
                    selBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                    selBtn.Font = Enum.Font.GothamBold
                    selBtn.TextSize = 10
                    selBtn.AutoButtonColor = false
                    corner(selBtn, 7)
                    pressFX(selBtn)
                    selBtn.MouseButton1Click:Connect(function()
                        if _G.PhoneState then
                            _G.PhoneState.selectedPlayer = p
                        end
                        _G.showDynamicNotification("Target: " .. p.DisplayName, colors.green)
                    end)
                    
                    local cloneBtn = Instance.new("TextButton", card)
                    cloneBtn.Size = UDim2.new(0, 64, 0, 28)
                    cloneBtn.Position = UDim2.new(1, -70, 0.5, -14)
                    cloneBtn.BackgroundColor3 = colors.green
                    cloneBtn.Text = "Clone"
                    cloneBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                    cloneBtn.Font = Enum.Font.GothamBold
                    cloneBtn.TextSize = 10
                    cloneBtn.AutoButtonColor = false
                    corner(cloneBtn, 7)
                    pressFX(cloneBtn)
                    cloneBtn.MouseButton1Click:Connect(function()
                        cloneItems(p, function(done)
                            if done then
                                _G.showDynamicNotification("Clone complete!", colors.green)
                            else
                                _G.showDynamicNotification("Clone failed", colors.red)
                            end
                        end)
                    end)
                end
            end
            
        elseif favSelectedTab == "Items" then
            if #favItems == 0 then
                showEmptyState("No favorite items yet")
                return
            end
            
            local itemGrid = Instance.new("UIGridLayout", listHolder)
            itemGrid.CellSize = UDim2.new(0.5, -6, 0, 175)
            itemGrid.CellPadding = UDim2.new(0, 8, 0, 8)
            itemGrid.FillDirection = Enum.FillDirection.Horizontal
            itemGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
            itemGrid.SortOrder = Enum.SortOrder.LayoutOrder
            
            for i, item in ipairs(favItems) do
                local card = Instance.new("Frame", listHolder)
                card.Size = UDim2.new(0, 0, 0, 175)
                card.BackgroundColor3 = colors.card
                card.LayoutOrder = i
                corner(card, 12)
                stroke(card, colors.border, 1, 0.3)
                
                -- Gold accent top
                local goldAccent = Instance.new("Frame", card)
                goldAccent.Size = UDim2.new(1, -16, 0, 2)
                goldAccent.Position = UDim2.new(0, 8, 0, 6)
                goldAccent.BackgroundColor3 = colors.gold
                goldAccent.BackgroundTransparency = 0.4
                corner(goldAccent, 1)
                
                -- Thumbnail
                local imgContainer = Instance.new("Frame", card)
                imgContainer.Size = UDim2.new(0, 80, 0, 80)
                imgContainer.Position = UDim2.new(0.5, -40, 0, 14)
                imgContainer.BackgroundColor3 = colors.card2
                corner(imgContainer, 10)
                stroke(imgContainer, colors.border, 1, 0.3)
                
                local thumb = Instance.new("ImageLabel", imgContainer)
                thumb.Size = UDim2.new(1, -8, 1, -8)
                thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
                thumb.AnchorPoint = Vector2.new(0.5, 0.5)
                thumb.BackgroundColor3 = colors.card2
                thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.id .. "&width=150&height=150&format=png"
                thumb.ScaleType = Enum.ScaleType.Fit
                corner(thumb, 7)
                
                -- ID label
                local idContainer = Instance.new("Frame", card)
                idContainer.Size = UDim2.new(1, -20, 0, 20)
                idContainer.Position = UDim2.new(0, 10, 0, 100)
                idContainer.BackgroundColor3 = colors.card2
                corner(idContainer, 5)
                
                local idLabel = Instance.new("TextLabel", idContainer)
                idLabel.Size = UDim2.new(1, -4, 1, 0)
                idLabel.BackgroundTransparency = 1
                idLabel.Text = item.id
                idLabel.TextColor3 = colors.green
                idLabel.Font = Enum.Font.Code
                idLabel.TextSize = 10
                idLabel.TextXAlignment = Enum.TextXAlignment.Center
                
                local copyBtn = Instance.new("TextButton", idContainer)
                copyBtn.Size = UDim2.new(1, 0, 1, 0)
                copyBtn.BackgroundTransparency = 1
                copyBtn.Text = ""
                copyBtn.MouseButton1Click:Connect(function()
                    Helpers.copyToClipboard(item.id)
                    _G.showDynamicNotification("Copied: " .. item.id, colors.green)
                end)
                
                -- Item label
                local itemLabel = Instance.new("TextLabel", card)
                itemLabel.Size = UDim2.new(1, -20, 0, 16)
                itemLabel.Position = UDim2.new(0, 10, 0, 124)
                itemLabel.BackgroundTransparency = 1
                itemLabel.Text = item.label or "Item"
                itemLabel.TextColor3 = colors.text2
                itemLabel.Font = Enum.Font.GothamBold
                itemLabel.TextSize = 9
                itemLabel.TextXAlignment = Enum.TextXAlignment.Center
                itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
                
                -- Action buttons
                local wearBtn = Instance.new("TextButton", card)
                wearBtn.Size = UDim2.new(0, 55, 0, 22)
                wearBtn.Position = UDim2.new(0.5, -60, 0, 145)
                wearBtn.BackgroundColor3 = colors.accent
                wearBtn.Text = "Wear"
                wearBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                wearBtn.Font = Enum.Font.GothamBold
                wearBtn.TextSize = 9
                wearBtn.AutoButtonColor = false
                corner(wearBtn, 6)
                pressFX(wearBtn)
                wearBtn.MouseButton1Click:Connect(function()
                    fireHat({item.id})
                    _G.showDynamicNotification("Wearing " .. item.id, colors.green)
                end)
                
                local delBtn = Instance.new("TextButton", card)
                delBtn.Size = UDim2.new(0, 55, 0, 22)
                delBtn.Position = UDim2.new(0.5, 5, 0, 145)
                delBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
                delBtn.Text = "Remove"
                delBtn.TextColor3 = colors.red
                delBtn.Font = Enum.Font.GothamBold
                delBtn.TextSize = 9
                delBtn.AutoButtonColor = false
                corner(delBtn, 6)
                pressFX(delBtn)
                delBtn.MouseButton1Click:Connect(function()
                    table.remove(favItems, i)
                    persistFavItems()
                    render()
                    _G.showDynamicNotification("Item removed", colors.red)
                end)
            end
        end
    end
    
    render()
end

print("[Favorites] App loaded!")