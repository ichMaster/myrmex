extends GdUnitTestSuite
## Contract + unit: the seven-phase tick order, sim-level determinism, and
## the spawner's cadence and regeneration (all draws from the spawner
## stream only).


func _params() -> SimParams:
	var params: SimParams = load("res://data/sim_params.tres")
	return params


func test_tick_phase_order_contract() -> void:
	# The trace of one step() is exactly the seven documented phases.
	var sim := Sim.new(42, _params())
	sim.step()
	assert_array(sim.last_step_trace).contains_exactly(
		["environment", "queen", "myrmeks", "predators", "combat", "knowledge", "render"])
	assert_array(Sim.PHASE_ORDER).is_equal(sim.last_step_trace)
	# The clock moved exactly one tick.
	assert_int(sim.clock.tick).is_equal(1)


func test_determinism_same_seed_same_hash_after_n_ticks() -> void:
	var sim_a := Sim.new(777, _params())
	var sim_b := Sim.new(777, _params())
	assert_int(sim_a.state_hash()).is_equal(sim_b.state_hash())
	for i in 450:
		sim_a.step()
		sim_b.step()
	assert_int(sim_a.state_hash()).is_equal(sim_b.state_hash())
	assert_int(sim_a.clock.tick).is_equal(450)

	var sim_c := Sim.new(778, _params())
	for i in 450:
		sim_c.step()
	assert_int(sim_a.state_hash()).is_not_equal(sim_c.state_hash())


func test_spawner_draws_only_from_spawner_stream() -> void:
	var sim := Sim.new(42, _params())
	var before: Dictionary = sim.rng.export_state()
	for i in 500:
		sim.step()
	var after: Dictionary = sim.rng.export_state()
	# The tick loop touches no stream but `spawner` in v0.1.
	for stream_name in ["worldgen", "combat", "strategy", "interventions"]:
		assert_that(after[stream_name]).override_failure_message(
			"stream '%s' was consumed by the tick loop" % stream_name).is_equal(before[stream_name])
	# The spawner stream did move: tick 200 and 400 each rolled p_food.
	assert_that(after["spawner"]).is_not_equal(before["spawner"])


func test_food_wave_cadence() -> void:
	var params := _params()
	var sim := Sim.new(90210, params)
	var objects_before := sim.world.objects.size()
	var wave_deltas: Array[int] = []
	var off_cadence_delta := 0
	for i in 20 * params.t_food + 1:
		var count_before := sim.world.objects.size()
		sim.step()
		var delta := sim.world.objects.size() - count_before
		# The step that processed tick T is the one where T % t_food == 0.
		if (sim.clock.tick - 1) % params.t_food == 0 and sim.clock.tick - 1 > 0:
			wave_deltas.append(delta)
		else:
			off_cadence_delta += delta
	# Nothing spawns off cadence; on cadence a wave adds 0–3 food cells.
	assert_int(off_cadence_delta).is_equal(0)
	assert_int(wave_deltas.size()).is_equal(20)
	var spawned_waves := 0
	for delta in wave_deltas:
		assert_int(delta).is_between(0, 3)
		if delta > 0:
			spawned_waves += 1
	# p_food = 0.3: with this seed some waves fire and some do not.
	assert_int(spawned_waves).is_between(1, 19)
	# Every spawned object is well-formed FOOD on free ground.
	var food_units_total := 0
	for cell in sim.world.objects:
		var object_data: Dictionary = sim.world.objects[cell]
		if object_data["type"] == "FOOD":
			assert_int(object_data["units"]).is_between(
				params.food_item_units_min, params.food_item_units_max)
			assert_int(sim.world.terrain[cell]).is_equal(SimWorld.Terrain.GROUND)
	assert_int(sim.world.objects.size()).is_greater_equal(objects_before)


func test_patch_regeneration_after_t_res() -> void:
	var params := _params()
	var sim := Sim.new(1337, params)
	# Deplete patch 0 by hand (harvesting arrives in v0.3): zero the
	# reserve, stamp the depletion tick, clear its RESOURCE objects.
	var patch: Dictionary = sim.world.patches[0]
	var cells: PackedInt32Array = patch["cells"]
	var depleted_tick: int = sim.clock.tick
	patch["reserve"] = 0
	patch["depleted_at"] = depleted_tick
	for cell in cells:
		sim.world.remove_object(cell)

	# Up to (but not including) depleted_at + t_res: still depleted.
	for i in params.t_res:
		sim.step()
	assert_int(sim.world.patches[0]["reserve"]).is_equal(0)
	assert_int(sim.world.patches[0]["depleted_at"]).is_equal(depleted_tick)

	# The step processing tick depleted_at + t_res regenerates it.
	sim.step()
	assert_int(sim.world.patches[0]["reserve"]).is_between(
		params.patch_reserve_min, params.patch_reserve_max)
	assert_int(sim.world.patches[0]["depleted_at"]).is_equal(-1)
	var restored := 0
	for cell in cells:
		var object_data: Dictionary = sim.world.object_at(cell)
		if not object_data.is_empty() and object_data["type"] == "RESOURCE":
			assert_int(object_data["patch_id"]).is_equal(0)
			restored += 1
	assert_int(restored).is_greater(0)
