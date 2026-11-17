-- A small popup for a new order, offer or post. It can be
-- dragged, closes by itself after a while, and can be switched off right in it or with the
-- "Popup" checkbox in each tab (one switch per tab). Nothing pops up during
-- combat: the newest one waits until the fight is over.
local _, ns = ...
local L = ns.L
local GOS = GuildOS
local UI = GOS.UI
local C = GOS.Colors

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SHOW_FOR = 25
local W, H = 360, 82

local frame, current, extra, hideAt = nil, nil, 0, 0
local pending = nil -- the newest popup that came in during combat

local function SavePos(f)
  local point, _, rel, x, y = f:GetPoint()
  ns.db.settings.popupPos = { point, rel, x, y }
end

local function Build()
  local f = CreateFrame("Frame", "GuildOSUnbrokenPopup", UIParent, "BackdropTemplate")
  f:SetSize(W, H)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  local bg, line = C.popup or C.panel, C.lineHi or C.border
  f:SetBackdropColor(bg.r, bg.g, bg.b, 0.97)
  f:SetBackdropBorderColor(line.r, line.g, line.b, 1)
  local pos = ns.db.settings.popupPos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else f:SetPoint("TOP", UIParent, "TOP", 0, -140) end

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self) end)

  f.icon = UI:CreateIcon(f, 32)
  f.icon:SetPoint("TOPLEFT", 8, -8)

  f.head = UI:CreateText(f, "", 11, C.gold.r, C.gold.g, C.gold.b)
  f.head:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, -1)
  f.head:SetPoint("RIGHT", f, "RIGHT", -28, 0)
  f.head:SetJustifyH("LEFT")
  f.head:SetWordWrap(false)

  f.text = UI:CreateText(f, "", 11, C.text.r, C.text.g, C.text.b)
  f.text:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -3)
  f.text:SetPoint("RIGHT", f, "RIGHT", -10, 0)
  f.text:SetJustifyH("LEFT")
  f.text:SetJustifyV("TOP")
  f.text:SetHeight(26)
  f.text:SetWordWrap(true)

  local close = UI:CreateButton(f, "x", 18, 18)
  close:SetPoint("TOPRIGHT", -5, -5)
  close:SetScript("OnClick", function() f:Hide() end)

  f.open = UI:CreateButton(f, L.POPUP_OPEN, 80, 20)
  f.open:SetPoint("BOTTOMRIGHT", -8, 8)
  f.open:SetScript("OnClick", function()
    local feature, sub = current and current.feature, current and current.sub
    f:Hide()
    if feature then UI:OpenWindow(feature) end
    if sub and ns.ShowSub then ns.ShowSub(sub) end
  end)

  -- the popup's own action (sign up for a group), left of "Show"
  f.act = UI:CreateButton(f, "", 100, 20)
  UI:SetButtonVariant(f.act, "primary")
  f.act:SetPoint("RIGHT", f.open, "LEFT", -6, 0)
  f.act:SetScript("OnClick", function()
    local a = current and current.action
    f:Hide()
    if a then GOS:SafeCall(a[2]) end
  end)

  f.off = UI:CreateButton(f, L.POPUP_OFF, 110, 20)
  f.off:SetScript("OnClick", function()
    local setting = current and current.setting
    local offMsg = current and current.offMsg
    f:Hide()
    if setting then
      ns.db.settings[setting] = false
      ns.Print(offMsg or setting == "marketPopup" and L.M_POPUP_OFF_MSG or L.POPUP_OFF_MSG)
      ns.Changed() -- the tab's checkbox follows
    end
  end)

  f.more = UI:CreateText(f, "", 10, C.textDim.r, C.textDim.g, C.textDim.b)
  f.more:SetPoint("TOPRIGHT", -28, -9)

  f.icon:EnableMouse(true)
  f.icon:SetScript("OnEnter", function(self)
    if not (current and current.tooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    current.tooltip(GameTooltip)
    GameTooltip:Show()
  end)
  f.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- closes by itself, but not while the mouse is on it
  f:SetScript("OnUpdate", function(self)
    if GetTime() >= hideAt and not self:IsMouseOver() then self:Hide() end
  end)
  f:SetScript("OnHide", function() current, extra = nil, 0 end)
  f:Hide()
  return f
end

-- info = { key, icon, head, text, feature, setting, action = { label, fn }, tooltip = fn(tt) }
local function Show(info)
  frame = frame or Build()
  if frame:IsShown() and current and current.key ~= info.key then extra = extra + 1 end
  current = info
  frame.icon.icon:SetTexture(info.icon)
  frame.head:SetText(info.head)
  frame.text:SetText(info.text)
  frame.more:SetText(extra > 0 and L.POPUP_MORE:format(extra) or "")
  -- "Show" only when there is a tab to open; the action left of it, "no more" left of both
  frame.open:SetShown(info.feature ~= nil)
  frame.act:ClearAllPoints()
  if info.feature then frame.act:SetPoint("RIGHT", frame.open, "LEFT", -6, 0)
  else frame.act:SetPoint("BOTTOMRIGHT", -8, 8) end
  if info.action then
    frame.act.label:SetText(info.action[1])
    frame.act:Show()
  else
    frame.act:Hide()
  end
  frame.off:ClearAllPoints()
  if info.action then frame.off:SetPoint("RIGHT", frame.act, "LEFT", -6, 0)
  elseif info.feature then frame.off:SetPoint("RIGHT", frame.open, "LEFT", -6, 0)
  else frame.off:SetPoint("BOTTOMRIGHT", -8, 8) end
  hideAt = GetTime() + SHOW_FOR
  frame:Show()
end

local function Pop(info)
  if ns.db.settings[info.setting] == false then return end
  if InCombatLockdown() then pending = info return end
  GOS:SafeCall(Show, info)
end

---------------------------------------------------------------- orders
-- called for each new order; `why` is the green hint, if any
function ns.ShowPopup(o, why)
  local id = o.id
  local body = o.sk and L.SKILL_TITLE:format(ns.OrderLabel(o)) or ns.OrderText(o)
  Pop({
    key = id, setting = "popup", feature = ns.FEATURE, sub = "seek",
    icon = ns.ItemIcon(o), head = o.sk and L.POPUP_SKILL or L.POPUP_NEW,
    text = ns.ColorName(o.by) .. ": " .. body .. (why or ""),
    still = function()
      local g = ns.G()
      local cur = g and g.orders[id]
      return cur and cur.st == "open"
    end,
    tooltip = function(tt)
      if o.it then tt:SetHyperlink("item:" .. o.it) else tt:AddLine(ns.OrderLabel(o), 1, 1, 1) end
    end,
  })
end

---------------------------------------------------------------- market
function ns.ShowOfferPopup(o)
  local id = o.id
  local seek = ns.OfferSeek(o)
  local head
  if seek then head = o.it and L.M_POPUP_SEEK_ITEM or L.M_POPUP_SEEK_SERVICE
  else head = o.it and L.M_POPUP_ITEM or L.M_POPUP_SERVICE end
  local have = seek and ns.OfferHave(o) or 0
  local why = ""
  if have > 0 then why = "  |cff40ff40" .. L.M_YOU_HAVE:format(have) .. "|r"
  elseif ns.SeekForMe(o) then why = "  |cff40ff40" .. L.SVC_YOU_CAN .. "|r" end
  Pop({
    key = id, setting = seek and "popup" or "marketPopup", feature = ns.FEATURE, sub = seek and "seek" or "offer",
    icon = ns.OfferIcon(o), head = head .. why,
    text = ns.ColorName(o.by) .. ": " .. ns.OfferLabel(o) .. (o.pr and ("  |cffffd100" .. o.pr .. "|r") or "")
      .. (o.note and ("\n|cffaaaaaa\"" .. o.note .. "\"|r") or ""),
    still = function()
      local g = ns.MarketStore()
      local cur = g and g.offers[id]
      return cur and ns.OfferLive(cur)
    end,
    tooltip = function(tt) ns.OfferTooltip(tt, o) end,
    action = { seek and L.M_HAVE or L.M_WANT, function()
      local g = ns.MarketStore()
      local cur = g and g.offers[id]
      if cur then ns.WantOffer(cur) end
    end },
  })
end

---------------------------------------------------------------- message board
local POST_ICON = "Interface\\Icons\\INV_Letter_15"

function ns.ShowPostPopup(p)
  local id = p.id
  Pop({
    key = id, setting = "boardPopup", feature = ns.BOARD_FEATURE, offMsg = L.B_POPUP_OFF_MSG,
    icon = POST_ICON, head = L.B_POPUP_HEAD,
    text = ns.ColorName(p.by) .. ": |cffffffff" .. ns.ShortText(p.txt, 110) .. "|r",
    still = function()
      local g = ns.BoardStore()
      local cur = g and g.posts[id]
      return cur and cur.st == "open"
    end,
    tooltip = function(tt)
      tt:AddLine(ns.ColorName(p.by), 1, 0.82, 0)
      tt:AddLine(p.txt, 1, 1, 1, true)
    end,
  })
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function()
  if not pending then return end
  local info = pending
  pending = nil
  -- it may have been taken, cancelled or ended during the fight
  if (not info.still or info.still()) and ns.db.settings[info.setting] ~= false then GOS:SafeCall(Show, info) end
end)
