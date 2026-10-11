extends Node
## Developer tool: renders key screens and places in a real window and saves
## PNGs to screenshots/ (README images and visual review). Not part of the game.
##
## Run (needs a display, not --headless):
##   godot --path . res://tools/capture/capture_screenshots.tscn
## Journal progress goes to user://capture_tmp/; consent is off, so nothing is
## written to the session file. Also prints chunk build timings and FPS samples.
##
## Another language (for checking translations and text overflow), saved to
## screenshots/<code>/ without changing the player's settings:
##   godot --path . res://tools/capture/capture_screenshots.tscn -- --lang=id
## A different output folder (absolute path): -- --out=C:/somewhere

const BASE_OUT_DIR := "res://screenshots"
const OVERWORLD := "res://game/scenes/world/overworld.tscn"

var world: Overworld
var _fps_samples: PackedFloat32Array = []
var out_dir := BASE_OUT_DIR


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	var placeholder := Node.new()
	get_tree().root.add_child.call_deferred(placeholder)
	await get_tree().process_frame
	get_tree().current_scene = placeholder
	# English unless --lang asks otherwise (the player's own language setting is
	# not used, and nothing is saved).
	L.set_language("en")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang=") and L.LANGUAGES.has(arg.trim_prefix("--lang=")):
			L.set_language(arg.trim_prefix("--lang="))
	if L.current() != "en":
		out_dir = "%s/%s" % [BASE_OUT_DIR, L.current()]
	# --out=<folder> writes somewhere else (e.g. a scratch folder for a quick look).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://capture_tmp"))
	SessionState.progress = ProgressStore.new("user://capture_tmp/progress.cfg")
	await _capture_all()
	get_tree().quit()


