class_name Diplomacy
extends RefCounted
## Relations, gifts, one-off trades and long-term trade agreements with the clans (GDD §9).
## Pure logic, owned by KingdomState.

signal changed

enum Tier { HOSTILE, TENSE, NEUTRAL, FRIENDLY, CLOSE }
enum GiftResult { OK, EMPTY, CANNOT_AFFORD, LIMIT_REACHED }
enum TradeResult { OK, REFUSED, SAME_RESOURCE, EMPTY, CANNOT_AFFORD, OVER_CAPACITY, TOO_SMALL }
## OK = the clan signed. DECLINED = valid offer, but the clan said no.
enum ProposalResult { OK, DECLINED, REFUSED, SAME_RESOURCE, EMPTY, TOO_LARGE, BAD_DURATION, ALREADY_HAS, ASKED_THIS_TURN }

const TIER_NAMES: Array[String] = ["Thù địch", "Căng thẳng", "Trung lập", "Thân thiện", "Thân thiết"]
## Lowest relation of each tier above HOSTILE.
const TIER_THRESHOLDS: Array[int] = [-59, -19, 20, 60]
const MIN_RELATION := -100
const MAX_RELATION := 100

## Relation points per turn moved back toward the clan's base relation, by personality.
const DRIFT_PER_TURN: Array[int] = [2, 3, 2, 1]  # PEACEFUL, AGGRESSIVE, MERCHANT, ISOLATED
## Gift value per relation point before the personality multiplier.
const GIFT_VALUE_PER_POINT := 5
const GIFT_MULTIPLIER: Array[float] = [1.5, 0.6, 1.0, 0.5]
const MAX_GIFT_GAIN_PER_TURN := 15
const TRADE_RELATION_GAIN := 1
const MAX_TRADE_GAIN_PER_TURN := 3
## Total value of goods a clan accepts from the player per turn (stops buy-here-sell-there loops).
const TRADE_CAPACITY_PER_TURN := 40
## Clans below this tier refuse to trade.
const MIN_TRADE_TIER := Tier.NEUTRAL

const BASE_PRICE := 0.6
const RELATION_PRICE := 0.2
const MERCHANT_BONUS := 0.15
const DEFICIT_BONUS := 1.4
const SURPLUS_BONUS := 1.3
const DISTANT_PENALTY := 0.85

# Long-term trade agreements (GDD §9.5).
const AGREEMENT_MIN_TURNS := 5
const AGREEMENT_MAX_TURNS := 30
## Most value the player may give per turn under one agreement.
const AGREEMENT_MAX_VALUE := 30
const AGREEMENT_SIGN_GAIN := 8
const AGREEMENT_TURN_GAIN := 1
const AGREEMENT_COMPLETE_GAIN := 3
const AGREEMENT_MISSED_PENALTY := 3
const AGREEMENT_CANCEL_PENALTY := 20
## While an agreement runs, the clan's relation drifts toward base + this instead of base.
const AGREEMENT_BASE_BONUS := 15
const AGREEMENT_MAX_CHANCE := 0.95
## Added to the acceptance chance, by personality: PEACEFUL, AGGRESSIVE, MERCHANT, ISOLATED.
const AGREEMENT_PERSONALITY: Array[float] = [0.05, -0.1, 0.15, -0.2]


class ClanState:
	extends RefCounted
	var data: ClanData
	var relation: int
	var gift_gain_this_turn := 0
	var trade_gain_this_turn := 0
	var traded_value_this_turn := 0
	## A refused or accepted proposal blocks further proposals to this clan until next turn.
	var proposed_this_turn := false

	func _init(p_data: ClanData) -> void:
		data = p_data
		relation = p_data.start_relation


## The player gives `give_amount` of `give_id` and receives `get_amount` of `get_id` every turn.
class Agreement:
	extends RefCounted
	var clan_id: StringName
	var give_id: StringName
	var give_amount: int
	var get_id: StringName
	var get_amount: int
	var total_turns: int
	var turns_left: int


var clans: Dictionary[StringName, ClanState] = {}
var agreements: Array[Agreement] = []
var _trade_values: Dictionary[StringName, int] = {}


func _init(clan_list: Array[ClanData], resource_types: Array[ResourceTypeData]) -> void:
	for clan in clan_list:
		clans[clan.clan_id] = ClanState.new(clan)
	for type in resource_types:
		_trade_values[type.resource_id] = type.trade_value


