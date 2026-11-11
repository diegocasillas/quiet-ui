local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

------------------------------------------------------------------------------
-- Frame alpha
------------------------------------------------------------------------------
function ns.Remember(frame)
    if not frame or Core.savedAlpha[frame] then return end
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" then alpha = 1 end
    Core.savedAlpha[frame] = alpha
end

function ns.EnsureAlphaHook(frame)
    if not frame or frame._puroPuroCineAlphaHook or not frame.SetAlpha then return end
    frame._puroPuroCineAlphaHook = true
    Core.hooked[#Core.hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._puroPuroCineApplying then return end
        if not ns.DB().enabled then return end
        if self._puroPuroCineChat and ns.ModernChat and not ns.ModernChat() then return end
        local want = self._puroPuroCineSecret
        if want == nil then
            want = self._puroPuroCineAlpha
            if type(want) ~= "number" then return end
            if not ns.IsSecret(alpha) and math.abs((alpha or 0) - want) < 0.02 then return end
        end
        self._puroPuroCineApplying = true
        self:SetAlpha(want)
        self._puroPuroCineApplying = false
    end)
end

local function CurrentAlpha(frame)
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) then return nil end
    return alpha
end
Core.CurrentAlpha = CurrentAlpha

function ns.PushAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    -- The SetAlpha hook already puts back overwrites. Skip the read when nothing changed.
    if frame._puroPuroCineSecret == nil and frame._puroPuroCineAlpha == alpha then return end
    frame._puroPuroCineAlpha = alpha
    frame._puroPuroCineSecret = nil
    local current = CurrentAlpha(frame)
    if current and math.abs(current - alpha) < 0.01 then
        return
    end
    frame._puroPuroCineApplying = true
    frame:SetAlpha(alpha)
    frame._puroPuroCineApplying = false
end

-- Holds an alpha that may be secret; the fade is skipped since it cannot be read.
function ns.HoldSecretAlpha(frame, alpha)
    if not ns.Usable(frame) or not frame.SetAlpha then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    frame._puroPuroCineAlpha = nil
    frame._puroPuroCineSecret = alpha
    frame._puroPuroCineApplying = true
    frame:SetAlpha(alpha)
    frame._puroPuroCineApplying = false
end

-- Remember, hook, and set in one go.
function ns.HoldAlpha(frame, alpha)
    if not ns.Usable(frame) then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    if ns.MarkingChat then ns.NoteChat(frame) end
    ns.PushAlpha(frame, alpha)
end

function ns.ReleaseAlpha(frame)
    if not frame or not frame.SetAlpha then return end
    frame._puroPuroCineAlpha = nil
    frame._puroPuroCineSecret = nil
    frame._puroPuroCineApplying = true
    frame:SetAlpha(Core.savedAlpha[frame] or 1)
    frame._puroPuroCineApplying = false
end

function ns.NoteChat(obj)
    if not obj or obj._puroPuroCineChat then return end
    obj._puroPuroCineChat = true
    Core.chatHeld[#Core.chatHeld + 1] = obj
end

function ns.ReleaseChatHold()
    for i = 1, #Core.chatHeld do
        local obj = Core.chatHeld[i]
        if obj.GetObjectType and obj:GetObjectType() == "Texture" then
            obj._puroPuroCineApplying = true
            obj:SetAlpha(Core.textureAlpha[obj] or 1)
            obj._puroPuroCineApplying = false
        else
            ns.ReleaseAlpha(obj)
        end
    end
end
