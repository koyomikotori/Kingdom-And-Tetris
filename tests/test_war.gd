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


# --- Board ----------------------------------------------------------------------------------

func test_lose_edge_cells_takes_the_closest_owned_cells() -> void:
	var board := BoardData.create_starting_board(12)
	var lost := board.lose_edge_cells(Vector2i.UP, 6)
	lost.sort()
	check_eq(lost, [Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4), Vector2i(7, 5)],
			"Top row of the territory, then the cells beside the castle")
	for coord in lost:
		var cell := board.get_cell(coord)
		check(not cell.owned and not cell.has_terrain(), "%s is wild again" % coord)
	check_eq(board.get_building_cells(Vector2i(5, 5)).size(), 4, "The castle is never lost")


func test_lose_edge_cells_destroys_buildings_and_spares_the_castle() -> void:
	var board := BoardData.create_starting_board(12)
	board.place_building(&"barracks", Vector2i(4, 7), Vector2i.ONE)
	board.lose_edge_cells(Vector2i.DOWN, 1)
	check_eq(board.count_buildings(&"barracks"), 0, "Barracks on the lost cell is destroyed")
	var everything := board.lose_edge_cells(Vector2i.LEFT, 100)
	check_eq(everything.size(), 11, "Only the castle's 4 cells remain owned")
	check_eq(board.count_owned_cells(), 4, "Castle kept")


func test_expand_north_shifts_everything_down() -> void:
	var board := BoardData.create_starting_board(12)
	board.set_land(Vector2i(4, 4), &"forest", true)
	var shifts := []
	board.resized.connect(func(shift: Vector2i) -> void: shifts.append(shift))
	board.expand(Vector2i.UP, 4)
	check_eq([board.width, board.height], [12, 16], "Four new rows")
	check_eq(shifts, [Vector2i(0, 4)], "Reports the shift")
	check_eq(board.get_building_cells(Vector2i(5, 9)).size(), 4, "Castle moved with its origin")
	check_eq(board.get_cell(Vector2i(4, 8)).terrain_id, &"forest", "Terrain moved")
	check(board.get_cell(Vector2i(4, 8)).is_key, "Key cell moved")
	check(not board.get_cell(Vector2i(4, 0)).owned and not board.get_cell(Vector2i(4, 0)).has_terrain(), "New rows are wild")
	check_eq(board.count_owned_cells(), 16, "Territory unchanged")


func test_expand_east_keeps_coordinates() -> void:
	var board := BoardData.create_starting_board(12)
	board.expand(Vector2i.RIGHT, 4)
	check_eq([board.width, board.height], [16, 12], "Four new columns")
	check_eq(board.get_building_cells(Vector2i(5, 5)).size(), 4, "Castle stays put")


## Annexing a clan grows the board: upgraded buildings must keep their level (bug after M11f).
func test_expand_keeps_building_levels() -> void:
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var board := BoardData.create_starting_board(12)
		board.set_land(Vector2i(4, 3), &"hill", false)
		board.place_building(&"mine", Vector2i(4, 3), Vector2i.ONE)
		board.set_building_level(Vector2i(4, 3), 4)
		var shift := Vector2i(4 if direction == Vector2i.LEFT else 0, 4 if direction == Vector2i.UP else 0)
		board.expand(direction, 4)
		check_eq(board.get_building_level(Vector2i(4, 3) + shift), 4, "Level kept growing %s" % direction)


# --- Declaring war ------------------------------------------------------------------------

func test_player_declares_war() -> void:
	var state := _state()
	var wars := state.wars
	var others_before := state.diplomacy.clans[&"north_wolves"].relation
	state.diplomacy.propose(_low_rng(), &"south_farmers", &"wood", 5, &"food", 4, 10)
	check_eq(wars.declare_war(&"south_farmers"), Wars.DeclareResult.OK, "Declared")
	check(wars.at_war_with(&"south_farmers"), "At war")
	check(state.diplomacy.clans[&"south_farmers"].relation <= Wars.DECLARE_RELATION, "Target turns hostile")
	check_eq(state.diplomacy.clans[&"north_wolves"].relation, others_before + Wars.DECLARE_OTHERS_PENALTY, "Others trust less")
	check(state.diplomacy.get_agreement(&"south_farmers") == null, "Trade agreement ends")
	check_eq(wars.check_declare(&"south_farmers"), Wars.DeclareResult.ALREADY_AT_WAR, "Already at war")
	check_eq(wars.check_declare(&"east_merchants"), Wars.DeclareResult.NOT_NEIGHBOR, "Two steps away: not yet")
	check_eq(wars.check_declare(&"golden_eagle"), Wars.DeclareResult.NOT_NEIGHBOR, "Distant clans cannot be fought")


