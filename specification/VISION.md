# Vision — Myrmex

Document version 1.9 — 27 September 2026.

## In one sentence

Myrmex is a deterministic cellular-world simulation in Godot where an autonomous nest of ant-like myrmeks — coordinated by a queen whose strategy is a real program, written by a human or an LLM — survives its first night, builds, and expands while you watch and prod the world, but never command a single creature.

## What we are building

A living nest in a large 2D cell world. About a hundred myrmeks in six roles (scouts, guards, builders, carriers, harvesters, and a stationary queen) share one knowledge map under fog of war, run an energy-and-hunger economy, mine resources, raise walls, and defend the gaps they themselves leave in those walls, while predators hunt by day and hunt harder by night. The founding drama is built in: the nest starts on bare ground and must gather, build, and shelter before the first dusk.

The queen's mind has two levels. The tactical level is an algorithmic task board that turns the nest's state into assigned tasks every planning cycle. Above it sits a **strategy program** — real code with a `plan(state) -> policy` function and persistent memory — that the queen executes herself in microseconds. In `LLM` mode a language model writes that program at the start and revises it by results (deaths, food income, nights without losses); every version is validated, journaled, and replayable. Strategies live in a library and can be raced against each other on identical seeds — a strategy arena.

The observer gets a StarCraft-style camera and minimap, an inspector, live parameter sliders, intervention tools (drop food, release a predator, reveal terrain), and automatic saves. The first release is a single native macOS app; later the simulation moves to a headless home server with web clients, then to several warring nests, births, evolution, and the strategy program as an inheritable genome. Evolution then runs at two levels: myrmek bodies mutate at birth, while queen strategy programs mutate through LLM revision and arena selection — the lines whose nests survive to swarm are the ones that persist and multiply.

## For whom

A private research-and-observation project for its author, and later a close circle of observers over a home server — not a commercial game and not a public service. Two interests drive it: watching a small ecosystem live by its own logic, and experimenting with LLM-written strategies against human-written ones on the arena.

## The strategy is a program

"Strategy" here is not a metaphor and not a bag of tuned weights — it is code the queen executes herself on every planning cycle, in microseconds, with a `memory` that survives between calls. It can be read, diffed, edited by hand, stored in a library, raced on the arena, and — later — inherited by a daughter queen as a genome. A whole strategy looks like this:

```lua
-- ambition is a budget: six goals, 0..1 each, normalized to sum to 1.
-- this one is a forager — food first, and it says so.
goals = {
  survival = 0.15, food = 0.45, shelter = 0.10,
  capacity = 0.10, territory = 0.15, queen = 0.05,
}

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

It sees only what the nest knows (`s` is the `StateView`), it returns only a policy (`p`), and it can ask for its own revision (`request_revision`) — which is how a program written by an LLM asks its author to look at the results and rewrite it. Everything between planning cycles — every task, every myrmek — is handled by the algorithmic tactical level, for free.

A program is **optional, and it has to earn its place.** With none, the queen plays on her own built-in algorithm (`BUILTIN`), directing every myrmek herself — that mode alone is expected to survive the first night, and it is the bar every program must clear. Because each strategy declares its own `goals`, the engine can judge it: at every dawn it scores declared against actual and, when a strategy fails — or breaches a floor it was never allowed to declare away — the queen demotes to `BUILTIN` at once, blacklists that version, and tries the next genuinely *different* idea from the library — the one whose declared goals fit what the nest needs right now, because the engine classifies its own situation (founding, siege, famine, crowded, stable) rather than trusting a static ranking. Near-identical programs count as one idea and are skipped, and after a couple of real attempts the ladder stops guessing and asks the model — handing it the failed programs together with their numbers, so the next attempt starts from what did not work rather than from nothing. The nest never stops playing while that happens.

## Designed tensions

The drama is arithmetic, not scripting. These numbers are the intended starting point, kept tunable:

- **The first night is winnable, barely.** A wall ring of radius 5 is about 40 walls — 40 resources — with interior room for roughly 70 of the 100 myrmeks. Twenty harvesters mine that much in under half a day, so the walls close before dusk *if* the patch is near; whoever doesn't fit inside sleeps by the gap under guard. The generator guarantees a hard-but-possible day one: two patches and ~20 food within 30 cells.
- **The food margin is thin.** A hundred myrmeks burn about 110 food units per day; the active zone spawns 120–150. Thirty carriers moving two units over hundred-cell trips supply ~0.3 units per tick — enough, with little to spare. Energy and starvation exist precisely to create this pressure: they make logistics matter and give carriers a purpose.
- **The night dilemma.** Sealing every gap at dusk makes the nest impregnable — but when the store is below the reserve, work continues in the dark despite the risk. Safety and hunger pull in opposite directions, and the strategy program owns that trade-off.
- **Defence without cheats.** Nothing stops a predator at a gap except a guard physically standing in it, and nothing gets through a wall — anyone's wall. Whether the nest is a fortress, a convoy system, or a chain of outposts is strategy, not rules.
- **The world wakes with expansion.** Only the active zone around the nest lives; the rest of the huge map sleeps until scouts reach it. A 2048x2048 world becomes meaningful exactly as fast as the nest's knowledge grows.

## The look

The logic is cellular; the picture is free. Vector art — simple shapes, soft gradients and shadows, deliberately no pixel aesthetic — in a **three-quarter RTS view**, the StarCraft feel: a high-angle camera over an axis-aligned **square** cell grid (never a diamond-isometric one, never a 3D camera — the volume lives in the sprites). Walls, rocks, storages and the queen's dome are drawn with a top face and a darker front face, cast soft shadows and overlap the cell above, Y-sorted; the ground plane stays a flat grid. Agents are **directional frames** — five per pose (N, NE, E, SE, S), the west side mirrored — still one myrmek silhouette for every role, tinted, so the set stays drawable by one person. Sprites stay sharp from 8 to 48 px per cell; movement is interpolated so the cell-by-cell logic looks alive; the ground is dressed by a render-only **decor layer** — grass tufts, pebbles, flowers, dry patches, seeded from the world hash — so the field never reads as a flat green while the simulation stays untouched (decor is under-agent scale: nothing looks blocking that is not); night falls as a smooth tone shift with warm light at the nest gap.

## Principles

- **The nest is autonomous.** The observer intervenes in the world — food, predators, parameters — never in a myrmek's head. There are no unit orders.
- **Simulation is pure data.** The sim has no dependency on the scene tree; rendering only reads state. Headless runs (tests, arena, server) are first-class from day one.
- **Determinism end to end.** One seed, discrete ticks, agents processed in id order, LLM responses journaled: any run replays exactly, with or without the model.
- **Strategy is a program, not weights.** `plan(s) -> policy` plus a `memory` table, behind the `StrategyRunner` seam — sandboxed Lua 5.4 from the very first prototype. Code can be read, diffed, versioned, and inherited.
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
- **StrategyRunner** — the seam hiding the strategy execution environment (sandboxed Lua 5.4 via godot-luaAPI) from the rest of the code.
- **`queen_brain`** — who decides the policy: `BUILTIN` (no program — the queen's own algorithm directs every myrmek), `PROGRAM` (a hand-written Lua program), `LLM` (the model writes and revises one), `LEARNED` (v6).
- **Situation** — what the nest needs right now, classified by the engine from its own numbers: `FOUNDING`, `SIEGE`, `FAMINE`, `CROWDED`, `STABLE`. It decides which goals matter, and therefore which strategy fits; the observer can pin one by hand.
- **The six goals** — the closed list every nest works toward: `survival`, `food`, `shelter`, `capacity`, `territory`, `queen`. A strategy covers all six to a degree (0..1, summing to 1 — ambition is a budget), a situation demands the same six with weights, and fit is their dot product. Coverage sets the bar a strategy is held to; it can never lower a floor.
- **Scorecard** — the dawn comparison of declared goals against actuals, with a healthy / warning / failing verdict; journaled, and read alike by the queen panel, the model and the arena.
- **Escalation ladder** — what happens on a failing verdict: demote to `BUILTIN`, blacklist the version, try the next genuinely different library strategy within a small budget, then ask the LLM with a dossier of what failed.
- **Fingerprint** — the policy vector a program produces on a fixed set of states; two programs that match are one idea, which is how siblings are skipped and a rehashed answer is refused.
- **Strategy library / arena** — stored strategy files with version history; headless batch runs on identical seeds producing a results table.
- **Distance field** — weighted BFS over known passable cells; going home is gradient descent, no search.
- **Tick / day cycle** — the discrete simulation step (10/s base); a day is day–dusk–night–dawn (600/60/400/60 ticks), with night favouring predators.
- **Interventions** — observer actions on the world: place food, create a patch, summon or remove a predator, heal, reveal map.

---

## History of changes

**v1.9 (27.09.2026)** — the projection decision reversed by the author after side-by-side mockups: the look is now the ¾ RTS view (sprite volume on an axis-aligned square grid, directional agent frames), replacing pure top-down; diamond isometric and true 3D remain excluded.

**v1.8 (27.09.2026)** — added the render-only decor layer to The look: seed-hashed ground dressing for variety, invisible to the simulation.

**v1.7 (27.09.2026)** — pinned the projection in The look: pure top-down, no isometric/pseudo-3D, as the consequence of rotation-based rendering and the one-silhouette rule.

**v1.6 (27.09.2026)** — goals became the closed list of six covered by every strategy to a degree (normalized to sum to 1), with fit as a dot product against the situation's demand; the worked example now declares a coverage vector (The strategy is a program, Glossary).

**v1.5 (27.09.2026)** — added the engine-classified **situation** that decides which goals matter now, and therefore which strategy fits (The strategy is a program, Glossary).

**v1.4 (27.09.2026)** — a program is optional and must earn its place: named the program-free `BUILTIN` mode as the bar every strategy has to clear, added declared `goals` to the worked example, and described the dawn scorecard, the escalation ladder with its budget and fingerprint-based similarity guard, and the failure dossier sent to the model (The strategy is a program, Glossary).

**v1.2 (27.09.2026)** — decision folded in: strategies are sandboxed Lua from the first prototype (Principles, Glossary).

**v1.1 (27.09.2026)** — restored vision material from the concept that Architecture and Roadmap do not carry: the strategy-program example and its meaning (The strategy is a program), the first-night math, food margin, night dilemma, no-cheat defence and the waking world (Designed tensions), the visual direction (The look), and evolution framed as two-level selection (What we are building).

**v1.0 (27.09.2026)** — initial version, derived from the retired concept v0.20 ([history/](history/)).
