-- Crafting orders: data, actions, crafter lookups (through Guild OS) and chat notices.
--
-- order = { id, by = requester, txt = item name, it = item ID (optional), n = quantity, note,
--           ms = true when the requester provides the materials,
--           sk = true for a standing order ("need it for skilling"): receiving a delivery opens it
--                again instead of closing it, dn = deliveries received so far,
--           st = "open" | "acc" | "dlv" (delivered) | "done" | "cxl", acc = crafter who took it,
--           c = created, u = last change, rev = revision, ed = who made the last change }
-- Names are short names as the guild roster and addon senders write them (Guild OS's
-- Compat.PlayerName: "First Surname" on WoW: Forever).
local _, ns = ...
local L = ns.L
local GOS = GuildOS

ns.FEATURE = "craftorders"
ns.DAY = 86400
ns.KEEP_ORDER = 14 * ns.DAY -- an order disappears two weeks after it was posted
ns.KEEP_DONE = 7 * ns.DAY   -- completed or cancelled ones a week after their last change
ns.KEEP_STANDING = 30 * ns.DAY -- a standing order runs until cancelled or 30 days without a change

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd9a94fGuild OS|r |cff888888Orders|r: " .. tostring(msg))
end

function ns.Enabled()
  return GOS and GOS.IsFeatureEnabled and GOS:IsFeatureEnabled(ns.FEATURE)
end

function ns.Me() return GOS.Compat.PlayerName() end

function ns.Short(name)
  if type(name) ~= "string" then return nil end
  return (Ambiguate and Ambiguate(name, "short")) or name:match("^([^-]+)") or name
end

---------------------------------------------------------------- saved data
-- GuildOSCraftOrdersDB = { settings = {...}, guilds = { [guild key] = { orders = {} } } }
local function GuildKey()
  local name = IsInGuild() and GetGuildInfo("player")
  if not name or name == "" then return nil end
  return name .. "@" .. (GetRealmName() or "?")
end

function ns.G()
  local key = GuildKey()
  if not key or not ns.db then return nil end
  local g = ns.db.guilds[key]
  if not g then g = { orders = {} }; ns.db.guilds[key] = g end
  return g
end

---------------------------------------------------------------- guild roster (online, class)
ns.roster, ns.rosterCount = {}, 0
function ns.ReadRoster()
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  if n == 0 then return end
  -- the roster updates often: the entries are reused, not built anew each time
  local r = ns.roster
  local seen = {}
  for i = 1, n do
    local name, _, _, _, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
    local short = ns.Short(name)
    if short then
      local e = r[short]
      if not e then e = {}; r[short] = e end
      e.online, e.class = online and true or false, class
      seen[short] = true
    end
  end
  for who in pairs(r) do if not seen[who] then r[who] = nil end end
  ns.rosterCount = n
end

function ns.IsOnline(who) return ns.roster[who] and ns.roster[who].online or false end

function ns.InGuild(who)
  if who == ns.Me() then return true end
  if ns.rosterCount == 0 then return true end -- not read yet: don't refuse
  return ns.roster[who] ~= nil
end

function ns.ColorName(who)
  local r = ns.roster[who]
  local hex = r and r.class and GOS.GetClassColorHex and GOS:GetClassColorHex(r.class)
  if type(hex) == "string" then
    hex = hex:gsub("^|c", ""):gsub("^#", "")
    if #hex == 6 then hex = "ff" .. hex end
    if #hex == 8 then return "|c" .. hex .. who .. "|r" end
  end
  return "|cffffffff" .. tostring(who) .. "|r"
end

---------------------------------------------------------------- text
-- typed or pasted text: drop escape codes, keep typed pipes
function ns.CleanText(s)
  if type(s) ~= "string" then return s end
  return (s:gsub("||", "\001"):gsub("|", ""):gsub("\001", "||"))
end

function ns.Ago(t)
  local d = math.max(0, time() - (t or time()))
  local s
  if d < 3600 then s = math.max(1, math.floor(d / 60)) .. "m"
  elseif d < 86400 then s = math.floor(d / 3600) .. "h"
  else s = math.floor(d / 86400) .. "d" end
  return L.AGO:format(s)
end

---------------------------------------------------------------- items, crafters, materials
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

function ns.ItemIcon(o)
  if o.cat and ns.GROUPS[o.cat] then return ns.GROUPS[o.cat].icon end
  return (o.it and GetItemIcon and GetItemIcon(o.it)) or "Interface\\Icons\\INV_Misc_Note_01"
end

