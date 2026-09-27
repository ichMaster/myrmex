# Myrmex — Concept Specification of a Myrmek Nest Simulation

Version 0.20 (concept). 27 September 2026.
Project name: **Myrmex** (from Greek *μύρμηξ*, "ant").
Creature: **myrmek** (plural: **myrmeks**), an ant-like creature that lives in a nest with central coordination.
Nest (in code: `Nest`) means both the community of myrmeks with their queen and their base: a patch of ground enclosed by walls, with storages inside. The myrmeks make and guard the gaps in the wall themselves.

---

## 1. Goal and scope

A simulation of an autonomous myrmek nest in a large cellular 2D world built in Godot. The observer watches the nest and can intervene (drop food, place predators, change parameters), but the nest lives by its own logic: the queen coordinates, myrmeks of different roles carry out tasks, predators hunt, and day turns into night.

The first version is a single nest with a fixed population of about 100 myrmeks, without births or evolution. The architecture is designed from the start to support births, evolution and several warring nests in later versions.

**In v1:** world generator, the nest's shared knowledge map (fog of war), six roles, the queen as coordinator, energy and hunger for all agents, food and building resources, nest construction, several predator types, a day and night cycle, intervention tools, a StarCraft-style minimap, save and load, and the queen's strategy as a program (GDScript in the prototype, Lua in v1) written by a human or an LLM (Gemini 3.1 Pro). In v1 this is a single native Godot application (macOS) with simulation and rendering in one process; a server-side simulation with a web client is planned for v1.3 (section 12).

**Not in v1:** myrmek births, evolution, multiple nests, sound.

---

## 2. Key decisions

| Question | Decision | Why |
|---|---|---|
| Engine | Godot 4.x (4.3+), GDScript | Fast start; critical parts can move to GDExtension later |
| Time | Discrete ticks, base 10 ticks/s, speed multipliers 0.5x–16x, pause, single step | Determinism, simple debugging, reproducible runs |
| World | Size set at generation: from 256x256 to 2048x2048, a multiple of the 64-cell chunk (default 2048x2048, 4.2 million cells); the cell is the atomic unit of logic | Small worlds for tests and quick runs, the large one for future nests |
| View | The graphics window shows a fragment (~64x36 cells); the rest is on the minimap | No rendering of 4 million cells; familiar strategy-game UX |
| Coordination | Shared knowledge map + the queen assigns tasks; no pheromones | Matches the concept; simpler to explain and debug |
| Nest memory | A visited cell is known forever; on known cells the nest sees objects and agents in real time | Simple for v1; a "last known state" mode is a parameter for the future |
| Energy | All myrmeks and predators have it; death from starvation | Creates economic pressure and gives carriers a purpose |
| Cell occupancy | At most one agent per cell everywhere, including inside the nest | Nest capacity is the number of ground cells inside the walls, so the nest must be built large enough |
| Walls and gaps | Walls are impassable to everyone without exception. There is no special "entrance" type: a gap is simply a ground cell in the wall ring that builders left or opened, and anyone can pass through it, predators included | Defence rests not on conventions but on guards standing in the gap and on builders who can close it |
| Start | The queen and the full myrmek population on open ground, with no structures and no stock | The first night is the first challenge: before dark the nest must gather resources, raise walls and collect food |
| Architecture | The simulation is pure data in arrays with no dependency on Node; rendering only reads the state | Tests without rendering, swappable graphics, scaling to thousands of agents |
| Queen's brain | Two levels: tactical (an algorithmic task board that directs every myrmek) and strategic (a strategy program with a `plan()` function that the queen runs herself; written by a human or an LLM). Language: GDScript in the prototype, sandboxed Lua from v1. The LLM never controls myrmeks directly | The model is called rarely, only to write or revise the program; the rest of the time the strategy runs in microseconds |
| Deployment | v1 is a single native macOS application with simulation and rendering in one process, but the simulation is already separated from rendering as pure data. From v1.3: a headless Godot server on Linux and a web client from the same project (plan in section 12) | Reach a living nest quickly; splitting into server and client later does not require rewriting the simulation |
| Determinism | One seed for the world and the simulation; agents are processed in id order; LLM responses are logged, so a run can be replayed even with the LLM | Reproducibility, replays, comparing balance and strategies |

---

## 3. World

### 3.1 Cell

Each cell has several layers:

| Layer | Data type | Values |
|---|---|---|
| Terrain | `PackedByteArray` | `GROUND` (passable), `WATER`, `WALL` (impassable to all) |
| Structure | `PackedByteArray` | `NONE`, `NEST_WALL`, `PAVEMENT` (paving: speeds up movement), `STORAGE_FOOD`, `STORAGE_RES`, `QUEEN_CHAMBER` |
| Object | sparse `Dictionary[cell -> Object]` | `FOOD(units)`, `RESOURCE(patch_id)`, `PILE(type, units)`; at most one object per cell |
| Agents | sparse `Dictionary[cell -> agent_ids]` | myrmeks and predators |
| Knowledge | `PackedByteArray` per nest | 0 = unknown, 1 = known |

### 3.2 Chunks

The world is divided into 64x64-cell chunks (for 2048x2048, a 32x32 grid of chunks). A chunk stores: an active flag, lists of agents and objects in it, and a "changed" flag for the minimap.

**Active zone**: chunks within radius R of the nest plus chunks that contain known cells or agents. Spawning of food and predators and resource regeneration happen only in the active zone. The rest of the world sleeps until discovered. This saves CPU and makes the large map meaningful for a nest of 100 myrmeks: the world "wakes up" along with the expansion.

### 3.3 Generation

- Input: seed, size, water share, rock share, number of resource patches.
- Terrain: `FastNoiseLite`, two noise layers (water: lakes and channels; rock: clusters), smoothed by a cellular automaton (2–3 iterations).
- Starting point: the centre of the largest connected ground region; a radius of 12 is cleared around the queen.
- Resource patches: N patches of 3–12 cells, each with a shared reserve (for example, 10–60 units). A patch's reserve is the number of nest cells that can be built from it.
- Starting food: M items of 1–5 units each, denser near the start.
- There is no starting nest: the queen and all myrmeks stand on the cleared area, and walls and storages must be built before the first night. The cell where the queen stands becomes `QUEEN_CHAMBER` at no resource cost.
- Start guarantees: within 30 cells of the queen, at least two resource patches and about 20 units of food are generated, so that the first day is hard but possible.

### 3.4 Environment dynamics

| Event | Rule (parameters) |
|---|---|
| Food spawning | Every `T_food` ticks, in each active chunk, with probability `p_food`, a cluster of 1–3 cells with 1–5 units each appears |
| Resource regeneration | A depleted patch gets a new reserve after `T_res` ticks, or a new patch appears in the active zone |
| Predator spawning | A target count of each type is maintained in the active zone; new ones appear on a ring 60–150 cells from the nest, outside the nest's vision |
| Predator carcass | Becomes a `FOOD` item (amount depends on the type), a reward for defence; carriers take it to storage like ordinary food |
| Food spoilage | None in v1 (parameter `food_decay` for the future) |

---

## 4. Time, day and night

