-- ================================================
-- GAMES.LUA — Mini Games (Single Player + Multiplayer via Firebase)
-- ================================================
-- Tab Single Player: Snake, 2048, Flappy-style
-- Tab Multiplayer: Tic-Tac-Toe turn-based via Firebase (challenge teman online)
-- ================================================

local Services    = _G.Services
local LocalPlayer = _G.LocalPlayer
local Players     = Services.Players
local Helpers     = _G.Helpers or {}
local Firebase    = _G.Firebase
local appContent  = _G.appContent
local UserInputService = Services.UserInputService
local TweenService = game:GetService("TweenService")

local corner  = Helpers.corner
local stroke  = Helpers.stroke
local pressFX = Helpers.pressFX

local C = {
    bg      = Color3.fromRGB(12, 12, 18),
    card    = Color3.fromRGB(20, 20, 28),
    card2   = Color3.fromRGB(28, 28, 38),
    border  = Color3.fromRGB(48, 48, 62),
    text    = Color3.fromRGB(240, 240, 250),
    text2   = Color3.fromRGB(155, 155, 172),
    text3   = Color3.fromRGB(95, 95, 112),
    accent  = Color3.fromRGB(100, 200, 130), -- hijau khas snake/game
    accent2 = Color3.fromRGB(100, 160, 255),
    gold    = Color3.fromRGB(255, 195, 70),
    red     = Color3.fromRGB(255, 95, 105),
}

-- ==================== STATE GLOBAL APP ====================
local currentTab = "single" -- "single" | "multiplayer"
local currentGame = nil     -- nil = menu game list, atau "snake"/"2048"/"flappy"
local gameAreaRef = nil     -- reference ke frame tempat game dirender
local gameLoopConn = nil    -- koneksi loop game aktif (dibersihkan tiap ganti game)
local inputConn = nil       -- koneksi input aktif (dibersihkan tiap ganti game)

-- Bersihkan semua koneksi aktif -- WAJIB dipanggil tiap kali keluar dari game
-- atau ganti game, supaya tidak numpuk banyak loop yang jalan bersamaan
-- (bug memory-leak klasik kalau lupa disconnect).
local function cleanupGameConnections()
    if gameLoopConn then
        pcall(function() gameLoopConn:Disconnect() end)
        gameLoopConn = nil
    end
    if inputConn then
        pcall(function() inputConn:Disconnect() end)
        inputConn = nil
    end
end

-- ==================== HIGH SCORE STORAGE (LOKAL) ====================
local Storage = _G.Storage
local function getHighScore(gameName)
    if Storage and Storage.appSettings then
        Storage.appSettings.highScores = Storage.appSettings.highScores or {}
        return Storage.appSettings.highScores[gameName] or 0
    end
    return 0
end

local function setHighScore(gameName, score)
    if Storage and Storage.appSettings then
        Storage.appSettings.highScores = Storage.appSettings.highScores or {}
        if score > (Storage.appSettings.highScores[gameName] or 0) then
            Storage.appSettings.highScores[gameName] = score
            pcall(function()
                if Storage.persistSettings then Storage.persistSettings() end
            end)
            return true -- new high score
        end
    end
    return false
end

-- ==================== FORWARD DECLARATIONS ====================
local renderGameMenu, renderMultiplayerTab, openGame

