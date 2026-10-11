class_name SceneryPiece
extends Node2D
## Authored, non-interactive scenery that gives a region its character:
## abandoned woodcutter cabins in Misty Pinewood, tide pools on the coast,
## a stranded hull on the isle. Solid pieces have collision.

var style: String = "cabin"
var variant: int = 0
var _t: float = 0.0


func _ready() -> void:
	if style in ["cabin", "hull"]:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(150, 54) if style == "cabin" else Vector2(220, 60)
		col.shape = shape
		col.position = Vector2(0, -20)
		body.add_child(col)
		add_child(body)
	if style == "tide_pool":
		z_index = -3


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if style == "tide_pool" and ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	match style:
		"cabin":
			_cabin()
		"tide_pool":
			_tide_pool()
		"hull":
			_hull()


func _cabin() -> void:
	BiomeDecorArt.shadow(self, 100.0)
	var wall := Color("#8a6f5e")
	draw_rect(Rect2(-75, -96, 150, 96), wall)
	for i in 6:
		draw_line(Vector2(-75, -96 + i * 16), Vector2(75, -96 + i * 16), wall.darkened(0.2), 2.0)
	# A roof that has partly fallen in, softened by moss.
	draw_colored_polygon(PackedVector2Array([Vector2(-90, -96), Vector2(-10, -150), Vector2(20, -128), Vector2(10, -96)]), Color("#7a5f6f"))
	draw_colored_polygon(PackedVector2Array([Vector2(30, -110), Vector2(90, -96), Vector2(40, -96)]), Color("#7a5f6f"))
	for p: Vector2 in [Vector2(-60, -100), Vector2(-30, -120), Vector2(50, -100), Vector2(-70, -10), Vector2(64, -6)]:
		draw_circle(p, 10.0, Color("#6f9b7a"))
	draw_rect(Rect2(-18, -60, 36, 60), Palette.NIGHT_DEEP)
	draw_rect(Rect2(36, -70, 26, 22), Palette.with_alpha(Palette.SKY, 0.5))
	draw_line(Vector2(36, -59), Vector2(62, -59), wall.darkened(0.3), 2.0)
	if variant % 2 == 1:
		# A neat stack of old logs by the wall.
		for i in 3:
			draw_circle(Vector2(-96, -10 - i * 14), 8.0, Palette.BARK)
			draw_circle(Vector2(-96, -10 - i * 14), 4.0, Palette.PATH_EDGE)


func _tide_pool() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	for i in 9:
		var a := TAU * float(i) / 9.0
		draw_circle(Vector2(cos(a), sin(a)) * 62.0, 16.0, Palette.STONE_DARK)
	draw_circle(Vector2.ZERO, 58.0, Palette.WATER)
	draw_circle(Vector2(-10, -8), 40.0, Palette.with_alpha(Palette.SKY, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var shimmer := 0.4 + 0.3 * sin(_t * 1.5 + variant)
	draw_line(Vector2(-24, -6), Vector2(-4, -6), Palette.with_alpha(Palette.IVORY, shimmer), 2.0)
	# A starfish and an anemone.
	var star := PackedVector2Array()
	for i in 10:
		var r := 9.0 if i % 2 == 0 else 4.0
		var a := TAU * float(i) / 10.0 - PI / 2.0
		star.append(Vector2(18, 6) + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(star, Color("#f4a259"))
	for i in 6:
		var a := TAU * float(i) / 6.0 + sin(_t + i) * 0.2
		draw_line(Vector2(-22, 8), Vector2(-22, 8) + Vector2(cos(a), sin(a)) * 8.0, Color("#f7b2c4"), 2.0)


func _hull() -> void:
	BiomeDecorArt.shadow(self, 130.0)
	var hull := PackedVector2Array([Vector2(-130, -40), Vector2(120, -60), Vector2(100, 0), Vector2(-110, 6)])
	draw_colored_polygon(hull, Color("#9c7b62"))
	for i in 4:
		draw_line(Vector2(-120, -30 + i * 9), Vector2(110, -50 + i * 12), Palette.BARK_DARK, 2.0)
	draw_line(Vector2(-20, -50), Vector2(-60, -150), Palette.BARK_DARK, 7.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-58, -146), Vector2(-20, -120), Vector2(-46, -96)]), Palette.with_alpha(Palette.CREAM, 0.8))
