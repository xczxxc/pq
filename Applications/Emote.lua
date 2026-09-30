--[[
    EMOTE.LUA — ULTRA PREMIUM PURPLE GLASS
    Version : 2.0
    Features:
    • Purple Glass UI
    • Search
    • All / Favorites tabs
    • Favorites persistence
    • Local emote cache
    • Automatic pagination
    • Thumbnail preloading
    • Pooled cards
    • Play / Stop emote
    • Speed control
    • Loop control
    • Fixed cache state handling
]]

local Services = _G.Services or {}
local LocalPlayer = _G.LocalPlayer or game:GetService("Players").LocalPlayer
local Helpers = _G.Helpers or {}
local Storage = _G.Storage or {}
local appContent = _G.appContent

local HttpService = Services.HttpService or game:GetService("HttpService")
local TweenService = Services.TweenService or game:GetService("TweenService")
local ContentProvider = Services.ContentProvider or game:GetService("ContentProvider")

if not LocalPlayer then
    warn("[Emote] LocalPlayer tidak ditemukan.")
    return
end

if not appContent then
    warn("[Emote] appContent tidak ditemukan.")
    return
end

-- =========================================================
-- HELPERS
-- =========================================================

local function createCorner(object, radius)
    if Helpers.corner then
        return Helpers.corner(object, radius)
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = object
    return corner
end

local function createStroke(object, color, thickness, transparency)
    if Helpers.stroke then
        return Helpers.stroke(object, color, thickness, transparency)
    end

    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.new(0, 0, 0)
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.Parent = object
    return stroke
end

local function createGradient(object, colorSequence, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = colorSequence
    gradient.Rotation = rotation or 90
    gradient.Parent = object
    return gradient
end

local function tween(object, properties, duration)
    local animation = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.15,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        properties
    )

    animation:Play()
    return animation
end

local function safeDestroy(object)
    if object then
        pcall(function()
            object:Destroy()
        end)
    end
end

-- =========================================================
-- PALETTE
-- =========================================================

local C = {
    white = Color3.fromRGB(255, 255, 255),
    black = Color3.fromRGB(0, 0, 0),

    background = Color3.fromRGB(247, 244, 253),
    backgroundDark = Color3.fromRGB(20, 12, 32),

    card = Color3.fromRGB(38, 20, 58),
    cardLight = Color3.fromRGB(58, 32, 90),

    purple = Color3.fromRGB(124, 58, 237),
    purpleLight = Color3.fromRGB(167, 120, 244),
    purpleDeep = Color3.fromRGB(88, 40, 170),

    text = Color3.fromRGB(255, 255, 255),
    textDark = Color3.fromRGB(30, 20, 45),
    textGray = Color3.fromRGB(140, 130, 155),

    border = Color3.fromRGB(225, 215, 245),
}

-- =========================================================
-- GLOBAL CACHE
-- =========================================================

_G.EmoteCache = _G.EmoteCache or {
    emotes = {},
    favorites = {},
    idSet = {},
    loaded = false,
    loading = false,
}

local Cache = _G.EmoteCache
local Emotes = Cache.emotes
local Favorites = Cache.favorites
local IdSet = Cache.idSet

local function isLoaded()
    return _G.EmoteCache.loaded == true
end

local function isLoading()
    return _G.EmoteCache.loading == true
end

-- =========================================================
-- STATE
-- =========================================================

local currentAnimTrack = nil
local currentSpeed = 1
local loopEnabled = false

local currentTab = "all"
local searchQuery = ""

local renderToken = 0

local resultsContainer = nil
local emptyLabel = nil

local cardPool = {}
local cardConnections = {}

local currentApp = nil

-- =========================================================
-- CACHE FILE
-- =========================================================

local CACHE_FILE_NAME = "PhoneIDViewer_EmoteCache.json"

local function loadEmotesFromDisk()
    if not isfile or not readfile then
        return false
    end

    if not isfile(CACHE_FILE_NAME) then
        return false
    end

    local success, result = pcall(function()
        return HttpService:JSONDecode(
            readfile(CACHE_FILE_NAME)
        )
    end)

    if not success or type(result) ~= "table" then
        return false
    end

    if #result == 0 then
        return false
    end

    table.clear(Emotes)
    table.clear(IdSet)

    for _, item in ipairs(result) do
        if type(item) == "table" and item.id then
            item.id = tonumber(item.id) or item.id

            if not IdSet[item.id] then
                IdSet[item.id] = true
                table.insert(Emotes, item)
            end
        end
    end

    if #Emotes > 0 then
        _G.EmoteCache.loaded = true
        return true
    end

    return false
