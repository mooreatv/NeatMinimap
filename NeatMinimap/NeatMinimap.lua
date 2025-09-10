local addon, _ns = ...
local NMM = _G[addon] --[[
   NeatMinimap by MooreaTV moorea@ymail.com (c) 2019 All rights reserved
   Licensed under LGPLv3 - No Warranty
   (contact the author if you need a different license)

   Neat Minimap auto hides/shows buttons and clutter as needed

   Get this addon binary release using curse/twitch client or on wowinterface
   The source of the addon resides on https://github.com/mooreatv/NeatMinimap
   (and the MoLib library at https://github.com/mooreatv/MoLib)

   Releases detail/changes are on https://github.com/mooreatv/NeatMinimap/releases
   ]] -- -- -- our name, our empty default (and unused) anonymous ns -- Table and base functions created by MoLib
NMM.L = NMM:GetLocalization() -- localization
local L = NMM.L
NMM.slashCmdName = "nmm" -- NMM.debug = 9 -- to debug before saved variables are loaded
NMM.addonHash = "6653948"
NMM.savedVarName = "NeatMinimapSaved"
NMM.doClock = false -- Defaults
NMM.doNight = true
NMM.doGarrison = false
NMM.doTrack = false
NMM.delay = 0.5
NMM.fadeDuration = 0.25 -- New default fade duration
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
            UIFrameFadeIn(b, NMM.fadeDuration, b:GetAlpha() or 0, 1) -- Replaced pcall(b.Show, b) with a fade-in effect
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
        if b and b.Hide and b.IsDragging then
            local ok, r = pcall(b.IsDragging, b)
            if ok and not r then
                UIFrameFadeOut(b, NMM.fadeDuration, b:GetAlpha() or 1, 0) -- Replaced pcall(b.Hide, b) with a fade-out effect
            end
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
    if delay <= 0 then delay = 0.1 end
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
    ["NeatMinimapFrame"] = true, -- Our own frame
    ["MiniMapMailFrame"] = true, -- Std blizz stuff
    ["MiniMapBattlefieldFrame"] = true,
    ["MinimapBorder"] = true,
    ["MinimapBackdrop"] = true,
    ["MiniMapInstanceDifficulty"] = true, -- bfa
    ["GuildInstanceDifficulty"] = true,
    ["MiniMapChallengeMode"] = true,
    ["GameTimeFrame"] = true, -- handled through config, ElvUI (or bfa?) reparents it
    ["SexyMapCustomBackdrop"] = true, -- SexyMap
    ["SexyMapPingFrame"] = true,
    ["MMHolder"] = true, -- ElvUI
    ["HelpOpenWebTicketButton"] = true,
    ["HelpOpenTicketButton"] = true,
    ["TopMiniPanel"] = true,
    ["LeftMiniPanel"] = true,
    ["RightMiniPanel"] = true,
    ["BottomMiniPanel"] = true,
    ["TopLeftMiniPanel"] = true,
    ["TopRightMiniPanel"] = true,
    ["BottomLeftMiniPanel"] = true,
    ["BottomRightMiniPanel"] = true,
    ["MinimapPanel"] = true,
    ["QuestieFrameGroup"] = true -- Questie 4.1 onward
}

function NMM:UpdateButtons()
    if (NMM.buttons and NMM.buttons[1] == _G.MinimapZoomOut) or _G.MinimapZoomOut:IsVisible() then -- ElvUI for instance hides these buttons already, don't show them back:
        self:Debug("Not ElvUI case")
        NMM.buttons = {_G.MinimapZoomOut, _G.MinimapZoomIn}
        if _G.MiniMapTracking then -- bfa search button
            table.insert(NMM.buttons, _G.MiniMapTracking)
        end

        if _G.GarrisonLandingPageMinimapButton and NMM.doGarrison then table.insert(NMM.buttons, _G.GarrisonLandingPageMinimapButton) end
        if NMM.doNight then
            self:Debug("Adding GameTimeFrame per config")
            table.insert(NMM.buttons, _G.GameTimeFrame)
        end
    else
        self:Debug("ElvUI case, we'll start with fewer managed buttons")
        NMM.buttons = {}
    end

    NMM.exclude["TimeManagerClockButton"] = not NMM.doClock --  if NMM.square then --    NMM.exclude["MinimapBorder"] = false --    NMM.exclude["MinimapBackdrop"] = false --    Minimap:SetMaskTexture("") --  end
    NMM.exclude["MiniMapTrackingFrame"] = not NMM.doTrack
    for _, b in ipairs({Minimap:GetChildren()}) do
        local name = b:GetName()
        if NMM.exclude[name] or not b.Hide then
            self:Debug("Skipping % %", name, b.Hide)
        else
            name = name or b.name
            if b.uiMapID then
                self:Debug(3, "Skipping HereBeDragons pins %", name)
            elseif b.data and b.data.UiMapID then
                self:Debug(3, "Skipping Questie/UiMapID pins %", name)
            elseif b.waypoint then
                self:Debug(3, "Skipping Zygor/waypoint pins %", name)
            elseif not name and not b.icon then
                self:Debug("Skipping unamed frame/button")
            elseif name and NMM:StartsWith(name, "QuestieFrame") then
                self:Debug(4, "Skipping QuestieFrames %", name)
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
    f:SetScript("OnEnter", function()
        NMM:ShowButtons() -- f:Show()
    end)

    f:SetScript("OnLeave", function() NMM:ScheduleNextCheck() end)
    Minimap:HookScript("OnEnter", function() NMM:ShowButtons() end)
    Minimap:HookScript("OnLeave", function() NMM:ScheduleNextCheck() end)
    NMM:ForceUpdate()
