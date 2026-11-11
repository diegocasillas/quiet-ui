local _, ns = ...
local Setup = ns.Setup or {}
ns.Setup = Setup

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
    button = Setup.Backdropped("Button", nil, parent)
    button:SetSize(112, 22)
    if not Setup.GoldEdge(button) then Setup.Flat(button, 0.9) end
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end
Setup.ActionButton = ActionButton

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
    button:SetSize(Setup.CONTENT_W, 22)
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
Setup.Choice = Choice

local function NudgeFade(delta)
    local n = (Setup.draft.chatFade or 10) + delta
    if n < 0 then n = 0 end
    if n > 60 then n = 60 end
    Setup.draft.chatFade = n
    Setup.Paint()
end
Setup.NudgeFade = NudgeFade

local function NudgeRangeYards(sign)
    local index = 3
    for i, yards in ipairs(Setup.RANGE_YARDS) do
        if yards == Setup.draft.rangeYards then
            index = i
            break
        end
    end
    index = index + sign
    if index < 1 then index = #Setup.RANGE_YARDS end
    if index > #Setup.RANGE_YARDS then index = 1 end
    Setup.draft.rangeYards = Setup.RANGE_YARDS[index]
    Setup.Paint()
end
Setup.NudgeRangeYards = NudgeRangeYards

local function NudgeRangeKind()
    Setup.draft.rangeKind = Setup.draft.rangeKind == "friendly" and "hostile" or "friendly"
    Setup.Paint()
end
Setup.NudgeRangeKind = NudgeRangeKind

local function NudgeGroup(id, delta)
    local n = (Setup.draft.groups[id] or 1) + delta
    local max = #ns.BAR_ROWS
    if n < 1 then n = 1 end
    if n > max then n = max end
    Setup.draft.groups[id] = n
    Setup.Paint()
end
Setup.NudgeGroup = NudgeGroup

local function Mini(parent, text, onClick)
    local button = Setup.Backdropped("Button", nil, parent)
    button:SetSize(22, 22)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    Setup.SkinSmall(button)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end
Setup.Mini = Mini

local function TargetBox(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(44, 22)
    button.box = CheckMark(button)
    button.box:SetPoint("CENTER")
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self)
        if self.mode and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Controlled by Group " .. self.group .. ": "
                .. (self.mode == "hover" and "Only on hover" or "Always visible"))
            GameTooltip:Show()
        end
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    return button
end
Setup.TargetBox = TargetBox

local function Stepper(parent, label, onDelta)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
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
Setup.Stepper = Stepper

-- Empty means bar 1. Escape only leaves the field, so the window stays open.
local function SpellField(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText("Spell")
    local box = Setup.Backdropped("EditBox", nil, row)
    box:SetSize(144, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(48)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if box.SetTextColor then box:SetTextColor(1, 0.95, 0.8, 1) end
    local gold = Setup.GoldEdge(box)
    if not gold then Setup.Flat(box, 0.9) end
    box._puroCineGold = gold and true or false
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
        Setup.draft.rangeSpell = self:GetText() or ""
        ShowHint(self)
    end)
    box:SetScript("OnEditFocusGained", function(self)
        ShowHint(self)
        if self._puroCineGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.86, 0.4, 1)
        end
    end)
    box:SetScript("OnEditFocusLost", function(self)
        ShowHint(self)
        if self._puroCineGold and self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(0.75, 0.6, 0.28, 0.95)
        end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    ShowHint(box)
    row.edit = box
    return row
end
Setup.SpellField = SpellField

local function PercentField(parent, label, key)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 22)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetText(label)
    local box = Setup.Backdropped("EditBox", nil, row)
    box:SetSize(72, 22)
    box:SetPoint("RIGHT", 0, 0)
    box:SetFontObject("GameFontHighlightSmall")
    box:SetAutoFocus(false)
    box:SetMaxLetters(16)
    box:SetTextInsets(6, 6, 0, 0)
    box:SetJustifyH("LEFT")
    if not Setup.GoldEdge(box) then Setup.Flat(box, 0.9) end
    box:SetScript("OnTextChanged", function(self) Setup.draft[key] = self:GetText() or "" end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.edit = box
    return row
end
Setup.PercentField = PercentField

local function Section(parent, text)
    -- Gold title only. The old group-indicator bar is the classic paperdoll and collides with the column titles.
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(Setup.CONTENT_W, 16)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 0, 0)
    row.label:SetText(text)
    return row
end
Setup.Section = Section

local function Body(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetWidth(Setup.CONTENT_W)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end
Setup.Body = Body

local function ColumnLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    return label
end
Setup.ColumnLabel = ColumnLabel
