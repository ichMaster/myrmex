class_name Worldgen
extends RefCounted
## The seeded world generator (ARCHITECTURE §World model, Generation).
## Every draw comes from the `worldgen` stream; float noise is allowed here
## and nowhere else in the sim — generation runs once and its output lives
## in the byte arrays. Start guarantees are enforced: a violating world is
## regenerated with a sub-seed derived from the master seed and the attempt.

const MAX_ATTEMPTS := 32
const SMOOTHING_PASSES := 3
## The start region must reach at least a tenth of the map, or it counts as
## enclosed by massifs and the world regenerates.
const MIN_START_REGION_DIVISOR := 10


## Generates a fully populated, guarantee-satisfying world. Identical
## SimRng master seeds produce identical worlds.
static func generate(rng_set: SimRng, params: SimParams) -> SimWorld:
	var stream := rng_set.stream("worldgen")
	for attempt in MAX_ATTEMPTS:
		# The derived sub-seed: master seed + attempt. Attempt 0 is the
		# canonical world for the seed; retries move to sibling worlds.
		stream.seed = hash("%d:worldgen:attempt:%d" % [rng_set.master_seed, attempt])
		var world := _generate_once(stream, params)
		if world != null and _guarantees_hold(world, params):
			return world
	push_error("Worldgen: no world satisfied the start guarantees after %d attempts" % MAX_ATTEMPTS)
	return null


# --- One generation attempt ---------------------------------------------------

static func _generate_once(stream: RandomNumberGenerator, params: SimParams) -> SimWorld:
	var world := SimWorld.new(params.world_size)
	var size := world.size

	_fill_terrain(world, stream, params)
	world.terrain = _smooth(world.terrain, size, SMOOTHING_PASSES)

	var start := _pick_start(world)
	if start < 0:
		return null
	world.start_cell = start
	_clear_start(world, params)

	# The brood dome sits on the cell just north of the queen's start cell.
	var chamber_y := world.y_of(start) - 1
	if chamber_y < 0:
		return null
	world.structures[world.idx(world.x_of(start), chamber_y)] = SimWorld.Structure.QUEEN_CHAMBER

	if not _place_patches(world, stream, params):
		return null
	if not _place_starting_food(world, stream, params):
		return null
	return world


## Water and rock from noise thresholds at the documented shares, highland
## as ellipse massifs with noise-wobbled edges, over a GROUND base.
static func _fill_terrain(world: SimWorld, stream: RandomNumberGenerator, params: SimParams) -> void:
	var size := world.size
	var cell_count := size * size

	var water_noise := FastNoiseLite.new()
	water_noise.seed = stream.randi()
	water_noise.frequency = 0.015
	var rock_noise := FastNoiseLite.new()
	rock_noise.seed = stream.randi()
	rock_noise.frequency = 0.03
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = stream.randi()
	edge_noise.frequency = 0.1

	var water_values := PackedFloat32Array()
	water_values.resize(cell_count)
	var rock_values := PackedFloat32Array()
	rock_values.resize(cell_count)
	for y in size:
		for x in size:
			var cell := x + y * size
			water_values[cell] = water_noise.get_noise_2d(x, y)
			rock_values[cell] = rock_noise.get_noise_2d(x, y)

	var water_threshold := _share_threshold(water_values, params.water_pct)
	var rock_threshold := _share_threshold(rock_values, params.rock_pct)
	for cell in cell_count:
		if water_values[cell] < water_threshold:
			world.terrain[cell] = SimWorld.Terrain.WATER
		elif rock_values[cell] < rock_threshold:
			world.terrain[cell] = SimWorld.Terrain.WALL

	_stamp_massifs(world, stream, edge_noise, params)


## The value below which share_pct percent of samples fall.
static func _share_threshold(values: PackedFloat32Array, share_pct: int) -> float:
	var ranked := values.duplicate()
	ranked.sort()
	var k := values.size() * share_pct / 100
	if k <= 0:
		return -INF
	return ranked[mini(k, ranked.size() - 1)]


