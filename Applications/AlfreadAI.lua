-- ================================================
-- ALFREADAI.LUA — Asisten AI "Alfread AI" (Groq)
-- Paham seluruh fitur AvatarClone: Premium, Messages, Settings,
-- sistem Key, dan dashboard website. Bisa menjelaskan cara pakai
-- tiap fitur ke pengguna secara akurat.
-- ================================================

local Services    = _G.Services
local LocalPlayer = _G.LocalPlayer
local T           = _G.T or {}
local Helpers     = _G.Helpers or {}
local appContent  = _G.appContent
local Config      = _G.Config or {}
local HttpService = game:GetService("HttpService")

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local pressFX = Helpers.pressFX

-- ==================== KONFIGURASI GROQ ====================
-- GANTI dengan API key Groq milik kamu sendiri (jangan share/commit ke publik).
local GROQ_API_KEY = "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"
local GROQ_MODEL   = "llama-3.3-70b-versatile"
local GROQ_URL     = "https://api.groq.com/openai/v1/chat/completions"

local C = {
    bg      = Color3.fromRGB(10, 10, 16),
    card    = Color3.fromRGB(20, 18, 30),
    aiBub   = Color3.fromRGB(26, 22, 40),
    userBub = Color3.fromRGB(90, 80, 220),
    border  = Color3.fromRGB(54, 46, 80),
    text    = Color3.fromRGB(240, 238, 250),
    text2   = Color3.fromRGB(165, 158, 190),
    text3   = Color3.fromRGB(100, 94, 130),
    accent  = Color3.fromRGB(130, 120, 255),
    accent2 = Color3.fromRGB(80, 200, 255),
    green   = Color3.fromRGB(90, 230, 160),
}

