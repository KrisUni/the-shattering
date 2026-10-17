#!/usr/bin/env bash
# Runs the GUT suite headless: the whole suite, or one test file passed as the
# first argument (res://test/test_x.gd, or a path relative to the repository root).
# GODOT must point at a Godot 4.7 binary; it defaults to `godot` on PATH.
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A fresh checkout has no .godot/ cache, and GUT's global classes (GutTest, ...)
# are not registered until the project has been imported once.
if [[ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ]]; then
	if ! import_log="$("$GODOT" --headless --path "$ROOT" --import 2>&1)"; then
		echo "$import_log" >&2
		echo "scripts/test.sh: the first import pass failed" >&2
		exit 1
	fi
fi

args=(--headless --path "$ROOT" -s addons/gut/gut_cmdln.gd)
if [[ $# -gt 0 ]]; then
	test_file="$1"
	[[ "$test_file" == res://* ]] || test_file="res://${test_file#./}"
	args+=("-gtest=$test_file")
fi

exec "$GODOT" "${args[@]}"
