# JiAddons: WoW Forever addon development

This folder holds all of Ji's World of Warcraft: **Forever** addon projects, plus the shared code and tooling they use. Read this file before working on any addon here. When you learn something new about the platform, add it to the knowledge log at the bottom.

## Layout

```
JiAddons/
  CLAUDE.md            this file: platform knowledge + conventions
  shared/              reusable Lua modules, embedded into every addon (source of truth)
  tools/               mock_wow.lua, harness.lua, sync-shared.sh, package.sh, new-addon.sh
  template/            skeleton used by tools/new-addon.sh
  <Project>/           one folder per addon project, e.g. JiLoot/
    <Addon>/           the folder that gets copied into Interface/AddOns
      <Addon>.toc
      Shared/          GENERATED copies of shared/*.lua; never edit these by hand
      *.lua
    tests/run_tests.lua
    dist/              built zips (git-ignored)
    README.md, CLAUDE.md (project-specific notes)
```

Projects:
- **JiLoot** is a loot frame (a port of the "Loot Frame" WeakAura) that also hides Blizzard's loot window while auto-looting. See `JiLoot/CLAUDE.md`.
- **JiUnitFrames** has Nurfed-style unit frames (a port of the 1.12.1 Nurfed UnitFrames look) built around Forever's secret health values. See `JiUnitFrames/CLAUDE.md`.
- **JiJournal** splits Forever's combined map and quest log into a Leatrix Maps-style world map (a restyled `WorldMapFrame`) and a WideQuestLogPlus-style quest log. See `JiJournal/CLAUDE.md`.
- **JiCombatFont** lets you choose the fonts for outgoing damage (the numbers above targets) and incoming damage (Blizzard's scrolling combat text). See `JiCombatFont/CLAUDE.md`.
- **JiCastBar** replaces the player's and target's cast bars with the ten styles of Elva's cast bar WeakAuras. See `JiCastBar/CLAUDE.md`.
- **JiBar** is a FuBar port with FuBar's plugins (micro menu, durability, honour, clock, quests, money, transporter, XP, performance, custom menu): configurable bars, and plugins dragged into place while unlocked. See `JiBar/CLAUDE.md`.

## Workflow

| Task | Command (run from `JiAddons/`) |
| --- | --- |
| New addon | `tools/new-addon.sh JiThing`: scaffolds `JiThing/`, syncs shared code, runs its tests |
| After editing `shared/` | `tools/sync-shared.sh`, then run every project's tests |
| Run a project's tests | `luajit JiLoot/tests/run_tests.lua` |
| Syntax-check a file | `luajit -bl path/to/file.lua >/dev/null` |
| Build a release zip | `tools/package.sh JiLoot`: syncs, runs tests, zips `<Addon>/` into `<Project>/dist/` |

- `luajit` (Lua 5.1-compatible) comes from Homebrew: `brew install luajit`. There is no plain `lua` on this machine.
- Nothing here can render WoW frames. The tests catch logic and API-usage errors, not layout. Ask Ji to check anything visual in game, and say what wasn't verified in game.
- Installing for testing: copy `<Project>/<Addon>/` into `World of Warcraft/_classic_beta_/Interface/AddOns/`. **New folders, new files and TOC changes need a full client restart**; `/reload` only reloads existing Lua.

## Shared modules (`shared/`)

Every file starts with `local addonName, ns = ...` and attaches to the addon's private `ns`. Embedded copies in different addons therefore never collide, and no LibStub is needed. Load them first in the TOC, in this order: `Shared\Util.lua`, `Shared\Compat.lua`, `Shared\Text.lua`, `Shared\Events.lua`, `Shared\Widgets.lua`.

| File | Provides |
| --- | --- |
| Util.lua | `ns.DeepCopy`, `ns.CopyDefaults`, `ns.LoadSavedVariables(globalName, defaults)`, `ns.ResetSavedVariables(globalName, defaults, keepKeys)`, `ns.Print(...)` (prefixes `ns.title`) |
| Compat.lua | `ns.IsSecret(v)`, `ns.SafeString(v)`, `ns.IsAddOnLoaded`, `ns.GetAddOnMetadata`, `ns.GetItemInfo`, `ns.GetItemInfoInstant`, `ns.GetItemCount`, `ns.GetItemStats`, `ns.GetDetailedItemLevel`, `ns.QualityColor(q)` → r, g, b, hex |
| Text.lua | `ns.ColorHex`, `ns.Colorize`, `ns.FormatMoney(copper, digitHex, {icons, hideSmall})`, `ns.Truncate` (UTF-8 safe), `ns.VisibleLength`, `ns.FormatToPattern`, `ns.MatchFormat`, `ns.CompileFormats`, `ns.ExtractItemLink` |
| Events.lua | `ns:RegisterEvent(event, fn)` (pcall-protected, returns false for unknown events), `ns:UnregisterEvent`, `ns:OnLoad(fn)` (runs at this addon's ADDON_LOADED), `ns.eventFrame` |
| Widgets.lua | `ns.Widgets`: `NewSet(onChange)` with `:Checkbox/:Slider/:Cycle/:Input/:ColorSwatch/:Refresh`; `NewLayout(content, width)` with `:Header/:Note/:Row`; `CreateWindow{name,title,width,height,onShow}`; `RegisterSettingsPanel{title,description,icon,open,toggle}` (Options → AddOns page and addon compartment); `Button`, `Font`, `Backdrop`, `NewFrame`, `AttachTooltip`, `OpenColorPicker` |

Rules:
- Only put code in `shared/` if it doesn't depend on any one addon. The only `ns` fields shared code reads are `ns.title` and `ns.db.debug`.
- Change `shared/`, run `tools/sync-shared.sh`, then run **all** projects' tests. Adding a new shared file means adding it to every TOC; the sync script warns when a TOC is missing one.
- Extend `tools/mock_wow.lua` when an addon starts using an API the mock lacks. The harness loads `.lua` files from the TOC and, from `.xml` files, only `<Font>` definitions (as global mock font objects with `_xml` holding the attributes). Keep the mock generic, not addon-specific. It covers units (`M.units`, with `.powers[type] = { cur, max }` for non-displayed power), auras, curves, secure templates and state drivers, secret mode (`M.secrets`), `hooksecurefunc` and CVars, the quest log (`M.questLog`, `QuestInfo_Display`) and a reduced `WorldMapFrame`. It also covers string widths, opt-in anchor geometry (`M.geometry`), the cursor, `MenuUtil` menus recorded in `M.menu` (`M.FindMenu`, `M.ClickMenu`), time (`M.fixedTime`, `M.gameTime`), XP and the watched faction, durability and repairs, spells, cooldowns and power costs (`M.spellCosts`), PvP stats, and casting (`M.units[u].cast`/`.channel`, duration objects, secret for units other than player and pet). `RegisterUnitEvent` filters `H.Fire` by the first argument, and `M.refuseTimers` makes `StatusBar:SetTimerDuration` throw. Panel toggles like `ToggleCharacter` record their calls in `M.calls`. `Show`/`Hide` fire `OnShow`/`OnHide` when the state changes, and `IsVisible` checks the parents, like the client. Note that the mock answers *any* capitalised method or field with a no-op function, so check `type(x) == "table"` rather than truthiness when probing Blizzard objects.

## WoW Forever platform facts

Sources: third-party guides (wowforeverguides.com/addons, foreverchanges.pro/addons, checked 2026-09-28) and in-game confirmation from Ji where noted. Anything unverified could change with patches.

- **Client:** Forever runs the modern retail (Midnight-era) client and UI engine, not the Classic client. Content is vanilla-based (level cap 60) plus new Forever content. It launches on 2026-11-04; the beta build was 1.60.1.69913 / 70009.
- **TOC:** `## Interface: 16001`. *Verified in game: JiLoot loads with it.* If a patch bumps the number, addons show as out of date until "Load out of date AddOns" is ticked, or the TOC is updated.
- **AddOns folder:** during the beta this is `World of Warcraft/_classic_beta_/Interface/AddOns/`. CurseForge files it under the game version "Forever (1.60.1)".
- **Game detection:** `WOW_PROJECT_ID` returns `1` (the retail value), so don't use it to detect Forever. Use capability checks, or `select(4, GetBuildInfo())`.
- **Addon ecosystem:** WeakAuras does **not** exist on Forever (it was never updated for Midnight's restrictions), which is why standalone ports like JiLoot exist. Auctionator works; TradeSkillMaster isn't available. Questie, AtlasLoot Classic Forever and similar addons have Forever versions.
- **Midnight's addon restrictions ("disarmament"):**
  - **Secret values:** unit data (health, names, sometimes booleans) and some event payloads arrive as secret values. `type()` still reports "number" or "string", but arithmetic, comparison and string operations throw errors. Always guard with `ns.IsSecret(v)` / `ns.SafeString(v)`, which wrap `issecretvalue`, before using event arguments, and skip the event when the payload is secret.
  - **No combat log:** `COMBAT_LOG_EVENT_UNFILTERED` and `CombatLogGetCurrentEventInfo` are unavailable, so no custom damage meters, and no addons that make combat decisions. Blizzard provides its own damage meter.
  - **Restricted functions:** `ChatFrame_OpenChat`, `ChatEdit_ActivateChat` and `C_SuperTrack.SetSuperTrackedUserWaypoint` are restricted. Don't write secure attributes onto Blizzard unit frames. Check `InCombatLockdown()` before touching protected frames and defer the work to `PLAYER_REGEN_ENABLED`. In the beta, secure snippets (click-casting, action-bar paging) are broken, and blocked protected calls can fail silently.
- **Removed globals** (build 69913): `GetSpellInfo` (use `C_Spell.GetSpellInfo`, which returns a table), `GetItemInfo` (use `C_Item.GetItemInfo`), `GetSpellBookItemName`, `GetNumTalentTabs`, `GetTalentInfo`, `GetNumSkillLines`. `IsAddOnLoaded` and `GetAddOnMetadata` now live under `C_AddOns`. Always go through the `ns.*` compat wrappers.
- **Lua:** Lua 5.1, modified. There's no `goto`, `//`, bitwise operators or `_ENV`; use the `bit` library for bit operations. There's no `require`, `dofile`, `loadfile`, `io` or `os`. **luajit accepts `goto`, but the game does not**, so never use it.
- **Saved variables:** they only exist from `ADDON_LOADED` onwards, never at file scope. (A beta bug where saved variables failed to restore was fixed in build 70009.)

## Coding conventions

- Every file starts with `local addonName, ns = ...` (or `local _, ns = ...`). Globals are limited to the `SavedVariables`, `SLASH_*`/`SlashCmdList` entries and named frames (`<Addon>OptionsFrame`, anchors).
- Settings live in `ns.defaults`. Load them with `ns.LoadSavedVariables("<Addon>DB", ns.defaults)` inside `ns:OnLoad`.
- Register events through `ns:RegisterEvent`. It's pcall-protected, because `RegisterEvent` throws on events the client doesn't know about.
- Never assume an API exists. Check `C_X and C_X.Func`, fall back to the old global, and cope with nil.
- Parse chat messages with Blizzard's localised global format strings (`ns.CompileFormats({{"LOOT_ITEM_SELF_MULTIPLE"}, ...})`), never with English text. Put the more specific `_MULTIPLE` formats first; CompileFormats already sorts longest-first.
- UI:
  - Call `fs:SetFont(...)` (or `W.Font`) **before** `SetText`.
  - Pass the `BackdropTemplate` template to any frame that needs `SetBackdrop`.
  - Prefer the shared widgets over Blizzard templates. `UIDropDownMenu`, `OptionsSliderTemplate` and `InputBoxTemplate` are deprecated or moved in the modern client.
- **Lua gotcha:** a multi-return call only expands when it's the *last* argument. In `f(a, Opt("x"), fmt)`, `Opt` passes only its first return value. This caused a real bug in JiLoot's options code.
- Keep comments short and explain *why*. Match the style of the surrounding code.

## Blizzard UI and API knowledge

Blizzard's own UI code is the best reference. Gethe's mirror has a **`forever` branch** with the exact Forever client UI (build 1.60.1.70124 as of 2026-09-30): `https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/<Addon>/...`. The `live` branch is retail. For example, the loot window is at `Blizzard_UIPanels_Game/Mainline/LootFrame.lua`. Read the real code before hooking or overriding any Blizzard frame.

- Forever is game type **`camelot`** in the mainline family. TOC lines tagged `[AllowLoadGameType camelot]` and the `Camelot/` folders hold Forever-only overrides.
- `Blizzard_APIDocumentationGenerated/*.lua` on that branch documents every API, including its secret rules: `SecretReturns`, `SecretWhen...` predicates, and `SecretArguments = "AllowedWhenTainted"` (addons may pass secrets) vs `"AllowedWhenUntainted"`/`"NotAllowed"` (addons may not). Grep it before relying on an API. `https://api.github.com/repos/Gethe/wow-ui-source/git/trees/forever?recursive=1` lists all files.

- **Loot window:** `LootFrameMixin:OnHide()` calls `CloseLoot()`, so hiding `LootFrame` mid-loot aborts the looting. To keep it out of sight, use `LootFrame:SetAlpha(0)` and restore it on `LOOT_CLOSED`. `LOOT_READY(autoLoot)` fires before `LOOT_OPENED(autoLoot, isFromItem)`.
- **Loot slot API:** `GetNumLootItems`, `GetLootSlotInfo(i)` (the 6th return is `locked`, meaning roll or master loot), `GetLootSlotType(i)` (`Enum.LootSlotType` Item=1, Money=2, Currency=3), `GetLootSlotLink`, `LootSlotHasItem`, `LootSlot(i)`.
- **Items:**
  - `C_Item.GetItemInfo` returns nil until the item is cached. Call `C_Item.RequestLoadItemDataByID(id)` and retry, or wait for `GET_ITEM_INFO_RECEIVED`.
  - Useful returns: 3 quality, 9 equipLoc, 10 icon, 11 sellPrice, 12 classID and 14 bindType. `Enum.ItemBind.OnAcquire` (1) means bind on pickup.
  - Class IDs: 2 weapon, 4 armor, 12 quest.
- **Item links:** the modern client colours links as `|cnIQ4:|Hitem:...|h[Name]|h|r` (quality-coded) rather than `|cffa335ee`. Match `|c[^|]*` for the colour, or use `ns.ExtractItemLink`.
- **Loot chat:** `CHAT_MSG_LOOT(msg, ..., playerName=arg5)`. The player name may be secret, so match only the self format strings: `LOOT_ITEM_SELF(_MULTIPLE)`, `LOOT_ITEM_PUSHED_SELF(_MULTIPLE)`, `LOOT_ITEM_CREATED_SELF(_MULTIPLE)`, `LOOT_ITEM_BONUS_ROLL_SELF(_MULTIPLE)` and `LOOT_ITEM_REFUND(_MULTIPLE)`.
- **Boss loot:** `ENCOUNTER_LOOT_RECEIVED(encounterID, itemID, itemLink, quantity, playerName, className)` also reports boss loot. De-duplicate it against the chat message.
- **Money:** `PLAYER_MONEY` has no payload, so diff `GetMoney()` against the value snapshotted at `PLAYER_ENTERING_WORLD`.
- **Currency:** `CURRENCY_DISPLAY_UPDATE(currencyID, quantity, quantityChange, gainSource, destroyReason)`. Info comes from `C_CurrencyInfo.GetCurrencyInfo(id)`: `.name`, `.iconFileID`, `.quantity`, `.maxQuantity`, `.totalEarned`, `.useTotalEarnedForMaxQty`, `.quality`.
- **Reputation:**
  - Chat: `CHAT_MSG_COMBAT_FACTION_CHANGE`, matched with the `FACTION_STANDING_INCREASED/DECREASED` formats and their `_ACH_BONUS`, `_BONUS`, `_GENERIC` and `_ACCOUNT_WIDE` variants.
  - Data: `C_Reputation.GetNumFactions` / `GetFactionDataByIndex(i)` return `.name`, `.factionID`, `.reaction`, `.currentStanding`, `.currentReactionThreshold`, `.nextReactionThreshold`, `.isHeader` and `.isHeaderWithRep`.
  - Collapsed headers hide factions; `C_Reputation.ExpandAllFactionHeaders()` reveals them.
- **Honor (classic-style):** `CHAT_MSG_COMBAT_HONOR_GAIN`, matched with `COMBATLOG_HONORGAIN`, `COMBATLOG_HONORGAIN_NO_RANK` and `COMBATLOG_HONORAWARD`. Honor may instead arrive as a currency (`Constants.CurrencyConsts.HONOR_CURRENCY_ID`).
- **Settings:** `Settings.RegisterCanvasLayoutCategory(panel, name)` + `Settings.RegisterAddOnCategory(category)`. The addon compartment uses `AddonCompartmentFrame:RegisterAddon{text, icon, func, notCheckable}`.
- **Colour picker:** `ColorPickerFrame:SetupColorPickerAndShow{r, g, b, hasOpacity, swatchFunc, cancelFunc}`.
- **Auctionator:** `Auctionator.API.v1.GetAuctionPriceByItemLink(callerID, link)` returns copper or nil.

## Porting WeakAuras

Wago has a JSON data API that returns an aura's metadata and full source without a browser:
- `https://data.wago.io/lookup/wago?id=<id>` gives the description, versions and changelog, comments and screenshot URLs.
- `https://data.wago.io/lookup/wago/code?id=<id>` returns `{json: "<aura table as JSON>"}`. In the aura table, `c` holds the child auras and `d` the group. Each child carries `actions.init.custom`, `triggers["1"].trigger.custom` (TSU functions), `customText`, `authorOptions` (the user settings), `config` (defaults), `conditions` and `subRegions` (layout).

Rebuild the aura's behaviour natively rather than emulating WeakAuras. Map `aura_env.config` to `ns.defaults`, the TSU `allstates` to a list of entries, and `authorOptions` to the widget set.

## Knowledge log

Add new findings here: dated, with the source, and marked **verified** (confirmed in game) or **unverified** (docs or guesses). Move a finding up into the sections above once it's well established.

- 2026-09-28 **verified**: JiLoot (interface 16001) loads and works in Forever. The custom widgets (plain CheckButton textures, BackdropTemplate frames, `UIPanelButtonTemplate`, `UIPanelCloseButton`) render correctly, and CHAT_MSG_LOOT, money, currency and reputation parsing work. (Ji: "Everything works and looks good".)
- 2026-09-28 **unverified**: hiding the loot window during auto-loot (the LootFrame alpha trick plus `LootSlot` on `LOOT_READY`) hasn't been confirmed in game yet.
- 2026-09-28 **unverified**: which chat events Forever marks as secret (e.g. loot messages during boss encounters) is unknown. JiLoot skips secret payloads and falls back to `ENCOUNTER_LOOT_RECEIVED`.
- 2026-09-30 **unverified** (Forever API docs, `forever` branch): secret unit data for addons.
  - Always secret: `UnitHealth` (`SecretReturns = true`), `UnitHealthMissing`, `UnitHealthPercent`.
  - Secret in some cases: `UnitHealthMax` for units that aren't player-controlled. `UnitPower`/`UnitPowerMax` for power types not flagged never-secret. `UnitName`, `UnitClass` (localised name), `UnitCreatureType` and `UnitGUID` when unit identity is restricted. Aura data during combat and encounters. For addons this doesn't mean secret fields: the call itself errors (see below).
  - Not secret: `UnitLevel`, `UnitClassification`, `UnitIsDead`, `UnitIsConnected`, `UnitReaction`, `UnitPowerType` and `UnitExists`.
  - Widget setters that accept secrets from addons: `FontString:SetText`, `SetFormattedText` and `SetTextColor`; `StatusBar:SetValue(v, Enum.StatusBarInterpolation.ExponentialEaseOut)`, `SetMinMaxValues` and `SetStatusBarColor`; `Region:SetAlpha` and `SetVertexColor`; `Texture:SetTexture` and `SetTexCoord`.
  - Setters that don't accept secrets: `SetShown`, all `Cooldown:SetCooldown*` and `SetFont`.
  - Curves turn secrets into display values: `C_CurveUtil.CreateCurve()`/`CreateColorCurve()` with `:SetType(Enum.LuaCurveType.Step|Linear)` and `:AddPoint(x, y)`, then `UnitHealthPercent(unit, true, curve)`.
  - JiUnitFrames is built on these rules. `tools/mock_wow.lua` mimics them: `M.secrets = true` makes unit data secret, and the widget setters unwrap it.
- 2026-09-30 **verified** (Ji, in game): `C_UnitAuras.GetAuraDataByIndex` throws "Auras cannot be accessed when secret while tainted by '<addon>'" once auras are secret. Every `C_UnitAuras` getter has `RequiresUnitAuraAccess` with `FailureMode = "Error"`. `C_Secrets.ShouldAurasBeSecret()` and `ShouldUnitAuraIndexBeSecret(unit, i, filter)` say in advance whether a read would fail.
  - The sanctioned way to show auras is `CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")` (`Blizzard_AuraContainer`). Configure it with `:SetUnit(unit)`, `:AddAuraGroup(key, filterString, { maxFrameCount, layout = { elementWidth, elementHeight, elementSpacing, layoutIndex }, initializeFrame = fn(button) })`, `:SetFlowLayoutAnchorPoint`, `:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, ...Up/Down)`, `:SetFlowLayoutMaximumLineSize(px)`, `:SetAuraGroupFilterString`, `:SetAuraGroupEnabled` and `:UpdateAllAuras()`.
  - In `initializeFrame`, create child regions on the button and register them: `SetIcon(texture)`, `SetApplicationCount(fontString)`, `SetDurationCooldown(cooldown)`, `AddDispelTypeTexture(texture, { style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset, showWithoutDispelType = true })` and `AddAuraShownAnimation(animGroup)`. Buttons are access-restricted after creation, and tooltips are built in.
  - Filter strings accept `!` negation, e.g. `HARMFUL|!RAID`.
  - JiUnitFrames uses this (**unverified** in game so far).
- 2026-09-30 **unverified**: Forever's `SecureTemplates.lua` still has `SecureUnitButtonTemplate` with the `target` and `togglemenu` actions, plus `RegisterUnitWatch` and `RegisterStateDriver` (`Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua`). Click bindings (`C_ClickBindings`) sit in front of unit-button clicks.
- 2026-09-30 **unverified**: Forever's `PartyFrame` fills its member frames from `PartyFrame.PartyMemberFramePool` in `OnShow`, so the member frames may not exist at `ADDON_LOADED`.
- 2026-10-11 **unverified** (Forever UI source): the quest log is the mainline `QuestMapFrame`, docked in `WorldMapFrame`. The classic `QuestLogFrame` isn't loaded for camelot.
  - Every "open the quest log" path calls one of three globals: `ToggleQuestLog` (the binding and the micro menu), `OpenQuestLog`, and `QuestMapFrame_OpenToQuestDetails` (objective tracker, quest timers).
  - The map opens small and without the docked log when the CVars are `miniWorldMap = 1` and `questLogOpen = 0`.
  - Giving a frame the attributes `UIPanelLayout-defined = true` and `UIPanelLayout-area = nil` takes it out of the panel layout: `ShowUIPanel` then just shows it.
  - `MapCanvasMixin:SetMouseWheelZoomMode(MAP_CANVAS_MOUSE_WHEEL_ZOOM_BEHAVIOR_NONE)` disables wheel zoom, and `ScrollContainer:InstantPanAndZoom` doesn't clamp the scale.
  - Blizzard's own map coordinates come from the `worldMapShowPlayerCoords`/`worldMapShowCursorCoords` CVars.
  - `C_QuestLog` getters return no secret values. JiJournal is built on these findings.
- 2026-10-11 **verified** (Ji, in game, JiJournal 0.1.0): the restyled `WorldMapFrame` works. Removing it from the panel layout, hiding `BorderFrame`, re-anchoring the `ScrollContainer` and wheel zoom past Blizzard's zoom levels all behave as intended. Questie's map button (Krowi_WorldMapButtons) shows in the canvas's top-right corner.
  - The quest log takeover failed: L still opened the map. The likely cause is that `Blizzard_WorldMap` loads after addons and redefines `ToggleQuestLog` (**unverified**; 0.1.1 re-applies the takeover after Blizzard addons load).
- 2026-10-11 **unverified** (Forever UI source and API docs): combat text fonts.
  - `DAMAGE_TEXT_FONT` (set per locale in `Blizzard_Fonts_Shared/Shared/GameFonts.xml`) is the font of the numbers above targets. Addons can overwrite it up to their `ADDON_LOADED`; the client reads it when the world loads, so later changes need a relog. Their size is the `WorldTextScale` CVar (not referenced in the UI source, so its existence on Forever is unverified).
  - The scrolling combat text around the player (`Blizzard_CombatText`, load on demand) draws with `CombatTextFont`. `C_CombatText.GetCurrentEventInfo` has `SecretReturns`, so don't call into or modify Blizzard's combat text code (taint).
  - There's no letter-spacing (tracking) API: `Font:SetSpacing` is line spacing. JiCombatFont bakes spacing into font copies with fontTools instead.
- 2026-10-13 symptom **verified** (Ji, in game), cause **unverified**: after `CombatTextFont:SetFont(...)`, incoming combat text showed "E N T E R I N G  C O M B A T" and "- 3 4" in every font, including Blizzard's own file. The likely cause is that `SetFont` drops `fixedSize`, which breaks text that Blizzard sizes with `SetTextHeight`. `CombatTextFont` inherits `SystemFont_World` (`height="64" filter="true" fixedSize="true"`), and `CombatText.lua` calls `SetTextHeight(25)` per message. (An earlier log entry blamed a space in secret text; that was wrong.)
  - The API docs hint at this: `Font:GetFontHeight` "Return is either in uiUnits or internal height due to fixedHeight"; `SetFontHeight` "Preserves all flags".
  - `fixedSize` can only be set in XML. To change such a font's file, define an XML `<Font fixedSize="true" ...>` and re-parent with `fontObject:SetFontObject(yours)` (**unverified**; JiCombatFont 0.5).
- 2026-10-11 **unverified** (Forever UI source): taint traps for addons that open Blizzard panels.
  - The game menu builds its buttons in `GameMenuFrameMixin:OnShow` → `InitButtons`, so opening it from addon code taints Log Out, Exit and Edit Mode.
  - `MainMenuMicroButtonMixin:OnClick` only acts when `self:IsMouseOver()`, so neither a Lua call nor a secure `type=click` delegate opens it.
  - Micro buttons reset their own alpha in `OnEnable`/`OnDisable` (1 / 0.5).
  - `ChatEdit_InsertLink`/`ChatEdit_GetActiveWindow` only exist as deprecated aliases (`Blizzard_DeprecatedChatInfo`, behind the `loadDeprecationFallbacks` CVar). Use `ChatFrameUtil.InsertLink`/`GetActiveWindow`. `GetCoinTextureString` is `C_CurrencyInfo.GetCoinTextureString`.
  - JiBar docks Blizzard's real micro buttons over its icons and uses a UIParent-parented secure overlay for the hearthstone. See `JiBar/CLAUDE.md`.
- 2026-10-11 **unverified** (Forever API docs): PvP has `GetPVPSessionStats`/`GetPVPYesterdayStats` (kills only), `GetPVPLifetimeStats`, `UnitHonor`/`UnitHonorLevel`, `GetPVPTimer`/`IsPVPTimerRunning`, but no classic rank or weekly honour functions (`GetPVPRankInfo`, `GetPVPThisWeekStats`...). `C_Spell.GetSpellCooldown` is `SecretWhenCooldownsRestricted`.
- 2026-10-12 **verified** (Ji, in game, JiBar 0.1.0): opening a Blizzard UI panel from addon code (`ToggleCharacter` and the like) taints the panel manager for the rest of the session.
  - `ShowUIPanel` → `FramePositionDelegate:SetAttribute` → the delegate stores `self.left`/`self.center` from tainted code. After that, even the secure C key binding opens the character sheet tainted, and `TextStatusBar` errors comparing secret health: "attempt to compare a secret number value (execution tainted by '<addon>')".
  - Rule: never open or close Blizzard windows from addon code. Click a Blizzard button through a `SecureActionButtonTemplate` overlay (`type=click`, `clickbutton`), or reparent the real micro button. See `JiBar/CLAUDE.md`.
- 2026-10-12 **verified** (Ji, in game, JiBar 0.1.1): an addon's `SecureActionButtonTemplate` registered only for `AnyUp` does nothing on mouse clicks (the hearthstone overlay didn't cast). The cause is read from Forever's `SecureTemplates.lua` and the fix is **unverified** until JiBar 0.1.2 is tested: `SecureActionButton_OnClick` treats addon clicks as key presses, so it follows the `ActionButtonUseKeyDown` CVar (default on) and acts only on down. Set the attribute `useOnKeyDown = false` (act on release), or register `AnyUp` and `AnyDown`.
- 2026-10-13 **unverified** (Forever API docs and UI source, `forever` branch): cast bars.
  - `UnitCastingInfo`/`UnitChannelInfo` and the `UNIT_SPELLCAST_*` events are `SecretWhenUnitSpellCastRestricted`: secret unless the unit is the player or their pet, or the spell is flagged otherwise. `C_Secrets.ShouldUnitSpellCastingBeSecret(unit)` says so in advance. `UNIT_SPELLCAST_INTERRUPTIBLE`/`NOT_INTERRUPTIBLE` aren't secret.
  - `UnitCastingDuration`/`UnitChannelDuration` return a `LuaDurationObject` (`GetRemainingDuration`, `GetTotalDuration`, `HasSecretValues`, ...). Only `UnitCastingDuration` is marked `SecretReturns`. `StatusBar:SetTimerDuration(duration, interpolation, Enum.StatusBarTimerDirection)` lets the client run a bar from it.
  - `Region:SetAlphaFromBoolean`/`SetVertexColorFromBoolean` take secret booleans.
  - Blizzard's own cast bar (`Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua`) still does `GetTime` arithmetic, which works only because its code is untainted.
  - The player bar is `PlayerCastingBarFrame`, a bottom-managed frame that edit mode re-parents and re-anchors. The target bar is `TargetFrameSpellBar`. Hide both with `UnregisterAllEvents()`: `Hide()` and `SetAlpha(0)` are taint traps or get undone (see `JiCastBar/CLAUDE.md`).
  - JiCastBar is built on these findings.
- 2026-10-14 **unverified** (Forever API docs): mana for the five second rule. `UnitPower`/`UnitPowerPercent` are `SecretWhenUnitPowerRestricted`: secret for power types not flagged never-secret, so the player's own mana may be secret (`C_Secrets.ShouldUnitPowerBeSecret` says in advance). `C_Spell.GetSpellPowerCost(spellID)` has no secret returns and gives `{type, cost, minCost, costPercent, requiredAuraID, hasRequiredAura}` per power type. `UNIT_SPELLCAST_SUCCEEDED` isn't secret for the player. Whether Forever keeps vanilla's 2-second mana ticks is unknown. JiUnitFrames' mana spark is built on these.
- 2026-10-14 **unverified** (DruidForeverManabar 1.0.4, a druid mana addon said to work on Forever): `GetShapeshiftFormID()` gives 1 cat, 3 travel, 4 aquatic, 5 bear/dire bear. It reads the mana percentage through `UnitPowerPercent("player", Enum.PowerType.Mana, false, CurveConstants.ScaleTo100)` and avoids arithmetic on mana, which suggests the player's mana can be secret. Its five second rule goes only by spell costs, cached per castGUID at `UNIT_SPELLCAST_SENT` and checking `cost`, `minCost`, `costPercent` and `costPerSec`.
