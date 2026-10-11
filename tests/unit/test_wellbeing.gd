extends "res://tests/test_case.gd"
## Tests for the optional well-being layer (0.4.0, P1): the five faces, Lumi's
## neutral replies, the session summary (real events only), the private mood
## journal (off by default, written only when on, never overwriting a damaged
## file), the mood-check setting, and that none of it reaches research data.
## Files go to user://test_tmp/, never the player's own.

const TEST_DIR := "user://test_tmp"
const JOURNAL := "user://test_tmp/wellbeing_journal_test.json"
const SETTINGS := "user://test_tmp/wellbeing_settings.cfg"


func _setup() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	if FileAccess.file_exists(JOURNAL):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JOURNAL))
	var saved := {
		"journal_path": Wellbeing.journal_path, "mood_journal": GameSettings.mood_journal,
		"counters": GameState.counters.duplicate(),
	}
	Wellbeing.journal_path = JOURNAL
	return saved


func _restore(saved: Dictionary) -> void:
	Wellbeing.journal_path = saved["journal_path"]
	GameSettings.mood_journal = saved["mood_journal"]
	GameState.counters = saved["counters"]
	if FileAccess.file_exists(JOURNAL):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(JOURNAL))


func test_five_faces_with_names() -> void:
	assert_eq(Wellbeing.FACES.size(), 5)
	assert_eq(Array(Wellbeing.FACES), ["Tense", "Uneasy", "Okay", "Calm", "Peaceful"])
	assert_eq(Wellbeing.face_name(1), "Tense")
	assert_eq(Wellbeing.face_name(5), "Peaceful")
	assert_eq(Wellbeing.face_name(0), "", "no face for 0")
	assert_eq(Wellbeing.face_name(null), "", "no face for a skip")
	assert_false(Wellbeing.is_valid_face(6))


func test_lumi_replies_are_neutral() -> void:
	for line in Wellbeing.LUMI_REPLIES:
		var lower := line.to_lower()
		for word in ["stress", "better", "fix", "heal", "calmer", "anxiety", "should", "therapy"]:
			assert_false(lower.contains(word), "reply '%s' avoids '%s'" % [line, word])


func test_summary_contains_only_real_events() -> void:
	var saved := _setup()
	Wellbeing.begin_play()
	assert_eq(Array(Wellbeing.summary_lines()), ["A quiet walk is time well spent."], "nothing happened: the quiet line")
	GameState.add_counter("planted", 3)
	GameState.add_counter("fish_caught")
	Wellbeing.note_new_place("Misty Pinewood")
	var lines := Wellbeing.summary_lines()
	assert_true(lines.has("You planted 3 seeds."), "planted seeds")
	assert_true(lines.has("You caught a fish."), "one fish, singular")
	assert_true(lines.has("You found a new place: Misty Pinewood."), "a new place")
	for line in lines:
		assert_false(line.contains("harvest") or line.contains("cooked") or line.contains("Hearthstone"), "nothing invented: %s" % line)
	assert_false(lines.has("A quiet walk is time well spent."), "no quiet line when something happened")
	assert_true(lines.size() <= Wellbeing.MAX_SUMMARY_LINES, "at most 4 lines")
	_restore(saved)


func test_summary_counts_only_this_session() -> void:
	var saved := _setup()
	GameState.add_counter("harvested", 5)
	Wellbeing.begin_play()
	assert_eq(Array(Wellbeing.summary_lines()), ["A quiet walk is time well spent."], "earlier harvests are not this session")
	EventBus.quest_completed.emit("act1_lost_lights")
	assert_true(Wellbeing.summary_lines().has("You finished a quest: Follow the Lost Lights."), "a quest finished this session")
	_restore(saved)


func test_journal_off_writes_nothing() -> void:
	var saved := _setup()
	GameSettings.mood_journal = false
	Wellbeing.begin_play()
	Wellbeing.start_face = 4
	Wellbeing.end_face = 5
	assert_false(Wellbeing.record_session_end(), "journal off: nothing written")
	assert_false(FileAccess.file_exists(JOURNAL), "no file")
	_restore(saved)


func test_journal_on_writes_once_and_deletes() -> void:
	var saved := _setup()
	GameSettings.mood_journal = true
	Wellbeing.begin_play()
	Wellbeing.start_face = 4
	GameState.add_counter("planted", 2)
	assert_true(Wellbeing.record_session_end(), "journal on: written")
	assert_false(Wellbeing.record_session_end(), "once per play session")
	var entries := Wellbeing.journal_entries()
	assert_eq(entries.size(), 1)
	if entries.size() == 1:
		var e: Dictionary = entries[0]
		assert_eq(int(e["start_face"]), 4, "start face")
		assert_eq(e["end_face"], null, "a skipped end face stays empty")
		assert_eq(int(e["minutes"]), 0, "minutes played")
		assert_true((e["summary"] as Array).has("You planted 2 seeds."), "summary lines kept")
		assert_true(String(e["local_time"]).length() >= 16, "local date and time")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(JOURNAL))
	assert_eq(int((data as Dictionary)["journal_version"]), Wellbeing.JOURNAL_VERSION, "versioned file")
	assert_true(Wellbeing.delete_journal() and not FileAccess.file_exists(JOURNAL), "deleted")
	_restore(saved)


func test_damaged_journal_is_never_overwritten() -> void:
	var saved := _setup()
	GameSettings.mood_journal = true
	var f := FileAccess.open(JOURNAL, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	Wellbeing.begin_play()
	assert_false(Wellbeing.record_session_end(), "refuses to write over a damaged journal")
	assert_eq(FileAccess.get_file_as_string(JOURNAL), "{ not json", "the file is untouched")
	_restore(saved)


func test_mood_check_setting_persists() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var old_path := GameSettings.settings_path
	var old := [GameSettings.mood_check, GameSettings.session_summary, GameSettings.mood_journal]
	GameSettings.settings_path = SETTINGS
	GameSettings.set_setting("mood_check", false)
	GameSettings.mood_check = true
	GameSettings.load_settings()
	assert_false(GameSettings.mood_check, "Don't ask is kept across restarts")
	GameSettings.mood_check = old[0]
	GameSettings.session_summary = old[1]
	GameSettings.mood_journal = old[2]
	GameSettings.settings_path = old_path
	if FileAccess.file_exists(SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS))


func test_journal_default_off_and_never_in_research_data() -> void:
	var fresh: Node = load("res://game/scripts/autoload/game_settings.gd").new()
	assert_false(fresh.get("mood_journal"), "the mood journal is off by default")
	assert_true(fresh.get("mood_check"), "the mood check asks by default")
	fresh.free()
	for column in SessionRecord.COLUMNS:
		assert_false(column.contains("mood") or column.contains("face"), "no mood data in the research schema (%s)" % column)
	assert_eq(SessionRecord.COLUMNS.size(), 16, "schema v1 keeps 16 columns")
