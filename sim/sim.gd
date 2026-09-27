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
var autosave_enabled := true
var autosave_path: String = SimSave.SAVE_PATH
var saves_written := 0


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
	if autosave_enabled and clock.is_dawn_tick():
		save_now()

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
## land here.
func save_now() -> void:
	if SimSave.write(self, autosave_path):
		saves_written += 1


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
