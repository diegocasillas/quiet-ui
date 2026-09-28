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

-- Same number fades together. Missing saved values use group.
-- Gamepad follows bar 1 and has no setup row.
ns.BAR_ROWS = {
    { id = "1", label = "Bar 1", group = 1, names = { "MainMenuBar", "MainActionBar", "GamepadMainActionBarFrame" } },
    { id = "2", label = "Bar 2", group = 1, names = { "MultiBarBottomLeft" } },
    { id = "3", label = "Bar 3", group = 1, names = { "MultiBarBottomRight" } },
    { id = "4", label = "Bar 4", group = 2, names = { "MultiBarRight" } },
    { id = "5", label = "Bar 5", group = 2, names = { "MultiBarLeft" } },
    { id = "6", label = "Bar 6", group = 3, names = { "MultiBar5" } },
    { id = "7", label = "Bar 7", group = 4, names = { "MultiBar6" } },
    { id = "8", label = "Bar 8", group = 5, names = { "MultiBar7" } },
    { id = "stance", label = "Stance bar", group = 1, names = { "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame" } },
    { id = "pet", label = "Pet bar", group = 1, names = { "PetActionBar", "PetActionBarFrame" } },
}

function ns.BarGroup(id)
    local fallback = 1
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id == id then
            fallback = row.group
            break
        end
    end
    if type(ns.CharDB) ~= "function" then return fallback end
    local groups = ns.CharDB().groups
    local n = type(groups) == "table" and groups[id]
    if type(n) ~= "number" or n ~= n then return fallback end
    n = math.floor(n)
    if n < 1 or n > #ns.BAR_ROWS then return fallback end
    return n
end

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

-- Combat, a vehicle and an instance do not count. Hover, a quest turn-in and
-- a pinned row are decided in the fader.
function ns.XPForced()
    return ns.InEditMode() or FlyoutOpen() or CursorBusy()
end

-- Action bars and the damage meter are fully visible while this is true.
function ns.ShowAll()
    return InCombatLockdown() or ns.InEditMode() or InVehicle() or ns.InForcedInstance()
        or FlyoutOpen() or CursorBusy()
end

local function Parent(frame)
    if not ns.Usable(frame) or not frame.GetParent then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok then return parent end
end

local function IsAncestor(frame, ancestor)
    local current = Parent(frame)
    local depth = 0
    while current and depth < 8 do
        if current == ancestor then return true end
        current = Parent(current)
        depth = depth + 1
    end
    return false
end

-- frame -> bar id, rebuilt each tick. A bar that parents another stays at
-- alpha 1 or the child would fade with it.
local owner = {}
local resolved = {}
local held = {}
local seenHeld = {}

local function Clear(map)
    for key in pairs(map) do
        map[key] = nil
    end
end

local function UnderOther(frame, bar)
    for other in pairs(owner) do
        if other ~= bar and IsAncestor(frame, other) then
            return true
        end
    end
    return false
end

local function HostsOther(bar)
    for other in pairs(owner) do
        if other ~= bar and owner[other] ~= owner[bar] and IsAncestor(other, bar) then
            return true
        end
    end
    return false
end

local function LeaveAlone(frame)
    if ns.IsBagRelated(frame) then return true end
    local name = ns.FrameName(frame)
    return name ~= nil and name:find("Micro") ~= nil
end

local function EachOwnButton(bar, fn)
    local seen = {}
    local function consider(button)
        if not ns.Usable(button) or seen[button] or LeaveAlone(button) or UnderOther(button, bar) then return end
        seen[button] = true
        fn(button)
    end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            consider(child)
        end
    end
    local prefix = BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            consider(_G[prefix .. i])
        end
    end
end

local function IsPressable(frame)
    if not ns.Usable(frame) or not frame.GetObjectType then return false end
    local ok, kind = pcall(frame.GetObjectType, frame)
    return ok and (kind == "Button" or kind == "CheckButton")
end

local function EachDeepButton(bar, fn, depth)
    depth = depth or 0
    if depth > 4 or not ns.Usable(bar) or not bar.GetChildren then return end
    for _, child in ipairs({ bar:GetChildren() }) do
        if ns.Usable(child) and not owner[child] and not LeaveAlone(child) then
            if IsPressable(child) then
                if not UnderOther(child, bar) then
                    fn(child)
                end
            else
                EachDeepButton(child, fn, depth + 1)
            end
        end
    end
end

local function ButtonsHovered(bar)
    local hit = false
    EachOwnButton(bar, function(button)
        if not hit and ns.MouseOver(button) then
            hit = true
        end
    end)
    if hit then return true end
    if not DEEP_HOVER[ns.FrameName(bar) or ""] then return false end
    EachDeepButton(bar, function(button)
        if not hit and ns.MouseOver(button) then
            hit = true
        end
    end)
    return hit
end

-- Hover on a nested bar belongs to that bar, not the frame behind it.
local function OverNested(bar)
    for other in pairs(owner) do
        if other ~= bar and owner[other] ~= owner[bar] and IsAncestor(other, bar) then
            if ns.MouseOver(other) or ButtonsHovered(other) then
                return true
            end
        end
    end
    return false
