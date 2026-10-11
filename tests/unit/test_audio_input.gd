extends "res://tests/test_case.gd"
## Tests for M11: music cue selection and hysteresis, missing-file fallback,
## adaptive meadow layers, audio settings persistence, hint frequency, gamepad
## bindings, key remapping, the Playful puzzle bonus and mode-based creature
## shyness. Settings are written to a temporary file, never the player's own.

const TEST_SETTINGS := "user://test_tmp/unit_settings.cfg"


func _redirect_settings() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	var old := GameSettings.settings_path
	GameSettings.settings_path = TEST_SETTINGS
	return old


func test_cue_selection_for_places_and_times() -> void:
	assert_eq(MusicManager.cue_for("whispering_meadow", "", false), "meadow")
	assert_eq(MusicManager.cue_for("misty_pinewood", "", false), "pinewood")
	assert_eq(MusicManager.cue_for("sunpetal_isles", "", false), "coast", "the isles share the coast's music")
	assert_eq(MusicManager.cue_for("misty_pinewood", "cottage", false), "cottage", "interiors have their own cue")
	assert_eq(MusicManager.cue_for("misty_pinewood", "cave_hollow", false), "caves")
	assert_eq(MusicManager.cue_for("whispering_meadow", "", true), "finale", "the finale wins")
	assert_eq(MusicManager.cue_for("open_sea", "", false), "", "boundary regions keep the current music")
	assert_eq(MusicManager.ambience_for("whispering_meadow", "", false), "meadow_birds", "birds by day")
	assert_eq(MusicManager.ambience_for("whispering_meadow", "", true), "night_insects", "insects at night")
	assert_eq(MusicManager.ambience_for("x", "cave_grotto", false), "cave_drips")
	assert_eq(MusicManager.ambience_for("x", "cottage", false), "", "quiet indoors")


func test_every_cue_and_ambience_file_exists() -> void:
	var cues: Array = MusicManager.REGION_CUES.values() + ["lumeria_theme", "cottage", "caves", "finale", "stinger_restore"]
	for cue: String in cues:
		if cue == MusicManager.MEADOW:
			for layer in MusicManager.MEADOW_LAYERS:
				assert_true(ResourceLoader.exists("%s/%s.wav" % [MusicManager.MUSIC_DIR, layer]), "meadow layer %s exists" % layer)
		else:
			assert_true(ResourceLoader.exists("%s/%s.wav" % [MusicManager.MUSIC_DIR, cue]), "music %s exists" % cue)
	for amb: String in MusicManager.DAY_AMBIENCE.values() + MusicManager.NIGHT_AMBIENCE.values() + ["cave_drips", "rain"]:
		assert_true(ResourceLoader.exists("%s/%s.wav" % [MusicManager.AMBIENCE_DIR, amb]), "ambience %s exists" % amb)


func test_loops_are_set_to_loop() -> void:
	var s := MusicManager.load_loop(MusicManager.MUSIC_DIR, "grove") as AudioStreamWAV
	assert_not_null(s, "the grove loop loads")
	assert_eq(s.loop_mode, AudioStreamWAV.LOOP_FORWARD, "it loops")
	assert_true(s.loop_end > s.mix_rate * 10, "over the whole piece")
	var once := MusicManager.load_loop(MusicManager.MUSIC_DIR, "grove", false) as AudioStreamWAV
	assert_eq(once.loop_mode, AudioStreamWAV.LOOP_DISABLED, "the quiet-pauses version plays once")


func test_no_restart_and_hysteresis_on_border_crossing() -> void:
	var mm := MusicManager
	mm.request_cue("grove", true)
	assert_eq(mm.current_cue, "grove")
	mm.request_cue("creek")
	assert_eq(mm.current_cue, "grove", "a new place waits a moment before the music changes")
	mm._process(0.5)
	mm.request_cue("grove")
	mm._process(MusicManager.HYSTERESIS + 0.1)
	assert_eq(mm.current_cue, "grove", "stepping back across the border never restarts the music")
	mm.request_cue("creek")
	mm._process(MusicManager.HYSTERESIS + 0.1)
	assert_eq(mm.current_cue, "creek", "staying in the new place changes the music")
	var before := mm.current_cue
	mm.request_cue("creek")
	assert_eq(mm.current_cue, before, "the same cue is never restarted")


func test_missing_music_falls_back_gracefully() -> void:
	var mm := MusicManager
	assert_null(mm.load_loop(MusicManager.MUSIC_DIR, "no_such_piece"), "a missing file is just skipped")
	mm._switch_to("no_such_piece")
	assert_true(mm.fallback_active, "the original synthesized pad steps in")
	mm._switch_to("grove")
	assert_false(mm.fallback_active, "and steps out again when music is back")


func test_meadow_has_adaptive_layers() -> void:
	var mm := MusicManager
	var s := mm.music_stream("meadow") as AudioStreamSynchronized
	assert_not_null(s, "the meadow plays synchronized layers")
	assert_eq(s.stream_count, 3, "base, day and night layers")
	mm.night = 0.0
	mm._apply_meadow_layers()
	assert_true(s.get_sync_stream_volume(1) > s.get_sync_stream_volume(2), "by day the flute layer leads")
	mm.night = 1.0
	mm._apply_meadow_layers()
	assert_true(s.get_sync_stream_volume(2) > s.get_sync_stream_volume(1), "at night the piano layer leads")


