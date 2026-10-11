class_name RegionAtmosphere
extends CanvasLayer
## Screen-space mood for regions that need it: layered drifting fog with warm
## pink light breaking through in Misty Pinewood, a soft salty haze on the
## coast. It fades in and out gradually as the player crosses regions, moves
## slower with Reduced Motion, and dims at night. Drawn under the HUD.
##
## 0.4.0 adds warm night details and biome signatures, all drawn here (this
## layer is not darkened by the night tint, and none of it uses a light):
## fireflies in the meadow and grove at dusk and night, low mist over water at
## night and early morning, a band of stars over open land at night, falling
## needles in the pinewood, drifting snow in the highlands, gulls over the
## coast by day, and the lighthouse beam sweeping the sea at night once it is
## lit. Reduce motion slows everything; snow and needles follow Weather effects.

const FADE_PER_SECOND := 0.35
const MOODS := {
	"misty_pinewood": {"fog": 0.7, "shafts": 1.0, "fog_color": Color(0.86, 0.9, 0.92), "shaft_color": Color(1.0, 0.82, 0.8)},
	"sunpetal_coast": {"fog": 0.25, "shafts": 0.0, "fog_color": Color(1.0, 0.97, 0.9), "shaft_color": Color(1, 1, 1)},
	"sunpetal_isles": {"fog": 0.2, "shafts": 0.0, "fog_color": Color(1.0, 0.97, 0.9), "shaft_color": Color(1, 1, 1)},
	"frostbloom_highlands": {"fog": 0.4, "shafts": 0.3, "fog_color": Color(0.95, 0.97, 1.0), "shaft_color": Color(0.85, 0.95, 1.0)},
}

var region: String = ""
var weather: String = "clear"
## Once the shrine is aligned, the aurora dances over the highlands at night.
var aurora: bool = false
## Camera position and zoom, for parallax fog and ground-locked cloud shadows.
var camera_pos: Vector2 = Vector2.ZERO
var camera_zoom: float = 1.0
const CLOUD_REGIONS: PackedStringArray = ["whispering_meadow", "firefly_grove", "crystal_creek", "sunpetal_coast", "sunpetal_isles"]
const FIREFLY_REGIONS: PackedStringArray = ["whispering_meadow", "firefly_grove", "crystal_creek"]
const STAR_REGIONS: PackedStringArray = ["whispering_meadow", "firefly_grove", "crystal_creek", "moonlit_sanctuary", "sunpetal_coast", "sunpetal_isles", "frostbloom_highlands"]
const COAST_REGIONS: PackedStringArray = ["sunpetal_coast", "sunpetal_isles"]
const FIREFLY_CELL := 230.0
const MIST_RADIUS := 90.0
const MIST_POINTS := 12
## World points of water near the camera (set by RegionFeatures a few times a second).
var water_points: PackedVector2Array = []
## In-game minute of the day (for morning mist).
var minute: float = 480.0
var lighthouse_pos: Vector2 = Vector2.INF
var lighthouse_lit: bool = false
var _fireflies: float = 0.0
var _mist: float = 0.0
var _stars: float = 0.0
var _needles: float = 0.0
var _snow: float = 0.0
var _gulls: float = 0.0
var _beam: float = 0.0
var night: float = 0.0
var in_sublevel: bool = false
var _fog: float = 0.0
var _shafts: float = 0.0
var _rain: float = 0.0
var _aurora: float = 0.0
var _clouds_shadow: float = 0.0
var _clouds: float = 0.0
var _fog_color: Color = Color.WHITE
var _shaft_color: Color = Color.WHITE
var _t: float = 0.0
var _canvas: Control
## Small particles (stars, fireflies, snow, needles) are collected into one
## triangle list per effect and drawn with a single command (performance).
var _bp := PackedVector2Array()
var _bc := PackedColorArray()
var _bi := PackedInt32Array()


func _ready() -> void:
	layer = 2
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_mood)
	add_child(_canvas)


