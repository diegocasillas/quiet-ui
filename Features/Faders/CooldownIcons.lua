local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- Cooldown manager icons that show only while the spell is ready. The icons of the
-- Essential and Utility windows fade one by one: a ready icon appears at once, one
-- on cooldown fades out. The window itself keeps its own rules (Visible.lua).
--
-- Whether a spell is ready is worked out the way Glowing Bars does it, in this order:
--   1. the spell (or item) cooldown, when the client lets addons read it;
--   2. the flag the cooldown manager keeps on the icon (isOnActualCooldown);
--   3. a timer started by the player's own casts, using the longest cooldown length
--      seen so far (or the spell's base cooldown).
-- A spell off cooldown but not usable (Execute, Revenge...) hides too, by the game's
-- own IsSpellUsable, so conditional spells need no class list.
-- Secret values (a fight hides most of them) are never read; the next source is used.
-- Nothing here is class specific: spells are matched by name, as the icons show them.
--
-- The icons are read when the game reports a change (a cooldown, usability, target, form or
-- equipment event, at most every MIN_GAP), when a cooldown estimated to end is about to,
-- and at least every SAFETY seconds for what no event covers. All of it runs on GetTime():
-- UpdateFaders hands over one frame's elapsed time, which is not the time between calls.

local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer" }
local GLOBAL_COOLDOWN = 1.51   -- a cooldown this short is the global cooldown, not the spell's
local READY_MARGIN = 0.2       -- this close to ready counts as ready
local CAST_GRACE = 1           -- after a cast the client may not show the cooldown yet
local STILL_RUNNING = 1        -- the icon says "on cooldown" but gives no time
local MIN_GAP = 0.1            -- events never scan more often than this
local SAFETY = 0.5             -- a scan with no event, for what the events do not report
local SPELL_TTL = 5            -- an icon's spell is read again after this (an override can change)
local LAST_EQUIPPED_SLOT = 19

local endsAt = {}        -- spell name -> GetTime() the cooldown is estimated to end
local knownLength = {}   -- spell name -> longest real cooldown length seen
local castAt = {}        -- spell name -> GetTime() of the last cast
local names = {}         -- spell id -> name
local useItems = {}      -- spell id -> equipped item id that casts it, or false
local targets = {}       -- icon -> true (ready, show) / false (on cooldown, hide)
local held = {}          -- icons whose alpha we hold
local spellOf = {}        -- cooldownID -> spell id, or false when the icon names none
local spellOfAt = {}      -- cooldownID -> GetTime() it was read
local dirty = true         -- an event says something may have changed
local lastScan = -math.huge
local wakeAt               -- GetTime() the nearest estimated cooldown is about to end

local function Readable(value)
    if value == nil or ns.IsSecret(value) then return false end
    if type(canaccessvalue) == "function" then return canaccessvalue(value) and true or false end
    return true
end

local function SpellName(spellId)
    if not Readable(spellId) then return nil end
    local kept = names[spellId]
    if kept then return kept end
    local ok, name
    if C_Spell and C_Spell.GetSpellName then
        ok, name = pcall(C_Spell.GetSpellName, spellId)
    elseif type(GetSpellInfo) == "function" then
        ok, name = pcall(GetSpellInfo, spellId)
    end
    if ok and type(name) == "string" and Readable(name) and name ~= "" then
        names[spellId] = name
        return name
    end
    return nil
end

-- Base cooldown in seconds; 0 when the spell has none (or only the global one).
local function BaseCooldown(spellId)
    if type(GetSpellBaseCooldown) ~= "function" then return 0 end
    local ok, cooldown, gcd = pcall(GetSpellBaseCooldown, spellId)
    if not ok or not Readable(cooldown) then return 0 end
    local length = tonumber(cooldown)
    local global = Readable(gcd) and tonumber(gcd) or nil
    if not length or length <= 0 then return 0 end
    if length < 500 then
        local gcdSeconds = global and global < 500 and global or 1.5
        return (length <= gcdSeconds + 0.05 or length <= 1.5) and 0 or length
    end
    return length <= (global or 1500) + 50 and 0 or length / 1000
end

-- An equipped item (a trinket) that casts this spell. Only for spells with no
-- cooldown of their own, since a trinket's spell carries the item's cooldown.
local function UseItem(spellId)
    local kept = useItems[spellId]
    if kept ~= nil then return kept or nil end
    local found
    if BaseCooldown(spellId) <= 0 then
        local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        if type(GetInventoryItemID) == "function" and type(getSpell) == "function" then
            for slot = 1, LAST_EQUIPPED_SLOT do
                local itemId = GetInventoryItemID("player", slot)
                if Readable(itemId) and itemId ~= 0 then
                    local ok, _, id = pcall(getSpell, itemId)
                    if ok and Readable(id) and id == spellId then found = itemId; break end
                end
            end
        end
    end
    useItems[spellId] = found or false
    return found
end

-- remain, length; nil when the client hides the numbers.
local function Build(start, duration)
    if (start ~= nil and not Readable(start)) or (duration ~= nil and not Readable(duration)) then
        return nil
    end
    local length = tonumber(duration) or 0
    if length > 0 and length <= GLOBAL_COOLDOWN then return 0, length end
    return math.max(length - (GetTime() - (tonumber(start) or 0)), 0), length
end

local function ReadCooldown(spellId)
    local itemId = UseItem(spellId)
    if itemId then
        local get = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
        if type(get) ~= "function" then return nil end
        local ok, start, duration = pcall(get, itemId)
        if not ok then return nil end
        return Build(start, duration)
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellId)
        if ok and type(info) == "table" then return Build(info.startTime, info.duration) end
        return nil
    end
    if type(GetSpellCooldown) == "function" then
        local ok, start, duration = pcall(GetSpellCooldown, spellId)
        if ok then return Build(start, duration) end
    end
    return nil
