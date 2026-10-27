extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	state.turn = 5
	return state


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Answers `event_id` (about `clan_id`) with choice `index`.
func _resolve(state: KingdomState, event_id: StringName, index: int, clan_id: StringName = &"",
		rng: RandomNumberGenerator = _rng()) -> Dictionary:
	state.events.pending = [{"event_id": event_id, "clan_id": clan_id}] as Array[Dictionary]
	return state.events.resolve(state, rng, index)


func _can(state: KingdomState, event_id: StringName) -> bool:
	return state.events.can_happen(state, state.events.events[event_id])


# --- Data ---------------------------------------------------------------------------------

func test_every_event_is_complete() -> void:
	var events := EventData.load_all()
	var resources := ResourceTypeData.load_all().map(func(t: ResourceTypeData) -> StringName: return t.resource_id)
	var units := UnitData.load_all().map(func(u: UnitData) -> StringName: return u.unit_id)
	check(events.size() >= 16, "First event set loaded (%d)" % events.size())
	for event_id in events:
		var event := events[event_id]
		check(not event.title.is_empty() and not event.text.is_empty(), "%s has text" % event_id)
		check(event.choices.size() >= 1 and event.choices.size() <= 3, "%s has 1-3 choices" % event_id)
		for choice in event.choices:
			check(not choice.outcomes.is_empty(), "%s: '%s' has an outcome" % [event_id, choice.text])
			for resource_id in choice.cost:
				check(resources.has(resource_id), "%s: cost %s exists" % [event_id, resource_id])
			for outcome in choice.outcomes:
				check(outcome.weight > 0.0 and not outcome.text.is_empty(), "%s: outcome has weight and text" % event_id)
				check(outcome.add_unit == &"" or units.has(outcome.add_unit), "%s: unit %s exists" % [event_id, outcome.add_unit])
				for resource_id in outcome.resources:
					check(resources.has(resource_id), "%s: resource %s exists" % [event_id, resource_id])
				if outcome.relation != 0 or outcome.declare_war or outcome.clan_strength != 0:
					check(event.needs_clan, "%s: clan effects need a clan" % event_id)


# --- When events happen -------------------------------------------------------------------

func test_turn_start_rolls_zero_to_three_events_with_the_chosen_odds() -> void:
	var counts := [0, 0, 0, 0]
	var rng := _rng(7)
	for i in 400:
		var state := _state()
		state.stockpile.add({&"food": 100, &"wood": 100, &"stone": 100})
		state.events.pending.clear()
		counts[state.events.roll(state, rng).size()] += 1
	check(counts[0] > 160 and counts[0] < 240, "About 50%% none (%d/400)" % counts[0])
	check(counts[1] > 90 and counts[1] < 150, "About 30%% one (%d/400)" % counts[1])
	check(counts[2] > 35 and counts[2] < 85, "About 15%% two (%d/400)" % counts[2])
	check(counts[3] > 5 and counts[3] < 40, "About 5%% three (%d/400)" % counts[3])


func test_no_events_before_turn_three_and_no_repeats_in_a_turn() -> void:
	var state := _state()
	state.turn = 2
	state.stockpile.add({&"food": 100, &"wood": 100, &"stone": 100})
	for event_id in state.events.events:
		if event_id != &"bandit_mercy":
			check(not _can(state, event_id), "%s waits for turn 3" % event_id)
	state.turn = 5
	state.stockpile.add({&"food": 100, &"wood": 100, &"stone": 100})
	for seed_value in 50:
		var picked := state.events.roll(state, _rng(seed_value)).map(func(e: Dictionary) -> StringName: return e.event_id)
		for event_id in picked:
			check_eq(picked.count(event_id), 1, "No repeat in one turn")
		state.events.last_turn.clear()


func test_conditions_and_cooldowns() -> void:
	var state := _state()
	check(not _can(state, &"crop_blight"), "No farmland")
	for x in 4:
		state.board.set_land(Vector2i(x, 0), &"farmland", false)
	state.stockpile.add({&"food": 30})
	check(_can(state, &"crop_blight"), "Farmland and food")
	state.events.last_turn[&"crop_blight"] = 5
	state.turn = 12
	check(not _can(state, &"crop_blight"), "Cooldown of 8 turns")
	state.turn = 13
	check(_can(state, &"crop_blight"), "Cooldown over")
	check(not _can(state, &"camp_plague"), "No barracks")


func test_bandits_beg_only_after_a_raid_was_beaten_last_turn() -> void:
	var state := _state()
	check(not _can(state, &"bandit_mercy"), "No raid")
	state.events.raid_won_turn = 4
	check(_can(state, &"bandit_mercy"), "Raid beaten last turn")
	state.turn = 6
	check(not _can(state, &"bandit_mercy"), "Too late")


