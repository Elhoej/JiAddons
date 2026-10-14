# JiCastBar: project notes

Read `../CLAUDE.md` first. It covers platform facts, shared code and tooling.

## Goal

Port Elva's cast bar WeakAuras (collection wago.io/xeJOxehA8: Sunset, Void, Celestial, Flux, Nebula, Fel, Ember, Galaxy, Sage, Astral) to a native player and target cast bar. The auras are `aurabar` regions with one `Cast` trigger on the player. Their init action is `PlayerCastingBarFrame:UnregisterAllEvents()`. "Elva Party Castbars" (4xELXBnVz) is a separate aura and isn't ported.

The aura source came from the Wago API (`../CLAUDE.md`, "Porting WeakAuras"). The code endpoint redirects, so use `curl -L`, and space the requests out or Cloudflare answers with a challenge page. The collection has no members endpoint; `https://data.wago.io/search?q=Elva+Cast+Bar` finds the auras.

## Files (`JiCastBar/`)

- `Styles.lua`: `ns.LAYOUT` (shared geometry; width and height are only the defaults), `ns.SHADE` and `ns.STYLES`, generated from the aura exports (texture, colours, background, spark, name offset, models).
  - WeakAuras' LibSharedMedia names map as follows:
    - "Solid" is a flat texture.
    - "DGround" is Details!' `bar_background.tga`, a flat 175/255 grey with a 1px top line that the border hides, so it's drawn as the colour × 0.686.
    - "Gradient" (Fel) is a texture whose source wasn't found. It's drawn flat.
    - "Fira Sans Black" is WeakAuras' `FiraSans-Heavy.ttf`, copied to `Media/`.
- `Cast.lua` (`ns.Cast`): `Query(unit)` reads `UnitCastingInfo`/`UnitChannelInfo` and marks whether the values are plain. It also has WeakAuras' time format (`FormatSeconds`: one decimal below the threshold, 9 s for remaining, 60 s for total), name cutting (27 characters, no ellipsis) and `SetTimeText`.
- `Bar.lua` (`ns.Bar`): one bar per unit. The rendering mirrors WeakAuras' `AuraBar.lua` and `SubRegionTypes/Model.lua`. See the comment at the top of the file.
  - `fill` is a clipping frame from the bar's left edge to the progress edge (the fill texture of the active invisible StatusBar). The full-width gradient texture inside it stays put, which is WeakAuras' fgMask behaviour. Channels use `SetReverseFill` and end `fill` at the texture's left edge.
  - Models: each sits in a clipping frame anchored to `fill` (`attach`) or the whole bar. The model itself is anchored to `fill` (`attach` + `stretch`) or the whole bar. They're set up again on every show and whenever a zero-width clip grows, as WeakAuras does. `transform` uses WeakAuras' Dragonflight conversion `SetTransform(vec(t/1000), vec(rad r), -scale/1000)`. `position` uses `SetPosition(z, x, y)` + `SetFacing`.
  - Size: `ApplySettings` sizes the root and the square icon from the settings. Spark heights scale by height / 28, the height Elva's sparks were made for, and spark widths stay as they are. Text size stays at 12.
  - Layering: bar textures < fill < spark/latency < models < border < texts.
  - The INNER_LEFT/INNER_RIGHT text anchors add 2px, as WeakAuras does.
- `Options.lua`: one section per bar. While the window is open the bars preview a sample cast (`ns.optionsOpen`).
- `Core.lua`: defaults (`JiCastBarDB.bars.player/target`; `width` includes the icon, which is `height` wide), `ns.SIZE_LIMITS` for the size sliders, `ns.Apply()`, Blizzard bar hiding, `/jcb` (`unlock`, `lock`, `reset`, `debug`).

## How casts are driven

Player casts are plain values. Target casts are secret (`SecretWhenUnitSpellCastRestricted`), so Lua must not do arithmetic or comparisons on them. `Bar:StartDriver` picks one of three modes, and `/jcb debug` prints which one ran:

- `relative` (plain casts): `valueBar` runs from 0 to the cast's length, with `GetTime() - start` as the value.
- `timer` (secret casts): `timerBar:SetTimerDuration(UnitCastingDuration/UnitChannelDuration(unit))`. The client advances it.
- `absolute` (secret casts, if the timer call throws): `valueBar:SetMinMaxValues(startMs, endMs)` with secrets and `SetValue(GetTime() * 1000)`. This could move in coarse steps if the client keeps bar values as 32-bit floats, which is unverified.

More rules:

- Each mode has its own StatusBar, so a timer left running never fights Lua-set values.
- The time text for secret casts is `SetFormattedText("%.1f || %.1f", duration:GetRemainingDuration(), duration:GetTotalDuration())`. If that throws, the text stays empty for that cast.
- Events are registered with `RegisterUnitEvent`, and every event just re-queries the unit. Payloads (cast GUIDs) may be secret. Re-querying also means a FAILED for a spell queued behind the current cast leaves the bar alone.
- A presence test on cast info uses `type(name) == "nil"`. `type()` is safe on secrets; `==` isn't.
- Plain casts hide 0.5 s past their end if no stop event arrived. Secret casts rely on the events.

## Rules for this addon

- Hide Blizzard's bars only with `UnregisterAllEvents()` (`PlayerCastingBarFrame`, `TargetFrameSpellBar`).
  - `Hide()` on the player bar relayouts the bottom managed frame container (extra action button) under our taint.
  - Edit mode, every cast start and the managed-frame fade-in all reset its alpha.
  - Writing its fields (`SetUnit`, `showCastbar`) taints secure paths that read them later.
  - Unregistering can't be undone safely, so turning the option off needs a /reload.
- Never pass secrets anywhere but widget setters, and never compare them. New elements need a test in secret mode (`M.secrets = true`; the mock makes casts secret for units other than player/pet).
- `ns.db.debug` makes swallowed errors (model setup) print. The tests turn it on and `NoErrors()` fails on them.

## Not verified in game

All of it so far. In particular:

- the frames anchored to the StatusBar texture following the progress, including at zero width and with reverse fill
- the `timer` mode being accepted for target casts
- the duration object text
- what the models look like at these settings
- whether `bonusobjectives-bar-spark` exists (it falls back to the cast bar spark if `C_Texture.GetAtlasInfo` says no)
- that unregistering Blizzard's bars causes no taint