end

local function saveEmotesToDisk()
    if not writefile then
        return
    end

    if #Emotes == 0 then
        return
    end

    pcall(function()
        writefile(
            CACHE_FILE_NAME,
            HttpService:JSONEncode(Emotes)
        )
    end)
end

-- =========================================================
-- FAVORITES
-- =========================================================

local function loadFavorites()
    if not Storage or not Storage.appSettings then
        return
    end

    Storage.appSettings.emoteFavorites =
        Storage.appSettings.emoteFavorites or {}

    Favorites = Storage.appSettings.emoteFavorites
    _G.EmoteCache.favorites = Favorites

    for index, value in ipairs(Favorites) do
        Favorites[index] = tonumber(value) or value
    end
end

local function saveFavorites()
    if not Storage or not Storage.appSettings then
        return
    end

    Storage.appSettings.emoteFavorites = Favorites

    pcall(function()
        if Storage.persistSettings then
            Storage.persistSettings()
        end
    end)
end

local function isFavorite(id)
    return table.find(Favorites, id) ~= nil
end

local function toggleFavorite(id)
    local index = table.find(Favorites, id)

    if index then
        table.remove(Favorites, index)
        return false
    end

    table.insert(Favorites, id)
    return true
end

loadEmotesFromDisk()
loadFavorites()

-- =========================================================
-- HTTP REQUEST
-- =========================================================

local function performRequest(url)
    local requestFunction

    if syn and syn.request then
        requestFunction = syn.request
    elseif http_request then
        requestFunction = http_request
    elseif request then
        requestFunction = request
    end

    if requestFunction then
        local success, response = pcall(function()
            return requestFunction({
                Url = url,
                Method = "GET",
                Headers = {
                    ["Content-Type"] = "application/json",
                },
            })
        end)

        if success and response then
            return response.Body
        end
    end

    local success, body = pcall(function()
        return game:HttpGet(url)
    end)

    if success then
        return body
    end

    return nil
end

-- =========================================================
-- FETCH EMOTE PAGE
-- =========================================================

local function fetchEmotePage(cursor)
    local url =
        "https://catalog.roblox.com/v1/search/items/details" ..
        "?Category=12" ..
        "&Subcategory=39" ..
        "&SortType=1" ..
        "&SortAggregation=" ..
        "&limit=30" ..
        "&IncludeNotForSale=true"

    if cursor and cursor ~= "" then
        url = url ..
            "&cursor=" ..
            HttpService:UrlEncode(cursor)
    end

    local body = performRequest(url)

    if not body then
        return nil
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)

    if not success then
        return nil
    end

    return data
end

-- =========================================================
-- FETCH ALL EMOTES
-- =========================================================

local function fetchAllEmotes(maxPages)
    if isLoading() then
        return
    end

    _G.EmoteCache.loading = true

    maxPages = maxPages or 30

    task.spawn(function()
        local cursor = ""
        local pages = 0
        local added = false

        while pages < maxPages do
            local page = fetchEmotePage(cursor)

            if not page then
                break
            end

            if type(page.data) ~= "table" then
                break
            end

            if #page.data == 0 then
                break
            end

            local preloadList = {}

            for _, item in ipairs(page.data) do
                local id = tonumber(item.id)

                if id and item.name and not IdSet[id] then
                    IdSet[id] = true

                    local emote = {
                        id = id,
                        name = tostring(item.name),
                        icon =
                            "rbxthumb://type=Asset&id=" ..
                            id ..
                            "&w=150&h=150",
                        updated = tostring(
                            item.updated or ""
                        ),
                    }

                    table.insert(Emotes, emote)
                    table.insert(
                        preloadList,
                        emote.icon
                    )

                    added = true
                end
            end

            if #preloadList > 0 then
                task.spawn(function()
                    pcall(function()
                        ContentProvider:PreloadAsync(
                            preloadList
                        )
                    end)
                end)
            end

            cursor = page.nextPageCursor or ""
            pages += 1

            if cursor == "" then
                break
            end

            task.wait(0.2)
        end

        _G.EmoteCache.loaded = true
        _G.EmoteCache.loading = false

        if added then
            saveEmotesToDisk()
        end

        if _G.renderEmotesRefresh then
            task.defer(_G.renderEmotesRefresh)
        end
    end)
