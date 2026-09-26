# QuietUI

Opinionated UI for WoW Forever. Modern and quiet: few frames, few buttons, text stays. The addon only turns on or off. No other settings.

## Product

- The goal is a clean UI, not a configurable framework.
- The only control is `/quiet` (`on` / `off`, no argument toggles).
- `QuietUIDB` may hold only `enabled` and the button position after dragging. No options panel, sliders, checkboxes, or libraries like Ace3.
- Player-facing text (chat, tooltip) is English.

## Look

- Flat, dark, thin border. Background `0.05, 0.05, 0.05, 0.75`, border `0.85, 0.85, 0.85, 0.35`, highlight `0.95, 0.75, 0.25`.
- Message prefix: `|cff8fd4c8QuietUI|r`.
- Action bars, the XP bar, and the cooldown manager fade out unless hovered, in combat, in a vehicle, in edit mode, or in an instance (party, raid, pvp, arena).
- The damage meter behaves the same and stays for 10 s after combat.
- The player frame (`PlayerFrame`) fades out unless the bar conditions apply, the player has a target, is dead, or is missing health. Power (mana, rage) does not count.
- The micro menu and bags collapse into one button. Left click opens bags, right click shows the bag slots for swapping, drag moves it.
- Chat keeps its text and drops the chrome. The input box is visible only while focused. Enter stays a Blizzard binding.

## Client

- WoW Forever beta, `Interface: 16001`. The API mixes classic and newer frames; a global may not exist.
- The main bar is `MainActionBar`, not `MainMenuBar`. The damage meter is a Blizzard load-on-demand addon; its frames are found by the `DamageMeter` prefix. The cooldown manager is `EssentialCooldownViewer`, `UtilityCooldownViewer`, `BuffIconCooldownViewer`, `BuffBarCooldownViewer`.
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
  - `Faders.lua`: XP bar, cooldown manager, damage meter, player frame.
  - `Menu.lua`: the bag button and micro menu.
  - `Chat.lua`: chat chrome and the input box.
  - `QuietUI.lua`: `ApplyAll`, `RestoreAll`, events, `OnUpdate`, `/quiet`.
- Call other files through `ns` at run time, not through locals captured at load, so load order only matters for `QuietUI.lua` being last.
- Comments in English, short, only where the reason is not visible from the code.
