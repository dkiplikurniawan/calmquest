extends "res://tests/test_case.gd"
## Tests for the V2 save system (SaveManager) using a temporary save folder,
## so a player's real saves are never touched.

const TEST_DIR := "user://test_tmp/saves"


func _setup() -> Node:
	var sm: Node = SaveManager
	sm.call("set_save_dir", TEST_DIR)
	for slot in range(1, 4):
		sm.call("delete_slot", slot)
	return sm


func _teardown(sm: Node) -> void:
	for slot in range(1, 4):
		sm.call("delete_slot", slot)
	sm.call("set_save_dir", "user://saves")
	sm.set("current_slot", -1)
	GameState.reset_world(Vector2(10240, 6144))


func test_round_trip_of_all_state_categories() -> void:
	var sm := _setup()
	GameState.reset_world(Vector2(10240, 6144))
	GameState.set_flag("heart_tree_restored")
	GameState.add_counter("lights_collected", 8)
	GameState.give_item("branch", 7)
	GameState.learn_recipe("fishing_rod")
	GameState.mark_collected("light_01")
	GameState.bloomed_beds["bed_west"] = true
	GameState.read_lore("note_fisher")
	GameState.mark_region_visited("firefly_grove")
	GameState.set_waystone_state("ws_grove", GameState.WAYSTONE_RESTORED)
	TimeManager.load_state({"day": 7, "minute": 900.0})
	GameState.mark_removed(Vector2i(2, 2), "2_2_5", 3)
	GameState.set_puzzle_state("creek_puzzle", {"solved": true})
	GameState.reveal(Vector2(4000, 3000), 600.0)
	GameState.add_pin(Vector2(123, 456))
	GameState.system_state("cottage")["roof"] = true
	TimeManager.load_state({"day": 7, "minute": 900.0})
	sm.set("pending_player", {"pos": [4100.0, 2900.0], "facing": [1.0, 0.0], "region_name": "Whispering Meadow", "sublevel": ""})
	assert_true(sm.call("save_slot", 1, "test"), "save succeeded: %s" % sm.get("last_error"))
	assert_true(FileAccess.file_exists(TEST_DIR + "/slot_1.json"), "slot file written")

	GameState.reset_world(Vector2(10240, 6144))
	TimeManager.load_state({"day": 1, "minute": 480.0})
	var data: Dictionary = sm.call("load_slot", 1)
	assert_false(data.is_empty(), "slot loads")
	sm.call("apply_save_data", data, Vector2(10240, 6144))
	assert_true(GameState.has_flag("heart_tree_restored"), "flags restored")
	assert_eq(GameState.counter("lights_collected"), 8, "counters restored")
	assert_eq(GameState.inventory.count("branch"), 7, "inventory restored")
	assert_true(GameState.inventory.has("lantern"), "starting tool kept")
	assert_true(GameState.known_recipes.has("fishing_rod"), "recipes restored")
	assert_true(GameState.is_collected("light_01"), "collected objects restored")
	assert_true(GameState.bloomed_beds.has("bed_west"), "garden beds restored")
	assert_true(GameState.lore_read.has("note_fisher"), "lore restored")
	assert_true(GameState.has_visited("firefly_grove"), "visited regions restored")
	assert_eq(GameState.waystone_state("ws_grove"), GameState.WAYSTONE_RESTORED, "waystones restored")
	assert_true(GameState.is_removed(Vector2i(2, 2), "2_2_5"), "world deltas restored")
	assert_true(bool(GameState.puzzle_state("creek_puzzle").get("solved", false)), "puzzles restored")
	assert_true(GameState.is_revealed(Vector2(4000, 3000)), "fog of war restored")
	assert_eq(GameState.pins.size(), 1, "pins restored")
	assert_true(bool(GameState.system_state("cottage").get("roof", false)), "system state restored")
	assert_eq(TimeManager.day, 7, "clock restored")
	var p: Dictionary = sm.get("pending_player")
	assert_eq(float(p["pos"][0]), 4100.0, "player position restored")
	_teardown(sm)


func test_second_save_keeps_a_backup_and_corruption_falls_back() -> void:
	var sm := _setup()
	GameState.reset_world(Vector2(10240, 6144))
	GameState.set_flag("first")
	sm.call("save_slot", 2, "one")
	GameState.set_flag("second")
	sm.call("save_slot", 2, "two")
	assert_true(FileAccess.file_exists(TEST_DIR + "/slot_2.bak.json"), "previous save kept as backup")
	var f := FileAccess.open(TEST_DIR + "/slot_2.json", FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var data: Dictionary = sm.call("load_slot", 2)
	assert_false(data.is_empty(), "a corrupt main file falls back to the backup")
	assert_true(bool((data["world"]["flags"] as Dictionary).get("first", false)), "backup holds the earlier save")
	assert_false(FileAccess.file_exists(TEST_DIR + "/slot_2.json.tmp"), "no temp file left behind")
	_teardown(sm)


func test_unreadable_slot_reports_clearly() -> void:
	var sm := _setup()
	var f := FileAccess.open(TEST_DIR + "/slot_3.json", FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	assert_true(sm.call("slot_exists", 3))
	assert_true((sm.call("load_slot", 3) as Dictionary).is_empty(), "nothing usable")
	assert_false(String(sm.get("last_error")).is_empty(), "a clear message is available")
	assert_true(sm.call("delete_slot", 3), "an unreadable slot can be deleted")
	assert_false(sm.call("slot_exists", 3))
	_teardown(sm)


func test_migration_from_v1_and_future_versions() -> void:
	var v1 := {"save_version": 1, "flags": {"heart_tree_restored": true}, "inventory": [{"id": "stone", "qty": 3}], "day": 4, "minute": 600.0}
	var migrated: Dictionary = SaveManager.migrate(v1)
	assert_eq(int(migrated["save_version"]), 2, "upgraded to v2")
	assert_true(bool(migrated["world"]["flags"]["heart_tree_restored"]), "world state moved")
	assert_eq(int(migrated["time"]["day"]), 4, "time moved")
	assert_true((SaveManager.migrate({"save_version": 99}) as Dictionary).is_empty(), "future versions refused")
	assert_true((SaveManager.migrate({}) as Dictionary).is_empty(), "missing version refused")


func test_saves_are_separate_from_research_data() -> void:
	var sm := _setup()
	sm.call("save_slot", 1, "test")
	var text := FileAccess.get_file_as_string(TEST_DIR + "/slot_1.json")
	for research_field in ["pre_stress_score", "post_stress_score", "score_delta", "experience_rating", "consent"]:
		assert_false(text.contains(research_field), "save does not contain %s" % research_field)
	_teardown(sm)
