-- ================================================
-- FRIENDS.LUA — Friends List, Cross-Server Invite, Avatar Clone
-- ================================================
-- Fitur:
--   1. Daftar teman Roblox asli (Players:GetFriendsAsync)
--   2. Invite lintas server/map -> tersimpan di Firebase, muncul sebagai
--      notifikasi begitu teman itu online/buka AvatarClone (kapanpun itu,
--      termasuk kalau sekarang dia offline -> invite nunggu sampai dia login)
--   3. Invite butuh persetujuan (Accept/Decline) dari penerima -- TIDAK
--      memaksa pindah server tanpa izin
--   4. Clone avatar teman lewat HumanoidDescription resmi Roblox
-- ================================================

local Services    = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players     = Services.Players
local Helpers     = _G.Helpers or {}
local Firebase    = _G.Firebase
local appContent  = _G.appContent
local TeleportService = Services.TeleportService

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local pressFX = Helpers.pressFX

local C = {
    bg      = Color3.fromRGB(10, 10, 16),
    card    = Color3.fromRGB(20, 20, 28),
    card2   = Color3.fromRGB(26, 26, 36),
    border  = Color3.fromRGB(48, 48, 62),
    text    = Color3.fromRGB(240, 240, 250),
    text2   = Color3.fromRGB(155, 155, 172),
    text3   = Color3.fromRGB(95, 95, 112),
    accent  = Color3.fromRGB(100, 160, 255),
    green   = Color3.fromRGB(90, 220, 150),
    gold    = Color3.fromRGB(255, 195, 70),
    red     = Color3.fromRGB(255, 95, 105),
}

-- ==================== FIREBASE PATHS ====================
-- /invites/<targetUserId>/<inviteId> = {
--     fromUserId, fromName, fromUsername, toUserId, toName,
--     placeId, jobId, timestamp, status ("pending"/"accepted"/"declined")
-- }

local function sendInvite(targetUserId, targetName)
    if not Firebase or not Firebase.PushData then
        if _G.showDynamicNotification then

            _G.showDynamicNotification("Firebase tidak tersedia", C.red)

        end
        return
    end

    local inviteData = {
        fromUserId   = LocalPlayer.UserId,
        fromName     = LocalPlayer.DisplayName,
        fromUsername = LocalPlayer.Name,
        toUserId     = targetUserId,
        toName       = targetName,
        placeId      = tostring(game.PlaceId),
        jobId        = game.JobId,
        timestamp    = os.time(),
        status       = "pending",
    }

    local ok = pcall(function()
        Firebase.PushData("invites/" .. tostring(targetUserId), inviteData)
    end)

    if ok then
        if _G.showDynamicNotification then
            _G.showDynamicNotification(
                "📨 Invite terkirim ke " .. targetName .. "! Menunggu dia online...", C.green
            )
        end
    else
        if _G.showDynamicNotification then

            _G.showDynamicNotification("Gagal mengirim invite", C.red)

        end
    end
end

-- ==================== CEK INVITE MASUK (DIPANGGIL SEKALI SAAT SCRIPT START) ====================
-- Ini yang membuat invite tetap "sampai" walau target lagi offline saat
-- dikirim -- karena kita simpan permanen di Firebase, dan baru dicek
-- begitu client target benar-benar jalan (dia login/buka game).
local function checkIncomingInvites()
    if not Firebase or not Firebase.GetData then return end

    task.spawn(function()
        local ok, invites = pcall(function()
            return Firebase.GetData("invites/" .. tostring(LocalPlayer.UserId))
        end)
        if not ok or not invites or type(invites) ~= "table" then return end

        for inviteId, inv in pairs(invites) do
            if type(inv) == "table" and inv.status == "pending" then
                -- Invite lebih dari 24 jam dianggap basi, auto-bersihkan
                if os.time() - (inv.timestamp or 0) > 86400 then
                    pcall(function()
                        Firebase.DeleteData("invites/" .. tostring(LocalPlayer.UserId) .. "/" .. inviteId)
                    end)
                else
                    -- Tampilkan notifikasi Accept/Decline
                    if _G.showInviteNotif then
                        _G.showInviteNotif(inv, inviteId)
                    end
                end
            end
        end
    end)
end

