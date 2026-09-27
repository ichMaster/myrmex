# Architecture — Myrmex

Document version 1.15 — 27 September 2026.

## Overview

Two layers bound by one rule: the **simulation is pure data** — arrays and dictionaries with no dependency on Godot's scene tree — and everything else (rendering, UI, later the network) only reads it or feeds commands into it at tick boundaries. Capabilities grow by version (three roles → six, one predator → three, a tiny `StateView` → the full one, single app → server and clients), but the sim/presentation split, the determinism rules, and the contracts below are fixed from the first line of code. That is what makes headless tests, the strategy arena, saves-as-serialization, and the v4 server split cheap instead of rewrites.

```mermaid
flowchart LR
    subgraph app["res://app/ — one process, v0–v3"]
        direction TB
        subgraph sim["res://sim/ — pure data: no Node, no scene tree, no network"]
            direction TB
            core["world · worldgen · chunks · clock · rng streams"]
            live["agents · nest · tasks · combat · spawner · pathfinding"]
            brain["queen_ai — task board<br/>strategy — StrategyRunner + StateView"]
            core --- live --- brain
        end
        view["res://view/ · res://ui/<br/>tile window · MultiMesh agents · minimap<br/>inspector · params · tools · queen panel"]
        llm["res://llm/<br/>gemini · openai_compat · anthropic · ollama · mock"]
    end
    data["res://data/*.tres<br/>parameter defaults"] --> sim
    sim -->|"read state — never mutate"| view
    view -->|"observer commands, applied at tick boundaries"| sim
    sim -->|"state report + metrics"| llm
    llm -->|"new strategy program → validated → applied at a tick boundary"| sim
    sim -->|"var_to_bytes, background thread"| saves[("user:// saves<br/>+ strategy library")]
```

How to read it: everything inside `res://sim/` is plain data stepped by the tick loop, and the arrows leaving it are read-only. Nothing on the right ever writes into the sim directly — the view's commands and the LLM's validated programs enter at tick boundaries, and a save is a serialization of the same data.

From v4 the same `res://sim/` runs headless on a server and the observer becomes a thin client; nothing in the simulation changes:

```mermaid
flowchart LR
    subgraph host["home Linux machine"]
        server["res://server/<br/>headless tick loop · res://sim/ · LLM · autosave<br/>command journal"]
        proxy["Caddy or nginx<br/>TLS wss · COOP/COEP · static web client"]
        server --- proxy
    end
    web["res://client/ — web export<br/>Mac · iPad · phone"]
    mac["res://client/ — native macOS"]
    proxy -->|"snapshot once, then deltas:<br/>camera area · global changes · minimap · stats"| web
    proxy --> mac
    web -->|"camera rect · commands · chunk requests<br/>(one shared token)"| proxy
```

The v4 split moves the identical sim behind a socket: the server owns the tick loop, the LLM calls and the saves; Caddy or nginx terminates TLS and serves the web build; clients keep only a local copy of what their camera can see, so bandwidth follows the viewport, not the population.

## What v0 implements

Everything below describes the full v1 system. The **v0 prototype** ([ROADMAP.md §v0](ROADMAP.md)) builds a reduced version of exactly this architecture — **not a separate codebase and not a throwaway**: v1 widens v0's scope without rewriting its structure. Read the table as "which parts of the sections that follow exist in the first build".

**Reduced in v0 (scope), per section:**

| Section | In v0 | Deferred |
|---|---|---|
| **World model** | 256x256 fixed, all layers present, objects/agents sparse | Sizes to 2048², 64x64 chunks, the active zone (v1.1) — in v0 the whole world is awake |
| **Time and the tick** | The full seven-phase order, 10 ticks/s, day–dusk–night–dawn with predator night multipliers, `seal_at_night` | Nothing |
| **Agents — roles** | Three: **worker** (scout + carrier + harvester in one: carries if there is cargo, mines if a patch is assigned, else takes the frontier), **builder**, **guard**; 40 myrmeks + the queen (22/8/10) | Six specialized roles, ~100 myrmeks, cargo handover between neighbours (v1.2) |
| **Agents — energy** | Full model: fixed-point energy, hunger thresholds, starvation deaths, cargo drop on death | Nothing |
| **Agents — predators** | The spider only, with its night multipliers and full state machine | Beetle, lizard, per-species target counts (v1.3) |
| **Combat** | Full: 8-adjacent damage, stacking attackers, gap crossfire, carcasses as food | Nothing |
| **Nest — knowledge** | Full: per-nest `known` mask, incremental frontier, unknown cells excluded from paths and tasks | Nothing |
| **Nest — structure** | Walls, storages, gaps, computed interior/capacity, demolition with resource return, night sealing; the build plan is **fixed rings that grow with population** | Traffic-driven planning, `PAVEMENT` and roads (v1.4) |
| **Queen — tactical** | The task board with `EXPLORE`, `FETCH_FOOD`, `HARVEST`, `BUILD`, `FEED_MYRMEK`, `PATROL`, `HOLD_GAP`, `OPEN_GAP`, `CLOSE_GAP`; ranking, greedy assignment, the first-day plan | `FETCH_PILE`, `DELIVER_RES`, `INTERCEPT`, `PAVE`, `ESCORT`, `GUARD_SITE`; defence-strategy weights (v1.3) |
| **Queen — strategic** | `StrategyRunner` with the **sandboxed Lua 5.4 runner** (sandbox, instruction limit, dry run), a **tiny `StateView`** (~10 scalars) and **6 policy fields**, `BUILTIN` + `PROGRAM` + `LLM` modes, **one shipped strategy** (`baseline.lua`), version validation and the journal. **Deliberately no judging machinery**: a broken version is rejected and the current keeps running; if nothing loads or `plan()` keeps misfiring, the nest drops to `BUILTIN` | The whole judging apparatus — six-goal coverage, the situation classifier, the scorecard, the escalation ladder with fingerprints and the ledger — plus the other shipped strategies, the full `StateView`/policy schema and the arena (v1.5) |
| **LLM** | Gemini 3.1 Pro + `MOCK`; writes the program at start, revises on three plain triggers — the first night, more than three deaths since dawn, `request_revision` | OpenAI-compatible, Anthropic, Ollama providers; the scorecard-driven triggers (v1.5) |
| **Pathfinding** | Weighted BFS distance field + local `AStarGrid2D`, recomputed **globally over the whole 256² world** | Incremental recomputation scoped to chunks (v1.1) |
| **Saves** | Serialization of the full state; **one autosave file**, written at dawn and on exit; launch resumes from it | Rotation (3 + one per day), the saved-days list, named slots (v1.6) |
| **Rendering** | SVG sprites, tile window, `MultiMeshInstance2D` myrmeks with interpolation, `CanvasModulate` day/night; **flat tiles, two zooms (16/32 px)** | Terrain-set autotiling, zooms 8–48, `PointLight2D` at the gap (v1.6) |
| **UI** | Camera, pause + 1x/4x/16x + step, minimap, click inspector, statistics, event log, queen panel; **two interventions** (place food, release a spider); parameters edited in `.tres` | The live parameters panel, the full inspector, all interventions (v1.6) |
| **Server / Net** | Not present — one process, `res://app/` | The whole of v4 |

**Not reduced in v0 (invariants).** The prototype cuts features, never the rules that make later versions cheap — each of these is load-bearing from the first commit:

- The simulation is **pure data** in `res://sim/`, with no `Node`, scene-tree or network dependency; view and UI only read it, and observer commands enter at tick boundaries.
- **Determinism end to end**: one master seed, named RNG streams, integer-only sim arithmetic, agents stepped in id order, the fixed seven-phase tick, journaled LLM answers.
- **Physical rules**: one agent per cell everywhere, 8-directional movement with Chebyshev radii, walls impassable to all, a gap as a plain ground cell, interior computed by flood fill, demolition returning its resource.
- **Contracts**: `StateView`, the policy schema, `StrategyRunner`, the task shape, the provider interface and the save format are all pinned by contract tests in v0 — they *grow* additively in v1 rather than changing shape.
- **The strategy sandbox**: Lua from v0.5, because the prototype is precisely where model-written code first runs inside the process.
- **Headless first**: `res://sim/` runs and is tested with no rendering (v0.1 ships before any view exists).

Estimated size of the whole prototype: three to four thousand lines of GDScript.

## Components