end

-- =========================================================
-- STOP EMOTE
-- =========================================================

local function stopEmote()
    if currentAnimTrack then
        pcall(function()
            currentAnimTrack:Stop()
        end)

        currentAnimTrack = nil
    end
end

-- =========================================================
-- PLAY EMOTE
-- =========================================================

local function playEmote(assetId)
    stopEmote()

    local character = LocalPlayer.Character

    if not character then
        return
    end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    if not humanoid then
        return
    end

    local track

    pcall(function()
        track =
            humanoid:PlayEmoteAndGetAnimTrackById(
                assetId
            )
    end)

    if not track then
        local description =
            humanoid:FindFirstChildOfClass(
                "HumanoidDescription"
            )

        if description then
            pcall(function()
                description:AddEmote(
                    "Emote_" .. tostring(assetId),
                    assetId
                )

                track =
                    humanoid:PlayEmoteAndGetAnimTrackById(
                        assetId
                    )
            end)
        end
    end

    if not track then
        return
    end

    currentAnimTrack = track

    pcall(function()
        track:AdjustSpeed(currentSpeed)
        track.Looped = loopEnabled
        track:Play()
    end)
end

-- =========================================================
-- CARD CONNECTION CLEANUP
-- =========================================================

local function clearCardConnections(card)
    if not cardConnections[card] then
        cardConnections[card] = {}
        return
    end

    for _, connection in ipairs(
        cardConnections[card]
    ) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    table.clear(cardConnections[card])
end

-- =========================================================
-- CREATE CARD
-- =========================================================

local function createPooledCard(parent)
    local wrapper = Instance.new("Frame")
    wrapper.Name = "EmoteCardWrapper"
    wrapper.BackgroundTransparency = 1
    wrapper.Size = UDim2.new(1, 0, 0, 144)
    wrapper.Parent = parent

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(1, 0, 1, 0)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = C.card
    card.BorderSizePixel = 0
    card.Parent = wrapper

    createCorner(card, 14)

    createGradient(
        card,
        ColorSequence.new({
            ColorSequenceKeypoint.new(
                0,
                C.cardLight
            ),
            ColorSequenceKeypoint.new(
                1,
                C.card
            ),
        }),
        60
    )

    createStroke(
        card,
        C.purpleLight,
        1,
        0.7
    )

    local thumbnailWrapper = Instance.new("Frame")
    thumbnailWrapper.Name = "ThumbWrap"
    thumbnailWrapper.Size =
        UDim2.new(1, -12, 0, 82)
    thumbnailWrapper.Position =
        UDim2.new(0, 6, 0, 6)
    thumbnailWrapper.BackgroundColor3 =
        C.purpleDeep
    thumbnailWrapper.BackgroundTransparency = 0.35
    thumbnailWrapper.BorderSizePixel = 0
    thumbnailWrapper.Parent = card

    createCorner(thumbnailWrapper, 10)

    local thumbnail = Instance.new("ImageLabel")
    thumbnail.Name = "Thumb"
    thumbnail.Size = UDim2.new(1, 0, 1, 0)
    thumbnail.BackgroundTransparency = 1
    thumbnail.ScaleType = Enum.ScaleType.Crop
    thumbnail.ImageColor3 = C.white
    thumbnail.Parent = thumbnailWrapper

    createCorner(thumbnail, 10)

    local favorite = Instance.new("TextButton")
    favorite.Name = "FavBtn"
    favorite.Size = UDim2.new(0, 25, 0, 25)
    favorite.Position =
        UDim2.new(1, -31, 0, 10)
    favorite.BackgroundColor3 = C.white
    favorite.BackgroundTransparency = 0.1
    favorite.Text = "☆"
    favorite.TextColor3 = C.purpleDeep
    favorite.Font = Enum.Font.GothamBold
    favorite.TextSize = 15
    favorite.AutoButtonColor = false
    favorite.ZIndex = 5
    favorite.Parent = card

    createCorner(favorite, 13)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLbl"
    nameLabel.Size =
        UDim2.new(1, -12, 0, 16)
    nameLabel.Position =
        UDim2.new(0, 6, 0, 94)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = "Emote"
    nameLabel.TextColor3 = C.white
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.TextXAlignment =
        Enum.TextXAlignment.Center
    nameLabel.TextTruncate =
        Enum.TextTruncate.AtEnd
    nameLabel.Parent = card

    local playButton = Instance.new("TextButton")
    playButton.Name = "PlayBtn"
    playButton.Size =
        UDim2.new(1, -12, 0, 26)
    playButton.Position =
        UDim2.new(0, 6, 0, 114)
    playButton.BackgroundColor3 =
        C.purpleLight
    playButton.Text = "▶  Play"
    playButton.TextColor3 = C.white
    playButton.Font = Enum.Font.GothamBold
    playButton.TextSize = 12
    playButton.AutoButtonColor = false
    playButton.Parent = card

    createCorner(playButton, 13)

    createGradient(
        playButton,
        ColorSequence.new({
            ColorSequenceKeypoint.new(
                0,
                C.purple
            ),
            ColorSequenceKeypoint.new(
                1,
                C.purpleDeep
            ),
        }),
        0
    )

    return wrapper