func test_hostile_aggressive_clan_may_declare_war() -> void:
	var state := _state()
	state.diplomacy.change_relation(&"north_wolves", -100)
	var declared := state.wars.end_turn(_low_rng())
	check(declared.has(&"north_wolves"), "Hostile wolves declare war")
	check(state.wars.at_war_with(&"north_wolves"), "At war now")
	var calm := _state()
	calm.diplomacy.change_relation(&"north_wolves", -100)
	check(calm.wars.end_turn(_high_rng()).is_empty(), "Not every turn")


func test_war_keeps_relation_hostile_and_armies_regrow() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	state.wars.lose_soldiers(&"north_wolves", 30)
	for i in 5:
		state.diplomacy.end_turn()
		state.wars.end_turn(_high_rng())
	check(state.diplomacy.clans[&"north_wolves"].relation <= Wars.DECLARE_RELATION, "No drift back to friendly during war")
	var front := state.wars.fronts[&"north_wolves"]
	check_eq(front.strength, 50 - 30 + 5 * ceili(front.max_strength * Wars.STRENGTH_REGEN_SHARE), "+10% of the maximum per turn")
	for i in 50:
		state.wars.end_turn(_high_rng())
	check_eq(front.strength, front.max_strength, "Capped at the maximum")


func test_clan_armies_grow_over_time() -> void:
	var state := _state()
	check_eq(state.wars.max_strength_at(&"north_wolves", 1), 50, "Starting strength on turn 1")
	check_eq(state.wars.max_strength_at(&"north_wolves", 51), 75, "+1% of it per turn")
	check_eq(state.wars.max_strength_at(&"north_wolves", 500), 100, "At most twice as many")
	state.wars.end_turn(_high_rng(), 50)
	check_eq(state.wars.fronts[&"north_wolves"].max_strength, 75, "End of turn 50: the maximum for turn 51")


func test_clan_army_follows_its_composition() -> void:
	var state := _state()
	var side := state.wars.create_clan_side(&"north_wolves", 42, state.units)
	check_eq(side.start_total(), 42, "Every soldier is placed")
	var by_type := {}
	for unit in side.units:
		by_type[unit.data.unit_id] = by_type.get(unit.data.unit_id, 0) + unit.start_soldiers
		check(unit.start_soldiers <= unit.data.squad_size, "Squads are not oversized")
	check(by_type[&"swordsman"] > by_type[&"spearman"], "Wolves are mostly swordsmen (3:2:2)")


# --- Invasions ----------------------------------------------------------------------------

func test_invasion_waits_for_cooldown_then_arrives() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	check_eq(state.wars.pick_invader(_low_rng()), &"", "Not right after the declaration")
	for i in Wars.INVASION_COOLDOWN:
		state.wars.end_turn(_high_rng())
	check_eq(state.wars.pick_invader(_low_rng()), &"north_wolves", "Invades once the cooldown is over")
	check_eq(state.wars.pick_invader(_low_rng()), &"", "Cooldown starts again")


func test_lost_invasion_costs_land_on_their_side() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	var simulator := BattleSimulator.new(state.wars.create_clan_side(&"north_wolves", 40, state.units),
			RaidSystem.create_kingdom_side(state), 1)
	var result := state.finish_invasion(&"north_wolves", _run(simulator))
	check(not result.won, "No army: the invasion wins")
	check_eq(result.lost_cells.size(), Wars.LAND_LOST_PER_DEFEAT, "Six cells lost")
	for coord: Vector2i in result.lost_cells:
		check(coord.x >= 6, "The wolves are east of the kingdom: lost cells are on the east side (%s)" % coord)


func test_won_invasion_weakens_the_clan() -> void:
	var state := _state()
	for i in 4:
		state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"south_farmers")
	var simulator := BattleSimulator.new(state.wars.create_clan_side(&"south_farmers", 18, state.units),
			RaidSystem.create_kingdom_side(state), 2)
	var result := state.finish_invasion(&"south_farmers", _run(simulator))
	check(result.won, "Four squads beat 18 farmers")
	check(result.lost_cells.is_empty(), "No land lost")
	check_eq(state.wars.fronts[&"south_farmers"].strength, 40 - result.enemy_lost, "The clan lost soldiers")
	check(result.enemy_lost > 0, "Some of them fell")


# --- Attacking --------------------------------------------------------------------------

func test_attack_requires_war_and_an_army_once_per_turn() -> void:
	var state := _state()
	check(state.start_attack(&"south_farmers") == null, "Not at war")
	state.wars.declare_war(&"south_farmers")
	check(state.start_attack(&"south_farmers") == null, "No army")
	state.army.add_squad(&"swordsman", 20)
	check(state.start_attack(&"south_farmers") != null, "Attack starts")
	check_eq(state.wars.check_attack(&"south_farmers", true), Wars.AttackResult.ALREADY_ATTACKED, "Once per turn")


