local _, ns = ...

-- Action bars. Alpha only: Hide(), Show() and state drivers are off limits.

local BUTTON_PREFIX = {
    MainMenuBar = "ActionButton",
    MainActionBar = "ActionButton",
    MultiBarBottomLeft = "MultiBarBottomLeftButton",
    MultiBarBottomRight = "MultiBarBottomRightButton",
    MultiBarRight = "MultiBarRightButton",
    MultiBarLeft = "MultiBarLeftButton",
    MultiBar5 = "MultiBar5Button",
    MultiBar6 = "MultiBar6Button",
    MultiBar7 = "MultiBar7Button",
    StanceBar = "StanceButton",
    StanceBarFrame = "StanceButton",
    ShapeshiftBarFrame = "ShapeshiftButton",
    PetActionBar = "PetActionButton",
    PetActionBarFrame = "PetActionButton",
}

local MAIN_BAR = {
    MainMenuBar = true,
    MainActionBar = true,
}

-- Buttons sit several levels deep and outside the root's rect.
local DEEP_HOVER = {
    GamepadMainActionBarFrame = true,
}

-- Orphan classic art. Children of a bar already follow that bar's alpha.
local BAR_ART = {
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarPageNumber",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarArtFrame",
}

-- Returns fn()'s result, or false when the API is missing or throws.
local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result and true or false
end

function ns.InEditMode()
    local frame = EditModeManagerFrame
    return frame and frame.IsShown and frame:IsShown() and true or false
end

function ns.InGroup()
    if type(IsInGroup) ~= "function" then return false end
    return Safe(IsInGroup)
end

function ns.InForcedInstance()
    if type(IsInInstance) ~= "function" then return false end
    return Safe(function()
        local inInstance, kind = IsInInstance()
        return inInstance and (
            kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
        )
    end)
end

local function InVehicle()
    if type(UnitHasVehicleUI) ~= "function" then return false end
    return Safe(UnitHasVehicleUI, "player")
end

local function CursorBusy()
    if type(GetCursorInfo) ~= "function" then return false end
    return Safe(function() return GetCursorInfo() ~= nil end)
end

local function FlyoutOpen()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end

-- Everything that fades is fully visible while this is true.
function ns.ShowAll()
    return InCombatLockdown() or ns.InEditMode() or InVehicle() or ns.InForcedInstance()
        or FlyoutOpen() or CursorBusy()
end

local function BarHovered(bar)
    if ns.MouseOver(bar) then return true end
    if DEEP_HOVER[ns.FrameName(bar) or ""] then
        return ns.TreeHas(bar, ns.MouseOver)
    end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            if ns.MouseOver(child) then return true end
        end
    end
    local prefix = BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            if ns.MouseOver(_G[prefix .. i]) then return true end
        end
    end
    return false
end

local function IsAncestor(frame, ancestor)
    local current = frame.GetParent and frame:GetParent()
    while current do
        if current == ancestor then return true end
        current = current.GetParent and current:GetParent()
    end
    return false
end

-- A bar that parents the bag slots stays visible while those slots are shown.
local function BarCoversBags(bar)
    if not ns.BagsShouldShow() then return false end
    local found = false
    ns.EachBagFrame(function(frame)
        if not found and frame ~= bar and IsAncestor(frame, bar) then
            found = true
        end
    end)
    return found
end

local function UpdateOneBar(bar, showAll, elapsed)
    if not bar:IsShown() then return end
    ns.UpdateFaded(bar, showAll or ns.Pinned("bars") or BarHovered(bar) or BarCoversBags(bar), elapsed)
end

local function FollowArt(alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = art.GetParent and art:GetParent()
            if not (parent and ns.IsBarFrame(parent)) then
                ns.HoldAlpha(art, alpha)
            end
        end
    end
end

function ns.UpdateBars(showAll, elapsed)
    local mainAlpha
    for _, name in ipairs(ns.BAR_NAMES) do
        local bar = _G[name]
        if bar then
            local ok, err = pcall(UpdateOneBar, bar, showAll, elapsed)
            if not ok then
                ns.Report("bar " .. name, err)
            elseif MAIN_BAR[name] then
                mainAlpha = bar._quietAlpha
            end
        end
    end
    if type(mainAlpha) == "number" then
        FollowArt(mainAlpha)
    end
end