end

-- =========================================================
-- UPDATE CARD
-- =========================================================

local function updateCardData(
    wrapper,
    emote,
    order,
    favoriteState
)
    clearCardConnections(wrapper)

    wrapper.LayoutOrder = order
    wrapper.Visible = true

    local card = wrapper:FindFirstChild("Card")

    if not card then
        return
    end

    local thumbnailWrapper =
        card:FindFirstChild("ThumbWrap")

    local thumbnail =
        thumbnailWrapper and
        thumbnailWrapper:FindFirstChild("Thumb")

    local nameLabel =
        card:FindFirstChild("NameLbl")

    local favorite =
        card:FindFirstChild("FavBtn")

    local playButton =
        card:FindFirstChild("PlayBtn")

    if not thumbnail
        or not nameLabel
        or not favorite
        or not playButton then
        return
    end

    thumbnail.Image = emote.icon or ""
    nameLabel.Text = emote.name or "Emote"

    favorite.Text =
        favoriteState and "★" or "☆"

    local connections = cardConnections[wrapper]

    table.insert(
        connections,
        favorite.MouseButton1Click:Connect(
            function()
                tween(
                    favorite,
                    {
                        Size = UDim2.new(
                            0,
                            29,
                            0,
                            29
                        ),
                    },
                    0.08
                )

                task.delay(
                    0.08,
                    function()
                        if favorite.Parent then
                            tween(
                                favorite,
                                {
                                    Size =
                                        UDim2.new(
                                            0,
                                            25,
                                            0,
                                            25
                                        ),
                                },
                                0.08
                            )
                        end
                    end
                )

                local nowFavorite =
                    toggleFavorite(emote.id)

                favorite.Text =
                    nowFavorite and
                    "★" or
                    "☆"

                saveFavorites()

                if currentTab ==
                    "favorites"
                    and
                    _G.renderEmotesRefresh then

                    task.defer(
                        _G.renderEmotesRefresh
                    )
                end
            end
        )
    )

    table.insert(
        connections,
        playButton.MouseButton1Down:Connect(
            function()
                tween(
                    playButton,
                    {
                        BackgroundColor3 =
                            C.purpleDeep,
                    },
                    0.08
                )
            end
        )
    )

    table.insert(
        connections,
        playButton.MouseButton1Up:Connect(
            function()
                tween(
                    playButton,
                    {
                        BackgroundColor3 =
                            C.purpleLight,
                    },
                    0.08
                )

                playEmote(emote.id)
            end
        )
    )

    table.insert(
        connections,
        playButton.MouseLeave:Connect(
            function()
                tween(
                    playButton,
                    {
                        BackgroundColor3 =
                            C.purpleLight,
                    },
                    0.08
                )
            end
        )
    )
end

-- =========================================================
-- FILTER / RENDER
-- =========================================================

