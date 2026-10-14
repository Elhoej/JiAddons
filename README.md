# JiAddons

Ji's World of Warcraft: Forever addons, plus the shared code and tools they're built with.

| Addon | What it does |
| --- | --- |
| [JiLoot](JiLoot/README.md) | Loot frame for items, money, currencies, reputation and honor, with prices. Also hides the loot window while auto-looting. |
| [JiUnitFrames](JiUnitFrames/README.md) | Nurfed-style player, target, target of target, pet and party frames. |
| [JiJournal](JiJournal/README.md) | A movable, zoomable world map (Leatrix Maps style) and a separate WideQuestLogPlus-style quest log. |
| [JiCombatFont](JiCombatFont/README.md) | Choose the fonts for outgoing (damage numbers) and incoming (scrolling combat text) damage. |
| [JiCastBar](JiCastBar/README.md) | Player and target cast bars in the ten styles of Elva's cast bar WeakAuras. |
| [JiBar](JiBar/README.md) | FuBar-style information bars with FuBar's plugins: micro menu, durability, honor, clock, quests, money, hearthstone, XP and performance. |

## Getting started

```
brew install luajit                     # test runner (Lua 5.1-compatible)
tools/new-addon.sh JiSomething          # scaffold a new addon project
tools/sync-shared.sh                    # copy shared/ into every addon after changing it
luajit JiLoot/tests/run_tests.lua       # run a project's tests
tools/package.sh JiLoot                 # build JiLoot/dist/JiLoot-<version>.zip
```

`shared/` holds the reusable Lua modules: API compatibility, text and money formatting, events and options widgets. Every addon embeds a copy of them in its own `Shared/` folder. `tools/` holds the mocked WoW API and test harness.

See [CLAUDE.md](CLAUDE.md) for WoW Forever platform notes and conventions.
