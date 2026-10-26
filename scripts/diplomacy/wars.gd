class_name Wars
extends RefCounted
## War and peace between the kingdom and the clans (GDD §9.6): declarations, clan armies that
## regrow over time, invasions, peace talks and annexation. Pure logic, owned by KingdomState.

signal changed

enum DeclareResult { OK, ANNEXED, NOT_NEIGHBOR, ALREADY_AT_WAR, TRUCE }
enum AttackResult { OK, ANNEXED, NOT_AT_WAR, ALREADY_ATTACKED, NO_ARMY }
enum PeaceResult { OK, DECLINED, NOT_AT_WAR, ASKED_THIS_TURN, CANNOT_AFFORD }

## Relation the target drops to (at most) when the player declares war.
const DECLARE_RELATION := -60
const DECLARE_RELATION_DROP := 40
## Every other clan's relation change when the player declares war.
const DECLARE_OTHERS_PENALTY := -5
## Instead of DECLARE_OTHERS_PENALTY for the target's friends (ClanData.friends).
const DECLARE_FRIEND_PENALTY := -15
## Added to every other clan's change when the player breaks a treaty by declaring war (GDD §9.7).
const BETRAY_ALLY_PENALTY := -20
const BREAK_PACT_PENALTY := -10
## Chance per turn that a hostile neighbour declares war, by personality:
## PEACEFUL, AGGRESSIVE, MERCHANT, ISOLATED.
const AI_DECLARE_CHANCE: Array[float] = [0.02, 0.15, 0.05, 0.05]
## Same, for clans that are only Tense: only aggressive clans go to war that early.
const AI_DECLARE_CHANCE_TENSE: Array[float] = [0.0, 0.05, 0.0, 0.0]
const STRENGTH_REGEN_PER_TURN := 2
const INVASION_CHANCE := 0.25
const INVASION_COOLDOWN := 3
## Share of its current soldiers a clan sends to invade.
const INVASION_SHARE := 0.6
## Owned cells lost on the clan's edge when an invasion wins.
const LAND_LOST_PER_DEFEAT := 6
## Share of each resource the invaders carry off when they win (bandits take 30%).
const INVASION_RESOURCE_LOSS := 0.4
## Loot per enemy soldier lost when the player's attack wins.
const LOOT_PER_SOLDIER: Dictionary[StringName, int] = {&"food": 1, &"wood": 1, &"stone": 1}
## Share of each resource paid when the player's attack fails.
const ATTACK_DEFEAT_COMPENSATION := 0.25
## A clan whose army falls below this share of its maximum surrenders and is annexed.
const ANNEX_THRESHOLD := 0.15
## Rows/columns of wild land the kingdom board gains on the annexed clan's side.
const ANNEX_EXPANSION := 4
const PEACE_BASE_CHANCE := 0.1
const PEACE_LOSSES_WEIGHT := 0.8
const PEACE_TRIBUTE_PER_POINT := 100.0
const PEACE_MAX_CHANCE := 0.95
const PEACE_MIN_RELATION := -30
const TRUCE_TURNS := 10


## The kingdom's standing with one clan.
class Front:
	extends RefCounted
	var clan_id: StringName
	var at_war := false
	var annexed := false
	var strength: int
	var max_strength: int
	var truce_turns := 0
	## Which board edge the clan borders; distant clans become neighbours after an annexation.
	var direction: ClanData.Direction
	var turns_since_invasion := 0
	var attacked_this_turn := false
	var peace_offered_this_turn := false

	func is_neighbor() -> bool:
		return direction != ClanData.Direction.NONE and not annexed

	func losses_share() -> float:
		return 1.0 - float(strength) / max_strength if max_strength > 0 else 1.0


var fronts: Dictionary[StringName, Front] = {}
var _diplomacy: Diplomacy


func _init(diplomacy: Diplomacy) -> void:
	_diplomacy = diplomacy
	for clan_id in diplomacy.clans:
		var data := diplomacy.clans[clan_id].data
		var front := Front.new()
		front.clan_id = clan_id
		front.strength = data.military_strength
		front.max_strength = data.military_strength
		front.direction = data.direction
		fronts[clan_id] = front


func at_war_with(clan_id: StringName) -> bool:
	return fronts[clan_id].at_war


# --- Declaring war ------------------------------------------------------------------------

