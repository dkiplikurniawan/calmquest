extends Control
## Study setup (Study Mode only): participant code, session length and
## language, then the existing check-in. See docs/STUDY_MODE.md.

var code_edit: LineEdit
var error_label: Label
var duration_buttons: Dictionary = {}
var language_buttons: Dictionary = {}
var _duration: int = StudyMode.DEFAULT_DURATION
var _language: String = StudyMode.DEFAULT_LANGUAGE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var box := UiKit.centered_panel(self, 700)
	box.add_child(UiKit.label("Study setup", UiTheme.HEADING))
	box.add_child(UiKit.label("For the researcher. Each session starts from the same fresh world and never touches the player's journeys.", UiTheme.SUBTLE, true))

	box.add_child(UiKit.label("Participant code (P01 to P999)", &"", true))
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "P01"
	code_edit.max_length = 4
	code_edit.custom_minimum_size.y = 48
	if not StudyMode.participant_code.is_empty():
		code_edit.text = StudyMode.participant_code
	code_edit.text_submitted.connect(func(_t: String) -> void: _start())
	box.add_child(code_edit)
	error_label = UiKit.label("", UiTheme.SUBTLE, true)
	error_label.add_theme_color_override("font_color", Color("#9b2c2c"))
	box.add_child(error_label)

	box.add_child(UiKit.label("Session length", &"", true))
	var durations := HBoxContainer.new()
	var dgroup := ButtonGroup.new()
	for minutes in StudyMode.DURATIONS:
		var b := UiKit.button(L.t("%d minutes") % minutes, func() -> void: _set_duration(minutes), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = dgroup
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		durations.add_child(b)
		duration_buttons[minutes] = b
	box.add_child(durations)

	box.add_child(UiKit.label("Language", &"", true))
	var languages := HBoxContainer.new()
	var lgroup := ButtonGroup.new()
	for code in ["id", "en"]:
		var b := UiKit.button(String(L.LANGUAGES[code]), func() -> void: _set_language(code), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = lgroup
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		languages.add_child(b)
		language_buttons[code] = b
	box.add_child(languages)

	var back := UiKit.button("Main Menu", func() -> void: SceneRouter.go_to(SceneRouter.MAIN_MENU))
	var start := UiKit.button("Start session", _start, UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([back, start]))
	_set_duration(StudyMode.duration_minutes)
	_set_language(StudyMode.language)
	code_edit.call_deferred("grab_focus")


func _set_duration(minutes: int) -> void:
	_duration = minutes
	for m: int in duration_buttons:
		(duration_buttons[m] as Button).set_pressed_no_signal(m == minutes)


func _set_language(code: String) -> void:
	_language = code
	for c: String in language_buttons:
		(language_buttons[c] as Button).set_pressed_no_signal(c == code)


## Validates the setup; returns "" when the session can start.
func validate() -> String:
	return StudyMode.configure(code_edit.text, _duration, _language)


func _start() -> void:
	var problem := validate()
	if not problem.is_empty():
		error_label.text = problem
		code_edit.grab_focus()
		return
	error_label.text = ""
	SceneRouter.go_to(SceneRouter.CHECK_IN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		SceneRouter.go_to(SceneRouter.MAIN_MENU)
