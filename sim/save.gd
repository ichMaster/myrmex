class_name SimSave
extends RefCounted
## Object-free serialization and the single-file autosave (ARCHITECTURE
## §Saves). A save is a snapshot of pure data — numbers, strings, arrays,
## dictionaries and packed arrays only, written with var_to_bytes into a
## compressed file, **never** the *_with_objects variants — plus a plain
## JSON sidecar header. v0: one file, no rotation, no slots.

const FORMAT_VERSION := 1
const SAVE_PATH := "user://autosave.save"

## Run outcomes the header may carry.
const OUTCOME_RUNNING := "running"
const OUTCOME_INFECTED := "infected"
const OUTCOME_STARVED := "starved"


# --- Snapshot (plain types only) ------------------------------------------------

## The full sim state as plain types. Sparse dictionaries are flattened to
## cell-sorted pair arrays so a load rebuilds them in one deterministic
## insertion order and the state hash survives the round trip.
static func snapshot(sim: Sim) -> Dictionary:
	var world := sim.world

	var object_pairs := []
	var object_cells := world.objects.keys()
	object_cells.sort()
	for cell in object_cells:
		object_pairs.append([cell, world.objects[cell]])

	var agent_pairs := []
	var agent_cells := world.agents.keys()
	agent_cells.sort()
	for cell in agent_cells:
		agent_pairs.append([cell, world.agents[cell]])

	var patch_pairs := []
	var patch_ids := world.patches.keys()
	patch_ids.sort()
	for patch_id in patch_ids:
		patch_pairs.append([patch_id, world.patches[patch_id]])

	return {
		"format_version": FORMAT_VERSION,
		"seed": sim.master_seed,
		"params": _params_snapshot(sim.params),
		"clock": sim.clock.export_state(),
		"rng": sim.rng.export_state(),
		"outcome": OUTCOME_RUNNING,
		"world": {
			"size": world.size,
			"start_cell": world.start_cell,
			"terrain": world.terrain,
			"structures": world.structures,
			"known": world.known,
			"objects": object_pairs,
			"agents": agent_pairs,
			"patches": patch_pairs,
		},
	}


## Every script variable of SimParams, so a resumed run keeps the exact
## parameters it started with even if res://data defaults change later.
static func _params_snapshot(params: SimParams) -> Dictionary:
	var out := {}
	for property in params.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out[property["name"]] = params.get(property["name"])
	return out


# --- Write ------------------------------------------------------------------------

## Writes the compressed save and its JSON sidecar header. Returns true on
## success. The header's date is wall-clock metadata for humans — nothing
## in the sim ever reads it.
static func write(sim: Sim, path: String = SAVE_PATH, outcome: String = OUTCOME_RUNNING) -> bool:
	var data := snapshot(sim)
	data["outcome"] = outcome

	var file := FileAccess.open_compressed(path, FileAccess.WRITE)
	if file == null:
		push_error("SimSave: cannot write '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_var(data) # plain var_to_bytes semantics — never *_with_objects
	file.close()

	var header := {
		"version": FORMAT_VERSION,
		"seed": sim.master_seed,
		"day": sim.clock.day(),
		"population": sim.world.agents.size(),
		"date": Time.get_datetime_string_from_system(),
		"outcome": outcome,
	}
	var header_file := FileAccess.open(_header_path(path), FileAccess.WRITE)
	if header_file == null:
		push_error("SimSave: cannot write header for '%s'" % path)
		return false
	header_file.store_string(JSON.stringify(header, "\t"))
	header_file.close()
	return true


static func _header_path(path: String) -> String:
	return path.get_basename() + ".json"


# --- Read -------------------------------------------------------------------------

static func save_exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Reads a snapshot back. A format_version other than the current one is an
## honest refusal — empty dictionary, never a silent migration.
static func read_snapshot(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open_compressed(path, FileAccess.READ)
	if file == null:
		push_error("SimSave: cannot read '%s' (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var data: Variant = file.get_var(false) # false: objects never decode
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SimSave: '%s' does not contain a snapshot" % path)
		return {}
	var snapshot_data: Dictionary = data
	var version := int(snapshot_data.get("format_version", -1))
	if version < FORMAT_VERSION:
		push_error("SimSave: refusing '%s' — format_version %d is older than current %d; no silent migration" % [path, version, FORMAT_VERSION])
		return {}
	if version > FORMAT_VERSION:
		push_error("SimSave: refusing '%s' — format_version %d is newer than this build understands (%d)" % [path, version, FORMAT_VERSION])
		return {}
	return snapshot_data


## Rebuilds a Sim from a snapshot: saved params, exact clock and RNG stream
## positions, and the world layers with dictionaries re-inserted in sorted
## order — the resumed run continues bit-identically.
static func restore(snapshot_data: Dictionary) -> Sim:
	var params := SimParams.new()
	var saved_params: Dictionary = snapshot_data["params"]
	for field in saved_params:
		params.set(field, saved_params[field])

	var sim := Sim.new(int(snapshot_data["seed"]), params, false)
	sim.clock.import_state(snapshot_data["clock"])
	sim.rng.import_state(snapshot_data["rng"])

	var world_data: Dictionary = snapshot_data["world"]
	var world := SimWorld.new(int(world_data["size"]))
	world.start_cell = int(world_data["start_cell"])
	world.terrain = world_data["terrain"]
	world.structures = world_data["structures"]
	world.known = world_data["known"]
	for pair in world_data["objects"]:
		world.objects[int(pair[0])] = pair[1]
	for pair in world_data["agents"]:
		world.agents[int(pair[0])] = pair[1]
	for pair in world_data["patches"]:
		world.patches[int(pair[0])] = pair[1]
	sim.world = world
	return sim
