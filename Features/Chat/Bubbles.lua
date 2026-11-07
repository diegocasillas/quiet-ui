local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

local function ApplyFont(bubble, chat)
    pcall(function()
        local font, size, flags
        if chat.GetFont then
            font, size, flags = chat:GetFont()
        end
        if type(size) ~= "number" or size <= 2 then
            font = font or "Fonts\\FRIZQT__.TTF"
            size = 14
        end
        if font then
            bubble.text:SetFont(font, size, flags)
        end
        if chat.GetShadowOffset and bubble.text.SetShadowOffset then
            local x, y = chat:GetShadowOffset()
            if type(x) == "number" and type(y) == "number" then
                bubble.text:SetShadowOffset(x, y)
            end
        end
        if chat.GetShadowColor and bubble.text.SetShadowColor then
            local r, g, b, a = chat:GetShadowColor()
            if type(r) == "number" then
                bubble.text:SetShadowColor(r, g, b, a or 1)
            end
        end
        if chat.GetSpacing and bubble.text.SetSpacing then
            local spacing = chat:GetSpacing()
            if type(spacing) == "number" then
                bubble.text:SetSpacing(spacing)
            end
        end
        if chat.GetIndentedWordWrap and bubble.text.SetIndentedWordWrap then
            bubble.text:SetIndentedWordWrap(chat:GetIndentedWordWrap())
        end
    end)
end
Chat.ApplyFont = ApplyFont

local function SizeBubble(bubble, msg, maxW)
    local font, size, flags = bubble.text:GetFont()
    -- A secret string cannot be concatenated into the cache key.
    local tail = msg.secret and tostring(msg) or (msg.text or "")
    local fontKey = tostring(font) .. ":" .. tostring(size) .. ":" .. tostring(flags)
    local key = fontKey .. ":" .. math.floor(maxW) .. ":" .. tail
    if bubble._quietSizeKey == key and bubble.h then
        return bubble.h
    end
    bubble._quietSizeKey = nil
    local innerMax = math.max(8, maxW - Chat.PAD * 2)
    if msg.secret then
        local lineH = type(size) == "number" and size or 14
        if bubble.text.GetSpacing then
            local spacing = bubble.text:GetSpacing()
            if type(spacing) == "number" and spacing > 0 then lineH = lineH + spacing end
        end
        local canRead = bubble:IsShown() and bubble._quietLaid == key
        bubble.text:SetWidth(innerMax)
        bubble.text:SetText(msg.text)
        bubble.text:SetTextColor(msg.r or 1, msg.g or 1, msg.b or 1, 1)
        bubble._quietLaid = key
        local measured = 0
        if canRead and bubble.text.GetStringHeight then
            local ok, h = pcall(bubble.text.GetStringHeight, bubble.text)
            if ok and type(h) == "number" and not ns.IsSecret(h) and h > 0 then
                measured = h
            end
        end
        local th = measured > 0 and measured or lineH * 4
        if canRead and measured > 0 then
            bubble._quietSizeKey = key
        end
        bubble.inner = innerMax
        bubble.h = th + Chat.PAD * 2
        bubble:SetSize(innerMax + Chat.PAD * 2, bubble.h)
        Chat.PlaceLinks(bubble, msg, innerMax)
        return bubble.h
    end
    local text = msg.text or ""
    local wide = msg.wide
    if msg._quietWidthFont ~= fontKey or msg._quietWidthText ~= text or not wide or wide <= 0 then
        wide = Chat.UnboundedWidth(bubble.text, text)
        if wide > 0 then
            msg.wide = wide
            msg._quietWidthFont, msg._quietWidthText = fontKey, text
        elseif msg._quietWidthFont == fontKey and msg._quietWidthText == text then
            wide = msg.wide or 0
        end
    end
    -- A width that matches the text exactly still wraps the last word.
    local SLACK = 8
    local fits = wide > 0 and wide + SLACK <= innerMax
    local inner = innerMax
    if fits then
        inner = math.max(8, wide + SLACK)
    end
    local lineH = type(size) == "number" and size or 14
    if bubble.text.GetSpacing then
        local spacing = bubble.text:GetSpacing()
        if type(spacing) == "number" and spacing > 0 then lineH = lineH + spacing end
    end
    local rows = 1
    if not fits and wide > inner + 0.5 then
        rows = math.ceil(wide / inner)
    end
    -- Read the bubble only after it was shown with this same text. A fresh
    -- string reports one short line, the row is shown, then it grows and the
    -- top message is dropped and put back every frame.
    local canRead = bubble:IsShown() and bubble._quietLaid == key
    bubble.text:SetWidth(inner)
    bubble.text:SetText(text)
    bubble.text:SetTextColor(msg.r or 1, msg.g or 1, msg.b or 1, 1)
    bubble._quietLaid = key
    local measured, lines = 0, 0
    if canRead and not fits then
        local h = bubble.text:GetStringHeight()
        if type(h) == "number" and not ns.IsSecret(h) and h > 0 then measured = h end
        if bubble.text.GetNumLines then
            local ok, n = pcall(bubble.text.GetNumLines, bubble.text)
            if ok and type(n) == "number" and not ns.IsSecret(n) and n >= 1 then
                lines = math.floor(n)
            end
        end
        if bubble.text.GetLineHeight then
            local ok, lh = pcall(bubble.text.GetLineHeight, bubble.text)
            if ok and type(lh) == "number" and not ns.IsSecret(lh) and lh > lineH then
                lineH = lh
            end
        end
        if lines > rows then rows = lines end
    end
    local th = math.max(rows, 1) * lineH
    if not fits and measured > th then th = measured end
    -- A line that fits stays one row. Only a real wrap may keep a taller size.
    if fits then
        th = lineH
        msg.h = th
    elseif type(msg.h) == "number" and msg.h > th then
        th = msg.h
    else
        msg.h = th
    end
    -- Spacing and conservative row estimates can exceed the rendered height.
    local trusted = fits or (canRead and measured > 0)
    if trusted then
        bubble._quietSizeKey = key
    end
    bubble.inner = inner
    bubble.h = th + Chat.PAD * 2
    bubble:SetSize(inner + Chat.PAD * 2, bubble.h)
    Chat.PlaceLinks(bubble, msg, inner)
    return bubble.h
