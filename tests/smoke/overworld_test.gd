extends Node
## V2 integration test: the open world and Act 1, played programmatically.
##
## Run:  godot --headless --path . res://tests/smoke/overworld_test.tscn
## Covers chunk streaming and world deltas, camera clamping, world bounds,
## region tracking, waystone travel, map/fog of war, the Crystal Creek puzzle,
## the moonlit veil, the Act 1 quest chain end to end, and that free
## exploration continues after the finale. Uses test-only journal storage.

const OVERWORLD := preload("res://game/scenes/world/overworld.tscn")

var _checks: int = 0
var _failures: PackedStringArray = []
var world: Overworld


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures.append(label)
		printerr("  FAIL ", label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Assertions compare English text; the player's chosen language must not change them.
	L.set_language("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	SessionState.progress = ProgressStore.new("user://test_tmp/overworld_progress.cfg")
	SessionState.storage = SessionStorage.new("user://test_tmp/overworld_sessions.csv")
	await _run()
	get_tree().paused = false
	print("")
	print("Overworld test: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		printerr("FAILED: ", f)
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


## Enabled PointLight2D nodes near the screen (the ones the renderer actually
## draws; lights far off-screen are culled). The total is printed for reference.
func _enabled_lights() -> int:
	var near := 0
	var total := 0
	for n in get_tree().root.find_children("*", "PointLight2D", true, false):
		var light := n as PointLight2D
		if light.enabled and light.is_visible_in_tree():
			total += 1
			if ViewCull.near(light.global_position, Overworld.LIGHT_MARGIN):
				near += 1
	print("    (%d lights switched on in the whole world, %d of them near the screen)" % [total, near])
	return near


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	SessionState.begin_session(5, AdaptiveComfortEngine.MODE_GENTLE, false)
	world = OVERWORLD.instantiate()
	add_child(world)
	world.features.wildlife.enabled = false
	await _frames(5)
	var w := world.world
	var screens := w.world_size() / Vector2(1280, 720)
	check(screens.x >= 8.0 and screens.y >= 8.0, "world is at least 8x8 screens (%.1f x %.1f)" % [screens.x, screens.y])
	check(world.current_region == "whispering_meadow", "start in Whispering Meadow")
	check(GameState.has_visited("whispering_meadow"), "start region recorded as visited")
	check(not QuestManager.tracked_id.is_empty(), "a quest is tracked at the start")

	# --- Streaming: only chunks near the camera are loaded -----------------------------
	var total_chunks := w.chunk_count().x * w.chunk_count().y
	check(world.streamer.loaded.size() > 0 and world.streamer.loaded.size() < total_chunks, "only nearby chunks loaded (%d of %d)" % [world.streamer.loaded.size(), total_chunks])
	check(world.streamer.loaded.has(w.chunk_of(world.player.global_position)), "the player's chunk is loaded")
	check(not world.streamer.loaded.has(Vector2i(9, 5)), "a far chunk is not loaded")

	# --- World deltas survive unload and reload ----------------------------------------
	var chunk := w.chunk_of(world.player.global_position)
	var node: Node2D = world.streamer.loaded[chunk]
	var victim := node.get_child(0)
	var victim_id := String(victim.get_meta(WorldStreamer.OBJECT_ID_META))
	var before := node.get_child_count()
	world.streamer.remove_object(chunk, victim_id)
	world.teleport_to(Vector2(8300, 4300))
	world.streamer.update_view(world.camera.visible_world_rect())
	await _frames(2)
	check(not world.streamer.loaded.has(chunk), "original chunk unloaded after travelling far")
	world.teleport_to(w.player_spawn)
	await _frames(2)
	var reloaded: Node2D = world.streamer.loaded.get(chunk)
	var ids := []
	for c in reloaded.get_children():
		ids.append(String(c.get_meta(WorldStreamer.OBJECT_ID_META)))
	check(not ids.has(victim_id), "removed object stays removed after the chunk reloads")
	check(reloaded.get_child_count() == before - 1, "every other object came back (%d)" % reloaded.get_child_count())

	# --- Camera stays inside the world at the corners ------------------------------------
	for corner in [Vector2(260, 260), Vector2(w.world_size().x - 260, w.world_size().y - 260), Vector2(260, w.world_size().y - 260)]:
		world.teleport_to(corner)
		await _frames(3)
		var view := world.camera.screen_world_rect()
		check(w.world_rect().grow(2.0).encloses(view), "camera view inside the world near %s (view %s)" % [str(corner), str(view)])

	# --- The player cannot leave the world -------------------------------------------------
	for test: Array in [[Vector2(1000, 420), Vector2.UP], [Vector2(5000, 5150), Vector2.DOWN], [Vector2(8400, 4300), Vector2.RIGHT]]:
		world.teleport_to(test[0])
		for i in 180:
			world.player.velocity = (test[1] as Vector2) * Player.SPEED * Player.RUN_MULTIPLIER
			world.player.move_and_slide()
			await get_tree().physics_frame
		var pos := world.player.global_position
		check(w.world_rect().has_point(pos) and not w.is_blocked_at(pos), "running %s stays on walkable land (%s)" % [str(test[1]), str(pos.round())])

	world.teleport_to(w.player_spawn)

	# --- Act 1, step 1: the Lost Lights --------------------------------------------------
	for id: String in MeadowLayout.LIGHTS.keys().slice(0, 8):
		for mote in world.meadow.motes.duplicate():
			if mote.interactable_id == id:
				_use(mote)
	_use(world.meadow.heart_tree)
	QuestManager.refresh()
	check(QuestManager.book.is_completed("act1_lost_lights"), "Act 1 quest 1 complete")
	check(QuestManager.tracked_id == "act1_firefly_grove", "tracking moves to the next quest")
	await get_tree().create_timer(5.0).timeout
	if world._modal_open:
		world._close_completion()

	# --- Act 1, step 2: Firefly Grove, waystone, Lantern Night ----------------------------------
	var grove_ws: Waystone = world.story.waystones["ws_grove"]
	world.teleport_to(grove_ws.position + Vector2(0, 80))
	check(world.current_region == "firefly_grove", "region tracking: Firefly Grove")
	check(GameState.waystone_state("ws_grove") == GameState.WAYSTONE_DISCOVERED, "waystone discovered by walking near")
	_use(grove_ws)
	check(grove_ws.is_restored(), "waystone relit")
	world.teleport_to(world.meadow.shrine.position + Vector2(0, 90))
	_use(world.meadow.shrine)
	check(world.lantern_catch.active, "Lantern Night starts at the grove shrine")
	for l in world.lantern_catch.get_remaining():
		_use(l)
	check(not world.lantern_catch.active, "Lantern Night completed in Firefly Grove")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("act1_firefly_grove"), "Act 1 quest 2 complete")

	# --- Act 1, step 3: Crystal Creek puzzle ------------------------------------------------
	var creek_ws: Waystone = world.story.waystones["ws_creek"]
	world.teleport_to(creek_ws.position + Vector2(0, 80))
	_use(creek_ws)
	check(world.current_region == "crystal_creek", "region tracking: Crystal Creek")
	var puzzle := world.story.puzzle
	world.teleport_to(puzzle.global_position + Vector2(0, 260))
	world._request_hint()
	world._request_hint()
	world._request_hint()
	check(puzzle.highlight_cell != Vector2i(-99, -99), "Gentle mode: the last hint highlights a crystal")
	var lever_count := 0
	for cell: Vector2i in [Vector2i(1, 0)]:
		_use(puzzle.mirror_nodes[cell])
	_use(puzzle.lever)
	check(int(puzzle.logic.mirrors[Vector2i(1, 0)]) == BeamPuzzle.SLASH, "the lever resets the crystals")
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(1, 2), Vector2i(3, 2)]:
		_use(puzzle.mirror_nodes[cell])
		lever_count += 1
	check(puzzle.is_solved, "beam puzzle solved by turning three crystals")
	check(GameState.has_flag("creek_awakened"), "creek awakened flag set")
	check(GameState.puzzle_state("creek_puzzle").get("solved", false), "puzzle progress saved in world state")
	await get_tree().physics_frame
	check(world.story.moon_gate.is_open, "the moonlit veil opens")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("act1_crystal_creek"), "Act 1 quest 3 complete")

	# --- Waystone travel and map ---------------------------------------------------------------
	world.travel_to("ws_grove")
	await get_tree().create_timer(1.6).timeout
	check(world.player.global_position.distance_to(grove_ws.position) < 200.0, "travel to a relit waystone works")
	world.open_map()
	check(world._modal_open and get_tree().paused, "the map pauses the game")
	check(world._overlay is MapPanel, "map overlay open")
	(world._overlay as MapPanel).close_map()
	check(not get_tree().paused, "closing the map resumes")
	check(GameState.revealed_fraction() > 0.02, "fog of war revealed while exploring (%.0f%%)" % (GameState.revealed_fraction() * 100.0))

	# --- Act 1, step 4: the Heart of Lumeria ------------------------------------------------
	var altar := world.story.altar
	world.teleport_to(altar.position + Vector2(0, 160))
	check(world.current_region == "moonlit_sanctuary", "region tracking: Moonlit Sanctuary")
	_use(altar)
	await get_tree().create_timer(MoonAltar.RESTORE_SECONDS + 0.5).timeout
	QuestManager.refresh()
	check(GameState.has_flag("heart_of_lumeria_restored"), "the Heart of Lumeria is restored")
	check(QuestManager.is_act_complete(1), "Act 1 complete")
	await get_tree().create_timer(3.5).timeout
	if world._modal_open:
		world._close_completion()

	# --- Free exploration continues ----------------------------------------------------------
	var start := world.player.global_position
	for i in 30:
		world.player.velocity = Vector2.DOWN * Player.SPEED
		world.player.move_and_slide()
		await get_tree().physics_frame
	check(world.player.global_position.distance_to(start) > 50.0, "the player can keep exploring after the finale")
	# V2 M9 (deliberate design change): the V2 story continues after Act 1, so
	# the tracked quest is now Act 2's gentle, untimed goal. Nothing is forced:
	# the player kept walking freely above, and any quest can be followed instead.
	var tracked := QuestManager.book.get_quest(QuestManager.tracked_id)
	check(int(tracked.get("act", 0)) == 2, "after Act 1, Act 2 begins as a gentle goal")
	check(not (tracked.get("steps", []) as Array).is_empty() and not tracked.has("time_limit"), "Act 2 has no time limit")
	world._refresh_hud()
	check(true, "HUD refresh after the ending works")

	# --- M3: gathering, crafting, workbench, notes, clock --------------------------------
	world.teleport_to(w.player_spawn)
	await _frames(2)
	var gatherable: Gatherable = null
	for chunk_node: Node2D in world.streamer.loaded.values():
		for c in chunk_node.get_children():
			if c is Gatherable and c.item_id == "fiber":
				gatherable = c
				break
		if gatherable != null:
			break
	check(gatherable != null, "fiber can be found near the meadow")
	if gatherable != null:
		var g_chunk := gatherable.chunk
		var g_id := String(gatherable.get_meta(WorldStreamer.OBJECT_ID_META))
		var before_fiber := GameState.inventory.count("fiber")
		_use(gatherable)
		check(GameState.inventory.count("fiber") == before_fiber + 1, "gathering adds one fiber")
		check(GameState.is_removed(g_chunk, g_id), "the gathered fiber is recorded as a world delta")
		TimeManager.sleep_until_morning()
		TimeManager.sleep_until_morning()
		check(not GameState.is_removed(g_chunk, g_id), "fiber grows back after a couple of days")
	GameState.give_item("fiber", 3)
	GameState.give_item("branch", 2)
	check(GameState.craft("twine", 0), "twine can be crafted by hand")
	check(not GameState.craft("plank", 0), "planks need a workbench")
	var bench_pos: Vector2 = w.poi("workbench")["pos"]
	world.teleport_to(bench_pos + Vector2(0, 90))
	check(world.station_tier_here() == 1, "standing near the workbench gives tier 1")
	check(GameState.craft("plank", world.station_tier_here()), "plank crafted at the workbench")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("side_toolkit"), "toolkit side quest completed through play")
	check(not GameState.known_recipes.has("fishing_rod"), "fishing rod recipe not known yet")
	world.teleport_to(w.poi("note_fisher")["pos"] + Vector2(0, 80))
	world.open_lore("note_fisher")
	check(GameState.known_recipes.has("fishing_rod"), "reading the creek note teaches the fishing rod")
	if world._overlay != null:
		(world._overlay as LorePanel).close_panel()
	check(GameState.known_recipes.has("bright_lantern"), "finishing Act 1 taught the bright lantern")
	world.open_inventory(1)
	check(world._overlay is InventoryPanel, "inventory and crafting panel opens")
	(world._overlay as InventoryPanel).close_panel()
	TimeManager.load_state({"day": 4, "minute": 23.0 * 60.0})
	await _frames(2)
	check(world.effective_night > 0.9, "night falls with the clock (safe and visual only)")
	TimeManager.load_state({"day": 4, "minute": 12.0 * 60.0})
	await _frames(2)
	check(world.effective_night < 0.05, "full daylight at noon")

	# --- M4: the cottage, restoration, stations, decorating ------------------------------
	var home := world.homestead
	world.teleport_to(home.exterior.get_interaction_point() + Vector2(0, 40))
	_use(home.exterior)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "cottage", "entering the cottage moves into the interior sub-level")
	check(home.interior.camera_rect().has_point(world.player.global_position), "the player is inside the cottage")
	check(world.camera.limit_right <= int(home.interior.camera_rect().end.x), "camera bounds follow the interior")
	_check_interior_reachability(home)
	check(home.try_restore("hearth") != "", "the hearth waits for the roof")
	check(home.try_restore("roof") != "", "restoring without materials just explains what is missing")
	for step: Dictionary in home.data["steps"]:
		for part: Dictionary in step["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	check(home.try_restore("roof") == "", "roof restored with materials")
	check(GameState.has_flag("cottage_roof") and GameState.known_recipes.has("woven_rug"), "restoring teaches new decor recipes")
	for id in ["hearth", "window", "bed", "workbench", "cooking_pot", "storage_chest", "bookshelf"]:
		check(home.try_restore(id) == "", "%s restored" % id)
	check(GameState.has_flag("cottage_restored"), "the cottage is fully restored")
	await _frames(2)
	check(world.night_tint.color.r > 0.95, "the lit hearth makes the interior warm")
	var day_before_sleep := TimeManager.day
	home.sleep()
	await get_tree().create_timer(1.6).timeout
	check(TimeManager.day == day_before_sleep + 1 and TimeManager.minute_of_day < 8.0 * 60.0, "sleeping moves to the next morning")
	var bench: Node2D = null
	for n in get_tree().get_nodes_in_group(&"crafting_stations"):
		if (n as Workbench).tier == 2:
			bench = n
	world.player.global_position = bench.global_position + Vector2(0, 70)
	check(world.station_tier_here() == 2, "the restored cottage workbench gives tier 2")
	GameState.storage.add("plank", 5)
	GameState.inventory.remove("plank", GameState.inventory.count("plank"))
	GameState.give_item("stone", 2)
	check(GameState.craft("garden_bench", 2, 1, true), "crafting uses planks from the storage chest when nearby")
	GameState.give_item("shell", 3)
	var shell_slot := -1
	for i in GameState.inventory.slots.size():
		if not GameState.inventory.slots[i].is_empty() and GameState.inventory.slots[i]["id"] == "shell":
			shell_slot = i
	check(StoragePanel.move_stack(GameState.inventory, GameState.storage, shell_slot) == 3, "a stack moves into the chest")
	check(GameState.storage.count("shell") == 3 and GameState.inventory.count("shell") == 0, "the chest holds it now")
	GameState.give_item("berry", 3)
	check(GameState.craft("berry_compote", CraftingBook.COOKING_TIER), "cooking a known dish at the pot")
	GameState.give_item("berry", 3)
	check(not GameState.craft("berry_compote", 2), "the workbench cannot cook")
	GameState.give_item("mushroom", 2)
	GameState.give_item("wildflower", 1)
	check(GameState.try_experiment(["wildflower", "stone"]) == "", "a wrong mix teaches nothing")
	check(GameState.inventory.count("mushroom") >= 2, "experimenting never uses ingredients")
	check(GameState.try_experiment(["mushroom", "wildflower"]) == "mushroom_soup", "the right mix discovers Mushroom Soup")
	check(ItemConsumer.use("berry_compote", world), "eating food works")
	check(ItemConsumer.Buffs.has("cozy"), "food gives a gentle temporary buff")
	GameState.give_item("wooden_chair", 1)
	var area := home.interior.area
	var free_cell := Vector2i(3, 3)
	check(not DecorRules.place(area, "wooden_chair", free_cell, 0).is_empty(), "placing a chair in the cottage")
	check(GameState.inventory.count("wooden_chair") == 0, "placing takes it from the bag")
	GameState.give_item("round_table", 1)
	check(DecorRules.place(area, "round_table", free_cell, 0).is_empty(), "occupied cells are refused")
	GameState.give_item("garden_lantern", 1)
	check(DecorRules.place(area, "garden_lantern", Vector2i(4, 4), 0).is_empty(), "outdoor-only decor stays outside")
	check(not DecorRules.store(area, free_cell).is_empty() and GameState.inventory.count("wooden_chair") == 1, "storing back is a full refund")
	world.open_build_mode()
	check(world._overlay is BuildModePanel, "build mode opens inside the cottage")
	var bm := world._overlay as BuildModePanel
	bm.cursor_cell = Vector2i(3, 4)
	bm._select(bm.items.find("wooden_chair"))
	check(bm.place_here(), "build mode places the selected item")
	bm.undo()
	check(DecorRules.placements("interior").is_empty(), "undo removes it again")
	bm.cursor_cell = Vector2i(3, 4)
	bm._select(bm.items.find("wooden_chair"))
	bm.place_here()
	bm.close_mode()
	await _frames(1)
	check(DecorRules.placements("interior").size() == 1, "one chair stays placed")
	var door: Interactable = null
	for c in home.interior.get_children():
		if c is CottageInterior.InteriorDoor:
			door = c
	_use(door)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "", "stepping outside returns to the meadow")
	check(world.player.global_position.distance_to(home.exterior.global_position) < 200.0, "back at the cottage door")
	var homestead_pos: Vector2 = w.poi("homestead")["pos"]
	world.teleport_to(homestead_pos)
	check(home.area_here() == home.homestead_area, "standing on the homestead plot enables build mode")
	GameState.give_item("wooden_fence", 4)
	var h_area := home.homestead_area
	check(not DecorRules.place(h_area, "wooden_fence", Vector2i(1, 1), 1).is_empty(), "a rotated fence is placed outdoors")
	check(not DecorRules.place(h_area, "garden_lantern", Vector2i(2, 1), 0).is_empty(), "a garden lantern is placed outdoors")
	home.refresh_decor("homestead")
	check(DecorRules.placements("homestead").size() == 2, "homestead decorations recorded")

	# --- M6: Misty Pinewood, Sunpetal Coast and Isles ---------------------------------------
	var fx := world.features
	check(fx.patches.size() >= 4 and fx.docks.size() == 4 and fx.sites.has("lighthouse") and fx.wreck != null, "M6 places are spawned")
	check(fx.kits.size() == 3 and fx.den != null and fx.gloomlings.size() >= 4, "the fox family and the Gloomlings are placed")
	# Wildlife
	fx.wildlife.enabled = true
	world.teleport_to(w.poi("ws_pinewood")["pos"] + Vector2(0, 90))
	await _frames(2)
	var spawned := fx.wildlife.try_spawn_near(world.player.global_position)
	check(spawned != null and (CreatureDB.get_creature(spawned.species).get("regions", []) as Array).has(w.region_at(spawned.global_position)), "a creature that belongs here appears nearby")
	var deer := fx.wildlife.spawn("mist_deer", world.player.global_position + Vector2(200, 0))
	world.player.velocity = Vector2.ZERO
	await get_tree().create_timer(Creature.SKETCH_SECONDS + 0.5).timeout
	check(CreatureDB.is_sketched("mist_deer"), "watching calmly sketches the creature into the journal")
	# Put the deer at a known distance (it may have wandered while being watched).
	deer.global_position = world.player.global_position + Vector2(150, 0)
	deer.state = Creature.State.IDLE
	var gap := deer.global_position.distance_to(world.player.global_position)
	world.player.velocity = (deer.global_position - world.player.global_position).normalized() * 360.0
	deer._think(0.05)
	check(deer.state == Creature.State.FLEE, "hurrying toward a shy creature makes it move away gently")
	for i in 10:
		deer._think(0.05)
	check(deer.global_position.distance_to(world.player.global_position) > gap, "it keeps a little distance (no harm, no loss)")
	world.player.velocity = Vector2.ZERO
	GameState.give_item("berry", 1)
	_use(deer)
	check(CreatureDB.friendship("mist_deer") == 1, "offering a liked treat raises friendship")
	fx.wildlife.clear_all()
	fx.wildlife.enabled = false
	# Gloom
	var patch: GloomPatch = fx.patches["gloom_pine_1"]
	world.teleport_to(patch.global_position + Vector2(0, 120))
	GameState.inventory.remove("bright_lantern", GameState.inventory.count("bright_lantern"))
	_use(patch.heart)
	check(not patch.is_cleared, "the small lantern cannot clear gloom")
	check(fx.hint_near(patch.global_position, false).contains("Bright Lantern"), "Lumi explains what melts gloom")
	fx._hide_gathered_in_gloom()
	check(_gatherables_in(patch).all(func(g: Gatherable) -> bool: return not g.visible), "gloom hides the resources inside it")
	var kit1: LostKit = fx.kits[0]
	check(not kit1.can_interact(), "a lost kit stays hidden while its gloom remains")
	GameState.give_item("bright_lantern", 1)
	_use(patch.heart)
	check(patch.is_cleared and GloomPatch.is_patch_cleared("gloom_pine_1"), "the Bright Lantern melts the gloom")
	await get_tree().create_timer(GloomPatch.CLEAR_SECONDS + 0.4).timeout
	check(patch.veil.strength < 0.01, "color flows back as the veil fades")
	fx._hide_gathered_in_gloom()
	check(_gatherables_in(patch).all(func(g: Gatherable) -> bool: return g.visible), "the hidden resources appear")
	_use(kit1)
	check(kit1.state() == "following", "a found kit follows you")
	world.teleport_to(fx.den.global_position + Vector2(0, 150))
	await _frames(3)
	check(kit1.state() == "home", "near the den the kit runs home")
	var patch3: GloomPatch = fx.patches["gloom_pine_3"]
	world.teleport_to(patch3.global_position + Vector2(0, 120))
	GameState.inventory.remove("bright_lantern", 1)
	GameState.give_item("luma_bloom", 1)
	_use(patch3.heart)
	check(patch3.is_cleared and GameState.inventory.count("luma_bloom") == 0, "a Luma Bloom from the garden clears gloom too")
	GameState.give_item("bright_lantern", 1)
	for id: String in fx.patches:
		(fx.patches[id] as GloomPatch).clear_gloom(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var kit2: LostKit = fx.kits[1]
	check(_reachable_local(fx.patches["gloom_pine_2"].global_position + Vector2(0, 90), kit2.get_interaction_point(), 64.0), "once the gloom is gone, the thorns melt and the hidden kit can be reached")
	for k in fx.kits:
		if k.state() == "lost":
			_use(k)
	world.teleport_to(fx.den.global_position + Vector2(0, 150))
	await _frames(3)
	check(LostKit.kits_home() == 3 and GameState.has_flag("fox_family_home"), "all the kits are home")
	check(GameState.has_flag("hearthstone_pinewood") and GameState.inventory.count("hearthstone_pinewood") == 1, "the fox family gives the pinewood Hearthstone")
	# Gloomlings
	var gl: Gloomling = fx.gloomlings["gloomling_pine_path"]
	world.teleport_to(gl.global_position + Vector2(0, 110))
	var resin_before := GameState.inventory.count("resin")
	_use(gl)
	check(world._overlay is ChoicePanel, "comforting a Gloomling offers kind choices")
	(world._overlay as ChoicePanel)._choose("song")
	await _frames(3)
	check(gl.is_calm and Gloomling.is_calmed(gl.gloomling_id), "a melody comforts the Gloomling")
	check(GameState.inventory.count("resin") == resin_before + 3, "it leaves what it kept safe")
	await get_tree().physics_frame
	world.player.global_position = gl.global_position + Vector2(0, 80)
	for i in 20:
		world.player.velocity = Vector2.UP * Player.SPEED
		world.player.move_and_slide()
		await get_tree().physics_frame
	check(world.player.global_position.y < gl.global_position.y - 40.0, "the path it sat in is free now")
	# Lighthouse
	var site: RestorationSite = fx.sites["lighthouse"]
	world.teleport_to(site.global_position + Vector2(0, 100))
	_use(site)
	check(world._overlay is SitePanel, "the lighthouse opens its restoration checklist")
	var sp := world._overlay as SitePanel
	for s: Dictionary in site.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	for id in ["door", "stairs", "lens", "lamp"]:
		sp._restore(id)
	check(GameState.has_flag("lighthouse_lit"), "the lighthouse is relit")
	check(GameState.has_flag("hearthstone_coast") and GameState.inventory.count("hearthstone_coast") == 1, "the lighthouse gives the coast's Hearthstone")
	sp.close_panel()
	await _frames(2)
	# Boat to the Wreck Isle
	var dock: BoatDock = fx.docks["dock_lighthouse"]
	world.teleport_to(dock.arrival_point())
	GameState.inventory.remove("small_boat", GameState.inventory.count("small_boat"))
	_use(dock)
	await get_tree().create_timer(1.2).timeout
	check(world.current_region == "sunpetal_coast", "without a boat the dock only explains")
	GameState.give_item("small_boat", 1)
	_use(dock)
	await get_tree().create_timer(1.6).timeout
	check(world.current_region == "sunpetal_isles", "the boat sails to the isle")
	check(world.player.global_position.distance_to(fx.docks["dock_east_isle"].arrival_point()) < 10.0, "arriving at the isle's dock")
	for i in 4:
		for k in SignalPuzzle.SOLUTION[i]:
			_use(fx.wreck.lanterns[i])
	check(fx.wreck.is_solved and GameState.has_flag("wreck_signal_solved"), "the wreck's signal puzzle is solved")
	check(GameState.has_flag("hearthstone_isles"), "the wreck holds the isles' Hearthstone")
	_use(fx.docks["dock_east_isle"])
	await get_tree().create_timer(1.6).timeout
	check(world.current_region == "sunpetal_coast", "and the boat sails back")
	QuestManager.refresh()
	for q in ["side_dimming_pines", "side_fox_family", "side_lighthouse", "side_wreck_isle"]:
		check(QuestManager.book.is_completed(q), "%s complete" % q)
	world._open_journal()
	await _frames(2)
	check(world._overlay is JournalPanel and (world._overlay as JournalPanel).tabs.get_tab_count() == 8, "the journal has eight pages")
	(world._overlay as JournalPanel).close()
	await _frames(2)

	# --- M7: farming, fishing, cooking, weather ------------------------------------------
	_make_room(10)
	var home2 := world.homestead
	var h2 := home2.homestead_area
	GameState.give_item("garden_plot", 2)
	var plot_cell := Vector2i(1, 4)
	check(not DecorRules.place(h2, "garden_plot", plot_cell, 0).is_empty(), "a garden plot is placed on the homestead")
	home2.refresh_decor("homestead")
	await _frames(1)
	var plot: FarmPlot = null
	for n in get_tree().get_nodes_in_group(Interactable.GROUP):
		if n is FarmPlot and (n as FarmPlot).plot_key == Farming.plot_key("homestead", plot_cell):
			plot = n
	check(plot != null, "the plot becomes a farm plot in the world")
	world.teleport_to(plot.global_position + Vector2(0, 60))
	for id in ["seed_carrot", "seed_wheat", "seed_strawberry", "seed_pumpkin", "seed_luma"]:
		GameState.inventory.remove(id, GameState.inventory.count(id))
	GameState.give_item("seed_wheat", 2)
	TimeManager.load_state({"day": 40, "minute": 9.0 * 60.0})
	Weather.force("clear")
	_use(plot)
	check(Farming.has_crop(plot.plot_key), "E plants the seed")
	GameState.inventory.remove("watering_can", GameState.inventory.count("watering_can"))
	_use(plot)
	check(not Farming.is_watered_today(plot.plot_key), "without a can, the plot only explains")
	GameState.give_item("watering_can", 1)
	_use(plot)
	check(Farming.is_watered_today(plot.plot_key), "the watering can waters it")
	TimeManager.load_state({"day": 41, "minute": 9.0 * 60.0})
	Weather.force("rain")
	check(Farming.is_watered_today(plot.plot_key), "rain waters the crops")
	world._tick_world()
	await _frames(2)
	check(world.features.atmosphere.weather == "rain", "the rain shows in the world")
	TimeManager.load_state({"day": 42, "minute": 9.0 * 60.0})
	Weather.force("clear")
	check(Farming.is_ripe(plot.plot_key), "two watered days grow the wheat")
	var wheat_before := GameState.inventory.count("wheat")
	_use(plot)
	check(GameState.inventory.count("wheat") > wheat_before and not Farming.has_crop(plot.plot_key), "E harvests the crop")
	# Fishing
	var spot: FishingSpot = world.features.fishing_spots["fish_meadow_pond"]
	world.teleport_to(spot.global_position + Vector2(0, 60))
	GameState.inventory.remove("fishing_rod", GameState.inventory.count("fishing_rod"))
	_use(spot)
	check(not (world._overlay is FishingPanel), "without a rod, the ripples only explain")
	GameState.give_item("fishing_rod", 1)
	_use(spot)
	check(world._overlay is FishingPanel, "a rod starts fishing")
	var fp := world._overlay as FishingPanel
	check(fp.mode_id == AdaptiveComfortEngine.MODE_GENTLE, "fishing follows the session mode (Gentle)")
	fp.skip_wait()
	await get_tree().create_timer(1.0).timeout
	check(fp.stage == FishingPanel.Stage.CAUGHT and Fishing.species_caught() >= 1, "Gentle mode lands the fish for you")
	fp.close_panel()
	await _frames(2)
	check(not world._modal_open, "fishing closes cleanly")
	for id in ["pebble_minnow", "crystal_trout", "moss_carp", "tide_sardine", "moonfin"]:
		Fishing.record_catch(id, 12)
	var bridge: FishingSpot = world.features.fishing_spots["fish_creek_bridge"]
	world.teleport_to(bridge.global_position + Vector2(0, 60))
	_use(bridge)
	var lp := world._overlay as FishingPanel
	lp.skip_wait()
	check(lp.fish_id == "old_whiskers", "Old Whiskers visits the bridge after five kinds")
	await get_tree().create_timer(1.0).timeout
	lp.close_panel()
	await _frames(2)
	QuestManager.refresh()
	check(GameState.inventory.count("fish_trophy") == 1 and QuestManager.book.is_completed("side_old_whiskers"), "the legend leaves a plaque and completes its quest")
	# Cooking with new ingredients
	GameState.give_item("carrot", 2)
	GameState.give_item("mushroom", 1)
	check(GameState.try_experiment(["carrot", "mushroom"]) == "carrot_soup", "experimenting with crops discovers a dish")
	check(GameState.craft("carrot_soup", CraftingBook.COOKING_TIER), "farm crops cook into a dish")
	# The forgotten garden
	_make_room(8)
	var garden: WitheredGarden = world.features.gardens["forgotten_garden"]
	world.teleport_to(garden.plant.global_position + Vector2(0, 110))
	GameState.inventory.remove("watering_can", GameState.inventory.count("watering_can"))
	_use(garden.plant)
	check(not WitheredGarden.is_revived("forgotten_garden"), "the withered plant needs water")
	GameState.give_item("watering_can", 1)
	_use(garden.plant)
	check(WitheredGarden.is_revived("forgotten_garden"), "watering revives it")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(_reachable_local(garden.plant.global_position + Vector2(0, 90), garden.chest.get_interaction_point(), 64.0), "the way into the garden is open")
	_use(garden.chest)
	check(GameState.inventory.count("seed_pumpkin") >= 2, "the old chest holds seeds")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("side_first_harvest") and QuestManager.book.is_completed("side_forgotten_garden"), "farming quests complete")
	TimeManager.load_state({"day": 42, "minute": 10.0 * 60.0})
	GameState.give_item("seed_carrot", 1)
	_use(plot)
	check(world._overlay is ChoicePanel, "with several kinds of seeds, a choice opens")
	(world._overlay as ChoicePanel)._choose("seed_carrot")
	await _frames(3)
	check(Farming.has_crop(plot.plot_key) and String(Farming.plot(plot.plot_key)["seed"]) == "seed_carrot", "the chosen seed is planted")

	# --- M8: Echo Caverns ------------------------------------------------------------------
	_make_room(8)
	var cv := world.caves
	check(cv.caves.size() == 2 and cv.entrances.size() == 2, "two cave systems with entrances")
	var hollow: CaveLevel = cv.caves["cave_hollow"]
	var e1: CavesController.CaveEntrance = cv.entrances["cave_hollow"]
	world.teleport_to(e1.global_position + Vector2(0, 110))
	GameState.inventory.remove("bright_lantern", GameState.inventory.count("bright_lantern"))
	_use(e1)
	await get_tree().create_timer(1.2).timeout
	check(world.current_sublevel == "", "without a Bright Lantern the cave is too dark to enter")
	GameState.give_item("bright_lantern", 1)
	_use(e1)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "cave_hollow", "entering Whispering Hollow")
	check(hollow.camera_rect().has_point(world.player.global_position), "the player is inside the cave")
	check(world.night_tint.color.r < 0.7, "caves are dim inside")
	var order := {}
	for b in hollow.braziers.braziers:
		order[b.order] = b
	_use(order[2])
	check(hollow.braziers.lit_count() == 0, "lighting out of order gently puts the flames out")
	for i in [1, 2, 3, 4]:
		_use(order[i])
	check(hollow.braziers.is_solved, "the braziers are lit in order")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check((hollow.doors["1"] as CaveParts.CaveDoor).is_open, "the first door opens")
	for spec: Array in [[0, Vector2i(-1, 0), 3], [1, Vector2i(1, 0), 6]]:
		var block: CaveParts.PushBlock = hollow.blocks.nodes[int(spec[0])]
		for i in int(spec[2]):
			var behind: Vector2 = hollow.to_global(hollow.cell_center(hollow.blocks.blocks[int(spec[0])] + (spec[1] as Vector2i))) + Vector2(0, 8)
			world.player.global_position = behind
			world.player.update_target()
			if world.player.current_target != block:
				break
			world.player.try_interact()
	check(hollow.blocks.is_solved, "pushing the blocks onto the plates (E from behind them)")
	await get_tree().physics_frame
	await get_tree().physics_frame
	check((hollow.doors["2"] as CaveParts.CaveDoor).is_open, "the gate opens")
	world.player.global_position = hollow.pedestal.global_position + Vector2(0, 30)
	_use(hollow.pedestal)
	check(hollow.bridge_revealed(), "the Bright Lantern reveals the light bridge")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_cave_reachability(hollow)
	_use(hollow.chest)
	check(GameState.has_flag("cave_chest:hollow_chest") and (hollow.doors["3"] as CaveParts.CaveDoor).is_open, "the chest opens and so does the shortcut")
	var crystal_note: LoreNote = null
	for c in hollow.get_children():
		if c is LoreNote:
			crystal_note = c
	_use(crystal_note)
	await _frames(2)
	if world._overlay is LorePanel:
		(world._overlay as LorePanel).close_panel()
	await _frames(2)
	check(GameState.known_recipes.has("crystal_tuner"), "the Song of the Crystals teaches the Crystal Tuner")
	_use(hollow.exit_node)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "" and world.player.global_position.distance_to(e1.global_position) < 200.0, "leaving puts you back at the entrance")
	# Singing Grotto
	var grotto: CaveLevel = cv.caves["cave_grotto"]
	var e2: CavesController.CaveEntrance = cv.entrances["cave_grotto"]
	world.teleport_to(e2.global_position + Vector2(0, 110))
	_use(e2)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "cave_grotto", "entering the Singing Grotto")
	var tdoor: CaveParts.CaveDoor = grotto.doors["T"]
	GameState.inventory.remove("crystal_tuner", GameState.inventory.count("crystal_tuner"))
	_use(tdoor)
	check(not tdoor.is_open, "the crystal door waits for a tuner")
	GameState.give_item("crystal_tuner", 1)
	_use(tdoor)
	check(tdoor.is_open, "the tuner opens the crystal door")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for bp in grotto.beams:
		var goal: Dictionary = bp.logic.solutions()[0]
		for cell: Vector2i in goal:
			if int(bp.logic.mirrors[cell]) != int(goal[cell]):
				_use(bp.mirror_nodes[cell])
		check(bp.is_solved, "%s solved by turning crystals" % bp.puzzle_id)
		await get_tree().physics_frame
		await get_tree().physics_frame
	_check_cave_reachability(grotto)
	_use(grotto.hearth)
	check(GameState.has_flag("hearthstone_caverns") and GameState.inventory.count("hearthstone_caverns") == 1, "the Hearthstone of the Echoes")
	_use(grotto.chest)
	check(GameState.has_flag("cave_chest:grotto_chest"), "the grotto's chest opens after the beams")
	world.hud.hide_dialogue()
	# Loading a save made inside a cave puts you back inside it.
	SaveManager.pending_player = {"sublevel": "cave_grotto", "pos": [grotto.entry_point().x, grotto.entry_point().y]}
	world.leave_sublevel(e2.global_position + Vector2(0, 110))
	world._restore_sublevel_from_save()
	await _frames(3)
	check(world.current_sublevel == "cave_grotto", "a save made in a cave restores inside it")
	_use(grotto.exit_node)
	await get_tree().create_timer(1.6).timeout
	check(world.current_sublevel == "", "and you can always walk out")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("side_echo_caverns"), "the caverns quest is complete")

	# --- M10: Frostbloom Highlands ---------------------------------------------------------
	_make_room(10)
	var fx10 := world.features
	var pass_pos: Vector2 = w.poi("mountain_path")["pos"]
	world.teleport_to(pass_pos + Vector2(0, 300))
	for i in 40:
		world.player.velocity = Vector2.UP * Player.SPEED
		world.player.move_and_slide()
		await get_tree().physics_frame
	check(world.player.global_position.y > pass_pos.y + 30.0, "fallen rocks block the pass")
	var path_site: RestorationSite = fx10.sites["mountain_path"]
	world.teleport_to(path_site.global_position + Vector2(0, 90))
	_use(path_site)
	check(world._overlay is SitePanel, "the rockfall opens a restoration checklist")
	var psp := world._overlay as SitePanel
	GameState.inventory.remove("climbing_rope", GameState.inventory.count("climbing_rope"))
	for s: Dictionary in path_site.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	psp._restore("rope")
	check(not RestorationSite.is_step_done("mountain_path", "rope"), "the first step needs the climbing rope")
	GameState.give_item("climbing_rope", 1)
	for id in ["rope", "clear", "steps"]:
		psp._restore(id)
	psp.close_panel()
	await _frames(2)
	check(GameState.has_flag("highlands_path_open") and GameState.inventory.count("climbing_rope") == 1, "the path is restored and the rope kept")
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.teleport_to(pass_pos + Vector2(0, 160))
	for i in 70:
		world.player.velocity = Vector2.UP * Player.SPEED
		world.player.move_and_slide()
		await get_tree().physics_frame
	check(world.player.global_position.y < pass_pos.y - 60.0, "the new steps lead up into the highlands")
	await get_tree().create_timer(0.8).timeout
	check(world.current_region == "frostbloom_highlands", "arriving in the Frostbloom Highlands")
	var shrine10: AuroraShrine = fx10.shrine
	for i in 3:
		var guard := 0
		while not shrine10.correct(i) and guard < 4:
			_use(shrine10.prisms[i])
			guard += 1
	check(shrine10.is_solved and GameState.has_flag("aurora_aligned"), "the aurora shrine is aligned")
	check(GameState.has_flag("hearthstone_highlands") and GameState.inventory.count("hearthstone_highlands") == 1, "the Hearthstone of the Aurora")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("side_highlands"), "the highlands quest is complete")
	world.hud.hide_dialogue()

	# --- M9: villagers, request board, Act 2 and Act 3 -------------------------------------
	_make_room(10)
	var vc := world.village
	TimeManager.load_state({"day": 43, "minute": 11.0 * 60.0})
	vc.check_arrivals()
	for id in VillageDB.ids():
		check(VillageDB.has_arrived(id), "%s has moved into the village" % id)
	await _frames(2)
	var bramble: Villager = vc.villagers["bramble"]
	check(bramble.visible and bramble.can_interact(), "villagers are out and about by day")
	var site_b: RestorationSite = vc.home_sites["bramble"]
	world.teleport_to(site_b.global_position + Vector2(0, 90))
	_use(site_b)
	check(world._overlay is SitePanel, "a villager's tent opens the home-building checklist")
	var sp9 := world._overlay as SitePanel
	for s: Dictionary in site_b.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
	for s: Dictionary in site_b.steps():
		sp9._restore(String(s["id"]))
	sp9.close_panel()
	await _frames(2)
	check(VillageDB.home_built("bramble") and (vc.homes["bramble"] as Villager.HomeView).built(), "Bramble's home is built")
	QuestManager.refresh()
	world.teleport_to(bramble.global_position + Vector2(0, 90))
	await _frames(1)
	GameState.give_item("wildflower", 6)
	_use(bramble)
	check(world._overlay is VillagerPanel, "talking opens a chat with the villager")
	var vp := world._overlay as VillagerPanel
	var before_pts := VillageDB.points("bramble")
	vp._give("wildflower")
	check(VillageDB.points("bramble") > before_pts, "a loved gift raises friendship")
	vp._deliver("wildflower", 5)
	check(GameState.has_flag("delivered:bramble:wildflower"), "handing over what the quest asks for")
	vp.close_panel()
	await _frames(2)
	# Request board
	world.teleport_to(vc.board.global_position + Vector2(0, 100))
	GameState.give_item("fiber", 6)
	_use(vc.board)
	check(world._overlay is RequestBoardPanel, "the request board opens")
	var req: Dictionary = VillageDB.open_requests()[0]
	(world._overlay as RequestBoardPanel)._complete(req)
	check(VillageDB.request_done(String(req["id"])), "a request is completed")
	(world._overlay as RequestBoardPanel).close_panel()
	await _frames(2)
	# Act 2 at the Heart Tree
	world.teleport_to(vc.circle.global_position + Vector2(0, 80))
	_use(vc.circle)
	check(GameState.has_flag("act2_heard"), "the Heart Tree tells of the five Hearthstones")
	check(vc.hearthstones_found() == 5, "all five Hearthstones were found through play")
	world.hud.hide_dialogue()
	_use(vc.circle)
	check(GameState.has_flag("hearthstones_placed"), "all five are set in the circle")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("act2_hearthstones") and QuestManager.book.is_active("act3_return"), "Act 2 complete, Act 3 begins")
	check(QuestManager.tracked_id == "act3_return", "the HUD follows Act 3")
	for id in VillageDB.ids():
		VillageDB.invite(id)
	QuestManager.refresh()
	# 0.4.0: the finale is a cinematic. Saves go to a test folder so the
	# autosaves before and after it can be checked.
	SaveManager.set_save_dir("user://test_tmp/saves_finale")
	SaveManager.delete_slot(1)
	SaveManager.current_slot = 1
	var save_reasons: Array[String] = []
	var on_saved := func(_slot: int, reason: String) -> void: save_reasons.append(reason)
	SaveManager.saved.connect(on_saved)
	var expected_guests := 0
	for cid in CreatureDB.all_ids():
		if CreatureDB.friendship(cid) > 0:
			expected_guests += 1
	expected_guests = mini(expected_guests, VillageController.FINALE_CREATURES)
	_use(vc.circle)
	await get_tree().create_timer(5.0).timeout
	check(vc.finale_running and vc.cinematic != null, "the finale plays as a cinematic")
	check(not world.hud.visible and not vc.cinematic.caption_text().is_empty(), "the HUD steps aside for the closing lines")
	check(vc.guest_count() == expected_guests, "befriended creatures join the festival (%d)" % vc.guest_count())
	check(save_reasons.has("before the Festival of Light"), "the game autosaves before the finale")
	var esc := InputEventAction.new()
	esc.action = InputSetup.PAUSE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	var esc_up := InputEventAction.new()
	esc_up.action = InputSetup.PAUSE
	esc_up.pressed = false
	Input.parse_input_event(esc_up)
	await _frames(2)
	check(not world._modal_open, "Esc during the finale does not open the pause menu")
	await get_tree().create_timer(20.0).timeout
	check(vc.cinematic != null and vc.cinematic.credits_text().contains("Godot"), "the credits roll")
	check(world.camera.override_zoom > 0.0, "the camera takes a wide shot")
	await get_tree().create_timer(VillageController.FINALE_SECONDS + 1.0 - 25.0).timeout
	check(GameState.has_flag("act3_complete"), "the Festival of Light restores Lumeria")
	check(save_reasons.has("the Festival of Light"), "the game autosaves after the finale")
	check(vc.cinematic == null and vc.guest_count() == 0 and world.hud.visible and world.camera.override_zoom == 0.0, "the cinematic cleans up after itself")
	var lanterns_lit := true
	for post in vc.posts:
		if post.has_meta("festival"):
			lanterns_lit = lanterns_lit and post.visible
	check(lanterns_lit, "festival lanterns stay around the Heart Tree")
	var all_clear := true
	for patch_node: GloomPatch in world.features.patches.values():
		all_clear = all_clear and patch_node.is_cleared
	check(all_clear, "all gloom is gone")
	check(world._overlay is FinalePanel, "a gentle ending message")
	(world._overlay as FinalePanel).close_panel()
	await _frames(2)
	check(not world._modal_open and world.player.input_enabled, "and the world stays open")
	await get_tree().create_timer(Overworld.NIGHT_FADE_SECONDS + 0.5).timeout
	check(world.night_amount < 0.01, "after the finale the clock decides day and night again")
	QuestManager.refresh()
	check(QuestManager.book.is_completed("act3_return") and QuestManager.book.is_active("postgame_wider_journal"), "post-game goals open up")
	var epilogue: LoreNote = null
	for n in get_tree().get_nodes_in_group(Interactable.GROUP):
		if n is LoreNote and (n as LoreNote).note_id == "note_epilogue":
			epilogue = n
	check(epilogue != null and epilogue.can_interact(), "a new note appears at the sanctuary")
	check(CreatureDB.matches("aurora_stag", "whispering_meadow", true, "clear"), "the Aurora Stag now roams")
	# The finale can be skipped at any moment (hold Esc); the result is the same.
	# (Test only: the flag is cleared so the finale can be played a second time.)
	GameState.set_flag("act3_complete", false)
	save_reasons.clear()
	vc.play_finale()
	await get_tree().create_timer(1.5).timeout
	check(vc.cinematic != null and world.player._input_block > 0.0, "the replayed finale holds the controls")
	vc.cinematic.request_skip()
	await _frames(4)
	check(not vc.finale_running and GameState.has_flag("act3_complete"), "skipping the finale still completes it")
	check(world._overlay is FinalePanel and save_reasons.has("the Festival of Light"), "a skipped finale still autosaves and says goodbye")
	(world._overlay as FinalePanel).close_panel()
	await _frames(2)
	check(not world._modal_open and world.player.input_enabled and world.hud.visible, "after skipping, free exploration continues")
	var after_skip := world.player.global_position
	for i in 20:
		world.player.velocity = Vector2.UP * Player.SPEED
		world.player.move_and_slide()
		await get_tree().physics_frame
	check(world.player.global_position.distance_to(after_skip) > 30.0, "the player can walk again after a skipped finale")
	# Light budget: at night in the village, with every lantern built.
	TimeManager.load_state({"day": TimeManager.day, "minute": 23.0 * 60.0})
	world.teleport_to(vc.circle.global_position + Vector2(0, 220))
	await get_tree().create_timer(1.0).timeout
	var lights := _enabled_lights()
	check(lights <= Overworld.LIGHT_BUDGET, "lights near the screen stay within the budget at the festival (%d of %d)" % [lights, Overworld.LIGHT_BUDGET])
	world.teleport_to(vc.fire.global_position + Vector2(0, 160))
	await get_tree().create_timer(1.0).timeout
	lights = _enabled_lights()
	check(lights <= Overworld.LIGHT_BUDGET, "lights near the screen stay within the budget in the village (%d of %d)" % [lights, Overworld.LIGHT_BUDGET])
	SaveManager.saved.disconnect(on_saved)
	SaveManager.delete_slot(1)
	SaveManager.set_save_dir("user://saves")
	SaveManager.current_slot = -1
	world.hud.hide_dialogue()

	# --- M11: music, ambience, captions, gamepad, weather toggle -----------------------------
	var mm := MusicManager
	TimeManager.load_state({"day": 44, "minute": 11.0 * 60.0})
	var pine_ws: Vector2 = w.poi("ws_pinewood")["pos"] + Vector2(0, 90)
	var coast_ws: Vector2 = w.poi("ws_coast")["pos"] + Vector2(0, 90)
	world.teleport_to(pine_ws)
	await get_tree().create_timer(MusicManager.HYSTERESIS + 0.8).timeout
	check(mm.current_cue == "pinewood" and mm.current_ambience == "wind_pines", "Misty Pinewood plays its own music and wind")
	world.teleport_to(coast_ws)
	await get_tree().create_timer(0.6).timeout
	world.teleport_to(pine_ws)
	await get_tree().create_timer(MusicManager.HYSTERESIS + 0.5).timeout
	check(mm.current_cue == "pinewood", "hopping away and straight back never restarts the music")
	world.teleport_to(coast_ws)
	await get_tree().create_timer(MusicManager.HYSTERESIS + MusicManager.CROSSFADE + 1.0).timeout
	check(mm.current_cue == "coast" and mm.current_ambience == "waves", "the coast music and waves take over")
	check(mm.playing_music_players() == 1, "after the crossfade only one music player is playing")
	var cottage_cue := MusicManager.cue_for(world.current_region, HomesteadController.SUBLEVEL, false)
	check(cottage_cue == "cottage", "the cottage has its own quiet music")
	GameSettings.captions = true
	AudioManager.play(&"discover")
	await _frames(2)
	check(world.hud._caption.visible and world.hud._caption.text.contains("twinkle"), "captions describe important sounds")
	GameSettings.captions = false
	var slot_before := world.hud.selected_hotbar
	var next := InputEventAction.new()
	next.action = InputSetup.HOTBAR_NEXT
	next.pressed = true
	world._unhandled_input(next)
	check(world.hud.selected_hotbar == (slot_before + 1) % Inventory.HOTBAR_SIZE, "the gamepad shoulder button cycles the hotbar")
	Weather.force("rain")
	GameSettings.weather_effects = false
	world._on_settings_changed()
	check(Weather.today() == "clear" and Weather.is_raining(), "weather effects can be turned off (crops are still watered)")
	GameSettings.weather_effects = true
	world._on_settings_changed()
	Weather.force("clear")

	# --- M5: save, "quit", relaunch, continue -------------------------------------------
	var sm := SaveManager
	sm.set_save_dir("user://test_tmp/saves_ow")
	sm.delete_slot(1)
	sm.current_slot = 1
	GameState.bound_session_id = "slot:1"
	var creek_spot := creek_ws.position + Vector2(0, 80)
	world.teleport_to(creek_spot)
	var twine_before := GameState.inventory.count("twine")
	var plank_before := GameState.inventory.count("plank")
	var day_before := TimeManager.day
	check(sm.save_slot(1, "test"), "manual save works")
	world.queue_free()
	await _frames(2)
	# Simulate quitting the game: wipe everything in memory.
	GameState.reset_world(w.world_size())
	QuestManager.book.reset_progress()
	TimeManager.reset_clock()
	sm.reload_current()
	world = OVERWORLD.instantiate()
	add_child(world)
	world.features.wildlife.enabled = false
	await _frames(5)
	QuestManager.refresh()
	check(world.player.global_position.distance_to(creek_spot) < 4.0, "player position restored after relaunch")
	check(QuestManager.is_act_complete(1), "quest progress restored after relaunch")
	check(GameState.waystone_state("ws_grove") == GameState.WAYSTONE_RESTORED, "waystones restored after relaunch")
	check(GameState.inventory.count("twine") == twine_before and GameState.inventory.count("plank") == plank_before, "inventory restored after relaunch")
	check(world.story.puzzle.is_solved and world.story.moon_gate.is_open, "puzzle and veil state restored after relaunch")
	check(world.story.altar.restored, "the restored altar stays restored")
	check(TimeManager.day == day_before, "the clock restored after relaunch")
	check(SessionState.session_active, "the research session is unaffected by loading")
	check(world.homestead.is_step_done("roof") and GameState.has_flag("cottage_restored"), "cottage restoration persists")
	# Homestead: the fence and lantern from M4 plus the garden plot from M7.
	check(DecorRules.placements("interior").size() == 1 and DecorRules.placements("homestead").size() == 3, "decorations persist")
	check(world.features.patches["gloom_pine_1"].is_cleared and GloomPatch.is_patch_cleared("gloom_pine_2"), "cleared gloom persists")
	check(LostKit.kits_home() == 3 and GameState.has_flag("lighthouse_lit") and world.features.wreck.is_solved, "fox family, lighthouse and wreck progress persist")
	check(CreatureDB.is_sketched("mist_deer") and CreatureDB.friendship("mist_deer") == 1, "the creature journal persists")
	check(world.features.gloomlings["gloomling_pine_path"].is_calm, "comforted Gloomlings stay light spirits")
	check(Farming.has_crop(Farming.plot_key("homestead", Vector2i(1, 4))), "planted crops persist")
	check(Fishing.caught("old_whiskers") == 1 and Fishing.species_caught() >= 6, "the fish journal persists")
	check(WitheredGarden.is_revived("forgotten_garden"), "the revived garden stays open")
	check(Weather.rained_on(41), "the weather history persists")
	check(GameState.has_flag("hearthstone_caverns") and world.caves.caves["cave_hollow"].braziers.is_solved and world.caves.caves["cave_hollow"].bridge_revealed(), "cave puzzles persist")
	check((world.caves.caves["cave_grotto"].doors["T"] as CaveParts.CaveDoor).is_open, "a tuned crystal door stays open")
	check(VillageDB.home_built("bramble") and VillageDB.points("bramble") > 0 and GameState.has_flag("act3_complete"), "villagers, homes and the story persist")
	sm.delete_slot(1)
	sm.set_save_dir("user://saves")
	sm.current_slot = -1

	# --- Session data unchanged by V2 -------------------------------------------------------------
	check(SessionRecord.COLUMNS.size() == 16 and SessionRecord.SCHEMA_VERSION == 1, "session CSV schema unchanged")
	world.queue_free()
	await get_tree().process_frame


