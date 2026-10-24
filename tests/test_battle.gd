extends "res://tests/test_suite.gd"

var terrains := TerrainLibrary.load_all()
var buildings := BuildingData.load_all()
var unit_list := UnitData.load_all()
var enemies := UnitData.load_enemies()


func _unit(id: StringName, row: UnitData.Row, kind: UnitData.AttackKind, hp: int = 100, attack: int = 10, defense: int = 0) -> UnitData:
	var unit := UnitData.new()
	unit.unit_id = id
	unit.display_name = String(id)
	unit.max_hp = hp
	unit.attack = attack
	unit.defense = defense
	unit.row = row
	unit.attack_kind = kind
	return unit


func _side(groups: Array) -> BattleSide:
	var side := BattleSide.new("test")
	for pair in groups:
		side.add_group(pair[0], pair[1])
	return side


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 5)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains, buildings, unit_list, 9)
	state.start()
	return state


func _hp_after_first_step(record: BattleRecord, side: int) -> Array:
	return record.steps[0].hp[side]


func test_unit_data_has_rows_and_kinds() -> void:
	var by_id := {}
	for unit in unit_list:
		by_id[unit.unit_id] = unit
	check_eq(by_id[&"swordsman"].row, UnitData.Row.FRONT, "Swordsmen fight in the front row")
	check_eq(by_id[&"spearman"].row, UnitData.Row.MIDDLE, "Spearmen fight in the middle row")
	check_eq([by_id[&"archer"].row, by_id[&"archer"].attack_kind], [UnitData.Row.BACK, UnitData.AttackKind.BOW], "Archers shoot from the back")
	check(enemies.has(&"bandit_thug") and enemies.has(&"bandit_archer"), "Bandit units are loaded")


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_same_seed_same_battle() -> void:
	var a := BattleSimulator.run(RaidSystem.create_bandit_side(RaidData.load_bandits(), enemies, 12, _seeded_rng(1)),
			_side([[unit_list[0], 4], [unit_list[2], 2]]), 77)
	var b := BattleSimulator.run(RaidSystem.create_bandit_side(RaidData.load_bandits(), enemies, 12, _seeded_rng(1)),
			_side([[unit_list[0], 4], [unit_list[2], 2]]), 77)
	check_eq(a.steps, b.steps, "Identical step logs")
	check_eq([a.winner, a.end_reason], [b.winner, b.end_reason], "Identical outcome")


func test_no_defenders_loses_immediately() -> void:
	var record := BattleSimulator.run(_side([[enemies[&"bandit_thug"], 3]]), _side([]), 1)
	check_eq(record.winner, BattleRecord.ATTACKER, "Bandits win against nobody")
	check_eq(record.end_reason, BattleRecord.EndReason.NO_ARMY, "Reason is no army")
	check(record.steps.is_empty(), "No steps are fought")


func test_phase_order_guns_arrows_melee() -> void:
	var gun := _unit(&"gun", UnitData.Row.BACK, UnitData.AttackKind.GUN, 100, 1)
	var bow := _unit(&"bow", UnitData.Row.BACK, UnitData.AttackKind.BOW, 100, 1)
	var sword := _unit(&"sword", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 1)
	var record := BattleSimulator.run(_side([[sword, 10], [gun, 2]]), _side([[sword, 10], [bow, 2]]), 3)
	var phases := record.steps.map(func(step: Dictionary) -> StringName: return step.phase)
	check(phases.size() >= 3, "At least guns, arrows and one melee round")
	check_eq(phases.slice(0, 3), [BattleSimulator.PHASE_GUNS, BattleSimulator.PHASE_ARROWS, BattleSimulator.PHASE_MELEE],
			"Guns fire first, then arrows, then melee")


func test_skips_ranged_phases_without_ranged_units() -> void:
	var sword := _unit(&"sword", UnitData.Row.FRONT, UnitData.AttackKind.MELEE)
	var record := BattleSimulator.run(_side([[sword, 5]]), _side([[sword, 5]]), 3)
	check_eq(record.steps[0].phase, BattleSimulator.PHASE_MELEE, "Melee-only armies start with melee")


func test_guns_hit_only_the_front_row() -> void:
	var gun := _unit(&"gun", UnitData.Row.BACK, UnitData.AttackKind.GUN, 100, 20)
	var front := _unit(&"front", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 1)
	var back := _unit(&"back", UnitData.Row.BACK, UnitData.AttackKind.MELEE, 100, 1)
	var record := BattleSimulator.run(_side([[gun, 3]]), _side([[front, 10], [back, 10]]), 4)
	var hp := _hp_after_first_step(record, BattleRecord.DEFENDER)
	check(hp[0] < 1000.0, "Front row took bullets")
	check_eq(hp[1], 1000.0, "Back row untouched by bullets")


