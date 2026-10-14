# JiUnitFrames

Nurfed-style unit frames for WoW Forever: player, target, target of target, pet, and party 1-4 with their pets. It's a port of the look and behaviour of Nurfed UnitFrames (1.12.1, "DPS" layout by Baroque). The original addon is in `Reference/` and the target look is in `Reference/NurfedFrames.png`.

## Install

Copy the `JiUnitFrames` folder (the one containing `JiUnitFrames.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Usage

- `/jiuf` opens the options. They're also under Options → AddOns and in the minimap addon compartment.
- `/jiuf unlock` makes the frames draggable, with green borders. Frames without a unit show your own character as sample data. Dragging any party frame moves the whole party, and party pets move with their party frame. `/jiuf lock` puts them back.
- `/jiuf reset` resets the positions.
- `/jiuf debug` prints API errors the frames would otherwise swallow. Turn this on if something looks wrong.
- Left-click targets and right-click opens the unit menu, in or out of combat.
- If Edit Mode's "Use Raid-Style Party Frames" is on, turn it off, or both party styles will show.

## What each frame shows

| Frame | Contents |
| --- | --- |
| Player | 3D portrait, druid mana bar underneath in cat/bear form, name (class colour), level, `cur (max)` health with missing health in orange, power, combat/resting icon, PvP rank, PvP flag, leader and master looter icons, raid group number, debuffs above |
| Target | Name + guild, level + class (or elite/rare + creature type), health %, 3D portrait, buffs below, debuffs above, combo points to the left, raid icon, PvP flag and rank |
| Target of target | Mini frame between the player and target: name and health % |
| Pet | `[level] name`, health %, bars, buffs and debuffs below |
| Party 1-4 | Class icon, `[F2] Name` (the key bound to "Target Party Member"), health %, bars, leader and master looter icons, PvP flag, target highlight, buffs below, 4 debuffs to the right, pet mini frame |

On the player's mana bar, a white spark crosses the bar during the 5 seconds after you spend mana (the five second rule, no spirit regen). After that, while mana isn't full, a fainter spark crosses it every 2 seconds, timed to the mana ticks. Both can be turned off under Mana in the options; unlocked frames loop the sweep as a preview.

Druids in cat or bear form get a mana bar under the player frame, styled and coloured like the normal mana bar, and the sparks move onto it. It can be turned off under Mana; unlocked frames show it as a preview.

Health bars use Nurfed's colours (green above 60%, orange down to 20%, then red) and glide to new values. Debuffs you can dispel flash on friendly frames.

## Forever's secret values

Forever runs Midnight's addon restrictions. `UnitHealth` is always a secret value to addons. Max health, power, NPC names and aura details become secret for NPCs or in combat. Addons can't do math on secret values, but they can pass them to widgets. So:

- Health and power text is written with `SetFormattedText`, and the bars get the secret values directly.
- Missing health comes from `UnitHealthMissing`. The health percentage and bar colour come from `UnitHealthPercent` with curves: a step curve for whole percents, a colour curve for Nurfed's gradient, and a curve that fades the missing-health text out at full health.
- Auras can't be read by addons at all while they're secret: `C_UnitAuras.GetAuraDataByIndex` errors with "Auras cannot be accessed when secret while tainted". Each aura row is therefore Blizzard's `CustomAuraContainerTemplate`. Its secure code picks the auras and fills the buttons (icon, stacks, duration spiral, dispel-type border, tooltip), and JiUnitFrames only styles each button once, when it's created. Debuff rows have two groups: `HARMFUL|RAID` (debuffs you can dispel, listed first, pulsing) and `HARMFUL|!RAID` (the rest).

Anything that differs from Blizzard's docs fails quietly behind `pcall` (see `/jiuf debug`).

## Not verified in game yet

All of this was built against Blizzard's Forever UI source and API docs and tested with the mocked API. None of it has run in the client yet. Check especially:

- The overall look against the screenshot: font, bar texture, spacing.
- Secret-value paths in combat: health %, the missing-health fade and bar colours.
- Aura containers: icons, stacks, spirals, dispel borders, tooltips, the pulse on dispellable debuffs, and target changes.
- Party frames showing and hiding as people join and leave (secure state drivers).
- The Blizzard frames staying hidden, including through Edit Mode.
- The druid mana bar: placement under the player frame, and that it shows in cat and bear form only.
- The mana spark: whether Forever keeps 2-second mana ticks (if regen is continuous, the tick spark won't line up), whether the player's mana is secret, and the spark's size and brightness on the 10 px bar.
- The class icon atlas `classicon-<class>`, and the master looter and PvP rank icons.

Known gaps: Nurfed shrank aura icons to fit when there were many; containers use a fixed icon size. The duration-spiral and dispel-flash options apply after /reload, because aura buttons can't be changed after they're created. Nurfed's combat text on the player portrait isn't ported: the combat log and `UNIT_COMBAT` amounts aren't available to addons.

## Media

`Media/statusbar.tga` is Nurfed's `statusbar6` texture. `Media/framd.ttf` is Franklin Gothic Medium from the Nurfed package. It's a commercial Microsoft font, so don't publish the addon with it; switch the default font to a game font first.

## Development

```
luajit JiUnitFrames/tests/run_tests.lua   # from JiAddons/
tools/package.sh JiUnitFrames             # builds JiUnitFrames/dist/JiUnitFrames-<version>.zip
```