func current_fog() -> float:
	return _fog


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	var mood: Dictionary = MOODS.get(region, {})
	var target_fog := 0.0 if in_sublevel else maxf(float(mood.get("fog", 0.0)), 0.55 if weather == "mist" else 0.0)
	var target_shafts := 0.0 if in_sublevel or weather in ["rain", "cloudy"] else float(mood.get("shafts", 0.0)) * (1.0 - night)
	_fog = move_toward(_fog, target_fog, FADE_PER_SECOND * delta)
	_shafts = move_toward(_shafts, target_shafts, FADE_PER_SECOND * delta)
	_rain = move_toward(_rain, 0.0 if in_sublevel or weather != "rain" else 1.0, FADE_PER_SECOND * delta)
	_clouds = move_toward(_clouds, 0.0 if in_sublevel or weather not in ["rain", "cloudy"] else 1.0, FADE_PER_SECOND * delta)
	if not mood.is_empty():
		_fog_color = _fog_color.lerp(mood["fog_color"], minf(1.0, delta))
		_shaft_color = _shaft_color.lerp(mood["shaft_color"], minf(1.0, delta))
	var shadow_target := 1.0 if region in CLOUD_REGIONS and not in_sublevel and weather in ["clear", "cloudy"] and GameSettings.weather_effects else 0.0
	_clouds_shadow = move_toward(_clouds_shadow, shadow_target * (1.0 - night), FADE_PER_SECOND * delta)
	var aurora_target := 1.0 if aurora and region == "frostbloom_highlands" and not in_sublevel and night > 0.3 else 0.0
	_aurora = move_toward(_aurora, aurora_target * night, FADE_PER_SECOND * delta)
	var outdoors := not in_sublevel
	var clear_sky := weather in ["clear", "mist"]
	var morning := 1.0 if minute >= 300.0 and minute <= 510.0 else 0.0
	_fireflies = move_toward(_fireflies, (clampf(night * 1.6, 0.0, 1.0) if outdoors and region in FIREFLY_REGIONS and weather != "rain" else 0.0), FADE_PER_SECOND * delta)
	_mist = move_toward(_mist, (maxf(night, morning * 0.8) if outdoors and not water_points.is_empty() else 0.0), FADE_PER_SECOND * delta)
	_stars = move_toward(_stars, (clampf((night - 0.4) * 2.0, 0.0, 1.0) if outdoors and clear_sky and region in STAR_REGIONS else 0.0), FADE_PER_SECOND * delta)
	_needles = move_toward(_needles, (1.0 if outdoors and region == "misty_pinewood" and GameSettings.weather_effects else 0.0), FADE_PER_SECOND * delta)
	_snow = move_toward(_snow, (1.0 if outdoors and region == "frostbloom_highlands" and GameSettings.weather_effects else 0.0), FADE_PER_SECOND * delta)
	_gulls = move_toward(_gulls, (clampf(1.0 - night * 2.0, 0.0, 1.0) if outdoors and region in COAST_REGIONS and weather != "rain" else 0.0), FADE_PER_SECOND * delta)
	var beam_visible := lighthouse_lit and outdoors and lighthouse_pos != Vector2.INF and lighthouse_pos.distance_to(camera_pos) < 2600.0
	_beam = move_toward(_beam, night if beam_visible else 0.0, FADE_PER_SECOND * delta)
	_canvas.visible = _fog > 0.005 or _shafts > 0.005 or _rain > 0.005 or _clouds > 0.005 or _aurora > 0.005 or _clouds_shadow > 0.005 \
		or _fireflies > 0.005 or _mist > 0.005 or _stars > 0.005 or _needles > 0.005 or _snow > 0.005 or _gulls > 0.005 or _beam > 0.005
	if _canvas.visible:
		_canvas.queue_redraw()


## World position -> screen position on this layer.
func _to_screen(world_pos: Vector2, size: Vector2) -> Vector2:
	return size / 2.0 + (world_pos - camera_pos) * camera_zoom


## Adds a small filled circle (a fan of `segments` triangles) to the batch.
func _batch_circle(center: Vector2, radius: float, col: Color, segments: int = 8) -> void:
	if col.a <= 0.003:
		return
	var base := _bp.size()
	_bp.append(center)
	_bc.append(col)
	for i in segments:
		var a := TAU * float(i) / float(segments)
		_bp.append(center + Vector2(cos(a), sin(a)) * radius)
		_bc.append(col)
	for i in segments:
		_bi.append_array([base, base + 1 + i, base + 1 + (i + 1) % segments])


