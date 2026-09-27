> **Brief v2.0 supersedes the style rules below where they conflict** — read `DESIGN_BRIEF.md` §2 (isometric presentation, no boxes, painted ground, living-hive creatures via the 3D rig) and §10 (architecture impact) first. Sections here that still apply verbatim: HUD recipe, panels, tokens, interactions, state.

# Handoff: Myrmex — sprite set, observer screen and panels

Design brief v1.4 (27 Sep 2026) → mockups → this package. Target: the Godot native macOS app (v0 prototype first, v1 items badged). Web client is v4.

## Overview
Everything the observer sees in Myrmex: the tint-ready world sprite set (terrain, structures, items, the one myrmek silhouette, queen, predators, markers, ground decor), the observer screen HUD in day and first-night states, the queen panel (LLM mode), the inspector (myrmek + cell), the minimap with its priority palette, the states board (day-phase overlays, zoom ladder, night seal, markers) and the v1 extension sheet (beetle, lizard, paving, six role tints, parameters panel).

## Art pipeline (brief v1.6)
The final art is **hand-painted raster** (PNG sheets, 128 px/cell master). Everything in this package is the composition reference the painter works over: silhouettes, footprints, camera, proportions, colour keys, fill-state encodings. Do NOT ship the SVGs as game art; do use them as the exact placement/size/readability spec and as placeholder sprites until painted ones land. Role tints in the painted set go through a team-colour mask (thorax + abdomen top), not whole-sprite modulate.

## About the design files
The files in this bundle are **design references created in HTML/SVG** — they show intended look and behaviour, they are not production code. Recreate them in the Godot project using its own scene tree, `Sprite2D`/`AnimatedSprite2D` with `modulate` tints, `CanvasModulate` for day phases, `PointLight2D` for the v1.6 gap light, and Godot Control nodes for the HUD. If a web client arrives later (v4), the same sprites and tokens apply.

**Pipeline decision (brief v1.6): shipped art is painted raster.** Everything in `sprites/` and `myrmex-art.js` is the *composition and shape reference* a painter (or generator + cleanup) works from: silhouette, proportions, camera, shadow placement, fill-state logic, palette. Paint at 128 px/cell, export 128/64/32/16 with mipmaps, one PNG per inventory item and state, per-role colour passes for the myrmek (worker / builder / guard in v0). Do not tint painted PNGs with `modulate`.

Two things are meant to be taken literally:
- `sprites/master/*.svg` — the white/grey masters. Import them at 128 px/cell with mipmaps and tint with the hex values below. `sprites/tinted/*.svg` are the same files with the tint baked in, for reference only.
- `myrmex-art.js` — a dependency-free JS module that draws every sprite and the scene. It is the *specification* of shape and shading (read `S.wall`, `S.myrmek`… as drawing instructions); do not ship it.

## Fidelity
**High-fidelity.** Colours, shapes, shading recipe, HUD layout, spacing and copy are final unless noted "proposal". The world data behind the scenes (`world-model.json`) is mock data for the mockup, not a level.