-- the order's item as a colored link when the game knows it, else its name in brackets;
-- a material group by its name in this client's language
function ns.OrderLabel(o)
  if o.cat and ns.GROUPS[o.cat] then return "|cffffd100[" .. ns.GroupLabel(o.cat) .. "]|r" end
  if o.it then
    local _, link = GetItemInfo(o.it)
    if link then return link end
  end
  return "|cffffffff[" .. (o.txt or "?") .. "]|r"
end

-- "20x [Item]", or a group without a count: "[Cloth]"
function ns.OrderText(o)
  return (o.cat and "" or (o.n .. "x ")) .. ns.OrderLabel(o)
end

-- Guild OS's crafter index: { { playerName, playerKey, class, profName }, ... } or nil
function ns.Crafters(o)
  local rt = GOS.RecipeTracker
  if not (o.it and rt and rt.GetCraftersForItem) then return nil end
  local ok, list = pcall(rt.GetCraftersForItem, rt, o.it)
  return ok and list or nil
end

-- a crafter's specialization in the profession they are listed with ("Weaponsmith", "Goblin
-- Engineer", "Tribal Leatherworking"), from Guild OS's profession records (WoW: Forever; every
-- member's own scan, shared with the guild). nil when there is none or it isn't known.
function ns.CrafterSpec(c)
  local P, cat = GOS.Professions, GOS.ProfCatalog
  if not (c and c.playerKey and P and P.Get and cat and cat.professions) then return nil end
  local ok, rec = pcall(P.Get, P, c.playerKey)
  if not ok or type(rec) ~= "table" or type(rec.profs) ~= "table" then return nil end
  for line, prof in pairs(cat.professions) do
    local e = rec.profs[line]
    if prof.en == c.profName and e and type(e.spec) == "number" and e.spec > 0 then
      local name = GOS.Compat and GOS.Compat.GetSpellInfo and GOS.Compat.GetSpellInfo(e.spec)
      return name
    end
  end
end

function ns.ICanCraft(o)
  if not o.it then return false end
  local rt = GOS.RecipeTracker
  if rt and rt.LocalCrafts and rt:LocalCrafts(o.it) then return true end
  local me = ns.Me()
  for _, c in ipairs(ns.Crafters(o) or {}) do
    if ns.Short(c.playerName) == me or ns.Short(c.playerKey) == me then return true end
  end
  return false
end

