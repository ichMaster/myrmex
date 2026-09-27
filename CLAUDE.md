# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Myrmex is at the specification stage: there is no code yet. Spec-driven development lives in exactly three files in [specification/](specification/):

- [specification/VISION.md](specification/VISION.md) — what is being built, for whom, principles, non-goals, glossary.
- [specification/ARCHITECTURE.md](specification/ARCHITECTURE.md) — components, world/agent/nest model, the queen's two-level brain, contracts, resilience, layout, testing.
- [specification/ROADMAP.md](specification/ROADMAP.md) — versions v0–v6 and phases `vA.B`, each with Goal, Tasks, DoD, and Tests.

These three files are the source of truth. When a decision changes, update every one of them it touches and keep them consistent. [specification/history/](specification/history/) holds the retired initial concept (English v0.20 and the Ukrainian original v0.19) — kept for history as the initial vision, frozen: never update, extend, or derive requirements from those files.

No build, lint, or test commands exist yet. The target stack is Godot 4.x (4.3+) / GDScript with headless tests (gdUnit4 or GUT); record the real commands here (run, headless run, test suite, single test) as soon as the Godot project exists.

## Conventions

- Terminology is fixed: the creature is a **myrmek** (never "ant" in prose), the base/community is the **nest** (never "colony" or "anthill"). Code identifiers use `nest_id`, `myrmek.gd`, `FEED_MYRMEK`.
- Build in roadmap order: take the next phase, implement to its DoD, and ship its tests with it. Roadmap phase `vA.B` maps to semver `A.B.0`; never bump a version without explicit confirmation.
- Defaults are data, not constants: parameter defaults belong in `res://data/*.tres` Resources (the table in ARCHITECTURE.md §Configuration), editable live from the parameters panel.
- No paid API calls in tests: the LLM is always the `MOCK` provider there.

## Architectural invariants

ARCHITECTURE.md is the authoritative statement; these must hold from the first line of code, including in the v0 prototype:

- **The simulation is pure data** in `res://sim/`, no `Node` dependency; rendering and UI only read state. Headless runs (tests, arena, later the server) are first-class.
- **Determinism end to end**: one seed, a single seeded RNG, discrete ticks, agents processed in id order, observer commands applied at tick boundaries, LLM responses journaled — every run replays exactly.
- **Fixed per-tick phase order**: environment → queen planning (every `N_plan` ticks) → myrmeks → predators → combat/deaths → knowledge update → render sync.
- **Physical rules**: at most one agent per cell everywhere; 8-directional movement with uniform cost (Chebyshev radii); walls impassable to everyone; a gap is just an open ground cell; the nest interior is computed by flood fill from the queen chamber, never stored; a demolished structure returns its resource; carried units drop on death.
- **Fog of war**: unknown cells do not exist for the nest — no paths, no tasks; known-but-unreachable cells are never task targets.
- **Two-level queen brain**: the algorithmic task board (tactics) under a strategy program `plan(s) -> policy` with persistent `memory` (strategy), behind the `StrategyRunner` seam (GDScript runner in the prototype, sandboxed Lua from v1.5). The strategy sees only `StateView` — copied scalars plus engine-side helpers — never the `World`; returned policies are schema- and bounds-checked; a version that fails validation is discarded while the previous one keeps running.
- **The LLM never controls an individual myrmek.** It only writes and revises the strategy program — asynchronously, rate-limited, every version validated and journaled.
- **Pathfinding**: a weighted BFS distance field over known passable cells plus an on-demand local `AStarGrid2D`; no global A*.
- **Saves are automatic and atomic**: serialization of the pure-data state on a background thread from array copies, temp file then rename; autosave at dawn, on exit, and before a new strategy version; launch resumes from the latest autosave.
