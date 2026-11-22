-- Keys and attunements: which endgame doors each character can open. Found by itself (bags,
-- key ring, bank once opened, finished attunement quests), synced like main/offspec, shown in
-- the "Keys" tab as a table: one row per member, one column per key.
--
-- keys = { id = who, who, ks = "brd,strat,...", c, u, rev, ed }   only `who` changes it
local _, ns = ...
local L = ns.L
local GOS = GuildOS

local de = GetLocale() == "deDE"

-- key, short label, English, German, item id or quest ids, icon (quests only)
local LIST = {
  { "brd",    "BRD",    "Shadowforge Key",        "Schattenschmiedeschlüssel", item = 11000 },
  { "strat",  "Strat",  "Key to the City",        "Schlüssel zur Stadt",       item = 12382 },
  { "scholo", "Scholo", "Skeleton Key",           "Skelettschlüssel",          item = 13704 },
  { "dm",     "DM",     "Crescent Key",           "Mondsichelschlüssel",       item = 18249 },
  { "ubrs",   "UBRS",   "Seal of Ascension",      "Siegel des Aufstiegs",      item = 12344 },
  { "ony",    "Ony",    "Drakefire Amulet",       "Drachenfeueramulett",       item = 16309 },
  { "mc",     "MC",     "Attunement to the Core", "Einstimmung auf den Kern",  quests = { 7848 },
    icon = "Interface\\Icons\\Spell_Fire_Incinerate" },
  { "bwl",    "BWL",    "Blackwing Lair attunement", "Pechschwingenhort-Einstimmung", quests = { 7761 },
    icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
  { "naxx",   "Naxx",   "Naxxramas attunement",   "Naxxramas-Einstimmung",     quests = { 9121, 9122, 9123 },
    icon = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
}

ns.KEYS, ns.KEY_BY = {}, {}
for i, k in ipairs(LIST) do
  local e = { key = k[1], short = k[2], name = de and k[4] or k[3], item = k.item, quests = k.quests,
              icon = k.icon, order = i }
  ns.KEYS[i] = e
  ns.KEY_BY[e.key] = e
end

-- the item's own (localized) name once the client knows it
function ns.KeyName(e)
  if e.item and GetItemInfo then
    local name = GetItemInfo(e.item)
    if name then return name end
  end
  return e.name
end

function ns.KeyIcon(e)
  if e.icon then return e.icon end
  local icon = e.item and (GetItemIcon and GetItemIcon(e.item)
    or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.item)))
  return icon or "Interface\\Icons\\INV_Misc_Key_03"
end

local function Store()
  local g = ns.G()
  if not g then return nil end
  g.keys = g.keys or {}
  return g
end
ns.KeyStore = Store

-- "brd,mc" -> { brd = true, mc = true }
function ns.KeySet(r)
  local set = {}
  if r and type(r.ks) == "string" then
    for k in r.ks:gmatch("[^,]+") do if ns.KEY_BY[k] then set[k] = true end end
  end
  return set
end

function ns.KeysOf(who)
  local g = Store()
  return g and g.keys[who]
end

---------------------------------------------------------------- finding my own
local function QuestDone(id)
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) end
  return false
end

local KEYRING = -2
local function OnKeyRing(item)
  local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
  local idAt = C_Container and C_Container.GetContainerItemID or GetContainerItemID
  if not slots or not idAt then return false end
  local ok, n = pcall(slots, KEYRING)
  if not ok or not n then return false end
  for slot = 1, n do
    local ok2, id = pcall(idAt, KEYRING, slot)
    if ok2 and id == item then return true end
  end
  return false
end

local function HasKey(e)
  if e.item then
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(e.item, true))
      or (GetItemCount and GetItemCount(e.item, true)) or 0
    return count > 0 or OnKeyRing(e.item)
  end
  for _, q in ipairs(e.quests or {}) do if QuestDone(q) then return true end end
  return false
end

