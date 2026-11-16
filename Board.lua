-- The guild message board: anyone posts a short message, the guild reads it and can answer below
-- it. Shared like the orders (everyone keeps everything), its own tab and feature switch.
--
-- post  = { id = "<by>:<time>:<rand>", by, txt, st = "open" | "gone", c, u, rev, ed }
--                                                              only `by` changes it
-- reply = { id = "<post id>#<who>#<time>", p = post id, who, txt, st = "open" | "gone",
--           c, u, rev, ed }                                    only `who` changes it
local _, ns = ...
local L = ns.L
local GOS = GuildOS

ns.BOARD_FEATURE = "board"
local KEEP_POST = 14 * ns.DAY -- a post stays two weeks after the last word in its thread
local KEEP_GONE = ns.DAY
ns.POST_MAX, ns.REPLY_MAX = 300, 200

function ns.BoardEnabled()
  return GOS and GOS.IsFeatureEnabled and GOS:IsFeatureEnabled(ns.BOARD_FEATURE)
end

local function Store()
  local g = ns.G()
  if not g then return nil end
  g.posts = g.posts or {}
  g.replies = g.replies or {}
  return g
end
ns.BoardStore = Store

-- the replies to a post, oldest first, and when the thread last saw a word
function ns.PostReplies(p)
  local g = Store()
  local out, last = {}, p.c or 0
  for _, r in pairs(g and g.replies or {}) do
    if r.p == p.id and r.st == "open" then
      out[#out + 1] = r
      if (r.c or 0) > last then last = r.c end
    end
  end
  table.sort(out, function(a, b) return (a.c or 0) < (b.c or 0) end)
  return out, last
end

function ns.PostLive(p)
  if p.st ~= "open" then return false end
  local _, last = ns.PostReplies(p)
  return time() - math.max(last, p.u or 0) <= KEEP_POST
end

-- only by its own dates: a relayed copy is judged before its replies are known
function ns.PostExpired(p)
  if p.st ~= "open" then return time() - (p.u or 0) > KEEP_GONE end
  return time() - (p.u or 0) > KEEP_POST * 3
end

---------------------------------------------------------------- actions
local function Stamp(rec)
  rec.rev = (rec.rev or 0) + 1
  rec.u = math.max(time(), rec.u or 0)
  rec.ed = ns.Me()
end

local function Clean(s, max)
  s = ns.CleanText(strtrim(s or "")):gsub("%s+", " ")
  return s:sub(1, max)
end

function ns.CreatePost(text)
  local g, me = Store(), ns.Me()
  if not g then ns.Print(L.NO_GUILD) return end
  local txt = Clean(text, ns.POST_MAX)
  if txt == "" then ns.Print(L.B_NEED_TEXT) return end
  local now = time()
  local p = {
    id = ("%s:%d:%d"):format(me, now, math.random(1000, 9999)),
    by = me, txt = txt, st = "open", c = now, u = now, rev = 1, ed = me,
  }
  g.posts[p.id] = p
  ns.SendPost(p)
  ns.Changed()
  return p
end

function ns.RemovePost(p)
  if p.by ~= ns.Me() or p.st ~= "open" then return end
  p.st = "gone"
  Stamp(p)
  ns.SendPost(p)
  ns.Changed()
end

function ns.CreateReply(p, text)
  local g, me = Store(), ns.Me()
  if not g or not ns.PostLive(p) then return end
  local txt = Clean(text, ns.REPLY_MAX)
  if txt == "" then return end
  local now = time()
  local r = {
    id = ("%s#%s#%d%04d"):format(p.id, me, now, math.random(0, 9999)), p = p.id,
    who = me, txt = txt, st = "open", c = now, u = now, rev = 1, ed = me,
  }
  g.replies[r.id] = r
  ns.SendReply(r)
  ns.Changed()
  return r
end

function ns.RemoveReply(r)
  if r.who ~= ns.Me() or r.st ~= "open" then return end
  r.st = "gone"
  Stamp(r)
  ns.SendReply(r)
  ns.Changed()
end

function ns.PurgeBoard()
  local g = Store()
  if not g then return end
  for id, p in pairs(g.posts) do
    if ns.PostExpired(p) or (p.st == "open" and not ns.PostLive(p) and time() - (p.u or 0) > KEEP_POST) then
      g.posts[id] = nil
    end
  end
  for id, r in pairs(g.replies) do
    if not g.posts[r.p] or (r.st ~= "open" and time() - (r.u or 0) > KEEP_GONE) then g.replies[id] = nil end
  end
end

---------------------------------------------------------------- notices
local function Ding()
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.TELL_MESSAGE or 3081, "Master") end
end

local function Short(txt, n)
  if #txt <= n then return txt end
  return txt:sub(1, n):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "…"
end
ns.ShortText = Short

function ns.OnPostChanged(p, old)
  if old or time() - (p.c or 0) > 600 or p.by == ns.Me() or p.st ~= "open" then return end
  if ns.db.settings.boardNotify ~= false then
    ns.Print(L.B_NEW_MSG:format(ns.ColorName(p.by), Short(p.txt, 120)))
  end
  if ns.ShowPostPopup then ns.ShowPostPopup(p) end
end

-- a reply to my post (with a sound), or in a thread I answered in
function ns.OnReplyChanged(r, old)
  if old or r.st ~= "open" or time() - (r.c or 0) > 600 or r.who == ns.Me() then return end
  local g = Store()
  local p = g and g.posts[r.p]
  if not p or p.st ~= "open" then return end
  local me = ns.Me()
  if p.by == me then
    ns.Print(L.B_REPLY_MINE_MSG:format(ns.ColorName(r.who), Short(r.txt, 120)))
    Ding()
    return
  end
  for _, o in pairs(g.replies) do
    if o.p == p.id and o.who == me and o.st == "open" then
      ns.Print(L.B_REPLY_MSG:format(ns.ColorName(r.who), ns.ColorName(p.by), Short(r.txt, 120)))
      return
    end
  end
end

function ns.CountPosts()
  local g = Store()
  local n = 0
  for _, p in pairs(g and g.posts or {}) do
    if p.by ~= ns.Me() and time() - (p.c or 0) <= 3 * ns.DAY and ns.PostLive(p) then n = n + 1 end
  end
  return n
end
