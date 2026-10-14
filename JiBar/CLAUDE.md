# JiBar: project notes

Read `../CLAUDE.md` first. It covers platform facts, shared code and tooling.

## Goal

A port of Ji's skinned FuBar 2.0 setup (1.12.1, source in `~/Documents/FuBarAddon`) with the same plugins: MicroMenuFu, DurabilityFu, HonorFu, ClockFu, QuestsFu, MoneyFu, TransporterFu, FuXPFu, PerformanceFu and CustomMenuFu, plus FuTextures' skins. Ji's reference screenshot is a single bottom bar: micro menu on the left; durability, honour, clock (big font), quests and money centred; transporter, XP and performance on the right. Differences Ji asked for: the XP plugin shows text instead of FuXP's icon, and the bar is highly configurable, with plugins placed by dragging while the bars are unlocked.

## Files (`JiBar/`)

- `Core.lua`: `ns.FONTS`/`OUTLINES`/`SKINS`/`STRATAS`, `ns.defaults` (`JiBarDB`), colour and format helpers (`ThresholdColor` is Crayon's red-to-green scale, `FormatCoins`, `FormatDuration`, `Today`), `ns.OutOfCombat`, chat helpers, startup and `/jibar` (`/jb`).
- `Plugin.lua`: the plugin base (`ns.RegisterPlugin`), the registry (`ns.Plugins`: placing, moving, enabling, the one-second tick) and the secure overlay.
- `Bar.lua` (`ns.Bars`): bars, layout, skins, auto-hide, hide in combat, unlocked mode (dragging plugins and bars, edge resizing).
- `Tip.lua` (`ns.Tip`): the Tablet-style tooltip.
- `Menu.lua` (`ns.Menu`): right-click menus through `MenuUtil`, and the renderer for plugin option lists.
- `Options.lua` (`ns.Options`): the options window.
- `Plugins/*.lua`: one file per plugin.
- `Media/`: FuBar's font (`HomizioBold.ttf`), its micro menu and plugin icons (`Micro/`, `Icons/`), the background skins (`Skins/`, FuBar's default plus FuTextures) and FuXP's bar textures (`XP/`). All TGAs were re-encoded as uncompressed 32-bit (several originals were RLE). The `*2.tga` hover copies were dropped: they're the same icons in purple, which the hover tint reproduces.

## How it fits together

- **Plugins** are declared with `ns.RegisterPlugin{ id, title, icon, place = { bar, side, order }, defaults, enabledByDefault }` and implement `UpdateText`, `OnTooltip(tip)`, `OnClick`, `OnMenu(root)`, `OnTick`, `OnEnable` as needed (see the header of `Plugin.lua`). `plugin.options` is a declarative list (toggle, select, range, color, execute, header) rendered both in the right-click menu (`Menu:AddOptions`) and the options window (`Options:BuildPlugin`). Ranges show `presets` in the menu.
- **Settings:** `db.plugins[id]` holds `enabled, bar, side, order, showIcon, showText, fontSize (0 = global), customColor, color` plus the plugin's own defaults, which win over the common ones (the clock's 25 px font).
- **Placement:** `bar.sides.LEFT/CENTER/RIGHT` are ordered lists (visual left to right). `Bars:Layout` places them by absolute x offsets: left from the left padding, right ending at the right padding, centre centred. Plugin widths are cached in `p.width` and re-measured by `Plugin:CheckWidth()` when the text changes; a width change relayouts that bar.
- **Unlocked mode:** `Bars:FindDropTarget` collects the gaps between plugins on every side of every bar and drops the plugin at the nearest one. Dragging a bar snaps it to the top or bottom edge within 12% of the screen, otherwise it floats. The yellow edge handles resize `width`/`x` (fractions of the screen).
- **Skins** tile horizontally (`SetTexture(file, "REPEAT", "CLAMP")`, u = width / 256) and crop vertically. Bordered FuTextures skins have the border in the top rows, so top bars flip the texture to keep the border on the edge facing the middle of the screen.
- **Icons and text:** JiBar's own icons are cropped to their visible columns (`ns.ICON_BOUNDS`, measured from the TGAs' alpha). The text then starts `db.iconGap` (6.5 px) after the icon's visible edge on every plugin. That was Honor's gap in 0.1.2: 3 px plus its icon's 3.5 px transparent margin. Blizzard textures (method or faction icons) aren't cropped. Multi-part texts go through `ns.Join`, which uses `db.separator` (default `•`, present in Homizio as glyph 130), escapes `|` and skips empty parts.
- **Tooltip:** rebuilt every second while open. Lines may have `onClick`; then the tooltip takes the mouse and stays open for 0.15 s after leaving the plugin so the mouse can reach it.

## Protected actions and taint

