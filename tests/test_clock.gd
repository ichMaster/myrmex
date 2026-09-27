extends GdUnitTestSuite
## Unit: the day-cycle clock. With the documented 600/60/400/60 cycle the
## phase boundaries land exactly at ticks 600/660/1060/1120, the day rolls
## over at 1120, and is_dawn_tick() fires once per day.


func _clock() -> SimClock:
	var params: SimParams = load("res://data/sim_params.tres")
	return SimClock.new(params)


func test_phase_boundaries_exact() -> void:
	var clock := _clock()
	var expectations := [
		[0, SimClock.Phase.DAY],
		[599, SimClock.Phase.DAY],
		[600, SimClock.Phase.DUSK],
		[659, SimClock.Phase.DUSK],
		[660, SimClock.Phase.NIGHT],
		[1059, SimClock.Phase.NIGHT],
		[1060, SimClock.Phase.DAWN],
		[1119, SimClock.Phase.DAWN],
		[1120, SimClock.Phase.DAY],
	]
	for pair in expectations:
		clock.tick = pair[0]
		assert_int(clock.phase()).override_failure_message(
			"phase at tick %d" % pair[0]).is_equal(pair[1])


func test_day_rollover() -> void:
	var clock := _clock()
	clock.tick = 0
	assert_int(clock.day()).is_equal(1)
	clock.tick = 1119
	assert_int(clock.day()).is_equal(1)
	clock.tick = 1120
	assert_int(clock.day()).is_equal(2)
	clock.tick = 1120 * 3 + 5
	assert_int(clock.day()).is_equal(4)


func test_dawn_tick_fires_once_per_day() -> void:
	var clock := _clock()
	var dawn_ticks: Array[int] = []
	for i in 2240:
		if clock.is_dawn_tick():
			dawn_ticks.append(clock.tick)
		clock.advance()
	assert_array(dawn_ticks).contains_exactly([1060, 2180])


func test_ticks_to_next_phase() -> void:
	var clock := _clock()
	var expectations := [
		[0, 600], [599, 1], [600, 60], [659, 1],
		[660, 400], [1059, 1], [1060, 60], [1119, 1], [1120, 600],
	]
	for pair in expectations:
		clock.tick = pair[0]
		assert_int(clock.ticks_to_next_phase()).override_failure_message(
			"ticks_to_next_phase at tick %d" % pair[0]).is_equal(pair[1])


func test_phase_names() -> void:
	var clock := _clock()
	clock.tick = 0
	assert_str(clock.phase_name()).is_equal("day")
	clock.tick = 1060
	assert_str(clock.phase_name()).is_equal("dawn")


func test_export_import_round_trip() -> void:
	var clock := _clock()
	clock.tick = 777
	var snapshot := clock.export_state()
	assert_int(typeof(snapshot["tick"])).is_equal(TYPE_INT)
	var restored := _clock()
	restored.import_state(snapshot)
	assert_int(restored.tick).is_equal(777)
	assert_int(restored.phase()).is_equal(SimClock.Phase.NIGHT)
	assert_int(restored.day()).is_equal(1)
