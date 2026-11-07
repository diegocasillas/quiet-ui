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
    if not frame or frame._quietAlphaHook or not frame.SetAlpha then return end
    frame._quietAlphaHook = true
    Core.hooked[#Core.hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._quietApplying then return end
        if not ns.DB().enabled then return end
        if self._quietChat and ns.ModernChat and not ns.ModernChat() then return end
        local want = self._quietSecret
        if want == nil then
            want = self._quietAlpha
            if type(want) ~= "number" then return end
            if not ns.IsSecret(alpha) and math.abs((alpha or 0) - want) < 0.02 then return end
        end
        self._quietApplying = true
        self:SetAlpha(want)
        self._quietApplying = false
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
    if frame._quietSecret == nil and frame._quietAlpha == alpha then return end
    frame._quietAlpha = alpha
    frame._quietSecret = nil
    local current = CurrentAlpha(frame)
    if current and math.abs(current - alpha) < 0.01 then
        return
    end
    frame._quietApplying = true
    frame:SetAlpha(alpha)
    frame._quietApplying = false
end

-- Holds an alpha that may be secret; the fade is skipped since it cannot be read.
function ns.HoldSecretAlpha(frame, alpha)
    if not ns.Usable(frame) or not frame.SetAlpha then return end
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    frame._quietAlpha = nil
    frame._quietSecret = alpha
    frame._quietApplying = true
    frame:SetAlpha(alpha)
    frame._quietApplying = false
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
    frame._quietAlpha = nil
    frame._quietSecret = nil
    frame._quietApplying = true
    frame:SetAlpha(Core.savedAlpha[frame] or 1)
    frame._quietApplying = false
end

function ns.NoteChat(obj)
    if not obj or obj._quietChat then return end
    obj._quietChat = true
    Core.chatHeld[#Core.chatHeld + 1] = obj
end

function ns.ReleaseChatHold()
    for i = 1, #Core.chatHeld do
        local obj = Core.chatHeld[i]
        if obj.GetObjectType and obj:GetObjectType() == "Texture" then
            obj._quietApplying = true
            obj:SetAlpha(Core.textureAlpha[obj] or 1)
            obj._quietApplying = false
        else
            ns.ReleaseAlpha(obj)
        end
    end
end