static func tier_for(relation: int) -> Tier:
	var tier := 0
	for threshold in TIER_THRESHOLDS:
		if relation >= threshold:
			tier += 1
	return tier as Tier


func get_tier(clan_id: StringName) -> Tier:
	return tier_for(clans[clan_id].relation)


func change_relation(clan_id: StringName, amount: int) -> void:
	var clan := clans[clan_id]
	clan.relation = clampi(clan.relation + amount, MIN_RELATION, MAX_RELATION)
	changed.emit()


## Relations drift toward each clan's base (raised while an agreement runs); per-turn gift,
## trade and proposal limits reset.
func end_turn() -> void:
	for clan_id in clans:
		var clan := clans[clan_id]
		var step: int = DRIFT_PER_TURN[clan.data.personality]
		var target := clan.data.base_relation + (AGREEMENT_BASE_BONUS if get_agreement(clan_id) != null else 0)
		clan.relation = int(move_toward(clan.relation, target, step))
		clan.gift_gain_this_turn = 0
		clan.trade_gain_this_turn = 0
		clan.traded_value_this_turn = 0
		clan.proposed_this_turn = false
	changed.emit()


func value_of(amounts: Dictionary[StringName, int]) -> int:
	var total := 0
	for resource_id in amounts:
		total += amounts[resource_id] * _trade_values.get(resource_id, 1)
	return total


# --- Gifts --------------------------------------------------------------------------------

## Relation the gift would add right now (after the per-turn limit).
func gift_gain(clan_id: StringName, amounts: Dictionary[StringName, int]) -> int:
	var clan := clans[clan_id]
	var raw := floori(float(value_of(amounts)) / GIFT_VALUE_PER_POINT * GIFT_MULTIPLIER[clan.data.personality])
	return clampi(raw, 0, MAX_GIFT_GAIN_PER_TURN - clan.gift_gain_this_turn)


func check_gift(stockpile: Stockpile, clan_id: StringName, amounts: Dictionary[StringName, int]) -> GiftResult:
	if value_of(amounts) <= 0:
		return GiftResult.EMPTY
	if clans[clan_id].gift_gain_this_turn >= MAX_GIFT_GAIN_PER_TURN:
		return GiftResult.LIMIT_REACHED
	if not stockpile.can_afford(amounts):
		return GiftResult.CANNOT_AFFORD
	return GiftResult.OK


## Pays the gift and raises the relation. Nothing happens unless check_gift() is OK.
func give_gift(stockpile: Stockpile, clan_id: StringName, amounts: Dictionary[StringName, int]) -> GiftResult:
	var result := check_gift(stockpile, clan_id, amounts)
	if result != GiftResult.OK:
		return result
	var gain := gift_gain(clan_id, amounts)
	stockpile.spend(amounts)
	clans[clan_id].gift_gain_this_turn += gain
	change_relation(clan_id, gain)
	return GiftResult.OK


static func describe_gift(result: GiftResult) -> String:
	match result:
		GiftResult.OK:
			return "Đã tặng quà."
		GiftResult.EMPTY:
			return "Chọn tài nguyên và số lượng để tặng."
		GiftResult.CANNOT_AFFORD:
			return "Không đủ tài nguyên."
		GiftResult.LIMIT_REACHED:
			return "Lượt này họ đã nhận đủ quà (tối đa +%d quan hệ mỗi lượt)." % MAX_GIFT_GAIN_PER_TURN
	return ""


# --- Trade --------------------------------------------------------------------------------

## How generous the clan is when the player gives `give_id` for `get_id`.
func price_factor(clan_id: StringName, give_id: StringName, get_id: StringName) -> float:
	var clan := clans[clan_id]
	var factor := BASE_PRICE + clan.relation / 100.0 * RELATION_PRICE
	if clan.data.personality == ClanData.Personality.MERCHANT:
		factor += MERCHANT_BONUS
	if clan.data.deficit.has(give_id):
		factor *= DEFICIT_BONUS
	if clan.data.surplus.has(get_id):
		factor *= SURPLUS_BONUS
	if not clan.data.is_neighbor():
		factor *= DISTANT_PENALTY
	return factor


## Units of `get_id` the player would receive for `give_amount` of `give_id` (rounded down).
func trade_quote(clan_id: StringName, give_id: StringName, give_amount: int, get_id: StringName) -> int:
	var value: int = give_amount * _trade_values.get(give_id, 1)
	return floori(value * price_factor(clan_id, give_id, get_id) / _trade_values.get(get_id, 1))


