class_name UiKit
extends RefCounted
## Small helpers for building consistent UI in code: labels, buttons with
## hover/click feedback, centered panels, modal overlays and confirmations.

const OVERLAY_COLOR := Color(0.11, 0.14, 0.25, 0.62)


static func label(text: String, variation: StringName = &"", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != &"":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 120
	return l


static func button(text: String, on_pressed: Callable, variation: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	if variation != &"":
		b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0, 48)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	wire_feedback(b)
	return b


## Hover/focus sound, a small "lift" on hover and a click sound on press.
static func wire_feedback(control: BaseButton) -> void:
	control.mouse_entered.connect(func() -> void: _lift(control, true))
	control.mouse_exited.connect(func() -> void: _lift(control, false))
	control.focus_entered.connect(func() -> void: AudioManager.play(&"ui_hover"))
	control.pressed.connect(func() -> void: AudioManager.play(&"ui_click"))


static func _lift(control: Control, hovered: bool) -> void:
	if not control.is_inside_tree():
		return
	if hovered:
		AudioManager.play(&"ui_hover")
	control.pivot_offset = control.size / 2.0
	var target := Vector2(1.03, 1.03) if hovered else Vector2.ONE
	var tween := control.create_tween()
	tween.tween_property(control, "scale", target, 0.12 * maxf(GameSettings.motion_scale(), 0.3)).set_trans(Tween.TRANS_SINE)


## Gives a UI root under a CanvasLayer the shared theme and keeps it in sync
## when text size or contrast settings change.
static func adopt_theme(root: Control) -> void:
	root.theme = GameSettings.ui_theme
	root.add_to_group(GameSettings.THEMED_ROOTS_GROUP)


## Full-screen dimmed overlay that blocks clicks to whatever is behind it.
static func overlay(parent: Node) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = OVERLAY_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(bg)
	return bg


## Adds a centered panel to `parent` and returns its content VBox.
static func centered_panel(parent: Node, min_width: float = 560.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = min_width
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func hbox(children: Array, align: BoxContainer.AlignmentMode = BoxContainer.ALIGNMENT_CENTER) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = align
	for c: Control in children:
		h.add_child(c)
	return h


## Modal yes/cancel confirmation built on top of `parent`.
## Works while the tree is paused. Escape cancels.
static func confirm(parent: Node, message: String, confirm_text: String, on_confirm: Callable) -> Control:
	var root := ConfirmLayer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	overlay(root)
	var box := centered_panel(root, 520)
	box.add_child(label("Are you sure?", UiTheme.HEADING))
	box.add_child(label(message, &"", true))
	var cancel := button("Cancel", root.queue_free)
	var do_confirm := func() -> void:
		root.queue_free()
		on_confirm.call()
	var ok := button(confirm_text, do_confirm, UiTheme.PRIMARY_BUTTON)
	box.add_child(hbox([cancel, ok]))
	cancel.call_deferred("grab_focus")
	return root


## Control that closes itself on Escape (used by confirm dialogs).
class ConfirmLayer extends Control:
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			queue_free()
