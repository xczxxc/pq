-- Applications/Players.lua
local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players = Services.Players
local T = _G.T or {}
local Helpers = _G.Helpers or {}
local Storage = _G.Storage or {}

local appContent = _G.appContent

function _G.openPlayersApp()
    -- Search Box
    local searchBox = Instance.new("Frame", appContent)
    searchBox.Size = UDim2.new(1, 0, 0, 36)
    searchBox.BackgroundColor3 = T.Card2 or Color3.fromRGB(230, 230, 230)
    searchBox.LayoutOrder = 0
    Helpers.corner(searchBox, 9)
    Helpers.stroke(searchBox, T.Border or Color3.fromRGB(200, 200, 200), 1, 0.3)

    local searchInput = Instance.new("TextBox", searchBox)
    searchInput.Size = UDim2.new(1, -16, 1, 0)
    searchInput.Position = UDim2.new(0, 8, 0, 0)
    searchInput.BackgroundTransparency = 1
    searchInput.PlaceholderText = "Search player..."
    searchInput.Text = ""
    searchInput.TextColor3 = T.Text or Color3.fromRGB(30, 30, 30)
    searchInput.Font = Enum.Font.Gotham
    searchInput.TextSize = 13
    searchInput.ClearTextOnFocus = false

    -- List Holder
    local listHolder = Instance.new("Frame", appContent)
    listHolder.Size = UDim2.new(1, 0, 0, 0)
    listHolder.AutomaticSize = Enum.AutomaticSize.Y
    listHolder.BackgroundTransparency = 1
    listHolder.LayoutOrder = 1

    local listLayout = Instance.new("UIListLayout", listHolder)
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function renderList(filter)
        -- Clear
        for _, c in ipairs(listHolder:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end

        filter = (filter or ""):lower()
        local list = Players:GetPlayers()
        local favSet = Storage.favSet or {}
        local selectedPlayer = _G.PhoneState and _G.PhoneState.selectedPlayer or nil

        -- Sort: You → Fav → Alphabetical
        table.sort(list, function(a, b)
            if a == LocalPlayer then return true end
            if b == LocalPlayer then return false end
            local af = favSet[tostring(a.UserId)] and 1 or 0
            local bf = favSet[tostring(b.UserId)] and 1 or 0
            if af ~= bf then return af > bf end
            return a.DisplayName < b.DisplayName
        end)

        for i, p in ipairs(list) do
            if filter == "" or p.Name:lower():find(filter, 1, true) or p.DisplayName:lower():find(filter, 1, true) then
                local isMe = p == LocalPlayer
                local isFav = favSet[tostring(p.UserId)] == true
                local isSel = selectedPlayer == p

                -- Row
                local row = Instance.new("Frame", listHolder)
                row.Size = UDim2.new(1, 0, 0, 60)
                row.BackgroundColor3 = isSel and Color3.fromRGB(220, 220, 220) or (T.Card2 or Color3.fromRGB(230, 230, 230))
                row.LayoutOrder = i
                Helpers.corner(row, 10)
                Helpers.stroke(row, isSel and (T.Accent or Color3.fromRGB(30, 30, 30)) or (T.Border or Color3.fromRGB(200, 200, 200)), isSel and 2 or 1, isSel and 0 or 0.3)

                -- Avatar
                local av = Instance.new("ImageLabel", row)
                av.Size = UDim2.new(0, 44, 0, 44)
                av.Position = UDim2.new(0, 8, 0.5, -22)
                av.BackgroundColor3 = T.BG or Color3.fromRGB(255, 255, 255)
                av.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. p.UserId .. "&width=100&height=100&format=png"
                Helpers.corner(av, 100)

                -- Display Name
                local nameLbl = Instance.new("TextLabel", row)
                nameLbl.Size = UDim2.new(1, -170, 0, 20)
                nameLbl.Position = UDim2.new(0, 60, 0, 10)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = (isMe and "(You) " or "") .. p.DisplayName
                nameLbl.TextColor3 = isMe and (T.Accent or Color3.fromRGB(30, 30, 30)) or (T.Text or Color3.fromRGB(30, 30, 30))
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.TextSize = 13
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

                -- Username
                local userLbl = Instance.new("TextLabel", row)
                userLbl.Size = UDim2.new(1, -170, 0, 16)
                userLbl.Position = UDim2.new(0, 60, 0, 32)
                userLbl.BackgroundTransparency = 1
                userLbl.Text = "@" .. p.Name
                userLbl.TextColor3 = T.Text2 or Color3.fromRGB(120, 120, 120)
                userLbl.Font = Enum.Font.Gotham
                userLbl.TextSize = 10
                userLbl.TextXAlignment = Enum.TextXAlignment.Left

                -- Fav button
                if not isMe then
                    local starBtn = Instance.new("TextButton", row)
                    starBtn.Size = UDim2.new(0, 34, 0, 30)
                    starBtn.Position = UDim2.new(1, -108, 0.5, -15)
                    starBtn.BackgroundColor3 = isFav and (T.Gold or Color3.fromRGB(200, 150, 0)) or (T.Card or Color3.fromRGB(245, 245, 245))
                    starBtn.Text = "Fav"
                    starBtn.TextColor3 = isFav and (T.OnAccent or Color3.new(1, 1, 1)) or (T.Text2 or Color3.fromRGB(120, 120, 120))
                    starBtn.Font = Enum.Font.GothamBold
                    starBtn.TextSize = 10
                    starBtn.AutoButtonColor = false
                    Helpers.corner(starBtn, 7)
                    Helpers.stroke(starBtn, T.Border or Color3.fromRGB(200, 200, 200), 1, 0.3)
                    Helpers.pressFX(starBtn)
                    starBtn.MouseButton1Click:Connect(function()
                        local k = tostring(p.UserId)
                        if favSet[k] then
                            favSet[k] = nil
                            Helpers.showDynamicNotification("Removed from fav", T.Text2)
                        else
                            favSet[k] = true
                            Helpers.showDynamicNotification("Added to fav", T.Gold)
                        end
                        if Storage.persistFav then Storage.persistFav() end
                        renderList(searchInput.Text)
                    end)
                end

                -- Select button
                local selBtn = Instance.new("TextButton", row)
                selBtn.Size = UDim2.new(0, 66, 0, 30)
                selBtn.Position = UDim2.new(1, -72, 0.5, -15)
                selBtn.BackgroundColor3 = T.Accent or Color3.fromRGB(30, 30, 30)
                selBtn.Text = isSel and "Selected" or "Select"
                selBtn.TextColor3 = T.OnAccent or Color3.new(1, 1, 1)
                selBtn.Font = Enum.Font.GothamBold
                selBtn.TextSize = 10
                selBtn.AutoButtonColor = false
                Helpers.corner(selBtn, 7)
                Helpers.pressFX(selBtn)
                selBtn.MouseButton1Click:Connect(function()
                    if _G.PhoneState then
                        _G.PhoneState.selectedPlayer = p
                    end
                    Helpers.showDynamicNotification("Target: " .. p.DisplayName, T.Green or Color3.fromRGB(0, 140, 0))
                    renderList(searchInput.Text)
                end)
            end
        end
    end

    -- Initial render
    renderList("")

    -- Search listener
    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        renderList(searchInput.Text)
    end)
end

print("[Players] App loaded!")