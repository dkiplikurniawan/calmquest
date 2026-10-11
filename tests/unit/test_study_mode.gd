extends "res://tests/test_case.gd"
## Tests for Study Mode (0.4.0, P1): activation (command line and hidden
## unlock), participant codes, the fresh study journey (identical every time,
## never slots 1-3), the gentle end (never while busy), the study CSV (header,
## participant code, the 16 schema-v1 columns, score_delta), the event log
## (consent only; breathing logs only started and stopped), and that the
## default flow never opens the research layer.
## Every file goes to user://test_tmp/.

const TEST_DIR := "user://test_tmp"
const SAVES := "user://test_tmp/saves_study"
const SETTINGS := "user://test_tmp/study_settings.cfg"
const STUDY_CSV := "user://test_tmp/study_sessions_test.csv"
const EVENTS_CSV := "user://test_tmp/study_events_test.csv"
const SESSIONS_CSV := "user://test_tmp/sessions_for_study_test.csv"


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _save_state() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	for p in [STUDY_CSV, EVENTS_CSV, SESSIONS_CSV]:
		_remove(p)
	var saved := {
		"settings_path": GameSettings.settings_path, "study_mode": GameSettings.study_mode, "language": GameSettings.language,
		"cli": StudyMode.cli_active, "code": StudyMode.participant_code, "minutes": StudyMode.duration_minutes,
		"study_store": StudyMode.sessions_store, "events_store": StudyMode.events_store,
		"save_dir": SaveManager.save_dir, "slot": SaveManager.current_slot, "storage": SessionState.storage,
	}
	GameSettings.settings_path = SETTINGS
	SaveManager.set_save_dir(SAVES)
	StudyMode.sessions_store = CsvFileStore.new(STUDY_CSV, StudyMode.study_header())
	StudyMode.events_store = CsvFileStore.new(EVENTS_CSV, StudyMode.EVENT_COLUMNS)
	SessionState.storage = SessionStorage.new(SESSIONS_CSV)
	return saved


func _restore(saved: Dictionary) -> void:
	StudyMode.session_running = false
	StudyMode.record_pending = false
	StudyMode.fake_elapsed = -1.0
	StudyMode.end_stage = StudyMode.EndStage.PLAYING
	StudyMode.cli_active = saved["cli"]
	StudyMode.participant_code = saved["code"]
	StudyMode.duration_minutes = saved["minutes"]
	StudyMode.sessions_store = saved["study_store"]
	StudyMode.events_store = saved["events_store"]
	GameSettings.study_mode = saved["study_mode"]
	GameSettings.language = saved["language"]
	GameSettings.settings_path = saved["settings_path"]
	SaveManager.save_dir = saved["save_dir"]
	SaveManager.current_slot = saved["slot"]
	SaveManager.reload_current()
	SessionState.storage = saved["storage"]
	SessionState.consent_to_store = false
	L.set_language("en")
	for p in [STUDY_CSV, EVENTS_CSV, SESSIONS_CSV, SETTINGS]:
		_remove(p)


func test_activation_by_command_line_argument() -> void:
	assert_true(StudyMode.parse_args(PackedStringArray(["--study"])), "--study turns it on")
	assert_false(StudyMode.parse_args(PackedStringArray([])), "no argument: off")
	assert_false(StudyMode.parse_args(PackedStringArray(["--studyx", "study"])), "only the exact flag")


func test_hidden_unlock_and_leave() -> void:
	var saved := _save_state()
	StudyMode.cli_active = false
	GameSettings.study_mode = false
	assert_false(StudyMode.is_active(), "off by default")
	assert_false(StudyMode.try_unlock("lumeria"), "a wrong phrase does nothing")
	assert_false(StudyMode.is_active())
	assert_true(StudyMode.try_unlock("  lumeria-study "), "the phrase (any case, spaces trimmed)")
	assert_true(StudyMode.is_active(), "on after the unlock")
	GameSettings.study_mode = false
	GameSettings.load_settings()
	assert_true(GameSettings.study_mode, "the unlock is remembered")
	StudyMode.leave()
	assert_false(StudyMode.is_active(), "Leave Study Mode turns it off")
	_restore(saved)


func test_participant_code_validation() -> void:
	for good in ["P01", "P99", "P123", "p07", " P05 "]:
		assert_true(StudyMode.is_valid_code(good), "valid: '%s'" % good)
	for bad in ["", "P", "P1", "P1234", "X01", "P0A", "01", "PP01", "P-01"]:
		assert_false(StudyMode.is_valid_code(bad), "invalid: '%s'" % bad)
	assert_eq(StudyMode.normalize_code(" p07 "), "P07")