-- ================================================================
-- ==================== GAME 1: SNAKE ============================
-- ================================================================
local function runSnakeGame(container)
    local GRID_SIZE = 12       -- grid 12x12
    local CELL_PX = 20         -- ukuran tiap sel dalam pixel
    local TICK_RATE = 0.18     -- kecepatan gerak (detik per langkah)

    local boardFrame = Instance.new("Frame", container)
    boardFrame.Size = UDim2.new(0, GRID_SIZE * CELL_PX, 0, GRID_SIZE * CELL_PX)
    boardFrame.Position = UDim2.new(0.5, -(GRID_SIZE * CELL_PX)/2, 0, 50)
    boardFrame.BackgroundColor3 = C.bg
    corner(boardFrame, 10)
    stroke(boardFrame, C.accent, 2, 0.2)

    -- Skor & status
    local scoreLbl = Instance.new("TextLabel", container)
    scoreLbl.Size = UDim2.new(1,0,0,30)
    scoreLbl.Position = UDim2.new(0,0,0,10)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = "Skor: 0  |  Best: " .. getHighScore("snake")
    scoreLbl.TextColor3 = C.text
    scoreLbl.Font = Enum.Font.GothamBlack
    scoreLbl.TextSize = 14

    -- ===== STATE SNAKE =====
    local snake = { {x=6, y=6}, {x=5, y=6}, {x=4, y=6} } -- head di index 1
    local direction = {x=1, y=0}
    local nextDirection = {x=1, y=0}
    local food = {x=9, y=6}
    local score = 0
    local gameOver = false
    local cellInstances = {} -- cache Frame per sel biar tidak re-create tiap tick

    local function getCell(x, y)
        local key = x .. "," .. y
        if not cellInstances[key] then
            local cell = Instance.new("Frame", boardFrame)
            cell.Size = UDim2.new(0, CELL_PX-1, 0, CELL_PX-1)
            cell.Position = UDim2.new(0, (x-1)*CELL_PX, 0, (y-1)*CELL_PX)
            cell.BackgroundTransparency = 1
            cell.BorderSizePixel = 0
            corner(cell, 3)
            cellInstances[key] = cell
        end
        return cellInstances[key]
    end

    local function randomFood()
        repeat
            food = {x = math.random(1, GRID_SIZE), y = math.random(1, GRID_SIZE)}
            local onSnake = false
            for _, seg in ipairs(snake) do
                if seg.x == food.x and seg.y == food.y then onSnake = true break end
            end
        until not onSnake
    end

    local function render()
        -- Reset semua cell yang sebelumnya kepakai
        for _, cell in pairs(cellInstances) do
            cell.BackgroundTransparency = 1
        end
        -- Gambar ular
        for i, seg in ipairs(snake) do
            local cell = getCell(seg.x, seg.y)
            cell.BackgroundTransparency = 0
            cell.BackgroundColor3 = (i == 1) and C.accent2 or C.accent
        end
        -- Gambar makanan
        local foodCell = getCell(food.x, food.y)
        foodCell.BackgroundTransparency = 0
        foodCell.BackgroundColor3 = C.gold
    end

    local function showGameOver()
        gameOver = true
        cleanupGameConnections()
        local isNewHigh = setHighScore("snake", score)

        local overlay = Instance.new("Frame", container)
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.3
        overlay.ZIndex = 10

        local msg = Instance.new("TextLabel", overlay)
        msg.Size = UDim2.new(1,-40,0,80)
        msg.Position = UDim2.new(0,20,0.4,0)
        msg.BackgroundTransparency = 1
        msg.Text = (isNewHigh and "🏆 REKOR BARU!\n" or "Game Over\n") .. "Skor: " .. score
        msg.TextColor3 = Color3.new(1,1,1)
        msg.Font = Enum.Font.GothamBlack
        msg.TextSize = 20
        msg.ZIndex = 11
        msg.TextWrapped = true

        local retryBtn = Instance.new("TextButton", overlay)
        retryBtn.Size = UDim2.new(0,140,0,40)
        retryBtn.Position = UDim2.new(0.5,-70,0.65,0)
        retryBtn.BackgroundColor3 = C.accent
        retryBtn.Text = "Main Lagi"
        retryBtn.TextColor3 = Color3.new(1,1,1)
        retryBtn.Font = Enum.Font.GothamBlack
        retryBtn.TextSize = 13
        retryBtn.AutoButtonColor = false
        retryBtn.ZIndex = 11
        corner(retryBtn, 10)
        pressFX(retryBtn)
        retryBtn.MouseButton1Click:Connect(function()
            openGame("snake")
        end)
    end

    local function tick()
        if gameOver then return end
        direction = nextDirection

        local head = snake[1]
        local newHead = {x = head.x + direction.x, y = head.y + direction.y}

        -- Cek tabrak dinding
        if newHead.x < 1 or newHead.x > GRID_SIZE or newHead.y < 1 or newHead.y > GRID_SIZE then
            showGameOver()
            return
        end
        -- Cek tabrak badan sendiri
        for _, seg in ipairs(snake) do
            if seg.x == newHead.x and seg.y == newHead.y then
                showGameOver()
                return
            end
        end

        table.insert(snake, 1, newHead)

        if newHead.x == food.x and newHead.y == food.y then
            score = score + 10
            scoreLbl.Text = "Skor: " .. score .. "  |  Best: " .. math.max(getHighScore("snake"), score)
            randomFood()
        else
            table.remove(snake) -- hapus ekor kalau tidak makan
        end

        render()
    end

    -- ===== INPUT: SWIPE/TAP KONTROL =====
    -- Karena ini di dalam UI phone-mockup (bukan game 3D), kontrol dibuat
    -- lewat 4 tombol arah on-screen -- paling reliable untuk semua device.
    local dpad = Instance.new("Frame", container)
    dpad.Size = UDim2.new(0, 140, 0, 140)
    dpad.Position = UDim2.new(0.5, -70, 0, 50 + GRID_SIZE*CELL_PX + 16)
    dpad.BackgroundTransparency = 1

    local function makeDirBtn(text, posX, posY, dx, dy)
        local btn = Instance.new("TextButton", dpad)
        btn.Size = UDim2.new(0,44,0,44)
        btn.Position = UDim2.new(0,posX,0,posY)
        btn.BackgroundColor3 = C.card2
        btn.Text = text
        btn.TextColor3 = C.text
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 16
        btn.AutoButtonColor = false
        corner(btn, 10)
        stroke(btn, C.border, 1, 0.4)
        pressFX(btn)
        btn.MouseButton1Click:Connect(function()
            -- Cegah membalik arah 180 derajat langsung (aturan snake klasik)
            if not (dx == -direction.x and dx ~= 0) and not (dy == -direction.y and dy ~= 0) then
                nextDirection = {x=dx, y=dy}
            end
        end)
        return btn
    end

    makeDirBtn("▲", 48, 0, 0, -1)
    makeDirBtn("◀", 0, 48, -1, 0)
    makeDirBtn("▶", 96, 48, 1, 0)
    makeDirBtn("▼", 48, 96, 0, 1)

    render()
    gameLoopConn = game:GetService("RunService").Heartbeat:Connect(function()
        -- Throttle manual pakai os.clock supaya tick rate konsisten walau FPS beda-beda
    end)
    -- Pakai task.spawn + while loop lebih simpel untuk tick rate tetap (bukan Heartbeat)
    if gameLoopConn then gameLoopConn:Disconnect() end
    local running = true
    gameLoopConn = {Disconnect = function() running = false end} -- fake connection object biar cleanupGameConnections() tetap kerja
    task.spawn(function()
        while running and not gameOver do
            task.wait(TICK_RATE)
            if running then tick() end
        end
    end)
