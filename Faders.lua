local _, ns = ...

-- Non-bar frames that fade like bars: XP bar, cooldown manager, damage meter,
-- and the player frame.

local STATUS_NAMES = {
    "StatusTrackingBarManager",
    "MainStatusTrackingBarContainer",
    "SecondaryStatusTrackingBarContainer",
    "MainMenuExpBar",
    "ReputationWatchBar",
}

local COOLDOWN_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "BuffBarCooldownViewer",
}

-- Keep the meter readable for a moment after combat ends.
local METER_AFTER_COMBAT = 10

local statusFrames = {}
local cooldownFrames = {}
local meterFrames = {}
local meterSet = {}
local lastCombat

local function IsFadeable(frame)
    return type(frame) == "table" and frame.SetAlpha and frame.IsShown and true or false
end

local function FindNamed(list, names)
    for i = #list, 1, -1 do
        list[i] = nil
    end
    for _, name in ipairs(names) do
        local frame = _G[name]
        if IsFadeable(frame) then
            list[#list + 1] = frame
        end
    end
end

local function AddMeter(frame)
    if meterSet[frame] or not IsFadeable(frame) then return end
    meterSet[frame] = true
    meterFrames[#meterFrames + 1] = frame
end

-- The meter is load-on-demand and its window names are not fixed, so a deep
-- scan of UIParent picks up whatever DamageMeter* frames exist.
local function FindMeters(deep)
    AddMeter(_G.DamageMeter)
    for i = 1, 10 do
        AddMeter(_G["DamageMeterSessionWindow" .. i])
    end
    if not deep or not UIParent or not UIParent.GetChildren then return end
    for _, child in ipairs({ UIParent:GetChildren() }) do
        local name = ns.FrameName(child)
        if name and name:find("^DamageMeter") then
            AddMeter(child)
        end
    end
end

function ns.FindFaders(deep)
    FindNamed(statusFrames, STATUS_NAMES)
    FindNamed(cooldownFrames, COOLDOWN_NAMES)
    FindMeters(deep)
end

function ns.MarkCombatEnd()
    if type(GetTime) == "function" then
        lastCombat = GetTime()
    end
end

local function MeterShouldShow(showAll)
    if showAll then return true end
    if lastCombat and type(GetTime) == "function" then
        return GetTime() - lastCombat < METER_AFTER_COMBAT
    end
    return false
end

-- A group shows together when any shown member is hovered.
local function UpdateGroup(frames, show, elapsed)
    if not show then
        for _, frame in ipairs(frames) do
            if ns.MouseOver(frame) then
                show = true
                break
            end
        end
    end
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            ns.UpdateFaded(frame, show, elapsed)
        end
    end
end

local function PlayerBusy()
    if UnitExists("target") or UnitIsDeadOrGhost("player") then return true end
    return UnitHealth("player") < UnitHealthMax("player")
end

local function UpdatePlayer(showAll, elapsed)
    local frame = PlayerFrame
    if not IsFadeable(frame) or not frame:IsShown() then return end
    local ok, busy = pcall(PlayerBusy)
    local show = showAll or ns.MouseOver(frame) or not ok or busy
    ns.UpdateFaded(frame, show, elapsed)
end

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

function ns.UpdateFaders(showAll, elapsed)
    Run("xp bar", UpdateGroup, statusFrames, showAll, elapsed)
    Run("cooldown manager", UpdateGroup, cooldownFrames, showAll, elapsed)
    Run("damage meter", UpdateGroup, meterFrames, MeterShouldShow(showAll), elapsed)
    Run("player frame", UpdatePlayer, showAll, elapsed)
end
