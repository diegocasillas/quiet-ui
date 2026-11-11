local _, ns = ...
local Menu = ns.Menu or {}
ns.Menu = Menu

------------------------------------------------------------------------------
-- Micro menu
------------------------------------------------------------------------------
local MICRO_SET = {}
for _, name in ipairs(Menu.MICRO_NAMES) do
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

-- Built by RefreshChrome and ResetMenu, so hover ticks do not read globals.
local microButtons = {}
local microBuilt = false
local microSeen = {}

-- Names and frames share the seen set, so a button listed both ways is kept once.
local function AddMicro(frame, key)
    if microSeen[key] then return end
    microSeen[key] = true
    if not ns.Usable(frame) or microSeen[frame] then return end
    microSeen[frame] = true
    microButtons[#microButtons + 1] = frame
end

local function BuildMicroButtons()
    for i = #microButtons, 1, -1 do microButtons[i] = nil end
    for key in pairs(microSeen) do microSeen[key] = nil end
    for _, name in ipairs(Menu.MICRO_NAMES) do
        AddMicro(_G[name], name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, entry in ipairs(MICRO_BUTTONS) do
            if type(entry) == "string" then
                if not entry:find("Queue") then AddMicro(_G[entry], entry) end
            elseif ns.Usable(entry) then
                local name = ns.FrameName(entry)
                if not name or not name:find("Queue") then AddMicro(entry, entry) end
            end
        end
    end
    for key in pairs(microSeen) do microSeen[key] = nil end
    microBuilt = true
end

local function MicroList()
    if not microBuilt then BuildMicroButtons() end
    return microButtons
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
    if Menu.refreshing or not ns.DB().enabled then return end
    Menu.refreshing = true
    local ok, err = pcall(function()
        BuildMicroButtons()
        for _, name in ipairs(Menu.MENU_FRAMES) do
            local frame = _G[name]
            if frame and not frame._puroCineChrome then
                MuteMenuFrame(frame)
                frame._puroCineChrome = true
            end
        end
    end)
    Menu.refreshing = false
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

local function ReadEdge(button, method)
    local fn = button[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, button)
    if ok and type(value) == "number" then return value end
end

local function MicroCorner()
    local tl, br, tlTop, tlLeft, brBottom, brRight
    local list = MicroList()
    for i = 1, #list do
        local button = list[i]
        if ns.Usable(button) and button.IsShown and button:IsShown() then
            local left, right = ReadEdge(button, "GetLeft"), ReadEdge(button, "GetRight")
            local top, bottom = ReadEdge(button, "GetTop"), ReadEdge(button, "GetBottom")
            if left and right and top and bottom then
                if not tl or top > tlTop or (top == tlTop and left < tlLeft) then
                    tl, tlTop, tlLeft = button, top, left
                end
                if not br or bottom < brBottom or (bottom == brBottom and right > brRight) then
                    br, brBottom, brRight = button, bottom, right
                end
            end
        end
    end
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
        box._puroCineA, box._puroCineB = nil, nil
        return
    end
    if box._puroCineA ~= tl or box._puroCineB ~= br then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", tl, "TOPLEFT")
        box:SetPoint("BOTTOMRIGHT", br, "BOTTOMRIGHT")
        box._puroCineA, box._puroCineB = tl, br
    end
    local strata = tl.GetFrameStrata and tl:GetFrameStrata()
    if type(strata) == "string" and box._puroCineStrata ~= strata then
        box:SetFrameStrata(strata)
        box._puroCineStrata = strata
    end
    local level = tl.GetFrameLevel and tl:GetFrameLevel() or 1
    if type(level) ~= "number" then level = 1 end
    local other = br.GetFrameLevel and br:GetFrameLevel()
    if type(other) == "number" and other < level then level = other end
    level = math.max(level - 1, 0)
    if box._puroCineLevel ~= level then
        box:SetFrameLevel(level)
        box._puroCineLevel = level
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
    local list = MicroList()
    for i = 1, #list do
        if ns.Hit(list[i]) then return true end
    end
    return false
end

local function UpdateMicro(elapsed)
    if not ns.DB().enabled then return end
    PlaceMicroCatcher()
    local show = ns.VisibilityShow("micro", false, MicroHot())
    local list = MicroList()
    for i = 1, #list do
        if ns.Usable(list[i]) then ns.UpdateFaded(list[i], show, elapsed) end
    end
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
        if frame then frame._puroCineChrome = nil end
    end
    for _, name in ipairs(Menu.MICRO_NAMES) do
        clear(name)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, entry in ipairs(MICRO_BUTTONS) do
            if type(entry) == "string" then
                clear(entry)
            elseif entry then
                entry._puroCineChrome = nil
            end
        end
    end
    for _, name in ipairs(Menu.MENU_FRAMES) do
        clear(name)
    end
    if microCatcher then
        microCatcher:Hide()
        microCatcher._puroCineA, microCatcher._puroCineB = nil, nil
    end
    BuildMicroButtons()
end
