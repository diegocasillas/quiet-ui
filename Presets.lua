local _, ns = ...

local snapshotChar, snapshotPreset

local KEYS = { "visible", "forceLayout", "player", "requireLivingTarget", "groupAuras", "alwaysShowDebuffs",
    "chat", "chatFade", "groups", "hostile", "friendly", "range" }

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = ns.Copy(item) end
    return result
end

function ns.CopySettings(source, target)
    target = target or {}
    for _, key in ipairs(KEYS) do target[key] = ns.Copy(source[key]) end
    return target
end

function ns.Presets()
    local db = ns.DB()
    if type(db.presets) ~= "table" then db.presets = {} end
    return db.presets
end

function ns.ActivePreset()
    local char = ns.CharDB()
    local preset = char.presetId and ns.Presets()[char.presetId]
    if type(preset) ~= "table" then
        char.presetId = nil
        return nil
    end
    return preset
end

function ns.Settings()
    local preset = ns.ActivePreset()
    if preset then
        local char = ns.CharDB()
        if snapshotChar ~= char or snapshotPreset ~= preset then
            ns.CopySettings(preset.settings, char)
            snapshotChar, snapshotPreset = char, preset
        end
        return preset.settings
    end
    return ns.CharDB()
end

function ns.PresetList()
    local list = {}
    for id, preset in pairs(ns.Presets()) do
        list[#list + 1] = { id = id, name = preset.name }
    end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end

function ns.PresetName(name, id)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Enter a preset name." end
    for other, preset in pairs(ns.Presets()) do
        if other ~= id and preset.name:lower() == name:lower() then
            return nil, "A preset with that name already exists."
        end
    end
    return name
end

function ns.SavePreset(id, name, layout, settings)
    local valid, err = ns.PresetName(name, id)
    if not valid then return nil, err end
    local db = ns.DB()
    if id and not ns.Presets()[id] then return nil, "That preset no longer exists." end
    if not id then
        db.nextPresetId = (db.nextPresetId or 0) + 1
        id = tostring(db.nextPresetId)
    end
    local saved = ns.CopySettings(settings)
    saved.forceLayout = nil
    ns.Presets()[id] = { name = valid, layout = ns.Copy(layout), settings = saved }
    return id
end

function ns.ActivatePreset(id, settings)
    local char = ns.CharDB()
    if id and not ns.Presets()[id] then return false end
    if settings then ns.CopySettings(settings, char) else ns.Settings() end
    char.presetId = id
    snapshotChar, snapshotPreset = nil, nil
    if id then ns.CopySettings(ns.Presets()[id].settings, char) end
    return true
end

function ns.DeletePreset(id)
    if ns.CharDB().presetId == id then ns.Settings(); ns.CharDB().presetId = nil end
    ns.Presets()[id] = nil
end
