class_name ChoicePanel
extends Control
## A small modal with a title, a short text and a few choices (buttons).
## Used for gentle decisions in the world: how to comfort a Gloomling, what to
## say to a villager, and so on. Esc or "Never mind" closes it without choosing.

signal chosen(choice_id: String)
signal closed


## options: Array of [id, label] or [id, label, enabled].
func setup(title: String, text: String, options: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 620)
	box.add_child(UiKit.label(title, UiTheme.HEADING))
	if not text.is_empty():
		box.add_child(UiKit.label(text, &"", true))
	var first: Button = null
	for o: Array in options:
		var id := String(o[0])
		var b := UiKit.button(String(o[1]), func() -> void: _choose(id), UiTheme.PRIMARY_BUTTON if first == null else &"")
		b.disabled = o.size() > 2 and not bool(o[2])
		box.add_child(b)
		if first == null and not b.disabled:
			first = b
	var cancel := UiKit.button("Never mind", close_panel)
	box.add_child(cancel)
	(first if first != null else cancel).call_deferred("grab_focus")


func _choose(id: String) -> void:
	chosen.emit(id)
	close_panel()


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