-- materials for the whole order (WoW: Forever, from Guild OS's recipe catalog): { { id, count } }
function ns.OrderMats(o)
  local out = {}
  local dir = GOS.ProfDirectory
  if not (o.it and dir and dir.ItemRecipes and dir.Reagents) then return out end
  local recipe = dir.ItemRecipes(o.it)[1]
  if not recipe then return out end
  for _, r in ipairs(dir.Reagents(recipe)) do
    out[#out + 1] = { r.itemID, r.count * o.n, GetItemCount and GetItemCount(r.itemID, true) or 0 }
  end
  return out
end

function ns.ItemName(id)
  local name = GetItemInfo(id)
  return name or ("#" .. id)
end

---------------------------------------------------------------- lifecycle
-- Delivered, completed or cancelled: gone from the list. The record itself stays (hidden) until it
-- expires, so a sync from someone who missed the change can't bring the order back.
function ns.Finished(o)
  return o.st == "dlv" or o.st == "done" or o.st == "cxl"
end

function ns.OrderExpired(o, now)
  now = now or time()
  if ns.Finished(o) then return now - (o.u or 0) > ns.KEEP_DONE end
  if o.sk then return now - (o.u or o.c or 0) > ns.KEEP_STANDING end
  return now - (o.c or o.u or 0) > ns.KEEP_ORDER
end

function ns.OrderNewer(a, b)
  if not b then return true end
  if (a.rev or 0) ~= (b.rev or 0) then return (a.rev or 0) > (b.rev or 0) end
  if (a.u or 0) ~= (b.u or 0) then return (a.u or 0) > (b.u or 0) end
  return tostring(a.ed or "") > tostring(b.ed or "")
end

local listeners = {}
function ns.OnChanged(fn) listeners[#listeners + 1] = fn end
local pending
function ns.Changed()
  if pending then return end
  pending = true
  C_Timer.After(0, function()
    pending = nil
    for _, fn in ipairs(listeners) do GOS:SafeCall(fn) end
  end)
end

local function Edit(o, changes)
  for k, v in pairs(changes) do o[k] = v end
  if changes.acc == false then o.acc = nil end
  o.rev = (o.rev or 0) + 1
  o.u = math.max(time(), o.u or 0)
  o.ed = ns.Me()
  ns.SendOrder(o)
  ns.Changed()
end

-- txt: an item link, an item ID or a name; pickedIt: the item chosen from the suggestions
-- (its ID, with txt its name); returns the order or nil
function ns.CreateOrder(txt, n, note, ms, pickedIt, sk, cat)
  local g, me = ns.G(), ns.Me()
  if not g then ns.Print(L.NO_GUILD) return end
  txt = strtrim(txt or "")
  -- a material group (picked, or its name typed): always a skilling call
  cat = cat or (not pickedIt and ns.GroupByName(txt)) or nil
  if cat then
    local now = time()
    local o = {
      id = ("%s:%d:%d"):format(me, now, math.random(1000, 9999)),
      by = me, txt = ns.GroupLabel(cat), cat = cat, n = 1, sk = true, st = "open",
      note = (function(s) s = ns.CleanText(strtrim(s or "")):sub(1, 150); return s ~= "" and s or nil end)(note),
      c = now, u = now, rev = 1, ed = me,
    }
    g.orders[o.id] = o
    ns.SendOrder(o)
    ns.Changed()
    return o
  end
  local it = pickedIt or tonumber(txt:match("item:(%d+)")) or tonumber(txt:match("^%d+$"))
  local name = txt:match("|h%[(.-)%]|h")
  if it and not name then name = GetItemInfo(it) end
  if not it and txt ~= "" then
    -- a typed name: one from the suggestion list, else the game's item cache
    it = ns.ExactItem and ns.ExactItem(txt)
    if not it then
      local _, link = GetItemInfo(txt)
      it = link and tonumber(link:match("item:(%d+)"))
    end
  end
  name = ns.CleanText(strtrim(name or txt)):sub(1, 100)
  if name == "" or name:match("^%d+$") and not it then ns.Print(L.NEED_ITEM) return end
  if name:match("^%d+$") then name = "#" .. name end
  n = math.max(1, math.min(1000, math.floor(tonumber(n) or 1)))
  note = ns.CleanText(strtrim(note or "")):sub(1, 150)
  local now = time()
  local o = {
    id = ("%s:%d:%d"):format(me, now, math.random(1000, 9999)),
    by = me, txt = name, it = it, n = n, note = note ~= "" and note or nil,
    ms = ms and true or nil, sk = sk and true or nil, st = "open", c = now, u = now, rev = 1, ed = me,
  }
  g.orders[o.id] = o
  ns.SendOrder(o)
  ns.Changed()
  return o
end

function ns.AcceptOrder(o)
  if o.sk or o.st ~= "open" or o.by == ns.Me() then return end -- standing orders are not taken
  Edit(o, { st = "acc", acc = ns.Me() })
end

function ns.ReturnOrder(o)
  if o.st ~= "acc" or o.acc ~= ns.Me() then return end
  Edit(o, { st = "open", acc = false })
end

-- "Delivered" ends the order; no confirmation by the requester. A standing order counts the
-- delivery and opens again for the next crafter.
function ns.DeliverOrder(o)
  if o.st ~= "acc" or o.acc ~= ns.Me() then return end
  if o.sk then
    Edit(o, { st = "open", acc = false, dn = (o.dn or 0) + 1 })
  else
    Edit(o, { st = "dlv" })
  end
end

function ns.CompleteOrder(o)
  if o.by ~= ns.Me() or o.st == "done" or o.st == "cxl" then return end
  if o.sk then
    -- standing order: count the delivery and open it again for the next crafter
    if o.st == "open" then return end
    Edit(o, { st = "open", acc = false, dn = (o.dn or 0) + 1 })
  else
    Edit(o, { st = "done" })
  end
end

function ns.CancelOrder(o)
  if o.by ~= ns.Me() or o.st == "done" or o.st == "cxl" then return end
  Edit(o, { st = "cxl" })
end

-- How many of the order's item I carry (bags and bank); for a group, its items in my bags.
function ns.HaveCount(o)
  if o.cat then
    local _, total = ns.GroupHoldings(o.cat)
    return total
  end
  return (o.it and GetItemCount and GetItemCount(o.it, true)) or 0
end

-- A skilling call ("if you don't need X anymore, send it to me"): anyone sends some, any number
-- of times, in one click; the call stays open and counts the sendings.
function ns.SendLeftover(o)
  if not o.sk or (o.st ~= "open" and o.st ~= "acc") or o.by == ns.Me() then return end
  -- one an older version marked as taken opens again with it
  Edit(o, { dn = (o.dn or 0) + 1, st = "open", acc = false })
end

function ns.PurgeOrders()
  local g = ns.G()
  if not g then return end
  local now = time()
  for id, o in pairs(g.orders) do
    if ns.OrderExpired(o, now) then g.orders[id] = nil end
  end
end

-- Members who left the guild: their orders and market entries go (and their "I want it"s).
-- A roster can come in half read while the client still loads it, so a name has to be missing
-- for 5 minutes first. Copies others still send are refused, see the sync.
local missingSince = {}
local function Left(who, now)
  if not who or who == ns.Me() then return false end
  if ns.roster[who] then missingSince[who] = nil; return false end
  missingSince[who] = missingSince[who] or now
  return now - missingSince[who] >= 300
end

function ns.PurgeLeavers()
  local g = ns.G()
  if not g or (ns.rosterCount or 0) == 0 then return false end
  local now, gone = GetTime(), false
  for id, o in pairs(g.orders) do
    if Left(o.by, now) then g.orders[id] = nil; gone = true end
  end
  if g.offers then
    for id, o in pairs(g.offers) do
      if Left(o.by, now) then g.offers[id] = nil; gone = true end
    end
  end
  if g.wants then
    for id, w in pairs(g.wants) do
      if Left(w.who, now) or (g.offers and not g.offers[w.o]) then g.wants[id] = nil; gone = true end
    end
  end
  return gone
end

function ns.Whisper(who)
  if not who then return end
  if ChatFrame_SendTell then ChatFrame_SendTell(who)
  elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. who .. " ") end
end

---------------------------------------------------------------- chat notices for live changes
local function Ding() pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081) end

function ns.OnOrderChanged(o, old)
  local me = ns.Me()
  if time() - (o.u or 0) > 600 then return end -- old news arriving with a sync
  local label = ns.OrderText(o)
  if not old then
    if o.sk and o.st == "open" and o.by ~= me then
      local have = ns.HaveCount(o)
      local why = have > 0 and (" |cff40ff40(" .. L.YOU_HAVE:format(have) .. ")|r") or ""
      if have > 0 or ns.db.settings.notifyAll then
        ns.Print(L.NEW_SKILL_MSG:format(ns.ColorName(o.by), label) .. why)
        if have > 0 then Ding() end
      end
      -- the popup comes for every new order (it has its own switch)
      if ns.ShowPopup then ns.ShowPopup(o, why) end
    elseif o.st == "open" and o.by ~= me then
      local can = ns.ICanCraft(o)
      if can or ns.db.settings.notifyAll then
        ns.Print(L.NEW_ORDER_MSG:format(ns.ColorName(o.by), label) .. (can and L.NEW_ORDER_CAN or ""))
        if can then Ding() end
      end
      if ns.ShowPopup then ns.ShowPopup(o, can and L.NEW_ORDER_CAN or "") end
    end
    return
  end
  if o.by == me then
    if o.sk and o.st == "open" and old.st == "open" and (o.dn or 0) > (old.dn or 0) then
      ns.Print(L.SENT_MSG:format(ns.ColorName(o.ed), ns.OrderLabel(o))); Ding()
    elseif o.st == "acc" and old.st == "open" then
      ns.Print(L.ACCEPTED_MSG:format(ns.ColorName(o.acc), label)); Ding()
    elseif o.st == "dlv" and old.st ~= "dlv" then
      ns.Print(L.DELIVERED_MSG:format(ns.ColorName(o.acc), label)); Ding()
    elseif o.st == "open" and old.st == "acc" and (o.dn or 0) > (old.dn or 0) then
      -- a standing order delivered and open again
      ns.Print(L.DELIVERED_MSG:format(ns.ColorName(old.acc), label)); Ding()
    elseif o.st == "open" and old.st == "acc" then
      ns.Print(L.RETURNED_MSG:format(ns.ColorName(old.acc), label))
    end
  end
  if old.acc == me and (old.st == "acc" or old.st == "dlv") then
    if o.st == "done" or (o.sk and o.st == "open" and o.ed == o.by) then
      ns.Print(L.COMPLETED_MSG:format(ns.ColorName(o.by), label))
    elseif o.st == "acc" and o.acc ~= me then
      ns.Print(L.LOST_RACE:format(ns.ColorName(o.acc), label))
    end
  end
end

-- open orders by others that I can craft
function ns.CountForMe()
  local g, me, n = ns.G(), ns.Me(), 0
  for _, o in pairs(g and g.orders or {}) do
    if o.st == "open" and o.by ~= me and not ns.OrderExpired(o) and ns.ICanCraft(o) then n = n + 1 end
  end
  return n
end
