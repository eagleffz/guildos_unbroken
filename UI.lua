-- The marketplace tab in the Guild OS window, with two halves: "Looking for" (this file: crafting
-- orders, skilling calls and plain requests for items or services, in one list and one form) and
-- "Offering" (MarketUI.lua). Built with Guild OS's own UI helpers, plus /gco.
-- Compact: the form is one line, filters and options a second, each entry a two-line row.
-- Under the hood orders and requests stay apart (own records, own sync): only the screen joins them.
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

local STATUS_COLOR = {
  open = "ffd9a94f", acc = "ff4fa3d9", dlv = "ff40c040", done = "ff808080", cxl = "ff804040",
}
local STATUS_ORDER = { open = 1, acc = 2, dlv = 3, done = 4, cxl = 5 }
local GOLD = { 0.85, 0.66, 0.31 }

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

local function Matches(o, filter, me)
  if ns.Finished(o) then return false end -- delivered, completed or cancelled: not listed
  if filter == "active" then return true end
  if filter == "forme" then
    if o.st ~= "open" or o.by == me then return false end
    if o.sk then return ns.HaveCount(o) > 0 end -- a skilling call I could send something for
    return ns.ICanCraft(o)
  end
  if filter == "items" then return o.it ~= nil or o.cat ~= nil end
  if filter == "services" then return o.it == nil and o.cat == nil end
  if filter == "mine" then return o.by == me or o.acc == me end
end

