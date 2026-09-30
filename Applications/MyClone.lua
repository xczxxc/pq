-- ================================================
-- MyClone.lua - MyClone App (Phone UI Enhanced & Fixed)
-- Fixed: State persistence on close, UI Overflow, App Reload Memory
-- ================================================

local Services = _G.Services or {
    Players = game:GetService("Players"),
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    HttpService = game:GetService("HttpService"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    TextChatService = game:GetService("TextChatService"),
    Debris = game:GetService("Debris"),
}

local Players = Services.Players
local Workspace = Services.Workspace
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local RunService = Services.RunService
local CoreGui = Services.CoreGui
local TextChatService = Services.TextChatService
local Debris = Services.Debris or game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local T = _G.T or {}
local Helpers = _G.Helpers or {}
local Storage = _G.Storage or {}

-- Alias helpers with safe fallbacks
local corner = Helpers.corner or function(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
end

local stroke = Helpers.stroke or function(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(60, 60, 80)
    s.Thickness = thickness or 1
    s.Parent = parent
end

local pressFX = Helpers.pressFX or function(btn)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset - 2, btn.Size.Y.Scale, btn.Size.Y.Offset - 2)}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, btn.Size.Y.Offset)}):Play()
    end)
end

-- ================================================
-- CONSTANTS & GLOBAL PERSISTENT STATE
-- ================================================
local FOLDER_NAME = "MyCloneFolder_V15"
local CONFIG_FILE = "MyClone_Config.json"
local CONFIG_SLOTS_FILE = "MyClone_ConfigSlots.json"
local VISUAL_CLONE_FILE = "MyClone_VisualClones.json"
local HISTORY_FILE = "MyClone_History.json"
local FAVORITES_FILE = "MyClone_Favorites.json"
local API_KEY_FILE = "MyClone_ApiKey.txt"
local FAV_PLAYERS_FILE = "MyClone_FavPlayers.json"

local COLORS = {
    Background = Color3.fromRGB(10, 11, 16),
    Panel = Color3.fromRGB(20, 22, 30),
    Panel2 = Color3.fromRGB(28, 30, 42),
    Panel3 = Color3.fromRGB(36, 39, 54),
    White = Color3.fromRGB(250, 250, 255),
    SoftWhite = Color3.fromRGB(210, 215, 230),
    Gray = Color3.fromRGB(135, 140, 160),
    DarkGray = Color3.fromRGB(75, 80, 95),
    Red = Color3.fromRGB(255, 65, 85),
    RedDark = Color3.fromRGB(180, 35, 55),
    Purple = Color3.fromRGB(140, 80, 255),
    PurpleDark = Color3.fromRGB(90, 45, 180),
    Green = Color3.fromRGB(50, 225, 130),
    Blue = Color3.fromRGB(60, 160, 255),
    Orange = Color3.fromRGB(255, 150, 50),
    Delete = Color3.fromRGB(95, 28, 38),
    DeleteActive = Color3.fromRGB(160, 35, 50),
    Gold = Color3.fromRGB(255, 205, 90),
    GoldDark = Color3.fromRGB(180, 140, 40),
    Emerald = Color3.fromRGB(45, 200, 150),
}

local function applyGradient(guiObject, colorA, colorB, rotation)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(colorA, colorB)
    gradient.Rotation = rotation or 90
    gradient.Parent = guiObject
    return gradient
end

local function applyShadow(guiObject, transparency)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "SoftShadow"
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://5554236805"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = transparency or 0.55
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(23, 23, 277, 277)
    shadow.Size = UDim2.new(1, 24, 1, 24)
    shadow.Position = UDim2.new(0, -12, 0, -12)
    shadow.ZIndex = guiObject.ZIndex - 1
    shadow.Parent = guiObject.Parent
    return shadow
end

-- Persistent Variables across UI close/reopen
_G.MyCloneState = _G.MyCloneState or {
    CloneData = {},
    SelectedClone = nil,
    CloneCounter = 0,
    EditMode = false,
    PositionMode = false,
    RotationMode = false,
    DanceMode = false,
    SyncTargetMode = false,
    SyncTargetPlayer = nil,
    CurrentTab = "Clones",
    HistoryList = {},
    FavoritesList = {},
    GroqApiKey = nil,
    HideAllNames = false,
    AIChatEnabled = false,
    AIChatCooldown = 10,
    AIChatLastTime = 0,
    ManualChatTarget = nil,
    VariationShape = "Circle",
    VariationRadius = 8,
    VariationCount = 6,
    PlayersSubTab = "Players",
    FriendsList = {},
    FavoritesPlayersList = {},
    FollowMeMode = false,
    FreezePoseMode = false,
    RainbowNameMode = false,
    AIChatStatus = "Belum aktif",
    AIChatLastError = nil,
    RobloxFriendsLoaded = false,
    RobloxFriendsList = {},
    RobloxFriendsLoading = false,
    OrbitMode = false,
    PulseGlowMode = false,
    MimicMode = false,
    -- Config multi-slot
    ConfigSlots = {},
    LastConfigSlot = nil,
    -- Sync upgrade
    SyncBroadcastMode = false,
    SyncAutoReconnect = true,
    -- Prank fitur
    GhostModeActive = false,
    RagdollPrankActive = false,
    RandomSwapActive = false,
    MemeChatActive = false,
    MemeChatInterval = 8,
    -- Clone Visual (ubah TAMPILAN DIRI SENDIRI jadi meniru avatar orang lain)
    VisualCloneSlots = {}, -- {[nama] = {userId=, username=, savedAt=}}
    VisualCloneActive = false, -- sedang ber-transformasi jadi orang lain?
    VisualCloneCurrentUserId = nil,
    VisualCloneCurrentName = nil,
    VisualCloneOriginalAppearanceId = nil, -- buat kembali ke wajah asli
    VisualClonePersist = true, -- tetap pakai tampilan clone walau ganti map/respawn
}

local State = _G.MyCloneState

local CurrentAnimatorConnection = nil
local SyncLoop = nil
local AIChatLoop = nil
local FollowMeLoop = nil
local RainbowLoop = nil
local GizmoDragging = false
local CameraRestoreType = nil
local CameraRestoreSubject = nil
local DeleteAllArmed = false
local DeleteAllFriendsArmed = false
local GhostModeLoop = nil
local RagdollPrankLoop = nil
local RandomSwapLoop = nil
local MemeChatLoop = nil

local GROQ_MODELS = {
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "gemma2-9b-it",
    "llama3-70b-8192",
    "llama3-8b-8192",
}

local MEME_LINES = {
    "bang, ini aku apa bayangan ya??",
    "kok jadi ada 2 gini sih ????",
    "aku juga bingung sebenarnya siapa yang asli",
    "eh sadar gak sih kita kembar",
    "udah ku duga bakal ada yang nge-clone",
    "halo, salam kenal, aku versi 2.0 nya",
    "kok mirip banget sama aku ya??",
    "system error: 2 orang sama terdeteksi",
    "jangan panik, ini cuma efek clone kok",
    "gimana caranya bisa jadi 2 gini wkwk",
}

-- References UI
local tabBarFrame = nil
local tabContentFrame = nil

-- Gizmos Persistent
_G.MyCloneGizmos = _G.MyCloneGizmos or {}
local Gizmos = _G.MyCloneGizmos

-- Forward Declarations
local rebuildCurrentTab, rebuildEditorTab, rebuildClonesTab, rebuildHistoryTab, rebuildSyncTab, rebuildAIChatTab
local rebuildVariasiTab, rebuildPlayersTab, rebuildVisualCloneTab

-- ================================================
-- UTILITY FUNCTIONS
-- ================================================
local function GetDisplayName(userId)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then return player.DisplayName end
    end
    local success, data = pcall(function()
        return game:HttpGet("https://users.roblox.com/v1/users/" .. userId)
    end)
    if success and data then
        local parsed = HttpService:JSONDecode(data)
        if parsed and parsed.displayName then return parsed.displayName end
    end
    return nil
end

local function ResolveUserId(value)
    value = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return LocalPlayer.UserId, true end
    local number = tonumber(value)
    if number then return number, false end
    local success, userId = pcall(function() return Players:GetUserIdFromNameAsync(value) end)
    if success and userId then return userId, false end
    return nil, false
end

local function CreateAvatarFromUserId(userId)
    local success, model = pcall(function() return Players:CreateHumanoidModelFromUserIdAsync(userId) end)
    if success and model then return model end
    local descSuccess, description = pcall(function() return Players:GetHumanoidDescriptionFromUserIdAsync(userId) end)
    if descSuccess and description then
        local modelSuccess, generated = pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15, Enum.AssetTypeVerification.Default)
        end)
        if modelSuccess then return generated end
    end
    return nil
end

local function PrepareCloneModel(model)
    if not model then return end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") or object:IsA("ModuleScript") then
            object:Destroy()
        end
    end
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then model.PrimaryPart = root else
        local part = model:FindFirstChildOfClass("BasePart")
        if part then model.PrimaryPart = part end
    end
    pcall(function() model:MakeJoints() end)
end

-- ================================================
-- CLONE VISUAL — CORE DARI cek.lua (TRUE VISUAL AVATAR SWAP)
-- Mengganti Character lokal dengan model avatar target yang dibuat
-- dari HumanoidDescription. Bukan NPC terpisah.
-- ================================================

local OriginalDesc = nil
local VisualCloneTransforming = false
local VisualCloneWatchdogBusy = false

local function CaptureOriginal()
    if OriginalDesc then return true end
    local ch = LocalPlayer.Character
    if not ch then return false end

    local h = ch:FindFirstChildOfClass("Humanoid")
    if not h then return false end

    local ok, desc = pcall(function()
        return h:GetAppliedDescription()
    end)
    if ok and desc then
        OriginalDesc = desc
        return true
    end

    local ok2, fallback = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(LocalPlayer.UserId)
    end)
    if ok2 and fallback then
        OriginalDesc = fallback
        return true
    end
    return false
end

local function PlayCloneTransformEffect(position)
    if not position then return end
    pcall(function()
        local effectPart = Instance.new("Part")
        effectPart.Name = "MyClone_VisualTransformEffect"
        effectPart.Size = Vector3.new(1, 1, 1)
        effectPart.Position = position
        effectPart.Anchored = true
        effectPart.CanCollide = false
        effectPart.CanTouch = false
        effectPart.CanQuery = false
        effectPart.Transparency = 1
        effectPart.Parent = Workspace

        local sparkle = Instance.new("Sparkles")
        sparkle.SparkleColor = COLORS.Gold
        sparkle.Parent = effectPart

        local light = Instance.new("PointLight")
        light.Brightness = 4
        light.Range = 14
        light.Color = COLORS.Gold
        light.Parent = effectPart

        TweenService:Create(light, TweenInfo.new(0.7), {
            Brightness = 0,
            Range = 3,
        }):Play()
        Debris:AddItem(effectPart, 1.0)
    end)
end

-- Animate diambil dari karakter lama supaya idle/walk/run/jump tetap normal.
local function SetupVisualCloneAnimations(newChar, oldChar)
    local humanoid = newChar and newChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local animSrc = nil
    if oldChar then
        animSrc = oldChar:FindFirstChild("Animate")
    end

    if not animSrc then
        pcall(function()
            animSrc = game:GetService("StarterPlayer").StarterCharacterScripts:FindFirstChild("Animate")
        end)
    end

    if animSrc then
        pcall(function()
            local animateClone = animSrc:Clone()
            animateClone.Disabled = false
            animateClone.Parent = newChar
        end)
        return
    end

    -- Fallback kalau Animate tidak ditemukan.
    task.spawn(function()
        task.wait(0.25)
        if not newChar.Parent or not humanoid.Parent then return end

        local function playAnimation(id, looped)
            local animation = Instance.new("Animation")
            animation.AnimationId = "rbxassetid://" .. tostring(id)

            local ok, track = pcall(function()
                return animator:LoadAnimation(animation)
            end)

            if ok and track then
                track.Looped = looped == true
                track:Play(0.1)
                return track
            end
        end

        playAnimation(507766388, true)

        humanoid.Running:Connect(function(speed)
            if not newChar.Parent then return end
            if speed > 0.5 then
                playAnimation(507767714, true)
            end
        end)
    end)
end

-- CORE DARI cek.lua:
-- buat model baru dari HumanoidDescription lalu jadikan Character LocalPlayer.
local function DoVisualCloneSwap(description, oldChar)
    if not description then
        return false, "HumanoidDescription tidak tersedia"
    end

    local spawnCF = CFrame.new(0, 5, 0)
    pcall(function()
        local root = oldChar and (
            oldChar:FindFirstChild("HumanoidRootPart")
            or oldChar.PrimaryPart
        )
        if root then
            spawnCF = root.CFrame
        end
    end)

    local rigType = Enum.HumanoidRigType.R15
    pcall(function()
        local oldHumanoid = oldChar and oldChar:FindFirstChildOfClass("Humanoid")
        if oldHumanoid then
            rigType = oldHumanoid.RigType
        end
    end)

    local ok, newChar = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(description, rigType)
    end)

    if not ok or not newChar then
        local fallbackOk, fallbackChar = pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(
                description,
                Enum.HumanoidRigType.R15
            )
        end)
        if fallbackOk and fallbackChar then
            newChar = fallbackChar
        else
            return false, "Gagal membuat karakter dari HumanoidDescription"
        end
    end

    -- Hapus script bawaan model; Animate dipasang sendiri.
    for _, obj in ipairs(newChar:GetDescendants()) do
        if obj:IsA("BaseScript") then
            obj:Destroy()
        end
    end

    local newHumanoid = newChar:FindFirstChildOfClass("Humanoid")
    if not newHumanoid then
        newChar:Destroy()
        return false, "Model avatar tidak memiliki Humanoid"
    end

    local root = newChar:FindFirstChild("HumanoidRootPart")
    if root then
        newChar.PrimaryPart = root
    else
        local firstPart = newChar:FindFirstChildWhichIsA("BasePart", true)
        if firstPart then
            newChar.PrimaryPart = firstPart
        end
    end

    -- Invisible dulu untuk mencegah flicker.
    for _, obj in ipairs(newChar:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Transparency = 1
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        end
    end

    newChar.Name = LocalPlayer.Name
    pcall(function()
        newChar:PivotTo(spawnCF)
    end)
    newChar.Parent = Workspace

    -- Sembunyikan karakter lama sebelum replace.
    if oldChar and oldChar.Parent then
        for _, obj in ipairs(oldChar:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("Decal") then
                obj.Transparency = 1
            end
        end
    end

    -- Sama seperti cek.lua: karakter baru menjadi Character asli.
    LocalPlayer.Character = newChar

    -- Hapus karakter lama agar tidak dobel.
    if oldChar and oldChar.Parent and oldChar ~= newChar then
        task.delay(0.05, function()
            pcall(function()
                if oldChar and oldChar.Parent then
                    oldChar:Destroy()
                end
            end)
        end)
    end

    -- Kamera mengikuti Humanoid karakter baru.
    pcall(function()
        local camera = Workspace.CurrentCamera
        if camera then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = newHumanoid
        end
    end)

    SetupVisualCloneAnimations(newChar, oldChar)

    -- HRP selalu invisible; body lain fade-in.
    for _, obj in ipairs(newChar:GetDescendants()) do
        if obj:IsA("BasePart") then
            if obj.Name == "HumanoidRootPart" then
                obj.Transparency = 1
            else
                pcall(function()
                    TweenService:Create(
                        obj,
                        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Transparency = 0}
                    ):Play()
                end)
            end
        elseif obj:IsA("Decal") then
            pcall(function()
                TweenService:Create(
                    obj,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Transparency = 0}
                ):Play()
            end)
        end
    end

    return true, newChar
end

local function GetTargetDescription(userId)
    -- Target online: AppliedDescription paling akurat.
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local ok, description = pcall(function()
                        return humanoid:GetAppliedDescription()
                    end)
                    if ok and description then
                        return description
                    end
                end
            end
            break
        end
    end

    -- Fallback target offline / karakter belum siap.
    local ok, description = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
    end)
    if ok and description then
        return description
    end

    return nil
end

local function ApplyCloneVisualToSelf(userId, displayLabel)
    if VisualCloneTransforming then
        return false, "Sedang memproses clone visual"
    end

    userId = tonumber(userId)
    if not userId then
        return false, "UserId target tidak valid"
    end

    if not LocalPlayer.Character then
        return false, "Karaktermu belum siap"
    end

    if not CaptureOriginal() then
        return false, "Gagal menyimpan avatar asli"
    end

    VisualCloneTransforming = true

    local oldChar = LocalPlayer.Character
    local oldRoot = oldChar and (
        oldChar:FindFirstChild("HumanoidRootPart")
        or oldChar.PrimaryPart
    )

    if oldRoot then
        PlayCloneTransformEffect(oldRoot.Position)
    end

    local description = GetTargetDescription(userId)
    if not description then
        VisualCloneTransforming = false
        return false, "Gagal mengambil avatar target"
    end

    local ok, result = DoVisualCloneSwap(description, oldChar)
    if not ok then
        VisualCloneTransforming = false
        return false, tostring(result)
    end

    State.VisualCloneActive = true
    State.VisualCloneCurrentUserId = userId
    State.VisualCloneCurrentName = displayLabel or tostring(userId)

    -- Compatibility field lama; bukan sumber transformasi.
    State.VisualCloneOriginalAppearanceId = LocalPlayer.UserId

    VisualCloneTransforming = false
    return true, "Berhasil clone visual menjadi " .. (displayLabel or tostring(userId))
end

