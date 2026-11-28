-- Guild OS 2 groups its tabs into rooms (Salão, Raids, Members, Workshop, ...). A tab no room names
-- lands in the Salão; ours go where they belong instead:
--   Marketplace -> Workshop (next to Crafts), Board -> Salão (next to Notices),
--   My Char -> Members, Keys -> Raids (next to Groups)
-- Older Guild OS has no rooms: then nothing happens and the tabs stay as they were.
local _, ns = ...
local L = ns.L
local UI = GuildOS and GuildOS.UI

local PLACES = {
  { room = "workshop", after = "crafts",   id = "gou_market", label = L.M_TAB, feature = ns.FEATURE },
  { room = "salao",    after = "bulletin", id = "gou_board",  label = L.B_TAB, feature = ns.BOARD_FEATURE },
  { room = "members",  after = "roster",   id = "gou_mychar", label = L.S_TAB, feature = ns.MYCHAR_FEATURE },
  { room = "raids",    after = "groups",   id = "gou_keys",   label = L.K_TAB, feature = ns.KEYS_FEATURE },
}

local function Place()
  if not (UI and type(UI.ROOMS) == "table") then return end
  for _, p in ipairs(PLACES) do
    local room
    for _, r in ipairs(UI.ROOMS) do if r.id == p.room then room = r end end
    if room and type(room.entries) == "table" and p.feature then
      local at, there = #room.entries + 1, false
      for i, e in ipairs(room.entries) do
        if e.feature == p.feature then there = true end
        if e.id == p.after then at = i + 1 end
      end
      if not there then
        table.insert(room.entries, at, { id = p.id, label = p.label, feature = p.feature })
      end
    end
  end
end

GuildOS:SafeCall(Place)