## Style rules (from the brief v1.5, refined by the mockups)
- **StarCraft-1 camera (brief amendment v1.5)**: every sprite is drawn from a high front camera. Creatures: plan silhouette → rotate for heading → `scale(1, 0.72)` about the cell centre → lift 4–14 px; flat ellipse shadow at the feet drawn outside the transform. Sphere shading lit from the top (`mx-sph` cx .5 cy .26), `mx-under` darkens the bottom of vertical faces. Vertical faces are 56/128 of a cell.
- **Ground variety**: four tints (`#8FAE6C` base, `#A3B26A` dry, `#7EA45F` lush, `#9DB27A` dust) chosen by smooth value-noise at 1/5 cell frequency (`vnoise`, thresholds .34/.66, dust where a second noise > .7); horizontal streak texture; extras 1/23 cells (dirt patch, pebble scatter, clover). Minimap mirrors the tints.
- **Water depth**: a cell with all 8 neighbours water is *deep* (`#0B2540` @ 28 % over base, caustics); otherwise *shore* (sand rim + foam per land side, sand corner squares, one shimmer ellipse).
- ¾ RTS view on an **axis-aligned square grid**. No diamond isometric, no 3D camera. Vertical objects (wall, rock, storages) have a top face + a front face darkened by a vertical gradient (black 38 % → 60 %) and extend **56/128 of a cell above** their own cell (Y-sorted, drawn after the row above).
- **WarCraft/StarCraft rendering school, vector**: every body shape carries a dark contour (`stroke #000 @ 50 %, 3.5 px at 128 px/cell`), a sphere gradient (`radialGradient cx .36 cy .3: white 50 % → clear → black 42 %`), legs drawn twice (dark 8 px under tinted 5 px). Top faces use a diagonal top-left-light gradient (`white 22 % → black 16 %`). Soft radial drop shadows under every free-standing object.
- **Ground is textured, not flat**: each ground cell gets two low-opacity blobs (dark 7 %, light 7 %) and four blade strokes (black 13 %), all seeded from `hash(x, y, 13)`. Inside the nest ring the ground is overlaid with earth `#7A5A3C @ 38 %` (trodden floor); the one-cell apron around the ring gets `@ 16 %`.
- **Water shorelines**: a water cell draws a 14/128 sand rim `#D9C9A8 @ 55 %` plus a 6/128 foam line `white @ 35 %` on every side that borders non-water.
- **Tint-ready**: masters are white; all shading is black/white overlays with opacity, so `modulate` works. Decor (row 21) and the gold on the queen/chamber are fixed colours, not tinted.
- Whole-frame **grain**: fractal-noise filter (`baseFrequency .8`, 2 octaves) at 13 % over the world layer, under the phase overlay.
- Night is a full-screen tint. The only light is the v1.6 gap light. No torches, no glowing eyes.
- A gap is ordinary ground. Never a door sprite.

Painterly reference layer: the scene applies an overlay grain (`feTurbulence`, opacity .13) above everything but the day-phase tint. Painted sprites carry equivalent grain baked in.

## Colour finals (write these back into DESIGN_BRIEF.md §4)
Changes from the brief's proposal are marked ★ with the reason.

Terrain / structures / items
- Ground `#8FAE6C` ★ (was `#93B072`; slightly deeper so bone-coloured workers and yellow food pop; the texture lifts it visually)
- Water `#4F86B3` ★ (was `#5D8FB8`; deeper so shore rims read)
- Rock `#9A958D` · Nest wall `#C97B4A` · Pavement `#D9C9A8` (v1)
- Storage food `#D9A441` · Storage resources `#9C6B45` · Queen chamber `#A86B9E`
- Food `#E8C84A` · Resource deposit `#8A5A3C` · Pile `#7A4E33`
- Trodden earth overlay (new) `#7A5A3C`

Myrmek role tints (one white silhouette) — lightness ladder, light → dark: worker, scout, builder, carrier, harvester, guard.
- Worker `#D9D2B4` ★ (was `#85A363` — identical lightness and hue to the ground, invisible at 16 px)
- Builder `#C9A227` · Guard `#4A6FA5`
- Scout `#64B5D9` (v1) · Carrier `#E09A5C` ★ (v1, was `#7FA85C`, same ground problem) · Harvester `#8A5A3C` (v1)
- Queen `#B65C8F` + gold `#E8C84A`

Tree canopy `#5F8A45` · trunk `#6B4A32` (fixed, not tinted).

Predators: Spider `#5A4A66` · Beetle `#4A5240` (v1) · Lizard `#A3B052` (v1). Minimap: all predators `#D64545`.

Minimap priority palette (leftmost wins): 1 unknown `#141413` → 2 predator `#D64545` → 3 myrmek `#F2EFE9` → 4 food `#E8C84A` → 5 resource `#8A5A3C` → 6 nest `#C97B4A` → 7 paving `#D9C9A8` (v1) → 8 water `#5D8FB8` → 9 rock `#9A958D` → 10 ground `#4E6B3A`. Viewport rectangle `#FAF9F5`, 1 px.

Day-phase overlays (full-screen `CanvasModulate`-equivalent): Day none · Dusk `#7A5A8C @ 30 %` · Night `#1A2340 @ 55 %` (+ gap light `#FFD9A0` radial, ~2 cells radius, v1.6 only) · Dawn `#D9924A @ 22 %`. Ground under the night overlay computes to `#4F6254` — the "night ground" used on the sprite sheet.

