local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

local function FontStamp(frame)
    local font, size, flags
    if frame.GetFont then
        local ok, f, s, fl = pcall(frame.GetFont, frame)
        if ok then font, size, flags = f, s, fl end
    end
    return tostring(font) .. "\0" .. tostring(size) .. "\0" .. tostring(flags)
end

local function BubbleAlpha(known, msg, fading, reveal, life, now, elapsed)
    local held = known and Chat.BubbleHeld(known)
    local natural = fading and not held and Chat.LineAlpha(msg, life, now) or 1
    local goal = (reveal or held) and 1 or natural
    local current = known and known._cinePA
    if type(current) ~= "number" or goal >= current then
        current = goal
    elseif current > goal + 0.02 then
        current = Chat.Approach(current, goal, elapsed, Chat.FADE_UI)
    else
        current = goal
    end
    return current, goal, held
end

local function PaintBubble(frame, bubble, x, y, alpha)
    if bubble._cinePX ~= x or bubble._cinePY ~= y then
        bubble:ClearAllPoints()
        bubble:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, y)
        bubble._cinePX, bubble._cinePY = x, y
    end
    if bubble._cinePA ~= alpha then
        bubble:SetAlpha(alpha)
        bubble._cinePA = alpha
    end
    if not bubble:IsShown() then bubble:Show() end
end

local function BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
    local msg = bubble.msg
    local animated = (msg.slide and now - msg.slide < Chat.SLIDE_TIME)
        or math.abs(bubble._cinePA - goal) > 0.01 or bubble._y ~= bubble._cineTargetY
    local fadeAt
    if not reveal and fading and life > 0 and msg.born and not held then
        local at = msg.born + life - Chat.FADE_OUT
        if now < at - 0.02 then fadeAt = at
        else animated = true end
    end
    return animated, fadeAt
end

local function AnimateFrame(frame, elapsed, now)
    local animations = frame._cineAnimations
    if not animations or #animations == 0 then return false end
    local fading = frame._cineOffset == 0
    local reveal = fading and frame._cineHover
    local life = frame._cineLife
    local count = #animations
    -- A disappearing row changes the stack. Decide before moving any other row.
    for i = 1, count do
        local bubble = animations[i]
        local msg = bubble.msg
        local current, goal, held = BubbleAlpha(bubble, msg, fading, reveal, life, now, elapsed)
        local sliding = msg.slide and now - msg.slide < Chat.SLIDE_TIME
        if current <= 0.01 and goal <= 0 and not sliding then return false end
        bubble._cinePendingAlpha, bubble._cinePendingGoal, bubble._cinePendingHeld = current, goal, held
    end
    local n, fadeAt = 0, frame._cineFadeAt
    for i = 1, count do
        local bubble = animations[i]
        local current, goal, held = bubble._cinePendingAlpha, bubble._cinePendingGoal, bubble._cinePendingHeld
        bubble._cinePendingAlpha, bubble._cinePendingGoal, bubble._cinePendingHeld = nil, nil, nil
        bubble._y = Chat.Ease(bubble._y, bubble._cineTargetY, elapsed)
        PaintBubble(frame, bubble, 4 + Chat.SlideX(bubble.msg, now), bubble._y, current)
        local animated, wake = BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
        if animated then n = n + 1; animations[n] = bubble end
        if wake and (not fadeAt or wake < fadeAt) then fadeAt = wake end
    end
    for i = n + 1, count do animations[i] = nil end
    frame._cineFadeAt = fadeAt
    frame._cineNext = n > 0 and 0 or fadeAt
    return true
end

