-------------------------------------------------------------------------------
-- Golden Hour in Options > AddOns
--
-- The same pages as the window, so the marks, number boxes and presets are
-- all here too: Golden Hour (presets and profiles) with one page under it
-- for each tab. Values are read straight from the game, so the window and
-- this panel always agree.
-------------------------------------------------------------------------------

local _, ns = ...

local category
local built = false
local holders = {}   -- { frame, page }

local function Refresh(h)
  h.page:Refresh()
  -- Once more next frame, when the sliders know their real size.
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if h.frame:IsVisible() then h.page:Refresh() end
    end)
  end
end

local function Holder(build)
  local f = CreateFrame("Frame")
  f:Hide()
  local page = build(f)
  page:Show()
  local h = { frame = f, page = page }
  f:SetScript("OnShow", function() Refresh(h) end)
  holders[#holders + 1] = h
  return f
end

function ns.BuildOptions()
  if built then return end
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  built = true
  local ok, err = pcall(function()
    local main = Holder(function(f) return ns.BuildPresetsPage(f, true) end)
    category = Settings.RegisterCanvasLayoutCategory(main, ns.TITLE)
    if Settings.RegisterCanvasLayoutSubcategory then
      local auto = Holder(function(f) return ns.BuildAutoPage(f, true) end)
      Settings.RegisterCanvasLayoutSubcategory(category, auto, "Automatic")
      for _, info in ipairs(ns.PAGES) do
        if #info.available > 0 then
          local sub = Holder(function(f) return ns.BuildSettingsPage(f, info, true) end)
          Settings.RegisterCanvasLayoutSubcategory(category, sub, info.title)
        end
      end
    end
    Settings.RegisterAddOnCategory(category)
  end)
  if not ok then ns.Print("couldn't build the Options pages: " .. tostring(err)) end
  ns.OnChange(function()
    for _, h in ipairs(holders) do
      if h.frame:IsVisible() then h.page:Refresh() end
    end
  end)
end

function ns.OpenOptions()
  if category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  else
    ns.ShowWindow()
  end
end
