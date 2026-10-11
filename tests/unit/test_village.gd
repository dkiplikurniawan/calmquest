extends "res://tests/test_case.gd"
## Tests for M9: villagers, friendship, deliveries, the request board, quest
## unlocks, the Act 2 / Act 3 chain, post-game content and cosmetics.

const WORLD_SIZE := Vector2(10240, 6144)


func _fresh() -> void:
	GameState.reset_world(WORLD_SIZE)
	QuestManager.book.reset_progress()
	TimeManager.day = 1


func test_villager_data_is_valid() -> void:
	var ids := VillageDB.ids()
	assert_true(ids.size() >= 4 and ids.size() <= 6, "4-6 villagers (%d)" % ids.size())
	var w := WorldData.load_from()
	var book := QuestBook.new()
	book.load_directory("res://game/data/quests")
	for id in ids:
		var v := VillageDB.villager(id)
		for k in ["name", "title", "personality", "arrives", "home", "spots", "loves", "likes", "lines", "reward"]:
			assert_true(v.has(k), "%s has %s" % [id, k])
		for item: String in (v["loves"] as Array) + (v["likes"] as Array):
			assert_true(ItemDB.exists(item), "%s's gift preference exists (%s)" % [id, item])
		var site := String(v["home"]["site"])
		assert_false(RestorationSite.site_data(site).is_empty(), "%s has a home to build" % id)
		assert_false(w.poi(site).is_empty(), "%s's home is placed in the world" % id)
		for key: String in v["spots"]:
			var s: Array = v["spots"][key]
			assert_false(w.is_blocked_at(Vector2(float(s[0]), float(s[1]))), "%s's %s spot is walkable" % [id, key])
		var cosmetic := String(v["reward"].get("cosmetic", "")).split(":")
		assert_true((Cosmetics.CLOAKS if cosmetic[0] == "cloak" else Cosmetics.GLOWS).has(cosmetic[1]), "%s's present exists" % id)
		var quest := book.get_quest("villager_" + id)
		assert_eq(String(quest.get("type", "")), "villager", "%s has a personal quest" % id)
		var steps: Array = quest.get("steps", [])
		assert_true(steps.size() >= 2 and steps.size() <= 4, "%s's quest has 2-4 steps" % id)
		for lines_key in ["greet", "morning", "evening", "night", "loved", "liked", "neutral", "lore", "invite"]:
			assert_true((v["lines"] as Dictionary).has(lines_key), "%s has a %s line" % [id, lines_key])


func test_friendship_is_gentle_and_never_decays() -> void:
	_fresh()
	VillageDB.talk("bramble")
	VillageDB.talk("bramble")
	assert_eq(VillageDB.points("bramble"), VillageDB.TALK_POINTS, "talking counts once a day")
	GameState.give_item("wildflower", 3)
	var r := VillageDB.gift("bramble", "wildflower")
	assert_true(bool(r["ok"]) and r["kind"] == "loved", "a loved gift")
	assert_false(bool(VillageDB.gift("bramble", "wildflower")["ok"]), "one gift a day")
	assert_eq(GameState.inventory.count("wildflower"), 2, "a refused gift costs nothing")
	assert_false(VillageDB.giftable("lantern"), "keepsakes can't be given away")
	TimeManager.day = 99
	assert_eq(VillageDB.points("bramble"), VillageDB.TALK_POINTS + 5, "friendship never decays")
	var reward := VillageDB.add_points("bramble", 100)
	assert_eq(VillageDB.petals("bramble"), VillageDB.MAX_PETALS, "capped at five petals")
	assert_false(reward.is_empty(), "best friends: a one-time present")
	assert_true(Cosmetics.is_unlocked("cloak:moss"), "Bramble's present is the moss cloak")
	assert_true(VillageDB.add_points("bramble", 10).is_empty(), "the present comes once")


func test_villager_quests_unlock_on_arrival_and_take_deliveries() -> void:
	_fresh()
	QuestManager.refresh()
	assert_false(QuestManager.book.is_active("villager_bramble"), "locked until Bramble arrives")
	GameState.set_flag("villager_arrived:bramble")
	QuestManager.refresh()
	assert_true(QuestManager.book.is_active("villager_bramble"), "unlocked when Bramble moves in")
	GameState.set_flag("home_built:bramble")
	QuestManager.refresh()
	var deliveries := VillageDB.deliveries_for("bramble")
	assert_eq(deliveries.size(), 1, "the quest now asks to bring wildflowers")
	assert_false(VillageDB.deliver("bramble", "wildflower", 5), "not enough wildflowers yet")
	GameState.give_item("wildflower", 5)
	assert_true(VillageDB.deliver("bramble", "wildflower", 5), "handing them over")
	QuestManager.refresh()
	assert_eq(int(QuestManager.book.step["villager_bramble"]), 2, "the step is done")
	GameState.add_counter("harvested:carrot")
	QuestManager.refresh()
	assert_true(QuestManager.book.is_completed("villager_bramble"), "Bramble's quest completes")


