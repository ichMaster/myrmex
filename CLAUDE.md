# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Myrmex is at the concept stage: there is no code yet, only the specification in [specification/myrmex-concept-v0.20.md](specification/myrmex-concept-v0.20.md). No build, lint or test commands exist yet. The spec is the source of truth; when implementing, follow its section numbers and parameter names.

## Spec conventions

- The spec is versioned by filename (`myrmex-concept-vX.Y.md`). When changing it, bump the version in the header and filename and add an entry at the top of section 14 (history of changes), listing the affected section numbers in parentheses, in the existing style. The spec language is English. The Ukrainian original, [specification/myrmex-concept-v0.19-UA.md](specification/myrmex-concept-v0.19-UA.md), is kept for history, frozen at v0.19 — never update it.
- Terminology is fixed: the creature is a **myrmek** (never "ant" in prose), the base/community is the **nest** (never "colony" or "anthill"). Code identifiers use `nest_id`, `myrmek.gd`, `FEED_MYRMEK`.
- Section 13 (open questions) is currently empty; new questions go there.

## What is being built

A 2D cellular simulation of an autonomous myrmek nest in **Godot 4.3+ / GDScript**. v1 is a single native macOS app (sim + render in one process); a headless Linux server with web client is planned for v1.3. The first milestone is prototype v0 "Перша ніч" (section 11): 256x256 world, three roles (worker, builder, guard), 40 myrmeks, spider only, GDScript strategy, `PROGRAM`/`LLM` queen modes with Gemini 3.1 Pro and `MOCK`. Iteration order is in section 11.4 — iteration 1 is headless sim + worldgen with console stats and single-file autosave.

## Architectural invariants (from the spec)

These must hold from the first line of code, including in the prototype:

- **Simulation is pure data, no `Node` dependency** (`res://sim/`). State lives in packed arrays per layer (terrain, structure, knowledge) plus sparse dictionaries for objects and agents. Rendering (`res://view/`, `res://ui/`) only reads state. This enables headless tests, save = serialization, and the later server/client split without rewriting the sim.
- **Determinism**: one seed for world and sim, single seeded RNG (`rng.gd`), discrete ticks (base 10/s), agents processed in id order, LLM responses logged so runs replay without re-calling the model.
- **Fixed per-tick phase order** (section 4): environment → queen planning (every `N_plan` ticks) → myrmeks → predators → combat/deaths → knowledge update → render sync.
- **One agent per cell everywhere**, including inside the nest; nest capacity = count of passable interior cells.
- **Walls are impassable to everyone.** There is no "entrance" type: a gap is just a ground cell left open in the wall ring. "Inside" is computed by flood fill from the queen chamber, not stored.
- **Fog of war**: unknown cells don't exist for the nest — no paths or tasks there. Frontier is maintained incrementally.
- **Two-level queen brain**: tactical level (algorithmic task board, assigns every task) and strategic level (a program with `plan(s) -> policy` plus persistent `memory`). The strategy only sees a `StateView` (copied scalars + engine-side helper functions like `predators_within(r)`), never the `World` object, and only returns a policy dictionary that is schema- and bounds-checked. **The LLM never controls individual myrmeks** — it only writes/revises the strategy program, asynchronously, while the current version keeps running. Strategy language is hidden behind the `StrategyRunner` interface (GDScript loaded at runtime in the prototype, sandboxed Lua 5.4 via godot-luaAPI in v1).
- **Pathfinding**: no global A*. A weighted BFS distance field to the nest over known passable cells (home = gradient descent), plus on-demand local `AStarGrid2D` in a bounding box with 16-cell margin.
- **Saves**: `var_to_bytes` into a compressed file with a small JSON header; written on a background thread from array copies, to a temp name then renamed. Autosave on every dawn, on exit, and before applying a new strategy version; the game resumes from the latest autosave on launch.

The planned file layout under `res://` is in section 9; default parameters are in section 10 and belong in `res://data/*.tres` Resources rather than hard-coded constants.