end
-- ================================================================
-- ==================== GAME 2: 2048 ==============================
-- ================================================================
local function run2048Game(container)
    local GRID = 4
    local CELL_PX = 60
    local GAP = 6

    local TILE_COLORS = {
        [2]=Color3.fromRGB(60,60,72),   [4]=Color3.fromRGB(70,70,85),
        [8]=Color3.fromRGB(90,70,50),   [16]=Color3.fromRGB(110,80,40),
        [32]=Color3.fromRGB(140,80,40), [64]=Color3.fromRGB(170,70,40),
        [128]=Color3.fromRGB(180,150,40), [256]=Color3.fromRGB(190,160,50),
        [512]=Color3.fromRGB(200,170,60), [1024]=Color3.fromRGB(210,180,70),
        [2048]=Color3.fromRGB(255,195,70),
    }

    local boardSize = GRID * CELL_PX + (GRID+1) * GAP
    local boardFrame = Instance.new("Frame", container)
    boardFrame.Size = UDim2.new(0, boardSize, 0, boardSize)
    boardFrame.Position = UDim2.new(0.5, -boardSize/2, 0, 50)
    boardFrame.BackgroundColor3 = C.bg
    corner(boardFrame, 10)
    stroke(boardFrame, C.gold, 2, 0.2)

    local scoreLbl = Instance.new("TextLabel", container)
    scoreLbl.Size = UDim2.new(1,0,0,30)
    scoreLbl.Position = UDim2.new(0,0,0,10)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = "Skor: 0  |  Best: " .. getHighScore("2048")
    scoreLbl.TextColor3 = C.text
    scoreLbl.Font = Enum.Font.GothamBlack
    scoreLbl.TextSize = 14

    -- ===== STATE =====
    local grid = {} -- grid[y][x] = angka atau 0 (kosong)
    for y = 1, GRID do
        grid[y] = {}
        for x = 1, GRID do grid[y][x] = 0 end
    end
    local score = 0
    local gameOver = false
    local tileInstances = {} -- [y][x] = Frame

    local function createTileSlots()
        for y = 1, GRID do
            tileInstances[y] = {}
            for x = 1, GRID do
                local slot = Instance.new("Frame", boardFrame)
                slot.Size = UDim2.new(0, CELL_PX, 0, CELL_PX)
                slot.Position = UDim2.new(0, GAP + (x-1)*(CELL_PX+GAP), 0, GAP + (y-1)*(CELL_PX+GAP))
                slot.BackgroundColor3 = C.card2
                corner(slot, 6)

                local label = Instance.new("TextLabel", slot)
                label.Size = UDim2.new(1,0,1,0)
                label.BackgroundTransparency = 1
                label.Text = ""
                label.Font = Enum.Font.GothamBlack
                label.TextSize = 20
                label.TextColor3 = Color3.new(1,1,1)

                tileInstances[y][x] = {frame = slot, label = label}
            end
        end
    end

    local function render()
        for y = 1, GRID do
            for x = 1, GRID do
                local val = grid[y][x]
                local inst = tileInstances[y][x]
                if val == 0 then
                    inst.frame.BackgroundColor3 = C.card2
                    inst.label.Text = ""
                else
                    inst.frame.BackgroundColor3 = TILE_COLORS[val] or Color3.fromRGB(255,80,80)
                    inst.label.Text = tostring(val)
                    inst.label.TextSize = val >= 1000 and 15 or (val >= 100 and 18 or 20)
                end
            end
        end
    end

    local function getEmptyCells()
        local empty = {}
        for y = 1, GRID do
            for x = 1, GRID do
                if grid[y][x] == 0 then table.insert(empty, {x=x, y=y}) end
            end
        end
        return empty
    end

    local function spawnTile()
        local empty = getEmptyCells()
        if #empty == 0 then return false end
        local pick = empty[math.random(1, #empty)]
        grid[pick.y][pick.x] = (math.random() < 0.9) and 2 or 4
        return true
    end

    -- Geser + gabung satu baris (array angka, 0 = kosong), return baris baru + skor tambahan
    local function slideRow(row)
        local filtered = {}
        for _, v in ipairs(row) do
            if v ~= 0 then table.insert(filtered, v) end
        end

        local merged = {}
        local addedScore = 0
        local i = 1
        while i <= #filtered do
            if filtered[i+1] and filtered[i] == filtered[i+1] then
                local newVal = filtered[i] * 2
                table.insert(merged, newVal)
                addedScore = addedScore + newVal
                i = i + 2
            else
                table.insert(merged, filtered[i])
                i = i + 1
            end
        end

        while #merged < GRID do table.insert(merged, 0) end
        return merged, addedScore
    end

    local function getColumn(x)
        local col = {}
        for y = 1, GRID do table.insert(col, grid[y][x]) end
        return col
    end
    local function setColumn(x, col)
        for y = 1, GRID do grid[y][x] = col[y] end
    end
    local function reverseArr(arr)
        local r = {}
        for i = #arr, 1, -1 do table.insert(r, arr[i]) end
        return r
    end

    local function checkGameOver()
        if #getEmptyCells() > 0 then return false end
        -- Cek apakah masih ada merge yang mungkin (horizontal/vertikal)
        for y = 1, GRID do
            for x = 1, GRID do
                local v = grid[y][x]
                if x < GRID and grid[y][x+1] == v then return false end
                if y < GRID and grid[y+1][x] == v then return false end
            end
        end
        return true
    end

    local function showGameOver()
        gameOver = true
        cleanupGameConnections()
        local isNewHigh = setHighScore("2048", score)

        local overlay = Instance.new("Frame", container)
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.3
        overlay.ZIndex = 10

        local msg = Instance.new("TextLabel", overlay)
        msg.Size = UDim2.new(1,-40,0,80)
        msg.Position = UDim2.new(0,20,0.4,0)
        msg.BackgroundTransparency = 1
        msg.Text = (isNewHigh and "🏆 REKOR BARU!\n" or "Game Over\n") .. "Skor: " .. score
        msg.TextColor3 = Color3.new(1,1,1)
        msg.Font = Enum.Font.GothamBlack
        msg.TextSize = 20
        msg.ZIndex = 11
        msg.TextWrapped = true

        local retryBtn = Instance.new("TextButton", overlay)
        retryBtn.Size = UDim2.new(0,140,0,40)
        retryBtn.Position = UDim2.new(0.5,-70,0.65,0)
        retryBtn.BackgroundColor3 = C.gold
        retryBtn.Text = "Main Lagi"
        retryBtn.TextColor3 = Color3.new(0,0,0)
        retryBtn.Font = Enum.Font.GothamBlack
        retryBtn.TextSize = 13
        retryBtn.AutoButtonColor = false
        retryBtn.ZIndex = 11
        corner(retryBtn, 10)
        pressFX(retryBtn)
        retryBtn.MouseButton1Click:Connect(function()
            openGame("2048")
        end)
    end

    local function move(dir) -- dir: "up"/"down"/"left"/"right"
        if gameOver then return end
        local moved = false
        local totalScoreAdd = 0

        if dir == "left" or dir == "right" then
            for y = 1, GRID do
                local row = grid[y]
                local original = table.clone(row)
                if dir == "right" then row = reverseArr(row) end
                local newRow, addedScore = slideRow(row)
                if dir == "right" then newRow = reverseArr(newRow) end
                grid[y] = newRow
                totalScoreAdd = totalScoreAdd + addedScore
                for x = 1, GRID do
                    if original[x] ~= newRow[x] then moved = true end
                end
            end
        else
            for x = 1, GRID do
                local col = getColumn(x)
                local original = table.clone(col)
                if dir == "down" then col = reverseArr(col) end
                local newCol, addedScore = slideRow(col)
                if dir == "down" then newCol = reverseArr(newCol) end
                setColumn(x, newCol)
                totalScoreAdd = totalScoreAdd + addedScore
                for y = 1, GRID do
                    if original[y] ~= newCol[y] then moved = true end
                end
            end
        end

        if moved then
            score = score + totalScoreAdd
            scoreLbl.Text = "Skor: " .. score .. "  |  Best: " .. math.max(getHighScore("2048"), score)
            spawnTile()
            render()
            if checkGameOver() then
                showGameOver()
            end
        end
    end

    -- ===== KONTROL: SWIPE GESTURE =====
    local swipeStart = nil
    inputConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            swipeStart = input.Position
        end
    end)

    local swipeEndConn
    swipeEndConn = UserInputService.InputEnded:Connect(function(input)
        if not swipeStart then return end
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local delta = input.Position - swipeStart
            swipeStart = nil
            if delta.Magnitude < 20 then return end -- terlalu kecil, abaikan (tap biasa)

            if math.abs(delta.X) > math.abs(delta.Y) then
                move(delta.X > 0 and "right" or "left")
            else
                move(delta.Y > 0 and "down" or "up")
            end
        end
    end)

    -- Simpan swipeEndConn juga supaya ke-disconnect saat cleanup
    local originalCleanup = cleanupGameConnections
    -- (swipeEndConn di-disconnect manual di bawah lewat wrapper input)
    local oldInputConn = inputConn
    inputConn = {
        Disconnect = function()
            pcall(function() oldInputConn:Disconnect() end)
            pcall(function() swipeEndConn:Disconnect() end)
        end
    }

    -- Tombol arah juga disediakan (fallback selain swipe, lebih pasti responnya)
    local btnRow = Instance.new("Frame", container)
    btnRow.Size = UDim2.new(0, 140, 0, 140)
    btnRow.Position = UDim2.new(0.5, -70, 0, 50 + boardSize + 16)
    btnRow.BackgroundTransparency = 1

    local function makeDirBtn(text, posX, posY, dir)
        local btn = Instance.new("TextButton", btnRow)
        btn.Size = UDim2.new(0,44,0,44)
        btn.Position = UDim2.new(0,posX,0,posY)
        btn.BackgroundColor3 = C.card2
        btn.Text = text
        btn.TextColor3 = C.text
        btn.Font = Enum.Font.GothamBlack
        btn.TextSize = 16
        btn.AutoButtonColor = false
        corner(btn, 10)
        stroke(btn, C.border, 1, 0.4)
        pressFX(btn)
        btn.MouseButton1Click:Connect(function() move(dir) end)
    end
    makeDirBtn("▲", 48, 0, "up")
    makeDirBtn("◀", 0, 48, "left")
    makeDirBtn("▶", 96, 48, "right")
    makeDirBtn("▼", 48, 96, "down")

    createTileSlots()
    spawnTile()
    spawnTile()
    render()
end
-- ================================================================
-- ==================== GAME 3: FLAPPY-STYLE ======================
-- ================================================================
local function runFlappyGame(container)
    local AREA_W, AREA_H = 260, 340
    local BIRD_SIZE = 22
    local GRAVITY = 900       -- px/detik^2
    local JUMP_VELOCITY = -320 -- px/detik
    local PIPE_WIDTH = 44
    local PIPE_GAP = 110
    local PIPE_SPEED = 130    -- px/detik
    local PIPE_INTERVAL = 1.6 -- detik antar pipa baru

    local playArea = Instance.new("Frame", container)
    playArea.Size = UDim2.new(0, AREA_W, 0, AREA_H)
    playArea.Position = UDim2.new(0.5, -AREA_W/2, 0, 50)
    playArea.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    playArea.ClipsDescendants = true
    corner(playArea, 10)
    stroke(playArea, C.accent2, 2, 0.2)

    local scoreLbl = Instance.new("TextLabel", container)
    scoreLbl.Size = UDim2.new(1,0,0,30)
    scoreLbl.Position = UDim2.new(0,0,0,10)
    scoreLbl.BackgroundTransparency = 1
    scoreLbl.Text = "Skor: 0  |  Best: " .. getHighScore("flappy")
    scoreLbl.TextColor3 = C.text
    scoreLbl.Font = Enum.Font.GothamBlack
    scoreLbl.TextSize = 14

    -- ===== STATE =====
    local birdY = AREA_H/2
    local birdVelocity = 0
    local pipes = {} -- {x=, gapY=, scored=bool, topFrame=, botFrame=}
    local score = 0
    local gameOver = false
    local timeSinceLastPipe = 0
    local started = false

    local bird = Instance.new("Frame", playArea)
    bird.Size = UDim2.new(0, BIRD_SIZE, 0, BIRD_SIZE)
    bird.Position = UDim2.new(0, 40, 0, birdY)
    bird.BackgroundColor3 = C.gold
    corner(bird, 100)
    stroke(bird, Color3.new(1,1,1), 1.5, 0.3)

    local hintLbl = Instance.new("TextLabel", playArea)
    hintLbl.Size = UDim2.new(1,0,0,30)
    hintLbl.Position = UDim2.new(0,0,0.4,0)
    hintLbl.BackgroundTransparency = 1
    hintLbl.Text = "Tap untuk mulai!"
    hintLbl.TextColor3 = Color3.new(1,1,1)
    hintLbl.Font = Enum.Font.GothamBlack
    hintLbl.TextSize = 16

    local function spawnPipe()
        local gapY = math.random(60, AREA_H - 60 - PIPE_GAP)

        local topPipe = Instance.new("Frame", playArea)
        topPipe.Size = UDim2.new(0, PIPE_WIDTH, 0, gapY)
        topPipe.Position = UDim2.new(0, AREA_W, 0, 0)
        topPipe.BackgroundColor3 = C.accent
        corner(topPipe, 4)

        local botPipe = Instance.new("Frame", playArea)
        botPipe.Size = UDim2.new(0, PIPE_WIDTH, 0, AREA_H - gapY - PIPE_GAP)
        botPipe.Position = UDim2.new(0, AREA_W, 0, gapY + PIPE_GAP)
        botPipe.BackgroundColor3 = C.accent
        corner(botPipe, 4)

        table.insert(pipes, {
            x = AREA_W, gapY = gapY, scored = false,
            topFrame = topPipe, botFrame = botPipe,
        })
    end

    local function showGameOver()
        gameOver = true
        cleanupGameConnections()
        local isNewHigh = setHighScore("flappy", score)

        local overlay = Instance.new("Frame", container)
        overlay.Size = UDim2.new(1,0,1,0)
        overlay.BackgroundColor3 = Color3.new(0,0,0)
        overlay.BackgroundTransparency = 0.3
        overlay.ZIndex = 10

        local msg = Instance.new("TextLabel", overlay)
        msg.Size = UDim2.new(1,-40,0,80)
        msg.Position = UDim2.new(0,20,0.4,0)
        msg.BackgroundTransparency = 1
        msg.Text = (isNewHigh and "🏆 REKOR BARU!\n" or "Game Over\n") .. "Skor: " .. score
        msg.TextColor3 = Color3.new(1,1,1)
        msg.Font = Enum.Font.GothamBlack
        msg.TextSize = 20
        msg.ZIndex = 11
        msg.TextWrapped = true

        local retryBtn = Instance.new("TextButton", overlay)
        retryBtn.Size = UDim2.new(0,140,0,40)
        retryBtn.Position = UDim2.new(0.5,-70,0.65,0)
        retryBtn.BackgroundColor3 = C.accent2
        retryBtn.Text = "Main Lagi"
        retryBtn.TextColor3 = Color3.new(1,1,1)
        retryBtn.Font = Enum.Font.GothamBlack
        retryBtn.TextSize = 13
        retryBtn.AutoButtonColor = false
        retryBtn.ZIndex = 11
        corner(retryBtn, 10)
        pressFX(retryBtn)
        retryBtn.MouseButton1Click:Connect(function()
            openGame("flappy")
        end)
    end

    local function jump()
        if gameOver then return end
        if not started then
            started = true
            hintLbl.Visible = false
        end
        birdVelocity = JUMP_VELOCITY
    end

    -- Input: tap dimana saja di area main untuk lompat
    local tapBtn = Instance.new("TextButton", playArea)
    tapBtn.Size = UDim2.new(1,0,1,0)
    tapBtn.BackgroundTransparency = 1
    tapBtn.Text = ""
    tapBtn.ZIndex = 5
    tapBtn.MouseButton1Click:Connect(jump)

    local lastTime = os.clock()
    local running = true
    gameLoopConn = {Disconnect = function() running = false end}

    task.spawn(function()
        while running and not gameOver do
            local now = os.clock()
            local dt = math.min(now - lastTime, 0.05) -- clamp dt biar tidak "loncat" kalau lag
            lastTime = now

            if started then
                birdVelocity = birdVelocity + GRAVITY * dt
                birdY = birdY + birdVelocity * dt

                -- Cek tabrak lantai/langit-langit
                if birdY < 0 or birdY > AREA_H - BIRD_SIZE then
                    showGameOver()
                    break
                end

                bird.Position = UDim2.new(0, 40, 0, birdY)

                -- Update pipa
                timeSinceLastPipe = timeSinceLastPipe + dt
                if timeSinceLastPipe >= PIPE_INTERVAL then
                    timeSinceLastPipe = 0
                    spawnPipe()
                end

                for i = #pipes, 1, -1 do
                    local pipe = pipes[i]
                    pipe.x = pipe.x - PIPE_SPEED * dt
                    pipe.topFrame.Position = UDim2.new(0, pipe.x, 0, 0)
                    pipe.botFrame.Position = UDim2.new(0, pipe.x, 0, pipe.gapY + PIPE_GAP)

                    -- Cek skor (bird lewat pipa)
                    if not pipe.scored and pipe.x + PIPE_WIDTH < 40 then
                        pipe.scored = true
                        score = score + 1
                        scoreLbl.Text = "Skor: " .. score .. "  |  Best: " .. math.max(getHighScore("flappy"), score)
                    end

                    -- Cek tabrakan (AABB sederhana)
                    local birdLeft, birdRight = 40, 40 + BIRD_SIZE
                    local birdTop, birdBot = birdY, birdY + BIRD_SIZE
                    local pipeLeft, pipeRight = pipe.x, pipe.x + PIPE_WIDTH

                    if birdRight > pipeLeft and birdLeft < pipeRight then
                        if birdTop < pipe.gapY or birdBot > pipe.gapY + PIPE_GAP then
                            showGameOver()
                            break
                        end
                    end

                    -- Buang pipa yang sudah lewat layar
                    if pipe.x < -PIPE_WIDTH then
                        pcall(function() pipe.topFrame:Destroy() end)
                        pcall(function() pipe.botFrame:Destroy() end)
                        table.remove(pipes, i)
                    end
                end
            end

            task.wait()
        end
    end)
end

-- ================================================================
-- ==================== MENU SINGLE PLAYER ========================
-- ================================================================
local SINGLE_PLAYER_GAMES = {
    {id = "snake",  name = "Snake",           icon = "🐍", desc = "Klasik ular makan buah, jangan tabrak dinding!", runner = runSnakeGame},
    {id = "2048",   name = "2048",            icon = "🔢", desc = "Gabungkan angka sampai capai 2048!", runner = run2048Game},
    {id = "flappy", name = "Flappy",          icon = "🐦", desc = "Tap untuk terbang, hindari pipa!", runner = runFlappyGame},
}

renderGameMenu = function()
    local menuSec = Instance.new("Frame", appContent)
    menuSec.Name = "SinglePlayerMenu"
    menuSec.Size = UDim2.new(1,0,0,0)
    menuSec.AutomaticSize = Enum.AutomaticSize.Y
    menuSec.BackgroundTransparency = 1
    menuSec.LayoutOrder = 2

    local layout = Instance.new("UIListLayout", menuSec)
    layout.Padding = UDim.new(0,10)

    for i, gameInfo in ipairs(SINGLE_PLAYER_GAMES) do
        local card = Instance.new("Frame", menuSec)
        card.Size = UDim2.new(1,0,0,84)
        card.BackgroundColor3 = C.card
        card.LayoutOrder = i
        corner(card, 14)
        stroke(card, C.border, 1, 0.4)

        local iconFrame = Instance.new("Frame", card)
        iconFrame.Size = UDim2.new(0,60,0,60)
        iconFrame.Position = UDim2.new(0,12,0,12)
        iconFrame.BackgroundColor3 = C.card2
        corner(iconFrame, 14)

        local iconLbl = Instance.new("TextLabel", iconFrame)
        iconLbl.Size = UDim2.new(1,0,1,0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = gameInfo.icon
        iconLbl.TextSize = 28

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(1,-160,0,20)
        nameLbl.Position = UDim2.new(0,82,0,14)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = gameInfo.name
        nameLbl.TextColor3 = C.text
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextSize = 14
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local descLbl = Instance.new("TextLabel", card)
        descLbl.Size = UDim2.new(1,-160,0,32)
        descLbl.Position = UDim2.new(0,82,0,36)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = gameInfo.desc
        descLbl.TextColor3 = C.text3
        descLbl.Font = Enum.Font.Gotham
        descLbl.TextSize = 9
        descLbl.TextWrapped = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left

        local bestLbl = Instance.new("TextLabel", card)
        bestLbl.Size = UDim2.new(0,70,0,16)
        bestLbl.Position = UDim2.new(1,-80,0,12)
        bestLbl.BackgroundTransparency = 1
        bestLbl.Text = "🏆 " .. getHighScore(gameInfo.id)
        bestLbl.TextColor3 = C.gold
        bestLbl.Font = Enum.Font.GothamBold
        bestLbl.TextSize = 10
        bestLbl.TextXAlignment = Enum.TextXAlignment.Right

        local playBtn = Instance.new("TextButton", card)
        playBtn.Size = UDim2.new(0,70,0,26)
        playBtn.Position = UDim2.new(1,-80,1,-36)
        playBtn.BackgroundColor3 = C.accent
        playBtn.Text = "Main"
        playBtn.TextColor3 = Color3.new(1,1,1)
        playBtn.Font = Enum.Font.GothamBlack
        playBtn.TextSize = 11
        playBtn.AutoButtonColor = false
        corner(playBtn, 8)
        pressFX(playBtn)
        playBtn.MouseButton1Click:Connect(function()
            openGame(gameInfo.id)
        end)
    end
end
-- ================================================================
-- ==================== MULTIPLAYER: TIC-TAC-TOE ==================
-- ================================================================
-- Turn-based via Firebase. Struktur data:
-- /game_sessions/<sessionId> = {
--     player1 = {userId, name}, player2 = {userId, name},
--     board = {"","","","","","","","",""},  -- 9 sel, "" / "X" / "O"
--     turn = userId (siapa giliran),
--     status = "waiting" / "playing" / "finished",
--     winner = userId / "draw" / nil,
--     lastMove = timestamp,
-- }
-- /game_challenges/<targetUserId>/<challengeId> = {
--     fromUserId, fromName, sessionId, timestamp
-- }

local ttt_currentSessionId = nil
local ttt_pollConn = nil
local ttt_boardCells = {}

local function ttt_generateSessionId()
    return "ttt_" .. tostring(os.time()) .. "_" .. tostring(math.random(1000,9999))
end

local function ttt_checkWinner(board)
    local lines = {
        {1,2,3},{4,5,6},{7,8,9}, -- horizontal
        {1,4,7},{2,5,8},{3,6,9}, -- vertikal
        {1,5,9},{3,5,7},         -- diagonal
    }
    for _, line in ipairs(lines) do
        local a,b,c = board[line[1]], board[line[2]], board[line[3]]
        if a ~= "" and a == b and b == c then
            return a
        end
    end
    -- Cek draw (semua terisi, tidak ada pemenang)
    local full = true
    for _, v in ipairs(board) do
        if v == "" then full = false break end
    end
    if full then return "draw" end
    return nil
end

local function ttt_createSession(opponentUserId, opponentName)
    if not Firebase then return nil end
    local sessionId = ttt_generateSessionId()

    local sessionData = {
        player1 = {userId = LocalPlayer.UserId, name = LocalPlayer.DisplayName},
        player2 = {userId = opponentUserId, name = opponentName},
        board = {"","","","","","","","",""},
        turn = opponentUserId, -- lawan mulai duluan setelah accept (biar adil, penantang nunggu)
        status = "waiting",
        winner = nil,
        lastMove = os.time(),
    }

    pcall(function()
        Firebase.SetData("game_sessions/" .. sessionId, sessionData)
        Firebase.PushData("game_challenges/" .. tostring(opponentUserId), {
            fromUserId = LocalPlayer.UserId,
            fromName = LocalPlayer.DisplayName,
            sessionId = sessionId,
            timestamp = os.time(),
        })
    end)

    return sessionId
end

local function ttt_makeMove(cellIndex)
    if not ttt_currentSessionId or not Firebase then return end

    task.spawn(function()
        local ok, session = pcall(function()
            return Firebase.GetData("game_sessions/" .. ttt_currentSessionId)
        end)
        if not ok or not session then return end
        if session.turn ~= LocalPlayer.UserId then return end -- bukan giliranmu
        if session.board[cellIndex] ~= "" then return end -- sel sudah terisi

        local mySymbol = (session.player1.userId == LocalPlayer.UserId) and "X" or "O"
        session.board[cellIndex] = mySymbol

        local winner = ttt_checkWinner(session.board)
        local otherUserId = (session.player1.userId == LocalPlayer.UserId)
            and session.player2.userId or session.player1.userId

        session.turn = otherUserId
        session.lastMove = os.time()
        if winner then
            session.status = "finished"
            session.winner = winner == "draw" and "draw" or LocalPlayer.UserId
        end

        pcall(function()
            Firebase.SetData("game_sessions/" .. ttt_currentSessionId, session)
        end)
    end)
end

local function ttt_renderBoard(container, session)
    for _, c in ipairs(container:GetChildren()) do
        if c.Name == "TTTBoard" then c:Destroy() end
    end

    local boardFrame = Instance.new("Frame", container)
    boardFrame.Name = "TTTBoard"
    boardFrame.Size = UDim2.new(0, 216, 0, 216)
    boardFrame.Position = UDim2.new(0.5, -108, 0, 90)
    boardFrame.BackgroundColor3 = C.bg
    corner(boardFrame, 10)
    stroke(boardFrame, C.accent2, 2, 0.2)

    local mySymbol = (session.player1.userId == LocalPlayer.UserId) and "X" or "O"
    local isMyTurn = session.turn == LocalPlayer.UserId and session.status ~= "finished"

    for i = 1, 9 do
        local row = math.floor((i-1)/3)
        local col = (i-1) % 3

        local cell = Instance.new("TextButton", boardFrame)
        cell.Size = UDim2.new(0,64,0,64)
        cell.Position = UDim2.new(0, 8 + col*70, 0, 8 + row*70)
        cell.BackgroundColor3 = C.card2
        cell.Text = session.board[i]
        cell.TextColor3 = session.board[i] == "X" and C.accent2 or C.gold
        cell.Font = Enum.Font.GothamBlack
        cell.TextSize = 28
        cell.AutoButtonColor = false
        corner(cell, 8)
        pressFX(cell)

        if isMyTurn and session.board[i] == "" then
            cell.MouseButton1Click:Connect(function()
                ttt_makeMove(i)
            end)
        end
    end

    local statusLbl = container:FindFirstChild("TTTStatus")
    if not statusLbl then
        statusLbl = Instance.new("TextLabel", container)
        statusLbl.Name = "TTTStatus"
        statusLbl.Size = UDim2.new(1,0,0,30)
        statusLbl.Position = UDim2.new(0,0,0,50)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Font = Enum.Font.GothamBlack
        statusLbl.TextSize = 13
    end

    if session.status == "finished" then
        if session.winner == "draw" then
            statusLbl.Text = "🤝 Seri!"
            statusLbl.TextColor3 = C.text2
        elseif session.winner == LocalPlayer.UserId then
            statusLbl.Text = "🎉 Kamu Menang!"
            statusLbl.TextColor3 = C.accent
        else
            statusLbl.Text = "😢 Kamu Kalah"
            statusLbl.TextColor3 = C.red
        end
    else
        statusLbl.Text = isMyTurn and ("Giliranmu (" .. mySymbol .. ")") or "Menunggu lawan..."
        statusLbl.TextColor3 = isMyTurn and C.accent or C.text3
    end
end

local function ttt_openSession(container, sessionId)
    ttt_currentSessionId = sessionId

    if ttt_pollConn then
        pcall(function() ttt_pollConn:Disconnect() end)
    end

    local running = true
    ttt_pollConn = {Disconnect = function() running = false end}

    task.spawn(function()
        while running do
            local ok, session = pcall(function()
                return Firebase.GetData("game_sessions/" .. sessionId)
            end)
            if ok and session then
                ttt_renderBoard(container, session)
            end
            task.wait(2) -- poll tiap 2 detik, cukup untuk turn-based
        end
    end)
end

-- ==================== RENDER TAB MULTIPLAYER ====================
renderMultiplayerTab = function()
    local mpSec = Instance.new("Frame", appContent)
    mpSec.Name = "MultiplayerSection"
    mpSec.Size = UDim2.new(1,0,0,0)
    mpSec.AutomaticSize = Enum.AutomaticSize.Y
    mpSec.BackgroundTransparency = 1
    mpSec.LayoutOrder = 2

    local layout = Instance.new("UIListLayout", mpSec)
    layout.Padding = UDim.new(0,10)

    local titleLbl = Instance.new("TextLabel", mpSec)
    titleLbl.Size = UDim2.new(1,0,0,20)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "🎮 Tic-Tac-Toe — Tantang Teman Online"
    titleLbl.TextColor3 = C.text
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 13
    titleLbl.LayoutOrder = 0

    local listScroll = Instance.new("ScrollingFrame", mpSec)
    listScroll.Size = UDim2.new(1,0,0,240)
    listScroll.BackgroundColor3 = C.bg
    listScroll.BorderSizePixel = 0
    listScroll.CanvasSize = UDim2.new(0,0,0,0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ScrollBarThickness = 3
    listScroll.LayoutOrder = 1
    corner(listScroll, 12)
    stroke(listScroll, C.border, 1, 0.4)

    local listPad = Instance.new("UIPadding", listScroll)
    listPad.PaddingTop = UDim.new(0,8); listPad.PaddingBottom = UDim.new(0,8)
    listPad.PaddingLeft = UDim.new(0,8); listPad.PaddingRight = UDim.new(0,8)

    local listLayout = Instance.new("UIListLayout", listScroll)
    listLayout.Padding = UDim.new(0,6)

    local function loadOnlinePlayersForChallenge()
        for _, c in ipairs(listScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end

        if not Firebase or not Firebase.GetOnlinePlayers then
            local e = Instance.new("TextLabel", listScroll)
            e.Size = UDim2.new(1,0,0,30)
            e.BackgroundTransparency = 1
            e.Text = "Firebase tidak tersedia"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 10
            return
        end

        local ok, onlineData = pcall(function() return Firebase.GetOnlinePlayers() end)
        if not ok or not onlineData or type(onlineData) ~= "table" then
            local e = Instance.new("TextLabel", listScroll)
            e.Size = UDim2.new(1,0,0,30)
            e.BackgroundTransparency = 1
            e.Text = "Tidak ada player online"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 10
            return
        end

        local order = 0
        for uid, p in pairs(onlineData) do
            if tostring(uid) ~= tostring(LocalPlayer.UserId) and type(p) == "table" then
                order = order + 1
                local row = Instance.new("Frame", listScroll)
                row.Size = UDim2.new(1,0,0,48)
                row.BackgroundColor3 = C.card
                row.LayoutOrder = order
                corner(row, 10)

                local nameLbl = Instance.new("TextLabel", row)
                nameLbl.Size = UDim2.new(1,-90,1,0)
                nameLbl.Position = UDim2.new(0,10,0,0)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = "🟢 " .. (p.displayName or p.name or "Unknown")
                nameLbl.TextColor3 = C.text
                nameLbl.Font = Enum.Font.GothamBold
                nameLbl.TextSize = 11
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left

                local challengeBtn = Instance.new("TextButton", row)
                challengeBtn.Size = UDim2.new(0,80,0,30)
                challengeBtn.Position = UDim2.new(1,-88,0.5,-15)
                challengeBtn.BackgroundColor3 = C.accent2
                challengeBtn.Text = "Tantang"
                challengeBtn.TextColor3 = Color3.new(1,1,1)
                challengeBtn.Font = Enum.Font.GothamBold
                challengeBtn.TextSize = 10
                challengeBtn.AutoButtonColor = false
                corner(challengeBtn, 8)
                pressFX(challengeBtn)
                challengeBtn.MouseButton1Click:Connect(function()
                    local sessionId = ttt_createSession(p.userId or uid, p.displayName or p.name)
                    if sessionId then
                        if _G.showDynamicNotification then
                            _G.showDynamicNotification(
                                "Tantangan terkirim ke " .. (p.displayName or p.name) .. "!", C.accent2
                            )
                        end
                    end
                end)
            end
        end

        if order == 0 then
            local e = Instance.new("TextLabel", listScroll)
            e.Size = UDim2.new(1,0,0,30)
            e.BackgroundTransparency = 1
            e.Text = "Tidak ada player lain yang online"
            e.TextColor3 = C.text3
            e.Font = Enum.Font.Gotham
            e.TextSize = 10
        end
    end

    local refreshBtn = Instance.new("TextButton", mpSec)
    refreshBtn.Size = UDim2.new(1,0,0,32)
    refreshBtn.BackgroundColor3 = C.card2
    refreshBtn.Text = "🔄 Refresh Daftar Online"
    refreshBtn.TextColor3 = C.text2
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 10
    refreshBtn.AutoButtonColor = false
    refreshBtn.LayoutOrder = 2
    corner(refreshBtn, 9)
    stroke(refreshBtn, C.border, 1, 0.3)
    pressFX(refreshBtn)
    refreshBtn.MouseButton1Click:Connect(loadOnlinePlayersForChallenge)

    loadOnlinePlayersForChallenge()

    -- ===== AREA GAME AKTIF (kalau sedang main) =====
    local activeGameArea = Instance.new("Frame", mpSec)
    activeGameArea.Size = UDim2.new(1,0,0,0)
    activeGameArea.AutomaticSize = Enum.AutomaticSize.Y
    activeGameArea.BackgroundTransparency = 1
    activeGameArea.LayoutOrder = 3

    -- Cek apakah ada sesi game yang sedang berjalan dengan kita (baik penantang atau ditantang)
    task.spawn(function()
        if not Firebase then return end
        local ok, challenges = pcall(function()
            return Firebase.GetData("game_challenges/" .. tostring(LocalPlayer.UserId))
        end)
        if ok and challenges and type(challenges) == "table" then
            for challengeId, ch in pairs(challenges) do
                if type(ch) == "table" and ch.sessionId then
                    -- Tampilkan sebagai notifikasi tantangan
                    local challengeCard = Instance.new("Frame", mpSec)
                    challengeCard.Size = UDim2.new(1,0,0,60)
                    challengeCard.BackgroundColor3 = C.card2
                    challengeCard.LayoutOrder = 4
                    corner(challengeCard, 12)
                    stroke(challengeCard, C.gold, 1.5, 0.3)

                    local chLbl = Instance.new("TextLabel", challengeCard)
                    chLbl.Size = UDim2.new(1,-100,1,0)
                    chLbl.Position = UDim2.new(0,12,0,0)
                    chLbl.BackgroundTransparency = 1
                    chLbl.Text = "🎮 " .. (ch.fromName or "Seseorang") .. " menantangmu!"
                    chLbl.TextColor3 = C.text
                    chLbl.Font = Enum.Font.GothamBold
                    chLbl.TextSize = 11
                    chLbl.TextXAlignment = Enum.TextXAlignment.Left
                    chLbl.TextWrapped = true

                    local acceptBtn = Instance.new("TextButton", challengeCard)
                    acceptBtn.Size = UDim2.new(0,80,0,32)
                    acceptBtn.Position = UDim2.new(1,-90,0.5,-16)
                    acceptBtn.BackgroundColor3 = C.accent
                    acceptBtn.Text = "Terima"
                    acceptBtn.TextColor3 = Color3.new(1,1,1)
                    acceptBtn.Font = Enum.Font.GothamBlack
                    acceptBtn.TextSize = 11
                    acceptBtn.AutoButtonColor = false
                    corner(acceptBtn, 8)
                    pressFX(acceptBtn)
                    acceptBtn.MouseButton1Click:Connect(function()
                        pcall(function()
                            Firebase.DeleteData("game_challenges/" .. tostring(LocalPlayer.UserId) .. "/" .. challengeId)
                        end)
                        pcall(function()
                            Firebase.SetData("game_sessions/" .. ch.sessionId .. "/status", "playing")
                        end)
                        challengeCard:Destroy()
                        ttt_openSession(activeGameArea, ch.sessionId)
                    end)
                end
            end
        end
    end)
end
-- ================================================================
-- ==================== SISTEM TAB UTAMA ==========================
-- ================================================================

openGame = function(gameId)
    cleanupGameConnections()
    if ttt_pollConn then
        pcall(function() ttt_pollConn:Disconnect() end)
        ttt_pollConn = nil
    end

    -- Bersihkan semua child appContent kecuali header (LayoutOrder 0) dan tab bar (LayoutOrder 1)
    for _, c in ipairs(appContent:GetChildren()) do
        if c:IsA("GuiObject") and c.LayoutOrder and c.LayoutOrder >= 2 then
            c:Destroy()
        end
    end

    local gameContainer = Instance.new("Frame", appContent)
    gameContainer.Name = "GameContainer"
    gameContainer.Size = UDim2.new(1,0,0,480)
    gameContainer.BackgroundColor3 = C.card
    gameContainer.LayoutOrder = 2
    corner(gameContainer, 14)
    stroke(gameContainer, C.border, 1, 0.4)

    local backBtn = Instance.new("TextButton", gameContainer)
    backBtn.Size = UDim2.new(0,70,0,28)
    backBtn.Position = UDim2.new(0,10,0,10)
    backBtn.BackgroundColor3 = C.card2
    backBtn.Text = "← Kembali"
    backBtn.TextColor3 = C.text2
    backBtn.Font = Enum.Font.GothamBold
    backBtn.TextSize = 10
    backBtn.AutoButtonColor = false
    backBtn.ZIndex = 20
    corner(backBtn, 8)
    pressFX(backBtn)
    backBtn.MouseButton1Click:Connect(function()
        cleanupGameConnections()
        _G.openApp("Games", _G.openGamesApp)
    end)

    for _, gameInfo in ipairs(SINGLE_PLAYER_GAMES) do
        if gameInfo.id == gameId then
            gameInfo.runner(gameContainer)
            return
        end
    end
end

-- ==================== ENTRY POINT APP ====================
function _G.openGamesApp()
    -- ===== HEADER =====
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1,0,0,44)
    header.BackgroundColor3 = C.card
    header.LayoutOrder = 0
    corner(header, 12)
    stroke(header, C.accent, 1, 0.5)

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1,-20,0,22)
    hTitle.Position = UDim2.new(0,12,0,4)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "🎮 Games"
    hTitle.TextColor3 = C.text
    hTitle.Font = Enum.Font.GothamBlack
    hTitle.TextSize = 13
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local hSub = Instance.new("TextLabel", header)
    hSub.Size = UDim2.new(1,-20,0,14)
    hSub.Position = UDim2.new(0,12,0,26)
    hSub.BackgroundTransparency = 1
    hSub.Text = "Main sendiri atau tantang teman online"
    hSub.TextColor3 = C.text3
    hSub.Font = Enum.Font.Gotham
    hSub.TextSize = 9
    hSub.TextXAlignment = Enum.TextXAlignment.Left

    -- ===== TAB BAR =====
    local tabBar = Instance.new("Frame", appContent)
    tabBar.Size = UDim2.new(1,0,0,38)
    tabBar.BackgroundColor3 = C.card2
    tabBar.LayoutOrder = 1
    corner(tabBar, 10)

    local tabLayout = Instance.new("UIListLayout", tabBar)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0,4)

    local tabPad = Instance.new("UIPadding", tabBar)
    tabPad.PaddingTop = UDim.new(0,4); tabPad.PaddingBottom = UDim.new(0,4)
    tabPad.PaddingLeft = UDim.new(0,4); tabPad.PaddingRight = UDim.new(0,4)

    local singleTabBtn, mpTabBtn

    local function renderContent()
        -- Bersihkan konten tab lama (LayoutOrder >= 2)
        for _, c in ipairs(appContent:GetChildren()) do
            if c:IsA("GuiObject") and c.LayoutOrder and c.LayoutOrder >= 2 then
                c:Destroy()
            end
        end

        if currentTab == "single" then
            singleTabBtn.BackgroundColor3 = C.accent
            singleTabBtn.TextColor3 = Color3.new(1,1,1)
            mpTabBtn.BackgroundColor3 = C.card2
            mpTabBtn.TextColor3 = C.text2
            renderGameMenu()
        else
            mpTabBtn.BackgroundColor3 = C.accent2
            mpTabBtn.TextColor3 = Color3.new(1,1,1)
            singleTabBtn.BackgroundColor3 = C.card2
            singleTabBtn.TextColor3 = C.text2
            renderMultiplayerTab()
        end
    end

    singleTabBtn = Instance.new("TextButton", tabBar)
    singleTabBtn.Size = UDim2.new(0.5,-2,1,0)
    singleTabBtn.BackgroundColor3 = C.accent
    singleTabBtn.Text = "🕹️ Single Player"
    singleTabBtn.TextColor3 = Color3.new(1,1,1)
    singleTabBtn.Font = Enum.Font.GothamBlack
    singleTabBtn.TextSize = 11
    singleTabBtn.AutoButtonColor = false
    corner(singleTabBtn, 8)
    pressFX(singleTabBtn)
    singleTabBtn.MouseButton1Click:Connect(function()
        currentTab = "single"
        renderContent()
    end)

    mpTabBtn = Instance.new("TextButton", tabBar)
    mpTabBtn.Size = UDim2.new(0.5,-2,1,0)
    mpTabBtn.BackgroundColor3 = C.card2
    mpTabBtn.Text = "🌐 Multiplayer"
    mpTabBtn.TextColor3 = C.text2
    mpTabBtn.Font = Enum.Font.GothamBlack
    mpTabBtn.TextSize = 11
    mpTabBtn.AutoButtonColor = false
    corner(mpTabBtn, 8)
    pressFX(mpTabBtn)
    mpTabBtn.MouseButton1Click:Connect(function()
        currentTab = "multiplayer"
        renderContent()
    end)

    renderContent()
end

print("[Games] Loaded! Single Player: Snake, 2048, Flappy | Multiplayer: Tic-Tac-Toe")
