class_name Stockpile
extends RefCounted
## Resources the kingdom currently holds. Amounts never go below zero.

signal changed

var _amounts: Dictionary[StringName, int] = {}


func get_amount(resource_id: StringName) -> int:
	return _amounts.get(resource_id, 0)


func add(amounts: Dictionary[StringName, int]) -> void:
	for resource_id in amounts:
		assert(amounts[resource_id] >= 0, "Use spend() to remove resources")
		_amounts[resource_id] = get_amount(resource_id) + amounts[resource_id]
	changed.emit()


func can_afford(cost: Dictionary[StringName, int]) -> bool:
	for resource_id in cost:
		if get_amount(resource_id) < cost[resource_id]:
			return false
	return true


## Returns false and changes nothing when the cost cannot be paid in full.
func spend(cost: Dictionary[StringName, int]) -> bool:
	if not can_afford(cost):
		return false
	for resource_id in cost:
		_amounts[resource_id] -= cost[resource_id]
	changed.emit()
	return true
