-------------------------------------------------------------------------------
-- Golden Hour: Blizzard-style widgets
--
-- Uses WoW's own templates where the client has them (red buttons,
-- checkboxes, the Settings slider, bottom tabs), with plain fallbacks.
-------------------------------------------------------------------------------

local _, ns = ...

local UI = {}
ns.UI = UI

ns.GOLD = { 1, 0.82, 0 }
ns.WHITE = { 1, 1, 1 }
ns.GRAY = { 0.6, 0.6, 0.6 }
ns.RED = { 1, 0.3, 0.25 }
ns.ORANGE = { 1, 0.55, 0.2 }

function UI.HasTemplate(name)
  if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
    return C_XMLUtil.GetTemplateInfo(name) ~= nil
  end
  return true
end

local function Make(kind, parent, template)
  if template and UI.HasTemplate(template) then
    local ok, f = pcall(CreateFrame, kind, nil, parent, template)
    if ok and f then return f, true end
  end
  return CreateFrame(kind, nil, parent), false
end

function UI.Text(parent, font, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font or "GameFontHighlight")
  if color then fs:SetTextColor(color[1], color[2], color[3]) end
  return fs
end

function UI.Tooltip(frame, fill)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    fill(GameTooltip, self)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- WoW's red button.
function UI.Button(parent, text, w, h)
  local b, real = Make("Button", parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, h or 22)
  if not real then
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.45, 0.06, 0.03, 1)
    local fs = UI.Text(b, "GameFontNormal")
    fs:SetPoint("CENTER")
    b.label = fs
    function b:SetText(t) self.label:SetText(t) end
    function b:GetText() return self.label:GetText() end
  end
  b:SetText(text or "")
  b.label = b.label or b:GetFontString()
  return b
end

-- WoW's checkbox with a label to its right.
function UI.Check(parent, label)
  local c, real = Make("CheckButton", parent, "UICheckButtonTemplate")
  c:SetSize(26, 26)
  if not real then
    local bg = c:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 5, -5)
    bg:SetPoint("BOTTOMRIGHT", -5, 5)
    bg:SetColorTexture(0.1, 0.1, 0.1, 1)
    c.mark = c:CreateTexture(nil, "ARTWORK")
    c.mark:SetPoint("TOPLEFT", 8, -8)
    c.mark:SetPoint("BOTTOMRIGHT", -8, 8)
    c.mark:SetColorTexture(1, 0.82, 0, 1)
    c.mark:Hide()
    local set = c.SetChecked
    function c:SetChecked(on) set(self, on); self.mark:SetShown(on and true or false) end
  end
  c.text = c.Text or c.text or UI.Text(c, "GameFontHighlight")
  c.text:ClearAllPoints()
  c.text:SetPoint("LEFT", c, "RIGHT", 2, 1)
  c.text:SetText(label or "")
  return c
end

-------------------------------------------------------------------------------
-- Slider over a list of stops. The Settings panel's slider with arrows at
-- each end when the client has it, otherwise a plain bar.
-- onPick(index) is called when the player moves it.
-------------------------------------------------------------------------------

local function PlainSlider(parent, w)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(w, 20)
  local track = f:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT", 18, 0)
  track:SetPoint("RIGHT", -18, 0)
  track:SetHeight(6)
  track:SetColorTexture(0.12, 0.12, 0.12, 1)
  local fill = f:CreateTexture(nil, "BORDER")
  fill:SetPoint("LEFT", track, "LEFT")
  fill:SetHeight(6)
  fill:SetColorTexture(0.7, 0.55, 0.1, 1)
  local thumb = CreateFrame("Button", nil, f)
  thumb:SetSize(12, 16)
  local tt = thumb:CreateTexture(nil, "ARTWORK")
  tt:SetAllPoints()
  tt:SetColorTexture(1, 0.82, 0, 1)
  local back = UI.Button(f, "<", 16, 18)
  back:SetPoint("LEFT")
  local fwd = UI.Button(f, ">", 16, 18)
  fwd:SetPoint("RIGHT")
  f.track, f.min, f.max, f.value = track, 1, 2, 1
  function f:Place()
    local tw = (self:GetWidth() or w) - 36
    local frac = (self.max > self.min) and (self.value - self.min) / (self.max - self.min) or 0
    thumb:ClearAllPoints()
    thumb:SetPoint("CENTER", track, "LEFT", frac * tw, 0)
    fill:SetWidth(math.max(1, frac * tw))
  end
  function f:SetRange(lo, hi) self.min, self.max = lo, hi; self:Place() end
  function f:SetValue(v) self.value = v; self:Place() end
  local function Step(d)
    local v = math.max(f.min, math.min(f.max, f.value + d))
    if v ~= f.value then f:SetValue(v); if f.onPick then f.onPick(v) end end
  end
  back:SetScript("OnClick", function() Step(-1) end)
  fwd:SetScript("OnClick", function() Step(1) end)
  f.Step = Step
  -- Click along the bar to jump there.
  f:EnableMouse(true)
  f:SetScript("OnMouseDown", function(self)
    local x = GetCursorPosition and select(1, GetCursorPosition())
    local left = track:GetLeft()
    local tw = track:GetWidth()
    local scale = self:GetEffectiveScale()
    if not (x and left and tw and tw > 0) then return end
    local frac = math.max(0, math.min(1, (x / scale - left) / tw))
    Step(math.floor(self.min + frac * (self.max - self.min) + 0.5) - self.value)
  end)
  return f
