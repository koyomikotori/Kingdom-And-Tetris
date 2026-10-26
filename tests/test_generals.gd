extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	# Generals only: advisors in the candidate list are tested in test_advisors.gd.
	state.generals.advisor_share = 0.0
	state.start()
	return state


func _rich(state: KingdomState) -> void:
	state.stockpile.add({&"food": 999, &"wood": 999, &"stone": 999, &"ore": 999, &"hardwood": 999, &"horses": 999})


func _general(state: KingdomState, might: int, command: int, stars: int = 3, trait_id: StringName = &"") -> General:
	var general := state.generals.generate(stars)
	general.might = might
	general.command = command
	general.trait_id = trait_id
	return general


func _run(simulator: BattleSimulator) -> BattleRecord:
	while not simulator.finished:
		simulator.step()
	return simulator.record


func test_data_loads() -> void:
	var generals := Generals.new()
	check_eq(generals.ranks.size(), 6, "Six star ranks")
	check_eq(generals.traits.size(), 6, "Six traits")
	check(generals.guard_unit != null and generals.guard_unit.unit_id == &"general_guard", "Bodyguard unit")
	check(not UnitData.load_all().any(func(u: UnitData) -> bool: return u.unit_id == &"general_guard"), "Not recruitable as a squad")


func test_generated_stats_follow_the_star_rank() -> void:
	var generals := Generals.new()
	generals.rng.seed = 5
	for stars in range(1, 7):
		var rank := generals.ranks[stars]
		for i in 30:
			var general := generals.generate(stars)
			var total := general.might + general.command
			check(total >= rank.total_min and total <= rank.total_max, "%d★ total %d in range" % [stars, total])
			check(general.might >= 1 and general.might <= 10 and general.command >= 1 and general.command <= 10, "Stats 1-10")
			check_eq(general.trait_id != &"", stars >= 2, "%d★ trait" % stars)


func test_candidates_respect_the_castle_level_and_refresh() -> void:
	var state := _state()
	check_eq(state.generals.candidates.size(), 3, "Three candidates at the start")
	check(state.generals.candidates.all(func(g: General) -> bool: return g.stars == 1), "Castle level 1: 1★ only")
	_rich(state)
	for i in 3:
		state.upgrade_castle()
	for i in 5:
		state.end_turn()
	check(state.generals.candidates.all(func(g: General) -> bool: return g.stars <= 4), "Up to castle level 4")
	check_eq(state.generals.candidates_turn, 6, "New list after 5 turns")
	var food := state.stockpile.get_amount(&"food")
	check(state.generals.buy_refresh(state.stockpile, state.castle_level, state.turn), "Paid refresh")
	check_eq(state.stockpile.get_amount(&"food"), food - 20, "20 food")


func test_recruiting_pays_and_the_first_general_commands() -> void:
	var state := _state()
	check_eq(state.generals.recruit(state.stockpile, 0), Generals.RecruitResult.CANNOT_AFFORD, "Too expensive")
	_rich(state)
	var food := state.stockpile.get_amount(&"food")
	var first := state.generals.candidates[0]
	check_eq(state.generals.recruit(state.stockpile, 0), Generals.RecruitResult.OK, "Hired")
	check_eq(state.stockpile.get_amount(&"food"), food - 30, "1★ costs 30 food")
	check(state.generals.commander == first, "First general commands")
	state.generals.add(state.generals.generate(1))
	state.generals.add(state.generals.generate(1))
	check_eq(state.generals.recruit(state.stockpile, 0), Generals.RecruitResult.NO_ROOM, "At most 3")
	var upkeep := state.get_army_upkeep()
	check_eq(upkeep.get(&"food", 0), 6, "3 x 2 food upkeep")
	var sources := state.get_income_breakdown()[&"food"].map(func(e: Dictionary) -> StringName: return e.source)
	check(sources.has(&"generals"), "Shown as its own income line")


func test_the_commander_leads_the_kingdoms_own_army() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.generals.add(_general(state, 6, 4))
	state.diplomacy.change_relation(&"south_farmers", 60)
	state.alliances.propose_alliance(_low_rng(), &"south_farmers")
	var side := state.create_kingdom_side(&"")
	var own := side.units[0]
	check(is_equal_approx(own.attack_mult, 1.18), "+3% per Võ lực point")
	check(is_equal_approx(own.defense_mult, 1.08), "+2% per Thống suất point")
	check(is_equal_approx(own.morale, 8 + 1.6), "+0.4 morale per point")
	var guard: BattleSide.Unit = side.units.filter(func(u: BattleSide.Unit) -> bool: return u.is_general_guard)[0]
	check_eq(guard.start_soldiers, 7, "3★ bodyguard")
	check_eq(side.general_name, state.generals.commander.name, "Named")
	for unit in side.units:
		if unit.ally != null:
			check_eq(unit.attack_mult, 1.0, "Allies get no bonus")
	state.generals.commander.wounded_turns = 2
	check(state.create_kingdom_side(&"").general_name.is_empty(), "A wounded commander stays home")


func test_traits_work_only_with_their_condition() -> void:
	var state := _state()
	state.army.add_squad(&"archer", 15)
	state.generals.add(_general(state, 1, 1, 3, &"forest_hunter"))
	check_eq(state.create_kingdom_side(&"").units[0].range_mult, 1.0, "Not enough forest")
	var placed := 0
	for cell in state.board.get_all_cells():
		if placed < 12 and not cell.has_building():
			state.board.set_land(cell.coord, &"forest", false)
			placed += 1
	check(is_equal_approx(state.create_kingdom_side(&"").units[0].range_mult, 1.25), "12 forest cells: +25% for archers")
	state.generals.commander.trait_id = &"castle_keeper"
	check(state.create_kingdom_side(&"", true).units[0].defense_mult > state.create_kingdom_side(&"", false).units[0].defense_mult,
			"Castle keeper only when defending")


