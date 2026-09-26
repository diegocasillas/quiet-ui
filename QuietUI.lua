local ADDON = ...

-- QuietUI for the WoW Forever beta.
-- Bars fade until hover, combat, or an instance. Bags and the micro menu
-- collapse to one button. Chat keeps its text and drops the window chrome.
-- No secure snippets and no ChatFrame_OpenChat: Enter stays a Blizzard binding.

local FADE_OUT = 0.3

local BAR_NAMES = {
    "MainMenuBar",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "StanceBar",
    "StanceBarFrame",
    "ShapeshiftBarFrame",
    "PetActionBar",
    "PetActionBarFrame",
}

local BUTTON_PREFIX = {
    MainMenuBar = "ActionButton",
    MultiBarBottomLeft = "MultiBarBottomLeftButton",
    MultiBarBottomRight = "MultiBarBottomRightButton",
    MultiBarRight = "MultiBarRightButton",
    MultiBarLeft = "MultiBarLeftButton",
    MultiBar5 = "MultiBar5Button",
    MultiBar6 = "MultiBar6Button",
    MultiBar7 = "MultiBar7Button",
    StanceBar = "StanceButton",
    StanceBarFrame = "StanceButton",
    ShapeshiftBarFrame = "ShapeshiftButton",
    PetActionBar = "PetActionButton",
    PetActionBarFrame = "PetActionButton",
}

-- Orphan classic art. Children of a bar already follow that bar's alpha.
local BAR_ART = {
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarPageNumber",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarArtFrame",
}

local MICRO_NAMES = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "PlayerSpellsMicroButton",
    "ProfessionMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "LFGMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "WorldMapMicroButton",
    "PVPMicroButton",
    "HousingMicroButton",
}

local BAG_NAMES = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    "BagBarExpandToggle",
    "KeyRingButton",
}

local MENU_FRAMES = {
    "MicroMenu",
    "MicroMenuContainer",
    "MicroButtonAndBagsBar",
    "BagsBar",
}

local CHAT_CHROME = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceSelfMuteButton",
    "ChatFrameToggleVoiceSelfDeafButton",
    "TextToSpeechButton",
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

local BAR_SET = {}
for _, name in ipairs(BAR_NAMES) do
    BAR_SET[name] = true
end

local SPARE_SET = {
    OverrideActionBar = true,
    ExtraActionBarFrame = true,
    ExtraAbilityContainer = true,
    ZoneAbilityFrame = true,
    PossessActionBar = true,
    PossessBarFrame = true,
    PlayerFrame = true,
    TargetFrame = true,
    Minimap = true,
    MinimapCluster = true,
    QuietUIMenuButton = true,
}

local hooked = {}
local hookedGlobal = {}
local savedFrame = {}
local textureAlpha = {}
local hidden = {}
local button
local booted = false
local refreshing = false
local stripping = false

local reported = {}
local function Report(name, err)
    if reported[name] then return end
    reported[name] = true
    print("|cff8fd4c8QuietUI|r: " .. name .. " chyba (jen jednou): " .. tostring(err))
end

local function DB()
    if type(QuietUIDB) ~= "table" then
        QuietUIDB = {}
    end
    if QuietUIDB.enabled == nil then
        QuietUIDB.enabled = true
    end
    return QuietUIDB
end

local function Print(msg)
    print("|cff8fd4c8QuietUI|r: " .. tostring(msg))
end

local function FrameName(frame)
    if frame and frame.GetName then
        return frame:GetName()
    end
end

local function IsBarFrame(frame)
    local name = FrameName(frame)
    return name and BAR_SET[name] or false
end

local function IsQueue(frame)
    local name = FrameName(frame)
    if not name then return false end
    return name:find("QueueStatus") ~= nil or name:find("LFGEye") ~= nil
end

local function IsSpared(frame)
    if not frame or frame == button then return true end
    if IsQueue(frame) or IsBarFrame(frame) then return true end
    local name = FrameName(frame)
    if not name then return false end
    if SPARE_SET[name] then return true end
    if name:find("Vehicle") or name:find("ExtraAction") or name:find("ZoneAbility") then
        return true
    end
    return false
