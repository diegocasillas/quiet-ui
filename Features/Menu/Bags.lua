local _, ns = ...
local Menu = ns.Menu or {}
ns.Menu = Menu

-- The micro menu and the native bag bar (backpack and bag slots) fade together:
-- hover, edit mode, and Glance show them, and the Visible row holds them. An
-- item on the cursor shows the bag bar too.

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
    "LegacyMicroButton",
}
Menu.MICRO_NAMES = MICRO_NAMES

local MENU_FRAMES = {
    "MicroMenu",
    "MicroMenuContainer",
    "MicroButtonAndBagsBar",
    "BagsBar",
}
Menu.MENU_FRAMES = MENU_FRAMES

Menu.refreshing = false

------------------------------------------------------------------------------
-- Bag bar
------------------------------------------------------------------------------
function ns.BagsShouldShow()
    if not ns.DB().enabled then return false end
    return ns.CursorHasItem()
end