end
Chat.SizeBubble = SizeBubble

local function RaiseCopy(icon, bubble)
    if icon.SetFrameStrata then
        pcall(icon.SetFrameStrata, icon, "DIALOG")
    end
    if icon.SetFrameLevel and bubble.GetFrameLevel then
        pcall(icon.SetFrameLevel, icon, (bubble:GetFrameLevel() or 1) + 20)
    end
end

local function ShowCopy(bubble, hot)
    local icon = bubble.copy
    if not icon then return end
    if not hot or not bubble:IsShown() or (bubble.msg and bubble.msg.secret) then
        if icon:IsShown() then
            icon:EnableMouse(false)
            icon:Hide()
        end
        return
    end
    RaiseCopy(icon, bubble)
    icon:Show()
    icon:EnableMouse(true)
    icon:SetAlpha(0.85)
end
Chat.ShowCopy = ShowCopy

local function EnterBubble(bubble)
    bubble._quietSettle = (bubble._quietSettle or 0) + 1
    bubble._quietHot = true
    ShowCopy(bubble, true)
    if bubble.chat then bubble.chat._quietDirty = true end
end
Chat.EnterBubble = EnterBubble

-- OnLeave fires while the pointer is still crossing to the icon. Recheck after it lands.
local function SettleHot(bubble)
    if not bubble then return end
    bubble._quietSettle = (bubble._quietSettle or 0) + 1
    local token = bubble._quietSettle
    local function apply()
        if bubble._quietSettle ~= token then return end
        local icon = bubble.copy
        local hot = ns.MouseOver(bubble) or (icon and icon:IsShown() and ns.MouseOver(icon))
        bubble._quietHot = hot and true or false
        ShowCopy(bubble, bubble._quietHot)
        if bubble.chat then bubble.chat._quietDirty = true end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.12, apply)
    else
        apply()
    end
end
Chat.SettleHot = SettleHot

