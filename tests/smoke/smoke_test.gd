extends Node
## Integration smoke test: loads the real overworld with autoloads and plays the
## V1 core loop (now the Whispering Meadow region) programmatically.
## V2 note: the meadow became one region of the open world, so objects are
## reached through world.meadow, and reachability is checked over the whole
## world with every chunk loaded (the checks themselves are unchanged).
##
## Run:  godot --headless --path . res://tests/smoke/smoke_test.tscn
## Exit code 0 = all checks passed, 1 = failures (listed in the output).
##
## It redirects SessionState's storage and journal files to user://test_tmp/ so
## a real player's data is never touched.

const OVERWORLD := preload("res://game/scenes/world/overworld.tscn")
const GRID := 32.0
const PLAYER_RADIUS := 11.0
const PLAYER_SHAPE_OFFSET := Vector2(0, -6)
const TEST_DIR := "user://test_tmp"
const TEST_CSV := "user://test_tmp/smoke_sessions.csv"
const TEST_PROGRESS := "user://test_tmp/smoke_progress.cfg"

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for p in [TEST_CSV, TEST_PROGRESS]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var real_storage := SessionState.storage
	var real_progress := SessionState.progress
	SessionState.storage = SessionStorage.new(TEST_CSV)
	SessionState.progress = ProgressStore.new(TEST_PROGRESS)

	await _run()

	SessionState.storage = real_storage
	SessionState.progress = real_progress
	get_tree().paused = false
	print("")
	print("Smoke test: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		printerr("FAILED: ", f)
	# Let one-shot sounds finish so the audio server releases its playbacks.
	await get_tree().create_timer(3.0).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	# --- Check-in -> session -------------------------------------------------------
	SessionState.begin_session(8, AdaptiveComfortEngine.MODE_GENTLE, true)
	check(SessionState.recommended_mode == "gentle", "score 8 records Gentle as the recommendation")
	check(SessionState.get_config().mode_id == AdaptiveComfortEngine.MODE_GENTLE, "selected mode applied")

	world = OVERWORLD.instantiate()
	add_child(world)
	# Ambient creatures wander; keep them out of the scripted interaction checks.
	world.features.wildlife.enabled = false
	for i in 3:
		await get_tree().physics_frame

	var player := world.player
	check(world.meadow.motes.size() == SessionState.TOTAL_MEADOW_LIGHTS, "12 light motes spawned")
	check(SessionState.TOTAL_MEADOW_LIGHTS >= SessionState.LIGHTS_FOR_HEART_TREE + SessionState.GARDEN_BED_COUNT, "enough lights exist for tree + all beds")
	check(world.meadow.prisms.size() == 3, "3 prism motes spawned")
	check(_visible_prisms() == 0, "no bonus prisms visible in Gentle")
	check(is_equal_approx(player.interaction_radius, 104.0), "Gentle reach radius applied to player")

	world.streamer.load_all()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_reachability(player, true)
	world.story.moon_gate.open_gate(true)
	world.features.open_mountain_path()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_reachability(player, false)
	GameState.set_flag("highlands_path_open", false)
	world.features.path_barrier.sync()
	GameState.set_flag("creek_awakened", false)

	# --- Reach is limited ---------------------------------------------------------------
	var first: LightMote = world.meadow.motes[0]
	player.global_position = first.global_position + Vector2(400, 0)
	player.update_target()
	check(player.current_target != first, "cannot target a light from far away")
	check(not player.try_interact() or player.current_target != first, "far interaction does not collect")
	check(SessionState.lights_collected == 0, "nothing collected from a distance")

	# --- Collect 8 lights, verify no double counting -----------------------------------
	var ids := MeadowLayout.LIGHTS.keys()
	for i in SessionState.LIGHTS_FOR_HEART_TREE:
		_collect_light(player, ids[i])
	check(SessionState.lights_collected == 8, "8 lights collected")
	var dup := _find_mote(ids[0])
	check(dup == null or not dup.can_interact(), "collected mote cannot be interacted with again")
	check(not SessionState.collect_item(ids[0], SessionState.KIND_LIGHT), "SessionState rejects a duplicate collection")
	check(SessionState.lights_collected == 8, "count unchanged after duplicate attempt")

	# --- Restore the Heart Tree -------------------------------------------------------------
	check(SessionState.can_restore_heart_tree(), "tree restorable with 8 light")
	_interact_with(player, world.meadow.heart_tree)
	check(SessionState.heart_tree_restored, "Heart Tree restored through interaction")
	check(world.meadow.heart_tree.restored, "Heart Tree visual state changed")
	check(SessionState.light_balance == 0, "8 light spent")

	# --- Mode switching keeps progress and never duplicates ------------------------------------
	var interactables_before := get_tree().get_nodes_in_group(Interactable.GROUP).size()
	SessionState.select_mode(AdaptiveComfortEngine.MODE_PLAYFUL)
	await get_tree().process_frame
	check(_visible_prisms() == 3, "Playful shows 3 bonus prisms")
	check(is_equal_approx(player.interaction_radius, 64.0), "Playful reach applied")
	check(SessionState.lights_collected == 8 and SessionState.heart_tree_restored, "progress kept after mode switch")
	SessionState.select_mode(AdaptiveComfortEngine.MODE_BALANCED)
	SessionState.select_mode(AdaptiveComfortEngine.MODE_PLAYFUL)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group(Interactable.GROUP).size() == interactables_before, "no objects duplicated by repeated mode switches")
	check(SessionState.engine.get_mode_history().size() == 4, "mode history recorded")

	# --- Remaining lights bloom all garden beds --------------------------------------------------
	for i in range(SessionState.LIGHTS_FOR_HEART_TREE, ids.size()):
		_collect_light(player, ids[i])
	check(SessionState.lights_collected == 12, "all 12 lights collected")
	for bed in world.meadow.beds:
		_interact_with(player, bed)
	check(SessionState.bloomed_beds.size() == 3, "all 3 garden beds bloomed")
	check(is_equal_approx(SessionState.get_restoration_progress(), 1.0), "garden restoration reaches 100%")

	# --- Bonus prism (Playful) --------------------------------------------------------------------
	var prism: LightMote = world.meadow.prisms[0]
	_interact_with(player, prism)
	check(SessionState.bonus_collected == 1, "bonus prism collected in Playful")

	# --- Hidden detail --------------------------------------------------------------------------
	_interact_with(player, world.meadow.details[0])
	check(SessionState.discoveries_this_session.size() == 1, "hidden detail recorded in journal")

	# --- Lantern Catch --------------------------------------------------------------------------
	SessionState.select_mode(AdaptiveComfortEngine.MODE_GENTLE)
	_interact_with(player, world.meadow.shrine)
	check(world.lantern_catch.active, "Lantern Night started at the shrine")
	var lanterns := world.lantern_catch.get_remaining()
	check(lanterns.size() == 6, "Gentle spawns 6 lanterns")
	var max_speed := 0.0
	for l in lanterns:
		max_speed = maxf(max_speed, l._target_speed)
	check(max_speed <= AdaptiveComfortEngine.LANTERN_SPEED_MAX, "lantern speed within the safe bound")
	SessionState.select_mode(AdaptiveComfortEngine.MODE_PLAYFUL)
	check(world.lantern_catch.get_remaining().size() == 6, "mode switch mid-night does not respawn lanterns")
	for l in world.lantern_catch.get_remaining():
		_interact_with(player, l)
	check(not world.lantern_catch.active, "night ends after all lanterns are caught")
	check(SessionState.lantern_nights_this_session == 1, "Lantern Night completion recorded")
	check(SessionState.lanterns_collected == 6, "6 lanterns counted")
	# Replay and end early: no penalty, nothing counted
	_interact_with(player, world.meadow.shrine)
	check(world.lantern_catch.active and world.lantern_catch.target_count == 10, "replay works (Playful: 10 lanterns)")
	_interact_with(player, world.meadow.shrine)
	check(not world.lantern_catch.active, "night can be ended early at the shrine")
	check(SessionState.lantern_nights_this_session == 1, "ending early is not counted as completion")

	# --- Hints and reach help -------------------------------------------------------------------
	var hints_before := SessionState.engine.hints_used
	world._request_hint()
	check(SessionState.engine.hints_used == hints_before + 1, "hint request counted")

	# --- Pause ---------------------------------------------------------------------------------
	await get_tree().create_timer(0.1).timeout
	if world._modal_open:
		world._close_completion()
	world._open_pause()
	check(get_tree().paused, "pause menu pauses the tree")
	world._close_pause()
	check(not get_tree().paused, "resume unpauses")

	# --- Finish, reflect and store (consent given) ------------------------------------------------
	var items := SessionState.get_items_collected()
	SessionState.end_gameplay()
	SessionState.set_reflection(5, 4)
	var result := SessionState.finalize_and_save(true)
	check(result["saved"], "record saved with consent: %s" % result["message"])
	var rows: Array = SessionState.storage.read_rows()["rows"]
	check(rows.size() == 1, "exactly one record written")
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		check(row["pre_stress_score"] == "8" and row["post_stress_score"] == "5", "scores stored")
		check(row["score_delta"] == "-3", "score_delta = post - pre = -3")
		check(row["items_collected"] == str(items), "items_collected stored (%s)" % row["items_collected"])
		check(row["garden_restored"] == "true" and row["completed"] == "true", "flags stored")
		check(row["selected_mode"] == "gentle" and row["final_mode"] == "playful", "modes stored")
		check(row["experience_rating"] == "4", "rating stored")
	check(SessionState.finalize_and_save(true)["saved"] and SessionState.storage.count_records() == 1, "finalizing twice does not write twice")

	# --- No consent: nothing stored; skipped answers stay missing --------------------------------
	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, false)
	check(SessionState.recommended_mode == "", "skipped check-in has no recommendation recorded")
	SessionState.set_reflection(null, null)
	var declined := SessionState.finalize_and_save(true)
	check(not declined["saved"], "declined consent: not saved")
	check(SessionState.storage.count_records() == 1, "declined consent wrote nothing")

	# --- Consent + skipped answers: empty cells, never zero ---------------------------------------
	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, true)
	SessionState.finalize_and_save(false)
	var rows2: Array = SessionState.storage.read_rows()["rows"]
	check(rows2.size() == 2, "incomplete session stored with consent")
	if rows2.size() == 2:
		var r2: Dictionary = rows2[1]
		check(r2["pre_stress_score"] == "" and r2["post_stress_score"] == "" and r2["score_delta"] == "", "missing answers stay empty")
		check(r2["completed"] == "false", "abandoned session marked incomplete")

	# --- Restart clears progress -----------------------------------------------------------------
	SessionState.begin_session(3, AdaptiveComfortEngine.MODE_BALANCED, false)
	SessionState.collect_item("light_01", SessionState.KIND_LIGHT)
	SessionState.restart_gameplay()
	check(SessionState.lights_collected == 0 and SessionState.collected_ids.is_empty(), "restart clears collected state")
	check(SessionState.pre_stress_score == 3, "restart keeps check-in answer")

	world.queue_free()
	await get_tree().process_frame


