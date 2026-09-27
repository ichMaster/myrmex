# Design Brief — Myrmex UI Mockups

Document version 1.2 — 27 September 2026.

The brief and full specification for mocking up the observer interface and the complete object set in the Claude Design app. Derived from [VISION.md](VISION.md) §The look, [ARCHITECTURE.md](ARCHITECTURE.md) (§Agents, §Nest, §Observability, §What v0 implements) and [ROADMAP.md](ROADMAP.md) (v0.2, v0.6, v1.6) — those three remain the source of truth; if this brief disagrees with them, they win.

**Workspace:** the Design canvas [Myrmex UI Mockups](https://claude.ai/artifact/Aiygb5QTuVC6wpdL5WEwqp) (private; the brief board is already on it). Design mockups as new artboards beside it.

---

## 1. Purpose and scope

Produce mockups for:

1. **The sprite set** — every world object (section 5): terrain, structures, items, one myrmek silhouette with role tints, the queen, three predators. Master size 128 px per cell.
2. **The observer screen** — world view plus HUD (section 6), in day and night variants.
3. **The panels** — queen panel, inspector, time/save cluster, intervention tools; the parameters panel in v1 form (section 7).

**Scope order: v0 first.** The prototype has 3 roles (worker · builder · guard), the spider only, zooms 16/32 px, two interventions, one autosave file. v1 adds 6 roles, beetle + lizard, zooms 8–48, paving and roads, the full tool set and the live parameters panel. Everything below carries a v0/v1 badge where it differs.

## 2. Style pillars

- **Pure top-down.** The camera looks straight down — **no isometric, no StarCraft-style ¾ pseudo-3D**, no elevation on walls or rocks: depth reads through shape, tint and a soft drop shadow, never through perspective. This is structural, not taste: agents are one sprite **rotated toward heading** (¾ view would demand directional frame sets), sprites fit their cells with no y-sorting, and the asset budget stays ~20 SVGs.
- **"The logic is cellular; the picture is free."** Vector: simple shapes, soft gradients and shadows. Deliberately **no pixel-art**, no outline-only line art.
- **One silhouette, many tints.** A single myrmek shape for every role; role, day phase and state are **color** (engine `modulate` tint), never separate assets. Sprites are drawn **white/grey wherever color varies**.
- **Sharp at every zoom.** SVG sources rasterized at 128 px/cell with mipmaps; art must read from 8 to 48 px per cell on screen.
- **Night is a tone, not new art.** One full-screen tint per day phase plus a single warm light at the nest gap. Movement is interpolated and myrmeks rotate toward their heading — shapes must tolerate rotation (no baked-in ground shadow direction).

### Hard constraints

- Role tints distinguishable at **16 px per cell**, and not by hue alone — lightness must differ too (color-blind safe: prefer blue/orange oppositions to red/green).
- One agent per cell: a myrmek fits inside its cell (~0.8 cell); predators are visually **1.5–2 cells**; the queen is clearly larger than a worker but stationary.
- The whole set stays hand-drawable: **~20 SVGs** total.
- HUD text contrast ≥ 4.5:1; icons are drawn strokes, never emoji; touch targets ≥ 44 px (the web client arrives in v4).
- A gap in the wall is **ordinary ground** — it must read as an opening in the ring, not as a special "door" object.

### Anti-patterns (from early AI mockups — do not repeat)

- **Pseudo-3D / ¾ RTS perspective** — tall rocks, domed nests, wall elevation. Top-down only.
- **Trees, bushes, decorative flora** — the terrain is ground, water and rock; nothing else exists.
- **A tamagotchi queen panel** (health / reproduction / "laying eggs") — the queen panel is the mode chip, the Lua program with fired branches, the policy readout and the version history. Births don't exist before v2.
- **Dig / build / terraform tools** — the observer never digs or builds; interventions act on the world (food, predators), never on structures.
- **HP on walls** — walls have no hit points; builders demolish them in time, nothing "damages" them before v5.
- **Torches, lanterns, glowing eyes at night** — night is one full-screen tint; even v1.6 adds only a single warm light per gap.
- **Manual save buttons** — saving is automatic; the UI shows only "saved · day N" (named slots are a v1.6 option).

## 3. Audience and platform

A single observer on **macOS desktop** (native Godot app, design at 1440×900 and up); web on Mac/iPad/phone in v4 — keep the HUD edge-anchored and scale-friendly. Sessions are long and ambient: the UI should be calm, legible from across the room, and quiet when nothing happens. UI chrome is dark over a bright world so the world stays the hero.

## 4. Color language

Starting proposal — refine in mockups, then write the finals back into this file. All object colors are **engine tints over white/grey art**.

### Terrain, structures, items

| Element | Hex | Notes |
|---|---|---|
| Ground | `#93B072` | calm green; night variants come from the overlay, not new art |
| Water | `#5D8FB8` | impassable |
| Rock | `#9A958D` | impassable; must contrast with nest wall |
| Nest wall | `#C97B4A` | warm clay — the nest's signature color |
| Pavement | `#D9C9A8` | v1; reads as "road" against ground |
| Storage — food | `#D9A441` | shows fill 0–20 units |
| Storage — resources | `#9C6B45` | shows fill 0–20 units |
| Queen chamber | `#A86B9E` | one cell, unique |
| Food item | `#E8C84A` | 1–5 units → size steps |
| Resource patch | `#8A5A3C` | 3–12 cells share one look |
| Pile | `#7A4E33` | dropped units awaiting a carrier |

### Myrmek role tints (one white silhouette)

| Role | Hex | Badge |
|---|---|---|
| Worker | `#85A363` | v0 |
| Builder | `#C9A227` | v0 |
| Guard | `#4A6FA5` | v0 |
| Scout | `#64B5D9` | v1 |
| Carrier | `#7FA85C` | v1 |
| Harvester | `#B5764A` | v1 |
| Queen | `#B65C8F` + gold accent `#E8C84A` | v0 |

### Predators

Spider `#5A4A66` (v0) · Beetle `#4A5240` (v1) · Lizard `#A3B052` (v1). On the minimap all predators are red.

### Minimap palette (priority order — leftmost wins within a block)

`1 unknown #141413` → `2 predator #D64545` → `3 myrmek #F2EFE9` → `4 food #E8C84A` → `5 resource #8A5A3C` → `6 nest #C97B4A` → `7 paving #D9C9A8` (v1) → `8 water #5D8FB8` → `9 rock #9A958D` → `10 ground #4E6B3A` (darker than terrain ground for 1-px readability).

### Day-phase overlays (full-screen tint over identical art)

| Phase | Ticks | Overlay |
|---|---|---|
| Day | 600 | none |
| Dusk | 60 | `#7A5A8C` @ 30% |
| Night | 400 | `#1A2340` @ 55% + gap light `#FFD9A0` (radial, one per gap — v1; the prototype has the tint only) |
| Dawn | 60 | `#D9924A` @ 22% |

### UI chrome

Panel `#201F1C` · raised `#2A2926` · text `#FAF9F5` · dim text `#B8B2A6` · accent `#D97757` · ok `#7FA85C` · warn `#D9A441` · danger `#D64545`.

**Rules:** anything that must be told apart differs in lightness, never hue alone; the night overlay may not push role tints below distinguishability at 16 px — verify on the States board.

## 5. Object and sprite inventory (~20 SVGs)

Master cell = 128 px. "Size" is in cells.

| # | Sprite | Badge | Size | Base color | States / variants | Notes |
|---|---|---|---|---|---|---|
| 1 | Ground tile | v0 | 1 | tintable grey | — | v1 adds terrain-set edges |
| 2 | Water tile | v0 | 1 | tint | v1: shore edges | impassable |
| 3 | Rock tile | v0 | 1 | tint | v1: cluster edges | impassable |
| 4 | Nest wall | v0 | 1 | tint | v1: autotile ring corners | under construction = ghost at 50% |
| 5 | Pavement | v1 | 1 | tint | edge trim | roads outside, floors inside |
| 6 | Storage — food | v0 | 1 | tint | fill 0 / ⅓ / ⅔ / full | readable fill state at 16 px |
| 7 | Storage — resources | v0 | 1 | tint | fill 0–full | distinct shape from food storage |
| 8 | Queen chamber | v0 | 1 | tint | — | placed free under the queen |
| 9 | Food item | v0 | ≤0.6 | tint | sizes for 1–5 units | also the predator carcass form |
| 10 | Resource deposit | v0 | 1 | tint | rich / depleted | patch = 3–12 such cells |
| 11 | Pile | v0 | ≤0.6 | tint | 1–3 heap sizes | |
| 12 | **Myrmek** | v0 | ~0.8 | **white** (tinted per role) | rotates to heading | one silhouette for all roles |
| 13 | Cargo dot | v0 | ~0.25 | food/resource tint | — | rides above a loaded myrmek |
| 14 | Queen | v0 | ~1.4 | tint + gold | — | stationary, unmistakable |
| 15 | Spider | v0 | ~1.5 | tint | idle-ambush / lunge / eating | few AnimatedSprite frames |
| 16 | Beetle | v1 | ~1.8 | tint | walk / attack | bulky tank |
| 17 | Lizard | v1 | ~2.0 long | tint | run / flee | fast, elongated |
| 18 | Selection ring | v0 | 1.2 | UI accent | myrmek / cell variants | inspector target |
| 19 | Path line + target marker | v0 | — | UI accent | — | drawn for the inspected myrmek |
| 20 | Gap light | v1 | ~2 radial | `#FFD9A0` | night only | warm glow at each open gap (`PointLight2D`, v1.6 — not in the prototype) |

## 6. Observer screen anatomy (design at 1440×900)

World view fills the frame; HUD is edge-anchored, dark chrome:

- **Top-left:** day counter + tick, day-phase indicator (four-segment pip: day/dusk/night/dawn).
- **Top-right:** statistics strip — population (by role, tinted dots), food store vs reserve, deaths today. v1: opens the charts panel.
- **Bottom-left:** minimap 256×256 (v0: 1 px/cell for 256²) with viewport rectangle, click-to-move; v1: "true map" toggle.
- **Bottom-center:** time controls — pause · 1× · 4× · 16× · single step (v1 adds 0.5×–16× ladder); autosave marker "saved: day N".
- **Right rail:** queen panel tab (section 7), intervention tools (v0: place food, release spider; v1: full set — patch, any predator, delete, heal, reveal), inspector docks here on click.
- **Bottom-right:** event log — last 3 lines, expandable (deaths, patch depleted, predator killed / inside, gap opened/closed, new ring).

**Required mockups:** day state and night state (sealed gaps + gap lights + dimmed world) of the same scene — mid-first-night with a spider at the gap is the hero moment.

## 7. Panels anatomy

- **Queen panel:** mode chip (`BUILTIN` / `PROGRAM` / `LLM`), current program (Lua, monospace) with **fired-branch highlighting** from the last cycle, current policy readout (6 fields in v0), version history list with change notes; "revise now" and "save to library" buttons. v1.5 adds: situation chip with demand, latest scorecard verdict, promotion/demotion history.
- **Inspector:** myrmek → role (tinted), state, energy bar (0–100 with 40/15 thresholds marked), hp, current task, path drawn on the map; cell → the layer stack (terrain / structure / object / agent / known).
- **Parameters panel (v1):** live sliders grouped — food frequency, night multipliers, energy costs, policy weights, predator targets; `queen_brain` switch + provider select.
- **Time & save cluster:** see section 6; "new world" is a deliberate, separated action.

## 8. States to design

- **Day-phase strip:** the same nest tile scene under all four overlays (hexes in section 4).
- **Zoom ladder:** one nest scene at 8 / 16 / 32 / 48 px per cell (v0 ships 16/32). Readability checklist at 16 px: role tints apart; food dot visible on ground; wall ≠ rock; storage fill state readable.
- **Night seal moment:** gaps walled shut, gap-light off outside glow, myrmeks clustered inside, stragglers by the wall under guard.
- **Markers:** selection ring, path line, unreachable-target absence (no marker — the queen never assigns those), construction ghost.

## 9. Deliverables and acceptance

Deliverables (as canvas artboards):

1. Sprite sheet v0 — items 1–15, 18–19 on light and dark ground, at 32 px and 16 px (item 20, the gap light, joins in v1).
2. Observer screen — day.
3. Observer screen — first night (hero shot).
4. Queen panel — `LLM` mode with fired branches.
5. Inspector — myrmek selected, path visible.
6. Minimap close-up with palette in situ.
7. v1 extension sheet — beetle, lizard, paving/roads, 6 role tints, parameters panel.

Accepted when: pleasant at both v0 zooms (ROADMAP v0.2 DoD); every silhouette unique at 16 px; role tints and fill states readable at 16 px; night variant legible with overlay applied; HUD text ≥ 4.5:1; no pixel-art, no emoji; sprites tint-ready (white/grey masters).

---

## History of changes

**v1.2 (27.09.2026)** — pinned pure top-down projection as the first style pillar (with the structural reasons) and added the Anti-patterns section distilled from an early AI mockup: no pseudo-3D, no flora, no tamagotchi queen panel, no dig/build tools, no wall HP, no torches, no manual save buttons.

**v1.1 (27.09.2026)** — corrected the gap light to v1 (`PointLight2D` arrives in v1.6; the prototype's night is the tint alone) in the inventory, the overlay table and deliverable 1; added the companion prototype brief ([DESIGN_BRIEF_PROTOTYPE.md](DESIGN_BRIEF_PROTOTYPE.md)).

**v1.0 (27.09.2026)** — initial brief: scope and pillars from VISION §The look, the proposed color language (object tints, role tints, minimap priority palette, day-phase overlays, UI chrome), the 20-sprite inventory with sizes and states, observer-screen and panel anatomy per ARCHITECTURE §Observability and ROADMAP v0.2/v0.6/v1.6, the states set, and the deliverables checklist with acceptance criteria.
