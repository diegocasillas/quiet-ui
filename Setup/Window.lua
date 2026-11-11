local _, ns = ...
local Setup = ns.Setup or {}
ns.Setup = Setup

local TABS = {
    { id = "general", label = "General", height = 264 },
    { id = "visible", label = "Visible", height = 290 },
    { id = "bars", label = "Bars", height = 308 },
    { id = "groups", label = "Groups", height = 320 },
    { id = "player", label = "Player", height = 292 },
    { id = "chat", label = "Chat", height = 72 },
    { id = "info", label = "Info", height = 148 },
}

-- Portrait frame needs room under the portrait. Gold dialog needs room inside the thick edge.
local CHROME = {
    portrait = { width = 612, side = 26, tabY = -74, pageY = -102, footer = 52, buttonY = 16 },
    gold = { width = 636, side = 38, tabY = -56, pageY = -88, footer = 64, buttonY = 28, titleY = -30, closeX = -18, closeY = -16 },
    flat = { width = 592, side = 16, tabY = -40, pageY = -76, footer = 52, buttonY = 16, titleY = -14, closeX = -10, closeY = -10 },
}

local function MaxPage()
    local max = 0
    for _, info in ipairs(TABS) do
        if info.height > max then max = info.height end
    end
    return max
end

local function TabButton(parent, text, width, onClick)
    local button = Setup.Backdropped("Button", nil, parent)
    button:SetSize(width, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.15)
    button:SetScript("OnClick", onClick)
    return button
end

local function Page(parent, id, height, metrics)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(Setup.CONTENT_W, height)
    page:SetPoint("TOPLEFT", metrics.side, metrics.pageY)
    page:SetFrameLevel(parent:GetFrameLevel() + 20)
    page:Hide()
    return page
end

local function ShowPage(widget, id)
    if widget.presetMenu then widget.presetMenu:Hide() end
    widget.page = id
    for _, page in ipairs(widget.pages) do
        if page.id == id then page:Show() else page:Hide() end
    end
    Setup.Paint()
end

local function EnsureEscape(widget)
    local name = widget:GetName()
    if not name or not UISpecialFrames then return end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = name
end

local function ApplyTitle(widget, text)
    if widget.SetTitle then
        local ok = pcall(widget.SetTitle, widget, text)
        if ok then return end
    end
    local title = widget.TitleText
    if not title and widget.TitleContainer then
        title = widget.TitleContainer.TitleText
    end
    if title and title.SetText then
        title:SetText(text)
    end
end

local function ApplyPortrait(widget)
    pcall(function()
        if widget.SetPortraitToUnit then
            widget:SetPortraitToUnit("player")
            return
        end
        if type(SetPortraitTexture) ~= "function" then return end
        local texture = widget.portrait
        if not texture and widget.PortraitContainer then
            texture = widget.PortraitContainer.portrait
        end
        if texture then
            SetPortraitTexture(texture, "player")
        end
    end)
end

local function GoldWindow(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        widget:SetBackdropColor(1, 1, 1, 1)
        widget:SetBackdropBorderColor(1, 1, 1, 1)
    end)
    return ok
end

local function CloseButton(parent, metrics)
    local button = Setup.Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button:SetPoint("TOPRIGHT", metrics.closeX, metrics.closeY)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText("X")
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", function()
        parent:Hide()
    end)
    return button
end

local function PortraitChrome(widget)
    return widget.SetTitle or widget.TitleText or widget.TitleContainer
        or widget.PortraitContainer or widget.portrait
end

