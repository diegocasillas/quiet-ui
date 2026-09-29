local _, ns = ...

-- One window, six tabs: the layout, what stays visible, which bars fade together and for which target, the player frame, chat, and a short description with Glance.
-- The frame is named so UISpecialFrames can close it on Escape.
-- The window keeps the tallest page, so switching tabs does not resize it.

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
    { key = "micro", label = "Micro menu" },
}

local CONTENT_W = 428
-- Bottom-left of the minimap, clear of the tracking button.
local MINIMAP_ANGLE = 225

local draft = {}
local frame
local minimapButton
local minimapHooked

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

-- Missing means on. Only an explicit false leaves buffs on their own.
function ns.GroupAuras()
    return ns.CharDB().groupAuras ~= false
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.ModernChat()
    return ns.CharDB().chat ~= false
end

-- Missing means off. Only an explicit true selects the QuietUI layout when the addon turns on.
function ns.ForceQuietLayout()
    return ns.CharDB().forceLayout == true
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

-- Missing means off. yards is 10, 28, or "spell". kind is "hostile" or "friendly".
-- spell is an optional name. Missing means the longest matching spell on bar 1.
function ns.Range()
    local range = ns.CharDB().range
    if type(range) ~= "table" then return nil end
    local yards = range.yards
    if yards ~= 10 and yards ~= 28 and yards ~= "spell" then return nil end
    local kind = range.kind == "friendly" and "friendly" or "hostile"
    local spell = range.spell
    if type(spell) ~= "string" or ns.IsSecret(spell) then return yards, kind end
    spell = spell:match("^%s*(.-)%s*$")
    if not spell or spell == "" then return yards, kind end
    return yards, kind, spell
end

local function FadeText(seconds)
    if not seconds or seconds <= 0 then return "Stay" end
    return seconds .. " s"
end

local RANGE_YARDS = { 10, 28, "spell" }

local function RangeYardsText(yards)
    if yards == 10 then return "10" end
    if yards == 28 then return "28" end
    return "Spell"
end

local function RangeKindText(kind)
    if kind == "friendly" then return "Friendly" end
    return "Unfriendly"
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

local function Backdropped(kind, name, parent, template)
    if template then
        local ok, widget = pcall(CreateFrame, kind, name, parent, template)
        if ok and widget then return widget end
    end
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end

-- Thin gold edge for the short tabs and steppers. The panel-button template is too tall for them.
local function GoldEdge(widget)
    if not widget.SetBackdrop then return false end
    local ok = pcall(function()
        widget:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 4,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        widget:SetBackdropColor(0.08, 0.06, 0.04, 0.92)
        widget:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
    end)
    return ok
end

local function SkinSmall(button)
    button._quietGold = GoldEdge(button) and true or false
    if not button._quietGold then Flat(button, 0.9) end
    if button._quietGold and button.label and button.label.SetTextColor then
        button.label:SetTextColor(1, 0.82, 0.35)
    end
end

local function PaintBox(box, on)
    if not box then return end
    if box.SetChecked then
        box:SetChecked(on and true or false)
        return
    end
    if not box.check then return end
    if on then box.check:Show() else box.check:Hide() end
end

