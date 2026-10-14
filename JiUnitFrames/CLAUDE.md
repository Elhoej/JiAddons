# JiUnitFrames: project notes

Read `../CLAUDE.md` first. It covers platform facts, shared code and tooling.

## Goal

Recreate the look and behaviour of Nurfed UnitFrames' "DPS" layout (`Reference/Nurfed/Nurfed_UnitFrames/Layout_2.lua`, screenshot `Reference/NurfedFrames.png`). Nurfed's code structure doesn't matter. Its layout numbers (sizes and offsets) do, and they're copied into `Frames.lua`. `Reference/` isn't part of the addon.

## Files (`JiUnitFrames/`)

- `Core.lua`: `ns.defaults`, saved variables (`JiUnitFramesDB`), `ns:OutOfCombat(key, fn)` (defers secure work to `PLAYER_REGEN_ENABLED`), `ns:ApplySettings()` and the `/jiuf` slash commands.
- `Unit.lua` (`ns.Unit`): secret-safe helpers. `Plain`, `Has`, `Bool`, `Try` (pcall with debug output), colours, `Curves()` (percent step curve, missing-text alpha curve, health colour curve), level and class labels, key binding labels, class icons.
- `Elements.lua` (`ns.Elements`): widget builders (`Text`, `Bar`, `HealthBar`, `PowerBar`, `Portrait`, `Icon`, `AuraRow`) and the `Update*` functions, including the druid mana bar (`DruidManaBar`/`UpdateDruidMana`: a strip under the player frame, shown for druids whenever the power bar isn't mana). They take `(frame, unit)` and skip elements the frame doesn't have. Aura rows are Blizzard `CustomAuraContainerTemplate` frames; see the comment above `StyleAuraButton`.
- `ManaSpark.lua` (`ns.ManaSpark`): the five second rule spark (after wago.io/tbc-mana-ticker). `Attach(bar, showsMana)` registers a bar; the first visible one showing mana gets the spark (the player's power bar, else the druid mana bar). A cast that spends mana starts a 5 s sweep; afterwards a 2 s sweep follows the regen ticks, which are detected from mana going up (plain mana only). With secret mana, the spell's cost (`C_Spell.GetSpellPowerCost`, read at `UNIT_SPELLCAST_SENT` before a shapeshift changes which costs apply, as DruidForeverManabar does) stands in for the mana drop. Its own frame runs the `OnUpdate` only while a spark is shown.
- `Frames.lua` (`ns.Frames`): builds the secure unit buttons (`JiUnitFrames_<key>`), routes events, handles visibility (unit watch, plus a state driver for party), positions, scale (`Frames.BASE_SCALE` = 1.15 on top of the sliders, because Nurfed's sizes look small on modern screens), dragging and test mode (`Frames.testMode`: missing units display "player").
- `Blizzard.lua`: disables Blizzard's player, target, pet and party frames.
- `Options.lua`: the options window.

## Rules for this addon

- Never do arithmetic, comparisons, concatenation or truth tests on unit data without checking `ns.IsSecret` first (`U.Plain`, `U.Has` and `U.Bool` do this). Pass secrets only to widget setters that accept them: `SetText`, `SetFormattedText`, `SetValue`, `SetMinMaxValues`, `SetAlpha`, `SetTextColor`/`SetVertexColor`/`SetStatusBarColor` and `SetTexture`. Cooldown setters and `SetShown` reject secrets.
- Never call `C_UnitAuras` getters: they throw for addon code whenever auras are secret (verified in game). Show auras through aura containers, and style their buttons only in `initializeFrame`. The client locks the buttons against addon access afterwards.
- Secure frames (the unit buttons) may only be created, moved, scaled, shown/hidden or re-driven out of combat. Route that work through `ns:OutOfCombat`. Their insecure children (bars, texts, aura buttons) can change any time.
- The tests run in both plain and secret mode (`M.secrets = true` in the mock), and `NoErrors()` fails on anything swallowed by `pcall`. Add both cases for new elements.
