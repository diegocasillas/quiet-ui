local ns = {}
QuietUIDB = {}; QuietUICharDB = { chatFade = 20 }
local function widget(parent)
    local obj = { parent = parent, scripts = {}, shown = true, text = '' }
    return setmetatable(obj, { __index = function(self, key)
        if key == 'CreateTexture' or key == 'CreateFontString' then return function() return widget(self) end end
        if key == 'GetScript' then return function(_, event) return self.scripts[event] end end
        if key == 'SetScript' then return function(_, event, fn) self.scripts[event] = fn end end
        if key == 'HookScript' then return function(_, event, fn) self.scripts[event] = fn end end
        if key == 'SetText' then return function(_, value) self.text = value; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end end
        if key == 'GetText' then return function() return self.text end end
        if key == 'GetName' then return function() return self.name end end
        if key == 'GetFrameLevel' then return function() return 1 end end
        if key == 'HasFocus' then return function() return false end end
        if key == 'Show' then return function() self.shown = true end end
        if key == 'Hide' then return function() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
        if key == 'IsShown' then return function() return self.shown end end
        if key == 'GetFontString' then return function() return widget(self) end end
        if key == 'Disable' or key == 'HighlightText' then return function() end end
        if key:match('^Set') or key:match('^Enable') or key:match('^Clear') or key:match('^Register') then return function() end end
    end })
end
UIParent = widget()
CreateFrame = function(_, name, parent) local obj = widget(parent); obj.name = name; if name then _G[name] = obj end; return obj end
UISpecialFrames = {}
ns.DB = function() return QuietUIDB end
ns.IsSecret = function() return false end
ns.Print = function(message) ns.message = message end
ns.BAR_ROWS = { { id = 1, label = 'Bar 1', group = 1 }, { id = 2, label = 'Bar 2', group = 2 } }
ns.BarGroup = function() return 1 end
ns.BarTarget = function() return false end
ns.ApplyAll = function() end
ns.CurrentLayoutRef = function() return { layoutName = 'Raid', layoutType = 1 } end
ns.LayoutChoices = function() return { { name = 'Other', ref = { layoutName = 'Other', layoutType = 1 } } } end
local preview, committed, cancelled
ns.PreviewLayout = function(ref) preview = ref.layoutName end
ns.CommitLayoutPreview = function() committed = true; preview = nil end
ns.CancelLayoutPreview = function() cancelled = true; preview = nil end
assert(loadfile('Presets.lua'))('QuietUI', ns)
assert(loadfile('Setup.lua'))('QuietUI', ns)
local id = ns.SavePreset(nil, 'Healer', ns.CurrentLayoutRef(), { chat = false, chatFade = 0, groupAuras = false, player = 'resource',
    requireLivingTarget = true, visible = { bars = true, swing = true },
    groups = { [1] = 2 }, hostile = { [1] = true }, friendly = { [2] = true },
    range = { yards = 'spell', kind = 'friendly', spell = 'Heal' } })
ns.ShowSetup()
local ui = QuietUISetup
assert(ui.presetSelector, 'General has no preset selector')
ui.presetSelector.scripts.OnClick()
assert(ui.presetMenu, 'Preset selector must open a menu')
ui.presetMenu.items[2].scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, 'Selection must remain a draft')
ui:Hide(); ns.ShowSetup(); ui.save.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chatFade == 20, 'Closing discards selection')
ui.presetSelector.scripts.OnClick(); ui.presetMenu.items[2].scripts.OnClick(); ui.save.scripts.OnClick()
assert(QuietUICharDB.presetId == id and QuietUICharDB.chat == false and QuietUICharDB.chatFade == 0)
ui.layoutSelector.scripts.OnClick(); ui.layoutMenu.items[1].scripts.OnClick()
assert(preview == 'Other', 'Layout selection must preview immediately')
assert(ns.Presets()[id].layout.layoutName == 'Raid', 'Preview must not save the shared preset')
ui:Hide(); ns.ShowSetup()
assert(cancelled and preview == nil and ns.Presets()[id].layout.layoutName == 'Raid')
ui.layoutSelector.scripts.OnClick(); ui.layoutMenu.items[1].scripts.OnClick(); ui.save.scripts.OnClick()
assert(committed and ns.Presets()[id].layout.layoutName == 'Other', 'Save must commit the preview')
assert(QuietUICharDB.groupAuras == false and QuietUICharDB.player == 'resource')
assert(QuietUICharDB.requireLivingTarget and QuietUICharDB.visible.bars and QuietUICharDB.visible.swing)
assert(QuietUICharDB.groups[1] == 2 and QuietUICharDB.hostile[1] and QuietUICharDB.friendly[2])
assert(QuietUICharDB.range.spell == 'Heal' and QuietUICharDB.range.kind == 'friendly')
ui.presetSelector.scripts.OnClick(); ui.presetMenu.items[1].scripts.OnClick(); ui.save.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chat == false, 'Detach preserves settings')
ns.ActivatePreset(id); ns.ShowSetup(); ui.reset.scripts.OnClick()
assert(not QuietUICharDB.presetId and QuietUICharDB.chat == nil)
assert(ns.Presets()[id].settings.chat == false, 'Reset must not mutate shared preset')
ui.newPreset.scripts.OnClick()
ui.presetDialog.edit:SetText('  Tank  ')
ui.presetDialog.yes.scripts.OnClick()
assert(#ns.PresetList() == 1, 'New preset stays a draft')
ui.save.scripts.OnClick()
local tank = QuietUICharDB.presetId
assert(tank and tank ~= id and ns.Presets()[tank].name == 'Tank')
ui.renamePreset.scripts.OnClick()
ui.presetDialog.edit:SetText('Healing')
ui.presetDialog.yes.scripts.OnClick()
ui:Hide(); ns.ShowSetup()
assert(ns.Presets()[tank].name == 'Tank', 'Closing must discard rename')
ui.renamePreset.scripts.OnClick()
ui.presetDialog.edit:SetText('Defender')
ui.presetDialog.yes.scripts.OnClick()
ui.save.scripts.OnClick()
assert(QuietUICharDB.presetId == tank and ns.Presets()[tank].name == 'Defender')
ui.deletePreset.scripts.OnClick()
ui.presetDialog.no.scripts.OnClick()
assert(ns.Presets()[tank], 'Cancelling deletion must preserve the preset')
ui.deletePreset.scripts.OnClick()
ui.presetDialog.yes.scripts.OnClick()
assert(not ns.Presets()[tank] and not QuietUICharDB.presetId)
print('PASS General draft selection, cancel, save, detach and reset')
