class_name Landmark
extends Node2D
## Large, recognizable structures that help navigation: each region has one,
## drawn tall so it stands out, and shown on the world map once seen.

const STYLES := ["elder_glowcap", "crystal_spire", "lookout_tower", "lighthouse", "frost_peak", "waterfall"]
const SEEN_DISTANCE := 1500.0

var landmark_id: String = ""
var style: String = "crystal_spire"
var _t: float = 0.0
var _light: PointLight2D
var _night: float = 0.0


func _ready() -> void:
	if style in ["elder_glowcap", "crystal_spire", "lookout_tower", "lighthouse"]:
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 34.0 if style == "elder_glowcap" else 26.0
		col.shape = shape
		col.position = Vector2(0, -8)
		body.add_child(col)
		add_child(body)
	if style in ["lighthouse", "elder_glowcap", "crystal_spire"]:
		_light = GlowTexture.make_light(Palette.GOLD_SOFT if style == "lighthouse" else Palette.TURQUOISE, 3.0, 0.0)
		_light.position = Vector2(0, -230 if style == "lighthouse" else -150)
		add_child(_light)


func set_night_amount(amount: float) -> void:
	_night = amount
	if _light != null:
		var dark := style == "lighthouse" and not GameState.has_flag("lighthouse_lit")
		_light.enabled = amount > 0.01 and not dark
		_light.energy = 0.55 * amount


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position, 700.0):
		queue_redraw()


func _draw() -> void:
	match style:
		"elder_glowcap":
			_elder_glowcap()
		"crystal_spire":
			_crystal_spire()
		"lookout_tower":
			_lookout_tower()
		"lighthouse":
			_lighthouse()
		"frost_peak":
			_frost_peak()
		"waterfall":
			_waterfall()


func _elder_glowcap() -> void:
	BiomeDecorArt.shadow(self, 90.0)
	draw_rect(Rect2(-22, -150, 44, 150), Palette.CREAM)
	draw_line(Vector2(-8, -140), Vector2(-8, -10), Palette.with_alpha(Palette.PATH_EDGE, 0.8), 3.0)
	var pulse := 0.85 + 0.15 * sin(_t * 1.2)
	draw_circle(Vector2(0, -170), 150.0 * pulse, Palette.with_alpha(BiomeDecorArt.GLOW_TEAL, 0.14))
	draw_set_transform(Vector2(0, -170), 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, 120.0, Color("#3f8f86"))
	draw_circle(Vector2(0, -20), 104.0, BiomeDecorArt.GLOW_TEAL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 7:
		var a := float(i) / 7.0 * PI + PI
		draw_circle(Vector2(cos(a) * 70.0, -190 + sin(a) * 26.0), 9.0, Palette.IVORY)


func _crystal_spire() -> void:
	BiomeDecorArt.shadow(self, 60.0)
	var pulse := 0.85 + 0.15 * sin(_t * 1.5)
	draw_circle(Vector2(0, -150), 110.0 * pulse, Palette.with_alpha(Palette.SKY, 0.16))
	for shard: Array in [[Vector2(0, 0), 1.0, Palette.SKY], [Vector2(-34, 6), 0.62, Palette.LAVENDER], [Vector2(36, 4), 0.7, BiomeDecorArt.GLOW_TEAL]]:
		var base: Vector2 = shard[0]
		var k := float(shard[1])
		var pts := PackedVector2Array([Vector2(-26, 0), Vector2(26, 0), Vector2(20, -220), Vector2(0, -280), Vector2(-20, -220)])
		for i in pts.size():
			pts[i] = base + pts[i] * k
		draw_colored_polygon(pts, shard[2] as Color)
		draw_line(pts[4], pts[3], Palette.with_alpha(Palette.IVORY, 0.85), 3.0, true)


func _lookout_tower() -> void:
	BiomeDecorArt.shadow(self, 60.0)
	for leg: float in [-34.0, 34.0]:
		draw_line(Vector2(leg, 0), Vector2(leg * 0.5, -220), Palette.BARK_DARK, 8.0, true)
	draw_line(Vector2(-30, -60), Vector2(30, -130), Palette.BARK, 4.0, true)
	draw_line(Vector2(30, -60), Vector2(-30, -130), Palette.BARK, 4.0, true)
	draw_rect(Rect2(-40, -250, 80, 34), Palette.BARK)
	draw_colored_polygon(PackedVector2Array([Vector2(-50, -250), Vector2(50, -250), Vector2(0, -300)]), Palette.ROOF)


func _lighthouse() -> void:
	BiomeDecorArt.shadow(self, 70.0)
	var body := PackedVector2Array([Vector2(-40, 0), Vector2(40, 0), Vector2(26, -210), Vector2(-26, -210)])
	draw_colored_polygon(body, Palette.IVORY)
	for band: float in [-60.0, -140.0]:
		draw_rect(Rect2(-36 + band * -0.07, band - 18, 72 - band * -0.14, 18), Color("#e9867a"))
	# The lamp stays dark until the lighthouse is restored (RestorationSite).
	var lit := GameState.has_flag("lighthouse_lit")
	draw_rect(Rect2(-24, -246, 48, 36), Palette.GOLD_SOFT if lit else Palette.STONE_DARK)
	if lit:
		var glow := 0.8 + 0.2 * sin(_t * 1.6)
		draw_circle(Vector2(0, -228), 40.0 * glow, Palette.with_alpha(Palette.GOLD, 0.3))
		if _night > 0.05:
			# A slowly sweeping beam over the sea.
			var dir := Vector2.RIGHT.rotated(_t * 0.5)
			var side := dir.orthogonal()
			var tip := Vector2(0, -228) + dir * 520.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -228), tip + side * 70.0, tip - side * 70.0]), Palette.with_alpha(Palette.GOLD_SOFT, 0.16 * _night))
	else:
		draw_line(Vector2(-20, -240), Vector2(20, -216), Palette.STONE, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-32, -246), Vector2(32, -246), Vector2(0, -276)]), Palette.ROOF)


func _frost_peak() -> void:
	var peak := PackedVector2Array([Vector2(-260, 0), Vector2(260, 0), Vector2(40, -360), Vector2(-20, -390)])
	draw_colored_polygon(peak, Color("#9fb2c9"))
	draw_colored_polygon(PackedVector2Array([Vector2(-90, -250), Vector2(80, -250), Vector2(40, -360), Vector2(-20, -390)]), BiomeDecorArt.SNOW)
	var a := 0.12 + 0.06 * sin(_t * 0.6)
	draw_arc(Vector2(0, -330), 260.0, PI * 1.1, PI * 1.9, 32, Palette.with_alpha(BiomeDecorArt.GLOW_TEAL, a), 18.0, true)


func _waterfall() -> void:
	draw_rect(Rect2(-70, -140, 140, 160), Palette.with_alpha(Palette.STONE_DARK, 0.9))
	draw_rect(Rect2(-46, -140, 92, 180), Palette.WATER)
	for i in 5:
		var y := fposmod(_t * 60.0 + i * 36.0, 180.0) - 140.0
		draw_line(Vector2(-36 + i * 18, y), Vector2(-36 + i * 18, y + 22), Palette.with_alpha(Palette.IVORY, 0.7), 3.0, true)
	draw_circle(Vector2(0, 46), 60.0, Palette.with_alpha(Palette.IVORY, 0.35))
