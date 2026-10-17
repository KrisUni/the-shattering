#!/usr/bin/env bash
# Runs the GUT suite headless: the whole suite, or one test file passed as the
# first argument (res://test/test_x.gd, or a path relative to the repository root).
# GODOT must point at a Godot 4.7 binary; it defaults to `godot` on PATH.
#
# Exit status: GUT's own (0 when everything passes, non-zero when a test fails),
# or 1 if the project cannot be imported or GUT did not run what it was asked to
# (a test script that would not load, a file that does not exist, no tests at all).
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Import before every run. GUT's global classes (GutTest, ...) and our own
# `class_name` scripts are only registered by an import pass, so without one a
# newly added `class_name` is unknown to the tests and they fail confusingly.
# The import's output is noisy and only shown if the import fails.
if ! import_log="$("$GODOT" --headless --path "$ROOT" --import 2>&1)"; then
	echo "$import_log" >&2
	echo "scripts/test.sh: the import pass failed" >&2
	exit 1
fi

args=(--headless --path "$ROOT" -s addons/gut/gut_cmdln.gd)
if [[ $# -gt 0 ]]; then
	test_file="$1"
	[[ "$test_file" == res://* ]] || test_file="res://${test_file#./}"
	# .gutconfig.json lists the test directory, and GUT would run that as well as
	# this file, so blank the directories out.
	args+=("-gdir=" "-gtest=$test_file")
fi

# GUT has no option to fail when it did not run what it was asked to: it logs a
# warning (or an error), drops the script, and still reports "All tests passed"
# with exit status 0. So the output is kept as well as shown, and searched for
# GUT's own messages (see addons/gut/test_collector.gd and gut.gd):
#   Ignoring script <path> because it does not extend GutTest
#       a script that fails to parse or load ends up here, and so does a test_*.gd
#       that forgot `extends GutTest`; both are mistakes
#   Could not find script:  <path>      a mistyped file argument
#   Nothing was run.                    no test script at all
run_log="$(mktemp)"
trap 'rm -f "$run_log"' EXIT

# Not under `set -e`: a failing run must still reach the check below.
gut_status=0
"$GODOT" "${args[@]}" | tee "$run_log" || gut_status="${PIPESTATUS[0]}"

not_run="$(grep -a -o -E 'Ignoring script .* because it does not extend GutTest|Could not find script: +.*|Nothing was run\.' "$run_log" | sort -u || true)"
if [[ -n "$not_run" ]]; then
	{
		echo
		echo "scripts/test.sh: FAILED: GUT did not run everything it was asked to:"
		sed 's/^/    /' <<<"$not_run"
		echo "    A parse or load error is printed near the top of the output above."
	} >&2
	[[ "$gut_status" -ne 0 ]] || gut_status=1
fi

exit "$gut_status"
