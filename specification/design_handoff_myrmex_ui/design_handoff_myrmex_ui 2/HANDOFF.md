# Myrmex — design handoff for Claude Code

Read in this order: **DESIGN_BRIEF.md** (what and why; §10 lists the architecture decisions to confirm) → **HANDOFF.md** (this file: what is in the folder and how to use it) → `art/` and `scenes/`.

## What is decided

- **Presentation:** isometric 2:1 over a square data grid. `screen = ((x−y)·64, (x+y)·32)`; depth sort by `x+y`. Cell master = 128 px.
- **Art pipeline:** creatures, nest structures and walls are **generated raster PNGs** (prompts in `CREATURE_PROMPTS.md`, sheets in `art/`). Ground, water, highland, decor, items and markers are **procedural** (reference renderer `myrmex-art.js`; vector SVG masters in `sprites/`).
- **Creature sheets:** 8 cells × 256 px in one row, heading index `N=0 NE=1 E=2 SE=3 S=4 SW=5 W=6 NW=7`; feet at ~86 % of cell height. Scale per creature (× cell): worker 1.05 · builder 1.3 · guard 1.5 · scout 1.1 · carrier 1.25 · harvester 1.3 · lurker 1.5 · stalker 1.7 · razorback 1.6 · brood mother 1.9 (single 512 px image).
- **Structure sheets** (`art/objects/`, 256 px cells unless noted): `ridge.png` 3 cells (run · corner · end) — drawn along the down-right diagonal; mirror horizontally for E–W runs; 1.25 × cell, feet +8. `dome.png` 512 px single, 1.7 ×. `sac.png` 4 cells (0 · ⅓ · ⅔ · full), 1.2 ×. `hollow.png` 6 cells (two variants × empty/half/full), 1.2 ×. `tree.png` 3 shapes (384 px), 2 ×. `egg.png` single (v2). `crag.png` and `decor.png` exist but are **not used** — procedural versions were preferred.
- **Palette:** see DESIGN_BRIEF §4 and `world-model.json → colors`.
- **Display names:** worker · builder · guard · scout · carrier · harvester · brood mother · lurker · stalker · razorback. Code ids stay `myrmek`, `queen`, `spider`, `beetle`, `lizard`.

## Folder map

```
DESIGN_BRIEF.md          brief v2.7 (+ §10 architecture impact — confirm before building)
HANDOFF.md               this file
README.md                HUD / panel / token spec (older sections superseded by the brief where they conflict)
CREATURE_PROMPTS.md      1–23 generation prompts (name = file number in uploads/)
world-model.json         mock world: ring, gaps, rooms, structures, agents, ponds, highland, palette
Myrmex UI Mockups.dc.html   the canvas (artboards 1a–1h, 2a–2e)
myrmex-art.js            reference renderer: procedural sprites, scene(), minimap(), raster hooks
art/creatures/*.png      14 creature sheets (+ README.md with per-file notes and gaps)
art/objects/*.png        ridge, dome, sac, hollow, tree, egg, crag, decor
art/raster-128.datauri.js  the 128 px preview bundle the canvas loads (not for the game)
scenes/*.svg             rendered boards: observer day/night, field-west, ore-east, three combat scenes
scenes/SCENES.json       the exact scene() parameters for each board (agents, predators, fx)
sprites/master|tinted/   vector SVG masters for the procedural set (ground, water, items, markers…)
```

## Godot mapping

- Ground/water/creep: shader over a biome-noise field (brief §10.2–3), not tiles.
- Highland: impassable terrain enum; render procedural crag clusters (`S.isoMountain` in `myrmex-art.js`) or paint from `art/objects/crag.png` if preferred later.
- Walls: `ridge.png` run/corner/end by neighbour mask; mirror for E–W.
- Creatures: `AnimatedSprite2D`, one `SpriteFrames` per pose, frame = heading index. Chroma is already removed (PNG alpha).
- Combat FX seen in scenes 2c–2e (slash arc, hit burst, blood pool, red alert, fallen body) are UI-layer sprites — draw as small vector or 64 px PNGs; parameters in `SCENES.json → fx`.
- HUD: `README.md` §HUD + `DESIGN_BRIEF.md` §6–7.

## Known gaps

- Worker / worker-cargo sheets lack true N, S, E, W views (diagonals substituted). Builder has one back view only. Stalker views are near-identical (radial hull). Regenerate with prompts 1–3, 9–10 if needed.
- Highland and ground decor generated files were rejected in review; procedural remains canonical.
- No generated art for ground, water, food, ore, piles, markers — procedural / vector masters in `sprites/`.
