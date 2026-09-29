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
    for i = 1, #resourceFrames do
        resourceFrames[i]._quietKids = nil
    end
    for i = 1, #auraFrames do
        auraFrames[i]._quietKids = nil
    end
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
            if ns.Hit(frame) then
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

-- Same length as the bar fade. Showing snaps to 1. Hiding eases.
local SMOOTH = 0.3
local POWER_FROM = LOW_POWER - 0.001
local HEALTH_FROM = 0.999

local POWER_REST = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 0 },
    { 1, 0 },
}
local POWER_FORCED = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { LOW_POWER, 1 },
    { 1, 1 },
}
local HEALTH_REST = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 0 },
}
local HEALTH_FORCED = {
    { 0, 1 },
    { HEALTH_FROM, 1 },
    { 1, 1 },
}

local curveCache = {}
local liveCurve = {}
local playerWeight = 0
local playerCurved = false
local auraWeight = 0
local aurasCurved = false
local resourceWeight = 0

-- Boolean show for the portrait. Low power stays on the curve below.
-- Edit mode shows it even when the player frame is off.
local function PlayerShouldShow()
    if ns.InEditMode() then return true end
    if ns.PlayerStyle() ~= "classic" then return false end
    return ns.Glancing()
        or ns.Hit(PlayerFrame)
        or ns.Hit(PetFrame)
        or ns.InCombat()
        or ns.InForcedInstance()
        or ns.InGroup()
        or ns.InVehicle()
        or ns.HasTarget()
end

local function ResourceForced()
    return ns.InCombat() or ns.InForcedInstance() or ns.InEditMode() or ns.Pinned("resource")
        or ns.Glancing()
end

-- Mana, focus and energy. Rage and the rest stay out even when the type number
-- is hidden, as long as the token is still a plain string.
local function RestingPower()
    if type(UnitPowerType) ~= "function" then return nil end
    local kind, token = UnitPowerType("player")
    if type(token) == "string" and not ns.IsSecret(token) then
        if token == "MANA" or token == "FOCUS" or token == "ENERGY" then return kind end
        return nil
    end
    if not ns.IsSecret(kind) then
        if RESTS_AT_MAX[kind] then return kind end
        return nil
    end
    return kind
end

-- Secret values cannot be lerped, so the curve points move and the widget fades.
local function MakeCurve(points)
    if not C_CurveUtil or type(C_CurveUtil.CreateCurve) ~= "function" then
        ns.Report("resource bar", "C_CurveUtil.CreateCurve missing")
        return nil
    end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        for i = 1, #points do
            c:AddPoint(points[i][1], points[i][2])
        end
        return c
    end)
    if not ok then
        ns.Report("resource bar", curve)
        return nil
    end
    return curve
end

local function CurveFor(points, key)
    if key then
        local cached = curveCache[key]
        if cached ~= nil then return cached or nil end
        curveCache[key] = false
    end
    local curve = MakeCurve(points)
    if key then
        curveCache[key] = curve or false
    end
    return curve
end

local function BlendPoints(rest, forced, t)
    if t <= 0 then return rest end
    if t >= 1 then return forced end
    local out = {}
    for i = 1, #rest do
        local y0, y1 = rest[i][2], forced[i][2]
        out[i] = { rest[i][1], y0 + (y1 - y0) * t }
    end
    return out
end

local function BlendedCurve(rest, forced, t, name)
    local curve
    if t <= 0 then
        curve = CurveFor(rest, name .. ":0")
    elseif t >= 1 then
        curve = CurveFor(forced, name .. ":1")
    else
        curve = MakeCurve(BlendPoints(rest, forced, t))
    end
    liveCurve[name] = curve
    return curve
end

local function NextWeight(current, show, elapsed)
    if show or current <= 0 then return show and 1 or 0 end
    local step = (elapsed or 0) / SMOOTH
    if current <= step then return 0 end
    return current - step
end

local function TakeWeight(curved, weight, show, elapsed, useCurve)
    if not useCurve then return false, weight end
    if not curved then
        weight = show and 1 or 0
    end
    return true, NextWeight(weight, show, elapsed)
end

local function EvalPower(weight)
    local kind = RestingPower()
    if kind == nil then return nil end
    local curve = BlendedCurve(POWER_REST, POWER_FORCED, weight, "power")
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitPowerPercent, "player", kind, false, curve)
    if ok and alpha ~= nil then return alpha end
    if not ok then ns.Report("player power", alpha) end
    return 0
end

local function EvalHealth(weight)
    local curve = BlendedCurve(HEALTH_REST, HEALTH_FORCED, weight, "health")
    if not curve or type(UnitHealthPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitHealthPercent, "player", false, curve)
    if ok and alpha ~= nil then return alpha end
    if not ok then ns.Report("player health", alpha) end
    return 0
end

local function PaintNumeric(frame, show, elapsed)
    if not (IsFadeable(frame) and frame:IsShown()) then return end
    ns.EaseAlpha(frame, show, elapsed)
end

local function PaintSecret(frame, alpha)
    if not (IsFadeable(frame) and frame:IsShown()) or alpha == nil then return end
    ns.HoldSecretAlpha(frame, alpha)
end

local function HealthPart(frame)
    local health = frame.HealthBarsContainer
    if ns.Usable(health) and health.SetAlpha then return health end
end

