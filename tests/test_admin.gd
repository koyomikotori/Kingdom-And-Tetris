extends "res://tests/test_suite.gd"
## Administrative buildings and agents (GDD §8 M14e).

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	state.stockpile.add({&"food": 900, &"wood": 900, &"stone": 900, &"ore": 900, &"hardwood": 900, &"horses": 900})
	return state


## Builds on a grass cell made for it.
func _build(state: KingdomState, building_id: StringName, at: Vector2i) -> BuildRules.Result:
	state.board.set_land(at, &"grass", false)
	return state.build(building_id, at)


func test_admin_buildings_unlock_with_the_castle() -> void:
	var state := _state()
	var buildings := state.buildings
	for id: StringName in [&"market", &"granary", &"academy", &"infirmary", &"magistrate", &"police"]:
		check_eq(buildings[id].category, BuildingData.Category.ADMIN, "%s is administrative" % id)
	check_eq(_build(state, &"market", Vector2i(4, 4)), BuildRules.Result.CASTLE_TOO_LOW, "Markets from castle level 2")
	var markets: Array[int] = []
	var academies: Array[int] = []
	for level in range(2, 7):
		markets.append(BuildRules.limit(buildings[&"market"], level))
		academies.append(BuildRules.limit(buildings[&"academy"], level))
	check_eq(markets, [1, 2, 3, 4, 5] as Array[int], "1 market at castle level 2, +1 per level")
	check_eq(academies, [1, 1, 1, 1, 1] as Array[int], "One academy")
	check_eq(BuildRules.limit(buildings[&"barracks"], 1), 3, "Others still count from level 1")
	check_eq(buildings[&"police"].max_level(), 4, "Police: 4 levels")
	state.castle_level = 2
	check_eq(_build(state, &"police", Vector2i(4, 4)), BuildRules.Result.CASTLE_TOO_LOW, "Police from castle level 3")


func test_markets_trade_more_and_better() -> void:
	var state := _state()
	state.castle_level = 6
	var clan := &"east_merchants"
	var capacity := state.diplomacy.remaining_capacity(clan)
	var price := state.diplomacy.price_factor(clan, &"wood", &"food")
	_build(state, &"market", Vector2i(4, 4))
	check_eq(state.diplomacy.remaining_capacity(clan), capacity + 10, "+10 trade value a turn")
	check(is_equal_approx(state.diplomacy.price_factor(clan, &"wood", &"food"), price * 1.03), "3% better prices")
	for at: Vector2i in [Vector2i(7, 4), Vector2i(4, 7), Vector2i(7, 7), Vector2i(2, 2)]:
		_build(state, &"market", at)
	check(is_equal_approx(state.diplomacy.price_factor(clan, &"wood", &"food"), price * 1.15), "15% at most")
	state.buildings_supplied = false
	check_eq(state.diplomacy.remaining_capacity(clan), capacity, "Unpaid markets do nothing")


func test_granaries_keep_plunder_and_feed_the_army() -> void:
	var state := _state()
	state.castle_level = 6
	for i in 10:
		state.army.add_squad(&"swordsman", 20)
	var upkeep: int = state.get_army_upkeep()[&"food"]
	_build(state, &"granary", Vector2i(4, 4))
	check(is_equal_approx(state.plunder_protection(), 0.1), "One granary keeps 10%")
	check_eq(state.get_army_upkeep()[&"food"], upkeep - roundi(upkeep * 0.02), "−2% army food")
	check_eq(state.get_net_income(), _net_from_parts(state), "Income breakdown adds up")
	for at: Vector2i in [Vector2i(7, 4), Vector2i(4, 7), Vector2i(7, 7), Vector2i(2, 2)]:
		_build(state, &"granary", at)
	check(is_equal_approx(state.plunder_protection(), 0.5), "Five granaries: 50%")
	# A lost raid takes 30% less half of it.
	var raid := RaidData.load_bandits()
	var food := state.stockpile.get_amount(&"food")
	state.army.squads.clear()
	var bandits := BattleSide.new("Quân cướp")
	bandits.add_unit(UnitData.load_enemies()[&"bandit_thug"], 16)
	var result := RaidSystem.resolve(state, raid, bandits, 1)
	check(not result.won, "No army: the raid is lost")
	check_eq(result.resources_lost[&"food"], floori(food * raid.resource_loss_on_defeat * 0.5), "Half kept from plunder")


