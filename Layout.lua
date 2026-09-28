local _, ns = ...

-- Offers the QuietUI Edit Mode layout from LayoutString.lua. Each new version
-- of that string is offered once; an update still waits for consent.
-- With Force QuietUI layout on, turning the addon on selects the layout
-- (creating it when missing) and remembers the previous one. Turning it off
-- selects that layout again. With force off, the active layout stays as it is.
-- Only C_EditMode is used: calling EditModeManagerFrame methods would taint it.

local LAYOUT_NAME = "QuietUI"

-- Blizzard ships Modern and Classic presets ahead of saved layouts.
local FALLBACK_PRESETS = 2

local done = false

local function EditModeReady()
    return C_EditMode
        and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.ConvertStringToLayoutInfo) == "function"
        and type(C_EditMode.SaveLayouts) == "function"
        and type(C_EditMode.SetActiveLayout) == "function"
end

local function PresetCount()
    local manager = EditModePresetLayoutManager
    if manager and type(manager.GetCopyOfPresetLayouts) == "function" then
        local ok, presets = pcall(manager.GetCopyOfPresetLayouts, manager)
        if ok and type(presets) == "table" then return #presets end
    end
    return FALLBACK_PRESETS
end

local function FindLayout(layouts)
    for i, layout in ipairs(layouts) do
        if layout.layoutName == LAYOUT_NAME then return i end
    end
end

local function ReadShipped()
    local layout = C_EditMode.ConvertStringToLayoutInfo(ns.LAYOUT_STRING or "")
    if type(layout) ~= "table" then
        error("LayoutString.lua could not be read")
    end
    layout.layoutName = LAYOUT_NAME
    layout.layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    return layout
end

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

local function MarkAnswered()
    ns.DB().layoutHash = ShippedHash()
end

local function LoadLayouts()
    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then return nil end
    return info
end

-- Saved once, before the switch. A retry must not overwrite it with QuietUI.
local function Remember(active, absolute)
    if type(active) ~= "number" or active < 1 or active == absolute then return end
    local char = ns.CharDB()
    if char.previousLayout == nil then
        char.previousLayout = active
    end
end

local function Write()
    local info = LoadLayouts()
    if not info then error("Edit Mode layouts are not loaded") end
    local shipped = ReadShipped()
    local index = FindLayout(info.layouts)
    local created = not index
    if index then
        shipped.layoutType = info.layouts[index].layoutType or shipped.layoutType
        info.layouts[index] = shipped
    else
        info.layouts[#info.layouts + 1] = shipped
        index = #info.layouts
    end
    -- Count presets before saving. SaveLayouts can rewrite the table it is given.
    local absolute = PresetCount() + index
    if created then
        info.activeLayout = absolute
    end
    C_EditMode.SaveLayouts(info)
    if created then
        C_EditMode.SetActiveLayout(absolute)
        ns.Print("Edit Mode layout \"" .. LAYOUT_NAME .. "\" saved.")
    else
        ns.Print("Edit Mode layout \"" .. LAYOUT_NAME .. "\" saved. Type /reload to finish.")
    end
end

-- True when the switch has been applied. False asks the caller to try again.
function ns.SelectQuietLayout()
    if InCombatLockdown() or not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local index = FindLayout(info.layouts)
    if not index then
        Remember(info.activeLayout, PresetCount() + #info.layouts + 1)
        MarkAnswered()
        Write()
        info = LoadLayouts()
        index = info and FindLayout(info.layouts)
        if not index then return false end
    end
    local absolute = PresetCount() + index
    if info.activeLayout == absolute then return true end
    Remember(info.activeLayout, absolute)
    C_EditMode.SetActiveLayout(absolute)
    -- A new character applies its default preset after this call. Not done until it stuck.
    local after = LoadLayouts()
    if after and after.activeLayout == absolute then return true end
    return false
end

function ns.RestorePreviousLayout()
    local char = ns.CharDB()
    local previous = char.previousLayout
    if previous == nil then return true end
    if InCombatLockdown() or not EditModeReady() then return false end
    local info = LoadLayouts()
    if not info then return false end
    local presets = PresetCount()
    local custom = type(previous) == "number" and previous - presets or nil
    local valid = type(previous) == "number" and previous >= 1
        and (previous <= presets or type(info.layouts[custom]) == "table")
    if not valid then
        char.previousLayout = nil
        return true
    end
    if info.activeLayout ~= previous then
        C_EditMode.SetActiveLayout(previous)
    end
    char.previousLayout = nil
    return true
end

------------------------------------------------------------------------------
-- Prompt. Own frame instead of StaticPopup, which spreads taint.
------------------------------------------------------------------------------
local prompt

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

local function PromptButton(parent, onClick)
    local button = Backdropped("Button", nil, parent)
    button:SetSize(110, 22)
    Flat(button, 0.9)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.label:SetPoint("CENTER")
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.95, 0.75, 0.25, 0.2)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreatePrompt()
    local frame = Backdropped("Frame", nil, UIParent)
    frame:SetSize(320, 96)
    frame:SetPoint("CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    Flat(frame, 0.9)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOP", 0, -16)
    frame.text:SetWidth(290)
    frame.yes = PromptButton(frame, function()
        frame:Hide()
        if InCombatLockdown() then
            ns.Print("layout can not change in combat, /reload after combat to try again")
            return
        end
        local ok, err = pcall(Write)
        if ok then
            MarkAnswered()
        else
            ns.Report("layout", err)
        end
    end)
    frame.yes:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -6, 14)
    frame.no = PromptButton(frame, function()
        frame:Hide()
        MarkAnswered()
    end)
    frame.no:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 6, 14)
    frame.no.label:SetText("Not now")
    frame:Hide()
    return frame
end

local function Ask(text, yesLabel)
    prompt = prompt or CreatePrompt()
    prompt.text:SetText("|cff8fd4c8QuietUI|r\n" .. text)
    prompt.yes.label:SetText(yesLabel)
    prompt:Show()
end

-- Returns true once the check could run, so it is not repeated this session.
local function Check()
    if ns.DB().layoutHash == ShippedHash() then return true end
    local info = LoadLayouts()
    if not info then return false end
    ReadShipped()
    if FindLayout(info.layouts) then
        Ask("LayoutString.lua has a new \"" .. LAYOUT_NAME .. "\" Edit Mode layout. Update it?", "Update")
    else
        Ask("Add the \"" .. LAYOUT_NAME .. "\" Edit Mode layout and switch to it?", "Add")
    end
    return true
end

-- Setup's Import layout writes the shipped layout now, even after "Not now".
function ns.ForceLayout()
    if not EditModeReady() then
        ns.Print("Edit Mode is not available")
        return
    end
    if InCombatLockdown() then
        ns.Print("layout can not change in combat")
        return
    end
    if prompt then prompt:Hide() end
    local ok, err = pcall(Write)
    if ok then
        MarkAnswered()
        done = true
    else
        ns.Report("layout", err)
    end
end

-- Layouts are not loaded right at login and are locked in combat, so this
-- retries on every apply until it has run once per session.
function ns.EnsureLayout()
    if done or InCombatLockdown() or not EditModeReady() then return end
    local ok, finished = pcall(Check)
    if not ok then
        done = true
        ns.Report("layout", finished)
    elseif finished then
        done = true
    end
end
