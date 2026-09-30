-- ================================================
-- FLOATING ICON - Muncul Cepat
-- ================================================

local Services = _G.Services
local LocalPlayer = _G.LocalPlayer
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local Helpers = _G.Helpers

local phoneIcon = nil
local isDragging = false
local dragStart = nil
local iconStartPos = nil
local clickMoved = false
local btn, container
local isHovering = false
local hasAppeared = false

local corner = Helpers.corner
local stroke = Helpers.stroke
local tween = Helpers.tween

local function createFloatingIcon()
    if phoneIcon then pcall(function() phoneIcon:Destroy() end) end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PhoneIcon"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    container = Instance.new("Frame", gui)
    container.Size = UDim2.new(0, 60, 0, 90)
    container.Position = UDim2.new(0, 15, 0.5, -45)
    container.BackgroundTransparency = 1
    container.ZIndex = 10

    btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(0, 0, 0, 0)
    btn.Position = UDim2.new(0.5, -25, 0.5, -40)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 2
    corner(btn, 14)
    stroke(btn, Color3.fromRGB(255, 255, 255), 2, 0.7)

    local screen = Instance.new("Frame", btn)
    screen.Size = UDim2.new(1, -8, 1, -28)
    screen.Position = UDim2.new(0, 4, 0, 18)
    screen.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    screen.ZIndex = 3
    corner(screen, 6)

    local notch = Instance.new("Frame", btn)
    notch.Size = UDim2.new(0, 20, 0, 4)
    notch.Position = UDim2.new(0.5, -10, 0, 7)
    notch.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notch.ZIndex = 4
    corner(notch, 2)

    local phoneIconContainer = Instance.new("Frame", screen)
    phoneIconContainer.Size = UDim2.new(0, 20, 0, 32)
    phoneIconContainer.Position = UDim2.new(0.5, -10, 0.5, -16)
    phoneIconContainer.BackgroundTransparency = 1
    phoneIconContainer.ZIndex = 5
    phoneIconContainer.Rotation = 45

    local phoneBody = Instance.new("Frame", phoneIconContainer)
    phoneBody.Size = UDim2.new(0, 10, 0, 16)
    phoneBody.Position = UDim2.new(0.5, -5, 0.5, -8)
    phoneBody.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    phoneBody.ZIndex = 6
    corner(phoneBody, 3)

    local speakerDot = Instance.new("Frame", phoneBody)
    speakerDot.Size = UDim2.new(0, 4, 0, 2)
    speakerDot.Position = UDim2.new(0.5, -2, 0, 2)
    speakerDot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    speakerDot.ZIndex = 7
    corner(speakerDot, 1)

    local homeDot = Instance.new("Frame", phoneBody)
    homeDot.Size = UDim2.new(0, 3, 0, 3)
    homeDot.Position = UDim2.new(0.5, -1.5, 1, -5)
    homeDot.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    homeDot.ZIndex = 7
    corner(homeDot, 100)

    local ledDot = Instance.new("Frame", btn)
    ledDot.Size = UDim2.new(0, 5, 0, 5)
    ledDot.Position = UDim2.new(0.5, -2.5, 0, 70)
    ledDot.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
    ledDot.ZIndex = 5
    corner(ledDot, 100)

    -- Drag system
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            clickMoved = false
            dragStart = input.Position
            iconStartPos = container.AbsolutePosition
        end
    end)

    btn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not isDragging then return end
        
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
                clickMoved = true
            end
            
            if clickMoved then
                local newX = iconStartPos.X + delta.X
                local newY = iconStartPos.Y + delta.Y
                
                local cam = Services.Workspace.CurrentCamera
                if cam then
                    local vp = cam.ViewportSize
                    newX = math.clamp(newX, 5, vp.X - 65)
                    newY = math.clamp(newY, 5, vp.Y - 95)
                end
                
                container.Position = UDim2.new(0, newX, 0, newY)
            end
        end
    end)

    -- Hover
    btn.MouseEnter:Connect(function()
        isHovering = true
        tween(btn, {Size = UDim2.new(0, 54, 0, 86)}, 0.2)
    end)

    btn.MouseLeave:Connect(function()
        isHovering = false
        if hasAppeared then
            tween(btn, {Size = UDim2.new(0, 50, 0, 80)}, 0.2)
        end
    end)

    -- Click
    -- Catatan: toggle buka/tutup di sini TIDAK menyentuh app yang sedang aktif.
    -- Saat closePhone() dipanggil, phone hanya di-hide (phone.Visible = false),
    -- app yang sedang terbuka (mis. MyClone) tetap ada sebagai child dan tetap
    -- Visible = true. Ketika openPhone() dipanggil lagi, Phone.lua akan mengecek
    -- _G.PhoneState.currentScreen — kalau bukan "home", dia TIDAK memanggil
    -- goHome(), sehingga app yang sama langsung kelihatan lagi tanpa reset.
    btn.MouseButton1Click:Connect(function()
        if clickMoved then return end
        
        local phoneFrame = _G.Phone and _G.Phone.phone
        
        if phoneFrame and phoneFrame.Visible then
            if _G.closePhone then _G.closePhone() end
        else
            if _G.openPhone then _G.openPhone() end
        end
    end)

    -- Animasi muncul cepat
    task.spawn(function()
        task.wait(0.1)
        tween(btn, {Size = UDim2.new(0, 50, 0, 80)}, 0.4, Enum.EasingStyle.Back)
        hasAppeared = true
    end)

    phoneIcon = gui
    print("[FloatingIcon] Created!")
end

-- ==================== INIT ====================
-- Langsung muncul tanpa menunggu loading selesai
task.spawn(function()
    task.wait(1)
    createFloatingIcon()
end)

-- ==================== MONITOR ====================
task.spawn(function()
    while true do
        task.wait(5)
        if not phoneIcon or not phoneIcon.Parent then
            if hasAppeared then
                createFloatingIcon()
            end
        end
    end
end)

print("[FloatingIcon] Module ready!")