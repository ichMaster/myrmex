#!/usr/bin/env bash
# The canonical headless test gate (ARCHITECTURE §Testing).
# Runs the vendored gdUnit4 CLI under `godot --headless`; exits non-zero on
# any test failure. CI and every /execute-issues validation call this script
# and nothing else.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
if [ -z "${GODOT_BIN}" ] || [ ! -x "$(command -v "${GODOT_BIN}")" ]; then
  echo "error: godot binary not found — install Godot 4.x or set GODOT_BIN" >&2
  exit 2
fi

# Refresh the import cache so script classes resolve in headless runs.
# Warnings here are tolerated; real parse errors fail the suite below.
"${GODOT_BIN}" --headless --path . --import >/dev/null 2>&1 || true

exec "${GODOT_BIN}" --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -c -a res://tests
