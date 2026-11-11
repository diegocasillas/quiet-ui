local _, ns = ...

-- A default on the header binding is stored as HEADER_CINE, so ` does nothing.
-- Take that key, or a free `, for PURO_CINE_GLANCE. Leave any other action alone.
-- Keys saved under the old binding names move to the new ones. Returns true if one moved.
local RENAMED = { CINE_GLANCE = "PURO_CINE_GLANCE", CINE_CAMERA_TOGGLE = "PURO_CINE_CAMERA_TOGGLE" }

local function MoveOldBindings()
    local moved = false
    for old, new in pairs(RENAMED) do
        local ok, keys = pcall(function() return { GetBindingKey(old) } end)
        local okNew, current = pcall(GetBindingKey, new)
        if ok and okNew and not (type(current) == "string" and current ~= "") then
            for _, key in ipairs(keys) do
                local set, bound = pcall(SetBinding, key, new)
                if set and bound then moved = true end
            end
        end
    end
    return moved
end

local function SaveCurrentBindings()
    if type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then return end
    local ok, set = pcall(GetCurrentBindingSet)
    if ok and type(set) == "number" then
        pcall(SaveBindings, set)
    end
end

function ns.EnsureGlanceBinding()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
    if type(GetBindingAction) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if MoveOldBindings() then SaveCurrentBindings() end
    local ok, existing = pcall(GetBindingKey, "PURO_CINE_GLANCE")
    if ok and type(existing) == "string" and existing ~= "" then return end
    local actionOk, action = pcall(GetBindingAction, "`")
    if not actionOk or type(action) ~= "string" then return end
    if action ~= "" and action ~= "HEADER_CINE" then return end
    local setOk, bound = pcall(SetBinding, "`", "PURO_CINE_GLANCE")
    if not setOk or not bound then return end
    if type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then return end
    local setOk2, set = pcall(GetCurrentBindingSet)
    if setOk2 and type(set) == "number" then
        pcall(SaveBindings, set)
    end
end
