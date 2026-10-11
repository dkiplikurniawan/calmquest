class_name RestController
extends Node
## Sitting at a rest spot (0.4.0). The player sits and Lumi curls up nearby;
## the camera slowly drifts and widens toward the view (a crossfade with
## Reduce motion); the HUD fades out completely; the music and ambience swell
## a little; with "Watch time pass while resting" on, the clock runs faster.
## Any movement, Esc or Run (gamepad: the stick, B or Start) stands up again. E (gamepad A)
## opens "Breathe with Lumi". There is no minimum or maximum time, and nothing
## is counted or rewarded.
## Quiet places are marked as found when the player comes near them.

signal rest_started(spot: RestSpot)
signal rest_ended(spot: RestSpot)

## The camera's wide shot while resting (smaller = more of the world).
const REST_ZOOM := 0.8
const DRIFT_DISTANCE := 130.0
## In-game minutes per real second with "Watch time pass while resting".
const TIME_LAPSE := 6.0
const DISCOVER_RADIUS := 300.0
const DISCOVER_INTERVAL := 0.5
## How long the controls line stays before fading (it returns on mouse move).
const CONTROLS_SECONDS := 6.0
const BOOST_SECONDS := 3.0

var overworld: Overworld
var spot: RestSpot = null
var overlay: RestOverlay
var _discover_t: float = 0.0
var _boost_tween: Tween


func setup(ow: Overworld) -> void:
	overworld = ow
	EventBus.rest_requested.connect(func(s: Node2D) -> void: start(s as RestSpot))


func is_resting() -> bool:
	return spot != null


func start(s: RestSpot) -> void:
	if s == null or is_resting() or overworld._modal_open or overworld.village.finale_running:
		return
	spot = s
	if RestSpots.mark_found(s.spot_id):
		overworld.hud.show_toast(L.t("A quiet place: %s") % s.display_name())
	var player := overworld.player
	player.sit_at(s.seat_point())
	overworld.lumi.rest_at(s.lumi_point())
	_camera(true)
	overworld.hud.set_resting(true)
	overworld.hud.set_prompt("")
	AudioManager.play(&"swell")
	_boost(true)
	overlay = RestOverlay.new()
	overlay.controller = self
	overworld.add_child(overlay)
	StudyMode.log_event("rest_spot_used", s.spot_id)
	StudyMode.log_event("activity_started", "resting")
	rest_started.emit(s)


func stand_up() -> void:
	if not is_resting():
		return
	var s := spot
	spot = null
	overworld.player.stand()
	overworld.lumi.wake()
	_camera(false)
	overworld.hud.set_resting(false)
	_boost(false)
	if overlay != null:
		overlay.queue_free()
		overlay = null
	StudyMode.log_event("activity_finished", "resting")
	rest_ended.emit(s)


## Opens "Breathe with Lumi" (from the rest spot).
func breathe() -> void:
	if is_resting():
		overworld.open_breathe()


## The rest spot's line and buttons step aside while breathing (whether it was
## opened with E or from the pause menu) and come back hidden afterwards.
func on_breathe_opened(panel: BreathePanel) -> void:
	if overlay == null or panel == null:
		return
	overlay.visible = false
	panel.closed.connect(func() -> void:
		if overlay != null:
			overlay.hide_controls()
			overlay.visible = true)


## Mouse: a click on the seat the player is next to (the current target) sits down.
func handle_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	if is_resting() or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return false
	var target := overworld.player.current_target as RestSpot
	if target == null:
		return false
	var world_pos := overworld.get_viewport().get_canvas_transform().affine_inverse() * click.position
	if world_pos.distance_to(target.get_interaction_point()) > 52.0:
		return false
	start(target)
	return true


## Input while resting; returns true when the event was used.
func handle_input(event: InputEvent) -> bool:
	if not is_resting():
		return false
	if event is InputEventMouseMotion:
		if overlay != null:
			overlay.show_controls()
		return false
	# Gamepad B is the Run button in this game, and Start is Pause: both stand up.
	for action in [InputSetup.MOVE_LEFT, InputSetup.MOVE_RIGHT, InputSetup.MOVE_UP, InputSetup.MOVE_DOWN, InputSetup.PAUSE, InputSetup.RUN, &"ui_cancel"]:
		if event.is_action_pressed(action):
			stand_up()
			return true
	if event.is_action_pressed(InputSetup.INTERACT):
		breathe()
		return true
	# Everything else (journal, map, build...) waits until the player stands up.
	return event is InputEventKey or event is InputEventJoypadButton


