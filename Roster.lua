-- A marker in the Guild OS roster, after the name and Guild OS's own marks: who runs this
-- plugin, and on which version. Purple = same or newer than mine, red = older. The row
-- tooltip names the version.
-- Versions come with every message of this plugin (and an answer to each hello), and are
-- kept per guild, so members who are offline right now still show theirs.
local _, ns = ...
local L = ns.L
local C = GuildOS.Colors

local PURPLE = { 0.70, 0.45, 1.00 }

function ns.CompareVersions(a, b)
  local pa, pb = {}, {}
  for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end

-- many answers arrive together after a login: redraw the roster once for all of them
local redraw = false
local function Redraw()
  if redraw then return end
  redraw = true
  C_Timer.After(1, function()
    redraw = false
    if GuildOS.RefreshRosterUI then GuildOS:SafeCall(GuildOS.RefreshRosterUI, GuildOS) end
  end)
end
ns.RedrawRoster = Redraw

function ns.SetPeerVersion(name, ver)
  local g = ns.G()
  if not g or not name then return end
  g.versions = g.versions or {}
  if g.versions[name] ~= ver then
    g.versions[name] = ver
    Redraw()
  end
end

function ns.PeerVersion(name)
  if not name then return nil end
  if name == ns.Me() then return ns.VERSION end
  local g = ns.G()
  return g and g.versions and g.versions[name]
end

local function MemberName(data)
  return ns.Short(data.fullName) or data.name
end

