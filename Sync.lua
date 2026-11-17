-- Sharing orders with guild members who run this plugin, over the hidden guild addon channel.
-- Same scheme as GuildHub's orders, on its own prefix (the two do not talk to each other):
--   O  an order:  { k="O", o=order, relay=true when passed on for someone else }
--   H  hello:     { k="H", o={ [orderId]=rev } } - "this is what I have"
-- On hello, whoever has something newer queues it and sends it after a random delay; whatever
-- someone else sends first is dropped from the queue, so the guild isn't flooded. Everyone keeps
-- everything, so an order reaches players who were offline when it was made.
-- Messages are LibSerialize + LibDeflate (Guild OS's copies), sent through AceComm.
local ADDON, ns = ...
local L = ns.L
local GOS = GuildOS

local PREFIX = "GOSCraftOrders" -- max 16 characters
local PROTO = 1
local HEARD_FOR = 60
local CAP_PER_PLAYER = 50

local AceComm = LibStub("AceComm-3.0")
local Ser = LibStub("GuildOS-LibSerialize") -- Guild OS ships its copy under its own name
local Deflate = LibStub("LibDeflate")
local comm = {}
AceComm:Embed(comm)

local function Encode(msg)
  return Deflate:EncodeForWoWAddonChannel(Deflate:CompressDeflate(Ser:Serialize(msg)))
end

local function Decode(text)
  local raw = Deflate:DecodeForWoWAddonChannel(text)
  raw = raw and Deflate:DecompressDeflate(raw)
  if not raw then return nil end
  local ok, msg = Ser:Deserialize(raw)
  if ok and type(msg) == "table" then return msg end
end

-- the orders, the market and the board share this channel; any one switched on is enough
function ns.AnyEnabled()
  return ns.Enabled() or (ns.MarketEnabled and ns.MarketEnabled())
    or (ns.BoardEnabled and ns.BoardEnabled())
end

local function Send(msg, prio)
  if not IsInGuild() or not ns.G() or not ns.AnyEnabled() then return end
  msg.v = PROTO
  msg.av = ns.VERSION -- the plugin version, for the marker in the Guild OS roster
  comm:SendCommMessage(PREFIX, Encode(msg), "GUILD", nil, prio or "NORMAL")
end

---------------------------------------------------------------- checks
local function SafeName(s)
  return type(s) == "string" and #s > 0 and #s <= 64 and not s:find("[|:%c]") and not s:find("^%s")
end
local function SafeText(s, max)
  if type(s) ~= "string" or #s > (max or 200) then return false end
  return not s:gsub("||", ""):find("|", 1, true)
end
local function Num(v, lo, hi) return type(v) == "number" and v == v and v >= lo and v <= hi end
local function OptNum(v, lo, hi) return v == nil or Num(v, lo, hi) end

local STATES = { open = true, acc = true, dlv = true, done = true, cxl = true }
local function ValidOrder(o, sender, relay)
  if type(o) ~= "table" or not SafeName(o.by) or not SafeName(o.ed) then return false end
  if type(o.id) ~= "string" or #o.id > 120 or o.id:sub(1, #o.by + 1) ~= o.by .. ":" then return false end
  if o.acc ~= nil and not SafeName(o.acc) then return false end
  if not SafeText(o.txt, 120) or #o.txt == 0 or (o.note ~= nil and not SafeText(o.note, 200)) then return false end
  if not Num(o.n, 1, 1000) or not STATES[o.st] or not OptNum(o.it, 1, 1e7) then return false end
  local soon = time() + ns.DAY
  if not Num(o.c, 0, soon) or not Num(o.u, 0, soon) or not Num(o.rev, 0, 1e6) then return false end
  if o.ms ~= nil and type(o.ms) ~= "boolean" then return false end
  if o.sk ~= nil and type(o.sk) ~= "boolean" then return false end
  if not OptNum(o.dn, 0, 1e6) then return false end
  if o.cat ~= nil and not ns.GROUPS[o.cat] then return false end
  -- who may do what: only the requester completes or cancels, only the crafter takes and delivers
  if (o.st == "done" or o.st == "cxl") and o.ed ~= o.by then return false end
  if (o.st == "acc" or o.st == "dlv") and (not o.acc or o.ed ~= o.acc) then return false end
  -- a live change must come from the one who made it
  if not relay and o.ed ~= sender then return false end
  return true
end

-- market: an offer only comes from its owner, a "want" only from the one who wants it
local OFFER_STATES = { open = true, sold = true, gone = true }
local function ValidOffer(o, sender, relay)
  if type(o) ~= "table" or not SafeName(o.by) or o.ed ~= o.by then return false end
  if type(o.id) ~= "string" or #o.id > 120 or o.id:sub(1, #o.by + 1) ~= o.by .. ":" then return false end
  if not SafeText(o.txt, 120) or #o.txt == 0 or (o.note ~= nil and not SafeText(o.note, 200))
    or (o.pr ~= nil and not SafeText(o.pr, 40)) then return false end
  if not OFFER_STATES[o.st] or not Num(o.n, 1, 1000) or not OptNum(o.it, 1, 1e7) then return false end
  local soon = time() + ns.DAY
  if not Num(o.c, 0, soon) or not Num(o.u, 0, soon) or not Num(o.rev, 0, 1e6) then return false end
  if not relay and o.by ~= sender then return false end
  return true
end

local function ValidWant(w, sender, relay)
  if type(w) ~= "table" or not SafeName(w.who) or w.ed ~= w.who then return false end
  if type(w.o) ~= "string" or #w.o > 120 or w.id ~= w.o .. "#" .. w.who then return false end
  if w.st ~= "in" and w.st ~= "out" then return false end
  local soon = time() + ns.DAY
  if not Num(w.c, 0, soon) or not Num(w.u, 0, soon) or not Num(w.rev, 0, 1e6) then return false end
  if not relay and w.who ~= sender then return false end
  return true
end

-- message board: a post only comes from its writer, a reply only from the one answering
local BOARD_STATES = { open = true, gone = true }
local function ValidPost(p, sender, relay)
  if type(p) ~= "table" or not SafeName(p.by) or p.ed ~= p.by then return false end
  if type(p.id) ~= "string" or #p.id > 120 or p.id:sub(1, #p.by + 1) ~= p.by .. ":" then return false end
  if not SafeText(p.txt, 400) or #p.txt == 0 or not BOARD_STATES[p.st] then return false end
  local soon = time() + ns.DAY
  if not Num(p.c, 0, soon) or not Num(p.u, 0, soon) or not Num(p.rev, 0, 1e6) then return false end
  if not relay and p.by ~= sender then return false end
  return true
end

local function ValidReply(r, sender, relay)
  if type(r) ~= "table" or not SafeName(r.who) or r.ed ~= r.who then return false end
  if type(r.p) ~= "string" or #r.p > 120 or type(r.id) ~= "string" or #r.id > 220 then return false end
  local head = r.p .. "#" .. r.who .. "#"
  if r.id:sub(1, #head) ~= head or not r.id:sub(#head + 1):match("^%d+$") then return false end
  if not SafeText(r.txt, 300) or #r.txt == 0 or not BOARD_STATES[r.st] then return false end
  local soon = time() + ns.DAY
  if not Num(r.c, 0, soon) or not Num(r.u, 0, soon) or not Num(r.rev, 0, 1e6) then return false end
  if not relay and r.who ~= sender then return false end
  return true
end

-- main / offspec: one record per character, only from that character
local function ValidSpec(s, sender, relay)
  if type(s) ~= "table" or not SafeName(s.who) or s.ed ~= s.who or s.id ~= s.who then return false end
  if type(s.ms) ~= "string" or not ns.SPECS[s.ms] then return false end
  if s.os ~= nil and (type(s.os) ~= "string" or not ns.SPECS[s.os]) then return false end
  local soon = time() + ns.DAY
  if not Num(s.c, 0, soon) or not Num(s.u, 0, soon) or not Num(s.rev, 0, 1e6) then return false end
  if not relay and s.who ~= sender then return false end
  return true
end

local function TooMany(store, by)
  local n = 0
  for _, o in pairs(store) do
    if (o.by or o.who) == by then n = n + 1; if n >= CAP_PER_PLAYER then return true end end
  end
  return false
end

---------------------------------------------------------------- de-duplicated sending
local queue, heard, flushing = {}, {}, false

local function HeardRecently(key, ver)
  local h = heard[key]
  return h and h.ver >= ver and GetTime() - h.at < HEARD_FOR
end

local function Flush()
  flushing = false
  for key, q in pairs(queue) do
    if not HeardRecently(key, q.ver) then
      Send(q.msg, "BULK")
      heard[key] = { ver = q.ver, at = GetTime() }
    end
  end
  wipe(queue)
end

local function Queue(key, ver, msg)
  if HeardRecently(key, ver) then return end
  queue[key] = { msg = msg, ver = ver }
  if not flushing then
    flushing = true
    C_Timer.After(1.5 + math.random() * 5, Flush)
  end
end

local function Heard(key, ver)
  local h = heard[key]
  if not h or h.ver <= ver then heard[key] = { ver = ver, at = GetTime() } end
  local q = queue[key]
  if q and q.ver <= ver then queue[key] = nil end
end

---------------------------------------------------------------- outgoing
function ns.SendOrder(o)
  Heard("O:" .. o.id, o.rev)
  Send({ k = "O", o = o })
end

local lastHello = 0
function ns.SendHello(force)
  local g = ns.G()
  if not g then return end
  if not force and GetTime() - lastHello < 60 then return end
  lastHello = GetTime()
  local have = {}
  if ns.Enabled() then
    for id, o in pairs(g.orders) do have[id] = o.rev or 0 end
  end
  -- `o` always goes (older versions expect it)
  local offers, wants
  if ns.MarketEnabled() and ns.MarketStore() then
    offers, wants = {}, {}
    for id, o in pairs(g.offers) do offers[id] = o.rev or 0 end
    for id, w in pairs(g.wants) do wants[id] = w.rev or 0 end
  end
  local posts, replies
  if ns.BoardEnabled() and ns.BoardStore() then
    posts, replies = {}, {}
    for id, p in pairs(g.posts) do posts[id] = p.rev or 0 end
    for id, r in pairs(g.replies) do replies[id] = r.rev or 0 end
  end
  local specs
  if ns.SpecStore and ns.SpecStore() then
    specs = {}
    for id, s in pairs(g.specs) do specs[id] = s.rev or 0 end
  end
  -- oe = false: my orders are switched off, so my empty list says nothing about what I lack
  Send({ k = "H", o = have, oe = ns.Enabled() and true or false, m = offers, w = wants,
         b = posts, r = replies, sp = specs, ver = ns.VERSION })
end

function ns.SendSpec(s)
  Heard("T:" .. s.id, s.rev)
  Send({ k = "T", o = s })
end

function ns.SendPost(p)
  Heard("B:" .. p.id, p.rev)
  Send({ k = "B", o = p })
end

function ns.SendReply(r)
  Heard("R:" .. r.id, r.rev)
  Send({ k = "R", o = r })
end

function ns.SendOffer(o)
  Heard("M:" .. o.id, o.rev)
  Send({ k = "M", o = o })
end

function ns.SendWant(w)
  Heard("W:" .. w.id, w.rev)
  Send({ k = "W", o = w })
end

---------------------------------------------------------------- incoming
-- A relayed copy can't prove who wrote it: ignore copies of my own orders (I have the real
-- ones), and changes by someone who is online right now (they send it themselves).
local function TrustRelay(author, old)
  if not old then return true end
  if author == ns.Me() then return false end
  return not ns.IsOnline(author)
end

local function OnOrder(msg, sender)
  local o = msg.o
  if not ValidOrder(o, sender, msg.relay) or ns.OrderExpired(o) or not ns.InGuild(o.by) then return end
  Heard("O:" .. o.id, o.rev)
  local g = ns.G()
  local old = g.orders[o.id]
  if old and not ns.OrderNewer(o, old) then return end
  if msg.relay and not TrustRelay(o.ed, old) then return end
  if not old and TooMany(g.orders, o.by) then return end
  -- keep only the known fields
  g.orders[o.id] = { id = o.id, by = o.by, txt = o.txt, it = o.it, n = o.n, note = o.note, ms = o.ms,
                     sk = o.sk, dn = o.dn, cat = o.cat, st = o.st, acc = o.acc, c = o.c, u = o.u, rev = o.rev, ed = o.ed }
  if not msg.relay then ns.OnOrderChanged(g.orders[o.id], old) end
  ns.Changed()
end

-- "here is my version": answers a hello, so whoever just logged in learns who runs which version.
-- One answer covers every hello in the last half minute (it goes to the whole guild).
local lastV, vPending = -1e9, false
local function AnswerVersion()
  if vPending then return end
  vPending = true
  local wait = math.max(0, lastV + 30 - GetTime()) + 2 + math.random() * 8
  C_Timer.After(wait, function()
    vPending = false
    lastV = GetTime()
    Send({ k = "V" }, "BULK")
  end)
end

-- the market's and the board's records work like orders; per kind: who wrote it, where
-- it is kept, which fields travel, and what to do when it changed
local RECORDS = {
  M = { valid = ValidOffer, author = "by", store = function() local g = ns.MarketStore(); return g and g.offers end,
        dead = function(r) return ns.OfferExpired(r) end, on = function(...) ns.OnOfferChanged(...) end,
        fields = { "id", "by", "it", "txt", "n", "pr", "note", "st", "c", "u", "rev", "ed" } },
  W = { valid = ValidWant, author = "who", store = function() local g = ns.MarketStore(); return g and g.wants end,
        on = function(...) ns.OnWantChanged(...) end,
        fields = { "id", "o", "who", "st", "c", "u", "rev", "ed" } },
  B = { valid = ValidPost, author = "by", store = function() local g = ns.BoardStore(); return g and g.posts end,
        dead = function(r) return ns.PostExpired(r) end, on = function(...) ns.OnPostChanged(...) end,
        fields = { "id", "by", "txt", "st", "c", "u", "rev", "ed" } },
  R = { valid = ValidReply, author = "who", store = function() local g = ns.BoardStore(); return g and g.replies end,
        on = function(...) ns.OnReplyChanged(...) end,
        fields = { "id", "p", "who", "txt", "st", "c", "u", "rev", "ed" } },
  T = { valid = ValidSpec, author = "who", store = function() local g = ns.SpecStore(); return g and g.specs end,
        on = function(...) ns.OnSpecChanged(...) end,
        fields = { "id", "who", "ms", "os", "c", "u", "rev", "ed" } },
}

function ns.RecordNewer(a, b)
  if (a.rev or 0) ~= (b.rev or 0) then return (a.rev or 0) > (b.rev or 0) end
  return (a.u or 0) > (b.u or 0)
end

local function OnRecord(msg, sender, kind)
  local K, r = RECORDS[kind], msg.o
  local store = K.store()
  if not store or not K.valid(r, sender, msg.relay) then return end
  local author = r[K.author]
  if (K.dead and K.dead(r)) or not ns.InGuild(author) then return end
  Heard(kind .. ":" .. r.id, r.rev)
  local old = store[r.id]
  if old and not ns.RecordNewer(r, old) then return end
  if msg.relay and not TrustRelay(author, old) then return end
  if not old and TooMany(store, author) then return end
  local copy = {} -- only the known fields
  for _, f in ipairs(K.fields) do copy[f] = r[f] end
  store[r.id] = copy
  if not msg.relay then K.on(copy, old) end
  ns.Changed()
end

-- what they have of one kind against mine: queue what I have newer, true when they have newer
local function Compare(mine, theirs, kind, live)
  local theyHaveNewer = false
  for id, r in pairs(mine) do
    local t = type(theirs[id]) == "number" and theirs[id] or nil
    if live(r) and (not t or (r.rev or 0) > t) then
      Queue(kind .. ":" .. id, r.rev or 0, { k = kind, o = r, relay = true })
    elseif t and t > (r.rev or 0) then
      theyHaveNewer = true
    end
  end
  for id in pairs(theirs) do if not mine[id] then return true end end
  return theyHaveNewer
end

local function OnHello(msg)
  if type(msg.o) ~= "table" then return end
  AnswerVersion()
  local g = ns.G()
  local newer = false
  if ns.Enabled() and msg.oe ~= false then
    newer = Compare(g.orders, msg.o, "O", function(o) return not ns.OrderExpired(o) end) or newer
  end
  if ns.MarketEnabled() and type(msg.m) == "table" and type(msg.w) == "table" and ns.MarketStore() then
    newer = Compare(g.offers, msg.m, "M", function(o) return not ns.OfferExpired(o) end) or newer
    newer = Compare(g.wants, msg.w, "W", function(w) return g.offers[w.o] ~= nil end) or newer
  end
  if ns.BoardEnabled() and type(msg.b) == "table" and type(msg.r) == "table" and ns.BoardStore() then
    newer = Compare(g.posts, msg.b, "B", function(p) return not ns.PostExpired(p) end) or newer
    newer = Compare(g.replies, msg.r, "R", function(r) return g.posts[r.p] ~= nil end) or newer
  end
  if type(msg.sp) == "table" and ns.SpecStore() then
    newer = Compare(g.specs, msg.sp, "T", function() return true end) or newer
  end
  if newer then C_Timer.After(2 + math.random() * 4, function() ns.SendHello() end) end
end

comm:RegisterComm(PREFIX, function(_, text, dist, sender)
  if dist ~= "GUILD" or not ns.AnyEnabled() then return end
  sender = ns.Short(sender)
  if not sender or sender == ns.Me() or not ns.G() or not ns.InGuild(sender) then return end
  local msg = Decode(text)
  if not msg or msg.v ~= PROTO then return end
  if type(msg.av) == "string" and #msg.av <= 20 and msg.av:match("^[%w%.%-]+$") then ns.SetPeerVersion(sender, msg.av) end
  GOS:SafeCall(function()
    if msg.k == "O" then if ns.Enabled() then OnOrder(msg, sender) end
    elseif msg.k == "M" or msg.k == "W" then if ns.MarketEnabled() then OnRecord(msg, sender, msg.k) end
    elseif msg.k == "B" or msg.k == "R" then if ns.BoardEnabled() then OnRecord(msg, sender, msg.k) end
    elseif msg.k == "T" then OnRecord(msg, sender, "T")
    elseif msg.k == "H" then OnHello(msg) end
  end)
end)

---------------------------------------------------------------- startup
ns.VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version"))
  or (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "0"

local started = false
local function Start(tries)
  if started or not ns.AnyEnabled() or not IsInGuild() then return end
  if not ns.G() then
    if (tries or 0) < 30 then C_Timer.After(2, function() Start((tries or 0) + 1) end) end
    return
  end
  started = true
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
  ns.PurgeOrders()
  -- the group planner is gone (1.12.0): drop what it had kept
  local g = ns.G()
  g.plans, g.signs = nil, nil
  ns.PurgeMarket()
  ns.PurgeBoard()
  ns.PurgeSpecs()
  C_Timer.After(5, function() ns.SendHello(true) end)
  -- after the guild had time to answer
  C_Timer.After(25, function()
    local n = ns.Enabled() and ns.CountForMe() or 0
    if n > 0 then ns.Print(L.LOGIN_HINT:format(n)) end
    local nm = ns.MarketEnabled() and ns.CountOffers() or 0
    if nm > 0 then ns.Print(L.M_LOGIN_HINT:format(nm)) end
    local nb = ns.BoardEnabled() and ns.CountPosts() or 0
    if nb > 0 then ns.Print(L.B_LOGIN_HINT:format(nb)) end
    -- once per character: say where main and offspec are set
    local me = ns.Me()
    ns.db.settings.specHint = ns.db.settings.specHint or {}
    if not ns.SpecsOf(me) and not ns.db.settings.specHint[me] and ns.CLASS_SPECS[ns.MyClass() or ""] then
      ns.db.settings.specHint[me] = true
      ns.Print(L.S_LOGIN_HINT)
    end
  end)
end
ns.Start = Start

local rosterQueued, lastRoster = false, -1e9
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    GuildOSCraftOrdersDB = GuildOSCraftOrdersDB or {}
    ns.db = GuildOSCraftOrdersDB
    ns.db.guilds = ns.db.guilds or {}
    ns.db.settings = ns.db.settings or {}
    -- "notify all" was off by default until 1.7.2, and a default is saved: switch it on once for
    -- everybody (off by choice and off by default look the same), it can be unticked again
    if not ns.db.settings.notifyMigrated then
      ns.db.settings.notifyAll, ns.db.settings.notifyMigrated = true, true
    end
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(5, Start)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("GuildHub") then ns.Print(L.CONFLICT_GUILDHUB) end
    -- this plugin used to be "GuildOS_CraftOrders": both at once would do everything twice.
    -- Switch the old one off for the next login and say so.
    if ADDON ~= "GuildOS_CraftOrders" and loaded and loaded("GuildOS_CraftOrders") then
      local disable = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn
      if disable then pcall(disable, "GuildOS_CraftOrders") end
      ns.Print(L.CONFLICT_OLD)
    end
  elseif event == "PLAYER_GUILD_UPDATE" then
    if not started then C_Timer.After(2, Start) end
  elseif event == "GUILD_ROSTER_UPDATE" then
    -- fires often (every guild event, other addons asking for the roster): read it at most every 5 s
    if not rosterQueued then
      rosterQueued = true
      C_Timer.After(math.max(0, lastRoster + 5 - GetTime()), function()
        rosterQueued, lastRoster = false, GetTime()
        ns.ReadRoster()
        ns.Changed()
      end)
    end
  end
end)

C_Timer.NewTicker(3600, function() ns.PurgeOrders(); ns.PurgeMarket(); ns.PurgeBoard(); ns.Changed() end)