A tick is one simulation step. An agent's speed is set as `move_cooldown` (how many ticks pass between steps): 1 is fast, 3 is slow.

Day cycle (parameters in ticks): day 600, dusk 60, night 400, dawn 60. Total 1120 ticks, about two minutes at 10 ticks/s.

**Effects of night:**

- Predators: `move_cooldown` is halved, the time to eat a myrmek is halved, vision radius grows by 50%.
- Myrmeks: vision radius decreases by 1 (parameter). This applies to detection; the reveal radius (section 5.2) is capped by current vision, so at night scouts reveal cells within radius 4, while the radius-2 reveal of the other roles is unaffected.
- Queen: night policy (parameter): scouts and carriers return to the nest as far as the interior allows (priority to hungry myrmeks and those carrying cargo), the rest gather near the gap under guard; guards stand in and near the gaps; at dusk builders close the gaps with walls and at dawn tear them down (`seal_at_night`, on by default); myrmeks left outside spend the night by the wall under guard; if the food store is below the reserve, work continues despite the risk.
- Graphics: smooth tone change via `CanvasModulate`, warm light near the nest gap.

**Phase order in every tick:**

1. Environment: clock, food and predator spawning, resource regeneration.
2. Nest planning (queen), every `N_plan` ticks (default 10).
3. Myrmeks: each performs one step of its state machine.
4. Predators: the same.
5. Combat and deaths.
6. Nest knowledge update (revealing cells around myrmeks).
7. Graphics sync (only if this frame is rendered).

---

## 5. Agents

### 5.1 Common model

Agent fields: `id`, `kind` (myrmek or predator), `type` (role or species), `nest_id`, `cell`, `hp`, `hp_max`, `energy`, `energy_max`, `move_cooldown`, `move_timer`, `vision`, `attack`, `carry` (type, units, capacity), `state`, `task_id`, `target_cell`, `path`. There is no age in v1: a myrmek lives until it is eaten or starves.

Movement is 8-directional: an agent steps to any of the 8 neighbouring cells, and a diagonal step costs the same ticks and energy as an orthogonal one. All radii and adjacency (vision, reveal, combat) use Chebyshev distance; this is why wall rings are squares (section 6.2).

### 5.2 Myrmek roles

| Role | At start | Parameters | What it does |
|---|---|---|---|
| Scout | 15 | vision 5, cooldown 1, hp 3 | Goes to the nearest edge of the known world (the "frontier") and reveals cells within radius 5. The queen spreads scouts across different sectors so they don't crowd together |
| Guard | 20 | vision 4, cooldown 2, hp 20, attack 5 | Patrols a ring around the nest, intercepts predators visible on the known map, holds the gaps in the wall, escorts groups of carriers and harvesters on long trips, guards locations: a resource patch, a rich food source, a stretch of road |
| Builder | 15 | cooldown 2, hp 5, carries 1 resource, builds a wall in 10 ticks, demolishes in 5 | Takes a resource from storage or from a carrier and builds a wall, storage or paving according to the plan. Can demolish any wall: open a gap, dismantle an old ring, close a gap for the night and open it again in the morning; the resource from a demolished wall is returned |
| Carrier | 30 | cooldown 1, hp 4, carries 2 units | Brings food from the map to storage, moves resources from piles to storage, delivers food to hungry myrmeks and resources to builders |
| Harvester | 20 | cooldown 2, hp 5, carries 3 units, mines 1 unit per 5 ticks | Works on an assigned patch; carries what it mines to storage itself, or leaves it as a pile near the patch if the queen has assigned carriers |
| Queen | 1 | stationary, hp 50, spends energy faster | Coordinator (section 6.2). In v1.1 she gives birth to myrmeks |

In total, 100 worker myrmeks plus the queen. The count of each role is a starting-configuration parameter.

All myrmeks reveal cells around themselves within radius 2; scouts within radius 5.

### 5.3 Myrmek state machine

A common framework for all roles: `IDLE` (waiting for a task in the nest or on the spot) → `GO_TO` (following a path to the target) → `WORK` (on-site action: gathering, mining, building, patrolling) → `RETURN` (returning with cargo) → `DEPOSIT` (dropping it in storage or handing it to a neighbouring myrmek) → `IDLE`.

Interrupts: `HUNGRY` (energy below the threshold: asks for food or goes to eat), `FLEE` (a working myrmek sees a predator nearby and moves away from it), `FIGHT` (guards only), `DEAD`.

Cargo can be handed between any two adjacent myrmeks of the same nest.

### 5.4 Energy and hunger

| Parameter | Default value |
|---|---|
| Maximum energy | 100 |
| Idle cost | 0.01 per tick |
| Step cost | 0.05 per step (+50% with cargo; 0.03 on paving) |
| Attack cost | 0.5 per attack |
| "Hungry" threshold | 40: asks for food but continues its task |
| "Critical" threshold | 15: drops its task, goes to the nest or waits for a carrier |
| One unit of food | +50 energy |
| Queen | 0.1 per tick; eats from storage automatically; "not hungry" at energy 70 and above |
| Death | energy 0 |

A myrmek in the nest with a non-empty storage eats by itself. For a hungry myrmek far from home, the queen assigns a carrier with food.

**Balance estimate.** 100 myrmeks at an average cost of 0.05 per tick is 5 energy per tick, i.e. 0.1 units of food per tick, or about 110 units per day (1120 ticks). Food spawning in the active zone should yield at least 120–150 units per day. The throughput of 30 carriers on a 100-cell trip (200 ticks round trip, 2 units each) is 0.3 units per tick, with margin. These numbers are a starting point for tuning.

### 5.5 Predators

| Species | Behaviour | Cooldown day / night | Vision day / night | hp | Attack | Eating time day / night | Carcass → food |
|---|---|---|---|---|---|---|---|
| Spider | Ambush: sits near routes, lunges at a myrmek in its field of view | 2 / 1 | 6 / 9 | 15 | 4 | 20 / 10 | 5 |
| Beetle | Slow tank: wanders, attacks everything nearby, does not flee | 3 / 2 | 4 / 6 | 40 | 6 | 30 / 15 | 8 |
| Lizard | Fast hunter: chases spotted myrmeks, at night takes an extra step every second tick, flees when hp is below 30% | 1 / 1+ | 8 / 12 | 25 | 5 | 15 / 6 | 6 |

The lizard's "1+" night cooldown is not a shorter cooldown but the extra step every second tick described in the behaviour column.

Common rules:

- Predators have energy; a hungry one hunts, a sated one wanders or rests; without prey it dies.
- State machine: `WANDER` → (sees a myrmek) `HUNT` → (adjacent cell) `ATTACK` → (myrmek dead) `EAT` (busy for `eat_time` ticks, does not move, vulnerable) → `REST` or `WANDER`; `FLEE` for species that flee.
- Walls are as impassable to predators as to everyone else. A predator enters the nest only through an open gap, and in the gap it becomes an easy target for guards on both sides.
- A working myrmek dies from a single blow (predator attack exceeds its hp). A guard survives several blows.
- The target count of each species in the active zone is a parameter; the observer can add predators manually.

### 5.6 Combat

