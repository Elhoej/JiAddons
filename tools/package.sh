#!/usr/bin/env bash
# Builds <Project>/dist/<Addon>-<version>.zip, ready to unzip into Interface/AddOns.
# Syncs shared/ into the addon and runs the project's tests first.
#
#   tools/package.sh JiLoot
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
project="${1:?usage: tools/package.sh <Project>}"
project_dir="$root/$project"
[[ -d "$project_dir" ]] || { echo "no project folder $project_dir" >&2; exit 1; }

"$root/tools/sync-shared.sh" "$project" >/dev/null

tests="$project_dir/tests/run_tests.lua"
if [[ -f "$tests" ]]; then
    if command -v luajit >/dev/null 2>&1; then
        luajit "$tests" >/dev/null || { echo "tests failed; run: luajit $project/tests/run_tests.lua" >&2; exit 1; }
    else
        echo "warning: luajit not found, skipping tests" >&2
    fi
fi

mkdir -p "$project_dir/dist"
for toc in "$project_dir"/*/*.toc; do
    addon_dir="$(dirname "$toc")"
    addon="$(basename "$addon_dir")"
    [[ "$(basename "$toc" .toc)" == "$addon" ]] || continue
    version="$(sed -n 's/^## Version: *//p' "$toc" | tr -d '\r')"
    out="$project_dir/dist/$addon-${version:-dev}.zip"
    rm -f "$out"
    (cd "$project_dir" && zip -qr "$out" "$addon" -x '*.DS_Store')
    echo "built $out"
done
