local _, ns = ...

-- The micro menu and bags collapse into one button. Left click opens bags,
-- right click shows the bag slots for swapping, drag moves the button.

local MICRO_NAMES = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "PlayerSpellsMicroButton",
    "ProfessionMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
    "PVPMicroButton",
    "HousingMicroButton",
}

local MENU_FRAMES = {
    "MicroMenu",
    "MicroMenuContainer",
    "MicroButtonAndBagsBar",
    "BagsBar",
}

local BORDER = { 0.85, 0.85, 0.85, 0.35 }
local HIGHLIGHT = { 0.95, 0.75, 0.25, 0.95 }

local button
local bagSlotsPinned = false
local refreshing = false

------------------------------------------------------------------------------
-- Bag slots
------------------------------------------------------------------------------
local function CursorHasItem()
    if type(GetCursorInfo) ~= "function" then return false end
    local ok, kind = pcall(GetCursorInfo)
    return ok and kind == "item"
end

function ns.BagsShouldShow()
    if not ns.DB().enabled then return false end
    return bagSlotsPinned or CursorHasItem()
end

function ns.UpdateBagSlots()
    if not ns.DB().enabled then return end
    local show = ns.BagsShouldShow()
    ns.EachBagFrame(function(frame)
        ns.HoldAlpha(frame, show and 1 or 0)
    end)
    if button and button.SetBackdropBorderColor then
        button:SetBackdropBorderColor(unpack(show and HIGHLIGHT or BORDER))
    end
end

local function ToggleBagSlots()
    bagSlotsPinned = not bagSlotsPinned
    ns.UpdateBagSlots()
    if bagSlotsPinned then
        ns.Print("bag slots shown")
    end
end

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------
local function PlaceButton(force)
    local db = ns.DB()
    if not force and button._quietPlaced == db then return end
    button._quietPlaced = db
    button:ClearAllPoints()
    if type(db.point) == "string" and type(db.relPoint) == "string"
        and type(db.x) == "number" and type(db.y) == "number" then
        button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    else
        button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
    end
end

local function SavePoint(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    if not point or type(x) ~= "number" or type(y) ~= "number" then return end
    local db = ns.DB()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    self._quietPlaced = db
end

local function Style(frame)
    if not frame.SetBackdrop then return end
    pcall(function()
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
        frame:SetBackdropBorderColor(unpack(BORDER))
    end)
end

local function AddIcon(frame)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    local usedAtlas = false
    if icon.SetAtlas then
        local ok, result = pcall(icon.SetAtlas, icon, "bag-main")
        usedAtlas = ok and result and true or false
    end
    if not usedAtlas then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    if highlight.SetColorTexture then
        highlight:SetColorTexture(1, 1, 1, 0.18)
    end
end

local function OnMouseUp(self, click)
    if self._moved then
        self._moved = false
        return
    end
    if click == "RightButton" then
        ToggleBagSlots()
    elseif type(ToggleAllBags) == "function" then
        ToggleAllBags()
    elseif type(ToggleBackpack) == "function" then
        ToggleBackpack()
    end
end

local function OnEnter(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("QuietUI", 1, 1, 1)
    GameTooltip:AddLine("Left click: open bags", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Right click: bag slots", 0.85, 0.85, 0.85)
    GameTooltip:AddLine("Drag: move", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function CreateButton()
    local ok, created = pcall(CreateFrame, "Button", "QuietUIMenuButton", UIParent, "BackdropTemplate")
    if not ok or not created then
        created = CreateFrame("Button", "QuietUIMenuButton", UIParent)
    end
    created:SetSize(28, 28)
    created:SetFrameStrata("MEDIUM")
    created:SetFrameLevel(40)
    created:SetClampedToScreen(true)
    created:SetMovable(true)
    created:EnableMouse(true)
    created:RegisterForDrag("LeftButton")
    created:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Style(created)
    AddIcon(created)
    created:SetScript("OnDragStart", function(self)
        self._moved = true
        self:StartMoving()
    end)
    created:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePoint(self)
    end)
    created:SetScript("OnMouseUp", OnMouseUp)
    created:SetScript("OnEnter", OnEnter)
    created:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    return created
end

local function EnsureButton()
    if button then
        PlaceButton(false)
    else
        button = CreateButton()
        PlaceButton(true)
    end
    button:Show()
end

------------------------------------------------------------------------------
-- Micro menu
------------------------------------------------------------------------------
local function MuteChildren(frame, keep)
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not keep(child) then
            ns.Mute(child)
        end
    end
end

-- A container that also holds bars, bags, or the LFG eye keeps its children
-- and only loses its own art.
local function HoldsSpared(frame)
    return ns.TreeHas(frame, ns.IsQueue) or ns.TreeHas(frame, ns.IsBarFrame)
        or ns.TreeHas(frame, ns.IsBagRelated)
end

local function MuteMenuFrame(frame)
    if ns.IsBarFrame(frame) or ns.IsBagRelated(frame) then return end
    if HoldsSpared(frame) then
        ns.HideTextures(frame)
        MuteChildren(frame, function(child)
            return ns.IsSpared(child) or ns.IsBagRelated(child)
        end)
    else
        ns.Mute(frame)
        MuteChildren(frame, ns.IsBagRelated)
    end
end

local function MuteMicroButtons()
    local seen = {}
    local function Consider(name)
        if not name or seen[name] or name:find("Queue") then return end
        seen[name] = true
        local frame = _G[name]
        if frame then ns.Mute(frame) end
    end
    for _, name in ipairs(MICRO_NAMES) do
        Consider(name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, name in ipairs(MICRO_BUTTONS) do
            Consider(name)
        end
    end
end

function ns.RefreshChrome()
    if refreshing or not ns.DB().enabled then return end
    refreshing = true
    local ok, err = pcall(function()
        MuteMicroButtons()
        for _, name in ipairs(MENU_FRAMES) do
            local frame = _G[name]
            if frame then MuteMenuFrame(frame) end
        end
        EnsureButton()
    end)
    refreshing = false
    if not ok then ns.Report("menu", err) end
end

-- The button itself is hover only; it stays while bag slots are in use or it is dragged.
function ns.UpdateMenuButton(elapsed)
    if not button or not button:IsShown() then return end
    local show = ns.MouseOver(button) or button._moved or ns.BagsShouldShow()
    ns.UpdateFaded(button, show, elapsed)
end

function ns.ResetMenu()
    bagSlotsPinned = false
    if button then button:Hide() end
end
