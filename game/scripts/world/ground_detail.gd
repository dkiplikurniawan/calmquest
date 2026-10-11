class_name GroundDetail
extends Node2D
## Purposeful ground detail for one chunk (0.4.0), drawn in a single static
## pass under all objects: grass tufts with subtle color variation, small
## flower patches, fallen leaves or needles, pebbles along path edges, soft
## canopy shadows under trees, and small puddles after rain.
## Placement is seeded from the world seed and the chunk (it uses its own
## random stream, so the existing scenery and object ids never change), and
## nothing here has collision, so it can never block a path.
## Performance: everything is built once into a single triangle mesh per chunk
## (one draw command), rebuilt only when the ground turns wet or dry.

const Z := -9
const TUFTS := 64
const FLOWER_PATCHES := 3
const LEAVES := 26
const PUDDLES := 3
const PEBBLE_SPACING := 64.0
const TREE_KINDS: PackedStringArray = ["tree", "grove_tree", "pine", "snow_pine"]
## Region ground styles: tuft colors, whether flowers and leaves appear, puddles.
const STYLES := {
	"whispering_meadow": {"tuft": [Color("#7fb98a"), Color("#9ccf8c"), Color("#6aa77a")], "flowers": true, "leaves": "", "puddles": true},
	"firefly_grove": {"tuft": [Color("#6fa98a"), Color("#8cc49a"), Color("#5c9878")], "flowers": true, "leaves": "gold", "puddles": true},
	"crystal_creek": {"tuft": [Color("#7cbfa0"), Color("#96d0b0"), Color("#64a88a")], "flowers": true, "leaves": "", "puddles": true},
	"moonlit_sanctuary": {"tuft": [Color("#8a97b8"), Color("#a3aed0"), Color("#76839f")], "flowers": false, "leaves": "", "puddles": false},
	"misty_pinewood": {"tuft": [Color("#5f8f74"), Color("#729f84"), Color("#4f7c63")], "flowers": false, "leaves": "needles", "puddles": true},
	"sunpetal_coast": {"tuft": [Color("#c9b98a"), Color("#d8c99b"), Color("#b8a676")], "flowers": false, "leaves": "", "puddles": false},
	"sunpetal_isles": {"tuft": [Color("#c9b98a"), Color("#d8c99b"), Color("#b8a676")], "flowers": false, "leaves": "", "puddles": false},
	"frostbloom_highlands": {"tuft": [Color("#e8f0f8"), Color("#d3e1ee"), Color("#f6fbff")], "flowers": false, "leaves": "", "puddles": false},
}
const FLOWER_SETS := [[Color("#f7b2c4"), Color("#fff6e5")], [Color("#ffd166"), Color("#fff3c4")], [Color("#c3b1e1"), Color("#a7d8f0")]]

var tufts: Array = []
var flowers: Array = []
var leaves: Array = []
var pebbles: Array = []
var canopy: Array = []
var puddles: Array = []
var _wet: bool = false
var _check_t: float = 0.0
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


## Seeded placement for `chunk`. `objects` is the chunk's generated scenery
## (for canopy shadows under its trees).
func setup(world: WorldData, chunk: Vector2i, objects: Array[Dictionary]) -> void:
	z_index = Z
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, chunk.x, chunk.y, "ground"])
	var rect := world.chunk_rect(chunk)
	for i in TUFTS:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var style := _style(world, p)
		var shade := rng.randi_range(0, 2)
		var tilt := rng.randf_range(-0.35, 0.35)
		var height := rng.randf_range(5.0, 10.0)
		if style.is_empty() or not _open_ground(world, p, 4.0):
			continue
		tufts.append([p, (style["tuft"] as Array)[shade], tilt, height])
	for i in FLOWER_PATCHES:
		var c := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var set_i := rng.randi_range(0, FLOWER_SETS.size() - 1)
		var count := rng.randi_range(5, 9)
		var style := _style(world, c)
		var dots: Array = []
		for k in count:
			dots.append([c + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-14.0, 14.0)), (FLOWER_SETS[set_i] as Array)[k % 2], rng.randf_range(1.8, 3.0)])
		if not style.is_empty() and bool(style["flowers"]) and _open_ground(world, c, 30.0):
			flowers.append_array(dots)
	for i in LEAVES:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var angle := rng.randf_range(0.0, TAU)
		var tint := rng.randf_range(0.0, 1.0)
		var style := _style(world, p)
		if style.is_empty() or String(style["leaves"]).is_empty() or not _open_ground(world, p, 2.0):
			continue
		var col := Color("#d9a74a").lerp(Color("#c97b42"), tint) if style["leaves"] == "gold" else Color("#8a6a4a").lerp(Color("#a8865c"), tint)
		leaves.append([p, angle, col, String(style["leaves"])])
	for path in world.paths:
		var pts: PackedVector2Array = path["points"]
		var half := float(path["width"]) * 0.5 + 5.0
		for s in range(pts.size() - 1):
			var a := pts[s]
			var b := pts[s + 1]
			var seg := b - a
			var length := seg.length()
			if length < 1.0 or not rect.grow(40.0).intersects(Rect2(a, Vector2.ZERO).expand(b)):
				continue
			var normal := seg.orthogonal().normalized()
			var n := int(length / PEBBLE_SPACING)
			for k in n:
				var side := 1.0 if (k + s) % 2 == 0 else -1.0
				var p := a + seg * (float(k) + 0.5) / float(n) + normal * side * (half + rng.randf_range(0.0, 6.0))
				var r := rng.randf_range(2.2, 4.0)
				if rect.has_point(p) and world.distance_to_river(p) > 6.0 and not world.is_blocked_at(p):
					pebbles.append([p, r])
	for o in objects:
		if TREE_KINDS.has(String(o["kind"])):
			canopy.append([o["pos"] + Vector2(14.0, 10.0), 62.0 * float(o["size"])])
	for i in PUDDLES:
		var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
		var w := rng.randf_range(16.0, 30.0)
		var style := _style(world, p)
		if not style.is_empty() and bool(style["puddles"]) and not world.is_blocked_at(p) and world.distance_to_river(p) > 30.0:
			puddles.append([p, w])
	_wet = is_wet()
	_build_mesh()


