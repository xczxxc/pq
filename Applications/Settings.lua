-- AvatarClone / PhoneIDViewer — Premium Settings v3.0
local Services = _G.Services or {}
local LocalPlayer = _G.LocalPlayer or game:GetService("Players").LocalPlayer
local Helpers = _G.Helpers or {}
local Storage = _G.Storage or {}
local Firebase = _G.Firebase
local Config = _G.Config or {}
local T = _G.T or {}
local appContent = _G.appContent
local TeleportService = Services.TeleportService or game:GetService("TeleportService")

local corner = Helpers.corner or function(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 10); return c end
local stroke = Helpers.stroke or function(o,c,t,tr) local s=Instance.new("UIStroke",o); s.Color=c; s.Thickness=t or 1; s.Transparency=tr or 0; return s end
local pressFX = Helpers.pressFX or function() end
local tween = Helpers.tween or function(o,p,t) game:GetService("TweenService"):Create(o,TweenInfo.new(t or .2),p):Play() end

local C = {
    bg = T.BG or Color3.fromRGB(248,249,252), card = T.Card or Color3.fromRGB(255,255,255),
    card2 = T.Card2 or Color3.fromRGB(242,244,248), border = T.Border or Color3.fromRGB(220,223,230),
    text = T.Text or Color3.fromRGB(20,22,28), sub = T.Text2 or Color3.fromRGB(105,110,122),
    muted = Color3.fromRGB(155,160,172), accent = T.Accent or Color3.fromRGB(35,95,255),
    green = T.Green or Color3.fromRGB(25,185,105), red = T.Red or Color3.fromRGB(235,65,75),
    gold = T.Gold or Color3.fromRGB(235,165,35), purple = Color3.fromRGB(132,82,255), cyan = Color3.fromRGB(30,170,220)
}

local function notify(msg,col) if _G.showDynamicNotification then _G.showDynamicNotification(msg,col or C.accent) end end
local function save() pcall(function() if Storage.persistSettings then Storage.persistSettings() end end) end

local function clearOld(name)
    local old = appContent:FindFirstChild(name)
    if old then old:Destroy() end
end

local function section(title, subtitle, order)
    local f=Instance.new("Frame",appContent); f.Name="Section_"..order; f.Size=UDim2.new(1,0,0,0); f.AutomaticSize=Enum.AutomaticSize.Y; f.BackgroundTransparency=1; f.LayoutOrder=order
    local h=Instance.new("TextLabel",f); h.Size=UDim2.new(1,0,0,22); h.BackgroundTransparency=1; h.Text=title; h.TextColor3=C.text; h.Font=Enum.Font.GothamBlack; h.TextSize=13; h.TextXAlignment=Enum.TextXAlignment.Left
    if subtitle then local s=Instance.new("TextLabel",f); s.Size=UDim2.new(1,0,0,18); s.Position=UDim2.new(0,0,0,20); s.BackgroundTransparency=1; s.Text=subtitle; s.TextColor3=C.sub; s.Font=Enum.Font.Gotham; s.TextSize=9; s.TextXAlignment=Enum.TextXAlignment.Left end
    local l=Instance.new("UIListLayout",f); l.Padding=UDim.new(0,7); l.SortOrder=Enum.SortOrder.LayoutOrder
    return f
end

local function card(parent,order,height)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,height or 0); f.AutomaticSize=height and Enum.AutomaticSize.None or Enum.AutomaticSize.Y; f.BackgroundColor3=C.card; f.BorderSizePixel=0; f.LayoutOrder=order; corner(f,16); stroke(f,C.border,1,.35)
    local p=Instance.new("UIPadding",f); p.PaddingTop=UDim.new(0,10); p.PaddingBottom=UDim.new(0,10); p.PaddingLeft=UDim.new(0,12); p.PaddingRight=UDim.new(0,12)
    local l=Instance.new("UIListLayout",f); l.Padding=UDim.new(0,5); l.SortOrder=Enum.SortOrder.LayoutOrder
    return f