-- ==================== SYSTEM PROMPT: PENGETAHUAN ALFREAD AI ====================
-- Ini yang bikin AI paham semua fitur AvatarClone. Kalau kamu menambah app baru
-- di masa depan, tambahkan juga dokumentasinya di sini supaya AI tetap akurat.
local SYSTEM_PROMPT = [[
Kamu adalah "Alfread AI", asisten virtual resmi di dalam script Roblox bernama AvatarClone / PhoneIDViewer, dibuat oleh developer bernama Alfread (username Roblox: ]] .. (Config.DEVELOPER_USERNAME or "AlfreadR0rw") .. [[).

Kepribadianmu: ramah, santai tapi jelas, jawab dalam Bahasa Indonesia casual kecuali user menulis dalam bahasa lain. Jawaban ringkas, tidak bertele-tele, langsung ke inti — tapi tetap lengkap kalau user minta penjelasan detail.

Kamu HARUS mengerti dan bisa menjelaskan fitur-fitur berikut kepada user dengan akurat:

## STRUKTUR APLIKASI
AvatarClone adalah UI gaya smartphone di dalam Roblox. User membuka "Phone" lalu memasukkan KEY untuk membuka semua fitur. Setelah key valid, muncul homescreen dengan icon-icon app yang bisa dibuka.

## SISTEM KEY (WAJIB DIJELASKAN KALAU DITANYA)
- Ada 4 jenis key: 3 Hari, 7 Hari, 30 Hari, dan Permanen (khusus, tidak pernah expired).
- Key didapat dari admin/developer lewat pembelian (link ada di Settings > Buy Key).
- Cara pakai: buka Phone, akan muncul layar "Masukkan Key", ketik kode key (format seperti CBK-XXXX-XXXX atau PERM-XXXX untuk permanen), tekan Unlock.
- Key hanya bisa dipakai OLEH SATU AKUN saja (terikat ke UserId pertama yang memasukkannya). Kalau key sudah dipakai orang lain, tidak bisa dipakai ulang.
- Kalau user sudah pernah memasukkan key valid sebelumnya dan belum expired, saat buka Phone lagi otomatis langsung masuk tanpa perlu ketik key lagi (auto-login).
- User bisa cek sisa waktu key nya di app Settings, ada timer countdown real-time dan progress bar.

## DAFTAR APP DI HOMESCREEN
1. **Players** — melihat daftar pemain di server, cari berdasarkan nama.
2. **Clone** — fitur cloning avatar.
3. **Messages** — chat dua arah dengan Admin. Pesan yang dikirim di sini masuk ke Dashboard Admin di website, dan admin bisa balas dari sana, balasannya muncul sebagai notifikasi di HP (bisa langsung dibalas dari notifikasi itu juga, tidak perlu buka app dulu).
4. **Settings** — lihat status key (aktif/expired, sisa waktu, jenis paket), profil developer, link social media (Discord/WhatsApp/Telegram), tombol aksi cepat (rejoin server, copy User ID, beli key, hapus key lokal).
5. **Premium** (👑) — KHUSUS pemilik Key Permanen atau Developer. Kalau user biasa (key 3/7/30 hari) mencoba buka, akan muncul pesan "Akses Premium Diperlukan". Fitur di dalamnya: melihat semua pemain yang online lintas server (tidak harus di map yang sama), tombol "TP ke Aku" untuk menarik pemain lain ke lokasi Developer, dan "TP-on-Tap" yaitu mode dimana Developer bisa tap dimana saja di layarnya dan pemain target otomatis dipindahkan ke titik itu, walau berbeda server sekalipun.
6. **Alfread AI** (aku sendiri!) — chat AI ini, bisa ditanya apa saja termasuk soal fitur-fitur script ini.

## DASHBOARD ADMIN (WEBSITE)
Developer/admin punya dashboard website terpisah untuk:
- Generate key baru (pilih durasi 3/7/30 hari atau Permanen, bisa generate banyak sekaligus).
- Melihat semua key yang pernah dibuat, siapa pemiliknya, status aktif/expired, sisa waktu real-time.
- Melihat daftar pemain yang sedang online.
- Chat dua arah dengan pemain (mode "Chat App" masuk ke app Messages di HP pemain, atau mode "Broadcast In-Game" yang memunculkan pesan sebagai balon chat di atas kepala karakter pemain, terlihat oleh semua orang di sekitarnya).
- Kirim notifikasi ke pemain tertentu atau semua pemain sekaligus.
- Fitur Teleport: pilih pemain online, lalu teleport ke lokasi preset tersimpan atau ke koordinat X,Y,Z manual.
- Dashboard bisa di-install sebagai aplikasi (PWA) di HP admin, tidak perlu buka browser terus-menerus.

## ATURAN PENTING SAAT MENJAWAB
- Kalau user bertanya soal cara pakai fitur, jelaskan LANGKAH-LANGKAHNYA secara berurutan dan jelas.
- Kalau user bertanya soal fitur Premium tapi dia sepertinya bukan pemilik key permanen, jelaskan bahwa fitur itu eksklusif dan sarankan hubungi admin untuk upgrade.
- Jangan mengarang fitur yang tidak ada di daftar di atas. Kalau ditanya sesuatu yang di luar pengetahuanmu tentang script ini, jawab jujur bahwa kamu tidak yakin dan sarankan tanya langsung ke Developer/Admin lewat app Messages.
- Kamu BUKAN bagian dari sistem pembayaran — kalau user tanya soal harga/pembayaran key, arahkan mereka untuk cek Settings > Buy Key atau hubungi admin.
- Jangan pernah berpura-pura bisa melakukan aksi di dalam game (seperti benar-benar men-teleport atau memberi item) — kamu hanya asisten chat yang menjelaskan, bukan yang mengeksekusi.
]]

-- ==================== STATE ====================
local chatHistory = {} -- {role, content}
local isTyping = false
local chatScrollRef = nil

-- ==================== HTTP REQUEST KE GROQ ====================
local function callGroqAPI(messages, callback)
    local payload = {
        model = GROQ_MODEL,
        messages = messages,
        temperature = 0.7,
        max_tokens = 1024,
    }

    task.spawn(function()
        local ok, result = pcall(function()
            local opts = {
                Url = GROQ_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"]  = "application/json",
                    ["Authorization"] = "Bearer " .. GROQ_API_KEY,
                },
                Body = HttpService:JSONEncode(payload),
            }
            if syn and syn.request then return syn.request(opts)
            elseif http_request then return http_request(opts)
            elseif request then return request(opts)
            else return HttpService:RequestAsync(opts) end
        end)

        if not ok or not result then
            callback(false, "Gagal terhubung ke server AI. Cek koneksi internet kamu.")
            return
        end

        local success = result.Success or (result.StatusCode and result.StatusCode < 300)
        if not success then
            local status = result.StatusCode or "?"
            local msg = "Server AI merespons error (kode " .. tostring(status) .. ")."
            if status == 401 then msg = "API key tidak valid. Hubungi developer untuk perbaikan." end
            if status == 429 then msg = "Terlalu banyak permintaan sekaligus, coba lagi sebentar." end
            callback(false, msg)
            return
        end

        local dok, data = pcall(function()
            return HttpService:JSONDecode(result.Body or result.body or "")
        end)

        if not dok or not data or not data.choices or not data.choices[1] then
            callback(false, "Respons AI tidak bisa dibaca.")
            return
        end

        local reply = data.choices[1].message and data.choices[1].message.content
        if not reply then
            callback(false, "AI tidak memberikan balasan.")
            return
        end

        callback(true, reply)
    end)
