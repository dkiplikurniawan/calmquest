class_name TravelPanel
extends Control
## Opened from a relit waystone: lists every other relit waystone. Travel is
## always free and instant (behind a short fade).

signal closed
signal travel_requested(waystone_id: String)


func setup(world: WorldData, from_id: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 560)
	box.add_child(UiKit.label("Lantern Waystones", UiTheme.HEADING))
	var first: Button = null
	for id in GameState.restored_waystones():
		if id == from_id:
			continue
		var poi := world.poi(id)
		var region := world.region_display(world.region_at(poi.get("pos", Vector2.ZERO)))
		var b := UiKit.button(L.t("Travel to %s") % region, func() -> void:
			travel_requested.emit(id)
			close_panel())
		box.add_child(b)
		if first == null:
			first = b
	if first == null:
		box.add_child(UiKit.label("Relight more waystones as you explore, and you can travel between them freely.", &"", true))
	var back := UiKit.button("Stay here", close_panel, UiTheme.PRIMARY_BUTTON)
	box.add_child(back)
	(first if first != null else back).call_deferred("grab_focus")


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