Every tick, an agent with an attack value that has an enemy in one of the 8 neighbouring cells deals damage to it. Several guards around one predator add up their damage. A predator in a gap is attacked by guards both from inside and outside. A dead predator becomes food. A myrmek killed by a predator disappears (the predator ate it); a myrmek that starves disappears too. In both cases any carried units drop on the myrmek's cell as a `FOOD` or `PILE` object; if the cell already holds an object, the units are lost.

---

## 6. Nest

### 6.1 Knowledge and fog of war

A `known` array per nest. A cell becomes known when any myrmek of the nest sees it. On known cells the nest sees the current state: objects, structures, predators. Unknown cells do not exist for the nest: no paths are built there and no tasks are assigned there.

**Frontier**: the set of known passable cells adjacent to unknown ones. Maintained incrementally. Scouts take the nearest frontier cell in their sector (sectors are angular ranges around the nest, one per scout).

### 6.2 The queen as coordinator

Every `N_plan` ticks the queen:

1. **Gathers state:** known unclaimed food, piles, patches with reserves, predators on the known map, hungry myrmeks, the build queue, storage levels, frontier size.
2. **Builds a task board:** tasks have a type, target, priority and assignee. Types: `EXPLORE`, `FETCH_FOOD`, `FETCH_PILE`, `HARVEST`, `BUILD`, `FEED_MYRMEK`, `DELIVER_RES`, `PATROL`, `INTERCEPT`, `HOLD_GAP`, `OPEN_GAP`, `CLOSE_GAP`, `PAVE`, `ESCORT` (group escort), `GUARD_SITE` (guarding a location).
3. **Ranks:** safety (predator near the nest) → feeding the hungry → food income → construction → resources → exploration. Weights are policy parameters.
4. **Assigns:** free myrmeks of the required role take the nearest task (greedily, by distance field). Known but unreachable cells — those with no finite distance in the field, for example across water — are never assigned as targets. A task is cancelled if its target disappears, and the myrmek gets a new one.
5. **Night policy** (section 4).
6. **Defence strategy:** guards are distributed between patrol, gaps, escort and site guarding according to policy weights. This is the space for strategies: "fortress" (everyone at the gaps, only short trips), "convoy" (every carrier group escorted), "outposts" (guards stand at patches and near food, with roads between them), or adaptive, where the weights depend on where myrmeks have recently died. In v1 the strategy is a set of parameters; later the queen can switch them herself.

**The first day.** While there is no nest, the queen follows a starting plan: harvesters go to the nearest patch, carriers bring resources to the queen and gather food nearby, builders raise the first ring of walls around the queen with one gap and a food storage inside, guards stand in a ring around the queen until the walls close, scouts explore the surroundings. Estimate: a ring of radius 5 is about 40 walls, i.e. 40 resources, with interior space for roughly 70 myrmeks; 20 harvesters mine that much in less than half a day, so the walls go up before nightfall if the patch is close. Those who don't fit spend the night by the gap under guard.

In v1.1 the birth decision is added here (section 12).

### 6.3 The queen's brain: strategy as a program

The planning in 6.2 is the tactical level: each time it turns the state into a task board according to the current policy. The strategic level above it produces not individual commands but a **strategy program**: code with a `plan()` function that the queen runs herself on every planning cycle and that defines the policy for the next ticks. The program is the strategy. It does not hand out tasks, does not move myrmeks and sees nothing beyond the nest's known map; everything that happens between cycles is done by the tactical level on its own.

**Program language.** The strategy is real code, not a set of weights: a module with a `plan(s) -> policy` function that the queen calls on every planning cycle, and a `memory` table that persists between calls. In the prototype strategies are written in GDScript and loaded on the fly (`GDScript.new()`, `source_code`, `reload()`): zero dependencies and a single language in the project. In v1 the runtime becomes Lua 5.4 via the godot-luaAPI extension, because it provides a real sandbox (the strategy cannot see `os`, `io`, `require`, `load` or anything from the engine) and an instruction counter that interrupts `plan()` on an infinite loop; GDScript cannot be isolated from the engine. Both variants sit behind a `StrategyRunner` interface, so changing the language does not touch the rest of the code. Example in Lua (the GDScript variant differs only in syntax):

```
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

**What the strategy sees.** Access is not automatic but goes through an explicit "state window", `StateView`, shared by both languages and by the API description given to the LLM. Simple values are assembled into a dictionary before the call and become a copied table in Lua: day phase, population by role, deaths by cause, storages and the queen's energy, known food, patches and predators with distances, the frontier, nest capacity versus population, gap status. Large structures (the map, the agent list) are not copied: instead the strategy has helper functions that run on the engine side, such as `predators_within(r)`, `nearest_food_dist()`, `patch_reserve(id)`, `cell(x, y)`. The `World` object is never passed to the strategy, only a `StateView` with read methods. What comes back is a policy table: ranking weights, guard distribution, night policy, build plan, paving threshold, capacity margin, and from v1.1 the desired role composition; it is converted to a `Dictionary` and checked against the schema and value bounds. A call to `plan()` costs microseconds.

**Execution safety.** In the prototype, where there is no sandbox, a new strategy version is protected by two cheap measures: static checking of the text against a whitelist of identifiers (local variables, arithmetic, conditions, loops over ranges, access to `s`, `p` and `memory`) and a dry run in a separate thread with a timeout. In v1 this is replaced by the Lua sandbox with an instruction limit; on the server (v1.3), where third-party strategies may appear, Lua is mandatory.

**Who writes the program**: the `queen_brain` parameter:

| Mode | Who writes the program | When it changes |
|---|---|---|
| `PROGRAM` | A human, or a previously written program saved in the library | Never by itself; the baseline for comparisons |
| `LLM` | A language model: writes the program at the start from a description of the language and state, then revises it based on results | On events (first night, predator in the nest, mass deaths, empty storage), on the `request_revision` action in the program itself, and no more often than once every `N_revision` ticks |
| `LEARNED` (v2) | A small neural network tunes parameters or picks a program from the library; when it lacks experience, it asks the LLM | On every planning cycle; the LLM only at low confidence |

**How LLM mode works.** At the start the model receives a description of the language (GDScript in the prototype, Lua in v1), the `StateView` API and policy fields, the nest's goal and the starting situation, and returns a program. After that it intervenes rarely: on revision it receives the current program, a state report, metrics since the last revision (deaths by cause, food collected, nights without losses) and a log of which code branches fired, and it returns a new version of the program with a short description of the changes for the log. Every version is validated: compilation, static analysis or sandbox, policy value bounds, and a dry run on recorded states from the previous day, so that a bug cannot bring the simulation down; a version that fails is discarded and the previous one keeps running. The model never controls an individual myrmek.

The call is asynchronous (`HTTPRequest`) and the simulation does not wait: while a new version is in flight, the current program keeps running. To avoid flooding requests at 16x speed, there is a minimum interval in real-time seconds. The main model is Gemini 3.1 Pro via the Google AI API; the provider is abstracted, so alongside it there are an OpenAI-compatible API, Anthropic, local Ollama, and `MOCK` for tests, which returns a program from a file. Keys are stored in a local configuration outside the project; from v1.3, only on the server. Every program version is written to the log together with its tick, so saving and replay reproduce a run with the LLM without repeating the calls.

**Strategy library.** Programs are stored as files (`user://strategies/`) with a name, version and revision history; they can be read, edited by hand, plugged in as `PROGRAM` and run on the same seed in headless mode to produce a results table, a "strategy arena". This is both a way to check whether the model's program is really better than a human-written one and a playground for experiments with prompts and models. In v2 the program becomes the queen's genome: a daughter queen inherits it, and revision by the model based on metrics plays the role of mutation (section 12). In v2 each nest will have its own queen with its own model or persona, and diplomacy between them becomes possible.

