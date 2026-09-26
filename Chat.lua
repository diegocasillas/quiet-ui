local _, ns = ...

-- Chat keeps its text and drops the chrome. The input shows only while it has
-- focus. No ChatFrame_OpenChat: Enter stays a Blizzard binding.

local CHAT_CHROME = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceSelfMuteButton",
    "ChatFrameToggleVoiceSelfDeafButton",
    "TextToSpeechButton",
}

local CHAT_BUTTON_SUFFIX = {
    "ButtonFrame",
    "ButtonFrameUpButton",
    "ButtonFrameDownButton",
    "ButtonFrameBottomButton",
    "ButtonFrameMinimizeButton",
    "MinimizeButton",
}

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

local stripping = false

local function ChatCount()
    return NUM_CHAT_WINDOWS or 10
end

local function StripTab(tab)
    if not tab or not ns.DB().enabled then return end
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
    if not tab._quietClick and tab.HookScript then
        tab._quietClick = true
        tab:HookScript("OnClick", function()
            if ns.DB().enabled then StripTab(tab) end
        end)
    end
end

------------------------------------------------------------------------------
-- Input box
------------------------------------------------------------------------------
local function SyncEdit(edit)
    if not ns.DB().enabled then
        edit._quietAlpha = nil
        return
    end
    local focused = edit._quietFocus or (edit.HasFocus and edit:HasFocus())
    local alpha = focused and 1 or 0
    ns.PushAlpha(edit, alpha)
    if edit._quietHeader then
        ns.PushAlpha(edit._quietHeader, alpha)
    end
end

local function SetFocus(edit, focused)
    edit._quietFocus = focused
    SyncEdit(edit)
end

local function BindEdit(edit)
    if not edit or edit._quietEdit or not edit.HookScript then return end
    edit._quietEdit = true
    ns.Remember(edit)
    ns.EnsureAlphaHook(edit)
    edit:HookScript("OnEditFocusGained", function(self) SetFocus(self, true) end)
    edit:HookScript("OnEditFocusLost", function(self) SetFocus(self, false) end)
    edit:HookScript("OnShow", SyncEdit)
    local name = ns.FrameName(edit)
    local header = name and _G[name .. "Header"]
    if header and header.SetAlpha and header.GetParent and header:GetParent() ~= edit then
        ns.Remember(header)
        ns.EnsureAlphaHook(header)
        edit._quietHeader = header
    end
    SyncEdit(edit)
end

-- Focus events can be missed, so visible input boxes are checked every frame.
function ns.SyncVisibleEdits()
    if not ns.DB().enabled then return end
    for i = 1, ChatCount() do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit and edit._quietEdit and edit:IsShown() then
            local focused = edit.HasFocus and edit:HasFocus() and true or false
            local alpha = edit:GetAlpha() or 0
            if focused then
                edit._quietFocus = true
                if alpha < 0.99 then SyncEdit(edit) end
            elseif edit._quietFocus or alpha > 0.01 then
                SetFocus(edit, false)
            end
        end
    end
end

------------------------------------------------------------------------------
-- Chat windows
------------------------------------------------------------------------------
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
    if not name then return end
    for _, suffix in ipairs(CHAT_BUTTON_SUFFIX) do
        ns.Mute(_G[name .. suffix])
    end
    StripTab(_G[name .. "Tab"])
    BindEdit(_G[name .. "EditBox"])
end

local function StripDock()
    local dock = GeneralDockManager
    if not dock then return end
    ns.HideTextures(dock)
    ns.HideBackground(dock.Background or _G.GeneralDockManagerBackground)
end

function ns.StripAllChat()
    if stripping or not ns.DB().enabled then return end
    stripping = true
    local ok, err = pcall(function()
        for i = 1, ChatCount() do
            StripChat(_G["ChatFrame" .. i])
        end
        for _, name in ipairs(CHAT_CHROME) do
            ns.Mute(_G[name])
        end
        StripDock()
    end)
    stripping = false
    if not ok then ns.Report("chat", err) end
end
