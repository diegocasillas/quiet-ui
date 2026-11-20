-- Run from the addon directory: lua tests/menu-update.lua
-- The micro menu is hidden nearly all the time, so an update that finds nothing to do must
-- cost almost nothing: the catcher's corners and the hover targets are read when the button
-- list is built (the chrome refresh, UpdateMicroButtons, ResetMenu), not on every update.
local ns = {}
local enabled, editMode = true, false
local counts = { edges = 0, bagWalk = 0, strata = 0 }
local hovered, faded = {}, {}

ns.DB = function() return { enabled = enabled } end
ns.InEditMode = function() return editMode end
ns.Usable = function(f) return type(f) == 'table' end
ns.FrameName = function(f) return f and f.name end
ns.Hit = function(f) return hovered[f] and true or false end
ns.VisibilityShow = function(_, _, isHovered) return isHovered end
ns.UpdateFaded = function(frame, show) faded[frame] = show end
ns.ArmCatcher = function() end
ns.CursorHasItem = function() return false end
ns.IsBarFrame, ns.IsBagRelated, ns.IsSpared, ns.IsQueue = function() return false end, function() return true end, function() return false end, function() return false end
ns.TreeHas = function() return false end
ns.HideTextures, ns.Mute = function() end, function() end
ns.Report = function(name, err) error('Report: ' .. name .. ' ' .. tostring(err)) end

local function frame(name, left, shown)
    local f = { name = name, shown = shown ~= false }
    local function edge(value) return function() counts.edges = counts.edges + 1; return value end end
    f.GetLeft, f.GetRight, f.GetTop, f.GetBottom = edge(left), edge(left + 20), edge(40), edge(10)
    f.IsShown = function(self) return self.shown end
    f.GetFrameStrata = function() counts.strata = counts.strata + 1; return 'MEDIUM' end
    f.GetFrameLevel = function() return 5 end
    return f
end
local buttons = { frame('CharacterMicroButton', 0), frame('SpellbookMicroButton', 30), frame('MainMenuMicroButton', 60) }
for _, b in ipairs(buttons) do _G[b.name] = b end
local bagBar = frame('BagsBar', 100)
local bagSlot = frame('BagSlot', 120)
_G.BagsBar = bagBar

CreateFrame = function()
    local f = { shown = false }
    for _, method in ipairs({ 'SetAlpha', 'ClearAllPoints', 'SetPoint', 'SetFrameStrata', 'SetFrameLevel' }) do
        f[method] = function() end
    end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    f.IsShown = function(self) return self.shown end
    return f
end
-- The bag bar's frames: the bar and one slot. The walk counts, since it allocates.
ns.EachBagFrame = function(fn)
    counts.bagWalk = counts.bagWalk + 1
    fn(bagBar)
    fn(bagSlot)
end

dofile('tests/addon.lua')('Menu.lua', ns)
local function check(label, cond) print((cond and 'PASS ' or 'FAIL ') .. label); if not cond then os.exit(1) end end
local function reset() counts.edges, counts.bagWalk, counts.strata = 0, 0, 0 end

ns.RefreshChrome()
reset()
ns.UpdateMenuButton(0.016)
check('the first update after a build reads the corners', counts.edges > 0)
check('and puts the buttons at the shown state it was asked for', faded[buttons[1]] == false)

-- A hundred updates with nothing to do read no corners, no strata and walk no bags.
reset()
for _ = 1, 100 do ns.UpdateMenuButton(0.016) end
check('idle updates read no button corners (' .. counts.edges .. ' reads)', counts.edges == 0)
check('idle updates read no frame strata', counts.strata == 0)
check('idle updates do not walk the bag bar', counts.bagWalk == 0)

-- Hover still shows the menu: a micro button, the catcher, or the bag bar's frames.
hovered[buttons[2]] = true
ns.UpdateMenuButton(0.016)
check('hovering a micro button shows the menu', faded[buttons[1]] == true)
hovered[buttons[2]] = nil
ns.UpdateMenuButton(0.016)
check('leaving it hides the menu again', faded[buttons[1]] == false)
hovered[bagSlot] = true
ns.UpdateMenuButton(0.016)
check('hovering a bag frame shows the menu', faded[buttons[1]] == true)
hovered[bagSlot] = nil
ns.UpdateMenuButton(0.016)

-- The chrome refresh (every second, and on UpdateMicroButtons) reads the corners again.
reset()
ns.RefreshChrome()
check('a rebuild walks the bag bar once', counts.bagWalk == 1)
ns.UpdateMenuButton(0.016)
check('and the next update reads the corners again', counts.edges > 0)
reset()
for _ = 1, 20 do ns.UpdateMenuButton(0.016) end
check('then it is quiet again', counts.edges == 0)

-- A new bag frame is picked up by the next rebuild.
local lateSlot = frame('LateSlot', 140)
local oldWalk = ns.EachBagFrame
ns.EachBagFrame = function(fn) oldWalk(fn); fn(lateSlot) end
hovered[lateSlot] = true
ns.UpdateMenuButton(0.016)
check('a bag frame created after the build is not read before the next rebuild', faded[buttons[1]] == false)
ns.RefreshChrome()
ns.UpdateMenuButton(0.016)
check('and is hover after it', faded[buttons[1]] == true)
hovered[lateSlot] = nil
ns.UpdateMenuButton(0.016)

-- Edit Mode hides the catcher; leaving it puts it back at once.
editMode = true
ns.UpdateMenuButton(0.016)
editMode = false
reset()
ns.UpdateMenuButton(0.016)
check('leaving Edit Mode reads the corners again', counts.edges > 0)

-- ResetMenu (the addon turning off) rebuilds, so turning it on places the catcher again.
ns.ResetMenu()
reset()
ns.UpdateMenuButton(0.016)
check('after ResetMenu the corners are read again', counts.edges > 0)

-- A button list that changes without any event is caught by the next rebuild.
buttons[3].shown = false
ns.RefreshChrome()
reset()
ns.UpdateMenuButton(0.016)
check('a changed button set is read at the next rebuild', counts.edges > 0)
print('all good')