UI chrome: panel `#201F1C` · raised `#2A2926` · text `#FAF9F5` · dim `#B8B2A6` · accent `#D97757` · ok `#7FA85C` · warn `#D9A441` · danger `#D64545` · well (code/minimap inset) `#12110F`.

## Sprite inventory and drawing notes
Master cell 128 px. Coordinates below are in the cell's 128×128 space **before** the creature foreshortening transform; "raised" means the top face is translated −56 px in y (rock: −52).

1. Ground — flat tint + texture (see rules). Sheet variant seeded with 4242.
2. Water — tint + radial depth (`mx-water`), three white ripple strokes (28/20/16 %). Shore rims added by the scene.
3. Rock — heptagon `22,22 70,8 116,30 120,84 84,112 30,104 10,60`; front = same polygon with `mx-front`; top = raised copy with `mx-top`, three facet overlays (light 20 %, light 8 %, dark 12 %), three crack strokes, a moss ellipse `#6E9A4E @ 55 %` at (34,80). Shadow ellipse (72,118) 60×16.
4. Nest wall — front face `y 92…128` with gradient and block seams (`y 110` horizontal, staggered verticals); top face `y −36…92` with `mx-top`, two seam rows at −36+44 / −36+88 with staggered verticals, 10 px light cap, 8 px light left edge, 10 px dark bottom edge, 5 px light lip, 2 px outline. Ghost = whole group at 55 % + white dashed inset `14 10`. Walls tile seamlessly (top face spans full 128 width).
5. Pavement (v1) — tint + `mx-top`, 4 px seams (`y 64`, `x 64` top half, `x 32/96` bottom half), light top/left edge lines, dark bottom/right.
6. Storage food — basket: body path `M16 44 v52 a48 18 0 0 0 96 0 V44`, four woven bands (light 20 % / dark 20 % arcs), outlined; lid ellipse (64,44) 48×18 with a dark 45 % well 40×13. **Fill state = disc size**: `r = 9 + 33·f` (light 72 %) with a highlight and a shadow dot; full adds a white 55 % rim. States 0 / ⅓ / ⅔ / full.
7. Storage resources — crate: front `14,60 100×52` with plank seams at x 48/80 and y 86; top `14,20 100×40` with 6 px light cap; four dark corner bolts 8×8; **fill = horizontal gauge** `26,30 76×20` dark 45 % track, light 75 % bar of width `76·f`.
8. Queen dome — clay half-dome on an elliptical plinth (64,104) 60×16 with front gradient, gold band, open front arch with dark interior, sphere shading, contour; Y-sorted, ~1 cell tall; the queen is drawn on the threshold cell (127,127). Previous flat-tile spec, superseded: clay **dome**: base ellipse (64,104) 60×16 with front gradient, dome arc `M4 104 A60 78 0 0 1 124 104` with sphere shading and outline, gold band arc at y 84 (6 px), two shading arcs, dark open front arch `M46 104 a18 26 0 0 1 36 0` with a gold rim, gold finial r 8 at (64,26). Drawn in the vertical pass; the queen stands on the cell directly **south** (127,127).
9. Food — 1–5 outlined spheres r `11 + 1.2·n` at `[64,64] [50,74] [78,74] [54,50] [76,52]` (first n), shared shadow. Also the carcass form.
10. Resource deposit — ore shards (five-point polygon with a light left facet 30 % and a dark right facet 28 %). Rich = 5 shards; depleted = 2 shards + three crack strokes.
11. Pile — 1–3 outlined mounds (20×14 / 22×15) with two dark pebble dots each.
12. **Myrmek** — drawn facing N inside ~0.8 cell: abdomen (64,96) 16×22 with two dark segment arcs, petiole `58,70 12×10`, thorax (64,60) 11×15, head (64,30) r 12, mandibles (two 4 px arcs), two eye dots r 2.5, antennae `58,26→48,12→44,0` mirrored, six legs `MLEGS` (see js). Directional frames = rotation 0/45/90/135/180 (N NE E SE S); west mirrored in-engine. The drop shadow is drawn **outside** the rotation, centred (no baked light direction).
13. Cargo dot — outlined sphere r 13 at (64,12) in the jaws, rotates with the heading; food `#E8C84A` or resource `#8A5A3C`.
14. Queen — ~1.4 cell, facing S. Head (64,−6) 20×19 with a gold crest polygon `50,−22 56,−38 64,−26 72,−38 78,−22`, thorax (64,34) 22×26, abdomen (64,104) 38×54 with three gold bands (82/106/130), two translucent wings 20×58 rotated ±14° at (34,96)/(94,96) white 22 % + 50 % stroke, long legs (7 px). Stationary.
15. Spider — ~1.5 cell. Abdomen (64,92) 32×36 with three white chevrons, cephalothorax r 22 at (64,46), head 12×9 with two fangs, five eye dots, eight 7 px legs. Poses: **ambush** (legs tucked), **lunge** (front legs thrown to y −46, body shifted −12), **eating** (legs spread wide, food item under the body). Three drawn directions N/E/S, rotate/mirror the rest.
16. Beetle (v1) — ~1.8 cell. Elytra (64,84) 54×70 with a centre seam and four rib lines, pronotum (64,4) 40×28, head (64,−34) 22×16, six 8 px legs. Attack pose adds a forked horn polygon.
17. Lizard (v1) — ~2 cells long. Body (64,52) 24×52 with a white dorsal stripe and four rib lines, head (64,−8) 17×22, tail 18 px stroke (run: S-curve `M64 100c-6 34 18 48 0 80s-40 30-46 58`; flee: curled right). Run legs splayed, flee legs tucked.
18. Selection ring — myrmek: flat ellipse at the feet (64,90) 66×28, dark halo 10 px + accent 6 px + inner 3 px at 35 %. Cell: rounded square `−8,−8 144×144 r14` with a 12 % fill.
19. Path + target — polyline through cell centres: black 30 % 12 px under accent 8 px dashed `22 18`; target = circle r 26 (halo + 6 px accent) with a r 8 dot.
20. Gap light (v1.6) — radial `#FFD9A0` 85 % → 35 % @ 45 % → 0, radius 2 cells, drawn **above** the night overlay, one per gap position.
21. Decor — **tree** (2-cell sprite, passable landmark): trunk 16×100 with front gradient, layered canopy ellipses `#5F8A45` with sphere shading and under-gradient, trunk `#6B4A32`, feet shadow. Placement `hash(x,y,23) % 31 == 0`, outside the ring apron, off paving, > 9 cells (Manhattan) from the nest centre. Also: **tree** (2 cells tall): trunk `56,20 16×100` with front gradient and two branches, four canopy ellipses (36×26, 38×28, 46×30, 28×20) with sphere shading and an under-shadow, five leaf highlights, feet shadow (74,118) 52×12; placed by `hash(x,y,23) % 31 == 0`, never inside/near the ring, on paving, or within 9 cells of the nest; passable, non-interactive. Tuft A/B (two-tone blade strokes with a dark under-stroke), pebbles (three outlined ellipses `#A8A399`), flower (six outlined petals `#F2EFE9` + gold centre), dry patch `#A3B378` blob with cracks, moss fleck `#6E9A4E`. ~1 per 5 ground cells, `hash(x,y,11) % 5 == 0`, type `(h >> 4) % 6`; never inside the ring, never under objects.