local function SlideX(msg, now)
    if not msg.slide then return 0 end
    local age = now - msg.slide
    if age < 0 or age >= Chat.SLIDE_TIME then return 0 end
    local t = age / Chat.SLIDE_TIME
    local k = 1 - (1 - t) * (1 - t)
    return -Chat.SLIDE_X * (1 - k)
end
Chat.SlideX = SlideX

local function ChatLife()
    local life = 10
    if ns.ChatFade then life = ns.ChatFade() end
    if type(life) ~= "number" then return 10 end
    return life
end
Chat.ChatLife = ChatLife

-- 0 hides the line. The last half second fades it. A missing interval stays at 10.
local function LineAlpha(msg, life, now)
    if life <= 0 or not msg.born then return 1 end
    local left = life - (now - msg.born)
    if left <= 0 then return 0 end
    if left >= Chat.FADE_OUT then return 1 end
    return left / Chat.FADE_OUT
end
Chat.LineAlpha = LineAlpha

local function Approach(current, goal, elapsed, duration)
    local step = (elapsed or 0) / duration
    if math.abs(goal - current) <= step then return goal end
    if goal > current then return current + step end
    return current - step
end
Chat.Approach = Approach

-- Keeps this line up, including the copy box.
local function BubbleHeld(bubble)
    if not bubble then return false end
    if bubble._quietHot then return true end
    return Chat.copyBox and Chat.copyBox:IsShown() and Chat.copyBox.anchor == bubble or false
end
Chat.BubbleHeld = BubbleHeld

-- Above the chat frame, under the bubbles. This client does not deliver the wheel
-- to a pass-through or motion-only frame, so the catcher keeps the mouse.
local function EnsureCatcher(frame)
    if frame._quietCatcher then return frame._quietCatcher end
    local ok, box = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not box then return end
    if box.EnableMouse then box:EnableMouse(true) end
    if type(box.SetMouseMotionEnabled) == "function" then
        pcall(box.SetMouseMotionEnabled, box, true)
    end
    if type(box.SetMouseClickEnabled) == "function" then
        pcall(box.SetMouseClickEnabled, box, true)
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta)
        Chat.Wheel(frame, delta)
    end)
    box:Hide()
    frame._quietCatcher = box
    return box
end
Chat.EnsureCatcher = EnsureCatcher

local function PlaceCatcher(frame)
    local box = frame._quietCatcher
    if not box then return end
    if not ns.Usable(frame) or not frame.IsShown or not frame:IsShown() then
        box:Hide()
        return
    end
    if box._quietSpan ~= frame then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(frame)
        box._quietSpan = frame
    end
    local strata = frame.GetFrameStrata and frame:GetFrameStrata()
    if type(strata) == "string" and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or 0
    if type(level) ~= "number" then level = 0 end
    if box._quietAnchor ~= level then
        box:SetFrameLevel(level + 1)
        box._quietAnchor = level
        frame._quietDirty = true
    end
    if not box:IsShown() then box:Show() end
end
Chat.PlaceCatcher = PlaceCatcher

-- The block, a bubble, or the copy icon. The copy box alone does not count.
-- A still pointer does not need another pass over every bubble.
local function FrameHot(frame)
    local box = frame._quietCatcher
    if box and box:IsShown() and ns.Hit(box) then return true end
    local byMsg = frame._quietByMsg
    if not byMsg then return false end
    local moved = not ns.PointerMoved or ns.PointerMoved()
    if not moved then
        local anyHot = false
        for _, bubble in pairs(byMsg) do
            if bubble._quietHot then
                anyHot = true
                break
            end
        end
        if not anyHot then return false end
    end
    for _, bubble in pairs(byMsg) do
        local over = bubble:IsShown() and ns.MouseOver(bubble)
        if bubble._quietHot or over then return true end
    end
    return false
end
Chat.FrameHot = FrameHot

local function Ease(current, target, elapsed)
    local t = math.min(1, (elapsed or 0) * 14)
    local y = current + (target - current) * t
    if math.abs(target - y) < 0.5 then return target end
    return y
end
Chat.Ease = Ease