end

function UI.Slider(parent, w, onPick)
  local s = {}
  if UI.HasTemplate("MinimalSliderWithSteppersTemplate") and MinimalSliderWithSteppersMixin then
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
    if ok and f and f.Init and f.RegisterCallback then
      f:SetWidth(w)
      s.frame = f
      s.blizzard = true
      local quiet = false
      function s:Setup(count, index)
        quiet = true
        f:Init(index, 1, count, count - 1, {})
        quiet = false
      end
      function s:SetIndex(index)
        quiet = true
        f:SetValue(index)
        quiet = false
      end
      f:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        if not quiet then onPick(math.floor(value + 0.5)) end
      end, s)
      -- The bar itself, for placing the default and Beyond marks.
      local inner = rawget(f, "Slider")
      s.track = inner or f
      s.thumbWidth = function()
        local th = inner and inner.GetThumbTexture and inner:GetThumbTexture()
        return th and th:GetWidth() or 0
      end
      return s
    end
  end
  local f = PlainSlider(parent, w)
  f.onPick = onPick
  s.frame = f
  s.track = f.track
  function s:Setup(count, index) f:SetRange(1, count); f:SetValue(index) end
  function s:SetIndex(index) f:SetValue(index) end
  return s
end

-------------------------------------------------------------------------------
-- A small box for typing a number. onEnter(text) returns true if it took it.
-------------------------------------------------------------------------------

function UI.NumberBox(parent, w, onEnter)
  local box, real = Make("EditBox", parent, "InputBoxTemplate")
  box:SetSize(w, 20)
  box:SetAutoFocus(false)
  box:SetMaxLetters(9)
  box:SetJustifyH("CENTER")
  if not real then
    box:SetFontObject("GameFontHighlight")
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    box:SetTextInsets(4, 4, 0, 0)
  end
  box:SetScript("OnEnterPressed", function(self)
    if onEnter(self:GetText()) then
      self:ClearFocus()
    else
      self:HighlightText()
      if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF) end
    end
  end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  -- Leaving without Enter puts the real value back.
  box:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
    ns.Changed()
  end)
  return box
end

-------------------------------------------------------------------------------
-- A dropdown: Blizzard's when the client has it, otherwise a button that
-- steps through the choices. list() returns { {value=, text=}, ... }.
-------------------------------------------------------------------------------