func test_audio_settings_persist() -> void:
	var old := _redirect_settings()
	GameSettings.set_setting("music_volume", 0.35)
	GameSettings.set_setting("ambience_volume", 0.25)
	GameSettings.set_setting("music_mode", 1)
	GameSettings.music_volume = 0.9
	GameSettings.ambience_volume = 0.9
	GameSettings.music_mode = 0
	GameSettings.load_settings()
	assert_eq(GameSettings.music_volume, 0.35, "music volume persists")
	assert_eq(GameSettings.ambience_volume, 0.25, "ambience volume persists")
	assert_eq(GameSettings.music_mode, 1, "music mode persists")
	var idx := AudioServer.get_bus_index(AudioManager.AMBIENCE_BUS)
	assert_true(idx >= 0 and AudioServer.get_bus_index(AudioManager.UI_BUS) >= 0, "Ambience and UI buses exist")
	GameSettings.set_setting("music_mode", 2)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(AudioManager.MUSIC_BUS)), "music off mutes the music bus")
	GameSettings.set_setting("music_mode", 0)
	GameSettings.set_setting("music_volume", 0.5)
	GameSettings.set_setting("ambience_volume", 0.6)
	GameSettings.settings_path = old


func test_hint_frequency_follows_mode_unless_chosen() -> void:
	var old := _redirect_settings()
	GameSettings.set_setting("hint_frequency", -1)
	assert_eq(GameSettings.effective_hint_frequency(&"gentle"), 3, "Gentle: helpful")
	assert_eq(GameSettings.effective_hint_frequency(&"balanced"), 2, "Balanced: normal")
	assert_eq(GameSettings.effective_hint_frequency(&"playful"), 1, "Playful: rare")
	GameSettings.set_setting("hint_frequency", 0)
	assert_eq(GameSettings.effective_hint_frequency(&"gentle"), 0, "the player's choice wins")
	GameSettings.set_setting("hint_frequency", -1)
	GameSettings.settings_path = old


func test_gamepad_bindings_cover_core_actions() -> void:
	for action in [InputSetup.INTERACT, InputSetup.PAUSE, InputSetup.HINT, InputSetup.JOURNAL, InputSetup.INVENTORY, InputSetup.RUN, InputSetup.MAP]:
		var has_pad := false
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadButton:
				has_pad = true
		assert_true(has_pad, "%s has a gamepad button" % action)
	for action in [InputSetup.MOVE_LEFT, InputSetup.MOVE_RIGHT, InputSetup.MOVE_UP, InputSetup.MOVE_DOWN]:
		var has_axis := false
		for e in InputMap.action_get_events(action):
			if e is InputEventJoypadMotion:
				has_axis = true
		assert_true(has_axis, "%s works with the left stick" % action)


func test_key_remapping_applies_persists_and_resets() -> void:
	var old := _redirect_settings()
	assert_eq(InputSetup.primary_key(InputSetup.INTERACT), KEY_E, "E interacts by default")
	var clash := GameSettings.rebind(InputSetup.INTERACT, KEY_G)
	assert_eq(clash, "", "G is free")
	assert_eq(InputSetup.primary_key(InputSetup.INTERACT), KEY_G, "G interacts now")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_G
	press.pressed = true
	assert_true(press.is_action_pressed(InputSetup.INTERACT), "pressing G triggers interact")
	assert_true(GameSettings.rebind(InputSetup.HINT, KEY_G).contains("Interact"), "a clash is reported")
	GameSettings.key_bindings = {}
	GameSettings.load_settings()
	assert_eq(int(GameSettings.key_bindings.get(String(InputSetup.INTERACT), 0)), KEY_G, "the binding is saved")
	GameSettings.reset_bindings()
	assert_eq(InputSetup.primary_key(InputSetup.INTERACT), KEY_E, "reset restores E")
	assert_eq(InputSetup.primary_key(InputSetup.HINT), KEY_H, "and H")
	GameSettings.settings_path = old


func test_playful_bonus_is_praise_only() -> void:
	GameState.reset_world(Vector2(10240, 6144))
	SessionState.select_mode(&"balanced", AdaptiveComfortEngine.REASON_PLAYER_CHOICE)
	assert_eq(PuzzleBonus.report("p", 3, 3), "", "no bonus talk outside Playful")
	SessionState.select_mode(&"playful", AdaptiveComfortEngine.REASON_PLAYER_CHOICE)
	assert_true(PuzzleBonus.report("p", 3, 3).contains("perfect"), "a perfect solve is celebrated")
	assert_true(PuzzleBonus.report("q", 9, 3).contains("can be done"), "otherwise a gentle note, no penalty")
	assert_eq(GameState.counter("bonus_puzzles"), 1)
	assert_true(Creature.mode_shyness() > 1.0, "Playful creatures need a little more calm")
	SessionState.select_mode(&"gentle", AdaptiveComfortEngine.REASON_PLAYER_CHOICE)
	assert_true(Creature.mode_shyness() < 1.0, "Gentle creatures are at ease quickly")
