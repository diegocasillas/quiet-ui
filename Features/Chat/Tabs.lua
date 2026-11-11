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
    if ns.MouseOver(_G["ChatFrame" .. i .. "Tab"]) then return true end
    return Docked(frame, i) and ns.MouseOver(GeneralDockManager)
end
Chat.TabRowHot = TabRowHot

-- Tabs show while the chat or the tab row is hovered, or while a tab flashes for new messages.
local function TabAlerting(tab)
    if tab.alerting then return true end
    local glow = tab.glow
    return glow and glow.IsShown and glow:IsShown() and true or false
end

local function FadeTabs(elapsed)
    local hot = ns.MouseOver(GeneralDockManager)
    for i = 1, Chat.ChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame and frame._puroPuroCineHover then hot = true end
    end
    for i = 1, Chat.ChatCount() do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and ns.Usable(tab) then
            ns.NoteChat(tab)
            ns.EaseAlpha(tab, hot or ns.MouseOver(tab) or TabAlerting(tab), elapsed)
        end
    end
end
Chat.FadeTabs = FadeTabs

-- Tabs keep Blizzard's own points above the chat; only their alpha is ours.
local function RestoreTabs()
    for i = 1, Chat.ChatCount() do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab and tab._puroPuroCineAlpha ~= nil then ns.ReleaseAlpha(tab) end
    end
end
Chat.RestoreTabs = RestoreTabs