end

local function row(parent,order,title,sub,icon,col,callback)
    local b=Instance.new("TextButton",parent); b.Size=UDim2.new(1,0,0,54); b.BackgroundTransparency=1; b.Text=""; b.AutoButtonColor=false; b.LayoutOrder=order; pressFX(b)
    local ib=Instance.new("Frame",b); ib.Size=UDim2.new(0,38,0,38); ib.Position=UDim2.new(0,0,.5,-19); ib.BackgroundColor3=col or C.accent; ib.BackgroundTransparency=.86; corner(ib,11)
    local il=Instance.new("TextLabel",ib); il.Size=UDim2.new(1,0,1,0); il.BackgroundTransparency=1; il.Text=icon or "•"; il.TextColor3=col or C.accent; il.Font=Enum.Font.GothamBlack; il.TextSize=17
    local t=Instance.new("TextLabel",b); t.Size=UDim2.new(1,-70,0,19); t.Position=UDim2.new(0,49,0,7); t.BackgroundTransparency=1; t.Text=title; t.TextColor3=C.text; t.Font=Enum.Font.GothamBold; t.TextSize=11; t.TextXAlignment=Enum.TextXAlignment.Left
    local s=Instance.new("TextLabel",b); s.Size=UDim2.new(1,-70,0,17); s.Position=UDim2.new(0,49,0,27); s.BackgroundTransparency=1; s.Text=sub or ""; s.TextColor3=C.sub; s.Font=Enum.Font.Gotham; s.TextSize=8; s.TextXAlignment=Enum.TextXAlignment.Left
    local ch=Instance.new("TextLabel",b); ch.Size=UDim2.new(0,18,1,0); ch.Position=UDim2.new(1,-18,0,0); ch.BackgroundTransparency=1; ch.Text=">"; ch.TextColor3=C.muted; ch.Font=Enum.Font.GothamBold; ch.TextSize=16
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

local function toggleRow(parent,order,title,sub,key,accent)
    local b=Instance.new("Frame",parent); b.Size=UDim2.new(1,0,0,54); b.BackgroundTransparency=1; b.LayoutOrder=order
    local t=Instance.new("TextLabel",b); t.Size=UDim2.new(1,-62,0,19); t.Position=UDim2.new(0,0,0,6); t.BackgroundTransparency=1; t.Text=title; t.TextColor3=C.text; t.Font=Enum.Font.GothamBold; t.TextSize=11; t.TextXAlignment=Enum.TextXAlignment.Left
    local s=Instance.new("TextLabel",b); s.Size=UDim2.new(1,-62,0,17); s.Position=UDim2.new(0,0,0,27); s.BackgroundTransparency=1; s.Text=sub; s.TextColor3=C.sub; s.Font=Enum.Font.Gotham; s.TextSize=8; s.TextXAlignment=Enum.TextXAlignment.Left
    local val=Storage.appSettings[key] == true
    local tr=Instance.new("Frame",b); tr.Size=UDim2.new(0,46,0,26); tr.Position=UDim2.new(1,-46,.5,-13); tr.BackgroundColor3=val and (accent or C.accent) or Color3.fromRGB(195,199,207); corner(tr,100)
    local kn=Instance.new("Frame",tr); kn.Size=UDim2.new(0,22,0,22); kn.Position=val and UDim2.new(1,-24,.5,-11) or UDim2.new(0,2,.5,-11); kn.BackgroundColor3=Color3.new(1,1,1); corner(kn,100)
    local bt=Instance.new("TextButton",tr); bt.Size=UDim2.new(1,0,1,0); bt.BackgroundTransparency=1; bt.Text=""
    bt.MouseButton1Click:Connect(function() val=not val; Storage.appSettings[key]=val; save(); tween(tr,{BackgroundColor3=val and (accent or C.accent) or Color3.fromRGB(195,199,207)},.16); tween(kn,{Position=val and UDim2.new(1,-24,.5,-11) or UDim2.new(0,2,.5,-11)},.16); notify(title..(val and " ON" or " OFF"),accent or C.accent) end)