local function renderEmotes()
    renderToken += 1

    local token = renderToken

    if not resultsContainer
        or not resultsContainer.Parent then
        return
    end

    local filtered = {}
    local query = string.lower(
        searchQuery or ""
    )

    for _, emote in ipairs(Emotes) do
        local include = true

        if currentTab == "favorites" then
            include = isFavorite(emote.id)
        end

        if include and query ~= "" then
            local name =
                string.lower(
                    tostring(
                        emote.name or ""
                    )
                )

            include =
                string.find(
                    name,
                    query,
                    1,
                    true
                ) ~= nil
        end

        if include then
            table.insert(
                filtered,
                emote
            )
        end
    end

    table.sort(
        filtered,
        function(a, b)
            return tostring(
                a.updated or ""
            ) >
                tostring(
                    b.updated or ""
                )
        end
    )

    for _, card in ipairs(cardPool) do
        card.Visible = false
    end

    if emptyLabel then
        emptyLabel.Visible =
            #filtered == 0

        if #filtered == 0 then
            if isLoading() then
                emptyLabel.Text =
                    "✨ Memuat emote..."
            else
                emptyLabel.Text =
                    "Tidak ada emote ditemukan"
            end
        end
    end

    task.spawn(function()
        local batch = 15

        for index, emote in ipairs(filtered) do
            if renderToken ~= token then
                return
            end

            local card =
                cardPool[index]

            if not card
                or not card.Parent then

                card =
                    createPooledCard(
                        resultsContainer
                    )

                cardPool[index] = card
            end

            updateCardData(
                card,
                emote,
                index,
                isFavorite(emote.id)
            )

            if index % batch == 0 then
                task.wait()
            end
        end
    end)
end

_G.renderEmotesRefresh = renderEmotes

-- =========================================================
-- BUILD APPLICATION
-- =========================================================

local function clearPreviousApp()
    if currentApp then
        safeDestroy(currentApp)
        currentApp = nil
    end

    resultsContainer = nil
    emptyLabel = nil

    table.clear(cardPool)
    table.clear(cardConnections)
end

