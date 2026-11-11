local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Cooldowns matter only when fighting or grouped, so hover does not count.
local function CooldownsShouldShow()
    return ns.InCombat() or ns.InForcedInstance() or ns.InGroup() or ns.InEditMode()
end
Faders.CooldownsShouldShow = CooldownsShouldShow

-- Aura buttons can sit outside their container's bounds, so children count too.
local function MouseOverAny(frame)
    if ns.Hit(frame) then return true end
    local kids = Faders.KidsOf(frame)
    for i = 1, #kids do
        if ns.Usable(kids[i]) and ns.Hit(kids[i]) then return true end
    end
    return false
end

local function AurasShouldShow()
    if ns.OnlyOnHover("auras") then
        local hovered = false
        for _, frame in ipairs(Faders.auraFrames) do
            if MouseOverAny(frame) then hovered = true; break end
        end
        return ns.VisibilityShow("auras", false, hovered)
    end
    local show = ns.InCombat() or ns.InForcedInstance() or (ns.InGroup() and ns.ShowPlayerFrameInParty()) or ns.InEditMode()
        or ns.Pinned("auras") or ns.Glancing()
    if not show and ns.GroupAuras() and Faders.PlayerShouldShow() then
        show = true
    end
    if not show then
        for _, frame in ipairs(Faders.auraFrames) do
            if MouseOverAny(frame) then
                show = true
                break
            end
        end
    end
    return show
end

local function UpdateAuras(elapsed)
    local usual = AurasShouldShow() and true or false
    -- A new buff shows the auras for a few seconds. Only on hover overrides it.
    local show = usual or (not ns.OnlyOnHover("auras") and ns.BuffPeek()) or false
    local useCurve = not ns.OnlyOnHover("auras") and ns.GroupAuras() and Faders.PlayerUsesThresholds()
    Faders.aurasCurved, Faders.auraWeight = Faders.TakeWeight(Faders.aurasCurved, Faders.auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and Faders.EvalPlayerThresholds(Faders.auraWeight) or nil
    Faders.UpdateIgnoredDebuffs(elapsed, usual)
    local keepDebuffs = not ns.OnlyOnHover("auras") and ns.AlwaysShowDebuffs()
    -- Dead or a ghost: the buffs fade out whatever else would show them. Hover,
    -- Glance and Edit Mode still show them; debuffs keep their own rules.
    local deadHide = ns.PlayerIsDead() and not ns.OnlyOnHover("auras") and not ns.Glancing() and not ns.InEditMode()
    for _, frame in ipairs(Faders.auraFrames) do
        if deadHide and frame ~= _G.DebuffFrame and not MouseOverAny(frame) then
            Faders.PaintNumeric(frame, false, elapsed)
        elseif keepDebuffs and frame == _G.DebuffFrame then
            if frame._puroCineSecret ~= nil or frame._puroCineAlpha ~= 1 then
                Faders.PaintNumeric(frame, true, elapsed)
            end
        elseif alpha ~= nil then
            Faders.PaintSecret(frame, alpha)
        else
            Faders.PaintNumeric(frame, show, elapsed)
        end
    end
end
Faders.UpdateAuras = UpdateAuras