func _visible_prisms() -> int:
	var n := 0
	for p in world.meadow.prisms:
		if is_instance_valid(p) and p.visible and not p.collected:
			n += 1
	return n


func _find_mote(id: String) -> LightMote:
	for m in world.meadow.motes:
		if is_instance_valid(m) and m.interactable_id == id:
			return m
	return null


func _collect_light(player: Player, id: String) -> void:
	var mote := _find_mote(id)
	if mote == null:
		check(false, "mote %s exists" % id)
		return
	_interact_with(player, mote)


## Places the player right next to the target and presses interact.
func _interact_with(player: Player, target: Interactable) -> void:
	player.global_position = target.get_interaction_point() + Vector2(0, 8)
	player.update_target()
	if player.current_target != target:
		# Another object may be closer; step slightly to the other side.
		player.global_position = target.get_interaction_point() + Vector2(0, -8)
		player.update_target()
	check(player.current_target == target, "can target %s" % target.interactable_id)
	player.try_interact()


func _flood(seeds: Array, free: Dictionary, reached: Dictionary) -> void:
	var queue: Array[Vector2i] = []
	for sd: Vector2i in seeds:
		reached[sd] = true
		queue.append(sd)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if free.has(n) and not reached.has(n):
				reached[n] = true
				queue.append(n)