function UI.Dropdown(parent, w, list, get, set)
  local d = {}
  if UI.HasTemplate("WowStyle1DropdownTemplate") then
    local ok, f = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    if ok and f and f.SetupMenu then
      f:SetWidth(w)
      f:SetupMenu(function(_, root)
        for _, c in ipairs(list()) do
          root:CreateRadio(c.text, function(v) return get() == v end, function(v) set(v) end, c.value)
        end
      end)
      d.frame = f
      function d:Refresh() if f.GenerateMenu then f:GenerateMenu() end end
      return d
    end
  end
  local b = UI.Button(parent, "", w, 22)
  b:SetScript("OnClick", function()
    local l, now = list(), get()
    local at = 1
    for i, c in ipairs(l) do if c.value == now then at = i end end
    local nextC = l[at % #l + 1]
    if nextC then set(nextC.value) end
  end)
  d.frame = b
  function d:Refresh()
    local now = get()
    local text = "?"
    for _, c in ipairs(list()) do if c.value == now then text = c.text end end
    b:SetText(text)
  end
  return d
end

-------------------------------------------------------------------------------
-- Tabs along the bottom of a window, like the character frame's.
-- onPick(i) when one is clicked. Returns tabs, Select(i).
-------------------------------------------------------------------------------

function UI.Tabs(frame, names, onPick)
  local tabs = {}
  local blizzard = UI.HasTemplate("PanelTabButtonTemplate") and PanelTemplates_SetNumTabs and PanelTemplates_SetTab
  for i, name in ipairs(names) do
    local t
    if blizzard then
      local ok, made = pcall(CreateFrame, "Button", frame:GetName() and (frame:GetName() .. "Tab" .. i) or nil,
        frame, "PanelTabButtonTemplate")
      if ok then t = made end
    end
    if not t then
      t = UI.Button(frame, name, 76, 24)
      blizzard = false
    end
    t:SetID(i)
    t:SetText(name)
    if blizzard and PanelTemplates_TabResize then
      pcall(PanelTemplates_TabResize, t, 0)
    end
    if i == 1 then
      t:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, blizzard and 2 or -2)
    else
      t:SetPoint("LEFT", tabs[i - 1], "RIGHT", blizzard and 3 or 2, 0)
    end
    t:SetScript("OnClick", function(self)
      if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB) end
      onPick(self:GetID())
    end)
    tabs[i] = t
  end
  if blizzard then
    frame.Tabs = tabs
    pcall(PanelTemplates_SetNumTabs, frame, #tabs)
  end
  local function Select(i)
    if blizzard then
      pcall(PanelTemplates_SetTab, frame, i)
    else
      for j, t in ipairs(tabs) do
        if t.LockHighlight then
          if j == i then t:LockHighlight() else t:UnlockHighlight() end
        end
      end
    end
  end
  return tabs, Select
end

-------------------------------------------------------------------------------
-- Popups: a name box and a yes/no, using Blizzard's StaticPopup.
-------------------------------------------------------------------------------

local function EditBoxOf(popup)
  return popup.editBox or popup.EditBox or (popup.GetEditBox and popup:GetEditBox())
end

-- A popup with a text box. opts: button, maxLetters, width, initial, readOnly.
function UI.AskText(text, onAccept, opts)
  opts = opts or {}
  if not (StaticPopupDialogs and StaticPopup_Show) then return end
  StaticPopupDialogs.GOLDENHOUR_TEXT = {
    text = text,
    button1 = opts.button or SAVE or "Save",
    button2 = (not opts.readOnly) and (CANCEL or "Cancel") or nil,
    hasEditBox = true,
    maxLetters = opts.maxLetters or 40,
    editBoxWidth = opts.width,
    OnAccept = function(self)
      local box = EditBoxOf(self)
      if box and onAccept then onAccept(box:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
      local popup = self:GetParent()
      if onAccept then onAccept(self:GetText()) end
      popup:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    OnShow = function(self)
      local box = EditBoxOf(self)
      if box then
        box:SetText(opts.initial or "")
        box:SetFocus()
        if opts.initial then box:HighlightText() end
      end
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("GOLDENHOUR_TEXT")
end

function UI.AskName(text, onAccept)
  UI.AskText(text, onAccept)
end

function UI.Confirm(text, yes, onAccept)
  if not (StaticPopupDialogs and StaticPopup_Show) then onAccept() return end
  StaticPopupDialogs.GOLDENHOUR_CONFIRM = {
    text = text,
    button1 = yes or OKAY or "Okay",
    button2 = CANCEL or "Cancel",
    OnAccept = function() onAccept() end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
  StaticPopup_Show("GOLDENHOUR_CONFIRM")
end

-------------------------------------------------------------------------------
-- Tooltip for a setting, shared by the window and the Options panel.
-------------------------------------------------------------------------------

function ns.FillSettingTooltip(tip, s)
  tip:SetText(s.label, ns.WHITE[1], ns.WHITE[2], ns.WHITE[3])
  tip:AddLine(s.tip, ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  if s.lower then tip:AddLine("Lower looks better.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true) end
  if s.warn then tip:AddLine(s.warn, ns.RED[1], ns.RED[2], ns.RED[3], true) end
  tip:AddLine(" ")
  local function Show(v)
    if s.toggle then return ns.Format(v) == ns.Format(s.toggle.on) and "On" or "Off" end
    return ns.Format(v)
  end
  tip:AddDoubleLine("Blizzard default", s.default and Show(s.default) or "unknown", 0.8, 0.8, 0.8, 1, 1, 1)
  tip:AddDoubleLine("Beyond Ultra", s.beyond ~= nil and Show(s.beyond) or "left as is", 0.8, 0.8, 0.8, 1, 0.82, 0)
  local mid = ns.MIDRANGE[s.cvar]
  tip:AddDoubleLine("Midrange", mid ~= nil and Show(mid) or "left as is", 0.8, 0.8, 0.8, 1, 0.55, 0.2)
  local lite = ns.LITE[s.cvar]
  tip:AddDoubleLine("Lite", lite ~= nil and Show(lite) or "left as is", 0.8, 0.8, 0.8, 0.6, 0.8, 1)
  if s.restart then tip:AddLine("Shows after a graphics restart.", 0.6, 0.8, 1, true) end
  tip:AddLine("Console name: " .. s.cvar, 0.5, 0.5, 0.5)
  if not s.toggle then tip:AddLine("Right-click the slider for Blizzard's default.", 0.5, 0.5, 0.5, true) end
end