func test_configure_validates_and_sets_language() -> void:
	var saved := _save_state()
	assert_false(StudyMode.configure("P1", 15, "id").is_empty(), "a bad code is refused with a message")
	assert_false(StudyMode.configure("P01", 12, "id").is_empty(), "only 10, 15 or 20 minutes")
	assert_eq(StudyMode.configure("p07", 20, "id"), "", "a good setup")
	assert_eq(StudyMode.participant_code, "P07")
	assert_eq(StudyMode.target_seconds(), 1200)
	assert_eq(L.current(), "id", "the session language is applied")
	assert_eq(StudyMode.DEFAULT_DURATION, 15, "default 15 minutes")
	assert_eq(StudyMode.DEFAULT_LANGUAGE, "id", "default Bahasa Indonesia")
	_restore(saved)


func _world_snapshot() -> String:
	var world := GameState.to_state()
	return JSON.stringify({"world": world, "time": TimeManager.to_state(), "quests": QuestManager.book.to_state(), "playtime": SaveManager.playtime_seconds}, "", true)


func test_study_journey_is_identical_and_never_touches_slots() -> void:
	var saved := _save_state()
	var size := Vector2(10240, 6144)
	for slot in [1, 2, 3]:
		var f := FileAccess.open(SaveManager.slot_path(slot), FileAccess.WRITE)
		f.store_string("player journey %d" % slot)
		f.close()
	StudyMode.participant_code = "P01"
	StudyMode.begin_play()
	assert_eq(SaveManager.current_slot, SaveManager.STUDY_SLOT, "the study slot is used")
	assert_true(SaveManager.slot_path(SaveManager.STUDY_SLOT).ends_with("saves_study/study_tmp.json"), "saves/study_tmp.json")
	SaveManager.prepare_world(size)
	var first := _world_snapshot()
	assert_true(FileAccess.file_exists(SaveManager.slot_path(SaveManager.STUDY_SLOT)), "the study journey is saved in its own file")
	assert_eq(TimeManager.day, 1, "day 1")
	assert_eq(TimeManager.minute_of_day, TimeManager.START_MINUTE, "the normal start time")
	GameState.add_counter("planted", 4)
	GameState.give_item("branch", 3)
	TimeManager.advance(300.0)
	StudyMode.end_play()
	assert_false(FileAccess.file_exists(SaveManager.slot_path(SaveManager.STUDY_SLOT)), "deleted after the session")
	StudyMode.begin_play()
	SaveManager.prepare_world(size)
	assert_eq(_world_snapshot(), first, "the second study journey starts from the identical state")
	StudyMode.end_play()
	for slot in [1, 2, 3]:
		assert_eq(FileAccess.get_file_as_string(SaveManager.slot_path(slot)), "player journey %d" % slot, "slot %d untouched" % slot)
		_remove(SaveManager.slot_path(slot))
	_restore(saved)


func test_gentle_end_waits_and_never_interrupts() -> void:
	var saved := _save_state()
	StudyMode.duration_minutes = 10
	StudyMode.session_running = true
	StudyMode.end_stage = StudyMode.EndStage.PLAYING
	StudyMode.fake_elapsed = 100.0
	assert_eq(StudyMode.end_step(false), "", "nothing before the time is up")
	StudyMode.fake_elapsed = 600.0
	assert_eq(StudyMode.end_step(true), "", "never during dialogue or a minigame")
	assert_eq(StudyMode.end_step(false), "announce", "then Lumi's gentle line")
	assert_eq(StudyMode.end_step(false), "", "the player can finish what they are doing")
	StudyMode.fake_elapsed = 659.0
	assert_eq(StudyMode.end_step(false), "", "up to 60 more seconds")
	StudyMode.fake_elapsed = 661.0
	assert_eq(StudyMode.end_step(true), "", "still never mid-dialogue or mid-minigame")
	assert_eq(StudyMode.end_step(false), "finish", "then on to the reflection")
	assert_eq(StudyMode.end_step(false), "", "only once")
	assert_true(StudyMode.END_LINE.contains("Shall we rest?"), "a gentle question, not a cut-off")
	_restore(saved)


func test_study_csv_header_row_and_score_delta() -> void:
	var saved := _save_state()
	StudyMode.participant_code = "P07"
	StudyMode.duration_minutes = 15
	var header := StudyMode.study_header()
	assert_eq(header.size(), 22, "6 study columns + 16 schema-v1 columns")
	assert_eq(Array(header.slice(0, 6)), ["study_schema_version", "participant_code", "language", "build_version", "git_commit", "target_duration_seconds"])
	assert_eq(Array(header.slice(6)), Array(SessionRecord.COLUMNS), "the v1 columns in the same order")
	var r := SessionRecord.new()
	r.session_id = SessionRecord.generate_session_id()
	r.session_started_at = SessionRecord.local_timestamp()
	r.pre_stress_score = 7
	r.post_stress_score = 4
	r.selected_mode = "gentle"
	r.final_mode = "gentle"
	r.recommended_mode = "gentle"
	assert_true(StudyMode.store_record(r)["ok"], "stored")
	var text := FileAccess.get_file_as_string(STUDY_CSV)
	assert_true(text.begins_with(",".join(header) + "\n"), "the header line")
	var rows: Array = StudyMode.sessions_store.read_rows()["rows"]
	assert_eq(rows.size(), 1)
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		assert_eq(row["study_schema_version"], "1")
		assert_eq(row["participant_code"], "P07")
		assert_eq(row["language"], L.current())
		assert_eq(row["build_version"], SaveManager.GAME_VERSION)
		assert_eq(row["target_duration_seconds"], "900")
		assert_eq(row["score_delta"], "-3", "score_delta = post - pre")
		assert_eq(row["pre_stress_score"], "7")
		assert_eq(row["experience_rating"], "", "a missing answer stays empty, never 0")
	_restore(saved)


