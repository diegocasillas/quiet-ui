local _, ns = ...

-- Which frames are bars, which belong to bags, and which must never be muted.

ns.BAR_NAMES = {
    "MainMenuBar",
    "MainActionBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "StanceBar",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBar",
    "PetActionBarFrame",
    "MultiCastActionBarFrame",
    "TotemFrame",
    "SwingTimerFrame",
    "GamepadMainActionBarFrame",
}

local BAG_NAMES = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    "BagBarExpandToggle",
    "KeyRingButton",
}

local SPARE_SET = {
    OverrideActionBar = true,
    ExtraActionBarFrame = true,
    ExtraAbilityContainer = true,
    ZoneAbilityFrame = true,
    PossessActionBar = true,
    PossessBarFrame = true,
    PlayerFrame = true,
    TargetFrame = true,
    Minimap = true,
    MinimapCluster = true,
    QuietUIMenuButton = true,
}

local BAR_SET = {}
for _, name in ipairs(ns.BAR_NAMES) do
    BAR_SET[name] = true
end

local BAG_SET = { BagsBar = true }
for _, name in ipairs(BAG_NAMES) do
    BAG_SET[name] = true
end

function ns.IsBarFrame(frame)
    local name = ns.FrameName(frame)
    return name and BAR_SET[name] or false
end

function ns.IsBagRelated(frame)
    local name = ns.FrameName(frame)
    return name and BAG_SET[name] or false
end

function ns.IsQueue(frame)
    local name = ns.FrameName(frame)
    if not name then return false end
    return name:find("QueueStatus") ~= nil or name:find("LFGEye") ~= nil
end

function ns.IsSpared(frame)
    if not frame then return true end
    if ns.IsQueue(frame) or ns.IsBarFrame(frame) then return true end
    local name = ns.FrameName(frame)
    if not name then return false end
    if SPARE_SET[name] then return true end
    return name:find("Vehicle") ~= nil
        or name:find("ExtraAction") ~= nil
        or name:find("ZoneAbility") ~= nil
end

function ns.TreeHas(frame, test, depth)
    depth = depth or 0
    if not ns.Usable(frame) or depth > 4 then return false end
    if test(frame) then return true end
    if not frame.GetChildren then return false end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.TreeHas(child, test, depth + 1) then
            return true
        end
    end
    return false
end

-- Alpha 0 for chrome that is neither spared, a bar, nor part of the bags.
function ns.Mute(frame)
    if not ns.Usable(frame) or ns.IsSpared(frame) or ns.IsBagRelated(frame) then return end
    ns.HoldAlpha(frame, 0)
end

function ns.EachBagFrame(fn)
    for _, name in ipairs(BAG_NAMES) do
        local frame = _G[name]
        if frame then fn(frame) end
    end
    local bags = _G.BagsBar
    if not bags then return end
    fn(bags)
    if not bags.GetChildren then return end
    for _, child in ipairs({ bags:GetChildren() }) do
        if ns.Usable(child) and not ns.IsSpared(child) then
            fn(child)
        end
    end
end
