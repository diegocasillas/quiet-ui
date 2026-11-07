local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

local function UpdatePlayer(elapsed)
    local show = Faders.PlayerShouldShow() and true or false
    if Faders.samplingPower then Faders.sampledPlayerShow = show end
    local blocked = Faders.DeadTargetBlocked()
    local useCurve = not blocked and Faders.PlayerUsesThresholds()
    Faders.playerCurved, Faders.playerWeight = Faders.TakeWeight(Faders.playerCurved, Faders.playerWeight, show, elapsed, useCurve)
    local alpha = useCurve and Faders.EvalPlayerThresholds(Faders.playerWeight) or nil
    local player = PlayerFrame
    local pet = PetFrame
    local target = TargetFrame
    if Faders.IsFadeable(target) then
        if blocked then
            ns.EaseAlpha(target, false, elapsed)
        elseif target._quietAlpha ~= nil or target._quietSecret ~= nil then
            ns.ReleaseAlpha(target)
        end
    end
    if alpha ~= nil then
        Faders.PaintSecret(player, alpha)
        if not Faders.Under(pet, player) then Faders.PaintSecret(pet, alpha) end
    else
        Faders.PaintNumeric(player, show, elapsed)
        if not Faders.Under(pet, player) then Faders.PaintNumeric(pet, show, elapsed) end
    end
end
Faders.UpdatePlayer = UpdatePlayer
