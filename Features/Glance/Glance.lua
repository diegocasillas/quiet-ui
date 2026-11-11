local _, ns = ...

------------------------------------------------------------------------------
-- Press Glance to show the faded HUD. Press again and the rules apply.
-- Full glance also shows what is set to Only on hover. The two exclude each other:
-- pressing one while the other is on swaps to it; pressing the same one clears it.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_NAME_CINE_GLANCE = "Glance"
BINDING_NAME_CINE_GLANCE_FULL = "Full glance"

-- false, "glance" or "full".
local mode = false

local function Toggle(target)
    if not ns.DB().enabled then return end
    mode = mode ~= target and target
end

function ns.ToggleGlance()
    Toggle("glance")
end

function ns.ToggleFullGlance()
    Toggle("full")
end

function CineGlance(keystate)
    if keystate == "down" then ns.ToggleGlance() end
end

function CineGlanceFull(keystate)
    if keystate == "down" then ns.ToggleFullGlance() end
end

-- Either one counts as Glance; only Full glance reaches the Only on hover rows.
function ns.Glancing()
    return mode ~= false
end

function ns.FullGlancing()
    return mode == "full"
end

function ns.GlanceMode()
    return mode
end

function ns.ClearGlance()
    mode = false
end
