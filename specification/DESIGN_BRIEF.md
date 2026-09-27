# Design Brief — Myrmex UI Mockups

Document version 2.0 — 27 September 2026.

**The canonical design brief now lives with the design itself: [design_handoff_myrmex_ui/DESIGN_BRIEF.md](design_handoff_myrmex_ui/DESIGN_BRIEF.md) (v2.0).** This file is a pointer kept so links and history do not break; do not add content here — amend the handoff brief instead.

The handoff package ([design_handoff_myrmex_ui/](design_handoff_myrmex_ui/)) also carries the README (HUD recipe, tokens, interactions), the shape-reference SVGs (`sprites/master|tinted/`), the rendered scenes, `world-model.json` (mock world — not a level) and `myrmex-art.js` (the shape spec — never shipped).

## Engineering acceptance (27.09.2026)

The handoff's §10 was accepted in full and folded into VISION v1.10, ARCHITECTURE v1.18 and ROADMAP v1.9:

- **2:1 isometric presentation** over the unchanged square data grid (depth sort `x+y`, inverse projection for clicks; the minimap stays square).
- **`HIGHLAND`** joins the terrain enum with worldgen massifs and a start-not-enclosed guarantee.
- **Painted continuous ground**, the render-derived **creep field**, and **passable trees** in the decor layer.
- **Hand-painted raster pipeline**: per-role colour passes, the eight-heading rig (five painted, three mirrored); painted art is never `modulate`-tinted; ~60 pieces v0 / ~110 full.
- The `QUEEN_CHAMBER` (brood dome) spawns on the cell north of the queen.

Three engineering answers to the handoff's open points:

1. **Dirt trails** render from the v1.4 traffic field — v0 ships without them (the mock's trails are static).
2. **Display names**: the creature keeps **myrmek** in the UI (project identity); **brood mother**, **lurker**, **tusk brute**, **winged shade** are adopted; code identifiers stay `queen` / `spider` / `beetle` / `lizard`.
3. **Canopy fade**: a tree's canopy drops to ~40% opacity while an agent is beneath, so trees never hide the colony.

## History of changes

**v2.0 (27.09.2026)** — superseded by the designer's consolidated brief in the handoff package; this file becomes a pointer carrying the engineering acceptance of §10 and the three answers (trails from traffic in v1.4, myrmek kept as the UI name, canopy fade).

**v1.4 (27.09.2026)** — projection flipped by the author's decision: the ¾ RTS view replaced pure top-down as the first pillar (sprite volume on the square grid, Y-sort, five-direction agent frames), the budget grew to ~50 v0 / ~90 full, the myrmek and spider rows carried directional frames, the 8-px flattening note joined the zoom ladder, and the anti-pattern excluded diamond isometric and true 3D.

**v1.3 (27.09.2026)** — added the decor set as inventory row 21 (six render-only ground-dressing sprites, seed-hashed, non-blocking), grew the budget to ~26 SVGs, included it in deliverable 1, and narrowed the flora anti-pattern to canopy-scale only.

**v1.2 (27.09.2026)** — pinned pure top-down projection as the first style pillar and added the Anti-patterns section distilled from an early AI mockup: no pseudo-3D, no flora, no tamagotchi queen panel, no dig/build tools, no wall HP, no torches, no manual save buttons.

**v1.1 (27.09.2026)** — corrected the gap light to v1 (`PointLight2D` arrives in v1.6; the prototype's night is the tint alone) in the inventory, the overlay table and deliverable 1; added the companion prototype brief ([DESIGN_BRIEF_PROTOTYPE.md](DESIGN_BRIEF_PROTOTYPE.md)).

**v1.0 (27.09.2026)** — initial brief: scope and pillars from VISION §The look, the proposed color language, the 20-sprite inventory, observer-screen and panel anatomy, the states set, and the deliverables checklist.
