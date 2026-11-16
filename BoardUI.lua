-- The "Board" tab: a post field on top, the posts below, newest activity first. Each post shows
-- its whole text; "Replies" opens its thread with a field to answer (one thread open at a time).
-- Plus /gboard.
local _, ns = ...
local L = ns.L
local GOS = GuildOS
local UI = GOS.UI
local C = GOS.Colors

local WHITE = "Interface\\Buttons\\WHITE8x8"
local BTN_W = 96
local BTN_H = 20
local FIELD_H = 22
local LIST_TOP = -58
local INDENT = 30
local GAP = 2

local function EditBox(parent, w, hint)
  local b = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  b:SetSize(w, FIELD_H)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  b:SetBackdropColor(0.05, 0.05, 0.066, 1)
  b:SetBackdropBorderColor(C.border.r, C.border.g, C.border.b, 0.4)
  GOS:ApplyFont(b, 11)
  b:SetTextColor(C.white.r, C.white.g, C.white.b)
  b:SetTextInsets(6, 6, 0, 0)
  b:SetAutoFocus(false)
  b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local ph = b:CreateFontString(nil, "OVERLAY")
  GOS:ApplyFont(ph, 11)
  ph:SetPoint("LEFT", 6, 0)
  ph:SetTextColor(0.4, 0.4, 0.4)
  ph:SetText(hint or "")
  local function upd() ph:SetShown(b:GetText() == "" and not b:HasFocus()) end
  b:HookScript("OnTextChanged", upd)
  b:HookScript("OnEditFocusGained", upd)
  b:HookScript("OnEditFocusLost", upd)
  upd()
  return b
end