func test_magistrate_adds_production() -> void:
	var state := _state()
	state.castle_level = 6
	state.board.set_land(Vector2i(2, 2), &"farmland", false)
	state.build(&"farm", Vector2i(2, 2))
	state.board.set_building_level(Vector2i(2, 2), 6)
	var food: int = state.get_turn_yield()[&"food"]
	_build(state, &"magistrate", Vector2i(4, 4))
	state.board.set_building_level(Vector2i(4, 4), 5)
	check_eq(state.get_turn_yield()[&"food"], food + roundi(food * 0.2), "Level 5: +20% production")
	check_eq(state.get_net_income(), _net_from_parts(state), "Income breakdown adds up")


func test_academy_teaches_and_infirmary_heals() -> void:
	var state := _state()
	state.castle_level = 6
	var general := state.generals.generate(3)
	state.generals.generals.append(general)
	general.wounded_turns = 3
	_build(state, &"academy", Vector2i(4, 4))
	state.board.set_building_level(Vector2i(4, 4), 2)
	state.stockpile.add({&"food": 500})
	state.end_turn()
	check_eq(general.xp, 10, "Level-2 academy: +10 XP a turn")
	check_eq(general.wounded_turns, 2, "Without an infirmary: one turn a turn")
	_build(state, &"infirmary", Vector2i(7, 4))
	state.board.set_building_level(Vector2i(7, 4), 5)
	state.end_turn()
	check_eq(general.wounded_turns, 0, "Infirmary: twice as fast")
	check(is_equal_approx(state.building_effect(&"commander_survival"), 0.2), "Level 5: −20% death chance")
	check(Generals.death_chance(general, 0.2) < Generals.death_chance(general), "…used by the death chance")
	var unit := BattleSide.Unit.new(state.units[&"swordsman"], 20, null)
	unit.soldiers = 10.0
	check_eq(BattleOutcome.soldiers_kept(unit, false, true), 5, "Lost battle: 50% kept")
	check_eq(BattleOutcome.soldiers_kept(unit, false, true, false, state.building_effect(&"retreat_keep")), 7,
			"Level-5 infirmary: 70% kept")


func test_agents_are_hired_once_and_go_on_missions() -> void:
	var state := _state()
	state.castle_level = 6
	check_eq(state.agent_slots(), 0, "No police: no agents")
	check_eq(state.agents.candidates.size(), 3, "Three candidates")
	check_eq(state.recruit_agent(0), Agents.Result.NO_ROOM, "Needs a Sở cảnh sát")
	_build(state, &"police", Vector2i(4, 4))
	check_eq(state.agent_slots(), 1, "Level 1: one agent")
	var stars := state.agents.candidates[0].stars
	var food := state.stockpile.get_amount(&"food")
	check_eq(state.recruit_agent(0), Agents.Result.OK, "Hired")
	check_eq(food - state.stockpile.get_amount(&"food"), 30 + 20 * stars, "Paid once")
	check_eq(state.recruit_agent(0), Agents.Result.NO_ROOM, "One slot")
	var upkeep := state.get_army_upkeep()
	check(not upkeep.has(&"wood"), "No upkeep for agents")
	var agent: Agent = state.agents.agents[0]
	check_eq(agent.max_level(), mini(10, 4 + agent.stars), "Max level 4 + stars")
	state.wars.fronts[&"north_wolves"].annexed = true
	check_eq(state.start_agent_mission(agent, Agent.RELATIONS, &"north_wolves"), Agents.Result.ANNEXED, "Not an annexed clan")
	check_eq(state.start_agent_mission(agent, Agent.RELATIONS, &"far_clan_that_does_not_exist"), Agents.Result.UNKNOWN_CLAN,
			"Unknown clan")
	var target: StringName = state.wars.fronts.keys().filter(
			func(id: StringName) -> bool: return not state.wars.fronts[id].annexed and state.diplomacy.distance(id) > 2)[0]
	check_eq(state.start_agent_mission(agent, Agent.RELATIONS, target), Agents.Result.OK, "Any clan, however far")
	check_eq(state.start_agent_mission(agent, Agent.SABOTAGE, target), Agents.Result.BUSY, "One mission at a time")