end

-- ==================== RENDER BUBBLE ====================
local function renderChatBubble(parent, msg, order)
    local isUser = msg.role == "user"

    local wrap = Instance.new("Frame", parent)
    wrap.Size = UDim2.new(1,0,0,0)
    wrap.AutomaticSize = Enum.AutomaticSize.Y
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order

    local bubble = Instance.new("Frame", wrap)
    bubble.AutomaticSize = Enum.AutomaticSize.Y
    bubble.Size = UDim2.new(0, 240, 0, 0)
    bubble.AnchorPoint = isUser and Vector2.new(1,0) or Vector2.new(0,0)
    bubble.Position = isUser and UDim2.new(1,0,0,0) or UDim2.new(0,0,0,0)
    bubble.BackgroundColor3 = isUser and C.userBub or C.aiBub
    corner(bubble, 14)
    if not isUser then stroke(bubble, C.border, 1, 0.4) end

    local pad = Instance.new("UIPadding", bubble)
    pad.PaddingTop = UDim.new(0,8); pad.PaddingBottom = UDim.new(0,8)
    pad.PaddingLeft = UDim.new(0,11); pad.PaddingRight = UDim.new(0,11)

    local lay = Instance.new("UIListLayout", bubble)
    lay.Padding = UDim.new(0,3)

    if not isUser then
        local tag = Instance.new("TextLabel", bubble)
        tag.Size = UDim2.new(1,0,0,13)
        tag.BackgroundTransparency = 1
        tag.Text = "✨ Alfread AI"
        tag.TextColor3 = C.accent2
        tag.Font = Enum.Font.GothamBlack
        tag.TextSize = 9
        tag.TextXAlignment = Enum.TextXAlignment.Left
        tag.LayoutOrder = 0
    end

    local textLbl = Instance.new("TextLabel", bubble)
    textLbl.Size = UDim2.new(1,0,0,0)
    textLbl.AutomaticSize = Enum.AutomaticSize.Y
    textLbl.BackgroundTransparency = 1
    textLbl.Text = msg.content
    textLbl.TextColor3 = C.text
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextSize = 12
    textLbl.TextWrapped = true
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.LayoutOrder = 1

    return wrap
end

local function renderTypingBubble(parent, order)
    local wrap = Instance.new("Frame", parent)
    wrap.Name = "TypingBubble"
    wrap.Size = UDim2.new(1,0,0,0)
    wrap.AutomaticSize = Enum.AutomaticSize.Y
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order

    local bubble = Instance.new("Frame", wrap)
    bubble.Size = UDim2.new(0, 60, 0, 32)
    bubble.BackgroundColor3 = C.aiBub
    corner(bubble, 14)
    stroke(bubble, C.border, 1, 0.4)

    local dotsRow = Instance.new("Frame", bubble)
    dotsRow.Size = UDim2.new(0, 34, 0, 8)
    dotsRow.Position = UDim2.new(0.5, -17, 0.5, -4)
    dotsRow.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout", dotsRow)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 4)

    for i = 1, 3 do
        local dot = Instance.new("Frame", dotsRow)
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.BackgroundColor3 = C.accent2
        corner(dot, 100)

        task.spawn(function()
            while dot.Parent do
                for _, t in ipairs({0.3, 1, 0.3}) do
                    if not dot.Parent then break end
                    game:GetService("TweenService"):Create(
                        dot, TweenInfo.new(0.35), {BackgroundTransparency = t}
                    ):Play()
                    task.wait(0.35)
                end
                task.wait(i * 0.1)
            end
        end)
    end

    return wrap
