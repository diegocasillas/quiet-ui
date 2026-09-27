<div align="center">

# QuietUI

**A quiet interface for WoW Forever.**
Few frames. Few buttons. The world stays on screen.

![QuietUI out of combat](docs/images/img001.png)

</div>

---

## Why

The default UI shows everything all the time: bars you do not press, a menu you
open twice a week, chat tabs, bag icons, XP. QuietUI hides what you do not
need right now and brings it back the moment you do.

It is either **on** or **off**. One window, `/quiet setup`, chooses what stays
on screen. That choice is saved per character.

## What fades

Checked rows in `/quiet setup` stay visible. Everything else follows this:

| Element | Shows when |
| --- | --- |
| Action bars | hover, combat, a vehicle, a dungeon, raid, battleground or arena, Edit Mode |
| XP bar | the same, and for a few seconds after a quest gives XP |
| Cooldown manager | combat, a group, an instance, Edit Mode |
| Damage meter | the same as the action bars, and it stays a moment after combat |
| Personal resource | combat, an instance, Edit Mode, or when mana, focus or energy is low. The health part also shows while you are hurt |
| Quest tracker | hover, Edit Mode |
| Buffs and debuffs | hover, combat, a group, an instance, Edit Mode |
| Bag button | hover, while the bag slots are open, or while an item is on the cursor |

![Action bars fade in on hover](docs/images/img002.png)

![QuietUI in combat](docs/images/img003.png)

### Player frame

Pick one in `/quiet setup`:

- **Personal resource** (the default). The portrait frame stays hidden. You use the personal resource bar above.
- **Classic.** The portrait frame shows with a target, in combat, in a group, in an instance, in a vehicle, on hover, and in Edit Mode.

### One button instead of two rows

The micro menu and all bag buttons collapse into a single small button.

- **Left click** opens your bags.
- **Right click** shows the bag slots, so you can swap bags.
- **Drag** moves it. The position is remembered.

![The bag and menu button](docs/images/img004.png)

### Modern chat

A toggle in `/quiet setup`, on by default. Uncheck it and the original chat comes back.

Each message is its own rounded bubble. A new line slides in from the left. At the bottom a line fades away after 10 seconds. Scroll up and the older lines are still there. Hover a line to copy it. Channel tags stay short, and the input appears only while you type. **Enter** works as always.

![Modern chat](docs/images/img005.png)

### A layout that fits

QuietUI ships its own Edit Mode layout, also called QuietUI. The first time
you log in, and again if that layout changes, a small prompt asks once:

- **Add** or **Update** puts the layout in place.
- **Not now** leaves your layouts alone.

**Import layout** in `/quiet setup` does the same later, including after Not now.
Turning QuietUI off does not switch your Edit Mode layout.

![Layout prompt](docs/images/img006.png)

## Commands

```text
/quiet          turn QuietUI on or off
/quiet setup    open the window
```

## The setup window

`/quiet setup` is the only window.

![Setup window](docs/images/img007.png)

**Always visible.** Check a row and that piece stays on screen: action bars,
XP bar, cooldown manager, damage meter, personal resource, quest tracker,
buffs and debuffs, bag button.

**Player frame.** Personal resource or Classic, as above.

**Chat.** Modern chat is a toggle, on by default. Uncheck it and Save to use the original chat. Fade after sets how long a line stays at the bottom: steps of 5 seconds, up to 60. Stay keeps the line. The default is 10 seconds.

- **Save** keeps the choices and closes the window.
- **Reset default** clears the checks, puts Personal resource, Modern chat, and a 10 second fade back, and applies that at once.
- **Import layout** writes the QuietUI Edit Mode layout.
- **Escape** closes the window and drops checks you have not saved.

## Install

1. Download the zip from the [latest release](https://github.com/rdurica/quiet-ui/releases/latest).
2. Extract it into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
   The zip already contains the `QuietUI` folder. The folder name has to stay `QuietUI`.
3. Start the game, or type `/reload`, and answer the layout prompt.

## Compatibility

Built for the **WoW Forever** beta.
