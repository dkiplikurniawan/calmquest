extends Control
## Pre-game check-in (Study Mode): optional 0-10 self-report, a transparent
## mode suggestion the player can override, and an explicit (unticked by
## default) consent box. Skipping is always possible and never blocks the game.
## Unchanged from V1; only where it leads changed (the study journey).

var _slider: StressSlider
var _recommendation: Label
var _mode_buttons: Dictionary = {}
var _mode_description: Label
var _consent: CheckBox
var _selected_mode: StringName = AdaptiveComfortEngine.DEFAULT_MODE
var _mode_chosen_by_player: bool = false
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 780
	center.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	panel.add_child(_content)

	_content.add_child(UiKit.label("How are you feeling today?", UiTheme.HEADING))
	_content.add_child(UiKit.label("An optional, private reflection. It is not a test or a diagnosis, and there are no right or wrong answers.", UiTheme.SUBTLE, true))
	_slider = StressSlider.new("Right now, how stressed do you feel? (0-10)")
	_slider.answered.connect(_on_answered)
	_content.add_child(_slider)
	_recommendation = UiKit.label("", &"", true)
	_content.add_child(_recommendation)
	_content.add_child(HSeparator.new())

	_content.add_child(UiKit.label("Choose how the meadow feels (you can change this any time from the pause menu):", &"", true))
	var group := ButtonGroup.new()
	var row := HBoxContainer.new()
	for mode_id in AdaptiveComfortEngine.ALL_MODES:
		var preset := AdaptiveComfortEngine.build_preset(mode_id)
		var b := UiKit.button(preset.display_name, func() -> void: _choose_mode(mode_id, true), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_mode_buttons[mode_id] = b
	_content.add_child(row)
	_mode_description = UiKit.label("", UiTheme.SUBTLE, true)
	_content.add_child(_mode_description)
	_content.add_child(HSeparator.new())

	_consent = CheckBox.new()
	_consent.text = "Save an anonymous record of this session on this device (optional)"
	_consent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_consent.button_pressed = false
	UiKit.wire_feedback(_consent)
	_content.add_child(_consent)
	var what := UiKit.button("What is stored? (Data & Privacy)", func() -> void: add_child(PrivacyPanel.new()))
	what.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(what)
	_content.add_child(UiKit.label("If you leave this unticked, nothing about your session is saved and the game works the same.", UiTheme.SUBTLE, true))

	var back := UiKit.button("Back", func() -> void: SceneRouter.go_to(_back_scene()))
	var skip := UiKit.button("Skip check-in", _skip)
	var begin := UiKit.button("Begin Adventure", _begin, UiTheme.PRIMARY_BUTTON)
	_content.add_child(UiKit.hbox([back, skip, begin]))

	_choose_mode(AdaptiveComfortEngine.DEFAULT_MODE, false)
	_recommendation.text = "Answer the question for a suggested mode, or simply choose one below."
	_slider.get_slider().call_deferred("grab_focus")


func _on_answered(score: int) -> void:
	var rec := AdaptiveComfortEngine.recommend(score)
	_recommendation.text = rec["message"]
	# Suggestions never override a mode the player already picked themselves.
	if not _mode_chosen_by_player:
		_choose_mode(rec["mode"], false)


func _choose_mode(mode_id: StringName, by_player: bool) -> void:
	_selected_mode = mode_id
	if by_player:
		_mode_chosen_by_player = true
	for id: StringName in _mode_buttons:
		(_mode_buttons[id] as Button).set_pressed_no_signal(id == mode_id)
	_mode_description.text = AdaptiveComfortEngine.build_preset(mode_id).description


func _begin() -> void:
	SessionState.begin_session(_slider.get_answer(), _selected_mode, _consent.button_pressed)
	_continue()


## Skipping ignores any slider answer. The mode stays Balanced unless the
## player picked another one.
func _skip() -> void:
	var mode := _selected_mode if _mode_chosen_by_player else AdaptiveComfortEngine.DEFAULT_MODE
	SessionState.begin_session(null, mode, _consent.button_pressed)
	_continue()


## Study Mode: straight into the fresh study journey. Otherwise (the check-in
## opened some other way) the journey screen, as before.
func _continue() -> void:
	if StudyMode.is_active() and not StudyMode.participant_code.is_empty():
		StudyMode.begin_play()
		SceneRouter.go_to(SceneRouter.OVERWORLD)
	else:
		SceneRouter.go_to(SceneRouter.SLOT_SELECT)


static func _back_scene() -> String:
	return SceneRouter.STUDY_SETUP if StudyMode.is_active() else SceneRouter.MAIN_MENU


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and get_children().filter(func(c: Node) -> bool: return c is PrivacyPanel).is_empty():
		get_viewport().set_input_as_handled()
		SceneRouter.go_to(_back_scene())