local function buildEmoteApp()
    if not appContent then
        return false
    end

    clearPreviousApp()

    currentApp = Instance.new("Frame")
    currentApp.Name = "UltraPremiumEmoteApp"
    currentApp.Size =
        UDim2.new(1, 0, 1, 0)
    currentApp.BackgroundTransparency = 1
    currentApp.BorderSizePixel = 0
    currentApp.Parent = appContent

    local layout =
        Instance.new("UIListLayout")

    layout.Padding =
        UDim.new(0, 10)

    layout.SortOrder =
        Enum.SortOrder.LayoutOrder

    layout.Parent = currentApp

    -- =====================================================
    -- SEARCH
    -- =====================================================

    local searchFrame =
        Instance.new("Frame")

    searchFrame.Name =
        "SearchBar"

    searchFrame.Size =
        UDim2.new(1, 0, 0, 40)

    searchFrame.BackgroundColor3 =
        C.white

    searchFrame.BorderSizePixel = 0
    searchFrame.LayoutOrder = 1
    searchFrame.Parent = currentApp

    createCorner(searchFrame, 20)

    createStroke(
        searchFrame,
        C.border,
        1,
        0.25
    )

    local searchIcon =
        Instance.new("TextLabel")

    searchIcon.Size =
        UDim2.new(0, 34, 1, 0)

    searchIcon.Position =
        UDim2.new(0, 7, 0, 0)

    searchIcon.BackgroundTransparency = 1
    searchIcon.Text = "⌕"
    searchIcon.TextColor3 = C.purple
    searchIcon.TextSize = 23
    searchIcon.Font =
        Enum.Font.GothamBold

    searchIcon.Parent = searchFrame

    local searchBox =
        Instance.new("TextBox")

    searchBox.Name =
        "SearchBox"

    searchBox.Size =
        UDim2.new(1, -78, 1, 0)

    searchBox.Position =
        UDim2.new(0, 40, 0, 0)

    searchBox.BackgroundTransparency = 1

    searchBox.PlaceholderText =
        "Cari gaya emote..."

    searchBox.PlaceholderColor3 =
        C.textGray

    searchBox.Text =
        searchQuery

    searchBox.TextColor3 =
        C.purpleDeep

    searchBox.Font =
        Enum.Font.GothamBold

    searchBox.TextSize = 13
    searchBox.ClearTextOnFocus = false

    searchBox.TextXAlignment =
        Enum.TextXAlignment.Left

    searchBox.Parent = searchFrame

    local clearButton =
        Instance.new("TextButton")

    clearButton.Size =
        UDim2.new(0, 32, 1, 0)

    clearButton.Position =
        UDim2.new(1, -36, 0, 0)

    clearButton.BackgroundTransparency = 1
    clearButton.Text = "×"
    clearButton.TextColor3 =
        C.textGray

    clearButton.Font =
        Enum.Font.GothamBold

    clearButton.TextSize = 18
    clearButton.Visible =
        searchQuery ~= ""

    clearButton.Parent =
        searchFrame

    searchBox:GetPropertyChangedSignal(
        "Text"
    ):Connect(function()
        searchQuery =
            searchBox.Text or ""

        clearButton.Visible =
            searchQuery ~= ""

        renderEmotes()
    end)

    clearButton.MouseButton1Click:Connect(
        function()
            searchBox.Text = ""
        end
    )

    -- =====================================================
    -- TAB BAR
    -- =====================================================

    local tabWrap =
        Instance.new("Frame")

    tabWrap.Name =
        "TabBar"

    tabWrap.Size =
        UDim2.new(1, 0, 0, 40)

    tabWrap.BackgroundColor3 =
        C.backgroundDark

    tabWrap.BorderSizePixel = 0
    tabWrap.LayoutOrder = 2
    tabWrap.Parent = currentApp

    createCorner(tabWrap, 20)

    local padding =
        Instance.new("UIPadding")

    padding.PaddingLeft =
        UDim.new(0, 4)

    padding.PaddingRight =
        UDim.new(0, 4)

    padding.PaddingTop =
        UDim.new(0, 4)

    padding.PaddingBottom =
        UDim.new(0, 4)

    padding.Parent = tabWrap

    local tabLayout =
        Instance.new("UIListLayout")

    tabLayout.FillDirection =
        Enum.FillDirection.Horizontal

    tabLayout.SortOrder =
        Enum.SortOrder.LayoutOrder

    tabLayout.Padding =
        UDim.new(0, 4)

    tabLayout.Parent = tabWrap

    local allButton =
        Instance.new("TextButton")

    allButton.Name = "AllTab"

    allButton.Size =
        UDim2.new(0.5, -2, 1, 0)

    allButton.BackgroundColor3 =
        C.purple

    allButton.Text =
        "Semua  ✨"

    allButton.TextColor3 =
        C.white

    allButton.Font =
        Enum.Font.GothamBold

    allButton.TextSize = 13
    allButton.AutoButtonColor = false
    allButton.LayoutOrder = 1
    allButton.Parent = tabWrap

    createCorner(allButton, 16)

    local favoriteButton =
        Instance.new("TextButton")

    favoriteButton.Name =
        "FavoriteTab"

    favoriteButton.Size =
        UDim2.new(0.5, -2, 1, 0)

    favoriteButton.BackgroundColor3 =
        C.backgroundDark

    favoriteButton.Text =
        "Favorit  ★"

    favoriteButton.TextColor3 =
        C.white

    favoriteButton.Font =
        Enum.Font.GothamBold

    favoriteButton.TextSize = 13
    favoriteButton.AutoButtonColor = false
    favoriteButton.LayoutOrder = 2
    favoriteButton.Parent = tabWrap

    createCorner(
        favoriteButton,
        16
    )

    local function refreshTabs()
        for _, child in ipairs(
            allButton:GetChildren()
        ) do
            if child:IsA("UIGradient") then
                child:Destroy()
            end
        end

        for _, child in ipairs(
            favoriteButton:GetChildren()
        ) do
            if child:IsA("UIGradient") then
                child:Destroy()
            end
        end

        if currentTab == "all" then
            allButton.BackgroundColor3 =
                C.purple

            favoriteButton.BackgroundColor3 =
                C.backgroundDark

            createGradient(
                allButton,
                ColorSequence.new({
                    ColorSequenceKeypoint.new(
                        0,
                        C.purpleLight
                    ),
                    ColorSequenceKeypoint.new(
                        1,
                        C.purple
                    ),
                }),
                0
            )
        else
            favoriteButton.BackgroundColor3 =
                C.purple

            allButton.BackgroundColor3 =
                C.backgroundDark

            createGradient(
                favoriteButton,
                ColorSequence.new({
                    ColorSequenceKeypoint.new(
                        0,
                        C.purpleLight
                    ),
                    ColorSequenceKeypoint.new(
                        1,
                        C.purple
                    ),
                }),
                0
            )
        end
    end

    allButton.MouseButton1Click:Connect(
        function()
            if currentTab == "all" then
                return
            end

            currentTab = "all"

            refreshTabs()
            renderEmotes()
        end
    )

    favoriteButton.MouseButton1Click:Connect(
        function()
            if currentTab == "favorites" then
                return
            end

            currentTab = "favorites"

            refreshTabs()
            renderEmotes()
        end
    )

    refreshTabs()

    -- =====================================================
    -- GRID
    -- =====================================================

    resultsContainer =
        Instance.new("ScrollingFrame")

    resultsContainer.Name =
        "EmoteGrid"

    resultsContainer.Size =
        UDim2.new(1, 0, 1, -100)

    resultsContainer.BackgroundTransparency = 1
    resultsContainer.BorderSizePixel = 0

    resultsContainer.ScrollBarThickness = 2
    resultsContainer.ScrollBarImageColor3 =
        C.purple

    resultsContainer.LayoutOrder = 3
    resultsContainer.Parent = currentApp

    local grid =
        Instance.new("UIGridLayout")

    grid.CellSize =
        UDim2.new(
            0.31,
            0,
            0,
            144
        )

    grid.CellPadding =
        UDim2.new(
            0.035,
            0,
            0,
            10
        )

    grid.SortOrder =
        Enum.SortOrder.LayoutOrder

    grid.Parent =
        resultsContainer

    local resultPadding =
        Instance.new("UIPadding")

    resultPadding.PaddingTop =
        UDim.new(0, 4)

    resultPadding.PaddingBottom =
        UDim.new(0, 12)

    resultPadding.Parent =
        resultsContainer

    grid:GetPropertyChangedSignal(
        "AbsoluteContentSize"
    ):Connect(function()
        if resultsContainer then
            resultsContainer.CanvasSize =
                UDim2.new(
                    0,
                    0,
                    0,
                    grid.AbsoluteContentSize.Y + 25
                )
        end
    end)

    emptyLabel =
        Instance.new("TextLabel")

    emptyLabel.Name =
        "EmptyLabel"

    emptyLabel.Size =
        UDim2.new(1, 0, 0, 60)

    emptyLabel.BackgroundTransparency = 1

    emptyLabel.Text =
        "✨ Memuat emote..."

    emptyLabel.TextColor3 =
        C.textGray

    emptyLabel.Font =
        Enum.Font.GothamBold

    emptyLabel.TextSize = 13
    emptyLabel.ZIndex = 10

    emptyLabel.Visible =
        #Emotes == 0

    emptyLabel.Parent =
        resultsContainer

    -- =====================================================
    -- INITIAL RENDER
    -- =====================================================

    renderEmotes()

    if #Emotes == 0
        or not isLoaded() then

        fetchAllEmotes(30)
    end

    return true
