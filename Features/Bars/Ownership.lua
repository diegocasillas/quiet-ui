local _, ns = ...
local Bars = ns.Bars or {}
ns.Bars = Bars

-- Frame ownership changes when the UI structure changes. A bar that parents another stays at
-- alpha 1 or the child would fade with it.
local owner = {}
Bars.owner = owner
-- Built with owner in Collect: hosts[bar] lists nested bars of another row, covered[bar]
-- marks a bar whose outer frame of the same row already carries the alpha.
local hosts = {}
Bars.hosts = hosts
local covered = {}
Bars.covered = covered
local resolved = {}
Bars.resolved = resolved
local held = {}
Bars.held = held
local seenHeld = {}
Bars.seenHeld = seenHeld

local function UnderOther(frame, bar)
    for other in pairs(owner) do
        if other ~= bar and Bars.IsAncestor(frame, other) then
            return true
        end
    end
    return false
end

local function HostsOther(bar)
    return hosts[bar] ~= nil
end
Bars.HostsOther = HostsOther

local function LeaveAlone(frame)
    if ns.IsBagRelated(frame) then return true end
    local name = ns.FrameName(frame)
    return name ~= nil and name:find("Micro") ~= nil
end

local function EachOwnButton(bar, fn)
    local seen = {}
    local function consider(button)
        if not ns.Usable(button) or seen[button] or LeaveAlone(button) or UnderOther(button, bar) then return end
        seen[button] = true
        fn(button)
    end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            consider(child)
        end
    end
    local prefix = Bars.BUTTON_PREFIX[ns.FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            consider(_G[prefix .. i])
        end
    end
end
Bars.EachOwnButton = EachOwnButton

local function IsPressable(frame)
    if not ns.Usable(frame) or not frame.GetObjectType then return false end
    local ok, kind = pcall(frame.GetObjectType, frame)
    return ok and (kind == "Button" or kind == "CheckButton")
end

local function EachDeepButton(bar, fn, depth)
    depth = depth or 0
    if depth > 4 or not ns.Usable(bar) or not bar.GetChildren then return end
    for _, child in ipairs({ bar:GetChildren() }) do
        if ns.Usable(child) and not owner[child] and not LeaveAlone(child) then
            if IsPressable(child) then
                if not UnderOther(child, bar) then
                    fn(child)
                end
            else
                EachDeepButton(child, fn, depth + 1)
            end
        end
    end
end
Bars.EachDeepButton = EachDeepButton
