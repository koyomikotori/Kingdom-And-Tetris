extends "res://tests/test_suite.gd"
## M11e: squad and general experience (GDD §8).

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	return state


func _rich(state: KingdomState) -> void:
	state.stockpile.add({&"food": 999, &"wood": 999, &"stone": 999, &"ore": 999, &"hardwood": 999, &"horses": 999})


func _run(simulator: BattleSimulator) -> BattleRecord:
	while not simulator.finished:
		simulator.step()
	return simulator.record


func test_squad_levels_follow_xp() -> void:
	check_eq(Experience.squad_level(0.0), 0, "Recruit")
	check_eq(Experience.squad_level(99.9), 0, "Still a recruit")
	check_eq(Experience.squad_level(100.0), 1, "Veteran")
	check_eq(Experience.squad_level(300.0), 2, "Elite")
	check_eq(Experience.squad_level(5000.0), 2, "Elite is the top")
	check_eq(Experience.squad_progress(200.0), 0.5, "Halfway from Veteran to Elite")
	check_eq(Experience.squad_progress(400.0), 1.0, "Full bar at the top")


func test_new_soldiers_dilute_xp() -> void:
	var army := Army.new()
	army.add_squad(&"swordsman", 10)
	var squad := army.squads[0]
	squad.xp = 200.0
	army.add_soldiers(squad, 10)
	check_eq(squad.soldiers, 20, "Soldiers added")
	check_eq(squad.xp, 100.0, "Half the soldiers are new: half the XP")
	check_eq(squad.level(), 1, "Elite-track squad dropped back to Veteran")
	army.set_soldiers(squad, 5)
	check_eq(squad.xp, 100.0, "Losing soldiers keeps the average")


func test_training_needs_a_barracks_and_stops_at_veteran() -> void:
	var state := _state()
	_rich(state)
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"spearman", 20)
	state.army.squads[1].xp = 250.0
	state.end_turn()
	check_eq(state.army.squads[0].xp, 0.0, "No barracks: no training")
	state.build(&"barracks", Vector2i(4, 4))
	for i in 12:
		state.end_turn()
	check_eq(state.army.squads[0].xp, 100.0, "Trained up to Veteran and no further")
	check_eq(state.army.squads[0].level(), 1, "Veteran")
	check_eq(state.army.squads[1].xp, 250.0, "Squads above the cap keep their XP")


func test_replenishment_dilutes_xp() -> void:
	var state := _state()
	_rich(state)
	state.build(&"barracks", Vector2i(4, 4))
	state.army.add_squad(&"swordsman", 18)
	state.army.squads[0].xp = 300.0
	state.end_turn()
	var squad := state.army.squads[0]
	check_eq(squad.soldiers, 20, "Replenished")
	# 300 × 18 / 20 = 270, then the squad is above the training cap: no training XP.
	check_eq(squad.xp, 270.0, "Diluted by the 2 new soldiers")


func test_levels_raise_battle_stats() -> void:
	var units := UnitData.load_all()
	var sword: UnitData = units.filter(func(u: UnitData) -> bool: return u.unit_id == &"swordsman")[0]
	var archer: UnitData = units.filter(func(u: UnitData) -> bool: return u.unit_id == &"archer")[0]
	var elite := Army.Squad.new(&"swordsman", 20, 300.0)
	var unit := BattleSide.Unit.new(sword, 20, elite)
	check_eq(unit.level, 2, "Elite in battle")
	check_eq(unit.melee_attack(), float(sword.melee_attack + 4), "+4 melee attack")
	check_eq(unit.melee_defense(), float(sword.melee_defense + 4), "+4 melee defense")
	check_eq(unit.morale, float(sword.morale + 4), "+4 morale")
	var veteran_archers := BattleSide.Unit.new(archer, 20, Army.Squad.new(&"archer", 20, 100.0))
	check_eq(veteran_archers.range_attack(), float(archer.range_attack + 2), "Ranged units: +2 range attack")
	check_eq(veteran_archers.melee_attack(), float(archer.melee_attack), "…instead of melee attack")
	var bandit := BattleSide.Unit.new(sword, 20, null)
	check_eq(bandit.level, 0, "Units without a squad have no level")


func test_elite_squads_win_mirror_battles() -> void:
	var wins := 0
	var units := UnitData.load_all()
	var sword: UnitData = units.filter(func(u: UnitData) -> bool: return u.unit_id == &"swordsman")[0]
	for seed_value in 10:
		var elite := BattleSide.new("Elite")
		elite.add_unit(sword, 20, Army.Squad.new(&"swordsman", 20, 300.0))
		var green := BattleSide.new("Green")
		green.add_unit(sword, 20, Army.Squad.new(&"swordsman", 20, 0.0))
		if BattleSimulator.simulate(green, elite, seed_value).winner == BattleRecord.DEFENDER:
			wins += 1
	check_eq(wins, 10, "Elite swordsmen beat the same number of recruits")


