class_name Terrain
extends Node2D
## Builds the static, always-loaded layer of the overworld from WorldData:
## the shader-drawn ground, paths, rivers with crossings, and terrain collision
## (sea, cliffs, lakes, river banks and an outer safety ring).
##
## Nothing here is streamed: the ground is one GPU quad, and the collision is
## a few hundred simple shapes, which is cheap for a 10240 x 6144 px world.

const GROUND_SHADER := preload("res://game/shaders/ground.gdshader")
const RIVER_SHADER := preload("res://game/shaders/river.gdshader")
const NOISE_SIZE := 256
## Length of each river collision piece along the river.
const RIVER_PIECE := 60.0
## River collision is a little narrower than the water so banks feel natural.
const RIVER_COLLISION_INSET := 34.0
const SAFETY_RING := 400.0

var world: WorldData
var ground: ColorRect
var ground_material: ShaderMaterial
var river_material: ShaderMaterial
var legend_index: Dictionary = {}
var noise_texture: ImageTexture


func build(world_data: WorldData) -> void:
	world = world_data
	noise_texture = _make_noise_texture(world.world_seed)
	_build_ground()
	_build_paths()
	_build_rivers()
	_build_collision()


## 0..1, scales water and river motion (Reduce Motion).
func set_motion(amount: float) -> void:
	ground_material.set_shader_parameter("motion", amount)
	river_material.set_shader_parameter("motion", amount)


func set_restoration(amount: float) -> void:
	ground_material.set_shader_parameter("restoration", amount)


# --- Ground ---------------------------------------------------------------------

func _build_ground() -> void:
	var chars: Array = world.legend.keys()
	chars.sort()
	var palette_img := Image.create(maxi(chars.size(), 1), 3, false, Image.FORMAT_RGBA8)
	for i in chars.size():
		var entry: Dictionary = world.legend[chars[i]]
		legend_index[chars[i]] = i
		var colors: Array = entry.get("palette", ["#ff00ff", "#ff00ff"])
		palette_img.set_pixel(i, 0, Color(String(colors[0])))
		palette_img.set_pixel(i, 1, Color(String(colors[1])))
		palette_img.set_pixel(i, 2, Color(0, 0, 0, 1.0 if bool(entry.get("water", false)) else 0.0))
	var map_img := Image.create(world.width_cells, world.height_cells, false, Image.FORMAT_R8)
	for y in world.height_cells:
		for x in world.width_cells:
			var idx := int(legend_index.get(world.rows[y][x], 0))
			map_img.set_pixel(x, y, Color(idx / 255.0, 0, 0))
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	ground_material.set_shader_parameter("biome_map", ImageTexture.create_from_image(map_img))
	ground_material.set_shader_parameter("palette", ImageTexture.create_from_image(palette_img))
	ground_material.set_shader_parameter("noise_tex", noise_texture)
	ground_material.set_shader_parameter("world_size", world.world_size())
	ground_material.set_shader_parameter("cell_size", world.cell_size)
	ground_material.set_shader_parameter("warp_amount", 0.16)
	ground = ColorRect.new()
	ground.name = "Ground"
	ground.size = world.world_size()
	ground.material = ground_material
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = -20
	add_child(ground)


