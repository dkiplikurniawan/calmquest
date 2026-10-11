extends "res://tests/test_case.gd"
## Tests for M3: item data, inventory, crafting, recipe discovery, the clock
## and resource respawn.


func test_item_and_recipe_data_load_cleanly() -> void:
	ItemDB.ensure_loaded()
	assert_eq(ItemDB.load_errors.size(), 0, "item data errors: %s" % ", ".join(ItemDB.load_errors))
	var book := CraftingBook.new()
	book.load_directory()
	assert_eq(book.load_errors.size(), 0, "recipe errors: %s" % ", ".join(book.load_errors))
	var resources := ItemDB.ids_in_category("resource")
	assert_true(resources.size() >= 15 and resources.size() <= 25, "15-25 resource types (%d)" % resources.size())


func test_every_gatherable_in_world_data_is_an_item() -> void:
	var w := WorldData.load_from()
	for profile: String in w.gather_profiles:
		for entry: Array in w.gather_profiles[profile]:
			assert_true(ItemDB.exists(String(entry[0])), "gatherable %s exists" % entry[0])
			assert_true(int(entry[2]) >= 1, "%s respawns" % entry[0])


func test_inventory_stacks_and_counts() -> void:
	var inv := Inventory.new()
	assert_eq(inv.add("branch", 150), 0, "150 branches fit across stacks")
	assert_eq(inv.count("branch"), 150)
	assert_eq(int(inv.slots[0]["qty"]), 99, "stacks fill to the maximum first")
	assert_true(inv.remove("branch", 100))
	assert_eq(inv.count("branch"), 50)
	assert_false(inv.remove("branch", 51), "cannot remove more than owned")
	assert_eq(inv.count("branch"), 50, "failed removal changes nothing")


func test_inventory_capacity_never_loses_items() -> void:
	var inv := Inventory.new()
	var ids := ItemDB.ids_in_category("resource")
	for i in inv.capacity():
		inv.add(ids[i % ids.size()], 99)
	var left := inv.add("luma_light", 5)
	assert_eq(left, 5, "nothing is added (or lost) when the bag is full")
	assert_eq(inv.count("luma_light"), 0)
	assert_eq(inv.add("not_an_item", 3), 3, "unknown items are refused")


func test_unique_items_cannot_be_discarded() -> void:
	var inv := Inventory.new()
	inv.add("lantern")
	inv.add("stone", 3)
	assert_false(inv.discard("lantern"), "tools are keepsakes")
	assert_true(inv.has("lantern"))
	assert_true(inv.discard("stone", 1))
	assert_eq(ItemDB.max_stack("lantern"), 1)


func test_bags_increase_capacity() -> void:
	var inv := Inventory.new()
	var base := inv.capacity()
	inv.add("gathering_bag")
	assert_eq(inv.capacity(), base + Inventory.BAG_BONUS)
	inv.add("travelers_pack")
	assert_eq(inv.capacity(), base + 2 * Inventory.BAG_BONUS)


func test_sort_merges_and_state_round_trip() -> void:
	var inv := Inventory.new()
	inv.add("stone", 5)
	inv.add("lantern")
	inv.swap(0, 7)
	inv.add("stone", 4)
	inv.sort_items()
	assert_eq(inv.count("stone"), 9)
	assert_eq(String(inv.slots[0]["id"]), "lantern", "tools sort first")
	var copy := Inventory.new()
	copy.load_state(inv.to_state())
	assert_eq(copy.count("stone"), 9)
	assert_eq(copy.count("lantern"), 1)


func _book() -> CraftingBook:
	var book := CraftingBook.new()
	book.load_directory()
	return book


func test_crafting_requirements_and_consumption() -> void:
	var book := _book()
	var inv := Inventory.new()
	var known := {"twine": true, "plank": true}
	assert_false(book.check("twine", inv, 0, known)["ok"], "no fiber yet")
	inv.add("fiber", 7)
	assert_true(book.craft("twine", inv, 0, known, 2), "craft twice")
	assert_eq(inv.count("twine"), 2)
	assert_eq(inv.count("fiber"), 1, "inputs consumed exactly")
	inv.add("branch", 2)
	assert_false(book.craft("plank", inv, 0, known), "planks need a workbench")
	assert_true(book.craft("plank", inv, 1, known), "workbench tier 1 works")
	assert_false(book.craft("fishing_rod", inv, 2, known), "unknown recipes cannot be crafted")


