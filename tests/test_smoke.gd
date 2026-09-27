extends GdUnitTestSuite
## Smoke: res://data/sim_params.tres loads and carries the documented
## defaults from ARCHITECTURE §Configuration (v0 world 256, day 600/60/400/60,
## shares 12/10/8, patches 40 at 10–60, food 60, T_food 200 / p_food 0.3 /
## T_res 3000, fixed-point energy in thousandths).


func _params() -> SimParams:
	var params: SimParams = load("res://data/sim_params.tres")
	return params


func test_params_resource_loads() -> void:
	assert_object(_params()).is_not_null().is_instanceof(SimParams)


func test_world_and_time_defaults() -> void:
	var p := _params()
	assert_int(p.world_size).is_equal(256)
	assert_int(p.ticks_per_second).is_equal(10)
	assert_int(p.day_ticks).is_equal(600)
	assert_int(p.dusk_ticks).is_equal(60)
	assert_int(p.night_ticks).is_equal(400)
	assert_int(p.dawn_ticks).is_equal(60)
	assert_int(p.n_plan).is_equal(10)
	# One full day is exactly 1120 ticks.
	assert_int(p.day_ticks + p.dusk_ticks + p.night_ticks + p.dawn_ticks).is_equal(1120)


func test_worldgen_defaults() -> void:
	var p := _params()
	assert_int(p.water_pct).is_equal(12)
	assert_int(p.rock_pct).is_equal(10)
	assert_int(p.highland_pct).is_equal(8)
	assert_int(p.patch_count).is_equal(40)
	assert_int(p.patch_cells_min).is_equal(3)
	assert_int(p.patch_cells_max).is_equal(12)
	assert_int(p.patch_reserve_min).is_equal(10)
	assert_int(p.patch_reserve_max).is_equal(60)
	assert_int(p.starting_food_items).is_equal(60)
	assert_int(p.food_item_units_min).is_equal(1)
	assert_int(p.food_item_units_max).is_equal(5)
	assert_int(p.start_clear_radius).is_equal(12)
	assert_int(p.guarantee_radius).is_equal(30)
	assert_int(p.guarantee_min_patches).is_equal(2)
	assert_int(p.guarantee_min_food_units).is_equal(20)


func test_environment_dynamics_defaults() -> void:
	var p := _params()
	assert_int(p.t_food).is_equal(200)
	assert_int(p.p_food_permille).is_equal(300)
	assert_int(p.t_res).is_equal(3000)


func test_energy_fixed_point_defaults() -> void:
	var p := _params()
	assert_int(p.energy_max_milli).is_equal(100000)
	assert_int(p.energy_idle_milli).is_equal(10)
	assert_int(p.energy_step_milli).is_equal(50)
	assert_int(p.energy_step_loaded_milli).is_equal(75)
	assert_int(p.energy_step_paved_milli).is_equal(30)
	assert_int(p.energy_attack_milli).is_equal(500)
	assert_int(p.food_unit_energy_milli).is_equal(50000)
	assert_int(p.queen_idle_milli).is_equal(100)
	assert_int(p.queen_sated_milli).is_equal(70000)
	# A loaded step costs exactly 1.5x a plain step (§Agents).
	assert_int(p.energy_step_loaded_milli * 2).is_equal(p.energy_step_milli * 3)