func test_failed_attack_costs_the_army_and_compensation() -> void:
	var state := _state()
	state.stockpile.add({&"food": 20, &"wood": 8})
	state.army.add_squad(&"archer", 15)
	state.wars.declare_war(&"north_wolves")
	var result := state.finish_attack(&"north_wolves", _run(state.start_attack(&"north_wolves")))
	check(not result.won, "One archer squad loses to the wolves")
	check_eq(state.army.count_squads(), 0, "The whole army is lost")
	check_eq(result.compensation, {&"food": 5, &"wood": 2}, "25% compensation")
	check_eq([state.stockpile.get_amount(&"food"), state.stockpile.get_amount(&"wood")], [15, 6], "Paid")


func test_retreating_from_an_attack_keeps_half() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"north_wolves")
	var simulator := state.start_attack(&"north_wolves")
	for i in 5:
		simulator.step()
	simulator.retreat(BattleRecord.ATTACKER)
	var alive := simulator.record.sides[BattleRecord.ATTACKER].units[0].alive()
	state.finish_attack(&"north_wolves", simulator.record)
	check_eq(state.army.count_soldiers(), roundi(alive * 0.5), "Retreat keeps half of the unbroken squad")


func test_winning_attack_loots_and_can_annex() -> void:
	var state := _state()
	for i in 4:
		state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"south_farmers")
	state.wars.fronts[&"south_farmers"].strength = 6
	var result := state.finish_attack(&"south_farmers", _run(state.start_attack(&"south_farmers")))
	check(result.won, "Won")
	check_eq(result.loot, {&"food": result.enemy_lost, &"wood": result.enemy_lost, &"stone": result.enemy_lost}, "1 of each per fallen enemy")
	check(result.annexed, "Below 15%: the clan surrenders")
	check(state.wars.fronts[&"south_farmers"].annexed, "Marked annexed")
	check_eq([state.board.width, state.board.height], [12, 12], "First annexation: no land yet (every second one)")
	check_eq(result.expanded, Vector2i.ZERO, "…reported")
	check_eq(state.wars.check_declare(&"steppe_tribes"), Wars.DeclareResult.OK, "Steppe tribes border the kingdom now")
	state.wars.declare_war(&"steppe_tribes")
	state.wars.fronts[&"steppe_tribes"].strength = 6
	result = state.finish_attack(&"steppe_tribes", _run(state.start_attack(&"steppe_tribes")))
	check(result.annexed, "Second annexation")
	check_eq([state.board.width, state.board.height], [12, 12 + Wars.ANNEX_EXPANSION], "Second annexation: land on top")
	check_eq(result.expanded, Vector2i.UP, "…reported")
	var stock: Dictionary[StringName, int] = {&"food": 50}
	state.stockpile.add(stock)
	check_eq(state.diplomacy.check_trade(state.stockpile, &"south_farmers", &"food", 5, &"wood"),
			Diplomacy.TradeResult.REFUSED, "No trading with an annexed clan")


func test_winning_without_crushing_them_does_not_annex() -> void:
	var state := _state()
	for i in 4:
		state.army.add_squad(&"swordsman", 20)
	state.wars.declare_war(&"south_farmers")
	state.wars.fronts[&"south_farmers"].strength = 30
	state.wars.fronts[&"south_farmers"].max_strength = 1000
	var result := state.finish_attack(&"south_farmers", _run(state.start_attack(&"south_farmers")))
	check(not result.annexed or state.wars.fronts[&"south_farmers"].strength < 150, "Annex only below 15% of maximum")
	check_eq([state.board.width, state.board.height], [12, 12], "No land (and a first annexation adds none either)")


# --- Peace ------------------------------------------------------------------------------

func test_peace_chance_rises_with_losses_and_tribute() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	var none: Dictionary[StringName, int] = {}
	var fresh := state.wars.peace_chance(&"north_wolves", none)
	var tribute: Dictionary[StringName, int] = {&"stone": 20}
	check(state.wars.peace_chance(&"north_wolves", tribute) > fresh, "Tribute helps")
	state.wars.lose_soldiers(&"north_wolves", 50)
	check(state.wars.peace_chance(&"north_wolves", none) > fresh, "Losses make them want peace")