- **World** (`world.gd`). Layer arrays per cell, chunk bookkeeping, cell access. See §World model.
- **Worldgen** (`worldgen.gd`). Deterministic generation from a seed: noise terrain, smoothing, start guarantees.
- **Clock** (`clock.gd`). Ticks, speed multipliers, day phases. See §Time and the tick.
- **Agents** (`agent.gd`, `myrmek.gd`, `predator.gd`). One shared record shape; per-role and per-species state machines. See §Agents.
- **Nest** (`nest.gd`). Knowledge mask, frontier, storages, structures, build plan and queue, interior/capacity.
- **Queen — tactical** (`queen_ai.gd`, `tasks.gd`). The task board: gather state → build tasks → rank → assign. See §The queen's brain.
- **Queen — strategic** (`strategy.gd`, `strategy_lua.gd`, `queen_policy.gd`, `strategy_eval.gd`, `nest_report.gd`). The `StrategyRunner` seam with the sandboxed Lua 5.4 runner (godot-luaAPI, from v0.5), `StateView` assembly, policy validation, the `BUILTIN`/`PROGRAM`/`LLM` modes, the scorecard and escalation ladder, the strategy library, and the LLM report and failure-dossier assembly.
- **LLM providers** (`res://llm/`). Gemini 3.1 Pro (main), OpenAI-compatible, Anthropic, Ollama, and `MOCK` (reads a program from a file); the `StateView`/policy API description and prompts for the model.
- **Pathfinding** (`pathfinding.gd`). Distance field + local A*. See §Pathfinding.
- **Combat** (`combat.gd`). Adjacent-cell damage, deaths, carcasses, cargo drops.
- **Spawner** (`spawner.gd`). Food, resource regeneration, predator population — active zone only.
- **RNG** (`rng.gd`). Named seeded streams (worldgen, spawner, combat, strategy, interventions), all derived from the master seed; every random draw goes through one of them.
- **Save** (`save.gd`). Serialization, autosave, slots. See §Saves.
- **View** (`res://view/`). Tile-window renderer, MultiMesh agents, minimap, day/night modulation. Reads state, never writes it.
- **UI** (`res://ui/`). HUD, inspector, parameter panel, statistics, intervention tools, queen panel.
- **Server / Client / Net** (`res://server/`, `res://client/`, `res://net/`, v4). Headless tick loop with connected observers; snapshot-plus-deltas protocol. See ROADMAP v4.

## World model

Each cell is a stack of layers:

| Layer | Storage | Values |
|---|---|---|
| Terrain | `PackedByteArray` | `GROUND` (passable), `WATER`, `WALL` (impassable to all) |
| Structure | `PackedByteArray` | `NONE`, `NEST_WALL`, `PAVEMENT`, `STORAGE_FOOD`, `STORAGE_RES`, `QUEEN_CHAMBER` |
| Object | sparse `Dictionary[cell -> Object]` | `FOOD(units)`, `RESOURCE(patch_id)`, `PILE(type, units)` — at most one object per cell |
| Agents | sparse `Dictionary[cell -> agent_id]` | myrmeks and predators — at most one agent per cell |
| Knowledge | `PackedByteArray` per nest | 0 unknown, 1 known |

The world is divided into **64x64 chunks** (a 32x32 grid at the default 2048x2048). A chunk stores an active flag, its agent/object lists, and a changed flag for the minimap. The **active zone** — chunks within a radius of the nest plus chunks with known cells or agents — is the only place spawning and regeneration run; the rest of the map sleeps until discovered.

**Generation:** seed + size (256–2048, multiple of 64) + water/rock shares + patch count → `FastNoiseLite` terrain smoothed by a cellular automaton; the start point is the centre of the largest connected ground region, cleared to radius 12; guarantees near the start (≥2 resource patches and ~20 food within 30 cells) make the first day hard but possible. The queen's cell becomes `QUEEN_CHAMBER` at no cost; there is no starting nest.

**Dynamics:** food clusters spawn per active chunk (`T_food`/`p_food`); depleted patches regenerate after `T_res`; each predator species is kept at a target count, spawning on a 60–150 cell ring outside the nest's vision; a predator carcass becomes `FOOD`.

## Time and the tick

Discrete ticks at 10/s base speed (0.5x–16x multipliers, pause, single-step). Agent speed is `move_cooldown` — ticks between steps. The day cycle is day 600 / dusk 60 / night 400 / dawn 60 = 1120 ticks. At night predators halve their cooldown and eating time and gain +50% vision; myrmeks lose 1 vision (detection; the reveal radius is capped by current vision); the queen's night policy pulls the nest inside, posts guards at gaps, and by default seals gaps at dusk and reopens them at dawn (`seal_at_night`).

**Phase order inside every tick (invariant):**

1. Environment: clock, spawning, regeneration.
2. Queen planning — every `N_plan` ticks (default 10).
3. Myrmeks: one state-machine step each, in id order.
4. Predators: the same.
5. Combat and deaths.
6. Knowledge update (reveal around myrmeks).
7. Render sync (only when this frame renders).

```mermaid
flowchart LR
    e["1 · environment<br/>clock · spawn · regen"] --> p["2 · queen planning<br/>every N_plan ticks"]
    p --> m["3 · myrmeks<br/>one step each, id order"]
    m --> d["4 · predators<br/>one step each, id order"]
    d --> c["5 · combat<br/>deaths · carcasses · cargo drops"]
    c --> k["6 · knowledge<br/>reveal around myrmeks"]
    k --> r["7 · render sync<br/>only when this frame renders"]
    r -.->|"tick + 1"| e
```

One full pass is one tick, and the order is a contract: the environment moves first, the queen plans on her own cycle, myrmeks act before predators, combat resolves the encounters, knowledge is revealed from the new positions, and rendering comes last — only when a frame is actually drawn, which is why a headless run is the same simulation minus step 7.

## Agents

One record shape for everyone: `id`, `kind`, `type`, `nest_id`, `cell`, `hp`/`hp_max`, `energy`/`energy_max`, `move_cooldown`/`move_timer`, `vision`, `attack`, `carry` (type, units, capacity), `state`, `task_id`, `target_cell`, `path`. No age. **Movement is 8-directional with uniform cost; all radii and adjacency use Chebyshev distance** — which is why wall rings are squares.

**Roles** (default mix 15/20/15/30/20 + the queen = 101):

| Role | Key stats | Job |
|---|---|---|
| Scout | vision 5, cooldown 1, hp 3 | Opens the frontier, one angular sector each; reveals radius 5 (others reveal radius 2) |
| Guard | vision 4, cooldown 2, hp 20, attack 5 | Patrols, intercepts, holds gaps, escorts groups, guards sites |
| Builder | cooldown 2, hp 5, carries 1 | Builds walls/storages/paving (`build_time` 10), demolishes anything (`demolish_time` 5, resource returned) |
| Carrier | cooldown 1, hp 4, carries 2 | Food to storage, piles to storage, food to the hungry, resources to builders |
| Harvester | cooldown 2, hp 5, carries 3, mines 1/5 ticks | Works an assigned patch; hauls or piles the yield |
| Queen | immobile, hp 50 | Coordinator; eats from storage automatically |

**State machine (all roles):** `IDLE → GO_TO → WORK → RETURN → DEPOSIT → IDLE`, with interrupts `HUNGRY` (energy < 40: asks for food, keeps working), critical (< 15: drops the task, heads home or waits for a carrier), `FLEE` (workers near a predator), `FIGHT` (guards only), `DEAD`. Adjacent nest-mates can hand cargo over.

```mermaid
stateDiagram-v2
    [*] --> IDLE
    IDLE --> GO_TO: task assigned
    GO_TO --> WORK: target reached
    GO_TO --> IDLE: target gone / unreachable
    WORK --> RETURN: cargo full / work done
    WORK --> IDLE: target exhausted
    RETURN --> DEPOSIT: at storage or neighbour
    DEPOSIT --> IDLE
    IDLE --> HUNGRY: energy < 40
    GO_TO --> HUNGRY: energy < 40
    WORK --> HUNGRY: energy < 40
    HUNGRY --> IDLE: fed (+50 energy)
    HUNGRY --> [*]: energy 0 — starved
    note right of HUNGRY
        < 40 · asks for food, keeps working
        < 15 · drops the task, heads home
        or waits for a carrier
    end note
    GO_TO --> FLEE: predator adjacent (workers)
    WORK --> FLEE: predator adjacent (workers)
    FLEE --> IDLE: clear
    FLEE --> [*]: caught — eaten
    IDLE --> FIGHT: enemy in range (guards only)
    FIGHT --> IDLE: enemy dead or gone
    FIGHT --> [*]: killed
```

The working loop is the top row — take a task, walk, work, return, deposit. Everything else is an interruption: hunger overrides in two grades (ask for food at 40, abandon the task at 15), workers flee rather than fight, only guards enter `FIGHT`, and the two exits are being eaten or starving. Whatever a myrmek carried at death drops on its cell (§Combat).

**Energy:** max 100; idle 0.01/tick; step 0.05 (+50% loaded; 0.03 on paving); attack 0.5; one food unit = +50; queen 0.1/tick, sated at ≥70; energy 0 = death. Energy and every other accumulated quantity are stored as **fixed-point integers** (thousandths of a unit: idle 10, step 50/75/30, attack 500, one food unit 50 000, max 100 000) — see §Determinism and replay. **On any death carried units drop on the cell as `FOOD`/`PILE` (lost if the cell already holds an object); an eaten or starved body disappears.**

**Predators** (energy-driven: hungry hunts, sated wanders, starving dies):

```mermaid
stateDiagram-v2
    [*] --> WANDER
    WANDER --> HUNT: myrmek in vision
    HUNT --> ATTACK: adjacent cell
    HUNT --> WANDER: prey lost
    ATTACK --> EAT: prey dead
    EAT --> REST: eat_time elapsed
    REST --> WANDER: rested
    REST --> HUNT: hungry again
    note right of EAT
        immobile for eat_time
        (halved at night) —
        an easy target for guards
    end note
    ATTACK --> FLEE: hp < 30% (lizard)
    HUNT --> FLEE: hp < 30% (lizard)
    FLEE --> WANDER: safe
    FLEE --> [*]: killed → carcass becomes FOOD
    ATTACK --> [*]: killed → carcass becomes FOOD
    WANDER --> [*]: energy 0 — starved
```