func test_study_record_follows_consent_and_keeps_sessions_csv_v1() -> void:
	var saved := _save_state()
	StudyMode.participant_code = "P02"
	SessionState.begin_session(6, AdaptiveComfortEngine.MODE_BALANCED, true)
	StudyMode.record_pending = true
	SessionState.set_reflection(3, 4)
	SessionState.finalize_and_save(true)
	assert_eq(SessionState.storage.count_records(), 1, "the normal v1 row is written too")
	assert_true(FileAccess.get_file_as_string(SESSIONS_CSV).begins_with(SessionStorage.header_line()), "sessions.csv keeps schema v1")
	assert_eq((StudyMode.sessions_store.read_rows()["rows"] as Array).size(), 1, "one study row")
	assert_false(StudyMode.record_pending, "written once")
	_remove(STUDY_CSV)
	SessionState.begin_session(6, AdaptiveComfortEngine.MODE_BALANCED, false)
	StudyMode.record_pending = true
	SessionState.finalize_and_save(true)
	assert_false(FileAccess.file_exists(STUDY_CSV), "no consent: no study row")
	_restore(saved)


func test_events_only_during_a_consented_study_session() -> void:
	var saved := _save_state()
	StudyMode.participant_code = "P03"
	StudyMode.session_running = true
	SessionState.consent_to_store = false
	StudyMode.log_event("region_entered", "firefly_grove")
	assert_false(FileAccess.file_exists(EVENTS_CSV), "no consent: nothing logged")
	SessionState.consent_to_store = true
	StudyMode.fake_elapsed = 12.0
	StudyMode.log_event("region_entered", "firefly_grove")
	var rows: Array = StudyMode.events_store.read_rows()["rows"]
	assert_eq(rows.size(), 1)
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		assert_eq(row["participant_code"], "P03")
		assert_eq(row["t_seconds"], "12.0")
		assert_eq(row["event"], "region_entered")
		assert_eq(row["detail"], "firefly_grove", "regions only, never positions")
	StudyMode.session_running = false
	StudyMode.log_event("hint_requested", "")
	assert_eq((StudyMode.events_store.read_rows()["rows"] as Array).size(), 1, "nothing outside a study session")
	_restore(saved)


func test_default_flow_never_opens_the_research_layer() -> void:
	var saved := _save_state()
	StudyMode.cli_active = false
	GameSettings.study_mode = false
	var menu: Script = load("res://game/scripts/ui/main_menu.gd")
	assert_eq(menu.call("start_target"), SceneRouter.SLOT_SELECT, "Start Adventure goes straight to the journeys")
	StudyMode.cli_active = true
	assert_eq(menu.call("start_target"), SceneRouter.STUDY_SETUP, "Study Mode goes to the setup")
	StudyMode.cli_active = false
	var slots: Script = load("res://game/scripts/ui/slot_select.gd")
	SessionState.session_active = false
	slots.call("start_play_session", AdaptiveComfortEngine.MODE_PLAYFUL, true)
	assert_false(SessionState.consent_to_store, "a normal play session stores no research data")
	assert_eq(SessionState.pre_stress_score, null, "no stress question in the default flow")
	assert_eq(SessionState.get_config().mode_id, AdaptiveComfortEngine.MODE_PLAYFUL, "the journey's mode")
	assert_true(bool(SessionState.start_cards.get("mode_card")) and bool(SessionState.start_cards.get("mood_check")), "a new journey asks for the mode card and the mood check")
	SessionState.start_cards = {}
	SessionState.finalize_and_save(false)
	assert_false(FileAccess.file_exists(SESSIONS_CSV), "nothing written")
	_restore(saved)


func test_breathing_logs_only_started_and_stopped_in_a_study() -> void:
	var saved := _save_state()
	StudyMode.participant_code = "P04"
	StudyMode.session_running = true
	SessionState.consent_to_store = true
	var panel := BreathePanel.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(panel)
	panel.setup()
	panel.pace_index = 1
	panel.begin_breathing()
	panel._process(BreathePanel.SETTLE_SECONDS + 5.0)
	panel.stop()
	panel.free()
	var rows: Array = StudyMode.events_store.read_rows()["rows"]
	var events := PackedStringArray()
	for r: Dictionary in rows:
		events.append("%s:%s" % [r["event"], r["detail"]])
	assert_eq(events, PackedStringArray(["activity_started:breathing", "activity_finished:breathing"]), "only breathing started and stopped are logged (no pace, timing or count)")
	_restore(saved)
