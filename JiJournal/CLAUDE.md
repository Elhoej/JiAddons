# JiJournal: project notes

Read `../CLAUDE.md` first. It covers platform facts, shared code and tooling.

## Goal

Replace Forever's combined "Map & Quest Log" window with two separate windows. The world map should look and behave like Leatrix Maps: borderless, not fullscreen, movable, wheel zoom, and zoom and pan remembered. The quest log should look like WideQuestLogPlus: zone list on the left, parchment details on the right. Ji's reference screenshots are Leatrix Maps (Classic 1.13) and WideQuestLogPlus.

## Files (`JiJournal/`)

- `Core.lua`: `ns.defaults`, saved variables (`JiJournalDB`), `ns.Debug`, `ns:ApplySettings()`, the `/jij` slash commands.
- `Map.lua` (`ns.Map`): restyles Blizzard's `WorldMapFrame`, with wheel zoom, per-map view memory and the coordinates bar.
- `QuestLog.lua` (`ns.QuestLog`): the quest log window. It replaces `ToggleQuestLog`, `OpenQuestLog` and `QuestMapFrame_OpenToQuestDetails`.
- `Options.lua`: the options window.

## How Forever's map and quest log work

Forever is the mainline client. The quest log is `QuestMapFrame`, docked inside `WorldMapFrame` (`Blizzard_WorldMap/QuestLogOwnerMixin.lua`). The classic `QuestLogFrame` isn't loaded for game type camelot, so there's no standalone quest log to reuse.

## Map: the rules it relies on

- **Panel layout:** `ShowUIPanel`/`HideUIPanel` just show and hide a frame whose `UIPanelLayout-area` attribute is nil (`UIParentPanelManager.lua`). JiJournal sets `UIPanelLayout-defined = true` and `area = nil` on `WorldMapFrame`, so M keeps working through Blizzard's own `ToggleWorldMap`, and the frame stays where it was put. Escape works through `UISpecialFrames`.
- **Display state:** the CVars `miniWorldMap = 1` and `questLogOpen = 0` make `QuestLogOwnerMixin` always pick "minimized, no log". The size comes from `map.minimizedWidth/Height`. A `SetDisplayState` hook hides `SidePanelToggle` (Blizzard re-shows it every time) and closes the docked log if anything opens it.
- **Zoom:** `SetMouseWheelZoomMode(MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE)` turns Blizzard's wheel zoom off, and an `OnMouseWheel` hook calls `ScrollContainer:InstantPanAndZoom(scale, x, y, true)`. It doesn't clamp the scale, so zoom can go past Blizzard's last zoom level (vanilla maps may only have one). The pan is computed so the map point under the cursor stays put.
- **View memory:** `views[mapID] = { scale / minScale, centreX, centreY }`. Blizzard resets the zoom in three places: in `OnShow`, on every map change (`SetMapID`), and in `OnFrameSizeChanged`. Opening the map with M runs that last one *after* `OnShow` (`SetDisplayState` → `UpdateSpacerFrameAnchoring`). So the view is restored in a `HookScript("OnShow")` and in `OnMapChanged` and `OnFrameSizeChanged` hooks. 0.1.1 missed the last one, so reopening the map lost the zoom. The mock's `ToggleWorldMap`/`SetDisplayState` follow the same order.
- **Buttons:** the map pin button is hidden for good (`KeepHidden`). Questie adds its map button through Krowi_WorldMapButtons. On Forever, Krowi lines buttons up in a row from the canvas's top-right corner (`TOPRIGHT -4, -2`, 32px apart) and re-anchors them in its own `OnMapChanged` hook. Questie removes Blizzard's buttons from Krowi's list, so `Map:ArrangeButtons` puts the filter button to the left of the shown Krowi buttons. It runs one frame after `OnShow`/`OnMapChanged`, so it comes after Krowi.
- **Taint:** the zoom and restore calls write to the scroll container from addon code. If Ctrl-click waypoints or other map actions ever get blocked in game, suspect this first.

## Quest log: the rules it relies on

- **Taking over the globals:** in Forever, `Blizzard_WorldMap` loads *after* addons, and it redefines `ToggleQuestLog`/`OpenQuestLog`. That overwrote JiJournal's versions in 0.1.0, so L opened the map. `QuestLog:TakeOver()` runs again on every `Blizzard_*` `ADDON_LOADED` and at `PLAYER_LOGIN`.
- **Details** come from `QuestInfo_Display(template, scrollChild)` after `C_QuestLog.SetSelectedQuest`. The template is a copy of `QUEST_TEMPLATE_LOG` without `canHaveSealMaterial` and `QuestInfo_ShowSeal`, which assume Blizzard's own detail frame as the content's grandparent.
- **Shared QuestInfo frames:** the QuestInfo frames (`QuestInfoTitleHeader`, `QuestInfoRewardsFrame`...) are shared with `QuestFrame`, the NPC dialog. Don't call `QuestInfo_Display` while `QuestFrame` or `QuestLogPopupDetailFrame` is shown, or the details are taken from the dialog. A `QuestFrame` `OnHide` hook redraws the details.
- **Collapse state** is JiJournal's own (`db.questLog.collapsed[headerTitle]`). Headers Blizzard collapsed (`info.isCollapsed`) are expanded with `ExpandQuestHeader`, because their quests may not be listed.
- **Track, share and abandon** go through Blizzard's `QuestMapQuestOptions_TrackQuest/ShareQuest/AbandonQuest(questID)`. Abandon shows Blizzard's confirmation popup.

## Testing

Run `luajit tests/run_tests.lua` (28 tests). The mock has a reduced `WorldMapFrame` (a single zoom level at scale 1, and an `OnShow` that resets the zoom like Blizzard's), `C_QuestLog` driven by `M.questLog`, and a recording `QuestInfo_Display`. In the mock, `ButtonFrameTemplate` doesn't exist, so the tests exercise the flat fallback window. The real template path is only checked in game.
