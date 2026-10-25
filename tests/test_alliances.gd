extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	return state


## An RNG whose first randf() satisfies `predicate`.
func _rng_where(predicate: Callable) -> RandomNumberGenerator:
	for seed_value in 10000:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if predicate.call(probe.randf()):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			return rng
	return RandomNumberGenerator.new()


func _low_rng() -> RandomNumberGenerator:
	return _rng_where(func(value: float) -> bool: return value < 0.01)


func _high_rng() -> RandomNumberGenerator:
	return _rng_where(func(value: float) -> bool: return value > 0.99)


func _run(simulator: BattleSimulator) -> BattleRecord:
	while not simulator.finished:
		simulator.step()
	return simulator.record


func _set_relation(state: KingdomState, clan_id: StringName, relation: int) -> void:
	state.diplomacy.change_relation(clan_id, relation - state.diplomacy.clans[clan_id].relation)


## Allies `clan_id` right away: relation 60 (Close), then 90 with the alliance's +30.
func _ally(state: KingdomState, clan_id: StringName) -> void:
	_set_relation(state, clan_id, 60)
	check_eq(state.alliances.propose_alliance(_low_rng(), clan_id), Alliances.AllianceResult.OK, "%s allied" % clan_id)


func _lent_soldiers(side: BattleSide) -> Dictionary:
	var result := {}
	for unit in side.units:
		if unit.ally != null:
			result[unit.ally.clan_id] = result.get(unit.ally.clan_id, 0) + unit.start_soldiers
	return result


# --- Data -----------------------------------------------------------------------------------

func test_clan_friendships_are_mutual() -> void:
	var clans := ClanData.load_all()
	var by_id := {}
	for clan in clans:
		by_id[clan.clan_id] = clan
	for clan in clans:
		check(not clan.friends.is_empty(), "%s has a friend" % clan.clan_id)
		for friend in clan.friends:
			check(by_id.has(friend), "%s: friend %s exists" % [clan.clan_id, friend])
			if by_id.has(friend):
				check((by_id[friend] as ClanData).friends.has(clan.clan_id), "%s <-> %s" % [clan.clan_id, friend])


# --- Alliance -------------------------------------------------------------------------------

func test_alliance_needs_a_close_relation() -> void:
	var state := _state()
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.NOT_CLOSE, "Friendly is not enough")
	_set_relation(state, &"south_farmers", 60)
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.OK, "Close")
	state.wars.declare_war(&"north_wolves")
	_set_relation(state, &"north_wolves", 80)
	check_eq(state.alliances.check_alliance(&"north_wolves"), Alliances.AllianceResult.AT_WAR, "Not while at war")


func test_alliance_chance_by_relation_personality_and_threat() -> void:
	var state := _state()
	_set_relation(state, &"east_merchants", 60)
	check(is_equal_approx(state.alliances.alliance_chance(&"east_merchants"), 0.45), "Merchants at 60: 0.3 + 0.15")
	_set_relation(state, &"east_merchants", 100)
	check(is_equal_approx(state.alliances.alliance_chance(&"east_merchants"), 0.95), "Capped at 95%")
	_set_relation(state, &"north_wolves", 60)
	check(is_equal_approx(state.alliances.alliance_chance(&"north_wolves"), 0.2), "Aggressive: 0.3 - 0.1")
	state.diplomacy.threat = 20
	check(is_equal_approx(state.alliances.alliance_chance(&"north_wolves"), 0.1), "Threat 20: -0.1")


func test_refused_alliance_waits_three_turns() -> void:
	var state := _state()
	_set_relation(state, &"south_farmers", 60)
	check_eq(state.alliances.propose_alliance(_high_rng(), &"south_farmers"), Alliances.AllianceResult.DECLINED, "Refused")
	check(not state.diplomacy.clans[&"south_farmers"].is_allied(), "Not allied")
	for i in 2:
		state.alliances.end_turn()
		check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.COOLDOWN, "Still waiting")
	state.alliances.end_turn()
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.OK, "Can ask again")


func test_alliance_raises_the_drift_target_and_expires() -> void:
	var state := _state()
	var before := state.diplomacy.target_relation(&"south_farmers")
	_ally(state, &"south_farmers")
	check_eq(state.diplomacy.target_relation(&"south_farmers"), before + 30, "+30 while allied")
	check_eq(state.alliances.allies(), [&"south_farmers"] as Array[StringName], "Listed as ally")
	var events: Array[Dictionary] = []
	for i in Alliances.ALLIANCE_TURNS:
		events = state.alliances.end_turn()
	check(not state.diplomacy.clans[&"south_farmers"].is_allied(), "Ended after 20 turns")
	check_eq(events, [{"clan_id": &"south_farmers", "event": &"alliance_expired"}], "Reported as expired")
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.OK, "Can be signed again")


