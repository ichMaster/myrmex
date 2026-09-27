# Roadmap — Myrmex

Document version 1.5 — 27 September 2026.

Seven versions, built in order: **v0** prototype "First Night" (headless core, three roles, the spider, sandboxed Lua strategies, the Gemini loop) → **v1** the full nest (big world, six roles, three predators, paving, the full StateView, the arena, full UI) → **v2** births → **v3** replay → **v4** server and clients → **v5** nests at war → **v6** evolution and the genome. Versions are numbered from 0; phases inside a version are numbered `vA.B`. Each phase lists a **Goal**, a short description, a **Tasks** list, and a **Definition of Done (DoD)**, and ships with the automated tests that encode its DoD (see [ARCHITECTURE.md](ARCHITECTURE.md) §Testing).

**Versioning (`A.B.C`).** Roadmap phase `vA.B` → semver `A.B.0`; a post-release fix on that phase bumps `C`. Never bump a version without explicit confirmation.

*Mapping from the retired concept ([history/](history/)): the concept's v0 prototype is v0 here; its v1.0 scope is spread across v1; its v1.1 births / v1.2 replay / v1.3 server are v2 / v3 / v4; its v2 ideas are v5–v6.*

---

## v0 — Prototype "First Night"

The living nest in miniature, built to answer three questions: does the vector look hold up at different zooms, is the simulation interesting to watch (roles, food economy, the first night), and does the "report → Gemini → program → behaviour change" loop work. Not a separate codebase — v1 with reduced scope: a 256x256 world without chunks (global BFS, 1 px/cell minimap), **three roles** (worker = scout+carrier+harvester, builder, guard; no cargo handover), 40 myrmeks + the queen (22/8/10), the spider only, fixed-ring nest plans, a tiny `StateView` (~10 state variables, 6 policy fields), two zooms (16/32 px), two interventions, one autosave file. Everything kept without compromise: pure-data sim, determinism, one agent per cell, energy and hunger, fog of war with a frontier, walls/gaps/night sealing, day–night with predator multipliers, the bare start, SVG + MultiMesh rendering. Estimated size: three to four thousand lines of GDScript. Depends on: nothing — this is the foundation.

### v0.1 — Headless simulation and world generator

**Goal:** a living world in arrays, observable from the console, saved and resumed deterministically.

Stand up `res://sim/` as pure data: layer arrays, the clock with the day cycle, the single seeded RNG, worldgen, the seven-phase tick loop (with empty agent phases for now), serialization, and a headless entry point that prints statistics.

**Tasks:**
- Project skeleton; `res://sim/` with `world.gd`, `clock.gd`, `rng.gd` (named streams derived from the master seed), `worldgen.gd`; parameters in `res://data/sim_params.tres`; the gdUnit4 addon and `scripts/test.sh` as the canonical headless test gate.
- Worldgen from seed: noise water/rock + cellular smoothing, largest-region start point cleared to radius 12, start guarantees (≥2 patches, ~20 food within 30 cells), patches with shared reserves, starting food.
- The tick loop with the fixed phase order; day/dusk/night/dawn transitions; speed multipliers and step as sim-level controls.
- Food spawning (`T_food`/`p_food`) and patch regeneration (`T_res`) — world-wide in v0 (no chunks).
- Serialization (`var_to_bytes` compressed + JSON header) and a single-file autosave at dawn and on exit; launch resumes from it.
- Headless run (`godot --headless`) printing population/food/day stats every N ticks.

**DoD:** a seeded headless run prints evolving world stats; two runs from one seed produce identical output; kill and relaunch resumes from the autosave and continues identically.

**Tests:** worldgen guarantees (start clearing, patches, food, connectivity); determinism — same seed → identical state hash after N ticks; save/load round-trip → bit-identical continuation.

### v0.2 — Render, camera, minimap, day and night

**Goal:** watch the world live.

The view layer over the untouched sim: flat tiles in a window around the camera, the minimap, day/night tinting, and time controls.

**Tasks:**
- Tile-window renderer (~128x96 buffer refilled on camera moves); flat tiles, no autotiling; zooms 16 and 32 px.
- Camera panning (WASD, edge, drag); minimap 256x256 at 1 px/cell with the colour priority (unknown > predator > myrmek > food > resource > nest > water > rock > ground), viewport frame, click-to-move; updates only for changed cells every `N_map` ticks.
- `CanvasModulate` day-phase gradient; pause / 1x / 4x / 16x / single step; day-and-tick counter with phase indicator.
- SVG sprite pipeline: import at 128 px/cell with mipmaps; tint via `modulate`.

