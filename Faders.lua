local _, ns = ...

-- Non-bar frames that fade: XP bar, cooldown manager, personal resource bar,
-- damage meter, the player frame, the pet frame, the quest tracker, and buffs.

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

-- Mana, focus and energy rest at max; rage and the rest rest at zero.
local RESTS_AT_MAX = { [0] = true, [2] = true, [3] = true }

local statusFrames = {}
local cooldownFrames = {}
local resourceFrames = {}
local questFrames = {}
local auraFrames = {}
local meterFrames = {}
local meterSet = {}
local lastCombat
local lastQuestXP

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
    FindNamed(questFrames, QUEST_NAMES)
    FindNamed(auraFrames, AURA_NAMES)
    FindMeters(deep)
end

function ns.MarkCombatEnd()
    if type(GetTime) == "function" then
        lastCombat = GetTime()
    end
end

function ns.MarkQuestXP(xp)
    if type(xp) == "number" and not ns.IsSecret(xp) and xp <= 0 then return end
    if type(GetTime) == "function" then
        lastQuestXP = GetTime()
    end
end

local function XPShouldShow()
    if ns.XPForced() then return true end
    if lastQuestXP and type(GetTime) == "function" then
        return GetTime() - lastQuestXP < XP_AFTER_QUEST
    end
    return false
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

local function Flag(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, ...)
    return ok and result and true or false
end

-- A child already follows its parent alpha. Fading it again would compound.
local function Under(frame, ancestor)
    if not frame or not frame.GetParent or not ancestor then return false end
    local parent = frame:GetParent()
    local depth = 0
    while parent and depth < 6 do
        if parent == ancestor then return true end
        if not parent.GetParent then return false end
        parent = parent:GetParent()
        depth = depth + 1
    end
    return false
end

-- Off, the portrait stays for edit mode. On, it shows beside the resource bar
-- with a target, in combat, in an instance, in a group, in a vehicle, on hover,
-- and while Glance is held. A pet out does not keep it up. The pet frame uses
-- the same alpha.
local function UpdatePlayer(elapsed)
    local player = PlayerFrame
    local pet = PetFrame
    local show = ns.InEditMode()
    if ns.PlayerStyle() == "classic" then
        show = show
            or ns.Glancing()
            or ns.MouseOver(player)
            or ns.MouseOver(pet)
            or InCombatLockdown()
            or ns.InForcedInstance()
            or ns.InGroup()
            or Flag(UnitHasVehicleUI, "player")
            or Flag(UnitExists, "target")
    end
    if IsFadeable(player) and player:IsShown() then
        ns.UpdateFaded(player, show, elapsed)
    end
    if IsFadeable(pet) and pet:IsShown() and not Under(pet, player) then
        ns.UpdateFaded(pet, show, elapsed)
    end
end

local function ResourceForced()
    return InCombatLockdown() or ns.InForcedInstance() or ns.InEditMode() or ns.Pinned("resource")
        or ns.Glancing()
end

-- Health and power are secret on this client, so Lua cannot compare them. A
-- curve maps the secret share straight to an alpha: 1 below the limit, 0 at it.
local curves = {}

local function ThresholdCurve(limit)
    local cached = curves[limit]
    if cached ~= nil then return cached or nil end
    curves[limit] = false
    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function" then
        ns.Report("resource bar", "C_CurveUtil.CreateCurve missing")
        return nil
    end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        c:AddPoint(0, 1)
        c:AddPoint(limit - 0.001, 1)
        c:AddPoint(limit, 0)
        if limit < 1 then c:AddPoint(1, 0) end
        return c
    end)
    if ok then
        curves[limit] = curve
    else
        ns.Report("resource bar", curve)
    end
    return curves[limit] or nil
end

local function LowPowerAlpha()
    local kind = UnitPowerType("player")
    if ns.IsSecret(kind) or not RESTS_AT_MAX[kind] then return 0 end
    local curve = ThresholdCurve(LOW_POWER)
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    return UnitPowerPercent("player", kind, false, curve)
end

local function MissingHealthAlpha()
    local curve = ThresholdCurve(1)
    if not curve or type(UnitHealthPercent) ~= "function" then return 0 end
    return UnitHealthPercent("player", false, curve)
end

local function SafeAlpha(label, fn)
    local ok, alpha = pcall(fn)
    if ok then return alpha end
    ns.Report(label, alpha)
    return 0
end

local function HealthPart(frame)
    local health = frame.HealthBarsContainer
    if ns.Usable(health) and health.SetAlpha then return health end
end

-- Two secret alphas cannot be merged, so the health part follows missing
-- health and every other child follows low power; the frame itself stays at 1.
local function HoldResourceParts(frame, forced)
    local health = HealthPart(frame)
    if not health or not frame.GetChildren then
        if forced then return false end
        ns.HoldSecretAlpha(frame, SafeAlpha("player power", LowPowerAlpha))
        return true
    end
    if forced then
        for _, child in ipairs({ frame:GetChildren() }) do
            if ns.Usable(child) and child.SetAlpha then ns.HoldAlpha(child, 1) end
        end
        return false
    end
    ns.HoldAlpha(frame, 1)
    local healthAlpha = SafeAlpha("player health", MissingHealthAlpha)
    local powerAlpha = SafeAlpha("player power", LowPowerAlpha)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child == health then
            ns.HoldSecretAlpha(child, healthAlpha)
        elseif ns.Usable(child) and child.SetAlpha then
            ns.HoldSecretAlpha(child, powerAlpha)
        end
    end
    return true
end

local function UpdateResource(elapsed)
    local forced = ResourceForced()
    for _, frame in ipairs(resourceFrames) do
        if frame:IsShown() and not HoldResourceParts(frame, forced) then
            ns.UpdateFaded(frame, true, elapsed)
        end
    end
end

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return InCombatLockdown() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
end

-- Aura buttons can sit outside their container's bounds, so children count too.
local function MouseOverAny(frame)
    if ns.MouseOver(frame) then return true end
    if not frame.GetChildren then return false end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) and ns.MouseOver(child) then return true end
    end
    return false
end

local function UpdateAuras(elapsed)
    local show = InCombatLockdown() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
        or ns.Pinned("auras") or ns.Glancing()
    if not show then
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    for _, frame in ipairs(auraFrames) do
        if frame:IsShown() then
            ns.UpdateFaded(frame, show, elapsed)
        end
    end
end

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

function ns.UpdateFaders(showAll, elapsed)
    local glance = ns.Glancing()
    Run("xp bar", UpdateGroup, statusFrames, XPShouldShow() or ns.Pinned("xp") or glance, elapsed)
    Run("cooldown manager", UpdateGroup, cooldownFrames, CooldownsShouldShow() or ns.Pinned("cooldowns") or glance, elapsed, true)
    Run("damage meter", UpdateGroup, meterFrames, MeterShouldShow(showAll) or ns.Pinned("meter") or glance, elapsed)
    Run("resource bar", UpdateResource, elapsed)
    Run("player frame", UpdatePlayer, elapsed)
    Run("quest tracker", UpdateGroup, questFrames, ns.InEditMode() or ns.Pinned("quests") or glance, elapsed)
    Run("buffs", UpdateAuras, elapsed)
end