func test_alliance_breaks_below_friendly_and_cancelling_costs_30() -> void:
	var state := _state()
	_ally(state, &"south_farmers")
	_set_relation(state, &"south_farmers", 19)
	var events := state.alliances.end_turn()
	check_eq(events, [{"clan_id": &"south_farmers", "event": &"alliance_broken"}], "Fell apart")
	check(not state.diplomacy.clans[&"south_farmers"].is_allied(), "No longer allied")
	_ally(state, &"east_merchants")
	state.alliances.cancel_alliance(&"east_merchants")
	check(not state.diplomacy.clans[&"east_merchants"].is_allied(), "Cancelled")
	check_eq(state.diplomacy.clans[&"east_merchants"].relation, 30, "90 - 30 penalty - 30 alliance bonus")


# --- Non-aggression pact --------------------------------------------------------------------

func test_pact_needs_friendly_and_lasts_ten_turns() -> void:
	var state := _state()
	check_eq(state.alliances.sign_pact(&"north_wolves"), Alliances.PactResult.NOT_FRIENDLY, "Wolves are not friendly")
	check_eq(state.alliances.sign_pact(&"south_farmers"), Alliances.PactResult.OK, "Farmers sign")
	check_eq(state.alliances.sign_pact(&"south_farmers"), Alliances.PactResult.ALREADY_HAS, "Once")
	var events: Array[Dictionary] = []
	for i in Alliances.PACT_TURNS:
		events = state.alliances.end_turn()
	check(not state.diplomacy.clans[&"south_farmers"].has_pact(), "Expired")
	check_eq(events, [{"clan_id": &"south_farmers", "event": &"pact_expired"}], "Reported")


func test_pact_stops_the_clan_declaring_war_even_when_hostile() -> void:
	var state := _state()
	_set_relation(state, &"north_wolves", 30)
	state.alliances.sign_pact(&"north_wolves")
	_set_relation(state, &"north_wolves", -90)
	check(state.wars.end_turn(_low_rng()).is_empty(), "No declaration during the pact")
	state.diplomacy.clans[&"north_wolves"].pact_turns = 0
	check_eq(state.wars.end_turn(_low_rng()), [&"north_wolves"] as Array[StringName], "Declares once it is over")


# --- Declaring war on friends and treaty partners -------------------------------------------

func test_declaring_war_angers_the_targets_friends_most() -> void:
	var state := _state()
	var eagle := state.diplomacy.clans[&"golden_eagle"].relation
	var farmers := state.diplomacy.clans[&"south_farmers"].relation
	state.wars.declare_war(&"north_wolves")
	check_eq(state.diplomacy.clans[&"golden_eagle"].relation, eagle - 15, "Friend of the wolves: -15")
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, farmers - 5, "Others: -5")


func test_betraying_an_ally_costs_everyone_and_ends_the_treaties() -> void:
	var state := _state()
	_ally(state, &"south_farmers")
	state.alliances.sign_pact(&"south_farmers")
	var steppe := state.diplomacy.clans[&"steppe_tribes"].relation
	var wolves := state.diplomacy.clans[&"north_wolves"].relation
	check_eq(state.wars.declare_penalty(&"south_farmers", &"north_wolves"), -5 - 20 - 10, "Preview")
	state.wars.declare_war(&"south_farmers")
	var farmers := state.diplomacy.clans[&"south_farmers"]
	check(not farmers.is_allied() and not farmers.has_pact(), "Both treaties are gone")
	check_eq(state.diplomacy.clans[&"north_wolves"].relation, wolves - 35, "Others: -5 - 20 (ally) - 10 (pact)")
	check_eq(state.diplomacy.clans[&"steppe_tribes"].relation, steppe - 45, "Their friend: -15 - 20 - 10")


# --- Lent soldiers --------------------------------------------------------------------------

func test_allies_send_thirty_percent_unless_weak_or_friends_with_the_enemy() -> void:
	var state := _state()
	_ally(state, &"east_merchants")  # 40 soldiers, friend of golden_eagle
	_ally(state, &"south_farmers")  # 30 soldiers
	check_eq(_lent_soldiers(state.create_kingdom_side(&"")), {&"east_merchants": 12, &"south_farmers": 9},
			"Both help against bandits")
	check_eq(_lent_soldiers(state.create_kingdom_side(&"golden_eagle")), {&"south_farmers": 9},
			"Merchants will not fight their friend")
	state.wars.fronts[&"south_farmers"].strength = 8  # below 30% of 30
	check_eq(_lent_soldiers(state.create_kingdom_side(&"")), {&"east_merchants": 12}, "Weak allies stay home")


func test_shared_victory_costs_the_ally_soldiers_and_raises_relation() -> void:
	var state := _state()
	_ally(state, &"east_merchants")
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"north_wolves")
	var relation := state.diplomacy.clans[&"east_merchants"].relation
	var invaders := state.wars.create_clan_side(&"north_wolves", 6, state.units)
	var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
	var result := state.finish_invasion(&"north_wolves", record)
	check(result.won, "Invasion beaten")
	var sent: int = result.allies[&"east_merchants"].sent
	var lost: int = result.allies[&"east_merchants"].lost
	check_eq(sent, 12, "Merchants sent 12")
	check_eq(state.wars.fronts[&"east_merchants"].strength, 40 - lost, "Their losses come out of their army")
	check_eq(state.diplomacy.clans[&"east_merchants"].relation, relation + 5, "Shared win: +5")
	check_eq(result.allies[&"east_merchants"].relation, 5, "Reported")
	check_eq(state.army.count_squads(), 2, "Ally units never touch the kingdom's squads")