func _near_reached(target: Vector2, limit: float, free: Dictionary, reached: Dictionary) -> bool:
	var center := Vector2i((target / GRID).floor())
	var r := ceili(limit / GRID) + 1
	for y in range(center.y - r, center.y + r + 1):
		for x in range(center.x - r, center.x + r + 1):
			var cell := Vector2i(x, y)
			if reached.has(cell) and (free[cell] as Vector2).distance_to(target) <= limit:
				return true
	return false


## Flood fill over the whole world using the player's real collision shape.
## Every interactable must have a reachable spot within the smallest reach
## radius. While the moonlit veil is closed, the sanctuary must NOT be reachable.
func _check_reachability(player: Player, veil_closed: bool) -> void:
	var space := world.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = PLAYER_RADIUS
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.exclude = [player.get_rid()]
	var area := world.world.world_rect()
	var cols := int(area.size.x / GRID)
	var rows := int(area.size.y / GRID)
	var free := {}
	for cy in rows:
		for cx in cols:
			var pos := Vector2(cx + 0.5, cy + 0.5) * GRID
			if world.world.is_blocked_at(pos):
				continue
			params.transform = Transform2D(0.0, pos + PLAYER_SHAPE_OFFSET)
			if space.intersect_shape(params, 1).is_empty():
				free[Vector2i(cx, cy)] = pos
	var start := Vector2i((world.world.player_spawn / GRID).floor())
	check(free.has(start), "player spawn is on free ground")
	var reached := {}
	var min_radius := AdaptiveComfortEngine.build_preset(AdaptiveComfortEngine.MODE_PLAYFUL).interaction_radius
	_flood([start], free, reached)
	# The isles are reached by boat (V2 M6): a dock whose base is reachable
	# connects to its paired dock's landing spot, so flooding continues there.
	var sailed := {}
	var grew := true
	while grew:
		grew = false
		for node in get_tree().get_nodes_in_group(Interactable.GROUP):
			var dock := node as BoatDock
			if dock == null or sailed.has(dock.dock_id) or not _near_reached(dock.get_interaction_point(), min_radius + dock.reach_bonus, free, reached):
				continue
			sailed[dock.dock_id] = true
			var dest: BoatDock = world.features.docks.get(dock.dest_id)
			var landing := Vector2i((dest.arrival_point() / GRID).floor())
			check(free.has(landing), "boat landing for %s is on free ground" % dest.dock_id)
			if free.has(landing) and not reached.has(landing):
				_flood([landing], free, reached)
				grew = true
	print("  info reachable cells: %d of %d free (veil %s, %d docks used)" % [reached.size(), free.size(), "closed" if veil_closed else "open", sailed.size()])
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if it is Lantern:
			continue
		# Gatherables are optional, regrowing resources. Sanctuary ones are skipped
		# (as before); highland ones are checked once the mountain path is open (M10).
		if it is Gatherable and (world.world.region_at(it.global_position) == "moonlit_sanctuary" or (veil_closed and world.world.region_at(it.global_position) == "frostbloom_highlands")):
			continue
		# Ambient creatures wander and are optional; a lost kit is hidden inside its
		# gloom (behind thorns) until the gloom is cleared. overworld_test.gd checks
		# that the kit becomes reachable once its gloom is gone.
		if it is Creature or (it is LostKit and not (it as LostKit).is_revealed()):
			continue
		# The forgotten garden's chest sits behind a withered plant until it is
		# watered (M7); overworld_test.gd checks it can be reached afterwards.
		if it is WitheredGarden.GardenChest and not WitheredGarden.is_revived((it as WitheredGarden.GardenChest).garden.garden_id):
			continue
		var target := it.get_interaction_point()
		# Interiors and caves are sub-levels outside the map, entered via doors;
		# they have their own reachability check in overworld_test.gd.
		if not world.world.world_rect().has_point(target):
			continue
		var limit := min_radius + it.reach_bonus
		var best := INF
		var center := Vector2i((target / GRID).floor())
		var r := ceili(limit / GRID) + 1
		for y in range(center.y - r, center.y + r + 1):
			for x in range(center.x - r, center.x + r + 1):
				var cell := Vector2i(x, y)
				if reached.has(cell):
					best = minf(best, (free[cell] as Vector2).distance_to(target) - it.reach_bonus)
		var in_sanctuary := world.world.region_at(target) == "moonlit_sanctuary" and not (it is MoonGate)
		# The highlands stay closed until the mountain path is restored (M10).
		var in_highlands := world.world.region_at(target) == "frostbloom_highlands"
		if veil_closed and in_highlands:
			check(best > min_radius, "mountain path closed: %s not reachable yet" % it.interactable_id)
		elif veil_closed and in_sanctuary:
			check(best > min_radius, "veil closed: %s not reachable yet" % it.interactable_id)
		elif not veil_closed or not in_sanctuary:
			check(best <= min_radius, "reachable: %s (closest free spot %.0f px)" % [it.interactable_id, best])
