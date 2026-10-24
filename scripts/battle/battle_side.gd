class_name BattleSide
extends RefCounted
## One army in a battle: a list of battle units, one per squad.


class Unit:
	extends RefCounted
	var data: UnitData
	## The kingdom squad this unit came from, or null (bandits, test armies).
	var squad: Army.Squad
	var start_soldiers: int
	## Fractional while casualties accumulate; alive() rounds up.
	var soldiers: float
	var morale: float
	var broken := false
	var has_charged := false
	var has_fired := false
	var next_volley_at := 0.0
	## Enemy soldiers this unit has taken down.
	var kills := 0.0
	## How many 25% casualty steps have already cost morale.
	var morale_steps := 0

	func _init(p_data: UnitData, count: int, p_squad: Army.Squad) -> void:
		data = p_data
		squad = p_squad
		start_soldiers = count
		soldiers = count
		morale = p_data.morale

	func alive() -> int:
		return ceili(soldiers - 0.0001) if soldiers > 0.0 else 0

	func lost() -> int:
		return start_soldiers - alive()

	## Still fighting: has soldiers and has not broken.
	func is_active() -> bool:
		return not broken and alive() > 0


var display_name: String
var units: Array[Unit] = []


func _init(p_display_name: String) -> void:
	display_name = p_display_name


## Adds a unit; counts of 0 or less are ignored.
func add_unit(data: UnitData, soldiers: int, squad: Army.Squad = null) -> void:
	if soldiers > 0:
		units.append(Unit.new(data, soldiers, squad))


func active_units() -> Array[Unit]:
	return units.filter(func(u: Unit) -> bool: return u.is_active())


func alive_total() -> int:
	var total := 0
	for unit in units:
		total += unit.alive()
	return total


func start_total() -> int:
	var total := 0
	for unit in units:
		total += unit.start_soldiers
	return total


func fraction_alive() -> float:
	var start := start_total()
	return float(alive_total()) / start if start > 0 else 0.0


## The front-most row that still has active units, or -1 when none.
func front_row() -> int:
	var best := -1
	for unit in active_units():
		if best == -1 or unit.data.row < best:
			best = unit.data.row
	return best