local function ResetCloneVisual()
    if VisualCloneTransforming then
        return false, "Sedang memproses transformasi"
    end

    if not OriginalDesc then
        CaptureOriginal()
    end

    if not OriginalDesc then
        return false, "Avatar asli belum tersimpan"
    end

    if not LocalPlayer.Character then
        return false, "Karaktermu belum siap"
    end

    VisualCloneTransforming = true

    local oldChar = LocalPlayer.Character
    local root = oldChar and (
        oldChar:FindFirstChild("HumanoidRootPart")
        or oldChar.PrimaryPart
    )

    if root then
        PlayCloneTransformEffect(root.Position)
    end

    local ok, result = DoVisualCloneSwap(OriginalDesc, oldChar)
    if not ok then
        VisualCloneTransforming = false
        return false, tostring(result)
    end

    State.VisualCloneActive = false
    State.VisualCloneCurrentUserId = nil
    State.VisualCloneCurrentName = nil

    VisualCloneTransforming = false
    return true, "Avatar dikembalikan ke wujud asli"
end

-- Persist opsional setelah respawn.
local function StartVisualCloneWatchdog()
    LocalPlayer.CharacterAdded:Connect(function(newCharacter)
        if VisualCloneWatchdogBusy then return end
        if not State.VisualCloneActive then return end
        if not State.VisualClonePersist then return end
        if not State.VisualCloneCurrentUserId then return end

        VisualCloneWatchdogBusy = true

        task.spawn(function()
            task.wait(0.8)

            if not newCharacter or not newCharacter.Parent then
                VisualCloneWatchdogBusy = false
                return
            end

            if not State.VisualCloneActive or not State.VisualCloneCurrentUserId then
                VisualCloneWatchdogBusy = false
                return
            end

            local description = GetTargetDescription(State.VisualCloneCurrentUserId)

            if description and newCharacter == LocalPlayer.Character then
                local swapOK = DoVisualCloneSwap(description, newCharacter)
                if swapOK then
                    State.VisualCloneActive = true
                end
            end

            VisualCloneWatchdogBusy = false
        end)
    end)
end

StartVisualCloneWatchdog()

local function GetNextSpawnCFrame()
    local character = LocalPlayer.Character
    if not character then return CFrame.new(0, 3, -5) end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return CFrame.new(0, 3, -5) end
    return root.CFrame * CFrame.new(0, 0, -5)
end

local function IsSyncTrack(track)
    local priority = track.Priority
    if priority == Enum.AnimationPriority.Action or
        priority == Enum.AnimationPriority.Action2 or
        priority == Enum.AnimationPriority.Action3 or
        priority == Enum.AnimationPriority.Action4 then
        return true
    end
    local name = string.lower(track.Name or "")
    if string.find(name, "walk") or string.find(name, "run") or
        string.find(name, "jump") or string.find(name, "fall") or
        string.find(name, "idle") or string.find(name, "climb") or
        string.find(name, "swim") or string.find(name, "sit") or
        string.find(name, "sleep") then
        return false
    end
    return true
end

local function GetAnimator(character)
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then return animator end
    animator = Instance.new("Animator")
    animator.Parent = humanoid
    return animator
end

local function StopAllCloneEmotes()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if not folder then return end
    for _, clone in ipairs(folder:GetChildren()) do
        if clone:IsA("Model") then
            local animator = GetAnimator(clone)
            if animator then
                for _, trk in ipairs(animator:GetPlayingAnimationTracks()) do
                    if IsSyncTrack(trk) then trk:Stop() end
                end
            end
        end
    end
end

local function PlayTrackOnClone(clone, sourceTrack)
    if not clone or not sourceTrack or not sourceTrack.Animation then return end
    local animator = GetAnimator(clone)
    if not animator then return end
    local animation = sourceTrack.Animation
    if not animation.AnimationId or animation.AnimationId == "" then return end
    for _, trk in ipairs(animator:GetPlayingAnimationTracks()) do
        if trk.Animation and trk.Animation.AnimationId == animation.AnimationId then
            trk:AdjustSpeed(sourceTrack.Speed)
            return trk
        end
    end
    local success, cloneTrack = pcall(function() return animator:LoadAnimation(animation) end)
    if not success or not cloneTrack then return end
    cloneTrack.Priority = sourceTrack.Priority
    cloneTrack.Looped = sourceTrack.Looped
    cloneTrack:Play(0.1, 1, math.max(sourceTrack.Speed, 0.1))
    return cloneTrack
end

local function ApplyDanceToSelected(callback)
    if State.SelectedClone and State.SelectedClone.Parent then callback(State.SelectedClone) end
end

local function ApplySyncToAll(callback)
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if not folder then return end
    for _, clone in ipairs(folder:GetChildren()) do
        if clone:IsA("Model") then callback(clone) end
    end
end

local function StartSyncLoop()
    if SyncLoop then SyncLoop:Disconnect(); SyncLoop = nil end
    if not (State.DanceMode or State.SyncTargetMode) then return end

    SyncLoop = RunService.Heartbeat:Connect(function()
        if not (State.DanceMode or State.SyncTargetMode) then return end
        local sourcePlayer = State.SyncTargetMode and State.SyncTargetPlayer or (State.DanceMode and LocalPlayer or nil)
        if not sourcePlayer then return end
        local character = sourcePlayer.Character
        if not character then return end
        local sourceAnimator = GetAnimator(character)
        if not sourceAnimator then return end
        local sourceTracks = sourceAnimator:GetPlayingAnimationTracks()
        local currentSyncAnimIds = {}
        for _, track in ipairs(sourceTracks) do
            if track.IsPlaying and IsSyncTrack(track) then
                currentSyncAnimIds[track.Animation.AnimationId] = track
            end
        end

        local applyFunc = State.DanceMode and ApplyDanceToSelected or ApplySyncToAll
        applyFunc(function(clone)
            local cloneAnimator = GetAnimator(clone)
            if not cloneAnimator then return end
            for _, cloneTrack in ipairs(cloneAnimator:GetPlayingAnimationTracks()) do
                if IsSyncTrack(cloneTrack) and not currentSyncAnimIds[cloneTrack.Animation.AnimationId] then
                    cloneTrack:Stop()
                end
            end
            for _, sourceTrack in pairs(currentSyncAnimIds) do
                PlayTrackOnClone(clone, sourceTrack)
            end
        end)
    end)
end

local function StopSyncSystem()
    if SyncLoop then SyncLoop:Disconnect(); SyncLoop = nil end
    if CurrentAnimatorConnection then CurrentAnimatorConnection:Disconnect(); CurrentAnimatorConnection = nil end
    StopAllCloneEmotes()
end

local function SetupDanceSync()
    StopSyncSystem()
    if not (State.DanceMode or State.SyncTargetMode) then return end
    local sourcePlayer = State.SyncTargetMode and State.SyncTargetPlayer or (State.DanceMode and LocalPlayer or nil)
    if not sourcePlayer then return end
    local character = sourcePlayer.Character
    if not character then return end
    local animator = GetAnimator(character)
    if not animator then return end
    CurrentAnimatorConnection = animator.AnimationPlayed:Connect(function(track)
        if not (State.DanceMode or State.SyncTargetMode) then return end
        if not IsSyncTrack(track) then return end
        task.wait(0.05)
        if State.DanceMode then
            ApplyDanceToSelected(function(clone) PlayTrackOnClone(clone, track) end)
        elseif State.SyncTargetMode then
            ApplySyncToAll(function(clone) PlayTrackOnClone(clone, track) end)
        end
    end)
    StartSyncLoop()
end

-- Auto-Reconnect: kalau target sync respawn (character lama hancur, yang
-- baru muncul), CurrentAnimatorConnection yang lama otomatis putus karena
-- Animator lama ikut hancur. Loop ini memantau itu dan menyambungkan lagi
-- otomatis tanpa perlu user pencet tombol manapun, asal
-- State.SyncAutoReconnect masih aktif.
local SyncWatchdogLoop = nil
local function StartSyncWatchdog()
    if SyncWatchdogLoop then return end
    SyncWatchdogLoop = RunService.Heartbeat:Connect(function()
        if not State.SyncAutoReconnect then return end
        if not (State.DanceMode or State.SyncTargetMode) then return end
        local sourcePlayer = State.SyncTargetMode and State.SyncTargetPlayer or (State.DanceMode and LocalPlayer or nil)
        if not sourcePlayer then return end
        -- Kalau target playernya sudah keluar game, matikan sync sepenuhnya.
        if not sourcePlayer.Parent then
            State.SyncTargetMode = false
            State.SyncTargetPlayer = nil
            StopSyncSystem()
            pcall(rebuildSyncTab)
            return
        end
        -- Kalau koneksi listener sudah putus (mis. karena respawn) tapi mode
        -- sync masih aktif, sambungkan ulang.
        if not CurrentAnimatorConnection or not CurrentAnimatorConnection.Connected then
            SetupDanceSync()
        end
    end)
end
StartSyncWatchdog()

local function CreateNameTag(clone, nameText, hide)
    local oldTag = clone:FindFirstChild("NameTag")
    if oldTag then oldTag:Destroy() end
    if hide or State.HideAllNames then return end

    local head = clone:FindFirstChild("Head") or clone.PrimaryPart
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "NameTag"
    billboard.Size = UDim2.new(0, 200, 0, 24)
    billboard.StudsOffset = Vector3.new(0, 2.6, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 50
    billboard.Adornee = head
    billboard.Parent = clone

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = nameText
    label.TextColor3 = COLORS.White
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    label.Parent = billboard

    return billboard
end

-- ================================================
-- CLONE VISUAL — Save/Load Slot (berisi userId target, bukan snapshot)
-- ================================================
local function SaveVisualCloneSlots()
    pcall(function()
        if writefile then writefile(VISUAL_CLONE_FILE, HttpService:JSONEncode(State.VisualCloneSlots)) end
    end)
end

local function LoadVisualCloneSlots()
    pcall(function()
        if isfile and readfile and isfile(VISUAL_CLONE_FILE) then
            local data = HttpService:JSONDecode(readfile(VISUAL_CLONE_FILE))
            if type(data) == "table" then State.VisualCloneSlots = data end
        end
    end)
end

-- Menyimpan sebuah target (userId + nama) sebagai slot bernama, supaya
-- bisa dipanggil ulang kapan saja tanpa perlu ketik ulang username/userId.
local function SaveVisualCloneSlot(slotName, userId, username)
    if not slotName or slotName == "" then return false, "Nama slot kosong" end
    if not userId then return false, "UserId tidak valid" end

    State.VisualCloneSlots[slotName] = {
        savedAt = os.time(),
        userId = userId,
        username = username or tostring(userId),
    }
    SaveVisualCloneSlots()
    return true, "Clone Visual '" .. slotName .. "' tersimpan (target: " .. (username or tostring(userId)) .. ")."
end

local function DeleteVisualCloneSlot(slotName)
    State.VisualCloneSlots[slotName] = nil
    SaveVisualCloneSlots()
end

local function RenameVisualCloneSlot(oldName, newName)
    if not State.VisualCloneSlots[oldName] then return false end
    if State.VisualCloneSlots[newName] then return false, "Nama sudah dipakai slot lain" end
    State.VisualCloneSlots[newName] = State.VisualCloneSlots[oldName]
    State.VisualCloneSlots[oldName] = nil
    SaveVisualCloneSlots()
    return true
end

-- Menerapkan sebuah slot tersimpan langsung ke diri sendiri.
local function LoadVisualCloneSlotToSelf(slotName)
    local slot = State.VisualCloneSlots[slotName]
    if not slot or not slot.userId then
        return false, "Slot Clone Visual tidak ditemukan"
    end
    return ApplyCloneVisualToSelf(slot.userId, slot.username or slotName)
end

local function SetGizmoVisibility()
    if not Gizmos.Position or not Gizmos.Rotation then return end
    Gizmos.Position.Adornee = nil
    Gizmos.Rotation.Adornee = nil
    if not State.SelectedClone or not State.EditMode then return end
    local root = State.SelectedClone.PrimaryPart
    if not root then return end
    if State.PositionMode then Gizmos.Position.Adornee = root end
    if State.RotationMode then Gizmos.Rotation.Adornee = root end
end

local function SelectClone(clone)
    if not clone or not clone:IsDescendantOf(Workspace:FindFirstChild(FOLDER_NAME)) then return end
    State.SelectedClone = clone
    SetGizmoVisibility()
    if State.CurrentTab == "Editor" and tabContentFrame then
        rebuildEditorTab()
    end
end

local function SaveHistory()
    pcall(function()
        if writefile then writefile(HISTORY_FILE, HttpService:JSONEncode(State.HistoryList)) end
    end)
end

local function LoadHistory()
    pcall(function()
        if isfile and readfile and isfile(HISTORY_FILE) then
            local data = HttpService:JSONDecode(readfile(HISTORY_FILE))
            if type(data) == "table" then State.HistoryList = data end
        end
    end)
end

local function SaveFavorites()
    pcall(function()
        if writefile then writefile(FAVORITES_FILE, HttpService:JSONEncode(State.FavoritesList)) end
    end)
end

local function LoadFavorites()
    pcall(function()
        if isfile and readfile and isfile(FAVORITES_FILE) then
            local data = HttpService:JSONDecode(readfile(FAVORITES_FILE))
            if type(data) == "table" then State.FavoritesList = data end
        end
    end)
end

local function SaveFavPlayers()
    pcall(function()
        if writefile then writefile(FAV_PLAYERS_FILE, HttpService:JSONEncode(State.FavoritesPlayersList)) end
    end)
end

local function LoadFavPlayers()
    pcall(function()
        if isfile and readfile and isfile(FAV_PLAYERS_FILE) then
            local data = HttpService:JSONDecode(readfile(FAV_PLAYERS_FILE))
            if type(data) == "table" then State.FavoritesPlayersList = data end
        end
    end)
end

-- ================================================
-- CONFIG MULTI-SLOT (Simpan & Muat Berdasarkan Nama)
-- ================================================
local function SaveConfigSlots()
    pcall(function()
        if writefile then writefile(CONFIG_SLOTS_FILE, HttpService:JSONEncode(State.ConfigSlots)) end
    end)
end

local function LoadConfigSlots()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_SLOTS_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_SLOTS_FILE))
            if type(data) == "table" then State.ConfigSlots = data end
        end
    end)
    -- Migrasi otomatis: kalau ada config lama (format single-slot) dan
    -- belum ada slot bernama apapun, jadikan itu slot pertama supaya
    -- data lama tidak hilang begitu saja setelah upgrade.
    if next(State.ConfigSlots) == nil then
        pcall(function()
            if isfile and readfile and isfile(CONFIG_FILE) then
                local oldData = HttpService:JSONDecode(readfile(CONFIG_FILE))
                if type(oldData) == "table" and #oldData > 0 then
                    State.ConfigSlots["Config Lama"] = {
                        savedAt = os.time(),
                        clones = oldData,
                    }
                    SaveConfigSlots()
                end
            end
        end)
    end
end

-- Membangun snapshot semua clone yang sedang ada di map jadi 1 tabel data,
-- dipakai baik untuk slot baru maupun overwrite slot yang sudah ada.
local function BuildConfigSnapshot()
    local clonesData = {}
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        for _, clone in ipairs(folder:GetChildren()) do
            if clone:IsA("Model") and State.CloneData[clone] then
                local info = State.CloneData[clone]
                local primary = clone.PrimaryPart
                if primary then
                    local pos = primary.Position
                    local rot = primary.CFrame - primary.CFrame.Position
                    local x, y, z, r11, r12, r13, r21, r22, r23, r31, r32, r33 = rot:GetComponents()
                    table.insert(clonesData, {
                        userId = info.UserId,
                        displayName = info.DisplayName or info.Username,
                        username = info.Username,
                        name = clone.Name,
                        hideName = info.HideName,
                        position = {pos.X, pos.Y, pos.Z},
                        rotation = {r11, r12, r13, r21, r22, r23, r31, r32, r33}
                    })
                end
            end
        end
    end
    return clonesData
end

-- Menghapus semua clone di map lalu spawn ulang sesuai isi 1 slot config.
local function ApplyConfigSlot(slotName, callback)
    local slot = State.ConfigSlots[slotName]
    if not slot or type(slot.clones) ~= "table" then
        if callback then callback(false, "Slot tidak ditemukan") end
        return
    end

    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        for _, clone in ipairs(folder:GetChildren()) do
            if clone:IsA("Model") then
                State.CloneData[clone] = nil
                clone:Destroy()
            end
        end
    end
    if State.SelectedClone then State.SelectedClone = nil end

    local total = #slot.clones
    local loaded = 0
    if total == 0 then
        if callback then callback(true, "Slot ini kosong (tidak ada clone tersimpan).") end
        return
    end

    for _, info in ipairs(slot.clones) do
        task.spawn(function()
            local userId = info.userId
            local model = CreateAvatarFromUserId(userId)
            if model then
                State.CloneCounter = State.CloneCounter + 1
                local cloneName = info.name or ("Clone_" .. tostring(State.CloneCounter))
                model.Name = cloneName
                PrepareCloneModel(model)
                local position = info.position
                local rotData = info.rotation
                local cf
                if position and rotData then
                    local pos = Vector3.new(position[1], position[2], position[3])
                    local rot = CFrame.new(0,0,0, rotData[1], rotData[2], rotData[3], rotData[4], rotData[5], rotData[6], rotData[7], rotData[8], rotData[9])
                    cf = CFrame.new(pos) * rot
                else
                    cf = GetNextSpawnCFrame()
                end
                model:PivotTo(cf)
                local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
                if rootPart then
                    rootPart.Anchored = true
                    rootPart.CanCollide = false
                    rootPart.Transparency = 1
                end
                local cloneData = {
                    Index = State.CloneCounter,
                    UserId = userId,
                    Username = info.username or info.displayName,
                    DisplayName = info.displayName,
                    OriginalCFrame = cf,
                    OriginalRotation = cf - cf.Position,
                    HideName = info.hideName or false,
                }
                State.CloneData[model] = cloneData
                model.Parent = Workspace:FindFirstChild(FOLDER_NAME)
                CreateNameTag(model, info.displayName or info.username or cloneName, cloneData.HideName)
            end
            loaded = loaded + 1
            if loaded >= total and callback then
                callback(true, "Slot '" .. slotName .. "' dimuat (" .. total .. " clone).")
            end
        end)
    end
