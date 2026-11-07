local _, ns = ...
local Setup = ns.Setup or {}
ns.Setup = Setup

local function Paint()
    if not Setup.frame then return end
    if Setup.frame.presetSelector then
        Setup.ButtonText(Setup.frame.presetSelector, Setup.presetName or "<no preset>")
        Setup.ButtonText(Setup.frame.layoutSelector, ns.LayoutLabel and ns.LayoutLabel(Setup.presetLayout)
            or (Setup.presetLayout and Setup.presetLayout.layoutName or "Choose layout"))
        if Setup.presetName then
            Setup.frame.forceLayout:Hide()
            Setup.frame.layoutSelector:Show()
            Setup.frame.renamePreset:Enable()
            if Setup.selectedPresetId then Setup.frame.deletePreset:Enable() else Setup.frame.deletePreset:Disable() end
        else
            Setup.frame.forceLayout:Show()
            Setup.frame.layoutSelector:Hide()
            Setup.frame.renamePreset:Disable()
            Setup.frame.deletePreset:Disable()
        end
    end
    for _, row in ipairs(Setup.frame.rows) do
        Setup.PaintBox(row.always.box, Setup.draft[row.key])
        Setup.PaintBox(row.hover.box, Setup.draft.hoverOnly[row.key])
    end
    if Setup.frame.forceLayout then
        Setup.PaintBox(Setup.frame.forceLayout.box, Setup.draft.forceLayout)
    end
    if Setup.frame.playerRow then
        Setup.PaintBox(Setup.frame.playerRow.box, Setup.draft.player)
    end
    if Setup.frame.playerThresholdKind then
        Setup.frame.playerThresholdKind.value:SetText(Setup.draft.playerThresholdKind == "health" and "Health" or "Resource")
        if Setup.draft.player then Setup.frame.playerThresholdKind:Show() else Setup.frame.playerThresholdKind:Hide() end
    end
    if Setup.frame.playerThresholdPercent then
        local row = Setup.frame.playerThresholdPercent
        if row.edit:GetText() ~= Setup.draft.playerThresholdPercent then row.edit:SetText(Setup.draft.playerThresholdPercent) end
        if Setup.draft.player then row:Show() else row.edit:ClearFocus(); row:Hide() end
    end
    if Setup.frame.requireLivingTarget then
        Setup.PaintBox(Setup.frame.requireLivingTarget.box, Setup.draft.requireLivingTarget)
    end
    if Setup.frame.groupAuras then
        Setup.PaintBox(Setup.frame.groupAuras.box, Setup.draft.groupAuras)
    end
    if Setup.frame.alwaysShowDebuffs then
        Setup.PaintBox(Setup.frame.alwaysShowDebuffs.box, Setup.draft.alwaysShowDebuffs)
    end
    if Setup.frame.showPlayerFrameInParty then
        Setup.PaintBox(Setup.frame.showPlayerFrameInParty.box, Setup.draft.showPlayerFrameInParty)
    end
    if Setup.frame.forceFramesInInstance then
        Setup.PaintBox(Setup.frame.forceFramesInInstance.box, Setup.draft.forceFramesInInstance)
    end
    if Setup.frame.chat then
        Setup.PaintBox(Setup.frame.chat.box, Setup.draft.chat)
    end
    if Setup.frame.fade then
        Setup.frame.fade.value:SetText(Setup.FadeText(Setup.draft.chatFade))
    end
    if Setup.frame.range then
        Setup.PaintBox(Setup.frame.range.box, Setup.draft.range)
    end
    if Setup.frame.rangeYards then
        Setup.frame.rangeYards.value:SetText(Setup.RangeYardsText(Setup.draft.rangeYards))
    end
    if Setup.frame.rangeKind then
        Setup.frame.rangeKind.value:SetText(Setup.RangeKindText(Setup.draft.rangeKind))
    end
    if Setup.frame.rangeSpell then
        if Setup.draft.rangeYards == "spell" then
            Setup.frame.rangeSpell:Show()
        else
            if Setup.frame.rangeSpell.edit and Setup.frame.rangeSpell.edit:HasFocus() then
                Setup.frame.rangeSpell.edit:ClearFocus()
            end
            Setup.frame.rangeSpell:Hide()
        end
        if Setup.frame.rangeSpell.edit and not Setup.frame.rangeSpell.edit:HasFocus() then
            local text = Setup.draft.rangeSpell or ""
            if Setup.frame.rangeSpell.edit:GetText() ~= text then
                Setup.frame.rangeSpell.edit:SetText(text)
            end
        end
    end
    if Setup.frame.groupRows then
        for _, row in ipairs(Setup.frame.groupRows) do
            row.value:SetText(tostring(Setup.draft.groups[row.id]))
            Setup.PaintBox(row.hostile.box, Setup.draft.hostile[row.id])
            Setup.PaintBox(row.friendly.box, Setup.draft.friendly[row.id])
            local mode = Setup.draft.groupVisibility[Setup.draft.groups[row.id]]
            for _, button in ipairs({ row.hostile, row.friendly }) do
                if mode then button:Disable() else button:Enable() end
                button:SetAlpha(mode and 0.4 or 1)
                button.mode = mode
                button.group = Setup.draft.groups[row.id]
            end
        end
    end
    if Setup.frame.visibilityRows then
        local members = {}
        for _, bar in ipairs(ns.BAR_ROWS) do
            local group = Setup.draft.groups[bar.id]
            members[group] = members[group] or {}
            members[group][#members[group] + 1] = bar.label
        end
        local count = 0
        for group, row in ipairs(Setup.frame.visibilityRows) do
            if members[group] then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", Setup.frame.groupContent, "TOPLEFT", 0, -count * 44)
                row.members:SetText(table.concat(members[group], ", "))
                Setup.PaintBox(row.always.box, Setup.draft.groupVisibility[group] == "always")
                Setup.PaintBox(row.hover.box, Setup.draft.groupVisibility[group] == "hover")
                row:Show()
                count = count + 1
            else row:Hide() end
        end
        Setup.frame.groupContent:SetHeight(math.max(1, count * 44))
        local max = math.max(0, count * 44 - Setup.GROUP_VIEW_H)
        Setup.frame.groupScroll:SetVerticalScroll(math.min(Setup.frame.groupScroll:GetVerticalScroll(), max))
    end
    if Setup.frame.tabs then
        for _, tab in ipairs(Setup.frame.tabs) do
            local on = tab.id == Setup.frame.page
            if tab._quietGold and tab.SetBackdropBorderColor then
                if on then
                    tab:SetBackdropBorderColor(1, 0.86, 0.4, 1)
                else
                    tab:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.85)
                end
            elseif tab.SetBackdropBorderColor then
                if on then
                    tab:SetBackdropBorderColor(0.95, 0.75, 0.25, 0.9)
                else
                    tab:SetBackdropBorderColor(0.85, 0.85, 0.85, 0.35)
                end
            end
            if tab.label and tab.label.SetTextColor then
                if on then
                    tab.label:SetTextColor(1, 0.86, 0.35)
                elseif tab._quietGold then
                    tab.label:SetTextColor(0.85, 0.8, 0.65)
                else
                    tab.label:SetTextColor(0.85, 0.85, 0.85)
                end
            end
        end
    end
end
Setup.Paint = Paint
