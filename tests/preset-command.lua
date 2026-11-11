-- Run from the addon directory: lua tests/preset-command.lua
local ns = {}
local db, char = { enabled = true }, {}
ns.DB = function() return db end
ns.CharDB = function() return char end
dofile('tests/addon.lua')('Presets.lua', ns)
local healer = ns.SavePreset(nil, 'Raid Healer', { chatFade = 0 })
local minimal = ns.SavePreset(nil, 'Minimal', { chat = false })
ns.ModernChat = function() return false end
for _, key in ipairs({ 'RefreshWorld', 'RefreshChrome', 'RestoreChat',
    'NextFadeTick', 'BeginTick', 'UpdateBars', 'UpdateFaders', 'UpdateMenuButton',
    'UpdateBagSlots', 'HideQuestCatcher', 'HideRangeMark', 'HideBarCatchers',
    'ResetMenu', 'RestoreAlpha', 'ForgetCursor', 'NoteCombat', 'MarkCombatEnd' }) do ns[key] = function() end end
ns.Report = function(_, err) error(err) end
ns.ShowAll = function() return false end
local messages, refreshed = {}, 0
ns.Print = function(message) messages[#messages + 1] = message end
ns.RefreshSetup = function() refreshed = refreshed + 1 end
local events = { scripts = {} }
function events:SetScript(key, value) self.scripts[key] = value end
function events:RegisterEvent() end
CreateFrame = function() return events end
SlashCmdList = {}
dofile('tests/addon.lua')('PuroCine.lua', ns)
for i = 1, 100 do
    local name = debug.getupvalue(events.scripts.OnEvent, i)
    if name == 'booted' then debug.setupvalue(events.scripts.OnEvent, i, true); break end
end
local command = SlashCmdList.PUROCINE
command('preset')
assert(messages[1] == 'Current preset: <no preset>.')
assert(messages[2] == 'Available presets: "Minimal", "Raid Healer".')
assert(char.presetId == nil)
command('  PrEsEt "rAiD hEaLeR"  ')
assert(char.presetId == healer and char.chatFade == 0 and db.enabled)
assert(refreshed == 1)
assert(messages[#messages] == 'Preset "Raid Healer" selected.')
command('preset Missing')
assert(messages[#messages]:find('was not found', 1, true))
command('preset "Raid Healer')
assert(messages[#messages] == 'Use /purocine preset "name".')
command('preset ""')
assert(messages[#messages]:find('was not found', 1, true))
assert(char.presetId == healer)
db.presets.duplicate = { name = 'RAID HEALER', settings = {} }
command('preset "Raid Healer"')
assert(messages[#messages]:find('More than one preset', 1, true))
assert(char.presetId == healer)
db.presets.duplicate = nil
command('preset Minimal')
assert(char.presetId == minimal and char.chat == false and char.chatFade == nil)
assert(db.enabled)
command('preset Raid Healer')
assert(char.presetId == healer)
command('off')
assert(not db.enabled)
command('preset Minimal')
assert(not db.enabled and char.presetId == minimal)
command('on')
assert(db.enabled and char.presetId == minimal)
command('preset')
assert(messages[#messages - 1] == 'Current preset: Minimal.')
db.presets = {}
command('preset')
assert(messages[#messages] == 'Available presets: none.')
assert(char.presetId == nil)
print('PASS preset commands, names, errors, snapshots and disabled selection')
