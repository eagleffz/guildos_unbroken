-- The "Market" tab in the Guild OS window: put up an item (drag it from your bags onto the slot or
-- the field, shift-click it, or type it) or a service, and see what the guild offers. Plus /gmarkt.
local _, ns = ...
local L = ns.L
local GOS = GuildOS
local UI = GOS.UI
local C = GOS.Colors

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROW_H = 34
local BTN_W = 80
local BTN_H = 20
local FIELD_H = 22
local LIST_TOP = -58
local GOLD = { 0.85, 0.66, 0.31 }
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function EditBox(parent, w, hint, numeric)
  local b = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  b:SetSize(w, FIELD_H)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  b:SetBackdropColor(0.05, 0.05, 0.066, 1)
  b:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)
  GOS:ApplyFont(b, 11)
  b:SetTextColor(C.white.r, C.white.g, C.white.b)
  b:SetTextInsets(6, 6, 0, 0)
  b:SetAutoFocus(false)
  if numeric then b:SetNumeric(true); b:SetMaxLetters(4) end
  b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if hint then
    local ph = b:CreateFontString(nil, "OVERLAY")
    GOS:ApplyFont(ph, 11)
    ph:SetPoint("LEFT", 6, 0)
    ph:SetTextColor(0.4, 0.4, 0.4)
    ph:SetText(hint)
    b.hint = ph
    local function upd() ph:SetShown(b:GetText() == "" and not b:HasFocus()) end
    b:HookScript("OnTextChanged", upd)
    b:HookScript("OnEditFocusGained", upd)
    b:HookScript("OnEditFocusLost", upd)
    upd()
  end
  return b
end

