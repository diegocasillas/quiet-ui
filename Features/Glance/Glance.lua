local _, ns = ...

------------------------------------------------------------------------------
-- Press Glance to show the faded HUD. Press again and the rules apply.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_CATEGORY_QUIETUI = "QuietUI"
BINDING_NAME_QUIETUI_GLANCE = "Glance"

local glancing = false

function ns.ToggleGlance()
    if not ns.DB().enabled then return end
    glancing = not glancing
end

function QuietUIGlance(keystate)
    if keystate == "down" then ns.ToggleGlance() end
end

function ns.Glancing()
    return glancing
end

function ns.ClearGlance()
    glancing = false
end