end

local additionalEventHandlers = {
    PLAYER_ENTERING_WORLD = function(_self, ...)
        NMM:Debug("OnPlayerEnteringWorld " .. NMM:Dump(...)) -- Events handling -- define NMM:AfterSavedVars() for post saved var loaded processing
        NMM:CreateOptionsPanel()
        NMM:SetupMouseInOut()
        C_Timer.After(5, function()
            NMM:SetupMouseInOut() -- addons might add their buttons after us
        end)
    end,
    DISPLAY_SIZE_CHANGED = function(_self) end,
    UI_SCALE_CHANGED = function(_self, ...)
        NMM:DebugEvCall(1, ...)
        if NMM.resetTimer then
            NMM:Debug(4, "cancelling previous reset timer")
            NMM.resetTimer:Cancel()
        end

        local delay = 1
        NMM:Debug(5, "scheduling reset in %s", delay)
        NMM.resetTimer = C_Timer.NewTimer(delay, function()
            NMM.resetTimer = nil
            NMM:SetupMouseInOut()
        end)
    end
}

NMM:RegisterEventHandlers(additionalEventHandlers)
function NMM:Help(msg) --
    NMM:PrintDefault("NeatMinimap: " .. msg .. "\n" .. "/nmm config -- open addon config\n" .. "/nmm bug -- report a bug\n" .. "/nmm debug on/off/level -- for debugging on at level or off.\n" .. "/nmm version -- shows addon version")
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
    if not (posRest == nil) then rest = string.sub(arg, posRest + 1) end
    if cmd == "b" then
        local subText = L["Please submit on discord or on curse or github or email"]
        NMM:PrintDefault(L["NeatMinimap bug report open: "] .. subText)
        NMM:BugReport(subText, "6653948\n\n" .. L["Bug report from slash command"]) -- base molib will add version and date/timne
    elseif cmd == "v" then
        NMM:PrintDefault("NeatMinimap " .. NMM.manifestVersion .. " (6653948) by MooreaTv (moorea@ymail.com)") -- version
    elseif cmd == "c" then
        NMM:ShowConfigPanel(NMM.optionsPanel) -- Show config panel
    elseif NMM:StartsWith(arg, "debug") then
        if rest == "on" then -- debug
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

