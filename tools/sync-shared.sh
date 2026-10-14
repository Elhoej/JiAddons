#!/usr/bin/env bash
# Copies JiAddons/shared/*.lua into every addon's Shared/ folder
# (<Project>/<Addon>/Shared/), so each addon ships its own embedded copy.
# Addons cannot load files from other AddOn folders, hence the copies.
#
#   tools/sync-shared.sh            sync every addon
#   tools/sync-shared.sh JiLoot     sync only the addons in project JiLoot
#
# Never edit <Addon>/Shared/*.lua directly: edit shared/ and re-run this.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
filter="${1:-}"

synced=0
for toc in "$root"/*/*/*.toc; do
    addon_dir="$(dirname "$toc")"
    addon="$(basename "$addon_dir")"
    project="$(basename "$(dirname "$addon_dir")")"
    [[ "$(basename "$toc" .toc)" == "$addon" ]] || continue
    [[ "$project" == "template" || "$project" == "tools" || "$project" == "shared" ]] && continue
    [[ -n "$filter" && "$project" != "$filter" ]] && continue

    mkdir -p "$addon_dir/Shared"
    for src in "$root"/shared/*.lua; do
        name="$(basename "$src")"
        {
            echo "-- Embedded copy of JiAddons/shared/$name. Do not edit here:"
            echo "-- edit shared/$name and run tools/sync-shared.sh."
            cat "$src"
        } > "$addon_dir/Shared/$name"
        if ! grep -q "Shared\\\\$name" "$toc"; then
            echo "warning: $project/$addon/$addon.toc does not list Shared\\$name" >&2
        fi
    done
    synced=$((synced + 1))
    echo "synced shared/ -> $project/$addon/Shared"
done

[[ $synced -gt 0 ]] || { echo "no addons found${filter:+ for project $filter}" >&2; exit 1; }
