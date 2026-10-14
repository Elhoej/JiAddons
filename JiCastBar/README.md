# JiCastBar

A World of Warcraft: Forever addon that replaces the player's and the target's cast bars with Elva's cast bars, a collection of ten WeakAuras (wago.io/xeJOxehA8). WeakAuras doesn't run on Forever, so this rebuilds them natively.

Every style has the same layout: 280×28 by default, spell icon on the left, spell name and "remaining | total" time in Fira Sans, and a 2px black border. They differ in colours, spark and the animated spell effects over the bar:

| Style | Fill | Spark | Spell effects |
| --- | --- | --- | --- |
| Sunset | violet → yellow gradient | yellow | 1, on the filled part |
| Void | violet → black gradient, darkened | none | 1, on the filled part |
| Celestial | blue → black gradient | none | 1, on the filled part |
| Flux | violet → light violet gradient | yellow | 2, on the filled part |
| Nebula | cyan → blue gradient, darkened, on dark blue | wide cyan | 1 on the filled part, 1 across the whole bar |
| Fel | green on dark green | wide green glow | 1 on the filled part, 1 across the whole bar |
| Ember | red → yellow gradient | yellow | 1, on the filled part |
| Galaxy | purple → black gradient | none | 1, on the filled part |
| Sage | flat green | none | 1, on the filled part |
| Astral | flat purple, darkened | wide pink | 1 on the filled part, 1 across the whole bar |

Gradients run across the whole bar and the cast reveals them, the way WeakAuras draws them. Channels drain from right to left.

## Usage

`/jcb` (or `/jicastbar`) opens the options, as does Options → AddOns → JiCastBar. For each bar you can set:

- whether it's shown
- the style
- the width (120–600, icon included) and height (12–60). The icon stays square, and the spark grows or shrinks with the height.
- the scale
- whether the spell effects are drawn
- whether Blizzard's bar is hidden

The player bar can also show your latency as a red block at the end of the cast. It's off by default, as in Elva's auras.

While the options are open, both bars show a looping sample cast. Unlock them (button or `/jcb unlock`) to drag them, then `/jcb lock`. `/jcb reset` puts them back. By default the player bar sits where Elva's auras put it, 312px below the screen centre, and the target bar sits 50px above that.

`/jcb debug` prints how each cast is driven, plus any errors setting up the spell effects.

Turning "Hide Blizzard's cast bar" off takes effect after a `/reload`. Blizzard's bars still appear in edit mode.

## Install

Copy the `JiCastBar` folder (the one containing `JiCastBar.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Development

```
luajit JiCastBar/tests/run_tests.lua   # from JiAddons/
tools/package.sh JiCastBar             # builds dist/JiCastBar-<version>.zip
```

The font is Fira Sans Heavy (SIL Open Font License, `Media/FiraSans-LICENSE.txt`), the same file WeakAuras ships as "Fira Sans Black".