SlashCmdList["NeatMinimap_Slash_Command"] = NMM.Slash -- Run/set at load time: -- Slash
SLASH_NeatMinimap_Slash_Command1 = "/nmm"
function NMM:CreateOptionsPanel() -- Options panel
    if NMM.optionsPanel then
        NMM:Debug("Options Panel already setup")
        return
    end

    NMM:Debug("Creating Options Panel")
    local p = NMM:Frame(L["NeatMinimap"])
    NMM.optionsPanel = p
    p:addText(L["NeatMinimap options"], "GameFontNormalLarge"):Place()
    p:addText(L["Neat Minimap auto hides/shows buttons and clutter as needed"]):Place()
    p:addText(L["These options let you control the behavior of NeatMinimap"] .. " " .. NMM.manifestVersion .. " 6653948"):Place()
    local doClock = p:addCheckBox(L["Also hide/show Clock"], L["Whether the Blizzard clock should also be hidden/shown"]):Place(4, 20) --  local makeSquare = p:addCheckBox(L["Make the minimap square"], L["Experimental minimalistic square version"]) --                    :Place(4, 20)
    local doNight = p:addCheckBox(L["Also hide/show Day/Night (classic) Calendar (BfA) indicator"], L["Whether the Blizzard Day/Night indicator should also be hidden/shown"]):Place(4, 20)
    local doGarrison = p:addCheckBox(L["Also hide/show Mission indicator"], L["Whether the Blizzard Garrison/Mission/Faction indicator should also be hidden/shown"]):Place(4, 20)
    local doTrack = p:addCheckBox(L["Also hide/show tracker indicator"], L["Whether the Tracking (mining/herb/hunter tracking/...) indicator should also be hidden/shown"]):Place(4, 20)
    local delaySlider = p:addSlider(L["Hide delay"], L["How long to continue to show the button after mousing out of the map area"], 0, 3, 0.5, L["No delay"], L["3 sec"], {
        ["0"] = L["none"],
        ["0.5"] = L["0.5 s"],
        [1] = L["1 s"],
        ["1.5"] = L["1 ½ s"],
        [2] = L["2 s"],
        ["2.5"] = L["2 ½ s"]
    }):Place(16, 30)

    local fadeSlider = p:addSlider(L["Fade duration"], L["How long the fade-in and fade-out effects should last"], 0.1, 1.0, 0.25, L["Fast"], L["Slow"], {
        ["0.1"] = L["0.1 s"],
        ["0.25"] = L["0.25 s"],
        ["0.5"] = L["0.5 s"],
        ["0.75"] = L["0.75 s"],
        ["1.0"] = L["1.0 s"]
    }):Place(16, 30)

    p:addText(L["Development, troubleshooting and advanced options:"]):Place(40, 20)
    p:addButton("Bug Report", L["Get Information to submit a bug."] .. "\n|cFF99E5FF/nmm bug|r", "bug"):Place(4, 20)
    local debugLevel = p:addSlider(L["Debug level"], L["Sets the debug level"] .. "\n|cFF99E5FF/nmm debug X|r", 0, 9, 1, "Off"):Place(16, 30)
    function p:refresh()
        NMM:Debug("Options Panel refresh!")
        if NMM.debug then
            xpcall(function()
                self:HandleRefresh() -- expose errors
            end, geterrorhandler())
        else
            self:HandleRefresh() -- normal behavior for interface option panel: errors swallowed by caller
        end
    end

    function p:HandleRefresh()
        p:Init()
        debugLevel:SetValue(NMM.debug or 0)
        doClock:SetChecked(NMM.doClock)
        doNight:SetChecked(NMM.doNight)
        doGarrison:SetChecked(NMM.doGarrison)
        doTrack:SetChecked(NMM.doTrack)
        delaySlider:SetValue(NMM.delay)
        fadeSlider:SetValue(NMM.fadeDuration)
        NMM:ShowButtons() --    makeSquare:SetValue(NMM.square)
    end

    function p:HandleOk()
        NMM:Debug(1, "NMM.optionsPanel.okay() internal")
        local sliderVal = debugLevel:GetValue() --    local changes = 0 --    changes = changes + NMM:SetSaved("lineLength", lineLengthSlider:GetValue()) --    if changes > 0 then --      NMM:PrintDefault("NMM: % change(s) made to grid config", changes) --    end
        if sliderVal == 0 then
            sliderVal = nil
            if NMM.debug then NMM:PrintDefault("NeatMinimap: options setting debug level changed from % to OFF.", NMM.debug) end
        else
            if NMM.debug ~= sliderVal then NMM:PrintDefault("NeatMinimap: options setting debug level changed from % to %.", NMM.debug, sliderVal) end
        end

        NMM:SetSaved("debug", sliderVal)
        NMM:SetSaved("doClock", doClock:GetChecked())
        NMM:SetSaved("doNight", doNight:GetChecked())
        NMM:SetSaved("doGarrison", doGarrison:GetChecked())
        NMM:SetSaved("doTrack", doTrack:GetChecked())
        NMM:SetSaved("delay", delaySlider:GetValue())
        NMM:SetSaved("fadeDuration", fadeSlider:GetValue())
        NMM:SetupMouseInOut() --    NMM:SetSaved("square", makeSquare:GetChecked())
        NMM:ScheduleNextCheck()
    end

    function p:cancel()
        NMM:PrintDefault("NeatMinimap: options screen cancelled, not making any changes.")
    end

    function p:okay()
        NMM:Debug(3, "NMM.optionsPanel.okay() wrapper")
        if NMM.debug then
            xpcall(function()
                self:HandleOk() -- expose errors
            end, geterrorhandler())
        else
            self:HandleOk() -- normal behavior for interface option panel: errors swallowed by caller
        end
    end

    NMM:ConfigPanel(NMM.optionsPanel) -- Add the panel to the Interface Options
end

NMM:Debug("nmm main file loaded") -- NMM.debug = 2