end

local function TreeHas(frame, test, depth)
    if not frame or depth > 4 then return false end
    if test(frame) then return true end
    if not frame.GetChildren then return false end
    for _, child in ipairs({ frame:GetChildren() }) do
        if TreeHas(child, test, depth + 1) then
            return true
        end
    end
    return false
end

local function Remember(frame)
    if not frame or savedFrame[frame] then return end
    local mouse = true
    if frame.IsMouseEnabled then
        mouse = not not frame:IsMouseEnabled()
    end
    savedFrame[frame] = {
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        mouse = mouse,
    }
end

local function EnsureAlphaHook(frame)
    if not frame or frame._quietAlphaHook or not frame.SetAlpha then return end
    frame._quietAlphaHook = true
    hooked[#hooked + 1] = frame
    pcall(hooksecurefunc, frame, "SetAlpha", function(self, alpha)
        if self._quietApplying then return end
        if not DB().enabled then return end
        local want = self._quietAlpha
        if type(want) ~= "number" then return end
        if math.abs((alpha or 0) - want) < 0.02 then return end
        self._quietApplying = true
        self:SetAlpha(want)
        self._quietApplying = false
    end)
end

local function PushAlpha(frame, alpha)
    if not frame or not frame.SetAlpha then return end
    frame._quietAlpha = alpha
    if frame.GetAlpha and math.abs((frame:GetAlpha() or 0) - alpha) < 0.01 then
        return
    end
    frame._quietApplying = true
    frame:SetAlpha(alpha)
    frame._quietApplying = false
end

local function ReleaseAlpha(frame)
    if not frame or not frame.SetAlpha then return end
    local info = savedFrame[frame]
    frame._quietAlpha = nil
    frame._quietApplying = true
    frame:SetAlpha(info and info.alpha or 1)
    frame._quietApplying = false
    if info and info.mouse and frame.EnableMouse then
        frame:EnableMouse(true)
    end
end

local function SilenceMouse(frame, depth)
    if InCombatLockdown() then return end
    if not frame or depth > 2 or IsSpared(frame) then return end
    if frame.EnableMouse then
        Remember(frame)
        frame:EnableMouse(false)
    end
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        SilenceMouse(child, depth + 1)
    end
end

local function Mute(frame)
    if not frame or IsSpared(frame) then return end
    Remember(frame)
    EnsureAlphaHook(frame)
    SilenceMouse(frame, 0)
    PushAlpha(frame, 0)
end

local function ForceTextureHidden(tex)
    if not tex or not tex.SetAlpha or not tex.GetAlpha then return end
    if tex.GetObjectType and tex:GetObjectType() ~= "Texture" then return end
    if textureAlpha[tex] == nil then
        textureAlpha[tex] = tex:GetAlpha()
    end
    if not tex._quietTexHook then
        tex._quietTexHook = true
        pcall(hooksecurefunc, tex, "SetAlpha", function(self, alpha)
            if self._quietApplying or not DB().enabled then return end
            if (alpha or 0) < 0.01 then return end
            self._quietApplying = true
            self:SetAlpha(0)
            self._quietApplying = false
        end)
    end
    if not DB().enabled then return end
    if tex:GetAlpha() >= 0.01 then
        tex._quietApplying = true
        tex:SetAlpha(0)
        tex._quietApplying = false
    end
end

local function HideTextures(frame)
    if not frame or not frame.GetNumRegions then return end
    local count = frame:GetNumRegions()
    for i = 1, count do
        ForceTextureHidden(select(i, frame:GetRegions()))
    end
end

local function Suppress(frame)
    if not frame or not frame.Hide or not frame.Show then return end
    if IsSpared(frame) or IsBarFrame(frame) then return end
    if hidden[frame] == nil then
        hidden[frame] = frame:IsShown() and true or false
        if not frame._quietHideHook then
            frame._quietHideHook = true
            hooksecurefunc(frame, "Show", function(self)
                if self._quietHiding then return end
                if DB().enabled and hidden[self] ~= nil and not InCombatLockdown() then
                    self._quietHiding = true
                    self:Hide()
                    self._quietHiding = false
                end
            end)
        end
    end
    if DB().enabled and not InCombatLockdown() then
        frame:Hide()
    end
end

------------------------------------------------------------------------------
-- Action bars. Alpha only: Hide() and state drivers are off limits here.
------------------------------------------------------------------------------
local function MouseOver(frame)
    if not frame or not frame.IsShown or not frame.IsMouseOver then return false end
    if not frame:IsShown() then return false end
    return frame:IsMouseOver() and true or false
end

local function BarHovered(bar)
    if MouseOver(bar) then return true end
    local buttons = bar.actionButtons or bar.buttons
    if type(buttons) == "table" then
        for _, child in ipairs(buttons) do
            if MouseOver(child) then return true end
        end
    end
    local prefix = BUTTON_PREFIX[FrameName(bar) or ""]
    if prefix then
        for i = 1, 12 do
            if MouseOver(_G[prefix .. i]) then return true end
        end
    end
    return false
end

local function InEditMode()
    local frame = EditModeManagerFrame
    return frame and frame.IsShown and frame:IsShown() and true or false
end

local function InForcedInstance()
    if type(IsInInstance) ~= "function" then return false end
    local forced = false
    local ok = pcall(function()
        local inInstance, kind = IsInInstance()
        forced = inInstance == true and (
            kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena"
        )
    end)
    return ok and forced or false
end

local function InVehicle()
    if type(UnitHasVehicleUI) ~= "function" then return false end
    local yes = false
    pcall(function()
        yes = UnitHasVehicleUI("player") and true or false
    end)
    return yes
end

local function CursorBusy()
    if type(GetCursorInfo) ~= "function" then return false end
    local busy = false
    pcall(function()
        busy = GetCursorInfo() ~= nil
    end)
    return busy
end

local function ShowAll()
    if InCombatLockdown() then return true end
    if InEditMode() then return true end
    if InVehicle() then return true end
    if InForcedInstance() then return true end
    if SpellFlyout and SpellFlyout.IsShown and SpellFlyout:IsShown() then return true end
    if CursorBusy() then return true end
    return false
end

local function UpdateOneBar(bar, showAll, elapsed)
    if not bar:IsShown() then return end
    Remember(bar)
    EnsureAlphaHook(bar)
    local target = (showAll or BarHovered(bar)) and 1 or 0
    local current = bar._quietAlpha
    if type(current) ~= "number" then
        current = bar:GetAlpha() or 1
    end
    local nextAlpha
    if target > current then
        nextAlpha = target
    else
        local step = (elapsed or 0) / FADE_OUT
        if current - target <= step then
            nextAlpha = target
        else
            nextAlpha = current - step
        end
    end
    PushAlpha(bar, nextAlpha)
end

local function FollowArt(alpha)
    for _, name in ipairs(BAR_ART) do
        local art = _G[name]
        if art and art.SetAlpha then
            local parent = art.GetParent and art:GetParent()
            if not (parent and IsBarFrame(parent)) then
                Remember(art)
                EnsureAlphaHook(art)
                PushAlpha(art, alpha)
            end
        end
    end
end

local function UpdateBars(elapsed)
    if not DB().enabled then return end
    local showAll = ShowAll()
    local mainAlpha
    for _, name in ipairs(BAR_NAMES) do
        local bar = _G[name]
        if bar then
            local ok, err = pcall(UpdateOneBar, bar, showAll, elapsed)
            if not ok then
                Report("lista " .. name, err)
            elseif name == "MainMenuBar" then
                mainAlpha = bar._quietAlpha
            end
        end
    end
    if type(mainAlpha) == "number" then
        FollowArt(mainAlpha)
    end
end

------------------------------------------------------------------------------
-- One button for bags (left) and the game menu (right).
------------------------------------------------------------------------------
local function PlaceButton(force)
    if not button then return end
    local db = DB()
    if not force and button._quietPlaced == db then return end
    button._quietPlaced = db
    button:ClearAllPoints()
    if type(db.point) == "string" and type(db.relPoint) == "string"
        and type(db.x) == "number" and type(db.y) == "number" then
        button:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
    else
        button:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
    end
end

local function SavePoint(self)
    local point, _, relPoint, x, y = self:GetPoint(1)
    if not point or type(x) ~= "number" or type(y) ~= "number" then return end
    local db = DB()
    db.point, db.relPoint, db.x, db.y = point, relPoint, x, y
    self._quietPlaced = db
end

local function EnsureButton()
    if button then
        PlaceButton(false)
        return button
    end
    local ok, created = pcall(CreateFrame, "Button", "QuietUIMenuButton", UIParent, "BackdropTemplate")
    if not ok or not created then
        created = CreateFrame("Button", "QuietUIMenuButton", UIParent)
    end
    button = created
    button:SetSize(28, 28)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(40)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    if button.SetBackdrop then
        pcall(function()
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            button:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
            button:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
        end)
    end
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 4, -4)
    icon:SetPoint("BOTTOMRIGHT", -4, 4)
    local usedAtlas = false
    if icon.SetAtlas then
        local atlasOk, atlasResult = pcall(icon.SetAtlas, icon, "bag-main")
        usedAtlas = atlasOk and atlasResult and true or false
    end
    if not usedAtlas then
        icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    if highlight.SetColorTexture then
        highlight:SetColorTexture(1, 1, 1, 0.18)
    end
    button:SetScript("OnDragStart", function(self)
        self._moved = true
        self:StartMoving()
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePoint(self)
    end)
    button:SetScript("OnMouseUp", function(self, click)
        if self._moved then
            self._moved = false
            return
        end
        if click == "RightButton" then
            if type(ToggleGameMenu) == "function" then
                ToggleGameMenu()
            end
        elseif type(ToggleAllBags) == "function" then
            ToggleAllBags()
        elseif type(ToggleBackpack) == "function" then
            ToggleBackpack()
        end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("QuietUI", 1, 1, 1)
        GameTooltip:AddLine("Levý klik: batohy", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Pravý klik: menu", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Táhni: přesunout", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    PlaceButton(true)
    return button
end

local function ConsiderMicro(name, seen, fn)
    if not name or seen[name] or name:find("Queue") then return end
    seen[name] = true
    local frame = _G[name]
    if frame then fn(frame) end
end

local function RefreshChrome()
    if refreshing or not DB().enabled then return end
    refreshing = true
    local ok, err = pcall(function()
    local seen = {}
    for _, name in ipairs(MICRO_NAMES) do
        ConsiderMicro(name, seen, Mute)
    end
    if type(MICRO_BUTTONS) == "table" then
        for _, name in ipairs(MICRO_BUTTONS) do
            ConsiderMicro(name, seen, Mute)
        end
    end
    for _, name in ipairs(BAG_NAMES) do
        Mute(_G[name])
    end
    for _, name in ipairs(MENU_FRAMES) do
        local frame = _G[name]
        if frame and not IsBarFrame(frame) then
            if TreeHas(frame, IsQueue, 0) or TreeHas(frame, IsBarFrame, 0) then
                HideTextures(frame)
                if frame.GetChildren then
                    for _, child in ipairs({ frame:GetChildren() }) do
                        if not IsSpared(child) then
                            Mute(child)
                        end
                    end
                end
            else
                Mute(frame)
                if frame.GetChildren then
                    for _, child in ipairs({ frame:GetChildren() }) do
                        Mute(child)
                    end
                end
            end
        end
    end
    local menu = EnsureButton()
    if menu then menu:Show() end
    end)
    refreshing = false
    if not ok then Report("menu", err) end
end

------------------------------------------------------------------------------
-- Chat: text stays, chrome goes, the input shows only while it has focus.
------------------------------------------------------------------------------
local function StripTab(tab)
    if not tab or not DB().enabled then return end
    HideTextures(tab)
    local name = FrameName(tab)
    if name then
        for _, suffix in ipairs(TAB_SUFFIX) do
            ForceTextureHidden(_G[name .. suffix])
        end
    end
    for _, key in ipairs(TAB_KEYS) do
        ForceTextureHidden(tab[key])
    end
    if not tab._quietClick and tab.HookScript then
        tab._quietClick = true
        tab:HookScript("OnClick", function()
            if DB().enabled then StripTab(tab) end
        end)
    end
end

local function SyncEdit(edit)
    if not edit then return end
    if not DB().enabled then
        edit._quietAlpha = nil
        return
    end
    local focused = edit._quietFocus or (edit.HasFocus and edit:HasFocus())
    PushAlpha(edit, focused and 1 or 0)
    local header = edit._quietHeader
    if header then
        PushAlpha(header, focused and 1 or 0)
    end
end

local function BindEdit(edit)
    if not edit or edit._quietEdit or not edit.HookScript then return end
    edit._quietEdit = true
    Remember(edit)
    EnsureAlphaHook(edit)
    edit:HookScript("OnEditFocusGained", function(self)
        self._quietFocus = true
        SyncEdit(self)
    end)
    edit:HookScript("OnEditFocusLost", function(self)
        self._quietFocus = false
        SyncEdit(self)
    end)
    edit:HookScript("OnShow", function(self)
        SyncEdit(self)
    end)
    local name = FrameName(edit)
    if name then
        local header = _G[name .. "Header"]
        if header and header.SetAlpha and header.GetParent and header:GetParent() ~= edit then
            Remember(header)
            EnsureAlphaHook(header)
            edit._quietHeader = header
        end
    end
    SyncEdit(edit)
end

local function StripChat(frame)
    if not frame or not DB().enabled then return end
    HideTextures(frame)
    local name = FrameName(frame)
    local background = frame.Background or (name and _G[name .. "Background"])
    if background then
        if background.GetObjectType and background:GetObjectType() == "Texture" then
            ForceTextureHidden(background)
        else
            HideTextures(background)
        end
    end
    if frame.NineSlice then
        HideTextures(frame.NineSlice)
    end
    Suppress(frame.ScrollBar)
    Suppress(frame.ScrollToBottomButton)
    Suppress(frame.buttonFrame)
    Suppress(frame.TextToSpeechButton)
    if name then
        Suppress(_G[name .. "ButtonFrame"])
        Suppress(_G[name .. "ButtonFrameUpButton"])
        Suppress(_G[name .. "ButtonFrameDownButton"])
        Suppress(_G[name .. "ButtonFrameBottomButton"])
        Suppress(_G[name .. "ButtonFrameMinimizeButton"])
        Suppress(_G[name .. "MinimizeButton"])
        StripTab(_G[name .. "Tab"])
        BindEdit(_G[name .. "EditBox"])
    end
end

local function SyncVisibleEdits()
    if not DB().enabled then return end
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        local edit = _G["ChatFrame" .. i .. "EditBox"]
        if edit and edit._quietEdit and edit.IsShown and edit:IsShown() then
            local focused = edit.HasFocus and edit:HasFocus() and true or false
            local alpha = edit.GetAlpha and edit:GetAlpha() or 0
            if focused then
                edit._quietFocus = true
                if alpha < 0.99 then SyncEdit(edit) end
            elseif edit._quietFocus or alpha > 0.01 then
                edit._quietFocus = false
                SyncEdit(edit)
            end
        end
    end
end

local function StripAllChat()
    if stripping or not DB().enabled then return end
    stripping = true
    local ok, err = pcall(function()
    local count = NUM_CHAT_WINDOWS or 10
    for i = 1, count do
        StripChat(_G["ChatFrame" .. i])
    end
    for _, name in ipairs(CHAT_CHROME) do
        Suppress(_G[name])
    end
    if GeneralDockManager then
        HideTextures(GeneralDockManager)
        local dockBg = GeneralDockManager.Background or _G["GeneralDockManagerBackground"]
        if dockBg then
            if dockBg.GetObjectType and dockBg:GetObjectType() == "Texture" then
                ForceTextureHidden(dockBg)
            else
                HideTextures(dockBg)
            end
        end
    end
    end)
    stripping = false
    if not ok then Report("chat", err) end
end

local function RestoreTextures()
    for tex, alpha in pairs(textureAlpha) do
        if tex and tex.SetAlpha then
            tex._quietApplying = true
            tex:SetAlpha(alpha or 1)
            tex._quietApplying = false
        end
    end
end

local function RestoreSuppressed()
    for frame, wasShown in pairs(hidden) do
        if wasShown and frame and frame.Show then
            frame:Show()
        end
    end
end

local function RestoreAll()
    for _, frame in ipairs(hooked) do
        ReleaseAlpha(frame)
    end
    RestoreTextures()
    RestoreSuppressed()
    if button then button:Hide() end
end

local function ApplyAll()
    if not DB().enabled then
        RestoreAll()
        return
    end
    RefreshChrome()
    StripAllChat()
    UpdateBars(0)
end

local function Boot()
    local first = not booted
    booted = true
    ApplyAll()
    if first and C_Timer and C_Timer.After then
        C_Timer.After(0.5, ApplyAll)
        C_Timer.After(2, ApplyAll)
    end
end

local function HookGlobal(name, fn)
    if hookedGlobal[name] or type(_G[name]) ~= "function" then return end
    local ok = pcall(hooksecurefunc, name, function(...)
        if not DB().enabled then return end
        local ran, err = pcall(fn, ...)
        if not ran then Report(name, err) end
    end)
    if ok then
        hookedGlobal[name] = true
    end
end

------------------------------------------------------------------------------
-- Events. Unknown names throw on this client, so each one is registered alone.
------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local chromeAcc = 0

events:SetScript("OnEvent", function(_, event, arg1)
    local ok, err = pcall(function()
        if event == "ADDON_LOADED" then
            if arg1 == ADDON then
                DB()
            elseif booted and DB().enabled then
                ApplyAll()
            end
            return
        end
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            DB()
            Boot()
            return
        end
        if not booted or not DB().enabled then return end
        if event == "PLAYER_REGEN_DISABLED" then
            UpdateBars(0)
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            UpdateBars(0)
            RefreshChrome()
            return
        end
        if event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS" then
            StripAllChat()
        end
    end)
    if not ok then Report(event or "event", err) end
end)

events:SetScript("OnUpdate", function(_, elapsed)
    if not booted or not DB().enabled then return end
    local ok, err = pcall(UpdateBars, elapsed)
    if not ok then Report("listy", err) end
    ok, err = pcall(SyncVisibleEdits)
    if not ok then Report("input", err) end
    chromeAcc = chromeAcc + (elapsed or 0)
    if chromeAcc < 1 then return end
    chromeAcc = 0
    ok, err = pcall(RefreshChrome)
    if not ok then Report("menu", err) end
    ok, err = pcall(StripAllChat)
    if not ok then Report("chat", err) end
end)

for _, eventName in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "UPDATE_CHAT_WINDOWS",
    "UPDATE_FLOATING_CHAT_WINDOWS",
}) do
    pcall(events.RegisterEvent, events, eventName)
end

HookGlobal("UpdateMicroButtons", RefreshChrome)
HookGlobal("FCF_SetWindowAlpha", StripAllChat)
HookGlobal("FCF_SetWindowColor", StripAllChat)
HookGlobal("FCF_DockUpdate", StripAllChat)

SLASH_QUIETUI1 = "/quiet"
SLASH_QUIETUI2 = "/quietui"
SlashCmdList["QUIETUI"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    local db = DB()
    local enable
    if msg == "on" or msg == "zap" then
        enable = true
    elseif msg == "off" or msg == "vyp" then
        enable = false
    else
        enable = not db.enabled
    end
    db.enabled = enable
    if not booted then
        Print(enable and "zapnuto" or "vypnuto")
        return
    end
    if enable then
        ApplyAll()
        Print("zapnuto")
    else
        RestoreAll()
        Print("vypnuto")
    end
end
