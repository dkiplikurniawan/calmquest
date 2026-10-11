class_name LorePanel
extends Control
## Shows a lore note's text and any recipes it taught. Escape or Close.

signal closed


func setup(note_id: String, learned: PackedStringArray) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var data := LoreNote.note_data(note_id)
	var box := UiKit.centered_panel(self, 640)
	box.add_child(UiKit.label(L.t(String(data.get("title", "An old note"))), UiTheme.HEADING, true))
	box.add_child(UiKit.label(L.t(String(data.get("text", ""))), &"", true))
	if not learned.is_empty():
		var names := PackedStringArray()
		for id in learned:
			var out: Dictionary = GameState.crafting.get_recipe(id).get("output", {})
			names.append(ItemDB.display_name(String(out.get("item", id))))
		box.add_child(UiKit.label(L.t("New recipe learned: %s") % ", ".join(names), UiTheme.SUBTLE, true))
	var close := UiKit.button("Close", close_panel, UiTheme.PRIMARY_BUTTON)
	box.add_child(close)
	close.call_deferred("grab_focus")


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