local function Paint()
    if not frame then return end
    for _, row in ipairs(frame.rows) do
        PaintBox(row.box, draft[row.key])
    end
    if frame.forceLayout then
        PaintBox(frame.forceLayout.box, draft.forceLayout)
    end
    if frame.playerRow then
        PaintBox(frame.playerRow.box, draft.player)
    end
    if frame.groupAuras then
        PaintBox(frame.groupAuras.box, draft.groupAuras)
    end
    if frame.chat then
        PaintBox(frame.chat.box, draft.chat)
    end
    if frame.fade then
        frame.fade.value:SetText(FadeText(draft.chatFade))
    end
    if frame.range then
        PaintBox(frame.range.box, draft.range)
    end
    if frame.rangeYards then
        frame.rangeYards.value:SetText(RangeYardsText(draft.rangeYards))
    end
    if frame.rangeKind then
        frame.rangeKind.value:SetText(RangeKindText(draft.rangeKind))
    end
    if frame.rangeSpell then
        if draft.rangeYards == "spell" then
            frame.rangeSpell:Show()
        else
            if frame.rangeSpell.edit and frame.rangeSpell.edit:HasFocus() then
                frame.rangeSpell.edit:ClearFocus()
            end
            frame.rangeSpell:Hide()
        end
        if frame.rangeSpell.edit and not frame.rangeSpell.edit:HasFocus() then
            local text = draft.rangeSpell or ""
            if frame.rangeSpell.edit:GetText() ~= text then
                frame.rangeSpell.edit:SetText(text)
            end
        end
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
            if tab._quietGold and tab.SetBackdropBorderColor then
                if on then
                    tab:SetBackdropBorderColor(1, 0.86, 0.4, 1)
                else
                    tab:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.85)
                end
            elseif tab.SetBackdropBorderColor then
                if on then
                    tab:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.9)
                else
                    tab:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
                end
            end
            if tab.label and tab.label.SetTextColor then
                if on then
                    tab.label:SetTextColor(1, 0.86, 0.35)
                elseif tab._quietGold then
                    tab.label:SetTextColor(0.85, 0.8, 0.65)
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
    draft.forceLayout = ns.ForceQuietLayout()
    draft.player = ns.PlayerStyle() == "classic"
    draft.groupAuras = ns.GroupAuras()
    draft.chat = ns.ModernChat()
    draft.chatFade = ns.ChatFade()
    local yards, kind, spell = ns.Range()
    draft.range = yards ~= nil
    draft.rangeYards = yards or "spell"
    draft.rangeKind = kind or "hostile"
    draft.rangeSpell = spell or ""
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
    if draft.forceLayout then
        db.forceLayout = true
    else
        db.forceLayout = nil
    end
    if draft.player then
        db.player = nil
    else
        db.player = "resource"
    end
    if draft.groupAuras then
        db.groupAuras = nil
    else
        db.groupAuras = false
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
    if draft.range then
        local spell = type(draft.rangeSpell) == "string" and draft.rangeSpell:match("^%s*(.-)%s*$") or ""
        db.range = {
            yards = draft.rangeYards or "spell",
            kind = draft.rangeKind == "friendly" and "friendly" or "hostile",
        }
        if spell ~= "" then db.range.spell = spell end
    else
        db.range = nil
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
    -- A plain Button also has SetText, so the template has to be the thing that succeeded.
    local ok, button = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if ok and button then
        button:SetSize(112, 22)
        button:SetText(text)
        local label = button.GetFontString and button:GetFontString()
        if label and label.SetFontObject then
            pcall(label.SetFontObject, label, "GameFontNormalSmall")
        end
        button:SetScript("OnClick", onClick)
        return button
    end
    button = Backdropped("Button", nil, parent)
    button:SetSize(112, 22)
    if not GoldEdge(button) then Flat(button, 0.9) end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function CheckMark(parent)
    -- The loose checkbox textures draw only the tick on this client. The template keeps the box.
    local ok, box = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if ok and box and box.SetChecked then
        box:SetSize(22, 22)
        box:EnableMouse(false)
        if box.Text then box.Text:Hide() end
        local text = box.GetFontString and box:GetFontString()
        if text then text:Hide() end
        return box
    end
    box = parent:CreateTexture(nil, "ARTWORK")
    box:SetSize(20, 20)
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box.check = parent:CreateTexture(nil, "OVERLAY")
    box.check:SetAllPoints(box)
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:Hide()
    return box
end

local function Choice(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(CONTENT_W, 22)
    button.box = CheckMark(button)
    button.box:SetPoint("LEFT", 0, 0)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("LEFT", button.box, "RIGHT", 4, 0)
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

local function NudgeRangeYards(sign)
    local index = 3
    for i, yards in ipairs(RANGE_YARDS) do
        if yards == draft.rangeYards then
            index = i
            break
        end
    end
    index = index + sign
    if index < 1 then index = #RANGE_YARDS end
    if index > #RANGE_YARDS then index = 1 end
    draft.rangeYards = RANGE_YARDS[index]
    Paint()
end

local function NudgeRangeKind()
    draft.rangeKind = draft.rangeKind == "friendly" and "hostile" or "friendly"
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
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 22)
    button.box = CheckMark(button)
    button.box:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    return button
end

local function Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 22)
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

