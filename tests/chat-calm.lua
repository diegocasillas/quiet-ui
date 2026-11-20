-- Run from the addon directory: lua tests/chat-calm.lua
-- A still pointer with nothing moving skips the chat pass, apart from one every 0.1 s.
-- A dirty window, a due bubble, a tab starting to flash, a window shown or hidden (Wake),
-- an input box easing, or a moving pointer runs one at once.
local ns, now = {}, 100
local cursorX, cursorY = 10, 10
GetTime = function() return now end
GetCursorPosition = function() return cursorX, cursorY end
NUM_CHAT_WINDOWS = 2
ns.DB = function() return { enabled = true } end
ns.ModernChat = function() return true end
ns.Usable = function() return true end
ns.IsSecret = function() return false end
ns.Report = function(_, err) error(err) end
ns.Wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
ns.EaseAlpha = function() end
local counts = { tabs = 0, hover = 0, layout = 0 }
local tabsEasing = false

local function shown() return true end
local frame1 = { _puroCineBubbles = true, IsShown = shown }
local frame2 = { _puroCineBubbles = true, IsShown = shown }
local tab1 = { IsShown = shown }
ChatFrame1, ChatFrame2, ChatFrame1Tab = frame1, frame2, tab1

assert(loadfile('Features/Chat/Base.lua'))('PuroCine', ns)
local Chat = ns.Chat
assert(Chat.Window(1) == frame1 and Chat.Window(1, 'Tab') == tab1, 'Chat.Window must find windows and tabs')
assert(loadfile('Features/Chat/Update.lua'))('PuroCine', ns)
Chat.HideActive, Chat.PlaceCatcher, Chat.HideNativeText = function() end, function() end, function() end
Chat.FrameHot = function() counts.hover = counts.hover + 1; return false end
Chat.TabRowHot = function() return false end
Chat.LayoutFrame = function(frame) counts.layout = counts.layout + 1; frame._puroCineDirty = nil end
Chat.FadeTabs = function() counts.tabs = counts.tabs + 1; return tabsEasing end

local function update(step)
    now = now + (step or 0.01)
    ns.UpdateChat(step or 0.01)
end
local function passes() return counts.tabs end
local function expect(n, why) assert(passes() == n, why .. ' (passes ' .. passes() .. ', expected ' .. n .. ')') end

-- The first call is a full pass; a still pointer then goes calm.
update()
expect(1, 'The first call must run a full pass')
update(); update()  -- the pointer has not moved since the first read: calm starts after this pass
local calmStart = passes()
for _ = 1, 5 do update(0.01) end
expect(calmStart, 'A still pointer with nothing to do must skip the pass')

-- After 0.1 s one periodic pass runs.
update(0.1)
expect(calmStart + 1, 'A calm chat must still run a pass every 0.1 s')
local base = passes()

-- A moving pointer runs a pass every call.
cursorX = cursorX + 5; update(0.01)
cursorX = cursorX + 5; update(0.01)
expect(base + 2, 'A moving pointer must run a full pass')
update(0.01); update(0.01)  -- still again: one more pass settles, then calm
base = passes()
for _ = 1, 3 do update(0.01) end
expect(base, 'The chat must go calm again once the pointer stops')

-- A dirty window runs a pass and lays out at once.
frame1._puroCineDirty = true
update(0.01)
expect(base + 1, 'A dirty window must run a pass at once')
assert(counts.layout >= 1, 'A dirty window must be laid out')
base = passes(); update(0.01); update(0.01)
base = passes()

-- Wake (a window shown or hidden, an input box changing focus) runs a pass at once.
update(0.01)
expect(base, 'Calm again before the wake test')
Chat.Wake()
update(0.01)
expect(base + 1, 'Wake must run a pass on the next call')
update(0.01); update(0.01)
base = passes()

-- A bubble due to fade wakes the chat at its time, and not before.
frame1._puroCineNext = now + 0.05
update(0.01); update(0.01)
expect(base, 'A bubble that is not due yet must not wake the chat')
update(0.05)
assert(passes() > base, 'A due bubble must run a pass')
frame1._puroCineNext = nil
update(0.01); update(0.01); base = passes()

-- A tab that starts to flash runs a pass.
tab1.alerting = true
update(0.01)
expect(base + 1, 'A tab starting to flash must run a pass')
tab1.alerting = nil
update(0.01); update(0.01); base = passes()

-- An input box still easing keeps the chat awake until it settles.
local edit = { _puroCineEdit = true, _puroCineWant = 1, _puroCineAlpha = 0 }
ChatFrame1EditBox = edit
Chat.Wake()  -- focus changes call Wake through SyncEdit
update(0.01); base = passes()
update(0.01); update(0.01)
expect(base + 2, 'An input box that still eases must keep the passes going')
edit._puroCineAlpha = 1
update(0.01); update(0.01); base = passes()
update(0.01); update(0.01)
expect(base, 'A settled input box must let the chat go calm')

-- A tab still easing keeps the chat awake.
tabsEasing = true
Chat.Wake()
update(0.01); base = passes()
update(0.01); update(0.01)
expect(base + 2, 'Tabs that still ease must keep the passes going')
tabsEasing = false
update(0.01); update(0.01); update(0.01); base = passes()

-- One idle second at 60 fps: about ten passes, not sixty.
update(0.01); update(0.01); base = passes()
for _ = 1, 60 do update(1 / 60) end
local idle = passes() - base
assert(idle >= 8 and idle <= 12, 'An idle second must run about ten passes, ran ' .. idle)

-- While bubbles animate (the window asks to run every frame) with a still pointer, the pass
-- runs every call but the hover is read only about every 0.1 s.
frame1._puroCineNext = 0
counts.hover = 0
local startPasses = passes()
for _ = 1, 20 do update(0.005) end
assert(passes() - startPasses == 20, 'An animating chat must run a pass every call')
assert(counts.hover <= 3, 'A still pointer must not read the hover every call, read ' .. counts.hover)
frame1._puroCineNext = nil

-- Modern chat off, or the addon off: nothing runs.
ns.ModernChat = function() return false end
base = passes(); Chat.Wake(); update(0.01)
expect(base, 'Nothing may run while modern chat is off')
print('PASS chat goes calm on a still pointer and wakes for dirty windows, due bubbles, tabs, inputs and Wake')
