# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Myrmex is at the specification stage: there is no code yet. Spec-driven development lives in exactly three files in [specification/](specification/):

- [specification/VISION.md](specification/VISION.md) — what is being built, for whom, principles, non-goals, glossary.
- [specification/ARCHITECTURE.md](specification/ARCHITECTURE.md) — components, world/agent/nest model, the queen's two-level brain, contracts, resilience, layout, testing.
- [specification/ROADMAP.md](specification/ROADMAP.md) — versions v0–v6 and phases `vA.B`, each with Goal, Tasks, DoD, and Tests.

These three files are the source of truth. Design material: the canonical design brief is [specification/design_handoff_myrmex_ui/DESIGN_BRIEF.md](specification/design_handoff_myrmex_ui/DESIGN_BRIEF.md) (v2.0) inside the designer's handoff package — its `art/*.png` sheets (creatures and nest structures, 8 headings per row, regenerable from `CREATURE_PROMPTS.md`) are the **working game art**, copied into `res://art/` at build time; `sprites/*.svg`, `scenes/`, `myrmex-art.js` and `world-model.json` are shape/composition references for the procedural set — never imported into `res://` (`crag.png`/`decor.png` are rejected: procedural is canonical there). [specification/DESIGN_BRIEF.md](specification/DESIGN_BRIEF.md) is a pointer carrying the engineering acceptance and the outstanding design items (currently: the defeat card). All design material follows the three SDD files and never overrides them. When a decision changes, update every one of them it touches and keep them consistent. [specification/history/](specification/history/) holds the retired initial concept (English v0.20 and the Ukrainian original v0.19) — kept for history as the initial vision, frozen: never update, extend, or derive requirements from those files.

No build, lint, or test commands exist yet. The target stack is Godot 4.x (4.3+) / GDScript with headless tests (gdUnit4); record the real commands here (run, headless run, test suite, single test) as soon as the Godot project exists.

## SDLC pipeline (skills)

The code is built from the specs by the SDLC skills in `.claude/skills/`, with every run tracked by `codegen/` — overview in [CODEGEN.md](CODEGEN.md), tracker detail in [codegen/README.md](codegen/README.md):

- **GitHub-driven:** `/ship-phase <selectors>` — per phase `vA.B`: reconcile against the real code → `generate-issues` → `upload-issues` → `execute-issues` → `review-and-fix-issues` → `release-version vA.B.0`, with a HARDEN sweep at each version (`vA`) boundary by default (`--no-harden` to skip). Needs an authenticated `gh`.
- **File-driven, offline:** `/ship-solution [selectors]` — executes from existing `specification/implementation/vA.B-issues.md` files (`reconcile-issues` → `execute-issues-file` → `review-and-fix-issues` → `release-version`); it cannot generate a missing issues file.
- `specification/implementation/` is the skills' working directory (issues files, GitHub/execution reports, code reviews). `/reset-generated` clears a run's output using the run's own event log — dry-run by default; for Myrmex the generated app is the product, so resets are deliberate experiments only.
- Dashboard: `cd codegen && ../.venv/bin/python -m uvicorn dashboard.server:app --port 8420` (deps: `.venv/bin/pip install -r codegen/requirements.txt`); the hooks in `.claude/settings.json` emit events automatically.

Rules that hold across all skills: issue ids are **`MYRMEX-###`**, globally sequential (`max(GitHub, local issues files) + 1`), never restarted; one issue = one commit, in dependency order; tests ship with the feature and the LLM provider is `MOCK` in tests (no paid calls); a seam change updates ARCHITECTURE.md + its contract test in the same commit; releases are `vA.B.C` tags cut per phase by `release-version` — never bump a version without explicit confirmation; the canonical test gate is `scripts/test.sh` (headless), created in v0.1.

## Conventions