end

local function stat(parent,order,title,value,col)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(.5,-4,0,58); f.BackgroundColor3=C.card2; f.BorderSizePixel=0; f.LayoutOrder=order; corner(f,13)
    local v=Instance.new("TextLabel",f); v.Size=UDim2.new(1,-14,0,25); v.Position=UDim2.new(0,7,0,7); v.BackgroundTransparency=1; v.Text=value; v.TextColor3=col or C.text; v.Font=Enum.Font.GothamBlack; v.TextSize=16; v.TextXAlignment=Enum.TextXAlignment.Left
    local t=Instance.new("TextLabel",f); t.Size=UDim2.new(1,-14,0,16); t.Position=UDim2.new(0,7,0,34); t.BackgroundTransparency=1; t.Text=title; t.TextColor3=C.sub; t.Font=Enum.Font.Gotham; t.TextSize=8; t.TextXAlignment=Enum.TextXAlignment.Left
end

function _G.openSettingsApp()
    pcall(function()
        local hero=section("SETTINGS", "Personalize PhoneIDViewer tanpa masuk menu yang berantakan.", 1)
        local hc=card(hero,1)
        local banner=Instance.new("Frame",hc); banner.Size=UDim2.new(1,0,0,78); banner.BackgroundColor3=C.accent; banner.BorderSizePixel=0; corner(banner,16)
        local g=Instance.new("UIGradient",banner); g.Color=ColorSequence.new(C.accent,C.purple); g.Rotation=25
        local title=Instance.new("TextLabel",banner); title.Size=UDim2.new(1,-24,0,25); title.Position=UDim2.new(0,12,0,11); title.BackgroundTransparency=1; title.Text="PHONE • CONTROL CENTER"; title.TextColor3=Color3.new(1,1,1); title.Font=Enum.Font.GothamBlack; title.TextSize=14; title.TextXAlignment=Enum.TextXAlignment.Left
        local sub=Instance.new("TextLabel",banner); sub.Size=UDim2.new(1,-24,0,25); sub.Position=UDim2.new(0,12,0,37); sub.BackgroundTransparency=1; sub.Text="Appearance, behavior, access & quick actions"; sub.TextColor3=Color3.new(1,1,1); sub.TextTransparency=.15; sub.Font=Enum.Font.Gotham; sub.TextSize=9; sub.TextXAlignment=Enum.TextXAlignment.Left

        local app=section("APPEARANCE", "Tampilan dan pengalaman penggunaan.", 2)
        local ac=card(app,1)
        toggleRow(ac,1,"Glow Effects","Efek visual tombol dan panel", "glowEnabled",C.purple)
        toggleRow(ac,2,"Toast Notifications","Tampilkan notifikasi kecil saat aksi selesai", "toastEnabled",C.accent)
        toggleRow(ac,3,"Button Feedback","Animasi tekan pada tombol", "buttonSounds",C.cyan)
        row(ac,4,"Open Appearance","Tema, wallpaper, opacity & visual preset","✦",C.purple,function() if _G.openApp and _G.openAppearanceApp then _G.openApp("Appearance",_G.openAppearanceApp) end end)

        local keySec=section("ACCESS", "Akses lokal — tidak membutuhkan Firebase atau access key.", 3)
        local kc=card(keySec,1)
        local status=Instance.new("Frame",kc); status.Size=UDim2.new(1,0,0,84); status.BackgroundColor3=C.card2; status.BorderSizePixel=0; corner(status,14)
        local badge=Instance.new("TextLabel",status); badge.Size=UDim2.new(0,72,0,22); badge.Position=UDim2.new(0,10,0,10); badge.BackgroundColor3=C.green; badge.Text="LOCAL"; badge.TextColor3=Color3.new(1,1,1); badge.Font=Enum.Font.GothamBlack; badge.TextSize=8; corner(badge,8)
        local timer=Instance.new("TextLabel",status); timer.Size=UDim2.new(1,-100,0,32); timer.Position=UDim2.new(0,10,0,38); timer.BackgroundTransparency=1; timer.Text="UNLIMITED"; timer.TextColor3=C.text; timer.Font=Enum.Font.GothamBlack; timer.TextSize=20; timer.TextXAlignment=Enum.TextXAlignment.Left
        local detail=Instance.new("TextLabel",status); detail.Size=UDim2.new(0,150,0,20); detail.Position=UDim2.new(1,-160,0,10); detail.BackgroundTransparency=1; detail.Text="NO KEY REQUIRED"; detail.TextColor3=C.sub; detail.Font=Enum.Font.Code; detail.TextSize=8; detail.TextXAlignment=Enum.TextXAlignment.Right
        row(kc,2,"Access Mode","Local access is enabled for this build","✓",C.green,function() notify("Local access active",C.green) end)

        local quick=section("QUICK ACTIONS", "Aksi yang sering dipakai.", 4)
        local qc=card(quick,1)
        row(qc,1,"Rejoin Server","Masuk kembali ke instance sekarang","↻",C.accent,function() pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId) end) end)
        row(qc,2,"Copy User ID","Salin Roblox UserId","ID",C.cyan,function() pcall(function() Helpers.copyToClipboard(tostring(LocalPlayer.UserId)) end); notify("User ID copied",C.cyan) end)
        row(qc,3,"Copy Job ID","Salin instance JobId untuk debugging","#",C.purple,function() pcall(function() Helpers.copyToClipboard(tostring(game.JobId)) end); notify("Job ID copied",C.purple) end)
        row(qc,4,"Copy User Name","Salin username Roblox","@",C.gold,function() pcall(function() Helpers.copyToClipboard(tostring(LocalPlayer.Name)) end); notify("Username copied",C.gold) end)

        local dev=section("DEVELOPER", "Informasi build dan project.", 5)
        local dc=card(dev,1)
        local grid=Instance.new("Frame",dc); grid.Size=UDim2.new(1,0,0,58); grid.BackgroundTransparency=1; grid.LayoutOrder=1
        local gl=Instance.new("UIGridLayout",grid); gl.CellSize=UDim2.new(.5,-4,1,0); gl.CellPadding=UDim2.new(0,8,0,0)
        stat(grid,1,"VERSION","3.0",C.accent); stat(grid,2,"MODULES","25+",C.purple)
        row(dc,2,"Developer","@"..tostring(Config.DEVELOPER_USERNAME or "AlfreadR0rw"),"◆",C.gold,function() pcall(function() Helpers.copyToClipboard(tostring(Config.DEVELOPER_USERNAME or "AlfreadR0rw")) end); notify("Developer copied",C.gold) end)
        row(dc,3,"Reset UI Settings","Kembalikan preferensi visual ke default","↺",C.red,function() for _,k in ipairs({"glowEnabled","toastEnabled","buttonSounds","phoneOpacity","themeIndex","wallpaperUrl"}) do Storage.appSettings[k]=nil end; save(); notify("UI settings reset",C.red) end)

        local foot=section("ABOUT", "AvatarClone • PhoneIDViewer", 6)
        local fc=card(foot,1)
        local l=Instance.new("TextLabel",fc); l.Size=UDim2.new(1,0,0,42); l.BackgroundTransparency=1; l.Text="Premium modular phone interface\nBuilt for fast avatar, clone, social & utility workflows."; l.TextColor3=C.sub; l.Font=Enum.Font.Gotham; l.TextSize=9; l.TextWrapped=true; l.TextXAlignment=Enum.TextXAlignment.Left
    end)
end

print("[Settings] Premium v3 loaded")
