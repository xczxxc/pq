-- ================================================
-- MODEL3D APP — Spawn Model 3D (Asset ID) & Gambar (Catbox)
-- Gizmo: Posisi, Rotasi, Ukuran
-- Config: Save/Load lokal (per player) + sinkron Firebase (dev <-> semua player)
-- ================================================

local Services         = _G.Services
local LocalPlayer      = _G.LocalPlayer
local T                = _G.T or {}
local Helpers          = _G.Helpers or {}
local Config           = _G.Config or {}
local Storage          = _G.Storage
local Firebase         = _G.Firebase
local appContent       = _G.appContent

local Players          = Services.Players
local Workspace        = Services.Workspace
local HttpService       = Services.HttpService
local RunService       = Services.RunService
local UserInputService = Services.UserInputService
local InsertService    = game:GetService("InsertService")
local AssetService     = game:GetService("AssetService")
local CoreGui          = game:GetService("CoreGui")

local corner   = Helpers.corner
local stroke   = Helpers.stroke
local tween    = Helpers.tween
local pressFX  = Helpers.pressFX

local DEV_USER_ID = Config.DEVELOPER_USER_ID

-- ==================== DARK THEME (konsisten dengan app lain) ====================
local C = {
    bg      = Color3.fromRGB(12, 12, 18),
    card    = Color3.fromRGB(22, 22, 30),
    card2   = Color3.fromRGB(28, 28, 38),
    border  = Color3.fromRGB(46, 46, 60),
    text    = Color3.fromRGB(240, 240, 250),
    text2   = Color3.fromRGB(160, 160, 178),
    text3   = Color3.fromRGB(95, 95, 112),
    accent  = Color3.fromRGB(130, 120, 255),
    accent2 = Color3.fromRGB(80, 200, 255),
    green   = Color3.fromRGB(90, 230, 160),
    red     = Color3.fromRGB(255, 95, 100),
    gold    = Color3.fromRGB(255, 195, 80),
}

-- ==================== FOLDER WORKSPACE ====================
local FOLDER_NAME = "Model3D_Objects"

local function getFolder()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = Workspace
    end
    return folder
end

-- ==================== STATE PERSISTEN (survive reopen app) ====================
_G.Model3DState = _G.Model3DState or {
    SelectedObject = nil,   -- instance yang sedang dipilih di map
    PositionMode   = false,
    RotationMode   = false,
    ScaleMode      = false,
    ConfigFilter   = "Milikku", -- "Milikku" | "Developer" | "Player Lain" (khusus dev)
    BrowsePlayerUserId = nil,   -- dipakai dev untuk browse config player tertentu
}
local State = _G.Model3DState

_G.Model3DGizmos = _G.Model3DGizmos or {}
local Gizmos = _G.Model3DGizmos

local isDeveloper = (DEV_USER_ID and tostring(LocalPlayer.UserId) == tostring(DEV_USER_ID))

-- ==================== STORAGE LOKAL ====================
local LOCAL_FILE = "PhoneIDViewer_Model3DConfigs.json"
local function loadLocalConfigs()
    local data = {}
    pcall(function()
        if isfile and isfile(LOCAL_FILE) then
            data = HttpService:JSONDecode(readfile(LOCAL_FILE))
        end
    end)
    return type(data) == "table" and data or {}
end
local function saveLocalConfigs(data)
    pcall(function()
        if writefile then writefile(LOCAL_FILE, HttpService:JSONEncode(data)) end
    end)
end
local LocalConfigs = loadLocalConfigs() -- {[configName] = configData}

-- ==================== HELPER: CFrame <-> Table ====================
local function cframeToTable(cf)
    local components = {cf:GetComponents()}
    return components
end
local function tableToCFrame(t)
    if not t or #t < 12 then return CFrame.new() end
    return CFrame.new(unpack(t))
end

-- ==================== SPAWN OBJECT: MODEL 3D DARI ASSET ID ====================
-- CATATAN PENTING: InsertService:LoadAsset() TIDAK BISA dipakai di runtime
-- game / executor (hanya boleh dari Roblox Studio saat development) — itu
-- sengaja dikunci Roblox, bukan bug, dan errornya persis "InsertService
-- cannot be used to load assets". Jadi method itu TIDAK dipakai sama sekali.
--
-- Sebagai gantinya kita coba 2 metode berurutan, dari yang paling lengkap:
--   1) AssetService:LoadAssetAsync(id) — pengganti resmi modern InsertService:
--      LoadAsset (dirilis Roblox September 2025), mengembalikan Model UTUH
--      (bisa berisi banyak part/texture, bukan cuma 1 mesh polos). Ini class
--      berbeda dari InsertService jadi TIDAK ikut kena block yang sama.
--      Catatan: hasilnya Sandboxed (tanpa script capability) — tidak masalah
--      untuk objek yang cuma ditampilkan visual seperti di app ini.
--   2) Kalau (1) gagal (mis. asset third-party dan "Allow Loading Third
--      Party Assets" belum aktif di game ini) -> fallback ke
--      InsertService:CreateMeshPartAsync, yang HANYA menghasilkan geometri
--      mesh polos (tanpa banyak part/texture kompleks) tapi tetap resmi
--      diizinkan Roblox untuk dipakai di runtime.
local function spawnModel3D(assetId, atCFrame)
    local id = tonumber(assetId)
    if not id then return nil, "Asset ID tidak valid (harus berupa angka)." end

    local model = nil
    local errors = {}

    -- ===== METODE 1: AssetService:LoadAssetAsync (paling lengkap) =====
    local ok1, result1 = pcall(function()
        return AssetService:LoadAssetAsync(id)
    end)
    if ok1 and result1 then
        model = result1
        model.Name = "Model3D_" .. tostring(id)
        model:SetAttribute("Model3D_Kind", "model")
        model:SetAttribute("Model3D_AssetId", id)

        -- Kalau hasilnya bukan Model murni (kadang Model pembungkus berisi
        -- 1 Model lagi di dalamnya), ratakan supaya PivotTo tetap presisi.
        if model:IsA("Model") then
            local children = model:GetChildren()
            if #children == 1 and children[1]:IsA("Model") and not model.PrimaryPart then
                local inner = children[1]
                for _, grandchild in ipairs(inner:GetChildren()) do
                    grandchild.Parent = model
                end
                inner:Destroy()
            end
        end

        if not model.PrimaryPart then
            local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
            if firstPart then model.PrimaryPart = firstPart end
        end
    else
        table.insert(errors, "AssetService:LoadAssetAsync -> " .. tostring(result1))
    end

    -- ===== METODE 2 (fallback): InsertService:CreateMeshPartAsync =====
    if not model then
        local contentId = "rbxassetid://" .. tostring(id)
        local ok2, result2 = pcall(function()
            return InsertService:CreateMeshPartAsync(
                contentId,
                Enum.CollisionFidelity.Default,
                Enum.RenderFidelity.Automatic
            )
        end)
        if ok2 and result2 then
            local meshPart = result2
            meshPart.Anchored = true
            meshPart.CanCollide = false

            model = Instance.new("Model")
            model.Name = "Model3D_" .. tostring(id)
            model:SetAttribute("Model3D_Kind", "model")
            model:SetAttribute("Model3D_AssetId", id)
            meshPart.Parent = model
            model.PrimaryPart = meshPart
        else
            table.insert(errors, "InsertService:CreateMeshPartAsync -> " .. tostring(result2))
        end
    end

    if not model then
        return nil, "Asset ID " .. tostring(id) .. " gagal dimuat dengan semua metode:\n"
            .. table.concat(errors, "\n")
    end

    if not model.PrimaryPart then
        return nil, "Asset ID " .. tostring(id) .. " tidak berisi part apapun yang bisa ditampilkan."
    end

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end

    model.Parent = getFolder()
    local baseCFrame = atCFrame or CFrame.new()
    local pivotOk, pivotErr = pcall(function() model:PivotTo(baseCFrame) end)
    if not pivotOk then
        warn("[Model3D] Gagal memposisikan model " .. tostring(id) .. ": " .. tostring(pivotErr))
    end

    return model, nil
end

-- ==================== SPAWN OBJECT: GAMBAR ====================
-- CATATAN PENTING: ImageLabel.Image / Decal.Texture di Roblox HANYA menerima
-- format "rbxassetid://<angka>" (asset yang sudah di-upload & disetujui
-- Roblox). Roblox TIDAK BISA merender link gambar eksternal (Catbox, Imgur,
-- dll) secara langsung — itu bukan bug, itu batasan resmi platform Roblox
-- (rendering gambar HTTPS mentah tidak didukung ImageLabel/Decal apapun).
--
-- Jadi fungsi ini menerima 2 macam input:
--   1) Asset ID Roblox polos (angka) atau "rbxassetid://<angka>" -> langsung
--      dipakai, ini yang PASTI muncul.
--   2) Link Catbox/URL lain -> TIDAK bisa langsung dirender. Untuk pakai
--      gambar dari Catbox, upload dulu gambarnya ke roblox.com/develop
--      (gratis & instan sebagai Decal), lalu masukkan Asset ID hasil upload
--      itu ke sini — bukan link Catbox-nya.
local function normalizeImageId(input)
    input = tostring(input):gsub("^%s+", ""):gsub("%s+$", "")
    if input:match("^rbxassetid://%d+$") then
        return input, nil
    end
    if input:match("^%d+$") then
        return "rbxassetid://" .. input, nil
    end
    if input:match("^https?://") then
        return nil, "Link eksternal (mis. Catbox) tidak bisa langsung ditampilkan Roblox.\n"
            .. "Upload dulu gambarnya ke roblox.com/develop (gratis, jadi Decal), "
            .. "lalu masukkan Asset ID hasil upload itu ke sini."
    end
    return nil, "Format tidak dikenali. Masukkan Asset ID Roblox (angka) atau rbxassetid://..."
