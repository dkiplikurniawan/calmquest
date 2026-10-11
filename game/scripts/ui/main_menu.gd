extends Control
## Main menu: Start Adventure, How to Play, Settings, Data & Privacy, Quit.

## Clicks on the version label within this many seconds count toward the unlock.
const UNLOCK_WINDOW_SECONDS := 4.0

var _buttons: VBoxContainer
var _first_button: Button
var _status: Label
var version_label: Label
var study_badge: Label
var _version_clicks: int = 0
var _first_click_msec: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size.x = 420
	center.add_child(column)

	var title := UiKit.label("CALMQUEST", UiTheme.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiKit.label("The Lost Light", UiTheme.LIGHT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(UiKit.spacer(18))

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_buttons)
	_first_button = UiKit.button("Start Adventure", _start, UiTheme.PRIMARY_BUTTON)
	_buttons.add_child(_first_button)
	_buttons.add_child(UiKit.button("How to Play", func() -> void: _open_overlay(HowToPlayPanel.new())))
	_buttons.add_child(UiKit.button("Settings", func() -> void: _open_overlay(SettingsPanel.new())))
	_buttons.add_child(UiKit.button("Data & Privacy", func() -> void: _open_overlay(PrivacyPanel.new())))
	if not OS.has_feature("web"):
		_buttons.add_child(UiKit.button("Quit Game", _quit))

	column.add_child(UiKit.spacer(10))
	_status = UiKit.label("", UiTheme.LIGHT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_status)
	_show_last_save_status()

	var footer := UiKit.label("A cozy, well-being-oriented game prototype. It is not a medical, diagnostic or therapeutic tool.", UiTheme.LIGHT, true)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -56
	footer.offset_bottom = -16
	footer.add_theme_font_size_override("font_size", int(15 * GameSettings.get_text_scale()))
	add_child(footer)

	# A tiny version label. Clicking it 7 times opens the Study Mode unlock.
	version_label = UiKit.label("v" + SaveManager.GAME_VERSION, UiTheme.LIGHT)
	version_label.add_theme_font_size_override("font_size", int(13 * GameSettings.get_text_scale()))
	version_label.modulate.a = 0.6
	version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version_label.offset_right = -12
	version_label.offset_bottom = -8
	version_label.gui_input.connect(_on_version_input)
	add_child(version_label)
	study_badge = UiKit.label("Study Mode", UiTheme.LIGHT)
	study_badge.position = Vector2(16, 12)
	study_badge.add_theme_font_size_override("font_size", int(15 * GameSettings.get_text_scale()))
	add_child(study_badge)
	_refresh_study_badge()
	MusicManager.request_cue("lumeria_theme", true)
	MusicManager.request_ambience("")
	_first_button.call_deferred("grab_focus")


## Reports the outcome of a session that ended by leaving to the menu.
func _show_last_save_status() -> void:
	var result: Dictionary = SessionState.last_save_result
	if result.is_empty():
		return
	if result.get("saved", false):
		_status.text = "Your incomplete session record was saved on this device."
	elif not result.get("ok", true):
		_status.text = L.t("The session record could not be saved: %s") % result.get("message", "")
	SessionState.last_save_result = {}


func _open_overlay(panel: Control) -> void:
	add_child(panel)
	_buttons.visible = false
	panel.tree_exited.connect(func() -> void:
		if is_inside_tree():
			_buttons.visible = true
			_first_button.grab_focus())


func _start() -> void:
	SceneRouter.go_to(start_target())


## Start Adventure goes straight to the journeys; in Study Mode to the setup.
static func start_target() -> String:
	return SceneRouter.STUDY_SETUP if StudyMode.is_active() else SceneRouter.SLOT_SELECT


func _refresh_study_badge() -> void:
	study_badge.visible = StudyMode.is_active()


func _on_version_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		register_version_click(Time.get_ticks_msec())


## Counts clicks on the version label; the 7th quick click opens the unlock.
func register_version_click(now_msec: int) -> bool:
	if _version_clicks == 0 or now_msec - _first_click_msec > UNLOCK_WINDOW_SECONDS * 1000.0:
		_version_clicks = 0
		_first_click_msec = now_msec
	_version_clicks += 1
	if _version_clicks >= StudyMode.UNLOCK_CLICKS:
		_version_clicks = 0
		open_unlock_dialog()
		return true
	return false


## The small "study unlock phrase" dialog.
func open_unlock_dialog() -> Control:
	var layer := UiKit.ConfirmLayer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.set_meta("unlock_dialog", true)
	add_child(layer)
	UiKit.overlay(layer)
	var box := UiKit.centered_panel(layer, 460)
	box.add_child(UiKit.label("Study unlock", UiTheme.HEADING))
	box.add_child(UiKit.label("Enter the study unlock phrase.", UiTheme.SUBTLE, true))
	var edit := LineEdit.new()
	edit.custom_minimum_size.y = 44
	box.add_child(edit)
	var message := UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(message)
	var submit := func() -> void:
		if StudyMode.try_unlock(edit.text):
			layer.queue_free()
			_refresh_study_badge()
			_status.text = "Study Mode is on."
		else:
			message.text = "That phrase is not right."
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	var cancel := UiKit.button("Cancel", layer.queue_free)
	var ok := UiKit.button("Unlock", submit, UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([cancel, ok]))
	edit.call_deferred("grab_focus")
	return layer


func _quit() -> void:
	get_tree().quit()