end

-- What the cooldown manager says of one icon. nil when it says nothing usable.
local function ReadIcon(icon, name, now)
    -- An icon drawing an aura counts the aura down, not the cooldown.
    local aura = icon.auraInstanceID
    if aura ~= nil then return nil end
    local fromAura = icon.wasSetFromAura
    if Readable(fromAura) and fromAura then return nil end
    local on = icon.isOnActualCooldown
    if not Readable(on) then return nil end
    if on then return math.max((endsAt[name] or now) - now, STILL_RUNNING) end
    if now - (castAt[name] or -CAST_GRACE) <= CAST_GRACE then return nil end
    endsAt[name] = nil
    return 0
end

local function Remaining(spellId, name, icon, now)
    local remain, length = ReadCooldown(spellId)
    if remain ~= nil then
        if length > GLOBAL_COOLDOWN then knownLength[name] = length end
        if remain > READY_MARGIN then
            endsAt[name] = now + remain
            return remain
        end
        if now - (castAt[name] or -CAST_GRACE) > CAST_GRACE then
            endsAt[name] = nil
            return 0
        end
    else
        local fromIcon = ReadIcon(icon, name, now)
        if fromIcon ~= nil then return fromIcon end
    end
    local ends = endsAt[name]
    if not ends then return 0 end
    if ends <= now then
        endsAt[name] = nil
        return 0
    end
    return ends - now
end

-- The spell an icon draws (an override, like a stance or talent swap, wins). The answer
-- is kept per cooldownID: the game builds a new table for every read.
local function IconSpell(icon, now)
    local id = icon.cooldownID
    if not Readable(id) then return nil end
    local at = spellOfAt[id]
    if at and now - at < SPELL_TTL then return spellOf[id] or nil end
    local spell
    if C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, id)
        if ok and type(info) == "table" then
            spell = info.overrideSpellID
            if not Readable(spell) or spell == 0 then spell = info.spellID end
            if not Readable(spell) then spell = nil end
        end
    end
    spellOf[id], spellOfAt[id] = spell or false, now
    return spell
end

-- True when the game says the spell cannot be used now for a reason other than a
-- missing resource: Execute on a healthy target, Revenge before a block, the wrong
-- stance. A resource short of the cost leaves the spell showing, as does a value the
-- client hides (a fight may make it secret).
local function Unusable(spellId)
    if not (C_Spell and C_Spell.IsSpellUsable) then return false end
    local ok, usable, noPower = pcall(C_Spell.IsSpellUsable, spellId)
    if not ok or not Readable(usable) or usable then return false end
    return not (Readable(noPower) and noPower)
