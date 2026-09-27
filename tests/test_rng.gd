extends GdUnitTestSuite
## Contract: the named RNG streams (ARCHITECTURE §Determinism and replay).
## Pins the closed stream list, per-stream determinism, stream independence,
## and exact resume from an exported state — the seams saves and replay
## stand on.

const MASTER_SEED := 424242


func _draw(rng_set: SimRng, stream_name: String, count: int) -> Array[int]:
	var out: Array[int] = []
	var stream := rng_set.stream(stream_name)
	for i in count:
		out.append(stream.randi())
	return out


func test_stream_list_pinned() -> void:
	# The closed list, in order — a new stream is a contract change.
	assert_array(SimRng.STREAM_NAMES).contains_exactly(
		["worldgen", "spawner", "combat", "strategy", "interventions"])
	var rng_set := SimRng.new(MASTER_SEED)
	for stream_name in SimRng.STREAM_NAMES:
		assert_bool(rng_set.has_stream(stream_name)).is_true()
		assert_object(rng_set.stream(stream_name)).is_not_null()
	assert_bool(rng_set.has_stream("weather")).is_false()


func test_same_seed_identical_sequences() -> void:
	var a := SimRng.new(MASTER_SEED)
	var b := SimRng.new(MASTER_SEED)
	for stream_name in SimRng.STREAM_NAMES:
		assert_array(_draw(a, stream_name, 50)).is_equal(_draw(b, stream_name, 50))


func test_different_seeds_differ() -> void:
	var a := SimRng.new(1)
	var b := SimRng.new(2)
	assert_array(_draw(a, "worldgen", 20)).is_not_equal(_draw(b, "worldgen", 20))


func test_stream_independence() -> void:
	# Draws from `spawner` never shift `combat`'s sequence.
	var noisy := SimRng.new(MASTER_SEED)
	var quiet := SimRng.new(MASTER_SEED)
	_draw(noisy, "spawner", 100)
	assert_array(_draw(noisy, "combat", 50)).is_equal(_draw(quiet, "combat", 50))
	# And per-stream sub-seeds differ: streams are not one shared sequence.
	var fresh_a := SimRng.new(MASTER_SEED)
	var fresh_b := SimRng.new(MASTER_SEED)
	assert_array(_draw(fresh_a, "spawner", 20)).is_not_equal(_draw(fresh_b, "combat", 20))


func test_export_import_resumes_exactly() -> void:
	var original := SimRng.new(MASTER_SEED)
	for stream_name in SimRng.STREAM_NAMES:
		_draw(original, stream_name, 10)
	var snapshot := original.export_state()
	# Snapshot is plain types only: {name: {"seed": int, "state": int}}.
	for stream_name in SimRng.STREAM_NAMES:
		assert_bool(snapshot.has(stream_name)).is_true()
		assert_int(typeof(snapshot[stream_name]["seed"])).is_equal(TYPE_INT)
		assert_int(typeof(snapshot[stream_name]["state"])).is_equal(TYPE_INT)

	var expected := {}
	for stream_name in SimRng.STREAM_NAMES:
		expected[stream_name] = _draw(original, stream_name, 20)

	# Import over a *different* master seed must still resume exactly.
	var resumed := SimRng.new(1)
	resumed.import_state(snapshot)
	for stream_name in SimRng.STREAM_NAMES:
		assert_array(_draw(resumed, stream_name, 20)).is_equal(expected[stream_name])
