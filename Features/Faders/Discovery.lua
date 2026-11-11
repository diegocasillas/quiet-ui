local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Non-bar frames that fade: XP bar, cooldown manager, personal resource bar,
-- damage meter, the player frame, the pet frame, the quest tracker, buffs,
-- and the range gradient on the target nameplate.

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

local PARTY_NAMES = {
    "CompactPartyFrameContainer",
    "CompactRaidFrameContainer",
    "PartyFrame",
}

local QUEST_NAMES = {
    "ObjectiveTrackerFrame",
    "QuestWatchFrame",
    "WatchFrame",
}

local AURA_NAMES = {
    "BuffFrame",
    "DebuffFrame",
    "TemporaryEnchantFrame",
}

-- Keep the meter readable for a moment after combat ends.
local METER_AFTER_COMBAT = 10

-- Quest XP arrives out of combat, so the XP bar shows it for a moment.
local XP_AFTER_QUEST = 5

-- The resource bar also shows out of combat below this share of max power.
local LOW_POWER = 0.7
Faders.LOW_POWER = LOW_POWER

-- Mana, focus and energy rest at max; rage and the rest rest at zero.
local RESTS_AT_MAX = { [0] = true, [2] = true, [3] = true }
Faders.RESTS_AT_MAX = RESTS_AT_MAX

local statusFrames = {}
Faders.statusFrames = statusFrames
local cooldownFrames = {}
Faders.cooldownFrames = cooldownFrames
local resourceFrames = {}
Faders.resourceFrames = resourceFrames
local partyFrames = {}
Faders.partyFrames = partyFrames
local questFrames = {}
Faders.questFrames = questFrames
local auraFrames = {}
Faders.auraFrames = auraFrames
local meterFrames = {}
Faders.meterFrames = meterFrames
local meterSet = {}
local lastCombat
local lastQuestXP

local function IsFadeable(frame)
    return ns.Usable(frame) and frame.SetAlpha and frame.IsShown and true or false
end
Faders.IsFadeable = IsFadeable

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

-- Drop the child cache only when the frame grew or the count cannot be read.
local function RefreshKids(list)
    for i = 1, #list do
        local frame = list[i]
        local count, known
        if type(frame.GetNumChildren) == "function" then
            local ok, value = pcall(frame.GetNumChildren, frame)
            if ok and type(value) == "number" and not ns.IsSecret(value) then
                count, known = value, true
            end
        end
        if not known or frame._puroPuroCineKidCount ~= count then
            frame._puroPuroCineKids = nil
            frame._puroPuroCineKidCount = known and count or nil
        end
    end
end

function ns.FindFaders(deep)
    FindNamed(statusFrames, STATUS_NAMES)
    FindNamed(cooldownFrames, COOLDOWN_NAMES)
    FindNamed(resourceFrames, RESOURCE_NAMES)
    FindNamed(questFrames, QUEST_NAMES)
    FindNamed(auraFrames, AURA_NAMES)
    FindNamed(partyFrames, PARTY_NAMES)
    RefreshKids(resourceFrames)
    RefreshKids(auraFrames)
    FindMeters(deep)
end

function ns.MarkCombatEnd()
    if type(GetTime) == "function" then
        lastCombat = GetTime()
    end
    ns.TouchHud()
end

function ns.MarkQuestXP(xp)
    if type(xp) == "number" and not ns.IsSecret(xp) and xp <= 0 then return end
    if type(GetTime) == "function" then
        lastQuestXP = GetTime()
    end
    ns.TouchHud()
end

local function XPShouldShow()
    if ns.OnlyOnHover("xp") then return false end
    if ns.ShowAll() then return true end
    if lastQuestXP and type(GetTime) == "function" then
        return GetTime() - lastQuestXP < XP_AFTER_QUEST
    end
    return false
end
Faders.XPShouldShow = XPShouldShow

local function MeterShouldShow()
    if ns.InCombat() or ns.InForcedInstance() or ns.InEditMode() then return true end
    if lastCombat and type(GetTime) == "function" then
        return GetTime() - lastCombat < METER_AFTER_COMBAT
    end
    return false
end
Faders.MeterShouldShow = MeterShouldShow

local function PartyShouldShow()
    if ns.InEditMode() then return true end
    return ns.Glancing()
        or ns.InCombat()
        or (ns.InGroup() and ns.ShowPlayerFrameInParty())
        or ns.InForcedInstance()
        or ns.InVehicle()
        or ns.HasTarget()
end
Faders.PartyShouldShow = PartyShouldShow

local function RaidManagerShouldShow()
    if ns.InEditMode() then return true end
end
Faders.RaidManagerShouldShow = RaidManagerShouldShow

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end
Faders.Run = Run
