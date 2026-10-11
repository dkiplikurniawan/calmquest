class_name Lumi
extends Node2D
## Lumi the Lightkeeper: a small, original fox-like light spirit.
##
## Follow algorithm: Lumi eases toward a point behind the player using
## frame-rate independent exponential smoothing. A dead zone stops tiny
## corrections (no jitter when the player stands still). If Lumi falls too far
## behind (e.g. after a scene event), she fades out and reappears beside the
## player instead of getting lost. Lumi has no collision, so she never blocks movement.
## 0.4.0: a softer, layered glow, a small trail of sparkles while moving, a
## happy hop on reactions, and a longer celebration for the finale. A sprite
## sheet in assets/sprites/lumi.png replaces the drawing when present.

## Distance Lumi keeps behind the player.
@export var follow_distance: float = 54.0
## Smoothing rate; higher = catches up faster.
@export var follow_rate: float = 3.0
## Lumi ignores target changes smaller than this (prevents jitter).
@export var dead_zone: float = 10.0
## Beyond this distance Lumi gently fades and reappears near the player.
@export var recovery_distance: float = 520.0

const FLOAT_HEIGHT := 34.0

var target: Node2D = null
var animation_intensity: float = 1.0
var _t: float = 0.0
var _hop: float = 0.0
var _happy: float = 0.0
var _recovering: bool = false
var _settled: bool = false
var _light: PointLight2D
## Recent positions (local to the current position) for the sparkle trail.
var _trail: Array = []
var _last_pos: Vector2 = Vector2.INF
var _celebrate: float = 0.0
## Resting beside the player at a rest spot (Vector2.INF = following).
var _rest_pos: Vector2 = Vector2.INF
var _curl: float = 0.0


func _ready() -> void:
	_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.6, 0.9)
	_light.position = Vector2(0, -FLOAT_HEIGHT)
	add_child(_light)


func apply_config(config: ModeConfig, motion_scale: float) -> void:
	animation_intensity = config.animation_intensity * motion_scale


## Brightens Lumi's own light at night (0 = day, 1 = night).
func set_night_amount(amount: float) -> void:
	_light.color = Cosmetics.glow_color()
	_light.enabled = amount > 0.01
	_light.energy = 0.6 * amount


func snap_to_target() -> void:
	if target != null:
		global_position = _desired_position()


## Small happy hop with sparkles (item collected, discovery...).
func react() -> void:
	_hop = 1.0
	_happy = 1.4


## A longer celebration (the finale): several hops and a burst of sparkles.
func celebrate(seconds: float = 4.0) -> void:
	_celebrate = seconds
	react()


func is_celebrating() -> bool:
	return _celebrate > 0.0


## Rest spots: Lumi settles at `pos` and curls up until wake().
func rest_at(pos: Vector2) -> void:
	_rest_pos = pos


func wake() -> void:
	_rest_pos = Vector2.INF


func is_resting() -> bool:
	return _rest_pos != Vector2.INF


func curl_amount() -> float:
	return _curl


func _desired_position() -> Vector2:
	var facing := Vector2.DOWN
	if target is Player:
		facing = (target as Player).facing
	var side := Vector2(-facing.y, facing.x) * 14.0
	return target.global_position - facing * follow_distance + side


func _process(delta: float) -> void:
	_t += delta
	_hop = maxf(0.0, _hop - delta * 2.2)
	_happy = maxf(0.0, _happy - delta)
	if _celebrate > 0.0:
		_celebrate = maxf(0.0, _celebrate - delta)
		if _hop <= 0.0 and _celebrate > 0.3:
			react()
	# Sparkle trail: remember where Lumi was while she moves.
	if _last_pos != Vector2.INF and global_position.distance_to(_last_pos) > 3.0 and animation_intensity > 0.2:
		_trail.push_front([global_position, 0.0])
	_last_pos = global_position
	for p: Array in _trail:
		p[1] = float(p[1]) + delta
	_trail = _trail.filter(func(p: Array) -> bool: return float(p[1]) < 0.6).slice(0, 8)
	_curl = move_toward(_curl, 1.0 if is_resting() else 0.0, delta * 0.8)
	if is_resting():
		global_position = global_position.lerp(_rest_pos, 1.0 - exp(-1.5 * delta))
		_settled = false
	elif target != null and not _recovering:
		var desired := _desired_position()
		var gap := global_position.distance_to(desired)
		if gap > recovery_distance:
			_recover()
		elif gap > dead_zone or not _settled:
			var weight := 1.0 - exp(-follow_rate * delta)
			global_position = global_position.lerp(desired, weight)
			_settled = gap < dead_zone * 0.5
		if gap > dead_zone * 2.0:
			_settled = false
	queue_redraw()


func _recover() -> void:
	_recovering = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(snap_to_target)
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: _recovering = false)


