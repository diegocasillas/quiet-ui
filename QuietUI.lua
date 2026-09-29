local ADDON, ns = ...

-- Wiring: apply / restore, events, the per-frame update, and /quiet.

local booted = false
local hookedGlobal = {}
local chromeAcc = 0
local glancing = false
local layoutPending = nil
local layoutChosen = false
local finishingLayout = false
local settleUntil = 0
local settleToken = 0

local function Run(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.Report(label, err) end
end

local function UpdateFades(elapsed, rescan)
    if not ns.DB().enabled then return end
    ns.NextFadeTick()
    ns.BeginTick(rescan)
    local showAll = ns.ShowAll()
    ns.UpdateBars(showAll, elapsed, rescan)
    ns.UpdateFaders(showAll, elapsed)
    ns.UpdateMenuButton(elapsed)
end

-- Select once per enable, restore on disable. Both wait out combat and login.
-- With Force QuietUI layout off, the active Edit Mode layout stays as it is.
local function FinishLayout()
    if finishingLayout then return end
    if not ns.ForceQuietLayout() then
        layoutPending = nil
        return
    end
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
    if not ns.DB().enabled or not ns.ForceQuietLayout() then return end
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
            if token ~= settleToken or not ns.DB().enabled or not ns.ForceQuietLayout() then return end
            if type(GetTime) == "function" and GetTime() > settleUntil then return end
            layoutChosen = false
            layoutPending = "select"
            FinishLayout()
        end)
    end
end

local function RestoreAll()
    glancing = false
    ns.HideQuestCatcher()
    ns.HideBarCatchers()
    ns.ResetMenu()
    ns.RestoreChat()
    ns.RestoreAlpha()
    settleToken = settleToken + 1
    settleUntil = 0
    layoutChosen = false
    if ns.ForceQuietLayout() then
        layoutPending = "restore"
        FinishLayout()
    else
        layoutPending = nil
    end
end

local function ApplyAll()
    if not ns.DB().enabled then
        RestoreAll()
        return
    end
    ns.RefreshWorld()
    if ns.ForceQuietLayout() then
        if not layoutChosen then
            layoutPending = "select"
            FinishLayout()
        end
    else
        -- A later Save with force on selects again. previousLayout stays.
        layoutChosen = false
        layoutPending = nil
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
    ns.RefreshWorld()
    ns.FindFaders(true)
    ns.ScanSwing()
    ApplyAll()
end

-- A default on the header binding is stored as HEADER_QUIETUI, so ` does nothing.
-- Take that key, or a free `, for QUIETUI_GLANCE. Leave any other action alone.
local function EnsureGlanceBinding()
    if type(GetBindingKey) ~= "function" or type(SetBinding) ~= "function" then return end
    if type(GetBindingAction) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local ok, existing = pcall(GetBindingKey, "QUIETUI_GLANCE")
    if ok and type(existing) == "string" and existing ~= "" then return end
    local actionOk, action = pcall(GetBindingAction, "`")
    if not actionOk or type(action) ~= "string" then return end
    if action ~= "" and action ~= "HEADER_QUIETUI" then return end
    local setOk, bound = pcall(SetBinding, "`", "QUIETUI_GLANCE")
    if not setOk or not bound then return end
    if type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then return end
    local setOk2, set = pcall(GetCurrentBindingSet)
    if setOk2 and type(set) == "number" then
        pcall(SaveBindings, set)
    end
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
    EnsureGlanceBinding()
    ns.EnsureMinimap()
    if first and ns.DB().enabled then
        ArmLayoutSettle()
    end
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            ApplyAll()
            ns.EnsureMinimap()
        end)
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
    ns.NoteCombat(true)
    UpdateFades(0)
end

function handlers.PLAYER_REGEN_ENABLED()
    ns.NoteCombat(false)
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
    if not ns.DB().enabled or not ns.ForceQuietLayout() then return end
    if type(GetTime) == "function" and GetTime() > settleUntil then return end
    layoutChosen = false
    layoutPending = "select"
    FinishLayout()
end

