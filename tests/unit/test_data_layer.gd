extends "res://tests/test_case.gd"
## Tests for CsvCodec, SessionRecord and SessionStorage.
## Storage tests use a dedicated file under user://test_tmp/ and clean it up.

const TEST_DIR := "user://test_tmp"
const TEST_FILE := "user://test_tmp/sessions_test.csv"
const EXPORT_FILE := "user://test_tmp/export_test.csv"
const FOREIGN_FILE := "user://test_tmp/foreign.csv"


func _make_record(pre: Variant = 7, post: Variant = 4) -> SessionRecord:
	var r := SessionRecord.new()
	r.session_id = SessionRecord.generate_session_id()
	r.session_started_at = SessionRecord.local_timestamp()
	r.pre_stress_score = pre
	r.recommended_mode = "gentle"
	r.selected_mode = "gentle"
	r.final_mode = "balanced"
	r.session_duration_seconds = 312
	r.hints_used = 2
	r.interaction_help_events = 1
	r.items_collected = 9
	r.garden_restored = true
	r.post_stress_score = post
	r.experience_rating = 4
	r.completed = true
	return r


func _clean() -> void:
	for p in [TEST_FILE, EXPORT_FILE, FOREIGN_FILE]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))


# --- CsvCodec -------------------------------------------------------------------

func test_csv_escapes_commas_quotes_and_newlines() -> void:
	assert_eq(CsvCodec.escape_field("plain"), "plain")
	assert_eq(CsvCodec.escape_field("a,b"), "\"a,b\"")
	assert_eq(CsvCodec.escape_field("say \"hi\""), "\"say \"\"hi\"\"\"")
	assert_eq(CsvCodec.escape_field("line1\nline2"), "\"line1\nline2\"")
	assert_eq(CsvCodec.escape_field(""), "", "empty stays empty (missing value)")


func test_csv_round_trip() -> void:
	var fields := PackedStringArray(["x", "a,b", "say \"hi\"", "", "multi\nline", " padded "])
	var text := CsvCodec.encode_row(PackedStringArray(["h1", "h2", "h3", "h4", "h5", "h6"])) + CsvCodec.encode_row(fields)
	var rows := CsvCodec.parse_text(text)
	assert_eq(rows.size(), 2, "two rows parsed")
	assert_eq(rows[1].size(), 6)
	for i in fields.size():
		assert_eq(rows[1][i], fields[i], "field %d" % i)


# --- SessionRecord --------------------------------------------------------------

func test_record_columns_match_schema() -> void:
	assert_eq(SessionRecord.COLUMNS.size(), 16)
	assert_eq(SessionRecord.COLUMNS[0], "schema_version")
	assert_eq(_make_record().to_row().size(), SessionRecord.COLUMNS.size())


func test_record_row_values() -> void:
	var row := _make_record(7, 4).to_row()
	var idx := func(name: String) -> int: return SessionRecord.COLUMNS.find(name)
	assert_eq(row[idx.call("schema_version")], "1")
	assert_eq(row[idx.call("pre_stress_score")], "7")
	assert_eq(row[idx.call("post_stress_score")], "4")
	assert_eq(row[idx.call("score_delta")], "-3")
	assert_eq(row[idx.call("garden_restored")], "true")
	assert_eq(row[idx.call("experience_rating")], "4")


func test_missing_scores_stay_empty_not_zero() -> void:
	var row := _make_record(null, null).to_row()
	assert_eq(row[SessionRecord.COLUMNS.find("pre_stress_score")], "")
	assert_eq(row[SessionRecord.COLUMNS.find("post_stress_score")], "")
	assert_eq(row[SessionRecord.COLUMNS.find("score_delta")], "")
	var zero_row := _make_record(0, 0).to_row()
	assert_eq(zero_row[SessionRecord.COLUMNS.find("pre_stress_score")], "0", "zero is kept as a real answer")
	assert_eq(zero_row[SessionRecord.COLUMNS.find("score_delta")], "0")


