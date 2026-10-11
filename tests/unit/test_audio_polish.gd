extends "res://tests/test_case.gd"
## Tests for the 0.4.0 audio pass (P3): rendered music is preferred over the
## placeholders (with one warning on fallback), footstep surfaces, the
## footstep setting, pitch variation bounds, gentle SFX levels, and no errors
## when audio files are missing.

const TEST_SETTINGS := "user://test_tmp/audio_polish_settings.cfg"


func test_rendered_music_is_preferred_and_placeholders_are_the_fallback() -> void:
	var mm := MusicManager
	var old_dir := mm.rendered_dir
	var old_warn := mm.placeholder_warnings
	assert_false(mm.is_rendered("grove"), "no rendered recordings are shipped yet (honest default)")
	# Point the rendered folder at a folder that has some pieces, to show the preference.
	mm.rendered_dir = MusicManager.AMBIENCE_DIR
	assert_true(mm.music_path("rain").begins_with(MusicManager.AMBIENCE_DIR), "a rendered file wins when present")
	assert_true(mm.is_rendered("rain"))
	var rendered := mm.load_music("rain") as AudioStreamWAV
	assert_not_null(rendered, "the rendered file loads")
	assert_eq(rendered.loop_mode, AudioStreamWAV.LOOP_FORWARD, "and loops")
	assert_eq(mm.music_path("grove"), "%s/grove.wav" % MusicManager.MUSIC_DIR, "otherwise the placeholder")
	mm.placeholder_warnings = 0
	assert_not_null(mm.load_music("grove"), "the placeholder loads")
	mm.load_music("creek")
	mm.load_music("coast")
	assert_eq(mm.placeholder_warnings, 1, "the fallback warns once, not for every piece")
	assert_null(mm.load_music("no_such_piece"), "a missing piece is skipped without an error")
	mm.rendered_dir = old_dir
	mm.placeholder_warnings = old_warn


func test_footstep_surface_rules() -> void:
	assert_eq(Footsteps.surface_for("whispering_meadow", "", false, false), "grass")
	assert_eq(Footsteps.surface_for("whispering_meadow", "", true, false), "path")
	assert_eq(Footsteps.surface_for("crystal_creek", "", true, true), "wood", "bridges and docks are wood")
	assert_eq(Footsteps.surface_for("sunpetal_coast", "", false, false), "sand")
	assert_eq(Footsteps.surface_for("sunpetal_isles", "", true, false), "sand", "coast paths are sandy too")
	assert_eq(Footsteps.surface_for("frostbloom_highlands", "", true, false), "snow")
	assert_eq(Footsteps.surface_for("", "cottage", false, false), "wood", "the cottage floor")
	assert_eq(Footsteps.surface_for("", "cave_hollow", false, false), "stone", "caves")
	assert_eq(Footsteps.surface_for("", "cave_grotto", true, true), "stone")


func test_footstep_surfaces_in_the_real_world() -> void:
	var world := WorldData.load_from()
	var crossing: Vector2 = world.rivers[0]["crossings"][0]["pos"]
	assert_eq(Footsteps.surface_at(world, crossing, ""), "wood", "on a bridge")
	var dock: Vector2 = world.pois_of_kind("dock")[0]["pos"]
	assert_eq(Footsteps.surface_at(world, dock, ""), "wood", "on a dock")
	var path_point: Vector2 = world.paths[0]["points"][1]
	if world.region_at(path_point) == "whispering_meadow":
		assert_eq(Footsteps.surface_at(world, path_point, ""), "path", "on a meadow path")
	var found := {}
	var step := world.cell_size
	var y := step * 0.5
	while y < world.world_size().y and found.size() < 3:
		var x := step * 0.5
		while x < world.world_size().x:
			var p := Vector2(x, y)
			var region := world.region_at(p)
			if not world.is_blocked_at(p) and world.distance_to_paths(p) > 80.0 and not world.is_on_crossing(p):
				if region == "whispering_meadow" and not found.has("grass"):
					found["grass"] = Footsteps.surface_at(world, p, "")
				elif region == "frostbloom_highlands" and not found.has("snow"):
					found["snow"] = Footsteps.surface_at(world, p, "")
				elif region == "sunpetal_coast" and not found.has("sand") and Footsteps.surface_at(world, p, "") != "wood":
					found["sand"] = Footsteps.surface_at(world, p, "")
			x += step
		y += step
	for expected: String in ["grass", "snow", "sand"]:
		assert_eq(String(found.get(expected, "")), expected, "%s ground" % expected)
	assert_eq(Footsteps.surface_at(world, crossing, "cottage"), "wood", "inside the cottage")
	assert_eq(Footsteps.surface_at(world, crossing, "cave_hollow"), "stone", "inside a cave")


