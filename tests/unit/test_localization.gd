extends "res://tests/test_case.gd"
## Tests for the English / Bahasa Indonesia language setting: the catalog
## loads, every translation keeps its placeholders (in order) and line breaks,
## switching translates labels, data getters and composed text, the setting
## persists and is sanitized, and the research CSV never depends on the
## language. Every test switches back to English before it ends.
## Settings are written to a temporary file, never the player's own.

const TEST_SETTINGS := "user://test_tmp/unit_language.cfg"
const PLACEHOLDER := "%(?:[-+ 0#]*\\d*(?:\\.\\d+)?[sdif]|%)"


func _placeholders(re: RegEx, text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m in re.search_all(text):
		out.append(m.get_string())
	out.append("lines:%d" % text.count("\n"))
	return out


func test_catalog_loads_completely() -> void:
	L.load_errors.clear()
	var cat := L.catalog("id")
	assert_true(L.load_errors.is_empty(), "catalog files parse: %s" % ", ".join(L.load_errors))
	assert_true(cat.size() > 1400, "the Indonesian catalog is complete (%d entries)" % cat.size())
	var empty := 0
	for k: String in cat:
		if String(cat[k]).strip_edges().is_empty():
			empty += 1
	assert_eq(empty, 0, "no empty translations")
	assert_eq(String(cat.get("Settings", "")), "Pengaturan", "a known entry")


func test_translations_keep_placeholders_in_order() -> void:
	var re := RegEx.new()
	re.compile(PLACEHOLDER)
	var cat := L.catalog("id")
	var bad := PackedStringArray()
	for k: String in cat:
		if _placeholders(re, k) != _placeholders(re, String(cat[k])):
			bad.append(k)
	assert_true(bad.is_empty(), "placeholders and line breaks match: %s" % "; ".join(bad))


func test_english_is_the_default_and_source() -> void:
	L.set_language("en")
	assert_eq(L.current(), "en")
	assert_eq(L.t("Settings"), "Settings", "English shows the source text")
	assert_eq(ItemDB.display_name("branch"), "Fallen Branch")
	assert_eq(L.t("a text with no translation at all"), "a text with no translation at all", "unknown text stays as it is")
	assert_eq(L.t(""), "", "empty text stays empty")


func test_switching_translates_getters_and_composed_text() -> void:
	L.set_language("id")
	assert_eq(L.current(), "id")
	assert_eq(L.t("Settings"), "Pengaturan")
	assert_eq(ItemDB.display_name("branch"), "Ranting Jatuh", "item names come from the catalog")
	assert_eq(VillageDB.display_name("pip"), "Pip", "names stay names")
	assert_eq(L.t("Talk to %s") % VillageDB.display_name("pip"), "Bicara dengan Pip", "templates are translated before formatting")
	assert_eq(LumiGuide.compass_word(Vector2.ZERO, Vector2(100, 0)), "timur", "directions")
	assert_true(LumiGuide.hint_for_target(Vector2.ZERO, Vector2(2000, 0), L.t("a light")).begins_with("Aku merasakan sebuah cahaya di arah timur"), "Lumi's hint reads naturally")
	assert_eq(ScoreComparison.describe(7, 4), "Skor stres yang kamu laporkan turun 3 poin selama sesi ini.", "results sentence")
	var label := Label.new()
	label.text = "Settings"
	(Engine.get_main_loop() as SceneTree).root.add_child(label)
	assert_eq(label.atr(label.text), "Pengaturan", "labels translate their exact text automatically")
	assert_eq(label.text, "Settings", "the label keeps the English source in .text")
	label.free()
	L.set_language("en")
	assert_eq(ItemDB.display_name("branch"), "Fallen Branch", "back to English")


func test_language_setting_persists_and_is_sanitized() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	var old_path := GameSettings.settings_path
	var old_language := GameSettings.language
	GameSettings.settings_path = TEST_SETTINGS
	GameSettings.set_setting("language", "id")
	assert_eq(L.current(), "id", "the setting switches the language at once")
	GameSettings.language = "en"
	GameSettings.load_settings()
	assert_eq(GameSettings.language, "id", "the language is saved")
	GameSettings.set_setting("language", "xx")
	assert_eq(GameSettings.language, "en", "an unknown language falls back to English")
	assert_eq(L.current(), "en")
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	GameSettings.settings_path = old_path
	GameSettings.language = old_language
	L.set_language("en")


func test_research_record_does_not_depend_on_language() -> void:
	var r := SessionRecord.new()
	r.session_id = "cq-0123456789abcdef"
	r.session_started_at = "2026-10-11T10:00:00"
	r.pre_stress_score = 7
	r.post_stress_score = 4
	r.recommended_mode = "gentle"
	r.selected_mode = "gentle"
	r.final_mode = "balanced"
	L.set_language("en")
	var english := r.to_row()
	var header := SessionStorage.header_line()
	L.set_language("id")
	assert_eq(r.to_row(), english, "the CSV row is identical in Indonesian")
	assert_eq(SessionStorage.header_line(), header, "the CSV header (schema v1) is identical")
	assert_eq(r.get_score_delta(), -3, "score_delta = post - pre")
	L.set_language("en")