func _process(delta: float) -> void:
	if overworld == null:
		return
	if is_resting():
		if GameSettings.rest_time_passes and TimeManager.running:
			TimeManager.advance(delta * TIME_LAPSE)
		return
	_discover_t -= delta
	if _discover_t > 0.0:
		return
	_discover_t = DISCOVER_INTERVAL
	discover_near(overworld.player.global_position)


## Marks quiet places near `pos` as found (they then appear on the map).
func discover_near(pos: Vector2) -> PackedStringArray:
	var found := PackedStringArray()
	for n in get_tree().get_nodes_in_group(RestSpot.GROUP_NAME):
		var s := n as RestSpot
		if s == null or not s.is_visible_in_tree() or RestSpots.is_found(s.spot_id):
			continue
		if s.global_position.distance_to(pos) <= DISCOVER_RADIUS and RestSpots.mark_found(s.spot_id):
			found.append(s.spot_id)
			overworld.hud.show_toast(L.t("A quiet place: %s") % s.display_name())
	return found


func _camera(on: bool) -> void:
	var cam := overworld.camera
	if cam == null:
		return
	cam.override_zoom = REST_ZOOM if on else 0.0
	cam.drift_offset = spot.view_dir * DRIFT_DISTANCE if on and spot != null and not GameSettings.reduce_motion and not GameSettings.reduced_camera_motion else Vector2.ZERO
	if GameSettings.reduce_motion or GameSettings.reduced_camera_motion:
		SceneRouter.fade_through(cam.snap)


func _exit_tree() -> void:
	AudioManager.set_rest_boost(0.0)


func _boost(on: bool) -> void:
	if _boost_tween != null:
		_boost_tween.kill()
	_boost_tween = create_tween()
	_boost_tween.tween_method(AudioManager.set_rest_boost, AudioManager.rest_boost, 1.0 if on else 0.0, BOOST_SECONDS if on else 1.2)


## The quiet line of controls at the bottom while resting (fades away; any
## mouse movement brings it back as clickable buttons).
class RestOverlay extends CanvasLayer:
	var controller: RestController
	var breathe_button: Button
	var stand_button: Button
	var _root: Control
	var _shown: float = RestController.CONTROLS_SECONDS

	func _ready() -> void:
		# Under the HUD layer, so "Breathe with Lumi" (a HUD overlay) covers it.
		layer = 4
		_root = Control.new()
		_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root)
		UiKit.adopt_theme(_root)
		var name_label := UiKit.label(controller.spot.display_name(), UiTheme.LIGHT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var line := UiKit.label(RestSpots.line(controller.spot.spot_id), UiTheme.LIGHT, true)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.custom_minimum_size.x = 640
		breathe_button = UiKit.button(L.t("Breathe with Lumi") + "  [%s]" % InputSetup.key_name(InputSetup.primary_key(InputSetup.INTERACT)), controller.breathe)
		stand_button = UiKit.button(L.t("Stand up") + "  [%s]" % InputSetup.key_name(InputSetup.primary_key(InputSetup.PAUSE)), controller.stand_up)
		for b in [breathe_button, stand_button]:
			b.focus_mode = Control.FOCUS_NONE
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_END
		box.add_theme_constant_override("separation", 10)
		box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		box.offset_bottom = -36
		box.add_child(name_label)
		box.add_child(line)
		box.add_child(UiKit.hbox([breathe_button, stand_button]))
		_root.add_child(box)
		_root.modulate.a = 0.0
		if GameSettings.control_hints == GameSettings.HINTS_NEVER:
			_shown = 0.0

	func show_controls() -> void:
		_shown = maxf(_shown, 3.0)

	func hide_controls() -> void:
		_shown = 0.0
		_root.modulate.a = 0.0

	func controls_visible() -> bool:
		return _root.modulate.a > 0.05

	func _process(delta: float) -> void:
		_shown = maxf(0.0, _shown - delta)
		var target := 1.0 if _shown > 0.0 else 0.0
		_root.modulate.a = move_toward(_root.modulate.a, target, delta * 1.5)
		var clickable := _root.modulate.a > 0.3
		for b in [breathe_button, stand_button]:
			b.mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
