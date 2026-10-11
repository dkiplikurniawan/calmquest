extends "res://tests/test_case.gd"
## Tests for the 0.4.0 relaxation features (P5): rest spot data and placement,
## finding quiet places (and the one cosmetic), the breathing pace timing for
## every preset, Reduce motion, stopping on any input, and that breathing
## stores nothing beyond the chosen pace and length.

const TEST_SETTINGS := "user://test_tmp/rest_settings.cfg"


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func test_rest_spot_data_is_complete() -> void:
	var ids := RestSpots.ids()
	assert_true(ids.size() >= 8 and ids.size() <= 12, "8-12 rest spots (%d)" % ids.size())
	var seen := {}
	var kinds := {}
	for s: Dictionary in RestSpots.all():
		var id := String(s["id"])
		assert_false(seen.has(id), "rest spot ids are unique (%s)" % id)
		seen[id] = true
		kinds[String(s["kind"])] = true
		assert_false(String(s.get("name", "")).is_empty(), "%s has a name" % id)
		assert_false(String(s.get("text", "")).is_empty(), "%s has a short line for the journal" % id)
		assert_true(s.has("pos") != s.has("cave"), "%s is either in the open world or in a cave" % id)
		var v: Array = s.get("view", [0, 0])
		assert_true(Vector2(float(v[0]), float(v[1])).length() > 0.1, "%s has a view direction" % id)
	assert_true(kinds.size() >= 5, "several kinds of seats (%s)" % str(kinds.keys()))
	assert_eq(RestSpots.overworld_spots().size() + RestSpots.cave_spots("cave_grotto").size() + RestSpots.cave_spots("cave_hollow").size(), ids.size(), "every spot is placed somewhere")


func test_open_world_spots_sit_in_open_ground_away_from_scenery() -> void:
	var w := WorldData.load_from()
	var zones: Array = []
	for p in w.pois:
		zones.append([p["pos"], float(p["clear"])])
	var noise := ChunkGenerator.make_noise(w.world_seed)
	for s: Dictionary in RestSpots.overworld_spots():
		var pos := RestSpots.world_pos(s)
		var id := String(s["id"])
		assert_true(w.world_rect().has_point(pos), "%s is on the map" % id)
		assert_false(w.is_blocked_at(pos) or w.is_water_at(pos), "%s is on open, dry ground" % id)
		for k in 8:
			assert_false(w.is_blocked_at(pos + Vector2.from_angle(TAU * k / 8.0) * 50.0), "%s has room around the seat" % id)
		var chunk := w.chunk_of(pos)
		var nearest := INF
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var c := chunk + Vector2i(dx, dy)
				var objects := ChunkGenerator.generate(w, c, zones, noise)
				objects.append_array(ChunkGenerator.generate_features(w, c, zones, noise, objects))
				for o in objects:
					nearest = minf(nearest, pos.distance_to(o["pos"]))
		assert_true(nearest >= 60.0, "%s is clear of generated scenery (%.0f px)" % [id, nearest])


func test_cave_spots_are_on_open_floor() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/caves/caves.json"))
	var caves := {}
	for c: Dictionary in data["caves"]:
		caves[String(c["id"])] = c
	for s: Dictionary in RestSpots.all():
		if not s.has("cave"):
			continue
		assert_true(caves.has(String(s["cave"])), "%s is in a real cave" % s["id"])
		var cave: Dictionary = caves[String(s["cave"])]
		var rows: Array = cave["rows"]
		var cell: Array = s["cell"]
		assert_eq(String(rows[int(cell[1])])[int(cell[0])], ".", "%s sits on open cave floor" % s["id"])


func test_finding_quiet_places_and_the_single_cosmetic() -> void:
	var state := GameState.system_state(RestSpots.STATE_KEY)
	var saved := state.duplicate(true)
	var cosmetics_unlocked: Dictionary = GameState.system_state("cosmetics").get("unlocked", {}).duplicate()
	state.clear()
	var first := RestSpots.ids()[0]
	assert_false(RestSpots.is_found(first))
	assert_true(RestSpots.mark_found(first), "a quiet place is found once")
	assert_false(RestSpots.mark_found(first), "and not twice")
	assert_false(RestSpots.mark_found("no_such_place"), "unknown places are ignored")
	assert_eq(RestSpots.found_ids(), PackedStringArray([first]))
	assert_false(Cosmetics.is_unlocked(RestSpots.ALL_FOUND_COSMETIC), "no reward for a single place")
	for id in RestSpots.ids():
		RestSpots.mark_found(id)
	assert_true(RestSpots.all_found())
	assert_true(Cosmetics.is_unlocked(RestSpots.ALL_FOUND_COSMETIC), "finding every quiet place unlocks the dusk glow (cosmetic only)")
	state.clear()
	state.merge(saved)
	var cs := GameState.system_state("cosmetics")
	if cs.has("unlocked"):
		cs["unlocked"] = cosmetics_unlocked