local function Tip(frame, title, text)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 1, 1)
    GameTooltip:AddLine(text, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns.BuildBoardPanel(panel)
  local filter = "all"
  local open -- the id of the post whose thread is open
  local refresh

  ---------------------------------------------------------------- line 1: a new post
  local postBox = EditBox(panel, 300, L.B_POST_HINT)
  postBox:SetPoint("TOPLEFT", 8, -6)
  postBox:SetMaxLetters(ns.POST_MAX)
  local postBtn = UI:CreateButton(panel, L.B_POST, 90, FIELD_H)
  UI:SetButtonVariant(postBtn, "primary")
  postBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -6)
  postBox:SetPoint("RIGHT", postBtn, "LEFT", -6, 0)
  local function Submit()
    if ns.CreatePost(postBox:GetText()) then
      postBox:SetText("")
      postBox:ClearFocus()
    end
  end
  postBtn:SetScript("OnClick", Submit)
  postBox:SetScript("OnEnterPressed", Submit)

  ---------------------------------------------------------------- line 2: filter and options
  local filterBtns = {}
  local function PaintFilters()
    for key, b in pairs(filterBtns) do
      local col = key == filter and C.gold or C.text
      b.baseLabelColor = { col.r, col.g, col.b }
      b.label:SetTextColor(col.r, col.g, col.b)
    end
  end
  local x, last = 8, nil
  for _, f in ipairs({ { "all", L.F_ACTIVE }, { "mine", L.F_MINE } }) do
    local b = UI:CreateButton(panel, f[2], 56, BTN_H)
    b:SetPoint("TOPLEFT", x, -33)
    b:SetScript("OnClick", function() filter = f[1]; PaintFilters(); refresh() end)
    Tip(b, f[2], f[1] == "mine" and L.B_F_MINE_TT or L.B_F_ALL_TT)
    filterBtns[f[1]] = b
    x = x + b:GetWidth() + 4
    last = b
  end
  local function Check(label, tipText, anchor, gap)
    local c = UI:CreateCheckbox(panel, label, 18)
    c:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
    c:SetWidth(c.label:GetStringWidth() + 26)
    Tip(c, label, tipText)
    return c
  end
  local notifyCheck = Check(L.P_NOTIFY, L.B_NOTIFY_TT, last, 10)
  notifyCheck.checkbox.onChanged = function(_, checked) ns.db.settings.boardNotify = checked and true or false end
  local popupCheck = Check(L.POPUP, L.B_POPUP_TT, notifyCheck, 8)
  popupCheck.checkbox.onChanged = function(_, checked) ns.db.settings.boardPopup = checked and true or false end

  ---------------------------------------------------------------- list
  local scroll, content = UI:CreateScrollFrame(panel, "GuildOSBoardScroll")
  scroll:SetPoint("TOPLEFT", 4, LIST_TOP)
  scroll:SetPoint("BOTTOMRIGHT", -6, 4)
  UI:BindScrollChildWidth(scroll, content, 16)
  local empty = UI:CreateText(content, L.B_EMPTY, 11, C.textDim.r, C.textDim.g, C.textDim.b)
  empty:SetPoint("TOPLEFT", 8, -8)

  local function Width()
    local w = content:GetWidth()
    if not w or w < 200 then w = (panel:GetWidth() or 640) - 26 end
    return w
  end

  -- a post: header line, the text (wrapped), two buttons on the right
  local posts = {}
  local function GetPost(i)
    if posts[i] then return posts[i] end
    local f = CreateFrame("Frame", nil, content, "BackdropTemplate")
    f:SetBackdrop({ bgFile = WHITE })
    f.icon = UI:CreateIcon(f, 22)
    f.icon:SetPoint("TOPLEFT", 4, -6)
    f.icon.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    f.b1 = UI:CreateButton(f, "", BTN_W, BTN_H)
    f.b1:SetPoint("TOPRIGHT", -4, -6)
    f.b2 = UI:CreateButton(f, "", BTN_W, BTN_H)
    f.b2:SetPoint("RIGHT", f.b1, "LEFT", -4, 0)
    f.head = UI:CreateText(f, "", 10, C.textDim.r, C.textDim.g, C.textDim.b)
    f.head:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 6, 0)
    f.head:SetJustifyH("LEFT")
    f.head:SetWordWrap(false)
    f.text = UI:CreateText(f, "", 11, C.white.r, C.white.g, C.white.b)
    f.text:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -3)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWordWrap(true)
    if f.text.SetNonSpaceWrap then f.text:SetNonSpaceWrap(true) end
    posts[i] = f
    return f
  end

  -- a reply: "Name · 5m ago" and the text, an "x" for my own
  local replies = {}
  local function GetReply(i)
    if replies[i] then return replies[i] end
    local f = CreateFrame("Frame", nil, content, "BackdropTemplate")
    f:SetBackdrop({ bgFile = WHITE })
    f:SetBackdropColor(0.04, 0.04, 0.05, 0.6)
    f.text = UI:CreateText(f, "", 11, C.text.r, C.text.g, C.text.b)
    f.text:SetPoint("TOPLEFT", 8, -4)
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    f.text:SetWordWrap(true)
    if f.text.SetNonSpaceWrap then f.text:SetNonSpaceWrap(true) end
    f.del = UI:CreateButton(f, "x", 18, 18)
    f.del:SetPoint("TOPRIGHT", -4, -2)
    Tip(f.del, L.B_DELETE_REPLY, L.B_DELETE_REPLY_TT)
    replies[i] = f
    return f
  end

  -- the answer field under the open thread
  local editor = CreateFrame("Frame", nil, content)
  editor:SetHeight(FIELD_H + 8)
  local replyBox = EditBox(editor, 200, L.B_REPLY_HINT)
  replyBox:SetPoint("TOPLEFT", 8, -4)
  replyBox:SetMaxLetters(ns.REPLY_MAX)
  local sendBtn = UI:CreateButton(editor, L.B_SEND, 80, FIELD_H)
  UI:SetButtonVariant(sendBtn, "primary")
  sendBtn:SetPoint("TOPRIGHT", -4, -4)
  replyBox:SetPoint("RIGHT", sendBtn, "LEFT", -6, 0)
  editor:Hide()
  local function SendReply()
    local g = ns.BoardStore()
    local p = g and open and g.posts[open]
    if p and ns.CreateReply(p, replyBox:GetText()) then replyBox:SetText("") end
  end
  sendBtn:SetScript("OnClick", SendReply)
  replyBox:SetScript("OnEnterPressed", SendReply)

  local function Matches(p, me)
    if not ns.PostLive(p) then return false end
    if filter ~= "mine" or p.by == me then return true end
    local g = ns.BoardStore()
    for _, r in pairs(g.replies) do
      if r.p == p.id and r.who == me and r.st == "open" then return true end
    end
    return false
  end

  refresh = function()
    if not panel:IsVisible() or not ns.db then return end
    local s = ns.db.settings
    notifyCheck.checkbox:SetChecked(s.boardNotify ~= false)
    popupCheck.checkbox:SetChecked(s.boardPopup ~= false)

    local g, me = ns.BoardStore(), ns.Me()
    local list = {}
    for _, p in pairs(g and g.posts or {}) do
      if Matches(p, me) then
        local rs, lastWord = ns.PostReplies(p)
        list[#list + 1] = { p = p, r = rs, last = lastWord }
      end
    end
    table.sort(list, function(a, b) return a.last > b.last end)

    local w = Width()
    local y, ri = 0, 0
    local openShown = false
    for i, e in ipairs(list) do
      local p, rs = e.p, e.r
      local f = GetPost(i)
      f.post = p
      local bg = (i % 2 == 0) and C.row2 or C.row1
      f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a or 1)
      local nr = #rs
      f.head:SetText(ns.ColorName(p.by) .. "  |cff888888" .. ns.Ago(p.c)
        .. (nr > 0 and ("  ·  " .. L.B_REPLIES_N:format(nr)) or "") .. "|r")
      local textW = w - 22 - 10 - 2 * BTN_W - 16
      f.head:SetWidth(textW)
      f.text:SetWidth(textW)
      f.text:SetText(p.txt)
      local h = math.max(34, 6 + 14 + 3 + f.text:GetStringHeight() + 8)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      f:SetWidth(w)
      f:SetHeight(h)

      local isOpen = open == p.id
      f.b1.label:SetText(isOpen and L.B_CLOSE or (nr > 0 and L.B_REPLIES:format(nr) or L.B_ANSWER))
      f.b1:SetScript("OnClick", function()
        open = (open ~= p.id) and p.id or nil
        if open then replyBox:SetText("") end
        refresh()
        if open then replyBox:SetFocus() end
      end)
      if p.by == me then
        f.b2.label:SetText(L.M_REMOVE)
        f.b2:SetScript("OnClick", function() ns.RemovePost(p) end)
      else
        f.b2.label:SetText(L.B_WHISPER)
        f.b2:SetScript("OnClick", function() ns.Whisper(p.by) end)
      end
      f:Show()
      y = y + h + GAP

      if isOpen then
        openShown = true
        for _, r in ipairs(rs) do
          ri = ri + 1
          local rf = GetReply(ri)
          rf:ClearAllPoints()
          rf:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT, -y)
          rf:SetWidth(w - INDENT)
          rf.text:SetWidth(w - INDENT - 16 - 22)
          rf.text:SetText(ns.ColorName(r.who) .. " |cff888888" .. ns.Ago(r.c) .. "|r  " .. r.txt)
          local rh = rf.text:GetStringHeight() + 8
          rf:SetHeight(rh)
          rf.del:SetShown(r.who == me)
          rf.del:SetScript("OnClick", function() ns.RemoveReply(r) end)
          rf:Show()
          y = y + rh + GAP
        end
        editor:ClearAllPoints()
        editor:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT, -y)
        editor:SetWidth(w - INDENT)
        editor:Show()
        y = y + editor:GetHeight() + GAP * 3
      end
    end
    for i = #list + 1, #posts do posts[i]:Hide(); posts[i].post = nil end
    for i = ri + 1, #replies do replies[i]:Hide() end
    if not openShown then
      editor:Hide()
      open = nil
    end
    empty:SetShown(#list == 0)
    content:SetHeight(math.max(1, y))
  end

  ns.OnChanged(refresh)
  panel:HookScript("OnShow", function()
    if ns.Start then ns.Start() end
    GOS:SafeCall(refresh)
  end)
  -- wrapped text needs the real width: lay out again when it changes
  local lastW = 0
  content:HookScript("OnSizeChanged", function(self, w)
    if w and math.abs(w - lastW) > 1 then lastW = w; GOS:SafeCall(refresh) end
  end)
  -- "5m ago" moves on while the tab is open
  local tick = 0
  panel:HookScript("OnUpdate", function(_, elapsed)
    tick = tick + elapsed
    if tick >= 60 then tick = 0; GOS:SafeCall(refresh) end
  end)

  PaintFilters()
  GOS:SafeCall(refresh)
  return refresh
end

---------------------------------------------------------------- registration
UI:RegisterFeature({
  id = ns.BOARD_FEATURE, label = L.B_TAB, desc = L.B_FEATURE_DESC, order = 49,
  build = function(c) return ns.BuildBoardPanel(c) end,
})

SLASH_GUILDOSBOARD1 = "/gboard"
SLASH_GUILDOSBOARD2 = "/pinnwand"
SlashCmdList.GUILDOSBOARD = function() UI:OpenWindow(ns.BOARD_FEATURE) end
