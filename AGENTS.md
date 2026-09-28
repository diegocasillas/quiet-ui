# QuietUI

Opinionated UI for WoW Forever. Modern and quiet: few frames, few buttons, text stays. The addon turns on or off, and one window chooses what stays visible.

## Product

- The goal is a clean UI, not a configurable framework.
- `/quiet` turns it on or off (`on` / `off`, no argument toggles). `/quiet setup` is the one window, with five tabs: General, Visible, Bars, Player, and Chat. General holds Force QuietUI layout (missing means off). Check what stays visible, set which bars fade together, choose which bars stay up for an enemy or a friendly target, turn the player frame on or off, group buffs and debuffs with that frame (missing means off), choose modern chat and how soon its lines fade, then Save, which leaves the window open. Reset default restores the rules below, turns force off, and saves immediately. Import layout writes the bundled Edit Mode layout right away, even after "Not now". The X and Escape close the window without saving. The window stays the size of the tallest tab, so switching tabs does not resize it. A minimap button opens that window. Left click opens it even while QuietUI is off. Drag moves it around the minimap.
- `QuietUIDB` is the account and may hold only `enabled`, the button position after dragging, `layoutHash` (the last answered layout version), and `minimap` (degrees around the minimap for the setup button; a missing value sits at the bottom-left). The setup is per character in `QuietUICharDB`: `visible` (which rows stay on screen; a missing flag means off), `forceLayout` (`true` selects the QuietUI layout when the addon turns on and restores the previous one when it turns off; missing means off), `player` (`resource` keeps the portrait for edit mode; missing means on, beside the personal resource bar), `groupAuras` (`true` shows buffs and debuffs while the player frame is visible; missing means off), `chat` (`false` turns modern chat off; missing means on), `chatFade` (seconds a modern-chat line stays at the bottom; missing means 10, `0` keeps it), `groups` (fade group per bar; a missing key keeps the default below), `hostile` and `friendly` (bar ids that stay up while the target is alive and can be attacked, or is friendly; a missing key means off), and `previousLayout` (the Edit Mode layout index that was active before QuietUI, kept even while force is off). No sliders and no libraries like Ace3.
- Player-facing text (chat, tooltip) is English.

## Look

- Flat, dark, thin border. Background `0.05, 0.05, 0.05, 0.75`, border `0.85, 0.85, 0.85, 0.35`, highlight `0.95, 0.75, 0.25`.
- The setup window uses the game character frame: gold border, player portrait, and the game's checkboxes and buttons. When that frame template is missing, it uses the gold dialog, then the flat border.
- Message prefix: `|cff8fd4c8QuietUI|r`.
- A short friendly greeting on login and reload: the state, then one short line each for `/quiet` and `/quiet setup` so commands never wrap. No other chat messages unless the player acts or something fails.
- A checked row under Always visible stays visible and skips the fade below. Unchecked rows keep it. The player frame check turns the portrait and pet on beside the resource bar, and they still fade.
- Action bars fade in groups. Hover shows the whole group from the bar rectangle, including empty slots. A filled button stays above that rectangle, so its tooltip and click still land on the spell. The default is bars 1–3 with the stance bar, the pet bar and the totem bar, bars 4–5, and each later bar on its own. The swing timer is group 10. The same number in `/quiet setup` fades together. Combat, a vehicle, edit mode, an instance (party, raid, pvp, arena), an open spell flyout, or an item on the cursor shows every group. The Action bars check shows every action bar group and leaves the swing timer down. The Swing timer check keeps that bar up on its own. Enemy and Friend on a bar row keep that bar up while the target is alive and can be attacked (`UnitCanAttack`, and not `UnitIsDeadOrGhost`) or is friendly (`UnitIsFriend`), including out of combat. They do not show the rest of the fade group. A missing flag means off. The XP bar fades out unless hovered or in edit mode. It also shows for 5 s after a quest turn-in that gives XP, while a spell flyout is open, or while an item is on the cursor. Combat, a vehicle and an instance do not show it.
- The cooldown manager shows only in combat, in an instance, in a group, or in edit mode. Hover does not show it.
- The damage meter behaves the same and stays for 10 s after combat.
- The personal resource bar shows only in combat, in an instance, or in edit mode, and anywhere while mana, focus, or energy is below 70 %. Its health bar also shows anywhere while health is not full. Hover does not show it.
- The player frame (`PlayerFrame`) is on unless setup sets `player` to `resource`. Off, it shows only in edit mode. On, it shows with a target, in combat, in an instance (party, raid, pvp, arena), in a group, in a vehicle, on hover, and while Glance is on. It also shows while mana, focus, or energy is below 70%. Rage and the other powers that rest at zero do not. A pet being out does not keep it up. `PetFrame` uses the same alpha. The personal resource bar keeps its own rules.
- The quest tracker (`ObjectiveTrackerFrame` / `QuestWatchFrame`) shows only on hover or in edit mode. Hover is the whole rectangle, including the gaps between quests. An invisible catcher on `UIParent` follows that rectangle. It is not a child of the tracker, so a faded tracker does not drop the mouse, and it does not take clicks.
- Buffs and debuffs (`BuffFrame`, `DebuffFrame`, `TemporaryEnchantFrame`) show only in combat, in an instance, in a group, on hover, or in edit mode. With `groupAuras` on they also show while the player frame is visible, including while mana, focus, or energy is below 70% and the player frame is on. With the player frame off, grouping does not pull them up.
- The micro menu and bags collapse into one button. The button shows only on hover, while bag slots are shown, while an item is on the cursor, or while dragged. Left click opens bags, right click shows the bag slots for swapping, drag moves it.
- Press `` ` `` (Glance) to show the faded HUD at once: every action bar, the XP bar, the cooldown manager, the damage meter, the personal resource bar (health and power), the quest tracker, buffs and debuffs, and the bag button. The portrait and pet show only when the player frame is on. Press again and the rules above apply, including a checked row. The state is not saved, and turning QuietUI off clears it. Chat is unchanged and the addon does not toggle. The binding is `QUIETUI_GLANCE`, category `QUIETUI` (shown as QuietUI). Do not set `header` on it: the client turns that into a bindable row named `HEADER_QUIETUI` under Other. `SetBinding` applies `` ` `` when that key is free or still on `HEADER_QUIETUI`, and leaves any other action alone. The key can be changed in Key Bindings. Only the key-down arrives as a toggle; key-up is ignored.
- The addon ships an Edit Mode layout named `QuietUI`. `LayoutString.lua` is the source of truth. Each new version of the string is offered once in the addon's own flat prompt (not `StaticPopup`, which spreads taint). The answer (add, update, or not now) is remembered as a hash in `QuietUIDB.layoutHash`; saved layouts are never compared, because the client rewrites them. An updated layout is replaced in place only after the player agrees. With Force QuietUI layout on, turning QuietUI on selects the QuietUI layout and creates it from that string when it is missing. The layout that was active before is stored per character as `previousLayout` and selected again when QuietUI is turned off. With force off, enable, disable, login, and reload leave the active layout alone. Use `C_EditMode` only, never `EditModeManagerFrame` methods (taint).
- Chat keeps its text and drops the chrome while Modern chat is on (the default). Each line is a translucent black bubble; a new line slides in from the left and older lines ease upward. At the bottom, a line fades across its last half second and drops after the fade interval (10 s unless setup says otherwise; 0 keeps it). The lines stay in the list, so scrolling still walks the full history. Hover a line to copy it. A numbered channel shows only its number, and guild, party, raid and the other group tags use a short letter. Joining, leaving, or changing a channel is not shown. Money and experience lines are not shown. Loot stays. The input is a flat field, visible only while focused. Enter stays a Blizzard binding. Turning Modern chat off leaves the original chat untouched.