end

-- =========================================================
-- GLOBAL OPEN FUNCTION
-- =========================================================

function _G.openEmoteApp()
    local success, result =
        pcall(buildEmoteApp)

    if not success then
        warn(
            "[Emote] Build error:",
            result
        )

        return false
    end

    return result
end

-- =========================================================
-- OPTIONAL GLOBAL CONTROLS
-- =========================================================

function _G.EmoteStop()
    stopEmote()
end

function _G.EmoteSetSpeed(speed)
    speed = tonumber(speed)

    if not speed then
        return
    end

    currentSpeed =
        math.clamp(
            speed,
            0.1,
            5
        )

    if currentAnimTrack then
        pcall(function()
            currentAnimTrack:AdjustSpeed(
                currentSpeed
            )
        end)
    end
end

function _G.EmoteSetLoop(enabled)
    loopEnabled =
        enabled == true

    if currentAnimTrack then
        pcall(function()
            currentAnimTrack.Looped =
                loopEnabled
        end)
    end
end

function _G.EmoteRefresh()
    if _G.renderEmotesRefresh then
        _G.renderEmotesRefresh()
    end
end

-- =========================================================
-- START
-- =========================================================

print(
    "[Emote] Ultra Premium Purple Glass loaded successfully."
)

pcall(function()
    _G.openEmoteApp()
end)