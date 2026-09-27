class_name SimWorld
extends RefCounted
## The world as layered arrays (ARCHITECTURE §World model). Each cell is a
## stack: terrain byte, structure byte, at most one object, at most one
## agent, and a per-nest knowledge byte. Pure data — no Node, no scene; cell
## index is x + y * size. v0: 256x256, no chunks, the whole world is awake.

## Terrain layer. GROUND is passable; WATER, HIGHLAND (mountain massifs) and
## WALL (rock) are impassable to all. Byte values are a pinned contract.
enum Terrain { GROUND = 0, WATER = 1, HIGHLAND = 2, WALL = 3 }

## Structure layer. Byte values are a pinned contract. NEST_WALL blocks
## movement; the QUEEN_CHAMBER (brood dome) occupies its cell — the queen
## stands beside it, never on it.
enum Structure {
	NONE = 0,
	NEST_WALL = 1,
	PAVEMENT = 2,
	STORAGE_FOOD = 3,
	STORAGE_RES = 4,
	QUEEN_CHAMBER = 5,
}

var size: int
## The nest's founding cell — the centre of the largest ground region.
var start_cell: int = -1

var terrain := PackedByteArray()
var structures := PackedByteArray()
## Sparse cell -> object. Object shapes (pinned):
##   {"type": "FOOD", "units": int}
##   {"type": "RESOURCE", "patch_id": int}
##   {"type": "PILE", "pile": String, "units": int}
var objects: Dictionary = {}
## Sparse cell -> agent_id. Empty until v0.3.
var agents: Dictionary = {}
## Knowledge for the one v0 nest: 0 unknown, 1 known.
var known := PackedByteArray()
## Patch registry: patch_id -> {"cells": PackedInt32Array, "reserve": int,
## "depleted_at": int} (-1 while the reserve is above zero).
var patches: Dictionary = {}


func _init(world_size: int) -> void:
	size = world_size
	var cell_count := size * size
	terrain.resize(cell_count)
	structures.resize(cell_count)
	known.resize(cell_count)


# --- Cell addressing ----------------------------------------------------------

func idx(x: int, y: int) -> int:
	return x + y * size


func x_of(cell: int) -> int:
	return cell % size


func y_of(cell: int) -> int:
	return cell / size


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


# --- Layers ---------------------------------------------------------------------

func terrain_at(cell: int) -> int:
	return terrain[cell]


func structure_at(cell: int) -> int:
	return structures[cell]


## Passable = in bounds, GROUND, and no blocking structure. Movement and
## worldgen both route through this single query.
func is_passable(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var cell := idx(x, y)
	if terrain[cell] != Terrain.GROUND:
		return false
	var s := structures[cell]
	return s != Structure.NEST_WALL and s != Structure.QUEEN_CHAMBER


# --- Objects (at most one per cell) ---------------------------------------------

func object_at(cell: int) -> Dictionary:
	return objects.get(cell, {})


## Places an object; refuses (false) when the cell is already occupied —
## the one-object-per-cell rule is enforced here, not by callers.
func place_object(cell: int, object_data: Dictionary) -> bool:
	if objects.has(cell):
		return false
	objects[cell] = object_data
	return true


func remove_object(cell: int) -> void:
	objects.erase(cell)


static func make_food(units: int) -> Dictionary:
	return {"type": "FOOD", "units": units}


static func make_resource(patch_id: int) -> Dictionary:
	return {"type": "RESOURCE", "patch_id": patch_id}


static func make_pile(pile: String, units: int) -> Dictionary:
	return {"type": "PILE", "pile": pile, "units": units}


## Total food units lying in the world (FOOD objects only).
func total_food_units() -> int:
	var total := 0
	for cell in objects:
		var object_data: Dictionary = objects[cell]
		if object_data["type"] == "FOOD":
			total += object_data["units"]
	return total


# --- State hash -------------------------------------------------------------------

## Deterministic hash over every layer, with sparse dictionaries flattened
## in sorted-key order so insertion history never leaks into the hash. The
## sim-level hash (clock + rng) builds on top of this one.
func state_hash() -> int:
	var object_canon := []
	var object_cells := objects.keys()
	object_cells.sort()
	for cell in object_cells:
		var object_data: Dictionary = objects[cell]
		var field_names := object_data.keys()
		field_names.sort()
		var fields := []
		for field in field_names:
			fields.append([field, object_data[field]])
		object_canon.append([cell, fields])

	var agent_canon := []
	var agent_cells := agents.keys()
	agent_cells.sort()
	for cell in agent_cells:
		agent_canon.append([cell, agents[cell]])

	var patch_canon := []
	var patch_ids := patches.keys()
	patch_ids.sort()
	for patch_id in patch_ids:
		var patch: Dictionary = patches[patch_id]
		patch_canon.append([patch_id, patch["cells"], patch["reserve"], patch["depleted_at"]])

	return hash([
		size, start_cell, terrain, structures, known,
		object_canon, agent_canon, patch_canon,
	])