func test_relations_mission_raises_relation_each_turn() -> void:
	var diplomacy := Diplomacy.new(ClanData.load_all(), ResourceTypeData.load_all())
	var wars := Wars.new(diplomacy)
	var agents := Agents.new()
	var agent := agents.generate(6)
	agent.level = 4
	agents.agents.append(agent)
	var clan: StringName = wars.fronts.keys()[0]
	agents.start_mission(agent, Agent.RELATIONS, clan, wars)
	var before: int = diplomacy.clans[clan].memories.get(Diplomacy.MEMORY_AGENT, 0)
	# A seed where the agent is not caught on the first turn.
	agents.rng.seed = 7
	var events := agents.end_turn(diplomacy, 4, 1, 1)
	check(events.is_empty() or events[0].event == &"level", "Not caught (seed 7)")
	check_eq(diplomacy.clans[clan].memories.get(Diplomacy.MEMORY_AGENT, 0) - before, 4, "+level relation a turn")
	check_eq(agent.turns_left, Agents.MISSION_TURNS - 1, "One turn done")
	check_eq(agent.xp, Agents.XP_PER_TURN, "Learns on missions")


func test_sabotage_slows_regrowth_and_missions_end() -> void:
	var diplomacy := Diplomacy.new(ClanData.load_all(), ResourceTypeData.load_all())
	var wars := Wars.new(diplomacy)
	var agents := Agents.new()
	wars.sabotage = agents.sabotage_on
	var agent := agents.generate(6)
	agent.level = 10
	agents.agents.append(agent)
	var clan: StringName = wars.fronts.keys()[0]
	check(is_equal_approx(Agent.SABOTAGE_BY_LEVEL[0], 1.0) and is_equal_approx(agent.sabotage_share(), 0.06), "1% … 6%")
	agents.start_mission(agent, Agent.SABOTAGE, clan, wars)
	check(is_equal_approx(agents.sabotage_on(clan), 0.06), "Level 10 takes 6% off")
	var front: Wars.Front = wars.fronts[clan]
	front.strength = 0
	wars.end_turn(RandomNumberGenerator.new(), 1)
	check_eq(front.strength, ceili(front.max_strength * (Wars.STRENGTH_REGEN_SHARE - 0.06)), "Regrows 4% instead of 10%")
	check(is_equal_approx(Agents.detect_chance(1), 0.03) and is_equal_approx(Agents.detect_chance(4), 0.005),
			"3% caught on the first turn, less with a better police")
	check(is_equal_approx(Agents.detect_chance(1, 9), 0.12) and is_equal_approx(Agents.detect_chance(4, 9), 0.095),
			"+1% a turn spent there: 12% on the 10th turn")
	check(is_equal_approx(Agents.current_detect_chance(agent, 1), 0.03), "First turn of the mission")
	check(is_equal_approx(Agents.kill_chance(1), 0.35) and is_equal_approx(Agents.kill_chance(6), 0.1), "40% − 5% × stars")
	# A mission that is never caught runs its 10 turns; the chance rises turn by turn.
	agents.end_turn(diplomacy, 99, 1, 1)
	if agent.is_busy():
		check(is_equal_approx(Agents.current_detect_chance(agent, 99), 0.015), "Second turn: +1%")
	var finished := false
	for attempt in 50:
		if not agent.is_busy():
			if agents.agents.has(agent):
				agents.start_mission(agent, Agent.SABOTAGE, clan, wars)
			else:
				agent = agents.generate(6)
				agents.agents.append(agent)
				agents.start_mission(agent, Agent.SABOTAGE, clan, wars)
		var turns := Agents.MISSION_TURNS - agent.turns_left
		var last := {}
		while agent.is_busy():
			turns += 1
			var events := agents.end_turn(diplomacy, 99, 1, 1)
			if not events.is_empty():
				last = events[-1]
		if last.get("event") == &"done":
			check_eq(turns, Agents.MISSION_TURNS, "Done after 10 turns")
			finished = true
			break
	check(finished, "Some mission ran to the end")
	check(not agent.is_busy(), "Back home, free again")



