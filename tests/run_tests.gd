extends SceneTree
## Headless test runner. From the project folder:
##   <godot> --headless --path . -s res://tests/run_tests.gd
## Exits with code 0 when every test passes, 1 otherwise.

const TEST_FILES := [
	"res://tests/test_board.gd",
	"res://tests/test_pieces.gd",
	"res://tests/test_economy.gd",
	"res://tests/test_army.gd",
	"res://tests/test_battle.gd",
	"res://tests/test_diplomacy.gd",
	"res://tests/test_war.gd",
	"res://tests/test_alliances.gd",
	"res://tests/test_save.gd",
	"res://tests/test_victory.gd",
	"res://tests/test_events.gd",
	"res://tests/test_production.gd",
	"res://tests/test_generals.gd",
	"res://tests/test_experience.gd",
	"res://tests/test_advisors.gd",
	"res://tests/test_art.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in TEST_FILES:
		var suite_script: GDScript = load(path)
		# A test file that fails to compile must fail the run, not silently contribute 0 tests.
		if suite_script == null or not suite_script.can_instantiate():
			total += 1
			failed += 1
			print("  FAIL  %s could not be loaded (see the script error above)" % path)
			continue
		for method in suite_script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var suite = suite_script.new()
			suite.call(test_name)
			total += 1
			if suite.failures.is_empty():
				print("  PASS  %s" % test_name)
			else:
				failed += 1
				print("  FAIL  %s" % test_name)
				for failure in suite.failures:
					print("        - %s" % failure)
	print("\n%d/%d tests passed" % [total - failed, total])
	GameArt.clear_cache()
	quit(1 if failed > 0 else 0)
