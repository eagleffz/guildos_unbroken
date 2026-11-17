-- A second marker in the Guild OS roster, next to Guild OS's own version dot: who runs this
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
local function Marker(row)
  if row.gcoDot then return row.gcoDot end
  local dot = row:CreateTexture(nil, "OVERLAY")
  dot:SetSize(6, 6)
  dot:SetTexture("Interface\\Buttons\\WHITE8x8")
  -- left of Guild OS's dot: that one sits at the very end of the name column
  dot:SetPoint("RIGHT", row.addonDot, "LEFT", -3, 0)
  dot:Hide()
  row.gcoDot = dot
  -- make room for it: the name gets a little narrower after each column layout
  if row.ApplyColumns then
    hooksecurefunc(row, "ApplyColumns", function(self)
      if self.nameText:IsShown() then
        self.nameText:SetWidth(math.max(20, self.nameText:GetWidth() - 9))
      end
      if self.gcoDot then self.gcoDot:SetShown(self.__gcoVer ~= nil and self.nameText:IsShown()) end
    end)
    local w = row.nameText:GetWidth()
    if w and w > 29 then row.nameText:SetWidth(w - 9) end
  end
  return dot
end

local function UpdateRow(row, data)
  if not row or not data or not row.addonDot or not row.nameText then return end
  local ver = ns.Enabled() and ns.PeerVersion(MemberName(data)) or nil
  row.__gcoVer = ver
  local dot = Marker(row)
  if not ver or not row.nameText:IsShown() then dot:Hide() return end
  local old = ns.CompareVersions(ver, ns.VERSION) < 0
  local col = old and C.red or nil
  if col then dot:SetVertexColor(col.r, col.g, col.b, 0.9)
  else dot:SetVertexColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.9) end
  dot:Show()
end

local function AddTooltip(row)
  local data = row and row.memberData
  if not data or not GameTooltip:IsShown() then return end
  local name = MemberName(data)
  -- main / offspec, whenever the member set them
  local s = ns.SpecsOf and ns.SpecsOf(name)
  local ver = ns.Enabled() and ns.PeerVersion(name)
  if s or ver then GameTooltip:AddLine(" ") end
  if s then
    GameTooltip:AddDoubleLine(L.S_MAIN, ns.SpecText(s.ms) or "?", 0.85, 0.66, 0.31, 1, 1, 1)
    if s.os then GameTooltip:AddDoubleLine(L.S_OFF, ns.SpecText(s.os) or "?", 0.85, 0.66, 0.31, 1, 1, 1) end
  end
  if not ver then
    if s then GameTooltip:Show() end
    return
  end
  local old = ns.CompareVersions(ver, ns.VERSION) < 0
  if old then
    GameTooltip:AddLine(L.ROSTER_VER_OLD:format(ver), C.red.r, C.red.g, C.red.b)
  else
    GameTooltip:AddLine(L.ROSTER_VER:format(ver), PURPLE[1], PURPLE[2], PURPLE[3])
  end
  GameTooltip:Show()
end

-- Guild OS's roster draws each row through these two global functions
local function Hook()
  if type(UpdateRosterRow) == "function" then
    hooksecurefunc("UpdateRosterRow", function(row, data) GuildOS:SafeCall(UpdateRow, row, data) end)
  end
  if type(ShowRowTooltip) == "function" then
    hooksecurefunc("ShowRowTooltip", function(row) GuildOS:SafeCall(AddTooltip, row) end)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  Hook()
end)
