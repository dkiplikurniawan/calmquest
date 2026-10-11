class_name MapView
extends Control
## Draws the Lumeria map: biome colors where explored, soft fog elsewhere,
## paths, the river, discovered points of interest, waystones, pins, the quest
## marker (optional) and the player. Used by the world map (M) and the minimap.

const FOG_COLOR := Color("#3a4568")
const ICON_RADIUS := 7.0

var world: WorldData
## World area shown inside this control (whole world for the big map).
var view_rect: Rect2 = Rect2()
var show_labels: bool = true
var show_quest_marker: bool = true
var player_pos: Vector2 = Vector2.ZERO
var player_facing: Vector2 = Vector2.DOWN
var quest_target: Vector2 = Vector2.INF
## Extra POIs to show (id -> {pos, kind, label}), e.g. the Heart Tree.
var extra_pois: Dictionary = {}

var _fog_texture: ImageTexture


func setup(world_data: WorldData) -> void:
	world = world_data
	view_rect = world.world_rect()
	clip_contents = true
	refresh_fog()


## Rebuilds the explored/fog image from GameState (call after exploring).
func refresh_fog() -> void:
	if world == null or GameState.fog_size == Vector2i.ZERO:
		return
	var size := GameState.fog_size
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			var pos := (Vector2(x, y) + Vector2(0.5, 0.5)) * GameState.FOG_CELL
			if GameState.fog[y * size.x + x] == 1:
				var colors: Array = world.legend_at(pos).get("palette", ["#888888"])
				img.set_pixel(x, y, Color(String(colors[0])))
			else:
				img.set_pixel(x, y, FOG_COLOR)
	_fog_texture = ImageTexture.create_from_image(img)
	queue_redraw()


func world_to_map(p: Vector2) -> Vector2:
	return (p - view_rect.position) / view_rect.size * size


func map_to_world(p: Vector2) -> Vector2:
	return view_rect.position + p / size * view_rect.size


func _draw() -> void:
	if world == null or _fog_texture == null:
		return
	# Fog/biome image covering the whole world, placed according to view_rect.
	var world_rect_on_map := Rect2(world_to_map(Vector2.ZERO), world_to_map(world.world_size()) - world_to_map(Vector2.ZERO))
	draw_texture_rect(_fog_texture, world_rect_on_map, false)
	var px_scale := size.x / view_rect.size.x
	for p: Dictionary in world.paths:
		_draw_revealed_polyline(p["points"], maxf(2.0, float(p["width"]) * px_scale * 1.4), Palette.PATH)
	for rv: Dictionary in world.rivers:
		_draw_revealed_polyline(rv["points"], maxf(3.0, float(rv["width"]) * px_scale), Palette.WATER)
	for p in world.pois:
		_draw_poi(p)
	for id: String in extra_pois:
		var e: Dictionary = extra_pois[id]
		if GameState.is_revealed(e["pos"]):
			_draw_icon(world_to_map(e["pos"]), String(e.get("kind", "landmark")), true)
	if show_labels:
		_draw_region_labels()
	for pin: Vector2 in GameState.pins:
		var m := world_to_map(pin)
		draw_line(m, m + Vector2(0, -16), Palette.INK, 2.0, true)
		draw_colored_polygon(PackedVector2Array([m + Vector2(0, -16), m + Vector2(12, -12), m + Vector2(0, -8)]), Color("#e9867a"))
	if show_quest_marker and quest_target != Vector2.INF:
		var q := world_to_map(quest_target)
		draw_arc(q, 11.0, 0.0, TAU, 24, Palette.GOLD_DEEP, 3.0, true)
		draw_circle(q, 4.0, Palette.GOLD)
	_draw_player()


func _draw_revealed_polyline(pts: PackedVector2Array, width: float, color: Color) -> void:
	for i in range(pts.size() - 1):
		if GameState.is_revealed(pts[i]) or GameState.is_revealed(pts[i + 1]):
			draw_line(world_to_map(pts[i]), world_to_map(pts[i + 1]), color, width, true)