func test_accepted_peace_ends_the_war_with_a_truce() -> void:
	var state := _state()
	state.stockpile.add({&"stone": 20})
	state.wars.declare_war(&"north_wolves")
	# A fresh war at -60 relation has ~0% chance; after heavy losses they listen.
	state.wars.lose_soldiers(&"north_wolves", 40)
	var tribute: Dictionary[StringName, int] = {&"stone": 10}
	check(state.wars.peace_chance(&"north_wolves", tribute) > 0.2, "Worth asking now")
	check_eq(state.wars.propose_peace(_low_rng(), state.stockpile, &"north_wolves", tribute), Wars.PeaceResult.OK, "Accepted")
	check(not state.wars.at_war_with(&"north_wolves"), "War over")
	check_eq(state.stockpile.get_amount(&"stone"), 10, "Tribute paid")
	check(state.diplomacy.clans[&"north_wolves"].relation >= Wars.PEACE_MIN_RELATION, "Relation lifted to Tense")
	check_eq(state.wars.check_declare(&"north_wolves"), Wars.DeclareResult.TRUCE, "Truce")
	for i in Wars.TRUCE_TURNS:
		state.wars.end_turn(_high_rng())
	check_eq(state.wars.check_declare(&"north_wolves"), Wars.DeclareResult.OK, "Truce over")


func test_declined_peace_keeps_tribute_and_waits() -> void:
	var state := _state()
	state.stockpile.add({&"stone": 20})
	state.wars.declare_war(&"north_wolves")
	var tribute: Dictionary[StringName, int] = {&"stone": 10}
	check_eq(state.wars.propose_peace(_high_rng(), state.stockpile, &"north_wolves", tribute), Wars.PeaceResult.DECLINED, "Declined")
	check_eq(state.stockpile.get_amount(&"stone"), 20, "Tribute kept")
	check_eq(state.wars.check_peace(state.stockpile, &"north_wolves", tribute), Wars.PeaceResult.ASKED_THIS_TURN, "Wait a turn")


func test_end_turn_can_bring_an_invasion() -> void:
	var state := _state()
	state.wars.declare_war(&"north_wolves")
	state.wars.fronts[&"north_wolves"].turns_since_invasion = 100
	var found := false
	for i in 30:
		var report := state.end_turn()
		if report.has("pending_invasion"):
			found = true
			check_eq(report.pending_invasion.clan_id, &"north_wolves", "The wolves invade")
			check(not report.has("pending_raid"), "At most one battle per turn")
			break
	check(found, "An invasion happens within 30 turns at 25% per turn")


# --- Wariness and plunder -------------------------------------------------------------------

func test_threat_grows_with_territory_annexations_and_army() -> void:
	var state := _state()
	check_eq(state.get_threat(), 0, "Starting kingdom is no threat")
	for x in 12:
		state.board.set_land(Vector2i(x, 0), &"grass", false)
	check_eq(state.get_threat(), 3, "12 extra cells = 3")
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"swordsman", 20)
	check_eq(state.get_threat(), 5, "40 soldiers = +2")
	state.wars.fronts[&"south_farmers"].annexed = true
	check_eq(state.get_threat(), 20, "An annexed clan = +15")


func test_wary_clans_drift_below_their_base() -> void:
	var state := _state()
	state.diplomacy.threat = 30
	check_eq(state.diplomacy.target_relation(&"north_wolves"), -15 - 30, "Aggressive: full threat")
	check_eq(state.diplomacy.target_relation(&"east_merchants"), 20 - 12, "Merchants: 0.4 x threat")
	for i in 60:
		state.diplomacy.end_turn()
	check_eq(state.diplomacy.clans[&"north_wolves"].relation, -45, "Wolves settle at -45 instead of -15")


func test_tense_aggressive_clan_may_declare_war() -> void:
	var state := _state()
	state.diplomacy.change_relation(&"north_wolves", -20)  # -10 -> -30: tense
	state.diplomacy.change_relation(&"west_fortress", -30)  # -5 -> -35: tense, but isolated
	var declared := state.wars.end_turn(_low_rng())
	check_eq(declared, [&"north_wolves"] as Array[StringName], "Only the aggressive clan goes to war while merely tense")


func test_lost_invasion_also_plunders_resources() -> void:
	var state := _state()
	state.stockpile.add({&"food": 10, &"wood": 5, &"stone": 3})
	state.wars.declare_war(&"north_wolves")
	var simulator := BattleSimulator.new(state.wars.create_clan_side(&"north_wolves", 40, state.units),
			RaidSystem.create_kingdom_side(state), 1)
	var result := state.finish_invasion(&"north_wolves", _run(simulator))
	check_eq(result.resources_lost, {&"food": 4, &"wood": 2, &"stone": 1}, "40% of each resource, rounded down")
	check_eq([state.stockpile.get_amount(&"food"), state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")],
			[6, 3, 2], "Stockpile reduced")
