class_name Generals
extends RefCounted
## The kingdom's generals (GDD §8, M11d): up to MAX_GENERALS, one of them the commander; the
## recruitment candidates; wounds; battle bonuses. Owned by KingdomState; takes what it needs as
## arguments (no reference back to the state).

signal changed

enum RecruitResult { OK, NO_ROOM, CANNOT_AFFORD, GONE }

const MAX_GENERALS := 3
const CANDIDATES := 3
## Turns between two new candidate lists.
const CANDIDATE_TURNS := 5
const REFRESH_COST: Dictionary[StringName, int] = {&"food": 20}
const STAT_MIN := 1
const STAT_MAX := 10
## Per point of Võ lực: melee attack and charge.
const MIGHT_ATTACK := 0.03
## Per point of Thống suất: morale, and melee defense / armor.
const COMMAND_MORALE := 0.4
const COMMAND_DEFENSE := 0.02
## The bodyguard fights beside the general: extra attack per Võ lực point and extra defense per
## Thống suất point, on top of the army-wide bonus.
const GUARD_MIGHT_ATTACK := 0.05
const GUARD_COMMAND_DEFENSE := 0.05
## Every unit of the side loses this much morale when the general falls.
const FALL_MORALE_LOSS := 3.0
const DEATH_CHANCE := 0.3
const WOUND_TURNS := 3
const GUARD_UNIT_PATH := "res://data/general_units/general_guard.tres"
const FAMILY_NAMES: Array[String] = ["Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô", "Dương",
		"Đinh", "Mạc", "Phan", "Tôn", "Khúc", "Lạc", "Thạch", "Kiều"]
const MIDDLE_NAMES: Array[String] = ["Văn", "Đức", "Minh", "Quốc", "Hữu", "Công", "Thành", "Bá", "Trọng", "Khắc"]
const GIVEN_NAMES: Array[String] = ["Dũng", "Hùng", "Khải", "Bình", "Sơn", "Hải", "Long", "Thắng", "Kiên", "Phong",
		"Vĩnh", "Trung", "Nghĩa", "Đạt", "Lâm", "Uy", "Hào", "Cường", "Hiển", "Tráng", "Bảo", "Chiến"]

var generals: Array[General] = []
var commander: General
## Generals the player may recruit right now.
var candidates: Array[General] = []
## Turn the candidate list was last made.
var candidates_turn := -100
var ranks: Dictionary[int, GeneralRankData] = GeneralRankData.load_all()
var traits: Dictionary[StringName, GeneralTraitData] = GeneralTraitData.load_all()
var guard_unit: UnitData = load(GUARD_UNIT_PATH)
## Own random numbers, so generals never shift the kingdom's raid, invasion and event rolls.
var rng := RandomNumberGenerator.new()


## A new random general: the total of Võ lực + Thống suất comes from the rank, split at random;
## generals of 2 stars and more get a random trait.
func generate(stars: int) -> General:
	var rank := ranks[clampi(stars, 1, ranks.size())]
	var general := General.new()
	general.stars = rank.stars
	general.name = "%s %s %s" % [FAMILY_NAMES[rng.randi_range(0, FAMILY_NAMES.size() - 1)],
			MIDDLE_NAMES[rng.randi_range(0, MIDDLE_NAMES.size() - 1)], GIVEN_NAMES[rng.randi_range(0, GIVEN_NAMES.size() - 1)]]
	var total := rng.randi_range(rank.total_min, rank.total_max)
	var low := maxi(STAT_MIN, total - STAT_MAX)
	var high := mini(STAT_MAX, total - STAT_MIN)
	general.might = rng.randi_range(low, high)
	general.command = total - general.might
	if general.stars >= 2 and not traits.is_empty():
		var ids: Array[StringName] = []
		ids.assign(traits.keys())
		ids.sort()
		general.trait_id = ids[rng.randi_range(0, ids.size() - 1)]
	return general


## New candidates, each of up to `max_stars` stars (lower stars more likely).
func refresh_candidates(max_stars: int, turn: int) -> void:
	candidates.clear()
	var weights := PackedFloat32Array()
	for stars in range(1, maxi(1, max_stars) + 1):
		weights.append(max_stars - stars + 1)
	for i in CANDIDATES:
		candidates.append(generate(rng.rand_weighted(weights) + 1))
	candidates_turn = turn
	changed.emit()


## Pays to replace the candidates now. Returns false (nothing paid) when it cannot be afforded.
func buy_refresh(stockpile: Stockpile, max_stars: int, turn: int) -> bool:
	if not stockpile.spend(REFRESH_COST):
		return false
	refresh_candidates(max_stars, turn)
	return true


func cost_of(general: General) -> Dictionary[StringName, int]:
	return ranks[general.stars].recruit_cost


func check_recruit(stockpile: Stockpile, index: int) -> RecruitResult:
	if index < 0 or index >= candidates.size():
		return RecruitResult.GONE
	if generals.size() >= MAX_GENERALS:
		return RecruitResult.NO_ROOM
	if not stockpile.can_afford(cost_of(candidates[index])):
		return RecruitResult.CANNOT_AFFORD
	return RecruitResult.OK


## Hires candidate `index`. The first general becomes the commander.
func recruit(stockpile: Stockpile, index: int) -> RecruitResult:
	var result := check_recruit(stockpile, index)
	if result == RecruitResult.OK:
		stockpile.spend(cost_of(candidates[index]))
		add(candidates.pop_at(index))
	return result


## Adds a general (recruited, or from an event). False when there is no room.
func add(general: General) -> bool:
	if generals.size() >= MAX_GENERALS:
		return false
	generals.append(general)
	if commander == null:
		commander = general
	changed.emit()
	return true


