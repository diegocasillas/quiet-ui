local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

-- Empty slots are not mouse frames. The catcher is not a child of the bar:
-- a faded parent would drop the mouse. Clicks stay off so spells keep them.
local catchers = {}
local catcherSeen = {}

local function HideCatchers()
    for _, box in pairs(catchers) do
        box:Hide()
    end
end
Bars.HideCatchers = HideCatchers

function ns.HideBarCatchers()
    HideCatchers()
end

local function EnsureCatcher(bar)
    local box = catchers[bar]
    if box then return box end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:SetAlpha(1)
    created:Hide()
    catchers[bar] = created
    return created
end

local function MatchLevel(box, bar)
    local strata = bar.GetFrameStrata and bar:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = bar.GetFrameLevel and bar:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
end

-- MainMenuBar's own rect is wider than its slots when it hosts other bars.
local function SlotCorner(bar)
    local prefix = Bars.BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if not prefix then return end
    local tl, br, tlTop, tlLeft, brBottom, brRight
    for i = 1, 12 do
        local button = _G[prefix .. i]
        if ns.Usable(button) and button.GetLeft then
            local left, right = button:GetLeft(), button.GetRight and button:GetRight()
            local top, bottom = button.GetTop and button:GetTop(), button.GetBottom and button:GetBottom()
            if left and right and top and bottom then
                if not tl or top > tlTop or (top == tlTop and left < tlLeft) then
                    tl, tlTop, tlLeft = button, top, left
                end
                if not br or bottom < brBottom or (bottom == brBottom and right > brRight) then
                    br, brBottom, brRight = button, bottom, right
                end
            end
        end
    end
    if tl and br then return tl, br end
end

local function PlaceCatcher(bar)
    local box = EnsureCatcher(bar)
    if not box then return end
    local slotted = ns.FrameName(bar) == "MainMenuBar" and Bars.HostsOther(bar)
    if slotted then
        local tl, br = SlotCorner(bar)
        if not tl then
            box:Hide()
            box._quietSpan = nil
            return
        end
        if box._quietSlotA ~= tl or box._quietSlotB ~= br then
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", tl, "TOPLEFT")
            box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
            box._quietSlotA, box._quietSlotB = tl, br
        end
        box._quietSpan = "slots"
    elseif box._quietSpan ~= bar then
        box:ClearAllPoints()
        box:SetAllPoints(bar)
        box._quietSpan = bar
        box._quietSlotA, box._quietSlotB = nil, nil
    end
    MatchLevel(box, bar)
    if not box:IsShown() then box:Show() end
end

local function SyncCatchers()
    for bar in pairs(catcherSeen) do
        catcherSeen[bar] = nil
    end
    for _, entry in ipairs(Bars.resolved) do
        for _, bar in ipairs(entry.frames) do
            if ns.Usable(bar) and bar.IsShown and bar:IsShown() then
                PlaceCatcher(bar)
                catcherSeen[bar] = true
            end
        end
    end
    for bar, box in pairs(catchers) do
        if not catcherSeen[bar] then
            box:Hide()
        end
    end
end
Bars.SyncCatchers = SyncCatchers

local function CatcherHit(bar)
    local box = catchers[bar]
    return box and ns.Hit(box) and true or false
end

-- The bar rectangle, plus buttons that sit outside it on the gamepad and totem bars.
local function DirectHot(bar)
    if CatcherHit(bar) then return true end
    if Bars.ButtonsHovered(bar) then return true end
    return ns.Hit(bar)
end

-- Hover on a nested bar belongs to that bar, not the frame behind it.
local function OverNested(bar)
    local nested = Bars.hosts[bar]
    if not nested then return false end
    for i = 1, #nested do
        if DirectHot(nested[i]) then return true end
    end
    return false
end

local function BarHovered(bar)
    if OverNested(bar) then return false end
    return DirectHot(bar)
end
Bars.BarHovered = BarHovered

-- A bar that parents the bag slots stays visible while those slots are shown.
local function BarCoversBags(bar)
    if not ns.BagsShouldShow() then return false end
    local found = false
    ns.EachBagFrame(function(frame)
        if not found and frame ~= bar and Bars.IsAncestor(frame, bar) then
            found = true
        end
    end)
    return found
end
Bars.BarCoversBags = BarCoversBags

local function FollowArt(alpha)
    for _, name in ipairs(Bars.BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = Bars.Parent(art)
            if not (parent and ns.IsBarFrame(parent)) then
                ns.HoldAlpha(art, alpha)
            end
        end
    end
end
Bars.FollowArt = FollowArt
