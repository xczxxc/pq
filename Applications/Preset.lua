-- ================================================
-- PRESET APP - Dark Theme, Custom Name, Edit, Clone, View & Wear Single
-- ================================================

local Services = _G.Services or {
    Players = game:GetService("Players"),
    HttpService = game:GetService("HttpService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage")
}
local LocalPlayer = Services.Players.LocalPlayer
local Players = Services.Players
local HttpService = Services.HttpService
local ReplicatedStorage = Services.ReplicatedStorage
local T = _G.T or {}
local Helpers = _G.Helpers or {}
local Config = _G.Config or {}
local Storage = _G.Storage or {}

local appContent = _G.appContent

local corner = Helpers.corner or function() end
local stroke = Helpers.stroke or function() end
local pressFX = Helpers.pressFX or function() end

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

if not Storage.presets then
    Storage.presets = {}
end
local presets = Storage.presets

-- ==================== LIFECYCLE ====================
local PresetLifecycle = {
    active = false,
    tasks = {},
}

local function cleanupPreset()
    PresetLifecycle.active = false
    for _, task in ipairs(PresetLifecycle.tasks) do
        pcall(function() task.cancel() end)
    end
    PresetLifecycle.tasks = {}
end

table.insert(_G.AvatarCloneCleanupTasks or {}, cleanupPreset)

-- ==================== HELPERS ====================
local function savePresets()
    if Storage.persistPresets then
        pcall(function() Storage.persistPresets() end)
    end
end

local function getItems(player)
    local items = {}
    if not player then return items end
    
    local ok, data = pcall(function()
        local response = game:HttpGet("https://avatar.roblox.com/v1/users/" .. player.UserId .. "/avatar")
        return HttpService:JSONDecode(response)
    end)
    
    if ok and data and data.assets then
        for _, asset in ipairs(data.assets) do
            if asset.id and type(asset.id) == "number" then
                table.insert(items, {
                    Value = tostring(asset.id),
                    Label = asset.name or ("Item " .. asset.id),
                    Type = "ACC",
                })
            end
        end
    end
    
    return items
end

local function fireHat(ids)
    if #ids == 0 then return end
    
    local remote = ReplicatedStorage
    local path = (Config.REMOTE_PATH or "remotes.hat"):split(".")
    for _, part in ipairs(path) do
        remote = remote:FindFirstChild(part)
        if not remote then return end
    end
    
    pcall(function()
        remote:FireServer("hat", {"hat", unpack(ids)})
    end)
end

