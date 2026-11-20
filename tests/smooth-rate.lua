-- Run from the addon directory: lua tests/smooth-rate.lua
-- Smooth fades update 30 times a second whatever the frame rate, a HUD change updates at
-- once, and a CPU profile lists the parts of smooth and faders under their own rows.
local ns, now, clock, messages = {}, 0, 0, {}
local db = { enabled = true }
local hud = false
ns.DB = function() return db end
ns.Print = function(message) messages[#messages + 1] = message end
ns.Report = function(_, err) error(err) end
ns.ConsumeHud = function() local value = hud; hud = false; return value end
ns.FrameHot = function() return false end
local smooth = { calls = 0, elapsed = 0 }
local profiling = false
ns.UpdateSmooth = function(elapsed, profile)
    smooth.calls, smooth.elapsed = smooth.calls + 1, smooth.elapsed + elapsed
    if profile then
        profiling = true
        profile('player frame', function() clock = clock + 2 end)
    end
end
ns.UpdateFaders = function(_, profile)
    if profile then profile('cooldown icons', function() clock = clock + 1 end) end
end
GetTime = function() return now end
debugprofilestop = function() return clock end
local events = { scripts = {} }
function events:SetScript(key, value) self.scripts[key] = value end
function events:RegisterEvent() end
function events:RegisterUnitEvent() end
CreateFrame = function() return events end
SlashCmdList = {}
dofile('tests/addon.lua')('PuroCine.lua', ns)
-- Anything the update loop asks of other files is a quiet no-op.
setmetatable(ns, { __index = function() return function() end end })
for i = 1, 100 do
    local name = debug.getupvalue(events.scripts.OnUpdate, i)
    if name == 'booted' then debug.setupvalue(events.scripts.OnUpdate, i, true); break end
end
local function frame(elapsed)
    now = now + elapsed
    events.scripts.OnUpdate(events, elapsed)
end

-- One second at 60 fps: about 30 updates that carry the whole second between them.
for _ = 1, 60 do frame(1 / 60) end
assert(smooth.calls >= 29 and smooth.calls <= 31, 'Expected about 30 smooth updates, got ' .. smooth.calls)
assert(math.abs(smooth.elapsed - 1) < 0.05, 'The updates must carry all the elapsed time, got ' .. smooth.elapsed)

-- One second at 144 fps: a step takes whole frames (5 of them, 34.7 ms), so just under 30.
smooth.calls, smooth.elapsed = 0, 0
for _ = 1, 144 do frame(1 / 144) end
assert(smooth.calls >= 27 and smooth.calls <= 31, 'Expected about 30 smooth updates at 144 fps, got ' .. smooth.calls)

-- A slow frame is not lost: the update carries it. (A HUD change first empties the carry-over.)
hud = true
frame(0)
smooth.calls, smooth.elapsed = 0, 0
frame(0.5)
assert(smooth.calls == 1 and math.abs(smooth.elapsed - 0.5) < 1e-9, 'A long frame must update once with its time')

-- A HUD change updates on its own frame, without waiting for the next step.
smooth.calls = 0
frame(0.001)
assert(smooth.calls == 0, 'A short frame must wait for the step')
hud = true
frame(0.001)
assert(smooth.calls == 1, 'A HUD change must update smooth at once')

-- The profile lists the parts after the top rows, under their section names.
SlashCmdList.PUROCINE('profile')
for _ = 1, 12 do frame(1) end
local text = table.concat(messages, '\n')
assert(profiling, 'Smooth must get the part timer while a profile runs')
assert(text:find('smooth / player frame: ', 1, true), 'Missing the smooth part row:\n' .. text)
assert(text:find('faders / cooldown icons: ', 1, true), 'Missing the faders part row:\n' .. text)
profiling = false
smooth.calls = 0
for _ = 1, 10 do frame(0.1) end
assert(not profiling, 'Smooth must not get the part timer once the profile ended')
print('PASS smooth runs at 30 Hz, a HUD change runs it at once, and the profile lists smooth and faders parts')
