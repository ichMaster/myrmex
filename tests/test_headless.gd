extends GdUnitTestSuite
## Unit: the headless harness — the phase DoD as automated checks, run
## in-process against the same static loop the entry point uses. Two runs
## from one seed produce an identical stats trace and final hash; an
## interrupted run resumes into the uninterrupted continuation.

const RunSim := preload("res://tools/run_sim.gd")
const TEST_SAVE := "user://test_headless_resume.save"


func before_test() -> void:
	for path in [TEST_SAVE, "user://test_headless_resume.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _params() -> SimParams:
	var params: SimParams = load("res://data/sim_params.tres")
	return params


func _fresh_sim(seed_value: int) -> Sim:
	var sim := Sim.new(seed_value, _params())
	sim.autosave_enabled = false
	return sim


func test_parse_args_defaults_and_values() -> void:
	var defaults := RunSim.parse_args(PackedStringArray())
	assert_int(defaults["seed"]).is_equal(1)
	assert_int(defaults["ticks"]).is_equal(1120)
	assert_int(defaults["size"]).is_equal(0)
	assert_int(defaults["stats_every"]).is_equal(100)
	assert_bool(defaults["new"]).is_false()
	assert_bool(defaults["hash"]).is_false()

	var parsed := RunSim.parse_args(PackedStringArray(
		["--seed=42", "--ticks=300", "--size=128", "--stats-every=50", "--new", "--hash"]))
	assert_int(parsed["seed"]).is_equal(42)
	assert_int(parsed["ticks"]).is_equal(300)
	assert_int(parsed["size"]).is_equal(128)
	assert_int(parsed["stats_every"]).is_equal(50)
	assert_bool(parsed["new"]).is_true()
	assert_bool(parsed["hash"]).is_true()


func test_two_runs_one_seed_identical_trace_and_hash() -> void:
	# The DoD line, automated: identical stats trace, identical final hash.
	var sim_a := _fresh_sim(42)
	var sim_b := _fresh_sim(42)
	var trace_a := RunSim.run_loop(sim_a, 500, 100)
	var trace_b := RunSim.run_loop(sim_b, 500, 100)
	assert_array(trace_a).is_equal(trace_b)
	assert_int(trace_a.size()).is_equal(6)
	assert_str(RunSim.hash_line(sim_a)).is_equal(RunSim.hash_line(sim_b))
	# The trace is alive: it starts at tick 0 and ends at tick 500.
	assert_str(trace_a[0]).contains("tick 0")
	assert_str(trace_a[5]).contains("tick 500")
	# A different seed diverges.
	var sim_c := _fresh_sim(43)
	RunSim.run_loop(sim_c, 500, 100)
	assert_str(RunSim.hash_line(sim_c)).is_not_equal(RunSim.hash_line(sim_a))


func test_stats_line_reads_live_state() -> void:
	var sim := _fresh_sim(7)
	var line := RunSim.stats_line(sim)
	assert_str(line).contains("day 1")
	assert_str(line).contains("tick 0")
	assert_str(line).contains("· day ·")
	assert_str(line).contains("saves 0")
	# Food and reserves come from the generated world.
	var food_items := 0
	for cell in sim.world.objects:
		if sim.world.objects[cell]["type"] == "FOOD":
			food_items += 1
	assert_str(line).contains("food %d" % food_items)


func test_interrupt_and_resume_equals_uninterrupted() -> void:
	# Uninterrupted reference: 900 ticks straight.
	var uninterrupted := _fresh_sim(1337)
	RunSim.run_loop(uninterrupted, 900, 100)

	# Interrupted twin: 400 ticks, shutdown save, "kill", resume, 500 more.
	var interrupted := _fresh_sim(1337)
	RunSim.run_loop(interrupted, 400, 100)
	interrupted.autosave_path = TEST_SAVE
	interrupted.save_now()
	var resumed := SimSave.restore(SimSave.read_snapshot(TEST_SAVE))
	resumed.autosave_enabled = false
	var tail := RunSim.run_loop(resumed, 500, 100)

	assert_int(resumed.clock.tick).is_equal(900)
	assert_str(RunSim.hash_line(resumed)).is_equal(RunSim.hash_line(uninterrupted))
	# The resumed tail reports exactly the line the uninterrupted run
	# reached — including the saves field (code review #2).
	assert_str(tail[tail.size() - 1]).is_equal(RunSim.stats_line(uninterrupted))


func test_resume_at_dawn_boundary_no_duplicate_save() -> void:
	# Regression (code review #2): a run killed right after the dawn
	# autosave used to re-save that dawn on resume and reset the saves
	# counter, so the resumed stats trace diverged from the uninterrupted one.
	var save_a := "user://test_dawn_a.save"
	var save_b := "user://test_dawn_b.save"
	for path in [save_a, save_b, "user://test_dawn_a.json", "user://test_dawn_b.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

	var uninterrupted := Sim.new(2026, _params())
	uninterrupted.autosave_path = save_a
	for i in 1200:
		uninterrupted.step()
	assert_int(uninterrupted.dawn_saves).is_equal(1)

	# Twin killed mid-tick 1060, right after the dawn write: the dawn
	# autosave file itself is the state we resume from.
	var doomed := Sim.new(2026, _params())
	doomed.autosave_path = save_b
	for i in 1061:
		doomed.step()
	var resumed := SimSave.restore(SimSave.read_snapshot(save_b))
	resumed.autosave_path = save_b
	assert_int(resumed.clock.tick).is_equal(1060)
	assert_int(resumed.dawn_saves).is_equal(1)
	while resumed.clock.tick < 1200:
		resumed.step()

	# No duplicate dawn save, and the stats line matches to the letter.
	assert_int(resumed.dawn_saves).is_equal(1)
	assert_str(RunSim.stats_line(resumed)).is_equal(RunSim.stats_line(uninterrupted))
	assert_str(RunSim.hash_line(resumed)).is_equal(RunSim.hash_line(uninterrupted))
