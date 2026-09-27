# QuietUI

Opinionated UI for WoW Forever. Modern and quiet: few frames, few buttons, text stays. The addon only turns on or off. No other settings.

## Product

- The goal is a clean UI, not a configurable framework.
- The only control is `/quiet` (`on` / `off`, no argument toggles). `/quiet layout` writes the bundled Edit Mode layout right away, even after "Not now".
- `QuietUIDB` may hold only `enabled`, the button position after dragging, and `layoutHash` (the last answered layout version). No options panel, sliders, checkboxes, or libraries like Ace3.
- Player-facing text (chat, tooltip) is English.

## Look

- Flat, dark, thin border. Background `0.05, 0.05, 0.05, 0.75`, border `0.85, 0.85, 0.85, 0.35`, highlight `0.95, 0.75, 0.25`.
- Message prefix: `|cff8fd4c8QuietUI|r`.
- A short friendly greeting on login and reload: the state, then one short line each for `/quiet` and `/quiet layout` so commands never wrap. No other chat messages unless the player acts or something fails.
- Action bars and the XP bar fade out unless hovered, in combat, in a vehicle, in edit mode, or in an instance (party, raid, pvp, arena). The XP bar also shows for 5 s after a quest turn-in that gives XP.
- The cooldown manager shows only in combat, in an instance, in a group, or in edit mode. Hover does not show it.
- The damage meter behaves the same and stays for 10 s after combat.
- The personal resource bar shows only in combat, in an instance, or in edit mode, and anywhere while mana, focus, or energy is below 70 %. Its health bar also shows anywhere while health is not full. Hover does not show it.
- The player frame (`PlayerFrame`) shows only on hover or in edit mode. Not in combat, not with a target.
- The quest tracker (`ObjectiveTrackerFrame` / `QuestWatchFrame`) shows only on hover or in edit mode.
- Buffs and debuffs (`BuffFrame`, `DebuffFrame`, `TemporaryEnchantFrame`) show only in combat, in an instance, in a group, on hover, or in edit mode.
- The micro menu and bags collapse into one button. The button shows only on hover, while bag slots are shown, while an item is on the cursor, or while dragged. Left click opens bags, right click shows the bag slots for swapping, drag moves it.
- The addon ships an Edit Mode layout named `QuietUI`. `LayoutString.lua` is the source of truth. Each new version of the string is offered once in the addon's own flat prompt (not `StaticPopup`, which spreads taint). The answer (add, update, or not now) is remembered as a hash in `QuietUIDB.layoutHash`; saved layouts are never compared, because the client rewrites them. Nothing changes without the player's consent. A new layout is activated; an updated one is replaced in place. `/quiet off` does not switch layouts. Use `C_EditMode` only, never `EditModeManagerFrame` methods (taint).
- Chat keeps its text and drops the chrome. The input box is visible only while focused. Enter stays a Blizzard binding.

## Client

- WoW Forever beta, `Interface: 16001`. The API mixes classic and newer frames; a global may not exist.
- The main bar is `MainActionBar`, not `MainMenuBar`. The damage meter is a Blizzard load-on-demand addon; its frames are found by the `DamageMeter` prefix. The cooldown manager is `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`. The personal resource bar is `PersonalResourceDisplayFrame`; do not fade nameplates, they are recycled across units.
- Unit health and power are secret values, even out of combat. Never compare them or do math on them; pass them to widgets (for example `UnitPowerPercent` with a `C_CurveUtil` curve into `SetAlpha`). Check with `ns.IsSecret`.
- Scans of `UIParent` children can hit forbidden frames. Check `ns.Usable` before calling any method.
- Wrap calls that may be missing on this client in `pcall`, or check `type` first.
- An unknown event in `RegisterEvent` throws. Register each event separately inside `pcall`.
- Print each error once through `Report`.

## Touching the UI

- Action bars only through alpha. Do not use `Hide()`, `Show()`, or state drivers on bars.
- No secure snippets. Do not touch `ChatFrame_OpenChat`.
- `PlayerFrame` only through alpha, per the rule above. Do not hide target, party, or raid frames, the minimap, vehicle / extra action / zone ability, or the LFG eye (`QueueStatus`, `LFGEye`).
- Blizzard overwrites alpha. Hold the wanted value with a `SetAlpha` hook and the `_quietApplying` flag so the hook does not loop.
- Disabling must restore saved alpha and textures (`RestoreAll`). Wire new behavior into both `ApplyAll` and `RestoreAll`.

## Code

- Files load in `QuietUI.toc` order and share the addon table: `local _, ns = ...`. No globals except `QuietUIDB` and the slash command. Do not add libraries.
  - `Core.lua`: `DB`, `Print`, `Report`, alpha hooks, fading, texture hiding, restore.
  - `Frames.lua`: bar / bag / spared classification, `Mute`.
  - `Bars.lua`: action bars and `ShowAll`.
  - `Faders.lua`: XP bar, cooldown manager, damage meter, player frame, quest tracker, buffs.
  - `Menu.lua`: the bag button and micro menu.
  - `Chat.lua`: chat chrome and the input box.
  - `LayoutString.lua`: only the Edit Mode export string. Update it by pasting a new export.
  - `Layout.lua`: asks to add or update the `QuietUI` Edit Mode layout from that string.
  - `QuietUI.lua`: `ApplyAll`, `RestoreAll`, events, `OnUpdate`, `/quiet`.
- Call other files through `ns` at run time, not through locals captured at load, so load order only matters for `QuietUI.lua` being last.
- Comments in English, short, only where the reason is not visible from the code.
