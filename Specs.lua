-- Main spec and offspec: every character says which of its class's talent trees it plays (and
-- which it would play when needed). The guild sees it in Guild OS's roster tooltip.
-- Set with /gspec or the "My specs" button in the marketplace tab; synced like the board.
--
-- spec = { id = who, who, ms = main spec key, os = offspec key (optional), c, u, rev, ed }
--                                                                    only `who` changes it
local _, ns = ...
local L = ns.L
local GOS = GuildOS

local de = GetLocale() == "deDE"

-- per class: key, English, German, role (T tank, H healer, D damage)
local LIST = {
  WARRIOR = { { "arms", "Arms", "Waffen", "D" }, { "fury", "Fury", "Furor", "D" },
              { "protw", "Protection", "Schutz", "T" } },
  PALADIN = { { "holypa", "Holy", "Heilig", "H" }, { "protpa", "Protection", "Schutz", "T" },
              { "ret", "Retribution", "Vergeltung", "D" } },
  HUNTER  = { { "bm", "Beast Mastery", "Tierherrschaft", "D" }, { "mm", "Marksmanship", "Treffsicherheit", "D" },
              { "surv", "Survival", "Überleben", "D" } },
  ROGUE   = { { "assa", "Assassination", "Meucheln", "D" }, { "combat", "Combat", "Kampf", "D" },
              { "sub", "Subtlety", "Täuschung", "D" } },
  PRIEST  = { { "disc", "Discipline", "Disziplin", "H" }, { "holypr", "Holy", "Heilig", "H" },
              { "shadow", "Shadow", "Schatten", "D" } },
  SHAMAN  = { { "ele", "Elemental", "Elementar", "D" }, { "enh", "Enhancement", "Verstärkung", "D" },
              { "restosh", "Restoration", "Wiederherstellung", "H" } },
  MAGE    = { { "arcane", "Arcane", "Arkan", "D" }, { "fire", "Fire", "Feuer", "D" },
              { "frost", "Frost", "Frost", "D" } },
  WARLOCK = { { "affli", "Affliction", "Gebrechen", "D" }, { "demo", "Demonology", "Dämonologie", "D" },
              { "destro", "Destruction", "Zerstörung", "D" } },
  DRUID   = { { "balance", "Balance", "Gleichgewicht", "D" }, { "bear", "Feral (Tank)", "Wilder Kampf (Tank)", "T" },
              { "cat", "Feral (Damage)", "Wilder Kampf (Schaden)", "D" }, { "restodr", "Restoration", "Wiederherstellung", "H" } },
}

ns.SPECS = {}          -- key -> { key, name, role, class }
ns.CLASS_SPECS = {}    -- class -> { spec, ... }
for class, list in pairs(LIST) do
  ns.CLASS_SPECS[class] = {}
  for _, s in ipairs(list) do
    local e = { key = s[1], name = de and s[3] or s[2], role = s[4], class = class }
    ns.SPECS[e.key] = e
    table.insert(ns.CLASS_SPECS[class], e)
  end
end

local ROLE_COLOR = { T = "ff6fa8ff", H = "ff40ff40", D = "ffff6060" }

-- "Protection (Tank)" with the role colored
function ns.SpecText(key)
  local s = key and ns.SPECS[key]
  if not s then return nil end
  return s.name .. " |c" .. ROLE_COLOR[s.role] .. "(" .. L["S_ROLE_" .. s.role] .. ")|r"
end

local function Store()
  local g = ns.G()
  if not g then return nil end
  g.specs = g.specs or {}
  return g
end
ns.SpecStore = Store

function ns.SpecsOf(who)
  local g = Store()
  return g and g.specs[who]
end

function ns.MyClass()
  local _, class = UnitClass("player")
  return class
end

-- ms: main spec key (required), os: offspec key or nil
function ns.SetSpecs(ms, os)
  local g, me = Store(), ns.Me()
  if not g then ns.Print(L.NO_GUILD) return end
  if not ns.SPECS[ms] then return end
  if os == ms or (os and not ns.SPECS[os]) then os = nil end
  local r = g.specs[me]
  if r and r.ms == ms and r.os == os then return end
  r = r or { id = me, who = me, c = time(), rev = 0 }
  r.ms, r.os = ms, os
  r.rev = (r.rev or 0) + 1
  r.u = math.max(time(), r.u or 0)
  r.ed = me
  g.specs[me] = r
  if ns.SendSpec then ns.SendSpec(r) end
  ns.Changed()
  if ns.RedrawRoster then ns.RedrawRoster() end