func test_clan_events_pick_a_matching_clan() -> void:
	var state := _state()
	var tribute: EventData = state.events.events[&"tribute_demand"]
	check(not _can(state, &"tribute_demand"), "No clan is tense yet")
	state.diplomacy.change_relation(&"north_wolves", -40)  # -10 -> -50: tense, 70 soldiers > 0
	check(_can(state, &"tribute_demand"), "Wolves are tense and stronger")
	check_eq(state.events.pick_clan(state, tribute, _rng()), &"north_wolves", "Only the wolves match")
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"swordsman", 20)
	check(not _can(state, &"tribute_demand"), "Not once the kingdom has more soldiers")
	check(not _can(state, &"ally_request"), "No ally")
	state.stockpile.add({&"wood": 30})
	state.diplomacy.clans[&"south_farmers"].alliance_turns = 10
	check_eq(state.events.pick_clan(state, state.events.events[&"ally_request"], _rng()), &"south_farmers", "The ally")


# --- Answers ------------------------------------------------------------------------------

func test_a_choice_pays_its_cost_and_applies_the_outcome() -> void:
	var state := _state()
	state.stockpile.add({&"food": 40})
	var relation := state.diplomacy.clans[&"south_farmers"].relation
	var result := _resolve(state, &"famine_aid", 0, &"south_farmers")
	check_eq(state.stockpile.get_amount(&"food"), 15, "Paid 25 food")
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, relation + 15, "+15")
	check_eq(state.diplomacy.clans[&"south_farmers"].memories.get(Diplomacy.MEMORY_EVENT), 15, "Remembered as an event")
	check(result.text.contains("Điền Trang Nam Lâm"), "Clan name filled in")
	check(state.events.pending.is_empty(), "Answered")


func test_unaffordable_choices_change_nothing() -> void:
	var state := _state()
	state.stockpile.add({&"food": 10})
	check(_resolve(state, &"famine_aid", 0, &"south_farmers").is_empty(), "Refused")
	check_eq(state.stockpile.get_amount(&"food"), 10, "Nothing paid")
	check_eq(state.events.pending.size(), 1, "Still waiting for an answer")


func test_outcomes_roll_by_weight() -> void:
	var stones := {}
	for seed_value in 200:
		var state := _state()
		state.stockpile.add({&"food": 20})
		_resolve(state, &"traveling_merchant", 0, &"", _rng(seed_value))
		var stone := state.stockpile.get_amount(&"stone")
		stones[stone] = stones.get(stone, 0) + 1
	check_eq(stones.keys().size(), 3, "Three possible results")
	check(stones[25] > stones[0], "The likely result comes up more often than the scam")


func test_army_effects() -> void:
	var state := _state()
	state.stockpile.add({&"food": 50})
	var volunteers := _resolve(state, &"volunteers", 0)
	check_eq(state.army.count_squads(), 1, "A new squad")
	check(volunteers.changes.any(func(line: String) -> bool: return line.contains("Kiếm binh")), "Reported")
	state.army.add_squad(&"swordsman", 20)
	var expected := 0
	for squad in state.army.squads:
		expected += floori(squad.soldiers * 0.75)
	_resolve(state, &"camp_plague", 1)
	check_eq(state.army.count_soldiers(), expected, "25% of each squad is lost (rounded in their favour)")
	state.stockpile.add({&"food": 10})
	var wounded := state.army.count_soldiers()
	_resolve(state, &"healer", 0)
	check(state.army.count_soldiers() > wounded, "Healer brings soldiers back")


func test_land_and_war_effects() -> void:
	var state := _state()
	state.stockpile.add({&"wood": 10})
	_resolve(state, &"settlers", 0)
	check_eq(state.hand.pieces.size(), 5, "Two extra pieces in the hand")
	state.diplomacy.change_relation(&"north_wolves", -40)
	var rng := RandomNumberGenerator.new()
	for seed_value in 1000:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.rand_weighted(PackedFloat32Array([0.5, 0.5])) == 1:
			rng.seed = seed_value
			break
	_resolve(state, &"tribute_demand", 1, &"north_wolves", rng)
	check(state.wars.at_war_with(&"north_wolves"), "Refusing tribute may start a war")


# --- Save ---------------------------------------------------------------------------------

func test_pending_events_and_cooldowns_are_saved() -> void:
	var state := _state()
	state.events.pending = [{"event_id": &"famine_aid", "clan_id": &"south_farmers"},
			{"event_id": &"no_such_event", "clan_id": &""}] as Array[Dictionary]
	state.events.last_turn[&"stone_vein"] = 4
	state.events.raid_won_turn = 3
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.events.pending, [{"event_id": &"famine_aid", "clan_id": &"south_farmers"}] as Array[Dictionary],
			"Pending event kept, unknown one dropped")
	check_eq(loaded.events.last_turn, {&"stone_vein": 4} as Dictionary[StringName, int], "Cooldowns")
	check_eq(loaded.events.raid_won_turn, 3, "Raid flag")
