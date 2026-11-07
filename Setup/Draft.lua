local _, ns = ...
local Setup = ns.Setup or {}
ns.Setup = Setup

local function ReadDraft(source)
    if Setup.frame and Setup.frame.rangeSpell and Setup.frame.rangeSpell.edit:HasFocus() then Setup.frame.rangeSpell.edit:ClearFocus() end
    source = source or (ns.Settings and ns.Settings() or ns.CharDB())
    if ns.MigrateOnce then ns.MigrateOnce(source) end
    Setup.draft.hoverOnly = {}
    for _, row in ipairs(Setup.ROWS) do
        Setup.draft.hoverOnly[row.key] = ns.HoverSetting(source, row.key)
        Setup.draft[row.key] = type(source.visible) == "table" and source.visible[row.key] == true and not Setup.draft.hoverOnly[row.key]
    end
    Setup.draft.forceLayout = source.forceLayout == true
    Setup.draft.player = source.player ~= "resource"
    Setup.draft.playerThresholdKind = source.playerThresholdKind == "health" and "health" or "resource"
    local value = source.playerThresholdPercent
    if value == false then Setup.draft.playerThresholdPercent = ""
    elseif type(value) == "number" and not ns.IsSecret(value)
        and value >= 1 and value <= 100 and value == math.floor(value) then Setup.draft.playerThresholdPercent = tostring(value)
    else Setup.draft.playerThresholdPercent = "70" end
    if Setup.frame and Setup.frame.playerThresholdPercent then Setup.frame.playerThresholdPercent.edit:ClearFocus() end
    Setup.draft.requireLivingTarget = source.requireLivingTarget == true
    Setup.draft.groupAuras = source.groupAuras ~= false
    Setup.draft.alwaysShowDebuffs = source.alwaysShowDebuffs ~= false
    Setup.draft.showPlayerFrameInParty = source.showPlayerFrameInParty ~= false
    Setup.draft.forceFramesInInstance = source.forceFramesInInstance ~= false
    Setup.draft.chat = source.chat ~= false
    local fade = source.chatFade
    Setup.draft.chatFade = type(fade) == "number" and fade == fade and math.floor(math.max(0, math.min(60, fade)) / 5) * 5 or 10
    local range = type(source.range) == "table" and source.range or {}
    Setup.draft.range = range.yards == 10 or range.yards == 28 or range.yards == "spell"
    Setup.draft.rangeYards = Setup.draft.range and range.yards or "spell"
    Setup.draft.rangeKind = range.kind == "friendly" and "friendly" or "hostile"
    Setup.draft.rangeSpell = type(range.spell) == "string" and not ns.IsSecret(range.spell) and range.spell or ""
    Setup.draft.groupVisibility = {}
    for group = 1, #ns.BAR_ROWS do
        local mode = type(source.groupVisibility) == "table" and source.groupVisibility[group]
        if mode == "always" or mode == "hover" then Setup.draft.groupVisibility[group] = mode end
    end
    Setup.draft.groups, Setup.draft.hostile, Setup.draft.friendly = {}, {}, {}
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = type(source.groups) == "table" and source.groups[row.id]
        Setup.draft.groups[row.id] = type(n) == "number" and n == n and n >= 1 and n <= #ns.BAR_ROWS and math.floor(n) or row.group
        Setup.draft.hostile[row.id] = type(source.hostile) == "table" and source.hostile[row.id] == true
        Setup.draft.friendly[row.id] = type(source.friendly) == "table" and source.friendly[row.id] == true
    end
end
Setup.ReadDraft = ReadDraft

Setup.LoadSavedDraft = function()
    ReadDraft()
    local preset = ns.ActivePreset()
    Setup.selectedPresetId = preset and ns.CharDB().presetId or nil
    Setup.presetName = preset and preset.name or nil
    Setup.presetLayout = preset and ns.Copy(preset.layout) or nil
end

-- Only checked bar ids are stored. A missing map means every box is off.
local function SavedFlags(flags)
    local saved
    for _, row in ipairs(ns.BAR_ROWS) do
        if flags[row.id] then
            saved = saved or {}
            saved[row.id] = true
        end
    end
    return saved
