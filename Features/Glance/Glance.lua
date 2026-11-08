local _, ns = ...

------------------------------------------------------------------------------
-- Press Glance to show the faded HUD. Press again and the rules apply.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_CATEGORY_CINE = "Cine"
BINDING_NAME_CINE_GLANCE = "Glance"

local glancing = false

function ns.ToggleGlance()
    if not ns.DB().enabled then return end
    glancing = not glancing
end

function CineGlance(keystate)
    if keystate == "down" then ns.ToggleGlance() end
end

function ns.Glancing()
    return glancing
end

function ns.ClearGlance()
    glancing = false
end