## Adds a short line (as a thin quad) to the batch.
func _batch_line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var n := (b - a).orthogonal().normalized() * width * 0.5
	var base := _bp.size()
	_bp.append_array([a - n, a + n, b + n, b - n])
	_bc.append_array([col, col, col, col])
	_bi.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


## Draws everything batched so far with one command, then clears the batch.
func _flush_batch() -> void:
	if not _bi.is_empty():
		RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _bi, _bp, _bc)
	_bp = PackedVector2Array()
	_bc = PackedColorArray()
	_bi = PackedInt32Array()


## A tiny stable random number for a grid cell (0..1).
static func _cell_rand(cell: Vector2i, salt: int) -> float:
	return float(absi(hash([cell.x, cell.y, salt])) % 10000) / 10000.0


func _draw_mood() -> void:
	var size := _canvas.size
	var dim := 1.0 - night * 0.65
	if _stars > 0.005:
		_draw_stars(size)
	if _beam > 0.005:
		_draw_beam(size)
	if _mist > 0.005:
		_draw_mist(size)
	# Cloud shadows drift slowly over the ground (locked to the world, so they
	# move with the landscape while the fog layers below move at other speeds).
	if _clouds_shadow > 0.005:
		var tile := Vector2(2600, 1800)
		var drift := Vector2(_t * 14.0, _t * 5.0)
		for i in 6:
			var base := Vector2(fposmod(i * 970.0, tile.x), fposmod(i * 610.0 + (i % 2) * 400.0, tile.y)) + drift
			var rel := Vector2(fposmod(base.x - camera_pos.x + tile.x * 0.5, tile.x) - tile.x * 0.5, fposmod(base.y - camera_pos.y + tile.y * 0.5, tile.y) - tile.y * 0.5)
			var p := size / 2.0 + rel * camera_zoom
			_canvas.draw_set_transform(p, 0.15, Vector2(2.2, 1.0) * camera_zoom)
			_canvas.draw_circle(Vector2.ZERO, 130.0 + 30.0 * (i % 3), Color(0.15, 0.2, 0.3, 0.06 * _clouds_shadow))
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aurora: soft green and violet ribbons across the top of the sky.
	if _aurora > 0.005:
		for k in 3:
			var col: Color = [Color("#8ff0c0"), Color("#9fd8ff"), Color("#c9a8ff")][k]
			var pts := PackedVector2Array()
			for i in 25:
				var x := size.x * float(i) / 24.0
				pts.append(Vector2(x, size.y * (0.12 + 0.06 * k) + sin(x * 0.006 + _t * 0.4 + k) * 26.0))
			_canvas.draw_polyline(pts, Color(col.r, col.g, col.b, 0.28 * _aurora), 22.0 - k * 4.0, true)
	# Overcast: a soft grey-blue veil over the whole view.
	if _clouds > 0.005:
		_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.5, 0.62, 0.16 * _clouds))
	# Rain: light slanted streaks (fewer and slower with Reduced Motion).
	if _rain > 0.005:
		var motion := maxf(GameSettings.motion_scale(), 0.25)
		var count := int(140 * motion)
		var rain_col := Color(0.85, 0.9, 1.0, 0.35 * _rain * (0.7 + 0.3 * dim))
		for i in count:
			var seed_x := fposmod(float(i) * 97.31, size.x + 200.0)
			var fall := fposmod(_t * 520.0 + float(i) * 53.7, size.y + 60.0) - 30.0
			var x := fposmod(seed_x - fall * 0.25, size.x + 200.0) - 100.0
			_canvas.draw_line(Vector2(x, fall), Vector2(x - 4.0, fall + 16.0), rain_col, 1.5)
	var fog := Color(_fog_color.r * dim, _fog_color.g * dim, _fog_color.b * (dim + night * 0.15), 1.0)
	# Light shafts: soft diagonal beams of warm light.
	if _shafts > 0.005:
		for i in 4:
			var x := size.x * (0.15 + 0.25 * i) + sin(_t * 0.05 + i) * 30.0
			var w := 70.0 + 30.0 * (i % 2)
			var a := (0.07 + 0.03 * sin(_t * 0.3 + i * 1.7)) * _shafts
			var beam := PackedVector2Array([Vector2(x, -10), Vector2(x + w, -10), Vector2(x + w - size.y * 0.45, size.y + 10), Vector2(x - size.y * 0.45, size.y + 10)])
			_canvas.draw_colored_polygon(beam, Color(_shaft_color.r, _shaft_color.g, _shaft_color.b, a))
	# Fog banks: wide, soft ellipses drifting at different speeds (parallax).
	if _fog > 0.005:
		for layer_i in 3:
			var speed := 6.0 + layer_i * 5.0
			var y_base := size.y * (0.25 + 0.3 * layer_i)
			# Parallax: far banks move slower than the ground, near ones faster.
			var depth := 0.5 + 0.35 * layer_i
			for j in 4:
				var x := fposmod(j * size.x * 0.4 + _t * speed - camera_pos.x * depth * camera_zoom, size.x * 1.6) - size.x * 0.3
				var y := y_base + sin(_t * 0.1 + j * 2.0 + layer_i) * 20.0 + fposmod(-camera_pos.y * depth * 0.3 * camera_zoom, 60.0) - 30.0
				_canvas.draw_set_transform(Vector2(x, y), 0.0, Vector2(2.6, 0.55))
				_canvas.draw_circle(Vector2.ZERO, size.y * 0.16, Color(fog.r, fog.g, fog.b, 0.075 * _fog))
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# A gentle overall haze at the screen edges.
		_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.12)), Color(fog.r, fog.g, fog.b, 0.12 * _fog))
		_canvas.draw_rect(Rect2(Vector2(0, size.y * 0.88), Vector2(size.x, size.y * 0.12)), Color(fog.r, fog.g, fog.b, 0.08 * _fog))
	if _needles > 0.005:
		_draw_falling(size, 26, Color("#8a6a4a"), 28.0, 0.55, true)
	if _snow > 0.005:
		_draw_falling(size, 70, Color(1, 1, 1), 22.0, 0.9, false)
	if _gulls > 0.005:
		_draw_gulls(size)
	if _fireflies > 0.005:
		_draw_fireflies(size)