-- Keys stay once seen: the bank only counts after it was opened, and a key is hardly ever lost.
function ns.ScanKeys()
  local g, me = Store(), ns.Me()
  if not g or not me then return end
  local r = g.keys[me]
  local set = ns.KeySet(r)
  local changed = false
  for _, e in ipairs(ns.KEYS) do
    if not set[e.key] and HasKey(e) then set[e.key], changed = true, true end
  end
  if r and not changed then return end
  local list = {}
  for _, e in ipairs(ns.KEYS) do if set[e.key] then list[#list + 1] = e.key end end
  r = r or { id = me, who = me, c = time(), rev = 0 }
  r.ks = table.concat(list, ",")
  r.rev = (r.rev or 0) + 1
  r.u = math.max(time(), r.u or 0)
  r.ed = me
  g.keys[me] = r
  if ns.SendKeys then ns.SendKeys(r) end
  ns.Changed()
end

-- the bags change often: look at most every few seconds
local scanQueued = false
local function QueueScan(delay)
  if scanQueued then return end
  scanQueued = true
  C_Timer.After(delay or 3, function()
    scanQueued = false
    GOS:SafeCall(ns.ScanKeys)
  end)
end
ns.QueueKeyScan = QueueScan

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "BAG_UPDATE", "BANKFRAME_OPENED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  QueueScan(event == "PLAYER_LOGIN" and 12 or 3)
end)

function ns.OnKeysChanged() end

-- members who left the guild
function ns.PurgeKeys()
  local g = Store()
  if not g or (ns.rosterCount or 0) == 0 then return end
  for who in pairs(g.keys) do
    if not ns.InGuild(who) then g.keys[who] = nil end
  end
end

---------------------------------------------------------------- the "Keys" tab
local UI, C = GOS.UI, GOS.Colors
local WHITE = "Interface\\Buttons\\WHITE8x8"
local YES = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local NO = "|cff555555-|r"
local NAME_W, ROW_H, HEAD_H, LIST_TOP = 150, 20, 40, -34