static func _style(world: WorldData, p: Vector2) -> Dictionary:
	return STYLES.get(world.region_at(p), {})


## Ground that is walkable, off the paths and rivers.
static func _open_ground(world: WorldData, p: Vector2, margin: float) -> bool:
	return not world.is_blocked_at(p) and world.distance_to_paths(p) > margin and world.distance_to_river(p) > margin


## Puddles show on a rainy day and the day after.
static func is_wet() -> bool:
	return Weather.is_raining() or Weather.rained_on(TimeManager.day - 1)


func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 2.0
	var wet := is_wet()
	if wet != _wet:
		_wet = wet
		_build_mesh()


## Number of triangles in this chunk's ground mesh.
func triangle_count() -> int:
	return _indices.size() / 3


## Builds the whole layer as one triangle list, in painter's order (the GPU
## draws the triangles of one command in order, so later shapes sit on top).
func _build_mesh() -> void:
	_points = PackedVector2Array()
	_colors = PackedColorArray()
	_indices = PackedInt32Array()
	for c: Array in canopy:
		_ellipse(c[0], float(c[1]), float(c[1]) * 0.55, 0.0, Color(0.08, 0.16, 0.12, 0.07), 16)
		_ellipse(c[0], float(c[1]) * 0.6, float(c[1]) * 0.33, 0.0, Color(0.08, 0.16, 0.12, 0.05), 12)
	if _wet:
		for pd: Array in puddles:
			var p: Vector2 = pd[0]
			var w := float(pd[1])
			_ellipse(p, w, w * 0.45, 0.0, Color("#8fb6c8"), 14)
			_ellipse(p + Vector2(-w * 0.25, -w * 0.07), w * 0.45, w * 0.2, 0.0, Color(1, 1, 1, 0.35), 10)
	for pb: Array in pebbles:
		_ellipse(pb[0], float(pb[1]), float(pb[1]), 0.0, Color("#b9aa92"), 7)
		_ellipse((pb[0] as Vector2) + Vector2(-0.8, -0.8), float(pb[1]) * 0.5, float(pb[1]) * 0.5, 0.0, Color("#d6c9b2"), 5)
	for l: Array in leaves:
		var p: Vector2 = l[0]
		if l[3] == "needles":
			var dir := Vector2.from_angle(float(l[1]))
			_quad_line(p - dir * 4.0, p + dir * 4.0, 1.4, l[2])
		else:
			_ellipse(p, 3.2, 1.8, float(l[1]), l[2], 7)
	for t: Array in tufts:
		var p: Vector2 = t[0]
		var col: Color = t[1]
		var tilt := float(t[2])
		var h := float(t[3])
		for k in 3:
			var off := float(k - 1) * 2.5
			var tip := p + Vector2(off + (tilt + (k - 1) * 0.35) * h, -h * (0.8 + 0.2 * (k % 2)))
			_triangle(p + Vector2(off - 1.0, 0), p + Vector2(off + 1.0, 0), tip, col)
	for f: Array in flowers:
		_ellipse(f[0], float(f[2]), float(f[2]), 0.0, f[1], 7)
		_ellipse(f[0], float(f[2]) * 0.35, float(f[2]) * 0.35, 0.0, Color("#fff8e1"), 5)
	queue_redraw()


func _ellipse(center: Vector2, rx: float, ry: float, angle: float, col: Color, segments: int) -> void:
	var base := _points.size()
	_points.append(center)
	_colors.append(col)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		_points.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(angle))
		_colors.append(col)
	for i in segments:
		_indices.append_array([base, base + 1 + i, base + 1 + (i + 1) % segments])


func _triangle(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var base := _points.size()
	_points.append_array([a, b, c])
	_colors.append_array([col, col, col])
	_indices.append_array([base, base + 1, base + 2])


func _quad_line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var n := (b - a).orthogonal().normalized() * width * 0.5
	var base := _points.size()
	_points.append_array([a - n, a + n, b + n, b - n])
	_colors.append_array([col, col, col, col])
	_indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _draw() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _indices, _points, _colors)
