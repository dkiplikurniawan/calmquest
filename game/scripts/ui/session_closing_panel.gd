class_name SessionClosingPanel
extends Control
## "Before you go..." when the player chooses Return to menu or Quit from the
## pause menu (never when the window is closed abruptly). A warm summary built
## only from real events, and, if the mood check is on, the same five faces.
## No before/after comparison and nothing that reads like a score.

signal keep_playing
signal leave(end_face: Variant)

## "menu" or "quit": decides the leave button's text.
var leaving_to: String = "menu"
var summary: Label
var faces: MoodFace.Row
var keep_button: Button
var leave_button: Button
var _end_face: Variant = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 660)
	box.add_child(UiKit.label("Before you go…", UiTheme.HEADING))
	if GameSettings.session_summary:
		summary = UiKit.label("\n".join(Wellbeing.summary_lines()), &"", true)
		box.add_child(summary)
	if GameSettings.mood_check:
		box.add_child(HSeparator.new())
		box.add_child(UiKit.label("How are you feeling now? (optional)", &"", true))
		faces = MoodFace.Row.new(52.0)
		faces.chosen.connect(func(face: int) -> void: _end_face = face)
		box.add_child(faces)
	keep_button = UiKit.button("Keep playing", func() -> void:
		keep_playing.emit()
		queue_free())
	leave_button = UiKit.button("Quit Game" if leaving_to == "quit" else "Return to menu", func() -> void:
		leave.emit(_end_face)
		queue_free(), UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([keep_button, leave_button]))
	keep_button.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		keep_playing.emit()
		queue_free()
