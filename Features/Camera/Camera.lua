local _, ns = ...

------------------------------------------------------------------------------
-- Camera modes, set with console commands. Action is the default at login and
-- reload; Normal is the way back, and one key toggles between them. Nothing is
-- saved: a mode picked with the key lasts until the next login or reload.
-- Turning QuietUI off goes back to Normal.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_NAME_QUIETUI_CAMERA_TOGGLE = "Toggle action camera"

local MODES = {
    action = {
        "actioncam full",
        "camerakeepcharactercentered 0",
        "actioncam noheadmove",
        "actioncam focusall",
    },
    normal = {
        "actioncam off",
        "camerakeepcharactercentered 1",
    },
}

-- The mode QuietUI last set; nil until it has changed the camera.
local current

local function Apply(mode)
    if type(ConsoleExec) ~= "function" then
        ns.Report("camera", "ConsoleExec is missing")
        return
    end
    current = mode
    for _, line in ipairs(MODES[mode]) do
        local ok, err = pcall(ConsoleExec, line)
        if not ok then ns.Report("camera", err) end
    end
end

-- Does nothing while QuietUI is off, like Glance.
function ns.SetCameraMode(mode)
    if not MODES[mode] or not ns.DB().enabled then return end
    Apply(mode)
end

function ns.ToggleCamera()
    ns.SetCameraMode(current == "action" and "normal" or "action")
end

function ns.ApplyDefaultCamera()
    ns.SetCameraMode("action")
end

function ns.RestoreCamera()
    if not current then return end
    Apply("normal")
    current = nil
end

function QuietUICameraToggle(keystate)
    if keystate == "down" then ns.ToggleCamera() end
end
