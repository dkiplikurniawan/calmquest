extends "res://tests/test_case.gd"
## Tests for M6: wildlife data and the Creature Journal, gloom and Gloomling
## state, the lighthouse restoration site, the shipwreck signal puzzle, the
## fox family, Hearthstones and the new quest data.

const WORLD_SIZE := Vector2(10240, 6144)
const SHAPES := ["rabbit", "deer", "fox", "owl", "bird", "crab", "frog", "moth", "otter", "hedgehog", "squirrel", "turtle", "snail"]


func _fresh() -> void:
	GameState.reset_world(WORLD_SIZE)
	TimeManager.day = 1


func test_creature_data_is_valid() -> void:
	CreatureDB.ensure_loaded()
	assert_eq(CreatureDB.load_errors.size(), 0, "creature errors: %s" % ", ".join(CreatureDB.load_errors))
	var w := WorldData.load_from()
	var ids := CreatureDB.all_ids()
	assert_true(ids.size() >= 12, "at least 12 creatures (%d)" % ids.size())
	for id in ids:
		var c := CreatureDB.get_creature(id)
		assert_true(SHAPES.has(String(c.get("shape", ""))), "%s has a drawable shape" % id)
		for r: String in c.get("regions", []):
			assert_true(w.regions.has(r), "%s lives in a real region (%s)" % [id, r])
		for item: String in c.get("likes", []):
			assert_true(ItemDB.exists(item), "%s likes an existing item (%s)" % [id, item])
		var gift: Dictionary = c.get("gift", {})
		assert_true(ItemDB.exists(String(gift.get("item", ""))), "%s gives an existing gift" % id)
		assert_true(String(c.get("time", "any")) in ["day", "night", "any"], "%s has a valid time" % id)


func test_every_open_region_has_wildlife_day_and_night() -> void:
	for region in ["whispering_meadow", "firefly_grove", "crystal_creek", "misty_pinewood", "sunpetal_coast"]:
		assert_true(CreatureDB.candidates(region, true, "clear").size() > 0, "%s has daytime creatures" % region)
		assert_true(CreatureDB.candidates(region, false, "clear").size() > 0, "%s has night creatures" % region)


func test_creatures_follow_time_and_weather() -> void:
	assert_true(CreatureDB.matches("lantern_moth", "whispering_meadow", false, "clear"), "moths fly at night")
	assert_false(CreatureDB.matches("lantern_moth", "whispering_meadow", true, "clear"), "moths rest by day")
	assert_false(CreatureDB.matches("rain_snail", "whispering_meadow", true, "clear"), "rain snails need rain")
	assert_true(CreatureDB.matches("rain_snail", "whispering_meadow", true, "rain"), "rain snails appear in the rain")
	assert_false(CreatureDB.matches("mist_deer", "whispering_meadow", true, "clear"), "deer stay in the pinewood")


func test_sketching_counts_each_creature_once() -> void:
	_fresh()
	assert_true(CreatureDB.sketch("mist_deer"), "first sketch")
	assert_false(CreatureDB.sketch("mist_deer"), "second sketch of the same kind adds nothing")
	assert_true(CreatureDB.is_seen("mist_deer"), "sketched creatures are seen")
	assert_eq(GameState.counter("creatures_sketched"), 1)
	assert_eq(CreatureDB.sketched_count(), 1)