local function Tip(frame, title, text)
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 1, 1)
    GameTooltip:AddLine(text, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- "Biete" green, "Suche" orange
function ns.OfferTag(o)
  if ns.OfferSeek(o) then return "|cffff9933" .. L.M_TAG_SEEK .. "|r" end
  return "|cff40c040" .. L.M_TAG_OFFER .. "|r"
end

-- the entry's tooltip (used by the popup too)
function ns.OfferTooltip(tt, o)
  local seek = ns.OfferSeek(o)
  if o.it then tt:SetHyperlink("item:" .. o.it)
  else tt:AddLine(o.txt, 0.5, 0.75, 1) ; tt:AddLine(L.M_SERVICE, 0.7, 0.7, 0.7) end
  tt:AddLine(" ")
  tt:AddLine(ns.OfferTag(o) .. "  " .. L.P_LEADER:format(ns.ColorName(o.by)) .. "  ·  " .. ns.Ago(o.c), 1, 1, 1)
  if o.it and o.n > 1 then tt:AddLine(L.M_QTY_LINE:format(o.n), 1, 1, 1) end
  if o.pr then tt:AddLine(L.M_PRICE_LINE:format(o.pr), GOLD[1], GOLD[2], GOLD[3]) end
  if o.note then tt:AddLine(o.note, 1, 1, 1, true) end
  local have = seek and ns.OfferHave(o) or 0
  if have > 0 then tt:AddLine(L.M_YOU_HAVE:format(have), 0.25, 1, 0.25) end
  local wants = ns.OfferWants(o)
  if #wants > 0 then
    tt:AddLine(" ")
    tt:AddLine(seek and L.M_HAD_BY or L.M_WANTED_BY, GOLD[1], GOLD[2], GOLD[3])
    for _, who in ipairs(wants) do
      local on = ns.IsOnline(who) or who == ns.Me()
      tt:AddDoubleLine(ns.ColorName(who), on and L.P_ONLINE or L.P_OFFLINE,
        1, 1, 1, on and 0.25 or 0.5, on and 1 or 0.5, on and 0.25 or 0.5)
    end
  end
end

local function Matches(o, filter, me, mine)
  if not ns.OfferLive(o) then return false end
  if filter == "offers" then return not ns.OfferSeek(o) end
  if filter == "seeks" then return ns.OfferSeek(o) end
  if filter == "items" then return o.it ~= nil end
  if filter == "services" then return o.it == nil end
  if filter == "mine" then return o.by == me or mine end
  return true
end

local function Actions(o, me, mine)
  local out = {}
  local function add(label, fn) out[#out + 1] = { label, fn } end
  local seek = ns.OfferSeek(o)
  if o.by == me then
    add(seek and L.M_GOT or L.M_SOLD, ns.SoldOffer)
    add(L.M_REMOVE, ns.RemoveOffer)
  else
    -- the same answer either way: "I want it" on an offer, "I have it" on a request
    if mine then add(seek and L.M_UNHAVE or L.M_UNWANT, ns.UnwantOffer)
    else add(seek and L.M_HAVE or L.M_WANT, ns.WantOffer) end
    add(L.B_WHISPER, function() ns.Whisper(o.by) end)
  end
  return out
end

function ns.BuildMarketPanel(panel)
  local filter = "all"
  local seekMode = false -- the form puts up a request ("Suche") instead of an offer ("Biete")
  local refresh

  ---------------------------------------------------------------- line 1: the new entry
  local kindBtn = UI:CreateButton(panel, L.M_KIND_OFFER, 76, FIELD_H)
  kindBtn:SetPoint("TOPLEFT", 8, -6)
  Tip(kindBtn, L.M_KIND_OFFER .. " / " .. L.M_KIND_SEEK, L.M_KIND_TT)

  local slot = CreateFrame("Button", nil, panel, "BackdropTemplate")
  slot:SetSize(FIELD_H, FIELD_H)
  slot:SetPoint("LEFT", kindBtn, "RIGHT", 4, 0)
  slot:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  slot:SetBackdropColor(0.05, 0.05, 0.066, 1)
  slot:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.6)
  slot.icon = slot:CreateTexture(nil, "ARTWORK")
  slot.icon:SetPoint("TOPLEFT", 1, -1)
  slot.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  slot.icon:SetTexture(EMPTY_SLOT)
  slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  Tip(slot, L.M_SLOT, L.M_SLOT_TT)

  local itemBox = EditBox(panel, 200, L.M_ITEM_HINT)
  itemBox:SetPoint("LEFT", slot, "RIGHT", 4, 0)
  local qtyBox = EditBox(panel, 38, nil, true)
  qtyBox:SetPoint("LEFT", itemBox, "RIGHT", 4, 0)
  qtyBox:SetText("1")
  Tip(qtyBox, L.QTY, L.M_QTY_TT)
  local priceBox = EditBox(panel, 110, L.M_PRICE_HINT)
  priceBox:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
  priceBox:SetMaxLetters(30)
  local noteBox = EditBox(panel, 140, L.NOTE_HINT)
  noteBox:SetPoint("LEFT", priceBox, "RIGHT", 4, 0)
  noteBox:SetMaxLetters(150)
  local createBtn = UI:CreateButton(panel, L.M_CREATE, 90, FIELD_H)
  UI:SetButtonVariant(createBtn, "primary")
  -- the button sits at the right edge (in line with the list), the note field takes the room between
  createBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -6)
  noteBox:SetPoint("RIGHT", createBtn, "LEFT", -6, 0)

  local function PaintKind()
    local col = seekMode and { 1, 0.6, 0.2 } or { 0.25, 0.75, 0.25 }
    kindBtn.label:SetText(seekMode and L.M_KIND_SEEK or L.M_KIND_OFFER)
    kindBtn.baseLabelColor = col
    kindBtn.label:SetTextColor(col[1], col[2], col[3])
    createBtn.label:SetText(seekMode and L.M_CREATE_SEEK or L.M_CREATE)
    if priceBox.hint then priceBox.hint:SetText(seekMode and L.M_PRICE_HINT_SEEK or L.M_PRICE_HINT) end
  end
  kindBtn:SetScript("OnClick", function() seekMode = not seekMode; PaintKind() end)
  PaintKind()

  local picked -- { id, text }: the item taken (dropped, shift-clicked or picked), while the field shows it

  local function SetItem(id, link)
    local name, l = GetItemInfo(id)
    link = link or l
    picked = { id = id, text = link or name or ("item:" .. id) }
    itemBox.quiet = true
    itemBox:SetText(picked.text)
    itemBox.quiet = nil
    itemBox:ClearFocus()
    local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    slot.icon:SetTexture((GetIcon and GetIcon(id)) or EMPTY_SLOT)
    priceBox:SetFocus()
  end

  local function ClearSlot()
    slot.icon:SetTexture(EMPTY_SLOT)
  end

  -- an item on the cursor (dragged from the bags) goes into the form
  local function TakeCursor()
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" or not id then return false end
    ClearCursor()
    SetItem(id, link)
    return true
  end
  slot:SetScript("OnReceiveDrag", TakeCursor)
  slot:SetScript("OnClick", function() if not TakeCursor() then itemBox:SetFocus() end end)
  itemBox:SetScript("OnReceiveDrag", TakeCursor)
  itemBox:HookScript("OnMouseUp", function() TakeCursor() end)

  ---------------------------------------------------------------- line 2: filters and options
  local filterBtns = {}
  local function PaintFilters()
    for key, b in pairs(filterBtns) do
      local col = key == filter and C.gold or C.text
      b.baseLabelColor = { col.r, col.g, col.b }
      b.label:SetTextColor(col.r, col.g, col.b)
    end
  end
  local x = 8
  for _, f in ipairs({ { "all", L.F_ACTIVE }, { "offers", L.M_F_OFFERS }, { "seeks", L.M_F_SEEKS },
                       { "items", L.M_F_ITEMS }, { "services", L.M_F_SERVICES }, { "mine", L.F_MINE } }) do
    local b = UI:CreateButton(panel, f[2], 60, BTN_H)
    b:SetPoint("TOPLEFT", x, -33)
    b:SetScript("OnClick", function() filter = f[1]; PaintFilters(); refresh() end)
    filterBtns[f[1]] = b
    x = x + b:GetWidth() + 4
  end
  local function Check(label, tipTitle, tipText, anchor, gap)
    local c = UI:CreateCheckbox(panel, label, 18)
    if anchor then c:SetPoint("LEFT", anchor, "RIGHT", gap, 0) else c:SetPoint("TOPLEFT", x + 14, -34) end
    c:SetWidth(c.label:GetStringWidth() + 26)
    Tip(c, tipTitle, tipText)
    return c
  end
  local notifyCheck = Check(L.P_NOTIFY, L.P_NOTIFY, L.M_NOTIFY_TT)
  notifyCheck.checkbox.onChanged = function(_, checked) ns.db.settings.marketNotify = checked and true or false end
  local popupCheck = Check(L.POPUP, L.POPUP, L.M_POPUP_TT, notifyCheck, 8)
  popupCheck.checkbox.onChanged = function(_, checked) ns.db.settings.marketPopup = checked and true or false end

  local function PaintChecks()
    notifyCheck.checkbox:SetChecked(ns.db.settings.marketNotify ~= false)
    popupCheck.checkbox:SetChecked(ns.db.settings.marketPopup ~= false)
  end

  ---------------------------------------------------------------- item suggestions (services: just type)
  local SUG_N, SUG_H = 8, 20
  local drop = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  drop:SetPoint("TOPLEFT", itemBox, "BOTTOMLEFT", 0, -2)
  drop:SetWidth(320)
  drop:SetFrameStrata("DIALOG")
  drop:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  drop:SetBackdropColor(0.058, 0.058, 0.075, 0.98)
  drop:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
  drop:Hide()

  local sugBtns, sugItems, sel = {}, {}, 0
  local function PaintSel() for i, b in ipairs(sugBtns) do b.hl:SetShown(i == sel) end end
  local function Pick(e) if e then drop:Hide(); SetItem(e.id) end end

  for i = 1, SUG_N do
    local b = CreateFrame("Button", nil, drop)
    b:SetHeight(SUG_H)
    b:SetPoint("TOPLEFT", 1, -1 - (i - 1) * SUG_H)
    b:SetPoint("RIGHT", drop, "RIGHT", -1, 0)
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(C.gold.r, C.gold.g, C.gold.b, 0.18)
    b.hl:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.name = UI:CreateText(b, "", 11)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", -6, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetScript("OnEnter", function() sel = i; PaintSel() end)
    b:SetScript("OnClick", function() Pick(sugItems[i]) end)
    sugBtns[i] = b
  end

  local function ShowSuggestions(text)
    local list = (text:find("|H", 1, true) or not ns.Suggest) and {} or ns.Suggest(text, SUG_N)
    sugItems = list
    for i, b in ipairs(sugBtns) do
      local e = list[i]
      if e then
        b.icon:SetTexture(ns.OfferIcon({ it = e.id }))
        b.name:SetText(e.name)
        b:Show()
      else
        b:Hide()
      end
    end
    sel = 0 -- nothing preselected: Enter keeps the text as a service
    PaintSel()
    drop:SetHeight(#list * SUG_H + 2)
    drop:SetShown(#list > 0)
  end

  itemBox:HookScript("OnTextChanged", function(self, userInput)
    if self.quiet then return end
    picked = nil
    ClearSlot()
    if userInput then ShowSuggestions(self:GetText()) else drop:Hide() end
  end)
  itemBox:SetScript("OnArrowPressed", function(_, key)
    if not drop:IsShown() then return end
    if key == "UP" then sel = math.max(1, sel - 1)
    elseif key == "DOWN" then sel = math.min(#sugItems, sel + 1) end
    PaintSel()
  end)
  itemBox:SetScript("OnEscapePressed", function(self)
    if drop:IsShown() then drop:Hide() else self:ClearFocus() end
  end)
  itemBox:HookScript("OnEditFocusLost", function()
    C_Timer.After(0.3, function()
      if not itemBox:HasFocus() and not drop:IsMouseOver() then drop:Hide() end
    end)
  end)

  local function Submit()
    local still = picked and itemBox:GetText() == picked.text
    local o = ns.CreateOffer(itemBox:GetText(), qtyBox:GetText(), priceBox:GetText(), noteBox:GetText(),
      still and picked.id or nil, seekMode)
    if o then
      itemBox:SetText(""); priceBox:SetText(""); noteBox:SetText(""); qtyBox:SetText("1")
      itemBox:ClearFocus(); priceBox:ClearFocus(); noteBox:ClearFocus(); qtyBox:ClearFocus()
      picked = nil
      ClearSlot()
      drop:Hide()
    end
  end
  createBtn:SetScript("OnClick", Submit)
  qtyBox:SetScript("OnEnterPressed", Submit)
  priceBox:SetScript("OnEnterPressed", Submit)
  noteBox:SetScript("OnEnterPressed", Submit)
  itemBox:SetScript("OnEnterPressed", function()
    if drop:IsShown() and sugItems[sel] then Pick(sugItems[sel]) else drop:Hide(); priceBox:SetFocus() end
  end)
  itemBox:SetScript("OnTabPressed", function()
    if drop:IsShown() and sugItems[sel] then Pick(sugItems[sel]) else drop:Hide(); qtyBox:SetFocus() end
  end)
  qtyBox:SetScript("OnTabPressed", function() priceBox:SetFocus() end)
  priceBox:SetScript("OnTabPressed", function() noteBox:SetFocus() end)
  noteBox:SetScript("OnTabPressed", function() itemBox:SetFocus() end)

  -- shift-click an item while the tab is open: it goes into the form, unless a chat line is typed
  if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
      if type(link) ~= "string" or not panel:IsVisible() or not IsShiftKeyDown() then return end
      local id = tonumber(link:match("item:(%d+)"))
      if not id then return end
      local chat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
      if chat and not itemBox:HasFocus() then return end
      SetItem(id, link)
      drop:Hide()
    end)
  end

  ---------------------------------------------------------------- list
  local scroll, content = UI:CreateScrollFrame(panel, "GuildOSMarketScroll")
  scroll:SetPoint("TOPLEFT", 4, LIST_TOP)
  scroll:SetPoint("BOTTOMRIGHT", -6, 4)
  UI:BindScrollChildWidth(scroll, content, 16) -- clear of Guild OS's scroll bar
  local empty = UI:CreateText(content, L.M_EMPTY, 11, C.textDim.r, C.textDim.g, C.textDim.b)
  empty:SetPoint("TOPLEFT", 8, -8)

  local rows = {}
  local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, content, "BackdropTemplate")
    row:SetHeight(ROW_H - 1)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    row:SetBackdrop({ bgFile = WHITE })
    local bg = (i % 2 == 0) and C.row2 or C.row1
    row:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      if not self.offer then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      ns.OfferTooltip(GameTooltip, self.offer)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.icon = UI:CreateIcon(row, 22)
    row.icon:SetPoint("LEFT", 4, 0)
    row.b1 = UI:CreateButton(row, "", BTN_W, BTN_H)
    row.b1:SetPoint("RIGHT", -4, 0)
    row.b2 = UI:CreateButton(row, "", BTN_W, BTN_H)
    row.b2:SetPoint("RIGHT", row.b1, "LEFT", -4, 0)

    local function text(size, y, col)
      local fs = UI:CreateText(row, "", size, col.r, col.g, col.b)
      fs:SetJustifyH("LEFT")
      fs:SetWordWrap(false)
      fs:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, y)
      fs:SetPoint("RIGHT", row, "RIGHT", -(2 * BTN_W + 16), 0)
      return fs
    end
    row.title = text(11, 0, C.text)
    row.meta = text(10, -14, C.textDim)
    rows[i] = row
    return row
  end

  local function FillButton(btn, action, o)
    if not action then btn:Hide() return end
    btn.label:SetText(action[1])
    btn:SetWidth(BTN_W)
    btn:SetScript("OnClick", function() action[2](o) end)
    btn:Show()
  end

  local shownItems = {} -- item ids on screen: only their arrival needs a redraw
  refresh = function()
    if not panel:IsVisible() then return end
    PaintChecks()
    wipe(shownItems)
    local g, me = ns.MarketStore(), ns.Me()
    local list = {}
    for _, o in pairs(g and g.offers or {}) do
      local wants, mine = ns.OfferWants(o)
      if Matches(o, filter, me, mine) then list[#list + 1] = { o = o, w = wants, mine = mine } end
    end
    table.sort(list, function(a, b) return (a.o.c or 0) > (b.o.c or 0) end)

    for i, e in ipairs(list) do
      local o, wants, mine = e.o, e.w, e.mine
      local row = GetRow(i)
      row.offer = o
      if o.it then shownItems[o.it] = true end
      row.icon.icon:SetTexture(ns.OfferIcon(o))
      local seek = ns.OfferSeek(o)
      row.title:SetText(ns.OfferTag(o) .. "  " .. ns.OfferLabel(o) .. (o.pr and ("  |cffffd100" .. o.pr .. "|r") or "")
        .. (o.it and "" or ("  |cff888888" .. L.M_SERVICE .. "|r")))
      local meta = { L.P_LEADER:format(ns.ColorName(o.by)), ns.Ago(o.c) }
      if #wants > 0 then
        local names = {}
        for j = 1, math.min(3, #wants) do names[j] = ns.ColorName(wants[j]) end
        meta[#meta + 1] = (seek and L.M_HAS_IT or L.M_WANTS):format(#wants,
          table.concat(names, ", ") .. (#wants > 3 and " …" or ""))
      end
      if mine then meta[#meta + 1] = "|cff40ff40" .. (seek and L.M_YOU_HAVE_IT or L.M_YOU_WANT) .. "|r" end
      local have = (seek and o.by ~= me and not mine) and ns.OfferHave(o) or 0
      if have > 0 then meta[#meta + 1] = "|cff40ff40" .. L.M_YOU_HAVE:format(have) .. "|r" end
      if o.note then meta[#meta + 1] = "|cffffffff\"" .. o.note .. "\"|r" end
      row.meta:SetText(table.concat(meta, " · "))

      local acts = Actions(o, me, mine)
      FillButton(row.b1, acts[1], o)
      FillButton(row.b2, acts[2], o)
      row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].offer = nil end
    empty:SetShown(#list == 0)
    content:SetHeight(math.max(1, #list * ROW_H))
  end

  ns.OnChanged(refresh)
  panel:HookScript("OnShow", function()
    if ns.Start then ns.Start() end
    GOS:SafeCall(refresh)
  end)
  local ev = CreateFrame("Frame", nil, panel)
  ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  ev:SetScript("OnEvent", function(_, _, id)
    if panel:IsVisible() and shownItems[id] then ns.Changed() end
  end)

  PaintFilters()
  GOS:SafeCall(refresh)
  return refresh
end

---------------------------------------------------------------- registration
UI:RegisterFeature({
  id = ns.MARKET_FEATURE, label = L.M_TAB, desc = L.M_FEATURE_DESC, order = 47,
  build = function(c) return ns.BuildMarketPanel(c) end,
})

SLASH_GUILDOSMARKET1 = "/gmarkt"
SLASH_GUILDOSMARKET2 = "/gmarket"
SlashCmdList.GUILDOSMARKET = function() UI:OpenWindow(ns.MARKET_FEATURE) end
