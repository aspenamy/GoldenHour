-------------------------------------------------------------------------------
-- Golden Hour: the window
--
-- A Blizzard portrait frame with tabs along the bottom: Presets first, then
-- one tab per group of settings.
-------------------------------------------------------------------------------

local _, ns = ...
local UI = ns.UI

local WIN_W, WIN_H = 700, 560
local OPTIONS_W = 660     -- page width inside Options > AddOns
local ROW_H = 31
local TOP_Y = -84          -- first row
local LABEL_X, SLIDER_X, VALUE_X = 24, 232, 492
local SLIDER_W = 250

local frame
local pages = {}           -- key -> page frame
local tabKeys = {}         -- tab index -> page key
local SelectTab
local current

-------------------------------------------------------------------------------
-- A row for one setting
-------------------------------------------------------------------------------

local function Mark(parent, color)
  local t = parent:CreateTexture(nil, "OVERLAY")
  t:SetSize(3, 9)
  t:SetColorTexture(color[1], color[2], color[3], 1)
  return t
end

local function MakeRow(page, s, y)
  local row = CreateFrame("Frame", nil, page)
  row:SetPoint("TOPLEFT", 8, y)
  row:SetPoint("TOPRIGHT", -8, y)
  row:SetHeight(ROW_H)
  row:EnableMouse(true)
  row.setting = s

  local hl = row:CreateTexture(nil, "BACKGROUND")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  hl:Hide()
  row:SetScript("OnEnter", function() hl:Show() end)
  row:SetScript("OnLeave", function() hl:Hide() end)
  UI.Tooltip(row, function(tip) ns.FillSettingTooltip(tip, s) end)

  local label = UI.Text(row, "GameFontHighlight")
  label:SetPoint("LEFT", LABEL_X - 8, 0)
  label:SetWidth(SLIDER_X - LABEL_X - 8)
  label:SetJustifyH("LEFT")
  label:SetText(s.label)
  if s.warn then
    label:SetText(s.label .. " |cffff5040*|r")
  end

  if s.toggle then
    local c = UI.Check(row, "")
    c:SetPoint("LEFT", SLIDER_X - 8, 0)
    c:SetScript("OnClick", function(self)
      ns.Set(s, self:GetChecked() and s.toggle.on or s.toggle.off)
    end)
    UI.Tooltip(c, function(tip) ns.FillSettingTooltip(tip, s) end)
    function row:Refresh()
      c:SetChecked(ns.IsOn(s))
    end
    return row
  end

  -- A box showing the value: type a number and press Enter to set it.
  local box = UI.NumberBox(row, 64, function(text)
    local v = tonumber(text)
    if v == nil then return false end
    ns.Set(s, ns.Clamp(s, v))
    return true
  end)
  box:SetPoint("LEFT", VALUE_X - 8, 0)
  UI.Tooltip(box, function(tip)
    ns.FillSettingTooltip(tip, s)
    local lo, hi = ns.Bounds(s)
    tip:AddLine(("Type a number from %s to %s and press Enter."):format(ns.Format(lo), ns.Format(hi)),
      0.5, 0.8, 1, true)
  end)
  local tag = UI.Text(row, "GameFontDisableSmall")
  tag:SetPoint("LEFT", box, "RIGHT", 6, 0)

  local slider = UI.Slider(row, SLIDER_W, function(index)
    local v = s.stopList[index]
    if v ~= nil then ns.Set(s, v) end
  end)
  slider.frame:SetPoint("LEFT", SLIDER_X - 8, 0)
  local count = math.max(2, #s.stopList)
  slider:Setup(count, ns.StopIndex(s))

  -- Little marks under the bar: gray for Blizzard's default, gold for Beyond.
  -- Placed from the bar's real size once it's laid out.
  local defMark = Mark(slider.frame, ns.GRAY)
  local midMark = Mark(slider.frame, ns.ORANGE)
  local beyondMark = Mark(slider.frame, ns.GOLD)
  local function PlaceMark(m, v)
    if v == nil then m:Hide() return end
    local f = slider.frame
    local bar = slider.track
    local left, width = 18, SLIDER_W - 36
    local fl, bl, bw = f:GetLeft(), bar and bar ~= f and bar:GetLeft(), bar and bar ~= f and bar:GetWidth()
    if fl and bl and bw and bw > 0 then left, width = bl - fl, bw end
    -- The thumb's center travels the bar minus half a thumb at each end.
    local thumb = slider.thumbWidth and slider.thumbWidth() or 0
    local i = ns.StopIndex(s, v)
    local frac = (count > 1) and (i - 1) / (count - 1) or 0
    m:ClearAllPoints()
    m:SetPoint("TOP", f, "LEFT", left + thumb / 2 + frac * (width - thumb), -6)
    m:Show()
  end
  local function PlaceMarks()
    PlaceMark(defMark, s.default)
    PlaceMark(midMark, ns.MIDRANGE[s.cvar])
    PlaceMark(beyondMark, s.beyond)
  end

  UI.Tooltip(slider.frame, function(tip) ns.FillSettingTooltip(tip, s) end)

  -- Right-click: Blizzard's default.
  local function RightClick(_, button)
    if button == "RightButton" and s.default ~= nil then ns.Set(s, s.default) end
  end
  row:SetScript("OnMouseUp", RightClick)
  local bar = rawget(slider.frame, "Slider") or slider.frame
  if bar.HookScript then bar:HookScript("OnMouseUp", RightClick) end

  function row:Refresh()
    local now = ns.Get(s)
    slider:SetIndex(ns.StopIndex(s, now))
    if not box:HasFocus() then box:SetText(ns.Format(now)) end
    if s.default ~= nil and ns.Format(now) == ns.Format(s.default) then
      tag:SetText("default")
    elseif s.beyond ~= nil and ns.Format(now) == ns.Format(s.beyond) then
      tag:SetText("|cffffd100beyond|r")
    elseif ns.MIDRANGE[s.cvar] ~= nil and ns.Format(now) == ns.Format(ns.MIDRANGE[s.cvar]) then
      tag:SetText("|cffff8c33midrange|r")
    else
      tag:SetText("")
    end
    PlaceMarks()
  end
  return row
end

-------------------------------------------------------------------------------
-- Pages
-------------------------------------------------------------------------------

local function PageHeader(page, title, blurb, x)
  local t = UI.Text(page, "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", x, -32)
  t:SetText(title)
  local b = UI.Text(page, "GameFontHighlightSmall")
  b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
  b:SetWidth(page.W - x - 16)
  b:SetJustifyH("LEFT")
  b:SetText(blurb)
  return t, b
end

local function Legend(page)
  local f = CreateFrame("Frame", nil, page)
  f:SetSize(300, 12)
  f:SetPoint("TOPLEFT", page.W - 18 - 300, TOP_Y + 18)
  local beyond = UI.Text(f, "GameFontDisableSmall")
  beyond:SetPoint("RIGHT")
  beyond:SetText("Beyond Ultra")
  local m3 = Mark(f, ns.GOLD)
  m3:SetPoint("RIGHT", beyond, "LEFT", -4, 0)
  local mid = UI.Text(f, "GameFontDisableSmall")
  mid:SetPoint("RIGHT", m3, "LEFT", -12, 0)
  mid:SetText("Midrange")
  local m2 = Mark(f, ns.ORANGE)
  m2:SetPoint("RIGHT", mid, "LEFT", -4, 0)
  local def = UI.Text(f, "GameFontDisableSmall")
  def:SetPoint("RIGHT", m2, "LEFT", -12, 0)
  def:SetText("Blizzard default")
  local m1 = Mark(f, ns.GRAY)
  m1:SetPoint("RIGHT", def, "LEFT", -4, 0)
end

-- inOptions: built into Options > AddOns instead of the window.
function ns.BuildSettingsPage(parent, info, inOptions)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints()
  page:Hide()
  page.W = inOptions and OPTIONS_W or WIN_W
  PageHeader(page, info.title, info.blurb, inOptions and 20 or 66)
  Legend(page)
  page.rows = {}
  local y = TOP_Y
  for _, s in ipairs(info.available) do
    local row = MakeRow(page, s, y)
    page.rows[#page.rows + 1] = row
    y = y - ROW_H
  end
  if #info.available == 0 then
    local none = UI.Text(page, "GameFontDisable")
    none:SetPoint("TOP", 0, TOP_Y - 20)
    none:SetText("This client doesn't have any of these settings.")
  else
    local note = UI.Text(page, "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 24, y - 8)
    note:SetText("Hover a setting for details. Type a number in a box and press Enter. Right-click a slider for Blizzard's default.")
  end
  function page:Refresh()
    for _, row in ipairs(self.rows) do row:Refresh() end
  end
  if inOptions and #info.available > 0 then ns.AddUndoRow(page, y - 30) end
  return page
end

-- The Presets page: one-click sets, profiles and the extras.
local PROFILE_ROWS = 3

local function Section(page, text, y)
  local t = UI.Text(page, "GameFontNormal")
  t:SetPoint("TOPLEFT", 20, y)
  t:SetText(text)
  local line = page:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", t, "RIGHT", 8, 0)
  line:SetWidth(math.max(10, page.W - 20 - 20 - 8 - math.ceil(t:GetStringWidth())))
  line:SetColorTexture(1, 0.82, 0, 0.25)
  return t
end

local function PresetButton(page, text, y, desc, onClick)
  local b = UI.Button(page, text, 160, 24)
  b:SetPoint("TOPLEFT", 24, y)
  b:SetScript("OnClick", onClick)
  local d = UI.Text(page, "GameFontHighlightSmall")
  d:SetPoint("LEFT", b, "RIGHT", 12, 0)
  d:SetWidth(page.W - 24 - 160 - 12 - 20)
  d:SetJustifyH("LEFT")
  d:SetText(desc)
  b.desc = d
  return b
end

function ns.AskBeyond()
  UI.Confirm("Set everything to Beyond Ultra?\n\nThese are very demanding. Undo puts your settings back.",
    "Beyond Ultra", ns.ApplyBeyond)
end

function ns.AskSaveProfile()
  UI.AskName("Save your current settings as:", ns.SaveProfile)
end

function ns.AskDeleteProfile(name)
  UI.Confirm(("Delete the profile \"%s\"?"):format(name), DELETE or "Delete", function() ns.DeleteProfile(name) end)
end

function ns.AskImport()
  UI.AskText("Paste a Golden Hour profile:", function(text)
    local name, why = ns.ImportProfile(text)
    if not name then ns.Print("couldn't add it: " .. why) end
  end, { button = "Add", maxLetters = 0, width = 360 })
end

function ns.ShowShare(name)
  local text = ns.ExportProfile(name)
  if not text then return end
  UI.AskText(("Copy this with Ctrl+C to share \"%s\":"):format(name), nil,
    { button = CLOSE or "Close", maxLetters = 0, width = 360, initial = text, readOnly = true })
end

function ns.BuildPresetsPage(parent, inOptions)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints()
  page:Hide()
  page.W = inOptions and OPTIONS_W or WIN_W
  PageHeader(page, inOptions and ns.TITLE or "Presets",
    "One click for the whole set, saved profiles of your own, and a way back to how things were.",
    inOptions and 20 or 66)
  if inOptions then
    local open = UI.Button(page, "Open Window", 120, 22)
    open:SetPoint("TOPLEFT", page.W - 20 - 120, -30)
    open:SetScript("OnClick", function()
      if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
      ns.ShowWindow()
    end)
  end

  local y = TOP_Y + 6
  Section(page, "Presets", y)
  y = y - 22
  for _, p in ipairs(ns.PRESETS) do
    local onClick = function() ns.ApplyPreset(p.key) end
    if p.key == "beyond" then onClick = ns.AskBeyond end
    PresetButton(page, p.name, y, p.desc, onClick)
    y = y - 30
  end
  local before = PresetButton(page, "Before Golden Hour", y, "", ns.RestoreSnapshot)
  y = y - 30
  local undo = PresetButton(page, "Undo", y, "", ns.Undo)

  y = y - 40
  Section(page, "Profiles", y)
  y = y - 22
  local save = PresetButton(page, "Save Current...", y, "", ns.AskSaveProfile)
  local import = UI.Button(page, "Import...", 110, 24)
  import:SetPoint("LEFT", save, "RIGHT", 8, 0)
  import:SetScript("OnClick", ns.AskImport)
  UI.Tooltip(import, function(tip)
    tip:SetText("Import a profile", 1, 1, 1)
    tip:AddLine("Paste a profile someone shared. It's checked first: only Golden Hour's settings, kept inside each one's safe range.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  end)
  save.desc:ClearAllPoints()
  save.desc:SetPoint("LEFT", import, "RIGHT", 12, 0)
  save.desc:SetWidth(page.W - 24 - 160 - 8 - 110 - 12 - 20)
  save.desc:SetText("Save yours, or add one someone shared.")
  y = y - 30

  local list = {}
  local offset = 0
  for i = 1, PROFILE_ROWS do
    local r = CreateFrame("Frame", nil, page)
    r:SetSize(page.W - 60, 24)
    r:SetPoint("TOPLEFT", 28, y - (i - 1) * 26)
    r.name = UI.Text(r, "GameFontHighlight")
    r.name:SetPoint("LEFT")
    r.name:SetWidth(250)
    r.name:SetJustifyH("LEFT")
    r.date = UI.Text(r, "GameFontDisableSmall")
    r.date:SetPoint("LEFT", 256, 0)
    r.delete = UI.Button(r, "Delete", 72, 22)
    r.delete:SetPoint("RIGHT")
    r.share = UI.Button(r, "Share", 72, 22)
    r.share:SetPoint("RIGHT", r.delete, "LEFT", -4, 0)
    r.load = UI.Button(r, "Load", 72, 22)
    r.load:SetPoint("RIGHT", r.share, "LEFT", -4, 0)
    list[i] = r
  end
  local empty = UI.Text(page, "GameFontDisableSmall")
  empty:SetPoint("TOPLEFT", 28, y - 4)
  empty:SetText("No profiles yet.")
  local listBottom = y - PROFILE_ROWS * 26
  local prev = UI.Button(page, "<", 26, 20)
  prev:SetPoint("TOPLEFT", page.W - 20 - 56, listBottom - 2)
  local nextB = UI.Button(page, ">", 26, 20)
  nextB:SetPoint("LEFT", prev, "RIGHT", 4, 0)
  prev:SetScript("OnClick", function() offset = math.max(0, offset - PROFILE_ROWS); page:Refresh() end)
  nextB:SetScript("OnClick", function() offset = offset + PROFILE_ROWS; page:Refresh() end)

  y = listBottom - 30
  Section(page, "Extras", y)
  y = y - 24
  local sparkle = UI.Check(page, "Loot sparkle")
  sparkle:SetPoint("TOPLEFT", 22, y)
  sparkle:SetScript("OnClick", function(self) ns.SetSparkle(self:GetChecked()) end)
  UI.Tooltip(sparkle, function(tip)
    tip:SetText("Loot sparkle", 1, 1, 1)
    tip:AddLine("Quest items sparkle instead of only getting an outline. Quest givers sparkle too, since the game uses one setting for both.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
    tip:AddLine("Blizzard's graphics quality slider turns it off. Golden Hour turns it back on a moment later.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
    tip:AddLine("Turning it off fully takes a game restart.", 0.6, 0.8, 1, true)
  end)
  local raid = UI.Check(page, "Also change raid and battleground graphics")
  raid:SetPoint("TOPLEFT", 260, y)
  raid:SetScript("OnClick", function(self) ns.SetRaid(self:GetChecked()) end)
  UI.Tooltip(raid, function(tip)
    tip:SetText("Raid and battleground graphics", 1, 1, 1)
    tip:AddLine("The game keeps a second copy of most of these settings for raids and battlegrounds, used when \"Raid / Battleground\" graphics are on in Blizzard's options.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
    tip:AddLine("With this on, every change here is made to both copies. Leave it off if you lower graphics in raids on purpose.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  end)

  function page:Refresh()
    local date = ns.SnapshotDate()
    before:SetEnabled(ns.db.snapshot ~= nil)
    before.desc:SetText(date
      and ("Every setting as it was on %s, the first time Golden Hour loaded."):format(date)
      or "Every setting as it was the first time Golden Hour loaded.")
    undo:SetEnabled(ns.CanUndo())
    undo.desc:SetText(ns.CanUndo() and ("Undoes \"%s\"."):format(ns.UndoLabel() or "the last change")
      or "Nothing to undo yet.")

    local names = ns.ProfileNames()
    if offset >= #names then offset = math.max(0, #names - PROFILE_ROWS) end
    offset = offset - offset % PROFILE_ROWS
    for i, r in ipairs(list) do
      local name = names[offset + i]
      if name then
        local p = ns.db.profiles[name]
        r.name:SetText(name)
        r.date:SetText(p and p.saved and ((p.shared and "added " or "saved ") .. p.saved) or "")
        r.load:SetScript("OnClick", function() ns.LoadProfile(name) end)
        r.share:SetScript("OnClick", function() ns.ShowShare(name) end)
        r.delete:SetScript("OnClick", function() ns.AskDeleteProfile(name) end)
        r:Show()
      else
        r:Hide()
      end
    end
    empty:SetShown(#names == 0)
    prev:SetShown(#names > PROFILE_ROWS)
    nextB:SetShown(#names > PROFILE_ROWS)
    prev:SetEnabled(offset > 0)
    nextB:SetEnabled(offset + PROFILE_ROWS < #names)

    sparkle:SetChecked(ns.db.sparkle)
    sparkle:SetEnabled(ns.HasSparkle())
    raid:SetChecked(ns.db.raid)
    raid:SetShown(ns.HasRaidCopies())
  end
  return page
end

-- The Auto page: hold settings through Blizzard's quality slider, and
-- switch by place.
function ns.BuildAutoPage(parent, inOptions)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints()
  page:Hide()
  page.W = inOptions and OPTIONS_W or WIN_W
  PageHeader(page, "Automatic",
    "Keep your settings when Blizzard's quality slider moves, and switch settings by where you are.",
    inOptions and 20 or 66)

  local y = TOP_Y + 6
  Section(page, "Keep my settings", y)
  y = y - 24
  local hold = UI.Check(page, "Put my settings back when Blizzard's Graphics Quality slider moves")
  hold:SetPoint("TOPLEFT", 22, y)
  hold:SetScript("OnClick", function(self) ns.SetHold(self:GetChecked()) end)
  UI.Tooltip(hold, function(tip)
    tip:SetText("Keep my settings", 1, 1, 1)
    tip:AddLine("Blizzard's Graphics Quality slider resets many of these settings. With this on, Golden Hour puts back what it last set a moment later.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
    tip:AddLine("Undo keeps Blizzard's values instead.", 0.6, 0.8, 1, true)
  end)

  y = y - 44
  Section(page, "Switch by place", y)
  y = y - 24
  local note = UI.Text(page, "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 24, y)
  note:SetWidth(page.W - 48)
  note:SetJustifyH("LEFT")
  note:SetText("Pick a preset or profile for each place. Leaving puts back what you had before.")
  y = y - 26
  local drops = {}
  for _, place in ipairs(ns.PLACES) do
    local label = UI.Text(page, "GameFontHighlight")
    label:SetPoint("TOPLEFT", 24, y - 5)
    label:SetText(place.label)
    local d = UI.Dropdown(page, 220, ns.ChoiceList,
      function() return ns.PlaceChoice(place.key) end,
      function(v) ns.SetPlace(place.key, v) end)
    d.frame:SetPoint("TOPLEFT", 232, y)
    drops[#drops + 1] = d
    y = y - 34
  end
  local foot = UI.Text(page, "GameFontDisableSmall")
  foot:SetPoint("TOPLEFT", 24, y - 6)
  foot:SetWidth(page.W - 48)
  foot:SetJustifyH("LEFT")
  foot:SetText("Cities and inns means anywhere you're resting. In raids and battlegrounds, Blizzard's own Raid / Battleground graphics take over when they're on, unless \"Also change raid and battleground graphics\" is ticked on Presets.")

  function page:Refresh()
    hold:SetChecked(ns.db.hold)
    for _, d in ipairs(drops) do d:Refresh() end
  end
  return page
end

-------------------------------------------------------------------------------
-- Footer: undo and graphics restart, on every page
-------------------------------------------------------------------------------

local footer

local function BuildFooter()
  footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", 8, 8)
  footer:SetPoint("BOTTOMRIGHT", -8, 8)
  footer:SetHeight(26)
  footer.undo = UI.Button(footer, "Undo", 90, 22)
  footer.undo:SetPoint("RIGHT", -4, 0)
  footer.undo:SetScript("OnClick", ns.Undo)
  UI.Tooltip(footer.undo, function(tip)
    tip:SetText("Undo", 1, 1, 1)
    tip:AddLine(ns.CanUndo() and ("Undoes \"%s\"."):format(ns.UndoLabel() or "the last change")
      or "Nothing to undo yet.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  end)
  footer.restart = UI.Button(footer, "Restart Graphics", 140, 22)
  footer.restart:SetPoint("RIGHT", footer.undo, "LEFT", -6, 0)
  footer.restart:SetScript("OnClick", ns.RestartGraphics)
  UI.Tooltip(footer.restart, function(tip)
    tip:SetText("Restart graphics", 1, 1, 1)
    tip:AddLine("Shadow resolution and HDR only change after the graphics restart. The screen goes black for a moment.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  end)
  -- Frame rate, so changes can be judged as they're made.
  footer.fps = UI.Text(footer, "GameFontHighlight")
  footer.fps:SetPoint("CENTER")
  local since = 1
  footer:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.5 then return end
    since = 0
    local fps = GetFramerate and GetFramerate()
    if fps then footer.fps:SetText(("FPS: |cffffd100%d|r"):format(math.floor(fps + 0.5))) end
  end)
  footer.options = UI.Button(footer, "Options", 90, 22)
  footer.options:SetPoint("LEFT", 4, 0)
  footer.options:SetScript("OnClick", function() ns.OpenOptions() end)
  UI.Tooltip(footer.options, function(tip)
    tip:SetText("Options > AddOns", 1, 1, 1)
    tip:AddLine("The same settings in Blizzard's Options window.", ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], true)
  end)
end

function ns.AddUndoRow(page, y)
  local undo = UI.Button(page, "Undo", 90, 22)
  undo:SetPoint("TOPLEFT", 24, y)
  undo:SetScript("OnClick", ns.Undo)
  local restart = UI.Button(page, "Restart Graphics", 140, 22)
  restart:SetPoint("LEFT", undo, "RIGHT", 6, 0)
  restart:SetScript("OnClick", ns.RestartGraphics)
  local refresh = page.Refresh
  function page:Refresh()
    refresh(self)
    undo:SetEnabled(ns.CanUndo())
    restart:SetShown(ns.needRestart)
  end
end

local function RefreshFooter()
  footer.undo:SetEnabled(ns.CanUndo())
  footer.restart:SetShown(ns.needRestart)
end

-------------------------------------------------------------------------------
-- The frame
-------------------------------------------------------------------------------

local function ShowPage(key)
  current = key
  for k, p in pairs(pages) do p:SetShown(k == key) end
  for i, k in ipairs(tabKeys) do
    if k == key and SelectTab then SelectTab(i) end
  end
  if pages[key] then
    pages[key]:Refresh()
    -- Once more next frame, when the sliders know their real size.
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if current == key and frame:IsShown() then pages[key]:Refresh() end
      end)
    end
  end
  ns.db.page = key
end

local function Refresh()
  if not (frame and frame:IsShown()) then return end
  if current and pages[current] then pages[current]:Refresh() end
  RefreshFooter()
end

local function SavePlace()
  local point, _, rel, x, y = frame:GetPoint()
  ns.db.pos = { point = point, rel = rel, x = x, y = y }
end

local function PlaceFrame()
  frame:ClearAllPoints()
  local p = ns.db.pos
  if p and p.point then
    frame:SetPoint(p.point, UIParent, p.rel or p.point, p.x or 0, p.y or 0)
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end

function ns.ResetPlace()
  ns.db.pos = nil
  if frame then PlaceFrame() end
  ns.Print("window moved back to the middle of the screen.")
end

local function MakeFrame()
  if UI.HasTemplate("PortraitFrameTemplate") then
    local ok, f = pcall(CreateFrame, "Frame", "GoldenHourFrame", UIParent, "PortraitFrameTemplate")
    if ok and f and f.CloseButton then return f, true end
  end
  local f = CreateFrame("Frame", "GoldenHourFrame", UIParent)
  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.06, 0.06, 0.07, 0.96)
  local title = UI.Text(f, "GameFontNormal")
  title:SetPoint("TOP", 0, -6)
  f.fallbackTitle = title
  local close = UI.Button(f, "X", 22, 20)
  close:SetPoint("TOPRIGHT", -4, -2)
  close:SetScript("OnClick", function() f:Hide() end)
  return f, false
end

local function Build()
  local blizzard
  frame, blizzard = MakeFrame()
  frame:SetSize(WIN_W, WIN_H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePlace()
  end)
  frame:Hide()
  if UISpecialFrames then table.insert(UISpecialFrames, "GoldenHourFrame") end

  if blizzard then
    if frame.SetTitle then frame:SetTitle(ns.TITLE) end
    if frame.SetPortraitToAsset then
      frame:SetPortraitToAsset(ns.ICON)
    else
      local p = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
      if p then p:SetTexture(ns.ICON) end
    end
  else
    frame.fallbackTitle:SetText(ns.TITLE)
  end

  -- A dark inset behind the rows, like Blizzard's panels.
  local inset = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  inset:SetPoint("TOPLEFT", 8, -70)
  inset:SetPoint("BOTTOMRIGHT", -8, 38)
  inset:SetColorTexture(0, 0, 0, 0.35)

  pages.presets = ns.BuildPresetsPage(frame)
  pages.auto = ns.BuildAutoPage(frame)
  tabKeys[1], tabKeys[2] = "presets", "auto"
  local names = { "Presets", "Auto" }
  for _, info in ipairs(ns.PAGES) do
    pages[info.key] = ns.BuildSettingsPage(frame, info)
    tabKeys[#tabKeys + 1] = info.key
    names[#names + 1] = info.tab
  end
  local _
  _, SelectTab = UI.Tabs(frame, names, function(i) ShowPage(tabKeys[i]) end)

  BuildFooter()
  PlaceFrame()

  frame:SetScript("OnShow", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN) end
    ShowPage(pages[ns.db.page or ""] and ns.db.page or "presets")
    RefreshFooter()
  end)
  frame:SetScript("OnHide", function()
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end
  end)
  ns.OnChange(Refresh)
end

function ns.Toggle()
  if not ns.db then return end
  if not frame then
    if #ns.list == 0 then ns.Scan() end
    Build()
  end
  frame:SetShown(not frame:IsShown())
end

function ns.ShowWindow()
  if not frame then ns.Toggle() return end
  frame:Show()
end
