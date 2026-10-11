extends "res://tests/test_case.gd"
## Tests for M7: weather, farming (crops never die), fishing (no fail state),
## the fish journal, the forgotten garden and the new cooking recipes.

const WORLD_SIZE := Vector2(10240, 6144)
const PLOT := "homestead:1,1"


func _fresh() -> void:
	GameState.reset_world(WORLD_SIZE)
	GameState.bound_session_id = "slot:test"
	TimeManager.day = 1


func _set_day(d: int) -> void:
	TimeManager.day = d


func test_weather_is_calm_at_first_and_deterministic() -> void:
	_fresh()
	assert_eq(Weather.roll(1, "slot:a"), "clear", "day 1 is always clear")
	assert_eq(Weather.roll(2, "slot:a"), "clear", "day 2 is always clear")
	assert_eq(Weather.roll(17, "slot:a"), Weather.roll(17, "slot:a"), "the same day rolls the same weather")
	var counts := {"clear": 0, "cloudy": 0, "rain": 0, "mist": 0}
	for d in range(3, 403):
		counts[Weather.roll(d, "slot:a")] += 1
	for k: String in counts:
		assert_true(int(counts[k]) > 0, "%s happens sometimes" % k)
	assert_true(int(counts["clear"]) > int(counts["rain"]), "clear days are the most common")


func test_rain_is_remembered_in_saves() -> void:
	_fresh()
	_set_day(5)
	Weather.force("rain")
	assert_true(Weather.is_raining() and Weather.rained_on(5))
	var saved := GameState.to_state()
	GameState.reset_world(WORLD_SIZE)
	GameState.load_state(saved, WORLD_SIZE)
	assert_true(Weather.rained_on(5), "rainy days survive a save round trip")


func test_planting_watering_and_growth() -> void:
	_fresh()
	GameState.give_item("seed_carrot", 2)
	assert_true(Farming.plant(PLOT, "seed_carrot"), "planting works")
	assert_eq(GameState.inventory.count("seed_carrot"), 1, "one seed used")
	assert_false(Farming.plant(PLOT, "seed_carrot"), "one crop per plot")
	assert_eq(Farming.stage(PLOT), 0, "a planted seed")
	assert_true(Farming.water(PLOT), "watering works")
	assert_false(Farming.water(PLOT), "once per day is enough")
	_set_day(2)
	assert_eq(Farming.growth_days(PLOT), 1, "a watered day counts as growth")
	assert_eq(Farming.stage(PLOT), 1, "it sprouts")
	_set_day(3)
	assert_eq(Farming.growth_days(PLOT), 1, "an unwatered day just waits")
	Farming.water(PLOT)
	_set_day(4)
	Farming.water(PLOT)
	_set_day(5)
	assert_true(Farming.is_ripe(PLOT), "three watered days: ripe")
	var r := Farming.harvest(PLOT, 7)
	assert_true(bool(r["ok"]), "harvest works")
	assert_true(GameState.inventory.count("carrot") >= 2, "carrots harvested")
	assert_false(Farming.has_crop(PLOT), "the plot is free again")
	assert_eq(GameState.counter("harvested"), 1)


func test_crops_never_die() -> void:
	_fresh()
	GameState.give_item("seed_wheat", 1)
	Farming.plant(PLOT, "seed_wheat")
	_set_day(60)
	assert_true(Farming.has_crop(PLOT), "two months without water: still there")
	assert_eq(Farming.stage(PLOT), 0, "it simply waited")
	Farming.water(PLOT)
	_set_day(61)
	Farming.water(PLOT)
	_set_day(62)
	assert_true(Farming.is_ripe(PLOT), "and grows as soon as it gets water")


func test_rain_waters_crops() -> void:
	_fresh()
	GameState.give_item("seed_wheat", 1)
	_set_day(5)
	Farming.plant(PLOT, "seed_wheat")
	Weather.force("rain")
	assert_true(Farming.is_watered_today(PLOT), "rain counts as watering")
	_set_day(6)
	Weather.force("rain")
	_set_day(7)
	Weather.force("clear")
	assert_true(Farming.is_ripe(PLOT), "two rainy days grew the wheat")


