-- Run from the addon directory: lua tests/cooldown-icons.lua
-- Cooldown manager icons that show only while ready: how readiness is decided, and when the
-- icons are read (events, a timer for a cooldown about to end, a slow safety scan).
local now = 100
GetTime = function() return now end
local SECRET = setmetatable({}, { __tostring = function() return 'secret' end })
local ns = { Faders = {} }
ns.IsSecret = function(v) return v == SECRET end
ns.Usable = function(f) return type(f) == 'table' end
ns.Report = function(name, err) error('Report: ' .. name .. ' ' .. tostring(err)) end
local option = true
ns.ReadyCooldownsOnly = function() return option end
ns.InEditMode = function() return false end
ns.Glancing = function() return false end
local alpha = {}
ns.EaseAlpha = function(icon, show) alpha[icon] = show end
ns.ReleaseAlpha = function(icon) alpha[icon] = 'released' end

local registered, handler = {}, nil
CreateFrame = function()
    return {
        RegisterUnitEvent = function(_, event) registered[event] = true; return true end,
        RegisterEvent = function(_, event) registered[event] = true end,
        SetScript = function(_, _, fn) handler = fn end,
    }
end

local spells, counts = {}, { cooldown = 0, info = 0 }
local overrides = {}
C_Spell = {
    GetSpellName = function(id) return spells[id] and spells[id].name end,
    GetSpellCooldown = function(id)
        counts.cooldown = counts.cooldown + 1
        local s = spells[id]
        if s.cd == SECRET then return { startTime = SECRET, duration = SECRET } end
        return { startTime = s.cd[1], duration = s.cd[2] }
    end,
    IsSpellUsable = function(id) local s = spells[id]; return s.usable ~= false, s.noPower or false end,
}
GetSpellBaseCooldown = function(id) return (spells[id].base or 0) * 1000, 1500 end
C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(id)
    counts.info = counts.info + 1
    return { spellID = id, overrideSpellID = overrides[id] }
end }
GetInventoryItemID = function() return nil end

local icons = {}
EssentialCooldownViewer = { IsVisible = function() return true end, itemFramePool = {
    EnumerateActive = function()
        local i = 0
        return function() i = i + 1; return icons[i] end
    end } }

assert(loadfile('Features/Faders/CooldownIcons.lua'))('PuroCine', ns)
local F = ns.Faders
local function icon(id, extra) local t = { cooldownID = id }; for k, v in pairs(extra or {}) do t[k] = v end; return t end
local function check(label, cond) print((cond and 'PASS ' or 'FAIL ') .. label); if not cond then os.exit(1) end end
-- UpdateFaders hands over one frame's elapsed time, whatever the time between calls.
local function update(dt) now = now + (dt or 0.05); F.UpdateCooldownIcons(0.013) end
local function fire(event, ...) handler(nil, event, ...) end
local function scans() return counts.cooldown end

check('the events that mark the icons are registered', registered.SPELL_UPDATE_COOLDOWN
    and registered.SPELL_UPDATE_USABLE and registered.PLAYER_TARGET_CHANGED
    and registered.UNIT_SPELLCAST_SUCCEEDED and registered.UPDATE_SHAPESHIFT_FORM
    and registered.PLAYER_EQUIPMENT_CHANGED)

------------------------------------------------------------------------------
-- Readiness
------------------------------------------------------------------------------
spells[1] = { name = 'Ready', cd = { 0, 0 } }
spells[2] = { name = 'OnCD', cd = { now, 30 }, base = 30 }
spells[3] = { name = 'SecretOn', cd = SECRET }
spells[4] = { name = 'SecretReady', cd = SECRET }
spells[5] = { name = 'Execute', cd = { 0, 0 }, usable = false }
spells[6] = { name = 'NoRage', cd = { 0, 0 }, usable = false, noPower = true }
spells[7] = { name = 'Gcd', cd = { now, 1.5 } }
icons = {
    icon(1), icon(2), icon(3, { isOnActualCooldown = true }),
    icon(4, { isOnActualCooldown = false }), icon(5), icon(6), icon(7),
}
update()
check('a ready spell is never held', alpha[icons[1]] == nil)
check('a readable cooldown hides', alpha[icons[2]] == false)
check('a secret cooldown and an icon on cooldown hides', alpha[icons[3]] == false)
check('a secret cooldown and a ready icon shows', alpha[icons[4]] == nil)
check('an unusable spell (Execute) hides', alpha[icons[5]] == false)
check('a spell short only of its resource stays shown', alpha[icons[6]] == nil)
check('the global cooldown counts as ready', alpha[icons[7]] == nil)

