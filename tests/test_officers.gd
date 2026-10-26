extends "res://tests/test_suite.gd"
## M12c: officer looks, gendered names, portraits and the battle sprites they pick (GDD §13).

var terrains := TerrainLibrary.load_all()


func _state() -> KingdomState:
	var gen := PieceGenerator.new(PieceShapeLibrary.load_all(), terrains, 1)
	var state := KingdomState.new(BoardData.create_starting_board(12), PieceHand.new(gen), terrains,
			BuildingData.load_all(), UnitData.load_all(), 3)
	state.start()
	return state


func test_looks_are_gender_balanced_and_valid() -> void:
	var generals := Generals.new()
	generals.rng.seed = 2
	var women := 0
	for i in 200:
		var general := generals.generate(3)
		var look := general.look
		if look.is_female():
			women += 1
			check_eq(look.beard, 0, "Women have no beard")
		check(look.skin >= 0 and look.skin < OfficerLook.SKIN_TONES.size(), "Skin in range")
		check(look.hair_style >= 0 and look.hair_style < OfficerLook.HAIR_STYLES, "Hair style in range")
		check(look.eyes >= 0 and look.eyes < OfficerLook.EYE_STYLES, "Eyes in range")
		check(look.accent >= 0 and look.accent < OfficerLook.ACCENT_COLORS.size(), "Accent in range")
	check(women > 70 and women < 130, "About half are women (%d/200)" % women)


func test_names_follow_the_gender() -> void:
	var advisors := Advisors.new()
	advisors.rng.seed = 4
	for i in 60:
		var advisor := advisors.generate(2)
		var parts := advisor.name.split(" ")
		check_eq(parts.size(), 3, "Family, middle and given name")
		var middles := Officer.FEMALE_MIDDLE_NAMES if advisor.look.is_female() else Officer.MALE_MIDDLE_NAMES
		check(middles.has(parts[1]), "%s: middle name fits the gender" % advisor.name)
		if advisor.look.is_female():
			check(Officer.FEMALE_GIVEN_NAMES.has(parts[2]), "%s: a woman's given name" % advisor.name)


func test_looks_are_saved_and_old_saves_get_one_from_the_name() -> void:
	var state := _state()
	var general := state.generals.generate(4)
	state.generals.add(general)
	var advisor := state.advisors.generate(3)
	state.advisors.add(advisor)
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_save()))
	var loaded := _state()
	loaded.load_save(data)
	check_eq(loaded.generals.generals[0].look.to_save(), general.look.to_save(), "General's look kept")
	check_eq(loaded.advisors.advisors[0].look.to_save(), advisor.look.to_save(), "Advisor's look kept")
	data.generals.generals[0].erase("look")
	var old := _state()
	old.load_save(data)
	var made := old.generals.generals[0].look
	check_eq(made.to_save(), OfficerLook.from_seed(general.name).to_save(), "Made from the name")
	var again := _state()
	again.load_save(data)
	check_eq(again.generals.generals[0].look.to_save(), made.to_save(), "Always the same look")


func test_portrait_layers_follow_the_look() -> void:
	var general := General.new()
	general.name = "A"
	general.stars = 5
	general.look.gender = &"m"
	general.look.beard = 2
	var parts := PortraitView.layers(general, Color.BLUE).map(func(e: Array) -> String: return e[0])
	check(parts.has("beard_2"), "A bearded general")
	check(parts.has("helmet") and parts.has("helmet_accent"), "Generals wear the helmet")
	check(parts.has("body_general") and parts.back() == "frame_1", "Armor, gold frame from 4 stars")
	var advisor := Advisor.new()
	advisor.name = "B"
	advisor.stars = 2
	advisor.look.gender = &"f"
	parts = PortraitView.layers(advisor, Color.BLUE).map(func(e: Array) -> String: return e[0])
	check(not parts.any(func(p: String) -> bool: return p.begins_with("beard")), "No beard")
	check(parts.has("hairpin") and parts.has("body_advisor"), "A woman advisor: hairpin and robe")
	check_eq(parts.back(), "frame_0", "Wooden frame below 4 stars")
	advisor.look.gender = &"m"
	parts = PortraitView.layers(advisor, Color.BLUE).map(func(e: Array) -> String: return e[0])
	check(parts.has("scholar_hat"), "A man advisor: the official's cap")


func test_every_portrait_part_exists() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var missing: Array[String] = []
	for i in 300:
		var officer: Officer = General.new() if i % 2 == 0 else Advisor.new()
		officer.stars = 1 + i % 6
		officer.look = OfficerLook.random(rng)
		for entry: Array in PortraitView.layers(officer, Color.WHITE):
			if GameArt.portrait_part(entry[0]) == null and not missing.has(entry[0]):
				missing.append(entry[0])
	check(missing.is_empty(), "Missing portrait parts: %s" % ", ".join(missing))


func test_officers_lead_in_their_own_look() -> void:
	var state := _state()
	state.army.add_squad(&"swordsman", 20)
	var general := state.generals.generate(3)
	state.generals.add(general)
	var advisor := state.advisors.generate(3)
	state.advisors.add(advisor)
	state.advisors.assign(advisor, &"military")
	var side := state.create_kingdom_side(&"")
	check(side.general_look == general.look, "The commander's look rides into battle")
	check(side.advisor_look == advisor.look, "So does the strategist's")
	var id := GameArt.officer_sprite(BattleView.GENERAL_KIND, general.look)
	check(GameArt.unit_sheet(id) != null and GameArt.unit_sheet(id, "_hair") != null, "Sprite sheet with a hair layer")


func test_world_map_art_exists() -> void:
	for piece: StringName in [&"parchment", &"mountain", &"trees", &"fort", &"fort_team", &"icon_war",
			&"icon_alliance", &"icon_pact"]:
		check(GameArt.world(piece) != null, "World map piece %s" % piece)


func test_pool_portraits_are_picked_by_group_and_name() -> void:
	var general := General.new()
	general.look.gender = &"f"
	check_eq(GameArt.portrait_group(general), "general_f", "Group by kind and gender")
	var advisor := Advisor.new()
	check_eq(GameArt.portrait_group(advisor), "advisor_m", "Advisors have their own groups")
	var names := PackedStringArray(["general_f_01.png", "general_f_02.png", "general_f_03.png"])
	var picked := GameArt.pick_portrait(names, "Lê Thị Lan")
	check(names.has(picked), "Picked from the group")
	check_eq(GameArt.pick_portrait(names, "Lê Thị Lan"), picked, "Always the same for the same officer")
	check_eq(GameArt.pick_portrait(PackedStringArray(), "Lê Thị Lan"), "", "Empty pool: nothing")


func test_without_pool_portraits_the_parts_are_used() -> void:
	var general := Generals.new().generate(2)
	if GameArt.portrait_pool(GameArt.portrait_group(general)).is_empty():
		check_eq(general.look.portrait, "", "No pool portrait to give")
		check(GameArt.officer_pool_portrait(general) == null, "PortraitView falls back to the parts")
	var look := OfficerLook.new()
	look.portrait = "general_m_03.png"
	check_eq(OfficerLook.from_save(look.to_save()).portrait, "general_m_03.png", "The given portrait is saved")
