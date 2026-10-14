# __ADDON__

A World of Warcraft: Forever addon.

## Install

Copy the `__ADDON__` folder (the one containing `__ADDON__.toc`) to `World of Warcraft/_classic_beta_/Interface/AddOns/`, then restart the game.

## Usage

`/__ADDON_LOWER__` opens the options.

## Development

```
luajit __ADDON__/tests/run_tests.lua   # from JiAddons/
../tools/package.sh __ADDON__          # builds dist/__ADDON__-<version>.zip
```
