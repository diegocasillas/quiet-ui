local _, ns = ...

-- Per character. An older build kept this on the account; the first character
-- to load keeps that copy, then the account keys are dropped.
local accountMoved = false

function ns.CharDB()
    if type(QuietUICharDB) ~= "table" then
        QuietUICharDB = {}
    end
    if not accountMoved then
        accountMoved = true
        local account = ns.DB()
        if account.visible ~= nil or account.player ~= nil then
            if QuietUICharDB.visible == nil and QuietUICharDB.player == nil then
                QuietUICharDB.visible = account.visible
                QuietUICharDB.player = account.player
            end
            account.visible = nil
            account.player = nil
        end
    end
    if ns.MigrateOnce then ns.MigrateOnce(QuietUICharDB) end
    return QuietUICharDB
end

-- These rows show only on hover until setup says otherwise.
local DEFAULT_HOVER = {
    xp = true, quests = true, meter = true, micro = true, ["raid manager"] = true,
}

function ns.DefaultHover(name)
    return DEFAULT_HOVER[name] and true or false
end

function ns.HoverSetting(settings, name)
    local hover = settings.hoverOnly
    local value
    if type(hover) == "table" then value = hover[name] end
    if type(value) == "boolean" then return value end
    -- A default hover row yields to an existing Always visible choice.
    return DEFAULT_HOVER[name] and not (type(settings.visible) == "table" and settings.visible[name] == true) or false
end

function ns.OnlyOnHover(name)
    return ns.HoverSetting(ns.Settings and ns.Settings() or ns.CharDB(), name)
end

function ns.VisibilityShow(name, usual, hovered)
    if ns.InEditMode() then return true end
    if ns.OnlyOnHover(name) then return hovered and true or false end
    if ns.Glancing() then return true end
    return ns.Pinned(name) or usual or hovered or false
end

function ns.Pinned(name)
    local visible = (ns.Settings and ns.Settings() or ns.CharDB()).visible
    return type(visible) == "table" and visible[name] and true or false
end

-- Missing means on. Only an explicit "resource" keeps the portrait for edit mode.
function ns.PlayerStyle()
    if (ns.Settings and ns.Settings() or ns.CharDB()).player == "resource" then return "resource" end
    return "classic"
end

function ns.PlayerThreshold()
    local settings = ns.Settings and ns.Settings() or ns.CharDB()
    local kind = settings.playerThresholdKind == "health" and "health" or "resource"
    local value = settings.playerThresholdPercent
    if value == false then return kind, nil end
    if type(value) == "number" and not ns.IsSecret(value)
        and value >= 1 and value <= 100 and value == math.floor(value) then return kind, value end
    return kind, 70
end

function ns.RequireLivingTarget()
    return (ns.Settings and ns.Settings() or ns.CharDB()).requireLivingTarget == true
end

-- Missing means on. Only an explicit false leaves buffs on their own.
function ns.GroupAuras()
    return (ns.Settings and ns.Settings() or ns.CharDB()).groupAuras ~= false
end

-- Missing means on. Only an explicit false lets debuffs fade.
function ns.AlwaysShowDebuffs()
    return (ns.Settings and ns.Settings() or ns.CharDB()).alwaysShowDebuffs ~= false
end

-- Missing means off. Only an explicit true keeps the player frame up in a party.
function ns.ShowPlayerFrameInParty()
    return (ns.Settings and ns.Settings() or ns.CharDB()).showPlayerFrameInParty == true
end

-- Missing means on. Only an explicit false keeps frames hidden in instance.
function ns.ForceFramesInInstance()
    return (ns.Settings and ns.Settings() or ns.CharDB()).forceFramesInInstance ~= false
end

-- Missing means on. Only an explicit false turns the modern chat off.
function ns.ModernChat()
    return (ns.Settings and ns.Settings() or ns.CharDB()).chat ~= false
end

-- Missing means off. Only an explicit true selects the QuietUI layout when the addon turns on.
function ns.ForceQuietLayout()
    return (ns.ActivePreset and ns.ActivePreset()) ~= nil
        or (ns.Settings and ns.Settings() or ns.CharDB()).forceLayout == true
end

-- Seconds a line stays at the bottom. Missing means 10. 0 keeps the line.
function ns.ChatFade()
    local n = (ns.Settings and ns.Settings() or ns.CharDB()).chatFade
    if type(n) ~= "number" or n ~= n then return 10 end
    if n <= 0 then return 0 end
    n = math.floor(n)
    if n > 60 then n = 60 end
    return math.floor(n / 5) * 5
end

-- Missing means off. yards is 10, 28, or "spell". kind is "hostile" or "friendly".
-- spell is an optional name. Missing means the longest matching spell on bar 1.
function ns.Range()
    local range = (ns.Settings and ns.Settings() or ns.CharDB()).range
    if type(range) ~= "table" then return nil end
    local yards = range.yards
    if yards ~= 10 and yards ~= 28 and yards ~= "spell" then return nil end
    local kind = range.kind == "friendly" and "friendly" or "hostile"
    local spell = range.spell
    if type(spell) ~= "string" or ns.IsSecret(spell) then return yards, kind end
    spell = spell:match("^%s*(.-)%s*$")
    if not spell or spell == "" then return yards, kind end
    return yards, kind, spell
end
