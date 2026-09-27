# Design Brief — Myrmex UI Mockups

Document version **2.8** — 27 September 2026. Supersedes 1.4–1.7 (their amendments are folded in; the history is at the end).

Derived from VISION.md §The look, ARCHITECTURE.md (§Agents, §Nest, §Observability, §What v0 implements) and ROADMAP.md (v0.2, v0.6, v1.6) — those three remain the source of truth for *what exists*; this brief owns *how it looks*. Where 2.0 changes an architectural assumption it says so explicitly in **§10 Architecture impact** so engineering can accept or push back before any art is commissioned.

**Workspace:** the Design canvas *Myrmex UI Mockups* (artboards 1a–1h) plus `design_handoff_myrmex_ui/` (README, vector shape references, world model).

---

## 1. Purpose and scope

Produce mockups for:

1. **The object set** — every world object (§5): terrain, highland, nest, structures, items, one myrmek body with role colour passes, the brood mother, three predators, decor. Master 128 px per cell.
2. **The observer screen** — world view plus HUD (§6), day and first-night variants.
3. **The panels** — queen panel, inspector, time/save cluster, tools; parameters panel in v1 form (§7).

**Scope order: v0 first.** 3 roles (worker · builder · guard), the lurker only, two zooms, two interventions, one autosave. v1 adds 6 roles, tusk brute + winged shade, zoom ladder, creep roads, full tools and the live parameters panel. v0/v1 badges mark the differences.

## 2. Style pillars (2.0)

- **Isometric RTS view — the StarCraft-1 picture.** The world is rendered as a **2:1 isometric diamond grid** (a 128×128 logical cell → a 128×64 screen diamond; camera rotated 45°, elevation ≈ 30°). The simulation grid stays square and axis-aligned in data; only the *presentation* rotates. Everything with height is an upright sprite standing on its diamond, depth-sorted by `x + y` (then `x`). This replaces the v1.4 "square grid on screen" pillar — see §10.
- **No boxes.** Nothing in the world is drawn as a cube or an extruded tile. Highland is a cluster of jagged crags; the nest wall is a run of fleshy mounds; storages are sacs and bone hollows. Volume comes from overlapping rounded/angular masses with a lit left facet, a dark right facet, a soft cast shadow to the lower-right and ambient occlusion where the mass meets the ground.
- **Painted raster in the StarCraft-1 / WarCraft-2 tradition.** Shipped art is hand-painted (or generator-assisted, then cleaned) PNG with baked light, texture and dark contours. The vector mockups are the *composition and shape reference*, not the shipped asset. Per-role colour passes replace runtime `modulate` tints on creatures (tinting a painting flattens it).
- **Seamless ground, not tiles.** The ground is a continuous painted surface: four biome tints placed by low-frequency noise, a soft blur under the decor layer so cell edges never show, dirt trails worn between the nest gaps and the food/ore, creep spreading from the nest as an irregular blob with veins. Cell boundaries are invisible except on the cell-selection marker.
- **Living hive.** Creatures and nest belong to one original *living-hive* species (inspired by the Zerg school; our own silhouettes — no Blizzard designs copied): chitin plates over exposed muscle, bone scythes/spines, amber eyes, creep and flesh for the nest.
- **Night is a tone.** One full-screen tint per day phase; the only light is the v1.6 gap light. No torches, no glowing eyes.

### Hard constraints

- Role colours distinguishable at **16 px per cell** on both day and night ground; not by hue alone (lightness ladder: worker light bone → builder gold → guard dark blue; v1: scout light blue, carrier orange, harvester brown).
- One agent per cell; a myrmek is ~1.3 cells of screen height (rig scale 1.3), predators 1.4–1.5, the brood mother 1.5. Stationary brood mother.
- Highland, water and the nest wall are **impassable**; trees are **passable landmarks** (agents walk under the canopy).
- HUD text contrast ≥ 4.5:1; icons are drawn strokes; touch targets ≥ 44 px.
- A gap in the wall is **ordinary ground** — it reads as an opening in the ridge, never as a door.
- The asset count stays commissionable by one painter: **~60 pieces for v0**, ~110 for the full game (§5).

### Anti-patterns

- **Cubes / extruded tiles / boxy cliffs** — the world must never read as a block game.
- **Plan-view (top-down) creatures** — a flat silhouette rotated for heading flattens the whole picture; every creature is a projected 3D body (see §5.12).
- **Visible tile seams on the ground** — no checkerboard, no per-cell colour jitter.
- **A tamagotchi queen panel** (health / eggs) — the queen panel is mode chip, Lua program with fired branches, policy readout, version history.
- **Dig / build / terraform tools; HP on walls; manual save buttons** — unchanged from 1.4.
- **Copying Blizzard silhouettes** — inspiration only.