func _capture_all() -> void:
	await _show("res://game/scenes/ui/main_menu.tscn", 1.5)
	await _snap("01_main_menu")
	await _show("res://game/scenes/ui/check_in.tscn", 1.0)
	await _snap("02_check_in")

	SessionState.begin_session(7, AdaptiveComfortEngine.MODE_GENTLE, false)
	await _show(OVERWORLD, 0.5)
	world = get_tree().current_scene as Overworld
	await _goto(Vector2(4330, 2620), 2.5)
	await _snap("03_meadow_gentle")

	for id: String in MeadowLayout.LIGHTS.keys().slice(0, 8):
		for mote in world.meadow.motes.duplicate():
			if mote.interactable_id == id:
				mote.interact()
	world.hud.hide_dialogue()
	world.meadow.heart_tree.interact()
	await _goto(Vector2(4520, 2640), 3.2)
	world.hud.hide_dialogue()
	await _snap("04_heart_tree_restored")
	printerr("step: waiting for completion panel")
	await _wait(2.2)
	printerr("step: modal=%s" % world._modal_open)
	if world._modal_open:
		world._close_completion()
	printerr("step: going to grove")

	await _goto(Vector2(2700, 1500), 2.0)
	world.hud.hide_dialogue()
	await _snap("05_firefly_grove")
	await _measure_walk(Vector2(1, 0.4), 3.0)

	world.teleport_to(world.meadow.shrine.position + Vector2(-90, 80))
	world.meadow.shrine.interact()
	await _wait(4.0)
	await _snap("06_lantern_catch_night")
	world.lantern_catch.end_night(false)
	await _wait(3.0)

	await _goto(Vector2(6560, 3150), 2.0)
	world.hud.hide_dialogue()
	await _snap("07_crystal_creek_puzzle")
	await _measure_walk(Vector2(0.3, 1), 3.0)

	await _goto(Vector2(4864, 1640), 2.0)
	world.hud.hide_dialogue()
	await _snap("08_moonlit_veil")

	await _goto(Vector2(2400, 4200), 2.0)
	world.hud.hide_dialogue()
	await _snap("09_misty_pinewood")

	await _goto(Vector2(7900, 4300), 2.0)
	world.hud.hide_dialogue()
	await _snap("10_sunpetal_coast")

	world.open_map()
	await _wait(0.8)
	await _snap("11_world_map")
	if world._overlay != null:
		(world._overlay as MapPanel).close_map()
	await _wait(0.3)

	world._open_pause()
	await _wait(0.6)
	await _snap("12_pause_menu")
	world._close_pause()

	# --- V2 M3/M4: inventory, crafting, cottage, build mode, cooking -------------------
	for item: Array in [["branch", 14], ["fiber", 20], ["stone", 12], ["plank", 20], ["twine", 8], ["clay", 8], ["sea_glass", 2], ["wildflower", 8], ["berry", 6], ["mushroom", 4], ["wooden_chair", 2], ["round_table", 1], ["woven_rug", 1], ["potted_plant", 2], ["garden_lantern", 3], ["wooden_fence", 8], ["stone_path", 6]]:
		GameState.give_item(item[0], item[1])
	world.teleport_to(Vector2(4000, 2520))
	await _wait(1.0)
	world.open_inventory(1)
	await _wait(0.8)
	await _snap("14_inventory_crafting")
	(world._overlay as InventoryPanel).close_panel()
	var home := world.homestead
	world.enter_sublevel("cottage", home.interior.entry_point(), home.interior.camera_rect(), HomesteadController.INTERIOR_ZOOM)
	await _wait(1.5)
	world.hud.hide_dialogue()
	await _snap("15_cottage_before")
	for id in ["roof", "hearth", "window", "bed", "workbench", "cooking_pot", "storage_chest", "bookshelf"]:
		home.try_restore(id)
	world.hud.hide_dialogue()
	var area := home.interior.area
	DecorRules.place(area, "woven_rug", Vector2i(4, 3), 0)
	DecorRules.place(area, "round_table", Vector2i(7, 3), 0)
	DecorRules.place(area, "wooden_chair", Vector2i(6, 3), 0)
	DecorRules.place(area, "potted_plant", Vector2i(0, 3), 0)
	home.refresh_decor("interior")
	await _wait(1.2)
	world.hud.hide_dialogue()
	await _snap("16_cottage_restored")
	world.open_build_mode()
	await _wait(0.6)
	await _snap("17_build_mode")
	(world._overlay as BuildModePanel).close_mode()
	world.open_cooking()
	await _wait(0.6)
	await _snap("18_cooking")
	(world._overlay as CookingPanel).close_panel()
	world.leave_sublevel(home.exterior.get_interaction_point() + Vector2(0, 60))
	var h_area := home.homestead_area
	for x in range(1, 9):
		DecorRules.place(h_area, "wooden_fence", Vector2i(x, 1), 0)
	for x in range(2, 8):
		DecorRules.place(h_area, "stone_path", Vector2i(x, 3), 0)
	DecorRules.place(h_area, "garden_lantern", Vector2i(2, 2), 0)
	DecorRules.place(h_area, "garden_lantern", Vector2i(7, 2), 0)
	home.refresh_decor("homestead")
	TimeManager.load_state({"day": 3, "minute": 21.5 * 60.0})
	world.teleport_to(h_area.rect().get_center() + Vector2(0, 120))
	await _wait(2.0)
	world.hud.hide_dialogue()
	await _snap("19_homestead_night")
	TimeManager.load_state({"day": 3, "minute": 10.0 * 60.0})

	# --- V2 M6: Misty Pinewood, gloom, wildlife, lighthouse, isles ---------------------
	var fx := world.features
	world.teleport_to(Vector2(1260, 2860))
	await _wait(3.0)
	world.hud.hide_dialogue()
	await _snap("21_pinewood_gloom")
	world.teleport_to(Vector2(2600, 3720))
	await _wait(0.8)
	fx.wildlife.clear_all()
	var p := world.player.global_position
	for c: Array in [["mist_deer", Vector2(-230, -60)], ["ember_fox", Vector2(170, -90)], ["puff_squirrel", Vector2(-120, 110)], ["moss_hedgehog", Vector2(210, 90)], ["hush_owl", Vector2(40, -170)], ["meadow_bunny", Vector2(-300, 60)]]:
		fx.wildlife.spawn(String(c[0]), p + (c[1] as Vector2))
	await _wait(1.2)
	world.hud.hide_dialogue()
	await _snap("22_creatures")
	GameState.give_item("bright_lantern", 1)
	var patch: GloomPatch = fx.patches["gloom_pine_1"]
	world.teleport_to(patch.global_position + Vector2(-60, 160))
	await _wait(0.6)
	patch.clear_gloom()
	await _wait(GloomPatch.CLEAR_SECONDS + 0.6)
	world.hud.hide_dialogue()
	await _snap("23_gloom_cleared")
	var gl: Gloomling = fx.gloomlings["gloomling_pine_den"]
	world.teleport_to(gl.global_position + Vector2(0, 110))
	await _wait(0.5)
	fx._on_gloomling(gl)
	await _wait(0.6)
	await _snap("24_gloomling_choice")
	(world._overlay as ChoicePanel).close_panel()
	var site: RestorationSite = fx.sites["lighthouse"]
	for s: Dictionary in site.steps():
		for part: Dictionary in s["inputs"]:
			GameState.give_item(String(part["item"]), int(part["qty"]))
		site.restore_step(String(s["id"]))
	TimeManager.load_state({"day": 4, "minute": 21.0 * 60.0})
	world.teleport_to(site.global_position + Vector2(-60, 70))
	await _wait(2.5)
	world.hud.hide_dialogue()
	await _snap("25_lighthouse_night")
	TimeManager.load_state({"day": 4, "minute": 11.0 * 60.0})
	world.teleport_to(fx.docks["dock_east_isle"].arrival_point() + Vector2(200, 60))
	await _wait(2.0)
	world.hud.hide_dialogue()
	await _snap("26_wreck_isle")
	world._open_journal()
	await _wait(0.4)
	(world._overlay as JournalPanel).tabs.current_tab = 2
	await _wait(0.4)
	await _snap("27_journal_creatures")
	(world._overlay as JournalPanel).close()
	await _wait(0.3)

	# --- V2 M7: farming, weather, fishing, the forgotten garden ------------------------
	TimeManager.load_state({"day": 10, "minute": 10.0 * 60.0})
	var h7 := world.homestead.homestead_area
	var crops := [["seed_wheat", 9, {}], ["seed_carrot", 8, {"8": true}], ["seed_strawberry", 4, {"4": true, "5": true, "6": true, "7": true, "8": true, "9": true}], ["seed_pumpkin", 7, {"7": true, "8": true, "9": true}], ["seed_luma", 5, {"5": true, "6": true, "7": true, "8": true, "9": true}]]
	for i in crops.size():
		var cell := Vector2i(1 + i, 5)
		GameState.give_item("garden_plot", 1)
		DecorRules.place(h7, "garden_plot", cell, 0)
		Farming.plots()[Farming.plot_key("homestead", cell)] = {"seed": crops[i][0], "planted": crops[i][1], "watered": crops[i][2]}
	world.homestead.refresh_decor("homestead")
	world.teleport_to(h7.cell_center(Vector2i(5, 5)) + Vector2(60, 190))
	await _wait(4.5)
	world.hud.hide_dialogue()
	await _snap("28_farm_plots")
	Weather.force("rain")
	world.teleport_to(Vector2(4700, 2800))
	await _wait(3.2)
	world.hud.hide_dialogue()
	await _snap("29_rain")
	Weather.force("clear")
	GameState.give_item("fishing_rod", 1)
	var pond: FishingSpot = fx.fishing_spots["fish_meadow_pond"]
	world.teleport_to(pond.global_position + Vector2(0, 60))
	await _wait(0.8)
	world.open_fishing(pond)
	var fishing := world._overlay as FishingPanel
	fishing.mode_id = &"balanced"
	fishing.skip_wait()
	fishing.press()
	await _wait(1.2)
	await _snap("30_fishing")
	fishing.close_panel()
	await _wait(0.3)
	GameState.give_item("watering_can", 1)
	var garden: WitheredGarden = fx.gardens["forgotten_garden"]
	world.teleport_to(garden.plant.global_position + Vector2(0, 150))
	await _wait(1.0)
	world.hud.hide_dialogue()
	await _snap("31_withered_garden")
	garden.revive()
	await _wait(2.0)
	world.hud.hide_dialogue()
	await _snap("32_garden_revived")
	for id in ["moss_carp", "pebble_minnow", "tide_sardine", "lantern_eel"]:
		Fishing.record_catch(id, 20)
	world._open_journal()
	await _wait(0.4)
	(world._overlay as JournalPanel).tabs.current_tab = 3
	await _wait(0.4)
	await _snap("33_journal_fish")
	(world._overlay as JournalPanel).close()
	await _wait(0.3)

	# --- V2 M8: Echo Caverns ------------------------------------------------------------
	var hollow: CaveLevel = world.caves.caves["cave_hollow"]
	world.enter_sublevel(hollow.cave_id, hollow.entry_point(), hollow.camera_rect(), CavesController.ZOOM)
	for b in hollow.braziers.braziers:
		if b.order <= 2:
			hollow.braziers.light(b)
	world.player.global_position = hollow.to_global(hollow.cell_center(Vector2i(3, 5)))
	world.camera.snap()
	await _wait(1.2)
	world.hud.hide_dialogue()
	await _snap("34_cave_braziers")
	for b in hollow.braziers.braziers:
		if b.order > 2:
			hollow.braziers.light(b)
	hollow.blocks.push(0, hollow.to_global(hollow.cell_center(hollow.blocks.blocks[0] + Vector2i(-1, 0))))
	world.player.global_position = hollow.to_global(hollow.cell_center(Vector2i(16, 4)))
	world.camera.snap()
	await _wait(1.2)
	world.hud.hide_dialogue()
	await _snap("35_cave_blocks")
	GameState.set_puzzle_state("hollow_bridge", {"solved": true})
	hollow.refresh_doors(true)
	world.player.global_position = hollow.to_global(hollow.cell_center(Vector2i(13, 10)))
	world.camera.snap()
	await _wait(1.0)
	await _snap("36_cave_bridge")
	var grotto: CaveLevel = world.caves.caves["cave_grotto"]
	world.enter_sublevel(grotto.cave_id, grotto.entry_point(), grotto.camera_rect(), CavesController.ZOOM)
	GameState.set_flag(grotto.door_flag("T"))
	grotto.refresh_doors(true)
	world.player.global_position = grotto.to_global(Vector2(416, 470))
	world.camera.snap()
	await _wait(1.2)
	world.hud.hide_dialogue()
	await _snap("37_grotto_beam")
	world.leave_sublevel(Vector2(4700, 2800))
	await _wait(0.5)

	# --- V2 M10: Frostbloom Highlands ------------------------------------------------------
	var path_site: RestorationSite = world.features.sites["mountain_path"]
	TimeManager.load_state({"day": 11, "minute": 11.0 * 60.0})
	world.teleport_to(path_site.global_position + Vector2(-40, 120))
	await _wait(2.0)
	world.hud.hide_dialogue()
	await _snap("45_mountain_pass")
	world.features.open_mountain_path()
	var shrine: AuroraShrine = world.features.shrine
	world.teleport_to(shrine.global_position + Vector2(-60, 200))
	await _wait(3.0)
	world.hud.hide_dialogue()
	await _snap("46_highlands_shrine")
	for i in 3:
		while not shrine.correct(i):
			shrine.turn(i)
	TimeManager.load_state({"day": 11, "minute": 22.0 * 60.0})
	await _wait(4.0)
	world.hud.hide_dialogue()
	await _snap("47_aurora_night")

	# --- V2 M9: the spirit village, Act 2 and Act 3 -------------------------------------
	var vc := world.village
	for id in VillageDB.ids():
		GameState.set_flag("villager_arrived:" + id)
	for id in ["bramble", "pip", "mossa"]:
		GameState.set_flag("home_built:" + id)
	vc._sync_village()
	TimeManager.load_state({"day": 12, "minute": 11.5 * 60.0})
	world.teleport_to(Vector2(5750, 3520))
	await _wait(2.5)
	world.hud.hide_dialogue()
	await _snap("38_village")
	world.open_villager_panel("bramble")
	await _wait(0.6)
	await _snap("39_villager_chat")
	(world._overlay as VillagerPanel).close_panel()
	await _wait(0.3)
	world.open_request_board()
	await _wait(0.6)
	await _snap("40_request_board")
	(world._overlay as RequestBoardPanel).close_panel()
	TimeManager.load_state({"day": 12, "minute": 19.0 * 60.0})
	world.teleport_to(Vector2(5750, 3660))
	await _wait(3.0)
	world.hud.hide_dialogue()
	await _snap("41_village_evening")
	for k in ["pinewood", "coast", "isles", "caverns", "highlands"]:
		GameState.set_flag("hearthstone_" + k)
	for f in ["act1_complete", "act2_heard", "hearthstones_placed"]:
		GameState.set_flag(f)
	TimeManager.load_state({"day": 12, "minute": 20.0 * 60.0})
	world.teleport_to(vc.circle.global_position + Vector2(0, 170))
	await _wait(1.0)
	vc.play_finale()
	await _wait(4.0)
	await _snap("42a_finale_gathering")
	# The light spreads (about 12-21 s), then the credits roll.
	await _wait(11.0)
	await _snap("42_festival_of_light")
	await _wait(11.0)
	await _snap("42b_finale_credits")
	var waited := 0.0
	while vc.finale_running and waited < 20.0:
		await _wait(0.5)
		waited += 0.5
	await _wait(0.5)
	if world._overlay is FinalePanel:
		await _snap("43_finale_panel")
		(world._overlay as FinalePanel).close_panel()
	await _wait(0.3)
	world._open_journal()
	await _wait(0.4)
	(world._overlay as JournalPanel).tabs.current_tab = 7
	await _wait(0.4)
	await _snap("44_journal_villagers")
	(world._overlay as JournalPanel).close()
	await _wait(0.3)

	# --- V2 M11: settings (audio, assistance, controls) and cloud shadows ----------------
	TimeManager.load_state({"day": 13, "minute": 10.5 * 60.0})
	Weather.force("clear")
	world.teleport_to(Vector2(4300, 3000))
	await _wait(3.5)
	world.hud.hide_dialogue()
	await _snap("48_meadow_cloud_shadows")
	var settings := SettingsPanel.new()
	world.hud.add_overlay(settings)
	await _wait(0.6)
	await _snap("49_settings_audio")
	var scrolls := settings.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		(scrolls[0] as ScrollContainer).scroll_vertical = 100000
	await _wait(0.6)
	await _snap("50_settings_controls")
	settings.close()
	await _wait(0.3)

	print("chunk builds: %d, last %.1f ms, max %.1f ms" % [world.streamer.total_builds, world.streamer.last_build_usec / 1000.0, world.streamer.max_build_usec / 1000.0])
	print("loaded chunks now: %d, objects: %d" % [world.streamer.loaded.size(), world.streamer.object_count()])
	if not _fps_samples.is_empty():
		var total := 0.0
		var lowest := INF
		for f in _fps_samples:
			total += f
			lowest = minf(lowest, f)
		print("FPS while walking: avg %.1f, min %.1f over %d samples" % [total / _fps_samples.size(), lowest, _fps_samples.size()])

	SessionState.end_gameplay()
	SessionState.set_reflection(5, 4)
	SessionState.finalize_and_save(true)
	await _show("res://game/scenes/ui/results.tscn", 1.0)
	await _snap("13_results")
	await _show("res://game/scenes/ui/slot_select.tscn", 1.0)
	await _snap("20_slot_select")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		printerr("capture: the window was asked to close (t=%.1fs); stopping." % (Time.get_ticks_msec() / 1000.0))
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		printerr("capture: window lost focus (t=%.1fs)" % (Time.get_ticks_msec() / 1000.0))
		# The game pauses itself when its window loses focus; the capture carries on.
		_resume_after_focus_loss.call_deferred()


func _resume_after_focus_loss() -> void:
	if world != null and is_instance_valid(world) and world.pause_menu.visible:
		world._close_pause()


func _goto(pos: Vector2, settle: float) -> void:
	printerr("goto %s" % str(pos))
	world.teleport_to(pos)
	printerr("  teleported")
	await _wait(settle)
	printerr("  settled")


## Walks the player in a direction for `seconds`, sampling the frame rate.
func _measure_walk(dir: Vector2, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		world.player.velocity = dir.normalized() * Player.SPEED * Player.RUN_MULTIPLIER
		world.player.move_and_slide()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		_fps_samples.append(Engine.get_frames_per_second())


func _show(path: String, seconds: float) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await _wait(seconds)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _snap(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [out_dir, file_name])
	var err := image.save_png(path)
	print("%s -> %s (t=%.1fs)" % [file_name, "saved" if err == OK else error_string(err), Time.get_ticks_msec() / 1000.0])