A predator is a hunger loop, not a script: it wanders until something edible enters its vision, hunts, strikes, and is then pinned in place for `eat_time` — the window in which guards kill it. Only the lizard flees when hurt; every carcass converts to `FOOD`, so a fight won feeds the nest.

| Species | Behaviour | Cooldown d/n | Vision d/n | hp | Attack | Eat d/n | Carcass |
|---|---|---|---|---|---|---|---|
| Spider | Ambush near routes | 2 / 1 | 6 / 9 | 15 | 4 | 20 / 10 | 5 |
| Beetle | Slow tank, never flees | 3 / 2 | 4 / 6 | 40 | 6 | 30 / 15 | 8 |
| Lizard | Chaser; night extra step every 2nd tick; flees < 30% hp | 1 / 1+ | 8 / 12 | 25 | 5 | 15 / 6 | 6 |

**Combat:** every tick, an agent with an attack value damages an enemy in one of its 8 neighbouring cells; damage stacks across attackers; a predator in a gap is hit from both sides. A worker dies to one predator hit; guards survive several.

## Nest

- **Knowledge:** a cell seen once by any nest myrmek is known forever; known cells show live state. The **frontier** (known passable cells bordering unknown) is maintained incrementally.

```
   outside                                  #  NEST_WALL — impassable to everyone
   · · · · · · · · · · ·                    .  interior ground (this is the capacity)
   · # # # # # # # # # ·                    Q  QUEEN_CHAMBER (free, on the queen's cell)
   · # . . . . . . . # ·                    F  STORAGE_FOOD   R  STORAGE_RES (2 res each)
   · # . = = = . . . # ·                    =  PAVEMENT — cooldown ÷ pave_speed
   · # . = Q F R . . # ·                    G  guard holding the gap
   · # . = = = . . . # ·                    ⟵  the gap: a plain ground cell, no wall.
   · # . . . . . . . # ·                        Anything may pass — one agent per cell,
   · # # # # G # # # # ·                        so one guard physically blocks it.
   · · · · ·⟵· · · · · ·
```

The flood fill from `Q` spreads over the 21 `.`/`=` cells and stops at `G`, so this nest's capacity is 21 myrmeks — everyone else sleeps outside by the gap, under guard. At dusk a builder walls `G` shut (`seal_at_night`) and reopens it at dawn.

- **Interior is computed, not built:** a flood fill from the queen chamber, blocked by walls, stopping at gaps. Its passable-cell count is the nest's capacity (target: population + ~10% margin, since one agent fits per cell). When capacity or storage runs short, the queen plans a wider ring; after it closes, the old ring is dismantled and its resources return.
- **Walls and gaps:** a wall costs 1 resource and is impassable to everyone; a storage cell costs 2 and holds 20 units; a gap is an open ground cell — one guard standing in it physically blocks it. Builders may wall any ground cell and demolish any wall (seal at dusk, reopen at dawn, break out if besieged).
- **Paving and roads:** `PAVEMENT` (1 resource) divides `move_cooldown` by `pave_speed` (default 2) and cuts step energy; the nest counts decaying per-cell traffic, and cells above `pave_traffic` enter the `PAVE` queue after walls and storages — roads grow along real routes. Predators get no benefit. Paving does not define "inside".
- **Flows:**

```mermaid
flowchart LR
    patch["resource patch · shared reserve"] -->|"harvester mines<br/>1 unit / 5 ticks"| cargo["cargo or pile<br/>beside the patch"]
    cargo -->|"harvester or carrier"| resstore[("STORAGE_RES<br/>20 units / cell")]
    resstore -->|"builder takes 1"| built["wall · storage cell · pavement"]
    built -.->|"demolished — resource returned"| resstore
    mapfood["food on the map<br/>spawned in active chunks"] -->|"carrier, 2 units"| foodstore[("STORAGE_FOOD<br/>20 units / cell")]
    foodstore --> queen["queen<br/>eats automatically"]
    foodstore --> inside["hungry myrmeks<br/>inside the nest"]
    foodstore -->|"carrier delivers · FEED_MYRMEK"| field["hungry myrmeks<br/>in the field"]
    carcass["predator carcass"] --> mapfood
    death["any death"] -.->|"carried units drop on the cell"| mapfood
```

Two currencies with one junction each: resources flow patch → storage → structure and return whenever something is demolished; food flows map → storage → mouths, with carriers as the only movers between stations. Deaths leak carried units back onto the map, and predator carcasses are the reward channel for defence.

## The queen's brain

**Tactical level — every `N_plan` ticks:** gather state (food, piles, patches, predators on the known map, hungry myrmeks, build queue, storage levels, frontier) → build the task board (`EXPLORE`, `FETCH_FOOD`, `FETCH_PILE`, `HARVEST`, `BUILD`, `FEED_MYRMEK`, `DELIVER_RES`, `PATROL`, `INTERCEPT`, `HOLD_GAP`, `OPEN_GAP`, `CLOSE_GAP`, `PAVE`, `ESCORT`, `GUARD_SITE`) → rank by policy (safety → feeding → food income → construction → resources → exploration) → assign greedily by the distance field. **Known but unreachable cells (no finite distance) are never assigned as targets.** A task whose target vanishes is cancelled. Guard distribution across patrol/gaps/escort/sites is the defence-strategy space ("fortress", "convoy", "outposts", adaptive). While no nest exists, a hardcoded first-day plan runs: harvesters to the nearest patch, builders raise a radius-5 ring (~40 walls) with one gap and a food storage, guards ring the queen, scouts open the surroundings.

**The tactical level is complete on its own.** With no strategy program at all, the queen runs on her built-in algorithm: the default policy plus the hardcoded plans (the first-day plan, night policy, ring expansion), directing every myrmek herself. This is a real playing mode, not a stub — it is what runs through phases v0.1–v0.4, before Lua exists in the project, and its bar is exactly the prototype's balance criterion: **survive the first night on at least half of all seeds, with no program and no model**. A strategy program never replaces this level; it only *tunes the policy* the level already obeys.

**Strategic level — the strategy program:** a module with `plan(s) -> policy` and a persistent `memory` table, executed by the queen on every planning cycle (microseconds). It assigns no tasks, moves no myrmeks, and sees nothing beyond the nest's knowledge.

```mermaid
flowchart TB
    world["sim state (the nest's known map only)"] --> sv["StateView — the only window<br/>copied scalars + engine-side helpers<br/>predators_within · nearest_food_dist · cell"]
    sv --> planf["plan s → policy<br/>sandboxed Lua 5.4 · microseconds · instruction-limited"]
    planf <--> mem[("memory<br/>plain data · persists between calls · saved with the state")]
    planf --> check{"normalize goals · schema + bounds check"}
    check -->|"out of bounds / error / interrupted"| keep["misfire: previous policy this cycle<br/>plan_errors_to_fail in a row → FAILED"]
    check -->|ok| policy["policy<br/>ranking weights · guard distribution · night policy<br/>build plan · pave threshold · capacity margin"]
    policy --> board["task board — tactics, every N_plan ticks<br/>gather → build tasks → rank → assign greedily by distance field"]
    board --> agents["one task per myrmek"]
    agents -->|"outcomes: deaths · food · capacity"| world
    agents -.-> score["strategy_eval — dawn scorecard<br/>declared goals vs actuals + engine floors"]
    goalsd[("goals: coverage over the six,<br/>normalized to sum to 1")] -.-> score
    score -->|"healthy · warning"| planf
    score -->|"failing"| ladder["escalation ladder<br/>demote to BUILTIN · blacklist ·<br/>best-fit eligible candidate · then the LLM"]
    world -.-> sit["situation: FOUNDING · SIEGE · FAMINE ·<br/>CROWDED · STABLE (hysteresis)"]
    sit -->|"demand over the same six goals"| ladder
    goalsd -.->|"fit = Σ demand × coverage"| ladder
    sit -.-> sv
    ladder -.-> planf
    planf -.->|"request_revision"| ladder
```

Read it top to bottom: state is condensed into the `StateView`, the sandboxed `plan()` turns it into a policy, validation lets that policy through or keeps the previous one, and the task board turns policy into per-myrmek tasks. The right-hand side is the judgment loop: declared coverage and the day's outcomes meet in the dawn scorecard, a failing verdict falls into the escalation ladder, and the situation's demand — not the strategy's own opinion — decides which candidate the ladder promotes next. The two levels run on different clocks: `plan()` is microseconds every `N_plan` ticks, while the model is called rarely and never blocks a tick. In the v0 prototype the right-hand judgment loop does not exist yet — the diagram collapses to the left column plus the `BUILTIN` fallback (§What v0 implements).

