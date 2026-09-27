# Design Brief — Myrmex v0 Prototype Interface

Document version 1.2 — 27 September 2026.

A self-contained brief for the Claude Design app: mock up **exactly what the v0 prototype's interface will look like** — nothing from later versions. Companion to [DESIGN_BRIEF.md](DESIGN_BRIEF.md) (the full-system brief); where they disagree, the v0 rules here win for these mockups.

---

## The game in two sentences

Myrmex is a deterministic ant-nest simulation: ~40 ant-like **myrmeks** (plus a queen) survive their first nights in a 256×256 cell world — gathering food, mining resources, walling a nest, holding its gap against a spider. The player only **observes and meddles** (drops food, releases a spider); the queen runs everything, and her strategy is a small Lua program shown live in her panel.

## Style, in one paragraph

Vector, calm, ambient, and **pure top-down** — the camera looks straight down; no isometric or StarCraft-style ¾ pseudo-3D, no elevation on walls or rocks (agents are one sprite rotated toward heading, so perspective would break them). Simple shapes, soft gradients and shadows, **no pixel-art**, no emoji. The world is bright; the HUD is dark, edge-anchored chrome (`#201F1C`, raised `#2A2926`, text `#FAF9F5`, dim `#B8B2A6`, accent `#D97757`, ok `#7FA85C`, danger `#D64545`; text contrast ≥ 4.5:1). One myrmek silhouette for all roles, colored by tint. Flat tiles (no autotile edges in v0), two zooms only: **16 and 32 px per cell**. Night is a full-screen tint — **no gap light in v0**. Icons are drawn strokes.

## v0 palette (engine tints over white/grey art)

| | | | |
|---|---|---|---|
| Ground `#93B072` | Water `#5D8FB8` | Rock `#9A958D` | Nest wall `#C97B4A` |
| Storage-food `#D9A441` | Storage-res `#9C6B45` | Queen chamber `#A86B9E` | Food `#E8C84A` |
| Resource `#8A5A3C` | Pile `#7A4E33` | Spider `#5A4A66` | |
| **Worker `#85A363`** | **Builder `#C9A227`** | **Guard `#4A6FA5`** | **Queen `#B65C8F` + gold** |

Minimap (1 px = 1 cell, priority left→right): unknown `#141413` → spider `#D64545` → myrmek `#F2EFE9` → food `#E8C84A` → resource `#8A5A3C` → nest `#C97B4A` → water `#5D8FB8` → rock `#9A958D` → ground `#4E6B3A`.

Day-phase overlays over identical art: day none · dusk `#7A5A8C` 30% · night `#1A2340` 55% · dawn `#D9924A` 22%.

## What is on the v0 screen — the complete list

Design at **1440×900**. The world view fills the frame; the HUD is exactly this and nothing more:

- **Top-left — clock:** `Day 2 · tick 0512/1120` + a four-segment phase pip (day·dusk·night·dawn, current segment lit).
- **Top-right — stats strip:** population as three tinted dots with counts (worker 22 · builder 8 · guard 10), food store `34`, deaths today `3`. No charts in v0.
- **Bottom-left — minimap:** 256×256 px, 1 px per cell, viewport rectangle, click moves the camera. No "true map" toggle in v0.
- **Bottom-center — time controls:** pause ▸ 1× 4× 16× ▸ single-step; beside them the autosave marker `saved · day 2`.
- **Right rail — three items only:** the queen panel tab, two intervention buttons (**place food**, **release spider**), and the inspector (appears on click).
- **Bottom-right — event log:** last 3 lines, expandable. Real v0 events only: `myrmek starved · worker`, `spider killed at gap`, `spider inside!`, `patch depleted`, `gap closed for the night`, `new ring started`.

Not in v0 (do not draw): parameters panel, charts, true-map toggle, escort/site tools, named save slots, gap light, roads/paving, beetle, lizard.

## The queen panel (v0 form)

Docked right, dark chrome, monospace for code:

- Mode chip: `BUILTIN` / `PROGRAM` / `LLM` (show `LLM` active).
- Current program: ~20 lines of Lua, with **two branches highlighted** (the ones that fired last cycle) — e.g. `if s.predators_within(12) >= 1` and `if s.food_store < s.population * 0.3`.
- Policy readout — exactly the six v0 fields with values: `weight_food 2.0 · guards_at_gaps 0.8 · seal_at_night on · ring_radius 5 · workers_harvest_share 0.2 · build_priority ring`.
- Version history: 3 rows (`v3 · day 2 · "more guards at night after losses" · Gemini`, …), current marked.
- One button: `revise now`.

## The inspector (v0 form)

- **Myrmek clicked:** role chip (tinted) · state (`GO_TO`) · energy bar 0–100 with marks at 40 and 15 · hp · task (`FETCH_FOOD → (141,88)`); its path drawn on the world as a soft accent line with a target marker.
- **Cell clicked:** the layer stack as rows — terrain `GROUND` · structure `NEST_WALL` · object `—` · agent `—` · known `yes`.

## Artboards to produce

1. **Screen — day** (1440×900, 32 px/cell): mid-day economy, the ground dressed by the sparse decor layer — the clay wall ring with one open gap, a guard in the gap, workers hauling food (cargo dots), builder at a half-built wall (ghost at 50%), queen + both storages inside, full HUD as specified.
2. **Screen — first night** (same scene, 16 px/cell): night overlay 55%, the gap **walled shut**, spider `#5A4A66` prowling outside, two stragglers by the wall with a guard, event log showing `gap closed for the night`. This is the hero shot.
3. **Queen panel — expanded** (~420×900) as specified above.
4. **Inspector — both variants** (~380×520 each): myrmek with path visible in a world snippet; cell layers.
5. **v0 sprite mini-sheet** (~1200×800): ground · water · rock · wall (+50% ghost) · storage-food (empty/⅔/full) · storage-res · queen chamber · food ×1/×3/×5 · resource (rich/depleted) · pile · **myrmek** in three role tints + cargo dot · queen · spider (ambush/lunge/eating) · selection ring · path marker · the **decor set** (grass tufts ×2, pebbles, flower, dry patch, moss fleck — render-only ground dressing, ~1 per 5 cells, visibly non-blocking) — each on light and dark ground, at 32 px and a 16 px strip below.
6. **Minimap close-up** (256×256 shown at 2×): the known blob around the nest, unknown black beyond, red spider dot, white myrmek specks, viewport rectangle.

## Anti-patterns — do not draw

Pseudo-3D / ¾ perspective · trees or bushes (obstacle-scale flora; the ground-cover decor set from the sprite list is welcome) · a queen panel with health/reproduction/eggs (it shows the mode chip, the Lua program, the six policy fields, the history) · dig or build tools (interventions are food and the spider only) · HP bars on walls · torches, lanterns or glowing eyes at night (the tint is the night) · manual save buttons (only `saved · day N`).

## Acceptance

Role tints apart at 16 px (they differ in lightness, not hue alone); wall ≠ rock at a glance; storage fill readable at 16 px; the night shot legible under the overlay; every silhouette unique at 16 px; HUD calm and quiet — the world stays the hero.

---

## History of changes

**v1.2 (27.09.2026)** — added the decor set to the sprite sheet and the day screen, and narrowed the flora anti-pattern to obstacle-scale only.

**v1.1 (27.09.2026)** — pinned pure top-down in the style paragraph and added the Anti-patterns list distilled from an early AI mockup.

**v1.0 (27.09.2026)** — initial version: the self-contained v0-only brief — palette subset, the complete v0 HUD list with explicit exclusions, the queen panel and inspector in v0 form, six artboards, acceptance criteria.