func _draw() -> void:
	var k := animation_intensity
	var float_y := -FLOAT_HEIGHT * (1.0 - 0.72 * _curl) + sin(_t * 1.6) * 4.0 * k * (1.0 - 0.8 * _curl) - sin(_hop * PI) * 14.0
	var c := Vector2(0, float_y)
	var facing_x := 1.0
	if target is Player and (target as Player).facing.x < -0.1:
		facing_x = -1.0

	# Ground shadow (shrinks while floating higher)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 9.0, Palette.with_alpha(Palette.SHADOW, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Sparkle trail behind Lumi.
	var glow_col := Cosmetics.glow_color()
	for p: Array in _trail:
		var age := float(p[1]) / 0.6
		var local: Vector2 = to_local(p[0]) + Vector2(0, -FLOAT_HEIGHT)
		draw_circle(local, 2.2 * (1.0 - age), Palette.with_alpha(glow_col, 0.6 * (1.0 - age)))
	# Soft glow, in gentle layers.
	var glow := 0.85 + 0.15 * sin(_t * 2.0)
	for i in 4:
		draw_circle(c, (32.0 - i * 6.0) * glow, Palette.with_alpha(glow_col, 0.06 + i * 0.04))
	var sprite := CharacterSprites.lumi()
	if sprite != null:
		CharacterSprites.draw_lumi(self, sprite, _t, c)
		return

	# Tail: a fluffy curl with a turquoise tip, swaying behind Lumi.
	var sway := sin(_t * 2.4) * 0.35 * k
	var tail_base := c + Vector2(-8 * facing_x, 4)
	var tail_mid := tail_base + Vector2(-9 * facing_x, -4).rotated(sway)
	var tail_tip := tail_mid + Vector2(-6 * facing_x, -9).rotated(sway * 1.5)
	draw_circle(tail_base, 5.5, Palette.CREAM)
	draw_circle(tail_mid, 6.0, Palette.CREAM)
	draw_circle(tail_tip, 5.0, Palette.TURQUOISE)

	# Ears
	for ear_side: float in [-1.0, 1.0]:
		var base := c + Vector2(6.0 * ear_side, -8)
		var ear := PackedVector2Array([base + Vector2(-4, 2), base + Vector2(4, 2), base + Vector2(2.0 * ear_side, -9)])
		draw_colored_polygon(ear, Palette.CREAM)
		var inner := PackedVector2Array([base + Vector2(-1.5, 1), base + Vector2(1.5, 1), base + Vector2(1.6 * ear_side, -5)])
		draw_colored_polygon(inner, Palette.LAVENDER)

	# Body / head (one round shape keeps the silhouette friendly)
	draw_circle(c, 11.0, Palette.IVORY)
	draw_circle(c + Vector2(0, 4), 8.0, Palette.CREAM)
	draw_arc(c, 11.0, 0.0, TAU, 32, Palette.with_alpha(Palette.GOLD_DEEP, 0.5), 1.5, true)

	# Face: happy squint after a reaction, otherwise round eyes
	var eye_y := c.y - 1.0
	var ex := 2.0 * facing_x
	if _curl > 0.5:
		# Curled up and dozing: closed eyes, the tail wrapped around the front.
		draw_arc(Vector2(-4 + ex, eye_y), 2.2, 0.0, PI, 8, Palette.INK, 1.5, true)
		draw_arc(Vector2(4 + ex, eye_y), 2.2, 0.0, PI, 8, Palette.INK, 1.5, true)
		draw_arc(c + Vector2(0, 3), 12.0, 0.25, PI - 0.25, 16, Palette.CREAM, 5.0, true)
		draw_circle(c + Vector2(-11.5 * facing_x, 7), 3.2, Palette.TURQUOISE)
	elif _happy > 0.0:
		draw_arc(Vector2(-4 + ex, eye_y + 1), 2.2, PI, TAU, 8, Palette.INK, 1.6, true)
		draw_arc(Vector2(4 + ex, eye_y + 1), 2.2, PI, TAU, 8, Palette.INK, 1.6, true)
	else:
		draw_circle(Vector2(-4 + ex, eye_y), 1.8, Palette.INK)
		draw_circle(Vector2(4 + ex, eye_y), 1.8, Palette.INK)
	draw_circle(Vector2(ex, eye_y + 3.5), 1.1, Palette.VIOLET_DARK)
	draw_circle(Vector2(-7 + ex, eye_y + 3), 1.6, Palette.with_alpha(Color("#f4a6a6"), 0.7))
	draw_circle(Vector2(7 + ex, eye_y + 3), 1.6, Palette.with_alpha(Color("#f4a6a6"), 0.7))

	# Discovery sparkles
	if _happy > 0.0:
		var a := minf(1.0, _happy)
		for i in 5:
			var ang := _t * 1.5 + i * TAU / 5.0
			var p := c + Vector2(cos(ang), sin(ang)) * (18.0 + (1.4 - _happy) * 12.0)
			draw_line(p + Vector2(-3, 0), p + Vector2(3, 0), Palette.with_alpha(Palette.GOLD, a), 1.5, true)
			draw_line(p + Vector2(0, -3), p + Vector2(0, 3), Palette.with_alpha(Palette.GOLD, a), 1.5, true)
