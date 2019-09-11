--[[
   NeatMinimap by MooreaTV moorea@ymail.com (c) 2019 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Neat Minimap auto hides/shows button as needed

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/NeatMinimap
   (and the MoLib library at https://github.com/mooreatv/MoLib)

   Releases detail/changes are on https://github.com/mooreatv/NeatMinimap/releases
   ]] --
--
-- our name, our empty default (and unused) anonymous ns
local addon, _ns = ...

-- Table and base functions created by MoLib
local NMM = _G[addon]
-- localization
NMM.L = NMM:GetLocalization()
local L = NMM.L

-- NMM.debug = 9 -- to debug before saved variables are loaded

NMM.slashCmdName = "nmm"
NMM.addonHash = "@project-abbreviated-hash@"
NMM.savedVarName = "NeatMinimapSaved"

-- Defaults
NMM.doClock = false
NMM.doNight = true
NMM.doGarrison = false
NMM.delay = 0.5

NMM.buttons = {}

NMM.buttonsShown = true

function NMM:ShowButtons(force)
  if NMM.buttonsShown and not force then
    NMM:Debug(5, "Already shown buttons")
    return
  end
  NMM:Debug("Showing buttons - force %", force)
  for _, b in ipairs(NMM.buttons) do
    if b and b.Show then
      b:Show()
    end
  end
  NMM.buttonsShown = true
  NMM:CancelCheck("showing buttons")
end

function NMM:HideButtons(force)
  if not NMM.buttonsShown and not force then
    NMM:Debug(5, "Already hidden buttons")
    return
  end
  NMM:Debug("Hiding buttons - force %", force)
  for _, b in ipairs(NMM.buttons) do
    if b and b.Hide then
      b:Hide()
    end
  end
  NMM.buttonsShown = false
end

function NMM:ForceUpdate()
  if NMM:IsCursorInside(NMM.minimapframe) then
    NMM:ShowButtons(true)
  else
    NMM:HideButtons(true)
  end
end

function NMM:IsCursorInside(f)
  local l, b, w, h = f:GetRect()
  local s = f:GetEffectiveScale() or 1
  local x1 = l * s
  local x2 = (l + w) * s
  local y1 = b * s
  local y2 = (b + h) * s
  local x, y = GetCursorPosition()
  local isIn = (x >= x1) and (x <= x2) and (y >= y1) and (y <= y2)
  self:Debug(2, "ISIN % cursor x % y % - scale %, rect % % dimension % x %", isIn, x, y, s, l, b, w, h)
  return isIn
end

function NMM:HasAncestor(child, parent)
  if not child then
    self:Debug("Not ancestor")
    return false
  end
  local p = child:GetParent()
  self:Debug("Checking % % %", child, p, parent)
  return p == parent or self:HasAncestor(p, parent)
end

function NMM:CancelCheck(msg)
  if self.timer then
    self:Debug(4, "cancelling previous timer " .. msg)
    self.timer:Cancel()
    self.timer = nil
  end
end

function NMM:ScheduleNextCheck()
  self:CancelCheck("scheduling next one")
  local delay = self.delay
  if delay <= 0 then
    delay = 0.1
  end
  self:Debug(5, "scheduling in %s", delay)
  self.timer = C_Timer.NewTimer(delay, function()
    self.timer = nil
    self:Check()
  end)
end

function NMM:Check()
  if NMM:IsCursorInside(NMM.minimapframe) then
    NMM:ShowButtons()
    NMM:ScheduleNextCheck()
    return
  end
  NMM:HideButtons()
end

NMM.exclude = {
  -- Our own frame
  ["NeatMinimapFrame"] = true,
  -- Std blizz stuff
  ["MiniMapMailFrame"] = true,
  ["MiniMapTrackingFrame"] = true,
  ["MiniMapBattlefieldFrame"] = true,
  ["MinimapBorder"] = true,
  ["MinimapBackdrop"] = true,
  -- SexyMap
  ["SexyMapCustomBackdrop"] = true,
  ["SexyMapPingFrame"] = true,
  -- ElvUI
  ["MMHolder"] = true,
  ["HelpOpenWebTicketButton"] = true,
  ["HelpOpenTicketButton"] = true,
  ["TopMiniPanel"] = true,
}

function NMM:UpdateButtons()
  -- ElvUI for instance hides these buttons already, don't show them back:
  if (NMM.buttons and NMM.buttons[1]==_G.MinimapZoomOut) or _G.MinimapZoomOut:IsVisible() then
    NMM.buttons = {_G.MinimapZoomOut, _G.MinimapZoomIn}
    if _G.MiniMapTracking then -- bfa search button
      table.insert(NMM.buttons, _G.MiniMapTracking)
    end
    if _G.GarrisonLandingPageMinimapButton and NMM.doGarrison then
      table.insert(NMM.buttons, _G.GarrisonLandingPageMinimapButton)
    end
    if NMM.doNight then
     table.insert(NMM.buttons, _G.GameTimeFrame)
    end
  else
    NMM.buttons = {}
  end
  NMM.exclude["TimeManagerClockButton"] = not NMM.doClock
  for _, b in ipairs({Minimap:GetChildren()}) do
    local name = b:GetName()
    if NMM.exclude[name] or not b.Hide then
      self:Debug("Skipping % %", name, b.Hide)
    else
      name = name or b.name
      if not name and not b.icon then
        self:Debug("Skipping unamed frame/button")
      elseif name and NMM:StartsWith(name, "QuestieFrame") then
        self:Debug(4, "Skipping QuestieFrames %", name)
      elseif name and NMM:StartsWith(name, "HandyNotes") then
        self:Debug(4, "Skipping HandyNotesPins %", name)
      else
        self:Debug("Adding %", name)
        table.insert(NMM.buttons, b)
      end
    end
  end
end

function NMM:SetupMouseInOut()
  NMM:UpdateButtons()
  local name = "NeatMinimapFrame"
  local f = NMM.minimapframe or NMM:Frame(name, name, nil, Minimap)
  NMM.minimapframe = f
  f:ClearAllPoints()
  local border = 25
  f:SetPoint("BOTTOMLEFT", -border, -border)
  f:SetPoint("TOPRIGHT", border, border)
  f:SetFrameStrata("BACKGROUND")
  f:EnableMouse(false)
  -- f:Show()
  f:SetScript("OnEnter", function()
    NMM:ShowButtons()
  end)
  f:SetScript("OnLeave", function()
    NMM:ScheduleNextCheck()
  end)
  Minimap:HookScript("OnEnter", function()
    NMM:ShowButtons()
  end)
  Minimap:HookScript("OnLeave", function()
    NMM:ScheduleNextCheck()
  end)
  NMM:ForceUpdate()
end

-- Events handling

-- define NMM:AfterSavedVars() for post saved var loaded processing

local additionalEventHandlers = {

  PLAYER_ENTERING_WORLD = function(_self, ...)
    NMM:Debug("OnPlayerEnteringWorld " .. NMM:Dump(...))
    NMM:CreateOptionsPanel()
    NMM:SetupMouseInOut()
    -- addons might add their buttons after us
    C_Timer.After(3, function()
      NMM:SetupMouseInOut()
    end)
  end,

  DISPLAY_SIZE_CHANGED = function(_self)
  end,

  UI_SCALE_CHANGED = function(_self, ...)
    NMM:DebugEvCall(1, ...)
  end

}

NMM:RegisterEventHandlers(additionalEventHandlers)

--

function NMM:Help(msg)
  NMM:PrintDefault("NeatMinimap: " .. msg .. "\n" .. "/nmm config -- open addon config\n" ..
                     "/nmm bug -- report a bug\n" .. "/nmm debug on/off/level -- for debugging on at level or off.\n" ..
                     "/nmm version -- shows addon version")
end

function NMM.Slash(arg) -- can't be a : because used directly as slash command
  NMM:Debug("Got slash cmd: %", arg)
  if #arg == 0 then
    NMM:Help("commands, you can use the first letter of each:")
    return
  end
  local cmd = string.lower(string.sub(arg, 1, 1))
  local posRest = string.find(arg, " ")
  local rest = ""
  if not (posRest == nil) then
    rest = string.sub(arg, posRest + 1)
  end
  if cmd == "b" then
    local subText = L["Please submit on discord or on curse or github or email"]
    NMM:PrintDefault(L["NeatMinimap bug report open: "] .. subText)
    -- base molib will add version and date/timne
    NMM:BugReport(subText, "@project-abbreviated-hash@\n\n" .. L["Bug report from slash command"])
  elseif cmd == "v" then
    -- version
    NMM:PrintDefault("NeatMinimap " .. NMM.manifestVersion ..
                       " (@project-abbreviated-hash@) by MooreaTv (moorea@ymail.com)")
  elseif cmd == "c" then
    -- Show config panel
    -- InterfaceOptionsList_DisplayPanel(NMM.optionsPanel)
    InterfaceOptionsFrame:Show() -- onshow will clear the category if not already displayed
    InterfaceOptionsFrame_OpenToCategory(NMM.optionsPanel) -- gets our name selected
  elseif NMM:StartsWith(arg, "debug") then
    -- debug
    if rest == "on" then
      NMM:SetSaved("debug", 1)
    elseif rest == "off" then
      NMM:SetSaved("debug", nil)
    else
      NMM:SetSaved("debug", tonumber(rest))
    end
    NMM:PrintDefault("NeatMinimap debug now %", NMM.debug)
  else
    NMM:Help('unknown command "' .. arg .. '", usage:')
  end
end

-- Run/set at load time:

-- Slash

SlashCmdList["NeatMinimap_Slash_Command"] = NMM.Slash

SLASH_NeatMinimap_Slash_Command1 = "/nmm"

-- Options panel

function NMM:CreateOptionsPanel()
  if NMM.optionsPanel then
    NMM:Debug("Options Panel already setup")
    return
  end
  NMM:Debug("Creating Options Panel")

  local p = NMM:Frame(L["NeatMinimap"])
  NMM.optionsPanel = p
  p:addText(L["NeatMinimap options"], "GameFontNormalLarge"):Place()
  p:addText(L["Neat Minimap auto hides/shows button as needed"]):Place()
  p:addText(L["These options let you control the behavior of NeatMinimap"] .. " " .. NMM.manifestVersion ..
              " @project-abbreviated-hash@"):Place()

  local doClock = p:addCheckBox(L["Also hide/show Clock"], L["Whether the Blizzard clock should also be hidden/shown"])
                    :Place(4, 20)
  local doNight = p:addCheckBox(L["Also hide/show Day/Night indicator"],
                                L["Whether the Blizzard Day/Night indicator should also be hidden/shown"]):Place(4, 20)

  local doGarrison = p:addCheckBox(L["Also hide/show Mission indicator"],
                                L["Whether the Blizzard Garrison/Mission/Faction indicator should also be hidden/shown"]):Place(4, 20)

  local delaySlider = p:addSlider(L["Show delay"], L["How long to show the button after mousing out of the map area"],
                                  0, 3, 0.5, L["No delay"], L["3 sec"], {
    ["0"] = L["none"],
    ["0.5"] = L["0.5 s"],
    [1] = L["1 s"],
    ["1.5"] = L["1 ½ s"],
    [2] = L["2 s"],
    ["2.5"] = L["2 ½ s"]
  }):Place(16, 30)

  p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 20)

  p:addButton("Bug Report", L["Get Information to submit a bug."] .. "\n|cFF99E5FF/nmm bug|r", "bug"):Place(4, 20)

  local debugLevel = p:addSlider(L["Debug level"], L["Sets the debug level"] .. "\n|cFF99E5FF/nmm debug X|r", 0, 9, 1,
                                 "Off"):Place(16, 30)

  function p:refresh()
    NMM:Debug("Options Panel refresh!")
    if NMM.debug then
      -- expose errors
      xpcall(function()
        self:HandleRefresh()
      end, geterrorhandler())
    else
      -- normal behavior for interface option panel: errors swallowed by caller
      self:HandleRefresh()
    end
  end

  function p:HandleRefresh()
    p:Init()
    debugLevel:SetValue(NMM.debug or 0)
    doClock:SetChecked(NMM.doClock)
    doNight:SetChecked(NMM.doNight)
    doGarrison:SetChecked(NMM.doGarrison)
    delaySlider:SetValue(NMM.delay)
    NMM:ShowButtons()
  end

  function p:HandleOk()
    NMM:Debug(1, "NMM.optionsPanel.okay() internal")
    --    local changes = 0
    --    changes = changes + NMM:SetSaved("lineLength", lineLengthSlider:GetValue())
    --    if changes > 0 then
    --      NMM:PrintDefault("NMM: % change(s) made to grid config", changes)
    --    end
    local sliderVal = debugLevel:GetValue()
    if sliderVal == 0 then
      sliderVal = nil
      if NMM.debug then
        NMM:PrintDefault("NeatMinimap: options setting debug level changed from % to OFF.", NMM.debug)
      end
    else
      if NMM.debug ~= sliderVal then
        NMM:PrintDefault("NeatMinimap: options setting debug level changed from % to %.", NMM.debug, sliderVal)
      end
    end
    NMM:SetSaved("debug", sliderVal)
    NMM:SetSaved("doClock", doClock:GetChecked())
    NMM:SetSaved("doNight", doNight:GetChecked())
    NMM:SetSaved("doGarrison", doGarrison:GetChecked())
    NMM:SetSaved("delay", delaySlider:GetValue())
    NMM:SetupMouseInOut()
    NMM:ScheduleNextCheck()
  end

  function p:cancel()
    NMM:PrintDefault("NeatMinimap: options screen cancelled, not making any changes.")
  end

  function p:okay()
    NMM:Debug(3, "NMM.optionsPanel.okay() wrapper")
    if NMM.debug then
      -- expose errors
      xpcall(function()
        self:HandleOk()
      end, geterrorhandler())
    else
      -- normal behavior for interface option panel: errors swallowed by caller
      self:HandleOk()
    end
  end
  -- Add the panel to the Interface Options
  InterfaceOptions_AddCategory(NMM.optionsPanel)
end

-- NMM.debug = 2
NMM:Debug("nmm main file loaded")