- **`StateView`** is the only window: simple values copied into a dictionary (day phase, population by role, deaths by cause, storages, queen energy, known food/patches/predators with distances, frontier size, capacity vs population, gap status, and the current **situation with its demand vector**) plus engine-side helpers (`predators_within(r)`, `nearest_food_dist()`, `patch_reserve(id)`, `cell(x, y)`, and `s.rand()` from the `strategy` RNG stream). The `World` object is never passed.
- **Policy** comes back as a table — ranking weights, guard distribution, night policy, build plan, paving threshold, capacity margin, `request_revision`, and (from v2) the desired role mix — converted to a `Dictionary` and checked against a schema and value bounds.
- **`StrategyRunner`** hides the execution environment. From the first prototype (v0.5) the runner is **Lua 5.4 via godot-luaAPI**: a real sandbox — only `base`/`table`/`string`/`math` are bound, so `os`, `io`, `require`, `load` and the engine simply do not exist for a strategy — with an instruction-counter hook that interrupts a looping `plan()` and protected calls for errors. Two determinism rules ride the seam. First, **`math.random` and `math.randomseed` are removed from the binding**: Lua 5.4 seeds its own generator unpredictably at state creation, which would quietly break bit-identical replay — a strategy that wants noise calls **`s.rand()`**, drawn from the named `strategy` stream like every other journaled draw. Second, **everything list-shaped in `StateView` arrives as a Lua sequence** traversed with `ipairs`; no API table has meaningful `pairs` order, and the contract test feeds `plan()` a permuted copy of the same state and requires the identical policy back. `memory` is plain data only (it is saved with the state). There is no GDScript runner; the seam stays so the environment could be swapped without touching the rest of the code.

**Who writes the program — `queen_brain`:**

| Mode | Who decides the policy | Changes |
|---|---|---|
| `BUILTIN` | **No program at all** — the queen's own algorithm: default policy + the hardcoded plans, assigning every myrmek directly | Never; this is the zero point every program is measured against |
| `PROGRAM` | A hand-written Lua program from `res://strategies/` or the user's library | Never by itself; swapped or edited by the person, reloaded on the fly |
| `LLM` | The model writes a program at start and revises it by results | v0: the first night, more than three deaths since dawn, `request_revision`. From v1.5: also a failing scorecard once the library budget is spent (the ladder). Always at most once per `N_revision` |
| `LEARNED` (v6) | A small NN tunes a program's parameters / picks one from the library; asks the LLM at low confidence | Every planning cycle |

`BUILTIN` is also the **fallback**, reached without ceremony: no API key, every candidate version rejected, a strategy file that will not load — the nest keeps playing on its own algorithm and says so in the queen panel. Nothing in the simulation depends on a program existing.

**The shipped strategies.** Hand-written Lua programs in `res://strategies/` — the `PROGRAM` mode's content, the arena's opponents, and what the `MOCK` provider serves in tests. **v0.5 ships exactly one, `baseline.lua`** (the balanced default): the prototype has nothing to select between and deliberately no selector. `fortress.lua` (guards massed at the gaps, always seal, a tight ring), `forager.lua` (food weighted heavily, fewer guards, a bigger harvest share) and `growth.lua` (a wider ring early, build priority once the store is safe) join in v1.5, together with the library and the judging apparatus below. Each is a few dozen readable lines within the six prototype policy fields, and the first thing the arena answers is whether any of them — or anything Gemini writes — actually beats `BUILTIN`.

**Scope note: everything from here to the arena is v1.5, not the prototype.** Situations and demand vectors, coverage goals, the scorecard, the escalation ladder with its budget, fingerprints and ledger — all of it arrives in v1.5, once there is a library worth choosing from. **v0 runs one strategy and no selection or evaluation algorithm at all:** `baseline.lua` or whatever the model writes, validated before apply; a broken version is rejected and the current keeps running; `plan_errors_to_fail` misfires in a row, or nothing loading at all, drops the nest to `BUILTIN`; the model is asked to revise on three plain triggers (the first night, more than three deaths since dawn, `request_revision`). That is the entire v0 story — the machinery below is what replaces those plain triggers when the library grows.

**Who decides what the nest needs *now*.** A strategy declaring its own goals only answers half the question; the other half is which goals matter at this moment, and that is **the engine's call, not the strategy's and not the model's**. Every cycle `strategy_eval.gd` classifies the nest's **situation** from the same numbers the task board already has — a pure function of state, so it is deterministic and testable:

| Situation | Recognized by | What it demands most |
|---|---|---|
| `FOUNDING` | No closed ring yet (day 1, or after a ring is lost) | `shelter`, then `food` — close a ring with a gap and stock the store before dusk |
| `SIEGE` | Predators inside the known radius, or deaths rising | `survival` and `shelter` — losses down even at the cost of income |
| `FAMINE` | Store below the reserve, or queen energy falling | `food`, then `queen` — income above everything |
| `CROWDED` | Capacity below population (beyond `capacity_grace`) | `capacity` — a wider ring and storages, ahead of population |
| `STABLE` | None of the above | `territory` and `capacity` — the only situation where growth is the point |

Each situation's demand is a weighted vector over the six goals below (the exact numbers are in the demand table).

This is what makes picking a strategy possible: a candidate's **declared goals are matched against the current demand**, and the ladder promotes the best *fit* among eligible programs, breaking ties by arena rank. `growth.lua` is an excellent program and the wrong one during a `FAMINE`; `fortress.lua` is right for a `SIEGE` and will slowly strangle a `STABLE` nest. Situations carry **hysteresis** (`situation_hysteresis`, default 1 day): a situation must hold before it takes effect, so the nest does not swap strategies every dawn on noise. The current situation and its demand ride in the `StateView` (`s.situation`), so a program can also branch on it itself, and in the LLM dossier, so the model writes for the situation the nest is actually in.

The observer may **pin an objective** from the queen panel — "grow capacity", "survive the night" — which overrides the classifier until unpinned. That is a queen-level knob like choosing a strategy, not an order to a myrmek, and it enters as a journaled command at a tick boundary, so replays are exact.

**The six goals — a closed list.** Everything a nest can be trying to do is one of six, fixed once and shared by the situations, the strategies, the scorecard, the arena and the model. Each has one measurable indicator, a **floor** the engine enforces unconditionally, and an **ambition target** that counts as fully achieved:

| Goal | Indicator | Floor (absolute) | Ambition target |
|---|---|---|---|
| `survival` | myrmek deaths per day ÷ population | population must not halve in a day | no deaths for a whole day |
| `food` | store ÷ reserve, and income ÷ consumption | the store must not sit empty for a whole day | store ≥ 2× reserve with income ≥ consumption |
| `shelter` | share of the population sheltered at night, ring intact | — (a breach shows up as `survival`) | everyone inside, every gap sealed at dusk |
| `capacity` | interior capacity ÷ population | not below population for more than `capacity_grace` days | capacity ≥ population + margin |
| `territory` | known cells gained per day, patches found | — | the frontier keeps moving, patches in reserve |
| `queen` | queen energy, distance from the nearest predator | the queen must not starve | energy ≥ 70 with no predator inside |

**Every strategy covers all six — to a degree.** A program exports a `goals` table beside `plan` giving each of the six a number from 0 to 1, and the engine **normalizes the vector to sum to 1**. That normalization is the whole point: ambition is a budget, so a program cannot promise everything, it has to choose. The shipped four make their ideas arithmetic:

| Strategy | `survival` | `food` | `shelter` | `capacity` | `territory` | `queen` |
|---|---|---|---|---|---|---|
| `baseline.lua` | 0.20 | 0.25 | 0.20 | 0.15 | 0.10 | 0.10 |
| `fortress.lua` | 0.40 | 0.15 | 0.30 | 0.05 | 0.00 | 0.10 |
| `forager.lua` | 0.15 | 0.45 | 0.10 | 0.10 | 0.15 | 0.05 |
| `growth.lua` | 0.10 | 0.20 | 0.10 | 0.35 | 0.20 | 0.05 |

**Each situation demands the same six, weighted.** The demand is a vector over the identical list, authored in `sim_params.tres`, each row summing to 1:

| Situation | `survival` | `food` | `shelter` | `capacity` | `territory` | `queen` |
|---|---|---|---|---|---|---|
| `FOUNDING` | 0.20 | 0.25 | 0.35 | 0.05 | 0.05 | 0.10 |
| `SIEGE` | 0.40 | 0.10 | 0.30 | 0.05 | 0.00 | 0.15 |
| `FAMINE` | 0.20 | 0.50 | 0.05 | 0.00 | 0.05 | 0.20 |
| `CROWDED` | 0.15 | 0.20 | 0.20 | 0.40 | 0.00 | 0.05 |
| `STABLE` | 0.15 | 0.20 | 0.05 | 0.25 | 0.25 | 0.10 |

**Who authors the demand vector.** Somebody has to say how badly each of the six is needed *right now*, because that vector is what selects the strategy. Three authors, in strict precedence:

1. **The engine, by default.** The situation classifier picks one of the five authored demand vectors above — a pure function of state with hysteresis. Nothing is invented at runtime: the five vectors are data in `sim_params.tres`, so the same state always produces the same demand, and a test can assert it.
2. **The observer, when they choose to.** From the queen panel they can pin a situation, or set the six numbers directly for finer control than the five presets give; the pin holds until released. It arrives as a journaled command at a tick boundary, so a replay makes the same choice.
3. **The model — never.** The LLM writes programs; it does not set the demand. That boundary is deliberate: the demand is the *question* and a program is the *answer*, and a model that set both would be grading its own homework — the arena's rankings and the scorecard's verdicts would stop meaning anything.

The six numbers are therefore the shared language of the whole mechanism: the engine asks in them, a strategy answers in them, the scorecard judges in them, the arena ranks in them, and the dossier explains a failure in them. In v0 the demand is always one of the five authored vectors; blending two adjacent situations into a weighted mix is an additive refinement for v1.5 if edge cases call for it.