-- ==================== UI: NOTIFIKASI INVITE DENGAN ACCEPT/DECLINE ====================
function _G.showInviteNotif(inv, inviteId)
    local gui = _G.Phone and _G.Phone.gui
    if not gui then return end

    local banner = Instance.new("Frame", gui)
    banner.Size = UDim2.new(1, -20, 0, 110)
    banner.Position = UDim2.new(0, 10, 0, -130)
    banner.BackgroundColor3 = C.card
    banner.ZIndex = 999
    banner.BorderSizePixel = 0
    corner(banner, 16)
    stroke(banner, C.accent, 1.5, 0.3)

    local titleLbl = Instance.new("TextLabel", banner)
    titleLbl.Size = UDim2.new(1,-20,0,20)
    titleLbl.Position = UDim2.new(0,14,0,10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "🎮 Undangan Server"
    titleLbl.TextColor3 = C.accent
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 13
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local descLbl = Instance.new("TextLabel", banner)
    descLbl.Size = UDim2.new(1,-20,0,18)
    descLbl.Position = UDim2.new(0,14,0,32)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = (inv.fromName or "Seseorang") .. " mengundangmu ke server-nya"
    descLbl.TextColor3 = C.text2
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextXAlignment = Enum.TextXAlignment.Left

    local acceptBtn = Instance.new("TextButton", banner)
    acceptBtn.Size = UDim2.new(0.48,-4,0,32)
    acceptBtn.Position = UDim2.new(0,14,0,62)
    acceptBtn.BackgroundColor3 = C.green
    acceptBtn.Text = "✓ Terima"
    acceptBtn.TextColor3 = Color3.new(1,1,1)
    acceptBtn.Font = Enum.Font.GothamBlack
    acceptBtn.TextSize = 12
    acceptBtn.AutoButtonColor = false
    corner(acceptBtn, 10)
    pressFX(acceptBtn)

    local declineBtn = Instance.new("TextButton", banner)
    declineBtn.Size = UDim2.new(0.48,-4,0,32)
    declineBtn.Position = UDim2.new(0.52,4,0,62)
    declineBtn.BackgroundColor3 = C.card2
    declineBtn.Text = "✕ Tolak"
    declineBtn.TextColor3 = C.text2
    declineBtn.Font = Enum.Font.GothamBold
    declineBtn.TextSize = 12
    declineBtn.AutoButtonColor = false
    corner(declineBtn, 10)
    stroke(declineBtn, C.border, 1, 0.4)
    pressFX(declineBtn)

    local ts = game:GetService("TweenService")
    ts:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Position = UDim2.new(0,10,0,16)}):Play()

    local function dismiss()
        ts:Create(banner, TweenInfo.new(0.25), {Position = UDim2.new(0,10,0,-130)}):Play()
        task.delay(0.3, function() pcall(function() banner:Destroy() end) end)
    end

    acceptBtn.MouseButton1Click:Connect(function()
        pcall(function()
            Firebase.DeleteData("invites/" .. tostring(LocalPlayer.UserId) .. "/" .. inviteId)
        end)
        dismiss()
        -- Sama server? langsung tanpa teleport. Beda server -> TeleportToPlaceInstance.
        if inv.jobId == game.JobId and tostring(inv.placeId) == tostring(game.PlaceId) then
            if _G.showDynamicNotification then

                _G.showDynamicNotification("Kamu sudah di server yang sama!", C.green)

            end
        else
            pcall(function()
                TeleportService:TeleportToPlaceInstance(tonumber(inv.placeId), inv.jobId, LocalPlayer)
            end)
        end
    end)

    declineBtn.MouseButton1Click:Connect(function()
        pcall(function()
            Firebase.DeleteData("invites/" .. tostring(LocalPlayer.UserId) .. "/" .. inviteId)
        end)
        dismiss()
    end)

    task.delay(15, function()
        if banner.Parent then dismiss() end
    end)
end

-- ==================== CLONE AVATAR TEMAN ====================
-- Membaca HumanoidDescription resmi Roblox (API publik, sama seperti
-- yang dipakai fitur "Clone" avatar orang lain di game manapun) lalu
-- diterapkan ke avatar sendiri.
local function cloneAvatarFrom(userId, displayName)
    local char = LocalPlayer.Character
    if not char then
        if _G.showDynamicNotification then

            _G.showDynamicNotification("Karakter belum siap", C.red)

        end
        return
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    task.spawn(function()
        local ok, desc = pcall(function()
            return Players:GetHumanoidDescriptionFromUserId(userId)
        end)

        if ok and desc then
            pcall(function()
                humanoid:ApplyDescription(desc)
            end)
            if _G.showDynamicNotification then
                _G.showDynamicNotification(
                    "✨ Avatar " .. displayName .. " berhasil di-clone!", C.green
                )
            end
        else
            if _G.showDynamicNotification then
                _G.showDynamicNotification(
                    "Gagal mengambil avatar " .. displayName, C.red
                )
            end
        end
    end)
