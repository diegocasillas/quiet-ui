local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local hookedGlobal = {}
local chromeAcc = 0

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

local function UpdateFades(elapsed)
    if not ns.DB().enabled then return end
    ns.NextFadeTick()
    local showAll = ns.ShowAll()
    ns.UpdateBars(showAll, elapsed)
    ns.UpdateFaders(showAll, elapsed)
    ns.UpdateMenuButton(elapsed)
end

local function RestoreAll()
    ns.ResetMenu()
    ns.RestoreAlpha()
end

local function ApplyAll()
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    ns.EnsureLayout()
    ns.RefreshChrome()
    ns.StripAllChat()
    UpdateFades(0)
    ns.UpdateBagSlots()
end

local function Rescan()
    ns.FindFaders(true)
    ApplyAll()
end

local function Boot()
    local first = not booted
    booted = true
    Rescan()
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, ApplyAll)
        C_Timer.After(2, Rescan)
    end
end

local function HookGlobal(name, fn)
    if hookedGlobal[name] or type(_G[name]) ~= "function" then return end
    local ok = pcall(hooksecurefunc, name, function(...)
        if not ns.DB().enabled then return end
        Run(name, fn, ...)
    end)
    if ok then
        hookedGlobal[name] = true
    end
end

------------------------------------------------------------------------------
-- Events. Unknown names throw on this client, so each one is registered alone.
------------------------------------------------------------------------------
local handlers = {}

function handlers.ADDON_LOADED(name)
    if name == ADDON then
        ns.DB()
    elseif booted and ns.DB().enabled then
        Rescan()
    end
end

function handlers.PLAYER_LOGIN()
    ns.DB()
    Boot()
end
handlers.PLAYER_ENTERING_WORLD = handlers.PLAYER_LOGIN

function handlers.PLAYER_REGEN_DISABLED()
    UpdateFades(0)
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.MarkCombatEnd()
    UpdateFades(0)
    ns.RefreshChrome()
end

function handlers.EDIT_MODE_LAYOUTS_UPDATED()
    ns.EnsureLayout()
end

function handlers.UPDATE_CHAT_WINDOWS()
    ns.StripAllChat()
end
handlers.UPDATE_FLOATING_CHAT_WINDOWS = handlers.UPDATE_CHAT_WINDOWS

-- These run before boot and while disabled; the rest only while active.
local ALWAYS = {
    ADDON_LOADED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
}

local events = CreateFrame("Frame")

events:SetScript("OnEvent", function(_, event, ...)
    local handler = handlers[event]
    if not handler then return end
    if not ALWAYS[event] and (not booted or not ns.DB().enabled) then return end
    Run(event, handler, ...)
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not booted or not ns.DB().enabled then return end
    Run("bars", UpdateFades, elapsed)
    Run("bags", ns.UpdateBagSlots)
    Run("input", ns.SyncVisibleEdits)
    chromeAcc = chromeAcc + (elapsed or 0)
    if chromeAcc < 1 then return end
    chromeAcc = 0
    Run("frame scan", ns.FindFaders, false)
    Run("menu", ns.RefreshChrome)
    Run("chat", ns.StripAllChat)
end)

for eventName in pairs(handlers) do
    pcall(events.RegisterEvent, events, eventName)
end

HookGlobal("UpdateMicroButtons", ns.RefreshChrome)
HookGlobal("FCF_SetWindowAlpha", ns.StripAllChat)
HookGlobal("FCF_SetWindowColor", ns.StripAllChat)
HookGlobal("FCF_DockUpdate", ns.StripAllChat)

------------------------------------------------------------------------------
-- /quiet on | off | layout, no argument toggles.
------------------------------------------------------------------------------
SLASH_QUIETUI1 = "/quiet"
SLASH_QUIETUI2 = "/quietui"
SlashCmdList["QUIETUI"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "layout" then
        ns.ForceLayout()
        return
    end
    local db = ns.DB()
    if msg == "on" then
        db.enabled = true
    elseif msg == "off" then
        db.enabled = false
    else
        db.enabled = not db.enabled
    end
    if booted then
        if db.enabled then ApplyAll() else RestoreAll() end
    end
    ns.Print(db.enabled and "enabled" or "disabled")
end
