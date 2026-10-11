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
	await _check_hud_and_ui(host)
	await _check_rest_and_breathe(host)

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
	# Rings: the golden ring only on the target, soft markers only on the 2 nearest (Gentle).
	SessionState.select_mode(AdaptiveComfortEngine.MODE_GENTLE)
	direct.teleport_to(direct.world.player_spawn)
	await get_tree().process_frame
	var probes: Array[Interactable] = []
	for i in 5:
		var probe := Interactable.new()
		probe.interactable_id = "ring_probe_%d" % i
		probe.position = direct.player.position + Vector2(40.0 + i * 28.0, 0.0)
		direct.entities.add_child(probe)
		probes.append(probe)
	await get_tree().process_frame
	direct.player.update_target()
	direct._update_markers()
	var marked: Array = []
	var unmarked_near: Array = []
	var limit := SessionState.get_config().interaction_radius * Overworld.MARKER_RADIUS_FACTOR
	var targeted := 0
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		var gap := direct.player.global_position.distance_to(it.get_interaction_point()) - it.reach_bonus
		if it.is_targeted:
			targeted += 1
		if it.show_marker:
			marked.append(gap)
		elif gap < limit and it.can_interact() and it != direct.player.current_target:
			unmarked_near.append(gap)
	check(targeted <= 1, "the golden ring is on one object at most")
	check(marked.size() == Overworld.MAX_NEARBY_MARKERS and unmarked_near.size() >= 1, "Gentle markers on only the %d nearest of several objects (%d marked, %d not)" % [Overworld.MAX_NEARBY_MARKERS, marked.size(), unmarked_near.size()])
	var nearest_ok := true
	for g in marked:
		for u in unmarked_near:
			nearest_ok = nearest_ok and float(g) <= float(u)
	check(nearest_ok, "the markers are on the nearest objects, none far away")
	SessionState.select_mode(AdaptiveComfortEngine.MODE_BALANCED)
	direct._update_markers()
	var balanced_marks := 0
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if (node as Interactable).show_marker:
			balanced_marks += 1
	check(balanced_marks == 0, "no extra rings in Balanced, only the target's")
	for probe in probes:
		probe.queue_free()
	# Footsteps follow the walk bob, and the setting silences them.
	var steps := [0]
	direct.player.footstep.connect(func() -> void: steps[0] += 1)
	direct.player.velocity = Vector2(150, 0)
	for i in 60:
		direct.player._process(1.0 / 60.0)
	check(steps[0] >= 3 and steps[0] <= 5, "about 4 footsteps per second while walking (%d)" % steps[0])
	steps[0] = 0
	direct.player.velocity = Vector2.ZERO
	for i in 60:
		direct.player._process(1.0 / 60.0)
	check(steps[0] == 0, "no footsteps when standing still")
	var played := []
	var on_sound := func(sound: StringName) -> void: played.append(String(sound))
	AudioManager.sound_played.connect(on_sound)
	var old_footsteps := GameSettings.footsteps
	GameSettings.footsteps = true
	direct._on_footstep()
	check(played.size() == 1 and played[0].begins_with("step_"), "a footstep sound for the ground (%s)" % ", ".join(played))
	GameSettings.footsteps = false
	direct._on_footstep()
	check(played.size() == 1, "Footsteps Off: silent")
	GameSettings.footsteps = old_footsteps
	AudioManager.sound_played.disconnect(on_sound)
	direct.queue_free()
	await get_tree().process_frame

	GameSettings.mood_check = saved_settings[0]
	GameSettings.session_summary = saved_settings[1]
	GameSettings.mood_journal = saved_settings[2]
	GameSettings.study_mode = saved_settings[3]
	GameState.counters = saved_counters
	get_tree().paused = false


