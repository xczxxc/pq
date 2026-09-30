-- ================================================
-- ITEMS APP - Grid 2 Kolom Seperti Favorites
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
    accent = Color3.fromRGB(255, 255, 255),
    text = Color3.fromRGB(255, 255, 255),
    text2 = Color3.fromRGB(170, 170, 180),
    text3 = Color3.fromRGB(100, 100, 115),
    border = Color3.fromRGB(45, 45, 55),
    gold = Color3.fromRGB(255, 180, 50),
    green = Color3.fromRGB(0, 230, 118),
    red = Color3.fromRGB(255, 82, 82),
}

local favItems = Storage.favItems or {}

-- ==================== HTTP REQUEST ====================
local function httpGet(url)
    if syn and syn.request then
        local ok, result = pcall(function()
            return syn.request({Url = url, Method = "GET"})
        end)
        if ok and result and result.StatusCode == 200 and result.Body then
            return result.Body
        end
    end
    
    if http_request then
        local ok, result = pcall(function()
            return http_request({Url = url, Method = "GET"})
        end)
        if ok and result and result.StatusCode == 200 and result.Body then
            return result.Body
        end
    end
    
    if request then
        local ok, result = pcall(function()
            return request({Url = url, Method = "GET"})
        end)
        if ok and result then
            local body = result.Body or result
            if body and body ~= "" then return body end
        end
    end
    
    local ok, result = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and result and result ~= "" then return result end
    
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

local function getItems(player)
    local items = {}
    if not player then return items end
    
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
    
    return items
end

