local _, ns = ...
local Layout = ns.Layout or {}
ns.Layout = Layout

-- Offers the Cine Edit Mode layout from LayoutString.lua. Each new version
-- of that string is offered once; an update still waits for consent.
-- With Force Cine layout on, turning the addon on selects the layout
-- (creating it when missing) and remembers the previous one. Turning it off
-- selects that layout again. With force off, the active layout stays as it is.
-- Only C_EditMode is used: calling EditModeManagerFrame methods would taint it.

local LAYOUT_NAME = "Cine"
Layout.LAYOUT_NAME = LAYOUT_NAME

-- Blizzard ships Modern and Classic presets ahead of saved layouts.
local FALLBACK_PRESETS = { { layoutName = "Modern" }, { layoutName = "Classic" } }

Layout.done = false
local missingWarned = {}
Layout.missingWarned = missingWarned

local function EditModeReady()
    return C_EditMode
        and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.ConvertStringToLayoutInfo) == "function"
        and type(C_EditMode.SaveLayouts) == "function"
        and type(C_EditMode.SetActiveLayout) == "function"
end
Layout.EditModeReady = EditModeReady

local presetManager, presetLayouts

local function PresetLayouts()
    local manager = EditModePresetLayoutManager
    if presetLayouts and presetManager == manager then return presetLayouts end
    if manager then
        local presets = manager.presetLayoutInfo
        if type(presets) ~= "table" and type(manager.GetCopyOfPresetLayouts) == "function" then
            local ok, result = pcall(manager.GetCopyOfPresetLayouts, manager)
            if ok then presets = result end
        end
        if type(presets) == "table" and #presets > 0 then
            local list = {}
            for index, preset in ipairs(presets) do
                list[index] = type(preset) == "table" and {
                    layoutName = preset.layoutName, interfaceStyle = preset.interfaceStyle,
                } or {}
            end
            presetManager, presetLayouts = manager, list
            return list
        end
    end
    return FALLBACK_PRESETS
end
Layout.PresetLayouts = PresetLayouts

local function PresetCount()
    return #PresetLayouts()
end
Layout.PresetCount = PresetCount

local function KeyboardStyle()
    return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Mkb or 0
end
Layout.KeyboardStyle = KeyboardStyle

local function CurrentStyle()
    if InputUtil and type(InputUtil.GetCurrentInterfaceStyle) == "function" then
        local ok, style = pcall(InputUtil.GetCurrentInterfaceStyle)
        if ok and type(style) == "number" then return style end
    end
    if InputUtil and type(InputUtil.IsGamepadUIEnabled) == "function" then
        local ok, enabled = pcall(InputUtil.IsGamepadUIEnabled)
        if ok and enabled then
            return Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad or 1
        end
    end
    return KeyboardStyle()
end
Layout.CurrentStyle = CurrentStyle

ns.CurrentInterfaceStyle = CurrentStyle

local function LayoutReference(layout)
    return { layoutName = layout.layoutName, layoutType = layout.layoutType,
        interfaceStyle = layout.interfaceStyle or KeyboardStyle() }
end
Layout.LayoutReference = LayoutReference

function ns.LayoutLabel(ref)
    if not ref then return "Choose layout" end
    if ref.layoutName then return ref.layoutName end
    if ref.builtin then
        local names = PresetLayouts()
        local name = names[ref.builtin] and names[ref.builtin].layoutName
            or ({ "Modern", "Classic" })[ref.builtin]
            or ("Built-in layout " .. ref.builtin)
        if name:lower() == "gamepad" then return name .. " (Gamepad mode only)" end
        return name
    end
    return "Choose layout"
end

local function FindLayout(layouts)
    for i, layout in ipairs(layouts) do
        if layout.layoutName == LAYOUT_NAME then return i end
    end
end
Layout.FindLayout = FindLayout

local function ReadShipped()
    local layout = C_EditMode.ConvertStringToLayoutInfo(ns.LAYOUT_STRING or "")
    if type(layout) ~= "table" then
        error("LayoutString.lua could not be read")
    end
    layout.layoutName = LAYOUT_NAME
    layout.layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    return layout
end
Layout.ReadShipped = ReadShipped

-- The client rewrites a saved layout, so it never matches the string again.
-- Instead the string's hash marks which version the player already answered.
local function Hash(text)
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 33 + text:byte(i)) % 4294967296
    end
    return string.format("%08x", hash)
end

local function ShippedHash()
    return Hash(ns.LAYOUT_STRING or "")
end
Layout.ShippedHash = ShippedHash

local function MarkAnswered()
    ns.DB().layoutHash = ShippedHash()
end
Layout.MarkAnswered = MarkAnswered

local function LoadLayouts()
    local ok, info = pcall(C_EditMode.GetLayouts)
    if not ok then return nil end
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end
Layout.LoadLayouts = LoadLayouts

local function LayoutRef(info, absolute)
    if type(absolute) ~= "number" then return nil end
    if absolute <= PresetCount() then return { builtin = absolute } end
    local layout = info.layouts[absolute - PresetCount()]
    if not layout then return nil end
    return LayoutReference(layout)
end
Layout.LayoutRef = LayoutRef

local function ResolveLayout(info, ref)
    if type(ref) ~= "table" then return nil end
    if ref.builtin and ref.builtin >= 1 and ref.builtin <= PresetCount() then return ref.builtin end
    for index, layout in ipairs(info.layouts) do
        if layout.layoutName == ref.layoutName and layout.layoutType == ref.layoutType
            and (ref.interfaceStyle == nil or (layout.interfaceStyle or KeyboardStyle()) == ref.interfaceStyle) then
            return PresetCount() + index
        end
    end
end
Layout.ResolveLayout = ResolveLayout

function ns.LayoutInterfaceStyle(ref)
    if type(ref) ~= "table" then return nil end
    if type(ref.interfaceStyle) == "number" then return ref.interfaceStyle end
    if ref.builtin then
        local layout = PresetLayouts()[ref.builtin]
        return layout and (layout.interfaceStyle or KeyboardStyle()) or nil
    end
    if not EditModeReady() then return nil end
    local info = LoadLayouts()
    if not info then return nil end
    local absolute = ResolveLayout(info, ref)
    local layout = absolute and info.layouts[absolute - PresetCount()]
    return layout and (layout.interfaceStyle or KeyboardStyle()) or KeyboardStyle()
end

function ns.ValidatePresetInterface()
    local preset = ns.ActivePreset and ns.ActivePreset()
    if not preset then return true end
    if not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local style = ns.PresetInterfaceStyle(preset)
    if style == nil then return false end
    if style ~= CurrentStyle() then
        ns.ActivatePreset(nil)
        if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
        if ns.RefreshSetup then ns.RefreshSetup() end
        ns.Print('Preset "' .. preset.name .. '" uses a layout for another interface mode. '
            .. 'Using personal settings instead.')
    end
    return true
end
