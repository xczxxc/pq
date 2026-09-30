-- ================================================
-- VOLUME APP - Dark Theme
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players = Services.Players
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local T = _G.T
local Helpers = _G.Helpers

local appContent = _G.appContent
local appTitle = _G.appTitle

local corner = Helpers.corner
local stroke = Helpers.stroke
local tween = Helpers.tween
local pressFX = Helpers.pressFX

local colors = {
    card = Color3.fromRGB(25, 25, 32),
    card2 = Color3.fromRGB(30, 30, 38),
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

local globalVolumeLevel = 1

local function applyVolumeEverywhere(vol)
    globalVolumeLevel = vol
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("Sound") then
            obj.Volume = vol
        end
    end
end

function _G.openVolumeApp()
    local currentVol = globalVolumeLevel
    
    -- ==================== MASTER VOLUME ====================
    local masterFrame = Instance.new("Frame", appContent)
    masterFrame.Size = UDim2.new(1, 0, 0, 120)
    masterFrame.BackgroundColor3 = colors.card2
    masterFrame.LayoutOrder = 0
    corner(masterFrame, 12)
    stroke(masterFrame, colors.border, 1, 0.3)
    
    local mTitle = Instance.new("TextLabel", masterFrame)
    mTitle.Size = UDim2.new(1, -20, 0, 24)
    mTitle.Position = UDim2.new(0, 10, 0, 8)
    mTitle.BackgroundTransparency = 1
    mTitle.Text = "Master Volume"
    mTitle.TextColor3 = colors.text
    mTitle.Font = Enum.Font.GothamBold
    mTitle.TextSize = 14
    mTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    local volLbl = Instance.new("TextLabel", masterFrame)
    volLbl.Size = UDim2.new(1, -20, 0, 20)
    volLbl.Position = UDim2.new(0, 10, 0, 34)
    volLbl.BackgroundTransparency = 1
    volLbl.Text = "Volume: " .. math.floor(currentVol * 100) .. "%"
    volLbl.TextColor3 = colors.text
    volLbl.Font = Enum.Font.Gotham
    volLbl.TextSize = 12
    volLbl.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Slider
    local sliderBar = Instance.new("TextButton", masterFrame)
    sliderBar.Size = UDim2.new(1, -20, 0, 28)
    sliderBar.Position = UDim2.new(0, 10, 0, 56)
    sliderBar.BackgroundColor3 = colors.card
    sliderBar.Text = ""
    corner(sliderBar, 14)
    stroke(sliderBar, colors.border, 1.5, 0)
    
    local fill = Instance.new("Frame", sliderBar)
    fill.Size = UDim2.new(currentVol, 0, 1, 0)
    fill.BackgroundColor3 = colors.accent2
    corner(fill, 14)
    
    local function setMasterVol(percent)
        currentVol = math.clamp(percent, 0, 1)
        applyVolumeEverywhere(currentVol)
        fill.Size = UDim2.new(currentVol, 0, 1, 0)
        volLbl.Text = "Volume: " .. math.floor(currentVol * 100) .. "%"
    end
    
    sliderBar.MouseButton1Down:Connect(function()
        local con
        con = RunService.RenderStepped:Connect(function()
            local mousePos = UserInputService:GetMouseLocation()
            local absX = sliderBar.AbsolutePosition.X
            local absSizeX = sliderBar.AbsoluteSize.X
            if absSizeX <= 0 then absSizeX = 1 end
            local relX = (mousePos.X - absX) / absSizeX
            setMasterVol(math.clamp(relX, 0, 1))
            
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                con:Disconnect()
            end
        end)
    end)
    
    -- Mute/Max buttons
    local btnContainer = Instance.new("Frame", masterFrame)
    btnContainer.Size = UDim2.new(1, -20, 0, 28)
    btnContainer.Position = UDim2.new(0, 10, 0, 88)
    btnContainer.BackgroundTransparency = 1
    
    local muteBtn = Instance.new("TextButton", btnContainer)
    muteBtn.Size = UDim2.new(0.48, 0, 1, 0)
    muteBtn.BackgroundColor3 = colors.card
    muteBtn.Text = "Mute"
    muteBtn.TextColor3 = colors.text
    muteBtn.Font = Enum.Font.GothamBold
    muteBtn.TextSize = 12
    muteBtn.AutoButtonColor = false
    corner(muteBtn, 8)
    stroke(muteBtn, colors.border, 1, 0.3)
    pressFX(muteBtn)
    muteBtn.MouseButton1Click:Connect(function() setMasterVol(0) end)
    
    local maxBtn = Instance.new("TextButton", btnContainer)
    maxBtn.Size = UDim2.new(0.48, 0, 1, 0)
    maxBtn.Position = UDim2.new(0.52, 0, 0, 0)
    maxBtn.BackgroundColor3 = colors.card
    maxBtn.Text = "Max"
    maxBtn.TextColor3 = colors.text
    maxBtn.Font = Enum.Font.GothamBold
    maxBtn.TextSize = 12
    maxBtn.AutoButtonColor = false
    corner(maxBtn, 8)
    stroke(maxBtn, colors.border, 1, 0.3)
    pressFX(maxBtn)
    maxBtn.MouseButton1Click:Connect(function() setMasterVol(1) end)
    
    -- ==================== ACTIVE SOUNDS ====================
    local activeTitle = Instance.new("TextLabel", appContent)
    activeTitle.Size = UDim2.new(1, 0, 0, 20)
    activeTitle.BackgroundTransparency = 1
    activeTitle.Text = "Active Sounds"
    activeTitle.TextColor3 = colors.text
    activeTitle.Font = Enum.Font.GothamBold
    activeTitle.TextSize = 12
    activeTitle.TextXAlignment = Enum.TextXAlignment.Left
    activeTitle.LayoutOrder = 1
    
    local soundsHolder = Instance.new("Frame", appContent)
    soundsHolder.Size = UDim2.new(1, 0, 0, 0)
    soundsHolder.AutomaticSize = Enum.AutomaticSize.Y
    soundsHolder.BackgroundTransparency = 1
    soundsHolder.LayoutOrder = 2
    
    local soundsLayout = Instance.new("UIListLayout", soundsHolder)
    soundsLayout.Padding = UDim.new(0, 4)
    
    local function refreshSoundsList()
        for _, c in ipairs(soundsHolder:GetChildren()) do
            if not c:IsA("UIListLayout") then c:Destroy() end
        end
        
        local activeSounds = {}
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("Sound") and obj.IsPlaying then
                table.insert(activeSounds, obj)
            end
        end
        
        if #activeSounds == 0 then
            local n = Instance.new("TextLabel", soundsHolder)
            n.Size = UDim2.new(1, 0, 0, 30)
            n.BackgroundTransparency = 1
            n.Text = "No active sounds."
            n.TextColor3 = colors.text3
            n.Font = Enum.Font.Gotham
            n.TextSize = 11
            return
        end
        
        for _, snd in ipairs(activeSounds) do
            local row = Instance.new("Frame", soundsHolder)
            row.Size = UDim2.new(1, 0, 0, 44)
            row.BackgroundColor3 = colors.card2
            corner(row, 8)
            stroke(row, colors.border, 1, 0.3)
            
            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size = UDim2.new(1, -100, 0, 18)
            nameLbl.Position = UDim2.new(0, 6, 0, 4)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = snd.Name
            nameLbl.TextColor3 = colors.text
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.TextSize = 11
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            
            local sndVolLbl = Instance.new("TextLabel", row)
            sndVolLbl.Size = UDim2.new(0, 40, 0, 16)
            sndVolLbl.Position = UDim2.new(0, 6, 0, 24)
            sndVolLbl.BackgroundTransparency = 1
            sndVolLbl.Text = math.floor(snd.Volume * 100) .. "%"
            sndVolLbl.TextColor3 = colors.text2
            sndVolLbl.Font = Enum.Font.Gotham
            sndVolLbl.TextSize = 10
            
            local sndSlider = Instance.new("TextButton", row)
            sndSlider.Size = UDim2.new(1, -140, 0, 18)
            sndSlider.Position = UDim2.new(0, 46, 0, 24)
            sndSlider.BackgroundColor3 = colors.card
            sndSlider.Text = ""
            corner(sndSlider, 9)
            stroke(sndSlider, colors.border, 1, 0)
            
            local sndFill = Instance.new("Frame", sndSlider)
            sndFill.Size = UDim2.new(snd.Volume, 0, 1, 0)
            sndFill.BackgroundColor3 = colors.accent2
            corner(sndFill, 9)
            
            local function setSndVol(v)
                v = math.clamp(v, 0, 1)
                snd.Volume = v
                sndVolLbl.Text = math.floor(v * 100) .. "%"
                sndFill.Size = UDim2.new(v, 0, 1, 0)
            end
            
            sndSlider.MouseButton1Down:Connect(function()
                local con
                con = RunService.RenderStepped:Connect(function()
                    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                        con:Disconnect()
                        return
                    end
                    local mousePos = UserInputService:GetMouseLocation()
                    local relX = (mousePos.X - sndSlider.AbsolutePosition.X) / sndSlider.AbsoluteSize.X
                    setSndVol(relX)
                end)
            end)
            
            local muteBtn = Instance.new("TextButton", row)
            muteBtn.Size = UDim2.new(0, 40, 0, 22)
            muteBtn.Position = UDim2.new(1, -96, 0, 20)
            muteBtn.BackgroundColor3 = colors.card
            muteBtn.Text = "Mute"
            muteBtn.TextColor3 = colors.text
            muteBtn.Font = Enum.Font.GothamBold
            muteBtn.TextSize = 9
            muteBtn.AutoButtonColor = false
            corner(muteBtn, 5)
            pressFX(muteBtn)
            muteBtn.MouseButton1Click:Connect(function()
                if snd.Volume > 0 then
                    setSndVol(0)
                else
                    setSndVol(0.5)
                end
            end)
            
            local stopBtn = Instance.new("TextButton", row)
            stopBtn.Size = UDim2.new(0, 40, 0, 22)
            stopBtn.Position = UDim2.new(1, -50, 0, 20)
            stopBtn.BackgroundColor3 = colors.red
            stopBtn.Text = "Stop"
            stopBtn.TextColor3 = Color3.new(1, 1, 1)
            stopBtn.Font = Enum.Font.GothamBold
            stopBtn.TextSize = 9
            stopBtn.AutoButtonColor = false
            corner(stopBtn, 5)
            pressFX(stopBtn)
            stopBtn.MouseButton1Click:Connect(function()
                snd:Stop()
            end)
        end
    end
    
    refreshSoundsList()
    
    task.spawn(function()
        while appContent.Parent do
            task.wait(2)
            if appTitle and appTitle.Text == "Volume" then
                refreshSoundsList()
            end
        end
    end)
end

print("[Volume] App loaded!")