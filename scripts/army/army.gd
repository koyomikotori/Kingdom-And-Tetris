class_name Army
extends RefCounted
## The kingdom's soldiers as a list of squads. Each recruitment adds one squad; a squad keeps
## its own soldier count after battles (GDD §7.6).

signal changed


class Squad:
	extends RefCounted
	var unit_id: StringName
	var soldiers: int

	func _init(p_unit_id: StringName, p_soldiers: int) -> void:
		unit_id = p_unit_id
		soldiers = p_soldiers


var squads: Array[Squad] = []


func add_squad(unit_id: StringName, soldiers: int) -> void:
	if soldiers > 0:
		squads.append(Squad.new(unit_id, soldiers))
		changed.emit()


## Sets a squad's soldier count; squads that reach 0 are removed.
func set_soldiers(squad: Squad, soldiers: int) -> void:
	squad.soldiers = maxi(0, soldiers)
	if squad.soldiers == 0:
		squads.erase(squad)
	changed.emit()


func remove_squad(squad: Squad) -> void:
	squads.erase(squad)
	changed.emit()


func count_squads(unit_id: StringName = &"") -> int:
	if unit_id == &"":
		return squads.size()
	return squads.filter(func(s: Squad) -> bool: return s.unit_id == unit_id).size()


func count_soldiers(unit_id: StringName = &"") -> int:
	var total := 0
	for squad in squads:
		if unit_id == &"" or squad.unit_id == unit_id:
			total += squad.soldiers
	return total


## Total upkeep per turn: each squad pays its unit's upkeep.
func get_upkeep(units: Dictionary[StringName, UnitData]) -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for squad in squads:
		var unit: UnitData = units.get(squad.unit_id)
		if unit != null:
			Economy.add_into(total, unit.upkeep)
	return total