end

-- ==================== BUKA APP ====================
function _G.openAlfreadAIApp()
    -- ===== HEADER =====
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,50)
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 12)
    stroke(header, C.accent, 1, 0.5)

    local grad = Instance.new("UIGradient", header)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accent2),
    })
    grad.Transparency = NumberSequence.new(0.88)
    grad.Rotation = 20

    local avatarFrame = Instance.new("Frame", header)
    avatarFrame.Size = UDim2.new(0,34,0,34)
    avatarFrame.Position = UDim2.new(0,8,0.5,-17)
    avatarFrame.BackgroundColor3 = C.accent
    corner(avatarFrame, 100)
    local avatarGrad = Instance.new("UIGradient", avatarFrame)
    avatarGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accent2),
    })

    local avatarIcon = Instance.new("TextLabel", avatarFrame)
    avatarIcon.Size = UDim2.new(1,0,1,0)
    avatarIcon.BackgroundTransparency = 1
    avatarIcon.Text = "✨"
    avatarIcon.TextSize = 16

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1,-130,0,20)
    hTitle.Position = UDim2.new(0,50,0,6)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "Alfread AI"
    hTitle.TextColor3 = C.text
    hTitle.Font = Enum.Font.GothamBlack
    hTitle.TextSize = 14
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hSub = Instance.new("TextLabel", header)
    hSub.Size = UDim2.new(1,-130,0,14)
    hSub.Position = UDim2.new(0,50,0,26)
    hSub.BackgroundTransparency = 1
    hSub.Text = "🟢 Online · Paham semua fitur AvatarClone"
    hSub.TextColor3 = C.green
    hSub.Font = Enum.Font.Gotham
    hSub.TextSize = 9
    hSub.TextXAlignment = Enum.TextXAlignment.Left

    local clearBtn = Instance.new("TextButton", header)
    clearBtn.Size = UDim2.new(0,60,0,26)
    clearBtn.Position = UDim2.new(1,-68,0.5,-13)
    clearBtn.BackgroundColor3 = Color3.fromRGB(255,90,100)
    clearBtn.BackgroundTransparency = 0.85
    clearBtn.Text = "🗑 Clear"
    clearBtn.TextColor3 = Color3.fromRGB(255,90,100)
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 9
    clearBtn.AutoButtonColor = false
    corner(clearBtn, 8)
    pressFX(clearBtn)

    -- ===== QUICK PROMPT CHIPS =====
    local quickSec = Instance.new("Frame", appContent)
    quickSec.Size = UDim2.new(1,0,0,30)
    quickSec.BackgroundTransparency = 1
    quickSec.LayoutOrder = 1

    local quickScroll = Instance.new("ScrollingFrame", quickSec)
    quickScroll.Size = UDim2.new(1,0,1,0)
    quickScroll.BackgroundTransparency = 1
    quickScroll.ScrollBarThickness = 0
    quickScroll.ScrollingDirection = Enum.ScrollingDirection.X
    quickScroll.CanvasSize = UDim2.new(0,0,0,0)
    quickScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local quickLayout = Instance.new("UIListLayout", quickScroll)
    quickLayout.FillDirection = Enum.FillDirection.Horizontal
    quickLayout.Padding = UDim.new(0,6)

    local QUICK_PROMPTS = {
        "Cara pakai key gimana?",
        "Fitur Premium itu apa?",
        "Cara buka Settings?",
        "Fitur Messages buat apa?",
    }

    -- ===== CHAT SCROLL =====
    local chatScroll = Instance.new("ScrollingFrame", appContent)
    chatScroll.Size = UDim2.new(1,0,0,300)
    chatScroll.BackgroundColor3 = C.bg
    chatScroll.BorderSizePixel = 0
    chatScroll.CanvasSize = UDim2.new(0,0,0,0)
    chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    chatScroll.ScrollBarThickness = 3
    chatScroll.LayoutOrder = 2
    corner(chatScroll, 12)
    stroke(chatScroll, C.border, 1, 0.3)
    chatScrollRef = chatScroll

    local chatLayout = Instance.new("UIListLayout", chatScroll)
    chatLayout.Padding = UDim.new(0,8)
    chatLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local chatPad = Instance.new("UIPadding", chatScroll)
    chatPad.PaddingTop = UDim.new(0,10); chatPad.PaddingBottom = UDim.new(0,10)
    chatPad.PaddingLeft = UDim.new(0,10); chatPad.PaddingRight = UDim.new(0,10)

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
    inputBox.PlaceholderText = "Tanya apa saja ke Alfread AI..."
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

    -- ===== RENDER SEMUA HISTORY =====
    local function renderAllHistory()
        for _, c in ipairs(chatScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end

        if #chatHistory == 0 then
            local welcome = Instance.new("TextLabel", chatScroll)
            welcome.Size = UDim2.new(1,0,0,60)
            welcome.BackgroundTransparency = 1
            welcome.Text = "✨ Halo! Aku Alfread AI.\nTanya aku apa saja soal script AvatarClone ini, atau ngobrol santai aja!"
            welcome.TextColor3 = C.text3
            welcome.Font = Enum.Font.Gotham
            welcome.TextSize = 11
            welcome.TextWrapped = true
            welcome.LayoutOrder = 0
        else
            for i, msg in ipairs(chatHistory) do
                renderChatBubble(chatScroll, msg, i)
            end
        end

        task.defer(function()
            pcall(function()
                chatScroll.CanvasPosition = Vector2.new(
                    0, math.max(0, chatScroll.AbsoluteCanvasSize.Y - chatScroll.AbsoluteWindowSize.Y)
                )
            end)
        end)
    end

    for _, prompt in ipairs(QUICK_PROMPTS) do
        local chip = Instance.new("TextButton", quickScroll)
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = C.card
        chip.Text = ""
        chip.AutoButtonColor = false
        corner(chip, 100)
        stroke(chip, C.border, 1, 0.3)
        pressFX(chip)

        local chipPad = Instance.new("UIPadding", chip)
        chipPad.PaddingLeft = UDim.new(0,12); chipPad.PaddingRight = UDim.new(0,12)

        local chipLbl = Instance.new("TextLabel", chip)
        chipLbl.Size = UDim2.new(0,0,1,0)
        chipLbl.AutomaticSize = Enum.AutomaticSize.X
        chipLbl.BackgroundTransparency = 1
        chipLbl.Text = prompt
        chipLbl.TextColor3 = C.text2
        chipLbl.Font = Enum.Font.GothamBold
        chipLbl.TextSize = 9

        chip.MouseButton1Click:Connect(function()
            inputBox.Text = prompt
        end)
    end

    -- ===== KIRIM PESAN =====
    local function doSend()
        if isTyping then return end
        local txt = inputBox.Text
        if txt == "" or txt:match("^%s*$") then return end
        inputBox.Text = ""

        table.insert(chatHistory, {role="user", content=txt})
        renderAllHistory()

        isTyping = true
        local typingBubble = renderTypingBubble(chatScroll, #chatHistory + 1)
        task.defer(function()
            pcall(function()
                chatScroll.CanvasPosition = Vector2.new(
                    0, math.max(0, chatScroll.AbsoluteCanvasSize.Y - chatScroll.AbsoluteWindowSize.Y)
                )
            end)
        end)

        -- Susun messages array untuk Groq: system prompt + history percakapan
        local apiMessages = {{role="system", content=SYSTEM_PROMPT}}
        for _, m in ipairs(chatHistory) do
            table.insert(apiMessages, {role=m.role, content=m.content})
        end

        callGroqAPI(apiMessages, function(success, reply)
            isTyping = false
            pcall(function() typingBubble:Destroy() end)

            if success then
                table.insert(chatHistory, {role="assistant", content=reply})
            else
                table.insert(chatHistory, {role="assistant", content="⚠️ " .. reply})
            end
            renderAllHistory()
        end)
    end

    sendBtn.MouseButton1Click:Connect(doSend)
    inputBox.FocusLost:Connect(function(enter) if enter then doSend() end end)
    clearBtn.MouseButton1Click:Connect(function()
        chatHistory = {}
        renderAllHistory()
        if _G.showDynamicNotification then
            _G.showDynamicNotification("Riwayat chat dihapus", C.accent2)
        end
    end)

    renderAllHistory()
end

print("[Alfread AI] Loaded! Siap menjawab pertanyaan seputar AvatarClone.")