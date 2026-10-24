class_name BattleSide
extends RefCounted
## One army in a battle: a list of groups, one per unit type. Soldiers are tracked as a
## shared HP pool per group, so a group of 10 swordsmen with 950 HP has 10 soldiers alive.


class Group:
	extends RefCounted
	var unit: UnitData
	var start_count: int
	var hp: float
	var damage_dealt: float = 0.0

	func _init(p_unit: UnitData, count: int) -> void:
		unit = p_unit
		start_count = count
		hp = float(count * p_unit.max_hp)

	## Soldiers still standing. A partly damaged soldier still counts.
	func alive() -> int:
		if hp <= 0.0:
			return 0
		return ceili(hp / unit.max_hp - 0.0001)

	func lost() -> int:
		return start_count - alive()


var display_name: String
var groups: Array[Group] = []


func _init(p_display_name: String) -> void:
	display_name = p_display_name


## Adds a group; counts of 0 or less are ignored.
func add_group(unit: UnitData, count: int) -> void:
	if count > 0:
		groups.append(Group.new(unit, count))


func alive_total() -> int:
	var total := 0
	for group in groups:
		total += group.alive()
	return total


func start_total() -> int:
	var total := 0
	for group in groups:
		total += group.start_count
	return total


func fraction_alive() -> float:
	var start := start_total()
	return float(alive_total()) / start if start > 0 else 0.0


func has_attack_kind(kind: UnitData.AttackKind) -> bool:
	for group in groups:
		if group.alive() > 0 and group.unit.attack_kind == kind:
			return true
	return false
