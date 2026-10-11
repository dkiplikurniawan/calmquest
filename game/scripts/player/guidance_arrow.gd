class_name GuidanceArrow
extends Node2D
## Soft golden chevron around the player pointing at the nearest uncollected
## light. Shown in Gentle mode by default, or after repeated hint requests.

const ORBIT_RADIUS := 46.0
const CENTER_OFFSET := Vector2(0, -22)
## Hide when the target is this close; the target ring takes over.
const HIDE_DISTANCE := 110.0

var active: bool = false
var has_target: bool = false
var target_position: Vector2 = Vector2.ZERO
var _t: float = 0.0


func set_target(world_position: Vector2) -> void:
	has_target = true
	target_position = world_position


func clear_target() -> void:
	has_target = false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not active or not has_target:
		return
	var origin := global_position + CENTER_OFFSET
	var to_target := target_position - origin
	if to_target.length() < HIDE_DISTANCE:
		return
	var dir := to_target.normalized()
	var tip_center := CENTER_OFFSET + dir * (ORBIT_RADIUS + sin(_t * 2.5) * 3.0)
	var normal := Vector2(-dir.y, dir.x)
	var tip := tip_center + dir * 9.0
	var left := tip_center - dir * 5.0 + normal * 9.0
	var right := tip_center - dir * 5.0 - normal * 9.0
	var notch := tip_center - dir * 1.0
	var alpha := 0.75 + 0.25 * sin(_t * 2.5)
	var shape := PackedVector2Array([tip, left, notch, right])
	draw_colored_polygon(shape, Palette.with_alpha(Palette.GOLD, alpha))
	var outline := shape.duplicate()
	outline.append(tip)
	draw_polyline(outline, Palette.with_alpha(Palette.GOLD_DEEP, alpha), 2.0, true)