## Fireflies: one per world cell near the camera, looping slowly and blinking.
func _draw_fireflies(size: Vector2) -> void:
	var view := Rect2(camera_pos - size / camera_zoom / 2.0, size / camera_zoom).grow(FIREFLY_CELL)
	var c0 := Vector2i(floori(view.position.x / FIREFLY_CELL), floori(view.position.y / FIREFLY_CELL))
	var c1 := Vector2i(floori(view.end.x / FIREFLY_CELL), floori(view.end.y / FIREFLY_CELL))
	var motion := maxf(GameSettings.motion_scale(), 0.3)
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var cell := Vector2i(cx, cy)
			if _cell_rand(cell, 1) > 0.55:
				continue
			var phase := _cell_rand(cell, 2) * TAU
			var home := (Vector2(cell) + Vector2(_cell_rand(cell, 3), _cell_rand(cell, 4))) * FIREFLY_CELL
			var wander := Vector2(cos(_t * 0.35 + phase), sin(_t * 0.45 + phase * 1.3)) * 26.0 * motion
			var blink := 0.3 + 0.7 * maxf(0.0, sin(_t * (1.4 + _cell_rand(cell, 5)) + phase))
			var p := _to_screen(home + wander, size)
			var a := _fireflies * blink
			_batch_circle(p, 7.0 * camera_zoom, Color(1.0, 0.93, 0.55, 0.16 * a), 10)
			_batch_circle(p, 2.0 * camera_zoom, Color(1.0, 0.97, 0.75, 0.95 * a), 6)
	_flush_batch()