## Client

- WoW Forever beta, `Interface: 16001`. The API mixes classic and newer frames; a global may not exist.
- The main bar is `MainActionBar`, not `MainMenuBar`. In gamepad mode the bars live under `GamepadMainActionBarFrame` (load-on-demand `Blizzard_GamepadActionBars`). The damage meter is a Blizzard load-on-demand addon; its frames are found by the `DamageMeter` prefix. The cooldown manager is `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`. The personal resource bar is `PersonalResourceDisplayFrame`; do not fade nameplates, they are recycled across units.
- Unit health and power are secret values, even out of combat. Never compare them or do math on them; pass them to widgets (for example `UnitPowerPercent` with a `C_CurveUtil` curve into `SetAlpha`). Check with `ns.IsSecret`.
- Scans of `UIParent` children can hit forbidden frames. Check `ns.Usable` before calling any method.
- Wrap calls that may be missing on this client in `pcall`, or check `type` first.
- An unknown event in `RegisterEvent` throws. Register each event separately inside `pcall`.
- Print each error once through `Report`.

## Touching the UI

- Action bars only through alpha. Do not use `Hide()`, `Show()`, or state drivers on bars.
- No secure snippets. Do not touch `ChatFrame_OpenChat`.
- `PlayerFrame` and `PetFrame` only through alpha, per the rule above. Do not hide target, party, or raid frames, the minimap, vehicle / extra action / zone ability, or the LFG eye (`QueueStatus`, `LFGEye`).
- Blizzard overwrites alpha. Hold the wanted value with a `SetAlpha` hook and the `_quietApplying` flag so the hook does not loop.
- Disabling must restore saved alpha and textures (`RestoreAll`). Wire new behavior into both `ApplyAll` and `RestoreAll`.

## Code

- Files load in `QuietUI.toc` order and share the addon table: `local _, ns = ...`. No globals except `QuietUIDB`, `QuietUICharDB`, the slash command, `QuietUISetup` so Escape can close the setup window, and `QuietUIGlance`, `BINDING_CATEGORY_QUIETUI`, and `BINDING_NAME_QUIETUI_GLANCE` for the Glance key. Do not add libraries.
  - `Core.lua`: `DB`, `Print`, `Report`, alpha hooks, fading, texture hiding, restore.
  - `Frames.lua`: bar / bag / spared classification, `Mute`.
  - `Bars.lua`: action bars, `ShowAll`, and `BarTarget`.
  - `Faders.lua`: XP bar, cooldown manager, damage meter, player frame, pet frame, quest tracker, buffs.
  - `Menu.lua`: the bag button and micro menu.
  - `Chat.lua`: chat chrome, line bubbles, and the input box.
  - `LayoutString.lua`: only the Edit Mode export string. Update it by pasting a new export.
  - `Layout.lua`: asks to add or update the `QuietUI` Edit Mode layout from that string.
  - `Setup.lua`: the `/quiet setup` window, `CharDB`, `Pinned`, `PlayerStyle`, `GroupAuras`, `ChatFade`.
  - `QuietUI.lua`: `ApplyAll`, `RestoreAll`, events, `OnUpdate`, `/quiet`.
- Call other files through `ns` at run time, not through locals captured at load, so load order only matters for `QuietUI.lua` being last.
- Comments in English, short, only where the reason is not visible from the code.
