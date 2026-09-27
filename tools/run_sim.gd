extends SceneTree
## Headless entry point (ROADMAP §v0.1): boots a seeded sim, prints evolving
## stats, autosaves at dawn and before exit, resumes from the autosave when
## one exists. The loop and the stats line are static so the determinism
## tests run them in-process — the printed trace and the state hash are the
## values two runs from one seed must reproduce exactly.
##
## Usage (via scripts/run_headless.sh):
##   --seed=N         master seed for a new run (default 1)
##   --ticks=N        ticks to run this session (default 1120 — one day)
##   --size=N         world size for a new run (default from sim_params)
##   --new            ignore an existing autosave, start fresh
##   --hash           print the final state hash
##   --stats-every=N  stats cadence in ticks (default 100)


func _initialize() -> void:
	var exit_code := _main(OS.get_cmdline_user_args())
	quit(exit_code)


func _main(user_args: PackedStringArray) -> int:
	var args := parse_args(user_args)

	var sim: Sim
	if SimSave.save_exists() and not args["new"]:
		var snapshot := SimSave.read_snapshot()
		if snapshot.is_empty():
			# read_snapshot already explained the refusal.
			return 1
		sim = SimSave.restore(snapshot)
		print("resumed from %s · seed %d · day %d · tick %d" % [
			SimSave.SAVE_PATH, sim.master_seed, sim.clock.day(), sim.clock.tick])
	else:
		var params: SimParams = load("res://data/sim_params.tres").duplicate(true)
		if args["size"] > 0:
			params.world_size = args["size"]
		sim = Sim.new(args["seed"], params)
		if sim.world == null:
			return 1
		print("new world · seed %d · size %d" % [sim.master_seed, params.world_size])

	run_loop(sim, args["ticks"], args["stats_every"], true)

	# The shutdown save: kill-and-relaunch resumes from here.
	sim.save_now()
	print("saved · %s" % SimSave.SAVE_PATH)
	if args["hash"]:
		print(hash_line(sim))
	return 0


static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {
		"seed": 1, "ticks": 1120, "size": 0,
		"new": false, "hash": false, "stats_every": 100,
	}
	for arg in user_args:
		if arg.begins_with("--seed="):
			args["seed"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--ticks="):
			args["ticks"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--size="):
			args["size"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--stats-every="):
			args["stats_every"] = maxi(1, int(arg.get_slice("=", 1)))
		elif arg == "--new":
			args["new"] = true
		elif arg == "--hash":
			args["hash"] = true
		else:
			push_warning("run_sim: ignoring unknown argument '%s'" % arg)
	return args


## Steps the sim `ticks` times, collecting a stats line every `stats_every`
## ticks plus a final one. The returned trace is pure sim state — two runs
## from one seed return identical arrays.
static func run_loop(sim: Sim, ticks: int, stats_every: int, echo := false) -> PackedStringArray:
	var lines := PackedStringArray()
	for i in ticks:
		if sim.clock.tick % stats_every == 0:
			var line := stats_line(sim)
			lines.append(line)
			if echo:
				print(line)
		sim.step()
	var final_line := stats_line(sim)
	lines.append(final_line)
	if echo:
		print(final_line)
	return lines


## `day/tick/phase · food items · patch reserves · saves` — evolving world
## stats, every value read straight from sim state.
static func stats_line(sim: Sim) -> String:
	var food_items := 0
	for cell in sim.world.objects:
		if sim.world.objects[cell]["type"] == "FOOD":
			food_items += 1
	var reserves := 0
	for patch_id in sim.world.patches:
		reserves += int(sim.world.patches[patch_id]["reserve"])
	return "day %d · tick %d · %s · food %d · reserves %d · saves %d" % [
		sim.clock.day(), sim.clock.tick, sim.clock.phase_name(),
		food_items, reserves, sim.saves_written,
	]


static func hash_line(sim: Sim) -> String:
	return "state_hash %016x" % sim.state_hash()