end

-- ==================== AMBIL DAFTAR TEMAN ROBLOX ASLI ====================
local function fetchFriendsList(callback)
    task.spawn(function()
        local ok, friendPages = pcall(function()
            return Players:GetFriendsAsync(LocalPlayer.UserId)
        end)

        if not ok then
            callback({})
            return
        end

        local friends = {}
        local page = friendPages:GetCurrentPage()
        for _, friendInfo in ipairs(page) do
            table.insert(friends, {
                userId      = friendInfo.Id,
                displayName = friendInfo.DisplayName or friendInfo.Username,
                username    = friendInfo.Username,
                isOnline    = friendInfo.IsOnline,
            })
        end

        -- Ambil beberapa halaman lagi kalau ada (dibatasi biar tidak berat)
        local pageCount = 0
        while not friendPages.IsFinished and pageCount < 3 do
            local ok2 = pcall(function() friendPages:AdvanceToNextPageAsync() end)
            if not ok2 then break end
            local nextPage = friendPages:GetCurrentPage()
            for _, friendInfo in ipairs(nextPage) do
                table.insert(friends, {
                    userId      = friendInfo.Id,
                    displayName = friendInfo.DisplayName or friendInfo.Username,
                    username    = friendInfo.Username,
                    isOnline    = friendInfo.IsOnline,
                })
            end
            pageCount = pageCount + 1
        end

        table.sort(friends, function(a, b)
            if a.isOnline ~= b.isOnline then return a.isOnline end
            return a.displayName < b.displayName
        end)

        callback(friends)
    end)
end

-- ==================== RENDER SATU KARTU TEMAN ====================
local function renderFriendCard(parent, friend, order)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,0,0,78)
    card.BackgroundColor3 = C.card
    card.LayoutOrder = order
    corner(card, 14)
    stroke(card, friend.isOnline and C.green or C.border, 1, friend.isOnline and 0.5 or 0.3)

    local avatarFrame = Instance.new("Frame", card)
    avatarFrame.Size = UDim2.new(0,42,0,42)
    avatarFrame.Position = UDim2.new(0,10,0,10)
    avatarFrame.BackgroundColor3 = C.card2
    corner(avatarFrame, 100)
    stroke(avatarFrame, friend.isOnline and C.green or C.text3, 1.5, 0.2)

    local avatarImg = Instance.new("ImageLabel", avatarFrame)
    avatarImg.Size = UDim2.new(1,-4,1,-4)
    avatarImg.Position = UDim2.new(0,2,0,2)
    avatarImg.BackgroundTransparency = 1
    avatarImg.Image = "https://www.roblox.com/headshot-thumbnail/image?userId="..friend.userId.."&width=100&height=100&format=png"
    corner(avatarImg, 100)

    local nameLbl = Instance.new("TextLabel", card)
    nameLbl.Size = UDim2.new(1,-140,0,18)
    nameLbl.Position = UDim2.new(0,58,0,10)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = friend.displayName
    nameLbl.TextColor3 = C.text
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local userLbl = Instance.new("TextLabel", card)
    userLbl.Size = UDim2.new(1,-140,0,14)
    userLbl.Position = UDim2.new(0,58,0,28)
    userLbl.BackgroundTransparency = 1
    userLbl.Text = "@"..friend.username .. (friend.isOnline and "  🟢 Online" or "  ⚪ Offline")
    userLbl.TextColor3 = friend.isOnline and C.green or C.text3
    userLbl.Font = Enum.Font.Gotham
    userLbl.TextSize = 9
    userLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Tombol Invite (selalu aktif -- termasuk saat offline, karena
    -- invite tersimpan di Firebase dan nunggu sampai dia online)
    local inviteBtn = Instance.new("TextButton", card)
    inviteBtn.Size = UDim2.new(0.48,-14,0,26)
    inviteBtn.Position = UDim2.new(0,10,0,56)
    inviteBtn.BackgroundColor3 = C.accent
    inviteBtn.BackgroundTransparency = 0.8
    inviteBtn.Text = "📨 Invite"
    inviteBtn.TextColor3 = C.accent
    inviteBtn.Font = Enum.Font.GothamBold
    inviteBtn.TextSize = 10
    inviteBtn.AutoButtonColor = false
    corner(inviteBtn, 8)
    pressFX(inviteBtn)
    inviteBtn.MouseButton1Click:Connect(function()
        sendInvite(friend.userId, friend.displayName)
    end)

    -- Tombol Clone Avatar
    local cloneBtn = Instance.new("TextButton", card)
    cloneBtn.Size = UDim2.new(0.48,-14,0,26)
    cloneBtn.Position = UDim2.new(0.5,4,0,56)
    cloneBtn.BackgroundColor3 = C.gold
    cloneBtn.BackgroundTransparency = 0.8
    cloneBtn.Text = "✨ Clone"
    cloneBtn.TextColor3 = C.gold
    cloneBtn.Font = Enum.Font.GothamBold
    cloneBtn.TextSize = 10
    cloneBtn.AutoButtonColor = false
    corner(cloneBtn, 8)
    pressFX(cloneBtn)
    cloneBtn.MouseButton1Click:Connect(function()
        cloneAvatarFrom(friend.userId, friend.displayName)
    end)
