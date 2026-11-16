-- Material groups for skilling calls: "send me any cloth / leather / ore & bars you don't need".
-- An item belongs to a group by its ID (classic materials below) or, on clients that sort trade
-- goods into subclasses (TBC and later, retail), by its item subclass.
local _, ns = ...
local L = ns.L

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

ns.GROUP_ORDER = { "cloth", "leather", "ore", "stone", "herb", "ench" }

ns.GROUPS = {
  cloth = {
    icon = "Interface\\Icons\\INV_Fabric_Linen_01", words = "stoff tuch cloth fabric",
    ids = { 2589, 2592, 4306, 4338, 14047, 14256, 14342,   -- linen .. runecloth, felcloth, mooncloth
            2996, 2997, 4305, 4339, 14048 },                -- bolts
  },
  leather = {
    icon = "Interface\\Icons\\INV_Misc_LeatherScrap_03", words = "leder balg bälge felle leather hide skin",
    ids = { 2934, 2318, 2319, 4234, 4304, 8170,             -- scraps, light .. rugged leather
            783, 4232, 4235, 8169, 8171,                    -- hides
            4231, 4233, 4236, 8172, 15407 },                -- cured hides
  },
  ore = {
    icon = "Interface\\Icons\\INV_Ore_Copper_01", words = "erz barren metall ore bar bars metal",
    ids = { 2770, 2771, 2772, 2775, 2776, 3858, 7911, 10620, 11370,             -- ores
            2840, 3576, 2841, 3575, 3859, 2842, 3577, 3860, 6037, 12359, 11371 }, -- bars
  },
  stone = {
    icon = "Interface\\Icons\\INV_Stone_02", words = "stein steine stone stones",
    ids = { 2835, 2836, 2838, 7912, 12365 },
  },
  herb = {
    icon = "Interface\\Icons\\INV_Misc_Herb_10", words = "kraut kräuter pflanzen herb herbs",
    ids = { 2447, 765, 2449, 785, 2450, 2452, 2453, 3820, 3355, 3369, 3356, 3357, 3818, 3821,
            3358, 3819, 4625, 8831, 8836, 8838, 8839, 8845, 8846, 13464, 13463, 13465, 13466,
            13467, 13468 },
  },
  ench = {
    icon = "Interface\\Icons\\INV_Enchant_DustStrange", words = "verzauberung staub essenz splitter enchanting dust essence shard",
    ids = { 10940, 11083, 11137, 11176, 16204,                      -- dusts
            10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203, -- essences
            10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344 },           -- shards
  },
}

-- trade goods (item class 7) subclasses on clients that have them
local SUBCLASS = { [5] = "cloth", [6] = "leather", [7] = "ore", [9] = "herb", [12] = "ench" }

local byId = {}
for key, g in pairs(ns.GROUPS) do
  for _, id in ipairs(g.ids) do byId[id] = key end
end

function ns.GroupLabel(key) return L["GROUP_" .. key] end

-- the group an item belongs to, or nil
function ns.ItemGroup(id)
  if byId[id] then return byId[id] end
  if GetItemInfoInstant then
    local _, _, _, _, _, classID, subID = GetItemInfoInstant(id)
    if classID == 7 then return SUBCLASS[subID] end
  end
end

-- what I carry in my bags: { [itemID] = count }
local function BagItems()
  local out = {}
  local C = C_Container
  local numSlots = (C and C.GetContainerNumSlots) or GetContainerNumSlots
  for bag = 0, NUM_BAG_SLOTS or 4 do
    for slot = 1, (numSlots and numSlots(bag)) or 0 do
      local id, count
      if C and C.GetContainerItemInfo then
        local info = C.GetContainerItemInfo(bag, slot)
        if info then id, count = info.itemID, info.stackCount end
      elseif GetContainerItemInfo then
        local _, c, _, _, _, _, link = GetContainerItemInfo(bag, slot)
        id, count = link and tonumber(link:match("item:(%d+)")), c
      end
      if id then out[id] = (out[id] or 0) + (count or 1) end
    end
  end
  return out
end

-- a group's items in my bags: { { id, count }, ... } (most first) and the total
function ns.GroupHoldings(key)
  local list, total = {}, 0
  for id, n in pairs(BagItems()) do
    if ns.ItemGroup(id) == key then
      list[#list + 1] = { id, n }
      total = total + n
    end
  end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  return list, total
end

-- groups for the typed text (name or keyword); every group when `all` and nothing is typed
function ns.SuggestGroups(text, all)
  text = strtrim(text or ""):lower()
  local out = {}
  if text == "" and not all then return out end
  for _, key in ipairs(ns.GROUP_ORDER) do
    local g = ns.GROUPS[key]
    local label = ns.GroupLabel(key)
    if text == "" or #text >= 2 and ((label:lower() .. " " .. g.words):find(text, 1, true)) then
      out[#out + 1] = { cat = key, name = label }
    end
  end
  return out
end

-- the group for an exactly typed group name (any case), or nil
function ns.GroupByName(text)
  text = strtrim(text or ""):lower()
  for _, key in ipairs(ns.GROUP_ORDER) do
    if ns.GroupLabel(key):lower() == text then return key end
  end
end
