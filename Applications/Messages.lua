-- ================================================
-- MESSAGES APP - Fixed & Upgraded
-- Fix #1: Notif muncul terus → sekarang pakai timestamp bukan count
-- Fix #2: Quick-reply dari banner langsung kirim ke Firebase /chat
-- Fix #3: Chat dari player masuk ke website dengan field yang konsisten
-- ================================================

local Services    = _G.Services
local LocalPlayer = _G.LocalPlayer
local T           = _G.T or {}
local Helpers     = _G.Helpers or {}
local Firebase    = _G.Firebase
local appContent  = _G.appContent

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local pressFX = Helpers.pressFX

local C = {
    bg      = Color3.fromRGB(248,248,252),
    card    = Color3.fromRGB(255,255,255),
    border  = Color3.fromRGB(220,220,228),
    text    = Color3.fromRGB(20,20,28),
    text2   = Color3.fromRGB(100,100,115),
    text3   = Color3.fromRGB(160,160,175),
    accent  = Color3.fromRGB(0,150,255),
    green   = Color3.fromRGB(0,200,100),
    admin   = Color3.fromRGB(139,92,246),
}

-- ==================== CHAT MONITOR (FIX UTAMA) ====================
-- BUG LAMA: pakai #chatList > lastChatCount
--   → tiap script restart, lastChatCount = 0
--   → semua chat lama dianggap "baru" → notif banjir
--
-- FIX: simpan timestamp pesan TERAKHIR yang sudah ditampilkan.
--      Hanya pesan dengan timestamp LEBIH BARU dari itu yang dianggap baru.

local lastSeenTimestamp = os.time() -- init ke "sekarang" → chat lama tidak muncul

