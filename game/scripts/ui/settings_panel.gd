class_name SettingsPanel
extends Control
## Settings overlay (used from the main menu and the pause menu).
## Every control changes a real setting through GameSettings, which applies and
## saves it immediately. Escape or "Back" closes the panel.

signal closed

const REGION_TITLE_NAMES: PackedStringArray = ["First visit only", "Every visit", "Off"]
const DAY_LENGTHS: Array[int] = [15, 20, 24]
const TIME_MODE_NAMES: PackedStringArray = ["Normal day and night", "Keep it day", "Keep it night"]
const GENTLE_CLOCK_NAMES: PackedStringArray = ["Normal speed", "Half speed", "Paused"]

var _value_labels: Dictionary = {}
var _language_button: Button
var _mood_button: Button
var _window_mode_button: Button
var _ui_scale_button: Button
var _hints_button: Button
var _window_button: Button
var _text_button: Button
var _titles_button: Button
var _time_buttons: Array[Button] = []
var _music_mode_button: Button
var _hint_button: Button
var _bind_buttons: Dictionary = {}
var _bind_status: Label
## The action waiting for a new key (empty when not listening).
var listening_action: StringName = &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 640)
	box.add_child(UiKit.label("Settings", UiTheme.HEADING))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	list.add_child(UiKit.label("Language", UiTheme.SUBTLE))
	_language_button = UiKit.button("", _cycle_language)
	list.add_child(_language_button)
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Well-being", UiTheme.SUBTLE))
	_mood_button = UiKit.button("", _toggle_mood_check)
	list.add_child(_mood_button)
	list.add_child(_check("Show session summary when I leave", "session_summary"))
	list.add_child(_check("Keep a private mood journal on this device", "mood_journal"))
	list.add_child(UiKit.label("All of this is optional, stays on this device and is never a measurement. The journal can be deleted any time in Data & Privacy.", UiTheme.SUBTLE, true))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Audio", UiTheme.SUBTLE))
	list.add_child(_volume_row("Master volume", "master_volume"))
	list.add_child(_volume_row("Music", "music_volume"))
	list.add_child(_volume_row("Ambience", "ambience_volume"))
	list.add_child(_volume_row("Sound effects", "sfx_volume"))
	list.add_child(_volume_row("Interface sounds", "ui_volume"))
	_music_mode_button = UiKit.button("", _cycle_music_mode)
	list.add_child(_music_mode_button)
	list.add_child(UiKit.label("The music is designed to support a calm atmosphere. The current tracks are synthesized placeholders made from the game's own MIDI scores.", UiTheme.SUBTLE, true))
	list.add_child(_check("Footsteps", "footsteps"))
	list.add_child(_check("Captions for important sounds", "captions"))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Display", UiTheme.SUBTLE))
	_window_mode_button = UiKit.button("", func() -> void: _cycle("window_mode", GameSettings.WINDOW_MODE_NAMES.size()))
	list.add_child(_window_mode_button)
	_window_button = UiKit.button("", _cycle_window_size)
	list.add_child(_window_button)
	list.add_child(_check("VSync (smoother motion, steadier frame rate)", "vsync"))
	_ui_scale_button = UiKit.button("", func() -> void: _cycle("ui_scale_index", GameSettings.UI_SCALES.size()))
	list.add_child(_ui_scale_button)
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Interface", UiTheme.SUBTLE))
	_hints_button = UiKit.button("", func() -> void: _cycle("control_hints", GameSettings.CONTROL_HINT_NAMES.size()))
	list.add_child(_hints_button)
	list.add_child(_check("Fade the quest tracker while walking and the hotbar when unused", "hud_fade"))
	list.add_child(_check("Quest tracker: show only the quest title", "quest_tracker_compact"))
	list.add_child(UiKit.label("Mouse: move the mouse to show the menu icon in the top-right corner.", UiTheme.SUBTLE, true))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Readability", UiTheme.SUBTLE))
	_text_button = UiKit.button("", _cycle_text_size)
	list.add_child(_text_button)
	list.add_child(_check("High contrast interface", "high_contrast"))
	list.add_child(_check("Reduce motion (calmer animations and transitions)", "reduce_motion"))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Exploring", UiTheme.SUBTLE))
	list.add_child(_check("Run by pressing Shift once (instead of holding it)", "run_toggle"))
	list.add_child(_check("Reduced camera motion (no look-ahead or zoom changes)", "reduced_camera_motion"))
	list.add_child(_check("Show minimap", "show_minimap"))
	list.add_child(_check("Show the quest direction compass", "show_compass"))
	_titles_button = UiKit.button("", _cycle_region_titles)
	list.add_child(_titles_button)
	list.add_child(_check("Weather effects (rain, clouds, mist); crops are still watered when off", "weather_effects"))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Time of day (night is always safe)", UiTheme.SUBTLE))
	for spec: Array in [["day_length_minutes", "Day length"], ["time_mode", "Time"], ["gentle_clock", "Clock in Gentle mode"], ["autosave_minutes", "Autosave"]]:
		var key: String = spec[0]
		var b := UiKit.button("", func() -> void: _cycle_time(key))
		b.set_meta("key", key)
		b.set_meta("title", spec[1])
		list.add_child(b)
		_time_buttons.append(b)
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Gameplay assistance", UiTheme.SUBTLE))
	list.add_child(_check("Lumi's occasional comments (hints on request always work)", "lumi_chatter"))
	list.add_child(_check("Automatic assistance (guiding glow after repeated hints, reach tips)", "adaptive_assistance"))
	_hint_button = UiKit.button("", _cycle_hint_frequency)
	list.add_child(_hint_button)
	list.add_child(UiKit.label("Gameplay modes (Gentle, Balanced, Playful) can be changed any time from the pause menu.", UiTheme.SUBTLE, true))
	list.add_child(HSeparator.new())

	list.add_child(UiKit.label("Controls", UiTheme.SUBTLE))
	list.add_child(UiKit.label("Click an action, then press the new key. A gamepad works too: left stick to move, A interact, B run or back, X bag, Y ask Lumi, Start pause, LB/RB hotbar.", UiTheme.SUBTLE, true))
	for action in InputSetup.REMAPPABLE:
		var b := UiKit.button("", func() -> void: _listen(action))
		list.add_child(b)
		_bind_buttons[action] = b
	_bind_status = UiKit.label("", UiTheme.SUBTLE, true)
	list.add_child(_bind_status)
	list.add_child(UiKit.button("Reset controls to defaults", func() -> void:
		GameSettings.reset_bindings()
		_bind_status.text = "Controls reset."
		_refresh_bindings()))

	var back := UiKit.button("Back", close, UiTheme.PRIMARY_BUTTON)
	box.add_child(back)
	_refresh_cycle_buttons()
	back.call_deferred("grab_focus")


