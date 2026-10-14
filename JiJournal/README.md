# JiJournal

A world map and quest log for WoW Forever, kept as two separate windows:

- **World map** (M), styled after Leatrix Maps. It's a borderless window that doesn't cover the screen, and you can move it. Scroll to zoom, on every map. Each map remembers its zoom and pan between openings and sessions. A bar along the bottom shows the map name and the cursor and player coordinates.
- **Quest log** (L), laid out like WideQuestLogPlus. Quests are grouped by zone on the left, with `[level]` prefixes coloured by difficulty, `(Complete)` markers and a tick for tracked quests. The parchment details are on the right, with `Abandon Quest`, `Share Quest` and `Exit` along the bottom.

## Install

Copy the `JiJournal` folder (the one containing `JiJournal.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Usage

- `/jij` (or `/jijournal`) opens the options. They're also under Options → AddOns and in the minimap addon compartment.
- `/jij quests` toggles the quest log, and `/jij reset` puts both windows back in their default places.
- `/jij debug` prints API errors the addon would otherwise swallow.

On the map:

- Scroll the mouse wheel to zoom in and out around the cursor.
- Drag the map to pan it.
- Left-click a zone to open its map, and right-click to go up a level.
- Drag the bar along the bottom to move the window. M and Escape close it.

In the quest log:

- Click a zone to collapse or expand it, or click **All** to collapse or expand every zone.
- Click a quest to see its details.
- Shift-click a quest to link it into an open chat box. With chat closed, shift-click tracks or untracks it instead.
- **Track Quest** adds the selected quest to the objective tracker.

Clicking a quest in the objective tracker opens it in JiJournal's quest log.

Map size, map opacity, maximum zoom, quest log size, quest levels and quest IDs can all be changed in the options. Either half of the addon can be turned off there (this takes effect after `/reload`).

## How it works

The map is Blizzard's own `WorldMapFrame`, restyled. Quest pins, flight points, dungeon entrances, waypoints and the filter button all keep working. JiJournal sets the `miniWorldMap` and `questLogOpen` CVars so the map always opens small, without the docked quest panel. If you turn JiJournal off, use the buttons on Blizzard's map to get the large map back.

The quest log is a new window. Its details pane is drawn by Blizzard's `QuestInfo` code, so rewards, item tooltips and links behave as in Blizzard's own quest windows.

## Development

```
luajit JiJournal/tests/run_tests.lua   # from JiAddons/
tools/package.sh JiJournal             # builds JiJournal/dist/JiJournal-<version>.zip
```
