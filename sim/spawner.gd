class_name SimSpawner
extends RefCounted
## Environment dynamics (ARCHITECTURE §World model, Dynamics): food waves on
## the T_food cadence and patch regeneration after T_res. Every draw comes
## from the `spawner` stream. v0 has no chunks — the whole map is the one
## active region, so each wave is a single p_food roll.


## Phase 1 of the tick. Runs the food wave (on T_food multiples) and patch
## regeneration; deterministic — patches are visited in id order.
func step_environment(world: SimWorld, clock: SimClock, rng_set: SimRng, params: SimParams) -> void:
	var stream := rng_set.stream("spawner")
	_food_wave(world, clock, stream, params)
	_regenerate_patches(world, clock, stream, params)


## Every t_food ticks the region rolls p_food (per-mille) for one food
## cluster: 1–3 adjacent cells, 1–5 units each, on free ground.
func _food_wave(world: SimWorld, clock: SimClock, stream: RandomNumberGenerator, params: SimParams) -> void:
	if clock.tick == 0 or clock.tick % params.t_food != 0:
		return
	if stream.randi_range(0, 999) >= params.p_food_permille:
		return

	var cluster_cells := stream.randi_range(1, 3)
	var center := -1
	for _attempt in 60:
		var x := stream.randi_range(0, world.size - 1)
		var y := stream.randi_range(0, world.size - 1)
		if _free_ground(world, x, y):
			center = world.idx(x, y)
			break
	if center < 0:
		return

	world.place_object(center, SimWorld.make_food(
		stream.randi_range(params.food_item_units_min, params.food_item_units_max)))
	var placed := 1
	var center_x := world.x_of(center)
	var center_y := world.y_of(center)
	var growth_attempts := 0
	while placed < cluster_cells and growth_attempts < 20:
		growth_attempts += 1
		var x := center_x + stream.randi_range(-1, 1)
		var y := center_y + stream.randi_range(-1, 1)
		if not _free_ground(world, x, y):
			continue
		world.place_object(world.idx(x, y), SimWorld.make_food(
			stream.randi_range(params.food_item_units_min, params.food_item_units_max)))
		placed += 1


## A patch whose reserve hit zero regains a fresh 10–60 reserve t_res ticks
## after depletion, and its RESOURCE objects reappear on still-free cells.
func _regenerate_patches(world: SimWorld, clock: SimClock, stream: RandomNumberGenerator, params: SimParams) -> void:
	var patch_ids := world.patches.keys()
	patch_ids.sort()
	for patch_id in patch_ids:
		var patch: Dictionary = world.patches[patch_id]
		if patch["reserve"] > 0 or patch["depleted_at"] < 0:
			continue
		if clock.tick - int(patch["depleted_at"]) < params.t_res:
			continue
		patch["reserve"] = stream.randi_range(params.patch_reserve_min, params.patch_reserve_max)
		patch["depleted_at"] = -1
		var cells: PackedInt32Array = patch["cells"]
		for cell in cells:
			if world.terrain[cell] == SimWorld.Terrain.GROUND \
					and world.structures[cell] == SimWorld.Structure.NONE \
					and not world.objects.has(cell):
				world.place_object(cell, SimWorld.make_resource(patch_id))


func _free_ground(world: SimWorld, x: int, y: int) -> bool:
	if not world.in_bounds(x, y):
		return false
	var cell := world.idx(x, y)
	return world.terrain[cell] == SimWorld.Terrain.GROUND \
			and world.structures[cell] == SimWorld.Structure.NONE \
			and not world.objects.has(cell)
