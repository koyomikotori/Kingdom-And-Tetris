class_name EventSystem
extends RefCounted
## Random events (GDD §9c): rolls 0–3 events at the start of a turn among those whose conditions
## hold, keeps them pending until the player answers, then applies the chosen answer. Owned by
## KingdomState; takes the state as an argument instead of holding it (no reference cycle).

## Chance of 0, 1, 2 and 3 events at the start of a turn.
const COUNT_CHANCES: Array[float] = [0.5, 0.3, 0.15, 0.05]

var events: Dictionary[StringName, EventData] = EventData.load_all()
## Events waiting for an answer, oldest first: {"event_id", "clan_id"}.
var pending: Array[Dictionary] = []
## event_id -> turn it last happened (for cooldowns).
var last_turn: Dictionary[StringName, int] = {}
## Turn the kingdom last beat a bandit raid (KingdomState.finish_raid).
var raid_won_turn := -100
var _resource_types: Array[ResourceTypeData] = ResourceTypeData.load_all()


## Start of a turn: adds 0–3 events to `pending` and returns the new entries.
func roll(state: KingdomState, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var added: Array[Dictionary] = []
	var count := rng.rand_weighted(PackedFloat32Array(COUNT_CHANCES))
	var candidates: Array[EventData] = []
	for event_id in events:
		if can_happen(state, events[event_id]):
			candidates.append(events[event_id])
	for i in count:
		if candidates.is_empty():
			break
		var weights := PackedFloat32Array()
		for event in candidates:
			weights.append(event.weight)
		var event: EventData = candidates.pop_at(rng.rand_weighted(weights))
		var clan_id := pick_clan(state, event, rng)
		if event.needs_clan and clan_id == &"":
			continue
		last_turn[event.event_id] = state.turn
		var entry := {"event_id": event.event_id, "clan_id": clan_id}
		pending.append(entry)
		added.append(entry)
	return added


## Whether the event's conditions hold right now (its clan is checked by pick_clan).
func can_happen(state: KingdomState, event: EventData) -> bool:
	if state.turn < event.min_turn or state.turn - last_turn.get(event.event_id, -1000) < event.cooldown:
		return false
	for resource_id in event.min_stock:
		if state.stockpile.get_amount(resource_id) < event.min_stock[resource_id]:
			return false
	for terrain_id in event.min_terrain:
		if state.board.count_owned_terrain(terrain_id) < event.min_terrain[terrain_id]:
			return false
	if event.required_building != &"" and state.board.count_buildings(event.required_building) == 0:
		return false
	if state.army.count_squads() < event.min_squads:
		return false
	if event.needs_free_squad_slot and state.army.count_squads() >= state.get_squad_capacity():
		return false
	if event.needs_wounded_squad and not _has_wounded_squad(state):
		return false
	if event.needs_raid_won_last_turn and raid_won_turn != state.turn - 1:
		return false
	return not event.needs_clan or not _matching_clans(state, event).is_empty()


## A clan matching the event's filters, or &"" (also for events about no clan).
func pick_clan(state: KingdomState, event: EventData, rng: RandomNumberGenerator) -> StringName:
	if not event.needs_clan:
		return &""
	var clans := _matching_clans(state, event)
	return clans[rng.randi_range(0, clans.size() - 1)] if not clans.is_empty() else &""


func _matching_clans(state: KingdomState, event: EventData) -> Array[StringName]:
	var result: Array[StringName] = []
	var clan_ids: Array[StringName] = []
	clan_ids.assign(state.diplomacy.clans.keys())
	clan_ids.sort()
	for clan_id in clan_ids:
		var clan := state.diplomacy.clans[clan_id]
		var tier := state.diplomacy.get_tier(clan_id)
		if clan.annexed or tier < event.clan_min_tier or tier > event.clan_max_tier:
			continue
		if event.clan_must_be_allied and not clan.is_allied():
			continue
		if not event.clan_may_be_at_war and state.wars.at_war_with(clan_id):
			continue
		if event.clan_must_be_stronger and state.wars.fronts[clan_id].strength <= state.army.count_soldiers():
			continue
		result.append(clan_id)
	return result


func _has_wounded_squad(state: KingdomState) -> bool:
	for squad in state.army.squads:
		if squad.soldiers < state.units[squad.unit_id].squad_size:
			return true
	return false


## The oldest unanswered event, or null.
func current_event() -> EventData:
	return events.get(pending[0].event_id) if not pending.is_empty() else null


func current_clan() -> StringName:
	return pending[0].clan_id if not pending.is_empty() else &""


## The event's text with its clan's name filled in.
func fill(state: KingdomState, text: String, clan_id: StringName) -> String:
	return text.replace("{clan}", state.diplomacy.clans[clan_id].data.display_name) if clan_id != &"" else text


func can_choose(state: KingdomState, choice: EventChoiceData) -> bool:
	return state.stockpile.can_afford(choice.cost)


## Answers the oldest pending event with choice `index`: pays its cost, rolls one outcome and
## applies it. Returns {"text": what happened, "changes": Array[String]} or {} when the choice
## cannot be afforded (nothing changes then).
func resolve(state: KingdomState, rng: RandomNumberGenerator, index: int) -> Dictionary:
	var event := current_event()
	var clan_id := current_clan()
	var choice := event.choices[index]
	if not can_choose(state, choice):
		return {}
	pending.pop_front()
	var changes: Array[String] = []
	if not choice.cost.is_empty():
		state.stockpile.spend(choice.cost)
		changes.append("Đã trả: %s" % _amounts(choice.cost))
	if choice.outcomes.is_empty():
		return {"text": "", "changes": changes}
	var weights := PackedFloat32Array()
	for outcome in choice.outcomes:
		weights.append(outcome.weight)
	var outcome := choice.outcomes[rng.rand_weighted(weights)]
	_apply(state, outcome, clan_id, changes)
	return {"text": fill(state, outcome.text, clan_id), "changes": changes}


func _apply(state: KingdomState, outcome: EventOutcomeData, clan_id: StringName, changes: Array[String]) -> void:
	var gained: Dictionary[StringName, int] = {}
	var lost: Dictionary[StringName, int] = {}
	for resource_id in outcome.resources:
		var amount := outcome.resources[resource_id]
		if amount > 0:
			gained[resource_id] = amount
		elif amount < 0:
			lost[resource_id] = mini(-amount, state.stockpile.get_amount(resource_id))
	for resource_id in outcome.resource_loss:
		var amount := floori(state.stockpile.get_amount(resource_id) * outcome.resource_loss[resource_id])
		lost[resource_id] = lost.get(resource_id, 0) + amount
	state.stockpile.add(gained)
	state.stockpile.spend(lost)
	if not gained.is_empty():
		changes.append("Nhận: %s" % _amounts(gained))
	if lost.values().any(func(amount: int) -> bool: return amount > 0):
		changes.append("Mất: %s" % _amounts(lost))
	if clan_id != &"" and outcome.relation != 0:
		state.diplomacy.change_relation(clan_id, outcome.relation, Diplomacy.MEMORY_EVENT)
		changes.append("Quan hệ với %s %+d" % [_clan_name(state, clan_id), outcome.relation])
	if outcome.relation_all != 0:
		for other in state.diplomacy.clans:
			if not state.diplomacy.clans[other].annexed:
				state.diplomacy.change_relation(other, outcome.relation_all, Diplomacy.MEMORY_EVENT)
		changes.append("Quan hệ với mọi gia tộc %+d" % outcome.relation_all)
	if outcome.add_unit != &"" and outcome.add_soldiers > 0 and state.units.has(outcome.add_unit):
		var unit_name := state.units[outcome.add_unit].display_name
		if state.army.count_squads() < state.get_squad_capacity():
			state.army.add_squad(outcome.add_unit, outcome.add_soldiers)
			changes.append("Thêm 1 đơn vị %s (%d lính)" % [unit_name, outcome.add_soldiers])
		else:
			changes.append("Không còn chỗ cho thêm đơn vị %s" % unit_name)
	if outcome.army_loss > 0.0 and state.army.count_squads() > 0:
		var before := state.army.count_soldiers()
		for squad in state.army.squads.duplicate():
			state.army.set_soldiers(squad, floori(squad.soldiers * (1.0 - outcome.army_loss)))
		changes.append("Mất %d lính" % (before - state.army.count_soldiers()))
	if outcome.replenish > 0.0:
		var added := 0
		for squad in state.army.squads:
			var full := state.units[squad.unit_id].squad_size
			var gain := mini(ceili(full * outcome.replenish), full - squad.soldiers)
			if gain > 0:
				state.army.set_soldiers(squad, squad.soldiers + gain)
				added += gain
		if added > 0:
			changes.append("Bổ sung %d lính" % added)
	if outcome.extra_pieces > 0:
		state.hand.draw_extra(outcome.extra_pieces)
		changes.append("Thêm %d mảnh đất vào tay" % outcome.extra_pieces)
	if clan_id != &"" and outcome.clan_strength != 0:
		var front := state.wars.fronts[clan_id]
		front.strength = clampi(front.strength + outcome.clan_strength, 0, front.max_strength)
		changes.append("Quân %s %+d lính" % [_clan_name(state, clan_id), outcome.clan_strength])
	if clan_id != &"" and outcome.declare_war and state.wars.clan_declares_war(clan_id):
		changes.append("%s tuyên chiến với vương quốc!" % _clan_name(state, clan_id))


func _amounts(amounts: Dictionary[StringName, int]) -> String:
	return UiFormat.amounts(amounts, _resource_types)


func _clan_name(state: KingdomState, clan_id: StringName) -> String:
	return state.diplomacy.clans[clan_id].data.display_name


# --- Save (GDD §10.1) ---------------------------------------------------------------------

func to_save() -> Dictionary:
	var turns := {}
	for event_id in last_turn:
		turns[String(event_id)] = last_turn[event_id]
	var waiting: Array = []
	for entry in pending:
		waiting.append({"event_id": String(entry.event_id), "clan_id": String(entry.clan_id)})
	return {"last_turn": turns, "pending": waiting, "raid_won_turn": raid_won_turn}


## Pending events that no longer exist in the data are dropped.
func load_save(data: Dictionary) -> void:
	last_turn.clear()
	for event_name: String in data.last_turn:
		last_turn[StringName(event_name)] = int(data.last_turn[event_name])
	pending.clear()
	for entry: Dictionary in data.pending:
		if events.has(StringName(entry.event_id)):
			pending.append({"event_id": StringName(entry.event_id), "clan_id": StringName(entry.clan_id)})
	raid_won_turn = int(data.raid_won_turn)
