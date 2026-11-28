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
-- Guild OS 2 draws its marks after the name (its crest, the founder's banner): ours is a small
-- dot after the last of them. Older Guild OS had a dot of its own at the end of the name cell.
local MARK_W = 22 -- a Guild OS mark (18) and its gap (4)
local DOT_ROOM = 10

local function PlaceDot(row)
  local dot = row.gcoDot
  if not dot then return end
  dot:ClearAllPoints()
  if row.marks then
    local n = row.markKinds and #row.markKinds or 0
    dot:SetPoint("LEFT", row.nameText, "RIGHT", 4 + n * MARK_W, 0)
  elseif row.addonDot then
    dot:SetPoint("RIGHT", row.addonDot, "LEFT", -3, 0)
  end
  dot:SetShown(row.__gcoVer ~= nil and row.nameText:IsShown() and row.nameShown ~= false)
end

local function Marker(row)
  if row.gcoDot then return row.gcoDot end
  local dot = row:CreateTexture(nil, "OVERLAY")
  dot:SetSize(6, 6)
  dot:SetTexture("Interface\Buttons\WHITE8x8")
  dot:Hide()
  row.gcoDot = dot
  if row.FitName then
    -- Guild OS 2: the name takes what the marks leave; leave room for ours too
    hooksecurefunc(row, "FitName", function(self)
      if self.__gcoVer then
        local room = math.max(20, (self.nameMax or 100) - (self.markKinds and #self.markKinds or 0) * MARK_W - DOT_ROOM)
        if (self.nameText:GetWidth() or 0) > room then self.nameText:SetWidth(room) end
      end
      PlaceDot(self)
    end)
  elseif row.ApplyColumns and row.addonDot then
    -- older Guild OS: the name gets a little narrower after each column layout
    hooksecurefunc(row, "ApplyColumns", function(self)
      if self.nameText:IsShown() then
        self.nameText:SetWidth(math.max(20, self.nameText:GetWidth() - 9))
      end
      PlaceDot(self)
    end)
    local w = row.nameText:GetWidth()
    if w and w > 29 then row.nameText:SetWidth(w - 9) end
  end
  return dot
end

local function UpdateRow(row, data)
  if not row or not data or not row.nameText or not (row.marks or row.addonDot) then return end
  local ver = ns.Enabled() and ns.PeerVersion(MemberName(data)) or nil
  local had = row.__gcoVer
  row.__gcoVer = ver
  local dot = Marker(row)
  if ver then
    local old = ns.CompareVersions(ver, ns.VERSION) < 0
    local col = old and C.red or nil
    if col then dot:SetVertexColor(col.r, col.g, col.b, 0.9)
    else dot:SetVertexColor(PURPLE[1], PURPLE[2], PURPLE[3], 0.9) end
  end
  -- Guild OS fitted the name before we knew: fit it again when ours comes or goes
  if row.FitName and (had ~= nil) ~= (ver ~= nil) then row:FitName() end
  PlaceDot(row)
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
