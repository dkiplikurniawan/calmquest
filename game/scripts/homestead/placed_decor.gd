class_name PlacedDecor
extends Node2D
## A decoration placed on a build grid. Solid furniture gets a collision box;
## lamps get a warm glow at night. Positioned at the footprint's bottom center
## so it y-sorts with the player.

var item_id: String = ""
var area_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var rot: int = 0
var footprint: Rect2 = Rect2()
var _light: PointLight2D


func setup(area: BuildArea, p: Dictionary) -> void:
	item_id = String(p["item"])
	area_id = area.id
	cell = Vector2i(int(p["x"]), int(p["y"]))
	rot = int(p.get("rot", 0))
	var rect := area.footprint_rect(cell, DecorRules.size_of(item_id), rot)
	position = Vector2(rect.get_center().x, rect.end.y - 4.0)
	footprint = Rect2(rect.position - position, rect.size)
	var data := DecorRules.decor_data(item_id)
	if String(data.get("layer", "object")) == "floor":
		z_index = -4
	if bool(data.get("solid", false)):
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size * Vector2(0.8, 0.45)
		col.shape = shape
		col.position = Vector2(0, -rect.size.y * 0.25)
		body.add_child(col)
		add_child(body)
	if bool(data.get("light", false)):
		_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.3, 0.0)
		_light.position = Vector2(0, -rect.size.y * 0.6)
		add_child(_light)


func set_night_amount(amount: float) -> void:
	if _light != null:
		_light.enabled = amount > 0.05
		_light.energy = 0.55 * amount


func _draw() -> void:
	var data := DecorRules.decor_data(item_id)
	if String(data.get("layer", "object")) != "floor":
		BiomeDecorArt.shadow(self, footprint.size.x * 0.35)
	var size := minf(footprint.size.x, footprint.size.y) * 0.95
	if footprint.size.x > footprint.size.y * 1.5 or footprint.size.y > footprint.size.x * 1.5:
		size = maxf(footprint.size.x, footprint.size.y) * 0.5
	draw_set_transform(Vector2(0, footprint.position.y + footprint.size.y / 2.0), PI / 2.0 if rot % 2 == 1 and DecorRules.size_of(item_id) == Vector2i.ONE else 0.0, Vector2.ONE)
	ItemArt.draw(self, Vector2.ZERO, size, item_id)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