Readability checked on the sheet: at 16 px worker/builder/guard separate by lightness; food dot visible on ground; wall ≠ rock (warm clay block vs grey facets); storage fill states legible (disc size / gauge length).

## Screens

### Observer screen (1440×900, design at 32 px/cell; tweak shows 16 px)
World fills the frame. HUD is edge-anchored, 16 px from the edges, dark chrome that never touches structures.

Panel recipe (all HUD boxes): `background linear-gradient(180deg, rgba(46,44,39,.96), rgba(26,25,22,.97))`, `border 1px #0E0D0B`, `box-shadow inset 0 0 0 1px rgba(255,255,255,.07), inset 0 2px 0 rgba(201,123,74,.85) [clay trim], 0 10px 28px rgba(0,0,0,.45)`, radius 6. Raised button: `linear-gradient(180deg,#3A3833,#26251F)`, `inset 0 1px 0 rgba(255,255,255,.14), inset 0 -2px 0 rgba(0,0,0,.45), 0 0 0 1px #0E0D0B`; active adds `0 0 0 2px rgba(217,119,87,.5)` and accent text. Primary button: `linear-gradient(180deg,#E48A6A,#C4633F)`, text `#201F1C`. Wells (code, portrait, minimap): `#12110F` with `inset 0 2px 6px rgba(0,0,0,.6)`.

