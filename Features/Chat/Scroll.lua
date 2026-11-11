local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

------------------------------------------------------------------------------
-- Bubbles. Native lines stay so scroll and history keep working; their alpha
-- is held at 0 so the text is not drawn twice.
------------------------------------------------------------------------------
local function ScrollOffset(frame)
    if type(frame.GetScrollOffset) == "function" then
        local ok, offset = pcall(frame.GetScrollOffset, frame)
        if ok and type(offset) == "number" and not ns.IsSecret(offset) then
            return offset
        end
    end
    if type(frame.scrollOffset) == "number" then
        return frame.scrollOffset
    end
    return frame._puroCineScroll or 0
end
Chat.ScrollOffset = ScrollOffset

local function AtBottom(frame)
    if type(frame.AtBottom) == "function" then
        local ok, at = pcall(frame.AtBottom, frame)
        if ok then return not not at end
    end
    return ScrollOffset(frame) < 1
end
Chat.AtBottom = AtBottom

local function ClampScroll(frame, value)
    if value < 0 then return 0 end
    local max = frame._puroCineLines and #frame._puroCineLines or 0
    if value > max then return max end
    return value
end
Chat.ClampScroll = ClampScroll

local function TrackScroll(frame)
    if frame._puroCineScrollHook then return end
    frame._puroCineScrollHook = true
    local native = type(frame.GetScrollOffset) == "function"
    if not native then
        frame._puroCineScroll = 0
    end
    local function hook(name, fn)
        if type(frame[name]) ~= "function" then return end
        pcall(hooksecurefunc, frame, name, function(self)
            self._puroCineDirty = true
            if fn then fn(self) end
        end)
    end
    if native then
        hook("ScrollUp")
        hook("ScrollDown")
        hook("PageUp")
        hook("PageDown")
        hook("ScrollToBottom")
    else
        hook("ScrollUp", function(self)
            self._puroCineScroll = ClampScroll(self, (self._puroCineScroll or 0) + 1)
        end)
        hook("ScrollDown", function(self)
            self._puroCineScroll = ClampScroll(self, (self._puroCineScroll or 0) - 1)
        end)
        hook("PageUp", function(self)
            self._puroCineScroll = ClampScroll(self, (self._puroCineScroll or 0) + 10)
        end)
        hook("PageDown", function(self)
            self._puroCineScroll = ClampScroll(self, (self._puroCineScroll or 0) - 10)
        end)
        hook("ScrollToBottom", function(self)
            self._puroCineScroll = 0
        end)
    end
    if frame.HookScript then
        frame:HookScript("OnSizeChanged", function(self)
            self._puroCineDirty = true
        end)
    end
end
Chat.TrackScroll = TrackScroll

local function MaxLines(frame)
    if type(frame.GetMaxLines) == "function" then
        local ok, n = pcall(frame.GetMaxLines, frame)
        if ok and type(n) == "number" and n > 1 then return math.floor(n) end
    end
    return 128
end
Chat.MaxLines = MaxLines