local function KidsOf(frame)
    local kids = frame._quietKids
    if kids then return kids end
    kids = {}
    frame._quietKids = kids
    if not frame.GetChildren then return kids end
    for _, child in ipairs({ frame:GetChildren() }) do
        kids[#kids + 1] = child
    end
    return kids
end

-- Two secret alphas cannot be merged, so the health part follows missing
-- health and every other child follows low power. The frame itself stays at 1.
local function PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    if not (IsFadeable(frame) and frame:IsShown()) then return end
    local health = HealthPart(frame)
    local kids = KidsOf(frame)
    if not health or #kids == 0 then
        if powerAlpha ~= nil then
            PaintSecret(frame, powerAlpha)
        else
            PaintNumeric(frame, show, elapsed)
        end
        return
    end
    if frame._quietAlpha ~= 1 or frame._quietSecret ~= nil then
        ns.HoldAlpha(frame, 1)
    end
    for i = 1, #kids do
        local child = kids[i]
        if ns.Usable(child) and child.SetAlpha then
            if child == health then
                ns.HoldSecretAlpha(child, healthAlpha)
            elseif powerAlpha ~= nil then
                ns.HoldSecretAlpha(child, powerAlpha)
            else
                ns.EaseAlpha(child, show, elapsed)
            end
        end
    end
end

local function UpdateResource(elapsed)
    local show = ResourceForced() and true or false
    resourceWeight = NextWeight(resourceWeight, show, elapsed)
    local powerAlpha = EvalPower(resourceWeight)
    local healthAlpha = EvalHealth(resourceWeight)
    for _, frame in ipairs(resourceFrames) do
        PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    end
end

local function UpdatePlayer(elapsed)
    local show = PlayerShouldShow() and true or false
    local useCurve = ns.PlayerStyle() == "classic" and RestingPower() ~= nil
    playerCurved, playerWeight = TakeWeight(playerCurved, playerWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPower(playerWeight) or nil
    local player = PlayerFrame
    local pet = PetFrame
    if alpha ~= nil then
        PaintSecret(player, alpha)
        if not Under(pet, player) then PaintSecret(pet, alpha) end
    else
        PaintNumeric(player, show, elapsed)
        if not Under(pet, player) then PaintNumeric(pet, show, elapsed) end
    end
end

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
end

-- Aura buttons can sit outside their container's bounds, so children count too.
local function MouseOverAny(frame)
    if ns.Hit(frame) then return true end
    local kids = KidsOf(frame)
    for i = 1, #kids do
        if ns.Usable(kids[i]) and ns.Hit(kids[i]) then return true end
    end
    return false
end

local function AurasShouldShow()
    local show = ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
        or ns.Pinned("auras") or ns.Glancing()
    if not show then
        for _, frame in ipairs(auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    if not show and ns.GroupAuras() and PlayerShouldShow() then
        show = true
    end
    return show
end

local function UpdateAuras(elapsed)
    local show = AurasShouldShow() and true or false
    local useCurve = ns.GroupAuras() and ns.PlayerStyle() == "classic" and RestingPower() ~= nil
    aurasCurved, auraWeight = TakeWeight(aurasCurved, auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and EvalPower(auraWeight) or nil
    for _, frame in ipairs(auraFrames) do
        if alpha ~= nil then
            PaintSecret(frame, alpha)
        else
            PaintNumeric(frame, show, elapsed)
        end
    end
end

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

-- The tracker container is not mouse-enabled, so the gaps between quests are
-- not hover. This frame is not its child: a faded parent would drop the mouse.
local questCatcher
local questCatcherTarget

local function ShownQuest()
    for i = 1, #questFrames do
        local frame = questFrames[i]
        if ns.Usable(frame) and frame:IsShown() then
            return frame
        end
    end
end

local function EnsureQuestCatcher()
    if questCatcher then return questCatcher end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:Hide()
    questCatcher = created
    return created
end

local function PlaceQuestCatcher()
    local box = EnsureQuestCatcher()
    if not box then return end
    local target = ShownQuest()
    if not target or ns.InEditMode() or not ns.DB().enabled then
        box:Hide()
        questCatcherTarget = nil
        return
    end
    if questCatcherTarget ~= target then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(target)
        questCatcherTarget = target
    end
    local strata = target.GetFrameStrata and target:GetFrameStrata()
    if type(strata) == "string" then
        box:SetFrameStrata(strata)
    end
    local level = target.GetFrameLevel and target:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    box:SetFrameLevel(math.max(level - 1, 0))
    if not box:IsShown() then box:Show() end
end

function ns.HideQuestCatcher()
    if not questCatcher then return end
    questCatcher:Hide()
    questCatcherTarget = nil
end

function ns.UpdateSmooth(elapsed)
    Run("resource bar", UpdateResource, elapsed)
    Run("player frame", UpdatePlayer, elapsed)
    Run("buffs", UpdateAuras, elapsed)
end

function ns.UpdateFaders(showAll, elapsed)
    local glance = ns.Glancing()
    Run("xp bar", UpdateGroup, statusFrames, XPShouldShow() or ns.Pinned("xp") or glance, elapsed)
    Run("cooldown manager", UpdateGroup, cooldownFrames, CooldownsShouldShow() or ns.Pinned("cooldowns") or glance, elapsed, true)
    Run("damage meter", UpdateGroup, meterFrames, MeterShouldShow(showAll) or ns.Pinned("meter") or glance, elapsed)
    Run("quest catcher", PlaceQuestCatcher)
    local questHot = questCatcher and ns.Hit(questCatcher)
    Run("quest tracker", UpdateGroup, questFrames, ns.InEditMode() or ns.Pinned("quests") or glance or questHot, elapsed)
end