Type: IBM Plex Sans (400/500/600) for UI, IBM Plex Mono (400/500/600) for ticks, coordinates, code, ids. Sizes: day counter 20/600; body 13; secondary 12; captions/uppercase labels 11 with `.04em` tracking; mono 12. All HUD text ≥ 4.5:1 on the panel gradient (`#FAF9F5` and `#B8B2A6` both pass).

- **Top-left — day/phase chip**: "Day 1" 20/600 · "tick 742" mono 12 dim · 1 px divider · four-segment phase pip (widths 64/10/44/10 px, height 6, radius 3; active `#FAF9F5`, rest white 22 %) over a caption "DAY · 458 TO DUSK". Padding 10 14 10 16, gap 14. Night variant: "Night 1", third segment lit, "NIGHT · 248 TO DAWN".
- **Top-right — statistics strip**: Population with three tinted 10 px dots and counts (10 · 3 · 3) and a bold total; Food store value + 72×6 bar (`#D9A441` fill, 2 px white reserve tick at 35 %) + "reserve 20"; Deaths today; a 16 px stroked bar-chart glyph (v1 opens charts). Dividers 1×22 white 12 %. Gap 18, padding 10 16.
- **Bottom-left — minimap**: 256×256 well inside a 6 px panel padding, radius 5. 1 px per cell, priority palette above, viewport rect. Click-to-move. v1 adds a "true map" toggle.
- **Bottom-centre — time cluster**: 44×44 targets: pause (two 3.5×12 rects), 1×, 4×, 16×, single step (triangle + bar). Active speed raised + accent text. Divider, then "● saved · day 1" (7 px `#7FA85C` dot, 12 px dim text). No save button. "New world" lives in a separate menu, never here.
- **Right rail** (320 wide, top 76, gap 4 below the header): tab row Queen | Tools (36 high; Queen tab carries a 9 px mono `LLM` chip in accent 20 % bg). Tools (v0): two 48-high rows — 20 px stroked icon, title 13/500, hint 11 dim, mono hotkey (F / S). Active tool row raised. v1 adds place patch, any predator, delete, heal, reveal. The **inspector docks below the tools** when something is selected: 64 px portrait well (selected sprite, facing S, on `#1C1B18`), role dot + "Worker" 14/600 + "#41" mono, state caption; Energy label + value, 8 px bar (`#7FA85C`), threshold ticks at 40 (`#D9A441`) and 15 (`#D64545`) with mono labels; grid of HP / Task / Cargo / Path rows (12.5 px). Night variant shows the Queen tab instead: "Last cycle · t810 · v7", a 3-line code well with the fired branch highlighted, a 3-row status grid (gaps / outside / predator, warn and danger colours), "Open queen panel" raised button.
- **Bottom-right — event log**: 320 wide, "EVENTS" caption + chevron, last 3 lines mono 12 (`tNNN` dim + message; danger lines in `#D64545`). Expands upward.

### Queen panel (380 wide, LLM mode)
Header: queen glyph (14 px `#B65C8F` disc with a 3 px gold inner ring) + "Queen" 16/600; mode segmented control BUILTIN / PROGRAM / LLM in a `#141413` pill, mono 10/600, active `#D97757` bg with `#201F1C` text. "PROGRAM · v7" caption with "last cycle t810 · 2 branches fired". Code well: mono 12 / 1.65, 22 px gutter with line numbers; **fired lines** get `rgba(217,119,87,.18)` row background and an accent `●` in the gutter (lines 2–3 and 8–9 in the mock). Policy: 3×2 grid of raised cells — label 11 dim, value mono 14/500 (forage_radius 14 · min_guards 2 · reserve 20 · seal_at dusk · rest_below 40 · build_priority 0.6). Versions: rows `v7 / note / d1 t690` with the current version's id in accent. Footer: "Revise now" primary + "Save to library" raised, 44 high. v1.5 adds situation chip, scorecard verdict, promotion history. **No** health / reproduction / eggs.

