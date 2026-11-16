-- The guild marketplace: "Biete" (on offer) and "Suche" (wanted), each for an item (dragged in,
-- shift-clicked or typed) or a service ("portal to Darnassus", "+5 stamina on chest"). The guild
-- sees it and answers with one click: "Want it" on an offer, "Have it" on a request.
-- Its own tab and feature switch in Guild OS.
--
-- offer = { id = "<by>:<time>:<rand>" (an offer) or "<by>:<time>:<rand>:s" (a request), by,
--           it = item id (nil for a service), txt = item name or service, n = quantity,
--           pr = price as typed (optional), note,
--           st = "open" | "sold" | "gone", c, u, rev, ed }            only `by` changes it
-- want  = { id = "<offer id>#<who>", o = offer id, who, st = "in" | "out", c, u, rev, ed }
--           on an offer: wants it; on a request: has it              only `who` changes it
-- The kind travels in the id, so a copy relayed by an older version (which drops fields it
-- doesn't know) still is what it was.
local _, ns = ...
local L = ns.L
local GOS = GuildOS

ns.MARKET_FEATURE = "market"
local KEEP_OFFER = 7 * ns.DAY -- an offer runs a week after its last change
local KEEP_GONE = ns.DAY

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- the marketplace shares the orders' tab (and its switch in Guild OS) since 2.1.0
function ns.MarketEnabled() return ns.Enabled() end

local function Store()
  local g = ns.G()
  if not g then return nil end
  g.offers = g.offers or {}
  g.wants = g.wants or {}
  return g
end
ns.MarketStore = Store

function ns.OfferLive(o) return o.st == "open" and time() - (o.u or 0) <= KEEP_OFFER end

function ns.OfferExpired(o)
  if o.st ~= "open" then return time() - (o.u or 0) > KEEP_GONE end
  return time() - (o.u or 0) > KEEP_OFFER + KEEP_GONE
end

-- a request ("Suche") rather than an offer ("Biete")
function ns.OfferSeek(o) return type(o.id) == "string" and o.id:sub(-2) == ":s" end

-- how many of a request's item I carry (bags and bank)
function ns.OfferHave(o)
  if not o.it then return 0 end
  local count = (C_Item and C_Item.GetItemCount) or GetItemCount
  local ok, n = pcall(count, o.it, true)
  return ok and tonumber(n) or 0
end

---------------------------------------------------------------- known services
-- Services the plugin knows: they get an icon, are found in the suggestions (in either
-- language), read in each player's own language, and whoever can do one hears of a request.
-- A service travels as its text, so an entry is recognized by any of its names.
ns.SERVICES = {
  { key = "lockpick", class = "ROGUE", icon = "Interface\\Icons\\Spell_Nature_MoonKey",
    names = { "Lockpicking", "Schlossknacken", "Pick Lock", "Schloss knacken", "Lockbox", "Lockboxes",
              "Schließkassette", "Schließkassetten", "Open lockboxes", "Schließkassetten öffnen" },
    skill = { "Lockpicking", "Schlossknacken" } },
}
for _, s in ipairs(ns.SERVICES) do
  s.lower = {}
  for i, n in ipairs(s.names) do s.lower[i] = n:lower() end
end

function ns.ServiceName(s) return L["SVC_" .. s.key] end

-- the known service an entry's text means, or nil
function ns.ServiceOf(text)
  text = strtrim(text or ""):lower()
  if text == "" then return nil end
  for _, s in ipairs(ns.SERVICES) do
    if text == ns.ServiceName(s):lower() then return s end
    for _, n in ipairs(s.lower) do if text == n then return s end end
  end
end

-- services for the typed text (any of their names contains it), for the suggestion lists
function ns.SuggestServices(text)
  text = strtrim(text or ""):lower()
  local out = {}
  if #text < 3 then return out end
  for _, s in ipairs(ns.SERVICES) do
    local hit = ns.ServiceName(s):lower():find(text, 1, true)
    for _, n in ipairs(s.lower) do hit = hit or n:find(text, 1, true) end
    if hit then out[#out + 1] = { svc = s, name = ns.ServiceName(s), icon = s.icon } end
  end
  return out
end

-- my own skill in a service: rank (or true when the class has it but no skill line shows)
function ns.MyServiceSkill(s)
  local _, class = UnitClass("player")
  if s.class and class ~= s.class then return nil end
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank = GetSkillLineInfo(i)
      if not header and name then
        for _, n in ipairs(s.skill or {}) do if name == n then return rank or true end end
      end
    end
  end
  return true
end

-- guild members who can do a service (by class), online first: { name, online }
function ns.ServicePeople(s)
  local out = {}
  for who, e in pairs(ns.roster or {}) do
    if s.class and e.class == s.class then out[#out + 1] = { who, e.online } end
  end
  table.sort(out, function(a, b)
    if a[2] ~= b[2] then return a[2] end
    return a[1] < b[1]
  end)
  return out
end

-- a request for a service I can do
function ns.SeekForMe(o)
  if not ns.OfferSeek(o) or o.it or o.by == ns.Me() then return false end
  local s = ns.ServiceOf(o.txt)
  return s and ns.MyServiceSkill(s) ~= nil or false
end

-- "3x [Mithril Bar]" or the service in brackets
function ns.OfferLabel(o)
  if o.it then
    local _, link = GetItemInfo(o.it)
    return (o.n > 1 and (o.n .. "x ") or "") .. (link or ("|cffffffff[" .. o.txt .. "]|r"))
  end
  local s = ns.ServiceOf(o.txt)
  return "|cff80c0ff[" .. (s and ns.ServiceName(s) or o.txt) .. "]|r"
end

function ns.OfferIcon(o)
  local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
  if o.it then return (GetIcon and GetIcon(o.it)) or "Interface\\Icons\\INV_Misc_Note_05" end
  local s = o.txt and ns.ServiceOf(o.txt)
  return s and s.icon or "Interface\\Icons\\INV_Misc_Note_05"
end

-- who wants an offer (sorted), and whether I do
function ns.OfferWants(o)
  local g = Store()
  local out, mine = {}, false
  for _, w in pairs(g and g.wants or {}) do
    if w.o == o.id and w.st == "in" then
      out[#out + 1] = w.who
      if w.who == ns.Me() then mine = true end
    end
  end
  table.sort(out)
  return out, mine
end

---------------------------------------------------------------- actions
local function Stamp(rec)
  rec.rev = (rec.rev or 0) + 1
  rec.u = math.max(time(), rec.u or 0)
  rec.ed = ns.Me()
end

-- text: item link, item name or a service; pickedIt: an item picked from the suggestions;
-- seek: a request ("Suche") instead of an offer
function ns.CreateOffer(text, n, price, note, pickedIt, seek)
  local g, me = Store(), ns.Me()
  if not g then ns.Print(L.NO_GUILD) return end
  text = strtrim(text or "")
  local it = pickedIt or tonumber(text:match("item:(%d+)"))
  local name = text:match("|h%[(.-)%]|h")
  if it and not name then name = GetItemInfo(it) end
  if not it and text ~= "" then
    -- a typed name of a known item, else a service
    it = ns.ExactItem and ns.ExactItem(text)
    if it then name = GetItemInfo(it) or text end
  end
  name = ns.CleanText(strtrim(name or text)):sub(1, 100)
  if name == "" then ns.Print(L.M_NEED_TEXT) return end
  local now = time()
  local function clean(s, max) s = ns.CleanText(strtrim(s or "")):sub(1, max); return s ~= "" and s or nil end
  local o = {
    id = ("%s:%d:%d"):format(me, now, math.random(1000, 9999)) .. (seek and ":s" or ""),
    by = me, it = it, txt = name, n = it and math.max(1, math.min(1000, math.floor(tonumber(n) or 1))) or 1,
    pr = clean(price, 30), note = clean(note, 150),
    st = "open", c = now, u = now, rev = 1, ed = me,
  }
  g.offers[o.id] = o
  ns.SendOffer(o)
  ns.Changed()
  return o
end

local function EditOffer(o, changes)
  if o.by ~= ns.Me() then return end
  for k, v in pairs(changes) do o[k] = v end
  Stamp(o)
  ns.SendOffer(o)
  ns.Changed()
end
function ns.SoldOffer(o) EditOffer(o, { st = "sold" }) end
function ns.RemoveOffer(o) EditOffer(o, { st = "gone" }) end
-- still there: puts it up for another week
function ns.RenewOffer(o) EditOffer(o, {}) end

local function SetWant(o, st)
  local g, me = Store(), ns.Me()
  local id = o.id .. "#" .. me
  local w = g.wants[id]
  if not w then
    w = { id = id, o = o.id, who = me, c = time(), rev = 0 }
    g.wants[id] = w
  end
  w.st = st
  Stamp(w)
  ns.SendWant(w)
  ns.Changed()
end
function ns.WantOffer(o) if ns.OfferLive(o) then SetWant(o, "in") end end
function ns.UnwantOffer(o) SetWant(o, "out") end

function ns.PurgeMarket()
  local g = Store()
  if not g then return end
  for id, o in pairs(g.offers) do if ns.OfferExpired(o) then g.offers[id] = nil end end
  for id, w in pairs(g.wants) do
    if not g.offers[w.o] or time() - (w.u or 0) > KEEP_OFFER + KEEP_GONE then g.wants[id] = nil end
  end
end

---------------------------------------------------------------- notices
local function Ding()
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.READY_CHECK or 8960, "Master") end
end

function ns.OnOfferChanged(o, old)
  if old or time() - (o.u or 0) > 600 or o.by == ns.Me() or o.st ~= "open" then return end
  local seek = ns.OfferSeek(o)
  local have = seek and ns.OfferHave(o) or 0
  local can = ns.SeekForMe(o)
  -- requests share the "Looking for" tab's switch (the orders'), offers have their own
  local notify
  if seek then notify = ns.db.settings.notifyAll ~= false else notify = ns.db.settings.marketNotify ~= false end
  -- a request for something I carry or can do always comes, with a sound
  if notify or have > 0 or can then
    local why = ""
    if have > 0 then why = " |cff40ff40" .. L.M_YOU_HAVE:format(have) .. "|r"
    elseif can then why = " |cff40ff40" .. L.SVC_YOU_CAN .. "|r" end
    ns.Print((seek and L.M_SEEK_MSG or L.M_NEW_MSG):format(ns.ColorName(o.by), ns.OfferLabel(o))
      .. (o.pr and (" |cffffd100" .. o.pr .. "|r") or "") .. why)
  end
  if have > 0 or can then Ding() end
  if ns.ShowOfferPopup then ns.ShowOfferPopup(o) end
end

function ns.OnWantChanged(w, old)
  if time() - (w.u or 0) > 600 or w.who == ns.Me() then return end
  local g = Store()
  local o = g and g.offers[w.o]
  if not o or o.by ~= ns.Me() or not ns.OfferLive(o) then return end
  local was = old and old.st == "in"
  local seek = ns.OfferSeek(o)
  if w.st == "in" and not was then
    ns.Print((seek and L.M_HAVE_MSG or L.M_WANT_MSG):format(ns.ColorName(w.who), ns.OfferLabel(o)))
    Ding()
  elseif w.st == "out" and was then
    ns.Print((seek and L.M_UNHAVE_MSG or L.M_UNWANT_MSG):format(ns.ColorName(w.who), ns.OfferLabel(o)))
  end
end

function ns.CountOffers()
  local g = Store()
  local n = 0
  for _, o in pairs(g and g.offers or {}) do
    if ns.OfferLive(o) and o.by ~= ns.Me() then n = n + 1 end
  end
  return n
end
