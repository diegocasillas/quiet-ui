local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Catch hover even when Blizzard's container is not mouse-enabled.
local hoverCatchers = {}

local function ParkHover(name)
    local catchers = hoverCatchers[name]
    if not catchers or catchers.parked then return end
    for i = 1, #catchers do
        local box = catchers[i]
        if box:IsShown() then box:Hide() end
    end
    catchers.parked = true
end
Faders.ParkHover = ParkHover

local function HoverFrames(name, frames, active)
    local catchers = hoverCatchers[name]
    if not catchers then catchers = {}; hoverCatchers[name] = catchers end
    if active == nil then active = ns.OnlyOnHover(name) end
    if not active then
        ParkHover(name)
        return false
    end
    catchers.parked = nil
    local hovered = false
    for i, target in ipairs(frames) do
        local box = catchers[i]
        if ns.DB().enabled and not ns.InEditMode()
            and ns.Usable(target) and target:IsShown() then
            if not box then
                local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
                if ok and created then
                    box = created
                    catchers[i] = box
                    ns.ArmCatcher(box)
                end
            end
            if box then
                if box._puroPuroCineHoverTarget ~= target then
                    box:ClearAllPoints()
                    box:SetAllPoints(target)
                    box._puroPuroCineHoverTarget = target
                end
                local strata = target.GetFrameStrata and target:GetFrameStrata()
                if type(strata) == "string" and not ns.IsSecret(strata) and box._puroPuroCineStrata ~= strata then
                    box:SetFrameStrata(strata)
                    box._puroPuroCineStrata = strata
                end
                local level = target.GetFrameLevel and target:GetFrameLevel() or 1
                if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
                level = math.max(0, level - 1)
                if box._puroPuroCineLevel ~= level then
                    box:SetFrameLevel(level)
                    box._puroPuroCineLevel = level
                end
                if not box:IsShown() then box:Show() end
                if ns.Hit(box) then hovered = true end
            end
            if ns.Hit(target) then hovered = true end
        elseif box then box:Hide() end
    end
    for i = #frames + 1, #catchers do catchers[i]:Hide() end
    return hovered
end
Faders.HoverFrames = HoverFrames

function ns.HideHoverCatchers()
    for _, catchers in pairs(hoverCatchers) do
        for _, box in ipairs(catchers) do box:Hide() end
    end
end

-- A group shows together when any shown member is hovered.
local function UpdateGroup(frames, show, elapsed, noHover)
    if not show and not noHover then
        for _, frame in ipairs(frames) do
            if ns.Hit(frame) then
                show = true
                break
            end
        end
    end
    for _, frame in ipairs(frames) do
        if frame:IsShown() then
            ns.UpdateFaded(frame, show, elapsed)
        end
    end
end

-- A child already follows its parent alpha. Fading it again would compound.
local function Under(frame, ancestor)
    if not frame or not frame.GetParent or not ancestor then return false end
    local parent = frame:GetParent()
    local depth = 0
    while parent and depth < 6 do
        if parent == ancestor then return true end
        if not parent.GetParent then return false end
        parent = parent:GetParent()
        depth = depth + 1
    end
    return false
end
Faders.Under = Under

function ns.UpdateFaders(elapsed)
    local glance = ns.Glancing()
    local function UpdateVisible(name, frames, usual, noHover, exception)
        local hovered = HoverFrames(name, frames)
        if ns.OnlyOnHover(name) then
            UpdateGroup(frames, usual or ns.InEditMode() or exception or hovered or ns.FullGlancing(), elapsed)
        else
            UpdateGroup(frames, usual or ns.Pinned(name) or glance, elapsed, noHover)
        end
    end
    Faders.Run("xp bar", UpdateVisible, "xp", Faders.statusFrames, Faders.XPShouldShow(), false, ns.XPForced())
    Faders.Run("cooldown manager", UpdateVisible, "cooldowns", Faders.cooldownFrames, Faders.CooldownsShouldShow(), true)
    Faders.Run("damage meter", UpdateVisible, "meter", Faders.meterFrames, Faders.MeterShouldShow())
    Faders.Run("quest catcher", Faders.PlaceQuestCatcher)
    local questHot = Faders.questCatcher and ns.Hit(Faders.questCatcher)
    Faders.Run("quest tracker", UpdateGroup, Faders.questFrames, ns.VisibilityShow("quests", false, questHot), elapsed)
end
