-- Run from the addon directory: lua tests/presets.lua
local ns = {}
PuroCineDB = {}
PuroCineCharDB = { chat = false, range = { yards = 28 } }
ns.DB = function() return PuroCineDB end
ns.CharDB = function() return PuroCineCharDB end
local file = io.open('Settings/Presets.lua', 'r')
if file then file:close(); dofile('tests/addon.lua')('Presets.lua', ns) end
assert(type(ns.SavePreset) == 'function', 'Preset creation is not implemented')
local id = assert(ns.SavePreset(nil, '  Healer  ', PuroCineCharDB))
assert(PuroCineDB.presets[id].name == 'Healer')
assert(PuroCineDB.presets[id].settings.chat == false)
local first = PuroCineCharDB
ns.ActivatePreset(id)
PuroCineCharDB = {}
assert(ns.Settings().chat == nil, 'New characters must not inherit a preset')
ns.ActivatePreset(id)
assert(ns.Settings().chat == false)
ns.SavePreset(id, 'Healing', { chatFade = 0, groups = { [1] = 3 } })
PuroCineCharDB = first
assert(ns.Settings().chatFade == 0, 'Shared edits must reach other characters')
assert(ns.Settings().chat == nil, 'Missing values must replace old settings')
assert(PuroCineDB.presets[id].name == 'Healing')
PuroCineCharDB.groups[1] = 8
assert(PuroCineDB.presets[id].settings.groups[1] == 3, 'Snapshots must not alias shared settings')
assert(not ns.SavePreset(nil, ' healing ', {}), 'Duplicate names must be rejected')
assert(not ns.SavePreset(nil, '   ', {}), 'Empty names must be rejected')
first.groups[1] = 3
ns.Settings()
PuroCineCharDB = {}
ns.ActivatePreset(id)
ns.DeletePreset(id)
PuroCineCharDB = first
assert(ns.Settings().groups[1] == 3)
assert(first.presetId == nil, 'Deleted presets must detach other characters')
print('PASS shared presets, rename, validation, snapshots and deletion')
