# JiBar

FuBar for World of Warcraft: Forever. It gives you information bars along the screen edges with FuBar's plugins, styled like a skinned FuBar 2.0 setup:

| Plugin | Shows | Click |
| --- | --- | --- |
| Micro Menu | Flat icons for the game menu, social, guild, character, spellbook, talents, reputation, quests, raid, dungeon journal, PvP, world map and help. Group finder, professions, achievements, collections and the shop can be turned on. | Opens the window (Who, Friends and Raid open the social window; Reputation opens the character window) |
| Durability | Your most damaged item (or the average). The tooltip lists every item with its repair cost. Can repair automatically. | Character window |
| Honor | Honour earned today and your battleground score, e.g. `0 HONOR \| 8-5 (62%)` | Group finder |
| Clock | Realm or local time (or both). The tooltip shows local, realm and UTC time. | Calendar (shift: stopwatch) |
| Quests | Quests in the log out of the maximum, plus the last progress message. The tooltip lists quests by zone; clicking a quest opens it in JiJournal (or tracks it without JiJournal). | Quest log |
| Money | Your gold. The tooltip shows gains and spending for the session, today, yesterday and the last 7 days, plus all your characters on the realm. | Bags |
| Transporter | Your hearthstone's inn (or a teleport) and its cooldown | Uses it |
| Experience | `XP 62% +15%` (rested), or your watched reputation. A thin XP bar runs along the bar's edge. | Puts the numbers into chat |
| Performance | fps, latency, addon memory and how fast it grows. The tooltip lists the addons using the most memory. | Collects garbage |
| Custom Menu | Your own Lua snippets (off by default) | Opens the menu |

## Install

Copy the `JiBar` folder (the one containing `JiBar.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Usage

- Hover a plugin for its tooltip. Right-click it for its settings, its position, and "Hide".
- Right-click an empty part of a bar to choose its edge, background and auto-hide, which plugins it shows, and to add or remove bars.
- `/jibar unlock` (or "Lock bars" in any menu) unlocks the bars:
  - drag a plugin to any place on any bar; a yellow marker shows where it will go;
  - drag a bar to the top or bottom of the screen, or leave it in the middle to float;
  - drag a bar's yellow ends to resize it.

  `/jibar lock` when you're done.
- `/jibar` opens the options. They cover fonts (FuBar's Homizio by default, plus LibSharedMedia fonts if installed), text and hover colours, icon size, tooltip scale and opacity, and per bar: edge, size, position, scale, strata, background (FuBar's and FuTextures' skins, or a solid colour), tint, an edge line, padding and spacing per side, auto-hide and hide in combat. Each plugin also has its own settings there.
- `/jibar custom add <name> ### <lua>` adds an entry to the Custom Menu (`---` as the Lua adds a separator); `/jibar custom remove <name>` removes it.
- `/jibar reset` resets everything (then `/reload`).

## Development

```
luajit JiBar/tests/run_tests.lua   # from JiAddons/
tools/package.sh JiBar             # builds JiBar/dist/JiBar-<version>.zip
```

See `CLAUDE.md` for how it works.
