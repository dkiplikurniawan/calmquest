class_name MenuBackdrop
extends Control
## Calm animated background for menus: a sky that drifts slowly between dusk
## and twilight, three layers of floating Lumeria isles with gentle parallax
## (the mouse moves them a little too), fireflies and drifting motes of light.
## With Reduce motion the sky holds still and nothing drifts.

const MOTE_COUNT := 18
const FIREFLY_COUNT := 26
const STAR_COUNT := 60
const SKY_BANDS := 72
const SEED := 77
## One full dusk -> twilight -> dusk drift, in seconds.
const PALETTE_CYCLE := 150.0
const DUSK_TOP := Color("#2b2f5a")
const DUSK_HORIZON := Color("#c98a8f")
const TWILIGHT_TOP := Color("#151a33")
const TWILIGHT_HORIZON := Color("#6a5a9c")
## [x, y, width, depth]: depth 0 = far (small, faint, slow), 1 = near.
const ISLES := [
	[0.08, 0.40, 70.0, 0.0], [0.36, 0.34, 60.0, 0.0], [0.66, 0.38, 80.0, 0.0], [0.92, 0.33, 55.0, 0.0],
	[0.24, 0.55, 120.0, 0.5], [0.78, 0.52, 130.0, 0.5],
	[0.14, 0.72, 190.0, 1.0], [0.56, 0.86, 240.0, 1.0], [0.92, 0.74, 170.0, 1.0],
]

var _motes: Array = []
var _fireflies: Array = []
var _stars: Array = []
var _t: float = 0.0
var _mouse := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in STAR_COUNT:
		_stars.append([rng.randf(), rng.randf() * 0.5, rng.randf_range(0.8, 1.8), rng.randf_range(0.0, TAU)])
	for i in MOTE_COUNT:
		_motes.append([rng.randf(), rng.randf(), rng.randf_range(2.0, 4.5), rng.randf_range(0.0, TAU), rng.randf_range(0.004, 0.012)])
	for i in FIREFLY_COUNT:
		_fireflies.append([rng.randf(), rng.randf_range(0.45, 0.95), rng.randf_range(0.0, TAU), rng.randf_range(0.2, 0.5), rng.randf_range(18.0, 46.0)])


## 0 = dusk, 1 = twilight. Holds at dusk-ish with Reduce motion.
func palette_phase() -> float:
	if GameSettings.reduce_motion:
		return 0.35
	return 0.5 - 0.5 * cos(_t * TAU / PALETTE_CYCLE)


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if not GameSettings.reduce_motion and size.x > 0.0:
		var target := (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
		_mouse = _mouse.lerp(target.clamp(Vector2(-1, -1), Vector2(1, 1)), 1.0 - exp(-2.0 * delta))
	else:
		_mouse = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var phase := palette_phase()
	var top := DUSK_TOP.lerp(TWILIGHT_TOP, phase)
	var horizon := DUSK_HORIZON.lerp(TWILIGHT_HORIZON, phase)
	for i in SKY_BANDS:
		var t0 := float(i) / SKY_BANDS
		var color := top.lerp(Palette.NIGHT, minf(t0 * 1.4, 1.0)).lerp(horizon, maxf(0.0, t0 - 0.45) * 1.3)
		draw_rect(Rect2(0, h * t0, w, h / SKY_BANDS + 1.0), color)
	for s: Array in _stars:
		var a := (0.25 + 0.3 * phase) + 0.2 * sin(_t * 0.8 + float(s[3]))
		draw_circle(Vector2(float(s[0]) * w, float(s[1]) * h), float(s[2]), Palette.with_alpha(Palette.CREAM, a))
	for isle: Array in ISLES:
		var depth := float(isle[3])
		var drift := sin(_t * (0.05 + 0.08 * depth) + float(isle[0]) * 7.0) * (10.0 + 30.0 * depth)
		var parallax := _mouse * Vector2(8.0 + 26.0 * depth, 4.0 + 10.0 * depth)
		var bob := sin(_t * (0.35 + 0.15 * depth) + float(isle[1]) * 9.0) * (2.0 + 5.0 * depth)
		var center := Vector2(float(isle[0]) * w + drift, float(isle[1]) * h + bob) + parallax
		_island(center, float(isle[2]) * (0.8 + 0.4 * h / 720.0), depth, phase)
	for m: Array in _motes:
		var x := fposmod(float(m[0]) * w + sin(_t * 0.3 + float(m[3])) * 30.0, w)
		var y := fposmod(float(m[1]) * h - _t * float(m[4]) * h, h)
		var r := float(m[2])
		draw_circle(Vector2(x, y), r * 3.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.14))
		draw_circle(Vector2(x, y), r, Palette.with_alpha(Palette.GOLD_SOFT, 0.8))
	# Fireflies: small warm lights that loop slowly and blink.
	for f: Array in _fireflies:
		var speed := float(f[3])
		var radius := float(f[4])
		var p := Vector2(float(f[0]) * w, float(f[1]) * h) + Vector2(cos(_t * speed + float(f[2])), sin(_t * speed * 1.3 + float(f[2]))) * radius
		var blink := 0.35 + 0.65 * maxf(0.0, sin(_t * 1.7 + float(f[2]) * 3.0))
		draw_circle(p, 6.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.12 * blink))
		draw_circle(p, 1.8, Palette.with_alpha(Color("#fff3b0"), blink))


func _island(center: Vector2, width: float, depth: float, phase: float) -> void:
	var fade := 0.45 + 0.55 * depth
	var rock := PackedVector2Array([
		center + Vector2(-width * 0.5, 0), center + Vector2(width * 0.5, 0),
		center + Vector2(width * 0.25, width * 0.28), center + Vector2(0, width * 0.42),
		center + Vector2(-width * 0.28, width * 0.25),
	])
	draw_colored_polygon(rock, Palette.with_alpha(Palette.VIOLET_DARK, 0.75 * fade + 0.1))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, width * 0.52, Palette.with_alpha(Palette.SAGE_DARK, fade))
	draw_circle(Vector2(0, -6), width * 0.48, Palette.with_alpha(Palette.SAGE, fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center + Vector2(-width * 0.18, -width * 0.12), width * 0.12, Palette.with_alpha(Palette.FOREST, fade))
	draw_circle(center + Vector2(width * 0.12, -width * 0.16), width * 0.15, Palette.with_alpha(Palette.SAGE_DARK, fade))
	if depth > 0.4:
		# A tiny lit window or lantern on the nearer isles, warmer toward twilight.
		var glow := 0.6 + 0.4 * phase
		draw_circle(center + Vector2(0, -width * 0.1), width * 0.07, Palette.with_alpha(Palette.GOLD_SOFT, 0.25 * glow))
		draw_circle(center + Vector2(0, -width * 0.1), width * 0.04, Palette.with_alpha(Palette.GOLD_SOFT, 0.95 * glow))