### 6.4 The nest as a structure

Layout: `QUEEN_CHAMBER` in the centre, next to it `STORAGE_FOOD` and `STORAGE_RES`, around them ordinary ground enclosed by a closed ring of `NEST_WALL` with one or more gaps. A gap is a ground cell without a wall, not a separate structure type.

"Inside" is computed, not built: a flood fill from the queen chamber that does not cross walls and stops at gap cells. All passable cells of this region are the nest's interior, and their count is its capacity.

Rules:

- Walls are impassable to everyone. A gap lets anyone through, one agent per cell, so a single guard in a gap physically blocks it.
- A builder can place a wall on any ground cell (for example, to close a gap) and demolish any wall in `demolish_time` ticks (open a gap, dismantle an old ring, break through a wall from inside if the nest is surrounded). The resource from a demolished wall returns to storage. This way the nest itself decides how many gaps to have and when to close them.
- Default night policy: at dusk all gaps are closed with walls and at dawn they are opened (`seal_at_night`). While the nest is sealed, a predator cannot get inside at all, so night defence comes down to guarding those who didn't fit.
- Storage capacity: 20 units per storage cell of each type.
- Cost: a wall is 1 resource, a storage cell is 2 resources; interior space costs nothing.
- Expansion plan: the target capacity equals the population plus a margin (parameter, default 10%), because only one myrmek fits in a cell. When capacity runs short or storages are full, the queen plans a new, wider ring of walls; once it closes, the old ring is dismantled and the resource returns to storage. Order: first the walls of the new ring with gaps, then the storages. Building the nest to a size that fits everyone is the builders' first major goal.
- A builder takes 1 resource from storage (or from a nearby carrier), goes to the planned cell and builds it in `build_time` ticks.

**Paving and roads.** `PAVEMENT` is a structure on a ground cell over which myrmeks move faster: `move_cooldown` is divided by `pave_speed` (default 2, minimum 1 tick), and the energy cost per step is lower. Paving is laid both inside the nest, to reach storages and the queen faster, and outside as roads to resource patches and food-rich areas. Rules:

- Cost: 1 resource per cell, built in `build_time`, demolished like a wall with the resource returned. A wall placed on paving replaces it.
- The queen plans roads by traffic: the nest keeps a pass counter for each known cell (decaying over time); cells with traffic above the `pave_traffic` threshold go into the `PAVE` queue after walls and storages. This way roads grow by themselves along real routes and are not built to depleted patches.
- Predators get no benefit from paving: roads speed up only myrmeks.
- Paving does not count as "inside" by itself: the interior is still defined by the walls.

### 6.5 Food and resource flows

```
Resource patch --(harvester mines)--> cargo or pile near the patch
   --(harvester or carrier)--> resource storage --(builder)--> wall or storage cell

Food on the map --(carrier)--> food storage --> queen, hungry myrmeks in the nest
                                            --(carrier)--> hungry myrmeks in the field
Predator carcass --> food on the map
```

---

## 7. Observer and UI

| Element | Content |
|---|---|
| Camera | Panning (WASD, screen edge, dragging), zoom 8 / 16 / 32 / 48 px per cell, clicking the minimap moves the camera |
| Minimap | 256x256 px, one pixel is a block of (world size / 256) cells: 8x8 for 2048, 2x2 for 512. Colour priority within a block: unknown (black) > predator (red) > myrmek (white) > food (yellow) > resource (brown) > nest (orange) > paving (beige) > water (blue) > rock (grey) > ground (green). Updated only for changed chunks once every `N_map` ticks. A frame shows the current viewport. A "true map" toggle without fog |
| Time control | Pause, speed multipliers, single step forward, day and tick counter, day-phase indicator |
| Saving | Automatic: the nest saves itself at every dawn, on exit and before applying a new strategy version, and on launch the game continues from the latest autosave without asking. The interface only has a "saved: day N, time" label, a "new world" button and a list of saved days to go back to; manual saving to a named slot is an option (F5), not an obligation |
| Intervention tools | Place food (amount), create a resource patch, summon a predator (species), delete an object or agent, heal, reveal an area of the map |
| Inspector | Click a myrmek or predator: role or species, state, energy, hp, task, path (drawn on the map). Click a cell: contents of all layers |
| Parameters | A panel with live sliders: food frequency, night multipliers, energy costs, queen policy weights, target predator counts; a `queen_brain` toggle and LLM provider selection |
| Queen | The current strategy program with highlighting of the code branches that fired on the last cycle; the current policy; in LLM mode, the version history with change descriptions and response times; "revise now" and "save to library" buttons |
| Connection (v1.3) | Server address and token, connection status, latency, number of connected observers; on disconnect the client reconnects and receives a new snapshot |
| Statistics | Population by role, deaths by cause (starvation, predator), storages, percentage of the map known, number of predators; charts for the last N days |
| Event log | Deaths, patch depletion, predator killed, predator in the nest, gap opened or closed, new nest ring; in v1.1, births |

---

## 8. Graphics

The logic is cellular, the picture is free. The style is vector: simple shapes, soft gradients and shadows, no pixels. It is drawn with sprites in Godot: each object is an SVG file in `res://art/`, which Godot rasterizes on import at high resolution (128 px per cell, with mipmaps), so the image stays sharp at all zoom levels from 8 to 48 px. Sprites are white or grey where the colour varies, and role, day phase or state are applied via `modulate`.

- Terrain and nest: `TileMapLayer` with terrain sets for autotiling (water shores, rock edges, nest walls, paving edges). Only a window around the camera is rendered (a buffer of about 128x96 tiles), refilled as the camera moves.
- Food, resources, piles: `Sprite2D` with SVG sprites within the window.
- Myrmeks: `MultiMeshInstance2D` with a single myrmek SVG sprite as the texture, one instance per myrmek, with the role colour via the instance colour and rotation in the direction of movement; a separate small cargo sprite above the head. Positions are smoothly interpolated between ticks, so movement looks continuous even though the logic jumps from cell to cell.
- Predators: separate `AnimatedSprite2D` with a few SVG frames (there are few predators), visually larger than a cell.
- Day and night: `CanvasModulate` with a gradient by phase, `PointLight2D` near the nest gap.
- Art assets: the SVG set is small (ground, water, rock, wall, paving, storages, queen chamber, food, resource, pile, myrmek, cargo, three predators, a few UI markers), so it can be drawn by hand or generated by code and saved as SVG.

---

## 9. Godot project architecture

