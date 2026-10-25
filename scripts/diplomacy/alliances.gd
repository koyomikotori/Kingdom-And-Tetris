class_name Alliances
extends RefCounted
## Alliances and non-aggression pacts with the clans (GDD §9.7), and the soldiers clans lend to
## each other's battles: the kingdom's allies join its battles, a clan's friends defend it when
## the kingdom attacks. Treaty state lives on Diplomacy.ClanState. Pure logic, owned by KingdomState.

enum AllianceResult { OK, DECLINED, ANNEXED, AT_WAR, NOT_CLOSE, ALREADY_ALLIED, COOLDOWN }
enum PactResult { OK, ANNEXED, AT_WAR, NOT_FRIENDLY, ALREADY_HAS }

const ALLIANCE_TURNS := 20
## A running alliance can be renewed during its last turns, before its relation bonus is lost.
const ALLIANCE_RENEW_TURNS := 5
const ALLIANCE_MIN_TIER := Diplomacy.Tier.CLOSE
## The alliance falls apart when the relation drops below this tier.
const ALLIANCE_KEEP_TIER := Diplomacy.Tier.FRIENDLY
## Acceptance chance = BASE + (relation - 60) / RELATION_SCALE + personality - threat / THREAT_SCALE.
const ALLIANCE_BASE_CHANCE := 0.3
const ALLIANCE_RELATION_SCALE := 80.0
const ALLIANCE_THREAT_SCALE := 200.0
const ALLIANCE_MAX_CHANCE := 0.95
const ALLIANCE_RETRY_TURNS := 3
const ALLIANCE_CANCEL_PENALTY := 30
const PACT_TURNS := 10
const PACT_MIN_TIER := Diplomacy.Tier.FRIENDLY
## Share of its current soldiers a clan lends to a battle.
const HELP_SHARE := 0.3
## A clan below this share of its maximum strength keeps its soldiers at home.
const HELP_MIN_STRENGTH := 0.3
const SHARED_WIN_GAIN := 5
const SHARED_LOSS_PENALTY := 10

var _diplomacy: Diplomacy
var _wars: Wars


func _init(diplomacy: Diplomacy, wars: Wars) -> void:
	_diplomacy = diplomacy
	_wars = wars


func allies() -> Array[StringName]:
	var result: Array[StringName] = []
	for clan_id in _sorted_ids():
		if _diplomacy.clans[clan_id].is_allied():
			result.append(clan_id)
	return result


# --- Alliance -----------------------------------------------------------------------------

func alliance_chance(clan_id: StringName) -> float:
	var clan := _diplomacy.clans[clan_id]
	var chance := ALLIANCE_BASE_CHANCE + (clan.relation - Diplomacy.TIER_THRESHOLDS[Diplomacy.Tier.CLOSE - 1]) \
			/ ALLIANCE_RELATION_SCALE + Diplomacy.AGREEMENT_PERSONALITY[clan.data.personality] \
			- _diplomacy.threat / ALLIANCE_THREAT_SCALE
	return clampf(chance, 0.0, ALLIANCE_MAX_CHANCE)


func check_alliance(clan_id: StringName) -> AllianceResult:
	var clan := _diplomacy.clans[clan_id]
	if clan.annexed:
		return AllianceResult.ANNEXED
	if _wars.at_war_with(clan_id):
		return AllianceResult.AT_WAR
	if clan.alliance_turns > ALLIANCE_RENEW_TURNS:
		return AllianceResult.ALREADY_ALLIED
	if _diplomacy.get_tier(clan_id) < ALLIANCE_MIN_TIER:
		return AllianceResult.NOT_CLOSE
	if clan.alliance_cooldown > 0:
		return AllianceResult.COOLDOWN
	return AllianceResult.OK


## Offers an alliance, or renews one in its last ALLIANCE_RENEW_TURNS turns (for another
## ALLIANCE_TURNS); the clan accepts with alliance_chance(). A refusal blocks new offers for
## ALLIANCE_RETRY_TURNS turns.
func propose_alliance(rng: RandomNumberGenerator, clan_id: StringName) -> AllianceResult:
	var result := check_alliance(clan_id)
	if result != AllianceResult.OK:
		return result
	var clan := _diplomacy.clans[clan_id]
	if rng.randf() >= alliance_chance(clan_id):
		clan.alliance_cooldown = ALLIANCE_RETRY_TURNS
		_diplomacy.changed.emit()
		return AllianceResult.DECLINED
	clan.alliance_turns = ALLIANCE_TURNS
	_diplomacy.changed.emit()
	return AllianceResult.OK


## The player breaks the alliance: big relation penalty.
func cancel_alliance(clan_id: StringName) -> void:
	var clan := _diplomacy.clans[clan_id]
	if not clan.is_allied():
		return
	clan.alliance_turns = 0
	_diplomacy.change_relation(clan_id, -ALLIANCE_CANCEL_PENALTY, Diplomacy.MEMORY_TREATY)


# --- Non-aggression pact ------------------------------------------------------------------

func check_pact(clan_id: StringName) -> PactResult:
	var clan := _diplomacy.clans[clan_id]
	if clan.annexed:
		return PactResult.ANNEXED
	if _wars.at_war_with(clan_id):
		return PactResult.AT_WAR
	if clan.has_pact():
		return PactResult.ALREADY_HAS
	if _diplomacy.get_tier(clan_id) < PACT_MIN_TIER:
		return PactResult.NOT_FRIENDLY
	return PactResult.OK


## Friendly clans always sign: no war declarations from them for PACT_TURNS turns.
func sign_pact(clan_id: StringName) -> PactResult:
	var result := check_pact(clan_id)
	if result == PactResult.OK:
		_diplomacy.clans[clan_id].pact_turns = PACT_TURNS
		_diplomacy.changed.emit()
	return result