local function SelectMenu(owner, key, anchor, entries)
    local menu = owner[key]
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = Setup.Backdropped("Frame", nil, owner)
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel(owner:GetFrameLevel() + 60)
        Setup.Flat(menu, 1)
        if menu.SetBackdropBorderColor then menu:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.7) end
        menu:EnableMouse(true)
        menu.items = {}
        owner[key] = menu
    end
    for _, item in ipairs(menu.items) do item:Hide() end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    menu:SetSize(300, 12 + 28 * math.min(#entries, 8))
    if not menu.scroll then
        menu.scroll = CreateFrame("ScrollFrame", nil, menu)
        menu.scroll:SetPoint("TOPLEFT", 6, -6)
        menu.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        menu.content = CreateFrame("Frame", nil, menu.scroll)
        menu.content:SetWidth(288)
        menu.scroll:SetScrollChild(menu.content)
        menu.scroll:EnableMouseWheel(true)
        menu.scroll:SetScript("OnMouseWheel", function(_, delta)
            menu.offset = math.max(0, math.min(menu.maximum or 0, (menu.offset or 0) - delta * 28))
            menu.scroll:SetVerticalScroll(menu.offset)
        end)
    end
    menu.content:SetHeight(math.max(28, #entries * 28))
    menu.maximum = math.max(0, (#entries - 8) * 28)
    menu.offset = 0
    menu.scroll:SetVerticalScroll(0)
    for index, entry in ipairs(entries) do
        local item = menu.items[index]
        if not item then
            item = CreateFrame("Button", nil, menu.content)
            item:RegisterForClicks("LeftButtonUp")
            item.label = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            item.label:SetPoint("LEFT", 18, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            item.selected = item:CreateTexture(nil, "BACKGROUND")
            item.selected:SetAllPoints()
            item.selected:SetColorTexture(0.95, 0.75, 0.25, 0.12)
            item.mark = item:CreateTexture(nil, "ARTWORK")
            item.mark:SetSize(2, 14)
            item.mark:SetPoint("LEFT", 6, 0)
            item.mark:SetColorTexture(0.95, 0.75, 0.25, 1)
            local hover = item:CreateTexture(nil, "HIGHLIGHT")
            hover:SetAllPoints()
            hover:SetColorTexture(0.95, 0.75, 0.25, 0.16)
            menu.items[index] = item
        end
        item:SetSize(288, 26)
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 0, -(index - 1) * 28)
        Setup.ButtonText(item, entry.name)
        if entry.selected then
            item.selected:Show()
            item.mark:Show()
            item.label:SetTextColor(0.95, 0.75, 0.25)
        else
            item.selected:Hide()
            item.mark:Hide()
            item.label:SetTextColor(0.9, 0.9, 0.9)
        end
        item:SetScript("OnClick", function() menu:Hide(); entry.select() end)
        item:Show()
    end
    menu:Show()
end

local function PresetDialog(owner, title, text, accept)
    local dialog = owner.presetDialog
    if not dialog then
        local blocker = CreateFrame("Frame", nil, owner)
        blocker:SetAllPoints(owner)
        blocker:SetFrameLevel(owner:GetFrameLevel() + 75)
        blocker:EnableMouse(true)
        local ok, widget = pcall(CreateFrame, "Frame", nil, blocker, "PortraitFrameTemplate")
        local side, bodyY, editY, buttonY = 26, -96, -154, 18
        if ok and widget and PortraitChrome(widget) then
            dialog = widget
            ApplyTitle(dialog, "Shared preset")
            ApplyPortrait(dialog)
            dialog:SetSize(420, 244)
        else
            dialog = ok and widget or Setup.Backdropped("Frame", nil, blocker)
            if GoldWindow(dialog) then
                side, bodyY, editY, buttonY = 28, -56, -114, 28
                dialog:SetSize(420, 214)
            else
                Setup.Flat(dialog, 1)
                side, bodyY, editY, buttonY = 16, -40, -98, 16
                dialog:SetSize(380, 186)
            end
            dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            dialog.title:SetText("Shared preset")
            dialog.title:SetPoint("TOP", 0, -26)
        end
        dialog.blocker = blocker
        dialog:SetScript("OnHide", function() blocker:Hide() end)
        dialog:SetPoint("CENTER")
        dialog:SetFrameLevel(owner:GetFrameLevel() + 80)
        dialog:EnableMouse(true)
        local close = dialog.CloseButton or dialog.closeButton
        if close then close:SetScript("OnClick", function() dialog:Hide() end) end
        dialog.body = Setup.Body(dialog, "")
        local contentWidth = (side == 16 and 380 or 420) - 2 * side
        dialog.body:SetWidth(contentWidth)
        dialog.body:SetPoint("TOPLEFT", side, bodyY)
        dialog.edit = Setup.Backdropped("EditBox", nil, dialog)
        if not Setup.GoldEdge(dialog.edit) then Setup.Flat(dialog.edit, 1) end
        dialog.edit:SetSize(contentWidth, 24)
        dialog.edit:SetPoint("TOPLEFT", side, editY)
        dialog.edit:SetFontObject("GameFontHighlightSmall")
        dialog.edit:SetAutoFocus(false)
        dialog.edit:SetMaxLetters(64)
        dialog.edit:SetTextInsets(6, 6, 0, 0)
        dialog.edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
        dialog.edit:SetScript("OnEnterPressed", function() dialog.yes:GetScript("OnClick")() end)
        dialog.yes = Setup.ActionButton(dialog, "Confirm", function() end)
        dialog.yes:SetPoint("BOTTOMRIGHT", -side, buttonY)
        dialog.no = Setup.ActionButton(dialog, "Cancel", function() dialog:Hide() end)
        dialog.no:SetPoint("BOTTOMLEFT", side, buttonY)
        owner.presetDialog = dialog
    end
    dialog.body:SetText(title)
    if text ~= nil then dialog.edit:SetText(text); dialog.edit:Show() else dialog.edit:Hide() end
    dialog.yes:SetScript("OnClick", function()
        local ok, err = accept(dialog.edit:GetText())
        if ok then dialog:Hide(); Setup.Paint() else dialog.body:SetText(err) end
    end)
    if owner.presetMenu then owner.presetMenu:Hide() end
    dialog.blocker:Show()
    dialog:Show()
    if text ~= nil then dialog.edit:SetFocus(); dialog.edit:HighlightText() end
end

local function CreateSetup()
    local ok, widget = pcall(CreateFrame, "Frame", "PuroCineSetup", UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and widget and PortraitChrome(widget) then
        kind = "portrait"
        widget._puroCinePortrait = true
        ApplyTitle(widget, "Puro Cine")
        ApplyPortrait(widget)
    else
        if not (ok and widget) then
            widget = Setup.Backdropped("Frame", "PuroCineSetup", UIParent)
        end
        if GoldWindow(widget) then
            kind = "gold"
        else
            Setup.Flat(widget, 0.9)
        end
    end
    local metrics = CHROME[kind]
    widget:ClearAllPoints()
    widget:SetSize(metrics.width, -metrics.pageY + MaxPage() + metrics.footer)
    widget:SetPoint("CENTER")
    widget:SetFrameStrata("DIALOG")
    widget:EnableMouse(true)
    widget:Hide()
    EnsureEscape(widget)

    if kind ~= "portrait" then
        widget.title = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        widget.title:SetText("Puro Cine")
        widget.title:SetPoint("TOP", 0, metrics.titleY)
        widget.close = CloseButton(widget, metrics)
    end

    widget.tabs = {}
    widget.pages = {}
    -- Keep every tab on one centered row.
    local tabW, gap = 68, 4
    local total = #TABS * tabW + (#TABS - 1) * gap
    local x = -total / 2
    for _, info in ipairs(TABS) do
        local id = info.id
        local tab = TabButton(widget, info.label, tabW, function()
            ShowPage(widget, id)
        end)
        tab.id = id
        tab:SetFrameLevel(widget:GetFrameLevel() + 20)
        tab:SetPoint("TOP", widget, "TOP", x + tabW / 2, metrics.tabY)
        x = x + tabW + gap
        widget.tabs[#widget.tabs + 1] = tab
        widget.pages[#widget.pages + 1] = Page(widget, id, info.height, metrics)
    end

    local general = widget.pages[1]
    widget.presetHeader = Setup.Section(general, "Shared preset")
    widget.presetHeader:SetPoint("TOPLEFT", general, "TOPLEFT", 0, 0)
    widget.presetSelector = Setup.ActionButton(general, "<no preset>", function()
        local entries = { { name = "<no preset>", selected = Setup.presetName == nil, select = function()
            Setup.selectedPresetId, Setup.presetName = nil, nil
            Setup.Paint()
        end } }
        for _, item in ipairs(ns.PresetList()) do
            local id = item.id
            entries[#entries + 1] = { name = item.name, selected = Setup.selectedPresetId == id, select = function()
                local preset = ns.Presets()[id]
                if not preset then return end
                Setup.ReadDraft(preset.settings)
                Setup.selectedPresetId, Setup.presetName = id, preset.name
                Setup.Paint()
            end }
        end
        SelectMenu(widget, "presetMenu", widget.presetSelector, entries)
    end)
    widget.presetSelector:SetSize(Setup.CONTENT_W, 24)
    widget.presetSelector:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -24)
    widget.newPreset = Setup.ActionButton(general, "New preset", function()
        PresetDialog(widget, "Name the new shared preset.", "", function(name)
            local valid, err = ns.PresetName(name)
            if not valid then return false, err end
            Setup.selectedPresetId, Setup.presetName = nil, valid
            return true
        end)
    end)
    widget.newPreset:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -58)
    widget.renamePreset = Setup.ActionButton(general, "Rename", function()
        PresetDialog(widget, "Rename this shared preset.", Setup.presetName, function(name)
            local valid, err = ns.PresetName(name, Setup.selectedPresetId)
            if not valid then return false, err end
            Setup.presetName = valid
            return true
        end)
    end)
    widget.renamePreset:SetPoint("TOPLEFT", general, "TOPLEFT", (Setup.CONTENT_W - 112) / 2, -58)
    widget.deletePreset = Setup.ActionButton(general, "Delete", function()
        local id = Setup.selectedPresetId
        if not id then return end
        PresetDialog(widget, 'Delete "' .. Setup.presetName .. '" for all characters? They will keep their last settings.', nil, function()
            ns.DeletePreset(id)
            Setup.LoadSavedDraft()
            if ns.ApplyAll then ns.ApplyAll() end
            return true
        end)
    end)
    widget.deletePreset:SetPoint("TOPRIGHT", general, "TOPRIGHT", 0, -58)
    widget.presetHelp = Setup.Body(general, "Save updates the selected preset for every character. Without a preset, settings belong to this character.")
    widget.presetHelp:SetWidth(Setup.CONTENT_W)
    widget.presetHelp:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -104)

    widget.camera = Setup.Section(general, "Camera")
    widget.camera:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -144)
    widget.combatZoom = Setup.Choice(general, "Combat distance", function()
        Setup.draft.combatZoom = not Setup.draft.combatZoom
        Setup.Paint()
    end)
    widget.combatZoom:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -190)
    widget.combatZoomPercent = Setup.PercentField(general, "% of the farthest zoom", "combatZoomPercent")
    widget.combatZoomPercent:SetSize(220, 22)
    widget.combatZoomPercent:SetPoint("TOPLEFT", general, "TOPLEFT", 240, -190)
    widget.combatZoomPercent.edit:SetSize(52, 22)
    widget.combatZoomPercent.edit:ClearAllPoints()
    widget.combatZoomPercent.edit:SetPoint("LEFT", 0, 0)
    widget.combatZoomPercent.label:ClearAllPoints()
    widget.combatZoomPercent.label:SetPoint("LEFT", widget.combatZoomPercent.edit, "RIGHT", 6, 0)
    widget.defaultZoom = Setup.Choice(general, "Default distance", function()
        Setup.draft.defaultZoom = not Setup.draft.defaultZoom
        Setup.Paint()
    end)
    widget.defaultZoom:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -164)
    widget.defaultZoomPercent = Setup.PercentField(general, "% of the farthest zoom", "defaultZoomPercent")
    widget.defaultZoomPercent:SetSize(220, 22)
    widget.defaultZoomPercent:SetPoint("TOPLEFT", general, "TOPLEFT", 240, -164)
    widget.defaultZoomPercent.edit:SetSize(52, 22)
    widget.defaultZoomPercent.edit:ClearAllPoints()
    widget.defaultZoomPercent.edit:SetPoint("LEFT", 0, 0)
    widget.defaultZoomPercent.label:ClearAllPoints()
    widget.defaultZoomPercent.label:SetPoint("LEFT", widget.defaultZoomPercent.edit, "RIGHT", 6, 0)
    widget.rememberZoom = Setup.Choice(general, "After combat, return to my previous distance (off: the default)", function()
        Setup.draft.rememberZoom = not Setup.draft.rememberZoom
        Setup.Paint()
    end)
    widget.rememberZoom:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -216)
    widget.testZoomPercent = Setup.PercentField(general, "% of the farthest zoom", "testZoomPercent")
    widget.testZoomPercent:SetSize(220, 22)
    widget.testZoomPercent:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -242)
    widget.testZoomPercent.edit:SetSize(52, 22)
    widget.testZoomPercent.edit:ClearAllPoints()
    widget.testZoomPercent.edit:SetPoint("LEFT", 0, 0)
    widget.testZoomPercent.label:ClearAllPoints()
    widget.testZoomPercent.label:SetPoint("LEFT", widget.testZoomPercent.edit, "RIGHT", 6, 0)
    widget.testZoom = Setup.ActionButton(general, "Test zoom", function()
        local text = (Setup.draft.testZoomPercent or ""):match("^%s*(.-)%s*$")
        local n = tonumber(text)
        if not text:match("^%d+$") or not n or n < 1 or n > 100 then
            ns.Print("Enter a whole percentage from 1 to 100 to test.")
            return
        end
        if ns.TestZoom then ns.TestZoom(n) end
    end)
    widget.testZoom:SetPoint("TOPLEFT", general, "TOPLEFT", 250, -241)
    widget.testZoomBack = Setup.ActionButton(general, "Back", function()
        if ns.EndZoomTest then ns.EndZoomTest() end
    end)
    widget.testZoomBack:SetSize(72, 22)
    widget.testZoomBack:SetPoint("LEFT", widget.testZoom, "RIGHT", 8, 0)

    local visible = widget.pages[2]
    widget.always = Setup.Section(visible, "Visibility")
    widget.always:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, 0)
    local alwaysHeader = Setup.ColumnLabel(visible, "Always visible")
    alwaysHeader:SetPoint("TOP", visible, "TOPLEFT", 380, 0)
    local hoverHeader = Setup.ColumnLabel(visible, "Only on hover")
    hoverHeader:SetPoint("TOP", visible, "TOPLEFT", 484, 0)
    widget.rows = {}
    local y = -20
    for _, info in ipairs(Setup.ROWS) do
        local key = info.key
        local row = CreateFrame("Frame", nil, visible)
        row:SetSize(Setup.CONTENT_W, 22)
        row.label = Setup.Body(row, info.label)
        row.label:SetWidth(308)
        row.label:SetPoint("LEFT", 2, 0)
        row.always = Setup.TargetBox(row, function()
            Setup.draft[key] = not Setup.draft[key]
            if Setup.draft[key] then Setup.draft.hoverOnly[key] = false end
            Setup.Paint()
        end)
        row.hover = Setup.TargetBox(row, function()
            Setup.draft.hoverOnly[key] = not Setup.draft.hoverOnly[key]
            if Setup.draft.hoverOnly[key] then Setup.draft[key] = false end
            Setup.Paint()
        end)
        row.always:SetPoint("CENTER", row, "LEFT", 380, 0)
        row.hover:SetPoint("CENTER", row, "LEFT", 484, 0)
        row.key = key
        row:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y)
        y = y - 24
        widget.rows[#widget.rows + 1] = row
    end

    widget.forceFramesInInstance = Setup.Choice(visible, "Force frames in instance", function()
        Setup.draft.forceFramesInInstance = not Setup.draft.forceFramesInInstance
        Setup.Paint()
    end)
    widget.forceFramesInInstance:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y - 24)
    widget.letterbox = Setup.Choice(visible, "Letterbox", function()
        Setup.draft.letterbox = not Setup.draft.letterbox
        Setup.Paint()
    end)
    widget.letterbox:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y - 48)

    local bars = widget.pages[3]
    widget.groupHeader = Setup.Section(bars, "Fade together")
    widget.groupHeader:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, 0)
    widget.groupRows = {}
    y = -20
    for _, info in ipairs(ns.BAR_ROWS) do
        local id = info.id
        local row = Setup.Stepper(bars, info.label, function(sign)
            Setup.NudgeGroup(id, sign)
        end)
        row.id = id
        row.hostile = Setup.TargetBox(row, function()
            Setup.draft.hostile[id] = not Setup.draft.hostile[id]
            Setup.Paint()
        end)
        row.friendly = Setup.TargetBox(row, function()
            Setup.draft.friendly[id] = not Setup.draft.friendly[id]
            Setup.Paint()
        end)
        row.friendly:SetPoint("RIGHT", row.minus, "LEFT", -8, 0)
        row.hostile:SetPoint("RIGHT", row.friendly, "LEFT", -4, 0)
        -- Spans the stepper so the column title uses the button top, same as Enemy and Friend.
        row.step = CreateFrame("Frame", nil, row)
        row.step:SetPoint("TOPLEFT", row.minus, "TOPLEFT", 0, 0)
        row.step:SetPoint("BOTTOMRIGHT", row.plus, "BOTTOMRIGHT", 0, 0)
        row:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, y)
        y = y - 24
        widget.groupRows[#widget.groupRows + 1] = row
    end
    local first = widget.groupRows[1]
    widget.enemyHeader = Setup.ColumnLabel(bars, "Enemy")
    widget.friendHeader = Setup.ColumnLabel(bars, "Friend")
    widget.groupColumn = Setup.ColumnLabel(bars, "Group")
    -- The first row starts 20px under "Fade together", so these titles share that line.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 20)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 20)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 20)

    local groups = widget.pages[4]
    widget.visibilityHeader = Setup.Section(groups, "Group visibility")
    widget.visibilityHeader:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, 0)
    local groupAlwaysHeader = Setup.ColumnLabel(groups, "Always visible")
    groupAlwaysHeader:SetPoint("TOP", groups, "TOPLEFT", 380, 0)
    local groupHoverHeader = Setup.ColumnLabel(groups, "Only on hover")
    groupHoverHeader:SetPoint("TOP", groups, "TOPLEFT", 484, 0)
    widget.groupScroll = CreateFrame("ScrollFrame", nil, groups)
    widget.groupScroll:SetSize(Setup.CONTENT_W - 28, Setup.GROUP_VIEW_H)
    widget.groupScroll:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24)
    widget.groupContent = CreateFrame("Frame", nil, widget.groupScroll)
    widget.groupContent:SetSize(Setup.CONTENT_W - 28, 1)
    widget.groupScroll:SetScrollChild(widget.groupContent)
    local function ScrollGroups(delta)
        local max = math.max(0, widget.groupContent:GetHeight() - Setup.GROUP_VIEW_H)
        widget.groupScroll:SetVerticalScroll(math.max(0, math.min(max,
            widget.groupScroll:GetVerticalScroll() + delta)))
    end
    widget.groupScroll:EnableMouseWheel(true)
    widget.groupScroll:SetScript("OnMouseWheel", function(_, delta) ScrollGroups(-delta * 44) end)
    widget.groupUp = Setup.Mini(groups, "^", function() ScrollGroups(-44) end)
    widget.groupUp:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24)
    widget.groupDown = Setup.Mini(groups, "v", function() ScrollGroups(44) end)
    widget.groupDown:SetPoint("TOPRIGHT", groups, "TOPRIGHT", 0, -24 - Setup.GROUP_VIEW_H + 22)
    widget.visibilityRows = {}
    for group = 1, #ns.BAR_ROWS do
        local id = group
        local row = CreateFrame("Frame", nil, widget.groupContent)
        row:SetSize(Setup.CONTENT_W - 28, 44)
        row.label = Setup.Section(row, "Group " .. id)
        row.label:SetPoint("TOPLEFT", 2, -2)
        row.members = Setup.Body(row, "")
        row.members:SetWidth(308)
        row.members:SetPoint("TOPLEFT", 2, -18)
        row.always = Setup.TargetBox(row, function()
            Setup.draft.groupVisibility[id] = Setup.draft.groupVisibility[id] ~= "always" and "always" or nil
            Setup.Paint()
        end)
        row.hover = Setup.TargetBox(row, function()
            Setup.draft.groupVisibility[id] = Setup.draft.groupVisibility[id] ~= "hover" and "hover" or nil
            Setup.Paint()
        end)
        row.always:SetPoint("CENTER", row, "TOPLEFT", 380, -16)
        row.hover:SetPoint("CENTER", row, "TOPLEFT", 484, -16)
        widget.visibilityRows[group] = row
    end
    local help = Setup.Body(groups, "Both unchecked: usual rules. Edit Mode and Full glance still show hover-only frames.")
    help:SetPoint("TOPLEFT", groups, "TOPLEFT", 0, -24 - Setup.GROUP_VIEW_H - 10)

    local player = widget.pages[5]
    widget.player = Setup.Section(player, "Player frame")
    widget.player:SetPoint("TOPLEFT", player, "TOPLEFT", 0, 0)
    widget.playerRow = Setup.Choice(player, "Player frame", function()
        Setup.draft.player = not Setup.draft.player
        Setup.Paint()
    end)
    widget.playerRow:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -20)
    widget.playerThresholdKind = Setup.Stepper(player, "Show below", function()
        Setup.draft.playerThresholdKind = Setup.draft.playerThresholdKind == "resource" and "health" or "resource"
        Setup.Paint()
    end)
    widget.playerThresholdKind:SetSize(240, 22)
    widget.playerThresholdKind:SetPoint("TOPLEFT", player, "TOPLEFT", 24, -50)
    widget.playerThresholdKind.value:SetWidth(92)
    widget.playerThresholdPercent = Setup.PercentField(player, "%", "playerThresholdPercent")
    widget.playerThresholdPercent:SetSize(72, 22)
    widget.playerThresholdPercent:SetPoint("TOPLEFT", widget.playerThresholdKind, "TOPRIGHT", 12, 0)
    widget.playerThresholdPercent.edit:SetSize(52, 22)
    widget.playerThresholdPercent.edit:ClearAllPoints()
    widget.playerThresholdPercent.edit:SetPoint("LEFT", 0, 0)
    widget.playerThresholdPercent.label:ClearAllPoints()
    widget.playerThresholdPercent.label:SetPoint("LEFT", widget.playerThresholdPercent.edit, "RIGHT", 4, 0)
    widget.groupAuras = Setup.Choice(player, "Group buffs and debuffs with player frame", function()
        Setup.draft.groupAuras = not Setup.draft.groupAuras
        Setup.Paint()
    end)
    widget.groupAuras:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -84)
    widget.requireLivingTarget = Setup.Choice(player, "Require a living target for player and target frames", function()
        Setup.draft.requireLivingTarget = not Setup.draft.requireLivingTarget
        Setup.Paint()
    end)
    widget.requireLivingTarget:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -112)
    widget.alwaysShowDebuffs = Setup.Choice(player, "Always show debuffs", function()
        Setup.draft.alwaysShowDebuffs = not Setup.draft.alwaysShowDebuffs
        Setup.Paint()
    end)
    widget.alwaysShowDebuffs:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -140)
    widget.showPlayerFrameInParty = Setup.Choice(player, "Always show player frame in party", function()
        Setup.draft.showPlayerFrameInParty = not Setup.draft.showPlayerFrameInParty
        Setup.Paint()
    end)
    widget.showPlayerFrameInParty:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -164)
    widget.rangeHeader = Setup.Section(player, "Range")
    widget.rangeHeader:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -190)
    widget.range = Setup.Choice(player, "In range", function()
        Setup.draft.range = not Setup.draft.range
        Setup.Paint()
    end)
    widget.range:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -210)
    widget.rangeYards = Setup.Stepper(player, "Within", function(sign)
        Setup.NudgeRangeYards(sign)
    end)
    widget.rangeYards:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -234)
    widget.rangeYards.value:SetWidth(92)
    widget.rangeKind = Setup.Stepper(player, "Who", function()
        Setup.NudgeRangeKind()
    end)
    widget.rangeKind:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -258)
    widget.rangeKind.value:SetWidth(92)
    widget.rangeSpell = Setup.SpellField(player)
    widget.rangeSpell:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -282)

    local chat = widget.pages[6]
    widget.chatHeader = Setup.Section(chat, "Chat")
    widget.chatHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
    widget.chat = Setup.Choice(chat, "Modern chat", function()
        Setup.draft.chat = not Setup.draft.chat
        Setup.Paint()
    end)
    widget.chat:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -20)
    widget.fade = Setup.Stepper(chat, "Fade after", function(sign)
        Setup.NudgeFade(sign * 5)
    end)
    widget.fade:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -44)

    local info = widget.pages[7]
    widget.about = Setup.Section(info, "About")
    widget.about:SetPoint("TOPLEFT", info, "TOPLEFT", 0, 0)
    widget.aboutBody = Setup.Body(info, "While you explore, fewer frames stay on screen. They come back when you need them: talking to someone, a quest, a dungeon, or PvP.")
    widget.aboutBody:SetPoint("TOPLEFT", widget.about, "BOTTOMLEFT", 0, -4)
    widget.glanceHeader = Setup.Section(info, "Glance")
    widget.glanceHeader:SetPoint("TOPLEFT", widget.aboutBody, "BOTTOMLEFT", 0, -12)
    widget.glanceBody = Setup.Body(info, "Press ` to show what has faded. Press it again and the choices on the other tabs apply. Full glance (no default key) also shows what is set to Only on hover; pressing one while the other is on swaps to it. Change the keys under Puro Cine in Key Bindings. You can also use /purocine glance and /purocine glance full in a macro for your controller.")
    widget.glanceBody:SetPoint("TOPLEFT", widget.glanceHeader, "BOTTOMLEFT", 0, -4)

    widget.reset = Setup.ActionButton(widget, "Reset default", function()
        ns.ActivatePreset(nil, {})
        Setup.LoadSavedDraft()
        Setup.Paint()
        if ns.ApplyAll then ns.ApplyAll() end
    end)
    widget.save = Setup.ActionButton(widget, "Save", function()
        Setup.Write()
    end)
    widget.reset:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.save:SetFrameLevel(widget:GetFrameLevel() + 20)

    widget.reset:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    widget.save:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    widget:SetScript("OnHide", function()
        if ns.EndZoomTest then ns.EndZoomTest() end
        for _, key in ipairs({ "presetMenu", "presetDialog" }) do
            if widget[key] then widget[key]:Hide() end
        end
    end)
    ShowPage(widget, "general")
    return widget
end

function ns.RefreshSetup()
    if not Setup.frame or not Setup.frame:IsShown() then return end
    for _, key in ipairs({ "presetMenu", "presetDialog" }) do
        if Setup.frame[key] then Setup.frame[key]:Hide() end
    end
    Setup.LoadSavedDraft()
    Setup.Paint()
end

function ns.ShowSetup()
    Setup.frame = Setup.frame or CreateSetup()
    Setup.LoadSavedDraft()
    if Setup.frame._puroCinePortrait then
        ApplyPortrait(Setup.frame)
    end
    Setup.frame:Show()
    ShowPage(Setup.frame, Setup.frame.page or "general")
end
