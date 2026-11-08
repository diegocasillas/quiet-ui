local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- A pet under the player frame inherits its alpha. While the portrait hides on
-- death the pet must ignore that parent alpha; a client that cannot do that keeps
-- the usual rules for both.
local function PetIsolatable(under, pet)
    return not under or type(pet.SetIgnoreParentAlpha) == "function"
end

-- Dead or ghost with the player frame on: it fades. A target, Glance and Edit Mode show it.
-- The dead flag is cached in the world state, so the usual case ends at the first test.
local function PlayerDead(under, pet)
    if not ns.PlayerIsDead() then return false end
    if ns.InEditMode() or ns.Glancing() or ns.HasTarget() or ns.PlayerStyle() ~= "classic" then return false end
    return PetIsolatable(under, pet)
end

local function IsolatePet(pet, on)
    if Faders.petIsolated == on or not pet then return end
    Faders.petIsolated = on
    if type(pet.SetIgnoreParentAlpha) == "function" then pet:SetIgnoreParentAlpha(on) end
    if not on and (pet._quietAlpha ~= nil or pet._quietSecret ~= nil) then ns.ReleaseAlpha(pet) end
end

-- Restore: the pet follows its parent's alpha again.
function Faders.RestorePet()
    if Faders.petIsolated then IsolatePet(PetFrame, false) end
end

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
    local under = Faders.Under(pet, player)
    local dead = PlayerDead(under, pet)
    local petOwn = dead or not under
    if under then IsolatePet(pet, dead) end
    if alpha ~= nil then
        if dead then Faders.PaintNumeric(player, false, elapsed) else Faders.PaintSecret(player, alpha) end
        if petOwn then Faders.PaintSecret(pet, alpha) end
    else
        Faders.PaintNumeric(player, show and not dead, elapsed)
        if petOwn then Faders.PaintNumeric(pet, show, elapsed) end
    end
end
Faders.UpdatePlayer = UpdatePlayer
