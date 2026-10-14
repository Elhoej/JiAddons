# JiCombatFont

Picks the font and letter spacing for outgoing and incoming combat text from the `.ttf` files in `Media/` (from pfUI-fonts), plus the outgoing size. Platform knowledge, shared code and tooling are described in `../CLAUDE.md`.

## Files (`JiCombatFont/`)

- `Core.lua`: `ns.FONTS` (key = file name without `.ttf`; `"default"` = Blizzard's font), `ns.SPACINGS`, `ns.defaults` (`outgoing`, `incoming`, `outgoingSpacing`, `incomingSpacing`), saved variables (`JiCombatFontDB`), applying the fonts, and `/jcf`.
  - **Outgoing** sets `DAMAGE_TEXT_FONT` at our `ADDON_LOADED`. Saved variables aren't available at file scope, and ADDON_LOADED is still before the world loads. The client reads it when the world loads, so changes need a relog. `ns.OutgoingPending()` drives the "relog" note. The outgoing size is the `WorldTextScale` CVar (not saved by the addon; the client keeps it). If the CVar doesn't exist, the slider is replaced by a note.
  - **Incoming** re-parents `CombatTextFont` with `SetFontObject` onto one of the font objects in `IncomingFonts.xml`, at our ADDON_LOADED, when `Blizzard_CombatText` loads and at `PLAYER_LOGIN`. "Blizzard default" restores the original parent (`SystemFont_World`).
  - **Never call `CombatTextFont:SetFont`.** `CombatTextFont` inherits `SystemFont_World` (`Blizzard_Fonts_Shared/Shared/Fonts.xml`): `height="64" filter="true" fixedSize="true"`. `CombatText.lua` then calls `SetTextHeight(25)` on every message (crits 30 to 60). `SetFont` drops `fixedSize`, after which the letters keep the spacing of the font's own height but are drawn at 25: "E N T E R I N G  C O M B A T", "- 3 4". Versions 0.1 to 0.4 did this. `fixedSize` can only be set in XML, hence the generated font objects.
  - There's no incoming size setting: the drawn size comes from Blizzard's `SetTextHeight`.
- `IncomingFonts.xml`: GENERATED. One `<Font name="JiCombatFont_<key>[_<p|m><n>]">` per font and spacing, with `SystemFont_World`'s attributes.
- `Options.lua`: two font lists side by side, each row drawn in its own font, with a sample above, then spacing sliders and the outgoing size.
- `Media/`: the fonts. `Spaced/<key>_<p|m><n>.ttf` are copies with n% of the em added to every non-zero advance width (there's no letter-spacing API; `SetSpacing` is line spacing).
- `../tools/make_font_variants.py` builds `Media/Spaced/` and `IncomingFonts.xml` with fontTools. The copies drop `hdmx`/`LTSH`/`VDMX` and hinting, and are subset to Latin, Greek and Cyrillic. `tests/run_tests.lua` checks that the fonts, the copies, the font objects, `ns.FONTS` and `ns.SPACINGS` match.

## Notes

- `DAMAGE_TEXT_FONT` is set in `Blizzard_Fonts_Shared/Shared/GameFonts.xml`.
- There's deliberately no "test" button that calls `CombatText:AddMessage`: running addon code inside Blizzard's combat text would taint it, and it handles secret values (`C_CombatText.GetCurrentEventInfo` has `SecretReturns`). For the same reason, don't change `CombatTextConstants`.
- Verified in game: fonts change (0.1 to 0.4). The fixed-size font objects (0.5) are **unverified**.