func test_footstep_setting_persists() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	var old_path := GameSettings.settings_path
	var old := GameSettings.footsteps
	GameSettings.settings_path = TEST_SETTINGS
	GameSettings.set_setting("footsteps", false)
	GameSettings.footsteps = true
	GameSettings.load_settings()
	assert_false(GameSettings.footsteps, "Footsteps: Off is kept")
	GameSettings.footsteps = old
	GameSettings.settings_path = old_path
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func test_pitch_variation_stays_within_bounds() -> void:
	assert_almost(AudioManager.varied_pitch(1.0, 0.0), 0.96)
	assert_almost(AudioManager.varied_pitch(1.0, 1.0), 1.04)
	assert_almost(AudioManager.varied_pitch(1.0, 0.5), 1.0)
	assert_almost(AudioManager.varied_pitch(1.2, 1.0), 1.248)
	assert_almost(AudioManager.varied_pitch(1.0, 7.0), 1.04, "out-of-range input is clamped")
	var seen := {}
	for i in 60:
		AudioManager.play(&"gather")
		var p := AudioManager.last_pitch
		assert_true(p >= 0.96 - 0.0001 and p <= 1.04 + 0.0001, "pitch %.3f within +-4%%" % p)
		seen[snappedf(p, 0.001)] = true
	assert_true(seen.size() > 10, "repeats really vary")


func test_effects_are_soft_and_gentle() -> void:
	var lib := SoundSynth.build_library()
	for name in [&"gather", &"craft", &"cook", &"place", &"quest_step", &"splash", &"catch", &"discover", &"restore", &"collect", &"swell"]:
		assert_true(lib.has(name), "sound %s exists" % name)
	for key: StringName in lib:
		var s: PackedFloat32Array = lib[key]
		var peak := SoundSynth.peak(s)
		assert_true(peak > 0.0005 and peak <= 0.5, "%s is audible but never loud (peak %.3f)" % [key, peak])
		# No harsh transient: the first 2 ms stay well under the sound's own peak.
		var head := 0.0
		for i in mini(s.size(), int(0.002 * SoundSynth.SFX_RATE)):
			head = maxf(head, absf(s[i]))
		assert_true(head <= peak * 0.6, "%s starts softly" % key)
	for surface in SoundSynth.SURFACES:
		for v in [1, 2]:
			var step: PackedFloat32Array = lib[StringName("step_%s_%d" % [surface, v])]
			assert_true(SoundSynth.peak(step) <= 0.2, "footsteps are quiet (%s %d)" % [surface, v])
			assert_true(step.size() <= int(0.15 * SoundSynth.SFX_RATE), "footsteps are short (%s)" % surface)
	assert_true(SoundSynth.peak(lib[&"ui_hover"]) <= 0.06, "UI hover is very quiet")


func test_missing_audio_never_errors() -> void:
	AudioManager.play(&"no_such_sound")
	AudioManager.play_footstep("lava")
	assert_true(AudioManager.has_sound(&"step_grass_1"), "an unknown surface falls back to grass")
	assert_null(MusicManager.load_loop(MusicManager.MUSIC_DIR, "no_such_piece"), "missing music is skipped")


func assert_almost(actual: float, expected: float, message: String = "") -> void:
	assert_true(absf(actual - expected) < 0.0001, "%s expected %.4f got %.4f" % [message, expected, actual])
