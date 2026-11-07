local _, ns = ...
local Layout = ns.Layout or {}
ns.Layout = Layout

------------------------------------------------------------------------------
-- Prompt. Own frame instead of StaticPopup, which spreads taint.
-- Same character frame as setup, with a gear instead of the player portrait.
------------------------------------------------------------------------------
local prompt

local CHROME = {
    portrait = { width = 400, side = 26, textY = -96, buttonY = 18, height = 188 },
    flat = { width = 380, side = 16, titleY = -14, textY = -40, buttonY = 16, height = 132 },
}

local function Flat(frame, alpha)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, alpha)
    frame:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
end

local function Backdropped(kind, name, parent)
    local ok, frame = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and frame then return frame end
    return CreateFrame(kind, name, parent)
end

local function PortraitChrome(widget)
    return widget.SetTitle or widget.TitleText or widget.TitleContainer
        or widget.PortraitContainer or widget.portrait
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

local function PortraitRegion(widget)
    if widget.PortraitContainer and widget.PortraitContainer.portrait then
        return widget.PortraitContainer.portrait
    end
    return widget.portrait
end

local function TextureShown(texture)
    return texture and texture.GetTexture and texture:GetTexture()
end

-- Gear, same order as the minimap button. The character frame needs an icon in the circle.
local function ApplyGearPortrait(widget)
    if widget.SetPortraitAtlas then
        local ok = pcall(widget.SetPortraitAtlas, widget, "mechagon-projects")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    if widget.SetPortraitToAsset then
        local ok = pcall(widget.SetPortraitToAsset, widget, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(PortraitRegion(widget)) then return end
    end
    local texture = PortraitRegion(widget)
    if not texture then return end
    if texture.SetAtlas then
        local ok, result = pcall(texture.SetAtlas, texture, "mechagon-projects")
        if ok and result then return end
    end
    if type(SetPortraitToTexture) == "function" then
        local ok = pcall(SetPortraitToTexture, texture, "Interface\\Icons\\INV_Misc_Gear_01")
        if ok and TextureShown(texture) then return end
    end
    if not texture:SetTexture("Interface\\Icons\\INV_Misc_Gear_01") then
        texture:SetTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    end
end

-- The template close hides the frame without an answer. Only the two buttons decide.
local function HideClose(widget)
    local close = widget.CloseButton or widget.closeButton
    if close and close.Hide then close:Hide() end
end

local function SetButtonLabel(button, text)
    if button.label then
        button.label:SetText(text)
        return
    end
    if button.SetText then button:SetText(text) end
end

local function PromptButton(parent, text, onClick)
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
    Flat(button, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreatePrompt()
    local ok, frame = pcall(CreateFrame, "Frame", nil, UIParent, "PortraitFrameTemplate")
    local kind = "flat"
    if ok and frame and PortraitChrome(frame) then
        kind = "portrait"
        frame._quietGear = true
        ApplyTitle(frame, "QuietUI")
        ApplyGearPortrait(frame)
        HideClose(frame)
    else
        if not (ok and frame) then
            frame = Backdropped("Frame", nil, UIParent)
        end
        Flat(frame, 0.9)
    end
    local metrics = CHROME[kind]
    frame:ClearAllPoints()
    frame:SetSize(metrics.width, metrics.height)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    if kind ~= "portrait" then
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetText("|cff8fd4c8QuietUI|r")
        frame.title:SetPoint("TOP", 0, metrics.titleY)
    end
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, metrics.textY)
    frame.text:SetWidth(metrics.width - metrics.side * 2)
    frame.text:SetJustifyH("CENTER")
    frame.yes = PromptButton(frame, "Add", function()
        frame:Hide()
        if InCombatLockdown() then
            ns.Print("layout can not change in combat, /reload after combat to try again")
            return
        end
        local okWrite, err = pcall(Layout.Write)
        if okWrite then
            Layout.MarkAnswered()
        else
            ns.Report("layout", err)
        end
    end)
    frame.no = PromptButton(frame, "Not now", function()
        frame:Hide()
        Layout.MarkAnswered()
    end)
    local level = frame:GetFrameLevel() + 20
    frame.yes:SetFrameLevel(level)
    frame.no:SetFrameLevel(level)
    frame.no:SetPoint("BOTTOMLEFT", metrics.side, metrics.buttonY)
    frame.yes:SetPoint("BOTTOMRIGHT", -metrics.side, metrics.buttonY)
    frame:Hide()
    return frame
end

local function Ask(text, yesLabel)
    prompt = prompt or CreatePrompt()
    if prompt._quietGear then ApplyGearPortrait(prompt) end
    prompt.text:SetText(text)
    SetButtonLabel(prompt.yes, yesLabel)
    prompt:Show()
end

-- Returns true once the check could run, so it is not repeated this session.
local function Check()
    if ns.DB().layoutHash == Layout.ShippedHash() then return true end
    local info = Layout.LoadLayouts()
    if not info then return false end
    Layout.ReadShipped()
    if Layout.FindLayout(info.layouts) then
        Ask("The " .. Layout.LAYOUT_NAME .. " layout has changed. Update yours?", "Update")
    else
        Ask("Add the " .. Layout.LAYOUT_NAME .. " layout and switch to it?", "Add")
    end
    return true
end

-- Setup's Import layout writes the shipped layout now, even after "Not now".
function ns.ForceLayout()
    if not Layout.EditModeReady() then
        ns.Print("Edit Mode is not available")
        return
    end
    if InCombatLockdown() then
        ns.Print("layout can not change in combat")
        return
    end
    if prompt then prompt:Hide() end
    local ok, err = pcall(Layout.Write)
    if ok then
        Layout.MarkAnswered()
        Layout.done = true
    else
        ns.Report("layout", err)
    end
end

-- Layouts are not loaded right at login and are locked in combat, so this
-- retries on every apply until it has run once per session.
function ns.EnsureLayout()
    if ns.ActivePreset and ns.ActivePreset() then return end
    if Layout.done or InCombatLockdown() or not Layout.EditModeReady() then return end
    local ok, finished = pcall(Check)
    if not ok then
        Layout.done = true
        ns.Report("layout", finished)
    elseif finished then
        Layout.done = true
    end
end
