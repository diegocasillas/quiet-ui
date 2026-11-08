local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Same length as the bar fade. Showing snaps to 1. Hiding eases.
local SMOOTH = 0.3
local POWER_FROM = Faders.LOW_POWER - 0.001
local HEALTH_FROM = 0.999

local POWER_REST = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { Faders.LOW_POWER, 0 },
    { 1, 0 },
}
local POWER_FORCED = {
    { 0, 1 },
    { POWER_FROM, 1 },
    { Faders.LOW_POWER, 1 },
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
Faders.playerWeight = 0
Faders.playerCurved = false
Faders.auraWeight = 0
Faders.aurasCurved = false
Faders.resourceWeight = 0
Faders.resourceCurved = false
Faders.samplingPower = false
-- sampledKind: state lives in Faders
-- sampledPlayerShow: state lives in Faders
local powerWeights, powerAlphas = {}, {}
Faders.powerAlphas = powerAlphas
Faders.powerSampleCount = 0

local function DeadTargetBlocked()
    if not ns.RequireLivingTarget() or ns.InEditMode() or ns.Glancing() then return false end
    local fn = type(UnitIsDeadOrGhost) == "function" and UnitIsDeadOrGhost
        or (type(UnitIsDead) == "function" and UnitIsDead)
    if not fn then return false end
    local ok, dead = pcall(fn, "target")
    if not ok then
        ns.Report("target life", dead)
        return false
    end
    if ns.IsSecret(dead) then return false end
    return dead and true or false
end
Faders.DeadTargetBlocked = DeadTargetBlocked

-- Boolean show for the portrait. Health and power stay on the curves below.
-- Edit mode shows it even when the player frame is off.
local function PlayerShouldShow()
    if Faders.samplingPower and Faders.sampledPlayerShow ~= nil then return Faders.sampledPlayerShow end
    if ns.InEditMode() then return true end
    if DeadTargetBlocked() then return false end
    if ns.PlayerStyle() ~= "classic" then return false end
    return ns.Glancing()
        or ns.InCombat()
        or ns.InForcedInstance()
        or (ns.InGroup() and ns.ShowPlayerFrameInParty())
        or ns.InVehicle()
        or ns.HasTarget()
        or ns.Hit(PlayerFrame)
        or ns.Hit(PetFrame)
        -- Linked: whatever shows the personal resource bar shows the player frame.
        or (not ns.OnlyOnHover("resource") and Faders.ResourceForced())
end
Faders.PlayerShouldShow = PlayerShouldShow

local function ResourceForced()
    return ns.InCombat() or ns.InForcedInstance() or ns.InEditMode() or ns.Pinned("resource")
        or ns.Glancing()
end
Faders.ResourceForced = ResourceForced

-- With the player frame on, the personal resource bar and the player frame show and
-- hide together, the way grouped buffs follow the player frame. The resource row on
-- Only on hover keeps its own rules, and so does the bar while a dead target is
-- hiding the player frame.
local function ResourceLinked()
    return ns.PlayerStyle() == "classic" and not ns.OnlyOnHover("resource") and not DeadTargetBlocked()
end
Faders.ResourceLinked = ResourceLinked

-- Mana, focus and energy. Rage and the rest stay out even when the type number
-- is hidden, as long as the token is still a plain string.
local function ReadRestingPower()
    if type(UnitPowerType) ~= "function" then return nil end
    local kind, token = UnitPowerType("player")
    if type(token) == "string" and not ns.IsSecret(token) then
        if token == "MANA" or token == "FOCUS" or token == "ENERGY" then return kind end
        return nil
    end
    if not ns.IsSecret(kind) then
        if Faders.RESTS_AT_MAX[kind] then return kind end
        return nil
    end
    return kind
end
Faders.ReadRestingPower = ReadRestingPower

local function RestingPower()
    if Faders.samplingPower then return Faders.sampledKind end
    return ReadRestingPower()
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
        local key = name .. ":blend"
        curve = CurveFor(rest, key)
        if not curve then return nil end
        if type(curve.ClearPoints) ~= "function" then
            return MakeCurve(BlendPoints(rest, forced, t))
        end
        local ok, err = pcall(function()
            curve:ClearPoints()
            for i = 1, #rest do
                local y0, y1 = rest[i][2], forced[i][2]
                curve:AddPoint(rest[i][1], y0 + (y1 - y0) * t)
            end
        end)
        if not ok then
            curveCache[key] = nil
            ns.Report("resource bar", err)
            return MakeCurve(BlendPoints(rest, forced, t))
        end
    end
    return curve
end

local function NextWeight(current, show, elapsed)
    if show or current <= 0 then return show and 1 or 0 end
    local step = (elapsed or 0) / SMOOTH
    if current <= step then return 0 end
    return current - step
end
Faders.NextWeight = NextWeight

local function TakeWeight(curved, weight, show, elapsed, useCurve)
    if not useCurve then return false, weight end
    if not curved then
        weight = show and 1 or 0
    end
    return true, NextWeight(weight, show, elapsed)
end
Faders.TakeWeight = TakeWeight

local function EvalPower(weight)
    local kind = RestingPower()
    if kind == nil then return nil end
    if weight >= 1 then return 1 end
    -- Weights are plain numbers; the cached result may be secret and is never compared.
    if Faders.samplingPower then
        for i = 1, Faders.powerSampleCount do
            if powerWeights[i] == weight then return powerAlphas[i] end
        end
    end
    local curve = BlendedCurve(POWER_REST, POWER_FORCED, weight, "power")
    if not curve or type(UnitPowerPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitPowerPercent, "player", kind, false, curve)
    if ok and alpha ~= nil then
        if Faders.samplingPower then
            Faders.powerSampleCount = Faders.powerSampleCount + 1
            powerWeights[Faders.powerSampleCount] = weight
            powerAlphas[Faders.powerSampleCount] = alpha
        end
        return alpha
    end
    if not ok then ns.Report("player power", alpha) end
    return 0
end
Faders.EvalPower = EvalPower

local function EvalHealth(weight)
    if weight >= 1 then return 1 end
    local curve = BlendedCurve(HEALTH_REST, HEALTH_FORCED, weight, "health")
    if not curve or type(UnitHealthPercent) ~= "function" then return 0 end
    local ok, alpha = pcall(UnitHealthPercent, "player", false, curve)
    if ok and alpha ~= nil then return alpha end
    if not ok then ns.Report("player health", alpha) end
    return 0
end
Faders.EvalHealth = EvalHealth

local thresholdCurves = {}
local thresholdWeights, thresholdAlphas = {}, {}
Faders.thresholdAlphas = thresholdAlphas
Faders.thresholdSampleCount = 0

local function ThresholdCurve(name, percent, above)
    local ok, curve = pcall(function()
        local c = thresholdCurves[name]
        if not c then
            c = C_CurveUtil.CreateCurve()
            c:SetType(Enum.LuaCurveType.Step)
            thresholdCurves[name] = c
        end
        c:ClearPoints()
        c:AddPoint(0, 1)
        c:AddPoint(percent / 100, above)
        return c
    end)
    if ok then return curve end
    thresholdCurves[name] = nil
    ns.Report("player threshold curve", curve)
end

local function ReadThreshold()
    if ns.PlayerThreshold then return ns.PlayerThreshold() end
    return "health", 70
end

local function EvalPlayerThresholds(weight)
    if weight >= 1 then return 1 end
    if Faders.samplingPower then
        for i = 1, Faders.thresholdSampleCount do
            if thresholdWeights[i] == weight then return thresholdAlphas[i] end
        end
    end
    local kind, percent = ReadThreshold()
    local alpha = weight
    if percent then
        -- Curve points are plain numbers; only the evaluated alpha may be secret.
        local curve = ThresholdCurve(kind, percent, weight)
        if curve then
            local fn
            if kind == "health" then fn = UnitHealthPercent else fn = UnitPowerPercent end
            if type(fn) == "function" then
                local ok, result
                if kind == "health" then ok, result = pcall(fn, "player", false, curve)
                else ok, result = pcall(fn, "player", RestingPower(), false, curve) end
                if ok and result ~= nil then alpha = result
                elseif not ok then ns.Report("player " .. kind, result) end
            else ns.Report("player " .. kind, "Percentage API missing") end
        end
    end
    if Faders.samplingPower then
        Faders.thresholdSampleCount = Faders.thresholdSampleCount + 1
        thresholdWeights[Faders.thresholdSampleCount] = weight
        thresholdAlphas[Faders.thresholdSampleCount] = alpha
    end
    return alpha
end
Faders.EvalPlayerThresholds = EvalPlayerThresholds

local function PlayerUsesThresholds()
    if ns.PlayerStyle() ~= "classic" then return false end
    local kind, percent = ReadThreshold()
    return percent ~= nil and (kind == "health" or RestingPower() ~= nil)
end
Faders.PlayerUsesThresholds = PlayerUsesThresholds
