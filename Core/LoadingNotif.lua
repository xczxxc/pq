-- ================================================
-- LOADING NOTIFICATION - Progress Per Aplikasi
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local TweenService = Services.TweenService
local Helpers = _G.Helpers
local Config = _G.Config

local corner = Helpers.corner
local stroke = Helpers.stroke
local tween = Helpers.tween

-- Assets
local LogoURL = Config.LogoURL or "https://files.catbox.moe/io8o2d.png"
local LocalPath = Config.LogoLocalPath or "PhoneIDViewer_Logo.png"

pcall(function()
    if not isfile(LocalPath) then
        writefile(LocalPath, game:HttpGet(LogoURL))
    end
end)

local FinalLogo = (getcustomasset and isfile(LocalPath)) and getcustomasset(LocalPath) or LogoURL

local notifGui = nil
local progressFill = nil
local statusLbl = nil
local titleLbl = nil

local function createLoadingNotification()
    if notifGui then
        pcall(function() notifGui:Destroy() end)
        notifGui = nil
    end

    notifGui = Instance.new("ScreenGui")
    notifGui.Name = "LoadingNotif"
    notifGui.ResetOnSpawn = false
    notifGui.IgnoreGuiInset = true
    notifGui.DisplayOrder = 1000
    notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

    pcall(function() notifGui.Parent = game:GetService("CoreGui") end)
    if not notifGui.Parent then
        notifGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local container = Instance.new("Frame", notifGui)
    container.Size = UDim2.new(0, 260, 0, 70)
    container.Position = UDim2.new(1, -20, 1, -20)
    container.AnchorPoint = Vector2.new(1, 1)
    container.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    container.BorderSizePixel = 0
    container.ZIndex = 1001
    container.ClipsDescendants = true
    corner(container, 16)
    stroke(container, Color3.fromRGB(255, 255, 255), 2, 0.8)

    -- Gradient
    local bgGradient = Instance.new("UIGradient", container)
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 32)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20))
    })
    bgGradient.Rotation = 135

    -- Glow line
    local glowLine = Instance.new("Frame", container)
    glowLine.Size = UDim2.new(1, 0, 0, 2)
    glowLine.Position = UDim2.new(0, 0, 0, 0)
    glowLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glowLine.BorderSizePixel = 0
    glowLine.ZIndex = 1002
    corner(glowLine, 1)

    -- Logo
    local logoFrame = Instance.new("Frame", container)
    logoFrame.Size = UDim2.new(0, 50, 0, 50)
    logoFrame.Position = UDim2.new(0, 10, 0.5, -25)
    logoFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    logoFrame.BackgroundTransparency = 0.9
    logoFrame.ZIndex = 1003
    corner(logoFrame, 10)
    stroke(logoFrame, Color3.fromRGB(255, 255, 255), 1, 0.5)

    local logoImage = Instance.new("ImageLabel", logoFrame)
    logoImage.Size = UDim2.new(1, -6, 1, -6)
    logoImage.Position = UDim2.new(0, 3, 0, 3)
    logoImage.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    logoImage.Image = FinalLogo
    logoImage.ScaleType = Enum.ScaleType.Fit
    logoImage.ZIndex = 1004
    corner(logoImage, 8)

    -- Title
    titleLbl = Instance.new("TextLabel", container)
    titleLbl.Size = UDim2.new(1, -66, 0, 22)
    titleLbl.Position = UDim2.new(0, 62, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "PhoneIDViewer"
    titleLbl.TextColor3 = Color3.new(1, 1, 1)
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.ZIndex = 1004

    -- Status
    statusLbl = Instance.new("TextLabel", container)
    statusLbl.Size = UDim2.new(1, -66, 0, 16)
    statusLbl.Position = UDim2.new(0, 62, 0, 34)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Loading..."
    statusLbl.TextColor3 = Color3.fromRGB(150, 150, 170)
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 9
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.ZIndex = 1004

    -- Progress bar
    local progressBg = Instance.new("Frame", container)
    progressBg.Size = UDim2.new(1, -16, 0, 4)
    progressBg.Position = UDim2.new(0, 8, 1, -8)
    progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    progressBg.BorderSizePixel = 0
    progressBg.ZIndex = 1003
    corner(progressBg, 2)

    progressFill = Instance.new("Frame", progressBg)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    progressFill.BorderSizePixel = 0
    progressFill.ZIndex = 1004
    corner(progressFill, 2)

    -- Animasi masuk
    container.Position = UDim2.new(1, 300, 1, -20)
    tween(container, {Position = UDim2.new(1, -20, 1, -20)}, 0.3, Enum.EasingStyle.Quart)

    return notifGui
end

function _G.updateLoadingProgress(step, totalSteps, stepName)
    if not progressFill or not statusLbl then return end
    
    local progress = math.clamp(step / totalSteps, 0, 1)
    tween(progressFill, {Size = UDim2.new(progress, 0, 1, 0)}, 0.15)
    
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = string.format("[%d/%d] %s", step, totalSteps, stepName or "Loading...")
        
        if progress >= 0.8 then
            progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        elseif progress >= 0.5 then
            progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
        end
    end
end

function _G.finishLoading()
    if statusLbl and statusLbl.Parent then
        statusLbl.Text = "✅ Selesai!"
        statusLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
    end
    
    if progressFill and progressFill.Parent then
        progressFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
        tween(progressFill, {Size = UDim2.new(1, 0, 1, 0)}, 0.2)
    end
    
    task.wait(0.8)
    
    if notifGui then
        local container = notifGui:FindFirstChildOfClass("Frame")
        if container then
            tween(container, {Position = UDim2.new(1, 300, 1, -20)}, 0.3, Enum.EasingStyle.Quart)
        end
    end
    
    task.wait(0.3)
    pcall(function() notifGui:Destroy() end)
    notifGui = nil
end

function _G.showLoadingNotification()
    return createLoadingNotification()
end

print("[LoadingNotif] Module ready!")