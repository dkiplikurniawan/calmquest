class_name Decoration
extends Node2D
## Reusable procedural scenery: trees, bushes, flowers, stones, cottage...
## The origin is the object's base, so a y-sorted parent layers it correctly.
## Solid objects add their own small collision footprint.

## Values 0-8 are used by MeadowLayout.LANDMARKS; new kinds are appended (V2 biomes).
enum Kind {
	TREE, PINE, BUSH, FLOWER, STONE, MUSHROOM, GRASS, COTTAGE, FENCE,
	GROVE_TREE, GLOWCAP, FERN, REEDS, CRYSTAL, MOON_LILY, PILLAR, BEACH_GRASS,
	DRIFTWOOD, SHELL, SNOW_PINE, FROST_FLOWER, BOULDER, CLIFF_BOULDER,
	STUMP, BIRD_BATH, TINY_SHRINE, MUSHROOM_RING,
}

## Names used by ChunkGenerator / overworld.json decoration profiles.
const KIND_NAMES := {
	"tree": Kind.TREE, "pine": Kind.PINE, "bush": Kind.BUSH, "flower": Kind.FLOWER,
	"stone": Kind.STONE, "mushroom": Kind.MUSHROOM, "grass": Kind.GRASS,
	"grove_tree": Kind.GROVE_TREE, "glowcap": Kind.GLOWCAP, "fern": Kind.FERN,
	"reeds": Kind.REEDS, "crystal": Kind.CRYSTAL, "moon_lily": Kind.MOON_LILY,
	"pillar": Kind.PILLAR, "beach_grass": Kind.BEACH_GRASS, "driftwood": Kind.DRIFTWOOD,
	"shell": Kind.SHELL, "snow_pine": Kind.SNOW_PINE, "frost_flower": Kind.FROST_FLOWER,
	"boulder": Kind.BOULDER, "cliff_boulder": Kind.CLIFF_BOULDER,
	"stump": Kind.STUMP, "bird_bath": Kind.BIRD_BATH, "tiny_shrine": Kind.TINY_SHRINE, "mushroom_ring": Kind.MUSHROOM_RING,
}
## Kinds that sway gently in the breeze (rotation only, no redraw).
const SWAYING := [Kind.FLOWER, Kind.GRASS, Kind.FERN, Kind.REEDS, Kind.MOON_LILY, Kind.BEACH_GRASS, Kind.FROST_FLOWER]

const FLOWER_COLORS: Array[Color] = [Color("#c3b1e1"), Color("#ffd166"), Color("#a7d8f0"), Color("#f7b2c4"), Color("#fff6e5")]

@export var kind: Kind = Kind.TREE
@export var size: float = 1.0
@export var variant: int = 0

var sway_intensity: float = 1.0
var _t: float = 0.0


func _ready() -> void:
	_t = float(variant % 97) * 0.37
	_add_collision()
	set_process(SWAYING.has(kind))


static func kind_from_name(kind_name: String) -> Kind:
	if not KIND_NAMES.has(kind_name):
		push_warning("Decoration: unknown kind '%s'." % kind_name)
		return Kind.GRASS
	return KIND_NAMES[kind_name]


func _process(delta: float) -> void:
	_t += delta
	# Gentle sway by rotating the whole node: no redraw needed.
	rotation = sin(_t * 1.3) * 0.06 * sway_intensity


func _add_collision() -> void:
	var shape: Shape2D = null
	var offset := Vector2.ZERO
	match kind:
		Kind.TREE:
			var c := CircleShape2D.new()
			c.radius = 16.0 * size
			shape = c
			offset = Vector2(0, -6)
		Kind.PINE:
			var c := CircleShape2D.new()
			c.radius = 14.0 * size
			shape = c
			offset = Vector2(0, -6)
		Kind.STONE:
			var c := CircleShape2D.new()
			c.radius = 15.0 * size
			shape = c
			offset = Vector2(0, -6)
		Kind.COTTAGE:
			var r := RectangleShape2D.new()
			r.size = Vector2(180, 60) * size
			shape = r
			offset = Vector2(0, -30)
		Kind.FENCE:
			var r := RectangleShape2D.new()
			r.size = Vector2(110, 14) * size
			shape = r
			offset = Vector2(0, -6)
		Kind.GROVE_TREE, Kind.SNOW_PINE, Kind.PILLAR, Kind.CRYSTAL, Kind.BOULDER:
			var radius_by_kind := {Kind.GROVE_TREE: 16.0, Kind.SNOW_PINE: 14.0, Kind.PILLAR: 14.0, Kind.CRYSTAL: 12.0, Kind.BOULDER: 22.0}
			var c := CircleShape2D.new()
			c.radius = float(radius_by_kind[kind]) * size
			shape = c
			offset = Vector2(0, -6)
	if shape == null:
		return
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = offset
	body.add_child(col)
	add_child(body)