func dismiss(general: General) -> void:
	generals.erase(general)
	if commander == general:
		commander = null
	changed.emit()


## Adds one of the general's level points to &"might" (Võ lực) or &"command" (Thống suất).
## False (nothing changes) without points or when that stat is already at STAT_MAX.
func spend_point(general: General, stat: StringName) -> bool:
	if not can_spend_point(general, stat):
		return false
	general.points -= 1
	if stat == &"might":
		general.might += 1
	else:
		general.command += 1
	changed.emit()
	return true


func can_spend_point(general: General, stat: StringName) -> bool:
	if general == null or general.points <= 0:
		return false
	match stat:
		&"might":
			return general.might < STAT_MAX
		&"command":
			return general.command < STAT_MAX
	return false


func set_commander(general: General) -> void:
	if generals.has(general):
		commander = general
		changed.emit()


## The commander when able to fight, or null.
func active_commander() -> General:
	return commander if commander != null and commander.is_ready() else null


func get_upkeep() -> Dictionary[StringName, int]:
	var total: Dictionary[StringName, int] = {}
	for general in generals:
		Economy.add_into(total, ranks[general.stars].upkeep)
	return total


## End of a turn: wounds heal; a new candidate list every CANDIDATE_TURNS turns. Returns the
## generals that recovered this turn.
func end_turn(max_stars: int, turn: int) -> Array[General]:
	var healed: Array[General] = []
	for general in generals:
		if general.wounded_turns > 0:
			general.wounded_turns -= 1
			if general.wounded_turns == 0:
				healed.append(general)
	if turn - candidates_turn >= CANDIDATE_TURNS:
		refresh_candidates(max_stars, turn)
	changed.emit()
	return healed


# --- Battle -------------------------------------------------------------------------------

## The commander's trait, if it works with this territory (and battle side).
func active_trait(general: General, board: BoardData, defending: bool) -> GeneralTraitData:
	var data: GeneralTraitData = traits.get(general.trait_id)
	return data if data != null and data.is_active(board, defending) else null


## Puts the active commander at the head of `side`: their bonuses on every unit of the kingdom's
## own army (not on units lent by allies) and their bodyguard as a unit of its own.
func lead(side: BattleSide, board: BoardData, defending: bool) -> void:
	var general := active_commander()
	if general == null:
		return
	var trait_data := active_trait(general, board, defending)
	side.add_unit(guard_unit, ranks[general.stars].guards)
	var guard: BattleSide.Unit = side.units.back()
	guard.is_general_guard = true
	guard.attack_mult += general.might * GUARD_MIGHT_ATTACK
	guard.charge_mult += general.might * GUARD_MIGHT_ATTACK
	guard.defense_mult += general.command * GUARD_COMMAND_DEFENSE
	side.general_name = general.name
	for unit in side.units:
		if unit.ally != null:
			continue
		unit.attack_mult += general.might * MIGHT_ATTACK
		unit.charge_mult += general.might * MIGHT_ATTACK
		unit.defense_mult += general.command * COMMAND_DEFENSE
		unit.morale += general.command * COMMAND_MORALE
		if trait_data == null or not _trait_applies(trait_data, unit):
			continue
		unit.attack_mult += trait_data.melee_attack_bonus
		unit.charge_mult += trait_data.charge_bonus
		unit.defense_mult += trait_data.defense_bonus
		unit.range_mult += trait_data.range_bonus
		unit.morale += trait_data.morale_bonus


func _trait_applies(trait_data: GeneralTraitData, unit: BattleSide.Unit) -> bool:
	match trait_data.target:
		GeneralTraitData.Target.RANGED:
			return unit.data.is_ranged()
		GeneralTraitData.Target.FRONT_ROW:
			return unit.data.row == UnitData.Row.FRONT
	return true


## After a battle the commander led on `side`: if they fell, DEATH_CHANCE they died, otherwise
## they are wounded for WOUND_TURNS turns. A commander who lives gains battle XP
## (Experience.general_battle_xp, wounded or not).
## Returns {"name", "fate": &"none" | &"dead" | &"wounded", "xp": int, "levels": int}.
func after_battle(record: BattleRecord, side: int) -> Dictionary:
	var battle_side := record.sides[side]
	var general := commander
	if battle_side.general_name.is_empty() or general == null:
		return {"name": "", "fate": &"none", "xp": 0, "levels": 0}
	var fate := &"none"
	if battle_side.general_fallen:
		if rng.randf() < DEATH_CHANCE:
			dismiss(general)
			return {"name": general.name, "fate": &"dead", "xp": 0, "levels": 0}
		general.wounded_turns = WOUND_TURNS
		fate = &"wounded"
	var guard_kills := 0.0
	for unit in battle_side.units:
		if unit.is_general_guard:
			guard_kills += unit.kills
	var xp := Experience.general_battle_xp(guard_kills, record.winner == side)
	var levels := general.gain_xp(xp)
	changed.emit()
	return {"name": general.name, "fate": fate, "xp": xp, "levels": levels}


# --- Save (GDD §10.1) ---------------------------------------------------------------------

func to_save() -> Dictionary:
	var saved: Array = []
	for general in generals:
		saved.append(general.to_save())
	var waiting: Array = []
	for general in candidates:
		waiting.append(general.to_save())
	return {"generals": saved, "commander": generals.find(commander), "candidates": waiting,
			"candidates_turn": candidates_turn}


func load_save(data: Dictionary) -> void:
	generals.clear()
	for entry: Dictionary in data.generals:
		generals.append(General.from_save(entry))
	var index := int(data.commander)
	commander = generals[index] if index >= 0 and index < generals.size() else null
	candidates.clear()
	for entry: Dictionary in data.candidates:
		candidates.append(General.from_save(entry))
	candidates_turn = int(data.candidates_turn)
	changed.emit()
