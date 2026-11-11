local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

local function HideCopyBox()
    if not Chat.copyBox then return end
    local anchor = Chat.copyBox.anchor
    Chat.copyBox.anchor = nil
    Chat.copyBox._puroCineStick = nil
    Chat.copyBox:Hide()
    if anchor and anchor.chat then anchor.chat._puroCineDirty = true end
end
Chat.HideCopyBox = HideCopyBox

local function EnsureCopyBox()
    if Chat.copyBox then return Chat.copyBox end
    local box = Chat.Backdropped("EditBox", nil, UIParent)
    Chat.copyBox = box
    pcall(function()
        box:SetFrameStrata("DIALOG")
        box:SetSize(220, 24)
        box:SetAutoFocus(false)
        local font = ChatFontNormal or GameFontHighlight
        if font and box.SetFontObject then
            box:SetFontObject(font)
        end
        if box.SetTextInsets then box:SetTextInsets(6, 6, 2, 2) end
        if box.SetClampedToScreen then box:SetClampedToScreen(true) end
        box:EnableMouse(true)
    end)
    box:Hide()
    Chat.Flat(box, 0.94)
    box:SetScript("OnEscapePressed", function(self)
        self._puroCineStick = nil
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self._puroCineStick = nil
        self:ClearFocus()
    end)
    -- The click that opens the box also drops focus.
    box:SetScript("OnEditFocusLost", function(self)
        if self._puroCineStick and GetTime() < self._puroCineStick then
            local function refocus()
                if not self:IsShown() then return end
                self:SetFocus()
                self:HighlightText()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, refocus)
            end
            return
        end
        local anchor = self.anchor
        self:Hide()
        if anchor and anchor.chat then anchor.chat._puroCineDirty = true end
    end)
    Chat.copyBox = box
    return box
end

-- A secure global pops ADDON_ACTION_BLOCKED when an addon calls it. pcall does not stop that.
local function InsecureGlobal(name)
    if type(_G[name]) ~= "function" then return nil end
    if type(issecurevariable) == "function" and issecurevariable(name) then return nil end
    return _G[name]
end

local function WriteClipboard(text)
    local copy = InsecureGlobal("CopyToClipboard")
    if copy and pcall(copy, text) then return true end
    if not C_System or type(C_System.SetClipboard) ~= "function" then return false end
    if type(issecurevariable) == "function" and issecurevariable(C_System, "SetClipboard") then
        return false
    end
    return pcall(C_System.SetClipboard, text)
end

local function ShowCopyBox(anchor, text)
    local box = EnsureCopyBox()
    box.anchor = anchor
    box._puroCineStick = GetTime() + 0.2
    box:ClearAllPoints()
    local width = 220
    if anchor.GetWidth then
        local w = anchor:GetWidth()
        if type(w) == "number" and not ns.IsSecret(w) then
            width = math.max(180, math.min(420, w))
        end
    end
    box:SetSize(width, 24)
    box:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    box:SetText(text)
    box:Show()
    if anchor.chat then anchor.chat._puroCineDirty = true end
    local function focus()
        if not box:IsShown() then return end
        box:SetFocus()
        box:HighlightText()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, focus)
    else
        focus()
    end
end

local function CopyLine(bubble)
    local msg = bubble.msg
    if not msg or msg.secret then return end
    local text = Chat.PlainText(Chat.MessageBody(msg.text))
    if text == "" then return end
    if WriteClipboard(text) then return end
    ShowCopyBox(bubble, text)
end
Chat.CopyLine = CopyLine
