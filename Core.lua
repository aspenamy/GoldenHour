-------------------------------------------------------------------------------
-- Golden Hour: reading and writing settings, presets, profiles, undo,
-- the pre-addon snapshot and the loot sparkle
-------------------------------------------------------------------------------

local ADDON_NAME, ns = ...

ns.TITLE = "Golden Hour"
ns.ICON = "Interface\\AddOns\\GoldenHour\\media\\Icon"

local UNDO_MAX = 30
local GROUP_SECONDS = 2   -- slider moves this close together undo as one

-------------------------------------------------------------------------------
-- Saved data
-------------------------------------------------------------------------------

local DEFAULTS = {
  raid = false,      -- also change the raid and battleground copies
  sparkle = false,   -- keep the loot sparkle on
  hold = false,      -- put settings back after Blizzard's quality slider moves
  places = {},       -- place -> choice ("preset:lite", "profile:Name")
  profiles = {},
  undo = {},
}

local function InitDB()
  GoldenHourDB = type(GoldenHourDB) == "table" and GoldenHourDB or {}
  local db = GoldenHourDB
  for k, v in pairs(DEFAULTS) do
    if db[k] == nil then
      db[k] = type(v) == "table" and {} or v
    end
  end
  ns.db = db
end

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc66" .. ns.TITLE .. ":|r " .. msg)
end

-------------------------------------------------------------------------------
-- CVars
-------------------------------------------------------------------------------

