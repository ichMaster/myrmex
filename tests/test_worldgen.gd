extends GdUnitTestSuite
## Unit: the seeded generator. Guarantees hold across a batch of seeds,
## generation is deterministic per seed, and the terrain shares stay sane.

const BATCH_SEEDS: Array[int] = [1, 7, 42, 1337, 90210]


func _params() -> SimParams:
	var params: SimParams = load("res://data/sim_params.tres")
	return params


func _generate(seed_value: int) -> SimWorld:
	return Worldgen.generate(SimRng.new(seed_value), _params())


func test_guarantees_hold_across_seed_batch() -> void:
	var params := _params()
	for seed_value in BATCH_SEEDS:
		var world := _generate(seed_value)
		assert_object(world).override_failure_message("seed %d generated null" % seed_value).is_not_null()

		# Start cleared to the documented radius.
		var start_x := world.x_of(world.start_cell)
		var start_y := world.y_of(world.start_cell)
		for dy in range(-params.start_clear_radius, params.start_clear_radius + 1):
			for dx in range(-params.start_clear_radius, params.start_clear_radius + 1):
				if world.in_bounds(start_x + dx, start_y + dy):
					assert_int(world.terrain[world.idx(start_x + dx, start_y + dy)]).override_failure_message(
						"seed %d: uncleaned cell at %d,%d" % [seed_value, dx, dy]).is_equal(SimWorld.Terrain.GROUND)

		# The brood dome sits on the cell north of the start.
		assert_int(world.structures[world.idx(start_x, start_y - 1)]).is_equal(SimWorld.Structure.QUEEN_CHAMBER)

		# Patch registry: full count, documented footprints and reserves.
		assert_int(world.patches.size()).is_equal(params.patch_count)
		var near_patches := 0
		for patch_id in world.patches:
			var patch: Dictionary = world.patches[patch_id]
			var cells: PackedInt32Array = patch["cells"]
			assert_int(cells.size()).is_between(params.patch_cells_min, params.patch_cells_max)
			assert_int(patch["reserve"]).is_between(params.patch_reserve_min, params.patch_reserve_max)
			assert_int(patch["depleted_at"]).is_equal(-1)
			for cell in cells:
				var object_data: Dictionary = world.objects[cell]
				assert_str(object_data["type"]).is_equal("RESOURCE")
				assert_int(object_data["patch_id"]).is_equal(patch_id)
			var near := false
			for cell in cells:
				if maxi(absi(world.x_of(cell) - start_x), absi(world.y_of(cell) - start_y)) <= params.guarantee_radius:
					near = true
					break
			if near:
				near_patches += 1
		assert_int(near_patches).override_failure_message(
			"seed %d: only %d patches near start" % [seed_value, near_patches]).is_greater_equal(params.guarantee_min_patches)

		# ~20 food units within the guarantee radius, full item count worldwide.
		var near_units := 0
		var food_items := 0
		for cell in world.objects:
			var object_data: Dictionary = world.objects[cell]
			if object_data["type"] == "FOOD":
				food_items += 1
				assert_int(object_data["units"]).is_between(params.food_item_units_min, params.food_item_units_max)
				if maxi(absi(world.x_of(cell) - start_x), absi(world.y_of(cell) - start_y)) <= params.guarantee_radius:
					near_units += object_data["units"]
		assert_int(food_items).is_equal(params.starting_food_items)
		assert_int(near_units).is_greater_equal(params.guarantee_min_food_units)

		# The start region is not enclosed by massifs.
		assert_int(Worldgen.flood_count(world, world.start_cell)).is_greater_equal(
			world.size * world.size / Worldgen.MIN_START_REGION_DIVISOR)


func test_terrain_shares_sane() -> void:
	var world := _generate(42)
	var counts := [0, 0, 0, 0]
	for cell in world.size * world.size:
		counts[world.terrain[cell]] += 1
	var total := world.size * world.size
	# Ground majority; every impassable class present in meaningful volume.
	assert_int(counts[SimWorld.Terrain.GROUND] * 100 / total).is_between(50, 85)
	assert_int(counts[SimWorld.Terrain.WATER] * 100 / total).is_between(4, 20)
	assert_int(counts[SimWorld.Terrain.WALL] * 100 / total).is_between(4, 20)
	assert_int(counts[SimWorld.Terrain.HIGHLAND] * 100 / total).is_between(2, 16)


func test_generation_determinism() -> void:
	var world_a := _generate(42)
	var world_b := _generate(42)
	assert_int(world_a.state_hash()).is_equal(world_b.state_hash())
	assert_int(world_a.start_cell).is_equal(world_b.start_cell)
	assert_array(world_a.terrain).is_equal(world_b.terrain)

	var world_c := _generate(43)
	assert_int(world_a.state_hash()).is_not_equal(world_c.state_hash())
