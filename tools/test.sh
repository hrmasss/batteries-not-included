#!/usr/bin/env bash
# Runs every test headless. Usage: tools/test.sh [extra GUT args, e.g. -gselect=test_jetpack]
# GODOT points at the Godot 4.7.2 binary; defaults to `godot` on PATH.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Import first: it registers class names and imports resources on a fresh checkout.
timeout 600 "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
timeout 900 "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd "$@"
