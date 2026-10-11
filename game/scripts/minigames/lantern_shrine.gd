class_name LanternShrine
extends Interactable
## Stone shrine that starts (or gently ends) Lantern Catch.
## One bowl lights up for each Lantern Night completed this session.

const BOWL_COUNT := 3

var night_active: bool = false
var lit_bowls: int = 0
var _t: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	reach_bonus = 18.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 30)
	col.shape = shape
	col.position = Vector2(0, -12)
	body.add_child(col)
	add_child(body)
	_light = GlowTexture.make_light(Palette.GOLD_SOFT, 2.0, 0.0)
	_light.position = Vector2(0, -60)
	add_child(_light)


func get_prompt() -> String:
	if night_active:
		return "End Lantern Night (no penalty)"
	if lit_bowls > 0:
		return "Begin another Lantern Night"
	return "Begin Lantern Night (optional)"


func set_lit_bowls(count: int) -> void:
	lit_bowls = clampi(count, 0, BOWL_COUNT)
	queue_redraw()


func set_night_amount(amount: float) -> void:
	_light.enabled = amount > 0.01
	_light.energy = 0.5 * amount


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 60.0, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Steps and pedestal
	draw_rect(Rect2(-52, -14, 104, 14), Palette.STONE_DARK)
	draw_rect(Rect2(-42, -30, 84, 18), Palette.STONE)
	draw_rect(Rect2(-14, -70, 28, 42), Palette.STONE)
	draw_line(Vector2(-14, -70), Vector2(14, -70), Palette.IVORY, 2.0)
	# Crescent emblem: a shape cue for "night"
	draw_circle(Vector2(0, -52), 8.0, Palette.GOLD_SOFT)
	draw_circle(Vector2(4, -55), 7.0, Palette.STONE)
	# Bowls
	for i in BOWL_COUNT:
		var p := Vector2(-34 + i * 34, -34 if i != 1 else -76)
		draw_circle(p, 9.0, Palette.STONE_DARK)
		if i < lit_bowls:
			var flicker := 0.85 + 0.15 * sin(_t * 3.0 + i)
			draw_circle(p + Vector2(0, -6), 12.0 * flicker, Palette.with_alpha(Palette.GOLD, 0.3))
			draw_circle(p + Vector2(0, -5), 5.0 * flicker, Palette.GOLD_SOFT)
	if night_active:
		draw_arc(Vector2(0, -40), 60.0 + sin(_t * 1.5) * 4.0, 0.0, TAU, 40, Palette.with_alpha(Palette.GOLD_SOFT, 0.5), 2.0, true)
	draw_interaction_cues(48.0, Vector2(0, -16))