## Low mist drifting over nearby water at night and in the early morning.
## (At most MIST_POINTS soft ellipses: large overlapping shapes cost fill rate.)
func _draw_mist(size: Vector2) -> void:
	for i in mini(water_points.size(), MIST_POINTS):
		var w := water_points[i]
		var drift := Vector2(sin(_t * 0.12 + i) * 18.0, 0.0)
		var p := _to_screen(w + drift, size)
		_canvas.draw_set_transform(p, 0.0, Vector2(2.4, 0.6) * camera_zoom)
		_canvas.draw_circle(Vector2.ZERO, MIST_RADIUS, Color(0.92, 0.95, 1.0, 0.07 * _mist))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A band of soft stars at the top of the view over open land.
func _draw_stars(size: Vector2) -> void:
	var drift := Vector2(fposmod(-camera_pos.x * 0.02, size.x), 0.0)
	for i in 70:
		var x := fposmod(float(i) * 173.3 + drift.x, size.x)
		var y := size.y * 0.2 * fposmod(float(i) * 0.613, 1.0)
		var twinkle := 0.55 + 0.45 * sin(_t * (0.6 + fposmod(i * 0.37, 0.9)) + i)
		_batch_circle(Vector2(x, y), 1.0 + fposmod(i * 0.29, 1.2), Color(1.0, 0.98, 0.9, 0.7 * _stars * twinkle * (1.0 - y / (size.y * 0.24))), 6)
	_flush_batch()


## Falling needles (pinewood) or snow (highlands), in screen space.
func _draw_falling(size: Vector2, count: int, color: Color, speed: float, alpha: float, needles: bool) -> void:
	var motion := maxf(GameSettings.motion_scale(), 0.3)
	var amount := _needles if needles else _snow
	for i in count:
		var x0 := fposmod(float(i) * 97.7 - camera_pos.x * 0.15 * camera_zoom, size.x + 40.0) - 20.0
		var fall := fposmod(_t * speed * motion * (0.7 + fposmod(i * 0.31, 0.6)) + float(i) * 61.3 - camera_pos.y * 0.15 * camera_zoom, size.y + 40.0) - 20.0
		var sway := sin(_t * 0.9 * motion + i) * 12.0
		var p := Vector2(x0 + sway, fall)
		if needles:
			var tilt := Vector2.from_angle(0.8 + sin(_t + i) * 0.4) * 4.0
			_batch_line(p - tilt, p + tilt, 1.5, Color(color.r, color.g, color.b, alpha * amount))
		else:
			_batch_circle(p, 1.4 + fposmod(i * 0.47, 1.6), Color(color.r, color.g, color.b, alpha * amount * (0.7 + 0.3 * (1.0 - night))), 6)
	_flush_batch()


## Three gulls gliding slowly across the sky by day.
func _draw_gulls(size: Vector2) -> void:
	var motion := maxf(GameSettings.motion_scale(), 0.3)
	for i in 3:
		var x := fposmod(_t * (22.0 + i * 6.0) * motion + i * size.x * 0.37, size.x + 120.0) - 60.0
		var y := size.y * (0.12 + 0.07 * i) + sin(_t * 0.4 + i * 2.0) * 14.0
		var flap := sin(_t * 3.0 * motion + i) * 3.0
		var col := Color(0.25, 0.28, 0.36, 0.7 * _gulls)
		_canvas.draw_polyline(PackedVector2Array([Vector2(x - 10, y - 2 + flap), Vector2(x - 4, y - 5 - flap * 0.5), Vector2(x, y), Vector2(x + 4, y - 5 - flap * 0.5), Vector2(x + 10, y - 2 + flap)]), col, 1.8, true)


## The restored lighthouse: a warm beam slowly sweeping over the sea at night.
func _draw_beam(size: Vector2) -> void:
	var lamp := _to_screen(lighthouse_pos + Vector2(0, -230), size)
	var angle := _t * 0.35
	for k in 2:
		var a := angle + PI * k
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal()
		var length := 900.0 * camera_zoom
		var beam := PackedVector2Array([lamp, lamp + dir * length + side * length * 0.16, lamp + dir * length - side * length * 0.16])
		_canvas.draw_colored_polygon(beam, Color(1.0, 0.9, 0.6, 0.1 * _beam))
	_canvas.draw_circle(lamp, 26.0 * camera_zoom, Color(1.0, 0.92, 0.65, 0.35 * _beam))
