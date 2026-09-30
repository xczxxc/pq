-- AvatarClone — Dashboard app
local Players=game:GetService("Players")
local LocalPlayer=_G.LocalPlayer or Players.LocalPlayer
local T=_G.T or {}; local H=_G.Helpers or {}; local Storage=_G.Storage or {}; local appContent=_G.appContent
local function corner(o,r) return H.corner and H.corner(o,r) or Instance.new("UICorner",o) end
local function stroke(o,c,t,tr) return H.stroke and H.stroke(o,c,t,tr) end
local function notify(s,c) if _G.showDynamicNotification then _G.showDynamicNotification(s,c) end end
function _G.openDashboardApp()
 pcall(function()
  local bg=T.Card or Color3.fromRGB(255,255,255); local text=T.Text or Color3.fromRGB(20,20,25); local sub=T.Text2 or Color3.fromRGB(110,110,120); local accent=T.Accent or Color3.fromRGB(35,95,255)
  local head=Instance.new("Frame",appContent); head.Size=UDim2.new(1,0,0,92); head.BackgroundColor3=accent; head.BorderSizePixel=0; corner(head,18)
  local grad=Instance.new("UIGradient",head); grad.Color=ColorSequence.new(accent,Color3.fromRGB(130,70,255)); grad.Rotation=20
  local hi=Instance.new("TextLabel",head); hi.Size=UDim2.new(1,-20,0,28); hi.Position=UDim2.new(0,10,0,12); hi.BackgroundTransparency=1; hi.Text="WELCOME BACK"; hi.TextColor3=Color3.new(1,1,1); hi.Font=Enum.Font.GothamBlack; hi.TextSize=16; hi.TextXAlignment=Enum.TextXAlignment.Left
  local nm=Instance.new("TextLabel",head); nm.Size=UDim2.new(1,-20,0,22); nm.Position=UDim2.new(0,10,0,43); nm.BackgroundTransparency=1; nm.Text=LocalPlayer.DisplayName.."  •  @"..LocalPlayer.Name; nm.TextColor3=Color3.new(1,1,1); nm.TextTransparency=.1; nm.Font=Enum.Font.Gotham; nm.TextSize=9; nm.TextXAlignment=Enum.TextXAlignment.Left
  local sec=Instance.new("Frame",appContent); sec.Size=UDim2.new(1,0,0,130); sec.BackgroundTransparency=1; sec.LayoutOrder=2
  local grid=Instance.new("UIGridLayout",sec); grid.CellSize=UDim2.new(.5,-5,0,58); grid.CellPadding=UDim2.new(0,8,0,8)
  local function stat(title,val,col)
   local f=Instance.new("Frame",sec); f.BackgroundColor3=T.Card2 or Color3.fromRGB(242,244,248); f.BorderSizePixel=0; corner(f,14); stroke(f,T.Border or Color3.fromRGB(220,223,230),1,.4)
   local v=Instance.new("TextLabel",f); v.Size=UDim2.new(1,-14,0,24); v.Position=UDim2.new(0,7,0,6); v.BackgroundTransparency=1; v.Text=val; v.TextColor3=col; v.Font=Enum.Font.GothamBlack; v.TextSize=15; v.TextXAlignment=Enum.TextXAlignment.Left
   local l=Instance.new("TextLabel",f); l.Size=UDim2.new(1,-14,0,16); l.Position=UDim2.new(0,7,0,31); l.BackgroundTransparency=1; l.Text=title; l.TextColor3=sub; l.Font=Enum.Font.Gotham; l.TextSize=8; l.TextXAlignment=Enum.TextXAlignment.Left
  end
  stat("USER ID",tostring(LocalPlayer.UserId),accent); stat("PLACE ID",tostring(game.PlaceId),Color3.fromRGB(132,82,255)); stat("JOB ID",string.sub(game.JobId or "-",1,8),Color3.fromRGB(30,170,220)); stat("FAVORITES",tostring(Storage.favSet and #({}) or 0),Color3.fromRGB(25,185,105))
  local actions=Instance.new("Frame",appContent); actions.Size=UDim2.new(1,0,0,120); actions.BackgroundColor3=bg; actions.BorderSizePixel=0; actions.LayoutOrder=3; corner(actions,16); stroke(actions,T.Border or Color3.fromRGB(220,223,230),1,.35)
  local title=Instance.new("TextLabel",actions); title.Size=UDim2.new(1,-20,0,24); title.Position=UDim2.new(0,10,0,8); title.BackgroundTransparency=1; title.Text="QUICK LAUNCH"; title.TextColor3=text; title.Font=Enum.Font.GothamBlack; title.TextSize=11; title.TextXAlignment=Enum.TextXAlignment.Left
  local names={{"Clone",_G.openCloneApp},{"Players",_G.openPlayersApp},{"Emote",_G.openEmoteApp},{"AI",_G.openAlfreadAIApp}}
  for i,x in ipairs(names) do local b=Instance.new("TextButton",actions); b.Size=UDim2.new(.25,-6,0,48); b.Position=UDim2.new((i-1)*.25, i==1 and 5 or 3,0,43); b.BackgroundColor3=T.Card2 or Color3.fromRGB(242,244,248); b.Text=x[1]; b.TextColor3=text; b.Font=Enum.Font.GothamBold; b.TextSize=9; b.AutoButtonColor=false; corner(b,12); b.MouseButton1Click:Connect(function() if x[2] and _G.openApp then _G.openApp(x[1],x[2]) end end) end
 end)
end
print("[Dashboard] Loaded")
