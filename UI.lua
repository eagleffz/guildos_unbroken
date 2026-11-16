-- The "Orders" tab in the Guild OS window, built with Guild OS's own UI helpers, plus /gco.
-- Compact: the form is one line, filters and options a second, each order a two-line row.
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
  if filter == "mine" then return o.by == me or o.acc == me end
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
  for _, f in ipairs({ { "active", L.F_ACTIVE }, { "forme", L.F_FORME }, { "mine", L.F_MINE } }) do
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
    picked = { id = e.id, cat = e.cat, text = text }
    itemBox.quiet = true
    itemBox:SetText(text)
    itemBox.quiet = nil
    drop:Hide()
    if e.cat then
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
      for _, gr in ipairs(ns.SuggestGroups(text, skCheck.checkbox:GetChecked())) do list[#list + 1] = gr end
      if #list < SUG_N then
        for _, e in ipairs(ns.Suggest(text, SUG_N - #list)) do list[#list + 1] = e end
      end
    end
    sugItems = list
    for i, b in ipairs(sugBtns) do
      local e = list[i]
      if e then
        b.icon:SetTexture(ns.ItemIcon({ it = e.id, cat = e.cat }))
        b.name:SetText(e.cat and ("|cffffd100" .. e.name .. "|r") or e.name)
        if e.cat then b.info:SetText("|cffb080ff" .. L.GROUP .. "|r")
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

  local function Submit()
    local still = picked and itemBox:GetText() == picked.text
    local o = ns.CreateOrder(itemBox:GetText(), qtyBox:GetText(), noteBox:GetText(),
      msCheck.checkbox:GetChecked(), still and picked.id or nil, skCheck.checkbox:GetChecked(),
      still and picked.cat or nil)
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
    table.sort(list, function(a, b)
      if a.st ~= b.st then return STATUS_ORDER[a.st] < STATUS_ORDER[b.st] end
      return (a.c or 0) > (b.c or 0)
    end)

    for i, o in ipairs(list) do
      local row = GetRow(i)
      row.order = o
      if o.it then shownItems[o.it] = true end
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
    for i = #list + 1, #rows do rows[i]:Hide(); rows[i].order = nil end
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

---------------------------------------------------------------- registration
UI:RegisterFeature({
  id = ns.FEATURE, label = L.TAB, desc = L.FEATURE_DESC, order = 45,
  build = function(c) return ns.BuildPanel(c) end,
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
end
