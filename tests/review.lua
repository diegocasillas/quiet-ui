-- Run from the addon directory: lua tests/review.lua
local failures = 0
local unpack = table.unpack or unpack
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local function loadAddon(file, ns)
    assert(loadfile(file))('QuietUI', ns)
end
local function upvalue(fn, name)
    for i = 1, 100 do
        local key, value = debug.getupvalue(fn, i)
        if key == name then return value end
        if not key then break end
    end
    error('Missing helper: ' .. name)
end
local function frame(parent)
    local obj = { alpha = 1, shown = true, parent = parent, scripts = {}, children = {}, regions = {} }
    function obj:IsForbidden() return false end
    function obj:GetAlpha() return self.alpha end
    function obj:SetAlpha(value) self.alpha = value end
    function obj:IsShown() return self.shown end
    function obj:Show() self.shown = true end
    function obj:Hide() self.shown = false end
    function obj:GetParent() return self.parent end
    function obj:SetParent(value) self.parent = value end
    function obj:GetName() return self.name end
    function obj:GetFrameLevel() return 1 end
    function obj:GetWidth() return 100 end
    function obj:GetHeight() return 10 end
    function obj:GetNumRegions() return #self.regions end
    function obj:GetNumChildren() return #self.children end
    function obj:GetRegions()
        self.regionReads = (self.regionReads or 0) + 1
        return unpack(self.regions)
    end
    function obj:GetChildren()
        self.childReads = (self.childReads or 0) + 1
        return unpack(self.children)
    end
    function obj:SetScript(name, fn) self.scripts[name] = fn end
    function obj:HookScript() end
    for _, name in ipairs({ 'ClearAllPoints', 'SetAllPoints', 'SetPoint', 'SetFrameLevel',
        'EnableMouse', 'EnableMouseWheel', 'SetIgnoreParentAlpha', 'SetColorTexture' }) do
        obj[name] = function() end
    end
    function obj:CreateTexture() return frame(self) end
    return obj
end
local function namespace()
    QuietUIDB = { enabled = true }
    QuietUICharDB = {}
    UIParent = frame()
    GetTime = function() return 100 end
    hooksecurefunc = function(obj, method, hook)
        local original = obj[method]
        obj[method] = function(self, ...)
            local result = original(self, ...)
            hook(self, ...)
            return result
        end
    end
    local ns = {}
    loadAddon('Core.lua', ns)
    for _, name in ipairs({ 'InEditMode', 'InCombat', 'InGroup', 'InForcedInstance', 'InVehicle',
        'HasTarget', 'Glancing', 'Pinned', 'RequireLivingTarget', 'ShowAll', 'XPForced' }) do
        ns[name] = function() return false end
    end
    ns.CharDB = function() return QuietUICharDB end
    ns.ModernChat = function() return QuietUICharDB.chat ~= false end
    ns.GroupAuras = function() return true end
    ns.PlayerStyle = function() return 'classic' end
    ns.TouchHud = function() end
    return ns
end

