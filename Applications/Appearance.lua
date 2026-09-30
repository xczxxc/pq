-- AvatarClone — Appearance / Theme app
local H=_G.Helpers or {}; local T=_G.T or {}; local S=_G.Storage or {}; local appContent=_G.appContent
local function corner(o,r) return H.corner and H.corner(o,r) end
local function stroke(o,c,t,tr) return H.stroke and H.stroke(o,c,t,tr) end
local function notify(s,c) if _G.showDynamicNotification then _G.showDynamicNotification(s,c) end end
local function save() pcall(function() if S.persistSettings then S.persistSettings() end end) end
function _G.openAppearanceApp()
 pcall(function()
  local text=T.Text or Color3.fromRGB(20,20,25); local sub=T.Text2 or Color3.fromRGB(110,110,120)
  local hero=Instance.new("Frame",appContent); hero.Size=UDim2.new(1,0,0,92); hero.BackgroundColor3=T.Accent or Color3.fromRGB(35,95,255); hero.BorderSizePixel=0; corner(hero,18)
  local g=Instance.new("UIGradient",hero); g.Color=ColorSequence.new(T.Accent or Color3.fromRGB(35,95,255),Color3.fromRGB(132,82,255)); g.Rotation=25
  local h=Instance.new("TextLabel",hero); h.Size=UDim2.new(1,-20,0,28); h.Position=UDim2.new(0,10,0,12); h.BackgroundTransparency=1; h.Text="APPEARANCE LAB"; h.TextColor3=Color3.new(1,1,1); h.Font=Enum.Font.GothamBlack; h.TextSize=16; h.TextXAlignment=Enum.TextXAlignment.Left
  local s=Instance.new("TextLabel",hero); s.Size=UDim2.new(1,-20,0,22); s.Position=UDim2.new(0,10,0,43); s.BackgroundTransparency=1; s.Text="Choose a visual preset. Changes are stored locally."; s.TextColor3=Color3.new(1,1,1); s.TextTransparency=.15; s.Font=Enum.Font.Gotham; s.TextSize=9; s.TextXAlignment=Enum.TextXAlignment.Left
  local sec=Instance.new("Frame",appContent); sec.Size=UDim2.new(1,0,0,0); sec.AutomaticSize=Enum.AutomaticSize.Y; sec.BackgroundTransparency=1; sec.LayoutOrder=2; local l=Instance.new("UIListLayout",sec); l.Padding=UDim.new(0,8)
  local presets={{"Midnight","Dark premium",Color3.fromRGB(18,20,27),Color3.fromRGB(35,95,255),1},{"Arctic","Clean light",Color3.fromRGB(248,249,252),Color3.fromRGB(35,95,255),2},{"Violet","Purple accent",Color3.fromRGB(245,242,255),Color3.fromRGB(132,82,255),3},{"Emerald","Fresh green",Color3.fromRGB(242,249,246),Color3.fromRGB(25,185,105),4}}
  for i,p in ipairs(presets) do local b=Instance.new("TextButton",sec); b.Size=UDim2.new(1,0,0,68); b.BackgroundColor3=p[3]; b.Text=""; b.AutoButtonColor=false; b.LayoutOrder=i; corner(b,16); stroke(b,p[4],1,.2)
   local dot=Instance.new("Frame",b); dot.Size=UDim2.new(0,38,0,38); dot.Position=UDim2.new(0,12,.5,-19); dot.BackgroundColor3=p[4]; corner(dot,12)
   local t=Instance.new("TextLabel",b); t.Size=UDim2.new(1,-70,0,20); t.Position=UDim2.new(0,62,0,13); t.BackgroundTransparency=1; t.Text=p[1]; t.TextColor3=(p[5]==1 and Color3.new(1,1,1) or text); t.Font=Enum.Font.GothamBlack; t.TextSize=11; t.TextXAlignment=Enum.TextXAlignment.Left
   local d=Instance.new("TextLabel",b); d.Size=UDim2.new(1,-70,0,18); d.Position=UDim2.new(0,62,0,34); d.BackgroundTransparency=1; d.Text=p[2]; d.TextColor3=(p[5]==1 and Color3.fromRGB(180,185,195) or sub); d.Font=Enum.Font.Gotham; d.TextSize=8; d.TextXAlignment=Enum.TextXAlignment.Left
   b.MouseButton1Click:Connect(function() S.appSettings.themeIndex=p[5]; save(); notify("Preset "..p[1].." saved — reload phone to apply",p[4]) end)
  end
  local info=Instance.new("TextLabel",appContent); info.Size=UDim2.new(1,0,0,38); info.BackgroundTransparency=1; info.LayoutOrder=3; info.Text="Catatan: sistem theme saat ini dibaca saat Phone dibuat. Preset tersimpan untuk sesi berikutnya."; info.TextColor3=sub; info.Font=Enum.Font.Gotham; info.TextSize=8; info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left
 end)
end
print("[Appearance] Loaded")