func close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	# While waiting for a new key, the next key press is the binding (Esc cancels).
	if listening_action == &"" or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	var code := key.physical_keycode if key.physical_keycode != 0 else key.keycode
	if code == KEY_ESCAPE:
		_bind_status.text = "Unchanged."
	else:
		var clash := GameSettings.rebind(listening_action, code)
		_bind_status.text = L.t("%s is now %s.%s") % [L.t(String(InputSetup.ACTION_NAMES.get(listening_action, listening_action))), InputSetup.key_name(code), L.t(" (Also used by %s.)") % clash if not clash.is_empty() else ""]
	listening_action = &""
	_refresh_bindings()


func _listen(action: StringName) -> void:
	listening_action = action
	_bind_status.text = L.t("Press a key for %s (Esc to cancel)...") % L.t(String(InputSetup.ACTION_NAMES.get(action, action)))
	(_bind_buttons[action] as Button).text = L.t("%s: ...press a key...") % L.t(String(InputSetup.ACTION_NAMES.get(action, action)))


func _refresh_bindings() -> void:
	for action: StringName in _bind_buttons:
		(_bind_buttons[action] as Button).text = "%s: %s" % [L.t(String(InputSetup.ACTION_NAMES.get(action, action))), InputSetup.key_name(InputSetup.primary_key(action))]


func _cycle_music_mode() -> void:
	GameSettings.set_setting("music_mode", (GameSettings.music_mode + 1) % GameSettings.MUSIC_MODE_NAMES.size())
	_refresh_cycle_buttons()


func _cycle_hint_frequency() -> void:
	var next := GameSettings.hint_frequency + 1
	GameSettings.set_setting("hint_frequency", -1 if next > 3 else next)
	_refresh_cycle_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _volume_row(title: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var name_label := UiKit.label(title)
	name_label.custom_minimum_size.x = 220
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(GameSettings.get(key)) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value_label := UiKit.label("%d%%" % int(slider.value))
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_value_labels[key] = value_label
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v)
		GameSettings.set_setting(key, v / 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void: AudioManager.play(&"collect"))
	return row