end

local function SaveConfigSlot(slotName)
    if not slotName or slotName == "" then return false, "Nama slot kosong" end
    local snapshot = BuildConfigSnapshot()
    State.ConfigSlots[slotName] = {
        savedAt = os.time(),
        clones = snapshot,
    }
    State.LastConfigSlot = slotName
    SaveConfigSlots()
    return true, "Slot '" .. slotName .. "' tersimpan (" .. #snapshot .. " clone)."
end

local function DeleteConfigSlot(slotName)
    State.ConfigSlots[slotName] = nil
    if State.LastConfigSlot == slotName then State.LastConfigSlot = nil end
    SaveConfigSlots()
end

local function RenameConfigSlot(oldName, newName)
    if not State.ConfigSlots[oldName] then return false end
    if State.ConfigSlots[newName] then return false, "Nama sudah dipakai slot lain" end
    State.ConfigSlots[newName] = State.ConfigSlots[oldName]
    State.ConfigSlots[oldName] = nil
    if State.LastConfigSlot == oldName then State.LastConfigSlot = newName end
    SaveConfigSlots()
    return true
end

local function SaveApiKey()
    pcall(function()
        if writefile and State.GroqApiKey then writefile(API_KEY_FILE, State.GroqApiKey) end
    end)
    if Storage and Storage.appSettings then
        Storage.appSettings.groqApiKey = State.GroqApiKey
        if Storage.persistSettings then pcall(Storage.persistSettings) end
    end
end

local function LoadApiKey()
    pcall(function()
        if isfile and readfile and isfile(API_KEY_FILE) then
            State.GroqApiKey = readfile(API_KEY_FILE)
        end
    end)
    if not State.GroqApiKey and Storage and Storage.appSettings and Storage.appSettings.groqApiKey then
        State.GroqApiKey = Storage.appSettings.groqApiKey
    end
end

-- ================================================
-- CLONE CREATION
-- ================================================
local function CreateCloneFromUserId(userId, displayName, username)
    if not userId then return end

    local model = nil
    local dispName = displayName
    local uname = username or "Unknown"

    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            if not dispName then dispName = player.DisplayName end
            if not uname or uname == "Unknown" then uname = player.Name end
            if player.Character then
                player.Character.Archivable = true
                local success, result = pcall(function() return player.Character:Clone() end)
                if success and result then model = result end
            end
            break
        end
    end

    if not model then model = CreateAvatarFromUserId(userId) end
    if not dispName then dispName = GetDisplayName(userId) or uname end
    if not model then return end

    State.CloneCounter = State.CloneCounter + 1
    local cloneName = "Clone_" .. tostring(State.CloneCounter)
    model.Name = cloneName
    PrepareCloneModel(model)

    local spawnCFrame = GetNextSpawnCFrame()
    model:PivotTo(spawnCFrame)

    local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    if rootPart then
        rootPart.Anchored = true
        rootPart.CanCollide = false
        rootPart.Transparency = 1
    end

    local cloneData = {
        Index = State.CloneCounter,
        UserId = userId,
        Username = uname,
        DisplayName = dispName,
        OriginalCFrame = spawnCFrame,
        OriginalRotation = spawnCFrame - spawnCFrame.Position,
        HideName = false,
    }
    State.CloneData[model] = cloneData
    model.Parent = Workspace:FindFirstChild(FOLDER_NAME)

    CreateNameTag(model, dispName, false)
    SelectClone(model)

    -- Add to history
    local alreadyInHistory = false
    for _, entry in ipairs(State.HistoryList) do
        if entry.userId == userId then alreadyInHistory = true break end
    end
    if not alreadyInHistory then
        table.insert(State.HistoryList, {userId = userId, displayName = dispName, username = uname})
        SaveHistory()
    end

    if State.DanceMode or State.SyncTargetMode then SetupDanceSync() end

    if State.CurrentTab == "Clones" then rebuildClonesTab() end
    if State.CurrentTab == "History" then rebuildHistoryTab() end
end

local function CreateCloneFromInput(inputText)
    local userId, isSelf = ResolveUserId(inputText)
    if not userId then return end
    local dispName = nil
    local uname = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId == userId then
            dispName = player.DisplayName
            uname = player.Name
            break
        end
    end
    if not dispName then dispName = GetDisplayName(userId) or "Unknown" end
    if not uname then uname = "Unknown" end
    CreateCloneFromUserId(userId, dispName, uname)
end

-- ================================================
-- HTTP & AI CHAT
-- ================================================
-- Prioritas metode HTTP disamakan dengan AlfreadAI.lua (yang sudah terbukti jalan):
-- syn.request -> http_request -> request -> RequestAsync (fallback terakhir).
-- PENTING: kalau salah satu metode berhasil TERHUBUNG ke server (dapat response,
-- walau isinya error JSON dari Groq seperti model_not_found), itu dianggap
-- "berhasil transport"-nya, dan body-nya langsung dikembalikan apa adanya supaya
-- SendGroqMessage yang menentukan apakah errornya soal model atau bukan.
-- Kita TIDAK berhenti lebih awal berdasarkan status code di sini, supaya loop
-- multi-model di SendGroqMessage selalu lanjut mencoba model berikutnya.
local function performHttpPost(url, headers, body)
    local attempts = {}
    local opts = {Url = url, Method = "POST", Headers = headers, Body = body}

    if syn and syn.request then
        local success, response = pcall(function() return syn.request(opts) end)
        if success and response and response.Body then
            return response.Body, nil
        end
        table.insert(attempts, "syn.request: " .. tostring(success and (response and response.StatusCode) or response))
    end

    if http_request then
        local success, response = pcall(function() return http_request(opts) end)
        if success and response and response.Body then
            return response.Body, nil
        end
        table.insert(attempts, "http_request: " .. tostring(success and (response and response.StatusCode) or response))
    end

    if request then
        local success, response = pcall(function() return request(opts) end)
        if success and response and response.Body then
            return response.Body, nil
        end
        table.insert(attempts, "request(): " .. tostring(success and (response and response.StatusCode) or response))
    end

    if HttpService then
        local success, response = pcall(function() return HttpService:RequestAsync(opts) end)
        if success and response and response.Body then
            -- RequestAsync tetap punya Body walau StatusCode error (mis. 404) -
            -- itu tetap dikembalikan supaya SendGroqMessage bisa baca pesan
            -- error asli dari Groq dan lanjut ke model berikutnya kalau perlu.
            return response.Body, nil
        end
        table.insert(attempts, "RequestAsync: " .. tostring(success and (response and response.StatusCode) or response))
    end

    if #attempts == 0 then
        return nil, "Executor tidak mendukung HTTP request (syn.request/http_request/request/RequestAsync semua tidak tersedia)."
    end
    return nil, table.concat(attempts, " | ")
end

