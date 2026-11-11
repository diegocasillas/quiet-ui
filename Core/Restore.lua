local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------
function ns.RestoreAlpha()
    for _, frame in ipairs(Core.hooked) do
        frame._puroPuroCineAlpha = nil
        frame._puroPuroCineSecret = nil
        frame._puroPuroCineApplying = true
        frame:SetAlpha(Core.savedAlpha[frame] or 1)
        frame._puroPuroCineApplying = false
    end
    for tex, alpha in pairs(Core.textureAlpha) do
        tex._puroPuroCineApplying = true
        tex:SetAlpha(alpha or 1)
        tex._puroPuroCineApplying = false
    end
end