func check_declare(clan_id: StringName) -> DeclareResult:
	var front := fronts[clan_id]
	if front.annexed:
		return DeclareResult.ANNEXED
	if not front.is_neighbor():
		return DeclareResult.NOT_NEIGHBOR
	if front.at_war:
		return DeclareResult.ALREADY_AT_WAR
	if front.truce_turns > 0:
		return DeclareResult.TRUCE
	return DeclareResult.OK


## The player declares war: the target turns hostile and every other clan trusts the kingdom less,
## its friends most. Breaking an alliance or a non-aggression pact costs extra with everyone.
func declare_war(clan_id: StringName) -> DeclareResult:
	var result := check_declare(clan_id)
	if result != DeclareResult.OK:
		return result
	var clan := _diplomacy.clans[clan_id]
	_diplomacy.change_relation(clan_id, mini(clan.relation - DECLARE_RELATION_DROP, DECLARE_RELATION) - clan.relation,
			Diplomacy.MEMORY_WAR)
	for other in _diplomacy.clans:
		if other != clan_id:
			_diplomacy.change_relation(other, declare_penalty(clan_id, other), Diplomacy.MEMORY_AGGRESSION)
	_start_war(clan_id)
	return DeclareResult.OK


## Relation change for `other` if the player declared war on `clan_id` now.
func declare_penalty(clan_id: StringName, other: StringName) -> int:
	var clan := _diplomacy.clans[clan_id]
	var penalty := DECLARE_FRIEND_PENALTY if clan.data.friends.has(other) else DECLARE_OTHERS_PENALTY
	if clan.is_allied():
		penalty += BETRAY_ALLY_PENALTY
	if clan.has_pact():
		penalty += BREAK_PACT_PENALTY
	return penalty


func _start_war(clan_id: StringName) -> void:
	var front := fronts[clan_id]
	front.at_war = true
	front.turns_since_invasion = 0
	_diplomacy.clans[clan_id].alliance_turns = 0
	_diplomacy.clans[clan_id].pact_turns = 0
	_diplomacy.remove_agreement(clan_id)
	changed.emit()


## The clan declares war on the kingdom on its own (an event); false when it cannot right now.
func clan_declares_war(clan_id: StringName) -> bool:
	if check_declare(clan_id) != DeclareResult.OK:
		return false
	_start_war(clan_id)
	return true


## End of turn: armies regrow, truces count down, wars keep relations hostile, and hostile
## neighbours may declare war. Returns the clans that declared war this turn.
func end_turn(rng: RandomNumberGenerator) -> Array[StringName]:
	var declared: Array[StringName] = []
	for clan_id in fronts:
		var front := fronts[clan_id]
		if front.annexed:
			continue
		front.strength = mini(front.max_strength, front.strength + STRENGTH_REGEN_PER_TURN)
		front.truce_turns = maxi(0, front.truce_turns - 1)
		front.turns_since_invasion += 1
		front.attacked_this_turn = false
		front.peace_offered_this_turn = false
		var clan := _diplomacy.clans[clan_id]
		if front.at_war:
			if clan.relation > DECLARE_RELATION:
				_diplomacy.change_relation(clan_id, DECLARE_RELATION - clan.relation, Diplomacy.MEMORY_WAR)
		elif check_declare(clan_id) == DeclareResult.OK and _declare_chance(clan_id) > 0.0 \
				and rng.randf() < _declare_chance(clan_id):
			_start_war(clan_id)
			declared.append(clan_id)
	changed.emit()
	return declared


## Chance this turn that the clan declares war on its own (0 unless Tense or Hostile, and never
## during a non-aggression pact).
func _declare_chance(clan_id: StringName) -> float:
	if _diplomacy.clans[clan_id].has_pact():
		return 0.0
	var personality := _diplomacy.clans[clan_id].data.personality
	match _diplomacy.get_tier(clan_id):
		Diplomacy.Tier.HOSTILE:
			return AI_DECLARE_CHANCE[personality]
		Diplomacy.Tier.TENSE:
			return AI_DECLARE_CHANCE_TENSE[personality]
	return 0.0


# --- Battles ------------------------------------------------------------------------------

