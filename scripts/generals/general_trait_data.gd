class_name GeneralTraitData
extends Resource
## A general's trait (GDD §8, M11d): a battle bonus that only works while the kingdom meets its
## condition. One .tres per trait in data/traits/. Conditions left at their defaults are not checked.

enum Target { ALL, RANGED, FRONT_ROW }

@export var trait_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Condition")
## Owned cells of this terrain needed (with `min_cells`).
@export var terrain_id: StringName = &""
@export var min_cells: int = 0
## Buildings of this type needed (with `min_buildings`).
@export var building_id: StringName = &""
@export var min_buildings: int = 0
## Only in battles the kingdom defends (raids, invasions).
@export var defending_only: bool = false

@export_group("Effect")
@export var target: Target = Target.ALL
## Multipliers added on top of 1.0 (0.25 = +25%).
@export var melee_attack_bonus: float = 0.0
@export var charge_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var range_bonus: float = 0.0
@export var morale_bonus: float = 0.0


static func load_all() -> Dictionary[StringName, GeneralTraitData]:
	var result: Dictionary[StringName, GeneralTraitData] = {}
	result.assign(DataLibrary.load_folder("res://data/traits/", &"trait_id"))
	return result


## Whether the kingdom meets the condition right now.
func is_active(board: BoardData, defending: bool) -> bool:
	if terrain_id != &"" and board.count_owned_terrain(terrain_id) < min_cells:
		return false
	if building_id != &"" and board.count_buildings(building_id) < min_buildings:
		return false
	return defending or not defending_only


## Plain-language condition, for the UI.
func describe_condition(terrains: Dictionary[StringName, TerrainData], buildings: Dictionary[StringName, BuildingData]) -> String:
	if terrain_id != &"":
		var terrain: TerrainData = terrains.get(terrain_id)
		return "Cần từ %d ô %s" % [min_cells, terrain.display_name.to_lower() if terrain != null else String(terrain_id)]
	if building_id != &"":
		var building: BuildingData = buildings.get(building_id)
		return "Cần từ %d %s" % [min_buildings, building.display_name.to_lower() if building != null else String(building_id)]
	if defending_only:
		return "Khi phòng thủ"
	return "Luôn có tác dụng"