func test_one_agent_per_clan() -> void:
	var diplomacy := Diplomacy.new(ClanData.load_all(), ResourceTypeData.load_all())
	var wars := Wars.new(diplomacy)
	var agents := Agents.new()
	var first := agents.generate(1)
	var second := agents.generate(1)
	agents.agents.append_array([first, second])
	var clan: StringName = wars.fronts.keys()[0]
	var other: StringName = wars.fronts.keys()[1]
	check_eq(agents.start_mission(first, Agent.RELATIONS, clan, wars), Agents.Result.OK, "First agent goes")
	check(agents.agent_on(clan) == first, "Found on the clan")
	check_eq(agents.check_mission(second, clan, wars), Agents.Result.TARGET_TAKEN, "No second agent there")
	check_eq(agents.start_mission(second, Agent.SABOTAGE, clan, wars), Agents.Result.TARGET_TAKEN, "Not sent")
	check(not second.is_busy(), "Still idle")
	check_eq(agents.start_mission(second, Agent.SABOTAGE, other, wars), Agents.Result.OK, "Another clan is fine")

func test_caught_agents_anger_the_clan_and_may_die() -> void:
	var diplomacy := Diplomacy.new(ClanData.load_all(), ResourceTypeData.load_all())
	var wars := Wars.new(diplomacy)
	var agents := Agents.new()
	var clan: StringName = wars.fronts.keys()[0]
	var caught := 0
	var killed := 0
	for i in 400:
		var agent := agents.generate(1)
		agents.agents.append(agent)
		agent.mission = Agent.SABOTAGE  # past the one-per-clan rule, to count the odds
		agent.target = clan
		agent.turns_left = Agents.MISSION_TURNS
	var relation: int = diplomacy.clans[clan].memories.get(Diplomacy.MEMORY_AGENT, 0)
	agents.rng.seed = 3
	for event in agents.end_turn(diplomacy, 1, 1, 1):
		if event.event == &"caught":
			caught += 1
		elif event.event == &"killed":
			killed += 1
	check(caught + killed > 2 and caught + killed < 30, "About 3%% of 400 caught (%d)" % (caught + killed))
	check_eq(agents.agents.size(), 400 - killed, "The killed ones are gone")
	check(diplomacy.clans[clan].memories.get(Diplomacy.MEMORY_AGENT, 0) < relation, "The clan is angry")


func test_agents_are_saved() -> void:
	var state := _state()
	state.castle_level = 6
	_build(state, &"police", Vector2i(4, 4))
	state.recruit_agent(0)
	var agent: Agent = state.agents.agents[0]
	var clan: StringName = state.wars.fronts.keys()[1]
	state.start_agent_mission(agent, Agent.SABOTAGE, clan)
	agent.gain_xp(150)
	var copy := Agents.new()
	copy.load_save(JSON.parse_string(JSON.stringify(state.agents.to_save())))
	var back: Agent = copy.agents[0]
	check_eq([back.name, back.stars, back.level, back.xp, back.mission, back.target, back.turns_left],
			[agent.name, agent.stars, agent.level, agent.xp, Agent.SABOTAGE, clan, Agents.MISSION_TURNS], "Agent restored")
	check_eq(copy.candidates.size(), state.agents.candidates.size(), "Candidates restored")


func _net_from_parts(state: KingdomState) -> Dictionary[StringName, int]:
	var net: Dictionary[StringName, int] = {}
	for resource_id in state.get_income_breakdown():
		for entry: Dictionary in state.get_income_breakdown()[resource_id]:
			net[resource_id] = net.get(resource_id, 0) + entry.amount
	for resource_id in net.keys():
		if net[resource_id] == 0:
			net.erase(resource_id)
	return net
