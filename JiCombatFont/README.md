# JiCombatFont

A World of Warcraft: Forever addon that lets you choose the font and letter spacing of combat text, separately for:

- **Outgoing damage**: the damage and healing numbers above whatever you hit (`DAMAGE_TEXT_FONT`). Font and spacing changes show after you relog. There's also a size slider, which sets the client's `WorldTextScale` and applies at once.
- **Incoming damage**: Blizzard's scrolling combat text around your character (`CombatTextFont`). Changes apply at once. This text only appears when scrolling combat text for self is turned on in the game options. It has no size setting, because Blizzard sets the size of every message itself.

Letter spacing runs from -10% to +30% of the font size. It doesn't apply to Blizzard's default font.

Both default to Galaxy. The 14 fonts come from pfUI-fonts (Galaxy by Iconian Fonts, the rest from Google Fonts), plus Blizzard's default.

## Usage

`/jcf` (or `/jicombatfont`) opens the options, as does Options → AddOns → JiCombatFont. Each font in the lists is drawn in its own face. Click one to pick it.

## Install

Copy the `JiCombatFont` folder (the one containing `JiCombatFont.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Development

```
luajit JiCombatFont/tests/run_tests.lua   # from JiAddons/
tools/package.sh JiCombatFont             # builds dist/JiCombatFont-<version>.zip
```

To add a font, drop the `.ttf` into `JiCombatFont/Media/`, add it to `ns.FONTS` in `Core.lua` (the key is the file name without `.ttf`), and rebuild the generated files:

```
python3 -m pip install fonttools
python3 JiCombatFont/tools/make_font_variants.py   # from JiAddons/
```

The script writes:
- `Media/Spaced/`: a copy of every font per spacing step, with every letter's width changed. WoW has no letter-spacing API.
- `IncomingFonts.xml`: a font object per font and spacing for the incoming text.

Its `STEPS` must match `ns.SPACINGS`. Tests fail if the fonts, the copies, the font objects and the lists get out of sync.