---------------------------------------------------------------- the marker
-- Guild OS 2 draws round marks after the name (its crest, the founder's banner). Ours is a mark of
-- the same size: a coin in a ring, purple = same version or newer, red = older. The name stays on
-- the left and all marks, Guild OS's and ours, line up on the right of the name cell.
-- Older Guild OS (a dot of its own at the end of the name cell): a small dot next to it.
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local COIN = "Interface\\Icons\\INV_Misc_Coin_02"
local SIZE, GAP = 18, 4

local function Round(tex)
  if tex.SetMask then pcall(tex.SetMask, tex, ROUND) end
end

local function TextW(fs)
  local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
  return math.ceil(w or 0)
end

local function ShowMarkTip(m)
  local row = m:GetParent()
  local ver = row and row.__gcoVer
  if not ver then return end
  GameTooltip:SetOwner(m, "ANCHOR_RIGHT")
  if ns.CompareVersions(ver, ns.VERSION) < 0 then
    GameTooltip:SetText(L.ROSTER_VER_OLD:format(ver), C.red.r, C.red.g, C.red.b)
  else
    GameTooltip:SetText(L.ROSTER_VER:format(ver), PURPLE[1], PURPLE[2], PURPLE[3])
  end
  GameTooltip:Show()
end

local function NewMark(row)
  local m = CreateFrame("Button", nil, row)
  m:SetSize(SIZE, SIZE)
  m.ring = m:CreateTexture(nil, "ARTWORK")
  m.ring:SetAllPoints()
  m.ring:SetTexture(WHITE)
  Round(m.ring)
  m.icon = m:CreateTexture(nil, "OVERLAY")
  m.icon:SetPoint("CENTER")
  m.icon:SetSize(SIZE - 4, SIZE - 4)
  m.icon:SetTexture(COIN)
  m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  Round(m.icon)
  m:SetScript("OnEnter", ShowMarkTip)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- a click on the mark is a click on the row, as with Guild OS's marks
  m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  m:SetScript("OnClick", function(_, button)
    local fn = row:GetScript("OnClick")
    if fn then fn(row, button) end
  end)
  m:Hide()
  return m
end

-- Guild OS 2: name on the left, the marks right-aligned at the end of the name cell
local function Layout(row)
  local name = row.nameText
  local icons = {}
  for i, m in ipairs(row.marks) do
    if row.markKinds and row.markKinds[i] then icons[#icons + 1] = m end
  end
  local mine = row.gcoMark
  if mine then
    if row.__gcoVer then icons[#icons + 1] = mine end
    mine:SetShown(row.__gcoVer ~= nil and row.nameShown ~= false)
  end
  local max = row.nameMax or 100
  -- the name starts 42 px into its cell and may run to 10 px before its end: marks end 2 px before
  local x = max + 8
  for i = #icons, 1, -1 do
    local m = icons[i]
    m:ClearAllPoints()
    m:SetPoint("RIGHT", name, "LEFT", x, 0)
    x = x - SIZE - GAP
  end
  local room = math.max(20, max - #icons * (SIZE + GAP))
  name:SetWidth(math.max(1, math.min(TextW(name), room)))
end

local function Marker(row)
  if row.marks and row.FitName then
    if not row.gcoMark then
      row.gcoMark = NewMark(row)
      hooksecurefunc(row, "FitName", function(self) GuildOS:SafeCall(Layout, self) end)
    end
    return row.gcoMark
  end
  -- older Guild OS
  if row.gcoDot then return row.gcoDot end
  local dot = row:CreateTexture(nil, "OVERLAY")
  dot:SetSize(6, 6)
  dot:SetTexture(WHITE)
  dot:SetPoint("RIGHT", row.addonDot, "LEFT", -3, 0)
  dot:Hide()
  row.gcoDot = dot
  if row.ApplyColumns then
    hooksecurefunc(row, "ApplyColumns", function(self)
      if self.nameText:IsShown() then
        self.nameText:SetWidth(math.max(20, self.nameText:GetWidth() - 9))
      end
      self.gcoDot:SetShown(self.__gcoVer ~= nil and self.nameText:IsShown())
    end)
    local w = row.nameText:GetWidth()
    if w and w > 29 then row.nameText:SetWidth(w - 9) end
  end
  return dot
end

local function UpdateRow(row, data)
  if not row or not data or not row.nameText or not (row.marks or row.addonDot) then return end
  local ver = ns.Enabled() and ns.PeerVersion(MemberName(data)) or nil
  row.__gcoVer = ver
  local m = Marker(row)
  local r, g, b = PURPLE[1], PURPLE[2], PURPLE[3]
  if ver and ns.CompareVersions(ver, ns.VERSION) < 0 then r, g, b = C.red.r, C.red.g, C.red.b end
  if m == row.gcoMark then
    m.ring:SetVertexColor(r, g, b, 1)
    -- an offline member's row is grey: so is the coin
    if m.icon.SetDesaturated then m.icon:SetDesaturated(not data.isOnline) end
    Layout(row)
  else
    m:SetVertexColor(r, g, b, 0.9)
    m:SetShown(ver ~= nil and row.nameText:IsShown())
  end
end

local function AddTooltip(row, tip, locked)
  tip = tip or GameTooltip
  local data = row and row.memberData
  if not data or data.allied then return end
  if not locked and not tip:IsShown() then return end
  local name = MemberName(data)
  -- main / offspec, whenever the member set them
  local s = ns.SpecsOf and ns.SpecsOf(name)
  local ver = ns.Enabled() and ns.PeerVersion(name)
  if not s and not ver then return end
  tip:AddLine(" ")
  if s then
    tip:AddDoubleLine(L.S_MAIN, ns.SpecText(s.ms) or "?", 0.85, 0.66, 0.31, 1, 1, 1)
    if s.os then tip:AddDoubleLine(L.S_OFF, ns.SpecText(s.os) or "?", 0.85, 0.66, 0.31, 1, 1, 1) end
  end
  if ver then
    if ns.CompareVersions(ver, ns.VERSION) < 0 then
      tip:AddLine(L.ROSTER_VER_OLD:format(ver), C.red.r, C.red.g, C.red.b)
    else
      tip:AddLine(L.ROSTER_VER:format(ver), PURPLE[1], PURPLE[2], PURPLE[3])
    end
  end
  tip:Show()
end

-- Guild OS's roster draws each row through these two global functions
-- (ShowRowTooltip(row, tip, locked) since Guild OS 2: `tip` may be a card kept open)
local function Hook()
  if type(UpdateRosterRow) == "function" then
    hooksecurefunc("UpdateRosterRow", function(row, data) GuildOS:SafeCall(UpdateRow, row, data) end)
  end
  if type(ShowRowTooltip) == "function" then
    hooksecurefunc("ShowRowTooltip", function(row, tip, locked) GuildOS:SafeCall(AddTooltip, row, tip, locked) end)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  Hook()
end)