## Flood fill inside the cottage interior from the door: every restoration
## spot and station must be reachable.
func _check_interior_reachability(home: HomesteadController) -> void:
	var space := world.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.exclude = [world.player.get_rid()]
	var area := home.interior.area
	var step := 16.0
	var rect := area.rect()
	var start := home.interior.entry_point()
	var free := {}
	var cols := int(rect.size.x / step)
	var rows := int(rect.size.y / step)
	for y in rows:
		for x in cols:
			var p := rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * step
			params.transform = Transform2D(0.0, p + Vector2(0, -6))
			if space.intersect_shape(params, 1).is_empty():
				free[Vector2i(x, y)] = p
	var s := Vector2i(((start - rect.position) / step).floor())
	check(free.has(s), "the cottage entry point is free")
	var reached := {s: true}
	var queue: Array[Vector2i] = [s]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if free.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if not rect.grow(40).has_point(it.global_position):
			continue
		var best := INF
		for cell: Vector2i in reached:
			best = minf(best, (free[cell] as Vector2).distance_to(it.get_interaction_point()) - it.reach_bonus)
		check(best <= 64.0, "inside the cottage, %s is reachable (%.0f px)" % [it.interactable_id, best])


## Flood fill over a whole cave from its entrance (all doors open): every
## interactable inside must be reachable.
func _check_cave_reachability(cave: CaveLevel) -> void:
	var space := world.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.exclude = [world.player.get_rid()]
	var step := 16.0
	var rect := Rect2(cave.global_position, cave.size_px())
	var free := {}
	for y in int(rect.size.y / step):
		for x in int(rect.size.x / step):
			var p := rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * step
			params.transform = Transform2D(0.0, p + Vector2(0, -6))
			if space.intersect_shape(params, 1).is_empty():
				free[Vector2i(x, y)] = p
	var s := Vector2i(((cave.entry_point() - rect.position) / step).floor())
	check(free.has(s), "%s entry point is free" % cave.cave_id)
	var reached := {s: true}
	var queue: Array[Vector2i] = [s]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if free.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if not rect.has_point(it.global_position) or not it.can_interact():
			continue
		var best := INF
		for cell: Vector2i in reached:
			best = minf(best, (free[cell] as Vector2).distance_to(it.get_interaction_point()) - it.reach_bonus)
		check(best <= 64.0, "in %s, %s is reachable (%.0f px)" % [cave.cave_id, it.interactable_id, best])


