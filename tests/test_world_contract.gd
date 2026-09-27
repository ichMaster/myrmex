extends GdUnitTestSuite
## Contract: the cell layers (ARCHITECTURE §World model). Pins the terrain
## and structure byte values, the object dictionary shapes, one-object-per-
## cell, the passability rule and cell addressing — the seams worldgen,
## saves and every agent phase stand on.


func test_terrain_byte_values_pinned() -> void:
	assert_int(SimWorld.Terrain.GROUND).is_equal(0)
	assert_int(SimWorld.Terrain.WATER).is_equal(1)
	assert_int(SimWorld.Terrain.HIGHLAND).is_equal(2)
	assert_int(SimWorld.Terrain.WALL).is_equal(3)


func test_structure_byte_values_pinned() -> void:
	assert_int(SimWorld.Structure.NONE).is_equal(0)
	assert_int(SimWorld.Structure.NEST_WALL).is_equal(1)
	assert_int(SimWorld.Structure.PAVEMENT).is_equal(2)
	assert_int(SimWorld.Structure.STORAGE_FOOD).is_equal(3)
	assert_int(SimWorld.Structure.STORAGE_RES).is_equal(4)
	assert_int(SimWorld.Structure.QUEEN_CHAMBER).is_equal(5)


func test_layer_storage_shapes() -> void:
	var world := SimWorld.new(16)
	assert_int(world.terrain.size()).is_equal(256)
	assert_int(world.structures.size()).is_equal(256)
	assert_int(world.known.size()).is_equal(256)
	assert_int(typeof(world.terrain)).is_equal(TYPE_PACKED_BYTE_ARRAY)
	assert_int(typeof(world.structures)).is_equal(TYPE_PACKED_BYTE_ARRAY)
	assert_int(typeof(world.known)).is_equal(TYPE_PACKED_BYTE_ARRAY)
	assert_int(typeof(world.objects)).is_equal(TYPE_DICTIONARY)
	assert_int(typeof(world.agents)).is_equal(TYPE_DICTIONARY)
	assert_bool(world.agents.is_empty()).is_true()


func test_cell_addressing_round_trip() -> void:
	var world := SimWorld.new(16)
	var cell := world.idx(5, 9)
	assert_int(cell).is_equal(5 + 9 * 16)
	assert_int(world.x_of(cell)).is_equal(5)
	assert_int(world.y_of(cell)).is_equal(9)
	assert_bool(world.in_bounds(0, 0)).is_true()
	assert_bool(world.in_bounds(15, 15)).is_true()
	assert_bool(world.in_bounds(-1, 0)).is_false()
	assert_bool(world.in_bounds(0, 16)).is_false()


func test_object_shapes_pinned() -> void:
	var food := SimWorld.make_food(3)
	assert_array(food.keys()).contains_exactly_in_any_order(["type", "units"])
	assert_str(food["type"]).is_equal("FOOD")
	assert_int(food["units"]).is_equal(3)

	var resource := SimWorld.make_resource(7)
	assert_array(resource.keys()).contains_exactly_in_any_order(["type", "patch_id"])
	assert_str(resource["type"]).is_equal("RESOURCE")
	assert_int(resource["patch_id"]).is_equal(7)

	var pile := SimWorld.make_pile("food", 4)
	assert_array(pile.keys()).contains_exactly_in_any_order(["type", "pile", "units"])
	assert_str(pile["type"]).is_equal("PILE")


func test_one_object_per_cell() -> void:
	var world := SimWorld.new(16)
	var cell := world.idx(3, 3)
	assert_bool(world.place_object(cell, SimWorld.make_food(2))).is_true()
	assert_bool(world.place_object(cell, SimWorld.make_resource(0))).is_false()
	assert_str(world.object_at(cell)["type"]).is_equal("FOOD")
	world.remove_object(cell)
	assert_bool(world.object_at(cell).is_empty()).is_true()


func test_passability_rule() -> void:
	var world := SimWorld.new(16)
	assert_bool(world.is_passable(4, 4)).is_true()
	world.terrain[world.idx(4, 4)] = SimWorld.Terrain.WATER
	assert_bool(world.is_passable(4, 4)).is_false()
	world.terrain[world.idx(4, 4)] = SimWorld.Terrain.HIGHLAND
	assert_bool(world.is_passable(4, 4)).is_false()
	world.terrain[world.idx(4, 4)] = SimWorld.Terrain.WALL
	assert_bool(world.is_passable(4, 4)).is_false()
	# Structures: walls and the brood dome block, pavement does not.
	world.terrain[world.idx(4, 4)] = SimWorld.Terrain.GROUND
	world.structures[world.idx(4, 4)] = SimWorld.Structure.NEST_WALL
	assert_bool(world.is_passable(4, 4)).is_false()
	world.structures[world.idx(4, 4)] = SimWorld.Structure.QUEEN_CHAMBER
	assert_bool(world.is_passable(4, 4)).is_false()
	world.structures[world.idx(4, 4)] = SimWorld.Structure.PAVEMENT
	assert_bool(world.is_passable(4, 4)).is_true()
	assert_bool(world.is_passable(-1, 4)).is_false()


func test_state_hash_ignores_insertion_order() -> void:
	var world_a := SimWorld.new(16)
	var world_b := SimWorld.new(16)
	world_a.place_object(10, SimWorld.make_food(1))
	world_a.place_object(20, SimWorld.make_food(2))
	world_b.place_object(20, SimWorld.make_food(2))
	world_b.place_object(10, SimWorld.make_food(1))
	assert_int(world_a.state_hash()).is_equal(world_b.state_hash())
	world_b.remove_object(20)
	assert_int(world_a.state_hash()).is_not_equal(world_b.state_hash())