## 3. Audience and platform

Unchanged: single observer, macOS desktop Godot app at 1440×900+, web in v4. Calm, legible from across the room; dark chrome over a bright world.

## 4. Color finals (2.0)

Terrain
- Ground base `#6E8C4E` · dry `#86924E` · lush `#587E40` · dust `#7A8A54` — placed by smooth value noise (patch size 5 cells; dry < .34, lush > .66, dust where a second noise > .7).
- Biome washes over the tints (9-cell noise): scrub `#3E5C32` @ 35 %, meadow `#B4BE6A` @ 22 %, dirt `#8A6A42` @ 70 %. Biome also picks the decor set.
- Dirt trail `#7A5A3A` @ 55 %.
- Water `#3F739F`; deep water = base + `#0B2540` @ 30 %; shore rim `#C9B890` @ 50 % + foam white @ 40 % on each land side.
- Rock (single) `#8A8478` · Highland crags `#7E7568` (dark facets → `#5A3F2A` 30 % then `#1A0A14` 40 %; lit facets + `#F2E6C8` 15 %; moss `#6E9A4E`).
- Tree canopy `#5F8A45` · trunk `#6B4A32` (fixed).

Nest (creep)
- Ridge `#6B3557` · creep floor `#4A2440` (60 % inside, fading to 0 over ~4 cells outside) · flesh `#8E3A5C` · flesh highlight `#C2567A` · membrane nodules `#7A3F86` · bone `#E2D6B8` · eye `#F2B233`.
- Brood dome `#7A3A6A` · digestive sac `#9A4A72` (yolk `#D9A441`) · bone hollow `#5E3A52` · creep road (v1) `#8E5A7A`.
- Room floor washes (mockup only, @ 22 %): food halls `#C9A24A`, resource halls `#8A5A3C`, throne hall `#A86B9E`, nursery `#7A3F86`.

Items: food `#E8C84A` · ore deposit `#8A5A3C` with inner glow `#E07A4A` / `#FFB27A` · pile `#7A4E33`.

Creatures (shell colour = role; muscle `#D8465A`, bone `#E2D6B8`, glow `#7CF0D8`, eyes `#F2B233` fixed)
- Worker `#F2EBD8` · Builder `#FFB020` · Guard `#3EC9E8` · Scout `#9BE8FF` (v1) · Carrier `#FF7A45` (v1) · Harvester `#D9A46A` (v1).
- Brood mother `#B65C8F` + gold crest `#E8C84A` + egg sacs `#E9C8D8` (embryo `#4A1E3A`).
- Lurker · Stalker (v1) · Razorback (v1): all gold `#C9A24A` armour with blue `#2E6CFF` lenses.

Minimap (priority, leftmost wins): unknown `#141413` → predator `#D64545` → myrmek `#F2EFE9` → food `#E8C84A` → resource `#8A5A3C` → nest `#7A3A6A` → creep `#3E2244` → paving `#8E5A7A` (v1) → water `#5D8FB8` → highland `#6E6A62` → rock `#9A958D` → ground by biome (`#4E6B3A` base, `#5E7040` dry, `#456334` lush, `#587046` dust, `#3E5A30` scrub, `#66784A` meadow, `#6A5A3A` dirt). Viewport rectangle `#FAF9F5`, 1 px.

Day-phase overlays: day none · dusk `#7A5A8C` @ 30 % · night `#1A2340` @ 55 % (+ gap light `#FFD9A0` radial ~2 cells, v1.6) · dawn `#D9924A` @ 22 %.

UI chrome: panel gradient `#2E2C27 → #1A1916` with clay trim `#C97B4A`, raised `#3A3833 → #26251F`, well `#12110F`, text `#FAF9F5`, dim `#B8B2A6`, accent `#D97757`, ok `#7FA85C`, warn `#D9A441`, danger `#D64545`. Type: IBM Plex Sans / IBM Plex Mono.

## 5. Object inventory (2.0) — ~60 pieces v0

Master 128 px/cell; isometric diamond 128×64 on screen. "Upright" = sprite standing on the tile, feet at the tile centre. Vector references live in `sprites/master|tinted/`.

