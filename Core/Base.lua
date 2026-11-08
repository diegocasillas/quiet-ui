local _, ns = ...
local Core = ns.Core or {}
ns.Core = Core

-- Shared helpers: saved variables, messages, and the alpha machinery that
-- keeps a wanted alpha even when Blizzard code overwrites it.

local FADE_OUT = 0.3
Core.FADE_OUT = FADE_OUT
local PREFIX = "|cff8fd4c8Cine|r: "

local hooked = {}
Core.hooked = hooked
local savedAlpha = {}
Core.savedAlpha = savedAlpha
local textureAlpha = {}
Core.textureAlpha = textureAlpha
local reported = {}
local chatHeld = {}
Core.chatHeld = chatHeld

function ns.DB()
    if type(CineDB) ~= "table" then
        CineDB = {}
    end
    if CineDB.enabled == nil then
        CineDB.enabled = true
    end
    return CineDB
end

function ns.Print(msg)
    print(PREFIX .. tostring(msg))
end

function ns.Report(name, err)
    if reported[name] then return end
    reported[name] = true
    print(PREFIX .. name .. " error (shown once): " .. tostring(err))
end

-- Forbidden frames throw on almost any method call from addon code.
function ns.Usable(frame)
    if type(frame) ~= "table" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

-- Secret values (this client hides unit power even out of combat) cannot be
-- compared or used in arithmetic, only passed on to widgets.
function ns.IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value) and true or false
end

function ns.Wipe(t)
    if type(t) ~= "table" then return t end
    for key in pairs(t) do t[key] = nil end
    return t
end

function ns.FrameName(frame)
    if ns.Usable(frame) and frame.GetName then
        return frame:GetName()
    end
end

function ns.MouseOver(frame)
    if not frame or not frame.IsShown or not frame.IsMouseOver then return false end
    if not frame:IsShown() then return false end
    return frame:IsMouseOver() and true or false
end