func test_regrowing_and_bonus_crops() -> void:
	_fresh()
	GameState.give_item("seed_strawberry", 1)
	Farming.plant(PLOT, "seed_strawberry")
	for d in range(1, 5):
		_set_day(d)
		Farming.water(PLOT)
	_set_day(5)
	assert_true(bool(Farming.harvest(PLOT, 3)["ok"]))
	assert_true(Farming.has_crop(PLOT), "strawberries regrow instead of needing new seeds")
	assert_eq(Farming.days_needed(PLOT), 2, "regrowing is quicker")
	Farming.harvest(PLOT, 3)
	var luma := "homestead:2,2"
	GameState.give_item("seed_luma", 1)
	Farming.plant(luma, "seed_luma")
	for d in range(5, 9):
		_set_day(d)
		Farming.water(luma)
	_set_day(9)
	var before := GameState.inventory.count("luma_light")
	assert_true(bool(Farming.harvest(luma, 3)["ok"]))
	assert_eq(GameState.inventory.count("luma_bloom"), 1, "a Luma Bloom")
	assert_eq(GameState.inventory.count("luma_light"), before + 1, "plus a little Luma Light (light is renewable)")


func test_full_bag_never_loses_a_harvest() -> void:
	_fresh()
	GameState.give_item("seed_wheat", 1)
	Farming.plant(PLOT, "seed_wheat")
	Farming.water(PLOT)
	_set_day(2)
	Farming.water(PLOT)
	_set_day(3)
	for inv: Inventory in [GameState.inventory, GameState.storage]:
		for i in inv.capacity():
			inv.slots[i] = {"id": "stone", "qty": 99}
	var r := Farming.harvest(PLOT, 1)
	assert_false(bool(r["ok"]), "no room anywhere: the harvest waits")
	assert_true(Farming.is_ripe(PLOT), "the crop is still there")


func test_planted_plot_cannot_be_stored_away() -> void:
	_fresh()
	var area := BuildArea.make("homestead", Vector2.ZERO, 64.0, 6, 4)
	GameState.give_item("garden_plot", 1)
	assert_false(DecorRules.place(area, "garden_plot", Vector2i(1, 1), 0).is_empty(), "plot placed")
	GameState.give_item("seed_carrot", 1)
	Farming.plant(Farming.plot_key("homestead", Vector2i(1, 1)), "seed_carrot")
	assert_true(DecorRules.store(area, Vector2i(1, 1)).is_empty(), "a growing crop keeps its plot in place")
	assert_true(DecorRules.last_refusal.contains("growing"), "and says why")


func test_fish_data_is_valid() -> void:
	var ids := Fishing.all_fish()
	assert_true(ids.size() >= 10, "at least 10 fish (%d)" % ids.size())
	for id in ids:
		var f := Fishing.fish_data(id)
		assert_false(f.is_empty(), "%s has fishing data" % id)
		for w: String in f.get("waters", []):
			assert_true(w in ["creek", "pond", "sea"], "%s water %s" % [id, w])
		var s: Array = f.get("size", [])
		assert_true(s.size() == 2 and int(s[0]) <= int(s[1]), "%s has a size range" % id)
	for water in ["creek", "pond", "sea"]:
		assert_true(Fishing.candidates(water, "crystal_creek", true, "clear").size() > 0, "%s has fish by day" % water)
		assert_true(Fishing.candidates(water, "crystal_creek", false, "clear").size() > 0, "%s has fish at night" % water)
	assert_false(Fishing.candidates("creek", "crystal_creek", true, "clear").has("old_whiskers"), "the legend never bites by chance")
	assert_true(Fishing.candidates("pond", "whispering_meadow", true, "rain").has("mist_koi"), "rain brings the mist koi")


func test_old_whiskers_waits_for_five_kinds() -> void:
	_fresh()
	var rng := RandomNumberGenerator.new()
	assert_false(Fishing.pick("creek", "crystal_creek", "old_whiskers", rng) == "old_whiskers", "not before five kinds")
	for id in ["pebble_minnow", "crystal_trout", "moss_carp", "tide_sardine", "moonfin"]:
		Fishing.record_catch(id, 10)
	assert_eq(Fishing.species_caught(), 5)
	assert_eq(Fishing.pick("creek", "crystal_creek", "old_whiskers", rng), "old_whiskers", "now it comes to the special spot")
	var r := Fishing.record_catch("old_whiskers", 130)
	assert_eq(String(r["stored"]), "released", "the legend is let go")
	assert_eq(GameState.inventory.count("old_whiskers"), 0)
	assert_eq(GameState.inventory.count("fish_trophy"), 1, "and leaves a plaque")
	assert_false(Fishing.legendary_ready(), "once is enough")


