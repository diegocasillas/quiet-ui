local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Debuffs that only show by the usual aura rules (combat, hover, Glance...), not
-- through Always show debuffs. Lowercase names; the icons turn transparent, so the
-- other debuffs keep their places.
local IGNORED = {
    ["boosted rest"] = true,
}
local SCAN_EVERY = 0.1
local DEPTH = 3

local hidden = {}
local scanAcc = 0
local pending = 2 -- scans still due after an aura change
local idle = 0
local SAFETY = 1 -- seconds; a slow scan in case an icon was recycled with no event

-- Debuffs change only on the player's own aura event, so the icons are read then
-- (twice, in case the game draws them a frame late) and rarely otherwise.
if type(CreateFrame) == "function" then
    local auraEvents = CreateFrame("Frame")
    if pcall(auraEvents.RegisterUnitEvent, auraEvents, "UNIT_AURA", "player") then
        auraEvents:SetScript("OnEvent", function() pending = 2 end)
    end
end

-- Plain lowercase name of the aura an icon draws, or nil when it cannot be read
-- (secret in a fight, or an icon the client has locked).
local function AuraName(icon)
    local info = icon.buttonInfo
    local name = type(info) == "table" and info.name or nil
    if name == nil and C_UnitAuras then
        local id = (type(info) == "table" and info.auraInstanceID) or icon.auraInstanceID
        local index = type(info) == "table" and info.index
        local data
        if id ~= nil and not ns.IsSecret(id) and C_UnitAuras.GetAuraDataByAuraInstanceID then
            data = C_UnitAuras.GetAuraDataByAuraInstanceID("player", id)
        end
        -- The icons say their place in the debuff list, not their name.
        if not data and type(index) == "number" and not ns.IsSecret(index) and C_UnitAuras.GetAuraDataByIndex then
            data = C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")
        end
        name = data and data.name
    end
    if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    return name:lower()
end

local function Mark(icon)
    local ok, name = pcall(AuraName, icon)
    if not ok or name == nil then return end
    local ignored = IGNORED[name] == true
    -- Recycled icons are let go as soon as they draw another debuff.
    if ignored then
        hidden[icon] = true
    elseif hidden[icon] then
        hidden[icon] = nil
        ns.ReleaseAlpha(icon)
    end
end

local function Walk(depth, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if ns.Usable(child) then
            if child.buttonInfo or child.auraInstanceID then
                Mark(child)
            elseif depth > 1 and child.GetChildren then
                Walk(depth - 1, child:GetChildren())
            end
        end
    end
end

-- show: the usual aura rules say the auras show. Ignored icons then appear at once
-- and fade out over 0.3 s like the other frames. The game sets an icon's alpha back
-- to 1 as it counts the time down, so the alpha is held.
function Faders.UpdateIgnoredDebuffs(elapsed, show)
    scanAcc = scanAcc + (elapsed or 0)
    if scanAcc >= SCAN_EVERY then
        scanAcc = 0
        idle = idle + SCAN_EVERY
        -- (Names are secret in a fight: nothing to read then.)
        if (pending > 0 or idle >= SAFETY) and not ns.InCombat() then
            pending = math.max(0, pending - 1)
            idle = 0
            local frame = _G.DebuffFrame
            if ns.Usable(frame) and frame.GetChildren then Walk(DEPTH, frame:GetChildren()) end
        end
    end
    for icon in pairs(hidden) do
        if ns.Usable(icon) then ns.EaseAlpha(icon, show and true or false, elapsed) end
    end
end

-- Disable: every icon we made transparent comes back.
function Faders.RestoreIgnoredDebuffs()
    for icon in pairs(hidden) do
        ns.ReleaseAlpha(icon)
        hidden[icon] = nil
    end
    scanAcc, pending = 0, 2
end