**Fit is a dot product.** `fit = Σ demand[g] × coverage[g]` over the six — one multiplication per goal, deterministic, and explainable to the observer as a number. In a `FAMINE`: `forager` scores 0.28, `baseline` 0.20, `fortress` 0.19, `growth` 0.15, so the ladder promotes `forager` and the queen panel can say why in one line. In a `SIEGE` the same arithmetic gives `fortress` 0.28 against `baseline` 0.19. Ties break by arena rank for that situation (v1.5).

**Coverage sets the bar the strategy is held to; floors are not negotiable.** For each goal the expected value is `floor + coverage[g] × (target − floor)`: claim 0.45 of `food` and you are judged near the ambition target on food; claim 0.00 of `territory` and an unexplored day is not held against you. What coverage can never do is lower a **floor** — the population halving, a starved queen, a store empty for a day, capacity under population past its grace — those are failures at any coverage, which is why `fortress.lua` declaring `queen` 0.10 still cannot let the queen starve.

**The scorecard.** At every dawn `strategy_eval.gd` measures the six indicators over the past day, compares each against its coverage-derived expectation, and produces a `Scorecard` (§Contracts) with a verdict weighted by the **current situation's demand**: **healthy** (every demanded goal met), **warning** (a goal missed that this situation weights lightly), **failing** (a floor breached, a heavily demanded goal missed, or two consecutive `warning` days). So the same miss is read differently depending on what the nest actually needed — missing `territory` during a `FAMINE` is noise; missing `food` is the whole problem. Floors are checked immediately, not only at dawn, so a collapse does not get a full day to finish. A misfiring `plan()` — a runtime error or the instruction limit — keeps the previous policy for that cycle; **`plan_errors_to_fail` consecutive misfires (default 3) count as a floor breach** and send the version down the ladder. A freshly promoted version gets `probation_days` (default 1) of grace on everything but the floors. Every scorecard is journaled, and those journaled scorecards are exactly what the LLM's revision prompt and the arena's ranking read, so "good" has one definition across the live game, the arena and the model.

**The escalation ladder.** On a `failing` verdict the queen does not keep hoping:

```mermaid
stateDiagram-v2
    [*] --> BUILTIN: no program configured
    BUILTIN --> PROBATION: promote a candidate
    PROBATION --> ACTIVE: healthy through probation
    PROBATION --> FAILED: floor breached
    ACTIVE --> ACTIVE: healthy or warning
    ACTIVE --> FAILED: floor breached, or 2 warning days
    FAILED --> BUILTIN: demote at once, blacklist the version
    BUILTIN --> PROBATION: best-fit eligible candidate, budget permitting
    BUILTIN --> ASKING: budget spent or nothing eligible left
    ASKING --> PROBATION: answer passes validation and is no rehash
    ASKING --> BUILTIN: unavailable, rejected, or a rehash
    note right of BUILTIN
        eligible = untried in this crisis, not blacklisted,
        and no fingerprint sibling of a version that already
        failed. Among those, best fit = declared goals against
        the current situation's demand, ties by arena rank.
        Budget: library_attempts (2) per crisis.
        The nest plays on the queen's own algorithm
        throughout; ticks never wait for an answer.
    end note
    note right of ASKING
        the dossier sent to the model: every failed source
        with its scorecards, the floors breached, the
        blacklist and its reasons, and what BUILTIN
        achieved over the same days
    end note
```

