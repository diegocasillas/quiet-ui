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
    local show = AurasShouldShow() and true or false
    local useCurve = not ns.OnlyOnHover("auras") and ns.GroupAuras() and Faders.PlayerUsesThresholds()
    Faders.aurasCurved, Faders.auraWeight = Faders.TakeWeight(Faders.aurasCurved, Faders.auraWeight, show, elapsed, useCurve)
    local alpha = useCurve and Faders.EvalPlayerThresholds(Faders.auraWeight) or nil
    local keepDebuffs = not ns.OnlyOnHover("auras") and ns.AlwaysShowDebuffs()
    for _, frame in ipairs(Faders.auraFrames) do
        if keepDebuffs and frame == _G.DebuffFrame then
            if frame._quietSecret ~= nil or frame._quietAlpha ~= 1 then
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