end

local function spawnImage(imageInput, atCFrame)
    if not imageInput or imageInput == "" then return nil, "Input gambar kosong" end

    local imageId, err = normalizeImageId(imageInput)
    if not imageId then return nil, err end

    local part = Instance.new("Part")
    part.Name = "Model3D_Image"
    part.Size = Vector3.new(4, 4, 0.2)
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part:SetAttribute("Model3D_Kind", "image")
    part:SetAttribute("Model3D_ImageUrl", imageId)

    local gui = Instance.new("SurfaceGui")
    gui.Name = "ImageSurface"
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.AlwaysOnTop = false
    gui.PixelsPerStud = 50
    gui.Parent = part

    local img = Instance.new("ImageLabel")
    img.Name = "Img"
    img.Size = UDim2.new(1, 0, 1, 0)
    img.BackgroundTransparency = 1
    img.Image = imageId
    img.ScaleType = Enum.ScaleType.Fit
    img.Parent = gui

    -- Bungkus jadi Model supaya konsisten dengan objek model (PivotTo, dsb)
    local model = Instance.new("Model")
    model.Name = "Model3D_Image"
    model:SetAttribute("Model3D_Kind", "image")
    model:SetAttribute("Model3D_ImageUrl", imageId)
    part.Parent = model
    model.PrimaryPart = part

    model.Parent = getFolder()
    local baseCFrame = atCFrame or CFrame.new()
    pcall(function() model:PivotTo(baseCFrame) end)

    return model, nil
end

-- ==================== HAPUS OBJECT ====================
local function deleteObject(obj)
    if not obj then return end
    if State.SelectedObject == obj then
        State.SelectedObject = nil
        State.PositionMode = false
        State.RotationMode = false
        State.ScaleMode = false
    end
    pcall(function() obj:Destroy() end)
end

-- ==================== SCALE HELPER ====================
-- Menyimpan skala relatif per-object lewat attribute, supaya bisa dihitung
-- ulang tanpa distorsi berulang saat resize dipanggil banyak kali.
local function getObjectOriginalSize(obj)
    local stored = obj:GetAttribute("Model3D_OriginalSize")
    if stored then return stored end
    -- Hitung bounding box awal sekali saja lalu simpan.
    local ok, size = pcall(function()
        local _, sizeVec = obj:GetBoundingBox()
        return sizeVec
    end)
    if ok and size then
        obj:SetAttribute("Model3D_OriginalSize", size)
        return size
    end
    return Vector3.new(4, 4, 4)
end

local function applyScale(obj, scaleFactor)
    if not obj or not obj:IsA("Model") then return end
    scaleFactor = math.clamp(scaleFactor, 0.05, 50)
    local ok = pcall(function()
        obj:ScaleTo(scaleFactor)
    end)
    if ok then
        obj:SetAttribute("Model3D_Scale", scaleFactor)
    end
end

local function getObjectScale(obj)
    return obj:GetAttribute("Model3D_Scale") or 1
end

-- ==================== GIZMO SYSTEM ====================
local GizmoDragging = false
local CameraRestoreType, CameraRestoreSubject = nil, nil

local function lockCameraForDrag()
    local camera = Workspace.CurrentCamera
    if camera then
        CameraRestoreType = camera.CameraType
        CameraRestoreSubject = camera.CameraSubject
        camera.CameraType = Enum.CameraType.Scriptable
    end
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition end)
end

local function restoreCameraAfterDrag()
    local camera = Workspace.CurrentCamera
    if camera and CameraRestoreType then
        camera.CameraType = CameraRestoreType
        if CameraRestoreSubject and CameraRestoreSubject.Parent then
            camera.CameraSubject = CameraRestoreSubject
        end
    end
    pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
end

-- Helper: ambil BasePart representatif dari objek yang dipilih (Model).
-- SEMUA gizmo Roblox (Handles maupun ArcHandles) ternyata di executor ini
-- hanya menerima BasePart untuk Adornee, TIDAK menerima Model langsung
-- (walau di beberapa versi Roblox Handles bisa menerima Model, di sini
-- keduanya melempar "Expected BasePart got Model" kalau dikasih Model).
-- Jadi semua gizmo di bawah SELALU diberi PrimaryPart, bukan Model.
local function getAdorneePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function setGizmoVisibility()
    local target = getAdorneePart(State.SelectedObject)
    if Gizmos.Position then Gizmos.Position.Adornee = State.PositionMode and target or nil end
    if Gizmos.Rotation then Gizmos.Rotation.Adornee = State.RotationMode and target or nil end
    if Gizmos.Scale then Gizmos.Scale.Adornee = State.ScaleMode and target or nil end
end