func test_breathing_follows_each_pace() -> void:
	# Gentle 4 in / 6 out, Even 4 / 4, Slow 5 / 7.
	var expected := [[4.0, 6.0], [4.0, 4.0], [5.0, 7.0]]
	for i in BreathePanel.PACES.size():
		var inhale: float = expected[i][0]
		var exhale: float = expected[i][1]
		assert_eq(float(BreathePanel.PACES[i]["in"]), inhale, "pace %d breathes in for %d s" % [i, int(inhale)])
		assert_eq(float(BreathePanel.PACES[i]["out"]), exhale, "pace %d breathes out for %d s" % [i, int(exhale)])
		var at_start := BreathePanel.phase_at(0.01, i)
		assert_true(bool(at_start["inhale"]) and float(at_start["amount"]) < 0.05, "each breath starts by breathing in")
		var mid_in := BreathePanel.phase_at(inhale * 0.5, i)
		assert_true(bool(mid_in["inhale"]) and absf(float(mid_in["progress"]) - 0.5) < 0.01)
		var top := BreathePanel.phase_at(inhale - 0.01, i)
		assert_true(float(top["amount"]) > 0.99, "the glow is fullest at the top of the breath")
		var out := BreathePanel.phase_at(inhale + 0.01, i)
		assert_false(bool(out["inhale"]), "then breathing out for pace %d" % i)
		var mid_out := BreathePanel.phase_at(inhale + exhale * 0.5, i)
		assert_true(absf(float(mid_out["progress"]) - 0.5) < 0.01)
		var next := BreathePanel.phase_at(inhale + exhale + 0.01, i)
		assert_true(bool(next["inhale"]), "and the next breath begins after %d s" % int(inhale + exhale))


func test_glow_size_and_reduce_motion() -> void:
	assert_true(BreathePanel.glow_radius(1.0, false) > BreathePanel.glow_radius(0.0, false), "the glow grows while breathing in")
	assert_eq(BreathePanel.glow_radius(0.0, true), BreathePanel.glow_radius(1.0, true), "with Reduce motion the glow keeps its size")
	assert_eq(BreathePanel.LENGTHS, [1, 2, 3, 0] as Array[int], "1, 2 or 3 minutes, or until stopped")


func test_breathing_stops_on_any_input_and_stores_nothing() -> void:
	var old_path := GameSettings.settings_path
	GameSettings.settings_path = TEST_SETTINGS
	var journal_before := FileAccess.file_exists(Wellbeing.JOURNAL_PATH)
	var events_before := FileAccess.file_exists(StudyMode.EVENTS_PATH)
	var sessions_before := FileAccess.get_modified_time(SessionStorage.DEFAULT_PATH) if FileAccess.file_exists(SessionStorage.DEFAULT_PATH) else 0
	for stopper in [_key(KEY_SPACE), _click(), _joy(JOY_BUTTON_B)]:
		var panel := BreathePanel.new()
		_root().add_child(panel)
		panel.setup()
		var closed := [false]
		panel.closed.connect(func() -> void: closed[0] = true)
		panel.pace_index = 2
		panel.length_index = 0
		panel.begin_breathing()
		assert_true(panel.running, "breathing begins")
		panel._process(BreathePanel.SETTLE_SECONDS + 0.1)
		panel._process(3.0)
		assert_true(panel.elapsed > 2.9 and panel.running, "and keeps going on its own")
		panel._input(stopper)
		assert_true(closed[0], "any input stops it at once (%s)" % stopper.get_class())
		assert_false(panel.running)
		panel.free()
	assert_eq(GameSettings.breathe_pace, 2, "the chosen pace is remembered as a preference")
	assert_eq(FileAccess.file_exists(Wellbeing.JOURNAL_PATH), journal_before, "breathing writes no journal")
	assert_eq(FileAccess.file_exists(StudyMode.EVENTS_PATH), events_before, "outside Study Mode, no study events are written")
	var sessions_after := FileAccess.get_modified_time(SessionStorage.DEFAULT_PATH) if FileAccess.file_exists(SessionStorage.DEFAULT_PATH) else 0
	assert_eq(sessions_after, sessions_before, "and the research data is untouched")
	GameSettings.settings_path = old_path
	GameSettings.breathe_pace = 0
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func test_breathing_ends_by_itself_after_the_chosen_length() -> void:
	var old_path := GameSettings.settings_path
	GameSettings.settings_path = TEST_SETTINGS
	var panel := BreathePanel.new()
	_root().add_child(panel)
	panel.setup()
	var closed := [false]
	panel.closed.connect(func() -> void: closed[0] = true)
	panel.length_index = 0
	panel.begin_breathing()
	panel._process(BreathePanel.SETTLE_SECONDS + 0.1)
	for i in 61:
		panel._process(1.0)
	assert_true(panel.finished, "a one-minute session finishes after a minute")
	panel._process(BreathePanel.SETTLE_SECONDS + 0.1)
	assert_true(closed[0], "and then quietly closes, with no score or summary")
	if is_instance_valid(panel) and not panel.is_queued_for_deletion():
		panel.free()
	var endless := BreathePanel.new()
	_root().add_child(endless)
	endless.setup()
	endless.length_index = 3
	endless.begin_breathing()
	endless._process(BreathePanel.SETTLE_SECONDS + 0.1)
	for i in 400:
		endless._process(1.0)
	assert_true(endless.running and not endless.finished, "\"Until I stop\" keeps going")
	endless.free()
	GameSettings.settings_path = old_path
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e
