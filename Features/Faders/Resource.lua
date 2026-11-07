local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

local function PaintNumeric(frame, show, elapsed)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) then return end
    ns.EaseAlpha(frame, show, elapsed)
end
Faders.PaintNumeric = PaintNumeric

local function HoldResult(frame, alpha)
    if type(alpha) == "number" and not ns.IsSecret(alpha) then
        ns.HoldAlpha(frame, alpha)
    else
        ns.HoldSecretAlpha(frame, alpha)
    end
end

local function PaintSecret(frame, alpha)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) or alpha == nil then return end
    HoldResult(frame, alpha)
end
Faders.PaintSecret = PaintSecret

local function HealthPart(frame)
    local health = frame.HealthBarsContainer
    if ns.Usable(health) and health.SetAlpha then return health end
end

local function KidsOf(frame)
    local kids = frame._quietKids
    if kids then return kids end
    kids = {}
    frame._quietKids = kids
    if not frame.GetChildren then return kids end
    for _, child in ipairs({ frame:GetChildren() }) do
        kids[#kids + 1] = child
    end
    return kids
end
Faders.KidsOf = KidsOf

-- Two secret alphas cannot be merged, so the health part follows missing
-- health and every other child follows low power. The frame itself stays at 1.
local function PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    if not (Faders.IsFadeable(frame) and frame:IsShown()) then return end
    local health = HealthPart(frame)
    local kids = KidsOf(frame)
    if not health or #kids == 0 then
        if powerAlpha ~= nil then
            PaintSecret(frame, powerAlpha)
        else
            PaintNumeric(frame, show, elapsed)
        end
        return
    end
    if frame._quietAlpha ~= 1 or frame._quietSecret ~= nil then
        ns.HoldAlpha(frame, 1)
    end
    for i = 1, #kids do
        local child = kids[i]
        if ns.Usable(child) and child.SetAlpha then
            if child == health then
                HoldResult(child, healthAlpha)
            elseif powerAlpha ~= nil then
                HoldResult(child, powerAlpha)
            else
                ns.EaseAlpha(child, show, elapsed)
            end
        end
    end
end

local function UpdateResource(elapsed)
    if ns.OnlyOnHover("resource") then
        local hovered = Faders.HoverFrames("resource", Faders.resourceFrames)
        for _, frame in ipairs(Faders.resourceFrames) do
            if ns.Hit(frame) then hovered = true; break end
            for _, child in ipairs(KidsOf(frame)) do
                if ns.Usable(child) and ns.Hit(child) then hovered = true; break end
            end
        end
        local show = ns.VisibilityShow("resource", false, hovered)
        Faders.resourceWeight = show and 1 or 0
        for _, frame in ipairs(Faders.resourceFrames) do
            if Faders.IsFadeable(frame) and frame:IsShown() then
                local kids = KidsOf(frame)
                if #kids == 0 then PaintNumeric(frame, show, elapsed)
                else ns.HoldAlpha(frame, 1) end
                for _, child in ipairs(kids) do
                    if Faders.IsFadeable(child) then ns.EaseAlpha(child, show, elapsed) end
                end
            end
        end
        return
    end
    Faders.ParkHover("resource")
    local show = Faders.ResourceForced() and true or false
    Faders.resourceWeight = Faders.NextWeight(Faders.resourceWeight, show, elapsed)
    local powerAlpha = Faders.EvalPower(Faders.resourceWeight)
    local healthAlpha = Faders.EvalHealth(Faders.resourceWeight)
    for _, frame in ipairs(Faders.resourceFrames) do
        PaintResource(frame, show, elapsed, powerAlpha, healthAlpha)
    end
end
Faders.UpdateResource = UpdateResource