**DoD:** the generated world scrolls smoothly at both zooms at 16x speed; the minimap tracks changes and moves the camera; night is visibly night.

**Tests:** the view never mutates sim state (contract); minimap block invalidation on cell changes. Visual quality is assessed manually (prototype criterion: pleasant at both zooms).

### v0.3 — Three roles, building, the first night

**Goal:** from bare ground to a walled nest before dark — or a lesson in why not.

Agents arrive: worker/builder/guard state machines, the queen's tactical task board, knowledge and frontier, the energy economy, and nest construction with night sealing.

**Tasks:**
- Agent records and the shared state machine (`IDLE`/`GO_TO`/`WORK`/`RETURN`/`DEPOSIT` + `HUNGRY`/critical); 8-directional movement, one agent per cell; `MultiMeshInstance2D` rendering with interpolation and role tint.
- Roles: worker (carries if there is something to carry, mines if a patch is assigned, else explores the frontier), builder (walls, storages, open/close gaps), guard (patrol ring, stand in gaps); the immobile queen.
- Knowledge mask + incremental frontier; reveal radius 2 (5 for exploring workers); pathfinding: global weighted BFS distance field + local `AStarGrid2D`; unreachable targets never assigned.
- Task board on `N_plan`: `EXPLORE`, `FETCH_FOOD`, `HARVEST`, `BUILD`, `FEED_MYRMEK`, `PATROL`, `HOLD_GAP`, `OPEN_GAP`, `CLOSE_GAP`; ranking safety → feeding → food → build → explore; greedy assignment by distance; the hardcoded first-day plan. This is `queen_brain = BUILTIN`: the queen directs every myrmek on her own algorithm, with no strategy program anywhere in the project yet (Lua arrives in v0.5).
- Energy and hunger per §Agents (ARCHITECTURE), stored as fixed-point integers; eating from storage; starvation deaths with the cargo-drop rule.
- Construction: fixed-ring nest plan growing with population, `build_time`/`demolish_time`, resource return, flood-fill interior and capacity, `seal_at_night` (seal at dusk, reopen at dawn); night policy pulling myrmeks inside.

**DoD:** on a typical seed the nest raises a closed ring with one gap and a stocked food storage before the first dusk; myrmeks eat, starve, and die believably; capacity is respected; the whole thing still runs headless.

**Tests:** flood-fill interior/capacity; ring plan and sealing; frontier incremental = recomputed; energy budget (daily consumption within the designed band); task assignment skips unreachable targets; determinism still holds with agents.

### v0.4 — The spider, combat, deaths

**Goal:** danger that makes guards matter.

**Tasks:**
- Spider: ambush behaviour, `WANDER`/`HUNT`/`ATTACK`/`EAT`/`REST`, energy-driven hunting, night multipliers (cooldown, eating, vision); spawn ring 60–150 cells, target count.
- Combat: 8-adjacent damage each tick, stacking attackers, gap crossfire; worker one-hit deaths, `FLEE` for workers; carcass → `FOOD` hauled to storage; cargo drop on death.
- Balance pass: food spawn vs deaths vs guard coverage; death counters by cause.

**DoD:** on `BUILTIN` alone — no program, no model — the nest survives the first night in **≥50% of seeds** (headless batch); guards visibly intercept and hold gaps; a killed spider feeds the nest. This is the zero point every later strategy is measured against.

**Tests:** combat resolution and stacking; carcass and cargo-drop rules; night multipliers; the ≥50% survival smoke over a seed batch.

### v0.5 — The strategy program and the LLM loop

**Goal:** the queen's policy becomes a sandboxed Lua program; Gemini writes and revises it.

The strategic level over the task board: Lua 5.4 strategies via godot-luaAPI behind `StrategyRunner`, the tiny `StateView`, validation, the version journal, and the `PROGRAM`/`LLM` modes with Gemini 3.1 Pro and `MOCK`.