func _check(title: String, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = title
	c.button_pressed = bool(GameSettings.get(key))
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.toggled.connect(func(on: bool) -> void:
		GameSettings.set_setting(key, on)
		_refresh_cycle_buttons())
	UiKit.wire_feedback(c)
	return c


func _cycle_window_size() -> void:
	var next := (GameSettings.window_size_index + 1) % GameSettings.WINDOW_SIZES.size()
	GameSettings.set_setting("window_size_index", next)
	_refresh_cycle_buttons()


func _cycle_text_size() -> void:
	var next := (GameSettings.text_scale_index + 1) % UiTheme.TEXT_SCALES.size()
	GameSettings.set_setting("text_scale_index", next)
	_refresh_cycle_buttons()


func _cycle_time(key: String) -> void:
	match key:
		"day_length_minutes":
			var i := DAY_LENGTHS.find(GameSettings.day_length_minutes)
			GameSettings.set_setting(key, DAY_LENGTHS[(i + 1) % DAY_LENGTHS.size()])
		"time_mode":
			GameSettings.set_setting(key, (GameSettings.time_mode + 1) % 3)
		"gentle_clock":
			GameSettings.set_setting(key, (GameSettings.gentle_clock + 1) % 3)
		"autosave_minutes":
			var options: Array[int] = [3, 5, 10, 0]
			var i := options.find(GameSettings.autosave_minutes)
			GameSettings.set_setting(key, options[(i + 1) % options.size()])
	_refresh_cycle_buttons()


## English <-> Bahasa Indonesia. Labels update at once; composed texts are rebuilt here.
func _cycle_language() -> void:
	var i := L.ORDER.find(GameSettings.language)
	GameSettings.set_setting("language", L.ORDER[(i + 1) % L.ORDER.size()])
	_refresh_cycle_buttons()


## Cycles an integer setting through 0..count-1.
func _cycle(key: String, count: int) -> void:
	GameSettings.set_setting(key, (int(GameSettings.get(key)) + 1) % count)
	_refresh_cycle_buttons()


func _toggle_mood_check() -> void:
	GameSettings.set_setting("mood_check", not GameSettings.mood_check)
	_refresh_cycle_buttons()


func _cycle_region_titles() -> void:
	GameSettings.set_setting("region_titles", (GameSettings.region_titles + 1) % REGION_TITLE_NAMES.size())
	_refresh_cycle_buttons()


func _refresh_cycle_buttons() -> void:
	if _window_button == null or _text_button == null or _titles_button == null or _music_mode_button == null or _hint_button == null or _hints_button == null:
		return
	_language_button.text = L.t("Language / Bahasa: %s  (click to change)") % L.LANGUAGES[L.current()]
	_mood_button.text = L.t("Mood check when I start playing: %s  (click to change)") % (L.t("Ask") if GameSettings.mood_check else L.t("Don't ask"))
	_titles_button.text = L.t("Region titles: %s  (click to change)") % L.t(REGION_TITLE_NAMES[GameSettings.region_titles])
	for b in _time_buttons:
		var value := ""
		match String(b.get_meta("key")):
			"day_length_minutes":
				value = L.t("%d real minutes") % GameSettings.day_length_minutes
			"time_mode":
				value = L.t(TIME_MODE_NAMES[GameSettings.time_mode])
			"gentle_clock":
				value = L.t(GENTLE_CLOCK_NAMES[GameSettings.gentle_clock])
			"autosave_minutes":
				value = L.t("every %d minutes") % GameSettings.autosave_minutes if GameSettings.autosave_minutes > 0 else L.t("only when sleeping, travelling and finishing quests")
		b.text = L.t("%s: %s  (click to change)") % [L.t(String(b.get_meta("title"))), value]
	var s: Vector2i = GameSettings.WINDOW_SIZES[GameSettings.window_size_index]
	_window_button.text = L.t("Window size: %d x %d  (click to change)") % [s.x, s.y]
	_window_button.disabled = GameSettings.window_mode != GameSettings.WINDOWED
	_window_mode_button.text = L.t("Window: %s  (click to change)") % L.t(GameSettings.WINDOW_MODE_NAMES[GameSettings.window_mode])
	_ui_scale_button.text = L.t("Interface scale: %d%%  (click to change)") % int(round(GameSettings.ui_scale() * 100.0))
	_hints_button.text = L.t("Show control hints: %s  (click to change)") % L.t(GameSettings.CONTROL_HINT_NAMES[GameSettings.control_hints])
	_text_button.text = L.t("Text size: %s  (click to change)") % L.t(UiTheme.TEXT_SCALE_NAMES[GameSettings.text_scale_index])
	_music_mode_button.text = L.t("Music: %s  (click to change)") % L.t(GameSettings.MUSIC_MODE_NAMES[GameSettings.music_mode])
	var hint_name := L.t("By mode (Gentle: Helpful, Balanced: Normal, Playful: Rare)") if GameSettings.hint_frequency < 0 else L.t(GameSettings.HINT_FREQUENCY_NAMES[GameSettings.hint_frequency])
	_hint_button.text = L.t("Lumi's nudges toward your quest: %s  (H always works)") % hint_name
	_refresh_bindings()