func test_request_board_never_expires() -> void:
	_fresh()
	assert_eq(VillageDB.open_requests().size(), 0, "no villagers, no requests")
	for id in VillageDB.ids():
		GameState.set_flag("villager_arrived:" + id)
	var open := VillageDB.open_requests()
	assert_eq(open.size(), VillageDB.BOARD_SLOTS, "three requests at a time")
	var first: Dictionary = open[0]
	assert_true(VillageDB.complete_request(first).is_empty(), "not ready yet: nothing happens")
	TimeManager.day = 400
	assert_eq(String(VillageDB.open_requests()[0]["id"]), String(first["id"]), "still there 400 days later")
	var d: Dictionary = first["deliver"]
	GameState.give_item(String(d["item"]), int(d["qty"]))
	assert_false(VillageDB.complete_request(first).is_empty(), "completed with a reward")
	assert_true(VillageDB.request_done(String(first["id"])))
	assert_false(String(VillageDB.open_requests()[0]["id"]) == String(first["id"]), "the next request moves up")
	for r: Dictionary in VillageDB.all_requests():
		if r.has("deliver"):
			assert_true(ItemDB.exists(String(r["deliver"]["item"])), "%s asks for a real item" % r["id"])
		for it: Dictionary in (r.get("reward", {}) as Dictionary).get("items", []):
			assert_true(ItemDB.exists(String(it["item"])), "%s rewards a real item" % r["id"])


func test_story_chain_acts_two_and_three_is_completable() -> void:
	_fresh()
	for f in ["heart_tree_restored", "creek_awakened", "heart_of_lumeria_restored", "act1_complete"]:
		GameState.set_flag(f)
	GameState.add_counter("lights_collected", 8)
	GameState.add_counter("lantern_nights", 1)
	GameState.set_waystone_state("ws_grove", GameState.WAYSTONE_RESTORED)
	GameState.mark_region_visited("firefly_grove")
	GameState.mark_region_visited("crystal_creek")
	GameState.mark_region_visited("moonlit_sanctuary")
	QuestManager.refresh()
	assert_true(QuestManager.is_act_complete(1), "Act 1 done")
	assert_true(QuestManager.book.is_active("act2_hearthstones"), "Act 2 begins")
	GameState.set_flag("act2_heard")
	GameState.add_counter("hearthstones", 5)
	QuestManager.refresh()
	assert_true(QuestManager.book.is_completed("act2_hearthstones"), "five Hearthstones complete Act 2")
	assert_true(QuestManager.book.is_active("act3_return"), "Act 3 begins")
	GameState.set_flag("hearthstones_placed")
	for id in VillageDB.ids():
		VillageDB.invite(id)
	assert_false(VillageDB.invite("bramble"), "each friend is invited once")
	GameState.set_flag("act3_complete")
	QuestManager.refresh()
	assert_true(QuestManager.book.is_completed("act3_return"), "Act 3 completes")
	assert_true(QuestManager.book.is_active("postgame_wider_journal"), "post-game goals open up")
	assert_true(CreatureDB.matches("aurora_stag", "whispering_meadow", true, "clear"), "the Aurora Stag appears after the finale")


func test_post_game_targets_are_reachable_numbers() -> void:
	var book := QuestBook.new()
	book.load_directory("res://game/data/quests")
	var q := book.get_quest("postgame_wider_journal")
	for step: Dictionary in q["steps"]:
		var c: Dictionary = step["condition"]
		if c.get("counter", "") == "creatures_sketched":
			assert_true(int(c["at_least"]) <= CreatureDB.all_ids().size(), "every creature can be sketched")
		if c.get("counter", "") == "fish_species":
			assert_true(int(c["at_least"]) <= Fishing.all_fish().size(), "every fish can be caught")
		if c.get("counter", "") == "villager_best_friends":
			assert_true(int(c["at_least"]) <= VillageDB.ids().size(), "every villager can be befriended")


func test_cosmetics_are_earned_then_chosen() -> void:
	_fresh()
	assert_eq(Cosmetics.current("cloak"), "sage", "the default cloak")
	assert_false(Cosmetics.select("glow:ember"), "locked cosmetics can't be chosen")
	Cosmetics.unlock("glow:ember")
	assert_true(Cosmetics.select("glow:ember"))
	assert_eq(Cosmetics.glow_color(), Cosmetics.GLOWS["ember"]["color"], "Lumi glows with the chosen color")
	var saved := GameState.to_state()
	GameState.reset_world(WORLD_SIZE)
	GameState.load_state(saved, WORLD_SIZE)
	assert_eq(Cosmetics.current("glow"), "ember", "the choice is saved")
