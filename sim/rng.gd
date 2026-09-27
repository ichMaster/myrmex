class_name SimRng
extends RefCounted
## Named RNG streams derived from one master seed (ARCHITECTURE §Determinism
## and replay). Every random draw in the sim flows through exactly one of
## these streams, so systems never perturb each other's sequences. Pure data:
## no Node, no scene, no wall clock.

## The closed list of streams. An unknown name is a hard error.
const STREAM_NAMES: PackedStringArray = [
	"worldgen", "spawner", "combat", "strategy", "interventions",
]

var master_seed: int

var _streams: Dictionary = {}


func _init(seed_value: int) -> void:
	master_seed = seed_value
	for stream_name in STREAM_NAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = _derive_seed(seed_value, stream_name)
		_streams[stream_name] = rng


## One sub-seed per stream: hash(master seed, stream name). Godot's hash()
## is stable across runs and platforms for the same input string.
static func _derive_seed(seed_value: int, stream_name: String) -> int:
	return hash("%d:%s" % [seed_value, stream_name])


func has_stream(stream_name: String) -> bool:
	return _streams.has(stream_name)


## The accessor every draw goes through. Unknown stream name is a hard
## error: it is reported and null is returned, so the caller crashes at the
## call site instead of silently drawing from a wrong sequence.
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		push_error("SimRng: unknown stream '%s' (known: %s)" % [stream_name, STREAM_NAMES])
		return null
	return _streams[stream_name]


## Plain-types snapshot of every stream's position, for saves:
## {stream_name: {"seed": int, "state": int}}.
func export_state() -> Dictionary:
	var out := {}
	for stream_name in STREAM_NAMES:
		var rng: RandomNumberGenerator = _streams[stream_name]
		out[stream_name] = {"seed": rng.seed, "state": rng.state}
	return out


## Restores every stream to an exported position. Seed is set before state:
## assigning seed reseeds the generator, assigning state then moves it to the
## exact saved position, so the sequence resumes without a gap.
func import_state(state: Dictionary) -> void:
	for stream_name in STREAM_NAMES:
		if not state.has(stream_name):
			push_error("SimRng: missing stream '%s' in imported state" % stream_name)
			continue
		var entry: Dictionary = state[stream_name]
		var rng: RandomNumberGenerator = _streams[stream_name]
		rng.seed = int(entry["seed"])
		rng.state = int(entry["state"])