```
res://sim/        pure simulation, no Node
  world.gd        layer arrays, chunks, cell access
  worldgen.gd     generation from seed
  clock.gd        ticks, day phases
  agent.gd        base agent model
  myrmek.gd       myrmek state machine by role
  predator.gd     predator state machine by species
  nest.gd         knowledge, frontier, storages, nest structures, build plan
  queen_ai.gd     tactical planning and task board
  strategy.gd     StrategyRunner: interface and GDScript runner (prototype); StateView and helpers
  strategy_lua.gd Lua runner via godot-luaAPI (v1): sandbox, instruction limit, table conversion
  queen_policy.gd PROGRAM / LLM modes, validation and dry run of new versions, library
  nest_report.gd  assembling StateView for the strategy and the report for the LLM (variables, helpers, JSON)
  tasks.gd        task types and lifecycle
  pathfinding.gd  distance field, local A*
  combat.gd       combat, deaths
  spawner.gd      food, resources, predators in the active zone
  rng.gd          single seeded generator
  save.gd         state serialization, slots, autosave
res://app/        v1 main scene: tick loop and rendering in one process
res://server/     (v1.3) server main scene: tick loop, accepting clients, command log, autosave
res://client/     (v1.3) client main scene: connection, local state copy, camera
res://net/        (v1.3) protocol: message formats, snapshot, deltas, chunk versions, commands
res://view/       rendering: world_view (tile window), agents_view (MultiMesh), minimap, daynight
res://ui/         hud, inspector, params_panel, stats, tools, connect
res://llm/        providers (gemini, openai_compat, anthropic, ollama, mock), StateView and policy API description for the model, prompts
res://data/       Resource files: roles.tres, predators.tres, sim_params.tres
res://tests/      gdUnit4 or GUT: simulation tests without rendering (headless)
```

**Pathfinding** without a global A* over 4 million points:

- A distance field to the nest (`PackedInt32Array`): weighted BFS (Dijkstra with integer weights) only over known passable cells; a step on paving costs 1, on ground `pave_speed`. Recomputed incrementally when cells are revealed and structures change, or fully once every 100 ticks. Returning home is gradient descent without search.
- A local `AStarGrid2D` on the rectangle between the myrmek and its target with a 16-cell margin, only over known cells, with `weight_scale` for paving; built on request and released.
- Scouts: a target on the frontier plus local A*; fallback is a random walk.
- The path is cached in the agent; replanning happens when the next cell is occupied for several ticks in a row.

**Memory (for 2048x2048):** terrain 4 MB, structures 4 MB, knowledge 4 MB per nest, distance field 16 MB per nest; objects and agents are sparse. About 30 MB per nest in total.

**Performance:** 100 myrmeks at 10 ticks/s is trivial even at 16x. 5000 myrmeks is 50 thousand agent steps per second, acceptable for GDScript if a step is cheap and BFS and A* are amortized. Beyond that: simulating only active chunks, and GDExtension.

**Save and load.** Since the simulation is pure data, saving comes down to serialization: format version, seed and parameters, clock (tick, day phase, day number), layer arrays (terrain, structures, knowledge), sparse dictionaries of objects and agents, nest state (storages, task board, build plan and queue, frontier), RNG state. Writing uses `var_to_bytes` into a compressed file via `FileAccess.open_compressed` (roughly a few megabytes per slot), alongside a short JSON header (version, seed, day, population, date) for the slot list. After loading, the rendering, minimap and distance field are fully rebuilt. The format has a version field; compatibility with older saves is not guaranteed in v1. In v1 saves are stored locally in `user://`; from v1.3 on the server, and the client only sees the save list and sends commands.

**Saving is automatic.** The player should not have to remember it: the state is written by itself at every dawn (`autosave_ticks`), on exit, before applying a new strategy version and, optionally, every N minutes of real time. The last three autosaves are kept plus one for each simulation day; older ones are deleted. On launch the game continues from the latest autosave by itself; "new world" is a separate deliberate action. So that writing does not stall the simulation, serialization runs in a separate thread from a copy of the arrays (a few megabytes are copied in milliseconds), and the file is first written under a temporary name and only then renamed, so a crash during writing does not corrupt the previous save.

---

## 10. Default parameters

| Group | Parameter | Value |
|---|---|---|
| World | size | 2048x2048 (set at generation; minimum 256x256, multiple of 64) |
| | chunk | 64x64 |
| | water / rock share | 12% / 10% |
| | resource patches | 40 in the active zone at start, 10–60 units each |
| | starting food | 60 items of 1–5 units each |
| | active zone radius | 200 cells from the nest plus known chunks |
| Time | ticks per second | 10 |
| | day / dusk / night / dawn | 600 / 60 / 400 / 60 ticks |
| | queen planning | every 10 ticks |
| Nest | role composition | 15 / 20 / 15 / 30 / 20 (scout / guard / builder / carrier / harvester) |
| | food reserve in storage | 20 units |
| | start | queen and 100 myrmeks on open ground, no structures; within 30 cells, 2 resource patches and 20 units of food |
| | `seal_at_night` | on |
| Food | `T_food` / `p_food` | 200 ticks / 0.3 per active chunk |
| Resources | `T_res` | 3000 ticks |
| Predators | target count (spider / beetle / lizard) | 3 / 2 / 2 |
| | spawn ring | 60–150 cells from the nest |
| Queen's brain | `queen_brain` | `PROGRAM` (starting program from the library) |
| | `N_revision` | 1120 ticks (no more than once a day, except on events) |
| | minimum LLM interval | 60 real seconds |
| | LLM provider | Gemini 3.1 Pro (Google AI API); `MOCK` in tests |
| Network (v1.3) | `net_rate` | 10 packets per second per client |
| | `net_margin` | 8 cells around the camera frame |
| | port and access | WebSocket behind Caddy or nginx (`wss://`), token in the server configuration |
| Construction | `build_time` | 10 ticks per cell |
| | `demolish_time` | 5 ticks per cell |
| Paving | `pave_speed` | 2 (cooldown divided by 2, minimum 1) |
| | cost | 1 resource per cell |
| | `pave_traffic` | 30 passes per day per cell |
| Saving | `autosave_ticks` | 1120 (every dawn); also on exit and before a new strategy version |
| | what is kept | last 3 autosaves plus one per simulation day |
| | on launch | continue from the latest autosave |

---

## 11. Prototype "First Night" (v0)

The goal of the prototype is to get a living nest within a few development sessions, on which three things can be evaluated: how the vector graphics look at different zoom levels, whether the simulation is interesting to watch (roles, food economy, the first night), and whether the "report → Gemini → plan → behaviour change" loop works. The prototype is not a separate codebase: it is v1 with a reduced scope, so everything written here is only extended later.

### 11.1 What stays without compromise

Pure simulation in arrays separate from rendering; deterministic seed and discrete ticks; one agent per cell; energy and hunger for everyone; fog of war with a frontier; walls, gaps and closing gaps for the night; day and night with predator night multipliers; start without a nest; vector SVG sprites and `MultiMesh` for myrmeks.

### 11.2 Simplifications

