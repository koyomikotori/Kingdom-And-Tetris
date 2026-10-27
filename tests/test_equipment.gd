extends "res://tests/test_suite.gd"
## M12e: items, storage, equipping, the forge, loot and what items do (GDD §8 "Trang bị").

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	state.stockpile.add({&"food": 900, &"wood": 900, &"stone": 900, &"ore": 300, &"hardwood": 300, &"horses": 100})
	return state


func test_random_items_follow_their_rarity() -> void:
	var equipment := Equipment.new()
	equipment.rng.seed = 5
	for rarity in Item.Rarity.LEGENDARY:
		for slot in Item.SLOTS:
			var item := equipment.create(&"general", slot, rarity)
			check_eq(item.main_bonus(), Item.RARITY_MAIN[rarity], "Main bonus by rarity")
			check_eq(item.effects.size(), Item.RARITY_EFFECTS[rarity], "Effects by rarity")
			check(not item.display_name.is_empty(), "Named")
			if slot == &"weapon":
				check(Item.WEAPON_TYPES.has(item.weapon_type), "A general's weapon has a type")
	var fan := equipment.create(&"advisor", &"weapon", 2)
	check_eq(fan.main_stat(), &"strategy", "Advisors' weapons raise Mưu lược")
	check_eq(fan.weapon_type, &"", "No weapon type for advisors")


func test_legendaries_are_found_once() -> void:
	var equipment := Equipment.new()
	var count := equipment.legendaries.size()
	check(count >= 10, "Named legendaries (%d)" % count)
	var first := equipment.create_legendary(&"thanh_long_dao")
	check(first != null and first.rarity == Item.Rarity.LEGENDARY and first.weapon_type == &"dao", "Thanh long đao")
	check(equipment.create_legendary(&"thanh_long_dao") == null, "Only one per game")
	for i in count + 3:
		var item := equipment.create_random(Item.Rarity.LEGENDARY)
		check(item != null, "Always an item")
	check_eq(equipment.found_legendaries.size(), count, "Every legendary found once")
	check_eq(equipment.create_random(Item.Rarity.LEGENDARY).rarity, Item.Rarity.EPIC, "Then epic items instead")


func test_equipping_raises_stats_and_swaps() -> void:
	var state := _state()
	var general := state.generals.generate(3)
	state.generals.add(general)
	var sword := state.equipment.create(&"general", &"weapon", 2)
	var better := state.equipment.create(&"general", &"weapon", 3)
	state.equipment.receive(sword, state.stockpile)
	state.equipment.receive(better, state.stockpile)
	var fan := state.equipment.create(&"advisor", &"weapon", 0)
	state.equipment.receive(fan, state.stockpile)
	check_eq(state.equipment.equip(general, fan), Equipment.Result.WRONG_KIND, "A fan is for advisors")
	check_eq(state.equipment.equip(general, sword), Equipment.Result.OK, "Equipped")
	check_eq(general.total_might(), general.might + 3, "+3 Võ lực")
	state.equipment.equip(general, better)
	check_eq(general.total_might(), general.might + 4, "The better weapon")
	check(state.equipment.items.has(sword) and not state.equipment.items.has(better), "The old one back in storage")
	check_eq(state.equipment.unequip(general, &"weapon"), Equipment.Result.OK, "Taken off")
	check_eq(general.total_might(), general.might, "Back to the general's own Võ lực")


func test_storage_holds_twenty_and_dismissal_returns_items() -> void:
	var state := _state()
	for i in Equipment.MAX_STORAGE:
		state.equipment.receive(state.equipment.create(&"general", &"armor", 0), state.stockpile)
	var ore := state.stockpile.get_amount(&"ore")
	var extra := state.equipment.receive(state.equipment.create(&"general", &"armor", 1), state.stockpile)
	check(not extra.refund.is_empty(), "A full storage dismantles new items")
	check(state.stockpile.get_amount(&"ore") > ore, "…into materials")
	check_eq(state.equipment.items.size(), Equipment.MAX_STORAGE, "Still 20")
	var refund := state.equipment.dismantle(state.equipment.items[0], state.stockpile)
	check(not refund.is_empty() and state.equipment.items.size() == Equipment.MAX_STORAGE - 1, "Dismantled")
	var advisor := state.advisors.generate(2)
	state.advisors.add(advisor)
	state.equipment.equip(advisor, _stored(state, state.equipment.create(&"advisor", &"armor", 1)))
	state.dismiss_officer(advisor)
	check_eq(state.equipment.items.size(), Equipment.MAX_STORAGE, "The robe came back")
	check(not state.advisors.advisors.has(advisor), "Dismissed")