## 0.4.0 P2: the calm HUD, key hints, toasts, rings, in-world fishing, the
## main menu and About, display settings, and every screen in Indonesian.
func _check_hud_and_ui(host: Control) -> void:
	var saved := [GameSettings.control_hints, GameSettings.hud_fade, GameSettings.quest_tracker_compact,
		GameSettings.window_mode, GameSettings.vsync, GameSettings.ui_scale_index, GameSettings.high_contrast, GameSettings.text_scale_index]

	# HUD: no always-visible key buttons; the corner menu stays hidden until the mouse moves.
	var hud := Hud.new()
	add_child(hud)
	await get_tree().process_frame
	var visible_key_buttons := 0
	for b in hud.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree() and (b as Button).text.contains("("):
			visible_key_buttons += 1
	check(visible_key_buttons == 0, "no always-visible key buttons in the HUD")
	check(hud._menu.modulate.a < 0.05 and not hud._menu.is_open(), "the mouse menu icon is hidden until the mouse moves")
	hud._menu._input(InputEventMouseMotion.new())
	for i in 30:
		hud._menu._process(0.05)
	check(hud._menu.modulate.a > 0.9, "moving the mouse shows the menu icon")
	var requested := []
	hud.journal_requested.connect(func() -> void: requested.append("journal"))
	hud._menu.icon.pressed.emit()
	check(hud._menu.is_open(), "the icon opens the small menu")
	for b in hud._menu.list.get_children():
		if b is Button and String(b.get_meta("label")) == "Journal":
			(b as Button).pressed.emit()
	check(requested == ["journal"] and not hud._menu.is_open(), "the menu opens the journal (mouse users still have a way in)")

	# Control hints follow the setting.
	GameSettings.control_hints = GameSettings.HINTS_NEVER
	hud._apply_interface_settings()
	check(not hud.show_key_hint("journal") and not hud.is_key_hint_visible() and not hud.is_hint_strip_visible(), "Never: no key hints")
	GameSettings.control_hints = GameSettings.HINTS_SOMETIMES
	hud._apply_interface_settings()
	check(hud.show_key_hint("journal") and hud.is_key_hint_visible() and hud._key_hint_label.text == "[J] Journal", "Sometimes: a brief contextual hint")
	check(not hud.is_hint_strip_visible(), "Sometimes: no permanent strip")
	GameSettings.control_hints = GameSettings.HINTS_ALWAYS
	hud._apply_interface_settings()
	check(hud.is_hint_strip_visible() and hud._hint_strip_label.text.contains("[H] Ask Lumi"), "Always: a small strip of keys")
	GameSettings.control_hints = GameSettings.HINTS_SOMETIMES
	hud._apply_interface_settings()

	# Toasts: pickups within 2 s are grouped; at most 2 toasts at a time.
	hud.show_pickup("pinecone", 5)
	hud.show_pickup("mushroom", 4)
	hud.show_pickup("pinecone", 1)
	var texts := hud.toast_texts()
	check(texts.size() == 1 and texts[0] == "+6 Pinecone, +4 Forest Mushroom", "pickups are grouped into one toast (%s)" % ", ".join(texts))
	hud.show_toast("Waystone discovered")
	hud.show_toast("Done: Fix the roof")
	hud.show_banner("Hearthstone found!")
	check(hud.toast_texts().size() == 2 and hud.toast_texts()[1] == "Hearthstone found!", "at most 2 toasts, the newest kept")
	hud._update_toasts(2.1)
	hud.show_pickup("branch", 2)
	check(hud.toast_texts().has("+2 Fallen Branch"), "a later pickup starts a new toast")

	# Region titles and toasts never cover the player.
	hud.show_region_title("Frostbloom Highlands", "Soft snow, frost flowers and the aurora")
	await get_tree().process_frame
	hud._layout()
	var player_rect := hud.player_screen_rect()
	check(not hud.region_card_rect().intersects(player_rect), "the region title stays above the player")
	check(not hud.toast_area_rect().intersects(player_rect), "toasts stay below the player")
	check(hud.region_card_rect().end.y <= hud.get_viewport().get_visible_rect().size.y / 3.0 + 1.0, "the region title is in the upper third")

	# The tracker fades while walking and returns on quest updates; the hotbar fades when unused.
	GameSettings.hud_fade = true
	hud.set_objective("Gather light")
	hud.set_moving(true)
	for i in 40:
		hud._update_fades(0.25)
	check(hud.tracker_alpha() < 0.7, "the tracker fades a little while walking")
	check(hud.hotbar_alpha() < 0.5, "the hotbar fades when unused")
	hud.set_progress("Light carried: 3")
	hud.select_hotbar(1)
	for i in 4:
		hud._update_fades(0.25)
	check(hud.tracker_alpha() > 0.95 and hud.hotbar_alpha() > 0.95, "a quest update and hotbar input bring them back")
	GameSettings.quest_tracker_compact = true
	hud._apply_interface_settings()
	check(not hud._progress_row.visible, "the tracker can collapse to the title")
	GameSettings.quest_tracker_compact = false
	hud._apply_interface_settings()
	hud.queue_free()

	# In-world fishing: keyboard, mouse and gamepad, in every mode, with a larger fallback bar.
	var spot := FishingSpot.new()
	spot.water = "pond"
	var pond_holder := Node2D.new()
	add_child(pond_holder)
	pond_holder.add_child(spot)
	for mode: StringName in [AdaptiveComfortEngine.MODE_GENTLE, AdaptiveComfortEngine.MODE_BALANCED, AdaptiveComfortEngine.MODE_PLAYFUL]:
		for device in ["keyboard", "mouse", "gamepad"]:
			var panel := FishingPanel.new()
			host.add_child(panel)
			panel.setup(spot, "whispering_meadow", mode)
			panel.skip_wait()
			if panel.stage != FishingPanel.Stage.BITE:
				check(false, "a fish bites (%s, %s)" % [mode, device])
				panel.close_panel()
				continue
			var ev: InputEvent
			match device:
				"keyboard":
					ev = InputEventAction.new()
					(ev as InputEventAction).action = InputSetup.INTERACT
					(ev as InputEventAction).pressed = true
					panel._unhandled_input(ev)
				"mouse":
					ev = InputEventMouseButton.new()
					(ev as InputEventMouseButton).button_index = MOUSE_BUTTON_LEFT
					(ev as InputEventMouseButton).pressed = true
					panel._on_view_input(ev)
				"gamepad":
					ev = InputEventJoypadButton.new()
					(ev as InputEventJoypadButton).button_index = JOY_BUTTON_A
					(ev as InputEventJoypadButton).pressed = true
					panel._unhandled_input(ev)
			var expected := FishingPanel.Stage.CAUGHT if mode == AdaptiveComfortEngine.MODE_GENTLE else FishingPanel.Stage.REEL
			check(panel.stage == expected, "fishing reacts to the %s in %s mode" % [device, mode])
			if panel.stage == FishingPanel.Stage.REEL:
				for i in 400:
					panel.fish_pos = panel.zone + panel.zone_width() / 2.0
					panel._reel_step(0.05, false)
					if panel.stage == FishingPanel.Stage.CAUGHT:
						break
				check(panel.stage == FishingPanel.Stage.CAUGHT, "the fish is caught, no fail state (%s, %s)" % [mode, device])
			if device == "keyboard":
				check(panel.bobber != null and panel.bobber.is_inside_tree() and not panel.get_children().any(func(c: Node) -> bool: return c is ColorRect), "the bobber is in the world and nothing dims it (%s)" % mode)
			panel.close_panel()
			await get_tree().process_frame
	GameSettings.high_contrast = true
	var large := FishingPanel.new()
	host.add_child(large)
	large.setup(spot, "whispering_meadow", AdaptiveComfortEngine.MODE_BALANCED)
	check(large.is_large() and large.bar_size() == FishingPanel.LARGE_BAR_SIZE, "High contrast uses the larger fishing bar")
	large.close_panel()
	GameSettings.high_contrast = saved[6]
	pond_holder.queue_free()

	# Main menu: Continue / Start / Settings / About / Data & Privacy / Quit, no disclaimer.
	var menu: Control = load("res://game/scenes/ui/main_menu.tscn").instantiate()
	host.add_child(menu)
	await get_tree().process_frame
	var menu_text := _all_label_text(menu)
	check(not menu_text.contains("not a medical"), "the disclaimer moved off the main menu")
	var order := PackedStringArray()
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).visible:
			order.append((b as Button).text)
	var expected_order := ["Start Adventure", "Settings", "About", "Data & Privacy", "Quit Game"]
	if SaveManager.most_recent_slot() > 0:
		expected_order.push_front("Continue")
	check(Array(order) == expected_order, "menu order: %s" % ", ".join(order))
	check(menu.find_children("*", "Wordmark", true, false).size() == 1, "the drawn CALMQUEST wordmark")
	menu.queue_free()
	var about: Control = load("res://game/scenes/ui/about.tscn").instantiate()
	host.add_child(about)
	await get_tree().process_frame
	var about_text := _all_label_text(about)
	check(about_text.contains("It is not a medical, diagnostic or therapeutic tool."), "the About screen shows the disclaimer")
	check(about_text.contains("Godot") and about_text.contains(SaveManager.GAME_VERSION), "About shows credits, licenses and the version")
	check(_find_button(about, "How to Play") != null, "How to Play is reachable from About")
	about.queue_free()
	check(UiTheme.custom_font_path() != "" or GameSettings.ui_theme.default_font == null, "without a font file the default font is used")

	# Display settings persist (and older settings files are migrated).
	GameSettings.set_setting("window_mode", GameSettings.BORDERLESS)
	GameSettings.set_setting("vsync", false)
	GameSettings.set_setting("ui_scale_index", 3)
	GameSettings.set_setting("control_hints", GameSettings.HINTS_ALWAYS)
	GameSettings.window_mode = GameSettings.WINDOWED
	GameSettings.vsync = true
	GameSettings.ui_scale_index = 1
	GameSettings.control_hints = GameSettings.HINTS_SOMETIMES
	GameSettings.load_settings()
	check(GameSettings.window_mode == GameSettings.BORDERLESS and not GameSettings.vsync and GameSettings.ui_scale_index == 3 and GameSettings.control_hints == GameSettings.HINTS_ALWAYS, "display and interface settings persist")
	check(is_equal_approx(get_tree().root.content_scale_factor, 1.3), "the interface scale is applied")
	var legacy := ConfigFile.new()
	legacy.set_value(GameSettings.SECTION, "fullscreen", true)
	legacy.save(TEST_SETTINGS)
	GameSettings.load_settings()
	check(GameSettings.window_mode == GameSettings.FULLSCREEN, "an older settings file with fullscreen on becomes Fullscreen")
	GameSettings.set_setting("window_mode", saved[3])
	GameSettings.set_setting("vsync", saved[4])
	GameSettings.set_setting("ui_scale_index", saved[5])
	GameSettings.control_hints = saved[0]
	GameSettings.hud_fade = saved[1]
	GameSettings.quest_tracker_compact = saved[2]
	GameSettings.text_scale_index = saved[7]

	# Every screen builds in Indonesian too.
	GameSettings.set_setting("language", "id")
	for scene in ["res://game/scenes/ui/main_menu.tscn", "res://game/scenes/ui/about.tscn", "res://game/scenes/ui/study_setup.tscn", "res://game/scenes/ui/check_in.tscn", "res://game/scenes/ui/slot_select.tscn"]:
		var screen: Control = load(scene).instantiate()
		host.add_child(screen)
		await get_tree().process_frame
		check(screen.is_inside_tree() and screen.get_child_count() > 0, "%s builds in Indonesian" % scene.get_file())
		screen.queue_free()
	for panel: Control in [SettingsPanel.new(), PrivacyPanel.new(), JournalPanel.new(), HowToPlayPanel.new(), MoodCheckCard.new(), ModeChoiceCard.new(), SessionClosingPanel.new()]:
		host.add_child(panel)
		await get_tree().process_frame
		var heading := panel.find_children("*", "Label", true, false)
		check(panel.get_child_count() > 0 and not heading.is_empty(), "%s builds in Indonesian" % panel.get_script().get_global_name())
		panel.queue_free()
	var hud_id := Hud.new()
	add_child(hud_id)
	await get_tree().process_frame
	hud_id.show_pickup("pinecone", 2)
	check(hud_id.toast_texts()[0] == "+2 Buah Pinus", "toasts are translated")
	hud_id.queue_free()
	GameSettings.set_setting("language", "en")
	await get_tree().process_frame


