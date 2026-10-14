#!/usr/bin/env bash
# Scaffolds a new addon project from template/:
#   <Name>/<Name>/<Name>.toc, Core.lua, Shared/ (synced), tests/, README.md
#
#   tools/new-addon.sh JiThing
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
name="${1:?usage: tools/new-addon.sh <AddonName>}"
[[ "$name" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || { echo "addon name must be letters, digits or _" >&2; exit 1; }
dest="$root/$name"
[[ -e "$dest" ]] && { echo "$dest already exists" >&2; exit 1; }

upper="$(echo "$name" | tr '[:lower:]' '[:upper:]')"
lower="$(echo "$name" | tr '[:upper:]' '[:lower:]')"

cp -R "$root/template" "$dest"
mv "$dest/__ADDON__/__ADDON__.toc" "$dest/__ADDON__/$name.toc"
mv "$dest/__ADDON__" "$dest/$name"

find "$dest" -type f \( -name '*.lua' -o -name '*.toc' -o -name '*.md' \) -print0 |
    while IFS= read -r -d '' f; do
        sed -i '' -e "s/__ADDON_UPPER__/$upper/g" -e "s/__ADDON_LOWER__/$lower/g" -e "s/__ADDON__/$name/g" "$f"
    done

"$root/tools/sync-shared.sh" "$name"
if command -v luajit >/dev/null 2>&1; then
    luajit "$dest/tests/run_tests.lua"
fi
echo "created $dest"