end

-- ==================== BUKA APP ====================
function _G.openFriendsApp()
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,46)
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 12)
    stroke(header, C.accent, 1, 0.5)

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1,-70,0,22)
    hTitle.Position = UDim2.new(0,12,0,4)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "👥 Friends"
    hTitle.TextColor3 = C.text
    hTitle.Font = Enum.Font.GothamBlack
    hTitle.TextSize = 13
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hSub = Instance.new("TextLabel", header)
    hSub.Size = UDim2.new(1,-70,0,14)
    hSub.Position = UDim2.new(0,12,0,26)
    hSub.BackgroundTransparency = 1
    hSub.Text = "Invite lintas server & clone avatar"
    hSub.TextColor3 = C.text3
    hSub.Font = Enum.Font.Gotham
    hSub.TextSize = 9
    hSub.TextXAlignment = Enum.TextXAlignment.Left

    local refreshBtn = Instance.new("TextButton", header)
    refreshBtn.Size = UDim2.new(0,50,0,26)
    refreshBtn.Position = UDim2.new(1,-58,0.5,-13)
    refreshBtn.BackgroundColor3 = C.card2
    refreshBtn.Text = "🔄"
    refreshBtn.TextColor3 = C.text2
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.AutoButtonColor = false
    corner(refreshBtn, 8)
    stroke(refreshBtn, C.border, 1, 0.3)
    pressFX(refreshBtn)

    local listScroll = Instance.new("ScrollingFrame", appContent)
    listScroll.Size = UDim2.new(1,0,0,340)
    listScroll.BackgroundColor3 = C.bg
    listScroll.BorderSizePixel = 0
    listScroll.CanvasSize = UDim2.new(0,0,0,0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ScrollBarThickness = 3
    listScroll.ScrollBarImageColor3 = C.accent
    listScroll.LayoutOrder = 1
    corner(listScroll, 14)
    stroke(listScroll, C.border, 1, 0.4)

    local listPad = Instance.new("UIPadding", listScroll)
    listPad.PaddingTop = UDim.new(0,8); listPad.PaddingBottom = UDim.new(0,8)
    listPad.PaddingLeft = UDim.new(0,8); listPad.PaddingRight = UDim.new(0,8)

    local listLayout = Instance.new("UIListLayout", listScroll)
    listLayout.Padding = UDim.new(0,8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function renderFriends(list)
        for _, c in ipairs(listScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end

        if #list == 0 then
            local e = Instance.new("TextLabel", listScroll)
            e.Size = UDim2.new(1,0,0,40)
            e.BackgroundTransparency = 1
            e.Text = "Tidak ada teman ditemukan"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 11
            return
        end

        for i, friend in ipairs(list) do
            renderFriendCard(listScroll, friend, i)
        end
    end

    local function loadFriends()
        local loadingLbl = Instance.new("TextLabel", listScroll)
        loadingLbl.Size = UDim2.new(1,0,0,30)
        loadingLbl.BackgroundTransparency = 1
        loadingLbl.Text = "Memuat daftar teman..."
        loadingLbl.TextColor3 = C.text3
        loadingLbl.Font = Enum.Font.Gotham
        loadingLbl.TextSize = 10

        fetchFriendsList(function(friends)
            renderFriends(friends)
        end)
    end

    refreshBtn.MouseButton1Click:Connect(loadFriends)
    loadFriends()
end

-- Cek invite masuk sekali saat modul ini pertama kali di-load
task.spawn(function()
    task.wait(5) -- tunggu Firebase & LocalPlayer siap
    checkIncomingInvites()
end)

print("[Friends] Loaded! Invite lintas server + clone avatar siap.")
