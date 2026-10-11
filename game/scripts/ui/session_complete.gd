class_name SessionCompletePanel
extends CanvasLayer
## Shown after the Heart Tree is restored or when the player chooses to finish.
## The player can keep exploring or finish (which leads to the optional reflection).

signal continue_requested
signal finish_requested

var _root: Control
var _title: Label
var _stats: Label
var _continue_button: Button


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	UiKit.adopt_theme(_root)
	UiKit.overlay(_root)
	var box := UiKit.centered_panel(_root, 620)
	_title = UiKit.label("", UiTheme.HEADING, true)
	box.add_child(_title)
	_stats = UiKit.label("", &"", true)
	box.add_child(_stats)
	box.add_child(UiKit.label("There's no rush. You can keep wandering, or finish whenever you like.", UiTheme.SUBTLE, true))
	_continue_button = UiKit.button("Continue Exploring", func() -> void: continue_requested.emit())
	var finish := UiKit.button("Finish Session", func() -> void: finish_requested.emit(), UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([_continue_button, finish]))
	visible = false


## stats keys: lights, bonus, lanterns, tree_restored, beds, bed_total,
## restoration_percent, discoveries, duration_text, objective_done
func open(stats: Dictionary) -> void:
	_title.text = "The meadow feels brighter." if stats["objective_done"] else "Ready to rest for now?"
	var lines := PackedStringArray()
	lines.append(L.t("Lights gathered: %d") % stats["lights"])
	if int(stats["bonus"]) > 0:
		lines.append(L.t("Bonus Prism Motes: %d") % stats["bonus"])
	if int(stats["lanterns"]) > 0:
		lines.append(L.t("Lanterns released: %d") % stats["lanterns"])
	lines.append(L.t("Heart Tree: %s") % (L.t("restored") if stats["tree_restored"] else L.t("still waiting for light")))
	lines.append(L.t("Garden beds in bloom: %d of %d") % [stats["beds"], stats["bed_total"]])
	lines.append(L.t("Garden restoration: %d%%") % stats["restoration_percent"])
	lines.append(L.t("Hidden details found: %d") % stats["discoveries"])
	lines.append(L.t("Time in this session: %s") % stats["duration_text"])
	for extra: String in stats.get("extra", PackedStringArray()):
		lines.append(extra)
	_stats.text = "\n".join(lines)
	visible = true
	_continue_button.call_deferred("grab_focus")


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputSetup.PAUSE)):
		get_viewport().set_input_as_handled()
		continue_requested.emit()