local function initGizmos()
    pcall(function()
        if not Gizmos.Position or not Gizmos.Position.Parent then
            Gizmos.Position = Instance.new("Handles")
            Gizmos.Position.Style = Enum.HandlesStyle.Movement
            Gizmos.Position.Color3 = C.red
            Gizmos.Position.Parent = CoreGui
        end
        if not Gizmos.Rotation or not Gizmos.Rotation.Parent then
            Gizmos.Rotation = Instance.new("ArcHandles")
            Gizmos.Rotation.Color3 = C.accent
            Gizmos.Rotation.Parent = CoreGui
        end
        if not Gizmos.Scale or not Gizmos.Scale.Parent then
            Gizmos.Scale = Instance.new("Handles")
            Gizmos.Scale.Style = Enum.HandlesStyle.Resize
            Gizmos.Scale.Color3 = C.gold
            Gizmos.Scale.Parent = CoreGui
        end
    end)

    setGizmoVisibility()

    if Gizmos.Position and not Gizmos.Position:GetAttribute("Model3DConnected") then
        Gizmos.Position:SetAttribute("Model3DConnected", true)
        local dragStartCFrame = nil
        Gizmos.Position.MouseButton1Down:Connect(function()
            if not State.SelectedObject or not State.PositionMode then return end
            dragStartCFrame = State.SelectedObject:GetPivot()
            GizmoDragging = true
            lockCameraForDrag()
        end)
        Gizmos.Position.MouseDrag:Connect(function(face, distance)
            if not State.SelectedObject or not dragStartCFrame then return end
            local delta = Vector3.FromNormalId(face) * distance
            State.SelectedObject:PivotTo(dragStartCFrame * CFrame.new(delta))
        end)
        Gizmos.Position.MouseButton1Up:Connect(function()
            dragStartCFrame = nil
            GizmoDragging = false
            restoreCameraAfterDrag()
        end)
    end

    if Gizmos.Rotation and not Gizmos.Rotation:GetAttribute("Model3DConnected") then
        Gizmos.Rotation:SetAttribute("Model3DConnected", true)
        local rotStartCFrame = nil
        Gizmos.Rotation.MouseButton1Down:Connect(function()
            if not State.SelectedObject or not State.RotationMode then return end
            rotStartCFrame = State.SelectedObject:GetPivot()
            GizmoDragging = true
            lockCameraForDrag()
        end)
        Gizmos.Rotation.MouseDrag:Connect(function(axis, relativeAngle)
            if not State.SelectedObject or not rotStartCFrame then return end
            local axisVector = Vector3.FromAxis(axis)
            State.SelectedObject:PivotTo(rotStartCFrame * CFrame.fromAxisAngle(axisVector, relativeAngle))
        end)
        Gizmos.Rotation.MouseButton1Up:Connect(function()
            rotStartCFrame = nil
            GizmoDragging = false
            restoreCameraAfterDrag()
        end)
    end

    if Gizmos.Scale and not Gizmos.Scale:GetAttribute("Model3DConnected") then
        Gizmos.Scale:SetAttribute("Model3DConnected", true)
        local scaleStartValue = nil
        Gizmos.Scale.MouseButton1Down:Connect(function()
            if not State.SelectedObject or not State.ScaleMode then return end
            scaleStartValue = getObjectScale(State.SelectedObject)
            GizmoDragging = true
            lockCameraForDrag()
        end)
        Gizmos.Scale.MouseDrag:Connect(function(face, distance)
            if not State.SelectedObject or not scaleStartValue then return end
            -- distance dari Handles Resize dalam studs; ubah jadi faktor skala halus.
            local newScale = scaleStartValue + (distance * 0.15)
            applyScale(State.SelectedObject, newScale)
        end)
        Gizmos.Scale.MouseButton1Up:Connect(function()
            scaleStartValue = nil
            GizmoDragging = false
            restoreCameraAfterDrag()
        end)
    end
end

-- ==================== CONFIG BUILD/APPLY ====================
-- Membuat snapshot config dari SEMUA object yang sedang ada di folder Model3D.
local function buildConfigFromWorkspace(name)
    local folder = getFolder()
    local items = {}
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") then
            local kind = obj:GetAttribute("Model3D_Kind")
            local item = {
                kind   = kind,
                cframe = cframeToTable(obj:GetPivot()),
                scale  = getObjectScale(obj),
            }
            if kind == "model" then
                item.assetId = obj:GetAttribute("Model3D_AssetId")
            elseif kind == "image" then
                item.url = obj:GetAttribute("Model3D_ImageUrl")
            end
            table.insert(items, item)
        end
    end

    return {
        name        = name,
        ownerUserId = LocalPlayer.UserId,
        ownerName   = LocalPlayer.DisplayName,
        createdAt   = os.time(),
        items       = items,
        placeId     = game.PlaceId,
    }
end

-- Menghapus semua object Model3D yang sekarang ada di map lalu spawn ulang
-- sesuai isi config. Dipakai saat Load Config.
local function applyConfigToWorkspace(configData, callback)
    if not configData or type(configData) ~= "table" or not configData.items then
        if callback then callback(false, "Config kosong / rusak") end
        return
    end

    local folder = getFolder()
    for _, obj in ipairs(folder:GetChildren()) do
        obj:Destroy()
    end
    State.SelectedObject = nil
    State.PositionMode = false
    State.RotationMode = false
    State.ScaleMode = false
    setGizmoVisibility()

    local total = #configData.items
    local loaded = 0
    local failed = 0

    for _, item in ipairs(configData.items) do
        task.spawn(function()
            local cf = tableToCFrame(item.cframe)
            local obj, err
            if item.kind == "model" then
                obj, err = spawnModel3D(item.assetId, cf)
            elseif item.kind == "image" then
                obj, err = spawnImage(item.url, cf)
            end
            if obj then
                if item.scale and item.scale ~= 1 then
                    applyScale(obj, item.scale)
                end
                loaded = loaded + 1
            else
                failed = failed + 1
            end

            if loaded + failed >= total then
                if callback then callback(true, ("Selesai: %d berhasil, %d gagal"):format(loaded, failed)) end
            end
        end)
    end

    if total == 0 and callback then
        callback(true, "Config ini tidak berisi objek apapun.")
    end
end

-- ==================== SAVE / LOAD LOKAL ====================
local function saveConfigLocal(name)
    if not name or name == "" then return false, "Nama config kosong" end
    local configData = buildConfigFromWorkspace(name)
    LocalConfigs[name] = configData
    saveLocalConfigs(LocalConfigs)
    return true, "Config '" .. name .. "' tersimpan lokal (" .. #configData.items .. " objek)."
end

local function loadConfigLocal(name, callback)
    local data = LocalConfigs[name]
    if not data then
        if callback then callback(false, "Config tidak ditemukan") end
        return
    end
    applyConfigToWorkspace(data, callback)
end

local function deleteConfigLocal(name)
    LocalConfigs[name] = nil
    saveLocalConfigs(LocalConfigs)
end