## Highland massifs: ellipse blobs with noise-wobbled edges, stamped on
## GROUND only, until roughly highland_pct of the map is highland.
static func _stamp_massifs(world: SimWorld, stream: RandomNumberGenerator, edge_noise: FastNoiseLite, params: SimParams) -> void:
	var size := world.size
	var target := size * size * params.highland_pct / 100
	var stamped := 0
	var blobs := 0
	while stamped < target and blobs < 64:
		blobs += 1
		var cx := stream.randi_range(0, size - 1)
		var cy := stream.randi_range(0, size - 1)
		var a := float(stream.randi_range(8, 20))
		var b := float(stream.randi_range(8, 20))
		var angle := stream.randf() * TAU
		var cos_a := cos(angle)
		var sin_a := sin(angle)
		var reach := int(maxf(a, b)) + 2
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var x := cx + dx
				var y := cy + dy
				if not world.in_bounds(x, y):
					continue
				var rx := (dx * cos_a + dy * sin_a) / a
				var ry := (-dx * sin_a + dy * cos_a) / b
				var wobble := 1.0 + 0.25 * edge_noise.get_noise_2d(x, y)
				if rx * rx + ry * ry <= wobble:
					var cell := world.idx(x, y)
					if world.terrain[cell] == SimWorld.Terrain.GROUND:
						world.terrain[cell] = SimWorld.Terrain.HIGHLAND
						stamped += 1


## Cellular-automaton smoothing: a cell flips to a terrain that holds a
## 5-of-8 neighbourhood majority; out-of-bounds counts as WALL, which grows
## a natural rock rim at the map edge. Double-buffered, order-independent.
static func _smooth(terrain: PackedByteArray, size: int, passes: int) -> PackedByteArray:
	var current := terrain
	for _pass in passes:
		var next := PackedByteArray()
		next.resize(size * size)
		for y in size:
			for x in size:
				var counts_ground := 0
				var counts_water := 0
				var counts_highland := 0
				var counts_wall := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nx := x + dx
						var ny := y + dy
						if nx < 0 or ny < 0 or nx >= size or ny >= size:
							counts_wall += 1
							continue
						match current[nx + ny * size]:
							SimWorld.Terrain.GROUND: counts_ground += 1
							SimWorld.Terrain.WATER: counts_water += 1
							SimWorld.Terrain.HIGHLAND: counts_highland += 1
							SimWorld.Terrain.WALL: counts_wall += 1
				var cell := x + y * size
				var value := current[cell]
				if counts_ground >= 5:
					value = SimWorld.Terrain.GROUND
				elif counts_water >= 5:
					value = SimWorld.Terrain.WATER
				elif counts_highland >= 5:
					value = SimWorld.Terrain.HIGHLAND
				elif counts_wall >= 5:
					value = SimWorld.Terrain.WALL
				next[cell] = value
		current = next
	return current


# --- Start point -----------------------------------------------------------------

## The start is the cell of the largest connected ground region nearest its
## centroid. Returns -1 when the map has no ground at all.
static func _pick_start(world: SimWorld) -> int:
	var size := world.size
	var cell_count := size * size
	var visited := PackedByteArray()
	visited.resize(cell_count)

	var best_root := -1
	var best_count := 0
	var best_sum_x := 0
	var best_sum_y := 0
	for root in cell_count:
		if visited[root] == 1 or world.terrain[root] != SimWorld.Terrain.GROUND:
			continue
		var count := 0
		var sum_x := 0
		var sum_y := 0
		var stack := PackedInt32Array([root])
		visited[root] = 1
		while stack.size() > 0:
			var cell := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			count += 1
			var x := cell % size
			var y := cell / size
			sum_x += x
			sum_y += y
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= size or ny >= size:
						continue
					var neighbor := nx + ny * size
					if visited[neighbor] == 0 and world.terrain[neighbor] == SimWorld.Terrain.GROUND:
						visited[neighbor] = 1
						stack.append(neighbor)
		if count > best_count:
			best_count = count
			best_root = root
			best_sum_x = sum_x
			best_sum_y = sum_y

	if best_root < 0:
		return -1

	# Second pass over the winning region: the cell nearest the centroid.
	var centroid_x := best_sum_x / best_count
	var centroid_y := best_sum_y / best_count
	visited.fill(0)
	var best_cell := best_root
	var best_distance := 0x7FFFFFFF
	var stack2 := PackedInt32Array([best_root])
	visited[best_root] = 1
	while stack2.size() > 0:
		var cell := stack2[stack2.size() - 1]
		stack2.remove_at(stack2.size() - 1)
		var x := cell % size
		var y := cell / size
		var dx0 := x - centroid_x
		var dy0 := y - centroid_y
		var distance := dx0 * dx0 + dy0 * dy0
		if distance < best_distance or (distance == best_distance and cell < best_cell):
			best_distance = distance
			best_cell = cell
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var neighbor := nx + ny * size
				if visited[neighbor] == 0 and world.terrain[neighbor] == SimWorld.Terrain.GROUND:
					visited[neighbor] = 1
					stack2.append(neighbor)
	return best_cell


