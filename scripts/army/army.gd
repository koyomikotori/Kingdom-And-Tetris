class_name Army
extends RefCounted
## The kingdom's soldiers, stored as a count per unit type.

signal changed

var _counts: Dictionary[StringName, int] = {}


func get_count(unit_id: StringName) -> int:
	return _counts.get(unit_id, 0)


func get_total() -> int:
	var total := 0
	for unit_id in _counts:
		total += _counts[unit_id]
	return total


func add(unit_id: StringName, amount: int = 1) -> void:
	_counts[unit_id] = get_count(unit_id) + amount
	changed.emit()


## Removes up to `amount` soldiers; returns how many were actually removed.
func remove(unit_id: StringName, amount: int = 1) -> int:
	var removed := mini(amount, get_count(unit_id))
	if removed <= 0:
		return 0
	_counts[unit_id] -= removed
	if _counts[unit_id] == 0:
		_counts.erase(unit_id)
	changed.emit()
	return removed


## Total upkeep per turn for the whole army.
func get_upkeep(units: Dictionary[StringName, UnitData]) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for unit_id in _counts:
		var unit: UnitData = units.get(unit_id)
		if unit != null:
			for i in _counts[unit_id]:
				Economy.add_into(total, unit.upkeep)
	return total


## The unit type with the most soldiers (first by id on ties), or &"" when empty.
func get_largest_group() -> StringName:
	var best: StringName = &""
	var ids := _counts.keys()
	ids.sort()
	for unit_id: StringName in ids:
		if best == &"" or _counts[unit_id] > _counts[best]:
			best = unit_id
	return best