func _draw_poi(p: Dictionary) -> void:
	var kind := String(p.get("kind", ""))
	var id := String(p["id"])
	var pos: Vector2 = p["pos"]
	var visible_on_map := false
	match kind:
		"waystone":
			visible_on_map = GameState.waystone_state(id) != ""
		"landmark":
			visible_on_map = GameState.seen_landmarks.has(id) or GameState.is_revealed(pos)
		_:
			visible_on_map = GameState.is_revealed(pos)
	if not visible_on_map or kind == "moon_gate" or not bool(p.get("map", true)):
		return
	if kind == "gloom":
		if not GloomPatch.is_patch_cleared(id):
			draw_circle(world_to_map(pos), maxf(5.0, float(p.get("radius", 260.0)) * size.x / view_rect.size.x), Palette.with_alpha(Color("#3b3550"), 0.45))
		return
	var restored := kind == "waystone" and GameState.waystone_state(id) == GameState.WAYSTONE_RESTORED
	_draw_icon(world_to_map(pos), kind, restored)


func _draw_icon(m: Vector2, kind: String, bright: bool) -> void:
	match kind:
		"waystone":
			draw_circle(m, ICON_RADIUS + 3.0, Palette.INK)
			draw_circle(m, ICON_RADIUS, Palette.GOLD if bright else Palette.STONE)
		"landmark":
			draw_colored_polygon(PackedVector2Array([m + Vector2(0, -10), m + Vector2(8, 6), m + Vector2(-8, 6)]), Palette.IVORY)
			draw_polyline(PackedVector2Array([m + Vector2(0, -10), m + Vector2(8, 6), m + Vector2(-8, 6), m + Vector2(0, -10)]), Palette.INK, 2.0, true)
		"cave":
			draw_circle(m, ICON_RADIUS + 2.0, Palette.INK)
			draw_circle(m, ICON_RADIUS - 1.0, Palette.NIGHT_DEEP)
			draw_circle(m + Vector2(0, -1), 2.0, Palette.SKY)
		"dock":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-8, 0), m + Vector2(8, 0), m + Vector2(5, 5), m + Vector2(-5, 5)]), Palette.BARK)
			draw_line(m + Vector2(0, 0), m + Vector2(0, -10), Palette.INK, 2.0)
			draw_colored_polygon(PackedVector2Array([m + Vector2(1, -10), m + Vector2(7, -2), m + Vector2(1, -2)]), Palette.CREAM)
		"gate":
			draw_rect(Rect2(m - Vector2(6, 6), Vector2(12, 12)), Palette.STONE_DARK)
			draw_line(m - Vector2(5, 5), m + Vector2(5, 5), Palette.IVORY, 2.0)
		_:
			draw_circle(m, ICON_RADIUS + 2.0, Palette.INK)
			draw_circle(m, ICON_RADIUS - 1.0, Palette.LAVENDER)


func _draw_region_labels() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	for region_id: String in world.regions:
		var info: Dictionary = world.regions[region_id]
		if String(info.get("status", "")) == "boundary":
			continue
		var center := world.region_center(region_id)
		if center == Vector2.ZERO or not GameState.has_visited(region_id):
			continue
		var text := L.t(String(info.get("name", region_id)))
		var m := world_to_map(center)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(font, m - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Palette.with_alpha(Palette.NIGHT_DEEP, 0.8))
		draw_string(font, m - Vector2(w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.CREAM)


func _draw_player() -> void:
	var m := world_to_map(player_pos)
	var dir := player_facing.normalized() if player_facing != Vector2.ZERO else Vector2.DOWN
	var side := dir.orthogonal()
	var tip := m + dir * 11.0
	var pts := PackedVector2Array([tip, m - dir * 7.0 + side * 7.0, m - dir * 3.0, m - dir * 7.0 - side * 7.0])
	draw_colored_polygon(pts, Palette.GOLD)
	pts.append(tip)
	draw_polyline(pts, Palette.INK, 2.0, true)