- Terminology is fixed: the creature is a **myrmek** (never "ant" in prose), the base/community is the **nest** (never "colony" or "anthill"). Code identifiers use `nest_id`, `myrmek.gd`, `FEED_MYRMEK`. UI display names differ for flavour: the creature is still shown as **myrmek**, the queen as the **brood mother**, the predators as the **lurker** / **stalker** / **razorback** — code identifiers stay `queen`/`spider`/`beetle`/`lizard`.
- **When a spec changes, its diagrams change with it.** ARCHITECTURE.md holds nine diagrams (eight Mermaid blocks plus an ASCII cell grid). After editing any section, check whether a diagram now contradicts the text and update it in the same commit; every diagram carries one short explanatory paragraph directly beneath it (one paragraph is enough). Then verify every block still renders: extract the ```mermaid blocks and run `npx -y @mermaid-js/mermaid-cli@11 -i <file>.mmd -o <file>.svg` on each. A bracket-balance check is not enough — the real parser catches things it cannot (a `;` inside a label silently terminates the statement and GitHub then shows a red error box instead of the diagram).
- Each specification file carries a document version in its header ("Document version X.Y — date") and a **History of changes** section at its end. **Every time you change VISION.md, ARCHITECTURE.md, or ROADMAP.md, bump that file's document version and add a dated entry at the top of its history describing what changed and in which sections** (minor bump for content changes, major for restructuring). Document versions are per file and independent of the product/roadmap versions.
- Build in roadmap order: take the next phase, implement to its DoD, and ship its tests with it. Roadmap phase `vA.B` maps to semver `A.B.0`; never bump a version without explicit confirmation.
- Defaults are data, not constants: parameter defaults belong in `res://data/*.tres` Resources (the table in ARCHITECTURE.md §Configuration), editable live from the parameters panel.
- No paid API calls in tests: the LLM is always the `MOCK` provider there.

## Architectural invariants

ARCHITECTURE.md is the authoritative statement; these must hold from the first line of code, including in the v0 prototype:

- **The simulation is pure data** in `res://sim/`, no `Node` dependency; rendering and UI only read state. Headless runs (tests, arena, later the server) are first-class.
- **Determinism end to end**: one master seed with named RNG streams (worldgen/spawner/combat/strategy/interventions), discrete ticks, agents processed in id order, observer commands applied at tick boundaries, LLM responses journaled; sim arithmetic is integer-only (fixed-point energy, no transcendental functions in `res://sim/`), so runs replay bit-identically across platforms.
- **Fixed per-tick phase order**: environment → queen planning (every `N_plan` ticks) → myrmeks → predators → combat/deaths → knowledge update → render sync.
- **Physical rules**: at most one agent per cell everywhere; 8-directional movement with uniform cost (Chebyshev radii); walls impassable to everyone; a gap is just an open ground cell; the nest interior is computed by flood fill from the queen chamber, never stored; a demolished structure returns its resource; carried units drop on death.
- **Fog of war**: unknown cells do not exist for the nest — no paths, no tasks; known-but-unreachable cells are never task targets.
- **Two-level queen brain**: the algorithmic task board (tactics) under a strategy program `plan(s) -> policy` with persistent `memory` (strategy), behind the `StrategyRunner` seam (sandboxed Lua 5.4 via godot-luaAPI from v0.5: only `base`/`table`/`string`/`math` bound, instruction limit). The strategy sees only `StateView` — copied scalars plus engine-side helpers — never the `World`; returned policies are schema- and bounds-checked; a version that fails validation is discarded while the previous one keeps running.
- **The LLM never controls an individual myrmek.** It only writes and revises the strategy program — asynchronously, rate-limited, every version validated and journaled.
- **Pathfinding**: a weighted BFS distance field over known passable cells plus an on-demand local `AStarGrid2D`; no global A*.
- **Saves are automatic and atomic**: serialization of the pure-data state on a background thread from array copies, temp file then rename; autosave at dawn, on exit, and before a new strategy version; launch resumes from the latest autosave.
