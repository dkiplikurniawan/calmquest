extends Node
## UI smoke test: builds every menu screen and overlay with the real autoloads,
## exercises settings, the check-in recommendation/override logic and the
## results wording, without changing scenes.
##
## Run:  godot --headless --path . res://tests/smoke/ui_smoke_test.tscn
## Settings are redirected to user://test_tmp/ so the player's file is untouched.

const TEST_SETTINGS := "user://test_tmp/ui_settings.cfg"

var _checks: int = 0
var _failures: PackedStringArray = []


func check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", label)
	else:
		_failures.append(label)
		printerr("  FAIL ", label)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tmp"))
	GameSettings.settings_path = TEST_SETTINGS
	# Assertions compare English text; the player's chosen language must not change them.
	GameSettings.set_setting("language", "en")
	SessionState.progress = ProgressStore.new("user://test_tmp/ui_progress.cfg")
	await _run()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("")
	print("UI smoke test: %d checks, %d failed" % [_checks, _failures.size()])
	for f in _failures:
		printerr("FAILED: ", f)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)

	# --- Overlays build without errors ---------------------------------------------
	for panel: Control in [HowToPlayPanel.new(), SettingsPanel.new(), PrivacyPanel.new(), JournalPanel.new()]:
		host.add_child(panel)
		await get_tree().process_frame
		check(panel.is_inside_tree() and panel.get_child_count() > 0, "%s builds" % panel.get_script().get_global_name())
		panel.queue_free()
	await get_tree().process_frame

	# --- Settings have real effects -------------------------------------------------
	var hud_layer := Hud.new()
	add_child(hud_layer)
	await get_tree().process_frame
	var hud_root := hud_layer.get_child(0) as Control
	check(hud_root.theme == GameSettings.ui_theme, "HUD under a CanvasLayer uses the shared theme")
	var base_size := GameSettings.ui_theme.default_font_size
	GameSettings.set_setting("text_scale_index", 2)
	check(GameSettings.ui_theme.default_font_size > base_size, "Extra large text increases the font size (%d -> %d)" % [base_size, GameSettings.ui_theme.default_font_size])
	check(hud_root.theme == GameSettings.ui_theme, "HUD picks up the rebuilt theme")
	check(get_tree().root.theme == GameSettings.ui_theme, "window theme updated")
	GameSettings.set_setting("high_contrast", true)
	var panel_style := GameSettings.ui_theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	check(panel_style.bg_color == Color.WHITE, "high contrast switches panels to white")
	GameSettings.set_setting("reduce_motion", true)
	check(GameSettings.motion_scale() < 1.0, "reduce motion lowers the motion scale")
	GameSettings.set_setting("sfx_volume", 0.0)
	var sfx_bus := AudioServer.get_bus_index(AudioManager.SFX_BUS)
	check(sfx_bus >= 0 and AudioServer.is_bus_mute(sfx_bus), "SFX volume 0 mutes the SFX bus")
	GameSettings.set_setting("sfx_volume", 0.8)
	check(not AudioServer.is_bus_mute(sfx_bus), "SFX volume restored")
	GameSettings.set_setting("master_volume", 5.0)
	check(GameSettings.master_volume == 1.0, "out-of-range volume is clamped")
	check(FileAccess.file_exists(TEST_SETTINGS), "settings are saved to disk")
	GameSettings.set_setting("region_titles", 7)
	check(GameSettings.region_titles == 2, "region title option is clamped to a valid choice")
	GameSettings.set_setting("region_titles", 0)
	GameSettings.set_setting("show_minimap", true)
	check(GameSettings.show_minimap, "minimap can be switched on")
	GameSettings.set_setting("show_minimap", false)
	check(not GameSettings.show_minimap and GameSettings.show_compass, "defaults: minimap off, compass on")
	for key in ["text_scale_index", "high_contrast", "reduce_motion", "master_volume"]:
		GameSettings.set_setting(key, {"text_scale_index": 0, "high_contrast": false, "reduce_motion": false, "master_volume": 0.8}[key])
	hud_layer.queue_free()

	# --- Check-in: recommendation and override ---------------------------------------
	var check_in: Control = load("res://game/scenes/ui/check_in.tscn").instantiate()
	host.add_child(check_in)
	await get_tree().process_frame
	check(check_in.get("_selected_mode") == AdaptiveComfortEngine.MODE_BALANCED, "check-in starts on Balanced")
	check(not (check_in.get("_consent") as CheckBox).button_pressed, "consent box is unticked by default")
	check_in.call("_on_answered", 8)
	check(check_in.get("_selected_mode") == AdaptiveComfortEngine.MODE_GENTLE, "score 8 pre-selects Gentle")
	check_in.call("_on_answered", 2)
	check(check_in.get("_selected_mode") == AdaptiveComfortEngine.MODE_BALANCED, "score 2 pre-selects Balanced")
	check((check_in.get("_recommendation") as Label).text.contains("Playful"), "score 2 offers Playful as a choice")
	check_in.call("_choose_mode", AdaptiveComfortEngine.MODE_PLAYFUL, true)
	check_in.call("_on_answered", 9)
	check(check_in.get("_selected_mode") == AdaptiveComfortEngine.MODE_PLAYFUL, "player's own choice is never overridden by a suggestion")
	check_in.queue_free()

	# --- Stress slider: untouched means unanswered -------------------------------------
	var slider := StressSlider.new()
	host.add_child(slider)
	check(slider.get_answer() == null, "untouched slider gives no answer (not 5, not 0)")
	slider.get_slider().value = 0
	check(slider.get_answer() == 0, "moving the slider to 0 records 0")
	slider.queue_free()

	# --- Results wording uses only this session's answers --------------------------------
	SessionState.begin_session(7, AdaptiveComfortEngine.MODE_GENTLE, false)
	SessionState.set_reflection(4, null)
	var results: Control = load("res://game/scenes/ui/results.tscn").instantiate()
	host.add_child(results)
	await get_tree().process_frame
	var texts := _all_label_text(results)
	check(texts.contains("7 / 10") and texts.contains("4 / 10") and texts.contains("-3 points"), "results show the real before/after/change")
	check(texts.contains("decreased by 3 points"), "results sentence is neutral and correct")
	var lower := texts.to_lower()
	check(not lower.contains("cured") and not lower.contains("diagnosed") and not lower.contains("the game reduced"), "no clinical or causal claims in results")
	results.queue_free()

	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, false)
	SessionState.set_reflection(6, null)
	var results2: Control = load("res://game/scenes/ui/results.tscn").instantiate()
	host.add_child(results2)
	await get_tree().process_frame
	var texts2 := _all_label_text(results2)
	check(texts2.contains("Not answered") and texts2.contains("Not available"), "missing pre score shown as not answered")
	check(texts2.contains("check-in before playing was skipped"), "incomplete comparison explained")
	results2.queue_free()
	await get_tree().process_frame

	await _check_player_flow(host)

	# --- Language: English <-> Bahasa Indonesia ----------------------------------------
	var settings := SettingsPanel.new()
	host.add_child(settings)
	await get_tree().process_frame
	var lang_button := _find_button(settings, "Language / Bahasa")
	check(lang_button != null and lang_button.text.contains("English"), "Settings has a language option (English by default)")
	if lang_button != null:
		lang_button.pressed.emit()
		check(GameSettings.language == "id" and L.current() == "id", "the language option switches to Bahasa Indonesia")
		check(lang_button.text.contains("Bahasa Indonesia") and lang_button.text.contains("klik untuk mengganti"), "the option itself is shown in Indonesian")
		var heading := _find_label(settings, "Settings")
		check(heading != null and heading.atr(heading.text) == "Pengaturan", "the panel heading is translated at once")
		check(_find_button(settings, "Judul wilayah:") != null, "composed settings buttons are rebuilt in Indonesian")
		var hud_id := Hud.new()
		add_child(hud_id)
		await get_tree().process_frame
		hud_id.set_mode("Gentle")
		check((hud_id.get("_mode_label") as Label).text == "Mode: Lembut", "the HUD mode label is translated")
		hud_id.queue_free()
		SessionState.begin_session(7, AdaptiveComfortEngine.MODE_GENTLE, false)
		SessionState.set_reflection(4, null)
		var results_id: Control = load("res://game/scenes/ui/results.tscn").instantiate()
		host.add_child(results_id)
		await get_tree().process_frame
		check(_all_label_text(results_id).contains("turun 3 poin"), "the results screen is shown in Indonesian")
		results_id.queue_free()
		lang_button.pressed.emit()
		check(GameSettings.language == "en" and L.current() == "en", "and back to English")
		check(lang_button.text.contains("English") and lang_button.text.contains("click to change"), "the option is shown in English again")
	settings.queue_free()
	await get_tree().process_frame