func test_a_fallen_commander_loses_their_items() -> void:
	var state := _state()
	var general := state.generals.generate(3)
	state.generals.add(general)
	state.equipment.equip(general, _stored(state, state.equipment.create(&"general", &"weapon", 1)))
	var stored := state.equipment.items.size()
	state.generals.dismiss(general)  # what after_battle does when the commander dies
	check_eq(state.equipment.items.size(), stored, "Nothing comes back")


func test_armor_and_survival_lower_the_death_chance() -> void:
	var general := General.new()
	check_eq(Generals.death_chance(general), Generals.DEATH_CHANCE, "Base chance")
	var equipment := Equipment.new()
	general.items[&"armor"] = equipment.create_legendary(&"thiet_lan_giap")
	check(Generals.death_chance(general) < Generals.DEATH_CHANCE - 0.2, "Legendary armor protects a lot")
	check(Generals.death_chance(general) >= Generals.MIN_DEATH_CHANCE, "Never below the minimum")


func test_items_strengthen_the_bodyguard_by_weapon_type() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	var general := state.generals.generate(3)
	state.generals.add(general)
	var plain := state.create_kingdom_side(&"")
	var mace := _stored(state, state.equipment.create(&"general", &"weapon", 3))
	mace.weapon_type = &"chuy"
	state.equipment.equip(general, mace)
	var side := state.create_kingdom_side(&"")
	var guard := _guard(side)
	check(guard.defense_pierce > 0.0, "A mace pierces defense")
	check(guard.attack_mult > _guard(plain).attack_mult, "More Võ lực, stronger guard")
	check_eq(side.general_weapon, &"chuy", "The sprite shows the mace")
	var glaive := _stored(state, state.equipment.create(&"general", &"weapon", 3))
	glaive.weapon_type = &"thuong"
	state.equipment.equip(general, glaive)
	check(_guard(state.create_kingdom_side(&"")).charge_mult > _guard(side).charge_mult, "A spear charges harder")


func test_advisor_items_work_in_their_post() -> void:
	var state := _state()
	var advisor := state.advisors.generate(3)
	state.advisors.add(advisor)
	state.advisors.assign(advisor, &"admin")
	var cost := state.building_cost(state.buildings[&"farm"])
	var robe := state.equipment.create_legendary(&"bat_quai_dao_bao")
	state.equipment.receive(robe, state.stockpile)
	state.equipment.equip(advisor, robe)
	check_eq(state.advisors.post_stat(&"admin"), advisor.admin + 6, "+6 Nội chính")
	check(state.advisors.post_effect(&"admin", &"build_discount") > 0.0, "Discount while in Nội chính")
	var after := state.building_cost(state.buildings[&"farm"])
	check(after[&"wood"] <= cost[&"wood"], "Buildings cost less")
	state.advisors.assign(advisor, &"military")
	check_eq(state.advisors.post_effect(&"admin", &"build_discount"), 0.0, "Not outside Nội chính")


func test_the_forge_makes_items_in_two_turns() -> void:
	KingdomState.instant_construction = true
	var state := _state()
	check_eq(state.start_forge(&"general", &"weapon"), Equipment.Result.NO_FORGE, "Needs a forge")
	for i in 2:
		state.upgrade_castle()
	for x in range(2, 6):
		state.board.set_land(Vector2i(x, 2), &"grass", false)
	check_eq(state.build(&"forge", Vector2i(2, 2)), BuildRules.Result.OK, "Forge built at castle level 3")
	check_eq(state.build(&"forge", Vector2i(3, 2)), BuildRules.Result.LIMIT_REACHED, "Only one forge")
	check_eq(state.check_building_upgrade(Vector2i(2, 2)), KingdomState.UpgradeResult.CASTLE_TOO_LOW,
			"Forge level stays 2 below the castle")
	check_eq(state.forge_level(), 1, "Level 1")
	check_eq(state.start_forge(&"advisor", &"accessory"), Equipment.Result.OK, "Forging")
	check_eq(state.start_forge(&"general", &"weapon"), Equipment.Result.BUSY, "One at a time")
	check_eq(state.check_building_upgrade(Vector2i(2, 2)), KingdomState.UpgradeResult.FORGING, "No upgrade while forging")
	var report := state.end_turn()
	check(report.forged == null, "Not yet")
	report = state.end_turn()
	var item: Item = report.forged
	check(item != null and item.kind == &"advisor" and item.slot == &"accessory", "An advisor's accessory")
	check(item.rarity <= Item.Rarity.EPIC, "The forge never makes legendaries")
	check(state.equipment.items.has(item), "In storage")
	KingdomState.instant_construction = true


