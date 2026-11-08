local _, ns = ...
local Chat = ns.Chat or {}
ns.Chat = Chat

------------------------------------------------------------------------------
-- Input box
------------------------------------------------------------------------------
local function Backdropped(kind, name, parent)
    local ok, widget = pcall(CreateFrame, kind, name, parent, "BackdropTemplate")
    if ok and widget then return widget end
    return CreateFrame(kind, name, parent)
end
Chat.Backdropped = Backdropped

local ROUND_TEX = "Interface\\AddOns\\Cine\\Media\\round"
local ROUND_CUT = 10 / 32
local ROUND_PX = 6

local function MakeRound(parent)
    if parent._cineRound then return end
    local c = ROUND_CUT
    local s = ROUND_PX
    local function piece(x0, x1, y0, y1)
        local tex = parent:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(ROUND_TEX)
        tex:SetTexCoord(x0, x1, y0, y1)
        return tex
    end
    local tl = piece(0, c, 0, c)
    local tr = piece(1 - c, 1, 0, c)
    local bl = piece(0, c, 1 - c, 1)
    local br = piece(1 - c, 1, 1 - c, 1)
    local top = piece(c, 1 - c, 0, c)
    local bottom = piece(c, 1 - c, 1 - c, 1)
    local left = piece(0, c, c, 1 - c)
    local right = piece(1 - c, 1, c, 1 - c)
    local mid = piece(c, 1 - c, c, 1 - c)
    tl:SetPoint("TOPLEFT")
    tr:SetPoint("TOPRIGHT")
    bl:SetPoint("BOTTOMLEFT")
    br:SetPoint("BOTTOMRIGHT")
    tl:SetSize(s, s)
    tr:SetSize(s, s)
    bl:SetSize(s, s)
    br:SetSize(s, s)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    mid:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT")
    mid:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    parent._cineRound = { tl, tr, bl, br, top, bottom, left, right, mid }
end

local function TintRound(parent, r, g, b, a)
    MakeRound(parent)
    for i = 1, #parent._cineRound do
        parent._cineRound[i]:SetVertexColor(r, g, b, a)
    end
end
Chat.TintRound = TintRound

local function Flat(widget, alpha)
    if not widget then return end
    if widget.SetBackdrop then
        pcall(function()
            widget:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            widget:SetBackdropColor(0.05, 0.05, 0.05, alpha or 0.92)
            widget:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
        end)
        return
    end
    if widget.CreateTexture and not widget._cineFill then
        local fill = widget:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        fill:SetVertexColor(0.05, 0.05, 0.05, alpha or 0.92)
        widget._cineFill = fill
    end
end
Chat.Flat = Flat

local function HideEditChrome(edit)
    ns.HideTextures(edit)
    local name = ns.FrameName(edit)
    if name then
        for _, suffix in ipairs(Chat.EDIT_PARTS) do
            ns.ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(Chat.EDIT_PARTS) do
        ns.ForceTextureHidden(edit[key])
    end
    if edit._cineHeader then
        ns.HideTextures(edit._cineHeader)
    end
    if edit.SetBackdropColor then
        pcall(edit.SetBackdropColor, edit, 0, 0, 0, 0)
    end
    if edit.SetBackdropBorderColor then
        pcall(edit.SetBackdropBorderColor, edit, 0, 0, 0, 0)
    end
end

local function PadEdit(edit)
    if edit._cinePadded or not edit.SetTextInsets then return end
    if not edit._cineInsets and edit.GetTextInsets then
        local ok, left, right, top, bottom = pcall(edit.GetTextInsets, edit)
        if ok then
            edit._cineInsets = { left or 0, right or 0, top or 0, bottom or 0 }
        end
    end
    edit._cinePadded = true
    pcall(edit.SetTextInsets, edit, 4, 4, 0, 0)
end

local function UsableNumber(n)
    return type(n) == "number" and not ns.IsSecret(n)
end

-- One point only: a second corner on the edit box stretches the height.
local function PlacePlate(edit)
    local plate = edit._cinePlate
    if not plate then return end
    local header = edit._cineHeader
    local line = (header and header ~= edit and header.GetBottom) and header or edit
    local fontSize = 14
    if edit.GetFont then
        local _, size = edit:GetFont()
        if type(size) == "number" and size > 2 and size < 48 then
            fontSize = size
        end
    end
    local left = line.GetLeft and line:GetLeft()
    local right = edit.GetRight and edit:GetRight()
    local width
    if UsableNumber(left) and UsableNumber(right) and right > left then
        width = (right - left) + 12
    else
        local editW = edit.GetWidth and edit:GetWidth()
        width = (UsableNumber(editW) and editW or 200) + 48
    end
    -- The frame edge sits under the glyphs, so the plate is lifted by one line.
    -- A few extra pixels keep the letters off the top and bottom edges.
    local h = fontSize + 12
    plate:ClearAllPoints()
    plate:SetSize(width, h)
    plate:SetPoint("LEFT", line, "BOTTOMLEFT", -6, fontSize + 1)
end

