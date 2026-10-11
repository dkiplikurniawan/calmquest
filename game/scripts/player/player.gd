class_name Player
extends CharacterBody2D
## The Traveler: 8-direction movement, reach-limited interaction, procedural look.
##
## Movement uses Input.get_vector, which already limits diagonal input to length 1,
## so diagonal movement is never faster. High acceleration keeps it responsive
## (not slippery); motion_mode is FLOATING for top-down play.

signal interaction_attempted(success: bool, nearest_distance: float)
signal target_changed(target: Interactable)

const SPEED := 220.0
## Comfortable faster stroll (Shift). No stamina: running never runs out.
const RUN_MULTIPLIER := 1.6
const ACCELERATION := 2400.0
const FRICTION := 2800.0
const REACH_RING_SECONDS := 3.0

@export var interaction_radius: float = 72.0

var input_enabled: bool = true
var animation_intensity: float = 1.0
var current_target: Interactable = null
var facing: Vector2 = Vector2.DOWN
var nearest_distance: float = -1.0
var running: bool = false
## Multiplier from gentle food buffs (1.0 = none).
var speed_bonus: float = 1.0

var _input_block: float = 0.0
var _t: float = 0.0
var _walk: float = 0.0
var _pulse: float = 0.0
var _reach_ring: float = 0.0
var _run_toggled: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func apply_config(config: ModeConfig, motion_scale: float) -> void:
	interaction_radius = config.interaction_radius
	animation_intensity = config.animation_intensity * motion_scale


## Ignore gameplay input briefly (e.g. right after a menu closes) so the key
## that closed a dialog cannot trigger an interaction behind it.
func block_input(seconds: float) -> void:
	_input_block = maxf(_input_block, seconds)
	velocity = Vector2.ZERO


func show_reach_ring() -> void:
	_reach_ring = REACH_RING_SECONDS


func _physics_process(delta: float) -> void:
	_input_block = maxf(0.0, _input_block - delta)
	var dir := Vector2.ZERO
	if input_enabled and _input_block <= 0.0:
		dir = Input.get_vector(InputSetup.MOVE_LEFT, InputSetup.MOVE_RIGHT, InputSetup.MOVE_UP, InputSetup.MOVE_DOWN)
	running = _is_running()
	var speed := SPEED * (RUN_MULTIPLIER if running else 1.0) * speed_bonus
	if dir != Vector2.ZERO:
		velocity = velocity.move_toward(dir * speed, ACCELERATION * delta)
		facing = dir.normalized()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	move_and_slide()
	update_target()


func _is_running() -> bool:
	if GameSettings.run_toggle:
		return _run_toggled
	return Input.is_action_pressed(InputSetup.RUN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputSetup.RUN) and not event.is_echo() and GameSettings.run_toggle:
		_run_toggled = not _run_toggled
	if event.is_action_pressed(InputSetup.INTERACT) and not event.is_echo():
		if not input_enabled or _input_block > 0.0:
			return
		get_viewport().set_input_as_handled()
		try_interact()


## Interacts with the current target if one is within reach.
## Returns true on success. Reports misses so the adaptive engine can help.
func try_interact() -> bool:
	update_target()
	_pulse = 1.0
	if current_target != null:
		var target := current_target
		target.interact()
		interaction_attempted.emit(true, 0.0)
		return true
	interaction_attempted.emit(false, nearest_distance)
	return false


## Finds the nearest interactable within reach (radius + the object's reach bonus).
func update_target() -> void:
	var best: Interactable = null
	var best_gap := INF
	nearest_distance = -1.0
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if it == null or not it.can_interact():
			continue
		var gap := global_position.distance_to(it.get_interaction_point()) - it.reach_bonus
		if nearest_distance < 0.0 or gap < nearest_distance:
			nearest_distance = maxf(gap, 0.0)
		if gap <= interaction_radius and gap < best_gap:
			best_gap = gap
			best = it
	if best != current_target:
		if is_instance_valid(current_target):
			current_target.set_targeted(false)
		current_target = best
		if current_target != null:
			current_target.set_targeted(true)
		target_changed.emit(current_target)