| Area | In the prototype | Returns in v1 |
|---|---|---|
| World | 256x256, no chunks and no active zone; global BFS over the whole world; minimap 1 pixel per cell | Size up to 2048, chunks, active zone |
| Roles | Three: **worker** (combines scout, carrier and harvester: carries if there is something to carry; mines if there is a patch; otherwise goes to the frontier), **builder** (walls, storages, gaps), **guard** (patrol and gaps). No cargo handover between myrmeks | Scout, carrier and harvester as worker specializations; cargo handover |
| Population | 40: 22 workers, 8 builders, 10 guards, plus the queen | About 100 in six roles |
| Predators | Spider only, with night multipliers | Beetle and lizard |
| Guards | Patrol and gaps | Escort, site guarding, defence strategies |
| Construction | Walls and storages; the nest plan is fixed rings that grow with the population | Paving and roads by traffic |
| Queen's brain | `PROGRAM` and `LLM`. The strategy is a GDScript module with `plan(s)`, loaded on the fly, with static checking and a dry run. The `StateView` API is tiny: about ten state variables (phase, population, deaths since dawn, food in storage, nearest food, predators within a radius, whether the ring is closed, capacity versus population, gap status) and six policy fields (food versus construction weight, share of guards at gaps, close gaps at night, ring radius, share of workers on resources, construction priority). The LLM writes the program at the start and revises it after the first night and on the "more than three deaths since dawn" event. Providers: Gemini 3.1 Pro and `MOCK`, which reads the program from a file | Lua runner with sandbox, full API, strategy library, arena |
| Graphics | Flat tiles without autotiling; two zoom levels, 16 and 32 px; `CanvasModulate` for night; no light near the gap | Autotiling, four zoom levels, light |
| UI | Camera; pause and speeds 1x, 4x, 16x; minimap; click on a myrmek with a basic inspector; statistics (population, food, deaths); event log; queen panel with the current program and policy; two interventions: place food and release a spider. Parameters are edited in `.tres` | Parameters panel, full inspector, all interventions |
| Saving | Automatic only: one file, written at dawn and on exit, on launch the game continues from it; no slots and no manual saving | Autosave rotation, list of days, named slots |
| Cut entirely | Replay, paving and roads, escort, predator escalation, tests as a separate system (a headless run printing statistics to the console remains) | All of this in v1 and later |

### 11.3 Evaluation criteria

- The graphics look good at both zoom levels, and 40 myrmeks at 16x speed do not drop frames.
- Without the LLM the nest survives the first night in at least half of the seeds, i.e. the balance is not broken.
- The program from Gemini arrives in less than ten seconds and visibly changes behaviour: after losses more guards stand at the gaps, and when space runs short a new ring starts earlier.

### 11.4 Iteration order

1. Simulation and world generator in headless mode with statistics printed to the console; state serialization and autosave to a single file.
2. Rendering, camera, minimap, day and night.
3. Three roles, nest construction, the first night.
4. Spider, combat, deaths.
5. The LLM loop, first with `MOCK`, then with Gemini; the queen panel.
6. Inspector, interventions, event log.

Estimated size: three to four thousand lines of GDScript.

---

## 12. Roadmap

**v0: prototype "First Night"** (section 11).

**v1.0: this specification.**

**v1.1: births.** On every planning cycle the queen checks: energy is at least 70 and storage holds at least one unit above the reserve. If so, she consumes one unit of food and gives birth to `N_birth` myrmeks (default 3) of the role with the largest deficit against the desired composition. The queen computes the desired composition from needs: a large frontier means more scouts, spotted predators mean more guards, a long build queue means more builders, lots of known food means more carriers.

**v1.2: replay.** A log of observer interventions on top of the seed, to reproduce any run from the start without saving the full state.

**v1.3: server-side simulation and clients.** The simulation moves to a Linux server and runs continuously; clients only observe and intervene. The text below is the plan for this version, preserved in full.

**Server**: the same project, launched as `godot --headless --server` (a separate main scene). It runs the tick loop at its own speed, accepts connections via `WebSocketMultiplayerPeer`, applies client commands at tick boundaries and logs them, calls the LLM, and makes autosaves. Several clients can watch one simulation at the same time. Deployment: a home Linux machine, a systemd service or a Docker image with a headless export, with Caddy or nginx in front, which serves the web client, terminates TLS (`wss://`) and adds the COOP/COEP headers required by Godot in the browser. Access from outside the home network is through a tunnel or VPN at the owner's discretion. Access is via a single shared token in the server configuration, the same for all clients; accounts and roles are not planned.

**Client** simulates nothing: it keeps a local copy of only what it sees, draws it and sends commands. One project is exported to the web (the main option, works on Mac, iPad and phone) and as a native macOS application. Agent positions are interpolated between updates, so movement is smooth even with less frequent packets.

**What is transmitted: not the whole world, but a snapshot once and then only changes.**

| Stream | When | What exactly | Approximate size |
|---|---|---|---|
| Snapshot | On connection or after losing sync | Clock, parameters, current policy, nest state (storages, gaps, plan), known-cells mask, terrain and structures of known chunks, all objects and agents on the known map, statistics, recent events; all compressed | 100–500 KB for a typical nest; the full 2048x2048 terrain is not sent, the client receives unknown chunks when they are discovered or when "true map" is on |
| Area delta | Up to `net_rate` times per second (default 10), independent of simulation speed | Agents in the camera rectangle with a margin of `net_margin` cells: position, direction, state, cargo, hp; cell changes in this area | about 12 bytes per agent; with 100 agents in frame, up to 12 KB/s |
| Global changes | Every packet, only when present | Newly known cells, built and demolished structures, objects appearing and disappearing, deaths and births, log events | Sparse, tens of bytes per event |
| Minimap | Once every `N_map` ticks | Only changed minimap blocks, as palette indices | 1–3 KB/s |
| Statistics and queen | Once per second | Population, storages, death counters, current policy, strategy program version and latest changes | hundreds of bytes |

The client tells the server its camera (a rectangle in cells); when the camera moves it requests the full state of chunks it does not yet have or whose versions are outdated, and then receives deltas. Every chunk and every packet has a version number: a missing number means desynchronization, and the client requests a new snapshot. Client commands: time control, interventions (section 7), parameter changes, queen mode and provider, save and load, chunk requests. Messages are binary (`PackedByteArray` with fixed fields), compressed when larger than a kilobyte.

With 100 myrmeks and one viewer, traffic does not exceed 20 KB/s; with 5000 myrmeks the volume depends on how many of them are in frame, not on the population, because the minimap and statistics are aggregates.

**v2: multiple nests.** `nest_id` is already in every agent and every knowledge array; the server already accepts multiple clients, so each nest can have its own observer with intervention rights over that nest only. Added: separate structures and storages per nest, hostility between nests, myrmek-versus-myrmek combat, food theft, territory, and siege: builders of an enemy nest can demolish someone else's walls. The minimap shows nests in different colours.

**v2: LLM queens for multiple nests.** Each nest has its own model or persona; a shared channel for diplomacy (truces, trade, threats), which also goes through the log.

**v2: evolution.** Myrmek traits (speed, vision, attack, energy efficiency, capacity) with mutation at birth; selection through survival and contribution to food.

**v2: queen learning: the program as a genome.** Since the strategy is a program, learning means improving the program based on results, not tuning weights in a black box. Three mechanisms, from simple to complex:

