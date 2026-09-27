# Creature sheets (generated, v2.7)

All sheets: PNG with alpha, 8 cells × 256 px in one row, heading order **N, NE, E, SE, S, SW, W, NW** (index 0–7). Feet sit at ~86 % of cell height. `queen.png` is a single 512 px image facing the camera.

| file | creature (code id) | pose | notes |
|---|---|---|---|
| worker.png | myrmek · worker | idle/walk | N/E/S/W approximated from diagonals — regenerate for true profiles |
| worker_cargo.png | myrmek · worker | carrying food | same |
| builder.png | myrmek · builder | idle/walk | generator gave 7 near-identical views + 1 back view; headings assigned by best match |
| guard.png | myrmek · guard | idle | from a 2×6 sheet; W mirrored from E |
| spider_ambush / spider_lunge / spider_eating.png | spider (lurker) | 3 poses | radial body — headings are subtle |
| beetle_walk / beetle_attack.png | beetle (stalker) | 2 poses | radial hull — headings near-identical |
| lizard_run / lizard_flee.png | lizard (razorback) | 2 poses | W mirrored from E |
| queen.png | queen (brood mother) | static | single view |

Source generations are in `uploads/3.png … 12.png` (prompt numbers). Godot: one `SpriteFrames` per pose, frame index = heading; scale per creature: worker 1.05, builder 1.1, guard 1.5, lurker 1.5, stalker 1.7, razorback 1.6, brood mother 1.9 (× 128 px cell).
