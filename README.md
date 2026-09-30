# QuietUI

**Less UI. More world.** A quiet interface for the **WoW Forever beta** (Interface 16001).

QuietUI fades the Blizzard HUD while you explore and brings back the parts you
need through hover, combat, and your current situation. One setup window chooses
what stays visible, with personal settings or shared presets across characters.

![QuietUI while exploring](docs/images/img001.png)

## What you get

- **Bars when you need them.** Hover reveals a group of action bars; combat and
  instances bring every bar back. Choose bars to keep visible for an enemy or a
  friendly target.
- **A quieter HUD.** Quests appear on hover. Cooldowns and the damage meter appear
  when fighting or grouped. Health and resources appear when they need attention.
- **Chat without the chrome.** Messages appear in dark bubbles and fade after
  10 seconds by default. Hover to see faded lines, scroll through history, or copy
  a message. Enter works as usual.
- **One bag button.** Left click opens bags, right click reveals bag slots, and
  dragging moves the button.
- **Glance.** Press `` ` `` to reveal the faded HUD at once. Press again to return
  to your usual visibility rules. Chat stays unchanged.

![QuietUI in combat](docs/images/img003.png)

## Install

1. Download the zip from the [latest release](https://github.com/rdurica/quiet-ui/releases/latest).
2. Extract it into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
   The addon file should end up at `AddOns/QuietUI/QuietUI.toc`.
3. Start the game or type `/reload`. Accept the optional QuietUI layout, or choose
   **Not now** to keep your current layout.

## Controls

```text
/quiet          Toggle QuietUI
/quiet on       Enable QuietUI
/quiet off      Disable QuietUI
/quiet setup    Open settings
```

The minimap button also opens settings, even while QuietUI is off. Drag it around
the minimap to move it.

Glance defaults to `` ` `` if the key is free. Change it under **QuietUI** in
**Key Bindings**.

## Make it yours

Open `/quiet setup`, change your choices, then click **Save**. The window stays
open. **X** or **Escape** closes it without saving pending changes.

![QuietUI setup](docs/images/img007.png)

- **General:** Choose a shared preset or keep `<no preset>` for personal settings.
  Create, rename, or delete presets here, and choose the existing Edit Mode layout
  each preset uses. Without a preset, **Force QuietUI layout** switches to the
  bundled layout when QuietUI turns on; it is off by default.
- **Visible:** Check the HUD elements you want to keep on screen. Action bars and
  the swing timer have separate checks.
- **Bars:** Give bars the same number to reveal them together on hover. **Enemy**
  and **Friend** keep just that bar visible for the matching target.
- **Player:** Toggle the portrait and pet, group buffs with the player frame, or
  require a living target. Optional **In range** adds a green gradient to your
  target's nameplate while in range and the action bars are down. Choose 10 yards,
  28 yards, or Spell; leave the spell name empty to use the longest matching spell
  on bar 1. Choose Unfriendly or Friendly for the target type.
- **Chat:** Toggle modern chat and choose the fade delay. **Stay** keeps messages
  visible at the bottom.
- **Info:** A short guide to QuietUI and Glance.

With a preset selected, **Save** updates its settings for every character using
it. Other characters load the changes on their next login. Selecting, creating,
and renaming take effect after **Save**. Choosing a preset's layout previews it
immediately; **Save** stores the link, while **X** or **Escape** restores the layout
used before the preview. Deletion takes
effect immediately after confirmation. New characters start with `<no preset>`.
Leaving a preset, or losing it because it was deleted on another character, keeps
the last settings used as a personal copy.

A preset selects its linked layout when you log in, enable QuietUI, or save it.
Turning QuietUI off restores your previous layout. If the linked layout is missing,
QuietUI uses its bundled layout and reports the missing link once per login. Choose
a replacement in General and save to repair it. Layout changes wait until combat
ends. Presets can also be managed while QuietUI is off.

**Reset default** disconnects this character from its preset without changing the
shared preset, then applies and saves the defaults immediately: no Always visible
checks, default bar groups, player frame and grouped buffs on, modern chat with a
10-second fade, and Force layout, living-target requirement, and In range off.

**Import layout** adds or updates the bundled Edit Mode layout immediately,
including after choosing Not now. Each bundled layout version is offered once;
updates require your agreement. Without a preset and with Force layout off,
enabling or disabling QuietUI leaves your active layout alone.

<details>
<summary><strong>Visibility rules in detail</strong></summary>

All of these follow your Always visible choices and Glance, except that the player
and pet require the player frame to be enabled. Edit Mode reveals the HUD for
arranging it. Elements appear immediately and fade out over 0.3 seconds.

- **Action bars:** Hover, combat, a vehicle, an instance, an open spell flyout, or
  an item on the cursor. By default, bars 1–3, stance, pet, and totem fade together;
  bars 4–5 share another group, later bars each have their own, and swing uses 10.
- **XP:** Hover, five seconds after a quest awards XP, a spell flyout, or an item
  on the cursor. Combat alone does not reveal it.
- **Cooldowns and damage meter:** Combat, an instance, or a group. The meter stays
  for 10 seconds after combat. Hover does not reveal either.
- **Personal resource:** Combat, an instance, or mana, focus, or energy below 70%.
  Its health bar also appears when health is not full.
- **Player and pet:** A target, combat, an instance, a group, a vehicle, hover, or
  low mana, focus, or energy. Having a pet out alone does not reveal them.
  **Require a living target** overrides these rules and Glance for a dead target,
  fading player, pet, and target frames; Edit Mode still reveals them.
- **Buffs and debuffs:** Combat, an instance, a group, or hover. Grouping is on by
  default and also reveals them with the enabled player frame.
- **Quest tracker and micro menu:** Hover across their whole area, including gaps.
- **Bag button:** Hover, open bag slots, an item on the cursor, or dragging.

In range needs a visible target nameplate and a living target. It stays off during
combat, in vehicles and instances, in Edit Mode, with a spell flyout or item on the
cursor, during Glance, and with Action bars checked under Always visible.

</details>