### Inspector (standalone, 480 wide)
Myrmek: header with role dot, name, mono id + coords, state caption; 96 px portrait well beside a 15×9-cell scene crop at 32 px that shows the selection ring, dashed path and target marker; energy bar 10 px with "40 rest" / "15 starve" ticks; HP / State / Task / Cargo / Path rows 13 px. Cell: header with a 14 px accent-outlined square glyph, "(127,121)" mono, "GAP · NORTH" caption; scene crop with the square cell ring; five layer rows (terrain / structure / object / agent / known) with 12 px swatches, 90 px label column, 1 px separators.

### Minimap close-up
Minimap at 2× (512) in a well, palette list 1–10 with swatch, name, hex; the paving row wears a v1 badge; explanatory note in dim text.

### States board
Day-phase strip: four identical 17×11-cell crops at 20 px, labelled with overlay hex and %. Zoom ladder: the same 24×14 cells at 8/16/32/48 px (v0 ships 16/32). Night seal moment at 32 px without gap light (prototype truth). Markers: selection + path + target crop; a dusk crop with `ghostGap` (wall at 55 % with dashed inset). Unreachable target = no marker at all.

### v1 extension sheet
Pavement, beetle (walk/attack), lizard (run/flee), gap light on the five sheet rows; six role tints at 32/16 px on day and night ground; a paving crop (floors inside the ring along x 127 / y 126, road from the east gap to the patch); parameters panel (360 wide): queen_brain segmented + provider select; grouped sliders (4 px track, 16 px thumb, accent fill) — Food: food_frequency, food_units (range); Night: night_predator_mult, night_energy_mult; Energy/policy/predators: move_cost, weight_safety, spider_target, lizard_target.

## Interactions & behaviour
- Time: pause / 1× / 4× / 16× / step (v1: 0.5×–16× ladder). Autosave marker updates on each save; no manual save.
- Minimap click centres the camera; viewport rect follows.
- Click a myrmek → selection ring, path polyline + target marker for its current task, inspector docks in the rail. Click a cell → square ring, layer stack. Esc clears.
- Tools: pick a tool (row raised), click the world; hotkeys F / S. Interventions act on the world only (food, predators); never on structures.
- Queen panel: mode switch; "Revise now" triggers a cycle; fired-branch highlight refreshes each cycle; version rows select a version to diff (future).
- Movement interpolated between cells; myrmeks rotate toward heading; the drop shadow does not rotate.
- Y-sort: draw order by cell row; vertical sprites extend 36/128 above their cell.
- Day phase: one `CanvasModulate`-style overlay; gap lights only at night, v1.6.

## State
`day, tick, phase, speed, paused, lastSaveDay`; `population by role, foodStore, reserve, deathsToday`; `selection {kind: myrmek|cell, id|cell}`; `activeTool`; `events[]`; `queen {mode, programVersion, firedLines[], policy{6}, versions[]}`; `camera {x, y, pxPerCell}`; `known[]` for the minimap.

## Tokens
Spacing: 4 / 6 / 8 / 10 / 12 / 14 / 16 / 18 (HUD edge 16). Radii: panel 6, button 5, well 5, chip 4, pill 7. Icon sizes 16 / 20, touch targets ≥ 44. Type scale 9 (badges) / 10 / 11 / 12 / 12.5 / 13 / 14 / 16 / 20.

## Assets
- `sprites/master/*.svg` (48 files) and `sprites/tinted/*.svg` — generated from `myrmex-art.js`.
- `scenes/observer-day-32px.svg`, `observer-night-32px.svg`, `minimap-day.svg`, `minimap-night.svg` — the exact world renders used on the artboards.
- `world-model.json` — mock world used by the mockups (ring, gaps, structures, items, agents, colours).
- Fonts: IBM Plex Sans, IBM Plex Mono (Google Fonts / SIL OFL).
- No emoji, no raster art anywhere.

## Files
- `Myrmex UI Mockups.dc.html` — the canvas with artboards 1a–1h (needs `myrmex-art.js` beside it).
- `myrmex-art.js` — sprite/scene/minimap drawing code (the shape spec).
