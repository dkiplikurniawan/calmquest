class_name PauseMenu
extends CanvasLayer
## Pause menu. The world pauses the tree while this is open; this layer keeps
## processing (PROCESS_MODE_ALWAYS) so its buttons work.
## It reports choices through signals; the world applies them.

signal resume_requested
signal restart_requested
signal finish_requested
signal main_menu_requested
signal mode_requested(mode_id: StringName)
signal guidance_toggled(enabled: bool)
signal save_requested
signal load_requested(slot: int)

var _root: Control
var _mode_buttons: Dictionary = {}
var _mode_description: Label
var _guidance_check: CheckBox
var _storage_note: Label
var _resume_button: Button


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	UiKit.adopt_theme(_root)
	UiKit.overlay(_root)
	var box := UiKit.centered_panel(_root, 640)
	box.add_child(UiKit.label("Paused", UiTheme.HEADING))
	_resume_button = UiKit.button("Resume", func() -> void: resume_requested.emit(), UiTheme.PRIMARY_BUTTON)
	box.add_child(_resume_button)

	box.add_child(UiKit.label("Comfort mode (changes apply right away, progress is kept)", UiTheme.SUBTLE, true))
	var group := ButtonGroup.new()
	var row := HBoxContainer.new()
	for mode_id in AdaptiveComfortEngine.ALL_MODES:
		var preset := AdaptiveComfortEngine.build_preset(mode_id)
		var b := UiKit.button(preset.display_name, func() -> void: mode_requested.emit(mode_id), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_mode_buttons[mode_id] = b
	box.add_child(row)
	_mode_description = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_mode_description)
	_guidance_check = CheckBox.new()
	_guidance_check.text = "Guiding glow toward the nearest light"
	_guidance_check.toggled.connect(func(on: bool) -> void: guidance_toggled.emit(on))
	UiKit.wire_feedback(_guidance_check)
	box.add_child(_guidance_check)
	box.add_child(HSeparator.new())

	var settings := UiKit.button("Settings", _open_settings)
	var restart := UiKit.button("Restart Session", func() -> void:
		UiKit.confirm(_root, "Restart this session? Lights and garden progress in the meadow will reset. Your check-in answers and mode are kept.", "Restart", func() -> void: restart_requested.emit()))
	box.add_child(UiKit.hbox([settings, restart]))
	var save := UiKit.button("Save", func() -> void: save_requested.emit())
	var load := UiKit.button("Load", _open_load)
	box.add_child(UiKit.hbox([save, load]))
	var finish := UiKit.button("Finish Session", func() -> void: finish_requested.emit())
	var menu := UiKit.button("Main Menu", func() -> void:
		UiKit.confirm(_root, _main_menu_warning(), "Leave", func() -> void: main_menu_requested.emit()))
	box.add_child(UiKit.hbox([finish, menu]))
	_storage_note = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_storage_note)
	visible = false


func open(mode_id: StringName, guidance_on: bool) -> void:
	visible = true
	sync(mode_id, guidance_on)
	_storage_note.text = L.t("Session data: %s") % (L.t("saved on this device when the session ends (you agreed)") if SessionState.consent_to_store else L.t("not saved (you did not opt in)"))
	_resume_button.call_deferred("grab_focus")


func sync(mode_id: StringName, guidance_on: bool) -> void:
	for id: StringName in _mode_buttons:
		(_mode_buttons[id] as Button).set_pressed_no_signal(id == mode_id)
	_mode_description.text = AdaptiveComfortEngine.build_preset(mode_id).description
	_guidance_check.set_pressed_no_signal(guidance_on)


func set_status(text: String) -> void:
	_storage_note.text = text


func close() -> void:
	visible = false
	for child in _root.get_children():
		if child is SettingsPanel or child is UiKit.ConfirmLayer or child.has_meta("load_panel"):
			child.queue_free()


func _open_load() -> void:
	var layer := UiKit.ConfirmLayer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.set_meta("load_panel", true)
	_root.add_child(layer)
	UiKit.overlay(layer)
	var box := UiKit.centered_panel(layer, 760)
	box.add_child(UiKit.label("Load a journey", UiTheme.HEADING))
	box.add_child(UiKit.label("Your current journey is saved first, so nothing is lost.", UiTheme.SUBTLE, true))
	var list := SlotList.new()
	list.allow_new = false
	list.confirm_parent = layer
	list.slot_chosen.connect(func(slot: int, _new: bool) -> void:
		layer.queue_free()
		load_requested.emit(slot))
	box.add_child(list)
	list.build()
	var cancel := UiKit.button("Cancel", layer.queue_free)
	box.add_child(cancel)
	var first := list.first_button()
	(first if first != null else cancel).call_deferred("grab_focus")


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	_root.add_child(panel)
	panel.closed.connect(func() -> void: _resume_button.grab_focus())


func _main_menu_warning() -> String:
	if SessionState.consent_to_store:
		return "Return to the main menu? This session will end. Because you agreed to local storage, an incomplete session record (without an after-play reflection) will be saved."
	return "Return to the main menu? This session will end and meadow progress from this session will be lost. Nothing is stored."


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputSetup.PAUSE) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
