local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local hookedGlobal = {}
local chromeAcc = 0
local layoutPending = nil
local layoutChosen = false
local finishingLayout = false
local settleUntil = 0
local settleToken = 0

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

-- Select once per enable, restore on disable. Both wait out combat and login.
local function FinishLayout()
    if finishingLayout then return end
    if layoutPending ~= "select" and layoutPending ~= "restore" then return end
    finishingLayout = true
    local job = layoutPending
    local fn = job == "select" and ns.SelectQuietLayout or ns.RestorePreviousLayout
    local ok, done = pcall(fn)
    finishingLayout = false
    if not ok then
        layoutPending = nil
        if job == "select" then layoutChosen = true end
        ns.Report("layout", done)
    elseif done then
        layoutPending = nil
        if job == "select" then layoutChosen = true end
    end
end

-- A new character applies the default preset after login. Keep selecting until that settles.
local function ArmLayoutSettle()
    if not ns.DB().enabled then return end
    settleToken = settleToken + 1
    local token = settleToken
    layoutChosen = false
    layoutPending = "select"
    local now = type(GetTime) == "function" and GetTime() or 0
    settleUntil = now + 10
    FinishLayout()
    if not (C_Timer and C_Timer.After) then return end
    for _, delay in ipairs({ 1, 3, 6 }) do
        C_Timer.After(delay, function()
            if token ~= settleToken or not ns.DB().enabled then return end
            if type(GetTime) == "function" and GetTime() > settleUntil then return end
            layoutChosen = false
            layoutPending = "select"
            FinishLayout()
        end)
    end
end

local function RestoreAll()
    ns.ResetMenu()
    ns.RestoreChat()
    ns.RestoreAlpha()
    settleToken = settleToken + 1
    settleUntil = 0
    layoutChosen = false
    layoutPending = "restore"
    FinishLayout()
end

local function ApplyAll()
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    if not layoutChosen then
        layoutPending = "select"
        FinishLayout()
    end
    ns.EnsureLayout()
    ns.RefreshChrome()
    if ns.ModernChat() then
        ns.StripAllChat()
    else
        ns.RestoreChat()
    end
    UpdateFades(0)
    ns.UpdateBagSlots()
end

ns.ApplyAll = ApplyAll

local function Rescan()
    ns.FindFaders(true)
    ApplyAll()
end

local function Boot()
    local first = not booted
    booted = true
    ns.CharDB()
    if first then
        local state = ns.DB().enabled and "on, enjoy the quiet" or "off for now"
        ns.Print("is " .. state .. ".")
        print("   |cffffffff/quiet|r  switch it on or off")
        print("   |cffffffff/quiet setup|r  choose what stays visible")
    end
    Rescan()
    if first and ns.DB().enabled then
        ArmLayoutSettle()
    end
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

function handlers.PLAYER_ENTERING_WORLD(isInitialLogin, isReloading)
    ns.DB()
    Boot()
    if ns.DB().enabled and (isInitialLogin or isReloading) then
        ArmLayoutSettle()
    end
end

function handlers.PLAYER_REGEN_DISABLED()
    UpdateFades(0)
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.MarkCombatEnd()
    UpdateFades(0)
    ns.RefreshChrome()
    ns.EnsureLayout()
end

function handlers.QUEST_TURNED_IN(_, xp)
    ns.MarkQuestXP(xp)
end

function handlers.EDIT_MODE_LAYOUTS_UPDATED()
    ns.EnsureLayout()
    if not ns.DB().enabled then return end
    if type(GetTime) == "function" and GetTime() > settleUntil then return end
    layoutChosen = false
    layoutPending = "select"
    FinishLayout()
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
    if booted and (event == "PLAYER_REGEN_ENABLED" or event == "EDIT_MODE_LAYOUTS_UPDATED") then
        Run("layout", FinishLayout)
    end
    local handler = handlers[event]
    if not handler then return end
    if not ALWAYS[event] and (not booted or not ns.DB().enabled) then return end
    Run(event, handler, ...)
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not booted or not ns.DB().enabled then return end
    Run("bars", UpdateFades, elapsed)
    Run("bags", ns.UpdateBagSlots)
    if ns.ModernChat() then
        Run("input", ns.SyncVisibleEdits)
        Run("bubbles", ns.UpdateChat, elapsed)
    end
    chromeAcc = chromeAcc + (elapsed or 0)
    if chromeAcc < 1 then return end
    chromeAcc = 0
    Run("frame scan", ns.FindFaders, false)
    Run("menu", ns.RefreshChrome)
    if ns.ModernChat() then
        Run("chat", ns.StripAllChat)
    end
end)

for eventName in pairs(handlers) do
    pcall(events.RegisterEvent, events, eventName)
end

HookGlobal("UpdateMicroButtons", ns.RefreshChrome)
HookGlobal("FCF_SetWindowAlpha", ns.StripAllChat)
HookGlobal("FCF_SetWindowColor", ns.StripAllChat)
HookGlobal("FCF_DockUpdate", ns.StripAllChat)

------------------------------------------------------------------------------
-- /quiet on | off | setup, no argument toggles.
------------------------------------------------------------------------------
SLASH_QUIETUI1 = "/quiet"
SLASH_QUIETUI2 = "/quietui"
SlashCmdList["QUIETUI"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "setup" then
        ns.ShowSetup()
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