## 0.4.0 P5: rest spots (sit and stand with keyboard, mouse and gamepad; the
## HUD hides and returns; Lumi; the camera; time passing) and "Breathe with
## Lumi" from a rest spot and from the pause menu.
func _check_rest_and_breathe(host: Control) -> void:
	get_tree().paused = false
	var rest_state := GameState.system_state(RestSpots.STATE_KEY)
	var saved_rest := rest_state.duplicate(true)
	var old_lapse := GameSettings.rest_time_passes
	rest_state.clear()
	SessionState.begin_session(null, AdaptiveComfortEngine.MODE_BALANCED, false)
	var world: Overworld = load("res://game/scenes/world/overworld.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	world.features.wildlife.enabled = false
	var spots := get_tree().get_nodes_in_group(RestSpot.GROUP_NAME)
	check(spots.size() == RestSpots.ids().size(), "every rest spot is in the world or its cave (%d)" % spots.size())
	var spot: RestSpot = null
	for n in spots:
		if (n as RestSpot).spot_id == "rest_village_bench":
			spot = n
	check(spot != null, "the village bench is placed")
	if spot == null:
		world.queue_free()
		return
	# Coming near marks it as found (map and journal).
	world.teleport_to(spot.global_position + Vector2(0, 150))
	await get_tree().create_timer(RestController.DISCOVER_INTERVAL + 0.3).timeout
	check(RestSpots.is_found(spot.spot_id), "coming near a quiet place marks it as found")
	var journal := JournalPanel.new()
	host.add_child(journal)
	await get_tree().process_frame
	var quiet := journal.tabs.get_node_or_null("Quiet places")
	check(quiet != null and _all_label_text(quiet).contains(spot.display_name()), "the journal lists it under Quiet places")
	journal.queue_free()
	# Keyboard: E sits down.
	world.teleport_to(spot.global_position + Vector2(0, 34))
	await get_tree().process_frame
	world.player.update_target()
	check(world.player.current_target == spot, "the seat is the player's target")
	check(spot.get_prompt() == "Sit and rest", "[E] Sit and rest")
	_press(InputSetup.INTERACT)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.rest.is_resting() and world.player.sitting and not world.player.input_enabled, "E sits down")
	check(world.player.global_position.distance_to(spot.seat_point()) < 1.0, "on the seat")
	check(world.lumi.is_resting(), "Lumi curls up nearby")
	check(world.camera.override_zoom > 0.0, "the camera widens toward the view")
	await get_tree().create_timer(1.8).timeout
	check(world.hud.items_alpha() < 0.05, "the HUD fades out completely")
	check(world.lumi.curl_amount() > 0.5, "Lumi is curled up")
	check(AudioManager.rest_boost > 0.3, "the music and ambience swell a little")
	# E while resting: Breathe with Lumi; any key stops it and the rest goes on.
	_press(InputSetup.INTERACT)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world._overlay is BreathePanel, "E opens Breathe with Lumi at the rest spot")
	if world._overlay is BreathePanel:
		var panel := world._overlay as BreathePanel
		check(_all_label_text(panel).contains(BreathePanel.NOTE), "the panel says to breathe comfortably and stop if anything feels uncomfortable")
		panel.begin_breathing()
		await get_tree().create_timer(BreathePanel.SETTLE_SECONDS + 0.5).timeout
		check(panel.running and panel._cue.text == "Breathe in...", "Breathe in...")
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame
		var key_up := key.duplicate() as InputEventKey
		key_up.pressed = false
		Input.parse_input_event(key_up)
		await get_tree().process_frame
	check(world._overlay == null and not get_tree().paused and world.rest.is_resting(), "any key stops breathing; the rest goes on")
	# Watch time pass while resting.
	GameSettings.rest_time_passes = true
	var before := TimeManager.day * 1440.0 + TimeManager.minute_of_day
	await get_tree().create_timer(1.0).timeout
	var passed := TimeManager.day * 1440.0 + TimeManager.minute_of_day - before
	check(passed >= RestController.TIME_LAPSE * 0.7, "Watch time pass while resting: the clock runs faster (%.1f min in 1 s)" % passed)
	GameSettings.rest_time_passes = false
	# Keyboard: a movement key stands up.
	var seat := world.player.global_position
	_press(InputSetup.MOVE_LEFT)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not world.rest.is_resting() and not world.player.sitting and world.player.input_enabled, "a movement key stands up")
	check(world.player.global_position.distance_to(seat) < 30.0, "right where the seat is")
	await get_tree().create_timer(0.9).timeout
	check(world.hud.items_alpha() > 0.95, "the HUD comes back")
	check(not world.lumi.is_resting() and world.camera.override_zoom == 0.0 and AudioManager.rest_boost < 0.7, "Lumi follows again, the camera and the music return")
	# Keyboard: Esc stands up (and does not open the pause menu).
	spot.interact()
	await get_tree().process_frame
	_press(InputSetup.PAUSE)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not world.rest.is_resting() and not world._modal_open, "Esc stands up without opening the pause menu")
	# Gamepad: B (cancel) and the stick stand up; A sits down. (After standing,
	# input waits 0.2 s so the same press cannot sit down again at once.)
	world.teleport_to(spot.global_position + Vector2(0, 34))
	await get_tree().create_timer(0.3).timeout
	world.player.update_target()
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	Input.parse_input_event(pad_a)
	await get_tree().process_frame
	await get_tree().process_frame
	check(world.rest.is_resting(), "gamepad A sits down")
	var pad_b := InputEventJoypadButton.new()
	pad_b.button_index = JOY_BUTTON_B
	pad_b.pressed = true
	Input.parse_input_event(pad_b)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not world.rest.is_resting(), "gamepad B (the Run button) stands up")
	for e in [pad_a, pad_b]:
		var up := (e as InputEventJoypadButton).duplicate() as InputEventJoypadButton
		up.pressed = false
		Input.parse_input_event(up)
	await get_tree().process_frame
	spot.interact()
	await get_tree().process_frame
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	world._unhandled_input(stick)
	check(not world.rest.is_resting(), "moving the gamepad stick stands up")
	# Mouse: clicking the seat sits down; the Stand up button stands up.
	world.teleport_to(spot.global_position + Vector2(0, 34))
	await get_tree().process_frame
	world.player.update_target()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world.get_viewport().get_canvas_transform() * spot.get_interaction_point()
	world._unhandled_input(click)
	check(world.rest.is_resting(), "clicking the seat sits down")
	world._unhandled_input(InputEventMouseMotion.new())
	for i in 20:
		world.rest.overlay._process(0.05)
	check(world.rest.overlay.controls_visible(), "moving the mouse shows the rest controls")
	world.rest.overlay.stand_button.pressed.emit()
	await get_tree().process_frame
	check(not world.rest.is_resting(), "the Stand up button stands up")
	# The pause menu also offers Breathe with Lumi.
	world._open_pause()
	world.pause_menu.breathe_requested.emit()
	await get_tree().process_frame
	check(world._overlay is BreathePanel and not world.pause_menu.visible, "Breathe with Lumi from the pause menu")
	if world._overlay is BreathePanel:
		(world._overlay as BreathePanel).close_panel()
		await get_tree().process_frame
	check(not world._modal_open and not get_tree().paused, "Back returns to the world")
	world.queue_free()
	await get_tree().process_frame
	rest_state.clear()
	rest_state.merge(saved_rest)
	GameSettings.rest_time_passes = old_lapse
	get_tree().paused = false


## Sends a pressed-and-released action through the real input path.
func _press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


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
