class_name SimClock
extends RefCounted
## The day-cycle clock (ARCHITECTURE §Time and the tick): a tick counter and
## the day/phase state derived from it. The clock only counts ticks it is
## given — pause, single-step and speed multipliers live in the runner, and
## nothing here touches the wall clock. Pure data: no Node, no scene.

enum Phase { DAY, DUSK, NIGHT, DAWN }

const PHASE_NAMES: PackedStringArray = ["day", "dusk", "night", "dawn"]

## Total ticks elapsed since world start. Tick 0 is the first tick of day 1.
var tick: int = 0

var _day_ticks: int
var _dusk_ticks: int
var _night_ticks: int
var _dawn_ticks: int
var _cycle_ticks: int


func _init(params: SimParams) -> void:
	_day_ticks = params.day_ticks
	_dusk_ticks = params.dusk_ticks
	_night_ticks = params.night_ticks
	_dawn_ticks = params.dawn_ticks
	_cycle_ticks = _day_ticks + _dusk_ticks + _night_ticks + _dawn_ticks


func advance() -> void:
	tick += 1


## Day number, starting at 1.
func day() -> int:
	return tick / _cycle_ticks + 1


## Tick position inside the current day: 0.._cycle_ticks-1.
func tick_in_day() -> int:
	return tick % _cycle_ticks


## With the default 600/60/400/60 cycle the boundaries land exactly at
## 600 (dusk), 660 (night), 1060 (dawn) and 1120 (day rollover).
func phase() -> Phase:
	var t := tick_in_day()
	if t < _day_ticks:
		return Phase.DAY
	if t < _day_ticks + _dusk_ticks:
		return Phase.DUSK
	if t < _day_ticks + _dusk_ticks + _night_ticks:
		return Phase.NIGHT
	return Phase.DAWN


func phase_name() -> String:
	return PHASE_NAMES[phase()]


## True exactly once per day, on the first tick of DAWN — the autosave edge.
func is_dawn_tick() -> bool:
	return tick_in_day() == _day_ticks + _dusk_ticks + _night_ticks


func ticks_to_next_phase() -> int:
	var t := tick_in_day()
	if t < _day_ticks:
		return _day_ticks - t
	if t < _day_ticks + _dusk_ticks:
		return _day_ticks + _dusk_ticks - t
	if t < _day_ticks + _dusk_ticks + _night_ticks:
		return _day_ticks + _dusk_ticks + _night_ticks - t
	return _cycle_ticks - t


## Plain-types snapshot for saves.
func export_state() -> Dictionary:
	return {"tick": tick}


func import_state(state: Dictionary) -> void:
	tick = int(state["tick"])
