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

-- Events handling

-- define NMM:AfterSavedVars() for post saved var loaded processing

local additionalEventHandlers = {

  PLAYER_ENTERING_WORLD = function(_self, ...)
    NMM:Debug("OnPlayerEnteringWorld " .. NMM:Dump(...))
    NMM:CreateOptionsPanel()
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

  local delay = p:addSlider(L["Shown delay"], L["How long to show the button after mousing out of the map area"],
                                  2, 10, 1, L["1 sec"], L["5 sec"]):Place(16, 30)

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

-- bindings / localization
_G.NEATMINIMAP = "NeatMinimap"
_G.BINDING_HEADER_NMM = L["Neat Minimap addon key bindings"]
_G.BINDING_NAME_NMM_SOMETHING = L["TODO something"] .. " |cFF99E5FF/nmm todo|r"

-- NMM.debug = 2
NMM:Debug("nmm main file loaded")