spells[2].cd = { 0, 0 }
fire('SPELL_UPDATE_COOLDOWN')
update(0.2)
check('an icon comes back when its cooldown ends', alpha[icons[2]] == true)

spells[8] = { name = 'Timed', cd = SECRET, base = 30 }
icons[8] = icon(8)
fire('SPELL_UPDATE_COOLDOWN'); update(0.2)
check('with every source hidden and no cast the icon stays shown', alpha[icons[8]] == nil)
fire('UNIT_SPELLCAST_SUCCEEDED', 'player', 'guid', 8)
update(0.2)
check('a cast starts the estimated timer: hides', alpha[icons[8]] == false)
now = now + 31; update(0.01)
check('the estimate ends: shows again', alpha[icons[8]] == true)

------------------------------------------------------------------------------
-- When the icons are read
------------------------------------------------------------------------------
-- Idle, no events: one scan every 0.5 s of real time, though each call carries 13 ms.
update(1)  -- settle
local before = scans()
for _ = 1, 200 do update(0.05) end  -- ten seconds at 20 calls a second
local idleScans = (scans() - before) / #icons
check('idle icons are read about every 0.5 s of real time (' .. idleScans .. ' scans in 10 s)',
    idleScans >= 18 and idleScans <= 22)

-- An event is read within the next call, never more often than every 0.1 s.
update(0.2)
before = scans()
fire('SPELL_UPDATE_COOLDOWN')
update(0.12)
check('an event is read on the next call', scans() > before)
before = scans()
fire('SPELL_UPDATE_COOLDOWN')
update(0.02)
check('an event right after a scan waits for the minimum gap', scans() == before)
update(0.09)
check('and is read once the gap has passed', scans() > before)

-- A storm of events stays near ten scans a second.
update(0.2)
before = scans()
for _ = 1, 100 do fire('SPELL_UPDATE_COOLDOWN'); update(0.01) end  -- one second
local storm = (scans() - before) / #icons
check('events firing every call scan about ten times a second (' .. storm .. ')', storm >= 8 and storm <= 12)

-- A cooldown about to end is read as it does, with no event and no wait for the safety scan.
for k in pairs(spells) do if k ~= 1 then spells[k] = nil end end
icons = { icon(1), icon(11) }
spells[11] = { name = 'Soon', cd = { now, 3 }, base = 3 }
update(0.6)
check('a running cooldown hides', alpha[icons[2]] == false)
local ends = now + 3 - (now - spells[11].cd[1])
local readyAt
for _ = 1, 80 do
    update(0.05)
    if alpha[icons[2]] == true then readyAt = now; break end
end
check('the icon is ready by the time its cooldown ends', readyAt ~= nil and readyAt <= ends + 0.06)
check('and not long before', readyAt >= ends - 0.45)

-- The icon's spell is kept per cooldownID instead of read from the game every scan.
overrides = {}
icons = { icon(21), icon(22), icon(23), icon(24), icon(25) }
for id = 21, 25 do spells[id] = { name = 'S' .. id, cd = { 0, 0 } } end
update(6)  -- let the old entries expire, then count
counts.info = 0
for _ = 1, 200 do update(0.05) end
check('the icon spells are read a few times in 10 s, not every scan (' .. counts.info .. ' reads)', counts.info <= 15)

-- A form change swaps the spell an icon draws: the next read sees it.
spells[26] = { name = 'Swapped', cd = { now + 1000, 60 }, base = 60 }
overrides[21] = 26
update(0.6)
check('a changed override waits for the cache or an event', alpha[icons[1]] == nil)
fire('UPDATE_SHAPESHIFT_FORM')
update(0.2)
check('a form change reads the icon spell again', alpha[icons[1]] == false)

------------------------------------------------------------------------------
-- Leaving and switching off
------------------------------------------------------------------------------
local held = icons[1]
check('the icon of the swapped spell is held hidden', alpha[held] == false)
icons = { icon(22) }
update(0.6)
check('an icon that left the window is released', alpha[held] == 'released')
spells[27] = { name = 'Later', cd = { now + 1000, 60 }, base = 60 }
overrides[22] = 27
fire('UPDATE_SHAPESHIFT_FORM')
update(0.2)
held = icons[1]
check('another icon is held while the option is on', alpha[held] == false)
option = false
update(0.1)
check('turning the option off releases the held icons', alpha[held] == 'released')
option = true
print('all good')