local function EnsurePlate(edit)
    if edit._cinePlate then return edit._cinePlate end
    local parent = edit.GetParent and edit:GetParent()
    if not parent then return nil end
    local plate = Backdropped("Frame", nil, parent)
    plate:EnableMouse(false)
    TintRound(plate, 0.05, 0.05, 0.05, 0.72)
    plate:SetAlpha(0)
    ns.Remember(plate)
    ns.EnsureAlphaHook(plate)
    ns.NoteChat(plate)
    edit._cinePlate = plate
    return plate
end

local function ChatOf(edit)
    local name = ns.FrameName(edit)
    if name then
        local chatName = name:match("^(ChatFrame%d+)")
        local chat = chatName and _G[chatName]
        if chat then return chat end
    end
    return edit.GetParent and edit:GetParent()
end

-- Focused field sits above the bubbles. The plate stays just behind the field.
local function StackPlate(edit, focused)
    local plate = edit._cinePlate
    if not plate then return end
    local chat = ChatOf(edit)
    if not chat then return end
    local base = ((chat.GetFrameLevel and chat:GetFrameLevel()) or 0) + 2
    local editLevel = focused and (base + 5) or base
    pcall(plate.SetFrameLevel, plate, focused and (base + 4) or base)
    pcall(edit.SetFrameLevel, edit, editLevel)
    if edit._cineHeader and edit._cineHeader.SetFrameLevel then
        pcall(edit._cineHeader.SetFrameLevel, edit._cineHeader, editLevel)
    end
end

-- The unfocused field is invisible but shown; it lets clicks through to the tabs.
local function HoldEditMouse(edit, focused)
    if not edit.EnableMouse then return end
    if edit._cineMouse == nil and edit.IsMouseEnabled then
        edit._cineMouse = edit:IsMouseEnabled() and true or false
    end
    pcall(edit.EnableMouse, edit, focused and true or false)
end

local function ReleaseEditMouse(edit)
    if edit._cineMouse == nil then return end
    pcall(edit.EnableMouse, edit, edit._cineMouse)
    edit._cineMouse = nil
end

local function SyncEdit(edit)
    if not ns.DB().enabled or not ns.ModernChat() then
        ReleaseEditMouse(edit)
        edit._cineAlpha = nil
        if edit._cinePlate then
            edit._cinePlate._cineAlpha = nil
            edit._cinePlate:SetAlpha(0)
        end
        return
    end
    local focused = edit._cineFocus or (edit.HasFocus and edit:HasFocus())
    edit._cineWant = focused and 1 or 0
    HoldEditMouse(edit, focused)
    PadEdit(edit)
    HideEditChrome(edit)
    EnsurePlate(edit)
    PlacePlate(edit)
    StackPlate(edit, focused)
    if edit._cinePlate then
        edit._cinePlate._cineWant = edit._cineWant
    end
end

local function SetFocus(edit, focused)
    edit._cineFocus = focused
    SyncEdit(edit)
end

local function BindEdit(edit)
    if not edit or edit._cineEdit or not edit.HookScript then return end
    edit._cineEdit = true
    ns.Remember(edit)
    ns.EnsureAlphaHook(edit)
    ns.NoteChat(edit)
    edit:HookScript("OnEditFocusGained", function(self) SetFocus(self, true) end)
    edit:HookScript("OnEditFocusLost", function(self) SetFocus(self, false) end)
    edit:HookScript("OnShow", SyncEdit)
    local name = ns.FrameName(edit)
    local header = name and _G[name .. "Header"]
    if not header then
        header = edit.header or edit.Header
    end
    if header and header.SetAlpha and header.GetParent and header:GetParent() ~= edit then
        ns.Remember(header)
        ns.EnsureAlphaHook(header)
        ns.NoteChat(header)
        edit._cineHeader = header
    end
    SyncEdit(edit)
end
Chat.BindEdit = BindEdit

-- Focus events can be missed, so visible input boxes are checked every frame.
function ns.SyncVisibleEdits()
    if not ns.DB().enabled or not ns.ModernChat() then return end
    for i = 1, Chat.ChatCount() do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit and edit._cineEdit and edit:IsShown() then
            local focused = edit.HasFocus and edit:HasFocus() and true or false
            if focused then
                if not edit._cineFocus or edit._cineWant ~= 1 then
                    edit._cineFocus = true
                    SyncEdit(edit)
                end
                StackPlate(edit, true)
                PlacePlate(edit)
            elseif edit._cineFocus or edit._cineWant ~= 0 then
                SetFocus(edit, false)
            else
                StackPlate(edit, false)
            end
        end
    end
end

local function RestoreEdits()
    for i = 1, Chat.ChatCount() do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit then
            if edit._cineInsets and edit.SetTextInsets then
                pcall(edit.SetTextInsets, edit, edit._cineInsets[1], edit._cineInsets[2], edit._cineInsets[3], edit._cineInsets[4])
            end
            edit._cinePadded = nil
            edit._cineFocus = nil
            ReleaseEditMouse(edit)
            ns.ReleaseAlpha(edit)
            if edit._cineHeader then
                ns.ReleaseAlpha(edit._cineHeader)
            end
            if edit._cinePlate then
                edit._cinePlate._cineAlpha = nil
                edit._cinePlate._cineApplying = true
                edit._cinePlate:SetAlpha(0)
                edit._cinePlate._cineApplying = false
            end
        end
    end
end
Chat.RestoreEdits = RestoreEdits
