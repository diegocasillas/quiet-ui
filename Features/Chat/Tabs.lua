local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

-- ChatFrame1 is the dock itself; other windows say so with isDocked.
local function Docked(window, i)
    if i == 1 then return true end
    local d = window and window.isDocked
    return d == true or (type(d) == "number" and d > 0)
end

-- A tab click leaves the pointer on the tab row, so the row counts as the chat's hover.
local function TabRowHot(frame, i)
    if ns.MouseOver(Chat.Window(i, "Tab")) then return true end
    return Docked(frame, i) and ns.MouseOver(GeneralDockManager)
end
Chat.TabRowHot = TabRowHot

-- Tabs show while the chat or the tab row is hovered, or while a tab flashes for new messages.
local function TabAlerting(tab)
    if tab.alerting then return true end
    local glow = tab.glow
    return glow and glow.IsShown and glow:IsShown() and true or false
end

-- Mouse-over reads wait for a moved pointer, or 0.1 s, like the chat hover.
-- Returns true while a tab still eases.
local overAt

local function FadeTabs(elapsed)
    local now = GetTime()
    local read = not Chat.state.pointerStill or not overAt or now >= overAt
    if read then overAt = now + 0.1 end
    local hot, easing = false, false
    for i = 1, Chat.ChatCount() do
        local frame = Chat.Window(i)
        if frame and frame._puroCineHover then hot = true end
    end
    if read then Chat.state.dockOver = ns.MouseOver(GeneralDockManager) end
    hot = hot or Chat.state.dockOver
    for i = 1, Chat.ChatCount() do
        local tab = Chat.Window(i, "Tab")
        if tab and ns.Usable(tab) then
            ns.NoteChat(tab)
            if read then tab._puroCineOver = ns.MouseOver(tab) end
            tab._puroCineAlerting = tab.alerting and true or false
            local show = hot or tab._puroCineOver or TabAlerting(tab)
            ns.EaseAlpha(tab, show, elapsed)
            if tab._puroCineAlpha ~= (show and 1 or 0) then easing = true end
        end
    end
    return easing
end
Chat.FadeTabs = FadeTabs

-- Tabs keep Blizzard's own points above the chat; only their alpha is ours.
local function RestoreTabs()
    for i = 1, Chat.ChatCount() do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and tab._puroCineAlpha ~= nil then ns.ReleaseAlpha(tab) end
    end
end
Chat.RestoreTabs = RestoreTabs
