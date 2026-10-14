# JiLoot

A standalone loot frame for WoW Forever, ported from the "Loot Frame" WeakAura (https://wago.io/-IWPKK1il). Platform knowledge, shared code and tooling are described in `../CLAUDE.md`.

## Files (`JiLoot/`)

- `Core.lua`: `ns.defaults`, saved variables (`JiLootDB`), `ns.Money` (money text using the player's coin settings), blacklist and `/jiloot` slash commands. Starts the other modules in `ns:OnLoad`.
- `Sources.lua`: turns events into entries: items (loot chat plus encounter loot, de-duplicated), money, currencies, classic honor and reputation. Parsing uses localised global format strings.
- `Display.lua`: the row stack. It handles merging repeat loot, timers (paused on hover), fade and slide animations, the three-tier value glow and sound, tooltips, clicks (dismiss, blacklist, link) and `/jiloot test` sample rows.
- `LootWindow.lua`: while auto-looting, takes all slots and keeps Blizzard's `LootFrame` transparent unless there's bind-on-pickup, locked or uncached loot. The window reappears after 0.5s if items remain.
- `Options.lua`: the options window, built with `ns.Widgets`.
- `Shared/`: generated from `../shared`. Don't edit these files here.

## Entry shape (what `Display:Push` takes)

`{ kind = "item"|"money"|"currency"|"rep"|"honor", key, name, icon, quality, colorHex, count, duration, prio, ... }`. Item entries add `link, itemID, unitPrice, isGear, ilvl, tertiary, sockets, profQuality`. Money entries add `value`. Currency and rep entries add a pre-rendered `suffix`, plus `currencyID` or `factionName`. Pushing an entry whose `key` matches an existing one merges them: counts or values add up and the timer restarts.

## Testing

Run `luajit tests/run_tests.lua` (42 tests at the time of writing). It covers parsing, merging, expiry, hovering, blacklisting, sorting, highlighting, Auctionator prices, test mode, the options window and the loot-window cases.