func test_battles_give_squads_xp() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.army.add_squad(&"spearman", 20)
	state.wars.declare_war(&"north_wolves")
	var invaders := state.wars.create_clan_side(&"north_wolves", 10, state.units)
	var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
	var result := state.finish_invasion(&"north_wolves", record)
	check(result.won, "An easy win")
	var kingdom := record.sides[BattleRecord.DEFENDER]
	for i in 2:
		var unit := kingdom.units[i]
		check_eq(unit.squad.xp, Experience.squad_battle_xp(unit.kills, true), "Base + kills + win XP")
		check(unit.squad.xp >= Experience.SQUAD_BATTLE_XP + Experience.SQUAD_WIN_XP, "At least base + win")


func test_routed_squads_gain_nothing() -> void:
	var state := _state()
	state.army.add_squad(&"spearman", 20)
	state.wars.declare_war(&"north_wolves")
	var invaders := state.wars.create_clan_side(&"north_wolves", 80, state.units)
	var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
	state.finish_invasion(&"north_wolves", record)
	var unit := record.sides[BattleRecord.DEFENDER].units[0]
	if state.army.squads.has(unit.squad):
		check_eq(unit.squad.xp, Experience.squad_battle_xp(unit.kills, false), "Survivors of a defeat: base + kills")
	else:
		check_eq(unit.squad.xp, 0.0, "A lost squad gains nothing")


func test_general_levels_and_points() -> void:
	var general := General.new()
	general.stars = 1
	check_eq(general.max_level(), 3, "1★: max level 3")
	check_eq(general.gain_xp(50), 0, "Not enough for level 2")
	check_eq(general.gain_xp(60), 1, "100 XP for level 2")
	check_eq([general.level, general.xp, general.points], [2, 10, 1], "Leftover XP carries over")
	check_eq(general.gain_xp(1000), 1, "Capped at level 3")
	check_eq([general.level, general.xp, general.points], [3, 0, 2], "XP past the cap is dropped")
	var generals := Generals.new()
	general.might = 9
	general.command = 10
	generals.add(general)
	check(not generals.can_spend_point(general, &"command"), "Thống suất already at 10")
	check(not generals.spend_point(general, &"command"), "Nothing changes")
	check(generals.spend_point(general, &"might"), "Add to Võ lực")
	check_eq([general.might, general.points], [10, 1], "+1 Võ lực, one point left")
	check(not generals.spend_point(general, &"might"), "Võ lực at 10 too")
	check_eq(general.points, 1, "Point kept for later")


func test_only_the_commander_gains_battle_xp() -> void:
	var state := _state()
	state.army.add_squad(&"spearman", 20)
	state.army.add_squad(&"swordsman", 20)
	var leader := state.generals.generate(3)
	var reserve := state.generals.generate(3)
	state.generals.add(leader)
	state.generals.add(reserve)
	state.wars.declare_war(&"north_wolves")
	var invaders := state.wars.create_clan_side(&"north_wolves", 10, state.units)
	var record := _run(BattleSimulator.new(invaders, state.create_kingdom_side(&"north_wolves"), 1))
	var result := state.finish_invasion(&"north_wolves", record)
	var guard: BattleSide.Unit = record.sides[BattleRecord.DEFENDER].units.filter(
			func(u: BattleSide.Unit) -> bool: return u.is_general_guard)[0]
	var expected := Experience.general_battle_xp(guard.kills, true)
	check_eq(result.general.xp, expected, "Base + win + guard kills")
	var twin := General.new()
	twin.stars = leader.stars
	twin.gain_xp(expected)
	check_eq([leader.level, leader.xp, leader.points], [twin.level, twin.xp, twin.points], "The commander gained it")
	check(leader.level > 1 or leader.xp > 0, "Some progress")
	check_eq([reserve.level, reserve.xp], [1, 0], "The reserve general gains nothing")


func test_experience_is_saved() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.army.squads[0].xp = 123.5
	var general := state.generals.generate(4)
	general.gain_xp(250)
	state.generals.add(general)
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.army.squads[0].xp, 123.5, "Squad XP")
	var copy := loaded.generals.generals[0]
	check_eq([copy.level, copy.xp, copy.points], [general.level, general.xp, general.points], "General level, XP, points")


func test_version_1_saves_are_upgraded() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	state.generals.add(state.generals.generate(2))
	var game: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	# Strip the v2 fields to get a v1 save.
	for squad: Dictionary in game.army:
		squad.erase("xp")
	for general: Dictionary in game.generals.generals + game.generals.candidates:
		for key in ["level", "xp", "points"]:
			general.erase(key)
	var loaded := _state()
	loaded.load_save(SaveSystem.migrate(game, 1))
	check_eq(loaded.army.squads[0].xp, 0.0, "Old squads start as recruits")
	var copy := loaded.generals.generals[0]
	check_eq([copy.level, copy.xp, copy.points], [1, 0, 0], "Old generals start at level 1")
