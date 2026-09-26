local _, ns = ...

-- Shared helpers: saved variables, messages, and the alpha machinery that
-- keeps a wanted alpha even when Blizzard code overwrites it.

local FADE_OUT = 0.3
local PREFIX = "|cff8fd4c8QuietUI|r: "

local hooked = {}
local savedAlpha = {}
local textureAlpha = {}
local reported = {}

function ns.DB()
    if type(QuietUIDB) ~= "table" then
        QuietUIDB = {}
    end
    if QuietUIDB.enabled == nil then
        QuietUIDB.enabled = true
    end
    return QuietUIDB
end

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

function ns.Report(name, err)
    if reported[name] then return end
    reported[name] = true
    print(PREFIX .. name .. " error (shown once): " .. tostring(err))
end

-- Forbidden frames throw on almost any method call from addon code.
function ns.Usable(frame)
    if type(frame) ~= "table" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

-- Secret values (this client hides unit power even out of combat) cannot be
-- compared or used in arithmetic, only passed on to widgets.
function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

function ns.FrameName(frame)
    if ns.Usable(frame) and frame.GetName then
        return frame:GetName()
    end
end

function ns.MouseOver(frame)
    if not frame or not frame.IsShown or not frame.IsMouseOver then return false end
    if not frame:IsShown() then return false end
    return frame:IsMouseOver() and true or false
end

------------------------------------------------------------------------------
-- Frame alpha
------------------------------------------------------------------------------
function ns.Remember(frame)
    if not frame or savedAlpha[frame] then return end
    local alpha = frame.GetAlpha and frame:GetAlpha()
    if ns.IsSecret(alpha) or type(alpha) ~= "number" then alpha = 1 end
    savedAlpha[frame] = alpha
end

function ns.EnsureAlphaHook(frame)
    if not frame or frame._quietAlphaHook or not frame.SetAlpha then return end
    frame._quietAlphaHook = true
    hooked[#hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._quietApplying then return end
        if not ns.DB().enabled then return end
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

function ns.PushAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
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
    ns.PushAlpha(frame, alpha)
end

-- Old globals can alias new frames (MainMenuBar may be MainActionBar), so a
-- frame fades at most once per tick or it would fade twice as fast.
local fadeTick = 0

function ns.NextFadeTick()
    fadeTick = fadeTick + 1
end

function ns.UpdateFaded(frame, show, elapsed)
    if frame._quietTick == fadeTick then return end
    frame._quietTick = fadeTick
    ns.Remember(frame)
    ns.EnsureAlphaHook(frame)
    local target = show and 1 or 0
    local current = frame._quietAlpha
    if type(current) ~= "number" then
        current = CurrentAlpha(frame) or target
    end
    local nextAlpha = target
    if target < current then
        local step = (elapsed or 0) / FADE_OUT
        if current - target > step then
            nextAlpha = current - step
        end
    end
    ns.PushAlpha(frame, nextAlpha)
end

------------------------------------------------------------------------------
-- Textures
------------------------------------------------------------------------------
function ns.ForceTextureHidden(tex)
    if not tex or not tex.SetAlpha or not tex.GetAlpha then return end
    if tex.GetObjectType and tex:GetObjectType() ~= "Texture" then return end
    if textureAlpha[tex] == nil then
        textureAlpha[tex] = tex:GetAlpha()
    end
    if not tex._quietTexHook then
        tex._quietTexHook = true
        pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
            if self._quietApplying or not ns.DB().enabled then return end
            if (alpha or 0) < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    if not ns.DB().enabled then return end
    if tex:GetAlpha() >= 0.01 then
        tex._quietApplying = true
        tex:SetAlpha(0)
        tex._quietApplying = false
    end
end

function ns.HideTextures(frame)
    if not frame or not frame.GetNumRegions then return end
    for i = 1, frame:GetNumRegions() do
        ns.ForceTextureHidden(select(i, frame:GetRegions()))
    end
end

-- Hides a texture, or every texture region of a frame.
function ns.HideBackground(background)
    if not background then return end
    if background.GetObjectType and background:GetObjectType() == "Texture" then
        ns.ForceTextureHidden(background)
    else
        ns.HideTextures(background)
    end
end

------------------------------------------------------------------------------
-- Restore
------------------------------------------------------------------------------
function ns.RestoreAlpha()
    for _, frame in ipairs(hooked) do
        frame._quietAlpha = nil
        frame._quietSecret = nil
        frame._quietApplying = true
        frame:SetAlpha(savedAlpha[frame] or 1)
        frame._quietApplying = false
    end
    for tex, alpha in pairs(textureAlpha) do
        tex._quietApplying = true
        tex:SetAlpha(alpha or 1)
        tex._quietApplying = false
    end
end
