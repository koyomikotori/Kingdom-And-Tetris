class_name UiFormat
extends RefCounted
## Shared text formatting for the UI.


## "+2 Lương thực, -1 Gỗ" in `types` order; zero amounts are skipped.
static func amounts(values: Dictionary[StringName, int], types: Array[ResourceTypeData], signed: bool = false) -> String:
	var parts: Array[String] = []
	for type in types:
		var amount: int = values.get(type.resource_id, 0)
		if amount != 0:
			parts.append(("%+d %s" if signed else "%d %s") % [amount, type.display_name])
	return ", ".join(parts)
