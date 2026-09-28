local _, ns = ...

-- One window, four tabs: what stays visible, which bars fade together and for which target, the player frame, and chat.
-- The frame is named so UISpecialFrames can close it on Escape.

local ROWS = {
    { key = "bars", label = "Action bars" },
    { key = "swing", label = "Swing timer" },
    { key = "xp", label = "XP bar" },
    { key = "cooldowns", label = "Cooldown manager" },
    { key = "meter", label = "Damage meter" },
    { key = "resource", label = "Personal resource" },
    { key = "quests", label = "Quest tracker" },
    { key = "auras", label = "Buffs and debuffs" },
    { key = "menu", label = "Bag button" },
}

local draft = {}
local frame

-- Per character. An older build kept this on the account; the first character
-- to load keeps that copy, then the account keys are dropped.
function ns.CharDB()
    if type(QuietUICharDB) ~= "table" then
        QuietUICharDB = {}
    end
    local account = ns.DB()
    if account.visible ~= nil or account.player ~= nil then
        if QuietUICharDB.visible == nil and QuietUICharDB.player == nil then
            QuietUICharDB.visible = account.visible
            QuietUICharDB.player = account.player
        end
        account.visible = nil
        account.player = nil
    end
    return QuietUICharDB
end

function ns.Pinned(name)
    local visible = ns.CharDB().visible
    return type(visible) == "table" and visible[name] and true or false
end

-- Missing means on. Only an explicit "resource" keeps the portrait for edit mode.
function ns.PlayerStyle()
    if ns.CharDB().player == "resource" then return "resource" end
    return "classic"
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.ModernChat()
    return ns.CharDB().chat ~= false
end

-- Seconds a line stays at the bottom. Missing means 10. 0 keeps the line.
function ns.ChatFade()
    local n = ns.CharDB().chatFade
    if type(n) ~= "number" or n ~= n then return 10 end
    if n <= 0 then return 0 end
    n = math.floor(n)
    if n > 60 then n = 60 end
    return math.floor(n / 5) * 5
end

local function FadeText(seconds)
    if not seconds or seconds <= 0 then return "Stay" end
    return seconds .. " s"
end

local function Flat(widget, alpha)
    if not widget.SetBackdrop then return end
    widget:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    widget:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    widget:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
end

local function Backdropped(kind, name, parent)
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end

local function PaintBox(box, on)
    if not box.SetBackdropColor then return end
    if on then
        box:SetBackdropColor(0.95, 0.75, 0.25, 0.9)
        box:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.9)
    else
        box:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
        box:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
    end
end

local function Paint()
    if not frame then return end
    for _, row in ipairs(frame.rows) do
        PaintBox(row.box, draft[row.key])
    end
    if frame.playerRow then
        PaintBox(frame.playerRow.box, draft.player)
    end
    if frame.chat then
        PaintBox(frame.chat.box, draft.chat)
    end
    if frame.fade then
        frame.fade.value:SetText(FadeText(draft.chatFade))
    end
    if frame.groupRows then
        for _, row in ipairs(frame.groupRows) do
            row.value:SetText(tostring(draft.groups[row.id]))
            PaintBox(row.hostile.box, draft.hostile[row.id])
            PaintBox(row.friendly.box, draft.friendly[row.id])
        end
    end
    if frame.tabs then
        for _, tab in ipairs(frame.tabs) do
            local on = tab.id == frame.page
            if tab.SetBackdropBorderColor then
                if on then
                    tab:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.9)
                else
                    tab:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
                end
            end
            if tab.label and tab.label.SetTextColor then
                if on then
                    tab.label:SetTextColor(0.95, 0.75, 0.25)
                else
                    tab.label:SetTextColor(0.85, 0.85, 0.85)
                end
            end
        end
    end
end

local function ReadDraft()
    for _, row in ipairs(ROWS) do
        draft[row.key] = ns.Pinned(row.key)
    end
    draft.player = ns.PlayerStyle() == "classic"
    draft.chat = ns.ModernChat()
    draft.chatFade = ns.ChatFade()
    draft.groups = {}
    draft.hostile = {}
    draft.friendly = {}
    for _, row in ipairs(ns.BAR_ROWS) do
        draft.groups[row.id] = ns.BarGroup(row.id)
        draft.hostile[row.id] = ns.BarTarget(row.id, "hostile")
        draft.friendly[row.id] = ns.BarTarget(row.id, "friendly")
    end
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

