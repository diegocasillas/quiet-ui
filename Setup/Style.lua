local _, ns = ...
local Setup = ns.Setup or {}
ns.Setup = Setup

-- One window: layout, HUD visibility, bars, group visibility, player, chat and Glance.
-- The frame is named so UISpecialFrames can close it on Escape.
-- The window keeps the tallest page, so switching tabs does not resize it.

local ROWS = {
    { key = "xp", label = "XP bar" },
    { key = "cooldowns", label = "Cooldown manager" },
    { key = "meter", label = "Damage meter" },
    { key = "resource", label = "Personal resource" },
    { key = "quests", label = "Quest tracker" },
    { key = "auras", label = "Buffs and debuffs" },
    { key = "micro", label = "Micro menu" },
    { key = "raid manager", label = "Raid manager" },
}
Setup.ROWS = ROWS

local CONTENT_W = 560
Setup.CONTENT_W = CONTENT_W
local GROUP_VIEW_H = 264
Setup.GROUP_VIEW_H = GROUP_VIEW_H
-- Bottom-left of the minimap, clear of the tracking button.
local MINIMAP_ANGLE = 225
Setup.MINIMAP_ANGLE = MINIMAP_ANGLE

local draft = {}
Setup.draft = draft
-- selectedPresetId, presetName, presetLayout: state lives in Setup
-- LoadSavedDraft: state lives in Setup
-- frame: state lives in Setup
-- minimapButton: state lives in Setup
-- minimapHooked: state lives in Setup

local function FadeText(seconds)
    if not seconds or seconds <= 0 then return "Stay" end
    return seconds .. " s"
end
Setup.FadeText = FadeText

local RANGE_YARDS = { 10, 28, "spell" }
Setup.RANGE_YARDS = RANGE_YARDS

local function RangeYardsText(yards)
    if yards == 10 then return "10" end
    if yards == 28 then return "28" end
    return "Spell"
end
Setup.RangeYardsText = RangeYardsText

local function RangeKindText(kind)
    if kind == "friendly" then return "Friendly" end
    return "Unfriendly"
end
Setup.RangeKindText = RangeKindText

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
Setup.Flat = Flat

local function Backdropped(kind, name, parent, template)
    if template then
        local ok, widget = pcall(CreateFrame, kind, name, parent, template)
        if ok and widget then return widget end
    end
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end
Setup.Backdropped = Backdropped

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
Setup.GoldEdge = GoldEdge

local function SkinSmall(button)
    button._cineGold = GoldEdge(button) and true or false
    if not button._cineGold then Flat(button, 0.9) end
    if button._cineGold and button.label and button.label.SetTextColor then
        button.label:SetTextColor(1, 0.82, 0.35)
    end
end
Setup.SkinSmall = SkinSmall

local function PaintBox(box, on)
    if not box then return end
    if box.SetChecked then
        box:SetChecked(on and true or false)
        return
    end
    if not box.check then return end
    if on then box.check:Show() else box.check:Hide() end
end
Setup.PaintBox = PaintBox

local function ButtonText(button, text)
    if button.label then button.label:SetText(text) else button:SetText(text) end
end
Setup.ButtonText = ButtonText
