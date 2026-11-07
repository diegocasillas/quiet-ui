local _, ns = ...

-- The micro menu and the native bag bar (backpack and bag slots) fade together:
-- hover, edit mode, and Glance show them, and the Visible row holds them. An
-- item on the cursor shows the bag bar too.

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

local refreshing = false

------------------------------------------------------------------------------
-- Bag slots
------------------------------------------------------------------------------
function ns.BagsShouldShow()
    if not ns.DB().enabled then return false end
    return ns.CursorHasItem()
end

------------------------------------------------------------------------------
-- Micro menu
------------------------------------------------------------------------------
local MICRO_SET = {}
for _, name in ipairs(MICRO_NAMES) do
    MICRO_SET[name] = true
end

local function KnownMicro(frame)
    local name = ns.FrameName(frame)
    if not name or name:find("Queue") then return false end
    if MICRO_SET[name] then return true end
    if type(MICRO_BUTTONS) ~= "table" then return false end
    for _, entry in ipairs(MICRO_BUTTONS) do
        if entry == name or entry == frame then return true end
    end
    return false
end

local function EachMicroButton(fn)
    local seen = {}
    local function Consider(name)
        if type(name) ~= "string" or seen[name] or name:find("Queue") then return end
        seen[name] = true
        local frame = _G[name]
        if ns.Usable(frame) then fn(frame) end
    end
    for _, name in ipairs(MICRO_NAMES) do
        Consider(name)
    end
    if type(MICRO_BUTTONS) ~= "table" then return end
    for _, entry in ipairs(MICRO_BUTTONS) do
        if type(entry) == "string" then
            Consider(entry)
        elseif ns.Usable(entry) and not seen[entry] then
            local name = ns.FrameName(entry)
            if not name or not name:find("Queue") then
                seen[entry] = true
                fn(entry)
            end
        end
    end
end

-- A container that also holds bars, bags, or the LFG eye keeps those children.
local function HoldsSpared(frame)
    return ns.TreeHas(frame, ns.IsQueue) or ns.TreeHas(frame, ns.IsBarFrame)
        or ns.TreeHas(frame, ns.IsBagRelated)
end

local function HoldsMicro(frame)
    return ns.TreeHas(frame, KnownMicro)
end

-- Parent alpha stays. Zeroing a container would hide the buttons inside it.
local function MuteMenuFrame(frame)
    if not ns.Usable(frame) then return end
    if ns.IsBarFrame(frame) or ns.IsBagRelated(frame) or KnownMicro(frame) then return end
    ns.HideTextures(frame)
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if ns.Usable(child) and not ns.IsSpared(child) and not ns.IsBagRelated(child) and not KnownMicro(child) then
            if HoldsMicro(child) or HoldsSpared(child) then
                MuteMenuFrame(child)
            else
                ns.Mute(child)
            end
        end
    end
end

function ns.RefreshChrome()
    if refreshing or not ns.DB().enabled then return end
    refreshing = true
    local ok, err = pcall(function()
        for _, name in ipairs(MENU_FRAMES) do
            local frame = _G[name]
            if frame and not frame._quietChrome then
                MuteMenuFrame(frame)
                frame._quietChrome = true
            end
        end
    end)
    refreshing = false
    if not ok then ns.Report("menu", err) end
end

-- Gaps between buttons are not hover. The catcher is not their child, so a
-- faded button does not drop the mouse, and it does not take the click.
local microCatcher

local function EnsureMicroCatcher()
    if microCatcher then return microCatcher end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:SetAlpha(1)
    created:Hide()
    microCatcher = created
    return created
end

local function MicroCorner()
    local tl, br, tlTop, tlLeft, brBottom, brRight
    EachMicroButton(function(button)
        if not button.IsShown or not button:IsShown() or not button.GetLeft then return end
        local ok, left, right, top, bottom = pcall(function()
            return button:GetLeft(), button:GetRight(), button:GetTop(), button:GetBottom()
        end)
        if not ok or type(left) ~= "number" or type(right) ~= "number"
            or type(top) ~= "number" or type(bottom) ~= "number" then
            return
        end
        if not tl or top > tlTop or (top == tlTop and left < tlLeft) then
            tl, tlTop, tlLeft = button, top, left
        end
        if not br or bottom < brBottom or (bottom == brBottom and right > brRight) then
            br, brBottom, brRight = button, bottom, right
        end
    end)
    if tl and br then return tl, br end
end

local function PlaceMicroCatcher()
    local box = EnsureMicroCatcher()
    if not box then return end
    if not ns.DB().enabled or ns.InEditMode() then
        box:Hide()
        return
    end
    local tl, br = MicroCorner()
    if not tl then
        box:Hide()
        box._quietA, box._quietB = nil, nil
        return
    end
    if box._quietA ~= tl or box._quietB ~= br then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", tl, "TOPLEFT")
        box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
        box._quietA, box._quietB = tl, br
    end
    local strata = tl.GetFrameStrata and tl:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = tl.GetFrameLevel and tl:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    local other = br.GetFrameLevel and br:GetFrameLevel()
    if type(other) == "number" and other < level then level = other end
    level = math.max(level - 1, 0)
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
    if not box:IsShown() then box:Show() end
end

-- The bag bar sits beside the micro menu and fades with it.
local function MicroHot()
    if microCatcher and ns.Hit(microCatcher) then return true end
    local bagHot = false
    ns.EachBagFrame(function(frame)
        if not bagHot and ns.Hit(frame) then bagHot = true end
    end)
    if bagHot then return true end
    local hot = false
    EachMicroButton(function(button)
        if not hot and ns.Hit(button) then hot = true end
    end)
    return hot
end

local function UpdateMicro(elapsed)
    if not ns.DB().enabled then return end
    PlaceMicroCatcher()
    local show = ns.VisibilityShow("micro", false, MicroHot())
    EachMicroButton(function(button)
        ns.UpdateFaded(button, show, elapsed)
    end)
    -- The bag bar carries the backpack and its slots. An item on the cursor shows
    -- it so a bag can take the item.
    local bags = _G.BagsBar
    if ns.Usable(bags) then
        ns.UpdateFaded(bags, show or ns.BagsShouldShow(), elapsed)
    end
end

-- Hover, edit mode, or Glance shows the micro menu and the bag bar. Setup can pin them on.
function ns.UpdateMenuButton(elapsed)
    UpdateMicro(elapsed)
end

function ns.ResetMenu()
    local function clear(name)
        local frame = _G[name]
        if frame then frame._quietChrome = nil end
    end
    for _, name in ipairs(MICRO_NAMES) do
        clear(name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, entry in ipairs(MICRO_BUTTONS) do
            if type(entry) == "string" then
                clear(entry)
            elseif entry then
                entry._quietChrome = nil
            end
        end
    end
    for _, name in ipairs(MENU_FRAMES) do
        clear(name)
    end
    if microCatcher then
        microCatcher:Hide()
        microCatcher._quietA, microCatcher._quietB = nil, nil
    end
end
