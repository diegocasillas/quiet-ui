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
    CineDB = { enabled = enabled }
    local sent, reports = {}, {}
    ConsoleExec = function(line) sent[#sent + 1] = line end
    ns.DB = function() return CineDB end
    ns.Report = function(name, err) reports[#reports + 1] = name .. ': ' .. tostring(err) end
    assert(loadfile('Features/Camera/Camera.lua'))('Cine', ns)
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
    CineCameraToggle('down')
    assert(take() == NORMAL, 'First press did not go to normal')
    CineCameraToggle('down')
    assert(take() == ACTION, 'Second press did not go back to action')
end)

test('Before any default the first press goes to action', function()
    local ns, take = boot(true)
    CineCameraToggle('down')
    assert(take() == ACTION)
    CineCameraToggle('down')
    assert(take() == NORMAL)
end)

test('Key up is ignored and nothing runs while Cine is off', function()
    local ns, take = boot(true)
    CineCameraToggle('up')
    assert(take() == '', 'Key up changed the camera')
    CineDB.enabled = false
    CineCameraToggle('down'); ns.ApplyDefaultCamera()
    assert(take() == '', 'The camera changed while Cine is off')
end)

test('Turning Cine off restores normal only after Cine changed the camera', function()
    local ns, take = boot(true)
    ns.RestoreCamera()
    assert(take() == '', 'Restore ran without a change')
    ns.ApplyDefaultCamera(); take()
    CineDB.enabled = false
    ns.RestoreCamera()
    assert(take() == NORMAL)
    ns.RestoreCamera()
    assert(take() == '', 'Restore ran twice')
    CineDB.enabled = true
    CineCameraToggle('down')
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

os.exit(failures == 0 and 0 or 1)
