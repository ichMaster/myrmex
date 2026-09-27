# Vision — Myrmex

Document version 1.0 — 27 September 2026.

## In one sentence

Myrmex is a deterministic cellular-world simulation in Godot where an autonomous nest of ant-like myrmeks — coordinated by a queen whose strategy is a real program, written by a human or an LLM — survives its first night, builds, and expands while you watch and prod the world, but never command a single creature.

## What we are building

A living nest in a large 2D cell world. About a hundred myrmeks in six roles (scouts, guards, builders, carriers, harvesters, and a stationary queen) share one knowledge map under fog of war, run an energy-and-hunger economy, mine resources, raise walls, and defend the gaps they themselves leave in those walls, while predators hunt by day and hunt harder by night. The founding drama is built in: the nest starts on bare ground and must gather, build, and shelter before the first dusk.

The queen's mind has two levels. The tactical level is an algorithmic task board that turns the nest's state into assigned tasks every planning cycle. Above it sits a **strategy program** — real code with a `plan(state) -> policy` function and persistent memory — that the queen executes herself in microseconds. In `LLM` mode a language model writes that program at the start and revises it by results (deaths, food income, nights without losses); every version is validated, journaled, and replayable. Strategies live in a library and can be raced against each other on identical seeds — a strategy arena.

The observer gets a StarCraft-style camera and minimap, an inspector, live parameter sliders, intervention tools (drop food, release a predator, reveal terrain), and automatic saves. The first release is a single native macOS app; later the simulation moves to a headless home server with web clients, then to several warring nests, births, evolution, and the strategy program as an inheritable genome.

## For whom

A private research-and-observation project for its author, and later a close circle of observers over a home server — not a commercial game and not a public service. Two interests drive it: watching a small ecosystem live by its own logic, and experimenting with LLM-written strategies against human-written ones on the arena.

## Principles

- **The nest is autonomous.** The observer intervenes in the world — food, predators, parameters — never in a myrmek's head. There are no unit orders.
- **Simulation is pure data.** The sim has no dependency on the scene tree; rendering only reads state. Headless runs (tests, arena, server) are first-class from day one.
- **Determinism end to end.** One seed, discrete ticks, agents processed in id order, LLM responses journaled: any run replays exactly, with or without the model.
- **Strategy is a program, not weights.** `plan(s) -> policy` plus a `memory` table, behind the `StrategyRunner` seam (GDScript in the prototype, sandboxed Lua later). Code can be read, diffed, versioned, and inherited.
- **The LLM never controls a myrmek.** The model writes and revises the strategy program — rarely, asynchronously, budgeted. Tactics stay algorithmic and free.
- **Physical rules, not conventions.** Walls block everyone without exception; a gap is a real ground cell; at most one agent per cell anywhere; nest capacity is its interior area; a demolished wall returns its resource. Defence is guards standing in gaps and builders sealing them, not special-case rules.
- **Everything is a parameter.** Defaults live in data resources and on live sliders; balance is tuned, not hardcoded.
- **Complexity grows by versions.** Prototype "First Night" → the full nest → births → replay → server and clients → nests at war → evolution. Never all at once.

## Non-goals

- Not an RTS: no direct control of agents, no player-driven economy. Watching and perturbing is the whole interface.
- No pheromone simulation: coordination is the shared knowledge map plus the queen's task board — easier to explain and to debug.
- No public service: the server (v4) is a home machine behind one shared token for a close circle; no accounts, no open sign-up.
- No LLM micro-management: no per-tick or per-agent model calls, ever. Model calls are strategic, rare, and rate-limited.
- Not in the near versions: sound, weather, digging, food spoilage, myrmek age — listed as "later" ideas, deliberately unscheduled.

## Glossary

- **Myrmek** — the ant-like creature (from Greek *μύρμηξ*); plural myrmeks. Never called "ant" in prose.
- **Nest** — both the community (queen + myrmeks, in code `Nest`, keyed by `nest_id`) and its base: ground enclosed by walls with storages inside.
- **Queen** — the stationary coordinator; runs the task board and executes the strategy program. Births from v2.
- **Gap** — a ground cell left open in the wall ring; the only way in for anyone, including predators. No special "entrance" type exists.
- **Knowledge map / fog of war** — per-nest `known` mask; unknown cells do not exist for the nest (no paths, no tasks).
- **Frontier** — known passable cells bordering unknown ones; scouts take frontier targets in per-scout sectors.
- **Active zone** — chunks near the nest plus known/occupied ones; the only place food, resources, and predators spawn. The rest of the world sleeps.
- **Chunk** — a 64x64 cell block; the unit of activity, spawning, and minimap updates.
- **Patch / pile** — a resource deposit worked by harvesters / loose units left on the ground for carriers.
- **Paving** — a structure that speeds myrmeks up (never predators); roads grow automatically along high-traffic routes.
- **Task board** — the tactical level: typed, ranked tasks (`EXPLORE`, `FETCH_FOOD`, `HARVEST`, `BUILD`, `FEED_MYRMEK`, `HOLD_GAP`, …) assigned greedily by distance.
- **Policy** — the dictionary a strategy returns: ranking weights, guard distribution, night rules, build plan, thresholds. Schema- and bounds-checked.
- **Strategy program** — the code (`plan(s) -> policy` + `memory`) that *is* the nest's strategy; authored by a human or an LLM.
- **StateView** — the read-only window a strategy sees: copied scalars plus engine-side helper functions; never the `World` object.
- **StrategyRunner** — the seam hiding the strategy language (GDScript prototype runner, sandboxed Lua runner) from the rest of the code.
- **`queen_brain`** — who authors the program: `PROGRAM` (human/library), `LLM` (model writes and revises), `LEARNED` (v6).
- **Strategy library / arena** — stored strategy files with version history; headless batch runs on identical seeds producing a results table.
- **Distance field** — weighted BFS over known passable cells; going home is gradient descent, no search.
- **Tick / day cycle** — the discrete simulation step (10/s base); a day is day–dusk–night–dawn (600/60/400/60 ticks), with night favouring predators.
- **Interventions** — observer actions on the world: place food, create a patch, summon or remove a predator, heal, reveal map.

---

## History of changes

**v1.0 (27.09.2026)** — initial version, derived from the retired concept v0.20 ([history/](history/)).
