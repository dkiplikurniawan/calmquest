class_name RegionAtmosphere
extends CanvasLayer
## Screen-space mood for regions that need it: layered drifting fog with warm
## pink light breaking through in Misty Pinewood, a soft salty haze on the
## coast. It fades in and out gradually as the player crosses regions, moves
## slower with Reduced Motion, and dims at night. Drawn under the HUD.

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
	_canvas.visible = _fog > 0.005 or _shafts > 0.005 or _rain > 0.005 or _clouds > 0.005 or _aurora > 0.005 or _clouds_shadow > 0.005
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_mood() -> void:
	var size := _canvas.size
	var dim := 1.0 - night * 0.65
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
