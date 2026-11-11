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
    if button._cineAlpha ~= nil and not Bars.held[button] then return end
    Watch(button)
    ns.UpdateFaded(button, false, elapsed)
    return button._cineAlpha
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
        if bar._cineAlpha ~= nil then
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
        alpha = bar._cineAlpha
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
-- Fade group to the time its cast peek ends.
local peeks = {}
local PEEK_SECONDS = 2
local peekCount = 0

-- The spell an item casts when used (a hearthstone, a potion).
local function ItemSpell(itemID)
    local read = C_Item and C_Item.GetItemSpell or GetItemSpell
    if type(read) ~= "function" or type(itemID) ~= "number" then return end
    local ok, first, second = pcall(read, itemID)
    if not ok then return end
    return type(second) == "number" and second or (type(first) == "number" and first or nil)
end

local function ActionSpell(slot)
    if type(GetActionInfo) ~= "function" then return end
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok or ns.IsSecret(kind) or ns.IsSecret(id) then return end
    if kind == "macro" then
        if type(GetMacroSpell) == "function" then
            local okMacro, spell = pcall(GetMacroSpell, id)
            if okMacro and spell then return spell end
        end
        if type(GetMacroItem) == "function" then
            local okItem, _, link = pcall(GetMacroItem, id)
            local itemID = okItem and type(link) == "string" and tonumber(link:match("item:(%d+)"))
            return itemID and ItemSpell(itemID) or nil
        end
        return
    end
    if kind == "spell" then return id end
    if kind == "item" then return ItemSpell(id) end
end

local function BaseSpell(id)
    if C_Spell and type(C_Spell.GetBaseSpell) == "function" then
        local ok, base = pcall(C_Spell.GetBaseSpell, id)
        if ok and type(base) == "number" then return base end
    end
    return id
end

-- A cast out of combat holds the fade groups whose buttons carry that spell for a moment.
-- Hover groups peek too; a group under Always visible is up already.
function ns.PeekBarsForCast(spellID, extra)
    if type(spellID) ~= "number" or ns.IsSecret(spellID) or ns.InCombat() then return end
    if type(GetTime) ~= "function" then return end
    local base
    for _, entry in ipairs(Bars.resolved) do
        local group = ns.BarGroup(entry.id)
        local found = ns.GroupVisibility(group) == "always"
        for _, bar in ipairs(entry.frames) do
            if found then break end
            if ns.Usable(bar) then
                local list = Bars.ButtonsFor(bar, true)
                for i = 1, #list do
                    local slot = list[i].action
                    local spell = type(slot) == "number" and ActionSpell(slot)
                    if spell then
                        if spell ~= spellID then
                            base = base or BaseSpell(spellID)
                            found = BaseSpell(spell) == base
                        else
                            found = true
                        end
                        if found then
                            local untilTime = GetTime() + PEEK_SECONDS + (extra or 0)
                            if not peeks[group] then
                                peekCount = peekCount + 1
                            elseif peeks[group] > untilTime then
                                untilTime = peeks[group]
                            end
                            peeks[group] = untilTime
                            ns.TouchHud()
                            break
                        end
                    end
                end
            end
        end
    end
end

-- True once when a peek has just run out, so the bars get one more pass to fade.
function ns.BarPeekEnded()
    if peekCount == 0 or type(GetTime) ~= "function" then return false end
    local now, ended = GetTime(), false
    for group, untilTime in pairs(peeks) do
        if now >= untilTime then
            peeks[group] = nil
            peekCount = peekCount - 1
            ended = true
        end
    end
    return ended
end

local function Peeking(group)
    local untilTime = peeks[group]
    return untilTime ~= nil and type(GetTime) == "function" and GetTime() < untilTime
end
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
    if mode == "hover" then return ns.XPForced() or ns.FullGlancing() end
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
                or (not mode and friendly and ns.BarTarget(entry.id, "friendly"))
                or Peeking(group) or false
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
