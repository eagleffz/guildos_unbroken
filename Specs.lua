-- Main spec and offspec: every character says which of its class's talent trees it plays (and
-- which it would play when needed). The guild sees it in Guild OS's roster tooltip.
-- Set in the "My Char" tab (or /gspec); synced like the board.
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

-- a small icon per role: ability icons every client has (shield, holy light, two blades)
local ROLE_ICON = {
  T = "Interface\\Icons\\Ability_Defend",
  H = "Interface\\Icons\\Spell_Holy_FlashHeal",
  D = "Interface\\Icons\\Ability_DualWield",
}

-- the role's icon as text, `size` pixels (cut to the inner part, like Blizzard's buttons)
function ns.RoleIcon(role, size)
  local path = ROLE_ICON[role]
  if not path then return "" end
  size = size or 14
  return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(path, size, size)
end

-- "[icon] Protection (Tank)" with the role colored
function ns.SpecText(key, size)
  local s = key and ns.SPECS[key]
  if not s then return nil end
  return ns.RoleIcon(s.role, size) .. " " .. s.name .. " |c" .. ROLE_COLOR[s.role] .. "(" .. L["S_ROLE_" .. s.role] .. ")|r"
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

---------------------------------------------------------------- the "My Char" tab
local UI, C = GOS.UI, GOS.Colors
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

local function BuildPanel(panel)
  local class = ns.MyClass()
  local specs = ns.CLASS_SPECS[class] or {}
  local BW = 160
  frame = panel

  local head = UI:CreateText(panel, L.S_TITLE, 12, C.gold.r, C.gold.g, C.gold.b)
  head:SetPoint("TOPLEFT", 10, -10)
  local intro = UI:CreateText(panel, L.S_INTRO, 11, C.textDim.r, C.textDim.g, C.textDim.b)
  intro:SetPoint("TOPLEFT", 10, -30)
  intro:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
  intro:SetJustifyH("LEFT")
  intro:SetWordWrap(true)

  panel.buttons = {}
  local function Row(rowKey, label, y, withNone)
    local t = UI:CreateText(panel, label, 11, C.text.r, C.text.g, C.text.b)
    t:SetPoint("TOPLEFT", 10, y - 4)
    local x = 90
    local list = {}
    -- on the buttons the icon says the role
    for _, s in ipairs(specs) do list[#list + 1] = { s.key, ns.RoleIcon(s.role, 16) .. " " .. s.name } end
    if withNone then list[#list + 1] = { "none", L.S_NONE } end
    for _, e in ipairs(list) do
      local b = UI:CreateButton(panel, e[2], BW, 22)
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
      panel.buttons[#panel.buttons + 1] = b
      x = x + BW + 4
    end
  end
  Row("ms", L.S_MAIN, -60, false)
  Row("os", L.S_OFF, -88, true)
  if #specs == 0 then
    local t = UI:CreateText(panel, L.S_NO_CLASS, 11, C.textDim.r, C.textDim.g, C.textDim.b)
    t:SetPoint("TOPLEFT", 10, -64)
  end

  -- what the guild sees
  local seen = UI:CreateText(panel, "", 11, C.text.r, C.text.g, C.text.b)
  seen:SetPoint("TOPLEFT", 10, -124)
  seen:SetJustifyH("LEFT")
  local function refresh()
    if not panel:IsVisible() then return end
    Paint()
    local r = ns.SpecsOf(ns.Me())
    if r then
      seen:SetText(L.S_SEEN:format(ns.SpecText(r.ms) or "?", r.os and ns.SpecText(r.os) or L.S_NONE))
    else
      seen:SetText("|cff888888" .. L.S_NOT_SET .. "|r")
    end
  end
  ns.OnChanged(refresh)
  panel:HookScript("OnShow", function()
    if ns.Start then ns.Start() end
    GOS:SafeCall(refresh)
  end)
  GOS:SafeCall(refresh)
  return refresh
end

---------------------------------------------------------------- registration
ns.MYCHAR_FEATURE = "mychar"
UI:RegisterFeature({
  id = ns.MYCHAR_FEATURE, label = L.S_TAB, desc = L.S_FEATURE_DESC, order = 50,
  build = function(c) return BuildPanel(c) end,
})

function ns.ShowSpecs() UI:OpenWindow(ns.MYCHAR_FEATURE) end

SLASH_GUILDOSSPEC1 = "/gspec"
SLASH_GUILDOSSPEC2 = "/mychar"
SlashCmdList.GUILDOSSPEC = function() ns.ShowSpecs() end