func test_arrows_spread_over_all_rows() -> void:
	var bow := _unit(&"bow", UnitData.Row.BACK, UnitData.AttackKind.BOW, 100, 20)
	var front := _unit(&"front", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 1)
	var middle := _unit(&"middle", UnitData.Row.MIDDLE, UnitData.AttackKind.MELEE, 100, 1)
	var back := _unit(&"back", UnitData.Row.BACK, UnitData.AttackKind.MELEE, 100, 1)
	var record := BattleSimulator.run(_side([[bow, 6]]), _side([[front, 10], [middle, 10], [back, 10]]), 4)
	var hp := _hp_after_first_step(record, BattleRecord.DEFENDER)
	for i in 3:
		check(hp[i] < 1000.0 and hp[i] > 900.0, "Row %d took a share of the arrows (hp %.1f)" % [i, hp[i]])


func test_melee_hits_front_row_before_back_row() -> void:
	var sword := _unit(&"sword", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 15)
	var front := _unit(&"front", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 1)
	var back := _unit(&"back", UnitData.Row.BACK, UnitData.AttackKind.MELEE, 100, 1)
	var record := BattleSimulator.run(_side([[sword, 5]]), _side([[front, 10], [back, 10]]), 4)
	var hp := _hp_after_first_step(record, BattleRecord.DEFENDER)
	check(hp[0] < 1000.0, "Front row is hit in melee")
	check_eq(hp[1], 1000.0, "Back row is safe while the front row stands")


func test_defense_reduces_damage_but_never_below_one() -> void:
	var weak := _unit(&"weak", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 2)
	var wall := _unit(&"wall", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 1000, 1, 50)
	var record := BattleSimulator.run(_side([[weak, 10]]), _side([[wall, 1]]), 4)
	var lost: float = 1000.0 - record.steps[0].hp[BattleRecord.DEFENDER][0]
	check(lost >= 9.0 and lost <= 11.0, "10 soldiers deal ~1 damage each against high defense (got %.2f)" % lost)


func test_strong_army_routs_weak_army_and_damage_is_capped() -> void:
	var sword := _unit(&"sword", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100, 30, 5)
	var thug := _unit(&"thug", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 50, 5)
	var attacker := _side([[thug, 4]])
	var defender := _side([[sword, 10]])
	var record := BattleSimulator.run(attacker, defender, 4)
	check_eq(record.winner, BattleRecord.DEFENDER, "Strong defenders win")
	check(record.end_reason in [BattleRecord.EndReason.WIPED_OUT, BattleRecord.EndReason.ROUTED], "Loser was wiped out or routed")
	check(defender.groups[0].damage_dealt <= 200.0 + 0.01, "Damage dealt never exceeds the enemy's total HP")


func test_round_limit_tie_goes_to_defender() -> void:
	var tank := _unit(&"tank", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100000, 1, 100)
	var record := BattleSimulator.run(_side([[tank, 5]]), _side([[tank, 5]]), 4)
	check_eq(record.end_reason, BattleRecord.EndReason.ROUND_LIMIT, "Nobody can kill anyone")
	check_eq(record.steps.size(), BattleSimulator.MAX_MELEE_ROUNDS, "All melee rounds were fought")
	check_eq(record.winner, BattleRecord.DEFENDER, "Defender holds on a tie")


func test_raid_chance_and_watchtowers() -> void:
	var raid := RaidData.load_bandits()
	var state := _state()
	check_eq(RaidSystem.get_raid_chance(state, raid), 0.0, "No raids on turn 1")
	state.turn = 6
	check(is_equal_approx(RaidSystem.get_raid_chance(state, raid), 0.15), "15% from turn 6")
	state.stockpile.add({&"wood": 50, &"stone": 50})
	state.build(&"watchtower", Vector2i(4, 4))
	state.build(&"watchtower", Vector2i(7, 4))
	check(is_equal_approx(RaidSystem.get_raid_chance(state, raid), 0.07), "Two towers: 15% - 8%")
	check_eq(state.build(&"watchtower", Vector2i(4, 7)), BuildRules.Result.OK, "Third tower allowed")
	check_eq(state.build(&"watchtower", Vector2i(7, 7)), BuildRules.Result.LIMIT_REACHED, "Fourth tower refused")
	check(is_equal_approx(RaidSystem.get_raid_chance(state, raid), 0.03), "Three towers: 3%")
	state.buildings_supplied = false
	check(is_equal_approx(RaidSystem.get_raid_chance(state, raid), 0.15), "Unpaid towers do nothing")


