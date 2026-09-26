local _, ns = ...

-- Non-bar frames that fade: XP bar, cooldown manager, personal resource bar,
-- damage meter, and the player frame.

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

local RESOURCE_NAMES = {
    "PersonalResourceDisplayFrame",
}

-- Keep the meter readable for a moment after combat ends.
local METER_AFTER_COMBAT = 10

-- The resource bar also shows out of combat below this share of max power.
local LOW_POWER = 0.7

-- Mana, focus and energy rest at max; rage and the rest rest at zero.
local RESTS_AT_MAX = { [0] = true, [2] = true, [3] = true }

local statusFrames = {}
local cooldownFrames = {}
local resourceFrames = {}
local meterFrames = {}
local meterSet = {}
local lastCombat

local function IsFadeable(frame)
    return ns.Usable(frame) and frame.SetAlpha and frame.IsShown and true or false
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
    FindNamed(resourceFrames, RESOURCE_NAMES)
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
local function UpdateGroup(frames, show, elapsed, noHover)
    if not show and not noHover then
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

-- Health and power live on the resource bar, so the portrait is hover only.
local function UpdatePlayer(elapsed)
    local frame = PlayerFrame
    if not IsFadeable(frame) or not frame:IsShown() then return end
    ns.UpdateFaded(frame, ns.InEditMode() or ns.MouseOver(frame), elapsed)
end

local function ResourceForced()
    return InCombatLockdown() or ns.InForcedInstance() or ns.InEditMode()
end

-- Power is secret on this client, so Lua cannot compare it. A curve maps the
-- secret power share straight to an alpha: 1 below LOW_POWER, 0 above.
local lowPowerCurve

local function LowPowerCurve()
    if lowPowerCurve ~= nil then return lowPowerCurve or nil end
    lowPowerCurve = false
    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function" then
        ns.Report("resource bar", "C_CurveUtil.CreateCurve missing")
        return nil
    end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        c:AddPoint(0, 1)
        c:AddPoint(LOW_POWER - 0.001, 1)
        c:AddPoint(LOW_POWER, 0)
        c:AddPoint(1, 0)
        return c
    end)
    if ok then
        lowPowerCurve = curve
    else
        ns.Report("resource bar", curve)
    end
    return lowPowerCurve or nil
end

local function LowPowerAlpha()
    local kind = UnitPowerType("player")
    if ns.IsSecret(kind) or not RESTS_AT_MAX[kind] then return 0 end
    local curve = LowPowerCurve()
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    return UnitPowerPercent("player", kind, false, curve)
end

local function UpdateResource(elapsed)
    if ResourceForced() then
        UpdateGroup(resourceFrames, true, elapsed, true)
        return
    end
    local ok, alpha = pcall(LowPowerAlpha)
    if not ok then
        ns.Report("player power", alpha)
        alpha = 0
    end
    for _, frame in ipairs(resourceFrames) do
        if frame:IsShown() then
            ns.HoldSecretAlpha(frame, alpha)
        end
    end
end

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return InCombatLockdown() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
end

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

function ns.UpdateFaders(showAll, elapsed)
    Run("xp bar", UpdateGroup, statusFrames, showAll, elapsed)
    Run("cooldown manager", UpdateGroup, cooldownFrames, CooldownsShouldShow(), elapsed, true)
    Run("damage meter", UpdateGroup, meterFrames, MeterShouldShow(showAll), elapsed)
    Run("resource bar", UpdateResource, elapsed)
    Run("player frame", UpdatePlayer, elapsed)
end