func test_shared_defeat_lowers_relation_and_counts_only_own_losses() -> void:
	var state := _state()
	_ally(state, &"east_merchants")
	state.army.add_squad(&"swordsman", 10)
	state.wars.declare_war(&"north_wolves")
	var relation := state.diplomacy.clans[&"east_merchants"].relation
	var invaders := state.wars.create_clan_side(&"north_wolves", 70, state.units)
	var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
	var result := state.finish_invasion(&"north_wolves", record)
	check(not result.won, "Overrun")
	check_eq(state.diplomacy.clans[&"east_merchants"].relation, relation - 10, "Shared defeat: -10")
	var own_lost := 0
	for bucket in [result.casualties, result.scattered, result.retreat_losses]:
		for unit_id in bucket:
			own_lost += bucket[unit_id]
	check(own_lost <= 10, "Kingdom losses only count its own 10 soldiers (got %d)" % own_lost)


func test_friends_defend_the_attacked_clan_unless_allied_or_at_peace() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"west_fortress")  # friend: steppe_tribes (45)
	var simulator := state.start_attack(&"west_fortress")
	check_eq(_lent_soldiers(simulator.record.sides[BattleRecord.DEFENDER]), {&"steppe_tribes": 14}, "Steppe helps")
	var state2 := _state()
	state2.army.add_squad(&"swordsman", 20)
	_set_relation(state2, &"steppe_tribes", 30)
	state2.alliances.sign_pact(&"steppe_tribes")
	state2.wars.declare_war(&"west_fortress")
	check(_lent_soldiers(state2.start_attack(&"west_fortress").record.sides[BattleRecord.DEFENDER]).is_empty(),
			"A pact keeps the friend out")
	var state3 := _state()
	state3.army.add_squad(&"swordsman", 20)
	_ally(state3, &"steppe_tribes")
	state3.wars.declare_war(&"west_fortress")
	var sim3 := state3.start_attack(&"west_fortress")
	check(_lent_soldiers(sim3.record.sides[BattleRecord.DEFENDER]).is_empty(), "An ally does not defend them")
	check(_lent_soldiers(sim3.record.sides[BattleRecord.ATTACKER]).is_empty(), "…nor attack its own friend")


func test_helpers_lose_their_own_soldiers_not_the_targets() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"west_fortress")
	var record := _run(state.start_attack(&"west_fortress"))
	var result := state.finish_attack(&"west_fortress", record)
	var helper_lost: int = result.helpers[&"steppe_tribes"].lost
	check_eq(state.wars.fronts[&"steppe_tribes"].strength, 45 - helper_lost, "Steppe pays for its own losses")
	check_eq(state.wars.fronts[&"west_fortress"].strength, 55 - result.enemy_lost, "Fortress only loses its own")
	check(result.enemy_lost <= 55, "enemy_lost excludes the helpers")


func test_alliance_can_be_renewed_in_its_last_turns() -> void:
	var state := _state()
	_ally(state, &"south_farmers")
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.ALREADY_ALLIED, "Not yet")
	for i in Alliances.ALLIANCE_TURNS - Alliances.ALLIANCE_RENEW_TURNS:
		state.alliances.end_turn()
	check_eq(state.diplomacy.clans[&"south_farmers"].alliance_turns, 5, "5 turns left")
	check_eq(state.alliances.check_alliance(&"south_farmers"), Alliances.AllianceResult.OK, "Renewable")
	check_eq(state.alliances.propose_alliance(_low_rng(), &"south_farmers"), Alliances.AllianceResult.OK, "Renewed")
	check_eq(state.diplomacy.clans[&"south_farmers"].alliance_turns, Alliances.ALLIANCE_TURNS, "Another 20 turns")


func test_alliance_bonus_is_part_of_the_relation_at_once() -> void:
	var state := _state()
	_set_relation(state, &"south_farmers", 60)
	state.alliances.propose_alliance(_low_rng(), &"south_farmers")
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, 90, "+30 as soon as it is signed")
	state.diplomacy.clans[&"south_farmers"].alliance_turns = 1
	state.alliances.end_turn()
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, 60, "…and gone when it expires")


func test_pact_adds_ten_while_it_runs() -> void:
	var state := _state()
	var before := state.diplomacy.clans[&"south_farmers"].relation
	state.alliances.sign_pact(&"south_farmers")
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, before + 10, "+10 once signed")
	state.diplomacy.clans[&"south_farmers"].pact_turns = 1
	state.alliances.end_turn()
	check_eq(state.diplomacy.clans[&"south_farmers"].relation, before, "-10 when it expires")