task.spawn(function()
    -- Tunggu Firebase siap
    task.wait(3)

    while true do
        task.wait(4)

        if not Firebase or not Firebase.GetData then continue end

        local ok, chatData = pcall(function()
            return Firebase.GetData("chat")
        end)
        if not ok or not chatData or type(chatData) ~= "table" then continue end

        -- Kumpulkan semua chat, urutkan ascending by timestamp
        local chatList = {}
        for chatId, chatInfo in pairs(chatData) do
            if type(chatInfo) == "table" then
                table.insert(chatList, {id = chatId, data = chatInfo})
            end
        end
        table.sort(chatList, function(a, b)
            return (a.data.timestamp or 0) < (b.data.timestamp or 0)
        end)

        -- Filter hanya yang lebih baru dari lastSeenTimestamp
        local newChats = {}
        for _, item in ipairs(chatList) do
            local ts = item.data.timestamp or 0
            if ts > lastSeenTimestamp then
                table.insert(newChats, item)
            end
        end

        if #newChats == 0 then continue end

        -- Update timestamp ke yang terbaru
        local newestTs = newChats[#newChats].data.timestamp or 0
        lastSeenTimestamp = newestTs

        -- Tampilkan notif untuk setiap chat baru yang ditujukan ke user ini
        for _, item in ipairs(newChats) do
            local chat = item.data
            local chatId = item.id

            local isFromAdmin = chat.from == "admin"
            local myUid = tostring(LocalPlayer.UserId)
            local isForMe = chat.target == myUid or chat.target == "all"

            if isFromAdmin and isForMe then
                -- Pakai banner dengan tombol balas dari _G (didefinisikan di Phone.lua)
                if _G.showChatNotif then
                    local capturedId = chatId
                    local capturedFrom = chat.fromName or "Admin"
                    local capturedMsg  = chat.message or ""

                    _G.showChatNotif(
                        capturedFrom,
                        capturedMsg,
                        capturedId,
                        nil -- replyCallback opsional
                    )
                else
                    -- Fallback ke Dynamic Island kalau Phone belum load
                    if _G.showDynamicNotification then
                        _G.showDynamicNotification(
                            "💬 " .. (chat.message or ""),
                            C.admin
                        )
                    end
                end
            end
        end
    end
end)

-- ==================== BUKA APP ====================
function _G.openMessageApp()
    -- ===== HEADER =====
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,44)
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 12)
    stroke(header, C.border, 1, 0.3)

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1,-70,0,22)
    hTitle.Position = UDim2.new(0,12,0,4)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "💬 Messages"
    hTitle.TextColor3 = C.text
    hTitle.Font = Enum.Font.GothamBlack
    hTitle.TextSize = 13
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hSub = Instance.new("TextLabel", header)
    hSub.Size = UDim2.new(1,-70,0,14)
    hSub.Position = UDim2.new(0,12,0,26)
    hSub.BackgroundTransparency = 1
    hSub.Text = "Chat dengan Admin via Website"
    hSub.TextColor3 = C.text3
    hSub.Font = Enum.Font.Gotham
    hSub.TextSize = 9
    hSub.TextXAlignment = Enum.TextXAlignment.Left

    -- Badge status koneksi (fitur baru: kelihatan apakah Firebase nyambung)
    local connBadge = Instance.new("Frame", header)
    connBadge.Size = UDim2.new(0,50,0,20)
    connBadge.Position = UDim2.new(1,-60,0.5,-10)
    connBadge.BackgroundColor3 = (Firebase and Firebase.GetData) and C.green or C.admin
    connBadge.BackgroundTransparency = 0.85
    corner(connBadge, 8)

    local connDot = Instance.new("Frame", connBadge)
    connDot.Size = UDim2.new(0,6,0,6)
    connDot.Position = UDim2.new(0,8,0.5,-3)
    connDot.BackgroundColor3 = (Firebase and Firebase.GetData) and C.green or C.admin
    corner(connDot, 100)

    local connLbl = Instance.new("TextLabel", connBadge)
    connLbl.Size = UDim2.new(1,-18,1,0)
    connLbl.Position = UDim2.new(0,18,0,0)
    connLbl.BackgroundTransparency = 1
    connLbl.Text = (Firebase and Firebase.GetData) and "Live" or "Off"
    connLbl.TextColor3 = (Firebase and Firebase.GetData) and C.green or C.admin
    connLbl.Font = Enum.Font.GothamBold
    connLbl.TextSize = 8
    connLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- ===== CHAT LIST =====
    local chatScroll = Instance.new("ScrollingFrame", appContent)
    chatScroll.Size = UDim2.new(1,0,0,260)
    chatScroll.BackgroundColor3 = C.bg
    chatScroll.BorderSizePixel = 0
    chatScroll.CanvasSize = UDim2.new(0,0,0,0)
    chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatScroll.ScrollBarThickness = 3
    chatScroll.LayoutOrder = 1
    corner(chatScroll, 12)
    stroke(chatScroll, C.border, 1, 0.3)

    local chatLayout = Instance.new("UIListLayout", chatScroll)
    chatLayout.Padding = UDim.new(0,6)
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local chatPad = Instance.new("UIPadding", chatScroll)
    chatPad.PaddingTop    = UDim.new(0,8)
    chatPad.PaddingBottom = UDim.new(0,8)
    chatPad.PaddingLeft   = UDim.new(0,8)
    chatPad.PaddingRight  = UDim.new(0,8)

    -- ===== REPLY PREVIEW BAR =====
    local replyingTo = nil -- {id, fromName, message}

    local replyBar = Instance.new("Frame", appContent)
    replyBar.Size = UDim2.new(1,0,0,32)
    replyBar.BackgroundColor3 = Color3.fromRGB(235,235,245)
    replyBar.BorderSizePixel = 0
    replyBar.Visible = false
    replyBar.LayoutOrder = 2
    corner(replyBar, 8)
    stroke(replyBar, C.accent, 1, 0.5)

    local replyAccent = Instance.new("Frame", replyBar)
    replyAccent.Size = UDim2.new(0,3,1,-8)
    replyAccent.Position = UDim2.new(0,6,0,4)
    replyAccent.BackgroundColor3 = C.accent
    corner(replyAccent, 2)

    local replyLbl = Instance.new("TextLabel", replyBar)
    replyLbl.Size = UDim2.new(1,-50,0,28)
    replyLbl.Position = UDim2.new(0,14,0,2)
    replyLbl.BackgroundTransparency = 1
    replyLbl.Text = "Membalas..."
    replyLbl.TextColor3 = C.accent
    replyLbl.Font = Enum.Font.GothamBold
    replyLbl.TextSize = 9
    replyLbl.TextTruncate = Enum.TextTruncate.AtEnd
    replyLbl.TextXAlignment = Enum.TextXAlignment.Left

    local cancelReplyBtn = Instance.new("TextButton", replyBar)
    cancelReplyBtn.Size = UDim2.new(0,24,0,24)
    cancelReplyBtn.Position = UDim2.new(1,-30,0.5,-12)
    cancelReplyBtn.BackgroundTransparency = 1
    cancelReplyBtn.Text = "✕"
    cancelReplyBtn.TextColor3 = C.text2
    cancelReplyBtn.Font = Enum.Font.GothamBold
    cancelReplyBtn.TextSize = 12
    cancelReplyBtn.MouseButton1Click:Connect(function()
        replyingTo = nil
        replyBar.Visible = false
    end)

    -- ===== INPUT AREA =====
    local inputArea = Instance.new("Frame", appContent)
    inputArea.Size = UDim2.new(1,0,0,44)
    inputArea.BackgroundColor3 = C.card
    inputArea.LayoutOrder = 3
    corner(inputArea, 12)
    stroke(inputArea, C.border, 1, 0.3)

    local inputBox = Instance.new("TextBox", inputArea)
    inputBox.Size = UDim2.new(1,-54,0,34)
    inputBox.Position = UDim2.new(0,8,0.5,-17)
    inputBox.BackgroundColor3 = C.bg
    inputBox.PlaceholderText = "Ketik pesan ke Admin..."
    inputBox.PlaceholderColor3 = C.text3
    inputBox.Text = ""
    inputBox.TextColor3 = C.text
    inputBox.Font = Enum.Font.Gotham
    inputBox.TextSize = 11
    inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false
    corner(inputBox, 8)
    local ip = Instance.new("UIPadding", inputBox)
    ip.PaddingLeft = UDim.new(0,8)

    local sendBtn = Instance.new("TextButton", inputArea)
    sendBtn.Size = UDim2.new(0,36,0,36)
    sendBtn.Position = UDim2.new(1,-42,0.5,-18)
    sendBtn.BackgroundColor3 = C.accent
    sendBtn.Text = "➤"
    sendBtn.TextColor3 = Color3.new(1,1,1)
    sendBtn.Font = Enum.Font.GothamBlack
    sendBtn.TextSize = 16
    sendBtn.AutoButtonColor = false
    corner(sendBtn, 100)
    pressFX(sendBtn)

    -- ===== RENDER CHAT =====
    local function renderBubble(chatId, chatInfo, order)
        if not chatInfo or type(chatInfo) ~= "table" then return end
        local isAdmin = chatInfo.from == "admin"
        local myUid   = tostring(LocalPlayer.UserId)
        local isMe    = tostring(chatInfo.fromUserId or "") == myUid

        local wrap = Instance.new("Frame", chatScroll)
        wrap.Size = UDim2.new(1,0,0,0)
        wrap.AutomaticSize = Enum.AutomaticSize.Y
        wrap.BackgroundTransparency = 1
        wrap.LayoutOrder = order

        local bubble = Instance.new("TextButton", wrap)
        bubble.AutomaticSize = Enum.AutomaticSize.Y
        bubble.Size = UDim2.new(0,220,0,0)
        bubble.AnchorPoint = isMe and Vector2.new(1,0) or Vector2.new(0,0)
        bubble.Position = isMe and UDim2.new(1,0,0,0) or UDim2.new(0,0,0,0)
        bubble.BackgroundColor3 = isAdmin and Color3.fromRGB(240,240,255)
                                  or (isMe  and Color3.fromRGB(0,150,255)
                                            or Color3.fromRGB(240,240,240))
        bubble.AutoButtonColor = false
        bubble.Text = ""
        corner(bubble, 14)

        local bpad = Instance.new("UIPadding", bubble)
        bpad.PaddingTop    = UDim.new(0,8)
        bpad.PaddingBottom = UDim.new(0,6)
        bpad.PaddingLeft   = UDim.new(0,10)
        bpad.PaddingRight  = UDim.new(0,10)

        local blay = Instance.new("UIListLayout", bubble)
        blay.Padding = UDim.new(0,3)
        blay.SortOrder = Enum.SortOrder.LayoutOrder

        -- Nama pengirim
        local nameLbl = Instance.new("TextLabel", bubble)
        nameLbl.Size = UDim2.new(1,0,0,14)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = isAdmin and "Admin"
                       or (chatInfo.fromName or LocalPlayer.DisplayName)
        nameLbl.TextColor3 = isAdmin and C.admin
                             or (isMe and Color3.fromRGB(200,235,255)
                                     or C.text2)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 9
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.LayoutOrder = 0

        -- Reply preview
        if chatInfo.replyTo then
            local rbox = Instance.new("Frame", bubble)
            rbox.Size = UDim2.new(1,0,0,28)
            rbox.BackgroundColor3 = Color3.new(0,0,0)
            rbox.BackgroundTransparency = 0.75
            rbox.LayoutOrder = 1
            corner(rbox, 6)

            local racc = Instance.new("Frame", rbox)
            racc.Size = UDim2.new(0,3,1,-6)
            racc.Position = UDim2.new(0,4,0,3)
            racc.BackgroundColor3 = C.admin
            corner(racc, 2)

            local rlbl = Instance.new("TextLabel", rbox)
            rlbl.Size = UDim2.new(1,-14,1,0)
            rlbl.Position = UDim2.new(0,10,0,0)
            rlbl.BackgroundTransparency = 1
            rlbl.Text = "↩ " .. (chatInfo.replyToName or "")
            rlbl.TextColor3 = Color3.fromRGB(180,180,200)
            rlbl.Font = Enum.Font.Gotham
            rlbl.TextSize = 8
            rlbl.TextTruncate = Enum.TextTruncate.AtEnd
            rlbl.TextXAlignment = Enum.TextXAlignment.Left
        end

        -- Isi pesan
        local msgLbl = Instance.new("TextLabel", bubble)
        msgLbl.Size = UDim2.new(1,0,0,0)
        msgLbl.AutomaticSize = Enum.AutomaticSize.Y
        msgLbl.BackgroundTransparency = 1
        msgLbl.Text = chatInfo.message or ""
        msgLbl.TextColor3 = isMe and Color3.new(1,1,1) or C.text
        msgLbl.Font = Enum.Font.Gotham
        msgLbl.TextSize = 11
        msgLbl.TextWrapped = true
        msgLbl.TextXAlignment = Enum.TextXAlignment.Left
        msgLbl.LayoutOrder = chatInfo.replyTo and 2 or 1

        -- Waktu
        local timeLbl = Instance.new("TextLabel", bubble)
        timeLbl.Size = UDim2.new(1,0,0,12)
        timeLbl.BackgroundTransparency = 1
        local ts = chatInfo.timestamp or 0
        timeLbl.Text = ts > 0 and os.date("%H:%M", ts) or ""
        timeLbl.TextColor3 = isMe and Color3.fromRGB(200,230,255) or C.text3
        timeLbl.Font = Enum.Font.Gotham
        timeLbl.TextSize = 8
        timeLbl.TextXAlignment = Enum.TextXAlignment.Right
        timeLbl.LayoutOrder = 99

        -- Tap bubble → set reply
        if isAdmin then
            bubble.MouseButton1Click:Connect(function()
                replyingTo = {id = chatId, fromName = "Admin", message = chatInfo.message or ""}
                replyLbl.Text = "↩ Membalas Admin: " ..
                    (#(chatInfo.message or "") > 30 and chatInfo.message:sub(1,30).."..." or (chatInfo.message or ""))
                replyBar.Visible = true
            end)
        end

        return wrap
    end

    local function loadChats()
        -- Hapus bubble lama
        for _, c in ipairs(chatScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end

        if not Firebase or not Firebase.GetData then
            local e = Instance.new("TextLabel", chatScroll)
            e.Size = UDim2.new(1,0,0,40)
            e.BackgroundTransparency = 1
            e.Text = "Firebase tidak tersedia"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 10
            e.LayoutOrder = 0
            return
        end

        local ok, chatData = pcall(function() return Firebase.GetData("chat") end)
        if not ok or not chatData or type(chatData) ~= "table" then
            local e = Instance.new("TextLabel", chatScroll)
            e.Size = UDim2.new(1,0,0,40)
            e.BackgroundTransparency = 1
            e.Text = "Belum ada pesan"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 10
            e.LayoutOrder = 0
            return
        end

        local myUid = tostring(LocalPlayer.UserId)
        local sorted = {}
        for chatId, chatInfo in pairs(chatData) do
            if type(chatInfo) == "table" then
                -- Filter: tampilkan pesan yang melibatkan user ini
                local isForMe = chatInfo.target == myUid or chatInfo.target == "all"
                local isFromMe = tostring(chatInfo.fromUserId or "") == myUid
                if isForMe or isFromMe then
                    table.insert(sorted, {id=chatId, data=chatInfo})
                end
            end
        end
        table.sort(sorted, function(a,b)
            return (a.data.timestamp or 0) < (b.data.timestamp or 0)
        end)

        for i, item in ipairs(sorted) do
            renderBubble(item.id, item.data, i)
        end

        -- Auto-scroll ke bawah
        task.defer(function()
            pcall(function()
                chatScroll.CanvasPosition = Vector2.new(
                    0,
                    math.max(0, chatScroll.AbsoluteCanvasSize.Y - chatScroll.AbsoluteWindowSize.Y)
                )
            end)
        end)
    end

    -- Load pertama
    task.spawn(loadChats)

    -- Refresh button
    local refreshBtn = Instance.new("TextButton", appContent)
    refreshBtn.Size = UDim2.new(1,0,0,34)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(240,240,250)
    refreshBtn.Text = "🔄  Refresh"
    refreshBtn.TextColor3 = C.text2
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 11
    refreshBtn.AutoButtonColor = false
    refreshBtn.LayoutOrder = 4
    corner(refreshBtn, 10)
    stroke(refreshBtn, C.border, 1, 0.3)
    pressFX(refreshBtn)
    refreshBtn.MouseButton1Click:Connect(function()
        task.spawn(loadChats)
    end)

    -- ===== KIRIM PESAN =====
    local function doSend()
        local txt = inputBox.Text
        if txt == "" or txt:match("^%s*$") then return end
        inputBox.Text = ""

        if not Firebase or not Firebase.SendChat then
            _G.showDynamicNotification("Firebase tidak tersedia", C.admin)
            return
        end

        local replyId   = replyingTo and replyingTo.id      or nil
        local replyFrom = replyingTo and replyingTo.fromName or nil
        replyingTo  = nil
        replyBar.Visible = false

        local ok = pcall(function()
            Firebase.SendChat(
                LocalPlayer.UserId,
                LocalPlayer.DisplayName,
                LocalPlayer.Name,
                txt,
                replyId,
                replyFrom
            )
        end)

        if ok then
            _G.showDynamicNotification("Pesan terkirim!", C.green)
            task.wait(0.5)
            task.spawn(loadChats)
        else
            _G.showDynamicNotification("Gagal kirim pesan", C.admin)
        end
    end

    sendBtn.MouseButton1Click:Connect(doSend)
    inputBox.FocusLost:Connect(function(enter) if enter then doSend() end end)
end

print("[Messages] Loaded!")