In order: **demote to `BUILTIN` immediately** (the queen's own algorithm is never worse than a broken strategy and is always available), **blacklist** the failed version with its scorecard, **promote the best-fit eligible candidate** from the library — the one whose declared goals answer the current situation's demand, and once the budget is spent or nothing is eligible, **ask the LLM**. If the model is unavailable or every answer fails validation, the nest stays on `BUILTIN` and the queen panel says why. There is no path back up except a validated program serving its probation.

**Two library strategies are not a carousel.** Cycling through near-identical programs wastes days the nest may not have, so eligibility is deliberately narrow and budgeted:

- **A crisis budget.** A demotion opens (or continues) a *crisis*, and within one crisis the ladder promotes at most `library_attempts` candidates (default **2**). Spent — the library is done being asked and the LLM is next. The budget is counted in attempts, never in real seconds.
- **A similarity guard, so "already tried" generalizes.** Each program carries a **fingerprint**: the vector of policies it produced on the dry run over a fixed set of recorded states, plus its declared `goals`. Programs within `similarity_eps` of each other are *siblings*; when one fails, its siblings are skipped as `skipped_similar` **without consuming budget**, because they would behave the same. This is what actually stops the carousel — two strategies that differ only cosmetically count as one idea, and that idea has been tested.
- **Blacklisting with earned rehabilitation.** A failed version is blacklisted for `blacklist_days` of **simulation** time (default: the rest of the run in v0; a window from v1.5, when the library is large enough for it to matter). The window exists because the world moves — a strategy that failed with no walls up may be right once capacity is built — but re-entry is never free: a rehabilitated version starts on probation, and a second failure blacklists it for the whole run.
- **Everything is measured in ticks and days, never wall-clock.** A real-time window would make the same seed decide differently at 1x and 16x, which would break replay; sim-days and attempt counts keep the ladder deterministic.

**What the model is told.** When the ladder reaches the LLM it does not ask in the abstract — `nest_report.gd` assembles a **dossier of the failures**: the full source of every program that failed in this crisis, each with its scorecards (declared goal versus actual, per day), which floors were breached and when, the blacklist with reasons including anything skipped as a sibling, and — as the reference line — what `BUILTIN` achieved over the same days. The instruction that accompanies it is explicit: these ideas have been tried and these are their numbers, do not send an equivalent back. And that instruction is *enforced*, not merely requested: a returned program whose fingerprint is a sibling of a blacklisted one is rejected by validation as a rehash, exactly as a program that fails its bounds check would be.

**The LLM loop:** at the start of a run the model receives the language description, the `StateView`/policy/goals API, the six goals and the current situation, and returns a program; a revision receives the failure dossier above — or, outside a crisis, the current program with its scorecards and the log of which branches fired — and returns a new version plus a change note. Every version passes validation — compile, the sandbox, policy **and goals** bounds, the fingerprint check against the blacklist, and a dry run on recorded states from the last day — or is discarded, and the nest stays where the ladder left it (`BUILTIN` during a crisis, the current program otherwise). Calls are asynchronous (`HTTPRequest`); the simulation never waits; a minimum real-time interval prevents request storms at 16x. Every accepted version is journaled with its tick, so saves and replays reproduce LLM runs without new calls. **The model never controls an individual myrmek.**

```mermaid
sequenceDiagram
    participant Sim as tick loop
    participant Pol as queen_policy
    participant Prov as provider · Gemini or MOCK
    Sim->>Pol: trigger — a failing scorecard with the library budget spent ·<br/>first night · predator inside · request_revision · N_revision elapsed
    Pol->>Prov: async HTTPRequest — language + StateView/policy/goals API,<br/>the failure dossier: every failed source with its scorecards,<br/>floors breached, the blacklist and BUILTIN's numbers
    loop while the answer is in flight
        Sim->>Sim: ticks continue on the CURRENT program
    end
    Prov-->>Pol: new program + change note
    Pol->>Pol: compile · sandbox · policy and goals bounds · dry run on<br/>recorded states · fingerprint check — a rehash of a<br/>blacklisted version is rejected like any invalid program
    alt validation passes
        Pol->>Sim: autosave, then promote on probation at a tick boundary
        Pol->>Pol: journal {source, tick, change_note, metrics}
    else validation fails
        Pol->>Pol: discard — the nest stays on BUILTIN
    end
    Note over Sim,Prov: a minimum real-time interval prevents request storms at 16x ·<br/>the journal replays the run later with no new calls
```

The point of the sequence is what the simulation does while the request is out: it keeps ticking on whatever the ladder left active, because the call is asynchronous and an answer enters only at a tick boundary — after compilation, the sandbox, the bounds checks, the dry run and the fingerprint comparison against the blacklist. The journal line at the bottom is what makes an LLM run replayable without the LLM.

**Strategy library:** programs are files (`user://strategies/`) with names, versions, and revision history; any can be loaded as `PROGRAM` or raced headless on identical seeds — the arena.

**The arena** runs the matrix of *strategies × seeds* **sequentially in a single headless process** (`res://tools/run_arena.gd`). One process is the deliberate choice: each cell of the matrix gets its own fresh world from its own seed, nothing is shared, and the whole matrix is therefore reproducible by construction — re-running the same strategy list and seed list yields the same table, which is the only thing that makes "strategy A beats strategy B" a claim rather than an impression. Each run writes one results table under `user://arena/<run_id>/` — per cell: survival, days reached, deaths by cause, food collected, capacity growth, ticks elapsed — plus a summary ranking. Parallel worker processes are a later optimization, admissible precisely because the cells are already independent and individually seeded; they must never share simulation state, and a parallel run must reproduce the sequential table.

## Contracts

The stable seams. Changing a contract must change its contract test (§Testing).

- **Tick phase order** — the seven phases above, exactly.
- **`StateView`**: the scalar dictionary + helper functions; identical for the Lua runner and the API description sent to the LLM. Grows additively.
- **Policy table**: field set, types, and bounds, held in `policy_schema.gd` — the single source from which the validation and the LLM's API description are both generated, so the two cannot drift apart.
- **`StrategyRunner`**: `load(source) -> ok|error`, `plan(state_view) -> policy`, persistent `memory`, execution limits.
- **Task**: `{type, target, priority, assignee}` and its lifecycle (created → assigned → done/cancelled).
- **LLM provider**: async `request_program(context) -> {program_source, change_note}`; `MOCK` serves a file.
- **Agent record** and **cell layers** as defined in §Agents / §World model.
- **Save format**: versioned JSON header + compressed `var_to_bytes` body (§Saves).
- **Strategy version record**: `{id, source, author_mode, tick, change_note, metrics}` — the journal replays runs without re-calling the model.
- **Situation** (derived by the engine, pure function of state): `{situation: FOUNDING|SIEGE|FAMINE|CROWDED|STABLE, since_tick, demand: {the six goals → weight, summing to 1}, pinned_by_observer}` — carried in `StateView` and the LLM dossier; hysteresis before a change takes effect.
- **Goal coverage** (declared by a strategy): `{survival, food, shelter, capacity, territory, queen}`, each 0..1, normalized by the engine to sum to 1 — the strategy's ambition budget. It sets each goal's expectation (`floor + coverage × (target − floor)`) and is dotted with the situation's `demand` to score fit. It can never lower a floor.
- **Scorecard**: `{tick, day, strategy_id, goals: [{goal, expected, actual, met}], verdict: healthy|warning|failing, floor_breached}` — journaled per day; read by the queen panel, the LLM revision prompt and the arena's ranking, which is why all three agree on what "good" means.
- **Fingerprint**: the policy vector a program produces over a fixed set of recorded states, plus its declared `goals` — the similarity key that makes siblings skippable and a rehashed LLM answer rejectable.
- **Attempt ledger** (per run, journaled): `{crisis_id, strategy_id, fingerprint, outcome: promoted|failed|skipped_similar|rejected_rehash, tick, blacklist_until_day}` — the record the ladder consults, so "already tried" survives a save/load and replays identically.

## Pathfinding

No global A* over millions of cells:

- A **distance field** to the nest (`PackedInt32Array`): weighted BFS (integer Dijkstra) over known passable cells only — paving costs 1, ground `pave_speed`. Recomputed incrementally on reveals and structure changes, or fully every ~100 ticks. Going home is gradient descent, no search.
- A **local `AStarGrid2D`** on the rectangle between agent and target plus a 16-cell margin, known cells only, `weight_scale` for paving; built on demand, then released.
- Scouts: frontier target + local A*; fallback random walk. Paths are cached per agent; replan when the next cell stays occupied several ticks.

## Determinism and replay

One master seed drives everything, and randomness flows through **named streams** (worldgen, spawner, combat, strategy, interventions) derived from it — so an observer intervention consumes only its own stream and shifts nothing else. Agents step in id order; observer commands apply at tick boundaries; LLM responses are journaled by tick. **Sim arithmetic is integer-only**: energy and every accumulated quantity are fixed-point (§Agents), and transcendental functions (sin/pow/exp) are banned inside `res://sim/` — so runs replay bit-identically across platforms (the macOS app and the v4 Linux server). Float noise is allowed only in worldgen, whose output is computed once from the seed and stored as byte arrays. Consequences: identical runs from a seed on any platform, save/load that continues bit-identically, the arena's fair comparisons, and (v3) full replay from seed + intervention journal alone.

## Performance and memory

At 2048x2048: terrain 4 MB + structures 4 MB + knowledge 4 MB and distance field 16 MB per nest, sparse objects/agents — ~30 MB per nest. 100 myrmeks at 10 ticks/s is trivial even at 16x; 5000 (50k steps/s) is acceptable in GDScript with cheap steps and amortized BFS/A*; beyond that, simulate only active chunks and move hot paths to GDExtension.

## Saves

Since the sim is pure data, saving is serialization: format version, seed and parameters, clock, layer arrays, sparse object/agent dictionaries, nest state (storages, task board, build plan/queue, frontier), the whole strategy state (active mode and program, `memory`, the version journal, and from v1.5 the scorecards, the attempt ledger and the situation with `since_tick` and any observer pin), RNG stream states — `var_to_bytes` into a compressed file (`FileAccess.open_compressed`) beside a small JSON header (version, seed, day, population, date) for slot lists. The body carries **plain types only** — numbers, strings, arrays, dictionaries, packed arrays — and is read back with `bytes_to_var`, **never `bytes_to_var_with_objects`**: a save file can therefore never instantiate a class or execute code, which matters from v4 where saves live on a server and a file of unknown origin can arrive. A contract test asserts the round trip stays object-free. **Saving is automatic**: every dawn (`autosave_ticks` 1120), on exit, and before applying a new strategy version; the last 3 autosaves plus one per simulation day are kept; launch resumes from the latest autosave — "new world" is a deliberate action. Writes run on a background thread from array copies, to a temp name renamed on success, so a crash never corrupts the previous save. Loading rebuilds the render, minimap, and distance field. Backward compatibility across format versions is not guaranteed before v4 (saves move server-side there).

## Error handling and resilience

- **A candidate version** that fails any validation step — compile, sandbox, bounds, dry run, fingerprint — is simply never promoted; whatever was running keeps running. **The active program** failing is a different path: a misfiring `plan()` (runtime error, or interrupted by the instruction limit) keeps the previous policy for that cycle, and `plan_errors_to_fail` misfires in a row drop the nest to `BUILTIN` — directly in v0, via the escalation ladder from v1.5 (§The queen's brain).
- **LLM failures** (timeout, API error, malformed program) never stall the tick loop — calls are async and the current program continues; the minimum-interval guard holds at high speed.
- **Pathfinding**: an unreachable or vanished target cancels the task; blocked next-cells trigger replanning; scouts fall back to random walk.
- **Saves** are atomic (temp + rename) and off-thread; a failed save is logged and retried at the next trigger, never crashing the sim.

## Security

- Strategies run sandboxed from the first prototype: Lua 5.4 with only `base`/`table`/`string`/`math` bound (no `os`/`io`/`require`/`load`/engine access, no `math.random` — `s.rand()` serves the `strategy` stream instead) and an instruction counter. Every new version additionally passes schema/bounds validation and a dry run on recorded states. On the server (v4), where foreign strategies may appear, the same sandbox is the outer wall.
- LLM keys live in a **gitignored `.env` at the project root**; a committed `.env.example` documents the variable names and nothing else. Godot does not read `.env` itself, so a small loader in the app/server layer parses it into the process environment at startup — real environment variables always take precedence, which is how the v4 server supplies them (systemd `EnvironmentFile=`) without a second mechanism. The file is never committed, never bundled into an export, and never logged; a missing key parks `LLM` mode and drops the nest onto the fallback chain — the best-fit shipped strategy, else `BUILTIN` (§The queen's brain) — with a plain message, never a crash, and tests use `MOCK` and need no key at all.
- Server access (v4): one shared token for all clients, TLS (`wss://`) terminated by Caddy/nginx, external access via tunnel or VPN. No accounts.

## Observability

- **Event log**: deaths, patch depletion, predator killed / predator inside, gaps opened/closed, new ring; births from v2.
- **Statistics**: population by role, deaths by cause, storages, % of map known, predator counts; charts over recent days.
- **Queen panel**: the current **situation** with what it demands and how long it has held (plus the observer's pin, when set), the current mode and program with fired-branch highlighting from the last cycle, the active policy, the latest scorecard as declared-goal versus actual with its verdict, the promotion/demotion history (including why a version was blacklisted and what the ladder tried next), and in `LLM` mode the version history with change notes and response times, plus "revise now" and "save to library".
- **Autosave marker**: "saved: day N, time" — the save system is otherwise invisible.

## Configuration

Defaults are data (`res://data/*.tres` — `roles.tres`, `predators.tres`, `sim_params.tres`), edited live from the parameters panel. Key defaults: world 2048x2048; chunk 64; water/rock 12%/10%; 40 patches (10–60 units); 60 starting food items; active radius 200; 10 ticks/s; day 600/60/400/60; `N_plan` 10; roles 15/20/15/30/20; food reserve 20; `seal_at_night` on; `T_food` 200 / `p_food` 0.3; `T_res` 3000; predators 3/2/2 on a 60–150 ring; `queen_brain` `PROGRAM` with `baseline.lua` (`BUILTIN` before v0.5 exists, and as the fallback); `N_revision` 1120; LLM min interval 60 s; provider Gemini 3.1 Pro (`MOCK` in tests); `build_time` 10; `demolish_time` 5; `pave_speed` 2; `pave_traffic` 30/day; `autosave_ticks` 1120. `plan_errors_to_fail` 3 applies from v0 — that many misfires in a row drop the nest to `BUILTIN`. The judging data and defaults are v1.5: the six goals with their floors and ambition targets, the per-situation demand vectors and the coverage vectors in `sim_params.tres`; `probation_days` 1, `capacity_grace` 3 days, `warning_days_to_fail` 2, `library_attempts` 2 per crisis, `situation_hysteresis` 1 day, `similarity_eps` 0.1 (normalized policy distance), `blacklist_days` 5 sim-days; floors — population halving in a day, a starved queen, a food store empty for a whole day, capacity below population beyond `capacity_grace`.

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Engine | **Godot 4.x (4.3+)** | 2D cellular world, one project exporting to macOS (v1), headless Linux + web (v4). Version pinned in `project.godot`; hot paths can move to GDExtension later if profiling demands it |
| Language | **GDScript** | Everything but strategies. Fast to write, one language across sim/view/UI; the sim uses typed arrays and avoids per-tick allocation |
| Strategy runtime | **Lua 5.4 via godot-luaAPI** (GDExtension, from v0.5) | The only sandbox that holds: `base`/`table`/`string`/`math` bound (minus `math.random` — strategies draw noise via `s.rand()`), no `os`/`io`/`require`/`load`/engine, instruction-counter hook. Vendored in `res://addons/luaAPI/`, its version **pinned together with the Godot version** (it ships per-engine binaries); behind `StrategyRunner` so it stays swappable |
| Sim data | `PackedByteArray` / `PackedInt32Array` layers + sparse `Dictionary` | Layer arrays for terrain/structures/knowledge, sparse maps for objects/agents, `PackedInt32Array` distance field. Integer-only arithmetic (fixed-point energy) — §Determinism and replay |
| Randomness | `RandomNumberGenerator`, named streams | worldgen · spawner · combat · strategy · interventions, each derived from the master seed (`rng.gd`) |
| Pathfinding | Hand-written weighted BFS + `AStarGrid2D` | Distance field for the global case, engine A* on a bounded rectangle for the local one — §Pathfinding |
| Persistence | `var_to_bytes` + `FileAccess.open_compressed`, JSON header | Plain types only (never `*_with_objects`), background-thread writes, temp-then-rename — §Saves |
| Rendering | `TileMapLayer` tile window · `MultiMeshInstance2D` (myrmeks) · `AnimatedSprite2D` (predators) · `Sprite2D` (objects) · `CanvasModulate` + `PointLight2D` (day/night) | Only a ~128x96 window around the camera is filled; myrmek positions interpolate between ticks so cell-stepping logic looks continuous |
| Art | **SVG**, rasterized at import (128 px/cell, mipmaps), tinted via `modulate` | Small hand-drawable set; sharp from 8 to 48 px per cell; role/state/phase are colour, not extra assets |
| Config data | Godot `Resource` `.tres` files | `roles.tres`, `predators.tres`, `sim_params.tres` — defaults are data, editable live from the parameters panel |
| LLM | **Gemini 3.1 Pro** (Google AI API) via `HTTPRequest`, behind an abstracted provider seam | Alongside: OpenAI-compatible, Anthropic, local Ollama, and `MOCK` (reads a program from a file) — the only provider used in tests. Async; keys in a gitignored `.env` loaded into the environment (§Security), server-side only from v4 |
| Tests | **gdUnit4**, headless | `scripts/test.sh` is the canonical gate: unit, contract, determinism, strategy-safety, balance smoke. No paid API calls, ever |
| Networking (v4) | `WebSocketMultiplayerPeer`, binary `PackedByteArray` messages | Snapshot-plus-deltas protocol, compressed above 1 KB — see ROADMAP v4.1 |
| Deployment (v4) | Headless Linux export as a systemd service or Docker image, behind Caddy or nginx | TLS (`wss://`), COOP/COEP headers for the web export, one shared token, tunnel or VPN for outside access — see ROADMAP v4.3 |

Deliberately **not** in the stack: no physics engine (the world is cellular and stepped by hand), no navigation server, no ECS addon, no external build system, no runtime package manager — the two vendored addons (godot-luaAPI, gdUnit4) are the only third-party code.

## Repository layout

```
res://sim/           pure simulation — no Node, no scene tree, no network
  world.gd           layer arrays, chunks, cell access
  worldgen.gd        deterministic generation from a seed
  clock.gd           ticks, speed, day phases
  rng.gd             named seeded streams
  agent.gd           shared agent record
  myrmek.gd          myrmek state machine by role
  predator.gd        predator state machine by species
  nest.gd            knowledge, frontier, interior/capacity, storages, build plan
  tasks.gd           task types and lifecycle
  queen_ai.gd        tactical planning — the task board
  strategy.gd        StrategyRunner seam + StateView assembly and helpers
  strategy_lua.gd    the Lua 5.4 runner: sandbox, instruction limit, table conversion
  policy_schema.gd   policy fields, types, bounds — the validation source of truth
  queen_policy.gd    BUILTIN / PROGRAM / LLM modes, version validation, dry run, library
  strategy_eval.gd   situation classifier, declared goals vs actuals, the dawn
                     scorecard, candidate fit scoring, the escalation ladder
  nest_report.gd     the LLM report and the failure dossier (state, metrics, fired
                     branches, failed sources with their scorecards)
  pathfinding.gd     distance field + local A*
  combat.gd          adjacency damage, deaths, carcasses, cargo drops
  spawner.gd         food, resource regeneration, predators (active zone only)
  save.gd            serialization, autosave rotation, slots
res://app/           main scene: tick loop + render in one process (v0–v3)
res://view/          world_view (tile window), agents_view (MultiMesh), minimap, daynight
res://ui/            hud, inspector, params_panel, stats, tools, queen panel
res://llm/           providers (gemini, openai_compat, anthropic, ollama, mock),
                     the StateView/policy API description for the model, prompts
res://data/          roles.tres, predators.tres, sim_params.tres
res://art/           SVG sprites
res://strategies/    shipped strategy programs: the PROGRAM default, arena baselines,
                     MOCK inputs (the runtime library lives in user://strategies/)
res://tools/         headless entry points: run_sim.gd, run_arena.gd
res://addons/        vendored: luaAPI (godot-luaAPI), gdUnit4 — versions pinned
res://tests/         gdUnit4: headless simulation tests, golden StateView fixtures, seeds
res://server/        (v4) server main scene: tick loop, clients, command journal, autosave
res://client/        (v4) client main scene: connection, local state copy, camera
res://net/           (v4) protocol: snapshot, deltas, chunk versions, commands

scripts/             test.sh (the canonical gate), run_headless.sh, arena.sh, export.sh
deploy/              (v4) Dockerfile, compose, Caddyfile, systemd unit, deploy/backup scripts
specification/       VISION.md, ARCHITECTURE.md, ROADMAP.md, implementation/, history/
.claude/skills/      the SDLC skills that build this from the specs (CODEGEN.md)
codegen/             the run tracker and its dashboard
.github/workflows/   ci.yml — lint + the headless suite on every push/PR
```

## Testing

Every roadmap phase ships with the tests that encode its DoD; all sim tests run headless. CI (`.github/workflows/ci.yml`) runs `scripts/test.sh` on every push and pull request; the slow batches — the balance smoke and the arena — run nightly.

- **Unit**: worldgen guarantees, energy math, state machines, flood-fill interior/capacity, frontier maintenance, distance-field weights, traffic → `PAVE` queue, night multipliers, task ranking.
- **Contract**: `StateView` shape and helpers, policy schema/bounds, `StrategyRunner` behaviour (the Lua runner against golden `StateView` fixtures), task shape and lifecycle, save round-trip, tick phase order, and the judging shapes — `Situation`, `Goal coverage`, `Scorecard`, `Fingerprint`, the attempt ledger. Changing a contract changes its test.
- **Determinism**: same seed → identical state hash after N ticks; save/load → bit-identical continuation; replay from journal matches the original run.
- **Strategy safety**: sandbox escapes blocked, the instruction limit fires on a looping `plan()`, malformed/out-of-bounds policies rejected, a rejected candidate leaves the running state untouched.
- **Strategy judging (v1.5)**: coverage normalization (a vector of ones becomes six equal sixths); the fit dot product picks `forager` in a famine and `fortress` in a siege straight from the shipped tables; situation classification on fixture states, with hysteresis suppressing a one-day flip and an observer pin overriding the classifier; scorecard verdicts on fixture days, a laxer-than-floor claim clamped; siblings skipped without consuming budget; a rehashed answer rejected by fingerprint; the attempt ledger surviving save/load; identical policies from permuted state tables and across reruns that use `s.rand()`.
- **Balance smoke**: headless seed batches — on `BUILTIN` alone, no program and no model, the nest survives the first night in ≥50% of seeds.
- **LLM**: `MOCK` provider only in tests — no paid calls; the full report → program → validation → apply loop against canned programs, including deliberately broken ones.

## Open questions

Decisions still open, each with the current recommendation. When one is settled, fold the answer into the sections above and log it in the history; new questions are added here as they arise.

1. **The async boundary** — `HTTPRequest` is a `Node`, and the sim is pure data. *Recommendation: pin as a contract that `res://sim/` never touches the network or the scene tree — the LLM client lives in the app/server layer behind the provider seam, and a new program version enters the sim only at a tick boundary.*

---

## History of changes

**v1.15 (27.09.2026)** — the prototype de-complicated on purpose: **v0 runs exactly one shipped strategy (`baseline.lua`) and no selection or evaluation algorithm**. A scope note in The queen's brain marks everything from situations to the arena as v1.5; the v0 table, the `LLM` mode triggers (back to the three plain ones for v0), the shipped-strategies paragraph (the `fortress`/`forager`/`growth` trio moves to v1.5), Error handling, Saves, Configuration and Testing were version-marked to match. The one v0 safety valve kept: `plan_errors_to_fail` misfires in a row drop the nest to `BUILTIN` directly. The brain-diagram caption now says the right-hand judgment loop collapses away in v0.

**v1.14 (27.09.2026)** — a consistency pass over the seams left by v1.8–v1.13, plus two determinism holes closed: `math.random`/`math.randomseed` are removed from the Lua binding (Lua self-seeds unpredictably) in favour of `s.rand()` from the `strategy` stream, and `StateView` lists are pinned as `ipairs` sequences with a permutation contract test — both also added to Security, the Tech stack and Testing. A misfiring `plan()` now escalates: previous policy for the cycle, `plan_errors_to_fail` (3) consecutive misfires = a floor breach. Reconciled the pre-ladder leftovers: Error handling separates a rejected candidate from a failing active program, the LLM-loop paragraph loses the GDScript-era "static check", gains the goals bounds and fingerprint step and no longer claims "the previous version keeps running", the `LLM` mode row's triggers match the sequence diagram, the v0 table's LLM row drops the ">3 deaths" trigger and its strategic row gains the situation classifier, Security's missing-key path now ends in the fallback chain rather than `PROGRAM`, Saves now serializes the attempt ledger, scorecards, situation and active mode it had promised to keep, Configuration gains the fourth floor and `plan_errors_to_fail`, Contracts fixes the GDScript mention and names `policy_schema.gd` as the single policy source, `StateView` lists the situation and `s.rand()`, and Testing gains the CI line, the judging-shape contracts and a **Strategy judging** bullet. Every diagram now carries a short textual explanation directly beneath it, and the brain diagram's validation and misfire nodes were redrawn to match.

**v1.13 (27.09.2026)** — made explicit who authors the current goal vector, since that vector is what selects the strategy: the engine by default (one of five authored demand vectors, pure function of state with hysteresis), the observer by pinning a situation or setting the six numbers directly (a journaled tick-boundary command), and the model never — the demand is the question, a program is the answer, and a model setting both would grade its own homework. Noted that blending adjacent situations is an additive v1.5 refinement.

**v1.12 (27.09.2026)** — goals became a closed list of six (`survival`, `food`, `shelter`, `capacity`, `territory`, `queen`), each with one indicator, an absolute floor and an ambition target, replacing the earlier set of optional declared fields. A strategy now covers **all six to a degree**: a vector of 0..1 values normalized to sum to 1, so ambition is a budget and nothing can promise everything. Each situation demands the same six as a weighted vector, fit is their dot product (worked examples for `FAMINE` and `SIEGE`), each goal's expectation derives from coverage as `floor + coverage × (target − floor)`, and the scorecard's verdict is weighted by the situation's demand — so missing `territory` in a famine is noise while missing `food` is failure. Floors remain unconditional at any coverage. Coverage and demand tables for the four shipped strategies and five situations are given in full and live in `sim_params.tres`; the brain diagram now shows the dot product.

**v1.11 (27.09.2026)** — answered who sets the *current* goals, which declared goals alone could not: the engine classifies the nest's **situation** (`FOUNDING`, `SIEGE`, `FAMINE`, `CROWDED`, `STABLE`) as a pure, hysteresis-damped function of state, and that situation's **demand** is what a candidate's declared goals are matched against — so the ladder promotes the best *fit* rather than the next name in a list, with arena rank breaking ties. The situation rides in `StateView` (a program may branch on it) and in the LLM dossier (the model writes for the real situation); the observer may pin an objective from the queen panel as a journaled tick-boundary command. Added the `Situation` contract, `situation_hysteresis`, the classifier in `strategy_eval.gd`, the situation in the queen panel, and updated the two-level brain and ladder diagrams to show demand feeding candidate choice.

**v1.10 (27.09.2026)** — the escalation ladder stopped being a carousel: a per-crisis budget of `library_attempts` (2) candidates, a policy **fingerprint** so near-identical programs count as one idea and siblings of a failure are skipped without consuming budget, blacklisting with earned rehabilitation measured in **simulation days** (never wall-clock, to keep replay exact), and an **attempt ledger** contract that survives save/load. The LLM is now sent a **dossier of the failures** — every failed source with its scorecards, the floors breached, the blacklist and its reasons, and `BUILTIN`'s numbers over the same days — with the no-rehash rule enforced by fingerprint at validation rather than merely requested. The ladder diagram was added and the two existing strategy diagrams brought up to date with it — the two-level brain now shows the scorecard closing the loop and routing a failing verdict into the ladder, and the LLM sequence now carries the dossier, the fingerprint rehash check and promotion on probation. The `Fingerprint` and `Attempt ledger` contracts and the configuration defaults were updated together.

**v1.9 (27.09.2026)** — strategies became judgeable: every program declares a `goals` table beside `plan` (bounds-checked, clamped up to engine floors that cannot be declared away), `strategy_eval.gd` produces a journaled dawn `Scorecard` with a healthy/warning/failing verdict plus immediate floor checks and a probation window, and a `failing` verdict runs an escalation ladder — demote to `BUILTIN` at once, blacklist the version, promote the next ranked untried library strategy, ask the LLM only when nothing ready remains, stay on `BUILTIN` if that fails too (The queen's brain, with a state diagram). The same scorecard is what the queen panel, the LLM revision prompt and the arena ranking all read. Added the `Goals` and `Scorecard` contracts, scorecard defaults and floors (Configuration), `strategy_eval.gd` (Components, Repository layout) and the richer queen panel (Observability).

**v1.8 (27.09.2026)** — made the queen's own direct control an explicit mode: `BUILTIN` (no program at all — default policy plus the hardcoded plans, the queen assigning every myrmek herself) joins the `queen_brain` table as both the zero point every program is measured against and the silent fallback when there is no key, no loadable file, or no valid version; stated that the tactical level is complete on its own and that a program only tunes its policy (The queen's brain). Also specified the shipped starter strategies in `res://strategies/` — `baseline`, `fortress`, `forager`, `growth` — as the `PROGRAM` content, the arena's opponents and the `MOCK` provider's input.

**v1.7 (27.09.2026)** — two more open questions decided: the save format carries plain types only and is read with `bytes_to_var`, never `bytes_to_var_with_objects`, pinned by a contract test (Saves); LLM keys live in a gitignored `.env` at the project root with a committed `.env.example`, parsed into the environment by a loader in the app/server layer, real environment variables winning, a missing key degrading to `PROGRAM` mode (Security, Tech stack). One open question remains — the async boundary.

**v1.6 (27.09.2026)** — open question decided: the arena runs its *strategies × seeds* matrix sequentially in one headless process (`res://tools/run_arena.gd`), each cell freshly seeded and independent, writing one reproducible results table per run under `user://arena/<run_id>/`; parallel workers are a later optimization that must reproduce the sequential table (The queen's brain). Three open questions remain.

**v1.5 (27.09.2026)** — added the **What v0 implements** section after Overview: a per-section table of what the prototype reduces (world size and no chunks, three roles and 40 myrmeks, the spider only, fixed-ring build plans, the tiny StateView, the single autosave file, flat tiles and two zooms, two interventions, no server) against what it defers and to which phase, plus the list of invariants the prototype does **not** reduce (pure-data sim, determinism, physical rules, contracts pinned by tests, the Lua sandbox, headless-first).

**v1.4 (27.09.2026)** — split the former "Stack and repository layout" into a dedicated **Tech stack** section (a per-layer table: engine, language, strategy runtime, sim data structures, RNG, pathfinding, persistence, rendering, art, config data, LLM, tests, networking and deployment, plus an explicit list of what is deliberately not used) and a **Repository layout** section holding the tree. The tree is now file-by-file and gained the directories the specs had implied but never listed: `res://addons/` (the two vendored addons), `res://strategies/` (shipped programs, incl. `MOCK` inputs), `res://tools/` (headless entry points), `res://sim/policy_schema.gd`, plus the non-`res://` roots `scripts/`, `deploy/`, `.github/workflows/` and the existing `specification/`, `.claude/skills/`, `codegen/`.

**v1.3 (27.09.2026)** — added nine diagrams (Mermaid, plus an ASCII cell grid): the v0–v3 layer map and the v4 server/client topology (Overview), the seven tick phases (Time and the tick), the myrmek and predator state machines (Agents), the nest layout with its computed capacity and the food/resource economy (Nest), the two-level queen brain and the LLM revision sequence (The queen's brain). Also corrected a leftover in Overview that still described strategies moving from GDScript to Lua.

**v1.2 (27.09.2026)** — four open questions decided and folded in: strategies are sandboxed Lua 5.4 from the first prototype, no GDScript runner (Components, The queen's brain, Security, Error handling, Stack, Testing); the test framework is gdUnit4 (Stack, layout); sim arithmetic is integer-only — fixed-point energy in thousandths, transcendental functions banned in the sim, cross-platform bit-identity stated (Agents, Determinism and replay); the RNG becomes named streams derived from the master seed (Components, Determinism and replay, Saves). Open questions renumbered — four remain.

**v1.1 (27.09.2026)** — added the Open questions section: eight open decisions with recommendations (prototype strategy language, test framework, cross-platform float determinism, RNG streams, the async boundary, object-free serialization, the arena execution model, local key configuration).

**v1.0 (27.09.2026)** — initial version, derived from the retired concept v0.20 ([history/](history/)).