local function SendGroqMessage(prompt, systemPrompt, onProgress)
    if not State.GroqApiKey or State.GroqApiKey == "" then
        return nil, "API key belum diisi. Buka tab Config, masukkan Groq API Key dulu."
    end
    local url = "https://api.groq.com/openai/v1/chat/completions"
    local headers = {
        ["Authorization"] = "Bearer " .. State.GroqApiKey,
        ["Content-Type"] = "application/json",
    }
    local errors = {}

    for i, model in ipairs(GROQ_MODELS) do
        if onProgress then
            pcall(onProgress, "Mencoba model " .. i .. "/" .. #GROQ_MODELS .. " (" .. model .. ")...")
        end
        local body = HttpService:JSONEncode({
            model = model,
            messages = {
                {role = "system", content = systemPrompt or "Kamu adalah asisten yang menjawab singkat dalam bahasa gaul Indonesia, maksimal 10 kata, santai dan natural."},
                {role = "user", content = prompt},
            },
            temperature = 0.9,
            max_tokens = 100,
        })

        local responseBody, httpErr = performHttpPost(url, headers, body)
        if responseBody then
            local success, decoded = pcall(function() return HttpService:JSONDecode(responseBody) end)
            if success and decoded then
                if decoded.error then
                    table.insert(errors, model .. ": " .. tostring(decoded.error.message or decoded.error))
                elseif decoded.choices and decoded.choices[1] and decoded.choices[1].message and decoded.choices[1].message.content then
                    return decoded.choices[1].message.content, nil
                else
                    table.insert(errors, model .. ": response tidak berisi choices")
                end
            else
                table.insert(errors, model .. ": gagal decode JSON")
            end
        else
            table.insert(errors, model .. ": " .. tostring(httpErr))
        end
    end
    return nil, "Semua model gagal -> " .. table.concat(errors, " || ")
end

local function DisplayCloneBubble(clone, message)
    if not clone or not message or message == "" then return false end
    local head = clone:FindFirstChild("Head")
    if not head then return false end

    -- Gunakan bubble chat BAWAAN Roblox (legacy Chat API - paling stabil untuk NPC/Model non-player)
    local success = pcall(function()
        game:GetService("Chat"):Chat(head, message, Enum.ChatColor.White)
    end)
    if success then return true end

    -- Fallback: coba lewat ChatService modul jika tersedia (server-side biasanya, tapi aman dicoba)
    local success2 = pcall(function()
        TextChatService:DisplayBubble(clone, message)
    end)
    return success2
end

local function DoAIChatOnce()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if not folder then
        State.AIChatStatus = "Gagal: folder clone belum ada"
        return false, "Folder belum ada"
    end
    local clones = {}
    for _, clone in ipairs(folder:GetChildren()) do
        if clone:IsA("Model") then table.insert(clones, clone) end
    end
    if #clones < 2 then
        State.AIChatStatus = "Gagal: butuh minimal 2 clone"
        return false, "Butuh minimal 2 clone"
    end

    local clone1 = clones[math.random(1, #clones)]
    local clone2
    repeat clone2 = clones[math.random(1, #clones)] until clone2 ~= clone1

    State.AIChatStatus = "Meminta balasan AI..."
    local prompt = "Buat percakapan singkat dua orang dalam bahasa gaul Indonesia. Format WAJIB persis:\nA: [pesan]\nB: [pesan]\nMaksimal 6 kata per pesan, santai, natural, jangan pakai tanda kutip."
    local response, err = SendGroqMessage(prompt, "Kamu adalah AI yang membuat percakapan gaul Indonesia singkat. Selalu balas dua baris, baris pertama diawali 'A:' dan baris kedua diawali 'B:'. Jangan tambahkan penjelasan lain.", function(progressText)
        State.AIChatStatus = progressText
        pcall(rebuildAIChatTab)
    end)

    if not response then
        State.AIChatStatus = "Gagal"
        State.AIChatLastError = err or "Tidak diketahui"
        return false, err
    end

    -- Parsing lebih toleran: cari baris yang mengandung "A:" / "B:" di mana saja,
    -- kalau tidak ketemu, pakai 2 baris pertama yang tidak kosong sebagai fallback.
    local msg1, msg2 = nil, nil
    for line in response:gmatch("[^\n]+") do
        local cleaned = line:gsub("^%s+", ""):gsub("%s+$", "")
        if cleaned ~= "" then
            if not msg1 and cleaned:match("^[Aa]%s*:") then
                msg1 = cleaned:gsub("^[Aa]%s*:%s*", "")
            elseif not msg2 and cleaned:match("^[Bb]%s*:") then
                msg2 = cleaned:gsub("^[Bb]%s*:%s*", "")
            end
        end
    end
    if not msg1 or not msg2 then
        local fallbackLines = {}
        for line in response:gmatch("[^\n]+") do
            local cleaned = line:gsub("^%s+", ""):gsub("%s+$", "")
            if cleaned ~= "" then table.insert(fallbackLines, cleaned) end
        end
        msg1 = msg1 or fallbackLines[1]
        msg2 = msg2 or fallbackLines[2]
    end
    msg1 = msg1 and msg1:gsub('^"', ""):gsub('"$', "")
    msg2 = msg2 and msg2:gsub('^"', ""):gsub('"$', "")

    if msg1 and #msg1 > 0 and msg2 and #msg2 > 0 then
        DisplayCloneBubble(clone1, msg1)
        task.wait(2)
        DisplayCloneBubble(clone2, msg2)
        State.AIChatStatus = "Aktif - terakhir sukses"
        State.AIChatLastError = nil
        return true
    end

    State.AIChatStatus = "Gagal: format balasan AI tidak terbaca"
    State.AIChatLastError = "Response mentah: " .. tostring(response):sub(1, 120)
    return false, "Gagal parsing"
end

local function StartAIChat()
    if AIChatLoop then return end
    State.AIChatEnabled = true
    State.AIChatStatus = "Menunggu giliran pertama..."
    AIChatLoop = task.spawn(function()
        while State.AIChatEnabled do
            if os.clock() - State.AIChatLastTime >= State.AIChatCooldown then
                State.AIChatLastTime = os.clock()
                DoAIChatOnce()
                pcall(rebuildAIChatTab)
            end
            task.wait(2)
        end
    end)
end

local function StopAIChat()
    State.AIChatEnabled = false
    State.AIChatStatus = "Dihentikan"
    if AIChatLoop then
        pcall(task.cancel, AIChatLoop)
    end
    AIChatLoop = nil
end

-- ================================================
-- MANUAL CHAT (Kirim Pesan Manual ke Clone)
-- ================================================
local function SendManualChat(clone, message)
    if not clone or not message or message == "" then return false end
    DisplayCloneBubble(clone, message)
    return true
end

-- ================================================
-- VARIASI / FORMASI CLONE
-- ================================================
local function GetAllCloneModels()
    local list = {}
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if not folder then return list end
    for _, clone in ipairs(folder:GetChildren()) do
        if clone:IsA("Model") then table.insert(list, clone) end
    end
    return list
end

local function ArrangeFormation(shape, radius)
    local clones = GetAllCloneModels()
    local count = #clones
    if count == 0 then return end

    local character = LocalPlayer.Character
    local baseCFrame
    if character and character:FindFirstChild("HumanoidRootPart") then
        baseCFrame = character.HumanoidRootPart.CFrame
    else
        baseCFrame = CFrame.new(0, 3, 0)
    end

    if shape == "Circle" then
        for i, clone in ipairs(clones) do
            local angle = (i - 1) * (2 * math.pi / count)
            local offset = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
            local targetPos = baseCFrame.Position + offset
            local lookAt = CFrame.lookAt(targetPos, baseCFrame.Position)
            clone:PivotTo(lookAt)
        end
    elseif shape == "Line" then
        local startOffset = -((count - 1) * radius) / 2
        for i, clone in ipairs(clones) do
            local offset = Vector3.new(startOffset + (i - 1) * radius, 0, -radius)
            local targetCFrame = baseCFrame * CFrame.new(offset)
            clone:PivotTo(CFrame.new(targetCFrame.Position) * (baseCFrame - baseCFrame.Position))
        end
    elseif shape == "Grid" then
        local cols = math.ceil(math.sqrt(count))
        for i, clone in ipairs(clones) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            local offset = Vector3.new((col - (cols - 1) / 2) * radius, 0, -radius - row * radius)
            local targetCFrame = baseCFrame * CFrame.new(offset)
            clone:PivotTo(CFrame.new(targetCFrame.Position) * (baseCFrame - baseCFrame.Position))
        end
    elseif shape == "VShape" then
        for i, clone in ipairs(clones) do
            local side = (i % 2 == 0) and 1 or -1
            local step = math.ceil(i / 2)
            local offset = Vector3.new(side * step * (radius / 2), 0, -step * (radius / 2) - radius)
            local targetCFrame = baseCFrame * CFrame.new(offset)
            clone:PivotTo(CFrame.new(targetCFrame.Position) * (baseCFrame - baseCFrame.Position))
        end
    elseif shape == "Spiral" then
        for i, clone in ipairs(clones) do
            local t = i / count
            local angle = t * math.pi * 4
            local r = radius * t + 1
            local offset = Vector3.new(math.sin(angle) * r, 0, math.cos(angle) * r)
            local targetPos = baseCFrame.Position + offset
            local lookAt = CFrame.lookAt(targetPos, baseCFrame.Position)
            clone:PivotTo(lookAt)
        end
    end
end

-- ================================================
-- FOLLOW ME MODE
-- ================================================
local function StopFollowMe()
    State.FollowMeMode = false
    if FollowMeLoop then FollowMeLoop:Disconnect(); FollowMeLoop = nil end
end

local function StartFollowMe()
    if FollowMeLoop then return end
    State.FollowMeMode = true
    FollowMeLoop = RunService.Heartbeat:Connect(function()
        if not State.FollowMeMode then return end
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local baseCFrame = character.HumanoidRootPart.CFrame
        local clones = GetAllCloneModels()
        for i, clone in ipairs(clones) do
            if clone.PrimaryPart then
                local angle = (i - 1) * (2 * math.pi / math.max(#clones, 1))
                local offset = Vector3.new(math.sin(angle) * 6, 0, math.cos(angle) * 6 + 4)
                local targetCFrame = CFrame.new(baseCFrame.Position + offset)
                local currentPos = clone.PrimaryPart.Position
                local newPos = currentPos:Lerp(targetCFrame.Position, 0.06)
                local lookRot = CFrame.lookAt(newPos, baseCFrame.Position).Rotation
                clone:PivotTo(CFrame.new(newPos) * lookRot)
            end
        end
    end)
end

-- ================================================
-- RAINBOW NAME MODE
-- ================================================
local function StopRainbowNames()
    State.RainbowNameMode = false
    if RainbowLoop then RainbowLoop:Disconnect(); RainbowLoop = nil end
end

local function StartRainbowNames()
    if RainbowLoop then return end
    State.RainbowNameMode = true
    local hue = 0
    RainbowLoop = RunService.Heartbeat:Connect(function(dt)
        if not State.RainbowNameMode then return end
        hue = (hue + dt * 0.15) % 1
        local color = Color3.fromHSV(hue, 0.75, 1)
        local folder = Workspace:FindFirstChild(FOLDER_NAME)
        if not folder then return end
        for _, clone in ipairs(folder:GetChildren()) do
            local tag = clone:FindFirstChild("NameTag")
            if tag then
                local label = tag:FindFirstChildOfClass("TextLabel")
                if label then label.TextColor3 = color end
            end
        end
    end)
end

-- ================================================
-- FREEZE POSE (Anchor semua Part clone terpilih)
-- ================================================
local function ToggleFreezePose(clone)
    if not clone then return end
    local frozen = clone:GetAttribute("FreezePose")
    frozen = not frozen
    clone:SetAttribute("FreezePose", frozen)
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.Anchored = frozen
        end
    end
    local humanoid = clone:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if frozen then
            humanoid.PlatformStand = true
        else
            humanoid.PlatformStand = false
        end
    end
end

-- ================================================
-- ORBIT MODE (Clone mengorbit terus di sekitar kamu)
-- ================================================
local OrbitLoop = nil
local function StopOrbitMode()
    State.OrbitMode = false
    if OrbitLoop then OrbitLoop:Disconnect(); OrbitLoop = nil end
end

local function StartOrbitMode()
    if OrbitLoop then return end
    State.OrbitMode = true
    local t = 0
    OrbitLoop = RunService.Heartbeat:Connect(function(dt)
        if not State.OrbitMode then return end
        t = t + dt
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local basePos = character.HumanoidRootPart.Position
        local clones = GetAllCloneModels()
        local count = math.max(#clones, 1)
        for i, clone in ipairs(clones) do
            if clone.PrimaryPart then
                local speed = 0.6
                local angle = t * speed + (i - 1) * (2 * math.pi / count)
                local r = 9
                local offset = Vector3.new(math.sin(angle) * r, math.sin(t * 1.5 + i) * 0.6, math.cos(angle) * r)
                local targetPos = basePos + offset
                local lookRot = CFrame.lookAt(targetPos, basePos).Rotation
                clone:PivotTo(CFrame.new(targetPos) * lookRot)
            end
        end
    end)
end

-- ================================================
-- PULSE GLOW (Efek highlight berkedip di semua clone)
-- ================================================
local PulseLoop = nil
local function StopPulseGlow()
    State.PulseGlowMode = false
    if PulseLoop then PulseLoop:Disconnect(); PulseLoop = nil end
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        for _, clone in ipairs(folder:GetChildren()) do
            local highlight = clone:FindFirstChild("PulseHighlight")
            if highlight then highlight:Destroy() end
        end
    end
end

local function StartPulseGlow()
    if PulseLoop then return end
    State.PulseGlowMode = true
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        for _, clone in ipairs(folder:GetChildren()) do
            if clone:IsA("Model") and not clone:FindFirstChild("PulseHighlight") then
                local highlight = Instance.new("Highlight")
                highlight.Name = "PulseHighlight"
                highlight.FillColor = COLORS.Gold
                highlight.OutlineColor = COLORS.Gold
                highlight.FillTransparency = 0.7
                highlight.OutlineTransparency = 0.1
                highlight.Parent = clone
            end
        end
    end
    local t = 0
    PulseLoop = RunService.Heartbeat:Connect(function(dt)
        if not State.PulseGlowMode then return end
        t = t + dt * 2.2
        local alpha = (math.sin(t) + 1) / 2 -- 0..1
        local currentFolder = Workspace:FindFirstChild(FOLDER_NAME)
        if not currentFolder then return end
        for _, clone in ipairs(currentFolder:GetChildren()) do
            local highlight = clone:FindFirstChild("PulseHighlight")
            if highlight then
                highlight.FillTransparency = 0.9 - alpha * 0.4
                highlight.OutlineTransparency = 0.4 - alpha * 0.35
            end
        end
    end)
end

-- ================================================
-- MIMIC MODE (Clone meniru gerakan/animasi kamu real-time)
-- ================================================
local MimicLoop = nil
local function StopMimicMode()
    State.MimicMode = false
    if MimicLoop then MimicLoop:Disconnect(); MimicLoop = nil end
end

local function StartMimicMode()
    if MimicLoop then return end
    State.MimicMode = true
    MimicLoop = RunService.Heartbeat:Connect(function()
        if not State.MimicMode then return end
        local character = LocalPlayer.Character
        if not character then return end
        local myHumanoid = character:FindFirstChildOfClass("Humanoid")
        if not myHumanoid then return end
        local myAnim = myHumanoid:GetPlayingAnimationTracks()
        local myAnimId = nil
        for _, track in ipairs(myAnim) do
            if track.Animation then myAnimId = track.Animation.AnimationId break end
        end

        local clones = GetAllCloneModels()
        for _, clone in ipairs(clones) do
            local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
            if cloneHumanoid then
                -- Tiru state gerak (Walk/Run/Jump)
                pcall(function()
                    cloneHumanoid.WalkSpeed = myHumanoid.WalkSpeed
                end)
                if myAnimId then
                    local alreadyPlaying = false
                    for _, t in ipairs(cloneHumanoid:GetPlayingAnimationTracks()) do
                        if t.Animation and t.Animation.AnimationId == myAnimId then alreadyPlaying = true end
                    end
                    if not alreadyPlaying then
                        local animator = cloneHumanoid:FindFirstChildOfClass("Animator")
                        if animator then
                            local anim = Instance.new("Animation")
                            anim.AnimationId = myAnimId
                            local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
                            if ok and track then
                                for _, t in ipairs(cloneHumanoid:GetPlayingAnimationTracks()) do t:Stop(0.1) end
                                track:Play(0.1)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ================================================
-- FITUR PRANK / KONTEN CLONE
-- ================================================

-- --- GHOST MODE: clone menghilang & muncul lagi berkala (efek jumpscare) ---
local function StopGhostMode()
    State.GhostModeActive = false
    if GhostModeLoop then GhostModeLoop:Disconnect(); GhostModeLoop = nil end
    -- Pulihkan transparansi semua clone ke normal
    local clones = GetAllCloneModels()
    for _, clone in ipairs(clones) do
        for _, part in ipairs(clone:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = part:GetAttribute("Model3D_OriginalTransparency") or 0
            end
            if part:IsA("Decal") then part.Transparency = 0 end
        end
    end
end

local function StartGhostMode()
    if GhostModeLoop then return end
    State.GhostModeActive = true
    GhostModeLoop = task.spawn(function()
        while State.GhostModeActive do
            task.wait(math.random(4, 9))
            if not State.GhostModeActive then break end
            local clones = GetAllCloneModels()
            if #clones == 0 then continue end
            local target = clones[math.random(1, #clones)]

            -- Fade out cepat
            for _, part in ipairs(target:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    if part:GetAttribute("Model3D_OriginalTransparency") == nil then
                        part:SetAttribute("Model3D_OriginalTransparency", part.Transparency)
                    end
                    part.Transparency = 1
                end
                if part:IsA("Decal") then part.Transparency = 1 end
            end

            task.wait(math.random(2, 4))
            if not State.GhostModeActive or not target.Parent then continue end

            -- Fade in lagi (efek "muncul mendadak")
            for _, part in ipairs(target:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Transparency = part:GetAttribute("Model3D_OriginalTransparency") or 0
                end
                if part:IsA("Decal") then part.Transparency = 0 end
            end
        end
    end)
end

-- --- RAGDOLL PRANK: clone tiba-tiba jatuh lalu berdiri lagi ---
local function StopRagdollPrank()
    State.RagdollPrankActive = false
    if RagdollPrankLoop then RagdollPrankLoop:Disconnect(); RagdollPrankLoop = nil end
end

local function StartRagdollPrank()
    if RagdollPrankLoop then return end
    State.RagdollPrankActive = true
    RagdollPrankLoop = task.spawn(function()
        while State.RagdollPrankActive do
            task.wait(math.random(6, 12))
            if not State.RagdollPrankActive then break end
            local clones = GetAllCloneModels()
            if #clones == 0 then continue end
            local target = clones[math.random(1, #clones)]
            local humanoid = target:FindFirstChildOfClass("Humanoid")
            if humanoid then
                pcall(function() humanoid.PlatformStand = true end)
                -- Sedikit dorongan/tilt biar kelihatan "jatuh"
                if target.PrimaryPart then
                    local original = target:GetPivot()
                    local tiltCF = original * CFrame.Angles(math.rad(85), 0, math.random(-30, 30) * math.pi / 180)
                    pcall(function() target:PivotTo(tiltCF) end)
                    task.wait(math.random(2, 3))
                    if State.RagdollPrankActive and target.Parent then
                        pcall(function() target:PivotTo(original) end)
                        pcall(function() humanoid.PlatformStand = false end)
                    end
                end
            end
        end
    end)
end

-- --- RANDOM SWAP: posisi antar clone ditukar acak secara berkala ---
local function StopRandomSwap()
    State.RandomSwapActive = false
    if RandomSwapLoop then RandomSwapLoop:Disconnect(); RandomSwapLoop = nil end
end

local function StartRandomSwap()
    if RandomSwapLoop then return end
    State.RandomSwapActive = true
    RandomSwapLoop = task.spawn(function()
        while State.RandomSwapActive do
            task.wait(math.random(5, 10))
            if not State.RandomSwapActive then break end
            local clones = GetAllCloneModels()
            if #clones < 2 then continue end
            local a = clones[math.random(1, #clones)]
            local b
            repeat b = clones[math.random(1, #clones)] until b ~= a
            if a.Parent and b.Parent then
                local cfA, cfB = a:GetPivot(), b:GetPivot()
                pcall(function() a:PivotTo(cfB) end)
                pcall(function() b:PivotTo(cfA) end)
            end
        end
    end)
end

-- --- MEME CHAT: clone auto ngomong random baris lucu secara berkala ---
local function StopMemeChat()
    State.MemeChatActive = false
    if MemeChatLoop then MemeChatLoop:Disconnect(); MemeChatLoop = nil end
end

local function StartMemeChat()
    if MemeChatLoop then return end
    State.MemeChatActive = true
    MemeChatLoop = task.spawn(function()
        while State.MemeChatActive do
            task.wait(State.MemeChatInterval or 8)
            if not State.MemeChatActive then break end
            local clones = GetAllCloneModels()
            if #clones == 0 then continue end
            local target = clones[math.random(1, #clones)]
            local line = MEME_LINES[math.random(1, #MEME_LINES)]
            DisplayCloneBubble(target, line)
        end
    end)
end

-- --- COPY MY OUTFIT: semua clone langsung pakai outfit kamu saat ini ---
local function CopyMyOutfitToAllClones()
    local character = LocalPlayer.Character
    if not character then return false, "Karakter kamu belum siap" end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false, "Humanoid tidak ditemukan" end

    local ok, description = pcall(function() return humanoid:GetAppliedDescription() end)
    if not ok or not description then return false, "Gagal mengambil outfit kamu" end

    local clones = GetAllCloneModels()
    if #clones == 0 then return false, "Belum ada clone" end

    local successCount = 0
    for _, clone in ipairs(clones) do
        local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
        if cloneHumanoid then
            local applyOk = pcall(function()
                cloneHumanoid:ApplyDescription(description)
            end)
            if applyOk then successCount = successCount + 1 end
        end
    end

    return true, ("Outfit disalin ke %d clone."):format(successCount)
end

-- ================================================
-- UI BUILDERS & HELPERS
-- ================================================
local function makeLabel(text, size, color, font, parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, size + 8)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or COLORS.SoftWhite
    lbl.Font = font or Enum.Font.GothamMedium
    lbl.TextSize = size or 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function makeButton(text, color, parent, size)
    local btn = Instance.new("TextButton")
    btn.Size = size or UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = color or COLORS.Panel2
    btn.Text = text
    btn.TextColor3 = COLORS.White
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = false
    btn.Parent = parent
    corner(btn, 8)
    stroke(btn, Color3.fromRGB(255, 255, 255), 0.05)
    pressFX(btn)
    return btn
end

local function makeInput(placeholder, parent)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
    frame.BackgroundColor3 = COLORS.Panel2
    frame.Parent = parent
    corner(frame, 8)
    stroke(frame, COLORS.Panel3, 1)

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, -16, 1, 0)
    tb.Position = UDim2.new(0, 8, 0, 0)
    tb.BackgroundTransparency = 1
    tb.Text = "" -- WAJIB di-set eksplisit — TextBox baru dari Instance.new()
                 -- defaultnya punya Text = "TextBox" (bukan string kosong),
                 -- jadi tanpa baris ini placeholder ketutupan tulisan "TextBox".
    tb.PlaceholderText = placeholder or ""
    tb.PlaceholderColor3 = COLORS.Gray
    tb.TextColor3 = COLORS.White
    tb.Font = Enum.Font.Gotham
    tb.TextSize = 11
    tb.ClearTextOnFocus = false
    tb.TextXAlignment = Enum.TextXAlignment.Left
    tb.Parent = frame
    return tb, frame
end

local function clearTabContent()
    if not tabContentFrame then return end
    for _, child in ipairs(tabContentFrame:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

-- ================================================
-- TAB REBUILDERS
-- ================================================
rebuildClonesTab = function()
    clearTabContent()

    local inputLabel = makeLabel("MASUKKAN USERNAME / USER ID:", 10, COLORS.Gray, Enum.Font.GothamBold, tabContentFrame)
    inputLabel.LayoutOrder = 1
    local inputBox, inputFrame = makeInput("Ketik target avatar...", tabContentFrame)
    inputFrame.LayoutOrder = 2

    local cloneBtn = makeButton("CLONE TARGET", COLORS.Red, tabContentFrame)
    cloneBtn.LayoutOrder = 3
    cloneBtn.MouseButton1Click:Connect(function()
        CreateCloneFromInput(inputBox.Text)
        inputBox.Text = ""
    end)

    local cloneAllBtn = makeButton("CLONE SEMUA PLAYER", COLORS.Green, tabContentFrame)
    cloneAllBtn.LayoutOrder = 4
    cloneAllBtn.MouseButton1Click:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                CreateCloneFromUserId(player.UserId, player.DisplayName, player.Name)
            end
        end
    end)

    local clonesLabel = makeLabel("DAFTAR CLONE AKTIF:", 10, COLORS.Gray, Enum.Font.GothamBold, tabContentFrame)
    clonesLabel.LayoutOrder = 5

    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        local index = 6
        local cloneList = folder:GetChildren()
        if #cloneList == 0 then
            local emptyInfo = makeLabel("Belum ada clone yang dibuat.", 10, COLORS.DarkGray, nil, tabContentFrame)
            emptyInfo.LayoutOrder = index
        else
            for _, clone in ipairs(cloneList) do
                if clone:IsA("Model") then
                    local isSelected = (State.SelectedClone == clone)
                    local btnColor = isSelected and COLORS.PurpleDark or COLORS.Panel
                    local cloneButton = makeButton((isSelected and "▶ " or "") .. clone.Name, btnColor, tabContentFrame)
                    cloneButton.LayoutOrder = index
                    cloneButton.MouseButton1Click:Connect(function()
                        SelectClone(clone)
                        rebuildClonesTab()
                    end)
                    index = index + 1
                end
            end
        end
    end
end

rebuildEditorTab = function()
    clearTabContent()

    -- Edit Mode toggle
    local editModeBtn = makeButton(State.EditMode and "EDIT MODE: ACTIVE" or "EDIT MODE: OFF", State.EditMode and COLORS.Green or COLORS.Panel, tabContentFrame)
    editModeBtn.LayoutOrder = 1
    editModeBtn.MouseButton1Click:Connect(function()
        State.EditMode = not State.EditMode
        if not State.EditMode then
            State.PositionMode = false
            State.RotationMode = false
            SetGizmoVisibility()
        end
        rebuildEditorTab()
    end)

    -- Selected clone card
    local selectedFrame = Instance.new("Frame")
    selectedFrame.Size = UDim2.new(1, 0, 0, 85)
    selectedFrame.BackgroundColor3 = COLORS.Panel
    selectedFrame.LayoutOrder = 2
    selectedFrame.Parent = tabContentFrame
    corner(selectedFrame, 10)
    stroke(selectedFrame, COLORS.Panel3, 1)

    local selName = makeLabel(State.SelectedClone and State.SelectedClone.Name or "Tidak ada clone terpilih", 11, COLORS.White, Enum.Font.GothamBold, selectedFrame)
    selName.Position = UDim2.new(0, 10, 0, 4)
    selName.Size = UDim2.new(1, -20, 0, 18)

    local data = State.SelectedClone and State.CloneData[State.SelectedClone]
    local selInfo = makeLabel(State.SelectedClone and ("ID: " .. (data and data.UserId or "?") .. " | Display: " .. (data and data.DisplayName or "?")) or "Klik clone di daftar untuk mengedit", 9, COLORS.Gray, nil, selectedFrame)
    selInfo.Position = UDim2.new(0, 10, 0, 24)
    selInfo.Size = UDim2.new(1, -20, 0, 16)

    local renameBox = Instance.new("TextBox")
    renameBox.Size = UDim2.new(1, -70, 0, 28)
    renameBox.Position = UDim2.new(0, 10, 0, 48)
    renameBox.BackgroundColor3 = COLORS.Panel2
    renameBox.Text = ""
    renameBox.PlaceholderText = "Ubah nama clone..."
    renameBox.PlaceholderColor3 = COLORS.DarkGray
    renameBox.TextColor3 = COLORS.White
    renameBox.Font = Enum.Font.Gotham
    renameBox.TextSize = 10
    renameBox.ClearTextOnFocus = false
    renameBox.Parent = selectedFrame
    corner(renameBox, 6)

    local renameBtn = makeButton("SIMPAN", COLORS.Orange, selectedFrame, UDim2.new(0, 55, 0, 28))
    renameBtn.Position = UDim2.new(1, -58, 0, 48)
    renameBtn.TextColor3 = COLORS.Background
    renameBtn.MouseButton1Click:Connect(function()
        if not State.SelectedClone then return end
        local newName = renameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if newName == "" then return end
        State.SelectedClone.Name = newName
        if State.CloneData[State.SelectedClone] then State.CloneData[State.SelectedClone].Name = newName end
        local cData = State.CloneData[State.SelectedClone]
        if cData then CreateNameTag(State.SelectedClone, cData.DisplayName or newName, cData.HideName) end
        rebuildEditorTab()
    end)

    -- Hide name toggle
    local isHidden = State.SelectedClone and State.CloneData[State.SelectedClone] and State.CloneData[State.SelectedClone].HideName
    local hideBtn = makeButton(isHidden and "TAMPILKAN NAMA" or "SEMBUNYIKAN NAMA", COLORS.Panel2, tabContentFrame)
    hideBtn.LayoutOrder = 3
    hideBtn.MouseButton1Click:Connect(function()
        if not State.SelectedClone or not State.CloneData[State.SelectedClone] then return end
        local cData = State.CloneData[State.SelectedClone]
        cData.HideName = not cData.HideName
        if cData.HideName or State.HideAllNames then
            local tag = State.SelectedClone:FindFirstChild("NameTag")
            if tag then tag:Destroy() end
        else
            CreateNameTag(State.SelectedClone, cData.DisplayName or State.SelectedClone.Name, false)
        end
        rebuildEditorTab()
    end)

    -- Position Mode
    local posBtn = makeButton(State.PositionMode and "GIZMO POSISI: ON" or "GIZMO POSISI: OFF", State.PositionMode and COLORS.RedDark or COLORS.Panel, tabContentFrame)
    posBtn.LayoutOrder = 4
    posBtn.MouseButton1Click:Connect(function()
        if not State.EditMode then return end
        State.PositionMode = not State.PositionMode
        if State.PositionMode then State.RotationMode = false end
        SetGizmoVisibility()
        rebuildEditorTab()
    end)

    -- Rotation Mode
    local rotBtn = makeButton(State.RotationMode and "GIZMO ROTASI: ON" or "GIZMO ROTASI: OFF", State.RotationMode and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    rotBtn.LayoutOrder = 5
    rotBtn.MouseButton1Click:Connect(function()
        if not State.EditMode then return end
        State.RotationMode = not State.RotationMode
        if State.RotationMode then State.PositionMode = false end
        SetGizmoVisibility()
        rebuildEditorTab()
    end)

    -- Dance Mode
    local danceBtn = makeButton(State.DanceMode and "DANCE SYNC (SELECTED): ON" or "DANCE SYNC (SELECTED): OFF", State.DanceMode and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    danceBtn.LayoutOrder = 6
    danceBtn.MouseButton1Click:Connect(function()
        State.DanceMode = not State.DanceMode
        State.SyncTargetMode = false
        if State.DanceMode then
            if not State.SelectedClone then State.DanceMode = false else SetupDanceSync() end
        else
            StopSyncSystem()
        end
        rebuildEditorTab()
    end)

    -- Teleport to LocalPlayer
    local bringBtn = makeButton("TELEPORT KE SAYA", COLORS.Blue, tabContentFrame)
    bringBtn.LayoutOrder = 7
    bringBtn.MouseButton1Click:Connect(function()
        local character = LocalPlayer.Character
        if not character then return end
        local root = character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local targetCFrame = root.CFrame * CFrame.new(0, 0, -3)
        if State.SelectedClone and State.SelectedClone.PrimaryPart then
            State.SelectedClone:PivotTo(targetCFrame)
        end
    end)

    -- Reset position & rotation
    local resetPosBtn = makeButton("RESET POSISI", COLORS.Orange, tabContentFrame)
    resetPosBtn.LayoutOrder = 8
    resetPosBtn.MouseButton1Click:Connect(function()
        if not State.SelectedClone or not State.CloneData[State.SelectedClone] then return end
        local cData = State.CloneData[State.SelectedClone]
        local primary = State.SelectedClone.PrimaryPart
        if not primary then return end
        local currentRot = primary.CFrame - primary.CFrame.Position
        State.SelectedClone:PivotTo(CFrame.new(cData.OriginalCFrame.Position) * currentRot)
    end)

    local resetRotBtn = makeButton("RESET ROTASI", COLORS.Orange, tabContentFrame)
    resetRotBtn.LayoutOrder = 9
    resetRotBtn.MouseButton1Click:Connect(function()
        if not State.SelectedClone or not State.CloneData[State.SelectedClone] then return end
        local cData = State.CloneData[State.SelectedClone]
        local primary = State.SelectedClone.PrimaryPart
        if not primary then return end
        State.SelectedClone:PivotTo(CFrame.new(primary.CFrame.Position) * cData.OriginalRotation)
    end)

    -- Delete Selected
    local delBtn = makeButton("HAPUS CLONE INI", COLORS.Delete, tabContentFrame)
    delBtn.LayoutOrder = 10
    delBtn.MouseButton1Click:Connect(function()
        if not State.SelectedClone then return end
        local target = State.SelectedClone
        State.CloneData[target] = nil
        State.SelectedClone = nil
        SetGizmoVisibility()
        target:Destroy()
        rebuildEditorTab()
    end)

    -- Delete All
    local delAllBtn = makeButton("HAPUS SEMUA CLONE", COLORS.Delete, tabContentFrame)
    delAllBtn.LayoutOrder = 11
    delAllBtn.MouseButton1Click:Connect(function()
        if not DeleteAllArmed then
            DeleteAllArmed = true
            delAllBtn.Text = "KONFIRMASI HAPUS SEMUA?"
            delAllBtn.BackgroundColor3 = COLORS.DeleteActive
            task.delay(3, function()
                if DeleteAllArmed then
                    DeleteAllArmed = false
                    if delAllBtn and delAllBtn.Parent then
                        delAllBtn.Text = "HAPUS SEMUA CLONE"
                        delAllBtn.BackgroundColor3 = COLORS.Delete
                    end
                end
            end)
            return
        end
        DeleteAllArmed = false
        local folder = Workspace:FindFirstChild(FOLDER_NAME)
        if folder then
            for _, clone in ipairs(folder:GetChildren()) do clone:Destroy() end
        end
        table.clear(State.CloneData)
        State.SelectedClone = nil
        SetGizmoVisibility()
        rebuildEditorTab()
    end)
end

local function makeSectionHeader(text, parent, layoutOrder, accentColor)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 26)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = layoutOrder
    holder.Parent = parent

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 0, 14)
    bar.Position = UDim2.new(0, 0, 0.5, -7)
    bar.BackgroundColor3 = accentColor or COLORS.Gold
    bar.BorderSizePixel = 0
    bar.Parent = holder
    corner(bar, 2)

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 11
    label.TextColor3 = COLORS.SoftWhite
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = holder

    return holder
end

local function makePremiumCard(parent, layoutOrder, height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, height or 0)
    if not height then card.AutomaticSize = Enum.AutomaticSize.Y end
    card.BackgroundColor3 = COLORS.Panel
    card.LayoutOrder = layoutOrder
    card.Parent = parent
    corner(card, 12)
    stroke(card, COLORS.Panel3, 1, 0.4)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.Panel2),
        ColorSequenceKeypoint.new(1, COLORS.Panel),
    })
    grad.Rotation = 100
    grad.Parent = card

    return card
end

rebuildSyncTab = function()
    clearTabContent()

    makeSectionHeader("SYNC ANIMASI KE CLONE", tabContentFrame, 1, COLORS.Purple)

    -- ===== STATUS CARD =====
    local statusCard = makePremiumCard(tabContentFrame, 2)
    local statusPad = Instance.new("UIPadding", statusCard)
    statusPad.PaddingTop = UDim.new(0, 10); statusPad.PaddingBottom = UDim.new(0, 10)
    statusPad.PaddingLeft = UDim.new(0, 10); statusPad.PaddingRight = UDim.new(0, 10)
    local statusLayout = Instance.new("UIListLayout", statusCard)
    statusLayout.Padding = UDim.new(0, 4)

    local isActive = State.SyncTargetMode or State.DanceMode
    local statusText
    if State.SyncBroadcastMode then
        statusText = "🔴 BROADCAST: semua clone niru player random yang online"
    elseif State.SyncTargetMode and State.SyncTargetPlayer then
        statusText = "🟢 Sync aktif ke: " .. State.SyncTargetPlayer.Name
    elseif State.DanceMode then
        statusText = "🟢 Sync aktif ke: kamu sendiri (Dance Mode)"
    else
        statusText = "⚪ Sync tidak aktif"
    end
    local statusLbl = makeLabel(statusText, 11, isActive and COLORS.Green or COLORS.Gray, Enum.Font.GothamBold, statusCard)
    statusLbl.LayoutOrder = 1

    local reconnectLbl = makeLabel("Auto-Reconnect: " .. (State.SyncAutoReconnect and "ON (nyambung otomatis kalau target respawn)" or "OFF"), 8, COLORS.DarkGray, nil, statusCard)
    reconnectLbl.LayoutOrder = 2

    -- ===== PILIH PLAYER (PICKER, BUKAN TEXTBOX) =====
    makeSectionHeader("PILIH PLAYER TARGET", tabContentFrame, 3, COLORS.Blue)

    local otherPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then table.insert(otherPlayers, player) end
    end

    if #otherPlayers == 0 then
        local emptyLbl = makeLabel("Tidak ada player lain di map ini saat ini.", 9, COLORS.DarkGray, nil, tabContentFrame)
        emptyLbl.LayoutOrder = 4
    else
        for i, player in ipairs(otherPlayers) do
            local isSelected = State.SyncTargetMode and State.SyncTargetPlayer == player
            local card = makePremiumCard(tabContentFrame, 3 + i, 46)
            if isSelected then stroke(card, COLORS.Purple, 1.5, 0.1) end

            local avatarHolder = Instance.new("Frame", card)
            avatarHolder.Size = UDim2.new(0, 34, 0, 34)
            avatarHolder.Position = UDim2.new(0, 6, 0.5, -17)
            avatarHolder.BackgroundColor3 = COLORS.Panel2
            corner(avatarHolder, 17)
            stroke(avatarHolder, COLORS.Purple, 1, 0.4)

            local avatarImg = Instance.new("ImageLabel", avatarHolder)
            avatarImg.Size = UDim2.new(1, 0, 1, 0)
            avatarImg.BackgroundTransparency = 1
            corner(avatarImg, 17)
            task.spawn(function()
                local ok, content = pcall(function()
                    return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                end)
                if ok and content and avatarImg.Parent then avatarImg.Image = content end
            end)

            local nameLbl = makeLabel(player.DisplayName, 11, COLORS.White, Enum.Font.GothamBold, card)
            nameLbl.Size = UDim2.new(1, -140, 0, 18)
            nameLbl.Position = UDim2.new(0, 48, 0, 5)

            local subLbl = makeLabel("@" .. player.Name, 8, COLORS.Gray, nil, card)
            subLbl.Size = UDim2.new(1, -140, 0, 14)
            subLbl.Position = UDim2.new(0, 48, 0, 24)

            local syncBtn = makeButton(isSelected and "AKTIF ✓" or "SYNC", isSelected and COLORS.PurpleDark or COLORS.Panel2, card, UDim2.new(0, 70, 0, 34))
            syncBtn.Position = UDim2.new(1, -78, 0.5, -17)
            syncBtn.MouseButton1Click:Connect(function()
                if isSelected then
                    State.SyncTargetMode = false
                    State.SyncTargetPlayer = nil
                    StopSyncSystem()
                else
                    State.SyncTargetPlayer = player
                    State.SyncTargetMode = true
                    State.DanceMode = false
                    State.SyncBroadcastMode = false
                    SetupDanceSync()
                end
                rebuildSyncTab()
            end)
        end
    end

    local nextOrder = 4 + #otherPlayers

    -- ===== NONAKTIFKAN SEMUA =====
    local deactivateBtn = makeButton("⏹ NONAKTIFKAN SYNC", COLORS.Red, tabContentFrame)
    deactivateBtn.LayoutOrder = nextOrder + 1
    deactivateBtn.MouseButton1Click:Connect(function()
        State.SyncTargetMode = false
        State.SyncTargetPlayer = nil
        State.DanceMode = false
        State.SyncBroadcastMode = false
        StopSyncSystem()
        rebuildSyncTab()
    end)

    -- ===== FITUR TAMBAHAN =====
    makeSectionHeader("FITUR SYNC LAINNYA", tabContentFrame, nextOrder + 2, COLORS.Gold)

    local broadcastBtn = makeButton(State.SyncBroadcastMode and "📡 BROADCAST: ON" or "📡 SYNC KE SEMUA PLAYER ONLINE (Broadcast)", State.SyncBroadcastMode and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    broadcastBtn.LayoutOrder = nextOrder + 3
    broadcastBtn.MouseButton1Click:Connect(function()
        if State.SyncBroadcastMode then
            State.SyncBroadcastMode = false
            State.SyncTargetMode = false
            State.SyncTargetPlayer = nil
            StopSyncSystem()
        else
            local candidates = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then table.insert(candidates, player) end
            end
            if #candidates > 0 then
                State.SyncBroadcastMode = true
                State.SyncTargetPlayer = candidates[math.random(1, #candidates)]
                State.SyncTargetMode = true
                State.DanceMode = false
                SetupDanceSync()
            end
        end
        rebuildSyncTab()
    end)

    local autoReconnectBtn = makeButton("🔄 AUTO-RECONNECT: " .. (State.SyncAutoReconnect and "ON" or "OFF"), State.SyncAutoReconnect and COLORS.Emerald or COLORS.Panel, tabContentFrame)
    autoReconnectBtn.LayoutOrder = nextOrder + 4
    autoReconnectBtn.MouseButton1Click:Connect(function()
        State.SyncAutoReconnect = not State.SyncAutoReconnect
        rebuildSyncTab()
    end)

    -- ===== KONTEN / PRANK =====
    makeSectionHeader("FITUR KONTEN & PRANK CLONE", tabContentFrame, nextOrder + 5, COLORS.Red)

    local outfitBtn = makeButton("👕 SAMAKAN OUTFIT SEMUA CLONE KE AKU", COLORS.Blue, tabContentFrame)
    outfitBtn.LayoutOrder = nextOrder + 6
    outfitBtn.MouseButton1Click:Connect(function()
        local ok, msg = CopyMyOutfitToAllClones()
        outfitBtn.Text = ok and ("✓ " .. msg) or ("✗ " .. tostring(msg))
        task.delay(2.5, function()
            if outfitBtn and outfitBtn.Parent then outfitBtn.Text = "👕 SAMAKAN OUTFIT SEMUA CLONE KE AKU" end
        end)
    end)

    local ghostBtn = makeButton(State.GhostModeActive and "👻 GHOST MODE: ON" or "👻 GHOST MODE (Muncul-Hilang Acak)", State.GhostModeActive and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    ghostBtn.LayoutOrder = nextOrder + 7
    ghostBtn.MouseButton1Click:Connect(function()
        if State.GhostModeActive then StopGhostMode() else StartGhostMode() end
        rebuildSyncTab()
    end)

    local ragdollBtn = makeButton(State.RagdollPrankActive and "🤸 RAGDOLL PRANK: ON" or "🤸 RAGDOLL PRANK (Jatuh Acak)", State.RagdollPrankActive and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    ragdollBtn.LayoutOrder = nextOrder + 8
    ragdollBtn.MouseButton1Click:Connect(function()
        if State.RagdollPrankActive then StopRagdollPrank() else StartRagdollPrank() end
        rebuildSyncTab()
    end)

    local swapBtn = makeButton(State.RandomSwapActive and "🔀 RANDOM SWAP: ON" or "🔀 RANDOM SWAP (Tukar Posisi Acak)", State.RandomSwapActive and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    swapBtn.LayoutOrder = nextOrder + 9
    swapBtn.MouseButton1Click:Connect(function()
        if State.RandomSwapActive then StopRandomSwap() else StartRandomSwap() end
        rebuildSyncTab()
    end)

    local memeBtn = makeButton(State.MemeChatActive and "💬 MEME CHAT: ON" or "💬 MEME CHAT (Auto Ngomong Lucu)", State.MemeChatActive and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    memeBtn.LayoutOrder = nextOrder + 10
    memeBtn.MouseButton1Click:Connect(function()
        if State.MemeChatActive then StopMemeChat() else StartMemeChat() end
        rebuildSyncTab()
    end)

    local hint = makeLabel("Tips: gabungkan Ghost Mode + Ragdoll Prank + Meme Chat bareng-bareng buat konten yang lebih seru!", 8, COLORS.DarkGray, nil, tabContentFrame)
    hint.LayoutOrder = nextOrder + 11
    hint.TextWrapped = true
end

rebuildAIChatTab = function()
    clearTabContent()

    makeSectionHeader("GROQ API KEY", tabContentFrame, 1, COLORS.Gold)

    local apiInput, apiFrame = makeInput("Masukkan Groq API Key...", tabContentFrame)
    apiFrame.LayoutOrder = 2
    if State.GroqApiKey then apiInput.Text = State.GroqApiKey end

    local saveKeyBtn = makeButton("SIMPAN KEY", COLORS.Blue, tabContentFrame)
    saveKeyBtn.LayoutOrder = 3
    saveKeyBtn.MouseButton1Click:Connect(function()
        State.GroqApiKey = apiInput.Text:gsub("%s+", "")
        SaveApiKey()
        rebuildAIChatTab()
    end)

    -- ===== STATUS PANEL =====
    local statusCard = Instance.new("Frame")
    statusCard.Size = UDim2.new(1, 0, 0, 62)
    statusCard.BackgroundColor3 = COLORS.Panel2
    statusCard.LayoutOrder = 4
    statusCard.Parent = tabContentFrame
    corner(statusCard, 10)
    stroke(statusCard, State.AIChatEnabled and COLORS.Emerald or COLORS.Panel3, 1)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 8, 0, 8)
    statusDot.Position = UDim2.new(0, 10, 0, 10)
    statusDot.BackgroundColor3 = State.AIChatEnabled and COLORS.Emerald or COLORS.DarkGray
    statusDot.BorderSizePixel = 0
    statusDot.Parent = statusCard
    corner(statusDot, 4)

    local statusTitle = makeLabel("Status: " .. (State.AIChatStatus or "Belum aktif"), 10, COLORS.SoftWhite, Enum.Font.GothamBold, statusCard)
    statusTitle.Size = UDim2.new(1, -30, 0, 16)
    statusTitle.Position = UDim2.new(0, 24, 0, 6)

    local errorText = State.AIChatLastError and ("Error terakhir: " .. tostring(State.AIChatLastError)) or "Tidak ada error."
    local statusError = makeLabel(errorText, 8, State.AIChatLastError and COLORS.Red or COLORS.DarkGray, nil, statusCard)
    statusError.Size = UDim2.new(1, -20, 0, 34)
    statusError.Position = UDim2.new(0, 10, 0, 24)
    statusError.TextWrapped = true
    statusError.TextYAlignment = Enum.TextYAlignment.Top

    local aiToggleBtn = makeButton(State.AIChatEnabled and "AUTO AI CHAT: ACTIVE ●" or "AUTO AI CHAT: OFF", State.AIChatEnabled and COLORS.Emerald or COLORS.Panel, tabContentFrame)
    aiToggleBtn.LayoutOrder = 5
    aiToggleBtn.MouseButton1Click:Connect(function()
        if State.AIChatEnabled then
            StopAIChat()
        else
            StartAIChat()
        end
        rebuildAIChatTab()
    end)

    local testBtn = makeButton("TES PERCAKAPAN SEKARANG", COLORS.Orange, tabContentFrame)
    testBtn.LayoutOrder = 6
    testBtn.MouseButton1Click:Connect(function()
        State.AIChatStatus = "Menguji..."
        rebuildAIChatTab()
        task.spawn(function()
            DoAIChatOnce()
            rebuildAIChatTab()
        end)
    end)

    local infoLabel = makeLabel("Interval auto-chat: " .. State.AIChatCooldown .. " detik  |  Model: " .. GROQ_MODELS[1], 8, COLORS.Gray, nil, tabContentFrame)
    infoLabel.LayoutOrder = 7

    -- ===== CHAT MANUAL =====
    makeSectionHeader("CHAT MANUAL KE CLONE (Bubble Roblox Asli)", tabContentFrame, 8, COLORS.Blue)

    local clones = GetAllCloneModels()
    local targetName = State.ManualChatTarget and State.ManualChatTarget.Name or nil
    if State.ManualChatTarget and not State.ManualChatTarget.Parent then
        State.ManualChatTarget = nil
        targetName = nil
    end

    local targetBtn = makeButton(targetName and ("🎯 TARGET: " .. targetName) or "PILIH CLONE TARGET ▾", COLORS.Panel2, tabContentFrame)
    targetBtn.LayoutOrder = 9

    local pickerOpen = false
    local pickerHolder = Instance.new("Frame")
    pickerHolder.Size = UDim2.new(1, 0, 0, 0)
    pickerHolder.AutomaticSize = Enum.AutomaticSize.Y
    pickerHolder.BackgroundTransparency = 1
    pickerHolder.LayoutOrder = 10
    pickerHolder.Parent = tabContentFrame
    pickerHolder.Visible = false

    local pickerLayout = Instance.new("UIListLayout")
    pickerLayout.Padding = UDim.new(0, 4)
    pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    pickerLayout.Parent = pickerHolder

    if #clones == 0 then
        local noClone = makeLabel("Belum ada clone. Buat dulu di tab Clones.", 9, COLORS.DarkGray, nil, pickerHolder)
        noClone.LayoutOrder = 1
    else
        for i, clone in ipairs(clones) do
            local pickBtn = makeButton(clone.Name, COLORS.Panel, pickerHolder, UDim2.new(1, 0, 0, 28))
            pickBtn.LayoutOrder = i
            pickBtn.MouseButton1Click:Connect(function()
                State.ManualChatTarget = clone
                rebuildAIChatTab()
            end)
        end
    end

    targetBtn.MouseButton1Click:Connect(function()
        pickerOpen = not pickerOpen
        pickerHolder.Visible = pickerOpen
    end)

    local chatInput, chatFrame = makeInput("Ketik pesan buat clone...", tabContentFrame)
    chatFrame.LayoutOrder = 11

    local sendBtn = makeButton("KIRIM PESAN", COLORS.Blue, tabContentFrame)
    sendBtn.LayoutOrder = 12
    sendBtn.MouseButton1Click:Connect(function()
        local msg = chatInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if msg == "" then return end
        local target = State.ManualChatTarget or State.SelectedClone
        if not target or not target.Parent then return end
        SendManualChat(target, msg)
        chatInput.Text = ""
    end)

    local hint = makeLabel("Tips: kalau tidak pilih target, pesan dikirim ke clone yang sedang dipilih (Selected Clone).", 8, COLORS.DarkGray, nil, tabContentFrame)
    hint.LayoutOrder = 13

    -- ===== RAINBOW NAME TOGGLE =====
    makeSectionHeader("EFEK TAMBAHAN", tabContentFrame, 14, COLORS.Purple)

    local rainbowBtn = makeButton(State.RainbowNameMode and "RAINBOW NAME: ON 🌈" or "RAINBOW NAME: OFF", State.RainbowNameMode and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    rainbowBtn.LayoutOrder = 15
    rainbowBtn.MouseButton1Click:Connect(function()
        if State.RainbowNameMode then
            StopRainbowNames()
        else
            StartRainbowNames()
        end
        rebuildAIChatTab()
    end)
end

local function rebuildConfigTab()
    clearTabContent()

    local slotCount = 0
    for _ in pairs(State.ConfigSlots) do slotCount = slotCount + 1 end

    makeSectionHeader("CONFIG TERSIMPAN (" .. slotCount .. ")", tabContentFrame, 1, COLORS.Gold)

    -- ===== SIMPAN CONFIG BARU (dengan nama) =====
    local saveCard = makePremiumCard(tabContentFrame, 2)
    local savePad = Instance.new("UIPadding", saveCard)
    savePad.PaddingTop = UDim.new(0, 10); savePad.PaddingBottom = UDim.new(0, 10)
    savePad.PaddingLeft = UDim.new(0, 10); savePad.PaddingRight = UDim.new(0, 10)
    local saveLayout = Instance.new("UIListLayout", saveCard)
    saveLayout.Padding = UDim.new(0, 6)
    saveLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local saveTitle = makeLabel("SIMPAN CONFIG BARU", 10, COLORS.Gray, Enum.Font.GothamBold, saveCard)
    saveTitle.LayoutOrder = 1

    local nameInput, nameFrame = makeInput("Nama config (contoh: Squad Perang)", saveCard)
    nameFrame.LayoutOrder = 2

    local saveBtn = makeButton("💾 SIMPAN DENGAN NAMA INI", COLORS.Green, saveCard)
    saveBtn.LayoutOrder = 3
    saveBtn.MouseButton1Click:Connect(function()
        local slotName = nameInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if slotName == "" then return end
        local ok, msg = SaveConfigSlot(slotName)
        nameInput.Text = ""
        rebuildConfigTab()
    end)

    -- ===== QUICK SAVE (ke slot terakhir dipakai) =====
    if State.LastConfigSlot and State.ConfigSlots[State.LastConfigSlot] then
        local quickSaveBtn = makeButton("⚡ QUICK SAVE -> '" .. State.LastConfigSlot .. "'", COLORS.Blue, tabContentFrame)
        quickSaveBtn.LayoutOrder = 3
        quickSaveBtn.MouseButton1Click:Connect(function()
            SaveConfigSlot(State.LastConfigSlot)
            rebuildConfigTab()
        end)
    end

    -- ===== DAFTAR SEMUA SLOT CONFIG =====
    makeSectionHeader("PILIH CONFIG UNTUK DIMUAT", tabContentFrame, 4, COLORS.Blue)

    local slotNames = {}
    for name in pairs(State.ConfigSlots) do table.insert(slotNames, name) end
    table.sort(slotNames)

    if #slotNames == 0 then
        local emptyLbl = makeLabel("Belum ada config tersimpan. Simpan config pertama kamu di atas.", 9, COLORS.DarkGray, nil, tabContentFrame)
        emptyLbl.LayoutOrder = 5
        emptyLbl.TextWrapped = true
    else
        for i, slotName in ipairs(slotNames) do
            local slot = State.ConfigSlots[slotName]
            local cloneCount = (slot and slot.clones) and #slot.clones or 0
            local isActive = State.LastConfigSlot == slotName

            local card = makePremiumCard(tabContentFrame, 4 + i, 56)
            if isActive then stroke(card, COLORS.Gold, 1.5, 0.1) end

            local nameLbl = makeLabel((isActive and "★ " or "") .. slotName, 12, COLORS.White, Enum.Font.GothamBold, card)
            nameLbl.Size = UDim2.new(1, -160, 0, 20)
            nameLbl.Position = UDim2.new(0, 10, 0, 6)

            local savedDate = slot and slot.savedAt and os.date("%d/%m/%Y %H:%M", slot.savedAt) or "-"
            local subLbl = makeLabel(cloneCount .. " clone · " .. savedDate, 8, COLORS.Gray, nil, card)
            subLbl.Size = UDim2.new(1, -160, 0, 14)
            subLbl.Position = UDim2.new(0, 10, 0, 26)

            local loadBtn = makeButton("MUAT", COLORS.Blue, card, UDim2.new(0, 56, 0, 40))
            loadBtn.Position = UDim2.new(1, -160, 0.5, -20)
            loadBtn.MouseButton1Click:Connect(function()
                ApplyConfigSlot(slotName, function(ok, msg)
                    State.LastConfigSlot = slotName
                    rebuildConfigTab()
                end)
            end)

            local overwriteBtn = makeButton("↻", COLORS.Orange, card, UDim2.new(0, 40, 0, 40))
            overwriteBtn.Position = UDim2.new(1, -98, 0.5, -20)
            overwriteBtn.MouseButton1Click:Connect(function()
                SaveConfigSlot(slotName)
                rebuildConfigTab()
            end)

            local deleteBtn = makeButton("🗑", COLORS.Delete, card, UDim2.new(0, 40, 0, 40))
            deleteBtn.Position = UDim2.new(1, -50, 0.5, -20)
            deleteBtn.MouseButton1Click:Connect(function()
                DeleteConfigSlot(slotName)
                rebuildConfigTab()
            end)
        end
    end
end

rebuildVisualCloneTab = function()
    clearTabContent()

    makeSectionHeader("CLONE VISUAL — Ubah Wujudmu Jadi Orang Lain", tabContentFrame, 1, COLORS.Gold)

    local infoCard = makePremiumCard(tabContentFrame, 2)
    local infoPad = Instance.new("UIPadding", infoCard)
    infoPad.PaddingTop = UDim.new(0, 10); infoPad.PaddingBottom = UDim.new(0, 10)
    infoPad.PaddingLeft = UDim.new(0, 10); infoPad.PaddingRight = UDim.new(0, 10)
    local infoLayout = Instance.new("UIListLayout", infoCard)
    infoLayout.Padding = UDim.new(0, 4)

    local infoLbl = makeLabel("Bukan menggandakan diri jadi 2 — ini mengubah TUBUHMU SENDIRI supaya tampilannya sama persis kayak player yang kamu pilih. Kalau 'Tetap Pakai' diaktifkan, wujud ini akan otomatis dipertahankan walau kamu pindah map/respawn.", 9, COLORS.Gray, nil, infoCard)
    infoLbl.LayoutOrder = 1
    infoLbl.TextWrapped = true
    infoLbl.Size = UDim2.new(1, 0, 0, 48)

    -- ===== STATUS CARD =====
    local statusCard = makePremiumCard(tabContentFrame, 3)
    local statusPad = Instance.new("UIPadding", statusCard)
    statusPad.PaddingTop = UDim.new(0, 10); statusPad.PaddingBottom = UDim.new(0, 10)
    statusPad.PaddingLeft = UDim.new(0, 10); statusPad.PaddingRight = UDim.new(0, 10)
    local statusLayout = Instance.new("UIListLayout", statusCard)
    statusLayout.Padding = UDim.new(0, 4)
    if State.VisualCloneActive then
        stroke(statusCard, COLORS.Gold, 1.5, 0.1)
    end

    local statusText = State.VisualCloneActive
        and ("🟢 Sedang jadi: " .. tostring(State.VisualCloneCurrentName))
        or "⚪ Wujud asli (belum clone siapa-siapa)"
    local statusLbl = makeLabel(statusText, 11, State.VisualCloneActive and COLORS.Gold or COLORS.Gray, Enum.Font.GothamBold, statusCard)
    statusLbl.LayoutOrder = 1

    local persistLbl = makeLabel("Tetap Pakai Wujud Ini (walau pindah map/respawn): " .. (State.VisualClonePersist and "ON" or "OFF"), 8, COLORS.DarkGray, nil, statusCard)
    persistLbl.LayoutOrder = 2

    local statusBtnRow = Instance.new("Frame", tabContentFrame)
    statusBtnRow.Size = UDim2.new(1, 0, 0, 40)
    statusBtnRow.BackgroundTransparency = 1
    statusBtnRow.LayoutOrder = 4
    local statusBtnLayout = Instance.new("UIListLayout", statusBtnRow)
    statusBtnLayout.FillDirection = Enum.FillDirection.Horizontal
    statusBtnLayout.Padding = UDim.new(0, 6)

    local persistBtn = makeButton(State.VisualClonePersist and "🔒 TETAP PAKAI: ON" or "🔓 TETAP PAKAI: OFF", State.VisualClonePersist and COLORS.Emerald or COLORS.Panel2, statusBtnRow, UDim2.new(0.48, 0, 1, 0))
    persistBtn.MouseButton1Click:Connect(function()
        State.VisualClonePersist = not State.VisualClonePersist
        rebuildVisualCloneTab()
    end)

    local resetBtn = makeButton("↩ RESET KE WAJAH ASLI", COLORS.Red, statusBtnRow, UDim2.new(0.48, 0, 1, 0))
    resetBtn.MouseButton1Click:Connect(function()
        local ok, msg = ResetCloneVisual()
        resetBtn.Text = ok and "✓ Direset!" or ("✗ " .. tostring(msg))
        task.delay(2, function()
            if resetBtn and resetBtn.Parent then resetBtn.Text = "↩ RESET KE WAJAH ASLI" end
        end)
        rebuildVisualCloneTab()
    end)

    -- ===== PILIH PLAYER UNTUK DI-CLONE =====
    makeSectionHeader("PILIH PLAYERS — CLONE KE DIRI SENDIRI", tabContentFrame, 5, COLORS.Blue)

    local otherPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then table.insert(otherPlayers, player) end
    end

    if #otherPlayers == 0 then
        local emptyLbl = makeLabel("Tidak ada player lain di map ini saat ini.", 9, COLORS.DarkGray, nil, tabContentFrame)
        emptyLbl.LayoutOrder = 6
    else
        for i, player in ipairs(otherPlayers) do
            local isCurrentTarget = State.VisualCloneActive and State.VisualCloneCurrentUserId == player.UserId
            local card = makePremiumCard(tabContentFrame, 5 + i, 56)
            if isCurrentTarget then stroke(card, COLORS.Gold, 1.5, 0.1) end

            local avatarHolder = Instance.new("Frame", card)
            avatarHolder.Size = UDim2.new(0, 40, 0, 40)
            avatarHolder.Position = UDim2.new(0, 8, 0.5, -20)
            avatarHolder.BackgroundColor3 = COLORS.Panel2
            corner(avatarHolder, 20)
            stroke(avatarHolder, COLORS.Gold, 1, 0.4)

            local avatarImg = Instance.new("ImageLabel", avatarHolder)
            avatarImg.Size = UDim2.new(1, 0, 1, 0)
            avatarImg.BackgroundTransparency = 1
            corner(avatarImg, 20)
            task.spawn(function()
                local ok, content = pcall(function()
                    return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                end)
                if ok and content and avatarImg.Parent then avatarImg.Image = content end
            end)

            local nameLbl = makeLabel(player.DisplayName, 11, COLORS.White, Enum.Font.GothamBold, card)
            nameLbl.Size = UDim2.new(1, -180, 0, 18)
            nameLbl.Position = UDim2.new(0, 56, 0, 5)

            local subLbl = makeLabel("@" .. player.Name, 8, COLORS.Gray, nil, card)
            subLbl.Size = UDim2.new(1, -180, 0, 14)
            subLbl.Position = UDim2.new(0, 56, 0, 24)

            local cloneBtn = makeButton(isCurrentTarget and "AKTIF ✓" or "🔄 CLONE", isCurrentTarget and COLORS.GoldDark or COLORS.Blue, card, UDim2.new(0, 90, 0, 40))
            cloneBtn.Position = UDim2.new(1, -98, 0.5, -20)
            cloneBtn.MouseButton1Click:Connect(function()
                cloneBtn.Text = "..."
                task.spawn(function()
                    local ok, msg = ApplyCloneVisualToSelf(player.UserId, player.DisplayName)
                    if cloneBtn and cloneBtn.Parent then cloneBtn.Text = ok and "AKTIF ✓" or "✗ Gagal" end
                    rebuildVisualCloneTab()
                end)
            end)
        end
    end

    local nextOrder = 6 + #otherPlayers

    -- ===== SIMPAN SEBAGAI SLOT =====
    makeSectionHeader("SIMPAN TARGET DENGAN NAMA", tabContentFrame, nextOrder + 1, COLORS.Green)

    local saveCard = makePremiumCard(tabContentFrame, nextOrder + 2)
    local savePad = Instance.new("UIPadding", saveCard)
    savePad.PaddingTop = UDim.new(0, 10); savePad.PaddingBottom = UDim.new(0, 10)
    savePad.PaddingLeft = UDim.new(0, 10); savePad.PaddingRight = UDim.new(0, 10)
    local saveLayout = Instance.new("UIListLayout", saveCard)
    saveLayout.Padding = UDim.new(0, 6)

    local nameInput, nameFrame = makeInput("Nama slot (contoh: Wujud Boss)", saveCard)
    nameFrame.LayoutOrder = 1

    local saveBtn = makeButton("💾 SIMPAN WUJUD SEKARANG DENGAN NAMA INI", COLORS.Green, saveCard)
    saveBtn.LayoutOrder = 2
    saveBtn.MouseButton1Click:Connect(function()
        local slotName = nameInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if slotName == "" then return end
        if not State.VisualCloneActive or not State.VisualCloneCurrentUserId then
            saveBtn.Text = "✗ Belum clone siapa-siapa"
            task.delay(2, function()
                if saveBtn and saveBtn.Parent then saveBtn.Text = "💾 SIMPAN WUJUD SEKARANG DENGAN NAMA INI" end
            end)
            return
        end
        local ok, msg = SaveVisualCloneSlot(slotName, State.VisualCloneCurrentUserId, State.VisualCloneCurrentName)
        nameInput.Text = ""
        saveBtn.Text = ok and "✓ Tersimpan!" or ("✗ " .. tostring(msg))
        task.delay(2, function()
            if saveBtn and saveBtn.Parent then saveBtn.Text = "💾 SIMPAN WUJUD SEKARANG DENGAN NAMA INI" end
        end)
        rebuildVisualCloneTab()
    end)

    local saveHint = makeLabel("Tips: pencet CLONE ke salah satu player di atas dulu, baru ketik nama dan simpan di sini.", 8, COLORS.DarkGray, nil, tabContentFrame)
    saveHint.LayoutOrder = nextOrder + 3
    saveHint.TextWrapped = true

    -- ===== DAFTAR SLOT TERSIMPAN =====
    makeSectionHeader("SLOT TERSIMPAN", tabContentFrame, nextOrder + 4, COLORS.Purple)

    local slotNames = {}
    for name in pairs(State.VisualCloneSlots) do table.insert(slotNames, name) end
    table.sort(slotNames)

    if #slotNames == 0 then
        local emptyLbl = makeLabel("Belum ada slot tersimpan.", 9, COLORS.DarkGray, nil, tabContentFrame)
        emptyLbl.LayoutOrder = nextOrder + 5
    else
        for i, slotName in ipairs(slotNames) do
            local slot = State.VisualCloneSlots[slotName]
            local isCurrentTarget = State.VisualCloneActive and State.VisualCloneCurrentUserId == slot.userId
            local card = makePremiumCard(tabContentFrame, nextOrder + 5 + i, 56)
            if isCurrentTarget then stroke(card, COLORS.Gold, 1.5, 0.1) end

            local nameLbl = makeLabel(slotName, 12, COLORS.White, Enum.Font.GothamBold, card)
            nameLbl.Size = UDim2.new(1, -160, 0, 20)
            nameLbl.Position = UDim2.new(0, 10, 0, 6)

            local savedDate = slot.savedAt and os.date("%d/%m/%Y %H:%M", slot.savedAt) or "-"
            local subLbl = makeLabel("Target: " .. (slot.username or "?") .. " · " .. savedDate, 8, COLORS.Gray, nil, card)
            subLbl.Size = UDim2.new(1, -160, 0, 14)
            subLbl.Position = UDim2.new(0, 10, 0, 26)

            local loadBtn = makeButton(isCurrentTarget and "AKTIF ✓" or "JADI DIA", isCurrentTarget and COLORS.GoldDark or COLORS.Blue, card, UDim2.new(0, 74, 0, 40))
            loadBtn.Position = UDim2.new(1, -122, 0.5, -20)
            loadBtn.MouseButton1Click:Connect(function()
                loadBtn.Text = "..."
                task.spawn(function()
                    local ok, msg = LoadVisualCloneSlotToSelf(slotName)
                    if loadBtn and loadBtn.Parent then loadBtn.Text = ok and "AKTIF ✓" or "✗ Gagal" end
                    rebuildVisualCloneTab()
                end)
            end)

            local deleteBtn = makeButton("🗑", COLORS.Delete, card, UDim2.new(0, 40, 0, 40))
            deleteBtn.Position = UDim2.new(1, -50, 0.5, -20)
            deleteBtn.MouseButton1Click:Connect(function()
                DeleteVisualCloneSlot(slotName)
                rebuildVisualCloneTab()
            end)
        end
    end
end

rebuildHistoryTab = function()
    clearTabContent()

    if #State.HistoryList == 0 then
        local emptyLbl = makeLabel("Belum ada riwayat clone.", 10, COLORS.Gray, nil, tabContentFrame)
        emptyLbl.LayoutOrder = 1
    else
        for i, entry in ipairs(State.HistoryList) do
            local itemFrame = Instance.new("Frame")
            itemFrame.Size = UDim2.new(1, 0, 0, 42)
            itemFrame.BackgroundColor3 = COLORS.Panel
            itemFrame.LayoutOrder = i
            itemFrame.Parent = tabContentFrame
            corner(itemFrame, 8)
            stroke(itemFrame, COLORS.Panel3, 1)

            local nameLabel = makeLabel(entry.displayName or entry.username, 11, COLORS.White, Enum.Font.GothamBold, itemFrame)
            nameLabel.Size = UDim2.new(1, -75, 0, 20)
            nameLabel.Position = UDim2.new(0, 10, 0, 3)

            local subLabel = makeLabel("@" .. (entry.username or "unknown"), 9, COLORS.Gray, nil, itemFrame)
            subLabel.Size = UDim2.new(1, -75, 0, 14)
            subLabel.Position = UDim2.new(0, 10, 0, 22)

            local cloneBtn = makeButton("CLONE", COLORS.Red, itemFrame, UDim2.new(0, 58, 0, 26))
            cloneBtn.Position = UDim2.new(1, -64, 0, 8)
            cloneBtn.MouseButton1Click:Connect(function()
                CreateCloneFromUserId(entry.userId, entry.displayName, entry.username)
            end)
        end

        local clearBtn = makeButton("HAPUS RIWAYAT", COLORS.Delete, tabContentFrame)
        clearBtn.LayoutOrder = #State.HistoryList + 1
        clearBtn.MouseButton1Click:Connect(function()
            State.HistoryList = {}
            SaveHistory()
            rebuildHistoryTab()
        end)
    end
end

rebuildVariasiTab = function()
    clearTabContent()

    local titleLabel = makeLabel("BENTUK FORMASI CLONE:", 10, COLORS.Gray, Enum.Font.GothamBold, tabContentFrame)
    titleLabel.LayoutOrder = 1

    local shapes = {
        {key = "Circle", label = "LINGKARAN"},
        {key = "Line", label = "BARISAN"},
        {key = "Grid", label = "GRID / KOTAK"},
        {key = "VShape", label = "FORMASI V"},
        {key = "Spiral", label = "SPIRAL"},
    }

    for i, shapeData in ipairs(shapes) do
        local isActive = State.VariationShape == shapeData.key
        local shapeBtn = makeButton((isActive and "▶ " or "") .. shapeData.label, isActive and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
        shapeBtn.LayoutOrder = i + 1
        shapeBtn.MouseButton1Click:Connect(function()
            State.VariationShape = shapeData.key
            rebuildVariasiTab()
        end)
    end

    local radiusLabel = makeLabel("JARAK / RADIUS: " .. State.VariationRadius .. " studs", 10, COLORS.Gray, Enum.Font.GothamBold, tabContentFrame)
    radiusLabel.LayoutOrder = 10

    local radiusRow = Instance.new("Frame")
    radiusRow.Size = UDim2.new(1, 0, 0, 36)
    radiusRow.BackgroundTransparency = 1
    radiusRow.LayoutOrder = 11
    radiusRow.Parent = tabContentFrame

    local minusBtn = makeButton("-", COLORS.Panel2, radiusRow, UDim2.new(0, 50, 1, 0))
    minusBtn.MouseButton1Click:Connect(function()
        State.VariationRadius = math.max(2, State.VariationRadius - 2)
        rebuildVariasiTab()
    end)

    local plusBtn = makeButton("+", COLORS.Panel2, radiusRow, UDim2.new(0, 50, 1, 0))
    plusBtn.Position = UDim2.new(0, 58, 0, 0)
    plusBtn.MouseButton1Click:Connect(function()
        State.VariationRadius = math.min(60, State.VariationRadius + 2)
        rebuildVariasiTab()
    end)

    local applyBtn = makeButton("TERAPKAN FORMASI", COLORS.Green, tabContentFrame)
    applyBtn.LayoutOrder = 12
    applyBtn.MouseButton1Click:Connect(function()
        ArrangeFormation(State.VariationShape, State.VariationRadius)
    end)

    -- ===== FITUR MENARIK =====
    local extraLabel = makeLabel("FITUR VARIASI LAINNYA:", 10, COLORS.Gray, Enum.Font.GothamBold, tabContentFrame)
    extraLabel.LayoutOrder = 13

    local followBtn = makeButton(State.FollowMeMode and "FOLLOW ME: ON (Clone ngikutin)" or "FOLLOW ME: OFF", State.FollowMeMode and COLORS.PurpleDark or COLORS.Panel, tabContentFrame)
    followBtn.LayoutOrder = 14
    followBtn.MouseButton1Click:Connect(function()
        if State.FollowMeMode then
            StopFollowMe()
        else
            StartFollowMe()
        end
        rebuildVariasiTab()
    end)

    local freezeBtn = makeButton("FREEZE POSE (Clone Terpilih)", COLORS.Blue, tabContentFrame)
    freezeBtn.LayoutOrder = 15
    freezeBtn.MouseButton1Click:Connect(function()
        if State.SelectedClone then ToggleFreezePose(State.SelectedClone) end
    end)

    local randomizeBtn = makeButton("ACAK ULANG POSISI SEMUA CLONE", COLORS.Orange, tabContentFrame)
    randomizeBtn.LayoutOrder = 16
    randomizeBtn.MouseButton1Click:Connect(function()
        local clones = GetAllCloneModels()
        local character = LocalPlayer.Character
        local basePos = (character and character:FindFirstChild("HumanoidRootPart")) and character.HumanoidRootPart.Position or Vector3.new(0, 3, 0)
        for _, clone in ipairs(clones) do
            local randomOffset = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
            clone:PivotTo(CFrame.new(basePos + randomOffset))
        end
    end)

    local mirrorBtn = makeButton("HADAPKAN SEMUA KE SAYA", COLORS.Purple, tabContentFrame)
    mirrorBtn.LayoutOrder = 17
    mirrorBtn.MouseButton1Click:Connect(function()
        local clones = GetAllCloneModels()
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local myPos = character.HumanoidRootPart.Position
        for _, clone in ipairs(clones) do
            if clone.PrimaryPart then
                local cloneLook = CFrame.lookAt(clone.PrimaryPart.Position, myPos)
                clone:PivotTo(cloneLook)
            end
        end
    end)

    -- ===== FITUR PREMIUM BARU =====
    makeSectionHeader("FITUR PREMIUM", tabContentFrame, 18, COLORS.Gold)

    local orbitBtn = makeButton(State.OrbitMode and "ORBIT MODE: ON 🌀 (Mengelilingi kamu)" or "ORBIT MODE: OFF", State.OrbitMode and COLORS.GoldDark or COLORS.Panel, tabContentFrame)
    orbitBtn.LayoutOrder = 19
    orbitBtn.MouseButton1Click:Connect(function()
        if State.OrbitMode then StopOrbitMode() else StartOrbitMode() end
        rebuildVariasiTab()
    end)

    local pulseBtn = makeButton(State.PulseGlowMode and "PULSE GLOW: ON ✨" or "PULSE GLOW: OFF", State.PulseGlowMode and COLORS.GoldDark or COLORS.Panel, tabContentFrame)
    pulseBtn.LayoutOrder = 20
    pulseBtn.MouseButton1Click:Connect(function()
        if State.PulseGlowMode then StopPulseGlow() else StartPulseGlow() end
        rebuildVariasiTab()
    end)

    local mimicBtn = makeButton(State.MimicMode and "MIMIC MODE: ON 🪞 (Tiru gerakan kamu)" or "MIMIC MODE: OFF", State.MimicMode and COLORS.GoldDark or COLORS.Panel, tabContentFrame)
    mimicBtn.LayoutOrder = 21
    mimicBtn.MouseButton1Click:Connect(function()
        if State.MimicMode then StopMimicMode() else StartMimicMode() end
        rebuildVariasiTab()
    end)

    local countLabel = makeLabel("Total clone aktif: " .. #GetAllCloneModels(), 9, COLORS.DarkGray, nil, tabContentFrame)
    countLabel.LayoutOrder = 22
end

local function makePlayerCard(displayName, username, userId, parent, layoutOrder, actions)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 48)
    card.BackgroundColor3 = COLORS.Panel
    card.LayoutOrder = layoutOrder
    card.Parent = parent
    corner(card, 10)
    stroke(card, COLORS.Panel3, 1)

    -- Avatar thumbnail bulat
    local avatarHolder = Instance.new("Frame")
    avatarHolder.Size = UDim2.new(0, 36, 0, 36)
    avatarHolder.Position = UDim2.new(0, 6, 0, 6)
    avatarHolder.BackgroundColor3 = COLORS.Panel2
    avatarHolder.Parent = card
    corner(avatarHolder, 18)
    stroke(avatarHolder, COLORS.Gold, 1)

    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(1, 0, 1, 0)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Parent = avatarHolder
    corner(avatarImg, 18)
    if userId then
        task.spawn(function()
            local ok, content = pcall(function()
                local img = Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                return img
            end)
            if ok and content and avatarImg.Parent then
                avatarImg.Image = content
            end
        end)
    end

    local actionWidth = #actions * 44
    local nameLbl = makeLabel(displayName or username or "Unknown", 11, COLORS.White, Enum.Font.GothamBold, card)
    nameLbl.Size = UDim2.new(1, -actionWidth - 54, 0, 20)
    nameLbl.Position = UDim2.new(0, 50, 0, 6)

    local subLbl = makeLabel("@" .. (username or "unknown"), 9, COLORS.Gray, nil, card)
    subLbl.Size = UDim2.new(1, -actionWidth - 54, 0, 14)
    subLbl.Position = UDim2.new(0, 50, 0, 25)

    for i, actionData in ipairs(actions) do
        local btn = makeButton(actionData.text, actionData.color, card, UDim2.new(0, 38, 0, 38))
        btn.Position = UDim2.new(1, -(44 * (#actions - i + 1)), 0, 5)
        btn.TextSize = 8
        corner(btn, 8)
        btn.MouseButton1Click:Connect(actionData.onClick)
    end

    return card
end

local function isFavoritePlayer(userId)
    for _, entry in ipairs(State.FavoritesPlayersList) do
        if entry.userId == userId then return true end
    end
    return false
end

local function addFavoritePlayer(userId, displayName, username)
    if isFavoritePlayer(userId) then return end
    table.insert(State.FavoritesPlayersList, {userId = userId, displayName = displayName, username = username})
    SaveFavPlayers()
end

local function removeFavoritePlayer(userId)
    for i, entry in ipairs(State.FavoritesPlayersList) do
        if entry.userId == userId then
            table.remove(State.FavoritesPlayersList, i)
            break
        end
    end
    SaveFavPlayers()
end

local function isFriendAdded(userId)
    for _, entry in ipairs(State.FriendsList) do
        if entry.userId == userId then return true end
    end
    for _, entry in ipairs(State.RobloxFriendsList) do
        if entry.userId == userId then return true end
    end
    return false
end

-- ================================================
-- LOAD TEMAN ASLI DARI ROBLOX FRIENDS API
-- ================================================
local function LoadRobloxFriends()
    if State.RobloxFriendsLoading then return end
    State.RobloxFriendsLoading = true
    task.spawn(function()
        local success, pagesOrErr = pcall(function()
            return Players:GetFriendsAsync(LocalPlayer.UserId)
        end)
        if success and pagesOrErr then
            local results = {}
            local pages = pagesOrErr
            local ok2 = pcall(function()
                while true do
                    for _, item in ipairs(pages:GetCurrentPage()) do
                        table.insert(results, {
                            userId = item.Id,
                            displayName = item.DisplayName or item.Username,
                            username = item.Username,
                            isOnline = item.IsOnline,
                        })
                    end
                    if pages.IsFinished then break end
                    pages:AdvanceToNextPageAsync()
                end
            end)
            State.RobloxFriendsList = results
            State.RobloxFriendsLoaded = true
        else
            State.RobloxFriendsLoaded = false
        end
        State.RobloxFriendsLoading = false
        pcall(rebuildPlayersTab)
    end)
end

rebuildPlayersTab = function()
    clearTabContent()

    -- Sub-tab bar
    local subTabRow = Instance.new("Frame")
    subTabRow.Size = UDim2.new(1, 0, 0, 32)
    subTabRow.BackgroundTransparency = 1
    subTabRow.LayoutOrder = 1
    subTabRow.Parent = tabContentFrame

    local subTabLayout = Instance.new("UIListLayout")
    subTabLayout.FillDirection = Enum.FillDirection.Horizontal
    subTabLayout.Padding = UDim.new(0, 6)
    subTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    subTabLayout.Parent = subTabRow

    local subTabs = {"Players", "Friends", "Favorit"}
    for i, subName in ipairs(subTabs) do
        local isActive = State.PlayersSubTab == subName
        local subBtn = makeButton(subName, isActive and COLORS.PurpleDark or COLORS.Panel2, subTabRow, UDim2.new(0, 90, 1, 0))
        subBtn.LayoutOrder = i
        subBtn.MouseButton1Click:Connect(function()
            State.PlayersSubTab = subName
            rebuildPlayersTab()
        end)
    end

    if State.PlayersSubTab == "Players" then
        makeSectionHeader("PLAYERS DI MAP INI", tabContentFrame, 2, COLORS.Emerald)

        local playerList = Players:GetPlayers()
        local index = 3
        local anyOther = false
        for _, player in ipairs(playerList) do
            if player ~= LocalPlayer then
                anyOther = true
                local pUserId = player.UserId
                local isFav = isFavoritePlayer(pUserId)
                makePlayerCard(player.DisplayName, player.Name, pUserId, tabContentFrame, index, {
                    {
                        text = "CLONE",
                        color = COLORS.Red,
                        onClick = function()
                            CreateCloneFromUserId(pUserId, player.DisplayName, player.Name)
                        end,
                    },
                    {
                        text = isFav and "★" or "☆",
                        color = isFav and COLORS.Gold or COLORS.Panel2,
                        onClick = function()
                            if isFavoritePlayer(pUserId) then
                                removeFavoritePlayer(pUserId)
                            else
                                addFavoritePlayer(pUserId, player.DisplayName, player.Name)
                            end
                            rebuildPlayersTab()
                        end,
                    },
                    {
                        text = isFriendAdded(pUserId) and "✓" or "+F",
                        color = isFriendAdded(pUserId) and COLORS.Green or COLORS.Blue,
                        onClick = function()
                            if not isFriendAdded(pUserId) then
                                table.insert(State.FriendsList, {userId = pUserId, displayName = player.DisplayName, username = player.Name})
                                rebuildPlayersTab()
                            end
                        end,
                    },
                })
                index = index + 1
            end
        end
        if not anyOther then
            local emptyLbl = makeLabel("Tidak ada player lain di map ini.", 10, COLORS.DarkGray, nil, tabContentFrame)
            emptyLbl.LayoutOrder = index
        end

    elseif State.PlayersSubTab == "Friends" then
        makeSectionHeader("TEMAN ROBLOX KAMU", tabContentFrame, 2, COLORS.Blue)

        if not State.RobloxFriendsLoaded and not State.RobloxFriendsLoading then
            LoadRobloxFriends()
        end

        local refreshBtn = makeButton(State.RobloxFriendsLoading and "MEMUAT..." or "🔄 MUAT ULANG DAFTAR TEMAN", COLORS.Panel2, tabContentFrame)
        refreshBtn.LayoutOrder = 3
        refreshBtn.MouseButton1Click:Connect(function()
            State.RobloxFriendsLoaded = false
            LoadRobloxFriends()
            rebuildPlayersTab()
        end)

        local orderCounter = 4

        if State.RobloxFriendsLoading then
            local loadingLbl = makeLabel("Memuat daftar teman dari Roblox...", 9, COLORS.DarkGray, nil, tabContentFrame)
            loadingLbl.LayoutOrder = orderCounter
            orderCounter = orderCounter + 1
        elseif #State.RobloxFriendsList == 0 then
            local emptyLbl = makeLabel("Tidak ada teman ditemukan (atau gagal memuat).", 9, COLORS.DarkGray, nil, tabContentFrame)
            emptyLbl.LayoutOrder = orderCounter
            orderCounter = orderCounter + 1
        else
            for _, entry in ipairs(State.RobloxFriendsList) do
                local isFav = isFavoritePlayer(entry.userId)
                local card = makePlayerCard(entry.displayName, entry.username, entry.userId, tabContentFrame, orderCounter, {
                    {
                        text = "CLONE",
                        color = COLORS.Red,
                        onClick = function()
                            CreateCloneFromUserId(entry.userId, entry.displayName, entry.username)
                        end,
                    },
                    {
                        text = isFav and "★" or "☆",
                        color = isFav and COLORS.Gold or COLORS.Panel2,
                        onClick = function()
                            if isFavoritePlayer(entry.userId) then
                                removeFavoritePlayer(entry.userId)
                            else
                                addFavoritePlayer(entry.userId, entry.displayName, entry.username)
                            end
                            rebuildPlayersTab()
                        end,
                    },
                })
                if entry.isOnline then
                    local onlineDot = Instance.new("Frame")
                    onlineDot.Size = UDim2.new(0, 10, 0, 10)
                    onlineDot.Position = UDim2.new(0, 34, 0, 34)
                    onlineDot.BackgroundColor3 = COLORS.Emerald
                    onlineDot.BorderSizePixel = 0
                    onlineDot.ZIndex = 5
                    onlineDot.Parent = card
                    corner(onlineDot, 5)
                    stroke(onlineDot, COLORS.Panel, 2)
                end
                orderCounter = orderCounter + 1
            end
        end

        -- ===== TAMBAH MANUAL (pelengkap, misal teman belum add Roblox friend) =====
        makeSectionHeader("TAMBAH MANUAL (Opsional)", tabContentFrame, orderCounter, COLORS.Gray)
        orderCounter = orderCounter + 1

        local addInput, addFrame = makeInput("Username teman...", tabContentFrame)
        addFrame.LayoutOrder = orderCounter
        orderCounter = orderCounter + 1

        local addBtn = makeButton("TAMBAH MANUAL", COLORS.Green, tabContentFrame)
        addBtn.LayoutOrder = orderCounter
        orderCounter = orderCounter + 1
        addBtn.MouseButton1Click:Connect(function()
            local text = addInput.Text:gsub("^%s+", ""):gsub("%s+$", "")
            if text == "" then return end
            local userId, _ = ResolveUserId(text)
            if not userId then return end
            if isFriendAdded(userId) then return end
            local dispName = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player.UserId == userId then dispName = player.DisplayName break end
            end
            if not dispName then dispName = GetDisplayName(userId) or text end
            table.insert(State.FriendsList, {userId = userId, displayName = dispName, username = text})
            addInput.Text = ""
            rebuildPlayersTab()
        end)

        if #State.FriendsList > 0 then
            for i, entry in ipairs(State.FriendsList) do
                local isFav = isFavoritePlayer(entry.userId)
                makePlayerCard(entry.displayName, entry.username, entry.userId, tabContentFrame, orderCounter, {
                    {
                        text = "CLONE",
                        color = COLORS.Red,
                        onClick = function()
                            CreateCloneFromUserId(entry.userId, entry.displayName, entry.username)
                        end,
                    },
                    {
                        text = isFav and "★" or "☆",
                        color = isFav and COLORS.Gold or COLORS.Panel2,
                        onClick = function()
                            if isFavoritePlayer(entry.userId) then
                                removeFavoritePlayer(entry.userId)
                            else
                                addFavoritePlayer(entry.userId, entry.displayName, entry.username)
                            end
                            rebuildPlayersTab()
                        end,
                    },
                    {
                        text = "X",
                        color = COLORS.Delete,
                        onClick = function()
                            table.remove(State.FriendsList, i)
                            rebuildPlayersTab()
                        end,
                    },
                })
                orderCounter = orderCounter + 1
            end
        end

    elseif State.PlayersSubTab == "Favorit" then
        makeSectionHeader("PLAYER / TEMAN FAVORIT", tabContentFrame, 2, COLORS.Gold)

        if #State.FavoritesPlayersList == 0 then
            local emptyLbl = makeLabel("Belum ada favorit. Tekan ☆ di tab Players/Friends untuk menambahkan.", 10, COLORS.DarkGray, nil, tabContentFrame)
            emptyLbl.LayoutOrder = 3
        else
            for i, entry in ipairs(State.FavoritesPlayersList) do
                makePlayerCard(entry.displayName, entry.username, entry.userId, tabContentFrame, 2 + i, {
                    {
                        text = "CLONE",
                        color = COLORS.Red,
                        onClick = function()
                            CreateCloneFromUserId(entry.userId, entry.displayName, entry.username)
                        end,
                    },
                    {
                        text = "X",
                        color = COLORS.Delete,
                        onClick = function()
                            removeFavoritePlayer(entry.userId)
                            rebuildPlayersTab()
                        end,
                    },
                })
            end

            local clearFavBtn = makeButton("HAPUS SEMUA FAVORIT", COLORS.Delete, tabContentFrame)
            clearFavBtn.LayoutOrder = #State.FavoritesPlayersList + 3
            clearFavBtn.MouseButton1Click:Connect(function()
                State.FavoritesPlayersList = {}
                SaveFavPlayers()
                rebuildPlayersTab()
            end)
        end
    end
end

rebuildCurrentTab = function()
    if State.CurrentTab == "Clones" then
        rebuildClonesTab()
    elseif State.CurrentTab == "Editor" then
        rebuildEditorTab()
    elseif State.CurrentTab == "Sync" then
        rebuildSyncTab()
    elseif State.CurrentTab == "AI Chat" then
        rebuildAIChatTab()
    elseif State.CurrentTab == "Config" then
        rebuildConfigTab()
    elseif State.CurrentTab == "History" then
        rebuildHistoryTab()
    elseif State.CurrentTab == "Players" then
        rebuildPlayersTab()
    elseif State.CurrentTab == "Variasi" then
        rebuildVariasiTab()
    elseif State.CurrentTab == "Clone Visual" then
        rebuildVisualCloneTab()
    end
end

-- ================================================
-- MAIN APP OPEN FUNCTION
-- ================================================
function _G.openMyCloneApp()
    _G.CurrentPhoneApp = "MyClone.lua"

    LoadApiKey()
    LoadHistory()
    LoadFavorites()
    LoadFavPlayers()
    LoadConfigSlots()
    LoadVisualCloneSlots()

    if not Workspace:FindFirstChild(FOLDER_NAME) then
        local folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = Workspace
    end

    local appContent = _G.appContent
    if not appContent then return end

    for _, child in ipairs(appContent:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    -- Tab Bar (Horizontal Scrollable)
    tabBarFrame = Instance.new("ScrollingFrame")
    tabBarFrame.Size = UDim2.new(1, 0, 0, 34)
    tabBarFrame.BackgroundTransparency = 1
    tabBarFrame.BorderSizePixel = 0
    tabBarFrame.ScrollBarThickness = 0
    tabBarFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabBarFrame.AutomaticCanvasSize = Enum.AutomaticSize.X
    tabBarFrame.Parent = appContent

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 6)
    tabLayout.Parent = tabBarFrame

    local tabs = {"Clones", "Players", "Editor", "Sync", "Variasi", "Clone Visual", "AI Chat", "Config", "History"}
    for i, tabName in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 75, 1, 0)
        btn.BackgroundColor3 = (State.CurrentTab == tabName) and COLORS.PurpleDark or COLORS.Panel2
        btn.Text = tabName
        btn.TextColor3 = COLORS.White
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 9
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        btn.Parent = tabBarFrame
        corner(btn, 6)
        stroke(btn, COLORS.Panel3, 1)
        pressFX(btn)

        btn.MouseButton1Click:Connect(function()
            State.CurrentTab = tabName
            for _, child in ipairs(tabBarFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = COLORS.Panel2
                end
            end
            btn.BackgroundColor3 = COLORS.PurpleDark
            rebuildCurrentTab()
        end)
    end

    -- Tab Content Container (Vertical Scrollable)
    tabContentFrame = Instance.new("ScrollingFrame")
    tabContentFrame.Size = UDim2.new(1, 0, 1, -40)
    tabContentFrame.Position = UDim2.new(0, 0, 0, 40)
    tabContentFrame.BackgroundTransparency = 1
    tabContentFrame.BorderSizePixel = 0
    tabContentFrame.ScrollBarThickness = 3
    tabContentFrame.ScrollBarImageColor3 = COLORS.Purple
    tabContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabContentFrame.Parent = appContent

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = tabContentFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingRight = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 2)
    padding.Parent = tabContentFrame

    -- Initialize Gizmos safely
    local parentTarget = CoreGui
    pcall(function()
        if not Gizmos.Position or not Gizmos.Position.Parent then
            Gizmos.Position = Instance.new("Handles")
            Gizmos.Position.Style = Enum.HandlesStyle.Movement
            Gizmos.Position.Color3 = COLORS.Red
            Gizmos.Position.Parent = parentTarget
        end
        if not Gizmos.Rotation or not Gizmos.Rotation.Parent then
            Gizmos.Rotation = Instance.new("ArcHandles")
            Gizmos.Rotation.Color3 = COLORS.Purple
            Gizmos.Rotation.Parent = parentTarget
        end
    end)

    SetGizmoVisibility()

    -- Connect Gizmo Handlers safely once
    if Gizmos.Position and not Gizmos.Position:GetAttribute("DragConnected") then
        Gizmos.Position:SetAttribute("DragConnected", true)
        local dragStartCFrame = nil
        Gizmos.Position.MouseButton1Down:Connect(function()
            if not State.SelectedClone or not State.PositionMode or not State.SelectedClone.PrimaryPart then return end
            dragStartCFrame = State.SelectedClone.PrimaryPart.CFrame
            GizmoDragging = true
            local camera = Workspace.CurrentCamera
            if camera then
                CameraRestoreType = camera.CameraType
                CameraRestoreSubject = camera.CameraSubject
                camera.CameraType = Enum.CameraType.Scriptable
            end
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end)
        Gizmos.Position.MouseDrag:Connect(function(face, distance)
            if not State.SelectedClone or not dragStartCFrame then return end
            local delta = Vector3.FromNormalId(face) * distance
            State.SelectedClone:PivotTo(dragStartCFrame * CFrame.new(delta))
        end)
        Gizmos.Position.MouseButton1Up:Connect(function()
            dragStartCFrame = nil
            GizmoDragging = false
            local camera = Workspace.CurrentCamera
            if camera and CameraRestoreType then
                camera.CameraType = CameraRestoreType
                if CameraRestoreSubject and CameraRestoreSubject.Parent then
                    camera.CameraSubject = CameraRestoreSubject
                end
            end
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        end)
    end

    if Gizmos.Rotation and not Gizmos.Rotation:GetAttribute("DragConnected") then
        Gizmos.Rotation:SetAttribute("DragConnected", true)
        local rotStartCFrame = nil
        Gizmos.Rotation.MouseButton1Down:Connect(function()
            if not State.SelectedClone or not State.RotationMode or not State.SelectedClone.PrimaryPart then return end
            rotStartCFrame = State.SelectedClone.PrimaryPart.CFrame
            GizmoDragging = true
            local camera = Workspace.CurrentCamera
            if camera then
                CameraRestoreType = camera.CameraType
                CameraRestoreSubject = camera.CameraSubject
                camera.CameraType = Enum.CameraType.Scriptable
            end
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
        end)
        Gizmos.Rotation.MouseDrag:Connect(function(axis, relativeAngle)
            if not State.SelectedClone or not rotStartCFrame then return end
            local axisVector = Vector3.FromAxis(axis)
            State.SelectedClone:PivotTo(rotStartCFrame * CFrame.fromAxisAngle(axisVector, relativeAngle))
        end)
        Gizmos.Rotation.MouseButton1Up:Connect(function()
            rotStartCFrame = nil
            GizmoDragging = false
            local camera = Workspace.CurrentCamera
            if camera and CameraRestoreType then
                camera.CameraType = CameraRestoreType
                if CameraRestoreSubject and CameraRestoreSubject.Parent then
                    camera.CameraSubject = CameraRestoreSubject
                end
            end
            pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        end)
    end

    -- Click Selection in World
    local inputConn
    inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed or not State.EditMode then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local mouse = LocalPlayer:GetMouse()
            local target = mouse.Target
            local folder = Workspace:FindFirstChild(FOLDER_NAME)
            if folder and target and target:IsDescendantOf(folder) then
                local model = target:FindFirstAncestorOfClass("Model")
                if model then SelectClone(model) end
            end
        end
    end)

    appContent.Destroying:Connect(function()
        if inputConn then inputConn:Disconnect() end
        -- State and loops persist in background!
    end)

    rebuildCurrentTab()
end

return _G.openMyCloneApp