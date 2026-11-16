-- Item name suggestions for the order form: every item of the game, craftable ones first.
--   WoW: Forever / retail: Guild OS's profession catalog (every recipe that makes an item; the name
--                          is the item's when the client has it cached, else the recipe's spell name)
--   Anniversary:           Guild OS's guild recipe index (recipes some member knows)
-- plus the items of earlier orders. Built once on first use, rebuilt when the guild's data changed.
-- Every other item comes from Items.lua, searched in place (no copy here).
local _, ns = ...
local GOS = GuildOS

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local IsCached = C_Item and C_Item.IsItemDataCachedByID

local cache, builtAt

local function Build()
  local list, byId, byName = {}, {}, {}
  local function add(id, name, crafters, onlyNew)
    if not id or id <= 0 or type(name) ~= "string" or name == "" then return end
    local e = byId[id]
    if e then
      e.crafters = math.max(e.crafters, crafters or 0)
      return
    end
    local lower = name:lower()
    if onlyNew and byName[lower] then return end -- one entry per name is enough
    e = { id = id, name = name, lower = lower, crafters = crafters or 0 }
    byId[id] = e
    byName[lower] = e
    list[#list + 1] = e
  end

  local cat, dir, P = GOS.ProfCatalog, GOS.ProfDirectory, GOS.Professions
  if cat and cat.recipes and cat.F and dir then
    local F = cat.F
    for recipeId, r in pairs(cat.recipes) do
      local out = r[F.out]
      if out and out > 0 then
        -- the item's own name only when cached: asking for 2000 uncached items floods the server
        local cached = IsCached and IsCached(out)
        local name = (cached and GetItemInfo(out)) or dir.RecipeName(recipeId)
        if name and not name:find("^#") then
          local n = (P and P.CraftersOf) and #P:CraftersOf(recipeId) or 0
          add(out, name, n)
        end
      end
    end
  end

  local rt = GOS.RecipeTracker
  if rt and rt.BuildRecipeIndex and not dir then
    local ok, index = pcall(rt.BuildRecipeIndex, rt)
    for _, e in ipairs(ok and index or {}) do add(e.itemId, e.name, e.crafters and #e.crafters or 0) end
  end

  local g = ns.G()
  for _, o in pairs(g and g.orders or {}) do
    if o.it then add(o.it, GetItemInfo(o.it) or o.txt, 0) end
  end

  cache, builtAt = list, GetTime()
end

-- drop the list after the guild's recipes changed (at most once a minute)
function ns.InvalidateSuggestions()
  if builtAt and GetTime() - builtAt > 60 then cache = nil end
end

-- up to `max` items for the typed text: names starting with it first, then names containing it;
-- within each, items a guild member can craft first, then alphabetical
function ns.Suggest(text, max)
  text = strtrim(text or ""):lower()
  if #text < 2 then return {} end
  if not cache then Build() end
  local starts, contains = {}, {}
  for _, e in ipairs(cache) do
    local at = e.lower:find(text, 1, true)
    if at == 1 then starts[#starts + 1] = e
    elseif at then contains[#contains + 1] = e end
  end
  local function order(a, b)
    if (a.crafters > 0) ~= (b.crafters > 0) then return a.crafters > 0 end
    return a.lower < b.lower
  end
  table.sort(starts, order)
  table.sort(contains, order)
  max = max or 8
  local crafted, skip = {}, {}
  for _, l in ipairs({ starts, contains }) do
    for _, e in ipairs(l) do
      skip[e.id], skip[e.lower] = true, true
      crafted[#crafted + 1] = e
    end
  end
  -- every other item of the game (Items.lua): herbs, ore, bars, drops ... Up to three of them
  -- always get a place, or "mithril" would list only the many mithril crafts and never the ore.
  local others = ns.FindItems and ns.FindItems(text, max, skip) or {}
  local out = {}
  local first = max - math.min(3, #others)
  for i = 1, math.min(first, #crafted) do out[#out + 1] = crafted[i] end
  local ci = #out + 1
  for _, e in ipairs(others) do
    if #out >= max then break end
    out[#out + 1] = e
  end
  while #out < max and crafted[ci] do out[#out + 1] = crafted[ci]; ci = ci + 1 end
  return out
end

-- the item for an exactly typed name (any case), or nil
function ns.ExactItem(text)
  text = strtrim(text or ""):lower()
  if text == "" then return nil end
  if not cache then Build() end
  for _, e in ipairs(cache) do
    if e.lower == text then return e.id end
  end
  return ns.FindExactItem and ns.FindExactItem(text)
end
