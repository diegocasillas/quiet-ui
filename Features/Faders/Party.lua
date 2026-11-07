local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

local function UpdateParty(elapsed)
    local hovered = false
    for _, frame in ipairs(Faders.partyFrames) do
        if ns.Hit(frame) then hovered = true; break end
    end
    local show = ns.VisibilityShow("party", Faders.PartyShouldShow(), hovered)
    for _, frame in ipairs(Faders.partyFrames) do
        if Faders.IsFadeable(frame) and frame:IsShown() then
            ns.EaseAlpha(frame, show, elapsed)
        end
    end
end
Faders.UpdateParty = UpdateParty

local function UpdateRaidManager(elapsed)
    local hovered = false

    if ns.Hit(CompactRaidFrameManager) then hovered = true end
    
    local show = ns.VisibilityShow("raid manager", Faders.RaidManagerShouldShow(), hovered)
    if Faders.IsFadeable(CompactRaidFrameManager) and CompactRaidFrameManager:IsShown() then
        ns.EaseAlpha(CompactRaidFrameManager, show, elapsed)
    end
end
Faders.UpdateRaidManager = UpdateRaidManager