- **Never open Blizzard windows from addon code.** 0.1.0 called `ToggleCharacter`, `ToggleFriendsFrame` and similar from plugin clicks, and that broke the character sheet (Ji, in game). `ShowUIPanel` hands the frame to `FramePositionDelegate` through `SetAttribute`, and the delegate stores it in `self.left`/`self.center`. Written from tainted code, those fields taint every later open, even through the C key binding. `CharacterFrame:OnShow` → `ShowStatusBarText` then compares the player's secret health and errors: "attempt to compare a secret number value (execution tainted by 'JiBar')". Only a `/reload` clears it.
- **Secure overlays** (`Plugin:CreateSecureOverlay{ region, onEnter, onLeave }`, `Plugin:SetClickTarget`): an invisible `SecureActionButtonTemplate` button parented to **UIParent**, not to the bar. A protected child would make the bar protected, and then it couldn't be laid out in combat. It's registered for `AnyUp` with the attribute `useOnKeyDown = false`. Without that attribute an addon's secure button follows the `ActionButtonUseKeyDown` CVar (on by default) and acts only on key down, so with an up-only registration it never fires; 0.1.1 had that bug, and no secure click worked. It's placed by absolute coordinates over its region after each layout, out of combat only (`Plugins:SyncOverlays`, deferred to `PLAYER_REGEN_ENABLED`), and hidden while unlocked. Right clicks run `PostClick`, which opens the menu. Attributes change only out of combat (`ns.OutOfCombat`).
  - Window-opening plugins declare `clickTargets`. The overlay then `type=click`s a Blizzard button (`SECURE_ACTIONS.click` → `delegate:Click()`), so the window opens as Blizzard code:
    - Durability: `CharacterMicroButton`.
    - Honor: `LFDMicroButton`, falling back to `CharacterMicroButton`.
    - Quests: `QuestLogMicroButton`.
    - Clock: `GameTimeFrame`, and with shift, `TimeManagerClockButton`.
    - Money: `MainMenuBarBackpackButton`.
  - Targets are re-applied whenever a `Blizzard_*` addon loads (some are load on demand).
  - Transporter uses `type=item`/`spell` on the same kind of overlay.
- **Micro menu:** icons with a Blizzard micro button **dock** it: the real button is reparented onto the icon (`SetAllPoints`, alpha 0), so a click is a hardware click on Blizzard's button. The game menu needs this: `MainMenuMicroButtonMixin:OnClick` only acts while `self:IsMouseOver()`, so a click delegate does nothing. Its buttons are built in `OnShow`, so a tainted open would also taint Log Out and Edit Mode.
  - Blizzard resets the alpha in `OnEnable`/`OnDisable`, so hooks zero it again.
  - Only buttons the client's micro menu added (`layoutIndex`) and currently shows are docked. Hidden ones (Help, while the shop button is shown) get an overlay instead.
  - Icons without a micro button use overlays: Who/Friends/Raid click `QuickJoinToastButton` (the social window opens on its last tab), Reputation clicks `CharacterMicroButton` (you pick the tab), PvP clicks `LFDMicroButton`, World Map clicks `MinimapCluster.ZoneTextButton`. Their windows' tabs (`CharacterFrameModeTab*` are mouse-up Frames, `FriendsFrameTab*`) can't be selected securely.
  - Hiding an icon undocks its button (reparented to `MicroMenu`, then `Layout`).
- **Quest tooltip clicks** open the quest only through JiJournal's own quest log (not a UI panel). Without JiJournal a click tracks the quest instead, since `QuestMapFrame_OpenToQuestDetails` would open the world map from addon code.
- Hiding bars in combat is fine, because nothing JiBar parents is protected. Overlays get a `[combat] hide; show` state driver instead.

## Forever specifics used

- Honour: `Constants.CurrencyConsts.HONOR_CURRENCY_ID` currency diffs. Without the currency, the `COMBATLOG_HONORGAIN*`/`HONORAWARD` chat formats. Forever's API has `GetPVPSessionStats`, `GetPVPYesterdayStats` (kills only) and `GetPVPLifetimeStats`. There are no classic rank or weekly honour functions, so today's/yesterday's honour and battleground wins/losses (`GetBattlefieldWinner` vs `GetBattlefieldArenaFaction`) are JiBar's own records.
- Chat helpers: `ChatEdit_InsertLink`/`ChatEdit_GetActiveWindow` only exist in `Blizzard_DeprecatedChatInfo`, so JiBar uses `ChatFrameUtil.InsertLink`/`GetActiveWindow` first. Coin icons use `C_CurrencyInfo.GetCoinTextureString`.
- Forever's micro menu (`Blizzard_MicroMenu/Camelot/MicroMenuContainerOverrides.lua`): Character, Profession, Spellbook, Talent, Legacy, QuestLog, Housing, Guild, LFD, Collections, EJ, Help, Store, MainMenu.
- Repair cost per item is read from `C_TooltipInfo.GetInventoryItem(...).repairCost` when present (not in the generated docs, so possibly absent). Otherwise the tooltip shows the last merchant's `GetRepairAllCost()`.

## Not ported

FuBar's Jostle (moving Blizzard frames out of the bars' way: Edit Mode does that now), overflowing plugins onto a new panel, detaching plugin tooltips and attaching plugins to the minimap. Also left out: QuestsFu's quest levels in NPC dialogs and objectives in unit and item tooltips (the modern client shows objectives itself), HonorFu's flag-carrier targeting (protected) and auto release, DurabilityFu's repair popup (auto-repair instead), and MoneyFu's coin pickup on click (opens the bags instead).

## Testing

Run `luajit tests/run_tests.lua` (48 tests). The tests turn on `M.geometry` in the mock, which resolves frame anchors so layout, dragging and the overlay's position can be checked. They also use the mock's `MenuUtil` recorder (`M.menu`, `M.FindMenu`, `M.ClickMenu`) and fake Blizzard buttons (micro buttons, `QuickJoinToastButton`, `MinimapCluster.ZoneTextButton`, `GameTimeFrame`...) created before the addon loads. A test clicks every plugin and icon and fails if any `Toggle*` function was called from addon code. None of the rendering (skins, fonts, tooltip look), docking or secure clicks have been checked in game yet.