## Treaties count down; an alliance falls apart once the relation drops below Friendly.
## Returns one entry per change: {"clan_id", "event": &"alliance_expired" | &"alliance_broken" |
## &"pact_expired"}.
func end_turn() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for clan_id in _sorted_ids():
		var clan := _diplomacy.clans[clan_id]
		if clan.annexed:
			continue
		clan.alliance_cooldown = maxi(0, clan.alliance_cooldown - 1)
		if clan.is_allied():
			if _diplomacy.get_tier(clan_id) < ALLIANCE_KEEP_TIER:
				clan.alliance_turns = 0
				events.append({"clan_id": clan_id, "event": &"alliance_broken"})
			else:
				clan.alliance_turns -= 1
				if clan.alliance_turns == 0:
					events.append({"clan_id": clan_id, "event": &"alliance_expired"})
		if clan.has_pact():
			clan.pact_turns -= 1
			if clan.pact_turns == 0:
				events.append({"clan_id": clan_id, "event": &"pact_expired"})
	_diplomacy.changed.emit()
	return events


# --- Lent soldiers ------------------------------------------------------------------------

func help_size(clan_id: StringName) -> int:
	var front := _wars.fronts[clan_id]
	if front.annexed or front.strength < front.max_strength * HELP_MIN_STRENGTH:
		return 0
	return roundi(front.strength * HELP_SHARE)


## Allies that join the kingdom against `enemy_clan` (&"" for bandits): not the enemy's friends.
func helping_allies(enemy_clan: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for clan_id in allies():
		var friend_of_enemy := enemy_clan != &"" and _diplomacy.clans[enemy_clan].data.friends.has(clan_id)
		if clan_id != enemy_clan and not friend_of_enemy and _diplomacy.get_tier(clan_id) >= ALLIANCE_KEEP_TIER \
				and help_size(clan_id) > 0:
			result.append(clan_id)
	return result


## Friends of `target` that defend it against the kingdom, unless allied or at peace by pact with it.
func helping_friends(target: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for clan_id in _diplomacy.clans[target].data.friends:
		var clan: Diplomacy.ClanState = _diplomacy.clans.get(clan_id)
		if clan != null and clan_id != target and not clan.is_allied() and not clan.has_pact() \
				and help_size(clan_id) > 0:
			result.append(clan_id)
	return result


func add_allies(side: BattleSide, enemy_clan: StringName, units: Dictionary[StringName, UnitData]) -> void:
	for clan_id in helping_allies(enemy_clan):
		_wars.add_clan_units(side, clan_id, help_size(clan_id), units, true)


func add_friends(side: BattleSide, target: StringName, units: Dictionary[StringName, UnitData]) -> void:
	for clan_id in helping_friends(target):
		_wars.add_clan_units(side, clan_id, help_size(clan_id), units, true)


## After a battle: every lending clan loses the soldiers it lost; the kingdom's allies like it more
## after a shared win and less after a shared defeat.
## Returns {"allies": clan_id -> {"sent", "lost", "relation"}, "helpers": clan_id -> {"sent", "lost"}}
## (helpers = the enemy's friends).
func apply_battle(record: BattleRecord, kingdom_side: int) -> Dictionary:
	var won := record.winner == kingdom_side
	var allied := BattleOutcome.ally_losses(record, kingdom_side)
	var helpers := BattleOutcome.ally_losses(record, 1 - kingdom_side)
	for clan_id in allied:
		_wars.lose_soldiers(clan_id, allied[clan_id].lost)
		var change := SHARED_WIN_GAIN if won else -SHARED_LOSS_PENALTY
		_diplomacy.change_relation(clan_id, change, Diplomacy.MEMORY_BATTLE)
		allied[clan_id]["relation"] = change
	for clan_id in helpers:
		_wars.lose_soldiers(clan_id, helpers[clan_id].lost)
	return {"allies": allied, "helpers": helpers}


func _sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_diplomacy.clans.keys())
	ids.sort()
	return ids


static func describe_alliance(result: AllianceResult) -> String:
	match result:
		AllianceResult.OK:
			return "Họ đồng ý liên minh! Thời hạn %d lượt." % ALLIANCE_TURNS
		AllianceResult.DECLINED:
			return "Họ từ chối liên minh. Có thể đề nghị lại sau %d lượt." % ALLIANCE_RETRY_TURNS
		AllianceResult.ANNEXED:
			return "Gia tộc này đã bị sáp nhập."
		AllianceResult.AT_WAR:
			return "Đang chiến tranh, phải nghị hòa trước."
		AllianceResult.NOT_CLOSE:
			return "Cần quan hệ Thân thiết (≥ %d) để liên minh." % Diplomacy.TIER_THRESHOLDS[Diplomacy.Tier.CLOSE - 1]
		AllianceResult.ALREADY_ALLIED:
			return "Đang liên minh."
		AllianceResult.COOLDOWN:
			return "Họ vừa từ chối, cần thêm thời gian cân nhắc."
	return ""


static func describe_pact(result: PactResult) -> String:
	match result:
		PactResult.OK:
			return "Đã ký hiệp ước bất tương xâm %d lượt." % PACT_TURNS
		PactResult.ANNEXED:
			return "Gia tộc này đã bị sáp nhập."
		PactResult.AT_WAR:
			return "Đang chiến tranh, phải nghị hòa trước."
		PactResult.ALREADY_HAS:
			return "Đang có hiệp ước bất tương xâm."
		PactResult.NOT_FRIENDLY:
			return "Cần quan hệ Thân thiện (≥ %d) để ký bất tương xâm." % Diplomacy.TIER_THRESHOLDS[Diplomacy.Tier.FRIENDLY - 1]
	return ""
