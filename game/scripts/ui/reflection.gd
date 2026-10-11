extends Control
## Post-game reflection: the same optional 0-10 question as the check-in, plus
## an optional "how did the game feel" rating. Skipping is always possible.

const RATING_LABELS := ["1 - Not for me", "2", "3 - Okay", "4", "5 - Lovely"]

var _slider: StressSlider
var _rating: Variant = null
var _rating_buttons: Array[Button] = []
var _submitted: bool = false


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
	panel.custom_minimum_size.x = 760
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	box.add_child(UiKit.label("Before you go: how are you feeling now?", UiTheme.HEADING, true))
	box.add_child(UiKit.label("The same question as before, completely optional. Any answer is welcome, including the same or a higher number.", UiTheme.SUBTLE, true))
	_slider = StressSlider.new("Right now, how stressed do you feel? (0-10)")
	box.add_child(_slider)
	box.add_child(HSeparator.new())
	box.add_child(UiKit.label("How did the game feel to play? (optional)", &"", true))
	box.add_child(UiKit.label("This is about the game itself, not about your well-being.", UiTheme.SUBTLE, true))
	var group := ButtonGroup.new()
	group.allow_unpress = true
	var row := HBoxContainer.new()
	for i in RATING_LABELS.size():
		var value := i + 1
		var b := UiKit.button(RATING_LABELS[i], func() -> void: _toggle_rating(value), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		_rating_buttons.append(b)
	box.add_child(row)
	box.add_child(HSeparator.new())
	var note := "Your answers will be saved with this anonymous session record on this device, as you agreed." if SessionState.consent_to_store else "Nothing will be saved: you did not opt in to local storage."
	box.add_child(UiKit.label(note, UiTheme.SUBTLE, true))
	var skip := UiKit.button("Skip reflection", _skip)
	var done := UiKit.button("See results", _submit, UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([skip, done]))
	_slider.get_slider().call_deferred("grab_focus")


func _toggle_rating(value: int) -> void:
	var pressed := _rating_buttons[value - 1].button_pressed
	_rating = value if pressed else null


func _submit() -> void:
	_finish(_slider.get_answer(), _rating)


func _skip() -> void:
	_finish(null, null)


func _finish(score: Variant, rating: Variant) -> void:
	if _submitted:
		return
	_submitted = true
	SessionState.set_reflection(score, rating)
	SessionState.finalize_and_save(true)
	SceneRouter.go_to(SceneRouter.RESULTS)