test('Native chat stays visible after addon or Modern chat is disabled', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local strip = upvalue(ns.StripAllChat, 'StripChat')
    local bind = upvalue(strip, 'BindBubbles')
    local chat = frame()
    local font = frame(chat)
    function font:GetObjectType() return 'FontString' end
    chat.regions = { font }
    function chat:AddMessage() end
    function chat:HookScript(name, fn) self.scripts[name] = fn end
    local scrolls = 0
    function chat:ScrollUp() scrolls = scrolls + 1 end
    bind(chat)
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Active chat wheel must work')
    chat:AddMessage('enabled')
    assert(font.alpha == 0)
    QuietUICharDB.chat = false
    font.alpha = 1
    chat:AddMessage('modern chat off')
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Wheel hook remained active with Modern chat off')
    assert(font.alpha == 1, 'AddMessage hid native text with Modern chat off')
    QuietUICharDB.chat = nil
    QuietUIDB.enabled = false
    font.alpha = 1
    chat:AddMessage('addon off')
    chat.scripts.OnMouseWheel(chat, 1)
    assert(scrolls == 1, 'Wheel hook remained active with addon off')
    assert(font.alpha == 1, 'AddMessage hid native text with addon off')
    assert(#chat._quietLines == 3, 'History must still be collected while disabled')
end)

test('Native chat traversal reads each region and child list once', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local bind = upvalue(upvalue(ns.StripAllChat, 'StripChat'), 'BindBubbles')
    local chat = frame()
    function chat:AddMessage() end
    for i = 1, 8 do
        local font = frame(chat)
        function font:GetObjectType() return 'FontString' end
        chat.regions[i] = font
        chat.children[i] = frame(chat)
    end
    bind(chat)
    chat.regionReads, chat.childReads = 0, 0
    chat:AddMessage('hello')
    assert(chat.regionReads == 1, 'Region list reads: ' .. chat.regionReads)
    assert(chat.childReads == 1, 'Child list reads: ' .. chat.childReads)
end)

test('Chat verifies wrapped history and resized bubbles before going idle', function()
    local ns = namespace()
    ns.ChatFade = function() return 0 end
    loadAddon('Chat.lua', ns)
    local layout = upvalue(ns.UpdateChat, 'LayoutFrame')
    local size = upvalue(layout, 'SizeBubble')
    local function replace(fn, name, value)
        for i = 1, 100 do
            local key = debug.getupvalue(fn, i)
            if key == name then debug.setupvalue(fn, i, value); return end
            if not key then break end
        end
        error('Missing helper: ' .. name)
    end
    -- Three 60px words total 200px with spaces, but need three rows at 100px.
    replace(size, 'UnboundedWidth', function() return 200 end)
    replace(size, 'PlaceLinks', function() end)
    for _, scenario in ipairs({ 'history', 'scroll', 'hover', 'resize', 'secret', 'spacing' }) do
        local msg = { text = 'AAAAAA BBBBBB CCCCCC', born = 100,
            secret = scenario == 'secret' or nil }
        local fs = { reads = 0 }
        function fs:GetFont() return 'test', 14, '' end
        function fs:SetWidth(w) self.width = w end
        function fs:SetText() end
        function fs:SetTextColor() end
        function fs:GetStringHeight()
            self.reads = self.reads + 1
            if scenario == 'secret' and self.reads == 1 then return 0 end
            return self.width >= 200 and 14 or 42
        end
        function fs:GetNumLines() return self.width >= 200 and 1 or 3 end
        function fs:GetLineHeight() return 14 end
        function fs:GetSpacing() return scenario == 'spacing' and 2 or 0 end
        local bubble = frame()
        bubble.text, bubble.msg, bubble._y = fs, msg, 4
        function bubble:SetSize(w, h) self.width, self.height = w, h end
        local chat = frame()
        chat.width = scenario == 'resize' and 318 or 118
        function chat:GetWidth() return self.width end
        function chat:GetHeight() return 200 end
        function chat:GetFont() return 'test', 14, '' end
        chat._quietLines = scenario == 'scroll' and { msg, {} } or { msg }
        chat._quietByMsg = { [msg] = bubble }
        chat._quietDirty = true
        chat._quietHover = scenario == 'hover'
        chat._quietScroll = scenario == 'scroll' and 1 or 0
        layout(chat, 1/60)
        if scenario == 'resize' then
            assert(bubble._quietSizeKey, 'Single row should be cached')
            chat.width = 118
            layout(chat, 1/60)
        end
        assert(chat._quietNext == 0, scenario .. ': missing follow-up measurement')
        layout(chat, 1/60)
        if scenario == 'secret' then
            assert(not bubble._quietSizeKey, 'Zero height must not be cached')
            assert(chat._quietNext == 0, 'Unavailable height needs another measurement')
            layout(chat, 1/60)
        end
        assert(bubble.height >= 52, scenario .. ': last row remains clipped')
        if scenario == 'spacing' then
            local reads = fs.reads
            for _ = 1, 600 do layout(chat, 1/60) end
            print('Idle wrapped chat, 600 frames: extra height reads=' .. (fs.reads - reads))
            assert(fs.reads == reads, 'Line spacing kept remeasuring settled chat every frame')
        end
        assert(bubble._quietSizeKey, scenario .. ': measured size was not cached')
        assert(chat._quietNext == nil, scenario .. ': settled chat keeps waking')
        local reads = fs.reads
        layout(chat, 1/60)
        assert(fs.reads == reads, scenario .. ': idle chat remeasured text')
    end
end)

test('Chat uses rendered hyperlinks without covering wrapped text with buttons', function()
    local ns = namespace()
    loadAddon('Chat.lua', ns)
    local layout = upvalue(ns.UpdateChat, 'LayoutFrame')
    local create = upvalue(upvalue(layout, 'AcquireBubble'), 'CreateBubble')
    local bind = upvalue(create, 'BindBubbleLinks')
    local place = upvalue(upvalue(layout, 'SizeBubble'), 'PlaceLinks')
    local bubble = frame()
    bubble.chat, bubble.msg, bubble.links = frame(), { text = 'wrapped item links' }, {}
    function bubble:SetHyperlinksEnabled(value) self.hyperlinks = value end
    bind(bubble)
    assert(bubble.hyperlinks, 'Rendered hyperlink hit testing was not enabled')
    place(bubble, bubble.msg, 100)
    assert(#bubble.links == 0, 'Manual hit rectangles still cover rendered text')
    local oldTooltip, oldRef = GameTooltip, SetItemRef
    local shown, opened = {}, {}
    GameTooltip = {
        SetOwner = function(_, owner) assert(owner == bubble) end,
        SetHyperlink = function(_, link) shown[#shown + 1] = link end,
        Show = function() end,
        Hide = function() shown.hidden = true end,
    }
    SetItemRef = function(link, text, button, chat)
        opened[#opened + 1] = { link, text, button, chat }
    end
    -- The renderer supplies the same link on either row, and distinct adjacent links.
    for _, link in ipairs({ 'item:1', 'item:1', 'item:2' }) do
        bubble.scripts.OnHyperlinkEnter(bubble, link, '[Wrapped item]')
        bubble.scripts.OnHyperlinkClick(bubble, link, '[Wrapped item]', 'LeftButton')
        bubble.scripts.OnHyperlinkLeave(bubble)
        assert(shown[#shown] == link and shown.hidden, 'Tooltip used the wrong item')
        local click = opened[#opened]
        assert(click[1] == link and click[2] == '[Wrapped item]'
            and click[3] == 'LeftButton' and click[4] == bubble.chat)
    end
    bubble.msg = { secret = true }
    place(bubble, bubble.msg, 100)
    assert(not bubble.hyperlinks, 'Secret text still has hyperlink hit testing')
    bubble.scripts.OnHyperlinkEnter(bubble, 'item:3', '[Secret]')
    bubble.scripts.OnHyperlinkClick(bubble, 'item:3', '[Secret]', 'LeftButton')
    assert(#shown == 3 and #opened == 3, 'Secret message opened a link')
    bubble.msg = { text = 'reused bubble' }
    place(bubble, bubble.msg, 200)
    assert(bubble.hyperlinks, 'Reused bubble did not restore hyperlink hit testing')
    bind(frame()) -- Older clients may lack the method.
    GameTooltip, SetItemRef = oldTooltip, oldRef
end)

test('Always show debuffs defaults on and survives saves, presets and reset', function()
    local ns = namespace()
    ns.BAR_ROWS = {}
    loadAddon('Presets.lua', ns)
    loadAddon('Setup.lua', ns)
    local read = upvalue(upvalue(ns.ShowSetup, 'LoadSavedDraft'), 'ReadDraft')
    local saved = upvalue(upvalue(upvalue(ns.ShowSetup, 'CreateSetup'), 'Write'), 'DraftSettings')
    local draft = upvalue(read, 'draft')
    assert(ns.AlwaysShowDebuffs(), 'Missing setting must default on')
    read()
    assert(draft.alwaysShowDebuffs)
    draft.alwaysShowDebuffs = false
    ns.ActivatePreset(nil, saved())
    assert(QuietUICharDB.alwaysShowDebuffs == false and not ns.AlwaysShowDebuffs())
    local id = assert(ns.SavePreset(nil, 'Debuffs fade', {}, saved()))
    ns.ActivatePreset(id)
    assert(not ns.AlwaysShowDebuffs(), 'Preset did not retain opt-out')
    ns.DeletePreset(id)
    assert(not ns.AlwaysShowDebuffs(), 'Deleting preset lost personal snapshot')
    read({})
    ns.ActivatePreset(nil, saved())
    assert(ns.AlwaysShowDebuffs() and QuietUICharDB.alwaysShowDebuffs == nil,
        'Reset must restore default without storing an explicit true')
    read({ alwaysShowDebuffs = false })
    draft.alwaysShowDebuffs = true
    ns.ActivatePreset(nil, saved())
    assert(ns.AlwaysShowDebuffs(), 'Re-enabling did not clear opt-out')
end)

test('Debuffs stay visible alone and opt-out restores aura fading and alpha', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    local update = upvalue(ns.UpdateSmooth, 'UpdateAuras')
    BuffFrame, DebuffFrame, TemporaryEnchantFrame = frame(UIParent), frame(UIParent), frame(UIParent)
    DebuffFrame.alpha = 0.8
    ns.PlayerStyle = function() return 'resource' end
    ns.GroupAuras = function() return false end
    ns.FindFaders(false)
    update(1)
    assert(DebuffFrame.alpha == 1, 'Default did not show debuffs with player frame off')
    assert(BuffFrame.alpha == 0 and TemporaryEnchantFrame.alpha == 0, 'Debuffs revealed buffs')
    DebuffFrame:SetAlpha(0)
    assert(DebuffFrame.alpha == 1, 'Blizzard alpha overwrite was not held')
    QuietUICharDB.alwaysShowDebuffs = false
    update(0.15)
    assert(DebuffFrame.alpha > 0 and DebuffFrame.alpha < 1, 'Opt-out did not fade smoothly')
    update(1)
    assert(DebuffFrame.alpha == 0)
    ns.InCombat = function() return true end
    update(1)
    assert(DebuffFrame.alpha == 1 and BuffFrame.alpha == 1, 'Opt-out broke normal combat visibility')
    QuietUICharDB.alwaysShowDebuffs = nil
    ns.RestoreAlpha()
    QuietUIDB.enabled = false
    assert(DebuffFrame.alpha == 0.8, 'Disable did not restore original alpha')
    DebuffFrame:SetAlpha(0.4)
    assert(DebuffFrame.alpha == 0.4, 'Disabled addon still held debuff alpha')
    BuffFrame, DebuffFrame, TemporaryEnchantFrame = nil, nil, nil
end)

test('Always visible debuffs override the shared power alpha curve', function()
    local ns = namespace()
    loadAddon('Setup.lua', ns)
    loadAddon('Faders.lua', ns)
    local update = upvalue(ns.UpdateSmooth, 'UpdateAuras')
    for i = 1, 100 do
        local name = debug.getupvalue(update, i)
        if name == 'RestingPower' then debug.setupvalue(update, i, function() return 0 end) end
        if name == 'EvalPower' then debug.setupvalue(update, i, function() return 0.25 end) end
        if not name then break end
    end
    BuffFrame, DebuffFrame = frame(UIParent), frame(UIParent)
    ns.FindFaders(false)
    update(1)
    assert(BuffFrame.alpha == 0.25 and DebuffFrame.alpha == 1)
    QuietUICharDB.alwaysShowDebuffs = false
    update(1)
    assert(DebuffFrame.alpha == 0.25, 'Opt-out did not rejoin the power curve')
    BuffFrame, DebuffFrame = nil, nil
end)

test('Damage meter follows combat, instance, group, edit mode and grace only', function()
    local ns = namespace()
    loadAddon('Faders.lua', ns)
    DamageMeter = frame(UIParent)
    ns.FindFaders(false)
    ns.Hit = function() return true end
    ns.NextFadeTick()
    ns.ShowAll = function() return true end -- flyout or cursor item
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 0, 'Hover or bar showAll revealed meter')
    ns.InGroup = function() return true end
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 1, 'Group did not reveal meter')
    ns.InGroup = function() return false end
    ns.MarkCombatEnd()
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 1, 'Post-combat grace missing')
    GetTime = function() return 111 end
    ns.NextFadeTick()
    ns.UpdateFaders(1)
    assert(DamageMeter.alpha == 0, 'Post-combat grace did not expire')
    DamageMeter = nil
end)

test('Range mark detaches after fading and stops nameplate lookups', function()
    local ns = namespace()
    loadAddon('Faders.lua', ns)
    ns.Range = function() return 'spell', 'hostile', 'Test' end
    UnitExists = function() return true end
    UnitIsDeadOrGhost = function() return false end
    C_Spell = { IsSpellInRange = function() return true end }
    local plate, health = frame(UIParent), frame()
    plate.UnitFrame = { healthBar = health, IsShown = function() return true end }
    local lookups = 0
    C_NamePlate = { GetNamePlateForUnit = function() lookups = lookups + 1; return plate end }
    local mark
    CreateFrame = function() mark = frame(UIParent); return mark end
    ns.UpdateRange(0.1)
    assert(mark.shown and mark.parent == health and mark.alpha == 1)
    ns.Range = function() end
    ns.UpdateRange(0.3)
    assert(not mark.shown and mark.parent == UIParent, 'Invisible gradient stayed on nameplate')
    local before = lookups
    for i = 1, 60 do ns.UpdateRange(1 / 60) end
    assert(lookups == before, 'Hidden gradient still scanned nameplate')
end)

test('Core texture traversal reads the region list once', function()
    local ns = namespace()
    local root = frame()
    for i = 1, 8 do
        local texture = frame(root)
        function texture:GetObjectType() return 'Texture' end
        root.regions[i] = texture
    end
    ns.HideTextures(root)
    assert(root.regionReads == 1, 'Region list reads: ' .. root.regionReads)
end)


test('Target death invalidates cached bars without pointer movement', function()
    local ns = namespace()
    loadAddon('Frames.lua', ns)
    loadAddon('Bars.lua', ns)
    MainActionBar = frame(UIParent)
    MainActionBar.name = 'MainActionBar'
    CreateFrame = function() return frame(UIParent) end
    ns.Glancing = function() return false end
    ns.BagsShouldShow = function() return false end
    QuietUICharDB.friendly = { ['1'] = true }
    local dead = false
    UnitExists = function() return true end
    UnitIsFriend = function() return true end
    UnitCanAttack = function() return false end
    UnitIsDeadOrGhost = function() return dead end
    ns.RefreshWorld()
    ns.ConsumeHud()
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    assert(MainActionBar.alpha == 1, 'Living friendly target did not show its bar')
    dead = true
    ns.RefreshWorld()
    assert(ns.ConsumeHud(), 'Target death did not invalidate cached bar visibility')
    ns.NextFadeTick()
    ns.UpdateBars(false, 1, true)
    assert(MainActionBar.alpha == 0, 'Dead friendly target kept its bar visible')
    MainActionBar = nil
end)

test('Show-all transitions recalculate bars even with a stationary pointer', function()
    local ns = namespace()
    local events
    CreateFrame = function() events = frame(); function events:RegisterEvent() end; return events end
    SlashCmdList = {}
    loadAddon('QuietUI.lua', ns)
    local update = events.scripts.OnUpdate
    for i = 1, 100 do
        local name = debug.getupvalue(update, i)
        if name == 'booted' then debug.setupvalue(update, i, true); break end
    end
    ns.BeginTick = function() end
    ns.FocusChanged = function() return false end
    ns.ConsumeHud = function() return false end
    ns.UpdateFaders = function() end
    ns.UpdateMenuButton = function() end
    ns.UpdateRange = function() end
    ns.UpdateSmooth = function() end
    ns.UpdateChat = function() end
    ns.ForgetCursor = function() end
    GetCursorPosition = function() return 0, 0 end
    SpellFlyout = nil
    local force, scans = false, 0
    ns.ShowAll = function() return force end
    ns.UpdateBars = function(_, _, rescan) if rescan then scans = scans + 1 end end
    update(events, 0.01)
    scans = 0
    force = true
    update(events, 0.01)
    assert(scans == 1, 'Entering edit mode did not recalculate bars')
    scans = 0
    force = false
    update(events, 0.01)
    assert(scans == 1, 'Leaving edit mode did not recalculate bars')
    QuietUIGlance('up')
    assert(not ns.Glancing(), 'Key-up toggled Glance')
    QuietUIGlance('down')
    assert(ns.Glancing(), 'Key-down did not toggle Glance')
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Second key-down did not clear Glance')
    SlashCmdList.QUIETUI('  GlAnCe  ')
    assert(ns.Glancing(), 'Slash command did not toggle Glance')
    assert(QuietUIDB.enabled, 'Glance command disabled the addon')
    scans = 0
    update(events, 0.01)
    assert(scans == 1, 'Glance command did not recalculate bars')
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Key binding did not clear command Glance')
    SlashCmdList.QUIETUI('glance')
    SlashCmdList.QUIETUI('glance')
    assert(not ns.Glancing(), 'Second Glance command did not clear Glance')
    QuietUIDB.enabled = false
    QuietUIGlance('down')
    assert(not ns.Glancing(), 'Glance toggled while addon was disabled')
    SlashCmdList.QUIETUI('glance')
    assert(not ns.Glancing(), 'Glance command toggled while addon was disabled')
    assert(not QuietUIDB.enabled, 'Glance command enabled the addon')
    QuietUIDB.enabled = true
    SlashCmdList.QUIETUI('glance')
    for _, name in ipairs({ 'HideQuestCatcher', 'HideRangeMark', 'HideBarCatchers',
        'ResetMenu', 'RestoreChat', 'RestoreAlpha' }) do
        ns[name] = function() end
    end
    ns.ForceQuietLayout = function() return false end
    SlashCmdList.QUIETUI('off')
    assert(not ns.Glancing(), 'Disabling the addon did not clear command Glance')
    assert(not QuietUIDB.enabled, 'Off command did not disable the addon')
end)

os.exit(failures == 0 and 0 or 1)
