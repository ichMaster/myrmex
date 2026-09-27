extends GdUnitTestSuite
## Contract + unit: the object-free save format. Round trip preserves the
## state hash and the continued run bit-identically; the serialized tree is
## plain types only; the dawn edge writes once per day; a foreign
## format_version is refused, never migrated.

const TEST_SAVE := "user://test_save_roundtrip.save"

## Everything var_to_bytes may carry for us: numbers, strings, bools,
## arrays, dictionaries and packed arrays. TYPE_OBJECT and friends are the
## contract violation.
const PLAIN_TYPES: Array[int] = [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
	TYPE_ARRAY, TYPE_DICTIONARY,
	TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
]


func before_test() -> void:
	for path in [TEST_SAVE, "user://test_save_roundtrip.json", "user://test_dawn.save", "user://test_dawn.json", "user://test_refuse.save"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _params() -> SimParams:
	var params: SimParams = load("res://data/sim_params.tres")
	return params


func _assert_plain(value: Variant, trail: String) -> void:
	var value_type := typeof(value)
	assert_array(PLAIN_TYPES).override_failure_message(
		"non-plain type %s at %s" % [type_string(value_type), trail]).contains([value_type])
	if value_type == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		for key in dictionary:
			_assert_plain(key, trail + ".key")
			_assert_plain(dictionary[key], "%s.%s" % [trail, key])
	elif value_type == TYPE_ARRAY:
		var array: Array = value
		for i in array.size():
			_assert_plain(array[i], "%s[%d]" % [trail, i])


func test_snapshot_is_plain_types_only() -> void:
	var sim := Sim.new(42, _params())
	sim.autosave_enabled = false
	for i in 250:
		sim.step()
	_assert_plain(SimSave.snapshot(sim), "snapshot")


func test_round_trip_continues_bit_identically() -> void:
	var interrupted := Sim.new(1337, _params())
	interrupted.autosave_enabled = false
	var uninterrupted := Sim.new(1337, _params())
	uninterrupted.autosave_enabled = false

	for i in 300:
		interrupted.step()
		uninterrupted.step()

	# Save at the tick boundary, "kill" the interrupted run, resume it.
	assert_bool(SimSave.write(interrupted, TEST_SAVE)).is_true()
	var boundary_hash := interrupted.state_hash()
	var resumed := SimSave.restore(SimSave.read_snapshot(TEST_SAVE))
	assert_int(resumed.state_hash()).is_equal(boundary_hash)
	resumed.autosave_enabled = false

	# Both copies cross a t_food wave and keep identical hashes throughout.
	for i in 250:
		resumed.step()
		uninterrupted.step()
	assert_int(resumed.state_hash()).is_equal(uninterrupted.state_hash())
	assert_int(resumed.clock.tick).is_equal(uninterrupted.clock.tick)


func test_header_carries_documented_fields() -> void:
	var sim := Sim.new(7, _params())
	sim.autosave_enabled = false
	assert_bool(SimSave.write(sim, TEST_SAVE)).is_true()
	var header_text := FileAccess.get_file_as_string("user://test_save_roundtrip.json")
	var header: Dictionary = JSON.parse_string(header_text)
	assert_array(header.keys()).contains_exactly_in_any_order(
		["version", "seed", "day", "population", "date", "outcome"])
	assert_int(int(header["version"])).is_equal(SimSave.FORMAT_VERSION)
	assert_int(int(header["seed"])).is_equal(7)
	assert_int(int(header["day"])).is_equal(1)
	assert_int(int(header["population"])).is_equal(0)
	assert_str(header["outcome"]).is_equal("running")


func test_dawn_trigger_writes_once_per_day() -> void:
	var sim := Sim.new(90210, _params())
	sim.autosave_path = "user://test_dawn.save"
	# Two full days: dawn edges at ticks 1060 and 2180 only.
	for i in 2181:
		sim.step()
	assert_int(sim.saves_written).is_equal(2)
	assert_bool(SimSave.save_exists("user://test_dawn.save")).is_true()
	# The autosaved file resumes: it holds the tick-2180 boundary state.
	var resumed := SimSave.restore(SimSave.read_snapshot("user://test_dawn.save"))
	assert_int(resumed.clock.tick).is_equal(2180)


func test_in_memory_snapshot_is_isolated() -> void:
	# Regression (code review #1): snapshot() used to alias the live sim's
	# dictionaries — an in-memory restore shared state with the original.
	var sim := Sim.new(555, _params())
	sim.autosave_enabled = false
	for i in 50:
		sim.step()
	var snap := SimSave.snapshot(sim)
	var fork := SimSave.restore(snap)
	fork.autosave_enabled = false
	var fork_hash := fork.state_hash()
	assert_int(fork_hash).is_equal(sim.state_hash())

	# Mutate the original directly (dict and packed layers) and step it on.
	sim.world.patches[0]["reserve"] = 0
	sim.world.patches[0]["depleted_at"] = sim.clock.tick
	sim.world.terrain[0] = SimWorld.Terrain.WALL
	for i in 250:
		sim.step()

	# The fork and the snapshot itself are untouched by any of it.
	assert_int(fork.state_hash()).is_equal(fork_hash)
	var second_fork := SimSave.restore(snap)
	assert_int(second_fork.state_hash()).is_equal(fork_hash)
	# And forks are independent of each other too.
	second_fork.world.patches[0]["reserve"] = 1
	assert_int(fork.world.patches[0]["reserve"]).is_not_equal(1)


func test_foreign_format_versions_refused() -> void:
	for foreign_version in [0, 999]:
		var file := FileAccess.open_compressed("user://test_refuse.save", FileAccess.WRITE)
		file.store_var({"format_version": foreign_version, "seed": 1})
		file.close()
		assert_bool(SimSave.read_snapshot("user://test_refuse.save").is_empty()).override_failure_message(
			"format_version %d must be refused" % foreign_version).is_true()