end

-- someone else's changed: the roster tooltip shows it
function ns.OnSpecChanged()
  if ns.RedrawRoster then ns.RedrawRoster() end
end

-- members who left the guild
function ns.PurgeSpecs()
  local g = Store()
  if not g or (ns.rosterCount or 0) == 0 then return end
  for who in pairs(g.specs) do
    if not ns.InGuild(who) then g.specs[who] = nil end
  end
end

---------------------------------------------------------------- the small window
local UI, C = GOS.UI, GOS.Colors
local WHITE = "Interface\\Buttons\\WHITE8x8"
local frame

local function Paint()
  if not frame then return end
  local r = ns.SpecsOf(ns.Me())
  for _, b in ipairs(frame.buttons) do
    local on = r and ((b.row == "ms" and r.ms == b.key) or (b.row == "os" and (r.os or "none") == b.key))
    if b.row == "os" and b.key == "none" and not r then on = false end
    local col = on and C.gold or C.text
    b.baseLabelColor = { col.r, col.g, col.b }
    b.label:SetTextColor(col.r, col.g, col.b)
  end
end

local function Build()
  local class = ns.MyClass()
  local specs = ns.CLASS_SPECS[class] or {}
  local f = CreateFrame("Frame", "GuildOSUnbrokenSpecs", UIParent, "BackdropTemplate")
  local BW = 150
  f:SetSize(math.max(3, #specs) * (BW + 4) + 80, 104)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  local bg, line = C.popup or C.panel, C.lineHi or C.border
  f:SetBackdropColor(bg.r, bg.g, bg.b, 0.97)
  f:SetBackdropBorderColor(line.r, line.g, line.b, 1)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "GuildOSUnbrokenSpecs") -- Escape closes it

  local head = UI:CreateText(f, L.S_TITLE, 12, C.gold.r, C.gold.g, C.gold.b)
  head:SetPoint("TOPLEFT", 10, -9)
  local close = UI:CreateButton(f, "x", 18, 18)
  close:SetPoint("TOPRIGHT", -5, -5)
  close:SetScript("OnClick", function() f:Hide() end)

  f.buttons = {}
  local function Row(rowKey, label, y, withNone)
    local t = UI:CreateText(f, label, 11, C.text.r, C.text.g, C.text.b)
    t:SetPoint("TOPLEFT", 10, y - 4)
    local x = 70
    local list = {}
    for _, s in ipairs(specs) do list[#list + 1] = { s.key, ns.SpecText(s.key) } end
    if withNone then list[#list + 1] = { "none", L.S_NONE } end
    for _, e in ipairs(list) do
      local b = UI:CreateButton(f, e[2], BW, 20)
      b:SetPoint("TOPLEFT", x, y)
      b.row, b.key = rowKey, e[1]
      b:SetScript("OnClick", function()
        local r = ns.SpecsOf(ns.Me())
        if rowKey == "ms" then
          ns.SetSpecs(e[1], r and r.os)
        elseif r and r.ms then
          ns.SetSpecs(r.ms, e[1] ~= "none" and e[1] or nil)
        else
          ns.Print(L.S_MAIN_FIRST)
        end
        Paint()
      end)
      f.buttons[#f.buttons + 1] = b
      x = x + BW + 4
    end
  end
  Row("ms", L.S_MAIN, -32, false)
  Row("os", L.S_OFF, -58, true)
  if #specs == 0 then
    local t = UI:CreateText(f, L.S_NO_CLASS, 11, C.textDim.r, C.textDim.g, C.textDim.b)
    t:SetPoint("TOPLEFT", 10, -40)
  end
  local hint = UI:CreateText(f, L.S_HINT, 10, C.textDim.r, C.textDim.g, C.textDim.b)
  hint:SetPoint("BOTTOMLEFT", 10, 9)
  f:Hide()
  return f
end

function ns.ShowSpecs()
  frame = frame or Build()
  Paint()
  frame:Show()
end

SLASH_GUILDOSSPEC1 = "/gspec"
SlashCmdList.GUILDOSSPEC = function() ns.ShowSpecs() end
