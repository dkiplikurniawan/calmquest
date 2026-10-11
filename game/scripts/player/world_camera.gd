class_name WorldCamera
extends Camera2D
## Overworld camera: smooth follow, gentle look-ahead in the walking direction,
## a small dead zone, world-bound clamping and gradual context zoom.
## "Reduced camera motion" (Settings) disables look-ahead and zoom changes.
## Godot 4 zoom: values below 1 show more of the world.
## Look-ahead moves the camera's *position* (not `offset`): Godot does not clamp
## `offset` to the limits, so using it could show empty space past the map edge.

const BASE_OFFSET := Vector2(0, -20)
const LOOK_AHEAD := 90.0
const LOOK_AHEAD_RATE := 1.6
const ZOOM_RATE := 0.9
## Zoom used when reduced camera motion is on, and before a region sets one.
const DEFAULT_ZOOM := 0.92
const DEAD_ZONE := 0.06

var target_zoom: float = DEFAULT_ZOOM


func _ready() -> void:
	position = BASE_OFFSET
	offset = Vector2.ZERO
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	limit_smoothed = true
	drag_horizontal_enabled = true
	drag_vertical_enabled = true
	drag_left_margin = DEAD_ZONE
	drag_right_margin = DEAD_ZONE
	drag_top_margin = DEAD_ZONE
	drag_bottom_margin = DEAD_ZONE
	zoom = Vector2.ONE * DEFAULT_ZOOM


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func set_target_zoom(value: float) -> void:
	target_zoom = clampf(value, 0.7, 1.4)


## Jumps without smoothing (after teleports, behind a fade).
func snap() -> void:
	position = BASE_OFFSET
	zoom = Vector2.ONE * _wanted_zoom()
	reset_smoothing()


func _wanted_zoom() -> float:
	return DEFAULT_ZOOM if GameSettings.reduced_camera_motion else target_zoom


func _process(delta: float) -> void:
	var desired := BASE_OFFSET
	var body := get_parent() as CharacterBody2D
	if body != null and not GameSettings.reduced_camera_motion and body.velocity.length() > 40.0:
		desired += body.velocity.normalized() * LOOK_AHEAD
	position = position.lerp(desired, 1.0 - exp(-LOOK_AHEAD_RATE * delta))
	var z := lerpf(zoom.x, _wanted_zoom(), 1.0 - exp(-ZOOM_RATE * delta))
	zoom = Vector2(z, z)


## The world rectangle the camera shows (or is about to show), used for chunk
## streaming. It is centered on the followed body rather than on the camera's
## current screen center, which lags behind (and is still at the origin on the
## very first frame), so chunks always load where the player actually is.
func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	var center := get_screen_center_position()
	var body := get_parent() as Node2D
	if body != null:
		center = body.global_position + position
	return Rect2(center - size / 2.0, size)


## The rectangle actually shown on screen right now (after clamping to limits).
func screen_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(get_screen_center_position() - size / 2.0, size)
