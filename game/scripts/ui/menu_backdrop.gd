class_name MenuBackdrop
extends Control
## Calm animated background for menus: a dusk sky, floating islands of
## Lumeria Isles and a few slowly drifting motes of light.

const MOTE_COUNT := 22
const STAR_COUNT := 60
const SKY_BANDS := 72
const SEED := 77

var _motes: Array = []
var _stars: Array = []
var _t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in STAR_COUNT:
		_stars.append([rng.randf(), rng.randf() * 0.55, rng.randf_range(0.8, 1.8), rng.randf_range(0.0, TAU)])
	for i in MOTE_COUNT:
		_motes.append([rng.randf(), rng.randf(), rng.randf_range(2.0, 5.0), rng.randf_range(0.0, TAU), rng.randf_range(0.004, 0.012)])


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Vertical sky gradient from deep night blue to soft lavender at the horizon.
	var bands := SKY_BANDS
	for i in bands:
		var t0 := float(i) / bands
		var color := Palette.NIGHT_DEEP.lerp(Palette.NIGHT, minf(t0 * 1.6, 1.0)).lerp(Palette.VIOLET, maxf(0.0, t0 - 0.55) * 1.2)
		draw_rect(Rect2(0, h * t0, w, h / bands + 1.0), color)
	# Stars
	for s: Array in _stars:
		var a := 0.35 + 0.25 * sin(_t * 0.8 + float(s[3]))
		draw_circle(Vector2(float(s[0]) * w, float(s[1]) * h), float(s[2]), Palette.with_alpha(Palette.CREAM, a))
	# Floating islands (slow bob)
	_island(Vector2(w * 0.18, h * 0.62 + sin(_t * 0.5) * 6.0), 150.0)
	_island(Vector2(w * 0.82, h * 0.55 + sin(_t * 0.45 + 1.0) * 7.0), 120.0)
	_island(Vector2(w * 0.55, h * 0.82 + sin(_t * 0.4 + 2.0) * 5.0), 210.0)
	# Drifting light motes
	for m: Array in _motes:
		var x := fposmod(float(m[0]) * w + sin(_t * 0.3 + float(m[3])) * 30.0, w)
		var y := fposmod(float(m[1]) * h - _t * float(m[4]) * h, h)
		var r := float(m[2])
		draw_circle(Vector2(x, y), r * 3.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.16))
		draw_circle(Vector2(x, y), r, Palette.with_alpha(Palette.GOLD_SOFT, 0.85))


func _island(center: Vector2, width: float) -> void:
	var rock := PackedVector2Array([
		center + Vector2(-width * 0.5, 0), center + Vector2(width * 0.5, 0),
		center + Vector2(width * 0.25, width * 0.28), center + Vector2(0, width * 0.42),
		center + Vector2(-width * 0.28, width * 0.25),
	])
	draw_colored_polygon(rock, Palette.with_alpha(Palette.VIOLET_DARK, 0.9))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, width * 0.52, Palette.SAGE_DARK)
	draw_circle(Vector2(0, -6), width * 0.48, Palette.SAGE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(center + Vector2(-width * 0.18, -width * 0.12), width * 0.12, Palette.FOREST)
	draw_circle(center + Vector2(width * 0.12, -width * 0.16), width * 0.15, Palette.SAGE_DARK)
	draw_circle(center + Vector2(0, -width * 0.1), width * 0.05, Palette.with_alpha(Palette.GOLD_SOFT, 0.9))