func remaining_capacity(clan_id: StringName) -> int:
	return TRADE_CAPACITY_PER_TURN - clans[clan_id].traded_value_this_turn


func check_trade(stockpile: Stockpile, clan_id: StringName, give_id: StringName, give_amount: int,
		get_id: StringName) -> TradeResult:
	if get_tier(clan_id) < MIN_TRADE_TIER:
		return TradeResult.REFUSED
	if give_id == get_id:
		return TradeResult.SAME_RESOURCE
	if give_amount <= 0:
		return TradeResult.EMPTY
	if stockpile.get_amount(give_id) < give_amount:
		return TradeResult.CANNOT_AFFORD
	if give_amount * _trade_values.get(give_id, 1) > remaining_capacity(clan_id):
		return TradeResult.OVER_CAPACITY
	if trade_quote(clan_id, give_id, give_amount, get_id) <= 0:
		return TradeResult.TOO_SMALL
	return TradeResult.OK


## Swaps the goods and nudges the relation up. Nothing happens unless check_trade() is OK.
func trade(stockpile: Stockpile, clan_id: StringName, give_id: StringName, give_amount: int,
		get_id: StringName) -> TradeResult:
	var result := check_trade(stockpile, clan_id, give_id, give_amount, get_id)
	if result != TradeResult.OK:
		return result
	var received := trade_quote(clan_id, give_id, give_amount, get_id)
	stockpile.spend({give_id: give_amount})
	stockpile.add({get_id: received})
	var clan := clans[clan_id]
	clan.traded_value_this_turn += give_amount * _trade_values.get(give_id, 1)
	if clan.trade_gain_this_turn < MAX_TRADE_GAIN_PER_TURN:
		clan.trade_gain_this_turn += TRADE_RELATION_GAIN
		change_relation(clan_id, TRADE_RELATION_GAIN)
	else:
		changed.emit()
	return TradeResult.OK


static func describe_trade(result: TradeResult) -> String:
	match result:
		TradeResult.OK:
			return "Giao dịch thành công."
		TradeResult.REFUSED:
			return "Họ từ chối giao thương khi quan hệ đang căng thẳng."
		TradeResult.SAME_RESOURCE:
			return "Chọn hai loại tài nguyên khác nhau."
		TradeResult.EMPTY:
			return "Chọn số lượng muốn đưa."
		TradeResult.CANNOT_AFFORD:
			return "Không đủ tài nguyên."
		TradeResult.OVER_CAPACITY:
			return "Lượt này họ không nhận thêm nhiều hàng như vậy."
		TradeResult.TOO_SMALL:
			return "Số lượng quá ít để đổi được gì."
	return ""


# --- Long-term agreements -----------------------------------------------------------------

func get_agreement(clan_id: StringName) -> Agreement:
	for agreement in agreements:
		if agreement.clan_id == clan_id:
			return agreement
	return null


## Chance (0..AGREEMENT_MAX_CHANCE) that the clan signs. Asking for less than the fair amount
## (what they would pay in a one-off trade) makes it likelier; asking for more makes it harder.
func agreement_chance(clan_id: StringName, give_id: StringName, give_amount: int, get_id: StringName,
		get_amount: int) -> float:
	var fair := trade_quote(clan_id, give_id, give_amount, get_id)
	if fair <= 0 or get_amount <= 0:
		return 0.0
	var clan := clans[clan_id]
	var chance := 1.5 - float(get_amount) / fair + clan.relation / 200.0 + AGREEMENT_PERSONALITY[clan.data.personality]
	return clampf(chance, 0.0, AGREEMENT_MAX_CHANCE)


static func chance_name(chance: float) -> String:
	if chance >= 0.8:
		return "Rất có thể"
	if chance >= 0.55:
		return "Có thể"
	if chance >= 0.3:
		return "Khó"
	if chance > 0.0:
		return "Rất khó"
	return "Không thể"