static func _clear_start(world: SimWorld, params: SimParams) -> void:
	var start_x := world.x_of(world.start_cell)
	var start_y := world.y_of(world.start_cell)
	var radius := params.start_clear_radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := start_x + dx
			var y := start_y + dy
			if world.in_bounds(x, y):
				world.terrain[world.idx(x, y)] = SimWorld.Terrain.GROUND


# --- Patches and food ---------------------------------------------------------------

## A cell that can take a new object: ground, structure-free, object-free,
## and outside the immediate start area.
static func _free_for_object(world: SimWorld, x: int, y: int, min_start_distance: int) -> bool:
	if not world.in_bounds(x, y):
		return false
	var cell := world.idx(x, y)
	if world.terrain[cell] != SimWorld.Terrain.GROUND:
		return false
	if world.structures[cell] != SimWorld.Structure.NONE:
		return false
	if world.objects.has(cell):
		return false
	return _chebyshev(world, cell, world.start_cell) >= min_start_distance


static func _chebyshev(world: SimWorld, cell_a: int, cell_b: int) -> int:
	var dx: int = abs(world.x_of(cell_a) - world.x_of(cell_b))
	var dy: int = abs(world.y_of(cell_a) - world.y_of(cell_b))
	return maxi(dx, dy)


## 40 patches of 3–12 cells with one shared 10–60 reserve. The first two are
## centred within the guarantee radius — the "≥2 patches near the start"
## guarantee is constructive, not luck. Patch cells stay outside the cleared
## start radius.
static func _place_patches(world: SimWorld, stream: RandomNumberGenerator, params: SimParams) -> bool:
	var min_distance := params.start_clear_radius + 1
	var placed := 0
	var attempts := 0
	while placed < params.patch_count and attempts < params.patch_count * 20:
		attempts += 1
		var center := -1
		if placed < params.guarantee_min_patches:
			# Near-start patch: centre within the guarantee radius.
			var reach := params.guarantee_radius - 3
			var dx := stream.randi_range(-reach, reach)
			var dy := stream.randi_range(-reach, reach)
			var x := world.x_of(world.start_cell) + dx
			var y := world.y_of(world.start_cell) + dy
			if not _free_for_object(world, x, y, min_distance):
				continue
			center = world.idx(x, y)
		else:
			var x := stream.randi_range(0, world.size - 1)
			var y := stream.randi_range(0, world.size - 1)
			if not _free_for_object(world, x, y, min_distance):
				continue
			center = world.idx(x, y)

		var target_cells := stream.randi_range(params.patch_cells_min, params.patch_cells_max)
		var patch_cells := _grow_patch(world, stream, center, target_cells, min_distance, placed)
		if patch_cells.size() < params.patch_cells_min:
			# Undo a runt patch and try another centre.
			for cell in patch_cells:
				world.remove_object(cell)
			continue
		world.patches[placed] = {
			"cells": patch_cells,
			"reserve": stream.randi_range(params.patch_reserve_min, params.patch_reserve_max),
			"depleted_at": -1,
		}
		placed += 1
	return placed == params.patch_count


