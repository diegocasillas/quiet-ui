local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

-- Chat keeps its text and drops the chrome. Each line is drawn as its own
-- bubble; the input shows only while it has focus. No ChatFrame_OpenChat:
-- Enter stays a Blizzard binding.

local CHAT_CHROME = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceSelfMuteButton",
    "ChatFrameToggleVoiceSelfDeafButton",
    "TextToSpeechButton",
    "QuickJoinToastButton",
    "FriendsMicroButton",
}
Chat.CHAT_CHROME = CHAT_CHROME

local CHAT_BUTTON_SUFFIX = {
    "ButtonFrame",
    "ButtonFrameUpButton",
    "ButtonFrameDownButton",
    "ButtonFrameBottomButton",
    "ButtonFrameMinimizeButton",
    "MinimizeButton",
}
Chat.CHAT_BUTTON_SUFFIX = CHAT_BUTTON_SUFFIX

local TAB_SUFFIX = {
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "Glow",
}

local TAB_KEYS = {
    "leftTexture", "middleTexture", "rightTexture",
    "Left", "Middle", "Right",
    "HighlightLeft", "HighlightMiddle", "HighlightRight",
    "HighlightTexture", "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "glow", "Glow",
}

local EDIT_PARTS = {
    "Left", "Mid", "Right", "Middle",
    "FocusLeft", "FocusMid", "FocusRight", "FocusMiddle",
    "left", "mid", "right", "middle",
    "focusLeft", "focusMid", "focusRight", "focusMiddle",
}
Chat.EDIT_PARTS = EDIT_PARTS

local PAD = 5
Chat.PAD = PAD
local GAP = 3
Chat.GAP = GAP
local SLIDE_X = 18
Chat.SLIDE_X = SLIDE_X
local SLIDE_TIME = 0.2
Chat.SLIDE_TIME = SLIDE_TIME
local FADE_OUT = 0.5
Chat.FADE_OUT = FADE_OUT
local FADE_UI = 0.3
Chat.FADE_UI = FADE_UI
local MAX_LINKS = 12
Chat.MAX_LINKS = MAX_LINKS

Chat.stripping = false
Chat.chromeStripped = false
-- measureWide: state lives in Chat
-- copyBox: state lives in Chat

-- Whisper tabs open temporary windows past NUM_CHAT_WINDOWS (ChatFrame11+), listed in
-- CHAT_FRAMES. The highest one seen is kept, so RestoreChat still reaches a closed one.
local temporaryMax = 0

local function NoteTemporary()
    if type(CHAT_FRAMES) ~= "table" then return end
    for _, name in ipairs(CHAT_FRAMES) do
        local n = type(name) == "string" and tonumber(name:match("^ChatFrame(%d+)$"))
        if n and n > temporaryMax then temporaryMax = n end
    end
end
Chat.NoteTemporary = NoteTemporary

local function ChatCount()
    local n = NUM_CHAT_WINDOWS or 10
    return temporaryMax > n and temporaryMax or n
end
Chat.ChatCount = ChatCount

local function StripTab(tab)
    if not tab or not ns.DB().enabled or not ns.ModernChat() then return end
    local marked = ns.MarkingChat
    ns.MarkingChat = true
    ns.HideTextures(tab)
    local name = ns.FrameName(tab)
    if name then
        for _, suffix in ipairs(TAB_SUFFIX) do
            ns.ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(TAB_KEYS) do
        ns.ForceTextureHidden(tab[key])
    end
    if not tab._puroPuroCineClick and tab.HookScript then
        tab._puroPuroCineClick = true
        tab:HookScript("OnClick", function()
            if ns.DB().enabled and ns.ModernChat() then StripTab(tab) end
        end)
    end
    ns.MarkingChat = marked
end
Chat.StripTab = StripTab
