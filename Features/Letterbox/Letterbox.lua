local _, ns = ...
local Letterbox = ns.Letterbox or {}
ns.Letterbox = Letterbox

-- Black bars at the top and bottom of the screen. At full size each bar is half
-- of what a 2.39:1 frame leaves over; in combat or while Glance is on they shrink to half of that.
-- They sit under the UI (BACKGROUND strata), so frames draw over them.
local ASPECT = 2.39
local CALM, COMBAT = 1, 0.5
local SLIDE_TIME = 0.6 -- seconds for a full slide

local level = 0 -- 0 hidden, 1 full size; the bar height is eased from it

local function Build()
    if Letterbox.frame then return Letterbox.frame end
    if type(CreateFrame) ~= "function" or not UIParent then return nil end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("BACKGROUND")
    frame:SetFrameLevel(0)
    frame:EnableMouse(false)
    frame.top = frame:CreateTexture(nil, "BACKGROUND")
    frame.top:SetColorTexture(0, 0, 0, 1)
    frame.top:SetPoint("TOPLEFT")
    frame.top:SetPoint("TOPRIGHT")
    frame.bottom = frame:CreateTexture(nil, "BACKGROUND")
    frame.bottom:SetColorTexture(0, 0, 0, 1)
    frame.bottom:SetPoint("BOTTOMLEFT")
    frame.bottom:SetPoint("BOTTOMRIGHT")
    frame:Hide()
    Letterbox.frame = frame
    return frame
end

-- Full bar height for the screen's shape; 0 on a screen already wider than 2.39:1.
local function FullHeight()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not width or not height or width <= 0 or height <= 0 then return 0 end
    return math.max(0, (height - width / ASPECT) / 2) / 2
end

local function Draw(frame)
    local eased = level * level * (3 - 2 * level)
    local bar = math.max(FullHeight() * eased, 0.01)
    frame.top:SetHeight(bar)
    frame.bottom:SetHeight(bar)
end

local function Target()
    if not Letterbox.wanted then return 0 end
    return (ns.InCombat() or ns.Glancing()) and COMBAT or CALM
end

local function OnUpdate(frame, elapsed)
    local target = Target()
    if level ~= target then
        local step = (elapsed or 0) / SLIDE_TIME
        if level < target then level = math.min(target, level + step)
        else level = math.max(target, level - step) end
    end
    Draw(frame)
    if level == 0 and target == 0 then frame:Hide() end
end

function Letterbox.Wanted()
    return (ns.Settings and ns.Settings() or ns.CharDB()).letterbox == true
end

function Letterbox.Apply()
    if not ns.DB().enabled or not Letterbox.Wanted() then
        Letterbox.Restore()
        return
    end
    local frame = Build()
    if not frame then return end
    Letterbox.wanted = true
    if not Letterbox.scripted then
        Letterbox.scripted = true
        frame:SetScript("OnUpdate", OnUpdate)
    end
    Draw(frame)
    frame:Show()
end

-- Slides out, then hides.
function Letterbox.Restore()
    Letterbox.wanted = false
    local frame = Letterbox.frame
    if frame and frame:IsShown() and level > 0 then return end
    if frame then frame:Hide() end
end

ns.ApplyLetterbox = Letterbox.Apply
ns.RestoreLetterbox = Letterbox.Restore
