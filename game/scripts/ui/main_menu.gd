extends Control
## Main menu: Start Adventure, How to Play, Settings, Data & Privacy, Quit.

var _buttons: VBoxContainer
var _first_button: Button
var _status: Label


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
	SceneRouter.go_to(SceneRouter.CHECK_IN)


func _quit() -> void:
	get_tree().quit()