func test_session_id_is_random_and_anonymous() -> void:
	var a := SessionRecord.generate_session_id()
	var b := SessionRecord.generate_session_id()
	assert_true(a != b)
	assert_true(a.begins_with("cq-"))
	assert_eq(a.length(), 3 + SessionRecord.SESSION_ID_HEX_LENGTH)


func test_record_validation() -> void:
	assert_eq(_make_record().validate().size(), 0, "valid record")
	var bad := _make_record(15, -2)
	bad.experience_rating = 9
	bad.selected_mode = "turbo"
	bad.session_duration_seconds = -5
	assert_true(bad.validate().size() >= 5, "all problems reported")


# --- SessionStorage ---------------------------------------------------------------

func test_storage_creates_header_and_appends() -> void:
	_clean()
	var storage := SessionStorage.new(TEST_FILE)
	assert_false(storage.exists())
	assert_true(storage.append_record(_make_record(7, 4))["ok"])
	assert_true(storage.append_record(_make_record(null, 3))["ok"])
	var text := FileAccess.get_file_as_string(TEST_FILE)
	assert_true(text.begins_with(",".join(SessionRecord.COLUMNS) + "\n"), "header first")
	assert_eq(text.count("schema_version"), 1, "header written once")
	assert_eq(storage.count_records(), 2)
	var rows: Array = storage.read_rows()["rows"]
	assert_eq(rows[1]["pre_stress_score"], "", "missing stays missing after round trip")
	assert_eq(rows[0]["score_delta"], "-3")
	_clean()


func test_storage_refuses_invalid_records() -> void:
	_clean()
	var storage := SessionStorage.new(TEST_FILE)
	var result := storage.append_record(_make_record(42, 4))
	assert_false(result["ok"])
	assert_false(storage.exists(), "nothing written for an invalid record")
	_clean()


func test_storage_never_modifies_foreign_file() -> void:
	_clean()
	var f := FileAccess.open(FOREIGN_FILE, FileAccess.WRITE)
	f.store_string("name,email\nalice,a@example.com\n")
	f.close()
	var before := FileAccess.get_file_as_string(FOREIGN_FILE)
	var storage := SessionStorage.new(FOREIGN_FILE)
	assert_false(storage.append_record(_make_record())["ok"])
	assert_eq(FileAccess.get_file_as_string(FOREIGN_FILE), before, "foreign file untouched")
	assert_eq(storage.count_records(), -1)
	_clean()


func test_export_and_delete() -> void:
	_clean()
	var storage := SessionStorage.new(TEST_FILE)
	storage.append_record(_make_record())
	assert_false(storage.export_to("user://test_tmp/export.txt")["ok"], "non-csv refused")
	assert_false(storage.export_to(TEST_FILE)["ok"], "cannot export onto source")
	assert_true(storage.export_to(EXPORT_FILE)["ok"])
	assert_eq(FileAccess.get_file_as_string(EXPORT_FILE), FileAccess.get_file_as_string(TEST_FILE))
	assert_true(storage.delete_all()["ok"])
	assert_false(storage.exists())
	assert_true(storage.delete_all()["ok"], "deleting twice is harmless")
	assert_false(storage.export_to(EXPORT_FILE + ".csv")["ok"], "nothing to export after delete")
	_clean()


func test_write_failure_is_reported() -> void:
	# The parent "folder" is actually a file, so the write cannot succeed.
	# The storage layer must report the failure instead of claiming success.
	_clean()
	var blocker_path := TEST_DIR + "/blocker"
	var blocker := FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("not a folder")
	blocker.close()
	var storage := SessionStorage.new(blocker_path + "/sessions.csv")
	var result := storage.append_record(_make_record())
	assert_false(result["ok"], "write failure must be reported")
	assert_false((result["message"] as String).is_empty(), "a clear message is provided")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker_path))
	_clean()