func test_fish_journal_records_catches() -> void:
	_fresh()
	var r := Fishing.record_catch("moss_carp", 30)
	assert_true(bool(r["first"]), "first catch")
	Fishing.record_catch("moss_carp", 41)
	Fishing.record_catch("moss_carp", 25)
	assert_eq(Fishing.caught("moss_carp"), 3)
	assert_eq(Fishing.biggest("moss_carp"), 41, "the biggest is remembered")
	assert_eq(GameState.inventory.count("moss_carp"), 3, "fish go in the bag")
	assert_eq(GameState.counter("fish_species"), 1)


func test_fishing_minigame_has_no_fail_state() -> void:
	_fresh()
	var spot := FishingSpot.new()
	spot.setup({"id": "test_spot", "pos": Vector2.ZERO, "water": "pond"})
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var panel := FishingPanel.new()
	root.add_child(panel)
	panel.setup(spot, "whispering_meadow", &"balanced")
	panel.skip_wait()
	assert_eq(panel.stage, FishingPanel.Stage.BITE, "a fish bites")
	var before := GameState.inventory.total_items()
	panel._process(5.0)
	assert_eq(panel.stage, FishingPanel.Stage.MISSED, "waiting too long: it swims away")
	panel._process(2.0)
	assert_eq(panel.stage, FishingPanel.Stage.WAIT, "and the next one will come")
	assert_eq(GameState.inventory.total_items(), before, "a missed fish costs nothing")
	panel.skip_wait()
	panel.press()
	assert_eq(panel.stage, FishingPanel.Stage.REEL, "pressing during the bite hooks it")
	var steps := 0
	while panel.stage == FishingPanel.Stage.REEL and steps < 2000:
		var center := panel.zone + panel.zone_width() / 2.0
		panel._reel_step(0.05, panel.fish_pos > center)
		steps += 1
	assert_eq(panel.stage, FishingPanel.Stage.CAUGHT, "following the fish lands it")
	assert_true(Fishing.species_caught() == 1, "recorded in the journal")
	panel.press()
	assert_eq(panel.stage, FishingPanel.Stage.WAIT, "E casts again")
	var gentle := FishingPanel.new()
	root.add_child(gentle)
	gentle.setup(spot, "whispering_meadow", &"gentle")
	gentle.skip_wait()
	gentle._process(1.0)
	assert_eq(gentle.stage, FishingPanel.Stage.CAUGHT, "Gentle mode catches automatically")
	root.queue_free()
	spot.free()


func test_new_recipes_reference_real_items() -> void:
	var book := CraftingBook.new()
	book.load_directory()
	assert_eq(book.load_errors.size(), 0, "recipe errors: %s" % ", ".join(book.load_errors))
	for id in ["carrot_soup", "wheat_bread", "pumpkin_pie", "strawberry_jam", "fish_stew", "grilled_trout", "creek_skewer", "luma_tea", "garden_plot"]:
		var r := book.get_recipe(id)
		assert_false(r.is_empty(), "%s exists" % id)
		for part: Dictionary in r.get("inputs", []):
			assert_true(ItemDB.exists(String(part["item"])), "%s needs a real item (%s)" % [id, part["item"]])
	assert_true(book.recipes_for_discovery("note:note_gardener").has("garden_plot"), "the gardener's note teaches the garden plot")
	assert_eq(book.experiment_match(["carrot", "mushroom"]), "carrot_soup", "experimenting finds carrot soup")


func test_forgotten_garden_needs_water_then_opens_once() -> void:
	_fresh()
	var g := WitheredGarden.new()
	g.setup({"id": "test_garden", "pos": Vector2.ZERO, "hedges": [[-100, -100, 100, -100]], "gap": [0, 60], "chest": [0, 0], "rewards": [{"item": "seed_pumpkin", "qty": 2}]})
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(g)
	assert_true(g.open_chest().is_empty(), "the chest waits behind the plant")
	GameState.inventory.remove("watering_can", GameState.inventory.count("watering_can"))
	assert_false(g.revive(true), "no watering can, no revival")
	GameState.give_item("watering_can", 1)
	assert_true(g.revive(true), "watered: it blooms")
	assert_eq(g.open_chest().size(), 1, "the chest opens")
	assert_eq(GameState.inventory.count("seed_pumpkin"), 2)
	assert_true(g.open_chest().is_empty(), "only once")
	root.queue_free()