-- a plain request (the market's "Suche" record) in the same list
local function SeekMatches(o, filter, me, mine)
  if not ns.OfferLive(o) then return false end
  if filter == "active" then return true end
  if filter == "forme" then
    if o.by == me or mine then return false end
    return ns.OfferHave(o) > 0 or ns.SeekForMe(o)
  end
  if filter == "items" then return o.it ~= nil end
  if filter == "services" then return o.it == nil end
  if filter == "mine" then return o.by == me or mine end
end

-- an item a recipe makes: such a request becomes a crafting order (take it, deliver it)
local function Craftable(it)
  if not it then return false end
  local dir = GOS.ProfDirectory
  if dir and dir.ItemRecipes then
    local ok, list = pcall(dir.ItemRecipes, it)
    if ok and type(list) == "table" and #list > 0 then return true end
  end
  return ns.Crafters({ it = it }) ~= nil
end

-- the item a typed text means (link, id, a listed or cached name), or nil
local function ResolveItem(txt)
  txt = strtrim(txt or "")
  local it = tonumber(txt:match("item:(%d+)")) or tonumber(txt:match("^%d+$"))
  if it or txt == "" then return it end
  it = ns.ExactItem and ns.ExactItem(txt)
  if it then return it end
  local _, link = GetItemInfo(txt)
  return link and tonumber(link:match("item:(%d+)"))
end

-- the buttons a row offers: { { label, fn }, ... } (at most two)
local function Actions(o, me)
  local out = {}
  local function add(label, fn) out[#out + 1] = { label, fn } end
  -- a standing skilling call is never taken by one crafter: anyone just sends something
  -- (also when an older version marked it as taken)
  if o.sk and (o.st == "open" or o.st == "acc") then
    if o.by == me then add(L.B_END, ns.CancelOrder)
    else add(L.B_SENT, ns.SendLeftover); add(L.B_WHISPER, function() ns.Whisper(o.by) end) end
  elseif o.st == "open" then
    if o.by == me then add(L.B_CANCEL, ns.CancelOrder)
    else add(L.B_ACCEPT, ns.AcceptOrder); add(L.B_WHISPER, function() ns.Whisper(o.by) end) end
  elseif o.st == "acc" then
    if o.acc == me then add(L.B_DELIVER, ns.DeliverOrder); add(L.B_RETURN, ns.ReturnOrder)
    elseif o.by == me then add(L.B_WHISPER, function() ns.Whisper(o.acc) end); add(L.B_CANCEL, ns.CancelOrder) end
  end
  return out
end

local function Section(title)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(title, GOLD[1], GOLD[2], GOLD[3])
end

local function ShowTooltip(row)
  if row.seek then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    ns.OfferTooltip(GameTooltip, row.seek)
    GameTooltip:Show()
    return
  end
  local o = row.order
  if not o then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  if o.it then GameTooltip:SetHyperlink("item:" .. o.it)
  else GameTooltip:AddLine(o.cat and ns.GroupLabel(o.cat) or o.txt, 1, 1, 1) end
  if o.note then
    Section(L.TT_NOTE)
    GameTooltip:AddLine(o.note, 1, 1, 1, true)
  end
  if o.cat and o.by ~= ns.Me() then
    -- which of the group's items I could send
    local list = ns.GroupHoldings(o.cat)
    if #list > 0 then
      Section(L.TT_HAVE)
      for i, h in ipairs(list) do
        if i > 12 then break end
        GameTooltip:AddDoubleLine(ns.ItemName(h[1]), h[2], 1, 1, 1, 0.25, 1, 0.25)
      end
    end
  end
  local crafters = not o.sk and ns.Crafters(o)
  if crafters then
    Section(L.TT_CRAFTERS)
    for _, c in ipairs(crafters) do
      local who = ns.Short(c.playerName) or "?"
      local on = ns.IsOnline(who)
      local prof = c.profName and c.profName ~= "" and GOS.L[c.profName] or ""
      local spec = ns.CrafterSpec(c)
      if spec then prof = prof ~= "" and (prof .. " · " .. spec) or spec end
      GameTooltip:AddDoubleLine(ns.ColorName(who), prof,
        1, 1, 1, on and 0.25 or 0.5, on and 1 or 0.5, on and 0.25 or 0.5)
    end
  end
  local mats = o.sk and {} or ns.OrderMats(o)
  if #mats > 0 then
    Section(L.TT_MATS)
    for _, m in ipairs(mats) do
      local ok = m[3] >= m[2]
      GameTooltip:AddDoubleLine(m[2] .. "x " .. ns.ItemName(m[1]), m[3] .. "/" .. m[2],
        1, 1, 1, ok and 0.25 or 1, ok and 1 or 0.3, ok and 0.25 or 0.3)
    end
  end
  GameTooltip:Show()
end

function ns.BuildPanel(panel)
  local filter = "active"

  ---------------------------------------------------------------- line 1: the new order
  local itemBox = EditBox(panel, 250, L.ITEM_HINT)
  itemBox:SetPoint("TOPLEFT", 8, -6)
  local qtyBox = EditBox(panel, 38, nil, true)
  qtyBox:SetPoint("LEFT", itemBox, "RIGHT", 4, 0)
  qtyBox:SetText("1")
  Tip(qtyBox, L.QTY, L.QTY_TT)
  local noteBox = EditBox(panel, 200, L.NOTE_HINT)
  noteBox:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
  noteBox:SetMaxLetters(150)
  local createBtn = UI:CreateButton(panel, L.CREATE, 90, FIELD_H)
  UI:SetButtonVariant(createBtn, "primary")
  -- the button sits at the right edge (in line with the list), the note field takes the room between
  createBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -6)
  noteBox:SetPoint("RIGHT", createBtn, "LEFT", -6, 0)

  ---------------------------------------------------------------- line 2: filters and options
  local filterBtns = {}
  local refresh
  local function PaintFilters()
    for key, b in pairs(filterBtns) do
      local col = key == filter and C.gold or C.text
      b.baseLabelColor = { col.r, col.g, col.b }
      b.label:SetTextColor(col.r, col.g, col.b)
    end
  end
  local x = 8
  for _, f in ipairs({ { "active", L.F_ACTIVE }, { "forme", L.F_FORME }, { "items", L.M_F_ITEMS },
                       { "services", L.M_F_SERVICES }, { "mine", L.F_MINE } }) do
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
  local skCheck = Check(L.SKILL, L.SKILL_LONG, L.SKILL_TT)
  local msCheck = Check(L.MATS_MINE, L.MATS_MINE, L.MATS_TT, skCheck, 10)
  local notifyAll = Check(L.NOTIFY_ALL, L.NOTIFY_ALL, L.NOTIFY_TT, msCheck, 10)
  notifyAll.checkbox.onChanged = function(_, checked) ns.db.settings.notifyAll = checked and true or false end
  local popupCheck = Check(L.POPUP, L.POPUP, L.POPUP_TT, notifyAll, 10)
  popupCheck.checkbox.onChanged = function(_, checked) ns.db.settings.popup = checked and true or false end

  ---------------------------------------------------------------- suggestions under the item field
  -- typing "red" lists every craftable item with "red" in its name, "leder" the leather group;
  -- with "for skilling" ticked and nothing typed, every group. Arrows/mouse pick, Enter or Tab
  -- takes, Escape closes.
  local SUG_N, SUG_H = 8, 20
  local drop = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  drop:SetPoint("TOPLEFT", itemBox, "BOTTOMLEFT", 0, -2)
  drop:SetWidth(340)
  drop:SetFrameStrata("DIALOG")
  drop:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  drop:SetBackdropColor(0.058, 0.058, 0.075, 0.98)
  drop:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 1)
  drop:Hide()

  local sugBtns, sugItems, sel = {}, {}, 0
  local picked -- { id or cat, text }: the suggestion taken, while the field still shows its text

  local function PaintSel()
    for i, b in ipairs(sugBtns) do b.hl:SetShown(i == sel) end
  end

  local function Pick(e)
    if not e then return end
    local text = e.name
    if e.id then
      local _, link = GetItemInfo(e.id)
      text = link or e.name
    end
    picked = { id = e.id, cat = e.cat, svc = e.svc, text = text }
    itemBox.quiet = true
    itemBox:SetText(text)
    itemBox.quiet = nil
    drop:Hide()
    if e.svc then
      noteBox:SetFocus()
    elseif e.cat then
      -- a group only makes sense as a skilling call
      skCheck.checkbox:SetChecked(true)
      noteBox:SetFocus()
    else
      qtyBox:SetFocus()
      qtyBox:HighlightText()
    end
  end

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
    b.info = UI:CreateText(b, "", 10, C.textDim.r, C.textDim.g, C.textDim.b)
    b.info:SetPoint("RIGHT", -6, 0)
    b.name = UI:CreateText(b, "", 11)
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetPoint("RIGHT", b.info, "LEFT", -6, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetScript("OnEnter", function() sel = i; PaintSel() end)
    b:SetScript("OnClick", function() Pick(sugItems[i]) end)
    sugBtns[i] = b
  end

  local function ShowSuggestions(text)
    local list = {}
    if not text:find("|H", 1, true) then
      if not skCheck.checkbox:GetChecked() then
        for _, s in ipairs(ns.SuggestServices(text)) do list[#list + 1] = s end
      end
      for _, gr in ipairs(ns.SuggestGroups(text, skCheck.checkbox:GetChecked())) do list[#list + 1] = gr end
      if #list < SUG_N then
        for _, e in ipairs(ns.Suggest(text, SUG_N - #list)) do list[#list + 1] = e end
      end
    end
    sugItems = list
    for i, b in ipairs(sugBtns) do
      local e = list[i]
      if e then
        b.icon:SetTexture(e.svc and e.icon or ns.ItemIcon({ it = e.id, cat = e.cat }))
        b.name:SetText(e.cat and ("|cffffd100" .. e.name .. "|r") or e.svc and ("|cff80c0ff" .. e.name .. "|r") or e.name)
        if e.svc then b.info:SetText("|cff888888" .. L.M_SERVICE .. "|r")
        elseif e.cat then b.info:SetText("|cffb080ff" .. L.GROUP .. "|r")
        else b.info:SetText(e.crafters > 0 and ("|cff40ff40" .. L.SUG_CRAFTERS:format(e.crafters) .. "|r") or "") end
        b:Show()
      else
        b:Hide()
      end
    end
    sel = #list > 0 and 1 or 0
    PaintSel()
    drop:SetHeight(#list * SUG_H + 2)
    drop:SetShown(#list > 0)
  end

  itemBox:HookScript("OnTextChanged", function(self, userInput)
    if self.quiet then return end
    picked = nil
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
    -- a click on the list takes the focus first: let the click land
    C_Timer.After(0.3, function()
      if not itemBox:HasFocus() and not drop:IsMouseOver() then drop:Hide() end
    end)
  end)
  -- ticking "for skilling" with an empty item field offers the groups right away
  skCheck.checkbox.onChanged = function(_, checked)
    if checked and itemBox:GetText() == "" then
      itemBox:SetFocus()
      ShowSuggestions("")
    end
  end
  ns.OnChanged(ns.InvalidateSuggestions)

  -- One form for everything wanted: a skilling call (ticked, or a material group), a crafting order
  -- (an item a recipe makes), else a plain request for an item or a service.
  local function Submit()
    local text = itemBox:GetText()
    local still = picked and text == picked.text
    local sk = skCheck.checkbox:GetChecked()
    local cat = still and picked.cat or nil
    local it = still and picked.id or nil
    if not (sk or cat or ns.GroupByName(text)) and not (still and picked.svc) then
      it = it or ResolveItem(text)
    end
    local o
    if sk or cat or ns.GroupByName(text) or (it and Craftable(it)) then
      o = ns.CreateOrder(text, qtyBox:GetText(), noteBox:GetText(),
        msCheck.checkbox:GetChecked(), it, sk, cat)
    else
      o = ns.CreateOffer(text, qtyBox:GetText(), nil, noteBox:GetText(), it, true)
    end
    if o then
      itemBox:SetText(""); noteBox:SetText(""); qtyBox:SetText("1")
      itemBox:ClearFocus(); noteBox:ClearFocus(); qtyBox:ClearFocus()
      msCheck.checkbox:SetChecked(false)
      skCheck.checkbox:SetChecked(false)
      picked = nil
      drop:Hide()
    end
  end
  createBtn:SetScript("OnClick", Submit)
  qtyBox:SetScript("OnEnterPressed", Submit)
  noteBox:SetScript("OnEnterPressed", Submit)
  itemBox:SetScript("OnEnterPressed", function()
    if drop:IsShown() and sugItems[sel] then Pick(sugItems[sel]) else Submit() end
  end)
  itemBox:SetScript("OnTabPressed", function()
    if drop:IsShown() and sugItems[sel] then Pick(sugItems[sel]) else qtyBox:SetFocus() end
  end)
  qtyBox:SetScript("OnTabPressed", function() noteBox:SetFocus() end)
  noteBox:SetScript("OnTabPressed", function() itemBox:SetFocus() end)

  -- shift-click an item (bags, chat, tooltips) while the tab is open: it goes into the item field,
  -- unless a chat line is being typed
  if HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link)
      if type(link) ~= "string" or not link:find("item:", 1, true) then return end
      if not panel:IsVisible() or not IsShiftKeyDown() then return end
      local chat = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
      if chat and not itemBox:HasFocus() then return end
      itemBox:SetText(link)
      itemBox:ClearFocus()
      drop:Hide()
    end)
  end

  ---------------------------------------------------------------- list
  local scroll, content = UI:CreateScrollFrame(panel, "GuildOSUnbrokenScroll")
  scroll:SetPoint("TOPLEFT", 4, LIST_TOP)
  scroll:SetPoint("BOTTOMRIGHT", -6, 4)
  -- Guild OS draws its scroll bar inside the scroll frame's right edge (8 px, 2 px in):
  -- keep the rows clear of it
  UI:BindScrollChildWidth(scroll, content, 16)
  local empty = UI:CreateText(content, L.EMPTY, 11, C.textDim.r, C.textDim.g, C.textDim.b)
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
    row:SetScript("OnEnter", ShowTooltip)
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

  local shownItems = {} -- the item ids on screen: only their arrival needs a redraw
  refresh = function()
    if not panel:IsVisible() then return end
    wipe(shownItems)
    popupCheck.checkbox:SetChecked(ns.db.settings.popup ~= false)
    local g, me = ns.G(), ns.Me()
    local list = {}
    for _, o in pairs(g and g.orders or {}) do
      if not ns.OrderExpired(o) and Matches(o, filter, me) then list[#list + 1] = o end
    end
    -- plain requests from the market records join the list (they count as "open")
    local seeks = {}
    local ms = ns.MarketStore and ns.MarketStore()
    for _, o in pairs(ms and ms.offers or {}) do
      if ns.OfferSeek(o) then
        local wants, mine = ns.OfferWants(o)
        if SeekMatches(o, filter, me, mine) then
          seeks[o] = { wants, mine }
          list[#list + 1] = o
        end
      end
    end
    local function rank(o) return seeks[o] and 1 or STATUS_ORDER[o.st] end
    table.sort(list, function(a, b)
      if rank(a) ~= rank(b) then return rank(a) < rank(b) end
      return (a.c or 0) > (b.c or 0)
    end)

    for i, o in ipairs(list) do
      local row = GetRow(i)
      if o.it then shownItems[o.it] = true end
      local s = seeks[o]
      if s then
        row.order, row.seek = nil, o
        row.icon.icon:SetTexture(ns.OfferIcon(o))
        local title, meta = ns.OfferRowText(o, me, s[1], s[2])
        row.title:SetText(title)
        row.meta:SetText(meta)
        local acts = ns.OfferActions(o, me, s[2])
        FillButton(row.b1, acts[1], o)
        FillButton(row.b2, acts[2], o)
        row:Show()
      else
      row.order, row.seek = o, nil
      row.icon.icon:SetTexture(ns.ItemIcon(o))
      local item = ns.OrderText(o)
      if o.sk then
        -- a skilling call reads as the requester's plea to the guild
        row.title:SetText("|cffb080ff" .. L.STANDING .. "|r  "
          .. (o.by == me and L.SKILL_MINE:format(item) or L.SKILL_TITLE:format(item)))
      else
        row.title:SetText(item .. "  |c" .. STATUS_COLOR[o.st] .. L["ST_" .. o.st] .. "|r")
      end

      -- second line: who, when, and what matters for me
      local meta = { L.BY:format(ns.ColorName(o.by)) }
      if o.acc and not o.sk then meta[#meta + 1] = L.TAKEN_BY:format(ns.ColorName(o.acc)) end
      if o.sk and (o.dn or 0) > 0 then meta[#meta + 1] = L.DELIVERED_N:format(o.dn) end
      meta[#meta + 1] = ns.Ago(o.c)
      if o.sk then
        local have = o.by ~= me and ns.HaveCount(o) or 0
        if have > 0 then meta[#meta + 1] = "|cff40ff40" .. L.YOU_HAVE:format(have) .. "|r" end
      else
        meta[#meta + 1] = o.ms and L.MATS_BY_CREATOR or L.MATS_BY_CRAFTER
        local crafters = o.it and ns.Crafters(o)
        local can = o.st == "open" and o.by ~= me and ns.ICanCraft(o)
        local c
        if crafters then
          local on = 0
          for _, cr in ipairs(crafters) do if ns.IsOnline(ns.Short(cr.playerName)) then on = on + 1 end end
          c = L.CRAFTERS:format(#crafters, on)
        elseif o.it then
          c = L.NO_CRAFTERS
        end
        if c then meta[#meta + 1] = can and ("|cff40ff40" .. c .. "|r") or c end
      end
      if o.note then meta[#meta + 1] = "|cffffffff\"" .. o.note .. "\"|r" end
      row.meta:SetText(table.concat(meta, " · "))

      local acts = Actions(o, me)
      FillButton(row.b1, acts[1], o)
      FillButton(row.b2, acts[2], o)
      row:Show()
      end
    end
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].order, rows[i].seek = nil, nil end
    empty:SetShown(#list == 0)
    content:SetHeight(math.max(1, #list * ROW_H))
  end

  ns.OnChanged(refresh)
  panel:HookScript("OnShow", function()
    if ns.Start then ns.Start() end
    notifyAll.checkbox:SetChecked(ns.db.settings.notifyAll)
    GOS:SafeCall(refresh)
  end)
  -- item names and icons arrive from the server a moment after first use; bag changes alter
  -- "you have N"
  local ev = CreateFrame("Frame", nil, panel)
  ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  pcall(ev.RegisterEvent, ev, "BAG_UPDATE_DELAYED")
  ev:SetScript("OnEvent", function(_, event, id)
    if not panel:IsVisible() then return end
    -- the background item list loads thousands of items: only the ones on screen matter here
    if event == "GET_ITEM_INFO_RECEIVED" and not shownItems[id] then return end
    ns.Changed()
  end)

  PaintFilters()
  notifyAll.checkbox:SetChecked(ns.db.settings.notifyAll)
  popupCheck.checkbox:SetChecked(ns.db.settings.popup ~= false)
  GOS:SafeCall(refresh)
  return refresh
end

---------------------------------------------------------------- the tab: two halves
local SUB_H = 22
local subs, subBtns, subRefresh = {}, {}, {}
local current

local function CountSub(key)
  local me, n = ns.Me(), 0
  if key == "seek" then
    local g = ns.G()
    for _, o in pairs(g and g.orders or {}) do
      if not ns.OrderExpired(o) and not ns.Finished(o) then n = n + 1 end
    end
  end
  local ms = ns.MarketStore and ns.MarketStore()
  for _, o in pairs(ms and ms.offers or {}) do
    if ns.OfferLive(o) and ns.OfferSeek(o) == (key == "seek") then n = n + 1 end
  end
  return n
end

local function PaintSubs()
  for key, b in pairs(subBtns) do
    local on = key == current
    local col = on and C.gold or C.text
    b.label:SetText((key == "seek" and L.M_F_SEEKS or L.M_F_OFFERS) .. "  |cff888888(" .. CountSub(key) .. ")|r")
    b.baseLabelColor = { col.r, col.g, col.b }
    b.label:SetTextColor(col.r, col.g, col.b)
    if b.line then b.line:SetShown(on) end
  end
end

-- show one half ("seek" or "offer"); remembered for the next time
function ns.ShowSub(key)
  if not subs[key] then
    if ns.db then ns.db.settings.subTab = key end
    return
  end
  current = key
  if ns.db then ns.db.settings.subTab = key end
  for k, f in pairs(subs) do f:SetShown(k == key) end
  PaintSubs()
end

local function BuildTab(panel)
  local x = 8
  for _, key in ipairs({ "seek", "offer" }) do
    local b = UI:CreateButton(panel, "", 130, SUB_H)
    b:SetPoint("TOPLEFT", x, -4)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetColorTexture(C.gold.r, C.gold.g, C.gold.b, 1)
    b.line:SetPoint("BOTTOMLEFT", 2, 0)
    b.line:SetPoint("BOTTOMRIGHT", -2, 0)
    b.line:SetHeight(2)
    b:SetScript("OnClick", function() ns.ShowSub(key) end)
    Tip(b, key == "seek" and L.M_F_SEEKS or L.M_F_OFFERS, key == "seek" and L.SUB_SEEK_TT or L.SUB_OFFER_TT)
    subBtns[key] = b
    x = x + 134

    local f = CreateFrame("Frame", nil, panel)
    f:SetPoint("TOPLEFT", 0, -(SUB_H + 6))
    f:SetPoint("BOTTOMRIGHT", 0, 0)
    f:Hide()
    subs[key] = f
  end
  -- main / offspec (Specs.lua), top right
  local specBtn = UI:CreateButton(panel, L.S_BUTTON, 110, SUB_H)
  specBtn:SetPoint("TOPRIGHT", -22, -4)
  specBtn:SetScript("OnClick", function() ns.ShowSpecs() end)
  Tip(specBtn, L.S_TITLE, L.S_BUTTON_TT)

  subRefresh.seek = ns.BuildPanel(subs.seek)
  subRefresh.offer = ns.BuildMarketPanel(subs.offer)
  ns.OnChanged(function() if panel:IsVisible() then PaintSubs() end end)
  ns.ShowSub((ns.db and ns.db.settings.subTab == "offer") and "offer" or "seek")
  return function()
    PaintSubs()
    for _, fn in pairs(subRefresh) do if type(fn) == "function" then GOS:SafeCall(fn) end end
  end
end

---------------------------------------------------------------- registration
UI:RegisterFeature({
  id = ns.FEATURE, label = L.M_TAB, desc = L.M_FEATURE_DESC, order = 45,
  build = function(c) return BuildTab(c) end,
})

SLASH_GUILDOSCRAFTORDERS1 = "/gco"
SLASH_GUILDOSCRAFTORDERS2 = "/craftorders"
SlashCmdList.GUILDOSCRAFTORDERS = function(msg)
  if strtrim(msg or ""):lower() == "version" then
    -- the update popup has no tab checkbox: this turns it back on (or off again)
    local on = ns.db.settings.versionPopup == false
    if on then ns.db.settings.versionPopup = nil else ns.db.settings.versionPopup = false end
    ns.Print(on and L.VER_POPUP_ON_MSG or L.VER_POPUP_OFF_MSG)
    return
  end
  UI:OpenWindow(ns.FEATURE)
  ns.ShowSub("seek")
end
