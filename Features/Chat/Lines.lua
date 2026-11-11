local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

-- Longer tags first, so [Raid Leader] is not cut down to [Raid].
local CHAT_TAGS = {
    { "Battleground Leader", "BL" },
    { "Instance Leader", "IL" },
    { "Raid Warning", "RW" },
    { "Raid Leader", "RL" },
    { "Party Leader", "PL" },
    { "Battleground", "BG" },
    { "Officer", "O" },
    { "Instance", "I" },
    { "Guild", "G" },
    { "Party", "P" },
    { "Raid", "R" },
}

local TAG_SHORT = {}
for i = 1, #CHAT_TAGS do
    TAG_SHORT[CHAT_TAGS[i][1]] = CHAT_TAGS[i][2]
end

local TIMESTAMPS = {
    "^%[%d%d?:%d%d:?%d*%s?[AaPp]?[Mm]?%]%s*",
    "^%d%d?:%d%d:?%d*%s?[AaPp]?[Mm]?%s+",
}

local function SkipCodes(text, pos)
    while true do
        local _, e = text:find("^|c%x%x%x%x%x%x%x%x", pos)
        if not e then _, e = text:find("^|r", pos) end
        if not e then _, e = text:find("^%s+", pos) end
        if not e then return pos end
        pos = e + 1
    end
end

-- Only the channel tag that opens the line: [2. Trade - English] becomes [2],
-- [Guild] becomes [G]. Brackets inside the message stay as typed.
local function ShortChannel(text)
    if not text:find("[", 1, true) then return text end
    local pos = SkipCodes(text, 1)
    for i = 1, #TIMESTAMPS do
        local _, e = text:find(TIMESTAMPS[i], pos)
        if e then
            pos = SkipCodes(text, e + 1)
            break
        end
    end
    local from, to = text:match("^|Hchannel:[^|]*|h%[()[^%]]*()%]|h", pos)
    if not from then from, to = text:match("^%[()[^%]]*()%]", pos) end
    if not from then return text end
    local inner = text:sub(from, to - 1)
    local short = inner:match("^(%d+)%.%s*%S") or TAG_SHORT[inner]
    if not short then return text end
    return text:sub(1, from - 1) .. short .. text:sub(to)
end

-- The message a line carries, for copying: no time, channel tag or sender.
-- Lines without a sender (loot, system, emotes) keep everything after the tag.
local function MessageBody(text)
    if type(text) ~= "string" then return "" end
    local pos = SkipCodes(text, 1)
    for i = 1, #TIMESTAMPS do
        local _, e = text:find(TIMESTAMPS[i], pos)
        if e then
            pos = SkipCodes(text, e + 1)
            break
        end
    end
    local _, e = text:find("^|Hchannel:[^|]*|h%[[^%]]*%]|h", pos)
    if not e then _, e = text:find("^%[[^%]]*%]", pos) end
    if e then pos = SkipCodes(text, e + 1) end
    local rest = text:sub(pos)
    local sender = SkipCodes(rest, (rest:match("^To ()") or 1))
    _, e = rest:find("^|HB?N?player:.-|h.-|h", sender)
    if e then
        -- " says: ", " whispers: " or ": " right after the name, before any other link.
        local said = rest:match("^[^|:]*:%s*()", SkipCodes(rest, e + 1))
        local body = said and rest:sub(said)
        if body and body ~= "" then return body end
    end
    return rest
end
Chat.MessageBody = MessageBody

-- "Changed Channel: |Hchannel:%d|h[%s]|h" -> "Changed Channel:".
-- A missing global keeps the English lead from this client.
local NOTICE_SOURCES = {
    { "CHAT_YOU_CHANGED_NOTICE", "Changed Channel:" },
    { "CHAT_YOU_LEFT_NOTICE", "Left Channel:" },
    { "CHAT_SUSPENDED_NOTICE", "Left Channel:" },
    { "CHAT_YOU_JOINED_NOTICE", "Joined Channel:" },
}

local function NoticeLead(fmt, fallback)
    if type(fmt) ~= "string" then return fallback end
    local lead = fmt:match("^([^|%%]+)")
    if not lead then return fallback end
    lead = lead:gsub("%s+$", "")
    if lead == "" then return fallback end
    return lead
end

local NOTICE_LEADS = {}
do
    local seen = {}
    for i = 1, #NOTICE_SOURCES do
        local src = NOTICE_SOURCES[i]
        local lead = NoticeLead(_G[src[1]], src[2])
        if not seen[lead] then
            seen[lead] = true
            NOTICE_LEADS[#NOTICE_LEADS + 1] = lead
        end
    end
end

local function PlainLine(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h", "")
    text = text:gsub("|h", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("^%s*%[%d+:%d+:?%d*%]%s*", "")
    text = text:gsub("^%s*%d%d?:%d%d:%d%d%s+", "")
    text = text:gsub("^%s*%d%d?:%d%d%s+", "")
    return text:match("^%s*(.*)") or text
end

-- Zone notices shorten to "Changed Channel: [1]", which says nothing.
local function ChannelNotice(text)
    text = PlainLine(text)
    for i = 1, #NOTICE_LEADS do
        local lead = NOTICE_LEADS[i]
        if text:sub(1, #lead) == lead then return true end
    end
    return false
end

local function PushLine(frame, text, r, g, b, animate)
    -- A boss yell can be a secret string. Comparing or editing it throws.
    if type(text) ~= "string" then return end
    local secret = ns.IsSecret(text)
    if not secret then
        if text == "" then return end
        if ChannelNotice(text) then return end
        text = ShortChannel(text)
    end
    local lines = frame._puroPuroCineLines
    if not lines then return end
    local now = GetTime()
    local entry = {
        text = text,
        secret = secret and true or nil,
        r = type(r) == "number" and r or 1,
        g = type(g) == "number" and g or 1,
        b = type(b) == "number" and b or 1,
        born = now,
        slide = animate and now or nil,
    }
    -- Always the newest entry. The client sometimes passes addToStart, which
    -- would pin a new line to the top of this stack.
    lines[#lines + 1] = entry
    local n = #lines
    local over = n - Chat.MaxLines(frame)
    if over > 0 then
        for i = 1, n - over do
            lines[i] = lines[i + over]
        end
        for i = n - over + 1, n do
            lines[i] = nil
        end
    end
    frame._puroPuroCineDirty = true
end
Chat.PushLine = PushLine