func test_watchtower_upkeep_paid_or_paused() -> void:
	var state := _state()
	state.stockpile.add({&"wood": 4, &"stone": 3, &"food": 1})
	state.build(&"watchtower", Vector2i(4, 4))
	check_eq(state.get_building_upkeep(), {&"food": 1}, "Tower costs 1 food per turn")
	var report := state.end_turn()
	check(report.buildings_supplied, "Upkeep paid with 1 food")
	check_eq(state.stockpile.get_amount(&"food"), 0, "Food spent on upkeep")
	report = state.end_turn()
	check(not report.buildings_supplied, "No food left: tower paused")
	check(not state.buildings_supplied, "State remembers the pause for the raid roll")


func test_bandit_army_grows_with_turns() -> void:
	var raid := RaidData.load_bandits()
	var early := RaidSystem.create_bandit_side(raid, enemies, 6, RandomNumberGenerator.new())
	var late := RaidSystem.create_bandit_side(raid, enemies, 30, RandomNumberGenerator.new())
	check_eq(early.start_total(), 2 + floori(6 * 0.34), "Turn 6 bandit count")
	check(late.start_total() > early.start_total(), "More bandits later")


func test_lost_raid_takes_resources_and_soldiers() -> void:
	var state := _state()
	state.stockpile.add({&"food": 10, &"wood": 7, &"stone": 3})
	state.army.add(&"archer", 1)
	var bandits := _side([[enemies[&"bandit_thug"], 30]])
	var result := RaidSystem.resolve(state, RaidData.load_bandits(), bandits, 5)
	check(not result.won, "One archer cannot stop 30 bandits")
	check_eq(result.resources_lost, {&"food": 3, &"wood": 2}, "30% of each resource, rounded down (stone 0.9 -> 0)")
	check_eq([state.stockpile.get_amount(&"food"), state.stockpile.get_amount(&"wood"), state.stockpile.get_amount(&"stone")],
			[7, 5, 3], "Stockpile reduced")
	check_eq(state.army.get_total(), 0, "The archer died or fled")


func test_lost_raid_survivors_flee() -> void:
	var state := _state()
	state.army.add(&"swordsman", 10)
	var stalemate := _unit(&"rock", UnitData.Row.FRONT, UnitData.AttackKind.MELEE, 100000, 1000, 100)
	var result := RaidSystem.resolve(state, RaidData.load_bandits(), _side([[stalemate, 1]]), 5)
	var record: BattleRecord = result.record
	check(not result.won, "Invincible bandit wins")
	var survivors: int = record.sides[BattleRecord.DEFENDER].groups[0].alive()
	check_eq(result.fled.get(&"swordsman", 0), roundi(survivors * 0.3), "30% of survivors flee")
	check_eq(state.army.get_count(&"swordsman"), survivors - roundi(survivors * 0.3), "Army keeps the rest")


func test_won_raid_gives_reward_and_applies_casualties() -> void:
	var state := _state()
	state.army.add(&"swordsman", 12)
	state.army.add(&"archer", 4)
	var bandits := _side([[enemies[&"bandit_thug"], 3], [enemies[&"bandit_archer"], 1]])
	var result := RaidSystem.resolve(state, RaidData.load_bandits(), bandits, 5)
	check(result.won, "16 soldiers beat 4 bandits")
	check_eq(result.reward, {&"food": 4, &"wood": 4}, "1 food + 1 wood per bandit")
	check_eq(state.stockpile.get_amount(&"food"), 4, "Reward added")
	var record: BattleRecord = result.record
	for group in record.sides[BattleRecord.DEFENDER].groups:
		check_eq(state.army.get_count(group.unit.unit_id), group.alive(), "%s count matches survivors" % group.unit.unit_id)
	check(result.fled.is_empty() and result.resources_lost.is_empty(), "Winners lose nothing else")


func test_end_turn_can_trigger_a_raid() -> void:
	var state := _state()
	state.turn = 10
	state.raid = RaidData.load_bandits().duplicate()
	state.raid.base_chance = 1.0
	var report := state.end_turn()
	check(report.has("raid"), "Raid happens when the chance is 100%")
	check(not report.raid.won, "No army: the raid wins")
	state.raid.base_chance = 0.0
	check(not state.end_turn().has("raid"), "No raid at 0%")