**Tasks:**
- The godot-luaAPI addon, its version pinned together with the Godot version.
- `StrategyRunner` with the Lua 5.4 runner: only `base`/`table`/`string`/`math` bound (no `os`/`io`/`require`/`load`, nothing from the engine), an instruction-counter hook that interrupts a looping `plan()`, protected calls, table conversion both ways; `memory` persists between calls (plain data only — it is saved with the state).
- Tiny `StateView` (~10 scalars: phase, population, deaths since dawn, food store, nearest food, predators within radius, ring closed, capacity vs population, gap status) + 6 policy fields (food-vs-build weight, guards-at-gaps share, seal at night, ring radius, workers-on-resource share, build priority); schema and bounds validation.
- Safety: the sandbox + instruction limit, policy bounds, and a dry run on recorded states; a failed or interrupted version is discarded, the previous keeps running.
- `PROGRAM` mode with strategy files, and **the shipped starter set** in `res://strategies/` — several hand-written Lua programs, each a few dozen lines expressing a different idea within the six policy fields: `baseline.lua` (the `PROGRAM` default), `fortress.lua` (guards at the gaps, always seal, tight ring), `forager.lua` (food-weighted, fewer guards), `growth.lua` (wider ring early). They are also the `MOCK` provider's input and the arena's first opponents.
- **The situation classifier** (`strategy_eval.gd`): `FOUNDING` / `SIEGE` / `FAMINE` / `STABLE` derived from state as a pure function with `situation_hysteresis` before a change takes effect, exposed as `s.situation` in the `StateView` and used to score which candidate fits; the observer can pin one from the queen panel as a journaled command. (`CROWDED` joins in v1.4, when capacity planning arrives.)
- **The six goals, coverage and the dawn scorecard** (`strategy_eval.gd`): the closed goal list (`survival`, `food`, `shelter`, `capacity`, `territory`, `queen`) with each goal's indicator, floor and ambition target in `sim_params.tres`; every program exports a `goals` coverage vector (0..1 each, normalized to sum to 1) which sets its expectation per goal as `floor + coverage × (target − floor)`; fit against a situation is the dot product of demand and coverage. At every dawn actuals are scored into a journaled `Scorecard` whose verdict is weighted by the current demand (healthy / warning / failing), with the engine's floors — population halving, a starved queen, a day with an empty store — checked immediately and impossible to declare away. `probation_days` grace for a fresh version.
- **The escalation ladder, minimal form:** a `failing` verdict demotes to `BUILTIN` at once, blacklists that version, and promotes the best-fit eligible starter strategy (untried this crisis, not a fingerprint sibling of the failure, declared goals closest to the current situation's demand) within a budget of `library_attempts`; once spent, the LLM is asked with the **failure dossier** (every failed source, its scorecards, the floors breached, and `BUILTIN`'s numbers over the same days) and a returned rehash is rejected by fingerprint. `BUILTIN` plays throughout; the attempt ledger is journaled, so a save/load and a replay make the same choices.
- `BUILTIN` stays selectable and is the fallback: no key, an unloadable file, or every candidate version rejected → the nest plays on its own algorithm and the queen panel says so.
- The version journal `{source, author_mode, tick, change_note}`; autosave before applying a new version.
- `LLM` mode: report assembly (state + metrics + fired branches), async `HTTPRequest`, minimum real-time interval; providers Gemini 3.1 Pro and `MOCK` (program from file); revision triggers — first night, "more than three deaths since dawn", `request_revision`.
- Queen panel: current program with fired-branch highlighting, last policy and explanation, version history.

**DoD:** the concept's loop criterion — a program from Gemini arrives in under ten seconds and **visibly changes behaviour** (after losses, more guards at gaps; short on space, an earlier wider ring), and the four shipped strategies visibly differ from each other and from `BUILTIN` on the same seed; a deliberately broken version is rejected and a deliberately looping `plan()` is interrupted without stalling a tick — the nest keeps its previous strategy either way; a saved run replays with the journaled programs, no new model calls.

**Tests:** runner contract; sandbox escape attempts (`os`, `io`, `require`, `load`, `_G` tricks) blocked; the instruction limit fires; dry-run failure → previous version stays; policy and `goals` bounds, including a declaration laxer than a floor being clamped; situation classification from fixture states, including hysteresis suppressing a one-day flip and an observer pin overriding it; coverage normalization (a vector of ones becomes six equal sixths) and the fit dot product picking `forager` in a famine and `fortress` in a siege; a zero-coverage goal not held against a strategy while its floor still is; scorecard verdicts from fixture days; a deliberately bad strategy demoted to `BUILTIN` within a day with the nest surviving; siblings skipped without consuming budget and a rehashed answer rejected by fingerprint; the attempt ledger surviving save/load; `MOCK` end-to-end (dossier → program → apply); journal replay determinism. No paid calls in tests.

