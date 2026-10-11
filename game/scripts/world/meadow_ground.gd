class_name MeadowGround
extends Node2D
## Ground details of the Whispering Meadow region that the overworld shader
## does not draw: the Heart Tree plaza and the pond (with its collision).
## Placed at MeadowLayout.ORIGIN; everything here is in meadow-local space.
## (In V1 this node also drew the whole map and its boundary walls; the V2
## Terrain now owns the ground, paths and world boundary.)


func _ready() -> void:
	z_index = -10
	position = MeadowLayout.ORIGIN
	_build_pond_collision()


func _build_pond_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "PondCollision"
	var poly := CollisionPolygon2D.new()
	poly.polygon = _ellipse_points(MeadowLayout.POND_CENTER, MeadowLayout.POND_RADII * 0.92, 28)
	body.add_child(poly)
	add_child(body)


static func _ellipse_points(center: Vector2, radii: Vector2, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


func _draw() -> void:
	# Garden plaza around the Heart Tree.
	var plaza := MeadowLayout.HEART_TREE + Vector2(0, 70)
	draw_set_transform(plaza, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 250.0, Palette.PATH_EDGE)
	draw_circle(Vector2.ZERO, 240.0, Palette.with_alpha(Palette.PATH, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Pond with a soft rim, highlights and lily pads.
	var pc := MeadowLayout.POND_CENTER
	var pr := MeadowLayout.POND_RADII
	draw_colored_polygon(_ellipse_points(pc, pr + Vector2(14, 10), 40), Palette.SAGE_DARK)
	draw_colored_polygon(_ellipse_points(pc, pr, 40), Palette.WATER_DEEP)
	draw_colored_polygon(_ellipse_points(pc + Vector2(-10, -6), pr * 0.82, 40), Palette.WATER)
	draw_line(pc + Vector2(-80, -30), pc + Vector2(-20, -40), Palette.with_alpha(Palette.IVORY, 0.6), 3.0, true)
	draw_line(pc + Vector2(30, 20), pc + Vector2(90, 12), Palette.with_alpha(Palette.IVORY, 0.45), 3.0, true)
	for lily: Vector2 in [Vector2(-90, 30), Vector2(70, -40), Vector2(110, 40)]:
		draw_circle(pc + lily, 14.0, Palette.SAGE)
		draw_circle(pc + lily + Vector2(3, -2), 4.0, Color("#f7b2c4"))
