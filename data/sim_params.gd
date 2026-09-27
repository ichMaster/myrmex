class_name SimParams
extends Resource
## Simulation parameter defaults (ARCHITECTURE §Configuration).
##
## Defaults are data: the values live in res://data/sim_params.tres and are
## never hardcoded in sim code. The sim is integer-only — every accumulated
## quantity is a fixed-point integer in thousandths of a unit ("milli", the
## `_milli` suffix), and probabilities are stored per-mille (§Determinism
## and replay). Worldgen is the one place float noise is allowed.

# --- World -----------------------------------------------------------------

## World side in cells (square). v0 prototype: 256, no chunks — the whole
## world is awake. Generation accepts 256–2048, multiples of 64.
@export var world_size: int = 256

# --- Time (ticks; 1 s = ticks_per_second at speed x1) ------------------------

@export var ticks_per_second: int = 10
## Day cycle 600/60/400/60 — one full day is 1120 ticks.
@export var day_ticks: int = 600
@export var dusk_ticks: int = 60
@export var night_ticks: int = 400
@export var dawn_ticks: int = 60
## The queen plans every N_plan ticks (phase 2 of the tick).
@export var n_plan: int = 10

# --- Worldgen shares and guarantees ------------------------------------------

## Terrain shares in percent of cells.
@export var water_pct: int = 12
@export var rock_pct: int = 10
@export var highland_pct: int = 8
## Resource patches: count, footprint in cells, shared reserve in units.
@export var patch_count: int = 40
@export var patch_cells_min: int = 3
@export var patch_cells_max: int = 12
@export var patch_reserve_min: int = 10
@export var patch_reserve_max: int = 60
## Starting food: item count and units per item (denser near the start).
@export var starting_food_items: int = 60
@export var food_item_units_min: int = 1
@export var food_item_units_max: int = 5
## Start guarantees: cleared radius; and within guarantee_radius cells of the
## start there are at least guarantee_min_patches patches and about
## guarantee_min_food_units units of food; the start region is not enclosed.
@export var start_clear_radius: int = 12
@export var guarantee_radius: int = 30
@export var guarantee_min_patches: int = 2
@export var guarantee_min_food_units: int = 20

# --- Environment dynamics -----------------------------------------------------

## Every t_food ticks each active region rolls p_food (per-mille — 300 = 0.3)
## for a new 1–3 cell food cluster; a depleted patch regains a reserve after
## t_res ticks. v0: the whole map is the one active region.
@export var t_food: int = 200
@export var p_food_permille: int = 300
@export var t_res: int = 3000

# --- Energy (fixed-point thousandths — ARCHITECTURE §Agents) -------------------

## Max 100.000; costs per tick/action; one food unit restores 50.000.
@export var energy_max_milli: int = 100000
@export var energy_idle_milli: int = 10
@export var energy_step_milli: int = 50
@export var energy_step_loaded_milli: int = 75
@export var energy_step_paved_milli: int = 30
@export var energy_attack_milli: int = 500
@export var food_unit_energy_milli: int = 50000
## The queen burns 0.100/tick and is sated at ≥70.000.
@export var queen_idle_milli: int = 100
@export var queen_sated_milli: int = 70000
