# Myrmex

A deterministic simulation of an autonomous myrmek nest — ant-like creatures in a large cellular 2D world, coordinated by a queen whose strategy is a real program, written by a human or by an LLM.

You watch and you meddle. You never give an order.

> **Status: specification stage.** There is no code yet. The three documents in [`specification/`](specification/) are the source of truth, and the application is built from them by the SDLC skills in [`.claude/skills/`](.claude/skills/) — see [CODEGEN.md](CODEGEN.md). Build and run instructions land here with the first phase (v0.1).

## What it is

About a hundred myrmeks in six roles — scouts, guards, builders, carriers, harvesters and one immobile queen — share a single knowledge map under fog of war. They run an energy-and-hunger economy, mine resource patches, raise walls, and defend the gaps they themselves leave in those walls. Spiders ambush, beetles grind forward, lizards hunt faster after dark.

The nest starts on bare ground with nothing built and nothing stored, so the first night is the first real problem: gather, build, and get everyone inside before dusk. A wall ring of radius 5 costs about 40 resources and holds roughly 70 of the 100 myrmeks; the rest sleep outside by the gap, under guard. Food is deliberately tight — a hundred myrmeks burn about 110 units a day and the world spawns 120–150.

You get a StarCraft-style camera and minimap, an inspector, live parameter sliders, and tools to drop food, summon a predator or reveal terrain. What you do not get is unit control: the nest lives by its own logic, and the only way to change how it thinks is to change the program its queen runs.

## The queen's strategy is a program

Tactics are algorithmic: every planning cycle the queen turns the nest's state into a ranked task board and assigns each myrmek a job. Above that sits a **strategy program** — real code with a `plan(state) -> policy` function and a `memory` table that survives between calls — which the queen executes herself in microseconds:

```lua
memory = memory or { lost_last_day = 0 }

function plan(s)
  local p = defaults()
  if s.phase == "dusk" and not s.ring_closed then
    p.build_priority = "ring"; p.ring_radius = 5
  end
  if s.predators_within(12) >= 1 then
    p.guards_at_gaps = 0.8; p.seal_gaps = true
  end
  if s.food_store < s.population * 0.3 then
    p.weight_food = 2.0; p.workers_harvest_share = 0.2
  end
  if s.deaths_since_dawn > 3 then
    memory.lost_last_day = s.deaths_since_dawn
    p.request_revision = true
  end
  return p
end
```

It runs in a Lua 5.4 sandbox, sees only a read-only `StateView`, and returns only a bounds-checked policy. In `LLM` mode a language model writes that program and revises it from results — deaths by cause, food collected, nights without losses — asynchronously, while the current version keeps running. **The model never controls an individual myrmek**, and every version it writes is validated, journaled and replayable.

Because a strategy is code, strategies can be diffed, stored in a library, and raced against each other on identical seeds — a strategy arena. Later they become the queen's genome: a daughter queen inherits her mother's program, and revision plays the role of mutation.

## Documentation

| Document | What's in it |
|---|---|
| [specification/VISION.md](specification/VISION.md) | What is being built and why: principles, non-goals, the designed tensions, the glossary |
| [specification/ARCHITECTURE.md](specification/ARCHITECTURE.md) | How: components, world/agent/nest models, the queen's two-level brain, contracts, determinism, tech stack, testing, open questions — with diagrams |
| [specification/ROADMAP.md](specification/ROADMAP.md) | When: versions v0–v6, each phase with Goal, Tasks, Definition of Done and Tests |
| [CODEGEN.md](CODEGEN.md) | How the code gets built from those specs, and how each run is tracked |
| [specification/history/](specification/history/) | The retired initial concept, kept frozen as the original vision (the Ukrainian original and its English translation) |

## Roadmap at a glance

| Version | Delivers |
|---|---|
| **v0** | Prototype "First Night" — headless sim, three roles, the spider, sandboxed Lua strategies, the Gemini loop |
| **v1** | The full nest — 2048² chunked world, six roles, three predators, paving and roads, the strategy library and arena, the complete observer surface |
| **v2** | Births — the queen replaces losses and grows toward a needed role mix |
| **v3** | Replay — any run reproduced from seed plus journals alone |
| **v4** | Server and clients — headless Linux simulation, web and macOS observers |
| **v5** | Nests at war — several nests, hostility, siege, a queen per nest with its own model |
| **v6** | Evolution — heritable traits, the strategy program as genome, swarming |

## Architectural invariants

These hold from the first line of code:

- **The simulation is pure data.** `res://sim/` has no dependency on Godot's scene tree; rendering only reads state, observer commands enter at tick boundaries. Headless runs are first-class.
- **Determinism end to end.** One master seed with named RNG streams, integer-only sim arithmetic, agents stepped in id order, a fixed seven-phase tick, LLM answers journaled — every run replays bit-identically, on any platform.
- **Physical rules, not conventions.** One agent per cell everywhere; walls impassable to everyone; a gap is a real ground cell; nest capacity is its computed interior; a demolished wall returns its resource.
- **The LLM writes strategy, never commands.** Rare, asynchronous, rate-limited, validated before it applies.

## Tech stack

Godot 4.3+ with GDScript; Lua 5.4 via godot-luaAPI for strategies; gdUnit4 for headless tests; Gemini 3.1 Pro behind an abstracted provider seam (with a `MOCK` provider used in every test); vector SVG art rasterized at import. No physics engine, no ECS addon, no build system — the two vendored addons are the only third-party code. Full table in [ARCHITECTURE.md §Tech stack](specification/ARCHITECTURE.md#tech-stack).

## License

[MIT](LICENSE).
