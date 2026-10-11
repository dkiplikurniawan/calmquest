extends CanvasLayer
## Gentle fade transitions between screens (autoload "SceneRouter").
## Always unpauses the tree before changing scenes so no screen starts frozen.

signal transition_finished(scene_path: String)

const FADE_SECONDS := 0.45
const FADE_COLOR := Color("#1d2540")

const SPLASH := "res://game/scenes/main/splash.tscn"
const MAIN_MENU := "res://game/scenes/ui/main_menu.tscn"
const CHECK_IN := "res://game/scenes/ui/check_in.tscn"
const OVERWORLD := "res://game/scenes/world/overworld.tscn"
const SLOT_SELECT := "res://game/scenes/ui/slot_select.tscn"
const REFLECTION := "res://game/scenes/ui/reflection.tscn"
const RESULTS := "res://game/scenes/ui/results.tscn"
const STUDY_SETUP := "res://game/scenes/ui/study_setup.tscn"
const ABOUT := "res://game/scenes/ui/about.tscn"

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(FADE_COLOR, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func is_busy() -> bool:
	return _busy


## Fades out, runs `action` while the screen is covered (e.g. a teleport that
## builds new chunks), then fades back in. Clicks are blocked meanwhile.
func fade_through(action: Callable) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var duration := FADE_SECONDS * maxf(GameSettings.motion_scale(), 0.4)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	action.call()
	await get_tree().process_frame
	var tween_in := create_tween()
	tween_in.tween_property(_fade, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tween_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func go_to(scene_path: String) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: scene not found: %s" % scene_path)
		return
	_busy = true
	# Block clicks while the screen fades so nothing behind it is activated.
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var duration := FADE_SECONDS * maxf(GameSettings.motion_scale(), 0.4)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tween.finished
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: could not open %s (%s)" % [scene_path, error_string(err)])
	await get_tree().process_frame
	var tween_in := create_tween()
	tween_in.tween_property(_fade, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tween_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	transition_finished.emit(scene_path)