end

local function DraftSettings()
    local db = {}
    local visible
    for _, row in ipairs(Setup.ROWS) do
        if Setup.draft[row.key] then
            visible = visible or {}
            visible[row.key] = true
        end
    end
    db.visible = visible
    for _, row in ipairs(Setup.ROWS) do
        if Setup.draft.hoverOnly[row.key] or (row.key == "xp" and not Setup.draft[row.key]) then
            db.hoverOnly = db.hoverOnly or {}
            db.hoverOnly[row.key] = Setup.draft.hoverOnly[row.key] and true or false
        end
    end
    for _, row in ipairs(ns.BAR_ROWS) do
        local group = Setup.draft.groups[row.id]
        if Setup.draft.groupVisibility[group] then
            db.groupVisibility = db.groupVisibility or {}
            db.groupVisibility[group] = Setup.draft.groupVisibility[group]
        end
    end
    if Setup.draft.forceLayout then
        db.forceLayout = true
    else
        db.forceLayout = nil
    end
    if Setup.draft.player then
        db.player = nil
    else
        db.player = "resource"
    end
    if Setup.draft.playerThresholdKind == "health" then db.playerThresholdKind = "health" end
    local text = Setup.draft.playerThresholdPercent:match("^%s*(.-)%s*$")
    if text == "" then db.playerThresholdPercent = false
    else
        local n = tonumber(text)
        if not text:match("^%d+$") or not n or n < 1 or n > 100 then
            return nil, "Enter a whole percentage from 1 to 100, or leave the field empty."
        end
        if n ~= 70 then db.playerThresholdPercent = n end
    end
    db.requireLivingTarget = Setup.draft.requireLivingTarget and true or nil
    if Setup.draft.groupAuras then
        db.groupAuras = nil
    else
        db.groupAuras = false
    end
    if not Setup.draft.alwaysShowDebuffs then db.alwaysShowDebuffs = false end
    if not Setup.draft.showPlayerFrameInParty then db.showPlayerFrameInParty = false end
    if not Setup.draft.forceFramesInInstance then db.forceFramesInInstance = false end
    if Setup.draft.chat then
        db.chat = nil
    else
        db.chat = false
    end
    if Setup.draft.chatFade == 10 then
        db.chatFade = nil
    else
        db.chatFade = Setup.draft.chatFade
    end
    if Setup.draft.range then
        local spell = type(Setup.draft.rangeSpell) == "string" and Setup.draft.rangeSpell:match("^%s*(.-)%s*$") or ""
        db.range = {
            yards = Setup.draft.rangeYards or "spell",
            kind = Setup.draft.rangeKind == "friendly" and "friendly" or "hostile",
        }
        if spell ~= "" then db.range.spell = spell end
    else
        db.range = nil
    end
    local groups
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = Setup.draft.groups[row.id]
        if n ~= row.group then
            groups = groups or {}
            groups[row.id] = n
        end
    end
    db.groups = groups
    db.hostile = SavedFlags(Setup.draft.hostile)
    db.friendly = SavedFlags(Setup.draft.friendly)
    if Setup.presetName then db.forceLayout = nil end
    return db
end

local function Write()
    local settings, err = DraftSettings()
    if not settings then ns.Print(err); return end
    if Setup.presetName then
        if not Setup.presetLayout then ns.Print("Choose an Edit Mode layout before saving."); return end
        local id, err = ns.SavePreset(Setup.selectedPresetId, Setup.presetName, Setup.presetLayout, settings)
        if not id then ns.Print(err); return end
        if ns.CommitLayoutPreview then ns.CommitLayoutPreview(true) end
        ns.ActivatePreset(id)
    else
        if ns.CancelLayoutPreview then ns.CancelLayoutPreview() end
        ns.ActivatePreset(nil, settings)
    end
    Setup.LoadSavedDraft()
    Setup.Paint()
    if ns.LayoutSettingsChanged then ns.LayoutSettingsChanged() end
    if ns.ApplyAll then ns.ApplyAll() end
end
Setup.Write = Write