static func _make_noise_texture(seed_value: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var img := noise.get_seamless_image(NOISE_SIZE, NOISE_SIZE)
	return ImageTexture.create_from_image(img)


# --- Paths and rivers --------------------------------------------------------------------

func _build_paths() -> void:
	for p: Dictionary in world.paths:
		var pts: PackedVector2Array = p["points"]
		var width := float(p["width"])
		add_child(_line(pts, width + 10.0, Palette.PATH_EDGE, -16))
		add_child(_line(pts, width, Palette.PATH, -15))


func _build_rivers() -> void:
	river_material = ShaderMaterial.new()
	river_material.shader = RIVER_SHADER
	river_material.set_shader_parameter("noise_tex", noise_texture)
	for rv: Dictionary in world.rivers:
		var pts: PackedVector2Array = rv["points"]
		var width := float(rv["width"])
		add_child(_line(pts, width + 26.0, Palette.SAGE_DARK, -14))
		add_child(_line(pts, width + 8.0, Palette.WATER_DEEP, -13))
		var water := _line(pts, width - 18.0, Palette.WATER, -12)
		water.material = river_material
		add_child(water)
		var crossings := RiverCrossings.new()
		crossings.setup(rv)
		crossings.z_index = -11
		add_child(crossings)


static func _line(pts: PackedVector2Array, width: float, color: Color, z: int) -> Line2D:
	var line := Line2D.new()
	line.points = pts
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z
	return line


# --- Collision ---------------------------------------------------------------------------

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "TerrainCollision"
	add_child(body)
	# Blocked cells, merged into horizontal runs per row.
	for y in world.height_cells:
		var run_start := -1
		for x in world.width_cells + 1:
			var blocked := x < world.width_cells and bool(world.legend.get(world.rows[y][x], {}).get("blocked", true))
			if blocked and run_start < 0:
				run_start = x
			elif not blocked and run_start >= 0:
				var rect := Rect2(Vector2(run_start, y) * world.cell_size, Vector2(x - run_start, 1) * world.cell_size)
				_add_rect(body, rect.get_center(), rect.size, 0.0)
				run_start = -1
	# River banks, with gaps at bridges and stepping stones.
	for rv: Dictionary in world.rivers:
		var pts: PackedVector2Array = rv["points"]
		var width := float(rv["width"]) - RIVER_COLLISION_INSET
		var crossings: Array = rv["crossings"]
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var length := a.distance_to(b)
			var pieces := maxi(1, ceili(length / RIVER_PIECE))
			for k in pieces:
				var center := a.lerp(b, (k + 0.5) / pieces)
				if _near_crossing(center, crossings):
					continue
				_add_rect(body, center, Vector2(length / pieces + 12.0, width), (b - a).angle())
	# Outer safety ring: nobody can ever leave the world, even at high speed.
	var size := world.world_size()
	var t := SAFETY_RING
	_add_rect(body, Vector2(size.x / 2.0, -t / 2.0), Vector2(size.x + 2.0 * t, t), 0.0)
	_add_rect(body, Vector2(size.x / 2.0, size.y + t / 2.0), Vector2(size.x + 2.0 * t, t), 0.0)
	_add_rect(body, Vector2(-t / 2.0, size.y / 2.0), Vector2(t, size.y), 0.0)
	_add_rect(body, Vector2(size.x + t / 2.0, size.y / 2.0), Vector2(t, size.y), 0.0)


static func _near_crossing(pos: Vector2, crossings: Array) -> bool:
	for c: Dictionary in crossings:
		if pos.distance_to(c["pos"]) < float(c["radius"]):
			return true
	return false


static func _add_rect(body: StaticBody2D, center: Vector2, size: Vector2, angle: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = center
	col.rotation = angle
	body.add_child(col)


## Draws bridges and stepping stones over river crossings.
class RiverCrossings extends Node2D:
	var crossings: Array = []
	var river_angle_at: Dictionary = {}

	func setup(river: Dictionary) -> void:
		crossings = river["crossings"]
		var pts: PackedVector2Array = river["points"]
		for c: Dictionary in crossings:
			var best_angle := 0.0
			var best_d := INF
			for i in range(pts.size() - 1):
				var closest := Geometry2D.get_closest_point_to_segment(c["pos"], pts[i], pts[i + 1])
				var d := closest.distance_to(c["pos"])
				if d < best_d:
					best_d = d
					best_angle = (pts[i + 1] - pts[i]).angle()
			river_angle_at[c["pos"]] = best_angle
		queue_redraw()

	func _draw() -> void:
		for c: Dictionary in crossings:
			var pos: Vector2 = c["pos"]
			var radius := float(c["radius"])
			var along := float(river_angle_at.get(pos, 0.0))
			if String(c["kind"]) == "bridge":
				draw_set_transform(pos, along + PI / 2.0, Vector2.ONE)
				var length := radius * 2.0
				draw_rect(Rect2(-length / 2.0, -46, length, 92), Palette.BARK_DARK)
				for k in int(length / 22.0):
					var x := -length / 2.0 + 4.0 + k * 22.0
					draw_rect(Rect2(x, -42, 18, 84), Palette.BARK)
				draw_line(Vector2(-length / 2.0, -48), Vector2(length / 2.0, -48), Palette.BARK_DARK, 6.0, true)
				draw_line(Vector2(-length / 2.0, 48), Vector2(length / 2.0, 48), Palette.BARK_DARK, 6.0, true)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var dir := Vector2.RIGHT.rotated(along + PI / 2.0)
				for k in range(-2, 3):
					var p := pos + dir * k * 38.0 + Vector2(0, (k % 2) * 6.0)
					draw_circle(p + Vector2(0, 4), 19.0, Palette.with_alpha(Palette.INK, 0.18))
					draw_circle(p, 18.0, Palette.STONE)
					draw_circle(p + Vector2(-5, -5), 6.0, Palette.with_alpha(Palette.IVORY, 0.5))