local function BuildPanel(panel)
  local onlineOnly = ns.db and ns.db.settings.keysOnline or false

  local intro = UI:CreateText(panel, L.K_INTRO, 11, C.textDim.r, C.textDim.g, C.textDim.b)
  intro:SetPoint("TOPLEFT", 10, -10)
  intro:SetPoint("RIGHT", panel, "RIGHT", -150, 0)
  intro:SetJustifyH("LEFT")
  intro:SetWordWrap(false)

  local online = UI:CreateCheckbox(panel, L.K_ONLINE, 18)
  online:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -6)
  online:SetWidth(online.label:GetStringWidth() + 26)

  local scroll, content = UI:CreateScrollFrame(panel, "GuildOSKeysScroll")
  scroll:SetPoint("TOPLEFT", 4, LIST_TOP - HEAD_H)
  scroll:SetPoint("BOTTOMRIGHT", -6, 4)
  UI:BindScrollChildWidth(scroll, content, 16)

  local function ColW()
    local w = content:GetWidth()
    if not w or w < 200 then w = (panel:GetWidth() or 640) - 26 end
    return math.max(36, math.floor((w - NAME_W) / #ns.KEYS))
  end

  -- the head: one icon per key with its short name and how many have it
  local head = CreateFrame("Frame", nil, panel)
  head:SetPoint("TOPLEFT", 4, LIST_TOP)
  head:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
  head:SetHeight(HEAD_H)
  local nameHead = UI:CreateText(head, L.K_MEMBER, 11, C.gold.r, C.gold.g, C.gold.b)
  nameHead:SetPoint("BOTTOMLEFT", 8, 4)
  local cols = {}
  for i, e in ipairs(ns.KEYS) do
    local c = CreateFrame("Frame", nil, head)
    c:SetHeight(HEAD_H)
    c.icon = UI:CreateIcon(c, 18)
    c.icon:SetPoint("TOP", 0, -1)
    c.icon.icon:SetTexture(ns.KeyIcon(e))
    c.text = UI:CreateText(c, e.short, 10, C.text.r, C.text.g, C.text.b)
    c.text:SetPoint("TOP", c.icon, "BOTTOM", 0, -2)
    c:EnableMouse(true)
    c:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      if e.item then GameTooltip:SetHyperlink("item:" .. e.item)
      else GameTooltip:AddLine(ns.KeyName(e), 1, 1, 1) end
      local g, who = Store(), {}
      if g then
        for name, r in pairs(g.keys) do
          if ns.KeySet(r)[e.key] and ns.InGuild(name) then who[#who + 1] = name end
        end
      end
      table.sort(who)
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(L.K_HAVE_IT:format(#who), 0.85, 0.66, 0.31)
      for n = 1, math.min(#who, 25) do GameTooltip:AddLine(ns.ColorName(who[n])) end
      if #who > 25 then GameTooltip:AddLine(L.K_MORE:format(#who - 25), 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cols[i] = c
  end
  local line = head:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(C.border.r, C.border.g, C.border.b, 0.5)
  line:SetPoint("BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", 0, 0)
  line:SetHeight(1)

  local empty = UI:CreateText(content, L.K_EMPTY, 11, C.textDim.r, C.textDim.g, C.textDim.b)
  empty:SetPoint("TOPLEFT", 8, -8)

  local rows = {}
  local function GetRow(i)
    if rows[i] then return rows[i] end
    local f = CreateFrame("Frame", nil, content, "BackdropTemplate")
    f:SetBackdrop({ bgFile = WHITE })
    f:SetHeight(ROW_H)
    f.name = UI:CreateText(f, "", 11, C.text.r, C.text.g, C.text.b)
    f.name:SetPoint("LEFT", 8, 0)
    f.name:SetWidth(NAME_W - 12)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.cells = {}
    for c = 1, #ns.KEYS do
      local t = UI:CreateText(f, "", 11, C.text.r, C.text.g, C.text.b)
      t:SetJustifyH("CENTER")
      f.cells[c] = t
    end
    rows[i] = f
    return f
  end

  local function refresh()
    if not panel:IsVisible() or not ns.db then return end
    online.checkbox:SetChecked(onlineOnly)
    local cw = ColW()
    local counts = {}
    for i, c in ipairs(cols) do
      c:SetWidth(cw)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", head, "TOPLEFT", NAME_W + (i - 1) * cw, 0)
      counts[i] = 0
    end

    local g, me = Store(), ns.Me()
    local list = {}
    if g then
      for name, r in pairs(g.keys) do
        if ns.InGuild(name) and (not onlineOnly or name == me or ns.IsOnline(name)) then
          list[#list + 1] = { name = name, set = ns.KeySet(r) }
        end
      end
    end
    table.sort(list, function(a, b)
      if (a.name == me) ~= (b.name == me) then return a.name == me end
      local oa, ob = ns.IsOnline(a.name), ns.IsOnline(b.name)
      if oa ~= ob then return oa end
      return a.name < b.name
    end)

    for i, e in ipairs(list) do
      local f = GetRow(i)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
      f:SetPoint("RIGHT", content, "RIGHT", 0, 0)
      if e.name == me then f:SetBackdropColor(C.gold.r, C.gold.g, C.gold.b, 0.08)
      elseif i % 2 == 0 then f:SetBackdropColor(1, 1, 1, 0.03)
      else f:SetBackdropColor(0, 0, 0, 0) end
      local nm = ns.ColorName(e.name)
      if e.name ~= me and not ns.IsOnline(e.name) then nm = "|cff777777" .. e.name .. "|r" end
      f.name:SetText(nm)
      for c, k in ipairs(ns.KEYS) do
        local t = f.cells[c]
        t:ClearAllPoints()
        t:SetPoint("CENTER", f, "LEFT", NAME_W + (c - 0.5) * cw, 0)
        local has = e.set[k.key]
        t:SetText(has and YES or NO)
        if has then counts[c] = counts[c] + 1 end
      end
      f:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    for i, c in ipairs(cols) do c.text:SetText(ns.KEYS[i].short .. " |cff888888" .. counts[i] .. "|r") end
    empty:SetShown(#list == 0)
    content:SetHeight(math.max(1, #list * ROW_H))
  end

  online.checkbox.onChanged = function(_, checked)
    onlineOnly = checked and true or false
    ns.db.settings.keysOnline = onlineOnly
    GOS:SafeCall(refresh)
  end

  ns.OnChanged(refresh)
  panel:HookScript("OnShow", function()
    if ns.Start then ns.Start() end
    QueueScan(0.5)
    GOS:SafeCall(refresh)
  end)
  local lastW = 0
  content:HookScript("OnSizeChanged", function(_, w)
    if w and math.abs(w - lastW) > 1 then lastW = w; GOS:SafeCall(refresh) end
  end)
  GOS:SafeCall(refresh)
  return refresh
end

---------------------------------------------------------------- registration
ns.KEYS_FEATURE = "keys"
UI:RegisterFeature({
  id = ns.KEYS_FEATURE, label = L.K_TAB, desc = L.K_FEATURE_DESC, order = 51,
  build = function(c) return BuildPanel(c) end,
})

SLASH_GUILDOSKEYS1 = "/gkeys"
SlashCmdList.GUILDOSKEYS = function() UI:OpenWindow(ns.KEYS_FEATURE) end