### v0.6 — Inspector, interventions, event log

**Goal:** the observer's eyes and hands; the prototype complete.

**Tasks:**
- Click inspector: myrmek/spider (role, state, energy, hp, task, path drawn on the map), cell (all layers).
- Interventions: place food (amount), release a spider — applied as commands at tick boundaries.
- Event log (deaths, patch depleted, spider killed, spider inside, gap opened/closed, new ring); statistics panel (population, food, deaths by cause).

**DoD:** all three prototype evaluation criteria are assessable: graphics at both zooms with 40 myrmeks at 16x, ≥50% first-night survival without the LLM, and the visible Gemini behaviour change.

**Tests:** interventions are journaled commands (determinism preserved); inspector reads match sim state; events fire once each.

## v1 — The full nest

Scale the prototype to the full simulation: the big chunked world with an active zone, six specialized roles with cargo handover, the full predator ecology and defence strategies, paving and roads, the full strategy surface with a library and arena, and the complete observer surface with rotating saves. Default population 100 + the queen (15/20/15/30/20). Depends on: v0.

### v1.1 — Big world: chunks and the active zone

**Goal:** 2048x2048 without simulating 4 million sleeping cells.

**Tasks:**
- 64x64 chunks with active flags, agent/object lists, changed flags; the active zone (radius 200 + known/occupied chunks); spawning and regeneration gated to it.
- World size as a generation parameter (256–2048, multiple of 64); minimap block scaling (world/256 cells per pixel).
- Distance field goes incremental (recompute on reveal/structure change, full rebuild every ~100 ticks); memory within ~30 MB per nest at 2048.

**DoD:** a 2048 world runs at 16x with 100 myrmeks without frame drops; sleeping chunks wake as scouts reach them; small worlds still generate for tests.

**Tests:** spawn gating to the active zone; incremental distance field ≡ full rebuild; chunk wake/sleep transitions; memory sanity at 2048.

### v1.2 — Six roles and cargo handover

**Goal:** the full division of labour.

**Tasks:**
- Split the worker: scout (vision 5, sector assignment on the frontier), carrier (2 units; `FETCH_FOOD`/`FETCH_PILE`/`DELIVER_RES`/`FEED_MYRMEK`), harvester (3 units, mines 1/5 ticks, piles near the patch when carriers are assigned).
- Cargo handover between adjacent nest-mates; feeding hungry myrmeks in the field; role mix from `roles.tres`.
- Full task-type set on the board; task cancellation and reassignment polish.

**DoD:** the economy flows through piles and handovers; a hungry scout far from home gets fed by a dispatched carrier; role counts are config.

**Tests:** handover conservation (units never duplicated/lost); pile lifecycle; `FEED_MYRMEK` end-to-end; scout sector spreading.

### v1.3 — Predator ecology and defence strategies

**Goal:** three species and guards with doctrine.

**Tasks:**
- Beetle (slow tank) and lizard (chaser; night extra step every 2nd tick; flees under 30% hp); per-species target counts; predator energy lifecycle.
- Guard tasks `ESCORT` (accompany carrier/harvester groups) and `GUARD_SITE` (patch, food source, road section).
- Defence-strategy weights in the policy: patrol / gaps / escort / sites — expressible as "fortress", "convoy", "outposts", or adaptive mixes.

**DoD:** the three species create distinct pressure (ambush, siege-proof tank, night chases); shifting defence weights visibly redeploys guards and changes where deaths happen.

**Tests:** species state machines and night rules; escort binding to groups; weight-driven distribution; carcass values per species.

### v1.4 — Paving and roads

**Goal:** infrastructure that grows out of traffic.

**Tasks:**
- `PAVEMENT`: build/demolish like walls (1 resource, returned), `move_cooldown` ÷ `pave_speed`, reduced step energy; walls may replace paving.
- Decaying per-cell traffic counters on known cells; threshold `pave_traffic` → `PAVE` tasks queued after walls and storages.
- Weighted pathfinding already prices paving; predators gain nothing.

