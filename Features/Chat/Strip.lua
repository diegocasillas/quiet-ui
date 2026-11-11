local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

------------------------------------------------------------------------------
-- Chat windows
------------------------------------------------------------------------------
local function MarkStripped(frame)
    if not frame then return end
    if frame._puroCineLines and #frame._puroCineLines > 0 then
        Chat.HideNativeText(frame, true)
    end
    frame._puroCineStripped = true
    frame._puroCineDirty = true
end

local function StripChat(frame)
    if not frame or not ns.DB().enabled then return end
    ns.HideTextures(frame)
    local name = ns.FrameName(frame)
    ns.HideBackground(frame.Background or (name and _G[name .. "Background"]))
    if frame.NineSlice then
        ns.HideTextures(frame.NineSlice)
    end
    ns.Mute(frame.ScrollBar)
    ns.Mute(frame.ScrollToBottomButton)
    ns.Mute(frame.buttonFrame)
    ns.Mute(frame.TextToSpeechButton)
    if not name then
        Chat.BindBubbles(frame)
        MarkStripped(frame)
        return
    end
    for _, suffix in ipairs(Chat.CHAT_BUTTON_SUFFIX) do
        ns.Mute(_G[name .. suffix])
    end
    Chat.StripTab(_G[name .. "Tab"])
    Chat.BindEdit(_G[name .. "EditBox"])
    Chat.BindBubbles(frame)
    MarkStripped(frame)
end

local function StripDock()
    local dock = GeneralDockManager
    if not dock then return end
    ns.HideTextures(dock)
    ns.HideBackground(dock.Background or _G.GeneralDockManagerBackground)
end

function ns.StripAllChat(force)
    if Chat.stripping or not ns.DB().enabled or not ns.ModernChat() then return end
    Chat.stripping = true
    ns.MarkingChat = true
    if force then Chat.chromeStripped = false end
    Chat.NoteTemporary()
    local ok, err = pcall(function()
        for i = 1, Chat.ChatCount() do
            local frame = _G["ChatFrame" .. i]
            if frame and (force or not frame._puroCineStripped) then
                StripChat(frame)
            end
        end
        if not Chat.chromeStripped then
            for _, name in ipairs(Chat.CHAT_CHROME) do
                ns.Mute(_G[name])
            end
            StripDock()
            Chat.chromeStripped = true
        end
    end)
    ns.MarkingChat = false
    Chat.stripping = false
    if not ok then ns.Report("chat", err) end
end

-- Blizzard rewrote one window's alpha or color; strip only that window.
-- Only windows UpdateChat and RestoreChat walk.
local function OwnChatFrame(frame)
    for i = 1, Chat.ChatCount() do
        if _G["ChatFrame" .. i] == frame then return true end
    end
    return false
end

function ns.RestripChat(frame)
    if Chat.stripping or not ns.Usable(frame) or not OwnChatFrame(frame) or not ns.DB().enabled
        or not ns.ModernChat() then return end
    Chat.stripping = true
    ns.MarkingChat = true
    local ok, err = pcall(StripChat, frame)
    ns.MarkingChat = false
    Chat.stripping = false
    if not ok then ns.Report("chat", err) end
end