-- ==================== SAVE / LOAD FIREBASE ====================
-- Developer: simpan ke model3d_dev (terlihat semua orang).
-- Player biasa: simpan ke model3d_player (hanya dirinya + dev yang bisa lihat).
local function saveConfigFirebase(name, callback)
    if not Firebase then
        if callback then callback(false, "Firebase tidak tersedia") end
        return
    end
    local configData = buildConfigFromWorkspace(name)

    task.spawn(function()
        local ok
        if isDeveloper then
            ok = Firebase.SaveDevModel3D(LocalPlayer.UserId, name, configData)
        else
            ok = Firebase.SavePlayerModel3D(LocalPlayer.UserId, name, configData)
        end
        if callback then
            if ok then
                callback(true, "Config '" .. name .. "' tersimpan online (" .. #configData.items .. " objek).")
            else
                callback(false, "Gagal menyimpan ke server.")
            end
        end
    end)
end

-- Mengambil daftar config developer (bisa dipanggil siapapun, termasuk player biasa).
local function fetchDevConfigs(callback)
    if not Firebase then callback(nil, "Firebase tidak tersedia") return end
    task.spawn(function()
        local list = Firebase.GetDevModel3DList(DEV_USER_ID)
        callback(list)
    end)
end

-- Mengambil daftar config milik player yang sedang login (dirinya sendiri).
local function fetchMyPlayerConfigs(callback)
    if not Firebase then callback(nil, "Firebase tidak tersedia") return end
    task.spawn(function()
        local list = Firebase.GetPlayerModel3DList(LocalPlayer.UserId)
        callback(list)
    end)
end

-- Khusus developer: ambil daftar SEMUA player yang punya config tersimpan,
-- supaya dev bisa browse & load config milik player manapun.
local function fetchAllPlayerConfigsForDev(callback)
    if not Firebase or not isDeveloper then callback(nil) return end
    task.spawn(function()
        local all = Firebase.GetAllPlayerModel3D()
        callback(all)
    end)
end

local function loadConfigFromFirebaseData(configData, callback)
    applyConfigToWorkspace(configData, callback)
end

-- ==================== UI STATE ====================
local rebuildUI

-- ==================== RENDER: HEADER ====================
local function renderHeader()
    local header = Instance.new("Frame", appContent)
    header.Size = UDim2.new(1, 0, 0, 50)
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

    local icon = Instance.new("TextLabel", header)
    icon.Size = UDim2.new(0, 34, 0, 34)
    icon.Position = UDim2.new(0, 8, 0.5, -17)
    icon.BackgroundColor3 = C.accent
    icon.Text = "🧊"
    icon.TextSize = 16
    corner(icon, 100)

    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -130, 0, 20)
    title.Position = UDim2.new(0, 50, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "Model 3D"
    title.TextColor3 = C.text
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left

    local sub = Instance.new("TextLabel", header)
    sub.Size = UDim2.new(1, -130, 0, 14)
    sub.Position = UDim2.new(0, 50, 0, 26)
    sub.BackgroundTransparency = 1
    sub.Text = isDeveloper and "👑 Mode Developer" or "Spawn model & gambar ke map"
    sub.TextColor3 = isDeveloper and C.gold or C.text3
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 9
    sub.TextXAlignment = Enum.TextXAlignment.Left

    local clearBtn = Instance.new("TextButton", header)
    clearBtn.Size = UDim2.new(0, 60, 0, 26)
    clearBtn.Position = UDim2.new(1, -68, 0.5, -13)
    clearBtn.BackgroundColor3 = C.red
    clearBtn.BackgroundTransparency = 0.85
    clearBtn.Text = "🗑 Clear"
    clearBtn.TextColor3 = C.red
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 9
    clearBtn.AutoButtonColor = false
    corner(clearBtn, 8)
    pressFX(clearBtn)
    clearBtn.MouseButton1Click:Connect(function()
        local folder = getFolder()
        for _, obj in ipairs(folder:GetChildren()) do obj:Destroy() end
        State.SelectedObject = nil
        State.PositionMode, State.RotationMode, State.ScaleMode = false, false, false
        setGizmoVisibility()
        Helpers.showDynamicNotification("Semua objek dihapus", C.red)
        rebuildUI()
    end)
end

-- ==================== RENDER: SECTION LABEL ====================
local function sectionLabel(text, order)
    local lbl = Instance.new("TextLabel", appContent)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.text2
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    return lbl
end

-- ==================== RENDER: SPAWN MODEL 3D ====================
local function renderSpawnModelSection(order)
    sectionLabel("SPAWN MODEL 3D (Asset ID)", order)

    local row = Instance.new("Frame", appContent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.card
    row.LayoutOrder = order + 1
    corner(row, 12)
    stroke(row, C.border, 1, 0.3)

    local input = Instance.new("TextBox", row)
    input.Size = UDim2.new(1, -96, 1, -12)
    input.Position = UDim2.new(0, 8, 0, 6)
    input.BackgroundColor3 = C.bg
    input.PlaceholderText = "Masukkan Asset ID model..."
    input.PlaceholderColor3 = C.text3
    input.Text = ""
    input.TextColor3 = C.text
    input.Font = Enum.Font.Code
    input.TextSize = 12
    input.ClearTextOnFocus = false
    corner(input, 8)
    local ip = Instance.new("UIPadding", input)
    ip.PaddingLeft = UDim.new(0, 8)

    local spawnBtn = Instance.new("TextButton", row)
    spawnBtn.Size = UDim2.new(0, 80, 1, -12)
    spawnBtn.Position = UDim2.new(1, -84, 0, 6)
    spawnBtn.BackgroundColor3 = C.accent
    spawnBtn.Text = "SPAWN"
    spawnBtn.TextColor3 = Color3.new(1, 1, 1)
    spawnBtn.Font = Enum.Font.GothamBlack
    spawnBtn.TextSize = 11
    spawnBtn.AutoButtonColor = false
    corner(spawnBtn, 8)
    pressFX(spawnBtn)

    local function doSpawn()
        local assetId = input.Text:gsub("%s+", "")
        if assetId == "" then return end

        local character = LocalPlayer.Character
        local baseCFrame = CFrame.new(0, 5, 0)
        if character and character:FindFirstChild("HumanoidRootPart") then
            baseCFrame = character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -8)
        end

        spawnBtn.Text = "..."
        task.spawn(function()
            local obj, err = spawnModel3D(assetId, baseCFrame)
            spawnBtn.Text = "SPAWN"
            if obj then
                State.SelectedObject = obj
                input.Text = ""
                Helpers.showDynamicNotification("Model berhasil di-spawn!", C.green)
                rebuildUI()
            else
                Helpers.showDynamicNotification(err or "Gagal spawn model", C.red)
            end
        end)
    end

    spawnBtn.MouseButton1Click:Connect(doSpawn)
    input.FocusLost:Connect(function(enter) if enter then doSpawn() end end)
end

-- ==================== RENDER: SPAWN GAMBAR ====================
local function renderSpawnImageSection(order)
    sectionLabel("SPAWN GAMBAR (Asset ID Roblox)", order)

    local row = Instance.new("Frame", appContent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.card
    row.LayoutOrder = order + 1
    corner(row, 12)
    stroke(row, C.border, 1, 0.3)

    local input = Instance.new("TextBox", row)
    input.Size = UDim2.new(1, -96, 1, -12)
    input.Position = UDim2.new(0, 8, 0, 6)
    input.BackgroundColor3 = C.bg
    input.PlaceholderText = "Asset ID (mis. 1818) atau rbxassetid://..."
    input.PlaceholderColor3 = C.text3
    input.Text = ""
    input.TextColor3 = C.text
    input.Font = Enum.Font.Code
    input.TextSize = 11
    input.ClearTextOnFocus = false
    corner(input, 8)
    local ip = Instance.new("UIPadding", input)
    ip.PaddingLeft = UDim.new(0, 8)

    local spawnBtn = Instance.new("TextButton", row)
    spawnBtn.Size = UDim2.new(0, 80, 1, -12)
    spawnBtn.Position = UDim2.new(1, -84, 0, 6)
    spawnBtn.BackgroundColor3 = C.accent2
    spawnBtn.Text = "SPAWN"
    spawnBtn.TextColor3 = Color3.new(0, 0, 0)
    spawnBtn.Font = Enum.Font.GothamBlack
    spawnBtn.TextSize = 11
    spawnBtn.AutoButtonColor = false
    corner(spawnBtn, 8)
    pressFX(spawnBtn)

    local function doSpawn()
        local url = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if url == "" then return end

        local character = LocalPlayer.Character
        local baseCFrame = CFrame.new(0, 5, 0)
        if character and character:FindFirstChild("HumanoidRootPart") then
            baseCFrame = character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -8)
        end

        local obj, err = spawnImage(url, baseCFrame)
        if obj then
            State.SelectedObject = obj
            input.Text = ""
            Helpers.showDynamicNotification("Gambar berhasil di-spawn!", C.green)
            rebuildUI()
        else
            Helpers.showDynamicNotification(err or "Gagal spawn gambar", C.red)
        end
    end

    spawnBtn.MouseButton1Click:Connect(doSpawn)
    input.FocusLost:Connect(function(enter) if enter then doSpawn() end end)

    local hint = Instance.new("TextLabel", appContent)
    hint.Size = UDim2.new(1, 0, 0, 28)
    hint.BackgroundTransparency = 1
    hint.Text = "Punya link Catbox? Upload dulu ke roblox.com/develop (gratis, jadi Decal), lalu masukkan Asset ID hasil upload itu di sini."
    hint.TextColor3 = C.text3
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 9
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.LayoutOrder = order + 2
end

-- ==================== RENDER: DAFTAR OBJEK DI MAP ====================
local function renderObjectListSection(order)
    local folder = getFolder()
    local objects = folder:GetChildren()

    sectionLabel("OBJEK DI MAP (" .. #objects .. ")", order)

    if #objects == 0 then
        local empty = Instance.new("TextLabel", appContent)
        empty.Size = UDim2.new(1, 0, 0, 40)
        empty.BackgroundTransparency = 1
        empty.Text = "Belum ada objek. Spawn model atau gambar di atas."
        empty.TextColor3 = C.text3
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 10
        empty.TextWrapped = true
        empty.LayoutOrder = order + 1
        return
    end

    for i, obj in ipairs(objects) do
        local isSelected = State.SelectedObject == obj
        local kind = obj:GetAttribute("Model3D_Kind") or "model"

        local row = Instance.new("Frame", appContent)
        row.Size = UDim2.new(1, 0, 0, 46)
        row.BackgroundColor3 = isSelected and C.card2 or C.card
        row.LayoutOrder = order + 1 + i
        corner(row, 10)
        stroke(row, isSelected and C.accent or C.border, isSelected and 1.5 or 1, isSelected and 0.1 or 0.3)

        local icon = Instance.new("TextLabel", row)
        icon.Size = UDim2.new(0, 34, 0, 34)
        icon.Position = UDim2.new(0, 6, 0.5, -17)
        icon.BackgroundColor3 = C.bg
        icon.Text = kind == "image" and "🖼️" or "🧊"
        icon.TextSize = 14
        corner(icon, 8)

        local nameLbl = Instance.new("TextLabel", row)
        nameLbl.Size = UDim2.new(1, -160, 0, 18)
        nameLbl.Position = UDim2.new(0, 46, 0, 6)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = obj.Name
        nameLbl.TextColor3 = C.text
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 11
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

        local scaleLbl = Instance.new("TextLabel", row)
        scaleLbl.Size = UDim2.new(1, -160, 0, 14)
        scaleLbl.Position = UDim2.new(0, 46, 0, 24)
        scaleLbl.BackgroundTransparency = 1
        scaleLbl.Text = ("Scale: %.2fx"):format(getObjectScale(obj))
        scaleLbl.TextColor3 = C.text3
        scaleLbl.Font = Enum.Font.Gotham
        scaleLbl.TextSize = 9
        scaleLbl.TextXAlignment = Enum.TextXAlignment.Left

        local selectBtn = Instance.new("TextButton", row)
        selectBtn.Size = UDim2.new(0, 60, 0, 34)
        selectBtn.Position = UDim2.new(1, -104, 0.5, -17)
        selectBtn.BackgroundColor3 = isSelected and C.accent or C.card2
        selectBtn.Text = isSelected and "DIPILIH" or "PILIH"
        selectBtn.TextColor3 = isSelected and Color3.new(1, 1, 1) or C.text2
        selectBtn.Font = Enum.Font.GothamBold
        selectBtn.TextSize = 9
        selectBtn.AutoButtonColor = false
        corner(selectBtn, 8)
        pressFX(selectBtn)
        selectBtn.MouseButton1Click:Connect(function()
            State.SelectedObject = isSelected and nil or obj
            setGizmoVisibility()
            rebuildUI()
        end)

        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(0, 34, 0, 34)
        delBtn.Position = UDim2.new(1, -40, 0.5, -17)
        delBtn.BackgroundColor3 = C.red
        delBtn.BackgroundTransparency = 0.85
        delBtn.Text = "🗑"
        delBtn.TextColor3 = C.red
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.AutoButtonColor = false
        corner(delBtn, 8)
        pressFX(delBtn)
        delBtn.MouseButton1Click:Connect(function()
            deleteObject(obj)
            rebuildUI()
        end)
    end
end

-- ==================== RENDER: GIZMO CONTROL PANEL ====================
local function renderGizmoSection(order)
    sectionLabel("GIZMO KONTROL", order)

    if not State.SelectedObject or not State.SelectedObject.Parent then
        local hint = Instance.new("TextLabel", appContent)
        hint.Size = UDim2.new(1, 0, 0, 30)
        hint.BackgroundTransparency = 1
        hint.Text = "Pilih objek di daftar atas untuk mengaktifkan gizmo."
        hint.TextColor3 = C.text3
        hint.Font = Enum.Font.Gotham
        hint.TextSize = 10
        hint.TextWrapped = true
        hint.LayoutOrder = order + 1
        return
    end

    local btnRow = Instance.new("Frame", appContent)
    btnRow.Size = UDim2.new(1, 0, 0, 44)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = order + 1

    local btnLayout = Instance.new("UIListLayout", btnRow)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 6)
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function gizmoToggleBtn(label, icon, isActive, color, onClick)
        local btn = Instance.new("TextButton", btnRow)
        btn.Size = UDim2.new(0, 96, 1, 0)
        btn.BackgroundColor3 = isActive and color or C.card
        btn.Text = ""
        btn.AutoButtonColor = false
        corner(btn, 12)
        stroke(btn, isActive and color or C.border, isActive and 1.5 or 1, isActive and 0 or 0.3)
        pressFX(btn)

        local iconLbl = Instance.new("TextLabel", btn)
        iconLbl.Size = UDim2.new(1, 0, 0, 20)
        iconLbl.Position = UDim2.new(0, 0, 0, 4)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextSize = 14

        local textLbl = Instance.new("TextLabel", btn)
        textLbl.Size = UDim2.new(1, 0, 0, 16)
        textLbl.Position = UDim2.new(0, 0, 0, 24)
        textLbl.BackgroundTransparency = 1
        textLbl.Text = label
        textLbl.TextColor3 = isActive and Color3.new(1, 1, 1) or C.text2
        textLbl.Font = Enum.Font.GothamBold
        textLbl.TextSize = 9

        btn.MouseButton1Click:Connect(onClick)
        return btn
    end

    gizmoToggleBtn("Posisi", "✥", State.PositionMode, C.red, function()
        State.PositionMode = not State.PositionMode
        if State.PositionMode then State.RotationMode = false; State.ScaleMode = false end
        setGizmoVisibility()
        rebuildUI()
    end)
    gizmoToggleBtn("Rotasi", "↻", State.RotationMode, C.accent, function()
        State.RotationMode = not State.RotationMode
        if State.RotationMode then State.PositionMode = false; State.ScaleMode = false end
        setGizmoVisibility()
        rebuildUI()
    end)
    gizmoToggleBtn("Ukuran", "⤢", State.ScaleMode, C.gold, function()
        State.ScaleMode = not State.ScaleMode
        if State.ScaleMode then State.PositionMode = false; State.RotationMode = false end
        setGizmoVisibility()
        rebuildUI()
    end)

    -- Slider skala manual (selain drag gizmo) supaya presisi
    local scaleRow = Instance.new("Frame", appContent)
    scaleRow.Size = UDim2.new(1, 0, 0, 44)
    scaleRow.BackgroundColor3 = C.card
    scaleRow.LayoutOrder = order + 2
    corner(scaleRow, 12)
    stroke(scaleRow, C.border, 1, 0.3)

    local currentScale = getObjectScale(State.SelectedObject)

    local scaleLabel = Instance.new("TextLabel", scaleRow)
    scaleLabel.Size = UDim2.new(0, 80, 1, 0)
    scaleLabel.Position = UDim2.new(0, 10, 0, 0)
    scaleLabel.BackgroundTransparency = 1
    scaleLabel.Text = ("%.2fx"):format(currentScale)
    scaleLabel.TextColor3 = C.gold
    scaleLabel.Font = Enum.Font.GothamBlack
    scaleLabel.TextSize = 13
    scaleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local minusBtn = Instance.new("TextButton", scaleRow)
    minusBtn.Size = UDim2.new(0, 36, 0, 34)
    minusBtn.Position = UDim2.new(1, -160, 0.5, -17)
    minusBtn.BackgroundColor3 = C.card2
    minusBtn.Text = "−"
    minusBtn.TextColor3 = C.text
    minusBtn.Font = Enum.Font.GothamBlack
    minusBtn.TextSize = 16
    minusBtn.AutoButtonColor = false
    corner(minusBtn, 8)
    pressFX(minusBtn)
    minusBtn.MouseButton1Click:Connect(function()
        applyScale(State.SelectedObject, getObjectScale(State.SelectedObject) - 0.1)
        rebuildUI()
    end)

    local plusBtn = Instance.new("TextButton", scaleRow)
    plusBtn.Size = UDim2.new(0, 36, 0, 34)
    plusBtn.Position = UDim2.new(1, -118, 0.5, -17)
    plusBtn.BackgroundColor3 = C.card2
    plusBtn.Text = "+"
    plusBtn.TextColor3 = C.text
    plusBtn.Font = Enum.Font.GothamBlack
    plusBtn.TextSize = 16
    plusBtn.AutoButtonColor = false
    corner(plusBtn, 8)
    pressFX(plusBtn)
    plusBtn.MouseButton1Click:Connect(function()
        applyScale(State.SelectedObject, getObjectScale(State.SelectedObject) + 0.1)
        rebuildUI()
    end)

    local resetBtn = Instance.new("TextButton", scaleRow)
    resetBtn.Size = UDim2.new(0, 68, 0, 34)
    resetBtn.Position = UDim2.new(1, -76, 0.5, -17)
    resetBtn.BackgroundColor3 = C.card2
    resetBtn.Text = "Reset 1x"
    resetBtn.TextColor3 = C.text2
    resetBtn.Font = Enum.Font.GothamBold
    resetBtn.TextSize = 9
    resetBtn.AutoButtonColor = false
    corner(resetBtn, 8)
    pressFX(resetBtn)
    resetBtn.MouseButton1Click:Connect(function()
        applyScale(State.SelectedObject, 1)
        rebuildUI()
    end)
end

-- ==================== RENDER: SAVE CONFIG ====================
local function renderSaveConfigSection(order)
    sectionLabel("SIMPAN CONFIG", order)

    local row = Instance.new("Frame", appContent)
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = C.card
    row.LayoutOrder = order + 1
    corner(row, 12)
    stroke(row, C.border, 1, 0.3)

    local input = Instance.new("TextBox", row)
    input.Size = UDim2.new(1, -96, 1, -12)
    input.Position = UDim2.new(0, 8, 0, 6)
    input.BackgroundColor3 = C.bg
    input.PlaceholderText = "Nama config (mis. 'Rumah Kayu')"
    input.PlaceholderColor3 = C.text3
    input.Text = ""
    input.TextColor3 = C.text
    input.Font = Enum.Font.Gotham
    input.TextSize = 11
    input.ClearTextOnFocus = false
    corner(input, 8)
    local ip = Instance.new("UIPadding", input)
    ip.PaddingLeft = UDim.new(0, 8)

    local saveBtn = Instance.new("TextButton", row)
    saveBtn.Size = UDim2.new(0, 80, 1, -12)
    saveBtn.Position = UDim2.new(1, -84, 0, 6)
    saveBtn.BackgroundColor3 = C.green
    saveBtn.Text = "SIMPAN"
    saveBtn.TextColor3 = Color3.new(0, 0, 0)
    saveBtn.Font = Enum.Font.GothamBlack
    saveBtn.TextSize = 11
    saveBtn.AutoButtonColor = false
    corner(saveBtn, 8)
    pressFX(saveBtn)

    local function doSave()
        local name = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then
            Helpers.showDynamicNotification("Isi nama config dulu", C.red)
            return
        end

        -- Simpan lokal (selalu, sebagai backup offline)
        local okLocal, msgLocal = saveConfigLocal(name)

        -- Simpan ke Firebase (dev -> visible semua, player biasa -> hanya dirinya)
        saveConfigFirebase(name, function(okOnline, msgOnline)
            if okOnline then
                Helpers.showDynamicNotification(msgOnline, C.green)
            else
                Helpers.showDynamicNotification(msgLocal .. " (gagal sync online)", C.gold)
            end
            input.Text = ""
            rebuildUI()
        end)
    end

    saveBtn.MouseButton1Click:Connect(doSave)
    input.FocusLost:Connect(function(enter) if enter then doSave() end end)
end

-- ==================== RENDER: LOAD CONFIG ====================
local configListCache = {local_=nil, dev=nil, mine=nil, allPlayers=nil}
local configListLoading = {mine=false, dev=false, allPlayers=false}

local function renderConfigRow(name, sourceLabel, sourceColor, onLoad, onDelete)
    local row = Instance.new("Frame", appContent)
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = C.card
    row.LayoutOrder = 9999 -- diisi ulang oleh caller lewat urutan penambahan
    corner(row, 10)
    stroke(row, C.border, 1, 0.3)

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -160, 0, 20)
    nameLbl.Position = UDim2.new(0, 10, 0, 5)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = name
    nameLbl.TextColor3 = C.text
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 11
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local tagLbl = Instance.new("TextLabel", row)
    tagLbl.Size = UDim2.new(1, -160, 0, 14)
    tagLbl.Position = UDim2.new(0, 10, 0, 24)
    tagLbl.BackgroundTransparency = 1
    tagLbl.Text = sourceLabel
    tagLbl.TextColor3 = sourceColor
    tagLbl.Font = Enum.Font.GothamBold
    tagLbl.TextSize = 8
    tagLbl.TextXAlignment = Enum.TextXAlignment.Left

    local loadBtn = Instance.new("TextButton", row)
    loadBtn.Size = UDim2.new(0, 70, 0, 34)
    loadBtn.Position = UDim2.new(1, -114, 0.5, -17)
    loadBtn.BackgroundColor3 = C.accent
    loadBtn.Text = "LOAD"
    loadBtn.TextColor3 = Color3.new(1, 1, 1)
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.TextSize = 10
    loadBtn.AutoButtonColor = false
    corner(loadBtn, 8)
    pressFX(loadBtn)
    loadBtn.MouseButton1Click:Connect(onLoad)

    if onDelete then
        local delBtn = Instance.new("TextButton", row)
        delBtn.Size = UDim2.new(0, 34, 0, 34)
        delBtn.Position = UDim2.new(1, -40, 0.5, -17)
        delBtn.BackgroundColor3 = C.red
        delBtn.BackgroundTransparency = 0.85
        delBtn.Text = "🗑"
        delBtn.TextColor3 = C.red
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 12
        delBtn.AutoButtonColor = false
        corner(delBtn, 8)
        pressFX(delBtn)
        delBtn.MouseButton1Click:Connect(onDelete)
    end

    return row