function handlers.UPDATE_CHAT_WINDOWS()
    ns.StripAllChat(true)
end
handlers.UPDATE_FLOATING_CHAT_WINDOWS = handlers.UPDATE_CHAT_WINDOWS

function handlers.GROUP_ROSTER_UPDATE()
    ns.RefreshWorld()
end

function handlers.PLAYER_TARGET_CHANGED()
    ns.RefreshWorld()
end

function handlers.UNIT_ENTERED_VEHICLE()
    ns.RefreshWorld()
end

handlers.UNIT_EXITED_VEHICLE = handlers.UNIT_ENTERED_VEHICLE

-- These run before boot and while disabled; the rest only while active.
local ALWAYS = {
    ADDON_LOADED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
}

local events = CreateFrame("Frame")
local lastPointerX, lastPointerY
local lastFlyout = false
local lastGlance = false
local wasHot = false
local lastBusy = false
local slowAcc = 0
local fallbackAcc = 0
-- No focus API: a full button walk stays near 20 Hz instead of every pixel.
local FALLBACK_RESCAN = 0.05

local function PointerMoved()
    if type(GetCursorPosition) ~= "function" then return true end
    local x, y = GetCursorPosition()
    if x == lastPointerX and y == lastPointerY then return false end
    lastPointerX, lastPointerY = x, y
    return true
end

local function FlyoutShown()
    return SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() and true or false
end

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
    elapsed = elapsed or 0
    local flyout = FlyoutShown()
    local glance = ns.Glancing() and true or false
    local moved = PointerMoved()
    local hud = ns.ConsumeHud()
    slowAcc = slowAcc + elapsed
    local slow = slowAcc >= 0.1
    if slow then slowAcc = 0 end
    local focusChanged = false
    if moved or slow then
        local changed = ns.FocusChanged()
        if changed == nil then
            if moved then
                fallbackAcc = fallbackAcc + elapsed
                if fallbackAcc >= FALLBACK_RESCAN then
                    fallbackAcc = 0
                    focusChanged = true
                end
            end
        else
            fallbackAcc = 0
            focusChanged = changed
        end
    end
    local rescan = focusChanged or hud or flyout ~= lastFlyout or glance ~= lastGlance
    lastFlyout = flyout
    lastGlance = glance
    if rescan or wasHot then
        Run("bars", UpdateFades, elapsed, rescan)
        wasHot = ns.FrameHot()
    end
    if slow then
        ns.ForgetCursor()
        local busy = ns.CursorBusy()
        if busy ~= lastBusy then
            lastBusy = busy
            if not rescan and not wasHot then
                Run("bars", UpdateFades, elapsed, true)
                wasHot = ns.FrameHot()
                rescan = true
            end
        end
        if not rescan and not wasHot then
            ns.NextFadeTick()
            Run("faders", ns.UpdateFaders, ns.ShowAll(), elapsed)
            Run("menu", ns.UpdateMenuButton, elapsed)
            if ns.FrameHot() then wasHot = true end
        end
        Run("bags", ns.UpdateBagSlots)
        if ns.ModernChat() then
            Run("input", ns.SyncVisibleEdits)
        end
    end
    if ns.ModernChat() then
        Run("bubbles", ns.UpdateChat, elapsed)
    end
    Run("smooth", ns.UpdateSmooth, elapsed)
    chromeAcc = chromeAcc + elapsed
    if chromeAcc < 1 then return end
    chromeAcc = 0
    Run("frame scan", ns.FindFaders, false)
    Run("swing", ns.ScanSwing)
    Run("bar buttons", ns.ForgetBarButtons)
    Run("world", ns.RefreshWorld)
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
-- Press Glance to show the faded HUD. Press again and the rules apply.
-- The binding system calls a global; down and up both arrive.
------------------------------------------------------------------------------
BINDING_CATEGORY_QUIETUI = "QuietUI"
BINDING_NAME_QUIETUI_GLANCE = "Glance"

function QuietUIGlance(keystate)
    if keystate ~= "down" then return end
    glancing = not glancing
end

function ns.Glancing()
    return glancing
end

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
