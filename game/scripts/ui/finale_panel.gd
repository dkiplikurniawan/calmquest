class_name FinalePanel
extends Control
## Shown once after the Festival of Light. Gentle words, what changed, and a
## reminder that the world stays open. No credits roll that blocks play.

signal closed


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 760)
	box.add_child(UiKit.label("The Light Returns", UiTheme.HEADING))
	box.add_child(UiKit.label("The five Hearthstones sang through the Heart Tree, and light poured out across the meadow, the pines, the coast, the caves and the highlands. The gloom is gone. Your friends are dancing around the fire.", &"", true))
	box.add_child(UiKit.label("Lumeria stays open: keep exploring, decorating, fishing and visiting friends. A few new things have appeared since tonight. Your journal has a page called \"A Wider Journal\" for whenever you feel like looking.", UiTheme.SUBTLE, true))
	box.add_child(UiKit.label("Thank you for bringing the light home.", UiTheme.SUBTLE, true))
	var b := UiKit.button("Continue exploring", close_panel, UiTheme.PRIMARY_BUTTON)
	box.add_child(b)
	b.call_deferred("grab_focus")


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