- Revision by metrics. After each day the nest computes its results (deaths by cause, food collected, nights without losses, capacity growth) and shows the LLM which strategy branches fired and what came of it; the model rewrites the program. This already exists in v1 as the `LLM` mode; here a longer memory is added: a version history with results, so the model does not return to ideas that already failed.
- Arena and selection. Several programs are run on the same seeds in headless mode; the best remain in the library, the worse are discarded. The model receives "program — result" pairs and writes new candidates, i.e. it plays the role of mutation and crossover with meaning.
- `LEARNED` mode. A small neural network tunes the program's numerical parameters (weights, thresholds, radii) based on state and experience, or picks a program from the library; when confidence is lacking (ensemble disagreement or a novel state), the queen asks the LLM and remembers the answer. The constraint is the same: all of this is strategy only, tactics remain algorithmic.

The program together with its tuned parameters is the "queen's genome": a daughter queen inherits it, and revision by the model and selection in the arena play the role of mutation. This way evolution happens not only at the level of myrmeks (body traits) but also at the level of nests (strategy): the lines of queens whose nests survive to split are the ones that persist and multiply.

**v2: nest splitting (swarming).** A well-fed queen with a food surplus can give birth to a new queen. The daughter queen leaves the nest with a small escort, then gives birth to her own myrmeks, now with her own `nest_id`, and chooses a site for a new nest. A kinship timer `kin_timer` runs between the parent nest and the new one: until it expires, the parent nest considers the daughter queen and her brood its own: it does not attack them, lets them through its gaps, and her myrmeks may take food from the parent storage within a limit. When time runs out, kinship ends and the parent nest treats the new one like any other foreign nest: it attacks its myrmeks, and the defence and siege strategies (v2, multiple nests) work at full strength. The daughter queen inherits her mother's genome with mutation, so two neighbouring nests from the same root can behave differently, which is direct material for comparing strategies. Technically: a kinship table between nests with timers, the birth of a queen as a separate policy decision, and choosing a nest site from the mother's known map (passed to the daughter at the moment she leaves).

**Later:** maximum myrmek age (there is no age in v1), "last known state" memory instead of live observation, digging ground, weather, food spoilage, sound.

---

## 13. Open questions

There are no open questions: all concept decisions have been made. New questions are added here as they arise.

---

## 14. Change history

**v0.20 (27.09.2026)**

- The specification is now maintained in English; the Ukrainian original is kept for history, frozen at v0.19, as `myrmex-concept-v0.19-UA.md`.
- Movement specified as 8-directional with uniform step cost; all radii and adjacency use Chebyshev distance (5.1).
- Deaths unified: a starved myrmek disappears like an eaten one, and in both cases carried units drop on the cell as `FOOD`/`PILE`, or are lost if the cell already holds an object (5.6).
- Known but unreachable cells (no finite distance in the field) are never assigned as task targets (6.2).
- Clarified the night vision reduction: it affects detection, and the reveal radius is capped by current vision, so scouts reveal within radius 4 at night (4).
- The task `FEED_ANT` renamed to `FEED_MYRMEK`, closing the rename left unfinished in v0.2 (6.2).
- Fixed pre-v0.16 leftovers: the prototype's queen panel shows the current program and policy, and the evaluation criterion says "the program from Gemini" (11.2, 11.3).
- The change history rephrased in a neutral voice ("per review feedback" instead of addressing a dialogue partner) (14).
- Wording: "wall or storage cell" in the flow diagram (6.5); a note on the lizard's "1+" night cooldown (5.5).

**v0.19 (27.09.2026)**

- Closed the last two open questions for v1.3: server access is a single shared token for all clients, without accounts; hosting is a home Linux machine, with external access through a tunnel or VPN (12). Section 13 is empty.

**v0.18 (27.09.2026)**

- Per review feedback, saving became automatic: written at every dawn, on exit and before a new strategy version, continuing from the latest autosave on launch, rotation (last three plus one per day), writing in a thread from a copy of the arrays and via a temporary file (9, 7, 10).
- Minimal autosave to a single file with continuation on launch returned to the prototype; added to the first iteration (11).

**v0.17 (27.09.2026)**

- Per a review decision, the strategy language is real code instead of JSON rules: GDScript loaded on the fly in the prototype, with static checking and a dry run; in v1, Lua 5.4 via godot-luaAPI with a sandbox and instruction limit; both behind the `StrategyRunner` interface (6.3, 9, 11).
- Added the paragraph "What the strategy sees": access is not automatic but goes through `StateView`, a copy of simple values plus helper functions for large structures; the `World` object is not passed (6.3). The example program was rewritten in Lua.
- Updated the v1 scope (1), the "Queen's brain" row (2), the description of version validation in LLM mode (6.3), and the contents of `res://llm` (9).

**v0.16 (27.09.2026)**

- Following a review suggestion, the queen's strategy became a program: subsection 6.3 was rewritten. The LLM no longer produces a plan for a horizon but writes and revises a rule program (JSON with conditions in Godot `Expression`, actions on the policy and memory) that the queen runs herself on every cycle. The modes are now `PROGRAM` and `LLM` (plus `LEARNED` in v2); the `ADAPTIVE` mode disappeared, because adaptive rules are just a program. Added validation of versions by dry run and a strategy library with an arena.
- Updated the v1 scope (1), the "Queen's brain" row in key decisions (2), the queen panel in the UI (7), the files `strategy.gd`, `queen_policy.gd`, `nest_report.gd` and the contents of `res://llm` (9), the `queen_brain` and `N_revision` parameters instead of `N_policy` (10), and the "Queen's brain" row in the prototype with a tiny rule language (11).
- The "queen learning" item in the roadmap was rewritten as "the program as a genome": revision by metrics, arena and selection, `LEARNED` mode for program parameters (12).

**v0.15 (27.09.2026)**

- Added section 11 "Prototype 'First Night' (v0)": goal, what stays without compromise, a table of simplifications (256x256 world, three roles: worker, builder, guard; 40 myrmeks, spider only, a minimal queen plan with `FIXED` and `LLM`, reduced graphics and UI, saving and roads cut), evaluation criteria and iteration order.
- The former sections 11–13 became 12–14; a v0 line was added to the roadmap.

**v0.14 (27.09.2026)**

- The server architecture was moved from the v1 scope to the next version: the whole text of the former subsection 9.1 (the "snapshot plus deltas" protocol, deployment, clients) was preserved without cuts as the item "v1.3: server-side simulation and clients" in section 11.
- v1 is a single native macOS application with simulation and rendering in one process (1, 2); the `res://app` folder in the structure, with `res://server`, `res://client`, `res://net` marked as v1.3 (9); the "Connection" row in the UI and network parameters marked as v1.3 (7, 10); saves in v1 are local, the LLM key is in local configuration (6.3, 9); open questions about access and hosting assigned to v1.3 (12).

**v0.13 (27.09.2026)**