func _draw() -> void:
	match kind:
		Kind.TREE:
			_draw_tree()
		Kind.PINE:
			_draw_pine()
		Kind.BUSH:
			_draw_bush()
		Kind.FLOWER:
			_draw_flower()
		Kind.STONE:
			_draw_stone()
		Kind.MUSHROOM:
			_draw_mushroom()
		Kind.GRASS:
			_draw_grass()
		Kind.COTTAGE:
			_draw_cottage()
		Kind.FENCE:
			_draw_fence()
		_:
			BiomeDecorArt.draw(self, kind, size, variant)


func _shadow(radius: float) -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tree() -> void:
	var s := size
	_shadow(46.0 * s)
	var trunk := PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(7, -46), Vector2(-7, -46)])
	for i in trunk.size():
		trunk[i] *= s
	draw_colored_polygon(trunk, Palette.BARK)
	draw_line(Vector2(2, -6) * s, Vector2(3, -40) * s, Palette.BARK_DARK, 2.0, true)
	var greens: Array[Color] = [Palette.SAGE_DARK, Palette.SAGE, Palette.GRASS, Palette.MINT]
	var shift := (variant % 3) * 3.0
	var blobs := [
		[Vector2(-26 + shift, -66), 28.0, 0], [Vector2(24, -64 - shift), 27.0, 0],
		[Vector2(0, -88), 32.0, 1], [Vector2(-20, -82), 22.0, 1], [Vector2(22, -84), 22.0, 2],
		[Vector2(-6, -100), 18.0, 2], [Vector2(10, -70), 18.0, 3],
	]
	for b: Array in blobs:
		draw_circle((b[0] as Vector2) * s, float(b[1]) * s, greens[int(b[2])])
	draw_circle(Vector2(-12, -96) * s, 7.0 * s, Palette.with_alpha(Palette.IVORY, 0.25))


func _draw_pine() -> void:
	var s := size
	_shadow(32.0 * s)
	draw_rect(Rect2(Vector2(-5, -18) * s, Vector2(10, 18) * s), Palette.BARK)
	var layers := [[-18.0, 34.0, Palette.FOREST], [-48.0, 28.0, Palette.SAGE_DARK], [-74.0, 21.0, Palette.SAGE]]
	for l: Array in layers:
		var y := float(l[0]) * s
		var w := float(l[1]) * s
		var tri := PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(0, y - w * 1.25)])
		draw_colored_polygon(tri, l[2] as Color)


func _draw_bush() -> void:
	var s := size
	_shadow(30.0 * s)
	draw_circle(Vector2(-14, -14) * s, 16.0 * s, Palette.SAGE_DARK)
	draw_circle(Vector2(14, -14) * s, 16.0 * s, Palette.SAGE_DARK)
	draw_circle(Vector2(0, -22) * s, 19.0 * s, Palette.SAGE)
	draw_circle(Vector2(-6, -28) * s, 7.0 * s, Palette.with_alpha(Palette.MINT, 0.6))
	if variant % 2 == 0:
		for p: Vector2 in [Vector2(-12, -20), Vector2(8, -28), Vector2(14, -12)]:
			draw_circle(p * s, 3.0 * s, Color("#f7b2c4"))


func _draw_flower() -> void:
	var s := size
	var color: Color = FLOWER_COLORS[variant % FLOWER_COLORS.size()]
	draw_line(Vector2.ZERO, Vector2(0, -12) * s, Palette.SAGE_DARK, 2.0, true)
	draw_circle(Vector2(-3, -5) * s, 2.5 * s, Palette.SAGE)
	for i in 5:
		var a := i * TAU / 5.0
		draw_circle(Vector2(0, -14) * s + Vector2(cos(a), sin(a)) * 3.6 * s, 3.0 * s, color)
	draw_circle(Vector2(0, -14) * s, 2.2 * s, Palette.GOLD_DEEP)