func check_proposal(clan_id: StringName, give_id: StringName, give_amount: int, get_id: StringName,
		get_amount: int, turns: int) -> ProposalResult:
	if get_tier(clan_id) < MIN_TRADE_TIER:
		return ProposalResult.REFUSED
	if get_agreement(clan_id) != null:
		return ProposalResult.ALREADY_HAS
	if clans[clan_id].proposed_this_turn:
		return ProposalResult.ASKED_THIS_TURN
	if give_id == get_id:
		return ProposalResult.SAME_RESOURCE
	if give_amount <= 0 or get_amount <= 0:
		return ProposalResult.EMPTY
	if give_amount * _trade_values.get(give_id, 1) > AGREEMENT_MAX_VALUE:
		return ProposalResult.TOO_LARGE
	if turns < AGREEMENT_MIN_TURNS or turns > AGREEMENT_MAX_TURNS:
		return ProposalResult.BAD_DURATION
	return ProposalResult.OK


## Sends the offer. The clan accepts with agreement_chance(); either way it will not hear another
## offer until next turn. Signing raises the relation at once.
func propose(rng: RandomNumberGenerator, clan_id: StringName, give_id: StringName, give_amount: int,
		get_id: StringName, get_amount: int, turns: int) -> ProposalResult:
	var result := check_proposal(clan_id, give_id, give_amount, get_id, get_amount, turns)
	if result != ProposalResult.OK:
		return result
	clans[clan_id].proposed_this_turn = true
	if rng.randf() >= agreement_chance(clan_id, give_id, give_amount, get_id, get_amount):
		changed.emit()
		return ProposalResult.DECLINED
	var agreement := Agreement.new()
	agreement.clan_id = clan_id
	agreement.give_id = give_id
	agreement.give_amount = give_amount
	agreement.get_id = get_id
	agreement.get_amount = get_amount
	agreement.total_turns = turns
	agreement.turns_left = turns
	agreements.append(agreement)
	change_relation(clan_id, AGREEMENT_SIGN_GAIN)
	return ProposalResult.OK


## The player breaks the agreement early: big relation penalty.
func cancel_agreement(clan_id: StringName) -> void:
	var agreement := get_agreement(clan_id)
	if agreement == null:
		return
	agreements.erase(agreement)
	change_relation(clan_id, -AGREEMENT_CANCEL_PENALTY)


## Runs every agreement for one turn. Returns one entry per agreement:
## {"clan_id", "agreement", "event": &"delivered" | &"missed" | &"cancelled_by_clan", "completed": bool}.
func run_agreements(stockpile: Stockpile) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	for agreement in agreements.duplicate():
		var entry := {"clan_id": agreement.clan_id, "agreement": agreement, "completed": false}
		report.append(entry)
		if get_tier(agreement.clan_id) == Tier.HOSTILE:
			agreements.erase(agreement)
			entry["event"] = &"cancelled_by_clan"
			continue
		var payment: Dictionary[StringName, int] = {agreement.give_id: agreement.give_amount}
		if stockpile.spend(payment):
			var delivery: Dictionary[StringName, int] = {agreement.get_id: agreement.get_amount}
			stockpile.add(delivery)
			change_relation(agreement.clan_id, AGREEMENT_TURN_GAIN)
			entry["event"] = &"delivered"
		else:
			change_relation(agreement.clan_id, -AGREEMENT_MISSED_PENALTY)
			entry["event"] = &"missed"
		agreement.turns_left -= 1
		if agreement.turns_left <= 0:
			agreements.erase(agreement)
			change_relation(agreement.clan_id, AGREEMENT_COMPLETE_GAIN)
			entry["completed"] = true
	return report


static func describe_proposal(result: ProposalResult) -> String:
	match result:
		ProposalResult.OK:
			return "Họ đồng ý ký hợp đồng!"
		ProposalResult.DECLINED:
			return "Họ từ chối đề nghị. Hãy thử lại vào lượt sau."
		ProposalResult.REFUSED:
			return "Họ không muốn làm ăn khi quan hệ đang căng thẳng."
		ProposalResult.SAME_RESOURCE:
			return "Chọn hai loại tài nguyên khác nhau."
		ProposalResult.EMPTY:
			return "Chọn số lượng đưa và nhận mỗi lượt."
		ProposalResult.TOO_LARGE:
			return "Hợp đồng tối đa %d giá trị hàng mỗi lượt." % AGREEMENT_MAX_VALUE
		ProposalResult.BAD_DURATION:
			return "Thời hạn từ %d đến %d lượt." % [AGREEMENT_MIN_TURNS, AGREEMENT_MAX_TURNS]
		ProposalResult.ALREADY_HAS:
			return "Đã có hợp đồng với gia tộc này."
		ProposalResult.ASKED_THIS_TURN:
			return "Họ cần thời gian cân nhắc. Hãy đề nghị lại vào lượt sau."
	return ""
