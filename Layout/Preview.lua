local _, ns = ...
local Layout = ns.Layout or {}
ns.Layout = Layout

local previewOriginal, previewPending, previewApplying

function ns.LayoutStatus()
    if not Layout.EditModeReady() then return "Edit Mode is not available." end
    local info = Layout.LoadLayouts()
    if not info then return "Edit Mode layouts are not loaded." end
    local preset = ns.ActivePreset and ns.ActivePreset()
    local linked = preset and Layout.ResolveLayout(info, preset.layout)
    return string.format("Active layout: %s; preset layout: %s; preview: %s.",
        tostring(info.activeLayout), tostring(linked or "none"),
        previewPending and "pending" or previewOriginal and "open" or "none")
end

local function SelectReference(ref)
    if InCombatLockdown() or not Layout.EditModeReady() then return false end
    local info = Layout.LoadLayouts()
    if not info then return false end
    local absolute = Layout.ResolveLayout(info, ref)
    if not absolute then error("The selected Edit Mode layout is no longer available.") end
    if info.activeLayout ~= absolute then C_EditMode.SetActiveLayout(absolute) end
    local after = Layout.LoadLayouts()
    return after and after.activeLayout == absolute or false
end

function ns.LayoutPreviewActive()
    return previewOriginal ~= nil or previewPending ~= nil
end

-- A draft owns the layout until Save or cancel, including login-settle retries.
function ns.UpdateLayoutPreview()
    if previewApplying then return true end
    if previewPending then
        previewApplying = true
        local ok, applied = pcall(SelectReference, previewPending)
        previewApplying = false
        if not ok then
            previewPending = nil
            ns.Report("layout preview", applied)
        elseif applied then
            previewPending = nil
        end
    end
    return previewOriginal ~= nil or previewPending ~= nil
end

function ns.PreviewLayout(ref)
    if not previewOriginal then
        if not Layout.EditModeReady() then return end
        local info = Layout.LoadLayouts()
        if not info then return end
        previewOriginal = Layout.LayoutRef(info, info.activeLayout)
    end
    previewPending = ns.Copy(ref)
    ns.UpdateLayoutPreview()
end

function ns.CancelLayoutPreview()
    if not previewOriginal then return end
    previewPending = previewOriginal
    previewOriginal = nil
    ns.UpdateLayoutPreview()
end

function ns.CommitLayoutPreview(managed)
    if managed and previewOriginal and ns.DB().enabled then
        local char = ns.CharDB()
        if char.previousLayout == nil then
            local info = Layout.LoadLayouts()
            local absolute = info and Layout.ResolveLayout(info, previewOriginal)
            if absolute then
                char.previousLayout = absolute
                char.previousLayoutRef = ns.Copy(previewOriginal)
                char.presetLayoutManaged = true
            end
        end
    end
    previewOriginal, previewPending = nil, nil
end

function ns.LayoutChoices()
    if not Layout.EditModeReady() then return {} end
    local info = Layout.LoadLayouts()
    if not info then return {} end
    local result = {}
    local style = Layout.CurrentStyle()
    for index, layout in ipairs(Layout.PresetLayouts()) do
        if (layout.interfaceStyle or Layout.KeyboardStyle()) == style then
            result[#result + 1] = { name = ns.LayoutLabel({ builtin = index }), ref = { builtin = index } }
        end
    end
    local account = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    for _, layout in ipairs(info.layouts) do
        if layout.layoutType == account and (layout.interfaceStyle or Layout.KeyboardStyle()) == style then
            result[#result + 1] = { name = layout.layoutName,
                ref = Layout.LayoutReference(layout) }
        end
    end
    return result
end

function ns.CurrentLayoutRef()
    if not Layout.EditModeReady() then return nil end
    local info = Layout.LoadLayouts()
    if not info then return nil end
    local ref = Layout.LayoutRef(info, info.activeLayout)
    for _, choice in ipairs(ns.LayoutChoices()) do
        if Layout.ResolveLayout(info, choice.ref) == info.activeLayout then return ref end
    end
    return { layoutName = Layout.LAYOUT_NAME,
        layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1 }
end
