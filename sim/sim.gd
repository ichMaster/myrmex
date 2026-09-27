class_name Sim
extends RefCounted
## The simulation aggregate: owns the world, clock, RNG streams and spawner,
## and steps the invariant seven-phase tick (ARCHITECTURE §Time and the
## tick). The phase order is a contract; agent phases are explicit no-ops
## until their versions land (myrmeks v0.3, predators v0.6, planning v0.5).
## Pure data — a headless run is the same simulation minus render sync.

## The invariant phase order — pinned by the contract test.
const PHASE_ORDER: PackedStringArray = [
	"environment", "queen", "myrmeks", "predators", "combat", "knowledge", "render",
]

var master_seed: int
var params: SimParams
var rng: SimRng
var clock: SimClock
var world: SimWorld
var spawner: SimSpawner

## The trace of the last step's phases, for the order contract test and
## debugging. Rebuilt every step.
var last_step_trace := PackedStringArray()

## Autosave wiring (v0: one file, no rotation). The dawn edge writes the
## tick-boundary state; save_now() serves the runner's shutdown path.
## dawn_saves and last_autosave_tick persist in the save file — exit saves
## are not counted, so a resumed run's stats stay identical to an
## uninterrupted one — and neither field enters state_hash(): they are I/O
## metadata and never influence sim evolution.
var autosave_enabled := true
var autosave_path: String = SimSave.SAVE_PATH
var dawn_saves := 0
var last_autosave_tick := -1


func _init(seed_value: int, params_in: SimParams, generate_world := true) -> void:
	master_seed = seed_value
	params = params_in
	rng = SimRng.new(seed_value)
	clock = SimClock.new(params_in)
	spawner = SimSpawner.new()
	if generate_world:
		world = Worldgen.generate(rng, params_in)
		if world == null:
			push_error("Sim: worldgen failed for seed %d" % seed_value)


## One tick: the seven phases in the invariant order, then the clock moves.
## The dawn autosave fires before the phases, so the file holds a clean
## tick-boundary state — a resumed run processes this tick exactly like the
## uninterrupted one.
func step() -> void:
	if autosave_enabled and clock.is_dawn_tick() and last_autosave_tick != clock.tick:
		save_now(true)

	last_step_trace = PackedStringArray()

	_phase("environment")
	spawner.step_environment(world, clock, rng, params)

	_phase("queen")
	if clock.tick % params.n_plan == 0:
		pass # Queen planning lands in v0.5; the slot and cadence are fixed now.

	_phase("myrmeks") # No agents until v0.3.
	_phase("predators") # No predators until v0.6.
	_phase("combat") # Nothing to resolve until agents exist.
	_phase("knowledge") # No reveal until myrmeks move (v0.3).
	_phase("render") # Headless: the sync point exists, nothing draws.

	clock.advance()


func _phase(phase_name: String) -> void:
	last_step_trace.append(phase_name)


## Writes the autosave right now — the dawn edge and the shutdown path both
## land here. A dawn save stamps its tick and counts itself *before*
## writing, so the file it produces already knows this dawn is done — a
## run killed right after it resumes without a duplicate save.
func save_now(is_dawn := false) -> void:
	var previous_count := dawn_saves
	var previous_tick := last_autosave_tick
	if is_dawn:
		dawn_saves += 1
		last_autosave_tick = clock.tick
	if not SimSave.write(self, autosave_path):
		dawn_saves = previous_count
		last_autosave_tick = previous_tick


## Deterministic hash over the full sim state: world layers, clock position
## and every RNG stream position — the value the DoD's "identical after N
## ticks" and the save round-trip compare.
func state_hash() -> int:
	var rng_state := rng.export_state()
	var rng_canon := []
	for stream_name in SimRng.STREAM_NAMES:
		var entry: Dictionary = rng_state[stream_name]
		rng_canon.append([stream_name, entry["seed"], entry["state"]])
	return hash([world.state_hash(), clock.tick, rng_canon])