## The clan (if any) that invades at the start of this turn; resets its invasion cooldown.
func pick_invader(rng: RandomNumberGenerator) -> StringName:
	var ids := fronts.keys()
	ids.sort()
	for clan_id: StringName in ids:
		var front := fronts[clan_id]
		if front.at_war and front.is_neighbor() and front.strength > 0 \
				and front.turns_since_invasion >= INVASION_COOLDOWN and rng.randf() < INVASION_CHANCE:
			front.turns_since_invasion = 0
			return clan_id
	return &""


func invasion_size(clan_id: StringName) -> int:
	return roundi(fronts[clan_id].strength * INVASION_SHARE)


## The clan's soldiers as battle units, split by its army_units weights into squads.
func create_clan_side(clan_id: StringName, soldiers: int, units: Dictionary[StringName, UnitData]) -> BattleSide:
	var side := BattleSide.new(_diplomacy.clans[clan_id].data.display_name)
	add_clan_units(side, clan_id, soldiers, units)
	return side


## Adds `soldiers` of the clan to `side`. `lent` marks them as sent to help another army
## (BattleSide.Unit.ally), so their losses come out of this clan's strength.
func add_clan_units(side: BattleSide, clan_id: StringName, soldiers: int, units: Dictionary[StringName, UnitData],
		lent: bool = false) -> void:
	var data := _diplomacy.clans[clan_id].data
	var total_weight := 0.0
	for unit_id in data.army_units:
		total_weight += data.army_units[unit_id]
	if total_weight <= 0.0:
		return
	var remaining := soldiers
	var ids := data.army_units.keys()
	for i in ids.size():
		var unit: UnitData = units.get(ids[i])
		if unit == null:
			continue
		var share := remaining if i == ids.size() - 1 else roundi(soldiers * data.army_units[ids[i]] / total_weight)
		share = mini(share, remaining)
		remaining -= share
		while share > 0:
			var squad := mini(share, unit.squad_size)
			side.add_unit(unit, squad, null, data if lent else null)
			share -= squad


func lose_soldiers(clan_id: StringName, amount: int) -> void:
	var front := fronts[clan_id]
	front.strength = maxi(0, front.strength - amount)
	changed.emit()


## `has_army`: whether the kingdom has at least one squad.
func check_attack(clan_id: StringName, has_army: bool) -> AttackResult:
	var front := fronts[clan_id]
	if front.annexed:
		return AttackResult.ANNEXED
	if not front.at_war:
		return AttackResult.NOT_AT_WAR
	if front.attacked_this_turn:
		return AttackResult.ALREADY_ATTACKED
	if not has_army:
		return AttackResult.NO_ARMY
	return AttackResult.OK


func mark_attacked(clan_id: StringName) -> void:
	fronts[clan_id].attacked_this_turn = true
	changed.emit()


# --- Annexation ---------------------------------------------------------------------------

func should_annex(clan_id: StringName) -> bool:
	var front := fronts[clan_id]
	return front.at_war and front.strength < front.max_strength * ANNEX_THRESHOLD


## The clan surrenders and joins the kingdom. Distant clans on its roads become neighbours on
## the same side. Returns the board direction to expand toward.
func annex(clan_id: StringName) -> Vector2i:
	var front := fronts[clan_id]
	front.annexed = true
	front.at_war = false
	_diplomacy.clans[clan_id].annexed = true
	_diplomacy.remove_agreement(clan_id)
	for other in _diplomacy.clans[clan_id].data.roads:
		if fronts.has(other) and not fronts[other].annexed and fronts[other].direction == ClanData.Direction.NONE:
			fronts[other].direction = front.direction
	changed.emit()
	return ClanData.direction_vector(front.direction)


# --- Peace --------------------------------------------------------------------------------

func peace_chance(clan_id: StringName, tribute: Dictionary[StringName, int]) -> float:
	var front := fronts[clan_id]
	var chance := PEACE_BASE_CHANCE + PEACE_LOSSES_WEIGHT * front.losses_share() \
			+ _diplomacy.clans[clan_id].relation / 200.0 + _diplomacy.value_of(tribute) / PEACE_TRIBUTE_PER_POINT \
			+ _diplomacy.envoy * Diplomacy.ENVOY_CHANCE
	return clampf(chance, 0.0, PEACE_MAX_CHANCE)