| # | Object | v | Form | Notes |
|---|---|---|---|---|
| 1 | Ground 1/1b/1c/1d | v0 | flat | four tints, blurred together; streak texture + extras (dirt patch, pebble scatter, clover) 1/23 cells |
| 2 | Water shore / 2b deep | v0 | flat | shore rim + foam per land side; deep variant when all 8 neighbours are water |
| 3 | Rock | v0 | upright | 3 jagged crags, cast shadow |
| 3b–3d | Highland (interior · edge · outcrop) | v0 | upright | cluster of 6 angular crags per cell, tallest ~0.75 cell at the back, strata cracks, scree, grass at the foot; cells overlap into one massif |
| 4 | Nest ridge run · corner · end · ghost | v0 | upright | 4 fleshy mounds per cell stretched along the run direction, veins, 4 nodules, bone spines; ghost = 50 % + dashed ellipse |
| 5 | Creep road | v1 | flat | veined creep |
| 6 | Digestive sac 0 / ⅓ / ⅔ / full | v0 | upright | translucent sac, fill = glowing yolk size |
| 7 | Bone hollow 0 / ½ / full | v0 | upright | ribbed hollow, ore stacked between ribs |
| 8 | Brood dome | v0 | upright | flesh dome, veins, spines, eye-node; the brood mother stands one cell south |
| 9 | Food 1 / 3 / 5 | v0 | upright | lifted spheres |
| 10 | Ore deposit rich / depleted | v0 | upright | 5 / 2 shards with inner glow |
| 11 | Pile 1 / 3 | v0 | upright | |
| 12 | **Raider** (myrmek) 8 headings | v0 | upright rig | see §5.12; role colour passes worker/builder/guard (v0), +3 (v1) |
| 13 | Cargo | v0 | rig part | sphere held in the scythes |
| 14 | Brood mother | v0 | upright rig | faces camera |
| 15 | Lurker ambush / lunge / eating | v0 | upright rig | |
| 16 | Tusk brute walk / attack | v1 | upright rig | |
| 17 | Winged shade run / wings out | v1 | upright rig | |
| 18 | Selection: myrmek ellipse · cell diamond | v0 | flat | ellipse 116×58 at the feet; diamond outline on the tile |
| 19 | Path + target | v0 | flat | polyline through tile centres |
| 20 | Gap light | v1.6 | overlay | |
| 21 | Decor ×14 | v0 | upright small | tuft A/B, pebbles, flower, dry patch, moss, clover, pink flowers, leaf litter, mushrooms, twig, stone, dirt crack, **tree** (passable landmark, groves by noise) |

### 5.12 Creatures — generated raster (v2.7)

Creature sprites are produced with an image generator from the prompts in **`CREATURE_PROMPTS.md`** (global style block + one prompt per creature and pose, 8 headings per row, chroma-green background), then cut to 128 px cells. The vector rig below is retained only as the mockup placeholder and as a written body-plan reference for prompt tuning.

### 5.12a Creature rig (legacy placeholder)

**Alien vocabulary (2.1).** Nothing on a creature may read as an Earth insect or animal: bodies are **faceted chitin shells** (angular plates with a lit top facet and a bioluminescent seam along the lower edge) over exposed magenta muscle; limb joints carry **glowing nodes** (`#7CF0D8`); limbs end in **bone blades**, not feet; heads have **sensory slits** (glowing wedges) instead of round eyes, plus at most one central amber eye; dorsal **spine racks** (bone spikes with glowing bases). Role colour = shell colour, chosen to pop against both the green ground and the plum creep (v2.3): worker bone-white `#F2EBD8`, builder saffron `#FFB020`, guard cyan `#3EC9E8`; v1 scout `#9BE8FF`, carrier `#FF7A45`, harvester `#D9A46A`. Brood mother `#F0C06A`; predators (v2.6) are the **gold-and-blue order**: **gold armour is the body** (`#C9A24A`, highlight `#F4E2A0`, shadow `#7A5C22`), **blue energy lenses are the light** (`#2E6CFF` / `#9FDFFF`) set into every large plate, thin spike antennae, slim armoured limbs with a lens at each joint. Three archetypes with no shared body plan: lurker = low squat crawler of stacked gold plates with wide side scythe-plates and four short legs (rears up on lunge); stalker (code beetle) = tall egg hull with three big lenses on four long thin legs; razorback (code lizard) = six-legged low hunting beast in gold plate with a blue visor slit, spine blade-fins, forked tail blade and energy talons. Gold/blue appear nowhere on castes or the nest. Exposed muscle is hot coral `#D8465A` (highlight `#FF7A88`) — never plum, so flesh also separates from creep. Every creature has a near-black contour `#14080E`. Glow accents are the same teal on every creature so the species reads as one.