local function LayoutFrame(frame, elapsed)
    if not ns.Usable(frame) or not frame._cineLines then return end
    if not frame.IsShown or not frame:IsShown() then
        if frame._cineShown ~= false then
            frame._cineShown = false
            Chat.HideActive(frame)
        end
        return
    end
    if frame._cineShown == false then
        frame._cineDirty = true
    end
    frame._cineShown = true
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    if type(width) ~= "number" or ns.IsSecret(width) or width < 40 then return end
    if type(height) ~= "number" or ns.IsSecret(height) or height < 20 then return end
    local lines = frame._cineLines
    local offset = math.floor(Chat.ScrollOffset(frame))
    if offset < 0 then offset = 0 end
    local maxOffset = math.max(0, #lines - 1)
    if offset > maxOffset then offset = maxOffset end
    local life = Chat.ChatLife()
    local now = GetTime()
    local restack = frame._cineDirty or frame._cineW ~= width or frame._cineH ~= height
        or frame._cineOffset ~= offset or frame._cineLife ~= life
    local due = frame._cineNext == 0 or (type(frame._cineNext) == "number" and frame._cineNext > 0 and now >= frame._cineNext)
    if not restack and not due then return end
    if not restack and not frame._cineLayoutPending and (not frame._cineFadeAt or now < frame._cineFadeAt)
        and AnimateFrame(frame, elapsed, now) then return end
    frame._cineDirty = nil
    frame._cineW, frame._cineH = width, height
    frame._cineOffset = offset
    frame._cineLife = life
    Chat.RepairTinyFont(frame)
    local byMsg = frame._cineByMsg
    -- Only the bottom view drops old lines. Hover shows the page that fits; scrolling walks the rest.
    local fading = offset == 0
    local reveal = fading and frame._cineHover
    local index = #lines - offset
    local y = 4
    local seen = frame._cineSeen
    if not seen then
        seen = {}
        frame._cineSeen = seen
    else
        for key in pairs(seen) do
            seen[key] = nil
        end
    end
    local stack = frame._cineStack
    if not stack then
        stack = {}
        frame._cineStack = stack
    end
    local stackN = 0
    local fontStamp = frame._cineFont
    if restack or not fontStamp then
        fontStamp = FontStamp(frame)
        frame._cineFont = fontStamp
    end
    local animations = frame._cineAnimations
    if not animations then animations = {}; frame._cineAnimations = animations end
    local animatedN, fadeAt, measure, dropped = 0, nil, false, false
    local guard = 0
    while index >= 1 and guard < 40 do
        guard = guard + 1
        local msg = lines[index]
        local known = byMsg[msg]
        local current, goal, held = BubbleAlpha(known, msg, fading, reveal, life, now, elapsed)
        local place = true
        local sliding = msg.slide and now - msg.slide < Chat.SLIDE_TIME
        if current <= 0.01 and goal <= 0 and not sliding then
            place = false
            if not known then break end
            dropped = true
        end
        if place then
            local bubble = known or Chat.AcquireBubble(frame)
            local h = bubble.h
            if bubble.msg ~= msg or not h or not bubble._cineSizeKey or restack then
                if bubble._cineFontStamp ~= fontStamp then
                    Chat.ApplyFont(bubble, frame)
                    bubble._cineFontStamp = fontStamp
                    bubble._cineSizeKey = nil
                end
                h = Chat.SizeBubble(bubble, msg, width - 8)
            end
            if y > 4 and y + h > height - 2 then
                if not known then
                    Chat.ReleaseBubble(frame, bubble)
                end
                break
            end
            byMsg[msg] = bubble
            seen[msg] = true
            stackN = stackN + 1
            stack[stackN] = bubble
            local target = y
            bubble._cineTargetY = target
            if bubble.msg ~= msg or bubble._y == nil then
                bubble._y = target
            else
                bubble._y = Chat.Ease(bubble._y, target, elapsed)
            end
            bubble.msg = msg
            bubble.chat = frame
            PaintBubble(frame, bubble, 4 + Chat.SlideX(msg, now), bubble._y, current)
            -- Wrapped text needs a shown frame before its height can be trusted.
            if not bubble._cineSizeKey then measure = true end
            local animated, wake = BubbleSchedule(bubble, goal, held, fading, reveal, life, now)
            if animated then animatedN = animatedN + 1; animations[animatedN] = bubble end
            if wake and (not fadeAt or wake < fadeAt) then fadeAt = wake end
            y = y + h + Chat.GAP
        end
        index = index - 1
    end
    for i = stackN + 1, #stack do
        stack[i] = nil
    end
    -- Same level, newest raised last so it stays above the lines it pushes up.
    if restack then
        local level = (frame:GetFrameLevel() or 0) + 2
        for i = stackN, 1, -1 do
            local bubble = stack[i]
            bubble._cineLevel = level
            pcall(bubble.SetFrameLevel, bubble, level)
        end
    end
    for i = animatedN + 1, #animations do animations[i] = nil end
    -- Revisit a released history gap before continuing the remaining animations.
    frame._cineLayoutPending = measure or (dropped and animatedN > 0)
    frame._cineFadeAt = fadeAt
    frame._cineNext = (frame._cineLayoutPending or animatedN > 0) and 0 or fadeAt
    for msg, bubble in pairs(byMsg) do
        if not seen[msg] then
            byMsg[msg] = nil
            Chat.ReleaseBubble(frame, bubble)
        end
    end
end
Chat.LayoutFrame = LayoutFrame
