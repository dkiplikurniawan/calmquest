class_name PathBarrier
extends Node2D
## The fallen rocks on the old mountain path to the Frostbloom Highlands. They
## fill the narrow pass completely until the path is restored (flag), then
## they are gone and new wooden steps lead up.

var open_flag: String = "highlands_path_open"
var width: float = 256.0
var _body: StaticBody2D


func _ready() -> void:
	_body = StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 90)
	col.shape = shape
	_body.add_child(col)
	add_child(_body)
	sync()


func is_open() -> bool:
	return GameState.has_flag(open_flag)


func sync() -> void:
	for c in _body.get_children():
		(c as CollisionShape2D).set_deferred("disabled", is_open())
	queue_redraw()


func _draw() -> void:
	if is_open():
		for i in 5:
			var y := 50.0 - i * 26.0
			draw_rect(Rect2(-60, y - 8, 120, 16), Palette.BARK)
			draw_line(Vector2(-60, y + 8), Vector2(60, y + 8), Palette.BARK_DARK, 2.0)
		for x: float in [-70.0, 70.0]:
			draw_line(Vector2(x, 70), Vector2(x, -70), Color("#c2b280"), 3.0)
		return
	BiomeDecorArt.shadow(self, width * 0.5)
	for r: Array in [[Vector2(-90, 10), 46.0], [Vector2(-20, 20), 52.0], [Vector2(60, 6), 48.0], [Vector2(100, 24), 34.0], [Vector2(-60, -30), 36.0], [Vector2(20, -34), 40.0], [Vector2(-110, -10), 30.0]]:
		draw_circle(r[0] as Vector2, float(r[1]), Palette.STONE_DARK)
		draw_circle((r[0] as Vector2) + Vector2(-8, -10), float(r[1]) * 0.35, Palette.with_alpha(Palette.IVORY, 0.25))
	draw_circle(Vector2(0, -50), 10.0, Color("#f4f8fc"))
