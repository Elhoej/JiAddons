# JiLoot: Loot Frame for WoW Forever

JiLoot is a standalone addon version of the [Loot Frame WeakAura](https://wago.io/-IWPKK1il) by Hypocrit, built for **World of Warcraft: Forever**. WeakAuras has no Forever release, so this addon does the same job without it.

It shows a stack of rows for everything you pick up:

| Source | What a row shows |
| --- | --- |
| Items | Quality-coloured name, stack count (`5x`), bag count `(25)`, vendor unit and stack price, auction price, and item level, tertiary stats and sockets for gear |
| Money | Money looted, earned from quests or made by selling, merged into one row |
| Currencies | Amount gained plus your total and cap (red when capped) |
| Reputation | `+80 Argent Dawn Rep (160 / 6000) Friendly`; losses show in red |
| Honor | Classic-style honor kills and awards, or the Honor currency |

It works like the WeakAura:

- Each quality has its own display duration. A duration of `0` hides that kind of loot.
- Looting the same thing again adds to the existing row and restarts its timer.
- Rows glow in three tiers when loot is worth more than your thresholds (white, orange, red), with an optional sound at tier 3.
- Auction prices come from Auctionator, or from TradeSkillMaster if it's installed.
- Items, currencies and reputations can be blacklisted.

Additions over the WeakAura:

- Hovering a row pauses its timer and shows the item tooltip.
- Right-click dismisses a row. Alt + right-click blacklists it. Shift-click links the item in chat.
- An optional thin timer bar, fade and slide animations, grow up or down, and three sort modes.
- While you're auto-looting, Blizzard's loot window stays hidden unless something needs a decision. JiLoot takes everything itself, and the window still appears for bind-on-pickup items, loot rolls, or when your bags are full. You can turn this off under **Loot window** in the options.
- It works in any client language. Loot, reputation and honor messages are matched against Blizzard's own localised format strings instead of English text.

## Install

1. Copy the `JiLoot` folder (the one with `JiLoot.toc` in it) to
   `World of Warcraft/_classic_beta_/Interface/AddOns/` for the Forever beta. At launch, use the Forever client's `Interface/AddOns` folder.
2. Restart the game. `/reload` does not pick up new addon folders.
3. If JiLoot shows as out of date after a patch, tick **Load out of date AddOns** on the character-select AddOns screen. The TOC declares `## Interface: 16001`, the Forever interface number.

Or unzip `dist/JiLoot-<version>.zip` into the AddOns folder. Build it with `../tools/package.sh JiLoot`.

## Usage

| Command | Action |
| --- | --- |
| `/jiloot` | Open or close the options window. It's also under Options → AddOns and in the addon compartment. |
| `/jiloot test` | Show example rows so you can style the frame |
| `/jiloot unlock` / `lock` | Drag the frame by its green handle; right-click the handle to lock it |
| `/jiloot reset` | Move the frame back to its default position |
| `/jiloot clear` | Remove all rows |
| `/jiloot toggle` | Turn the frame on or off |
| `/jiloot bl item <id or link>` | Add an item to the blacklist, or remove it if it's already there. `currency <id>` and `rep <faction name>` work the same way. |
| `/jiloot bl list` | Show the blacklist |

`/jloot` works as a shorter alias.

## WoW Forever notes

Forever runs the modern (Midnight-era) client with its addon restrictions. JiLoot is written to cope with them:

- It uses only non-combat APIs: chat loot messages, `PLAYER_MONEY`, `CURRENCY_DISPLAY_UPDATE` and the reputation APIs. It doesn't touch the combat log.
- Every chat payload is checked with `issecretvalue` before it's read. Messages the client marks as secret are skipped instead of throwing errors. Boss loot also arrives through `ENCOUNTER_LOOT_RECEIVED` as a fallback, with de-duplication so nothing shows twice.
- It calls APIs through the `C_*` namespaces when they exist and falls back to the old globals. Events the client doesn't know about are skipped, so the addon still loads.
- If an item isn't cached yet, JiLoot requests its data and fills the row in when the data arrives.

## Development

JiLoot lives in the `JiAddons` workspace and embeds the shared modules from `../shared` in `JiLoot/Shared/`. Don't edit those copies here: edit `../shared` and run `../tools/sync-shared.sh`.

```
luajit tests/run_tests.lua      # from JiLoot/
../tools/package.sh JiLoot      # builds dist/JiLoot-<version>.zip
```

The tests load the addon against a mocked WoW API (`../tools/mock_wow.lua`) and replay loot, money, currency, reputation, honor and loot-window events. They also drive the UI: hover, clicks, blacklist, row limit, sorting, highlight tiers, Auctionator prices, test mode and the options window. The mock can't catch rendering problems, so check anything visual in game.

```
JiLoot/
  JiLoot.toc      addon manifest (Interface 16001)
  Shared/         embedded copies of ../shared (generated)
  Core.lua        defaults, saved variables, blacklist, slash commands
  Sources.lua     event parsing: items, money, currencies, honor, reputation
  Display.lua     the row stack: layout, timers, animations, glow, tooltips, test mode
  LootWindow.lua  hides Blizzard's loot window while auto-looting non-BoP loot
  Options.lua     options window, Blizzard settings entry and addon compartment
tests/            test runner
```

## Credits

The design and features follow the [Loot Frame WeakAura](https://wago.io/-IWPKK1il) by Hypocrit. JiLoot is a from-scratch reimplementation as a standalone addon.