## Frees bag slots by moving ordinary stacks to the chest (the bag fills up
## over the long test; this keeps later pickups in the bag).
func _make_room(slots: int) -> void:
	var inv := GameState.inventory
	var free := 0
	for s in inv.slots:
		if s.is_empty():
			free += 1
	for i in range(inv.capacity() - 1, -1, -1):
		if free >= slots:
			return
		var s: Dictionary = inv.slots[i]
		if s.is_empty() or ItemDB.is_unique(String(s["id"])):
			continue
		StoragePanel.move_stack(inv, GameState.storage, i)
		if inv.slots[i].is_empty():
			free += 1


## Gatherables currently loaded inside a gloom patch.
func _gatherables_in(patch: GloomPatch) -> Array[Gatherable]:
	var out: Array[Gatherable] = []
	for chunk_node: Node2D in world.streamer.loaded.values():
		for c in chunk_node.get_children():
			if c is Gatherable and patch.contains((c as Gatherable).global_position):
				out.append(c)
	return out


## Local flood fill with the player's collision: can `to` be reached from `from`?
func _reachable_local(from: Vector2, to: Vector2, reach: float) -> bool:
	var space := world.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.exclude = [world.player.get_rid()]
	var step := 16.0
	var rect := Rect2(from - Vector2(700, 600), Vector2(1400, 1200))
	var free := {}
	for y in int(rect.size.y / step):
		for x in int(rect.size.x / step):
			var p := rect.position + (Vector2(x, y) + Vector2(0.5, 0.5)) * step
			if world.world.is_blocked_at(p):
				continue
			params.transform = Transform2D(0.0, p + Vector2(0, -6))
			if space.intersect_shape(params, 1).is_empty():
				free[Vector2i(x, y)] = p
	var s := Vector2i(((from - rect.position) / step).floor())
	if not free.has(s):
		return false
	var reached := {s: true}
	var queue: Array[Vector2i] = [s]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if (free[c] as Vector2).distance_to(to) <= reach:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if free.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)
	return false


## Stands next to an interactable and presses E (the same path the player uses).
func _use(target: Interactable) -> void:
	var player := world.player
	player.global_position = target.get_interaction_point() + Vector2(0, 8)
	player.update_target()
	if player.current_target != target:
		player.global_position = target.get_interaction_point() + Vector2(0, -8)
		player.update_target()
	check(player.current_target == target, "can target %s" % target.interactable_id)
	player.try_interact()