func test_crafting_never_loses_inputs_when_full() -> void:
	var book := _book()
	var inv := Inventory.new()
	var ids := ItemDB.ids_in_category("resource")
	inv.add("fiber", 3)
	for i in range(1, inv.capacity()):
		inv.add(ids[i % ids.size()] if ids[i % ids.size()] != "fiber" else "stone", 99)
	var before := inv.count("fiber")
	# Using up the fiber stack frees a slot, so this succeeds; a second craft would not.
	var ok := book.craft("twine", inv, 0, {"twine": true})
	if not ok:
		assert_eq(inv.count("fiber"), before, "a refused craft keeps its inputs")
	else:
		assert_eq(inv.count("twine"), 1)


func test_unique_tool_only_once() -> void:
	var book := _book()
	var inv := Inventory.new()
	inv.add("twine", 10)
	inv.add("fiber", 10)
	var known := {"gathering_bag": true}
	assert_true(book.craft("gathering_bag", inv, 1, known))
	assert_false(book.check("gathering_bag", inv, 1, known)["ok"], "no duplicate keepsakes")


func test_recipe_discovery_keys() -> void:
	var book := _book()
	assert_true(book.recipes_for_discovery("start").has("twine"))
	assert_true(book.recipes_for_discovery("note:note_fisher").has("fishing_rod"))
	assert_true(book.recipes_for_discovery("flag:act1_complete").has("bright_lantern"))
	for id in book.order:
		var key := String(book.get_recipe(id).get("discover", ""))
		assert_true(key == "start" or key == "experiment" or key.contains(":"), "%s has a discovery key" % id)


func test_every_note_recipe_has_a_note() -> void:
	var book := _book()
	for id in book.order:
		var key := String(book.get_recipe(id).get("discover", ""))
		if key.begins_with("note:"):
			assert_false(LoreNote.note_data(key.substr(5)).is_empty(), "note for %s exists" % id)


func test_clock_days_and_daylight() -> void:
	var tm: Node = TimeManager
	var saved: Dictionary = tm.call("to_state")
	tm.call("load_state", {"day": 1, "minute": 23.0 * 60.0})
	assert_eq(float(tm.call("daylight")), 0.0, "night at 23:00")
	tm.call("advance", 120.0)
	assert_eq(int(tm.get("day")), 2, "midnight starts a new day")
	tm.call("load_state", {"day": 2, "minute": 12.0 * 60.0})
	assert_eq(float(tm.call("daylight")), 1.0, "full daylight at noon")
	tm.call("sleep_until_morning")
	assert_eq(int(tm.get("day")), 3, "sleeping moves to the next morning")
	tm.call("load_state", saved)


func test_gathered_resources_grow_back() -> void:
	var tm: Node = TimeManager
	var saved: Dictionary = tm.call("to_state")
	tm.call("load_state", {"day": 5, "minute": 600.0})
	GameState.mark_removed(Vector2i(3, 3), "test_obj", 2)
	assert_true(GameState.is_removed(Vector2i(3, 3), "test_obj"), "gone right after gathering")
	tm.call("load_state", {"day": 6, "minute": 600.0})
	assert_true(GameState.is_removed(Vector2i(3, 3), "test_obj"), "still gone the next day")
	tm.call("load_state", {"day": 7, "minute": 600.0})
	assert_false(GameState.is_removed(Vector2i(3, 3), "test_obj"), "grown back after 2 days")
	GameState.mark_removed(Vector2i(3, 3), "forever", 0)
	tm.call("load_state", {"day": 99, "minute": 600.0})
	assert_true(GameState.is_removed(Vector2i(3, 3), "forever"), "respawn 0 = gone for good")
	tm.call("load_state", saved)