func test_friendship_grows_once_a_day_never_decays_and_gifts_once() -> void:
	_fresh()
	var r := CreatureDB.offer("meadow_bunny")
	assert_false(bool(r["ok"]), "nothing to offer without a liked item")
	assert_true(String(r["reason"]).contains("Wild Berry"), "the reason names what it likes")
	GameState.give_item("berry", 10)
	assert_true(bool(CreatureDB.offer("meadow_bunny")["ok"]), "a berry is accepted")
	assert_eq(GameState.inventory.count("berry"), 9, "one berry used")
	assert_false(bool(CreatureDB.offer("meadow_bunny")["ok"]), "only one treat per day")
	assert_eq(GameState.inventory.count("berry"), 9, "a refused offer uses nothing")
	TimeManager.day = 2
	CreatureDB.offer("meadow_bunny")
	TimeManager.day = 3
	var last := CreatureDB.offer("meadow_bunny")
	assert_eq(int(last["friendship"]), CreatureDB.MAX_FRIENDSHIP, "three days of treats: best friends")
	assert_false((last["gift"] as Dictionary).is_empty(), "a thank-you gift at full friendship")
	assert_true(GameState.has_flag("creature_friend:meadow_bunny"))
	TimeManager.day = 30
	assert_eq(CreatureDB.friendship("meadow_bunny"), CreatureDB.MAX_FRIENDSHIP, "friendship never decays")
	assert_false(bool(CreatureDB.offer("meadow_bunny")["ok"]), "no more gifts after the first")
	assert_eq(GameState.counter("creature_friends"), 1)


func test_full_bag_never_loses_a_creature_gift() -> void:
	_fresh()
	var inv := GameState.inventory
	for i in inv.capacity():
		inv.slots[i] = {"id": "stone", "qty": 99}
	# Two berries: after one is offered the slot is still taken, so the bag stays full.
	inv.slots[inv.capacity() - 1] = {"id": "berry", "qty": 2}
	assert_eq(inv.room_for("wildflower"), 0, "the bag is full")
	var e := CreatureDB.entry("meadow_bunny")
	e["friendship"] = CreatureDB.MAX_FRIENDSHIP - 1
	var before := GameState.storage.count("wildflower")
	var r := CreatureDB.offer("meadow_bunny")
	assert_true(bool(r["ok"]), "offer accepted")
	assert_true(GameState.storage.count("wildflower") > before, "the gift waits in the cottage chest")


func test_gloom_and_gloomling_state_persist_in_saves() -> void:
	_fresh()
	GameState.system_state(GloomPatch.STATE_KEY)["gloom_pine_1"] = true
	GameState.system_state(Gloomling.STATE_KEY)["gloomling_coast"] = "song"
	var saved := GameState.to_state()
	GameState.reset_world(WORLD_SIZE)
	assert_false(GloomPatch.is_patch_cleared("gloom_pine_1"), "a new world has its gloom")
	GameState.load_state(saved, WORLD_SIZE)
	assert_true(GloomPatch.is_patch_cleared("gloom_pine_1"), "cleared gloom stays cleared after loading")
	assert_true(Gloomling.is_calmed("gloomling_coast"), "a comforted Gloomling stays a light spirit")


func test_gloomling_calm_gives_what_it_kept() -> void:
	_fresh()
	var g := Gloomling.new()
	g.setup({"id": "test_gloomling", "pos": Vector2.ZERO, "keeps": {"item": "resin", "qty": 3}, "blocks": true})
	assert_true(g.calm("food", true), "calming works with any kindness")
	assert_false(g.calm("light", true), "only once")
	assert_eq(GameState.inventory.count("resin"), 3, "it leaves what it kept safe")
	assert_eq(GameState.counter("gloomlings_calmed"), 1)
	g.free()


func test_lighthouse_site_steps_and_requirements() -> void:
	_fresh()
	var site := RestorationSite.new()
	site.setup("lighthouse", Vector2.ZERO)
	assert_eq(site.steps().size(), 4, "four restoration steps")
	assert_true(site.check_step("stairs").begins_with("First"), "stairs wait for the door")
	assert_true(site.restore_step("door").begins_with("Still needed"), "missing materials are explained")
	assert_false(RestorationSite.is_step_done("lighthouse", "door"), "nothing changes without materials")
	for s: Dictionary in site.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	for id in ["door", "stairs", "lens", "lamp"]:
		assert_eq(site.restore_step(id), "", "%s restored" % id)
	assert_true(RestorationSite.is_complete("lighthouse"))
	assert_true(GameState.has_flag("lighthouse_lit"), "the lamp is lit")
	for s: Dictionary in site.steps():
		for part: Dictionary in s["inputs"]:
			assert_true(ItemDB.category(String(part["item"])) in ["resource", "material"], "lighthouse uses renewable materials (%s)" % part["item"])
	site.free()


