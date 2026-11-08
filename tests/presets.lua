-- Run from the addon directory: lua tests/presets.lua
local ns = {}
CineDB = {}
CineCharDB = { forceLayout = true, chat = false, range = { yards = 28 }, previousLayout = 4 }
ns.DB = function() return CineDB end
ns.CharDB = function() return CineCharDB end
local file = io.open('Settings/Presets.lua', 'r')
if file then file:close(); dofile('tests/addon.lua')('Presets.lua', ns) end
assert(type(ns.SavePreset) == 'function', 'Preset creation is not implemented')
local id = assert(ns.SavePreset(nil, '  Healer  ', { layoutName = 'Raid', layoutType = 1 }, CineCharDB))
assert(CineDB.presets[id].name == 'Healer')
assert(CineDB.presets[id].settings.chat == false)
assert(CineDB.presets[id].settings.previousLayout == nil)
assert(CineDB.presets[id].settings.forceLayout == nil)
local first = CineCharDB
ns.ActivatePreset(id)
CineCharDB = {}
assert(ns.Settings().chat == nil, 'New characters must not inherit a preset')
ns.ActivatePreset(id)
assert(ns.Settings().chat == false)
ns.SavePreset(id, 'Healing', { layoutName = 'Raid', layoutType = 1 }, { chatFade = 0, groups = { [1] = 3 } })
CineCharDB = first
assert(ns.Settings().chatFade == 0, 'Shared edits must reach other characters')
assert(ns.Settings().chat == nil, 'Missing values must replace old settings')
assert(CineDB.presets[id].name == 'Healing')
assert(first.previousLayout == 4)
CineCharDB.groups[1] = 8
assert(CineDB.presets[id].settings.groups[1] == 3, 'Snapshots must not alias shared settings')
assert(not ns.SavePreset(nil, ' healing ', {}, {}), 'Duplicate names must be rejected')
assert(not ns.SavePreset(nil, '   ', {}, {}), 'Empty names must be rejected')
first.groups[1] = 3
ns.Settings()
CineCharDB = {}
ns.ActivatePreset(id)
ns.DeletePreset(id)
CineCharDB = first
assert(ns.Settings().groups[1] == 3)
assert(first.presetId == nil, 'Deleted presets must detach other characters')
assert(first.previousLayout == 4)
print('PASS shared presets, rename, validation, snapshots and deletion')
