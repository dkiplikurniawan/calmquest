extends "res://tests/test_case.gd"
## Tests for M10: the Frostbloom Highlands pass, the mountain path site (a
## tool step that never uses the tool up) and the aurora shrine puzzle.

const WORLD_SIZE := Vector2(10240, 6144)


func _fresh() -> void:
	GameState.reset_world(WORLD_SIZE)


func test_the_pass_is_the_only_way_up() -> void:
	var w := WorldData.load_from()
	var pass_pos: Vector2 = w.poi("mountain_path")["pos"]
	assert_false(w.is_blocked_at(pass_pos), "the pass cell is walkable ground")
	assert_eq(w.region_at(pass_pos), "frostbloom_highlands", "the pass belongs to the highlands")
	assert_false(w.is_blocked_at(pass_pos + Vector2(0, 200)), "the coast below the pass is walkable")
	assert_false(w.is_blocked_at(pass_pos + Vector2(0, -200)), "the highlands above the pass are walkable")
	assert_true(w.is_blocked_at(pass_pos + Vector2(-256, 0)) and w.is_blocked_at(pass_pos + Vector2(256, 0)), "cliffs on both sides of the pass")
	assert_eq(String(w.region_info("frostbloom_highlands").get("status", "")), "playable", "the highlands are playable now")


func test_mountain_path_needs_the_rope_and_keeps_it() -> void:
	_fresh()
	var site := RestorationSite.new()
	site.setup("mountain_path", Vector2.ZERO)
	GameState.give_item("twine", 2)
	assert_true(site.check_step("rope").contains("Climbing Rope"), "the first step asks for the rope")
	GameState.give_item("climbing_rope", 1)
	assert_eq(site.restore_step("rope"), "", "with the rope it works")
	assert_eq(GameState.inventory.count("climbing_rope"), 1, "the rope is a tool and is kept")
	for s: Dictionary in site.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	assert_eq(site.restore_step("clear"), "")
	assert_eq(site.restore_step("steps"), "")
	assert_true(GameState.has_flag("highlands_path_open"), "the path is open")
	site.free()


func test_rope_recipe_and_materials_are_obtainable() -> void:
	var book := CraftingBook.new()
	book.load_directory()
	assert_true(book.recipes_for_discovery("note:note_mountaineer").has("climbing_rope"), "the climber's note teaches the rope")
	var w := WorldData.load_from()
	assert_false(w.poi("note_mountaineer").is_empty(), "the climber's note is in the world")
	assert_false(w.is_blocked_at(w.poi("note_mountaineer")["pos"]), "and can be reached from the coast")
	for part: Dictionary in book.get_recipe("climbing_rope")["inputs"]:
		var found := false
		for profile: String in w.gather_profiles:
			for entry: Array in w.gather_profiles[profile]:
				if String(entry[0]) == String(part["item"]):
					found = true
		var craftable := not book.get_recipe(String(part["item"])).is_empty()
		assert_true(found or craftable, "%s can be gathered or crafted" % part["item"])


func test_aurora_shrine_aligns_and_resets() -> void:
	_fresh()
	var shrine := AuroraShrine.new()
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(shrine)
	assert_false(shrine.is_solved, "starts asleep")
	shrine.turn(0)
	shrine.reset_puzzle()
	for i in 3:
		assert_eq(shrine.facings[i], int(AuroraShrine.PRISMS[i][2]), "the lever turns prism %d back" % i)
	var h1 := shrine.next_hint(false)
	var h2 := shrine.next_hint(false)
	var h3 := shrine.next_hint(true)
	assert_true(h1 != h2 and h2 != h3, "the hint ladder gets clearer")
	for i in 3:
		while not shrine.correct(i):
			shrine.turn(i)
	assert_true(shrine.is_solved, "all beams meet: the aurora wakes")
	assert_true(bool(GameState.puzzle_state("aurora_shrine").get("solved", false)), "and it is saved")
	root.queue_free()