-- Empty means bar 1. Escape only leaves the field, so the window stays open.
local function SpellField(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText("Spell")
    local box = Backdropped("EditBox", nil, row)
    box:SetSize(144, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(48)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if box.SetTextColor then box:SetTextColor(1, 0.95, 0.8, 1) end
    local gold = GoldEdge(box)
    if not gold then Flat(box, 0.9) end
    box._quietGold = gold and true or false
    local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 6, 0)
    hint:SetText("Bar 1")
    box.hint = hint
    local function ShowHint(self)
        local text = self:GetText() or ""
        if text == "" and not self:HasFocus() then
            hint:Show()
        else
            hint:Hide()
        end
    end
    box:SetScript("OnTextChanged", function(self)
        draft.rangeSpell = self:GetText() or ""
        ShowHint(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.86, 0.4, 1)
        end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ShowHint(self)
        if self._quietGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
        end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ShowHint(box)
    row.edit = box
    return row
end

local function Section(parent, text)
    -- Gold title only. The old group-indicator bar is the classic paperdoll and collides with the column titles.
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(CONTENT_W, 16)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetText(text)
    return row
end

local function Body(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetWidth(CONTENT_W)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end

local function ColumnLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    return label
end

local TABS = {
    { id = "general", label = "General", height = 48 },
    { id = "visible", label = "Visible", height = 262 },
    { id = "bars", label = "Bars", height = 308 },
    { id = "player", label = "Player", height = 196 },
    { id = "chat", label = "Chat", height = 72 },
    { id = "info", label = "Info", height = 148 },
}

-- Portrait frame needs room under the portrait. Gold dialog needs room inside the thick edge.
local CHROME = {
    portrait = { width = 480, side = 26, tabY = -74, pageY = -102, footer = 52, buttonY = 16 },
    gold = { width = 504, side = 38, tabY = -56, pageY = -88, footer = 64, buttonY = 28, titleY = -30, closeX = -18, closeY = -16 },
    flat = { width = 460, side = 16, tabY = -40, pageY = -76, footer = 52, buttonY = 16, titleY = -14, closeX = -10, closeY = -10 },
}

local function MaxPage()
    local max = 0
    for _, info in ipairs(TABS) do
        if info.height > max then max = info.height end
    end
    return max
end

local function TabButton(parent, text, width, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(width, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.15)
    button:SetScript("OnClick", onClick)
    return button
end

local function Page(parent, id, height, metrics)
    local page = CreateFrame("Frame", nil, parent)
    page.id = id
    page:SetSize(CONTENT_W, height)
    page:SetPoint("TOPLEFT", metrics.side, metrics.pageY)
    page:SetFrameLevel(parent:GetFrameLevel() + 20)
    page:Hide()
    return page
end

local function ShowPage(widget, id)
    widget.page = id
    for _, page in ipairs(widget.pages) do
        if page.id == id then page:Show() else page:Hide() end
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
    local button = Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button:SetPoint("TOPRIGHT", metrics.closeX, metrics.closeY)
    button:SetFrameLevel(parent:GetFrameLevel() + 20)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText("X")
    SkinSmall(button)
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

local function CreateSetup()
    local ok, widget = pcall(CreateFrame, "Frame", "QuietUISetup", UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and widget and PortraitChrome(widget) then
        kind = "portrait"
        widget._quietPortrait = true
        ApplyTitle(widget, "QuietUI")
        ApplyPortrait(widget)
    else
        if not (ok and widget) then
            widget = Backdropped("Frame", "QuietUISetup", UIParent)
        end
        if GoldWindow(widget) then
            kind = "gold"
        else
            Flat(widget, 0.9)
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
        widget.title:SetText("QuietUI")
        widget.title:SetPoint("TOP", 0, metrics.titleY)
        widget.close = CloseButton(widget, metrics)
    end

    widget.tabs = {}
    widget.pages = {}
    -- Six labels on one row. Centered, so a wider gold frame still holds them.
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
    widget.layoutHeader = Section(general, "Layout")
    widget.layoutHeader:SetPoint("TOPLEFT", general, "TOPLEFT", 0, 0)
    widget.forceLayout = Choice(general, "Force QuietUI layout", function()
        draft.forceLayout = not draft.forceLayout
        Paint()
    end)
    widget.forceLayout:SetPoint("TOPLEFT", general, "TOPLEFT", 0, -20)

    local visible = widget.pages[2]
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

    local bars = widget.pages[3]
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
    widget.enemyHeader = ColumnLabel(bars, "Enemy")
    widget.friendHeader = ColumnLabel(bars, "Friend")
    widget.groupColumn = ColumnLabel(bars, "Group")
    -- The first row starts 20px under "Fade together", so these titles share that line.
    widget.enemyHeader:SetPoint("TOP", first.hostile, "TOP", 0, 20)
    widget.friendHeader:SetPoint("TOP", first.friendly, "TOP", 0, 20)
    widget.groupColumn:SetPoint("TOP", first.step, "TOP", 0, 20)

    local player = widget.pages[4]
    widget.player = Section(player, "Player frame")
    widget.player:SetPoint("TOPLEFT", player, "TOPLEFT", 0, 0)
    widget.playerRow = Choice(player, "Player frame", function()
        draft.player = not draft.player
        Paint()
    end)
    widget.playerRow:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -20)
    widget.groupAuras = Choice(player, "Group buffs and debuffs with player frame", function()
        draft.groupAuras = not draft.groupAuras
        Paint()
    end)
    widget.groupAuras:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -44)
    widget.rangeHeader = Section(player, "Range")
    widget.rangeHeader:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -76)
    widget.range = Choice(player, "In range", function()
        draft.range = not draft.range
        Paint()
    end)
    widget.range:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -96)
    widget.rangeYards = Stepper(player, "Within", function(sign)
        NudgeRangeYards(sign)
    end)
    widget.rangeYards:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -120)
    widget.rangeYards.value:SetWidth(48)
    widget.rangeKind = Stepper(player, "Who", function()
        NudgeRangeKind()
    end)
    widget.rangeKind:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -144)
    widget.rangeKind.value:SetWidth(92)
    widget.rangeSpell = SpellField(player)
    widget.rangeSpell:SetPoint("TOPLEFT", player, "TOPLEFT", 0, -168)

    local chat = widget.pages[5]
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

    local info = widget.pages[6]
    widget.about = Section(info, "About")
    widget.about:SetPoint("TOPLEFT", info, "TOPLEFT", 0, 0)
    widget.aboutBody = Body(info, "While you explore, fewer frames stay on screen. They come back when you need them: talking to someone, a quest, a dungeon, or PvP.")
    widget.aboutBody:SetPoint("TOPLEFT", widget.about, "BOTTOMLEFT", 0, -4)
    widget.glanceHeader = Section(info, "Glance")
    widget.glanceHeader:SetPoint("TOPLEFT", widget.aboutBody, "BOTTOMLEFT", 0, -12)
    widget.glanceBody = Body(info, "Press ` to show what has faded. Press it again and the choices on the other tabs apply. Change the key under QuietUI in Key Bindings.")
    widget.glanceBody:SetPoint("TOPLEFT", widget.glanceHeader, "BOTTOMLEFT", 0, -4)

    widget.reset = ActionButton(widget, "Reset default", function()
        local db = ns.CharDB()
        db.visible = nil
        db.forceLayout = nil
        db.player = nil
        db.groupAuras = nil
        db.chat = nil
        db.chatFade = nil
        db.groups = nil
        db.hostile = nil
        db.friendly = nil
        db.range = nil
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
    widget.reset:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.import:SetFrameLevel(widget:GetFrameLevel() + 20)
    widget.save:SetFrameLevel(widget:GetFrameLevel() + 20)

    widget.reset:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    widget.import:SetPoint("BOTTOM", 0, metrics.buttonY)
    widget.save:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    ShowPage(widget, "general")
    return widget
end

function ns.ShowSetup()
    frame = frame or CreateSetup()
    ReadDraft()
    if frame._quietPortrait then
        ApplyPortrait(frame)
    end
    frame:Show()
    ShowPage(frame, frame.page or "general")
end

------------------------------------------------------------------------------
-- Minimap button. Unnamed, parented to Minimap, so the fade walk never sees it.
------------------------------------------------------------------------------

local function MinimapDegrees()
    local n = ns.DB().minimap
    if type(n) ~= "number" or n ~= n then return MINIMAP_ANGLE end
    n = n % 360
    if n < 0 then n = n + 360 end
    return n
end

local function PlaceMinimap(button)
    local map = Minimap
    if not map or not button then return end
    local rad = math.rad(MinimapDegrees())
    local w = map:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = 140 end
    local radius = w / 2 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", map, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function CursorDegrees(map)
    if type(GetCursorPosition) ~= "function" or not map.GetCenter then return nil end
    local scale = map.GetEffectiveScale and map:GetEffectiveScale() or 1
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    local mx, my = map:GetCenter()
    if type(cx) ~= "number" or type(cy) ~= "number" or type(mx) ~= "number" or type(my) ~= "number" then
        return nil
    end
    local angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    if angle < 0 then angle = angle + 360 end
    return angle
end

local function ApplyGear(icon)
    if icon.SetAtlas then
        local ok, result = pcall(icon.SetAtlas, icon, "mechagon-projects")
        if ok and result then return end
    end
    if not icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function CreateMinimap()
    local button = CreateFrame("Button", nil, Minimap)
    button:SetSize(31, 31)
    local level = Minimap:GetFrameLevel()
    button:SetFrameLevel((type(level) == "number" and level or 0) + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    ApplyGear(icon)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnDragStart", function(self)
        self._moved = true
        self:SetScript("OnUpdate", function(owner)
            local angle = CursorDegrees(Minimap)
            if not angle then return end
            ns.DB().minimap = angle
            PlaceMinimap(owner)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnMouseUp", function(self, click)
        if self._moved then
            self._moved = false
            return
        end
        if click == "LeftButton" then
            ns.ShowSetup()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("QuietUI", 1, 1, 1)
        GameTooltip:AddLine("Left click: open setup", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return button
end

function ns.EnsureMinimap()
    if not Minimap then return end
    if not minimapHooked and Minimap.HookScript then
        minimapHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            if minimapButton then PlaceMinimap(minimapButton) end
        end)
    end
    if minimapButton then
        PlaceMinimap(minimapButton)
        minimapButton:Show()
        return
    end
    minimapButton = CreateMinimap()
    PlaceMinimap(minimapButton)
end
