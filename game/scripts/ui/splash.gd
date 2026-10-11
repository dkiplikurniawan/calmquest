extends Control
## Short splash: title fades in, then the main menu opens.
## Any key or click skips it immediately.

const HOLD_SECONDS := 2.2

var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := UiKit.label("CALMQUEST", UiTheme.TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UiKit.label("The Lost Light", UiTheme.LIGHT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.8 * maxf(GameSettings.motion_scale(), 0.5)).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_callback(_continue)
	MusicManager.request_cue("lumeria_theme", true)


func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	if _done:
		return
	_done = true
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
