-- Run from the addon directory: lua tests/camera.lua
local failures = 0
local function test(name, run)
    local ok, err = pcall(run)
    print((ok and 'PASS ' or 'FAIL ') .. name .. (ok and '' or ': ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
local ACTION = 'actioncam full|camerakeepcharactercentered 0|actioncam noheadmove|actioncam focusall'
local NORMAL = 'actioncam off|camerakeepcharactercentered 1'
local function boot(enabled)
    local ns = {}
    PuroCineDB = { enabled = enabled }
    local sent, reports = {}, {}
    ConsoleExec = function(line) sent[#sent + 1] = line end
    ns.DB = function() return PuroCineDB end
    ns.Report = function(name, err) reports[#reports + 1] = name .. ': ' .. tostring(err) end
    assert(loadfile('Features/Camera/Camera.lua'))('PuroCine', ns)
    local function take()
        local text = table.concat(sent, '|')
        for i = #sent, 1, -1 do sent[i] = nil end
        return text
    end
    return ns, take, reports
end

test('The default runs the first macro and one key toggles between the two', function()
    local ns, take = boot(true)
    ns.ApplyDefaultCamera()
    assert(take() == ACTION, 'Default is not the action camera')
    PuroCineCameraToggle('down')
    assert(take() == NORMAL, 'First press did not go to normal')
    PuroCineCameraToggle('down')
    assert(take() == ACTION, 'Second press did not go back to action')
end)

test('Before any default the first press goes to action', function()
    local ns, take = boot(true)
    PuroCineCameraToggle('down')
    assert(take() == ACTION)
    PuroCineCameraToggle('down')
    assert(take() == NORMAL)
end)

test('Key up is ignored and nothing runs while Puro Cine is off', function()
    local ns, take = boot(true)
    PuroCineCameraToggle('up')
    assert(take() == '', 'Key up changed the camera')
    PuroCineDB.enabled = false
    PuroCineCameraToggle('down'); ns.ApplyDefaultCamera()
    assert(take() == '', 'The camera changed while Puro Cine is off')
end)

test('Turning Puro Cine off restores normal only after Puro Cine changed the camera', function()
    local ns, take = boot(true)
    ns.RestoreCamera()
    assert(take() == '', 'Restore ran without a change')
    ns.ApplyDefaultCamera(); take()
    PuroCineDB.enabled = false
    ns.RestoreCamera()
    assert(take() == NORMAL)
    ns.RestoreCamera()
    assert(take() == '', 'Restore ran twice')
    PuroCineDB.enabled = true
    PuroCineCameraToggle('down')
    assert(take() == ACTION, 'The toggle forgot the restore')
end)

test('A missing ConsoleExec or a failing command is reported, not thrown', function()
    local ns, _, reports = boot(true)
    ConsoleExec = function() error('blocked') end
    ns.ApplyDefaultCamera()
    assert(#reports == 4 and reports[1]:find('camera'), 'Failures were not reported')
    ConsoleExec = nil
    ns.SetCameraMode('normal')
    assert(reports[#reports]:find('ConsoleExec'), 'Missing ConsoleExec was not reported')
end)

test('The distance key glides to the other of the two distances', function()
    local ns = boot(true)
    local zoom, calls = 10, {}
    GetCVar = function() return '1' end
    GetCameraZoom = function() return zoom end
    CameraZoomIn = function() calls[#calls + 1] = 'in' end
    CameraZoomOut = function() calls[#calls + 1] = 'out' end
    ns.DefaultZoomPercentShare = function() return 0.3 end
    ns.CombatZoomShare = function() return 0.6 end
    ns.Print = function() end
    -- Limit 15: default 4.5, combat 9, midpoint 6.75.
    PuroCineCameraDistanceToggle('up')
    for _ = 1, 5 do ns.UpdateCameraZoom(0.1) end
    assert(#calls == 0, 'Key up moved the camera')
    PuroCineCameraDistanceToggle('down')
    for _ = 1, 5 do ns.UpdateCameraZoom(0.1) end
    assert(calls[1] == 'in', 'Past the midpoint the key did not go to the nearer distance')
    zoom, calls = 4.5, {}
    PuroCineCameraDistanceToggle('down')
    for _ = 1, 5 do ns.UpdateCameraZoom(0.1) end
    assert(calls[1] == 'out', 'At the nearer distance the key did not go to the farther one')
    PuroCineDB.enabled = false
    zoom, calls = 10, {}
    PuroCineCameraDistanceToggle('down')
    for _ = 1, 5 do ns.UpdateCameraZoom(0.1) end
    assert(#calls == 0, 'The key moved the camera while Puro Cine is off')
end)

os.exit(failures == 0 and 0 or 1)