func _draw_stone() -> void:
	var s := size
	_shadow(20.0 * s)
	var pts := PackedVector2Array([
		Vector2(-18, 0), Vector2(-20, -10), Vector2(-10, -22), Vector2(6, -24),
		Vector2(18, -14), Vector2(19, 0),
	])
	for i in pts.size():
		pts[i] *= s
	draw_colored_polygon(pts, Palette.STONE)
	draw_line(Vector2(-10, -18) * s, Vector2(4, -20) * s, Palette.with_alpha(Palette.IVORY, 0.6), 3.0 * s, true)
	draw_line(Vector2(-18, 0) * s, Vector2(19, 0) * s, Palette.STONE_DARK, 3.0 * s, true)


func _draw_mushroom() -> void:
	var s := size
	for m: Array in [[Vector2(0, 0), 1.0], [Vector2(12, 4), 0.7], [Vector2(-10, 3), 0.6]]:
		var p := (m[0] as Vector2) * s
		var k := float(m[1]) * s
		draw_rect(Rect2(p + Vector2(-2.5, -9) * k, Vector2(5, 9) * k), Palette.CREAM)
		draw_circle(p + Vector2(0, -10) * k, 7.0 * k, Palette.ROOF)
		draw_circle(p + Vector2(-2, -12) * k, 1.6 * k, Palette.IVORY)


func _draw_grass() -> void:
	var s := size
	for i in 4:
		var x := (i - 1.5) * 4.0 * s
		draw_line(Vector2(x, 0), Vector2(x + (i - 1.5) * 2.0 * s, -10.0 * s - (i % 2) * 4.0 * s), Palette.GRASS_DARK, 2.0, true)


func _draw_cottage() -> void:
	var s := size
	_shadow(110.0 * s)
	# Walls
	draw_rect(Rect2(Vector2(-90, -100) * s, Vector2(180, 100) * s), Palette.CREAM)
	draw_rect(Rect2(Vector2(-90, -100) * s, Vector2(180, 100) * s), Palette.PATH_EDGE, false, 3.0)
	# Roof
	var roof := PackedVector2Array([Vector2(-108, -96), Vector2(108, -96), Vector2(70, -168), Vector2(-70, -168)])
	for i in roof.size():
		roof[i] *= s
	draw_colored_polygon(roof, Palette.ROOF)
	for row in 3:
		var y := (-110.0 - row * 20.0) * s
		draw_line(Vector2(-100 + row * 12, y / s) * s, Vector2(100 - row * 12, y / s) * s, Palette.with_alpha(Palette.VIOLET_DARK, 0.35), 2.0, true)
	# Chimney
	draw_rect(Rect2(Vector2(40, -188) * s, Vector2(20, 36) * s), Palette.STONE_DARK)
	# Door
	draw_rect(Rect2(Vector2(-16, -56) * s, Vector2(32, 56) * s), Palette.BARK)
	draw_circle(Vector2(0, -56) * s, 16.0 * s, Palette.BARK)
	draw_circle(Vector2(9, -28) * s, 2.5 * s, Palette.GOLD)
	# Glowing windows
	for wx: float in [-60.0, 34.0]:
		var r := Rect2(Vector2(wx, -78) * s, Vector2(26, 26) * s)
		draw_rect(r.grow(3.0 * s), Palette.BARK_DARK)
		draw_rect(r, Palette.GOLD_SOFT)
		draw_line(r.position + Vector2(r.size.x / 2, 0), r.position + Vector2(r.size.x / 2, r.size.y), Palette.BARK_DARK, 2.0)
		draw_line(r.position + Vector2(0, r.size.y / 2), r.position + Vector2(r.size.x, r.size.y / 2), Palette.BARK_DARK, 2.0)
	# Flower boxes
	for fx: float in [-60.0, 34.0]:
		for i in 3:
			draw_circle(Vector2(fx + 5 + i * 8, -50) * s, 3.5 * s, FLOWER_COLORS[(i + variant) % FLOWER_COLORS.size()])


func _draw_fence() -> void:
	var s := size
	for i in 5:
		var x := (-50.0 + i * 25.0) * s
		draw_rect(Rect2(Vector2(x - 3 * s, -26 * s), Vector2(6, 26) * s), Palette.BARK)
		draw_circle(Vector2(x, -26 * s), 3.0 * s, Palette.BARK)
	draw_line(Vector2(-54, -18) * s, Vector2(54, -18) * s, Palette.BARK_DARK, 4.0 * s, true)
	draw_line(Vector2(-54, -8) * s, Vector2(54, -8) * s, Palette.BARK_DARK, 4.0 * s, true)
