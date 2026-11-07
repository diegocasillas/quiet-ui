local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------
function ns.RestoreAlpha()
    for _, frame in ipairs(Core.hooked) do
        frame._quietAlpha = nil
        frame._quietSecret = nil
        frame._quietApplying = true
        frame:SetAlpha(Core.savedAlpha[frame] or 1)
        frame._quietApplying = false
    end
    for tex, alpha in pairs(Core.textureAlpha) do
        tex._quietApplying = true
        tex:SetAlpha(alpha or 1)
        tex._quietApplying = false
    end
end
