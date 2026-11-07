local _, ns = ...
local Layout = ns.Layout or {}
ns.Layout = Layout

-- Remember the original identity; switching between presets must not replace it.
local function Remember(active, absolute)
    if type(active) ~= "number" or active < 1 or active == absolute then return end
    local char = ns.CharDB()
    if char.previousLayout == nil then
        char.previousLayout = active
        local info = Layout.LoadLayouts()
        char.previousLayoutRef = info and Layout.LayoutRef(info, active)
    end
end

local function Write()
    local info = Layout.LoadLayouts()
    if not info then error("Edit Mode layouts are not loaded") end
    local shipped = Layout.ReadShipped()
    local index = Layout.FindLayout(info.layouts)
    local created = not index
    if index then
        shipped.layoutType = info.layouts[index].layoutType or shipped.layoutType
        info.layouts[index] = shipped
    else
        info.layouts[#info.layouts + 1] = shipped
        index = #info.layouts
    end
    -- Count presets before saving. SaveLayouts can rewrite the table it is given.
    local absolute = Layout.PresetCount() + index
    if created then
        info.activeLayout = absolute
    end
    C_EditMode.SaveLayouts(info)
    if created then
        C_EditMode.SetActiveLayout(absolute)
        ns.Print("Edit Mode layout \"" .. Layout.LAYOUT_NAME .. "\" saved.")
    else
        ns.Print("Edit Mode layout \"" .. Layout.LAYOUT_NAME .. "\" saved. Type /reload to finish.")
    end
end
Layout.Write = Write

-- True when the switch has been applied. False asks the caller to try again.
function ns.SelectQuietLayout()
    if InCombatLockdown() or not Layout.EditModeReady() then return false end
    local info = Layout.LoadLayouts()
    if not info then return false end
    local index = Layout.FindLayout(info.layouts)
    if not index then
        Remember(info.activeLayout, Layout.PresetCount() + #info.layouts + 1)
        Layout.MarkAnswered()
        Write()
        info = Layout.LoadLayouts()
        index = info and Layout.FindLayout(info.layouts)
        if not index then return false end
    end
    local absolute = Layout.PresetCount() + index
    if info.activeLayout == absolute then return true end
    Remember(info.activeLayout, absolute)
    C_EditMode.SetActiveLayout(absolute)
    -- A new character applies its default preset after this call. Not done until it stuck.
    local after = Layout.LoadLayouts()
    if after and after.activeLayout == absolute then return true end
    return false
end

function ns.SelectPresetLayout()
    if InCombatLockdown() or not Layout.EditModeReady() then return false end
    local preset = ns.ActivePreset()
    if not preset then return ns.SelectQuietLayout() end
    local info = Layout.LoadLayouts()
    if not info then return false end
    local absolute = Layout.ResolveLayout(info, preset.layout)
    if not absolute then
        if not ns.SelectQuietLayout() then return false end
        if ns.CharDB().previousLayout then ns.CharDB().presetLayoutManaged = true end
        local id = ns.CharDB().presetId
        if not Layout.missingWarned[id] then
            ns.Print('Preset "' .. preset.name .. '" refers to missing Edit Mode layout "'
                .. (preset.layout and preset.layout.layoutName or "Unknown") .. '". Using "QuietUI" instead.')
            Layout.missingWarned[id] = true
        end
        return true
    end
    Remember(info.activeLayout, absolute)
    if ns.CharDB().previousLayout then ns.CharDB().presetLayoutManaged = true end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = Layout.LoadLayouts()
    return after and after.activeLayout == absolute or false
end

function ns.RestorePreviousLayout()
    local char = ns.CharDB()
    local previous = char.previousLayout
    if previous == nil then char.presetLayoutManaged = nil; return true end
    if InCombatLockdown() or not Layout.EditModeReady() then return false end
    local info = Layout.LoadLayouts()
    if not info then return false end
    if char.previousLayoutRef then previous = Layout.ResolveLayout(info, char.previousLayoutRef) end
    local presets = Layout.PresetCount()
    local valid = type(previous) == "number" and previous >= 1
        and (previous <= presets or type(info.layouts[previous - presets]) == "table")
    if valid and info.activeLayout ~= previous then
        C_EditMode.SetActiveLayout(previous)
        local after = Layout.LoadLayouts()
        if not after or after.activeLayout ~= previous then return false end
    end
    char.previousLayout = nil
    char.previousLayoutRef = nil
    char.presetLayoutManaged = nil
    return true
end
