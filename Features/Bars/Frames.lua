local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

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
Bars.BUTTON_PREFIX = BUTTON_PREFIX

local MAIN_BAR = {
    MainMenuBar = true,
    MainActionBar = true,
}
Bars.MAIN_BAR = MAIN_BAR

-- Buttons sit several levels deep and outside the root's rect.
local DEEP_HOVER = {
    GamepadMainActionBarFrame = true,
    MultiCastActionBarFrame = true,
    TotemFrame = true,
}
Bars.DEEP_HOVER = DEEP_HOVER

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
Bars.BAR_ART = BAR_ART

local function Parent(frame)
    if not ns.Usable(frame) or not frame.GetParent then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok then return parent end
end
Bars.Parent = Parent

Bars.ancestorCache = {}
Bars.structureDirty = true
local parentHooked = setmetatable({}, { __mode = "k" })

local function WatchParent(frame)
    if not ns.Usable(frame) or parentHooked[frame] or type(frame.SetParent) ~= "function" then return end
    local ok = pcall(hooksecurefunc, frame, "SetParent", function()
        ns.ForgetBarButtons()
    end)
    if ok then parentHooked[frame] = true end
end
Bars.WatchParent = WatchParent

local function IsAncestor(frame, ancestor)
    local chain = Bars.ancestorCache[frame]
    if chain then return chain[ancestor] or false end
    chain = {}
    Bars.ancestorCache[frame] = chain
    WatchParent(frame)
    local current = Parent(frame)
    local depth = 0
    while current and depth < 8 do
        chain[current] = true
        WatchParent(current)
        current = Parent(current)
        depth = depth + 1
    end
    return chain[ancestor] or false
end
Bars.IsAncestor = IsAncestor