func check_peace(stockpile: Stockpile, clan_id: StringName, tribute: Dictionary[StringName, int]) -> PeaceResult:
	var front := fronts[clan_id]
	if not front.at_war:
		return PeaceResult.NOT_AT_WAR
	if front.peace_offered_this_turn:
		return PeaceResult.ASKED_THIS_TURN
	if not stockpile.can_afford(tribute):
		return PeaceResult.CANNOT_AFFORD
	return PeaceResult.OK


## Offers peace (with optional tribute, paid only if accepted). Accepting ends the war, lifts the
## relation to at least Tense and starts a truce. One offer per clan per turn.
func propose_peace(rng: RandomNumberGenerator, stockpile: Stockpile, clan_id: StringName,
		tribute: Dictionary[StringName, int]) -> PeaceResult:
	var result := check_peace(stockpile, clan_id, tribute)
	if result != PeaceResult.OK:
		return result
	var front := fronts[clan_id]
	front.peace_offered_this_turn = true
	if rng.randf() >= peace_chance(clan_id, tribute):
		changed.emit()
		return PeaceResult.DECLINED
	stockpile.spend(tribute)
	front.at_war = false
	front.truce_turns = TRUCE_TURNS
	var relation := _diplomacy.clans[clan_id].relation
	if relation < PEACE_MIN_RELATION:
		_diplomacy.change_relation(clan_id, PEACE_MIN_RELATION - relation, Diplomacy.MEMORY_WAR)
	changed.emit()
	return PeaceResult.OK


static func describe_declare(result: DeclareResult) -> String:
	match result:
		DeclareResult.OK:
			return "Đã tuyên chiến!"
		DeclareResult.ANNEXED:
			return "Gia tộc này đã bị sáp nhập."
		DeclareResult.NOT_NEIGHBOR:
			return "Không giáp biên, chưa thể gây chiến."
		DeclareResult.ALREADY_AT_WAR:
			return "Đang chiến tranh."
		DeclareResult.TRUCE:
			return "Đang trong thời gian đình chiến."
	return ""


static func describe_attack(result: AttackResult) -> String:
	match result:
		AttackResult.OK:
			return "Sẵn sàng tấn công."
		AttackResult.ANNEXED:
			return "Gia tộc này đã bị sáp nhập."
		AttackResult.NOT_AT_WAR:
			return "Phải tuyên chiến trước khi tấn công."
		AttackResult.ALREADY_ATTACKED:
			return "Lượt này đã tấn công họ rồi."
		AttackResult.NO_ARMY:
			return "Bạn không có quân để tấn công."
	return ""


static func describe_peace(result: PeaceResult) -> String:
	match result:
		PeaceResult.OK:
			return "Họ chấp nhận nghị hòa! Đình chiến %d lượt." % TRUCE_TURNS
		PeaceResult.DECLINED:
			return "Họ từ chối nghị hòa. Hãy thử lại vào lượt sau."
		PeaceResult.NOT_AT_WAR:
			return "Không có chiến tranh."
		PeaceResult.ASKED_THIS_TURN:
			return "Lượt này đã đề nghị hòa rồi."
		PeaceResult.CANNOT_AFFORD:
			return "Không đủ tài nguyên để bồi thường."
	return ""


# --- Save (GDD §10.1) ---------------------------------------------------------------------

## Front fields written as they are (ints, bools and the direction enum). max_strength comes
## from the clan data so rebalancing applies to old saves.
const SAVED_FRONT_FIELDS: Array[StringName] = [&"at_war", &"annexed", &"strength", &"truce_turns", &"direction",
		&"turns_since_invasion", &"attacked_this_turn", &"peace_offered_this_turn"]


func to_save() -> Dictionary:
	var result := {}
	for clan_id in fronts:
		var entry := {}
		for field in SAVED_FRONT_FIELDS:
			entry[String(field)] = fronts[clan_id].get(field)
		result[String(clan_id)] = entry
	return result


func load_save(data: Dictionary) -> void:
	for clan_name: String in data:
		var front: Front = fronts.get(StringName(clan_name))
		if front == null:
			continue
		var entry: Dictionary = data[clan_name]
		for field in SAVED_FRONT_FIELDS:
			if entry.has(String(field)):
				front.set(field, Diplomacy._plain(entry[String(field)], front.get(field)))
		front.strength = mini(front.strength, front.max_strength)
	changed.emit()
