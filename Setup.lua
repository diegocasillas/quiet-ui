local _, ns = ...

-- One window: what stays visible, and which player frame preset to use.
-- The frame is named so UISpecialFrames can close it on Escape.

local ROWS = {
    { key = "bars", label = "Action bars" },
    { key = "xp", label = "XP bar" },
    { key = "cooldowns", label = "Cooldown manager" },
    { key = "meter", label = "Damage meter" },
    { key = "resource", label = "Personal resource" },
    { key = "quests", label = "Quest tracker" },
    { key = "auras", label = "Buffs and debuffs" },
    { key = "menu", label = "Bag button" },
}

local STYLES = {
    { key = "resource", label = "Personal resource" },
    { key = "classic", label = "Classic" },
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

function ns.PlayerStyle()
    if ns.CharDB().player == "classic" then return "classic" end
    return "resource"
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.ModernChat()
    return ns.CharDB().chat ~= false
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
    for _, row in ipairs(frame.styles) do
        PaintBox(row.box, draft.player == row.key)
    end
    if frame.chat then
        PaintBox(frame.chat.box, draft.chat)
    end
end

local function ReadDraft()
    for _, row in ipairs(ROWS) do
        draft[row.key] = ns.Pinned(row.key)
    end
    draft.player = ns.PlayerStyle()
    draft.chat = ns.ModernChat()
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
    if draft.player == "classic" then
        db.player = "classic"
    else
        db.player = nil
    end
    db.chat = draft.chat and nil or false
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

local function Section(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText("|cff8fd4c8" .. text .. "|r")
    label:SetJustifyH("LEFT")
    return label
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
    widget:SetWidth(380)
    widget:SetPoint("CENTER")
    widget:SetFrameStrata("DIALOG")
    widget:EnableMouse(true)
    Flat(widget, 0.9)
    widget:Hide()
    EnsureEscape(widget)

    widget.title = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    widget.title:SetText("|cff8fd4c8QuietUI|r")

    widget.always = Section(widget, "Always visible")
    widget.rows = {}
    for _, info in ipairs(ROWS) do
        local row = Choice(widget, info.label, function()
            draft[info.key] = not draft[info.key]
            Paint()
        end)
        row.key = info.key
        widget.rows[#widget.rows + 1] = row
    end

    widget.player = Section(widget, "Player frame")
    widget.styles = {}
    for _, info in ipairs(STYLES) do
        local row = Choice(widget, info.label, function()
            draft.player = info.key
            Paint()
        end)
        row.key = info.key
        widget.styles[#widget.styles + 1] = row
    end

    widget.chatHeader = Section(widget, "Chat")
    widget.chat = Choice(widget, "Modern chat", function()
        draft.chat = not draft.chat
        Paint()
    end)

    widget.reset = ActionButton(widget, "Reset default", function()
        local db = ns.CharDB()
        db.visible = nil
        db.player = nil
        db.chat = nil
        ReadDraft()
        Paint()
        if ns.ApplyAll then ns.ApplyAll() end
    end)
    widget.import = ActionButton(widget, "Import layout", function()
        ns.ForceLayout()
    end)
    widget.save = ActionButton(widget, "Save", function()
        Write()
        widget:Hide()
        if ns.ApplyAll then ns.ApplyAll() end
    end)

    local y = -14
    widget.title:SetPoint("TOP", 0, y)
    y = y - 28
    widget.always:SetPoint("TOPLEFT", 16, y)
    y = y - 20
    for _, row in ipairs(widget.rows) do
        row:SetPoint("TOPLEFT", 16, y)
        y = y - 24
    end
    y = y - 6
    widget.player:SetPoint("TOPLEFT", 16, y)
    y = y - 20
    for _, row in ipairs(widget.styles) do
        row:SetPoint("TOPLEFT", 16, y)
        y = y - 24
    end
    y = y - 6
    widget.chatHeader:SetPoint("TOPLEFT", 16, y)
    y = y - 20
    widget.chat:SetPoint("TOPLEFT", 16, y)
    y = y - 24
    widget:SetHeight(-y + 50)
    widget.reset:SetPoint("BOTTOMLEFT", 16, 16)
    widget.import:SetPoint("BOTTOM", 0, 16)
    widget.save:SetPoint("BOTTOMRIGHT", -16, 16)
    return widget
end

function ns.ShowSetup()
    frame = frame or CreateSetup()
    ReadDraft()
    Paint()
    frame:Show()
end