end

local nextWake   -- the earliest wake of this scan

local function Evaluate(icon, now)
    local spellId = IconSpell(icon, now)
    local name = spellId and SpellName(spellId)
    -- Unknown spell: leave the icon alone.
    if not name then
        targets[icon] = true
        return
    end
    local remaining = Remaining(spellId, name, icon, now)
    local ready = remaining <= READY_MARGIN
    -- A cooldown with a known end is looked at again as it gets ready.
    local ends = endsAt[name]
    if not ready and ends then
        local wake = math.max(ends - READY_MARGIN, now + 0.05)
        if not nextWake or wake < nextWake then nextWake = wake end
    end
    -- A trinket's spell says nothing about the item, so items skip the check.
    if ready and not UseItem(spellId) and Unusable(spellId) then ready = false end
    targets[icon] = ready
end

local seen = {}
local function Scan(now)
    nextWake = nil
    for icon in pairs(seen) do seen[icon] = nil end
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        local pool = ns.Usable(viewer) and viewer.itemFramePool
        local visible = pool and viewer.IsVisible and viewer:IsVisible()
        if visible and not ns.IsSecret(visible) and type(pool.EnumerateActive) == "function" then
            for icon in pool:EnumerateActive() do
                if ns.Usable(icon) then
                    seen[icon] = true
                    local ok, err = pcall(Evaluate, icon, now)
                    if not ok then ns.Report("cooldown icons", err) end
                end
            end
        end
    end
    -- Icons that left the window (recycled, or the window closed) come back.
    for icon in pairs(targets) do
        if not seen[icon] then
            targets[icon] = nil
            if held[icon] then
                held[icon] = nil
                ns.ReleaseAlpha(icon)
            end
        end
    end
    wakeAt = nextWake
end

function Faders.RestoreCooldownIcons()
    for icon in pairs(held) do
        ns.ReleaseAlpha(icon)
        held[icon] = nil
    end
    for icon in pairs(targets) do targets[icon] = nil end
    lastScan, wakeAt, dirty = -math.huge, nil, true
end

function Faders.UpdateCooldownIcons(elapsed)
    if not ns.ReadyCooldownsOnly() then
        if next(held) or next(targets) then Faders.RestoreCooldownIcons() end
        return
    end
    -- Edit Mode and Glance show every icon, ready or not.
    local all = ns.InEditMode() or ns.Glancing()
    local now = GetTime()
    local since = now - lastScan
    if (dirty and since >= MIN_GAP) or since >= SAFETY or (wakeAt and now >= wakeAt) then
        dirty, lastScan = false, now
        Scan(now)
    end
    for icon, ready in pairs(targets) do
        if ns.Usable(icon) then
            local show = ready or all
            -- Only icons that have been hidden once need holding.
            if held[icon] or not show then
                held[icon] = true
                ns.EaseAlpha(icon, show, elapsed)
            end
        end
    end
end

-- Events mark the icons for a new read. The player's own casts also start the fallback
-- timer; the spell id can be secret in a fight, the cast is then unknown and the other
-- two sources carry on. A form, spell or talent change can swap the spell an icon draws.
if type(CreateFrame) == "function" then
    local events = CreateFrame("Frame")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
        "ACTIONBAR_UPDATE_USABLE", "PLAYER_TARGET_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
        "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, _, _, spellId)
        dirty = true
        if event == "PLAYER_EQUIPMENT_CHANGED" then
            for id in pairs(useItems) do useItems[id] = nil end
        elseif event == "UPDATE_SHAPESHIFT_FORM" then
            for name in pairs(knownLength) do knownLength[name] = nil end
            for id in pairs(spellOfAt) do spellOfAt[id] = nil end
        elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
            for id in pairs(spellOfAt) do spellOfAt[id] = nil end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local name = SpellName(spellId)
            if not name then return end
            local now = GetTime()
            castAt[name] = now
            local seconds = math.max(BaseCooldown(spellId), knownLength[name] or 0)
            if seconds > GLOBAL_COOLDOWN then endsAt[name] = now + seconds end
        end
    end)
end