## 0.4.0 P1: the default (Steam) flow, the optional well-being layer and the
## hidden Study Mode. Settings changed here are restored afterwards.
func _check_player_flow(host: Control) -> void:
	var saved_settings := [GameSettings.mood_check, GameSettings.session_summary, GameSettings.mood_journal, GameSettings.study_mode]
	var saved_counters := GameState.counters.duplicate()
	StudyMode.cli_active = false
	GameSettings.study_mode = false

	# Main menu: straight to the journeys; the hidden unlock.
	check(load("res://game/scripts/ui/main_menu.gd").call("start_target") == SceneRouter.SLOT_SELECT, "Start Adventure opens the journeys, not the check-in")
	var menu: Control = load("res://game/scenes/ui/main_menu.tscn").instantiate()
	host.add_child(menu)
	await get_tree().process_frame
	check(not (menu.get("study_badge") as Label).visible, "no Study badge in the default flow")
	for i in 6:
		menu.call("register_version_click", 1000 + i * 100)
	check(_unlock_dialog(menu) == null, "six clicks do nothing")
	menu.call("register_version_click", 1700)
	var dialog := _unlock_dialog(menu)
	check(dialog != null, "the 7th click on the version label opens the unlock")
	if dialog != null:
		var edit := dialog.find_children("*", "LineEdit", true, false)[0] as LineEdit
		edit.text = "LUMERIA"
		_find_button(dialog, "Unlock").pressed.emit()
		check(not StudyMode.is_active() and _all_label_text(dialog).contains("That phrase is not right."), "a wrong phrase is refused")
		edit.text = "LUMERIA-STUDY"
		_find_button(dialog, "Unlock").pressed.emit()
		await get_tree().process_frame
		check(StudyMode.is_active() and (menu.get("study_badge") as Label).visible, "the phrase turns Study Mode on and shows the badge")
	var privacy := PrivacyPanel.new()
	host.add_child(privacy)
	await get_tree().process_frame
	check(_find_button(privacy, "Leave Study Mode") != null, "Data & Privacy offers Leave Study Mode")
	_find_button(privacy, "Leave Study Mode").pressed.emit()
	check(not StudyMode.is_active(), "Leave Study Mode turns it off")
	privacy.queue_free()
	var privacy2 := PrivacyPanel.new()
	host.add_child(privacy2)
	await get_tree().process_frame
	check(_find_button(privacy2, "Leave Study Mode") == null, "no study controls when Study Mode is off")
	privacy2.queue_free()
	menu.queue_free()

	# Study setup validates the participant code.
	var setup: Control = load("res://game/scenes/ui/study_setup.tscn").instantiate()
	host.add_child(setup)
	await get_tree().process_frame
	(setup.get("code_edit") as LineEdit).text = "P1"
	check(not String(setup.call("validate")).is_empty(), "study setup refuses a bad participant code")
	(setup.get("code_edit") as LineEdit).text = "P12"
	check(String(setup.call("validate")).is_empty() and StudyMode.participant_code == "P12", "study setup accepts P12")
	check(StudyMode.duration_minutes == 15 and L.current() == "id", "defaults: 15 minutes, Bahasa Indonesia")
	GameSettings.set_setting("language", "en")
	setup.queue_free()

	# The mood check card: five labelled faces, Skip, Don't ask again.
	var card := MoodCheckCard.new()
	host.add_child(card)
	await get_tree().process_frame
	check(card.faces.buttons.size() == 5, "five faces")
	var labelled := true
	for i in card.faces.buttons.size():
		var b := card.faces.buttons[i]
		labelled = labelled and b.tooltip_text == Wellbeing.FACES[i] and _all_label_text(b).contains(Wellbeing.FACES[i])
		if "accessibility_name" in b:
			labelled = labelled and String(b.get("accessibility_name")) == Wellbeing.FACES[i]
	check(labelled, "every face has a text label and an accessible name (never color alone)")
	var answers := []
	card.finished.connect(func(face: Variant, dont_ask: bool) -> void: answers.append([face, dont_ask]))
	card.dont_ask.button_pressed = true
	card.faces.buttons[3].pressed.emit()
	check(answers == [[4, true]], "one tap answers (Calm, and Don't ask again)")
	var card2 := MoodCheckCard.new()
	host.add_child(card2)
	await get_tree().process_frame
	card2.finished.connect(func(face: Variant, dont_ask: bool) -> void: answers.append([face, dont_ask]))
	card2.skip_button.pressed.emit()
	check(answers.size() == 2 and answers[1] == [null, false], "Skip is always there")

	# "Before you go...": real events only, no comparison, no score.
	GameSettings.session_summary = true
	GameSettings.mood_check = true
	Wellbeing.begin_play()
	GameState.add_counter("planted", 2)
	var closing := SessionClosingPanel.new()
	closing.leaving_to = "quit"
	host.add_child(closing)
	await get_tree().process_frame
	var closing_text := _all_label_text(closing)
	check(closing_text.contains("Before you go") and closing_text.contains("You planted 2 seeds."), "the summary shows what really happened")
	var lower := closing_text.to_lower()
	check(not lower.contains("stress") and not lower.contains("/ 10") and not lower.contains("change") and not lower.contains("points"), "no before/after comparison or score")
	check(closing.leave_button.text == "Quit Game" and closing.faces != null, "Quit, and the optional faces")
	var left := []
	closing.leave.connect(func(face: Variant) -> void: left.append(face))
	closing.faces.buttons[4].pressed.emit()
	closing.leave_button.pressed.emit()
	check(left == [5], "the end face is passed on")
	GameSettings.session_summary = false
	GameSettings.mood_check = false
	check(not Wellbeing.wants_closing(), "both settings off: no closing panel")

	# Settings: the Well-being section.
	var settings := SettingsPanel.new()
	host.add_child(settings)
	await get_tree().process_frame
	var mood_button := _find_button(settings, "Mood check when I start playing")
	check(mood_button != null and mood_button.text.contains("Don't ask"), "Settings > Well-being shows the mood check option")
	if mood_button != null:
		mood_button.pressed.emit()
		check(GameSettings.mood_check and mood_button.text.contains("Ask"), "it switches to Ask")
	settings.queue_free()

	# Journal: the Feelings tab only when the journal is on.
	GameSettings.mood_journal = false
	var journal := JournalPanel.new()
	host.add_child(journal)
	await get_tree().process_frame
	check(journal.tabs.get_node_or_null("Feelings") == null, "no Feelings tab when the journal is off")
	journal.queue_free()
	GameSettings.mood_journal = true
	var journal2 := JournalPanel.new()
	host.add_child(journal2)
	await get_tree().process_frame
	check(journal2.tabs.get_node_or_null("Feelings") != null, "the Feelings tab when the journal is on")
	journal2.queue_free()

	# A new journey in a real world: mode card, then the mood check, then Lumi.
	GameSettings.mood_check = true
	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, false)
	SessionState.start_cards = {"mode_card": true, "mood_check": true}
	var world: Overworld = load("res://game/scenes/world/overworld.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world._overlay is ModeChoiceCard and get_tree().paused, "a new journey shows the mode card first")
	if world._overlay is ModeChoiceCard:
		var mode_card := world._overlay as ModeChoiceCard
		check(mode_card.selected == AdaptiveComfortEngine.MODE_BALANCED, "Balanced is pre-selected")
		mode_card.select(AdaptiveComfortEngine.MODE_PLAYFUL)
		(mode_card.get("_begin") as Button).pressed.emit()
		await get_tree().process_frame
		check(SessionState.get_config().mode_id == AdaptiveComfortEngine.MODE_PLAYFUL, "the chosen mode is applied")
	check(world._overlay is MoodCheckCard, "then the mood check")
	if world._overlay is MoodCheckCard:
		(world._overlay as MoodCheckCard).faces.buttons[3].pressed.emit()
		await get_tree().process_frame
		check(Wellbeing.start_face == 4 and not get_tree().paused and world.hud.is_dialogue_visible(), "Lumi answers warmly and the game continues")
	world._open_pause()
	world.pause_menu.leave_requested.emit()
	await get_tree().process_frame
	check(world._overlay is SessionClosingPanel, "Return to menu shows Before you go")
	if world._overlay is SessionClosingPanel:
		(world._overlay as SessionClosingPanel).keep_button.pressed.emit()
		await get_tree().process_frame
		check(not get_tree().paused, "Keep playing returns to the world")
	world.queue_free()
	await get_tree().process_frame
	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, false)
	var direct: Overworld = load("res://game/scenes/world/overworld.tscn").instantiate()
	add_child(direct)
	await get_tree().process_frame
	await get_tree().process_frame
	check(direct._overlay == null and not get_tree().paused, "a world opened directly shows no cards")
	direct.queue_free()
	await get_tree().process_frame

	GameSettings.mood_check = saved_settings[0]
	GameSettings.session_summary = saved_settings[1]
	GameSettings.mood_journal = saved_settings[2]
	GameSettings.study_mode = saved_settings[3]
	GameState.counters = saved_counters
	get_tree().paused = false


func _unlock_dialog(menu: Node) -> Control:
	for child in menu.get_children():
		if child.has_meta("unlock_dialog") and not child.is_queued_for_deletion():
			return child
	return null


func _find_button(node: Node, prefix: String) -> Button:
	for child in node.find_children("*", "Button", true, false):
		if (child as Button).text.begins_with(prefix):
			return child
	return null


func _find_label(node: Node, text: String) -> Label:
	for child in node.find_children("*", "Label", true, false):
		if (child as Label).text == text:
			return child
	return null


func _all_label_text(node: Node) -> String:
	var parts := PackedStringArray()
	for child in node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)