## Random blob growth from the centre over free ground; every claimed cell
## gets the RESOURCE object immediately (which also blocks other patches).
static func _grow_patch(world: SimWorld, stream: RandomNumberGenerator, center: int, target_cells: int, min_distance: int, patch_id: int) -> PackedInt32Array:
	var cells := PackedInt32Array()
	var frontier := PackedInt32Array([center])
	while cells.size() < target_cells and frontier.size() > 0:
		var pick := stream.randi_range(0, frontier.size() - 1)
		var cell := frontier[pick]
		frontier[pick] = frontier[frontier.size() - 1]
		frontier.remove_at(frontier.size() - 1)
		var x := world.x_of(cell)
		var y := world.y_of(cell)
		if not _free_for_object(world, x, y, min_distance):
			continue
		world.place_object(cell, SimWorld.make_resource(patch_id))
		cells.append(cell)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				if world.in_bounds(x + dx, y + dy):
					frontier.append(world.idx(x + dx, y + dy))
	cells.sort()
	return cells


## Starting food, denser near the start: half the items land within the
## guarantee radius (which also satisfies the ~20-units guarantee — every
## item is at least one unit), the rest anywhere on free ground.
static func _place_starting_food(world: SimWorld, stream: RandomNumberGenerator, params: SimParams) -> bool:
	var near_items := params.starting_food_items / 2
	for item in params.starting_food_items:
		var placed := false
		for _attempt in 200:
			var x: int
			var y: int
			if item < near_items:
				x = world.x_of(world.start_cell) + stream.randi_range(-params.guarantee_radius, params.guarantee_radius)
				y = world.y_of(world.start_cell) + stream.randi_range(-params.guarantee_radius, params.guarantee_radius)
			else:
				x = stream.randi_range(0, world.size - 1)
				y = stream.randi_range(0, world.size - 1)
			if not _free_for_object(world, x, y, 3):
				continue
			var units := stream.randi_range(params.food_item_units_min, params.food_item_units_max)
			world.place_object(world.idx(x, y), SimWorld.make_food(units))
			placed = true
			break
		if not placed:
			return false
	return true


# --- Guarantees --------------------------------------------------------------------

## Reachable ground area from a cell, 8-directional — the "not enclosed by
## massifs" check, and reusable by tests and later phases.
static func flood_count(world: SimWorld, from_cell: int) -> int:
	if world.terrain[from_cell] != SimWorld.Terrain.GROUND:
		return 0
	var size := world.size
	var visited := PackedByteArray()
	visited.resize(size * size)
	var stack := PackedInt32Array([from_cell])
	visited[from_cell] = 1
	var count := 0
	while stack.size() > 0:
		var cell := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		count += 1
		var x := cell % size
		var y := cell / size
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := x + dx
				var ny := y + dy
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var neighbor := nx + ny * size
				if visited[neighbor] == 0 and world.terrain[neighbor] == SimWorld.Terrain.GROUND:
					visited[neighbor] = 1
					stack.append(neighbor)
	return count


static func _guarantees_hold(world: SimWorld, params: SimParams) -> bool:
	# Start cleared and the chamber in place.
	if world.start_cell < 0:
		return false
	var chamber_cell := world.start_cell - world.size
	if chamber_cell < 0 or world.structures[chamber_cell] != SimWorld.Structure.QUEEN_CHAMBER:
		return false

	# ≥2 patches with a cell inside the guarantee radius.
	var near_patches := 0
	for patch_id in world.patches:
		var patch: Dictionary = world.patches[patch_id]
		var cells: PackedInt32Array = patch["cells"]
		for cell in cells:
			if _chebyshev(world, cell, world.start_cell) <= params.guarantee_radius:
				near_patches += 1
				break
	if near_patches < params.guarantee_min_patches:
		return false

	# ~20 food units inside the guarantee radius.
	var near_food_units := 0
	for cell in world.objects:
		var object_data: Dictionary = world.objects[cell]
		if object_data["type"] == "FOOD" and _chebyshev(world, cell, world.start_cell) <= params.guarantee_radius:
			near_food_units += object_data["units"]
	if near_food_units < params.guarantee_min_food_units:
		return false

	# The start region is not enclosed by massifs.
	return flood_count(world, world.start_cell) >= world.size * world.size / MIN_START_REGION_DIVISOR