-- ==================== OPEN PRESET APP ====================
function _G.openPresetApp()
    cleanupPreset()
    PresetLifecycle.active = true
    
    local selectedPlayer = _G.PhoneState and _G.PhoneState.selectedPlayer
    
    -- ==================== SAVE SECTION ====================
    local saveCard = Instance.new("Frame", appContent)
    saveCard.Size = UDim2.new(1, 0, 0, 130)
    saveCard.BackgroundColor3 = colors.card
    saveCard.LayoutOrder = 0
    corner(saveCard, 14)
    stroke(saveCard, colors.border, 1, 0.3)
    
    local saveTitle = Instance.new("TextLabel", saveCard)
    saveTitle.Size = UDim2.new(1, -24, 0, 22)
    saveTitle.Position = UDim2.new(0, 12, 0, 10)
    saveTitle.BackgroundTransparency = 1
    saveTitle.Text = "Save Current Player as Preset"
    saveTitle.TextColor3 = colors.text
    saveTitle.Font = Enum.Font.GothamBlack
    saveTitle.TextSize = 13
    saveTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local saveDesc = Instance.new("TextLabel", saveCard)
    saveDesc.Size = UDim2.new(1, -24, 0, 14)
    saveDesc.Position = UDim2.new(0, 12, 0, 32)
    saveDesc.BackgroundTransparency = 1
    saveDesc.Text = "Select a player first, then customize the preset name"
    saveDesc.TextColor3 = colors.text3
    saveDesc.Font = Enum.Font.Gotham
    saveDesc.TextSize = 9
    saveDesc.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Input nama preset
    local nameInput = Instance.new("TextBox", saveCard)
    nameInput.Size = UDim2.new(1, -24, 0, 32)
    nameInput.Position = UDim2.new(0, 12, 0, 50)
    nameInput.PlaceholderText = "Enter preset name..."
    nameInput.Text = selectedPlayer and (selectedPlayer.DisplayName .. " - " .. os.date("%d/%m %H:%M")) or ""
    nameInput.BackgroundColor3 = colors.card2
    nameInput.TextColor3 = colors.text
    nameInput.Font = Enum.Font.Gotham
    nameInput.TextSize = 12
    nameInput.ClearTextOnFocus = false
    corner(nameInput, 8)
    stroke(nameInput, colors.border, 1, 0.3)
    
    -- Save button
    local saveBtn = Instance.new("TextButton", saveCard)
    saveBtn.Size = UDim2.new(1, -24, 0, 34)
    saveBtn.Position = UDim2.new(0, 12, 0, 88)
    saveBtn.BackgroundColor3 = colors.accent
    saveBtn.Text = "Save Preset"
    saveBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    saveBtn.Font = Enum.Font.GothamBlack
    saveBtn.TextSize = 12
    saveBtn.AutoButtonColor = false
    corner(saveBtn, 8)
    pressFX(saveBtn)
    
    saveBtn.MouseButton1Click:Connect(function()
        if not selectedPlayer then
            if _G.showDynamicNotification then _G.showDynamicNotification("Select a player first!", colors.red) end
            return
        end
        
        local items = getItems(selectedPlayer)
        if #items == 0 then
            if _G.showDynamicNotification then _G.showDynamicNotification("Player has no items!", colors.red) end
            return
        end
        
        local presetName = nameInput.Text
        if presetName == "" or presetName:match("^%s*$") then
            presetName = selectedPlayer.DisplayName .. " - " .. os.date("%d/%m %H:%M")
        end
        
        local ids = {}
        for _, it in ipairs(items) do
            table.insert(ids, it.Value)
        end
        
        table.insert(presets, {
            name = presetName,
            ids = ids,
            date = os.date("%d/%m/%Y %H:%M"),
            favorite = false,
            playerName = selectedPlayer.DisplayName,
            playerId = selectedPlayer.UserId,
            itemCount = #ids
        })
        
        savePresets()
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Preset saved! (" .. #ids .. " items)", colors.green)
        end
        nameInput.Text = ""
        
        if _G.refreshCurr then
            _G.refreshCurr()
        end
    end)
    
    -- ==================== PRESETS LIST ====================
    if #presets == 0 then
        local emptyFrame = Instance.new("Frame", appContent)
        emptyFrame.Size = UDim2.new(1, 0, 0, 100)
        emptyFrame.BackgroundColor3 = colors.card
        emptyFrame.LayoutOrder = 1
        corner(emptyFrame, 14)
        stroke(emptyFrame, colors.border, 1, 0.4)
        
        local emptyText = Instance.new("TextLabel", emptyFrame)
        emptyText.Size = UDim2.new(1, -20, 0, 30)
        emptyText.Position = UDim2.new(0, 10, 0, 35)
        emptyText.BackgroundTransparency = 1
        emptyText.Text = "No presets saved yet"
        emptyText.TextColor3 = colors.text3
        emptyText.Font = Enum.Font.GothamBold
        emptyText.TextSize = 13
        emptyText.TextXAlignment = Enum.TextXAlignment.Center
        
        return
    end
    
    -- Sort: favorites first, then by date
    local sorted = {}
    for _, p in ipairs(presets) do
        table.insert(sorted, p)
    end
    table.sort(sorted, function(a, b)
        if a.favorite ~= b.favorite then return a.favorite end
        return (a.date or "") > (b.date or "")
    end)
    
    -- Counter
    local counterFrame = Instance.new("Frame", appContent)
    counterFrame.Size = UDim2.new(1, 0, 0, 22)
    counterFrame.BackgroundTransparency = 1
    counterFrame.LayoutOrder = 1
    
    local counterText = Instance.new("TextLabel", counterFrame)
    counterText.Size = UDim2.new(0, 120, 1, 0)
    counterText.BackgroundTransparency = 1
    counterText.Text = #sorted .. " preset" .. (#sorted ~= 1 and "s" or "")
    counterText.TextColor3 = colors.text2
    counterText.Font = Enum.Font.GothamBold
    counterText.TextSize = 10
    counterText.TextXAlignment = Enum.TextXAlignment.Left
    
    -- ==================== RENDER PRESETS ====================
    for i, preset in ipairs(sorted) do
        local row = Instance.new("Frame", appContent)
        row.Size = UDim2.new(1, 0, 0, 114)
        row.BackgroundColor3 = colors.card
        row.LayoutOrder = i + 1
        row.ClipsDescendants = true
        corner(row, 12)
        stroke(row, preset.favorite and colors.gold or colors.border, preset.favorite and 1.5 or 1, preset.favorite and 0.2 or 0.3)
        
        if preset.favorite then
            local accent = Instance.new("Frame", row)
            accent.Size = UDim2.new(0, 3, 1, -16)
            accent.Position = UDim2.new(0, 8, 0, 8)
            accent.BackgroundColor3 = colors.gold
            corner(accent, 2)
        end
        
        -- Preset name
        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size = UDim2.new(1, -24, 0, 24)
        nameLbl.Position = UDim2.new(0, 12, 0, 8)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = preset.name
        nameLbl.TextColor3 = colors.text
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Info
        local infoLbl = Instance.new("TextLabel", row)
        infoLbl.Size = UDim2.new(1, -24, 0, 16)
        infoLbl.Position = UDim2.new(0, 12, 0, 32)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = (preset.itemCount or #preset.ids) .. " items | " .. (preset.date or "")
        infoLbl.TextColor3 = colors.text2
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.TextSize = 9
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- ==================== ACTION BUTTONS ROW 1 ====================
        local btnRow1 = Instance.new("Frame", row)
        btnRow1.Size = UDim2.new(1, -24, 0, 26)
        btnRow1.Position = UDim2.new(0, 12, 0, 50)
        btnRow1.BackgroundTransparency = 1
        
        -- Clone button
        local cloneBtn = Instance.new("TextButton", btnRow1)
        cloneBtn.Size = UDim2.new(0, 70, 1, 0)
        cloneBtn.BackgroundColor3 = colors.green
        cloneBtn.Text = "Clone"
        cloneBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        cloneBtn.Font = Enum.Font.GothamBold
        cloneBtn.TextSize = 9
        cloneBtn.AutoButtonColor = false
        corner(cloneBtn, 6)
        pressFX(cloneBtn)
        
        cloneBtn.MouseButton1Click:Connect(function()
            if #preset.ids == 0 then
                if _G.showDynamicNotification then _G.showDynamicNotification("Preset has no items!", colors.red) end
                return
            end
            
            cloneBtn.Text = "Cloning..."
            cloneBtn.BackgroundColor3 = colors.gold
            
            local batchSize = Config.CLONE_BATCH_SIZE or 5
            local totalBatches = math.ceil(#preset.ids / batchSize)
            
            local function cloneBatch(batchIndex)
                if batchIndex > totalBatches then
                    cloneBtn.Text = "Done!"
                    cloneBtn.BackgroundColor3 = colors.green
                    if _G.showDynamicNotification then _G.showDynamicNotification("Clone complete!", colors.green) end
                    task.wait(1.5)
                    cloneBtn.Text = "Clone"
                    return
                end
                
                local startIdx = (batchIndex - 1) * batchSize + 1
                local endIdx = math.min(batchIndex * batchSize, #preset.ids)
                local batchIds = {}
                
                for j = startIdx, endIdx do
                    table.insert(batchIds, preset.ids[j])
                end
                
                fireHat(batchIds)
                cloneBtn.Text = batchIndex .. "/" .. totalBatches
                
                task.delay(Config.CLONE_DELAY or 6, function()
                    cloneBatch(batchIndex + 1)
                end)
            end
            
            cloneBatch(1)
        end)
        
        -- Wear All button
        local wearBtn = Instance.new("TextButton", btnRow1)
        wearBtn.Size = UDim2.new(0, 70, 1, 0)
        wearBtn.Position = UDim2.new(0, 75, 0, 0)
        wearBtn.BackgroundColor3 = colors.accent
        wearBtn.Text = "Wear All"
        wearBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
        wearBtn.Font = Enum.Font.GothamBold
        wearBtn.TextSize = 9
        wearBtn.AutoButtonColor = false
        corner(wearBtn, 6)
        pressFX(wearBtn)
        
        wearBtn.MouseButton1Click:Connect(function()
            if #preset.ids == 0 then
                if _G.showDynamicNotification then _G.showDynamicNotification("Preset has no items!", colors.red) end
                return
            end
            fireHat(preset.ids)
            if _G.showDynamicNotification then _G.showDynamicNotification("Wearing " .. #preset.ids .. " items!", colors.green) end
        end)
        
        -- View Items button (Liat Items)
        local itemsBtn = Instance.new("TextButton", btnRow1)
        itemsBtn.Size = UDim2.new(0, 70, 1, 0)
        itemsBtn.Position = UDim2.new(0, 150, 0, 0)
        itemsBtn.BackgroundColor3 = colors.card2
        itemsBtn.Text = "Items (" .. #preset.ids .. ")"
        itemsBtn.TextColor3 = colors.text
        itemsBtn.Font = Enum.Font.GothamBold
        itemsBtn.TextSize = 9
        itemsBtn.AutoButtonColor = false
        corner(itemsBtn, 6)
        stroke(itemsBtn, colors.border, 1, 0.3)
        pressFX(itemsBtn)
        
        -- Container untuk list item individual
        local itemsListFrame = Instance.new("Frame", row)
        itemsListFrame.Size = UDim2.new(1, -24, 0, 0)
        itemsListFrame.Position = UDim2.new(0, 12, 0, 114)
        itemsListFrame.BackgroundColor3 = colors.card2
        itemsListFrame.Visible = false
        itemsListFrame.ClipsDescendants = true
        corner(itemsListFrame, 8)
        stroke(itemsListFrame, colors.border, 1, 0.3)
        
        local itemsLayout = Instance.new("UIListLayout", itemsListFrame)
        itemsLayout.Padding = UDim.new(0, 4)
        
        local itemsPadding = Instance.new("UIPadding", itemsListFrame)
        itemsPadding.PaddingTop = UDim.new(0, 6)
        itemsPadding.PaddingBottom = UDim.new(0, 6)
        itemsPadding.PaddingLeft = UDim.new(0, 6)
        itemsPadding.PaddingRight = UDim.new(0, 6)

        -- Render item list
        for idx, id in ipairs(preset.ids) do
            local itemRow = Instance.new("Frame", itemsListFrame)
            itemRow.Size = UDim2.new(1, 0, 0, 24)
            itemRow.BackgroundColor3 = colors.card
            corner(itemRow, 4)
            
            local idLbl = Instance.new("TextLabel", itemRow)
            idLbl.Size = UDim2.new(1, -60, 1, 0)
            idLbl.Position = UDim2.new(0, 8, 0, 0)
            idLbl.BackgroundTransparency = 1
            idLbl.Text = "#" .. idx .. ": " .. tostring(id)
            idLbl.TextColor3 = colors.text
            idLbl.Font = Enum.Font.Gotham
            idLbl.TextSize = 9
            idLbl.TextXAlignment = Enum.TextXAlignment.Left

            -- Wear 1 Button
            local wear1Btn = Instance.new("TextButton", itemRow)
            wear1Btn.Size = UDim2.new(0, 48, 0, 18)
            wear1Btn.Position = UDim2.new(1, -52, 0.5, -9)
            wear1Btn.BackgroundColor3 = colors.accent2
            wear1Btn.Text = "Wear 1"
            wear1Btn.TextColor3 = Color3.fromRGB(0, 0, 0)
            wear1Btn.Font = Enum.Font.GothamBold
            wear1Btn.TextSize = 8
            wear1Btn.AutoButtonColor = false
            corner(wear1Btn, 4)
            pressFX(wear1Btn)

            wear1Btn.MouseButton1Click:Connect(function()
                fireHat({id})
                if _G.showDynamicNotification then
                    _G.showDynamicNotification("Wearing item: " .. id, colors.green)
                end
            end)
        end

        itemsBtn.MouseButton1Click:Connect(function()
            itemsListFrame.Visible = not itemsListFrame.Visible
            if itemsListFrame.Visible then
                local contentHeight = (#preset.ids * 28) + 12
                itemsListFrame.Size = UDim2.new(1, -24, 0, contentHeight)
                row.Size = UDim2.new(1, 0, 0, 114 + contentHeight + 8)
                itemsBtn.BackgroundColor3 = colors.accent2
                itemsBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
            else
                row.Size = UDim2.new(1, 0, 0, 114)
                itemsBtn.BackgroundColor3 = colors.card2
                itemsBtn.TextColor3 = colors.text
            end
        end)
        
        -- ==================== ACTION BUTTONS ROW 2 ====================
        local btnRow2 = Instance.new("Frame", row)
        btnRow2.Size = UDim2.new(1, -24, 0, 24)
        btnRow2.Position = UDim2.new(0, 12, 0, 82)
        btnRow2.BackgroundTransparency = 1
        
        -- Favorite button
        local favBtn = Instance.new("TextButton", btnRow2)
        favBtn.Size = UDim2.new(0, 50, 1, 0)
        favBtn.BackgroundColor3 = preset.favorite and colors.gold or colors.card2
        favBtn.Text = preset.favorite and "Unfav" or "Fav"
        favBtn.TextColor3 = preset.favorite and Color3.fromRGB(0, 0, 0) or colors.text2
        favBtn.Font = Enum.Font.GothamBold
        favBtn.TextSize = 8
        favBtn.AutoButtonColor = false
        corner(favBtn, 5)
        stroke(favBtn, colors.border, 1, 0.3)
        pressFX(favBtn)
        
        favBtn.MouseButton1Click:Connect(function()
            preset.favorite = not preset.favorite
            savePresets()
            if _G.refreshCurr then
                _G.refreshCurr()
            end
        end)
        
        -- Edit name button
        local editBtn = Instance.new("TextButton", btnRow2)
        editBtn.Size = UDim2.new(0, 50, 1, 0)
        editBtn.Position = UDim2.new(0, 55, 0, 0)
        editBtn.BackgroundColor3 = colors.card2
        editBtn.Text = "Rename"
        editBtn.TextColor3 = colors.text
        editBtn.Font = Enum.Font.GothamBold
        editBtn.TextSize = 8
        editBtn.AutoButtonColor = false
        corner(editBtn, 5)
        stroke(editBtn, colors.border, 1, 0.3)
        pressFX(editBtn)
        
        editBtn.MouseButton1Click:Connect(function()
            nameLbl.Visible = false
            
            local editInput = Instance.new("TextBox", row)
            editInput.Size = UDim2.new(1, -24, 0, 24)
            editInput.Position = UDim2.new(0, 12, 0, 8)
            editInput.Text = preset.name
            editInput.BackgroundColor3 = colors.card2
            editInput.TextColor3 = colors.text
            editInput.Font = Enum.Font.GothamBold
            editInput.TextSize = 12
            editInput.ZIndex = 10
            corner(editInput, 6)
            stroke(editInput, colors.accent2, 1.5, 0)
            
            editInput.FocusLost:Connect(function(enterPressed)
                local newName = editInput.Text
                if newName ~= "" and newName:match("%S") then
                    preset.name = newName
                    savePresets()
                    if _G.showDynamicNotification then _G.showDynamicNotification("Preset renamed!", colors.green) end
                end
                editInput:Destroy()
                nameLbl.Visible = true
                nameLbl.Text = preset.name
            end)
            
            editInput:CaptureFocus()
        end)
        
        -- Copy IDs button
        local copyBtn = Instance.new("TextButton", btnRow2)
        copyBtn.Size = UDim2.new(0, 50, 1, 0)
        copyBtn.Position = UDim2.new(0, 110, 0, 0)
        copyBtn.BackgroundColor3 = colors.card2
        copyBtn.Text = "Copy IDs"
        copyBtn.TextColor3 = colors.text
        copyBtn.Font = Enum.Font.GothamBold
        copyBtn.TextSize = 8
        copyBtn.AutoButtonColor = false
        corner(copyBtn, 5)
        stroke(copyBtn, colors.border, 1, 0.3)
        pressFX(copyBtn)
        
        copyBtn.MouseButton1Click:Connect(function()
            if Helpers.copyToClipboard then
                Helpers.copyToClipboard(table.concat(preset.ids, " "))
            elseif setclipboard then
                setclipboard(table.concat(preset.ids, " "))
            end
            if _G.showDynamicNotification then _G.showDynamicNotification("Copied " .. #preset.ids .. " IDs!", colors.green) end
        end)
        
        -- Delete button
        local delBtn = Instance.new("TextButton", btnRow2)
        delBtn.Size = UDim2.new(0, 50, 1, 0)
        delBtn.Position = UDim2.new(0, 165, 0, 0)
        delBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
        delBtn.Text = "Delete"
        delBtn.TextColor3 = colors.red
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 8
        delBtn.AutoButtonColor = false
        corner(delBtn, 5)
        stroke(delBtn, Color3.fromRGB(80, 30, 30), 1, 0.3)
        pressFX(delBtn)
        
        delBtn.MouseButton1Click:Connect(function()
            delBtn.Text = "Sure?"
            task.wait(1)
            if delBtn.Text == "Sure?" then
                local idx = table.find(presets, preset)
                if idx then
                    table.remove(presets, idx)
                end
                savePresets()
                if _G.showDynamicNotification then _G.showDynamicNotification("Preset deleted!", colors.red) end
                if _G.refreshCurr then
                    _G.refreshCurr()
                end
            end
        end)
    end
end

print("[Preset] App loaded successfully!")