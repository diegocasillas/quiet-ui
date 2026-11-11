local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

local function ReleaseBubble(frame, bubble)
    if Chat.copyBox and Chat.copyBox.anchor == bubble then
        Chat.HideCopyBox()
    end
    bubble._puroCineHot = false
    Chat.ShowCopy(bubble, false)
    bubble:Hide()
    bubble:SetAlpha(1)
    bubble.msg = nil
    bubble._y = nil
    bubble._puroCineSizeKey = nil
    bubble._puroCineLaid = nil
    bubble._puroCinePX = nil
    bubble._puroCinePY = nil
    bubble._puroCinePA = nil
    bubble._puroCineLevel = nil
    bubble._puroCineFontStamp = nil
    bubble._puroCineTargetY = nil
    bubble._puroCinePendingAlpha, bubble._puroCinePendingGoal, bubble._puroCinePendingHeld = nil, nil, nil
    frame._puroCinePool[#frame._puroCinePool + 1] = bubble
end
Chat.ReleaseBubble = ReleaseBubble

local function CreateBubble(frame)
    local bubble = CreateFrame("Frame", nil, frame)
    bubble._puroCineBubble = true
    bubble.chat = frame
    bubble.links = {}
    Chat.BindBubbleLinks(bubble)
    bubble:EnableMouse(true)
    bubble:EnableMouseWheel(true)
    local level = (frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 2
    if type(level) ~= "number" then level = 2 end
    pcall(bubble.SetFrameLevel, bubble, level)
    if bubble.SetClipsChildren then bubble:SetClipsChildren(true) end
    bubble:SetScript("OnMouseWheel", function(_, delta)
        Chat.Wheel(frame, delta)
    end)
    bubble:SetScript("OnEnter", function(self)
        Chat.EnterBubble(self)
    end)
    bubble:SetScript("OnLeave", function(self)
        Chat.SettleHot(self)
    end)
    Chat.TintRound(bubble, 0, 0, 0, 0.48)
    local text = bubble:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOPLEFT", bubble, "TOPLEFT", Chat.PAD, -Chat.PAD)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    if text.SetWordWrap then text:SetWordWrap(true) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end
    bubble.text = text
    local icon = CreateFrame("Button", nil, UIParent)
    icon:SetSize(12, 12)
    -- Overlap the bubble and grow the hit box so the pointer never crosses a dead gap.
    icon:SetPoint("LEFT", bubble, "RIGHT", -6, 0)
    if icon.SetHitRectInsets then
        icon:SetHitRectInsets(-8, -8, -10, -10)
    end
    icon:RegisterForClicks("LeftButtonUp")
    icon:SetAlpha(0)
    icon:EnableMouse(false)
    icon.bubble = bubble
    icon:SetScript("OnClick", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() Chat.CopyLine(bubble) end)
        else
            Chat.CopyLine(bubble)
        end
    end)
    icon:SetScript("OnEnter", function(self)
        if self.bubble then Chat.EnterBubble(self.bubble) end
        if self.front then self.front:SetVertexColor(0.95, 0.75, 0.25, 1) end
    end)
    icon:SetScript("OnLeave", function(self)
        if self.front then self.front:SetVertexColor(0.9, 0.9, 0.9, 0.85) end
        Chat.SettleHot(self.bubble)
    end)
    icon:SetScript("OnMouseWheel", function(_, delta)
        Chat.Wheel(frame, delta)
    end)
    Chat.AddRect(icon, 4, 1, 5, 7, 0.45, 0.45, 0.45, 0.85)
    icon.front = Chat.AddRect(icon, 1, 4, 5, 7, 0.9, 0.9, 0.9, 0.85)
    bubble.copy = icon
    bubble:Hide()
    return bubble
end

local function AcquireBubble(frame)
    local pool = frame._puroCinePool
    local bubble = pool[#pool]
    if bubble then
        pool[#pool] = nil
        return bubble
    end
    return CreateBubble(frame)
end
Chat.AcquireBubble = AcquireBubble

local function HideActive(frame)
    frame._puroCineDirty = true
    frame._puroCineNext, frame._puroCineFadeAt, frame._puroCineLayoutPending = 0, nil, nil
    local animations = frame._puroCineAnimations
    if animations then
        for i = #animations, 1, -1 do animations[i] = nil end
    end
    local byMsg = frame._puroCineByMsg
    if not byMsg then return end
    for msg, bubble in pairs(byMsg) do
        byMsg[msg] = nil
        ReleaseBubble(frame, bubble)
    end
end
Chat.HideActive = HideActive
