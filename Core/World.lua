local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

-- Returns fn()'s result, or false when the API is missing or throws.
local function Safe(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and not ns.IsSecret(result) and result and true or false
end

-- A corpse still counts as attackable. Enemy needs a living target.
local function TargetAlive()
    if type(UnitIsDeadOrGhost) == "function" then
        return not Safe(UnitIsDeadOrGhost, "target")
    end
    if type(UnitIsDead) == "function" then
        return not Safe(UnitIsDead, "target")
    end
    return true
end

local function HostileTarget()
    if type(UnitCanAttack) ~= "function" then return false end
    return Safe(UnitCanAttack, "player", "target") and TargetAlive()
end

local function FriendlyTarget()
    if type(UnitIsFriend) ~= "function" then return false end
    return Safe(UnitIsFriend, "player", "target") and TargetAlive()
end

local world = {
    combat = false,
    instance = false,
    group = false,
    vehicle = false,
    target = false,
    hostile = false,
    friendly = false,
}
Bars.world = world

function ns.InEditMode()
    local frame = EditModeManagerFrame
    return frame and frame.IsShown and frame:IsShown() and true or false
end

function ns.RefreshWorld()
    local combat = world.combat
    if type(InCombatLockdown) == "function" then
        local ok, locked = pcall(InCombatLockdown)
        if ok then combat = locked and true or false end
    end
    local group = type(IsInGroup) == "function" and Safe(IsInGroup) or false
    local vehicle = type(UnitHasVehicleUI) == "function" and Safe(UnitHasVehicleUI, "player") or false
    local target = type(UnitExists) == "function" and Safe(UnitExists, "target") or false
    local hostile = target and HostileTarget()
    local friendly = target and FriendlyTarget()
    local instance = false
    if type(IsInInstance) == "function" then
        instance = Safe(function()
            local inInstance, kind = IsInInstance()
            return inInstance and (
                kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
            )
        end)
    end
    if combat ~= world.combat or group ~= world.group or vehicle ~= world.vehicle
        or target ~= world.target or instance ~= world.instance
        or hostile ~= world.hostile or friendly ~= world.friendly then
        world.combat, world.group, world.vehicle = combat, group, vehicle
        world.target, world.instance = target, instance
        world.hostile, world.friendly = hostile, friendly
        ns.TouchHud()
    end
end

function ns.NoteCombat(on)
    local nextOn = on and true or false
    if nextOn ~= world.combat then
        world.combat = nextOn
        ns.TouchHud()
    end
end

function ns.InCombat()
    return world.combat
end

function ns.InGroup()
    return world.group
end

function ns.InForcedInstance()
    return world.instance and ns.ForceFramesInInstance()
end

function ns.InVehicle()
    return world.vehicle
end

function ns.HasTarget()
    return world.target
end

-- false means this tick has not read the cursor yet. nil is a real empty cursor.
local cursorKind = false
local hudDirty = true

function ns.TouchHud()
    hudDirty = true
end

function ns.ConsumeHud()
    local dirty = hudDirty
    hudDirty = false
    return dirty
end

function ns.ForgetCursor()
    cursorKind = false
end

function ns.BeginTick(hover)
    if not hover then return end
    cursorKind = false
    ns.RefreshMouse()
end

local function CursorKind()
    if cursorKind ~= false then return cursorKind end
    if type(GetCursorInfo) ~= "function" then
        cursorKind = nil
        return nil
    end
    local ok, kind = pcall(GetCursorInfo)
    cursorKind = ok and kind or nil
    return cursorKind
end

function ns.CursorBusy()
    return CursorKind() ~= nil
end

function ns.CursorHasItem()
    return CursorKind() == "item"
end

local function FlyoutOpen()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end
ns.FlyoutOpen = FlyoutOpen

-- Explicit HUD/bar-editing exceptions also reveal hover-only bars and XP.
function ns.XPForced()
    return ns.InEditMode() or FlyoutOpen() or ns.CursorBusy()
end

-- Action bars are fully visible while this is true.
function ns.ShowAll()
    return world.combat or ns.InEditMode() or world.vehicle or ns.InForcedInstance()
        or FlyoutOpen() or ns.CursorBusy()
end
