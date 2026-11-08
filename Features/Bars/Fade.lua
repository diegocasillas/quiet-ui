local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

local function Collect()
    if not Bars.structureDirty then return end
    Bars.structureDirty = false
    ns.Wipe(Bars.owner)
    ns.Wipe(Bars.hosts)
    ns.Wipe(Bars.covered)
    for index, row in ipairs(ns.BAR_ROWS) do
        local entry = Bars.resolved[index]
        if not entry then
            entry = { frames = {} }
            Bars.resolved[index] = entry
        end
        entry.id = row.id
        local frames = entry.frames
        local count = 0
        local seen = {}
        for _, name in ipairs(row.names) do
            local bar = _G[name]
            if ns.Usable(bar) and not seen[bar] then
                Bars.WatchParent(bar)
                seen[bar] = true
                count = count + 1
                frames[count] = bar
            end
        end
        for extra = count + 1, #frames do
            frames[extra] = nil
        end
        for _, bar in ipairs(frames) do
            Bars.owner[bar] = row.id
        end
        if row.id == "swing" then
            for frame in pairs(Bars.swingFound) do
                if not seen[frame] then
                    count = count + 1
                    frames[count] = frame
                    Bars.owner[frame] = row.id
                end
            end
            for extra = count + 1, #frames do
                frames[extra] = nil
            end
        end
    end
    -- Ownership passes run here once per structure change, not every tick.
    for bar, id in pairs(Bars.owner) do
        for other, otherId in pairs(Bars.owner) do
            if other ~= bar and otherId ~= id and Bars.IsAncestor(other, bar) then
                local list = Bars.hosts[bar]
                if not list then
                    list = {}
                    Bars.hosts[bar] = list
                end
                list[#list + 1] = other
            end
        end
    end
    for bar, id in pairs(Bars.owner) do
        for other, otherId in pairs(Bars.owner) do
            if other ~= bar and otherId == id and not Bars.hosts[other] and Bars.IsAncestor(bar, other) then
                Bars.covered[bar] = true
                break
            end
        end
    end
end

local function Watch(frame)
    Bars.seenHeld[frame] = true
    Bars.held[frame] = true
end

-- Shown buttons are released so range fading can set their alpha.
local function FadeButton(button, show, elapsed)
    if not button.IsShown or not button:IsShown() then return end
    if show then
        if Bars.held[button] then
            ns.ReleaseAlpha(button)
            Bars.held[button] = nil
        end
        return 1
    end
    if button._quietAlpha ~= nil and not Bars.held[button] then return end
    Watch(button)
    ns.UpdateFaded(button, false, elapsed)
    return button._quietAlpha
end

-- Parent stays at full alpha so a nested bar can keep its own.
local function FadeHosted(bar, show, elapsed)
    ns.HoldAlpha(bar, 1)
    local alpha
    local list = Bars.ButtonsFor(bar, true)
    for i = 1, #list do
        local nextAlpha = FadeButton(list[i], show, elapsed)
        if type(nextAlpha) == "number" then
            alpha = nextAlpha
        end
    end
    if type(alpha) == "number" then
        local regions = Bars.RegionsFor(bar)
        for i = 1, #regions do
            Watch(regions[i])
            ns.HoldAlpha(regions[i], alpha)
        end
    end
    return alpha
end

-- Deeper art follows the child frame. Only art parented to the bar itself needs a hold.
local function FadeChildArt(bar, alpha)
    for _, name in ipairs(Bars.BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha and Bars.Parent(art) == bar then
            Watch(art)
            ns.HoldAlpha(art, alpha)
        end
    end
end

local function ApplyBar(bar, show, elapsed)
    if Bars.covered[bar] then
        if bar._quietAlpha ~= nil then
            ns.ReleaseAlpha(bar)
        end
        return
    end
    local name = ns.FrameName(bar) or ""
    local alpha
    if Bars.HostsOther(bar) then
        alpha = FadeHosted(bar, show, elapsed)
        if Bars.MAIN_BAR[name] and type(alpha) == "number" then
            FadeChildArt(bar, alpha)
        end
    else
        ns.UpdateFaded(bar, show, elapsed)
        alpha = bar._quietAlpha
    end
    return name, alpha
end

local function ReleaseUnwatched()
    for frame in pairs(Bars.held) do
        if not Bars.seenHeld[frame] then
            ns.ReleaseAlpha(frame)
            Bars.held[frame] = nil
        end
    end
    ns.Wipe(Bars.seenHeld)
end

local showGroup = {}
local barShow = {}
local haveBarShow = false
local shownGroups = {}
local shownStamp = 0

-- True while a bar of that fade group is on screen and kept up (read by the letterbox).
-- A group counts only when stamped this pass, so nothing is wiped each frame.
function ns.BarGroupShowing(group)
    return shownGroups[group] == shownStamp
end

-- Hover groups skip automatic triggers; explicit HUD and bar editing still show them.
local function RowForced(id, showAllForced)
    local mode = ns.GroupVisibility(ns.BarGroup(id))
    if mode == "always" then return true end
    if mode == "hover" then return ns.XPForced() end
    return showAllForced
end

function ns.UpdateBars(showAll, elapsed, rescan)
    if rescan == nil then rescan = true end
    local showAllForced = showAll or ns.Glancing()
    -- ApplyBar reads hosts/covered, which ForgetBarButtons drops between rescans.
    Collect()
    if rescan or not haveBarShow then
        if ns.InEditMode() or not ns.DB().enabled then
            Bars.HideCatchers()
        else
            Bars.SyncCatchers()
        end
        for key in pairs(showGroup) do
            showGroup[key] = nil
        end
        local hostile, friendly
        do
            hostile = Bars.world.hostile
            friendly = Bars.world.friendly
            for _, entry in ipairs(Bars.resolved) do
                local group = ns.BarGroup(entry.id)
                for _, bar in ipairs(entry.frames) do
                    if ns.Usable(bar) and bar:IsShown() and (Bars.BarHovered(bar) or Bars.BarCoversBags(bar)) then
                        showGroup[group] = true
                    end
                end
            end
        end
        for _, entry in ipairs(Bars.resolved) do
            local group = ns.BarGroup(entry.id)
            local mode = ns.GroupVisibility(group)
            barShow[entry.id] = RowForced(entry.id, showAllForced) or showGroup[group]
                or (not mode and hostile and ns.BarTarget(entry.id, "hostile"))
                or (not mode and friendly and ns.BarTarget(entry.id, "friendly")) or false
        end
        haveBarShow = true
    end
    local mainAlpha, gamepadAlpha
    shownStamp = shownStamp + 1
    for _, entry in ipairs(Bars.resolved) do
        local show = RowForced(entry.id, showAllForced) or barShow[entry.id]
        for _, bar in ipairs(entry.frames) do
            if ns.Usable(bar) and bar:IsShown() then
                if show then shownGroups[ns.BarGroup(entry.id)] = shownStamp end
                local name, alpha = ApplyBar(bar, show, elapsed)
                if type(alpha) == "number" then
                    if Bars.MAIN_BAR[name] then
                        mainAlpha = alpha
                    elseif name == "GamepadMainActionBarFrame" then
                        gamepadAlpha = alpha
                    end
                end
            end
        end
    end
    local artAlpha = mainAlpha or gamepadAlpha
    if type(artAlpha) == "number" then
        Bars.FollowArt(artAlpha)
    end
    ReleaseUnwatched()
end
