local TweenService = game:GetService("TweenService")
local T = _G.T or {}

local Helpers = {}

function Helpers.corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = o
    return c
end

function Helpers.stroke(o, c, t, tr)
    local s = Instance.new("UIStroke")
    s.Color = c or T.Border or Color3.fromRGB(200, 200, 200)
    s.Thickness = t or 1
    s.Transparency = tr or 0
    s.Parent = o
    return s
end

function Helpers.gradient(o, seq, rot)
    local g = Instance.new("UIGradient")
    g.Color = seq
    g.Rotation = rot or 90
    g.Parent = o
    return g
end

function Helpers.tween(o, p, tm, st)
    TweenService:Create(o, TweenInfo.new(tm or 0.25, st or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), p):Play()
end

function Helpers.pressFX(b)
    local orig = b.Size
    b.MouseButton1Down:Connect(function()
        Helpers.tween(b, {Size = UDim2.new(orig.X.Scale * 0.94, orig.X.Offset * 0.94, orig.Y.Scale * 0.9, orig.Y.Offset * 0.9)}, 0.06)
    end)
    b.MouseButton1Up:Connect(function()
        Helpers.tween(b, {Size = orig}, 0.12, Enum.EasingStyle.Back)
    end)
    b.MouseLeave:Connect(function()
        Helpers.tween(b, {Size = orig}, 0.12, Enum.EasingStyle.Back)
    end)
end

function Helpers.copyToClipboard(txt)
    pcall(function() setclipboard(txt) end)
    pcall(function() toclipboard(txt) end)
end

function Helpers.showDynamicNotification(text, color)
    if _G.showDynamicNotification then
        _G.showDynamicNotification(text, color)
    elseif _G.dil and _G.di then
        _G.dil.Text = text
        _G.dil.TextColor3 = Color3.new(1, 1, 1)
        _G.diStroke.Color = color or Color3.new(1, 1, 1)
    end
end

function Helpers.buildToggle(parent, initial, onChange)
    local track = Instance.new("Frame", parent)
    track.Size = UDim2.new(0, 46, 0, 26)
    track.BackgroundColor3 = initial and (T.Accent or Color3.fromRGB(30, 30, 30)) or Color3.fromRGB(180, 180, 180)
    Helpers.corner(track, 100)
    
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = initial and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    Helpers.corner(knob, 100)
    
    local btn = Instance.new("TextButton", track)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    
    local state = initial
    btn.MouseButton1Click:Connect(function()
        state = not state
        track.BackgroundColor3 = state and (T.Accent or Color3.fromRGB(30, 30, 30)) or Color3.fromRGB(180, 180, 180)
        Helpers.tween(knob, {Position = state and UDim2.new(1, -24, 0.5, -11) or UDim2.new(0, 2, 0.5, -11)}, 0.18)
        if onChange then onChange(state) end
    end)
    
    return track
end

function Helpers.buildItemRow(parent, item, order)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = T.Card2 or Color3.fromRGB(230, 230, 230)
    row.LayoutOrder = order
    Helpers.corner(row, 10)
    Helpers.stroke(row, T.Border or Color3.fromRGB(200, 200, 200), 1, 0.3)
    
    local thumb = Instance.new("ImageLabel", row)
    thumb.Size = UDim2.new(0, 42, 0, 42)
    thumb.Position = UDim2.new(0, 5, 0.5, -21)
    thumb.BackgroundColor3 = T.BG or Color3.fromRGB(255, 255, 255)
    thumb.Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. item.Value .. "&width=100&height=100&format=png"
    thumb.ScaleType = Enum.ScaleType.Fit
    Helpers.corner(thumb, 8)
    
    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -130, 0, 18)
    nameLbl.Position = UDim2.new(0, 52, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = item.Label
    nameLbl.TextColor3 = T.Text or Color3.fromRGB(30, 30, 30)
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local idLbl = Instance.new("TextLabel", row)
    idLbl.Size = UDim2.new(1, -130, 0, 16)
    idLbl.Position = UDim2.new(0, 52, 0, 24)
    idLbl.BackgroundTransparency = 1
    idLbl.Text = item.Value
    idLbl.TextColor3 = T.Green or Color3.fromRGB(0, 140, 0)
    idLbl.Font = Enum.Font.Code
    idLbl.TextSize = 10
    idLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local copyBtn = Instance.new("TextButton", row)
    copyBtn.Size = UDim2.new(0, 60, 0, 28)
    copyBtn.Position = UDim2.new(1, -66, 0.5, -14)
    copyBtn.BackgroundColor3 = T.Accent or Color3.fromRGB(30, 30, 30)
    copyBtn.Text = "Copy"
    copyBtn.TextColor3 = T.OnAccent or Color3.new(1, 1, 1)
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 10
    copyBtn.AutoButtonColor = false
    Helpers.corner(copyBtn, 6)
    Helpers.pressFX(copyBtn)
    
    copyBtn.MouseButton1Click:Connect(function()
        Helpers.copyToClipboard(item.Value)
        Helpers.showDynamicNotification("Copied: " .. item.Value, T.Green)
    end)
end

return Helpers