func test_signal_puzzle_matches_the_captains_log() -> void:
	_fresh()
	var note := LoreNote.note_data("note_captain")
	var text := String(note.get("text", "")).to_lower()
	for i in 4:
		var color := SignalPuzzle.COLOR_NAMES[SignalPuzzle.SOLUTION[i]].split(" ")[-1]
		assert_true(text.contains(color) or text.contains(SignalPuzzle.COLOR_NAMES[SignalPuzzle.SOLUTION[i]]), "the log mentions %s" % SignalPuzzle.COLOR_NAMES[SignalPuzzle.SOLUTION[i]])
		assert_true(text.contains(SignalPuzzle.DIRECTIONS[i]), "the log mentions %s" % SignalPuzzle.DIRECTIONS[i])


func test_signal_puzzle_solves_resets_and_saves() -> void:
	_fresh()
	var p := SignalPuzzle.new()
	var root := Node.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.add_child(p)
	p.cycle(0)
	p.reset_puzzle()
	assert_eq(str(p.state), str([0, 0, 0, 0]), "the lever resets every lantern")
	var h1 := p.next_hint(false)
	var h2 := p.next_hint(false)
	var h3 := p.next_hint(true)
	assert_true(h1 != h2 and h2 != h3, "the hint ladder gets clearer")
	assert_true(p.lanterns.any(func(l: SignalPuzzle.SignalLantern) -> bool: return l.hinted), "Gentle hints highlight lanterns")
	for i in 4:
		for k in SignalPuzzle.SOLUTION[i]:
			p.cycle(i)
	assert_true(p.is_solved, "the right colors open the hold")
	assert_true(bool(GameState.puzzle_state("wreck_signal").get("solved", false)), "solved state is saved")
	root.queue_free()


func test_fox_kit_states() -> void:
	_fresh()
	assert_eq(LostKit.kit_state("kit_1"), "lost")
	LostKit.set_kit_state("kit_1", "home")
	LostKit.set_kit_state("kit_2", "following")
	assert_eq(LostKit.kits_home(), 1)
	var saved := GameState.to_state()
	GameState.reset_world(WORLD_SIZE)
	GameState.load_state(saved, WORLD_SIZE)
	assert_eq(LostKit.kit_state("kit_2"), "following", "a following kit is still with you after loading")


func test_m6_points_of_interest_and_quests_are_consistent() -> void:
	var w := WorldData.load_from()
	for kind in ["gloom", "gloomling", "dock", "site", "wreck_puzzle", "lost_kit", "fox_den"]:
		assert_true(w.pois_of_kind(kind).size() > 0, "world has %s" % kind)
	for d in w.pois_of_kind("dock"):
		var dest := w.poi(String(d["dest"]))
		assert_eq(String(dest.get("dest", "")), String(d["id"]), "dock %s pairs both ways" % d["id"])
		assert_false(w.is_blocked_at(d["pos"]), "dock %s stands on land" % d["id"])
		var water: Vector2 = d["pos"] + Vector2(0, 150.0 * float(d.get("water", 1)))
		assert_true(w.is_blocked_at(water), "dock %s faces the water" % d["id"])
	for k in w.pois_of_kind("lost_kit"):
		assert_false(w.poi(String(k["hidden_in"])).is_empty(), "%s hides in a real gloom patch" % k["id"])
	var book := QuestBook.new()
	book.load_directory("res://game/data/quests")
	for q in book.quests:
		for step: Dictionary in q["steps"]:
			var target := String(step.get("target", ""))
			if not target.is_empty() and target != "heart_tree":
				assert_false(w.poi(target).is_empty(), "quest %s targets a real place (%s)" % [q["id"], target])
	for id in ["hearthstone_pinewood", "hearthstone_coast", "hearthstone_isles", "hearthstone_caverns", "hearthstone_highlands"]:
		assert_true(ItemDB.exists(id) and ItemDB.is_unique(id), "%s is a keepsake item" % id)