**DoD:** roads emerge along real routes to living patches and rich food areas and are not built to depleted ones; travel on them is measurably faster and cheaper.

**Tests:** traffic decay and thresholding; pave queue ordering; field weights; no predator speedup.

### v1.5 — The full StateView, the library, and the arena

**Goal:** the full strategy surface and comparable strategies (the sandboxed Lua runner itself ships in v0.5).

**Tasks:**
- The full `StateView` (ARCHITECTURE §Contracts) and the full policy schema; the LLM's API description extended to match.
- **The full escalation ladder** over the library: candidates ranked **per situation** by arena results rather than by file order — the arena reports which program wins in a famine and which in a siege, and the ladder picks accordingly — fingerprints computed for every stored program, and blacklisting with earned rehabilitation after `blacklist_days` sim-days (a rehabilitated version re-enters on probation; a second failure blacklists it for the run).
- The **scorecard becomes the arena's scoring function**, so the live game, the arena and the model all rank strategies by the same numbers; arena results are reported per situation as well as overall.
- Strategy library (`user://strategies/`): names, versions, revision history; load as `PROGRAM`; save-to-library from the queen panel.
- The arena (`res://tools/run_arena.gd`): the *strategies × seeds* matrix — with `BUILTIN` as the zero-point entry — run **sequentially in one headless process**, each cell a fresh world from its own seed; one results table per run under `user://arena/<run_id>/` (per cell: survival, days, deaths by cause, food, capacity growth, ticks) plus a summary ranking.
- Providers: OpenAI-compatible, Anthropic, Ollama alongside Gemini and `MOCK`; keys in local config outside the repo.

**DoD:** the full `StateView` and policy surface are pinned by contract tests; the arena ranks a set of strategies on identical seeds, and re-running the same strategy list and seed list reproduces the table exactly.

**Tests:** golden `StateView` fixtures → expected policies; full policy schema bounds; arena reproducibility (the same matrix twice → an identical table); provider abstraction against mocks.

### v1.6 — The full observer surface and saves

**Goal:** everything the observer was promised; v1 complete.

**Tasks:**
- Parameters panel with live sliders (food frequency, night multipliers, energy costs, policy weights, predator targets) plus `queen_brain` and provider switches.
- All interventions: place food, create a patch, summon any predator, delete object/agent, heal, reveal an area — all journaled commands.
- Full inspector; statistics with charts over the last N days; complete event log.
- Save system: rotation (last 3 autosaves + one per day), the saved-days list with rollback, optional named slots (F5), background-thread writes with temp-and-rename, resume-on-launch, "new world" as the deliberate alternative.
- Graphics polish: zooms 8/16/32/48, terrain-set autotiling (shores, rock edges, walls, paving), `PointLight2D` at the gap, cargo sprites.

**DoD:** a full nest per this specification is observable, steerable, and tunable end to end; autosaves rotate and any saved day restores; the sim still runs and tests still pass headless.

**Tests:** rotation policy; threaded save integrity (kill mid-write → previous save intact); intervention command journal; slider changes take effect without restarts.

## v2 — Births

The nest becomes self-sustaining. Depends on: v1.

### v2.1 — The queen gives birth

**Goal:** population becomes a strategic resource.

**Tasks:**
- Birth rule each planning cycle: queen energy ≥ 70 and storage above the reserve → consume 1 food, birth `N_birth` (default 3) myrmeks of the most deficient role.
- Desired role mix computed from needs (large frontier → scouts, spotted predators → guards, long build queue → builders, much known food → carriers) and exposed as a policy field for strategies to override.
- Births in the event log and statistics; capacity pressure feeds the expansion plan.

**DoD:** a healthy nest replaces losses and grows toward its desired mix; a starving nest stops birthing; strategies can steer the mix.

**Tests:** birth conditions and role selection; policy override; capacity interaction; determinism with births on.

## v3 — Replay

Any run reproducible from almost nothing. Depends on: v1 (uses the v1.6 command journal); composes with v2.

### v3.1 — The intervention journal and replay

**Goal:** replay a whole run from seed + journal, no full-state saves needed.

**Tasks:**
- Persist the observer-command journal (tick-stamped) and the strategy-version journal alongside the seed and parameters.
- Replay mode: re-simulate from the start applying journaled commands and programs at their ticks; verification against saved state hashes.
- UI: load-replay, jump-to-day via the nearest autosave + fast-forward.

