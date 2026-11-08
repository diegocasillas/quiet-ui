local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------
function ns.RestoreAlpha()
    for _, frame in ipairs(Core.hooked) do
        frame._cineAlpha = nil
        frame._cineSecret = nil
        frame._cineApplying = true
        frame:SetAlpha(Core.savedAlpha[frame] or 1)
        frame._cineApplying = false
    end
    for tex, alpha in pairs(Core.textureAlpha) do
        tex._cineApplying = true
        tex:SetAlpha(alpha or 1)
        tex._cineApplying = false
    end
end
