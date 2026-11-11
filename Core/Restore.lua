local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------
function ns.RestoreAlpha()
    for _, frame in ipairs(Core.hooked) do
        frame._puroCineAlpha = nil
        frame._puroCineSecret = nil
        frame._puroCineApplying = true
        frame:SetAlpha(Core.savedAlpha[frame] or 1)
        frame._puroCineApplying = false
    end
    for tex, alpha in pairs(Core.textureAlpha) do
        tex._puroCineApplying = true
        tex:SetAlpha(alpha or 1)
        tex._puroCineApplying = false
    end
end
