class_name MoodCheckCard
extends Control
## The optional mood check when a journey starts: a small, soft card (not a
## full screen) with five faces, Skip, and "Don't ask again". One tap answers.
## It is not a measurement, and the answer is only kept if the player turned
## on the private mood journal. Never shown in Study Mode.

signal finished(face: Variant, dont_ask: bool)

var faces: MoodFace.Row
var dont_ask: CheckBox
var skip_button: Button
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UiKit.overlay(self)
	dim.color = Color(UiKit.OVERLAY_COLOR, 0.28)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -36
	card.custom_minimum_size.x = 640
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := UiKit.label("How are you feeling right now?", UiTheme.HEADING, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var note := UiKit.label("Just a gentle check-in, not a test. Tap a face, or skip.", UiTheme.SUBTLE, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	faces = MoodFace.Row.new()
	faces.chosen.connect(func(face: int) -> void: _finish(face))
	box.add_child(faces)
	dont_ask = CheckBox.new()
	dont_ask.text = "Don't ask again"
	UiKit.wire_feedback(dont_ask)
	skip_button = UiKit.button("Skip", func() -> void: _finish(null))
	var row := UiKit.hbox([dont_ask, skip_button])
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	faces.buttons[2].call_deferred("grab_focus")


func _finish(face: Variant) -> void:
	if _done:
		return
	_done = true
	finished.emit(face, dont_ask.button_pressed)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(null)
