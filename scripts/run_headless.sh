#!/usr/bin/env bash
# Headless run wrapper (ROADMAP §v0.1). Everything after the script name is
# passed to res://tools/run_sim.gd: --seed= --ticks= --size= --new --hash
# --stats-every=. Example: scripts/run_headless.sh --seed=42 --ticks=3000
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
if [ -z "${GODOT_BIN}" ] || [ ! -x "$(command -v "${GODOT_BIN}")" ]; then
  echo "error: godot binary not found — install Godot 4.x or set GODOT_BIN" >&2
  exit 2
fi

# Fresh checkout: without the .godot import cache the global class names
# (Sim, SimSave, ...) do not resolve and Godot still exits 0 — import once.
if [ ! -d .godot ]; then
  "${GODOT_BIN}" --headless --path . --import >/dev/null 2>&1 || true
fi

exec "${GODOT_BIN}" --headless --path . --script res://tools/run_sim.gd -- "$@"
