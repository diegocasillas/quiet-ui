local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

local buttonCache = {}
local deepCache = {}
local regionCache = {}

-- Glowing Bars (and addons like it) mark a glowing button SetIgnoreParentAlpha(true),
-- so the glow stays visible whatever its bar is doing. Under a bar Puro Cine fades that
-- would show the glow with the bar hidden. The mark is undone, so the button follows
-- its bar's alpha again; a glow on a bar that is showing looks as before.
local function FollowBarAlpha(button)
    if button._puroPuroCineFollowHook or type(button.SetIgnoreParentAlpha) ~= "function" then return end
    button._puroPuroCineFollowHook = true
    pcall(hooksecurefunc, button, "SetIgnoreParentAlpha", function(self, ignore)
        if not ignore or self._puroPuroCineFollowing or not ns.DB().enabled then return end
        self._puroPuroCineFollowing = true
        self:SetIgnoreParentAlpha(false)
        self._puroPuroCineFollowing = false
    end)
    if type(button.IsIgnoringParentAlpha) == "function" and ns.DB().enabled then
        local ok, ignoring = pcall(button.IsIgnoringParentAlpha, button)
        if ok and ignoring == true then button:SetIgnoreParentAlpha(false) end
    end
end

-- The buttons are looked up by name, not through the bar caches: some sit in
-- container frames the caches do not walk. A hook per button catches the next
-- mark at once; the sweep catches buttons made later and marks already set.
local GLOW_PREFIXES = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button",
    "MultiBar7Button", "MultiBar8Button", "StanceButton", "PetActionButton" }

function ns.FollowGlowButtons()
    if not ns.DB().enabled then return end
    for _, prefix in ipairs(GLOW_PREFIXES) do
        for index = 1, 12 do
            local button = _G[prefix .. index]
            if button and not button._puroPuroCineFollowHook then FollowBarAlpha(button) end
        end
    end
end

local function RememberButtons(bar, list, deep)
    local seen = {}
    local function add(button)
        if seen[button] then return end
        seen[button] = true
        FollowBarAlpha(button)
        list[#list + 1] = button
    end
    Bars.EachOwnButton(bar, add)
    if deep then Bars.EachDeepButton(bar, add) end
end

local function ButtonsFor(bar, deep)
    local cache = deep and deepCache or buttonCache
    local list = cache[bar]
    if list then return list end
    list = {}
    cache[bar] = list
    RememberButtons(bar, list, deep)
    return list
end
Bars.ButtonsFor = ButtonsFor

local function RegionsFor(bar)
    local list = regionCache[bar]
    if list then return list end
    list = {}
    regionCache[bar] = list
    if not bar.GetRegions then return list end
    for _, region in ipairs({ bar:GetRegions() }) do
        if region and region.SetAlpha and region.GetObjectType then
            local ok, kind = pcall(region.GetObjectType, region)
            if ok and kind == "Texture" then
                list[#list + 1] = region
            end
        end
    end
    return list
end
Bars.RegionsFor = RegionsFor

function ns.ForgetBarButtons()
    Bars.structureDirty = true
    Bars.ancestorCache = {}
    ns.Wipe(Bars.hosts)
    ns.Wipe(Bars.covered)
    ns.TouchHud()
    for bar in pairs(buttonCache) do
        buttonCache[bar] = nil
    end
    for bar in pairs(deepCache) do
        deepCache[bar] = nil
    end
    for bar in pairs(regionCache) do
        regionCache[bar] = nil
    end
end

-- GetNumChildren is enough to notice a new button. The full rebuild waits for that.
local childCounts = {}
local childPrimed = false
local childFallback = 0
local childArmed = false

local function ChildCount(bar)
    if type(bar.GetNumChildren) ~= "function" then return nil end
    local ok, count = pcall(bar.GetNumChildren, bar)
    if not ok or type(count) ~= "number" or ns.IsSecret(count) then return nil end
    return count
end

function ns.BarChildrenChanged()
    local missing = false
    local changed = false
    local seen = {}
    for _, row in ipairs(ns.BAR_ROWS) do
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if ns.Usable(bar) then
                seen[bar] = true
                local count = ChildCount(bar)
                if count == nil then
                    missing = true
                elseif childCounts[bar] ~= count then
                    if childPrimed then changed = true end
                    childCounts[bar] = count
                end
            end
        end
    end
    for bar in pairs(childCounts) do
        if not seen[bar] then
            childCounts[bar] = nil
            if childPrimed then changed = true end
        end
    end
    childPrimed = true
    if changed then return true end
    if not missing then return false end
    local now = type(GetTime) == "function" and GetTime() or 0
    if not childArmed then
        childArmed = true
        childFallback = now + 5
        return false
    end
    if now < childFallback then return false end
    childFallback = now + 5
    return true
end

local function ListHovered(list)
    for i = 1, #list do
        if ns.Hit(list[i]) then return true end
    end
    return false
end

-- Gamepad and totem buttons sit outside the bar rect, so the catcher misses them.
local function ButtonsHovered(bar)
    if not Bars.DEEP_HOVER[ns.FrameName(bar) or ""] then return false end
    if ListHovered(ButtonsFor(bar, false)) then return true end
    return ListHovered(ButtonsFor(bar, true))
end
Bars.ButtonsHovered = ButtonsHovered
