# Design Brief — Myrmex v0 Prototype Interface

Document version 2.0 — 27 September 2026.

A self-contained brief for a Claude Design session: mock up **exactly what the v0 prototype's interface will look like** — nothing from later versions. Companion to the canonical [design_handoff_myrmex_ui/DESIGN_BRIEF.md](design_handoff_myrmex_ui/DESIGN_BRIEF.md) (v2.0); where they disagree, the v0 rules here win for these mockups. Shape references: `design_handoff_myrmex_ui/sprites/`, scenes and `myrmex-art.js`.

---

## The game in two sentences

Myrmex is a deterministic hive simulation: ~40 ant-like **myrmeks** (plus the **brood mother**) survive their first nights in a 256×256 cell world — gathering food, mining ore, raising a ridge of fleshy wall, holding its gap against the **lurker**. The player only **observes and meddles** (drops food, releases the lurker); the brood mother runs everything, and her strategy is a small Lua program shown live in her panel.

## Style, in one paragraph

**2:1 isometric, hand-painted, living hive.** The data grid is square; the picture is a 128×64 screen diamond per cell, depth-sorted by `x+y`. **No boxes** — highland is jagged crags, the nest wall a run of fleshy mounds with bone spines, storages are a translucent digestive sac and a ribbed bone hollow; volume comes from a lit and a dark facet plus a soft cast shadow. Creatures are one **living-hive** species (chitin over muscle, bone scythes, amber eyes — our own silhouettes, nobody else's): a parametric rig projected into **eight headings** (five painted, three mirrored), roles as **colour passes**, never runtime tints. The ground is one continuous painted surface — four biome tints blended by seeded noise, no visible cell seams — dressed by the decor set incl. passable **trees** (canopy fades to ~40% over an agent). Night is a full-screen tint; **no gap light in v0**, no torches, no glowing eyes. HUD: dark bevelled panels with a clay trim over the bright world; IBM Plex Sans / IBM Plex Mono; text contrast ≥ 4.5:1.

## v0 palette (finals from the handoff)

| | | | |
|---|---|---|---|
| Ground base `#6E8C4E` | dry `#86924E` | lush `#587E40` | dust `#7A8A54` |
| Water `#3F739F` (deep +`#0B2540`@30%) | Highland crags `#7E7568` | Rock `#8A8478` | Dirt trail — **not in v0** |
| Nest ridge `#6B3557` | Creep floor `#4A2440` | Flesh `#8E3A5C` / hl `#C2567A` | Bone `#E2D6B8` · eye `#F2B233` |
| Digestive sac `#9A4A72` (yolk `#D9A441`) | Bone hollow `#5E3A52` | Brood dome `#7A3A6A` | Food `#E8C84A` · ore `#8A5A3C` (+glow `#E07A4A`) · pile `#7A4E33` |
| **Worker `#D9D2B4`** | **Builder `#C9A227`** | **Guard `#4A6FA5`** | **Brood mother `#B65C8F` + gold `#E8C84A`** |
| **Lurker `#5A4A66`** | Tree canopy `#5F8A45` · trunk `#6B4A32` | | |

Minimap (1 px/cell, priority left→right): unknown `#141413` → predator `#D64545` → myrmek `#F2EFE9` → food `#E8C84A` → ore `#8A5A3C` → nest `#7A3A6A` → creep `#3E2244` → water `#5D8FB8` → highland `#6E6A62` → rock `#9A958D` → ground by biome (base `#4E6B3A`, dry `#5E7040`, lush `#456334`, dust `#587046`). Viewport rect `#FAF9F5` 1 px.

Day-phase overlays over identical art: day none · dusk `#7A5A8C`@30% · night `#1A2340`@55% · dawn `#D9924A`@22%.

UI chrome: panel gradient `#2E2C27→#1A1916` with clay trim `#C97B4A` · raised `#3A3833→#26251F` · well `#12110F` · text `#FAF9F5` · dim `#B8B2A6` · accent `#D97757` · ok `#7FA85C` · warn `#D9A441` · danger `#D64545`.

## What is on the v0 screen — the complete list

Design at **1440×900**, world at 32 px/cell in isometric projection. The HUD is exactly this and nothing more:

- **Top-left — clock chip:** `Day 2` 20/600 · `tick 0512` mono dim · four-segment phase pip (day·dusk·night·dawn) · caption `DAY · 458 TO DUSK`.
- **Top-right — statistics strip:** population as three tinted dots with counts (worker 22 · builder 8 · guard 10) and a bold total, food store value + bar with the reserve tick, deaths today. No charts in v0.
- **Bottom-left — minimap:** 256×256 well (1 px per cell — the minimap stays **square**: it is a data view, not a projected one), viewport rectangle, click-to-move. No "true map" toggle in v0.
- **Bottom-centre — time cluster:** pause · 1× · 4× · 16× · single-step (44 px targets) + `● saved · day 2`. **No save button.**
- **Right rail (320 px):** tabs **Queen | Tools**; Tools = two rows only (**place food** `F`, **release lurker** `S`); the inspector docks below on click, with a 64 px portrait well (selected creature facing SE).
- **Bottom-right — event log:** last 3 mono lines, expandable: `myrmek starved · worker`, `lurker slain at the gap`, `lurker inside!`, `ore vein depleted`, `gap sealed for the night`, `new ridge begun`.

Not in v0 (do not draw): parameters panel, charts, true-map toggle, gap light, dirt trails, creep roads, tusk brute, winged shade, six roles, named saves.

## The queen panel (v0 form)

Header: brood-mother glyph (magenta disc, gold inner ring) + "Queen"; segmented mode control `BUILTIN / PROGRAM / LLM` (show `LLM` active). Code well (mono, line numbers): ~20 lines of Lua with **two fired branches highlighted** (row tint + gutter dot). Policy readout — exactly six fields: `weight_food 2.0 · guards_at_gaps 0.8 · seal_at_night on · ring_radius 5 · workers_harvest_share 0.2 · build_priority ring`. Version history (3 rows, current marked, change notes). One button: `Revise now`. **No health, no reproduction, no eggs.**

## The inspector (v0 form)

- **Myrmek:** role dot + name + mono id/coords, state caption; portrait well beside a small iso scene crop showing the selection ellipse, dashed path and target marker; energy bar with ticks at 40 (`rest`) and 15 (`starve`); HP / Task / Cargo / Path rows.
- **Cell:** header `(127,121)` + `GAP · NORTH` caption; scene crop with the **cell diamond** outline; five layer rows — terrain / structure / object / agent / known.

## Artboards to produce

1. **Screen — day** (1440×900, 32 px/cell iso): the fleshy ridge ring with one open gap, a guard in the gap, workers hauling (cargo sphere in the scythes), a builder at a ghost wall-mound, the brood dome with the brood mother one cell south, sac + hollow inside, a highland massif and a pond in view, full HUD.
2. **Screen — first night** (same scene): night tint 55%, the gap **sealed** (ghost→solid), the lurker prowling outside, two stragglers by the ridge with a guard, event log `gap sealed for the night`. **No gap light.** The hero shot.
3. **Queen panel — expanded** (~420×900) as specified.
4. **Inspector — both variants** (~480 wide): myrmek with path; cell layers.
5. **v0 sprite sheet** (~1400×900): ground ×4 tints · water shore/deep · rock · highland (interior/edge/outcrop) · ridge run/corner/end + ghost · digestive sac 0/⅓/⅔/full · bone hollow 0/½/full · brood dome · food 1/3/5 · ore rich/depleted · pile 1/3 · **myrmek 8 headings** in three role passes + cargo · brood mother · lurker (ambush/lunge/eating) · selection ellipse + cell diamond · path/target · decor ×14 incl. tree — on day and night ground, 32 px and a 16 px strip.
6. **Minimap close-up** (256 shown at 2×): known blob, unknown black, red lurker dot, bone-white myrmek specks, biome tones, viewport rect.

## Anti-patterns — do not draw

Cubes / extruded tiles / boxy cliffs · plan-view (top-down) creatures · visible tile seams or per-cell colour jitter · a tamagotchi queen panel (health/eggs) · dig, build or terraform tools · HP bars on walls · torches, lanterns, glowing eyes at night · manual save buttons · gap light (v1.6) · dirt trails and creep roads (v1.4+) · Blizzard silhouettes (inspiration only).

## Acceptance

Worker/builder/guard separate at 16 px on both day and night ground (lightness ladder, not hue alone); every silhouette unique at 16 px; sac and hollow fill states legible; wall ridge ≠ highland ≠ rock at a glance; the night shot legible under the tint; HUD text ≥ 4.5:1; the world reads as one painted place, and the HUD stays calm — the hive is the hero.

---

## History of changes

**v2.0 (27.09.2026)** — rewritten to the handoff v2.0 language: isometric 2:1 presentation, hand-painted no-boxes style, living-hive palette finals and display names (myrmek kept; brood mother, lurker), highland/creep/biome ground, eight-heading creatures, IBM Plex HUD recipe, updated artboards and anti-patterns. v0 exclusions extended with dirt trails and creep roads.

**v1.3 (27.09.2026)** — projection flipped to the ¾ RTS view; the anti-pattern excluded diamond isometric and true 3D.

**v1.2 (27.09.2026)** — added the decor set to the sprite sheet and the day screen; flora anti-pattern narrowed to obstacle-scale.

**v1.1 (27.09.2026)** — pinned pure top-down and added the anti-patterns list.

**v1.0 (27.09.2026)** — initial self-contained v0-only brief.