-- ==================== OPEN ITEMS APP ====================
function _G.openItemsApp()
    local selectedPlayer = _G.PhoneState and _G.PhoneState.selectedPlayer
    
    if not selectedPlayer then
        local empty = Instance.new("TextLabel", appContent)
        empty.Size = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text = "Select a player first."
        empty.TextColor3 = colors.text3
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.TextWrapped = true
        empty.LayoutOrder = 0
        return
    end
    
    -- Player header compact
    local headerCard = Instance.new("Frame", appContent)
    headerCard.Size = UDim2.new(1, 0, 0, 46)
    headerCard.BackgroundColor3 = colors.card
    headerCard.LayoutOrder = 0
    corner(headerCard, 12)
    stroke(headerCard, colors.border, 1, 0.3)
    
    local avatar = Instance.new("ImageLabel", headerCard)
    avatar.Size = UDim2.new(0, 32, 0, 32)
    avatar.Position = UDim2.new(0, 8, 0.5, -16)
    avatar.BackgroundColor3 = colors.card2
    avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. selectedPlayer.UserId .. "&width=100&height=100&format=png"
    corner(avatar, 100)
    
    local nameLbl = Instance.new("TextLabel", headerCard)
    nameLbl.Size = UDim2.new(1, -50, 0, 20)
    nameLbl.Position = UDim2.new(0, 44, 0, 5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = selectedPlayer.DisplayName
    nameLbl.TextColor3 = colors.text
    nameLbl.Font = Enum.Font.GothamBlack
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local userLbl = Instance.new("TextLabel", headerCard)
    userLbl.Size = UDim2.new(1, -50, 0, 14)
    userLbl.Position = UDim2.new(0, 44, 0, 26)
    userLbl.BackgroundTransparency = 1
    userLbl.Text = "@" .. selectedPlayer.Name
    userLbl.TextColor3 = colors.text3
    userLbl.Font = Enum.Font.Gotham
    userLbl.TextSize = 8
    userLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Get items
    local items = getItems(selectedPlayer)
    
    if #items == 0 then
        local empty = Instance.new("TextLabel", appContent)
        empty.Size = UDim2.new(1, 0, 0, 60)
        empty.BackgroundTransparency = 1
        empty.Text = "No items found for " .. selectedPlayer.DisplayName
        empty.TextColor3 = colors.text3
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 11
        empty.TextWrapped = true
        empty.LayoutOrder = 1
        return
    end
    
    -- Counter
    local counterFrame = Instance.new("Frame", appContent)
    counterFrame.Size = UDim2.new(1, 0, 0, 18)
    counterFrame.BackgroundTransparency = 1
    counterFrame.LayoutOrder = 1
    
    local counterText = Instance.new("TextLabel", counterFrame)
    counterText.Size = UDim2.new(0, 120, 1, 0)
    counterText.BackgroundTransparency = 1
    counterText.Text = #items .. " items found"
    counterText.TextColor3 = colors.text2
    counterText.Font = Enum.Font.GothamBold
    counterText.TextSize = 9
    counterText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Grid 2 kolom (seperti Favorites)
    local gridHolder = Instance.new("Frame", appContent)
    gridHolder.Size = UDim2.new(1, 0, 0, 0)
    gridHolder.AutomaticSize = Enum.AutomaticSize.Y
    gridHolder.BackgroundTransparency = 1
    gridHolder.LayoutOrder = 2
    
    local gridLayout = Instance.new("UIGridLayout", gridHolder)
    gridLayout.CellSize = UDim2.new(0.5, -6, 0, 160)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    for i, item in ipairs(items) do
        local card = Instance.new("Frame", gridHolder)
        card.Size = UDim2.new(0, 0, 0, 160)
        card.BackgroundColor3 = colors.card
        card.LayoutOrder = i
        corner(card, 12)
        stroke(card, colors.border, 1, 0.3)
        
        -- Thumbnail container
        local imgContainer = Instance.new("Frame", card)
        imgContainer.Size = UDim2.new(0, 70, 0, 70)
        imgContainer.Position = UDim2.new(0.5, -35, 0, 10)
        imgContainer.BackgroundColor3 = colors.card2
        corner(imgContainer, 10)
        stroke(imgContainer, colors.border, 1, 0.3)
        
        local thumb = Instance.new("ImageLabel", imgContainer)
        thumb.Size = UDim2.new(1, -8, 1, -8)
        thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
        thumb.AnchorPoint = Vector2.new(0.5, 0.5)
        thumb.BackgroundColor3 = colors.card2
        thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.Value .. "&width=150&height=150&format=png"
        thumb.ScaleType = Enum.ScaleType.Fit
        corner(thumb, 7)
        
        -- ID label
        local idContainer = Instance.new("Frame", card)
        idContainer.Size = UDim2.new(1, -16, 0, 18)
        idContainer.Position = UDim2.new(0, 8, 0, 86)
        idContainer.BackgroundColor3 = colors.card2
        corner(idContainer, 5)
        
        local idLabel = Instance.new("TextLabel", idContainer)
        idLabel.Size = UDim2.new(1, 0, 1, 0)
        idLabel.BackgroundTransparency = 1
        idLabel.Text = item.Value
        idLabel.TextColor3 = colors.text2
        idLabel.Font = Enum.Font.Code
        idLabel.TextSize = 9
        idLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        -- Item name
        local itemLabel = Instance.new("TextLabel", card)
        itemLabel.Size = UDim2.new(1, -16, 0, 14)
        itemLabel.Position = UDim2.new(0, 8, 0, 108)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = item.Label
        itemLabel.TextColor3 = colors.text
        itemLabel.Font = Enum.Font.GothamBold
        itemLabel.TextSize = 8
        itemLabel.TextXAlignment = Enum.TextXAlignment.Center
        itemLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Type badge
        local typeBadge = Instance.new("TextLabel", card)
        typeBadge.Size = UDim2.new(0, 35, 0, 12)
        typeBadge.Position = UDim2.new(0.5, -17, 0, 124)
        typeBadge.BackgroundColor3 = colors.card2
        typeBadge.Text = item.Type
        typeBadge.TextColor3 = colors.text3
        typeBadge.Font = Enum.Font.GothamBlack
        typeBadge.TextSize = 6
        corner(typeBadge, 6)
        stroke(typeBadge, colors.border, 1, 0.3)
        
        -- Action buttons
        local wearBtn = Instance.new("TextButton", card)
        wearBtn.Size = UDim2.new(0, 50, 0, 22)
        wearBtn.Position = UDim2.new(0.5, -53, 0, 138)
        wearBtn.BackgroundColor3 = colors.accent
        wearBtn.Text = "Wear"
        wearBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        wearBtn.Font = Enum.Font.GothamBold
        wearBtn.TextSize = 8
        wearBtn.AutoButtonColor = false
        corner(wearBtn, 6)
        pressFX(wearBtn)
        
        wearBtn.MouseButton1Click:Connect(function()
            fireHat({item.Value})
            _G.showDynamicNotification("Wearing " .. item.Value, colors.text)
        end)
        
        local favBtn = Instance.new("TextButton", card)
        favBtn.Size = UDim2.new(0, 50, 0, 22)
        favBtn.Position = UDim2.new(0.5, 3, 0, 138)
        favBtn.BackgroundColor3 = colors.card2
        favBtn.Text = "Fav"
        favBtn.TextColor3 = colors.text
        favBtn.Font = Enum.Font.GothamBold
        favBtn.TextSize = 8
        favBtn.AutoButtonColor = false
        corner(favBtn, 6)
        stroke(favBtn, colors.border, 1, 0.3)
        pressFX(favBtn)
        
        favBtn.MouseButton1Click:Connect(function()
            for _, fav in ipairs(favItems) do
                if tostring(fav.id) == item.Value then
                    _G.showDynamicNotification("Already in favorites", colors.text)
                    return
                end
            end
            
            table.insert(favItems, {
                id = item.Value,
                label = item.Label,
                date = os.date("%d/%m/%Y %H:%M"),
            })
            
            if Storage.persistFavItems then
                Storage.persistFavItems()
            end
            
            _G.showDynamicNotification("Added to favorites", colors.text)
        end)
    end
end

print("[Items] App loaded!")