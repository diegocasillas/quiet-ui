local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

-- Visible lines only, oldest first. Used when the frame will not give history back.
local function SeedFromRegions(frame)
    if not frame.GetNumRegions then return end
    local found = {}
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
            local text = region:GetText()
            if ns.IsSecret(text) or (type(text) == "string" and text ~= "") then
                local y = region.GetBottom and region:GetBottom()
                local r, g, b = 1, 1, 1
                if region.GetTextColor then
                    local cr, cg, cb = region:GetTextColor()
                    if type(cr) == "number" then
                        r, g, b = cr, cg, cb
                    end
                end
                found[#found + 1] = {
                    text = text,
                    y = type(y) == "number" and y or 0,
                    r = r, g = g, b = b,
                }
            end
        end
    end
    table.sort(found, function(a, b)
        return a.y > b.y
    end)
    for i = 1, #found do
        local line = found[i]
        Chat.PushLine(frame, line.text, line.r, line.g, line.b, false)
    end
end

local function BindBubbles(frame)
    if not frame or frame._quietBubbles or type(frame.AddMessage) ~= "function" then return end
    if not ns.Usable(frame) then return end
    frame._quietBubbles = true
    frame._quietLines = {}
    frame._quietPool = {}
    frame._quietByMsg = {}
    if type(frame.GetNumMessages) == "function" and type(frame.GetMessageInfo) == "function" then
        local ok, n = pcall(frame.GetNumMessages, frame)
        if ok and type(n) == "number" then
            for i = 1, n do
                local okLine, text, r, g, b = pcall(frame.GetMessageInfo, frame, i)
                if not okLine then break end
                Chat.PushLine(frame, text, r, g, b, false)
            end
        end
    end
    if #frame._quietLines == 0 then
        pcall(SeedFromRegions, frame)
    end
    Chat.TrackScroll(frame)
    local ok, err = pcall(hooksecurefunc, frame, "AddMessage", function(self, text, r, g, b)
        local bottom = Chat.AtBottom(self)
        if self._quietScrollHook and not bottom then
            self._quietScroll = (self._quietScroll or 0) + 1
        end
        Chat.PushLine(self, text, r, g, b, ns.DB().enabled and ns.ModernChat() and bottom)
        Chat.HideNativeText(self)
        if self._quietScrollHook then
            self._quietScroll = Chat.ClampScroll(self, self._quietScroll or 0)
        end
    end)
    if not ok then ns.Report("chat line", err) end
    if type(frame.Clear) == "function" then
        pcall(hooksecurefunc, frame, "Clear", function(self)
            if self._quietLines then ns.Wipe(self._quietLines) end
            self._quietScroll = 0
            self._quietDirty = true
        end)
    end
    Chat.EnsureCatcher(frame)
    if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
    if frame.HookScript and not frame._quietWheel then
        frame._quietWheel = true
        frame:HookScript("OnMouseWheel", function(self, delta)
            if not ns.DB().enabled or not ns.ModernChat() then return end
            Chat.Wheel(self, delta)
        end)
    end
end
Chat.BindBubbles = BindBubbles

local function EaseEdit(edit, elapsed)
    if not edit or not edit._quietEdit or edit._quietWant == nil then return end
    local show = edit._quietWant == 1
    ns.EaseAlpha(edit, show, elapsed)
    if edit._quietHeader then
        ns.EaseAlpha(edit._quietHeader, show, elapsed)
    end
    if edit._quietPlate then
        ns.EaseAlpha(edit._quietPlate, show, elapsed)
    end
end

function ns.UpdateChat(elapsed)
    if not ns.DB().enabled or not ns.ModernChat() then return end
    local now = GetTime()
    for i = 1, Chat.ChatCount() do
        EaseEdit(_G["ChatFrame" .. i .. "EditBox"], elapsed)
        local frame = _G["ChatFrame" .. i]
        if frame and frame._quietBubbles then
            if not ns.Usable(frame) or not frame.IsShown or not frame:IsShown() then
                if frame._quietShown ~= false then
                    Chat.HideActive(frame)
                    if frame._quietCatcher then frame._quietCatcher:Hide() end
                    frame._quietShown, frame._quietHover = false, false
                    frame._quietCatcherAt = nil
                end
            else
                if frame._quietShown == false then frame._quietDirty = true end
                -- Anchors follow the chat automatically; only stacking needs a periodic refresh.
                if frame._quietDirty or not frame._quietCatcherAt or now >= frame._quietCatcherAt then
                    Chat.PlaceCatcher(frame)
                    frame._quietCatcherAt = now + 0.1
                end
                local hot = Chat.FrameHot(frame) or Chat.TabRowHot(frame, i)
                if hot ~= frame._quietHover then
                    frame._quietHover = hot
                    frame._quietDirty = true
                end
                local wake = frame._quietNext
                if frame._quietDirty or wake == 0 or (type(wake) == "number" and wake > 0 and now >= wake) then
                    Chat.LayoutFrame(frame, elapsed)
                end
            end
        end
    end
    Chat.FadeTabs(elapsed)
end

function ns.RestoreChat()
    Chat.RestoreTabs()
    Chat.HideCopyBox()
    Chat.RestoreEdits()
    ns.ReleaseChatHold()
    Chat.chromeStripped = false
    for i = 1, Chat.ChatCount() do
        local frame = _G["ChatFrame" .. i]
        if frame and frame._quietBubbles then
            frame._quietStripped = nil
            frame._quietHover = false
            frame._quietCatcherAt = nil
            frame._quietTextSig = nil
            if frame._quietCatcher then frame._quietCatcher:Hide() end
            Chat.HideActive(frame)
            Chat.RestoreFonts(frame)
        elseif frame then
            frame._quietStripped = nil
        end
    end
end