func test_equipment_is_saved() -> void:
	var state := _state()
	var general := state.generals.generate(3)
	state.generals.add(general)
	state.equipment.equip(general, _stored(state, state.equipment.create_legendary(&"y_thien_kiem")))
	state.equipment.receive(state.equipment.create(&"advisor", &"weapon", 2), state.stockpile)
	state.equipment.forge_job = {"kind": &"general", "slot": &"armor", "turns": 1, "level": 2}
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	var worn: Item = loaded.generals.generals[0].items.get(&"weapon")
	check(worn != null and worn.legendary_id == &"y_thien_kiem", "Worn legendary kept")
	check_eq(loaded.equipment.items.size(), 1, "Storage kept")
	check(loaded.equipment.found_legendaries.has(&"y_thien_kiem"), "Found legendaries kept")
	check_eq(loaded.equipment.forge_job.turns, 1, "Forge job kept")
	data.erase("equipment")
	var old := _state()
	old.load_save(data)
	check(old.equipment.items.is_empty(), "Older saves: empty storage")


func test_item_events_and_effect_data() -> void:
	var effects := Equipment.effect_data()
	check(effects.size() >= 10, "Item effects loaded")
	for id in Equipment.new().legendaries:
		for effect in Equipment.new().legendaries[id].effects:
			check(effects.has(effect), "%s: effect %s exists" % [id, effect])
	var events := EventData.load_all()
	check(events.has(&"wandering_smith") and events.has(&"ancient_shrine"), "Item events")


func _stored(state: KingdomState, item: Item) -> Item:
	state.equipment.receive(item, state.stockpile)
	return item


func _guard(side: BattleSide) -> BattleSide.Unit:
	for unit in side.units:
		if unit.is_general_guard:
			return unit
	return null


func test_equipment_art_exists() -> void:
	for key in Item.NAMES:
		check(GameArt.item_icon(key) != null, "Icon for %s" % key)
	for id in Equipment.new().legendaries:
		check(GameArt.item_icon(id) != null, "Icon for %s" % id)
	for rarity in range(-1, Item.Rarity.LEGENDARY + 1):
		check(GameArt.item_frame(rarity) != null, "Frame for rarity %d" % rarity)
	for gender in OfficerLook.GENDERS:
		var look := OfficerLook.new()
		look.gender = gender
		for weapon_type in Item.WEAPON_TYPES:
			var id := GameArt.officer_sprite(BattleView.GENERAL_KIND, look, weapon_type)
			check(ResourceLoader.exists("res://assets/units/%s.png" % id), "Commander sprite %s" % id)


func test_swapping_moves_an_item_between_officers() -> void:
	var state := _state()
	var first := state.generals.generate(3)
	var second := state.generals.generate(2)
	state.generals.add(first)
	state.generals.add(second)
	var blade := _stored(state, state.equipment.create(&"general", &"weapon", 3))
	var spear := _stored(state, state.equipment.create(&"general", &"weapon", 1))
	state.equipment.equip(first, blade)
	state.equipment.equip(second, spear)
	check_eq(state.equipment.swap(first, second, &"weapon"), Equipment.Result.OK, "Swapped")
	check(second.items[&"weapon"] == blade and first.items[&"weapon"] == spear, "Each has the other's weapon")
	state.equipment.unequip(first, &"weapon")
	state.equipment.swap(second, first, &"weapon")
	check(first.items[&"weapon"] == blade and not second.items.has(&"weapon"), "Moved to an empty slot")
	var advisor := state.advisors.generate(2)
	state.advisors.add(advisor)
	check_eq(state.equipment.swap(first, advisor, &"weapon"), Equipment.Result.WRONG_KIND, "Not to an advisor")
