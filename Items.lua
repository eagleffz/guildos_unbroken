-- Every item of the game for the item field, not only craftable ones (Peacebloom, Mithril Ore ...).
-- The game has no search by name, so, like aux, the plugin asks the client about every item number
-- once and keeps the names (per account, in the client's language). After the first walk only
-- numbers without a name are looked at again, after a game patch.
--
-- Kept light on purpose:
--  * the walk asks the server slowly (REQ_PER_SEC, never more than OPEN_MAX at once), because every
--    answer is an event every other addon listening to it handles too; not in combat, not in an
--    instance, and it runs only until all numbers are done (the first login: some minutes)
--  * only one string per item is kept: no poor (grey) items and no quest items, which nobody orders
--  * the search reads that table directly with a case-insensitive pattern: no copy of the list, no
--    lower-cased string per item and keystroke
local _, ns = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local Exists = C_Item and C_Item.DoesItemExistByID
local Request = C_Item and C_Item.RequestLoadItemDataByID

local MAX_ID = Exists and 80000 or 30000 -- Forever adds items above Classic's numbers
local REQ_PER_SEC = 25     -- server requests per second
local OPEN_MAX = 15        -- requests waiting for an answer at most
local CHECK_PER_STEP = 400 -- numbers looked at per step (no request needed for most)
local STEP = 0.1           -- seconds between steps
local QUEST_CLASS = 12

local db
local open, nOpen = {}, 0
local ticker

local function DB()
  if db then return db end
  ns.db.items = ns.db.items or {}
  db = ns.db.items
  local locale, build = GetLocale(), select(2, GetBuildInfo())
  if db.locale ~= locale then
    db.locale, db.names, db.next, db.build = locale, {}, 1, nil
  end
  db.names = db.names or {}
  db.next = db.next or 1
  if db.build ~= build then
    db.build, db.next = build, 1 -- a patch may bring new items: walk again (known ones are skipped)
  end
  return db
end

-- keep the item's name if it is one somebody could order; true when the client had the item
local function Keep(id)
  local name, _, quality = GetItemInfo(id)
  if type(name) ~= "string" or name == "" then return false end
  if db.names[id] then return true end
  if quality == 0 then return true end
  local classID = GetItemInfoInstant and select(6, GetItemInfoInstant(id))
  if classID == QUEST_CLASS then return true end
  db.names[id] = name
  return true
end

local function Busy()
  if InCombatLockdown() then return true end
  local inInstance = IsInInstance()
  return inInstance
end

local budget = 0
local function Step()
  if Busy() then return end
  -- requests that never got an answer: give up on them
  local now = GetTime()
  for id, at in pairs(open) do
    if now - at > 10 then open[id] = nil; nOpen = nOpen - 1 end
  end
  budget = math.min(REQ_PER_SEC, budget + REQ_PER_SEC * STEP)
  local checked = 0
  while db.next <= MAX_ID and checked < CHECK_PER_STEP and budget >= 1 and nOpen < OPEN_MAX do
    local id = db.next
    db.next = id + 1
    checked = checked + 1
    if not db.names[id] and (not Exists or Exists(id)) then
      if not Keep(id) then
        if Request then Request(id) end -- GetItemInfo above already asked on clients without it
        open[id] = now
        nOpen = nOpen + 1
        budget = budget - 1
      end
    end
  end
  if db.next > MAX_ID and nOpen == 0 then
    ticker:Cancel()
    ticker = nil
    if ns.InvalidateSuggestions then ns.InvalidateSuggestions() end
  end
end

local function StartWalk()
  if ticker or not ns.db then return end
  DB()
  -- the materials of the skilling groups first: those get asked for most
  for _, g in pairs(ns.GROUPS or {}) do
    for _, id in ipairs(g.ids) do
      if not db.names[id] and not Keep(id) and Request then Request(id) end
    end
  end
  if db.next > MAX_ID then return end
  ticker = C_Timer.NewTicker(STEP, Step)
end

---------------------------------------------------------------- search
-- "mith" -> "[mM][iI][tT][hH]": matches without lower-casing every name
local function Pattern(text)
  return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%a", function(c)
    return "[" .. c:lower() .. c:upper() .. "]"
  end))
end

-- up to `max` items whose name contains `text` (starting with it first), skipping the ids and the
-- lower-cased names in `skip`: { { id, name }, ... }
function ns.FindItems(text, max, skip)
  local out = {}
  if not db then return out end
  local pat = Pattern(text)
  local starts, contains = {}, {}
  local limit = max * 4 -- enough to sort from, without collecting thousands for "ma"
  for id, name in pairs(db.names) do
    if not skip[id] then
      local at = name:find(pat)
      if at == 1 then
        if #starts < limit then starts[#starts + 1] = id end
      elseif at and #contains < limit then
        contains[#contains + 1] = id
      end
    end
  end
  local names = db.names
  local function byName(a, b) return names[a] < names[b] end
  table.sort(starts, byName)
  table.sort(contains, byName)
  for _, list in ipairs({ starts, contains }) do
    for _, id in ipairs(list) do
      if #out >= max then return out end
      local lower = names[id]:lower()
      if not skip[lower] then
        skip[lower] = true
        out[#out + 1] = { id = id, name = names[id], crafters = 0 }
      end
    end
  end
  return out
end

-- the item of an exactly typed name, any case
function ns.FindExactItem(text)
  if not db or text == "" then return nil end
  local pat = "^" .. Pattern(text) .. "$"
  for id, name in pairs(db.names) do
    if name:find(pat) then return id end
  end
end

---------------------------------------------------------------- events
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ev:SetScript("OnEvent", function(_, event, id, ok)
  if event == "PLAYER_LOGIN" then
    DB()
    C_Timer.After(20, StartWalk) -- after the login rush
  elseif db and type(id) == "number" then
    -- answers to the walk, and any item another addon or the game loaded: one table lookup
    if open[id] then open[id] = nil; nOpen = nOpen - 1 end
    if ok ~= false and not db.names[id] then Keep(id) end
  end
end)