func test_a_strong_commander_wins_more() -> void:
	var losses := []
	for with_general in [false, true]:
		var state := _state()
		for i in 3:
			state.army.add_squad(&"swordsman", 20)
		if with_general:
			state.generals.add(_general(state, 10, 10, 6))
		state.wars.declare_war(&"north_wolves")
		var invaders := state.wars.create_clan_side(&"north_wolves", 70, state.units)
		var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 4))
		losses.append(BattleOutcome.soldiers_lost(record, BattleRecord.ATTACKER))
	check(losses[1] > losses[0], "The enemy loses more against a 6★ commander (%d vs %d)" % [losses[1], losses[0]])


func test_a_fallen_general_costs_morale_and_may_die() -> void:
	var outcomes := {}
	for seed_value in 30:
		var state := _state()
		state.army.add_squad(&"spearman", 20)
		state.generals.add(_general(state, 1, 1, 1))
		state.generals.rng.seed = seed_value
		state.wars.declare_war(&"north_wolves")
		var invaders := state.wars.create_clan_side(&"north_wolves", 70, state.units)
		var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
		check(record.sides[BattleRecord.DEFENDER].general_fallen, "Overrun: the general falls")
		check(record.events.any(func(e: Dictionary) -> bool: return e.type == &"general_fallen"), "Battle event")
		var result := state.finish_invasion(&"north_wolves", record)
		outcomes[result.general.fate] = outcomes.get(result.general.fate, 0) + 1
		if result.general.fate == &"wounded":
			check_eq(state.generals.commander.wounded_turns, Generals.WOUND_TURNS, "Out for 3 turns")
		else:
			check(state.generals.generals.is_empty(), "Dead generals are gone")
	check(outcomes.get(&"dead", 0) > 0 and outcomes.get(&"wounded", 0) > outcomes.get(&"dead", 0), "Mostly wounded, sometimes dead")


func test_wounds_heal() -> void:
	var state := _state()
	state.generals.add(_general(state, 3, 3))
	state.generals.commander.wounded_turns = 2
	state.end_turn()
	var report := state.end_turn()
	check(state.generals.commander.is_ready(), "Ready again")
	check_eq(report.generals_healed.size(), 1, "Reported")


func test_generals_are_saved() -> void:
	var state := _state()
	state.generals.add(_general(state, 7, 5, 4, &"vanguard"))
	state.generals.add(_general(state, 2, 2, 1))
	state.generals.set_commander(state.generals.generals[1])
	state.generals.generals[0].wounded_turns = 2
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(JSON.stringify(loaded.generals.to_save()), JSON.stringify(state.generals.to_save()), "Same generals")
	check(loaded.generals.commander == loaded.generals.generals[1], "Same commander")
	data.erase("generals")
	var old := _state()
	old.load_save(data)
	check(old.generals.generals.is_empty() and old.generals.candidates.size() == 3, "Older saves get candidates")


func test_surrendered_general_follows_an_annexation() -> void:
	var state := _state()
	var event: EventData = state.events.events[&"surrendered_general"]
	check(not state.events.can_happen(state, event), "No annexation")
	state.events.annexed_turn = state.turn - 1
	check(state.events.can_happen(state, event), "Right after an annexation")
	state.events.pending = [{"event_id": &"surrendered_general", "clan_id": &""}] as Array[Dictionary]
	state.events.resolve(state, _low_rng(), 0)
	check_eq(state.generals.generals.size(), 1, "Joined")
	check(state.generals.generals[0].stars >= 3, "3★ or more")


func _low_rng() -> RandomNumberGenerator:
	for seed_value in 10000:
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.01:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			return rng
	return RandomNumberGenerator.new()


func test_the_bodyguard_fights_like_heroes() -> void:
	var generals := Generals.new()
	var swordsman: UnitData = UnitData.load_all().filter(func(u: UnitData) -> bool: return u.unit_id == &"swordsman")[0]
	var kingdom := BattleSide.new("Vương quốc")
	kingdom.add_unit(swordsman, 20)
	kingdom.add_unit(generals.guard_unit, 6)
	var enemy := BattleSide.new("Địch")
	for i in 3:
		enemy.add_unit(swordsman, 20)
	var record := _run(BattleSimulator.new(enemy, kingdom, 2))
	var soldier: BattleSide.Unit = record.sides[BattleRecord.DEFENDER].units[0]
	var guard: BattleSide.Unit = record.sides[BattleRecord.DEFENDER].units[1]
	var soldier_rate := soldier.kills / soldier.start_soldiers
	var guard_rate := guard.kills / guard.start_soldiers
	check(guard_rate > soldier_rate * 3.0, "A guard takes down several times more (%.2f vs %.2f per man)" % [guard_rate, soldier_rate])
	check(soldier.broken and not guard.broken, "The soldiers broke; the guards fought on to the last man")


func test_the_generals_stats_make_the_guard_stronger() -> void:
	var state := _state()
	state.generals.add(_general(state, 10, 10, 6))
	var guard: BattleSide.Unit = state.create_kingdom_side(&"").units.back()
	check(guard.is_general_guard, "Bodyguard")
	check(is_equal_approx(guard.attack_mult, 1.0 + 10 * Generals.GUARD_MIGHT_ATTACK + 10 * Generals.MIGHT_ATTACK), "Own Võ lực bonus plus the army's")