local function Write()
    local db = ns.CharDB()
    local visible
    for _, row in ipairs(ROWS) do
        if draft[row.key] then
            visible = visible or {}
            visible[row.key] = true
        end
    end
    db.visible = visible
    if draft.player then
        db.player = nil
    else
        db.player = "resource"
    end
    if draft.chat then
        db.chat = nil
    else
        db.chat = false
    end
    if draft.chatFade == 10 then
        db.chatFade = nil
    else
        db.chatFade = draft.chatFade
    end
    local groups
    for _, row in ipairs(ns.BAR_ROWS) do
        local n = draft.groups[row.id]
        if n ~= row.group then
            groups = groups or {}
            groups[row.id] = n
        end
    end
    db.groups = groups
    db.hostile = SavedFlags(draft.hostile)
    db.friendly = SavedFlags(draft.friendly)
end

local function ActionButton(parent, text, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(112, 22)
    Flat(button, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function Choice(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(348, 22)
    button.box = Backdropped("Frame", nil, button)
    button.box:SetSize(12, 12)
    button.box:SetPoint("LEFT", 2, 0)
    Flat(button.box, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.box, "RIGHT", 8, 0)
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.12)
    button:SetScript("OnClick", onClick)
    return button
end

local function NudgeFade(delta)
    local n = (draft.chatFade or 10) + delta
    if n < 0 then n = 0 end
    if n > 60 then n = 60 end
    draft.chatFade = n
    Paint()
end

local function NudgeGroup(id, delta)
    local n = (draft.groups[id] or 1) + delta
    local max = #ns.BAR_ROWS
    if n < 1 then n = 1 end
    if n > max then n = max end
    draft.groups[id] = n
    Paint()
end

local function Mini(parent, text, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    Flat(button, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 22)
    button.box = Backdropped("Frame", nil, button)
    button.box:SetSize(12, 12)
    button.box:SetPoint("CENTER")
    Flat(button.box, 0.9)
    button:SetScript("OnClick", onClick)
    return button
end

local function Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(348, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    row.plus = Mini(row, "+", function() onDelta(1) end)
    row.minus = Mini(row, "-", function() onDelta(-1) end)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetWidth(44)
    row.value:SetJustifyH("CENTER")
    row.plus:SetPoint("RIGHT", 0, 0)
    row.value:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
    row.minus:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
    return row
end

local function Section(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText("|cff8fd4c8" .. text .. "|r")
    label:SetJustifyH("LEFT")
    return label
end

local TABS = {
    { id = "visible", label = "Visible", height = 238 },
    { id = "bars", label = "Bars", height = 308 },
    { id = "player", label = "Player", height = 48 },
    { id = "chat", label = "Chat", height = 72 },
}

local function TabButton(parent, text, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(84, 22)
    Flat(button, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.15)
    button:SetScript("OnClick", onClick)
    return button
end

local function Page(parent, id, height)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(348, height)
    page:SetPoint("TOPLEFT", 16, -76)
    page:SetFrameLevel(parent:GetFrameLevel() + 5)
    page:Hide()
    return page
end

local function ShowPage(widget, id)
    widget.page = id
    for _, page in ipairs(widget.pages) do
        if page.id == id then page:Show() else page:Hide() end
    end
    for _, info in ipairs(TABS) do
        if info.id == id then
            widget:SetHeight(76 + info.height + 88)
            break
        end
    end
    Paint()
end

local function EnsureEscape(widget)
    local name = widget:GetName()
    if not name or not UISpecialFrames then return end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return end
    end
    UISpecialFrames[#UISpecialFrames + 1] = name
end

local function CreateSetup()
    local widget = Backdropped("Frame", "QuietUISetup", UIParent)
    widget:SetSize(380, 76 + TABS[1].height + 88)
    widget:SetPoint("CENTER")
    widget:SetFrameStrata("DIALOG")
    widget:EnableMouse(true)
    Flat(widget, 0.9)
    widget:Hide()
    EnsureEscape(widget)

    widget.title = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.title:SetText("|cff8fd4c8QuietUI|r")
    widget.title:SetPoint("TOP", 0, -14)

    widget.close = Backdropped("Button", nil, widget)
    widget.close:SetSize(18, 18)
    widget.close:SetPoint("TOPRIGHT", -10, -10)
    Flat(widget.close, 0.9)
    widget.close.label = widget.close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    widget.close.label:SetPoint("CENTER")
    widget.close.label:SetText("X")
    local closeHighlight = widget.close:CreateTexture(nil, "HIGHLIGHT")
    closeHighlight:SetAllPoints()
    closeHighlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    widget.close:SetScript("OnClick", function()
        widget:Hide()
    end)

    widget.tabs = {}
    widget.pages = {}
    local tabW, gap = 84, 4
    local total = #TABS * tabW + (#TABS - 1) * gap
    local x = -total / 2
    for _, info in ipairs(TABS) do
        local id = info.id
        local tab = TabButton(widget, info.label, function()
            ShowPage(widget, id)
        end)
        tab.id = id
        tab:SetPoint("TOP", widget, "TOP", x + tabW / 2, -40)
        x = x + tabW + gap
        widget.tabs[#widget.tabs + 1] = tab
        widget.pages[#widget.pages + 1] = Page(widget, id, info.height)
    end

    local visible = widget.pages[1]
    widget.always = Section(visible, "Always visible")
    widget.always:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, 0)
    widget.rows = {}
    local y = -20
    for _, info in ipairs(ROWS) do
        local row = Choice(visible, info.label, function()
            draft[info.key] = not draft[info.key]
            Paint()
        end)
        row.key = info.key
        row:SetPoint("TOPLEFT", visible, "TOPLEFT", 0, y)
        y = y - 24
        widget.rows[#widget.rows + 1] = row
    end

    local bars = widget.pages[2]
    widget.groupHeader = Section(bars, "Fade together")
    widget.groupHeader:SetPoint("TOPLEFT", bars, "TOPLEFT", 0, 0)
    widget.groupRows = {}
    y = -20
    for _, info in ipairs(ns.BAR_ROWS) do
        local id = info.id
        local row = Stepper(bars, info.label, function(sign)
            NudgeGroup(id, sign)
        end)
        row.id = id
        row.hostile = TargetBox(row, function()
            draft.hostile[id] = not draft.hostile[id]
            Paint()
        end)
        row.friendly = TargetBox(row, function()
            draft.friendly[id] = not draft.friendly[id]
            Paint()
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
    widget.enemyHeader = Section(bars, "Enemy")
    widget.friendHeader = Section(bars, "Friend")
    widget.groupColumn = Section(bars, "Group")
    -- The first row starts 20px under "Fade together", so these titles share that line.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 20)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 20)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 20)

    local player = widget.pages[3]
    widget.player = Section(player, "Player frame")
    widget.player:SetPoint("TOPLEFT", player, "TOPLEFT", 0, 0)
    widget.playerRow = Choice(player, "Player frame", function()
        draft.player = not draft.player
        Paint()
    end)
    widget.playerRow:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -20)

    local chat = widget.pages[4]
    widget.chatHeader = Section(chat, "Chat")
    widget.chatHeader:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, 0)
    widget.chat = Choice(chat, "Modern chat", function()
        draft.chat = not draft.chat
        Paint()
    end)
    widget.chat:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -20)
    widget.fade = Stepper(chat, "Fade after", function(sign)
        NudgeFade(sign * 5)
    end)
    widget.fade:SetPoint("TOPLEFT", chat, "TOPLEFT", 0, -44)

    widget.reset = ActionButton(widget, "Reset default", function()
        local db = ns.CharDB()
        db.visible = nil
        db.player = nil
        db.chat = nil
        db.chatFade = nil
        db.groups = nil
        db.hostile = nil
        db.friendly = nil
        ReadDraft()
        Paint()
        if ns.ApplyAll then ns.ApplyAll() end
    end)
    widget.import = ActionButton(widget, "Import layout", function()
        ns.ForceLayout()
    end)
    widget.save = ActionButton(widget, "Save", function()
        Write()
        if ns.ApplyAll then ns.ApplyAll() end
    end)

    widget.glance = widget:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    widget.glance:SetWidth(348)
    widget.glance:SetJustifyH("CENTER")
    widget.glance:SetText("Hold ` to look. Letting go follows these rules. Change the key in Key Bindings.")
    widget.glance:SetPoint("BOTTOM", 0, 46)
    widget.reset:SetPoint("BOTTOMLEFT", 16, 16)
    widget.import:SetPoint("BOTTOM", 0, 16)
    widget.save:SetPoint("BOTTOMRIGHT", -16, 16)
    ShowPage(widget, "visible")
    return widget
end

function ns.ShowSetup()
    frame = frame or CreateSetup()
    ReadDraft()
    frame:Show()
    ShowPage(frame, frame.page or "visible")
end