local function GetRaw(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  return GetCVar and GetCVar(name)
end

local function SetRaw(name, value)
  local ok, res
  if C_CVar and C_CVar.SetCVar then
    ok, res = pcall(C_CVar.SetCVar, name, tostring(value))
  else
    ok, res = pcall(SetCVar, name, tostring(value))
  end
  return ok and res ~= false
end

-- Returns exists, default value (string or nil).
local function Info(name)
  if C_CVar and C_CVar.GetCVarInfo then
    local ok, value, default, _, _, locked, _, readOnly = pcall(C_CVar.GetCVarInfo, name)
    if not ok or value == nil then return false end
    if locked or readOnly then return false end
    return true, default
  end
  return GetRaw(name) ~= nil, nil
end

local function Same(a, b)
  if a == nil or b == nil then return a == b end
  local na, nb = tonumber(a), tonumber(b)
  if na and nb then return math.abs(na - nb) < 0.0001 end
  return tostring(a) == tostring(b)
end

function ns.Format(v)
  local n = tonumber(v)
  if not n then return tostring(v or "?") end
  if n == math.floor(n) then return tostring(math.floor(n)) end
  return (("%.2f"):format(n):gsub("0+$", ""):gsub("%.$", ""))
end

-------------------------------------------------------------------------------
-- The settings this client has
-------------------------------------------------------------------------------

ns.list = {}     -- every available setting, in page order
ns.byCvar = {}   -- lower-case cvar -> setting

local function BuildStops(s)
  if s.toggle then return { s.toggle.off, s.toggle.on } end
  local stops, seen = {}, {}
  local function Add(v)
    v = tonumber(v)
    if v == nil then return end
    local key = ("%.4f"):format(v)
    if not seen[key] then seen[key] = true; stops[#stops + 1] = v end
  end
  if s.stops then
    for _, v in ipairs(s.stops) do Add(v) end
  else
    local i = 0
    while true do
      local v = s.min + i * s.step
      if v > s.max + 0.0001 then break end
      Add(math.floor(v * 100 + 0.5) / 100)
      i = i + 1
    end
    Add(s.max)
  end
  for _, v in ipairs(s.stopsExtra or {}) do Add(v) end
  if s.beyond then Add(s.beyond) end
  -- Blizzard's default gets its own stop, unless it's past a crash cap.
  local d = tonumber(s.default)
  local top = s.stops and s.stops[#s.stops] or s.max
  if d and d <= top + 0.0001 and d >= (s.min or d) then Add(d) end
  table.sort(stops)
  return stops
end

local function Scan()
  wipe(ns.list)
  wipe(ns.byCvar)
  for _, page in ipairs(ns.PAGES) do
    page.available = {}
    for _, s in ipairs(page.settings) do
      local exists, default = Info(s.cvar)
      if exists then
        s.default = default
        s.raidCvar = nil
        local raidExists = Info("RAID" .. s.cvar)
        if raidExists then s.raidCvar = "RAID" .. s.cvar end
        s.stopList = BuildStops(s)
        s.page = page
        page.available[#page.available + 1] = s
        ns.list[#ns.list + 1] = s
        ns.byCvar[s.cvar:lower()] = s
      end
    end
  end
end
ns.Scan = Scan

function ns.Get(s)
  return GetRaw(s.cvar)
end

-- Position of the current value among the stops (nearest).
function ns.StopIndex(s, value)
  local v = tonumber(value)
  if v == nil then v = tonumber(GetRaw(s.cvar)) end
  if v == nil then return 1 end
  local best, bestD = 1, math.huge
  for i, stop in ipairs(s.stopList) do
    local d = math.abs(stop - v)
    if d < bestD then best, bestD = i, d end
  end
  return best
end

-- Lowest and highest value a setting may take (crash caps included).
function ns.Bounds(s)
  return s.stopList[1], s.stopList[#s.stopList]
end

-- A typed number, kept inside the bounds.
function ns.Clamp(s, v)
  local lo, hi = ns.Bounds(s)
  v = math.max(lo, math.min(hi, v))
  return math.floor(v * 100 + 0.5) / 100
end

function ns.IsOn(s)
  return Same(GetRaw(s.cvar), s.toggle.on)
end

-------------------------------------------------------------------------------
-- Changing values, with undo
-------------------------------------------------------------------------------

local listeners = {}
function ns.OnChange(fn) listeners[#listeners + 1] = fn end
local function Changed()
  for _, fn in ipairs(listeners) do pcall(fn) end
end
ns.Changed = Changed

ns.needRestart = false

-- Every setting and its raid copy, as they are now.
local function Capture()
  local values = {}
  for _, s in ipairs(ns.list) do
    values[s.cvar] = GetRaw(s.cvar)
    if s.raidCvar then values[s.raidCvar] = GetRaw(s.raidCvar) end
  end
  return values
end
ns.Capture = Capture

-- What Golden Hour last set, to put back after Blizzard's quality slider.
local function Hold()
  ns.db.held = Capture()
end

-- An undo step: { label =, time =, values = { cvar = old value } }
local function NewStep(label)
  return { label = label, time = time(), values = {} }
end

local function PushStep(step)
  if not next(step.values) then return end
  local undo = ns.db.undo
  undo[#undo + 1] = step
  while #undo > UNDO_MAX do table.remove(undo, 1) end
end

-- Writes one CVar, noting the old value in step. Returns true if the client
-- kept the new value.
local function Write(step, name, value)
  local old = GetRaw(name)
  if old == nil then return false end
  if Same(old, value) then return true end
  if step.values[name] == nil then step.values[name] = old end
  SetRaw(name, value)
  return Same(GetRaw(name), value)
end

local function WriteSetting(step, s, value, withRaid)
  local ok = Write(step, s.cvar, value)
  if withRaid and s.raidCvar then Write(step, s.raidCvar, value) end
  if s.restart and next(step.values) then ns.needRestart = true end
  return ok
end

-- One setting from a slider or checkbox. Quick moves of the same slider
-- become one undo step.
function ns.Set(s, value)
  local undo = ns.db.undo
  local last = undo[#undo]
  local now = GetTime and GetTime() or time()
  local step
  if last and last.cvar == s.cvar and ns.lastSetAt and now - ns.lastSetAt < GROUP_SECONDS then
    step = last
  else
    step = NewStep(s.label)
    step.cvar = s.cvar
  end
  ns.lastSetAt = now
  local ok = WriteSetting(step, s, value, ns.db.raid)
  if step ~= last then PushStep(step) end
  if not ok and not step.warned then
    step.warned = true
    ns.Print(("the game didn't accept %s for %s, so it's at %s."):format(
      ns.Format(value), s.label, ns.Format(GetRaw(s.cvar))))
  end
  Hold()
  Changed()
  return ok
end

-- Many settings at once: values = { cvar = value }.
local function Apply(label, values, withRaid)
  local step = NewStep(label)
  local refused = 0
  for name, value in pairs(values) do
    local s = ns.byCvar[name:lower()]
    if s then
      if not WriteSetting(step, s, value, withRaid) then refused = refused + 1 end
    elseif Info(name) then
      if not Write(step, name, value) then refused = refused + 1 end
    end
  end
  PushStep(step)
  Hold()
  Changed()
  return next(step.values) ~= nil, refused
end

local function Report(what, done, refused)
  if not done then
    ns.Print(what .. ": nothing needed changing.")
  elseif refused > 0 then
    ns.Print(("%s: done, but the game refused %d setting(s)."):format(what, refused))
  else
    ns.Print(what .. ": done. Undo puts it back.")
  end
end

function ns.CanUndo()
  return #ns.db.undo > 0
end

function ns.UndoLabel()
  local last = ns.db.undo[#ns.db.undo]
  return last and last.label
end

function ns.Undo()
  local step = table.remove(ns.db.undo)
  if not step then
    ns.Print("nothing to undo.")
    return
  end
  for name, value in pairs(step.values) do
    SetRaw(name, value)
    local s = ns.byCvar[name:lower()]
    if s and s.restart then ns.needRestart = true end
  end
  ns.lastSetAt = nil
  ns.Print("undid " .. (step.label or "the last change") .. ".")
  Hold()
  Changed()
end

-------------------------------------------------------------------------------
-- Presets
-------------------------------------------------------------------------------

-- key -> name, description, values()
ns.PRESETS = {
  { key = "beyond", name = "Beyond Ultra",
    desc = "The top values from the WoW Forever settings guide, with its crash fixes. Needs a strong PC.",
    values = function()
      local v = {}
      for _, s in ipairs(ns.list) do
        if s.beyond ~= nil then v[s.cvar] = s.beyond end
      end
      return v
    end },
  { key = "midrange", name = "Midrange",
    desc = "Strong graphics card, mid-range CPU. High shadows, light and water, lighter view distance.",
    values = function() return ns.MIDRANGE end },
  { key = "lite", name = "Lite",
    desc = "For laptops and older PCs. Shorter view distance and simpler shadows, light and water.",
    values = function() return ns.LITE end },
  { key = "defaults", name = "Blizzard Defaults",
    desc = "The game's own value for every setting in Golden Hour.",
    values = function()
      local v = {}
      for _, s in ipairs(ns.list) do
        if s.default ~= nil then v[s.cvar] = s.default end
      end
      return v
    end },
}
ns.presetByKey = {}
for _, p in ipairs(ns.PRESETS) do ns.presetByKey[p.key] = p end

-- A preset's values, limited to settings this client has.
function ns.PresetValues(key)
  local p = ns.presetByKey[key]
  if not p then return nil end
  local values = {}
  for cvar, v in pairs(p.values()) do
    if ns.byCvar[cvar:lower()] then values[cvar] = v end
  end
  return values
end

function ns.ApplyPreset(key, quiet)
  local p = ns.presetByKey[key]
  if not p then return end
  local done, refused = Apply(p.name, ns.PresetValues(key), ns.db.raid)
  if not quiet then Report(p.name, done, refused) end
end

function ns.ApplyBeyond() ns.ApplyPreset("beyond") end
function ns.ApplyMidrange() ns.ApplyPreset("midrange") end
function ns.ApplyLite() ns.ApplyPreset("lite") end
function ns.ApplyDefaults() ns.ApplyPreset("defaults") end

local function TakeSnapshot()
  local db = ns.db
  if db.snapshot then return end
  db.snapshot = Capture()
  local sparkle = GetRaw(ns.SPARKLE_CVAR)
  if sparkle ~= nil then db.snapshot[ns.SPARKLE_CVAR] = sparkle end
  db.snapshotDate = date and date("%b %d, %Y") or "first load"
end

function ns.SnapshotDate()
  return ns.db.snapshotDate
end

function ns.RestoreSnapshot()
  local snap = ns.db.snapshot
  if not snap then return end
  -- The raid copies are in the snapshot by name, so they come back as they were.
  local values = {}
  for k, v in pairs(snap) do
    if k ~= ns.SPARKLE_CVAR then values[k] = v end
  end
  Report("Before Golden Hour", Apply("Before Golden Hour", values, false))
end

-------------------------------------------------------------------------------
-- Profiles
-------------------------------------------------------------------------------

-- Profile names lose characters that would break sharing or show as
-- color codes.
local function CleanName(name)
  name = tostring(name or ""):gsub("[:;=|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  return name
end
ns.CleanName = CleanName

function ns.ProfileNames()
  local names = {}
  for name in pairs(ns.db.profiles) do names[#names + 1] = name end
  table.sort(names, function(a, b) return a:lower() < b:lower() end)
  return names
end

function ns.SaveProfile(name)
  name = ns.CleanName(name)
  if name == "" then return end
  ns.db.profiles[name] = { values = Capture(), saved = date and date("%b %d, %Y") or "" }
  ns.db.lastProfile = name
  ns.Print(("saved your settings as \"%s\"."):format(name))
  Changed()
end

function ns.LoadProfile(name, quiet)
  local p = ns.db.profiles[name]
  if not p then return end
  ns.db.lastProfile = name
  local done, refused = Apply(name, p.values, p.shared and ns.db.raid or false)
  if not quiet then Report(name, done, refused) end
end

-------------------------------------------------------------------------------
-- Sharing profiles as text
--
--   GoldenHour:1:Name:farclip=12000;shadowMode=4;...
--
-- Pasted values are checked: only Golden Hour's own settings, only numbers,
-- and kept inside each setting's range, so a shared string can't go past a
-- crash cap.
-------------------------------------------------------------------------------


function ns.ExportProfile(name)
  local p = ns.db.profiles[name]
  if not p then return nil end
  local parts = {}
  for cvar, v in pairs(p.values) do
    if not cvar:find("^RAID") and ns.byCvar[cvar:lower()] and tonumber(v) then
      parts[#parts + 1] = cvar .. "=" .. ns.Format(v)
    end
  end
  table.sort(parts)
  return ("GoldenHour:1:%s:%s"):format(CleanName(name), table.concat(parts, ";"))
end

-- Returns the new profile's name, or nil and a reason.
function ns.ImportProfile(text)
  text = tostring(text or ""):gsub("%s", "")
  local name, body = text:match("^GoldenHour:1:([^:]*):(.*)$")
  if not body then return nil, "that isn't a Golden Hour profile." end
  local values, count = {}, 0
  for cvar, v in body:gmatch("([%w_]+)=([%d%.%-]+)") do
    local s = ns.byCvar[cvar:lower()]
    local n = tonumber(v)
    if s and n then
      if s.toggle then
        n = (n == tonumber(s.toggle.on)) and s.toggle.on or s.toggle.off
      else
        n = ns.Clamp(s, n)
      end
      values[s.cvar] = n
      count = count + 1
    end
  end
  if count == 0 then return nil, "no settings in it this client knows." end
  name = CleanName(name)
  if name == "" then name = "Shared" end
  local base, i = name, 2
  while ns.db.profiles[name] do
    name = ("%s %d"):format(base, i)
    i = i + 1
  end
  ns.db.profiles[name] = { values = values, saved = date and date("%b %d, %Y") or "", shared = true }
  ns.Print(("added the profile \"%s\" with %d settings. Load it to use it."):format(name, count))
  Changed()
  return name
end

function ns.DeleteProfile(name)
  if not ns.db.profiles[name] then return end
  ns.db.profiles[name] = nil
  if ns.db.lastProfile == name then ns.db.lastProfile = nil end
  ns.Print(("deleted \"%s\"."):format(name))
  Changed()
end

-------------------------------------------------------------------------------
-- Raid copies
-------------------------------------------------------------------------------

-- Turning this on copies the current values over, so raids match at once.
function ns.SetRaid(on)
  ns.db.raid = on and true or false
  if ns.db.raid then
    local step = NewStep("Raid and battleground copies")
    for _, s in ipairs(ns.list) do
      if s.raidCvar then Write(step, s.raidCvar, GetRaw(s.cvar)) end
    end
    PushStep(step)
    Hold()
  end
  Changed()
end

function ns.HasRaidCopies()
  for _, s in ipairs(ns.list) do
    if s.raidCvar then return true end
  end
  return false
end

-------------------------------------------------------------------------------
-- Graphics restart (shadow resolution, HDR)
-------------------------------------------------------------------------------

function ns.RestartGraphics()
  if InCombatLockdown and InCombatLockdown() then
    ns.Print("can't restart graphics in combat.")
    return
  end
  ns.needRestart = false
  if RestartGx then
    RestartGx()
  elseif ConsoleExec then
    ConsoleExec("gxRestart")
  end
  Changed()
end

-------------------------------------------------------------------------------
-- Loot sparkle
--
-- Quest items sparkle instead of only getting an outline. Blizzard's graphics
-- quality sliders turn it off, so it's set again a moment after they move.
-- Quest givers sparkle too: the game uses the one setting for both.
-------------------------------------------------------------------------------

local sparkleWaiting = false
local busy = false

local function ApplySparkle()
  if not ns.db.sparkle then return end
  if InCombatLockdown and InCombatLockdown() then
    sparkleWaiting = true
    return
  end
  sparkleWaiting = false
  if not Same(GetRaw(ns.SPARKLE_CVAR), 1) then
    busy = true
    SetRaw(ns.SPARKLE_CVAR, 1)
    busy = false
  end
end

function ns.HasSparkle()
  return GetRaw(ns.SPARKLE_CVAR) ~= nil
end

function ns.SetSparkle(on)
  ns.db.sparkle = on and true or false
  if ns.db.sparkle then
    ApplySparkle()
  else
    busy = true
    SetRaw(ns.SPARKLE_CVAR, 0)
    busy = false
    ns.Print("loot sparkle off. It fully goes away after you restart the game.")
  end
  Changed()
end

local function Later(seconds, fn)
  if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

-------------------------------------------------------------------------------
-- Hold my settings: Blizzard's Graphics Quality slider resets many of these.
-- With this on, Golden Hour's last settings go back a moment after it moves.
-------------------------------------------------------------------------------

local holdPending = false

local function RestoreHeld()
  holdPending = false
  local held = ns.db.held
  if not (ns.db.hold and held) then return end
  busy = true
  local done = Apply("Graphics quality change", held, false)
  busy = false
  if done then ns.Print("put your Golden Hour settings back after the graphics quality change. Undo keeps Blizzard's.") end
end

function ns.SetHold(on)
  ns.db.hold = on and true or false
  if ns.db.hold then Hold() end
  Changed()
end

-------------------------------------------------------------------------------
-- Switch by place: a preset or profile for dungeons, raids, battlegrounds
-- and rested areas. Leaving puts back what you had before.
-------------------------------------------------------------------------------

ns.PLACES = {
  { key = "dungeon", label = "Dungeons" },
  { key = "raid", label = "Raids" },
  { key = "pvp", label = "Battlegrounds and arenas" },
  { key = "city", label = "Cities and inns" },
}

local function PlaceLabel(key)
  for _, p in ipairs(ns.PLACES) do
    if p.key == key then return p.label end
  end
  return key
end

local function WhereAmI()
  local inside, kind = false, nil
  if IsInInstance then inside, kind = IsInInstance() end
  if inside then
    if kind == "raid" then return "raid" end
    if kind == "party" or kind == "scenario" then return "dungeon" end
    if kind == "pvp" or kind == "arena" then return "pvp" end
    return "world"
  end
  if IsResting and IsResting() then return "city" end
  return "world"
end

-- Choices: "" (leave alone), "preset:<key>", "profile:<name>".
function ns.ChoiceList()
  local list = { { value = "", text = "Don't change" } }
  for _, p in ipairs(ns.PRESETS) do
    list[#list + 1] = { value = "preset:" .. p.key, text = p.name }
  end
  for _, name in ipairs(ns.ProfileNames()) do
    list[#list + 1] = { value = "profile:" .. name, text = name .. " (profile)" }
  end
  return list
end

function ns.ChoiceText(value)
  for _, c in ipairs(ns.ChoiceList()) do
    if c.value == value then return c.text end
  end
  return "Don't change"
end

local function ChoiceValues(choice)
  local kind, rest = tostring(choice or ""):match("^(%a+):(.+)$")
  if kind == "preset" then return ns.PresetValues(rest), ns.db.raid end
  if kind == "profile" then
    local p = ns.db.profiles[rest]
    return p and p.values, false
  end
end

local function CheckPlace()
  if not ns.db then return end
  local db = ns.db
  local here = WhereAmI()
  if here == db.placeApplied then return end
  -- Leaving a place we switched for: put the old settings back.
  if db.placeApplied and db.beforePlace then
    local from = db.placeApplied
    busy = true
    Apply("Leaving " .. from, db.beforePlace, false)
    busy = false
    db.beforePlace, db.placeApplied = nil, nil
    ns.Print("left the " .. PlaceLabel(from):lower() .. ", so your settings are back.")
  end
  local values, withRaid = ChoiceValues(db.places[here])
  if values then
    db.beforePlace = Capture()
    db.placeApplied = here
    busy = true
    Apply(ns.ChoiceText(db.places[here]), values, withRaid)
    busy = false
    ns.Print(("%s: switched to %s. Leaving puts your settings back."):format(
      PlaceLabel(here), ns.ChoiceText(db.places[here])))
  end
end

function ns.SetPlace(key, choice)
  ns.db.places[key] = (choice ~= "" and choice) or nil
  Changed()
  CheckPlace()
end

function ns.PlaceChoice(key)
  local c = ns.db.places[key]
  if c then
    -- A deleted profile counts as no choice.
    local kind, rest = c:match("^(%a+):(.+)$")
    if kind == "profile" and not ns.db.profiles[rest] then return "" end
    return c
  end
  return ""
end

-------------------------------------------------------------------------------
-- Events and slash commands
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
pcall(events.RegisterEvent, events, "CVAR_UPDATE")

events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    InitDB()
  elseif event == "PLAYER_LOGIN" then
    Scan()
    TakeSnapshot()
    ApplySparkle()
    Later(5, ApplySparkle)
    if ns.BuildOptions then ns.BuildOptions() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if sparkleWaiting then ApplySparkle() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UPDATE_RESTING" then
    if ns.db and #ns.list > 0 then Later(1, CheckPlace) end
  elseif event == "CVAR_UPDATE" and type(arg1) == "string" and ns.db and not busy then
    local name = arg1:lower()
    if ns.QUALITY_CVARS[name] or name == ns.SPARKLE_CVAR:lower() then
      Later(1, ApplySparkle)
    end
    if ns.QUALITY_CVARS[name] and ns.db.hold and not holdPending then
      holdPending = true
      Later(1, RestoreHeld)
    end
    if ns.QUALITY_CVARS[name] or ns.byCvar[name] then
      Changed()
    end
  end
end)

function GoldenHour_OnAddonCompartmentClick()
  if ns.Toggle then ns.Toggle() end
end

SLASH_GOLDENHOUR1 = "/goldenhour"
SLASH_GOLDENHOUR2 = "/gh"
SlashCmdList.GOLDENHOUR = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "options" then
    if ns.OpenOptions then ns.OpenOptions() end
  elseif msg == "undo" then
    ns.Undo()
  elseif msg == "reset" then
    if ns.ResetPlace then ns.ResetPlace() end
  elseif msg == "help" then
    ns.Print("/gh opens the window. /gh options opens it in Options > AddOns. /gh undo undoes the last change. /gh reset moves the window back.")
  else
    if ns.Toggle then ns.Toggle() end
  end
end