**DoD:** a multi-day run with interventions and LLM revisions replays bit-identically from seed + journals alone.

**Tests:** replay hash equality; journal completeness (every mutation source is either sim-deterministic or journaled); autosave + fast-forward equivalence.

## v4 — Server and clients

The simulation moves to a headless Linux server and runs continuously; clients only watch and intervene. One project, three exports. Depends on: v1 (v2–v3 recommended first).

### v4.1 — The headless server and protocol

**Goal:** the sim behind a socket.

**Tasks:**
- Server main scene (`godot --headless --server`): the tick loop, `WebSocketMultiplayerPeer`, client commands applied at tick boundaries and journaled, LLM calls and autosaves server-side.
- Protocol (`res://net/`): connection snapshot (clock, parameters, policy, nest state, known mask, known chunks' terrain/structures, objects/agents, stats — 100–500 KB compressed); camera-area deltas up to `net_rate`/s (position/direction/state/cargo/hp, ~12 B/agent); sparse global changes; minimap block deltas; per-second stats/queen updates.
- Versioned chunks and packets; gap detection → snapshot resync; binary `PackedByteArray` messages, compressed above 1 KB.

**DoD:** a client connects, receives a snapshot, and tracks a running sim through deltas; a missed packet recovers via resync; several clients watch one sim.

**Tests:** snapshot/delta round-trip; version-gap resync; command journaling; bandwidth within budget (~20 KB/s at 100 myrmeks, one viewer).

### v4.2 — Web and macOS clients

**Goal:** watch from a browser, an iPad, or the Mac app.

**Tasks:**
- Client main scene: connection panel (address, token, status, latency), local copy of visible state, camera-driven chunk requests, agent interpolation between packets, auto-reconnect with fresh snapshot.
- Web export (COOP/COEP-ready) and native macOS export from the same project; interventions, time control, parameter changes, save list — all as commands.

**DoD:** the web client runs the full observer experience on Mac/iPad/phone; disconnect/reconnect is seamless; the native client matches.

**Tests:** client-side state convergence (client copy ≡ server region); reconnect flow; command round-trips.

### v4.3 — Deployment

**Goal:** the nest lives at home, around the clock.

**Tasks:**
- systemd service or Docker image of the headless export; Caddy/nginx in front serving the web client, terminating TLS (`wss://`), adding COOP/COEP.
- One shared access token in server config; external access via tunnel or VPN; LLM keys server-side only; saves server-side with the same rotation.

**DoD:** the server survives reboots, runs continuously for days, autosaves, and serves the web client to the close circle securely.

**Tests:** token rejection; restart-resume; long-run stability smoke.

## v5 — Nests at war

Everything is already keyed by `nest_id`; now there are several. Depends on: v2 (births) and v4 (per-nest observers).

### v5.1 — Multiple nests

**Goal:** neighbours, then enemies.

**Tasks:**
- Several nests with separate knowledge masks, storages, structures, task boards, and strategies; hostility model; myrmek-vs-myrmek combat; food theft; territory; siege — enemy builders demolish foreign walls.
- Per-nest observers over v4: each client bound to one nest's fog of war with intervention rights over it alone; minimap in nest colours.

**DoD:** two nests compete for the same patches, raid, besiege, and can destroy each other; each observer sees only their nest's world.

**Tests:** knowledge isolation between nests; combat and theft rules; per-observer authorization; determinism with N nests.

### v5.2 — LLM queens and diplomacy

**Goal:** different minds behind different walls.

**Tasks:**
- Per-nest `queen_brain` with its own provider/model/persona; a shared diplomacy channel (truce, trade, threats) that flows through the journal like everything else.
- Arena extended to nest-vs-nest matches on identical worlds.

**DoD:** two model-driven nests behave distinguishably; diplomacy messages are journaled and replayable; arena tables compare queen setups.

**Tests:** persona/provider isolation; diplomacy journaling and replay; nest-vs-nest arena determinism.

## v6 — Evolution and the genome

Selection at both levels: bodies and strategies. Depends on: v2 (births), v5 (multiple nests for nest-level selection).

### v6.1 — Evolution of myrmeks

**Goal:** traits under selection.

**Tasks:**
- Heritable traits (speed, vision, attack, energy efficiency, carry capacity) with mutation at birth; selection through survival and food contribution; trait statistics over generations.

**DoD:** trait distributions drift measurably under environmental pressure across generations.

**Tests:** mutation bounds; inheritance; deterministic evolution under a seed.

### v6.2 — The program as a genome

**Goal:** strategies that learn from lived results.

**Tasks:**
- Revision-by-metrics with long memory: version history with per-day results (deaths by cause, food, safe nights, capacity growth) fed to the LLM so failed ideas are not retried.
- Arena selection: programs raced on identical seeds; survivors stay in the library; the model writes new candidates from program–result pairs (mutation and crossover with meaning).
- `LEARNED` mode: a small NN tunes the program's numeric parameters (weights, thresholds, radii) or picks a library program by state; on low confidence (ensemble disagreement, novel state) it asks the LLM and remembers the answer. Strategy only — tactics stay algorithmic.

**DoD:** across arena generations, average nest outcomes improve without human edits; `LEARNED` beats static `PROGRAM` baselines on held-out seeds.

**Tests:** metric aggregation; selection loop; `LEARNED` confidence gating; no LLM calls below the interval or in CI.

### v6.3 — Swarming

**Goal:** nests that reproduce.

**Tasks:**
- A sated queen births a daughter queen who leaves with an escort, picks a site from her mother's known map (carried at departure), and births her own `nest_id` brood.
- Kinship: a `kin_timer` during which the parent nest treats the daughter's brood as its own (no attacks, gap passage, limited food rights); expiry → ordinary foreign nest.
- The daughter inherits the mother's genome (strategy program + tuned parameters + traits) with mutation.

**DoD:** a thriving nest splits; kin become strangers on schedule; sibling nests diverge behaviourally from mutated genomes — nest-level selection closes the loop.

**Tests:** kinship table and timer transitions; inheritance with mutation; site selection from the carried map; determinism through a split.

---

**Later (unscheduled):** maximum myrmek age, "last known state" memory instead of live vision on known cells, digging, weather, food spoilage, sound.

---

## History of changes

**v1.5 (27.09.2026)** — v0.5 restated around the closed six-goal list: coverage vectors normalized to sum to 1, per-goal expectations derived from coverage, fit as the demand·coverage dot product, and the scorecard verdict weighted by the current demand, with tests for normalization, fit and zero-coverage goals.

**v1.4 (27.09.2026)** — the situation classifier added to v0.5 (`FOUNDING`/`SIEGE`/`FAMINE`/`STABLE` with hysteresis, `s.situation`, the observer pin, `CROWDED` deferred to v1.4) with its tests, candidate promotion changed to best fit against the situation's demand, and v1.5's arena extended to rank strategies **per situation** so the full ladder picks by situation rather than a single global order.

**v1.3 (27.09.2026)** — the program-free mode and strategy judging spelled out across the phases: v0.3's task board named as `queen_brain = BUILTIN`, v0.4's DoD restated as the `BUILTIN` zero point, v0.5 gaining the shipped starter strategies, declared `goals` with the dawn scorecard and the minimal escalation ladder (budget, sibling skipping, failure dossier, rejected rehashes) plus tests for all of it, and v1.5 gaining the full ladder over a ranked library with rehabilitation and the scorecard as the arena's scoring function.

**v1.2 (27.09.2026)** — v1.5's arena task specified per the decided execution model: a sequential single-process matrix in `res://tools/run_arena.gd`, one results table per run under `user://arena/<run_id>/`, with table reproducibility in the DoD and tests.

**v1.1 (27.09.2026)** — decisions folded in: strategies are sandboxed Lua 5.4 from the prototype — v0.5 rewritten around godot-luaAPI (sandbox, instruction limit, dry run) and v1.5 renamed to "The full StateView, the library, and the arena" with the GDScript↔Lua parity tests dropped (intro, v1 intro, v0.5, v1.5); gdUnit4 and `scripts/test.sh` pinned in v0.1; named RNG streams in v0.1; fixed-point energy in v0.3.

**v1.0 (27.09.2026)** — initial version, derived from the retired concept v0.20 ([history/](history/)); the concept's v1.1 births / v1.2 replay / v1.3 server / v2 ideas renumbered as v2 / v3 / v4 / v5–v6.