func _process(delta: float) -> void:
	_t += delta
	var moving := velocity.length() > 20.0
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 6.0)
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	_reach_ring = maxf(0.0, _reach_ring - delta)
	queue_redraw()


func _draw() -> void:
	var k := animation_intensity
	var bob := sin(_t * 12.0) * 2.2 * _walk * k + sin(_t * 2.2) * 0.8 * (1.0 - _walk) * k
	var step := sin(_t * 12.0) * _walk
	var side := -1.0 if facing.x < -0.1 else 1.0
	var back_view := facing.y < -0.6

	if _reach_ring > 0.0:
		var a := minf(1.0, _reach_ring) * 0.7
		var segments := 28
		for i in segments:
			if i % 2 == 0:
				var a0 := TAU * i / segments
				draw_arc(Vector2.ZERO, interaction_radius, a0, a0 + TAU / segments, 4, Palette.with_alpha(Palette.GOLD_DEEP, a), 3.0, true)
	if _pulse > 0.0:
		draw_arc(Vector2.ZERO, 18.0 + (1.0 - _pulse) * 26.0, 0.0, TAU, 32, Palette.with_alpha(Palette.GOLD_SOFT, _pulse * 0.8), 2.5, true)

	# Shadow
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 15.0, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Feet peek out under the cloak, alternating while walking.
	draw_circle(Vector2(-5, -3 + step * 2.0), 3.6, Palette.BARK_DARK)
	draw_circle(Vector2(5, -3 - step * 2.0), 3.6, Palette.BARK_DARK)

	var y := -bob
	# Cloak (bell shape)
	var cloak := PackedVector2Array([
		Vector2(-8, -27 + y), Vector2(8, -27 + y), Vector2(13, -10 + y), Vector2(15, -4 + y),
		Vector2(-15, -4 + y), Vector2(-13, -10 + y),
	])
	draw_colored_polygon(cloak, Cosmetics.cloak_fill())
	draw_line(Vector2(-15, -4 + y), Vector2(15, -4 + y), Palette.MINT, 3.0, true)
	var cloak_outline := cloak.duplicate()
	cloak_outline.append(cloak[0])
	draw_polyline(cloak_outline, Cosmetics.cloak_edge(), 1.5, true)
	# Satchel strap and satchel
	if not back_view:
		draw_line(Vector2(-7 * side, -25 + y), Vector2(8 * side, -11 + y), Palette.BARK, 2.0, true)
	draw_circle(Vector2(9 * side, -10 + y), 4.0, Palette.BARK)

	# Hood behind the head
	draw_circle(Vector2(0, -38 + y), 13.5, Cosmetics.cloak_edge())
	draw_circle(Vector2(0, -40 + y), 12.0, Cosmetics.cloak_fill())
	# Head
	if not back_view:
		draw_circle(Vector2(facing.x * 1.5, -36 + y), 9.5, Color("#f6d9bf"))
		var eye_off := Vector2(facing.x * 3.0, facing.y * 1.5)
		draw_circle(Vector2(-3.6, -36 + y) + eye_off, 1.7, Palette.INK)
		draw_circle(Vector2(3.6, -36 + y) + eye_off, 1.7, Palette.INK)
		draw_circle(Vector2(-6, -32.5 + y) + eye_off, 1.8, Palette.with_alpha(Color("#f4a6a6"), 0.6))
		draw_circle(Vector2(6, -32.5 + y) + eye_off, 1.8, Palette.with_alpha(Color("#f4a6a6"), 0.6))
	# Hood rim over the forehead
	draw_arc(Vector2(0, -38 + y), 11.5, PI * 1.08, PI * 1.92, 16, Cosmetics.cloak_edge(), 3.0, true)
	# Scarf with a tail that trails opposite to movement
	draw_line(Vector2(-9, -27 + y), Vector2(9, -27 + y), Palette.LAVENDER, 5.0, true)
	var flutter := sin(_t * 5.0) * 2.0 * (0.3 + _walk) * k
	draw_line(Vector2(-6 * side, -26 + y), Vector2(-13 * side, -17 + y + flutter), Palette.VIOLET, 4.0, true)