Creatures are authored once as a **parametric 3D rig** — body parts placed in creature space (forward, right, up) — and projected per heading, so all eight directions come from one description and show real volume (top, side, legs down to the ground). Projection: `screen x = 64 + X`, `screen y = FEET + depth·0.55 − z`; far parts draw first. Painters receive the projected wireframes per heading as underdrawings.

- **Raider (myrmek)**: humped abdomen (flesh core + two chitin plates + two bone spines), plated thorax, low head with flesh jaw and two amber eyes (visible only when the face is toward the camera), two bone scythes forward, **four legs** (front and rear pairs) with feet on the ground, optional cargo sphere in the scythes. Scale 1.3.
- **Brood mother**: bloated flesh sac ~1.5 cells under three chitin plates and three bone spines, five translucent egg sacs with embryos, small plated head with a gold crest, four stubby legs. Faces the camera.
- **Lurker**: chitin bulb, flesh maw with four bone teeth, bone spines, two amber eyes, six flesh tentacles with bone tips; ambush (tentacles coiled) / lunge (thrown forward) / eating (wrapped around a food item).
- **Tusk brute (v1)**: three overlapping carapace plates with flesh seams over a big flesh body, plated head, two bone tusks (raised in attack), four thick legs, bone spine row.
- **Winged shade (v1)**: slim chitin body over a flesh belly, two legs, whip tail with bone tip, membrane wings folded (run) or spread (wings out).

## 6. Observer screen (1440×900, design zoom 32 px/cell; tweaks 48 / 64)

World fills the frame in isometric projection. HUD edge-anchored, 16 px margins, bevelled dark panels with a clay trim (§4). Unchanged layout: day/phase chip top-left; statistics strip top-right; minimap 256×256 bottom-left (1 px/cell, still square — the minimap is a *data* view, not a projected one); time cluster bottom-centre (pause · 1× · 4× · 16× · step · "saved · day N"); right rail with Queen | Tools tabs and the docked inspector (64 px portrait well showing the selected creature facing SE); event log bottom-right.

Hero moment: first night, gaps sealed, lurker lunging at the north gap under the night tint.

## 7. Panels

Unchanged from 1.4 in content (queen panel = mode chip + Lua with fired-branch highlight + 6-field policy + versions; inspector = portrait + scene crop + energy bar with 40/15 ticks + rows; parameters panel v1). Portrait and scene crops use the isometric renderer.

## 8. States

Day-phase strip · zoom ladder (32/48/64 shown; 16 must still read) · night seal without gap light · markers (selection ellipse, path, target, construction ghost) — all rendered isometrically.

### Combat states (v2.8)

Boards 2c–2e show how predator encounters read: **slash arc** (bone-white sweep from a guard scythe), **hit burst** (amber star at the struck cell), **blood pool** (plum ellipse, fades over a day), **alert marker** (red inverted drop above any myrmek that has seen a predator this tick), **fallen body** (bone-white curled silhouette on a dark pool; removed by carriers in v1). Guards face the threat; workers turn away and raise alert; builders hold position at the gap ready to seal. Predator poses: lurker lunge at a gap, razorbacks run/flee on the trail, stalker attack (lens flare) at the east gap.

## 9. The mock world (for the boards; not a level)

256² world, nest ring **(114–141, 114–137)** — 28×24 cells — gaps at (127,114) north and (141,126) east. Interior: entry hall from the north gap (walls x 124 / 130), two food halls west (digestive sacs at 116–118,116 and 116–117,122), two resource halls east (bone hollows at 138–140,116 and 139–140,122), central throne hall (122–132 × 128–133) with the brood dome at (127,130) and the brood mother at (127,131), nursery south (115–140 × 132–136), side galleries to the east gap. Creep footprint ≈ 34×31 cells, fading outward. Dirt trails: north gap → (127,111) → west to food at (112,112); east gap → (150,126) → north to ore at (150,116). Highland massifs at (96,108), (116,102), (160,138) and beyond; ponds at (104,120) etc. Full data in `world-model.json`.

## 10. Architecture impact — for Claude Code to confirm

What 2.0 changes against ARCHITECTURE.md and the v1.4 brief, and what it does *not*:

1. **Presentation projection: isometric.** Data stays a square grid; the renderer maps cell `(x, y)` to screen `((x−y)·64, (x+y)·32)` and depth-sorts by `x + y`. Godot: a `TileMap` in *Isometric* mode with a 128×64 tile, or a custom `Node2D` sorter. **Impact:** camera/pan/click-to-cell math changes (inverse projection on click); minimap stays square. No change to simulation code.
2. **Ground is a painted continuous layer**, not per-cell tiles: render the biome/tint field to a large texture (or 4 blended terrain layers with a soft mask), then decor/objects on top. **Impact:** a ground-texture bake step or a shader with noise-driven blend; per-cell terrain data unchanged.
3. **Creep is a scalar field** (0–1) around the nest, not a boolean "inside ring". **Impact:** one float per cell derived from the ring bounds + noise, or a spreading rule later; affects only rendering and (optionally) v2 mechanics.
4. **Highland is a new impassable terrain type** alongside water/rock. **Impact:** terrain enum + pathfinding cost = ∞; map generator places massifs (ellipse blobs + noise). Rock remains a single-cell obstacle.
5. **Trees are passable decor** (render-only, Y-sorted, ~1/17 ground cells in groves). **Impact:** decor layer only; no collision.
6. **Nest wall and interior walls share one asset** (the ridge run/corner/end); interior rooms are wall cells too. **Impact:** none on data (walls are walls); builders may place interior walls in v1+.
7. **Creatures: painted raster, per-role colour passes, 8 headings.** **Impact:** sprite atlas per role instead of `modulate`; 8 frames per pose (5 drawn + 3 mirrored still acceptable). Rig projection can also run at runtime in a vector prototype if painting lags.
8. **Asset budget** grows to ~60 v0 pieces (≈110 full). **Impact:** commissioning plan; no engine change.
9. **Display names**: raider / brood mother / lurker / tusk brute / winged shade in the UI; code identifiers (myrmek, queen, spider, beetle, lizard) unchanged.

Decision requested: accept 1–5 (presentation and terrain), or keep the v1.4 square-on-screen camera and apply only 6–9. Both variants are renderable from the same data; the mockups show variant A (isometric).

## 11. Deliverables

Canvas artboards 1a–1h (sheet v0, observer day, observer night, queen panel, inspector, minimap, states, v1 sheet); `design_handoff_myrmex_ui/` with README (shape spec), `myrmex-art.js` (reference renderer — not shipped), `sprites/master|tinted/*.svg`, `scenes/*.svg`, `world-model.json`, this brief.

## History of changes

**v2.8 (27.09.2026)** — generated art integrated for creatures, nest walls, dome and stores; combat states and open-ground boards (2a–2e); HANDOFF.md added.
**v2.7 (27.09.2026)** — creature art moves to generated raster: one prompt per creature/pose in `CREATURE_PROMPTS.md`; the vector rig stays only as a placeholder in the mockups. Castes: grub / dozer / sentinel; predators: gold-and-blue order (crawler lurker, four-legged stalker, six-legged razorback).
**v2.6 (27.09.2026)** — predators redrawn in the gold-armour / blue-lens language as three archetypes (crawler lurker, four-legged stalker, six-legged razorback); hand-authored silhouettes, no shared rig.
**v2.4 (27.09.2026)** — predators rebuilt as three body classes (burrower / walker / hoverer) unified by gold trim + blue core; display names tripod and shard (v2.5) replace tusk brute and winged shade (code ids unchanged).
**v2.3 (27.09.2026)** — creature palette for visibility on ground and creep (bone / saffron / cyan castes, red predators, coral muscle); three caste body plans (grub / dozer / sentinel) with SC1-density detail (scale rows, rib lines, sinew, spike ridges).
**v2.1 (27.09.2026)** — alien creature vocabulary: faceted shells, glowing joints/seams, blade limbs, sensory slits, spine racks; earthier role palette; ponds as smooth organic bodies; jagged tree canopies.
**v2.0 (27.09.2026)** — consolidated brief: isometric presentation, no-box volumes (crags, mounds), painted continuous ground with biomes/trails/creep field, highland terrain, passable trees, living-hive bestiary via a 3D rig, nest doubled with rooms, colour finals, §10 architecture-impact list for engineering sign-off.
**v1.7** — living-hive direction (raider / brood mother / lurker / tusk brute / winged shade), creep nest, palette shift.
**v1.6** — painted raster pipeline; dome; trees as decor.
**v1.5** — StarCraft-1 camera made explicit (foreshortened creatures, taller faces), ground variety, water depth.
**v1.4** — original brief.