- The simulation became server-side: headless Godot on Linux, a web client (main) and a native macOS client from the same project, connected via WebSocket; added "Server" and "Client" rows to key decisions (2), a new subsection 9.1 "Server and client" with the protocol (snapshot once, then camera-area deltas, global changes, minimap, statistics), the folders `res://server`, `res://client`, `res://net` (9), a "Connection" row in the UI (7) and network parameters (10).
- The main model for LLM mode is Gemini 3.1 Pro via the Google AI API, with the key only on the server (6.3, 10); the model question was closed, and a question about access and hosting was added instead (12).
- Clarified that saves live on the server (9) and that in v2 each nest can have its own observer (11).

**v0.12 (27.09.2026)**

- Closed the graphics style question: a vector style drawn with sprites in Godot (SVG rasterized on import at high resolution, colour via `modulate`); section 8 was rewritten accordingly, and one open question remains (12).

**v0.11 (27.09.2026)**

- Following a review suggestion, the "queen learning" item in the roadmap (11) was rewritten to the "LLM as teacher, neural network as experience" scheme: a shared directive schema for both, an ensemble of small MLPs as a confidence measure plus state novelty, a request to the LLM only at low confidence, an experience memory weighted by outcomes, network weights as a genome for inheritance. A `LEARNED` (v2) row was added to the modes table in 6.3.
- Per a review clarification, 6.3 and 11 now state explicitly: the LLM and the neural network work only at the strategic level. They produce a plan for a horizon of `N_policy` ticks and do not interfere with tactics; the LLM can propose a different horizon for the next decision.

**v0.10 (27.09.2026)**

- Following a review suggestion, two v2 items were added to the roadmap (11): "queen learning" (the policy as a genome that improves and is inherited; memory for the LLM queen; evolution at the nest level) and "nest splitting" (a daughter queen, the `kin_timer` kinship timer after which the parent nest becomes hostile, inheritance of the genome with mutation).

**v0.9 (27.09.2026)**

- Following a review suggestion, an LLM was added for the queen: a new subsection 6.3 "The queen's brain: algorithms and LLM" with `FIXED`, `ADAPTIVE`, `LLM` modes, a state report, a directive schema, an asynchronous call, providers, and a response log for reproducibility. The former 6.3 and 6.4 became 6.4 and 6.5.
- Updated the v1 scope (1), key decisions (2: "Queen's brain" row, determinism clarified), UI (7: "Queen" panel, mode toggle), project structure (9: `queen_policy.gd`, `nest_report.gd`, `res://llm/`), parameters (10), roadmap (11: LLM queens for multiple nests), and open questions (12).

**v0.8 (27.09.2026)**

- Closed four open questions based on review answers: predators on roads are not sped up (6.3, the `pave_predators` parameter removed from 10); predator carcasses are food that carriers take to storage (3.4); guards escort groups and guard locations (5.2, the `ESCORT` and `GUARD_SITE` tasks in 6.2); myrmeks have no age in v1 (5.1, 7, 11; moved to "Later").
- Added a "Defence strategy" item to 6.2 with example strategies ("fortress", "convoy", "outposts", adaptive).
- Only the graphics style remains among the open questions (12).

**v0.7 (27.09.2026)**

- Following a review suggestion, the "floor" returned in a new role: the `PAVEMENT` structure (paving) speeds up myrmek movement and is laid both inside the nest and outside as roads (3.1, 5.2, 6.3).
- Roads are planned by traffic: the nest counts passes over cells and paves the busiest routes (6.3); the `PAVE` task was added (6.2).
- Pathfinding became weighted: paving is cheaper than ground (9); the energy cost per step on paving was reduced (5.4); a paving colour was added to the minimap (7) and to autotiling (8).
- Added the `pave_speed`, `pave_traffic`, `pave_predators` parameters and cost (10); a new open question 5 about predators on roads (12).

**v0.6 (27.09.2026)**

- Closing gaps with walls for the night became the default behaviour: `seal_at_night` is on (sections 4, 6.3, 10); open question 5 was closed.
- Explicitly added that builders can demolish any wall (5.2, 6.3): open gaps, dismantle old rings, break through a wall from inside; the resource is returned. Added the `demolish_time` parameter (10).
- Added siege to the v2 roadmap: demolishing other nests' walls (11).

**v0.5 (27.09.2026)**

- Per review feedback, "floor" and "entrance" were removed as structure types: the nest is a patch of ground enclosed by walls; the interior is computed by a flood fill from the queen chamber (section 6.3), not built, and costs nothing.
- Walls are impassable to everyone without exception. A gap is an ordinary ground cell in the wall ring; the myrmeks make gaps themselves (builders place and dismantle walls) and guard them (sections 2, 6.3).
- Predators no longer "break the entrance" and are never "too big": the "Nest" column and the `BREACH` state were removed from 5.5, and the `breach_time` parameter from section 10; a predator enters only through an open gap (5.5, 5.6).
- The `HOLD_ENTRANCE` task was replaced with `HOLD_GAP`, and `OPEN_GAP` and `CLOSE_GAP` were added (6.2); the `seal_at_night` option was added (sections 4, 10).
- There is no longer a starting nest: at the start there are only the queen and all myrmeks on open ground, and the nest must be built before the first night (sections 2, 3.3, 10); a starting plan for the queen's first day was added to 6.2 with an estimate of whether the walls can be built in time; the question about the size of the starting nest was closed.
- Clarified the night policy (4), the event log (7), resource flows (6.4) and open questions (12).

**v0.4 (27.09.2026)**

- Per a comment on section 2: inside the nest, as outside, there is at most one myrmek per cell; "up to 8 per cell" was removed. The expansion plan in 6.3 was rewritten accordingly (there must be enough floor for the whole population), the starting nest in 3.3 was clarified, as was the night policy in section 4 (myrmeks return to the nest as far as the floor allows).
- "Colony" was replaced with "nest" throughout the text: the nest is both the community and the base. In code, `colony_id` → `nest_id`, `colony.gd` → `nest.gd`; section 6.3 was renamed "The nest as a structure".
- The question about the colony's name was closed; question 6 about the size of the starting nest was added instead.

**v0.3 (27.09.2026)**

- Per a comment on v0.2: save and load moved into the v1 scope (section 1).
- Added a description of saving to section 9 (what is saved, format, behaviour after loading) and the `save.gd` file to the project structure.
- Added a "Saving" row to the UI (section 7) and autosave and slot count parameters (section 10).
- In the roadmap, v1.2 now contains only replaying a run from the intervention log (section 11).
- The item about saving was removed from the open questions, and the rest were renumbered (section 12).
- Per a comment on section 2: the world size is set at generation and can be smaller than 2048; clarified sections 2, 3.2, 7 (minimap), 9 (memory) and 10.
- "Anthill" in all forms was replaced with "nest" (in code: `Nest`) throughout the text; adjectives were aligned ("compact nest", "starting nest"). The term was added to the header.

**v0.2 (27.09.2026)**

- The project name was changed from Formica to Myrmex; the origin of the name and the term for the creature were added to the header.
- The word "ant" (мураха) in all forms was replaced with "myrmek" throughout the text (sections 1–12), with grammatical agreement in neighbouring words.
- In section 9, the file `ant.gd` was renamed to `myrmek.gd`.
- Item 7 about the name of the colony and nest was added to the open questions.
- Code identifiers (`FEED_ANT`, `NEST_*`) have not been changed yet.

**v0.1 (27.09.2026)**: first version of the concept.