end

local function BarHovered(bar)
    if ButtonsHovered(bar) then return true end
    if OverNested(bar) then return false end
    return ns.MouseOver(bar)
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

local function FollowArt(alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = Parent(art)
            if not (parent and ns.IsBarFrame(parent)) then
                ns.HoldAlpha(art, alpha)
            end
        end
    end
end

local function Collect()
    Clear(owner)
    for index, row in ipairs(ns.BAR_ROWS) do
        local entry = resolved[index]
        if not entry then
            entry = { frames = {} }
            resolved[index] = entry
        end
        entry.id = row.id
        local frames = entry.frames
        local count = 0
        local seen = {}
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if bar and not seen[bar] then
                seen[bar] = true
                count = count + 1
                frames[count] = bar
            end
        end
        for extra = count + 1, #frames do
            frames[extra] = nil
        end
        for _, bar in ipairs(frames) do
            owner[bar] = row.id
        end
    end
end

-- The outer frame of the same bar already carries the alpha.
local function CoveredBySameBar(bar)
    local id = owner[bar]
    for other, otherId in pairs(owner) do
        if other ~= bar and otherId == id and IsAncestor(bar, other) and not HostsOther(other) then
            return true
        end
    end
    return false
end

local function Watch(frame)
    seenHeld[frame] = true
    held[frame] = true
end

-- Shown buttons are released so range fading can set their alpha.
local function FadeButton(button, show, elapsed)
    if not button.IsShown or not button:IsShown() then return end
    if show then
        if held[button] then
            ns.ReleaseAlpha(button)
            held[button] = nil
        end
        return 1
    end
    if button._quietAlpha ~= nil and not held[button] then return end
    Watch(button)
    ns.UpdateFaded(button, false, elapsed)
    return button._quietAlpha
end

-- Parent stays at full alpha so a nested bar can keep its own.
local function FadeHosted(bar, show, elapsed)
    ns.HoldAlpha(bar, 1)
    local alpha
    local function take(frame)
        local nextAlpha = FadeButton(frame, show, elapsed)
        if type(nextAlpha) == "number" then
            alpha = nextAlpha
        end
    end
    EachOwnButton(bar, take)
    EachDeepButton(bar, take)
    if type(alpha) == "number" and bar.GetRegions then
        for _, region in ipairs({ bar:GetRegions() }) do
            if region and region.SetAlpha and region.GetObjectType then
                local ok, kind = pcall(region.GetObjectType, region)
                if ok and kind == "Texture" then
                    Watch(region)
                    ns.HoldAlpha(region, alpha)
                end
            end
        end
    end
    return alpha
end

-- Deeper art follows the child frame. Only art parented to the bar itself needs a hold.
local function FadeChildArt(bar, alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha and Parent(art) == bar then
            Watch(art)
            ns.HoldAlpha(art, alpha)
        end
    end
end

local function ApplyBar(bar, show, elapsed)
    if CoveredBySameBar(bar) then
        if bar._quietAlpha ~= nil then
            ns.ReleaseAlpha(bar)
        end
        return
    end
    local name = ns.FrameName(bar) or ""
    local alpha
    if HostsOther(bar) then
        alpha = FadeHosted(bar, show, elapsed)
        if MAIN_BAR[name] and type(alpha) == "number" then
            FadeChildArt(bar, alpha)
        end
    else
        ns.UpdateFaded(bar, show, elapsed)
        alpha = bar._quietAlpha
    end
    return name, alpha
end

local function ReleaseUnwatched()
    for frame in pairs(held) do
        if not seenHeld[frame] then
            ns.ReleaseAlpha(frame)
            held[frame] = nil
        end
    end
    Clear(seenHeld)
end

function ns.UpdateBars(showAll, elapsed)
    Collect()
    local forced = showAll or ns.Pinned("bars")
    local showGroup = {}
    if not forced then
        for _, entry in ipairs(resolved) do
            local group = ns.BarGroup(entry.id)
            for _, bar in ipairs(entry.frames) do
                local ok, err = pcall(function()
                    if bar:IsShown() and (BarHovered(bar) or BarCoversBags(bar)) then
                        showGroup[group] = true
                    end
                end)
                if not ok then
                    ns.Report("bar " .. entry.id, err)
                end
            end
        end
    end
    local mainAlpha, gamepadAlpha
    for _, entry in ipairs(resolved) do
        local show = forced or showGroup[ns.BarGroup(entry.id)] or false
        for _, bar in ipairs(entry.frames) do
            local ok, err = pcall(function()
                if not bar:IsShown() then return end
                local name, alpha = ApplyBar(bar, show, elapsed)
                if type(alpha) ~= "number" then return end
                if MAIN_BAR[name] then
                    mainAlpha = alpha
                elseif name == "GamepadMainActionBarFrame" then
                    gamepadAlpha = alpha
                end
            end)
            if not ok then
                ns.Report("bar " .. entry.id, err)
            end
        end
    end
    local artAlpha = mainAlpha or gamepadAlpha
    if type(artAlpha) == "number" then
        FollowArt(artAlpha)
    end
    ReleaseUnwatched()
end