end

local function renderLoadConfigSection(order)
    sectionLabel("LOAD CONFIG", order)

    -- ===== FILTER TABS =====
    local tabs = {"Lokal", "Milikku (Online)", "Developer"}
    if isDeveloper then table.insert(tabs, "Semua Player") end

    local tabRow = Instance.new("Frame", appContent)
    tabRow.Size = UDim2.new(1, 0, 0, 30)
    tabRow.BackgroundTransparency = 1
    tabRow.LayoutOrder = order + 1

    local tabScroll = Instance.new("ScrollingFrame", tabRow)
    tabScroll.Size = UDim2.new(1, 0, 1, 0)
    tabScroll.BackgroundTransparency = 1
    tabScroll.ScrollBarThickness = 0
    tabScroll.ScrollingDirection = Enum.ScrollingDirection.X
    tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

    local tabLayout = Instance.new("UIListLayout", tabScroll)
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 6)

    for _, tabName in ipairs(tabs) do
        local isActive = State.ConfigFilter == tabName
        local chip = Instance.new("TextButton", tabScroll)
        chip.Size = UDim2.new(0, 0, 1, 0)
        chip.AutomaticSize = Enum.AutomaticSize.X
        chip.BackgroundColor3 = isActive and C.accent or C.card
        chip.Text = ""
        chip.AutoButtonColor = false
        corner(chip, 100)
        stroke(chip, isActive and C.accent or C.border, 1, isActive and 0 or 0.3)
        pressFX(chip)

        local chipPad = Instance.new("UIPadding", chip)
        chipPad.PaddingLeft = UDim.new(0, 12); chipPad.PaddingRight = UDim.new(0, 12)

        local chipLbl = Instance.new("TextLabel", chip)
        chipLbl.Size = UDim2.new(0, 0, 1, 0)
        chipLbl.AutomaticSize = Enum.AutomaticSize.X
        chipLbl.BackgroundTransparency = 1
        chipLbl.Text = tabName
        chipLbl.TextColor3 = isActive and Color3.new(1, 1, 1) or C.text2
        chipLbl.Font = Enum.Font.GothamBold
        chipLbl.TextSize = 9

        chip.MouseButton1Click:Connect(function()
            State.ConfigFilter = tabName
            State.BrowsePlayerUserId = nil
            rebuildUI()
        end)
    end

    -- ===== KONTEN SESUAI FILTER =====
    local baseOrder = order + 2

    if State.ConfigFilter == "Lokal" then
        local names = {}
        for name in pairs(LocalConfigs) do table.insert(names, name) end
        table.sort(names)

        if #names == 0 then
            local empty = Instance.new("TextLabel", appContent)
            empty.Size = UDim2.new(1, 0, 0, 30)
            empty.BackgroundTransparency = 1
            empty.Text = "Belum ada config lokal tersimpan."
            empty.TextColor3 = C.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 10
            empty.LayoutOrder = baseOrder
        else
            for i, name in ipairs(names) do
                local row = renderConfigRow(name, "💾 Lokal (device ini saja)", C.text3,
                    function()
                        loadConfigLocal(name, function(ok, msg)
                            Helpers.showDynamicNotification(msg, ok and C.green or C.red)
                            rebuildUI()
                        end)
                    end,
                    function()
                        deleteConfigLocal(name)
                        Helpers.showDynamicNotification("Config lokal dihapus", C.red)
                        rebuildUI()
                    end
                )
                row.LayoutOrder = baseOrder + i
            end
        end

    elseif State.ConfigFilter == "Milikku (Online)" then
        if not Firebase then
            local empty = Instance.new("TextLabel", appContent)
            empty.Size = UDim2.new(1, 0, 0, 30)
            empty.BackgroundTransparency = 1
            empty.Text = "Firebase tidak tersedia."
            empty.TextColor3 = C.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 10
            empty.LayoutOrder = baseOrder
        else
            local loadingLbl = Instance.new("TextLabel", appContent)
            loadingLbl.Size = UDim2.new(1, 0, 0, 30)
            loadingLbl.BackgroundTransparency = 1
            loadingLbl.Text = "Memuat config online kamu..."
            loadingLbl.TextColor3 = C.text3
            loadingLbl.Font = Enum.Font.Gotham
            loadingLbl.TextSize = 10
            loadingLbl.LayoutOrder = baseOrder

            if not configListLoading.mine and configListCache.mine == nil then
                configListLoading.mine = true
                fetchMyPlayerConfigs(function(list)
                    configListCache.mine = list or {}
                    configListLoading.mine = false
                    rebuildUI()
                end)
            end

            if configListCache.mine ~= nil then
                pcall(function() loadingLbl:Destroy() end)
                local list = configListCache.mine
                local names = {}
                if list and type(list) == "table" then
                    for configId, data in pairs(list) do table.insert(names, {id = configId, data = data}) end
                end
                table.sort(names, function(a, b) return (a.data.name or a.id) < (b.data.name or b.id) end)

                if #names == 0 then
                    local empty = Instance.new("TextLabel", appContent)
                    empty.Size = UDim2.new(1, 0, 0, 30)
                    empty.BackgroundTransparency = 1
                    empty.Text = "Belum ada config online milikmu."
                    empty.TextColor3 = C.text3
                    empty.Font = Enum.Font.Gotham
                    empty.TextSize = 10
                    empty.LayoutOrder = baseOrder
                else
                    for i, entry in ipairs(names) do
                        local row = renderConfigRow(entry.data.name or entry.id, "☁️ Online · hanya kamu yang lihat", C.accent2,
                            function()
                                loadConfigFromFirebaseData(entry.data, function(ok, msg)
                                    Helpers.showDynamicNotification(msg, ok and C.green or C.red)
                                    rebuildUI()
                                end)
                            end,
                            function()
                                task.spawn(function()
                                    Firebase.DeletePlayerModel3D(LocalPlayer.UserId, entry.id)
                                    configListCache.mine = nil
                                    Helpers.showDynamicNotification("Config online dihapus", C.red)
                                    rebuildUI()
                                end)
                            end
                        )
                        row.LayoutOrder = baseOrder + i
                    end
                end
            end
        end

    elseif State.ConfigFilter == "Developer" then
        if not Firebase or not DEV_USER_ID then
            local empty = Instance.new("TextLabel", appContent)
            empty.Size = UDim2.new(1, 0, 0, 30)
            empty.BackgroundTransparency = 1
            empty.Text = "Firebase / Developer ID tidak dikonfigurasi."
            empty.TextColor3 = C.text3
            empty.Font = Enum.Font.Gotham
            empty.TextSize = 10
            empty.LayoutOrder = baseOrder
        else
            local loadingLbl = Instance.new("TextLabel", appContent)
            loadingLbl.Size = UDim2.new(1, 0, 0, 30)
            loadingLbl.BackgroundTransparency = 1
            loadingLbl.Text = "Memuat config dari developer..."
            loadingLbl.TextColor3 = C.text3
            loadingLbl.Font = Enum.Font.Gotham
            loadingLbl.TextSize = 10
            loadingLbl.LayoutOrder = baseOrder

            if not configListLoading.dev and configListCache.dev == nil then
                configListLoading.dev = true
                fetchDevConfigs(function(list)
                    configListCache.dev = list or {}
                    configListLoading.dev = false
                    rebuildUI()
                end)
            end

            if configListCache.dev ~= nil then
                pcall(function() loadingLbl:Destroy() end)
                local list = configListCache.dev
                local names = {}
                if list and type(list) == "table" then
                    for configId, data in pairs(list) do table.insert(names, {id = configId, data = data}) end
                end
                table.sort(names, function(a, b) return (a.data.name or a.id) < (b.data.name or b.id) end)

                if #names == 0 then
                    local empty = Instance.new("TextLabel", appContent)
                    empty.Size = UDim2.new(1, 0, 0, 30)
                    empty.BackgroundTransparency = 1
                    empty.Text = "Developer belum menyimpan config apapun."
                    empty.TextColor3 = C.text3
                    empty.Font = Enum.Font.Gotham
                    empty.TextSize = 10
                    empty.LayoutOrder = baseOrder
                else
                    for i, entry in ipairs(names) do
                        local canDelete = isDeveloper
                        local row = renderConfigRow(entry.data.name or entry.id, "👑 Developer · terlihat semua pemain", C.gold,
                            function()
                                loadConfigFromFirebaseData(entry.data, function(ok, msg)
                                    Helpers.showDynamicNotification(msg, ok and C.green or C.red)
                                    rebuildUI()
                                end)
                            end,
                            canDelete and function()
                                task.spawn(function()
                                    Firebase.DeleteDevModel3D(DEV_USER_ID, entry.id)
                                    configListCache.dev = nil
                                    Helpers.showDynamicNotification("Config developer dihapus", C.red)
                                    rebuildUI()
                                end)
                            end or nil
                        )
                        row.LayoutOrder = baseOrder + i
                    end
                end
            end
        end

    elseif State.ConfigFilter == "Semua Player" and isDeveloper then
        -- Khusus developer: browse config milik player manapun yang pernah menyimpan.
        if not State.BrowsePlayerUserId then
            local loadingLbl = Instance.new("TextLabel", appContent)
            loadingLbl.Size = UDim2.new(1, 0, 0, 30)
            loadingLbl.BackgroundTransparency = 1
            loadingLbl.Text = "Memuat daftar player yang punya config..."
            loadingLbl.TextColor3 = C.text3
            loadingLbl.Font = Enum.Font.Gotham
            loadingLbl.TextSize = 10
            loadingLbl.LayoutOrder = baseOrder

            if not configListLoading.allPlayers and configListCache.allPlayers == nil then
                configListLoading.allPlayers = true
                fetchAllPlayerConfigsForDev(function(all)
                    configListCache.allPlayers = all or {}
                    configListLoading.allPlayers = false
                    rebuildUI()
                end)
            end

            if configListCache.allPlayers ~= nil then
                pcall(function() loadingLbl:Destroy() end)
                local all = configListCache.allPlayers
                local userIds = {}
                for uid in pairs(all) do table.insert(userIds, uid) end
                table.sort(userIds)

                if #userIds == 0 then
                    local empty = Instance.new("TextLabel", appContent)
                    empty.Size = UDim2.new(1, 0, 0, 30)
                    empty.BackgroundTransparency = 1
                    empty.Text = "Belum ada player yang menyimpan config."
                    empty.TextColor3 = C.text3
                    empty.Font = Enum.Font.Gotham
                    empty.TextSize = 10
                    empty.LayoutOrder = baseOrder
                else
                    for i, uid in ipairs(userIds) do
                        local configs = all[uid]
                        local count = 0
                        local ownerName = uid
                        if type(configs) == "table" then
                            for _, c in pairs(configs) do
                                count = count + 1
                                if type(c) == "table" and c.ownerName then ownerName = c.ownerName end
                            end
                        end

                        local row = Instance.new("Frame", appContent)
                        row.Size = UDim2.new(1, 0, 0, 46)
                        row.BackgroundColor3 = C.card
                        row.LayoutOrder = baseOrder + i
                        corner(row, 10)
                        stroke(row, C.border, 1, 0.3)

                        local nameLbl = Instance.new("TextLabel", row)
                        nameLbl.Size = UDim2.new(1, -90, 0, 20)
                        nameLbl.Position = UDim2.new(0, 10, 0, 5)
                        nameLbl.BackgroundTransparency = 1
                        nameLbl.Text = ownerName
                        nameLbl.TextColor3 = C.text
                        nameLbl.Font = Enum.Font.GothamBold
                        nameLbl.TextSize = 11
                        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

                        local tagLbl = Instance.new("TextLabel", row)
                        tagLbl.Size = UDim2.new(1, -90, 0, 14)
                        tagLbl.Position = UDim2.new(0, 10, 0, 24)
                        tagLbl.BackgroundTransparency = 1
                        tagLbl.Text = "UserId " .. tostring(uid) .. " · " .. count .. " config"
                        tagLbl.TextColor3 = C.text3
                        tagLbl.Font = Enum.Font.Gotham
                        tagLbl.TextSize = 8
                        tagLbl.TextXAlignment = Enum.TextXAlignment.Left

                        local browseBtn = Instance.new("TextButton", row)
                        browseBtn.Size = UDim2.new(0, 70, 0, 34)
                        browseBtn.Position = UDim2.new(1, -78, 0.5, -17)
                        browseBtn.BackgroundColor3 = C.accent
                        browseBtn.Text = "BUKA"
                        browseBtn.TextColor3 = Color3.new(1, 1, 1)
                        browseBtn.Font = Enum.Font.GothamBold
                        browseBtn.TextSize = 10
                        browseBtn.AutoButtonColor = false
                        corner(browseBtn, 8)
                        pressFX(browseBtn)
                        browseBtn.MouseButton1Click:Connect(function()
                            State.BrowsePlayerUserId = uid
                            rebuildUI()
                        end)
                    end
                end
            end
        else
            -- Sedang browse config milik 1 player tertentu
            local backBtn = Instance.new("TextButton", appContent)
            backBtn.Size = UDim2.new(0, 100, 0, 26)
            backBtn.BackgroundColor3 = C.card2
            backBtn.Text = "← Daftar Player"
            backBtn.TextColor3 = C.text2
            backBtn.Font = Enum.Font.GothamBold
            backBtn.TextSize = 9
            backBtn.AutoButtonColor = false
            backBtn.LayoutOrder = baseOrder
            corner(backBtn, 8)
            pressFX(backBtn)
            backBtn.MouseButton1Click:Connect(function()
                State.BrowsePlayerUserId = nil
                rebuildUI()
            end)

            local configs = configListCache.allPlayers and configListCache.allPlayers[State.BrowsePlayerUserId]
            local names = {}
            if type(configs) == "table" then
                for configId, data in pairs(configs) do table.insert(names, {id = configId, data = data}) end
            end
            table.sort(names, function(a, b) return (a.data.name or a.id) < (b.data.name or b.id) end)

            if #names == 0 then
                local empty = Instance.new("TextLabel", appContent)
                empty.Size = UDim2.new(1, 0, 0, 30)
                empty.BackgroundTransparency = 1
                empty.Text = "Player ini tidak punya config."
                empty.TextColor3 = C.text3
                empty.Font = Enum.Font.Gotham
                empty.TextSize = 10
                empty.LayoutOrder = baseOrder + 1
            else
                for i, entry in ipairs(names) do
                    local row = renderConfigRow(entry.data.name or entry.id, "🙋 Milik player · dev bisa load", C.green,
                        function()
                            loadConfigFromFirebaseData(entry.data, function(ok, msg)
                                Helpers.showDynamicNotification(msg, ok and C.green or C.red)
                                rebuildUI()
                            end)
                        end,
                        nil -- dev tidak menghapus config milik player lain dari sini
                    )
                    row.LayoutOrder = baseOrder + 1 + i
                end
            end
        end
    end
end

-- ==================== MAIN REBUILD ====================
local function clearAppContentLocal()
    for _, c in ipairs(appContent:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
end

rebuildUI = function()
    clearAppContentLocal()
    initGizmos()

    renderHeader()
    renderSpawnModelSection(1)
    renderSpawnImageSection(3)
    renderObjectListSection(6)
    renderGizmoSection(8)
    renderSaveConfigSection(11)
    renderLoadConfigSection(13)
end

-- ==================== BUKA APP ====================
function _G.openModel3DApp()
    -- Reset cache config online setiap kali app dibuka supaya datanya fresh,
    -- tapi TIDAK mereset objek yang sudah di-spawn di map (itu persist).
    configListCache = {local_=nil, dev=nil, mine=nil, allPlayers=nil}
    configListLoading = {mine=false, dev=false, allPlayers=false}
    rebuildUI()
end

print("[Model3D] Loaded! Siap spawn model & gambar ke map.")
