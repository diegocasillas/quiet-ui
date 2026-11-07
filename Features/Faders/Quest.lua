local _, ns = ...
local Faders = ns.Faders or {}
ns.Faders = Faders

-- The tracker container is not mouse-enabled, so the gaps between quests are
-- not hover. This frame is not its child: a faded parent would drop the mouse.
-- questCatcher: state lives in Faders
local questCatcherTarget

local function ShownQuest()
    for i = 1, #Faders.questFrames do
        local frame = Faders.questFrames[i]
        if ns.Usable(frame) and frame:IsShown() then
            return frame
        end
    end
end

local function EnsureQuestCatcher()
    if Faders.questCatcher then return Faders.questCatcher end
    local ok, created = pcall(CreateFrame, "Frame", nil, UIParent)
    if not ok or not created then return end
    ns.ArmCatcher(created)
    created:Hide()
    Faders.questCatcher = created
    return created
end

local function PlaceQuestCatcher()
    local box = EnsureQuestCatcher()
    if not box then return end
    local target = ShownQuest()
    if not target or ns.InEditMode() or not ns.DB().enabled then
        box:Hide()
        questCatcherTarget = nil
        return
    end
    if questCatcherTarget ~= target then
        box:SetParent(UIParent)
        box:ClearAllPoints()
        box:SetAllPoints(target)
        questCatcherTarget = target
        -- SetParent can move strata and level, so write them again.
        box._quietStrata, box._quietLevel = nil, nil
    end
    local strata = target.GetFrameStrata and target:GetFrameStrata()
    if type(strata) == "string" and not ns.IsSecret(strata) and box._quietStrata ~= strata then
        box:SetFrameStrata(strata)
        box._quietStrata = strata
    end
    local level = target.GetFrameLevel and target:GetFrameLevel() or 1
    if type(level) ~= "number" or ns.IsSecret(level) then level = 1 end
    level = math.max(level - 1, 0)
    if box._quietLevel ~= level then
        box:SetFrameLevel(level)
        box._quietLevel = level
    end
    if not box:IsShown() then box:Show() end
end
Faders.PlaceQuestCatcher = PlaceQuestCatcher

function ns.HideQuestCatcher()
    if not Faders.questCatcher then return end
    Faders.questCatcher:Hide()
    questCatcherTarget = nil
end
