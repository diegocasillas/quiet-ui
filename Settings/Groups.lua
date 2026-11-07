local _, ns = ...

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
    { id = "totem", label = "Totem bar", group = 1, names = { "MultiCastActionBarFrame", "TotemFrame" } },
    { id = "swing", label = "Swing timer", group = 10, names = {
        "SwingTimerFrame",
        "SwingTimer",
        "MainHandSwingTimer",
        "OffHandSwingTimer",
        "RangedSwingTimer",
        "SwingTimerMainHand",
        "SwingTimerOffHand",
    } },
}

-- Move legacy per-bar pins to group modes, splitting mixed groups to keep their visibility.
function ns.MigrateVisibility(settings)
    if type(settings) ~= "table" then return end
    local visible = settings.visible
    if type(visible) ~= "table" or (visible.bars == nil and visible.swing == nil) then return end
    local buckets, used = {}, {}
    local legacy = visible.bars ~= nil or visible.swing ~= nil
    for _, row in ipairs(ns.BAR_ROWS) do
        if visible[row.id] ~= nil then legacy = true end
        local n = type(settings.groups) == "table" and settings.groups[row.id]
        if type(n) ~= "number" or n ~= n or n < 1 or n > #ns.BAR_ROWS then n = row.group end
        n = math.floor(n)
        used[n] = true
        buckets[n] = buckets[n] or { pinned = {}, normal = {} }
        local pinned = visible[row.id] or (row.id ~= "swing" and visible.bars)
        local list = pinned and buckets[n].pinned or buckets[n].normal
        list[#list + 1] = row.id
    end
    if not legacy then return end
    settings.groupVisibility = type(settings.groupVisibility) == "table" and settings.groupVisibility or {}
    for n = 1, #ns.BAR_ROWS do
        local bucket = buckets[n]
        if bucket and #bucket.pinned > 0 then
            local pinGroup = n
            if #bucket.normal > 0 then
                for candidate = 1, #ns.BAR_ROWS do
                    if not used[candidate] then pinGroup = candidate; used[candidate] = true; break end
                end
                settings.groups = type(settings.groups) == "table" and settings.groups or {}
                for _, id in ipairs(bucket.pinned) do settings.groups[id] = pinGroup end
            end
            settings.groupVisibility[pinGroup] = "always"
        end
    end
    visible.bars = nil
    for _, row in ipairs(ns.BAR_ROWS) do visible[row.id] = nil end
end

-- Migration runs once per visible table; a replaced table migrates again.
local migrated = setmetatable({}, { __mode = "k" })

function ns.MigrateOnce(settings)
    if type(settings) ~= "table" then return end
    local visible = settings.visible
    if type(visible) ~= "table" or migrated[visible] then return end
    migrated[visible] = true
    ns.MigrateVisibility(settings)
end

-- Group 2 (bars 4 and 5) shows only on hover until setup says otherwise. "usual"
-- is the saved choice for the usual rules where a default would otherwise apply.
local DEFAULT_GROUP_MODE = { [2] = "hover" }

function ns.GroupMode(settings, group)
    local modes = settings.groupVisibility
    local mode = type(modes) == "table" and modes[group]
    if mode == "always" or mode == "hover" then return mode end
    if mode == "usual" then return nil end
    return DEFAULT_GROUP_MODE[group]
end

function ns.DefaultGroupMode(group)
    return DEFAULT_GROUP_MODE[group]
end

function ns.GroupVisibility(group)
    return ns.GroupMode(ns.Settings and ns.Settings() or ns.CharDB(), group)
end

function ns.AnyBarsAlwaysVisible()
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id ~= "swing" and ns.GroupVisibility(ns.BarGroup(row.id)) == "always" then return true end
    end
    return false
end

function ns.BarGroup(id)
    local fallback = 1
    for _, row in ipairs(ns.BAR_ROWS) do
        if row.id == id then
            fallback = row.group
            break
        end
    end
    if type(ns.CharDB) ~= "function" then return fallback end
    local groups = (ns.Settings and ns.Settings() or ns.CharDB()).groups
    local n = type(groups) == "table" and groups[id]
    if type(n) ~= "number" or n ~= n then return fallback end
    n = math.floor(n)
    if n < 1 or n > #ns.BAR_ROWS then return fallback end
    return n
end

-- Bars 1 to 3 stay up for an enemy target until setup says otherwise. A saved
-- false is the choice to turn a default off. kind is "hostile" or "friendly".
local DEFAULT_TARGET = { hostile = { ["1"] = true, ["2"] = true, ["3"] = true } }

function ns.DefaultBarTarget(id, kind)
    local defaults = DEFAULT_TARGET[kind]
    return defaults and defaults[id] and true or false
end

function ns.BarTargetSetting(settings, id, kind)
    local map = settings[kind]
    local value
    if type(map) == "table" then value = map[id] end
    if value == true then return true end
    if value == false then return false end
    return ns.DefaultBarTarget(id, kind)
end

function ns.BarTarget(id, kind)
    if type(ns.CharDB) ~= "function" then return false end
    return ns.BarTargetSetting(ns.Settings and ns.Settings() or ns.CharDB(), id, kind)
end
