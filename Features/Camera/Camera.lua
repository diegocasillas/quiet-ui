local _, ns = ...

------------------------------------------------------------------------------
-- Camera modes, set with console commands. Action is the default at login and
-- reload; Normal is the way back, and one key toggles between them. Nothing is
-- saved: a mode picked with the key lasts until the next login or reload.
-- Turning Cine off goes back to Normal.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_NAME_CINE_CAMERA_TOGGLE = "Toggle action camera"

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

-- The mode Cine last set; nil until it has changed the camera.
local current

-- The game's zoom limit is 15 yards times cameraDistanceMaxZoomFactor.
-- CameraZoomOut and CameraZoomIn glide, and carry the camera further than
-- asked, so a step sent every frame piles up and overshoots (into first person
-- on the way in). Instead one step is sent, the camera is left to settle, and
-- then the real distance is read again.
local ZOOM_BASE = 15
-- The combat zoom stops a little short of that limit.
local ZOOM_SHARE = 0.6
local ZOOM_GAIN = 0.5   -- share of the remaining distance sent per step
local ZOOM_MIN_STEP = 0.2
local ZOOM_DONE = 0.15  -- yards: close enough
local ZOOM_MOVED = 0.01 -- yards: change that counts as moving
local ZOOM_STILL = 0.1  -- seconds without moving: the step has settled
local ZOOM_NO_MOVE = 0.3 -- seconds after a step with no motion: the limit is reached
local ZOOM_GIVE_UP = 10
-- The way back in follows a planned path instead: a smoothstep from where the
-- camera is to the old distance, with a small correction toward the planned
-- point every frame (the error stays small, so the steps do not pile up).
local PATH_TIME = 1.5     -- seconds, plus PATH_PER_YARD for each yard to cover
local PATH_PER_YARD = 0.05
local PATH_MAX = 3
local PATH_GAIN = 0.3
local PATH_DEADBAND = 0.03
local PATH_EXTRA = 1.5    -- seconds past the plan before giving up
-- The distance before combat pulled the camera out; nil outside that.
local zoomBefore
-- The running move: target distance and its timers; nil when idle.
local zoomMove

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

-- Does nothing while Cine is off, like Glance.
function ns.SetCameraMode(mode)
    if not MODES[mode] or not ns.DB().enabled then return end
    Apply(mode)
end

function ns.ToggleCamera()
    ns.SetCameraMode(current == "action" and "normal" or "action")
end

local function ZoomNow()
    if type(GetCameraZoom) ~= "function" then return nil end
    local ok, zoom = pcall(GetCameraZoom)
    if ok and type(zoom) == "number" then return zoom end
end

local function StartZoom(target)
    zoomMove = { target = target, total = 0, last = ZoomNow(), sent = false }
end

-- Entering combat pulls the camera out to the player's zoom limit; leaving
-- it brings the camera back to the distance it had.
function ns.ZoomOutForCombat()
    if not ns.DB().enabled or current ~= "action" or not ns.CombatZoom() then return end
    if type(CameraZoomOut) ~= "function" or not ZoomNow() then
        ns.Report("camera", "zoom is missing")
        return
    end
    local factor = type(GetCVar) == "function" and tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or 1
    local target = ZOOM_BASE * factor * ZOOM_SHARE
    local now = ZoomNow()
    if now >= target then
        -- Already out that far: never pull the camera in. A return still
        -- pending from an earlier fight is held where it is.
        if zoomBefore then zoomMove = nil end
        return
    end
    -- A second fight before the return keeps the first distance.
    zoomBefore = zoomBefore or now
    StartZoom(target)
end

-- A smooth glide to a distance, in or out.
local function StartPath(target)
    StartZoom(target)
    local move = zoomMove
    if move and move.last then
        move.path = true
        move.from = move.last
        move.time = math.min(PATH_MAX, PATH_TIME + PATH_PER_YARD * math.abs(target - move.last))
    end
end

-- Login and reload also start the camera at a share of the zoom limit.
local LOGIN_SHARE = 0.3

function ns.ApplyDefaultCamera()
    ns.SetCameraMode("action")
    if current ~= "action" or not ZoomNow() then return end
    local factor = type(GetCVar) == "function" and tonumber(GetCVar("cameraDistanceMaxZoomFactor")) or 1
    StartPath(ZOOM_BASE * factor * LOGIN_SHARE)
end

function ns.ZoomBackAfterCombat()
    local before = zoomBefore
    zoomBefore = nil
    if not before or not ns.DB().enabled then return end
    StartPath(before)
end

local function FollowPath(move, elapsed, zoom)
    if not CameraZoomIn or not CameraZoomOut then zoomMove = nil return end
    local t = move.total
    if t > move.time + PATH_EXTRA
        or (t >= move.time and math.abs(move.target - zoom) < ZOOM_DONE) then
        zoomMove = nil
        return
    end
    local u = math.min(t / move.time, 1)
    local want = move.from + (move.target - move.from) * u * u * (3 - 2 * u)
    local err = want - zoom
    if math.abs(err) < PATH_DEADBAND then return end
    local ok, e = pcall(err > 0 and CameraZoomOut or CameraZoomIn, math.abs(err) * PATH_GAIN)
    if not ok then
        zoomMove = nil
        ns.Report("camera", e)
    end
end

function ns.UpdateCameraZoom(elapsed)
    local move = zoomMove
    if not move then return end
    local zoom = ZoomNow()
    if not zoom then zoomMove = nil return end
    move.total = move.total + elapsed
    if move.total > ZOOM_GIVE_UP then zoomMove = nil return end
    if move.path then return FollowPath(move, elapsed, zoom) end
    local changed = math.abs(zoom - move.last) >= ZOOM_MOVED
    move.last = zoom
    if move.sent then
        -- Waiting for the last step to settle.
        if changed then
            move.moved, move.wait = true, 0
            return
        end
        move.wait = (move.wait or 0) + elapsed
        if not move.moved then
            if move.wait > ZOOM_NO_MOVE then zoomMove = nil end
            return
        end
        if move.wait < ZOOM_STILL then return end
        move.sent, move.moved = false, false
    end
    local err = move.target - zoom
    if math.abs(err) < ZOOM_DONE then zoomMove = nil return end
    local step = math.min(math.abs(err), math.max(math.abs(err) * ZOOM_GAIN, ZOOM_MIN_STEP))
    local fn = err > 0 and CameraZoomOut or CameraZoomIn
    if type(fn) ~= "function" then zoomMove = nil return end
    local ok, e = pcall(fn, step)
    if not ok then
        zoomMove = nil
        ns.Report("camera", e)
        return
    end
    move.sent, move.moved, move.wait = true, false, 0
end

function ns.RestoreCamera()
    zoomBefore, zoomMove = nil, nil
    if not current then return end
    Apply("normal")
    current = nil
end

function CineCameraToggle(keystate)
    if keystate == "down" then ns.ToggleCamera() end
end
