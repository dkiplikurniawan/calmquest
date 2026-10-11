class_name Villager
extends Interactable
## A spirit villager walking a small daily routine in the village:
## morning near home, daytime at a favourite spot, evening by the campfire,
## asleep at home at night (then hidden; the home says so). E opens a chat.

const WALK_SPEED := 46.0

var villager_id: String = ""
var data: Dictionary = {}
var home_pos: Vector2 = Vector2.ZERO
var festival_spot: Vector2 = Vector2.INF
var _target: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _flip: float = 1.0
var _hop: float = 0.0
var _talk_glow: float = 0.0


func setup(id: String) -> void:
	villager_id = id
	data = VillageDB.villager(id)
	interactable_id = "villager_" + id
	var h: Array = data["home"]["pos"]
	home_pos = Vector2(float(h[0]), float(h[1]))
	position = spot_for(TimeManager.minute_of_day / 60.0)
	_target = position
	reach_bonus = 24.0
	_t = float(hash(id) % 100) * 0.1


func display_name() -> String:
	return L.t(String(data.get("name", villager_id)))


func is_asleep() -> bool:
	if festival_spot != Vector2.INF:
		return false
	var hour := TimeManager.minute_of_day / 60.0
	return hour < 6.0 or hour >= 21.0


## Where the villager wants to be at this hour.
func spot_for(hour: float) -> Vector2:
	if festival_spot != Vector2.INF:
		return festival_spot
	var spots: Dictionary = data.get("spots", {})
	var key := "morning" if hour < 10.0 else ("day" if hour < 17.0 else "evening")
	if hour < 6.0 or hour >= 21.0:
		return home_pos + Vector2(0, 60)
	var s: Array = spots.get(key, [home_pos.x, home_pos.y + 60])
	return Vector2(float(s[0]), float(s[1]))


func can_interact() -> bool:
	return VillageDB.has_arrived(villager_id) and not is_asleep() and super.can_interact()


func get_prompt() -> String:
	return L.t("Talk to %s") % display_name()


func get_interaction_point() -> Vector2:
	return global_position + Vector2(0, -14)


func cheer() -> void:
	_talk_glow = 1.0


func _process(delta: float) -> void:
	super(delta)
	var arrived := VillageDB.has_arrived(villager_id)
	visible = arrived and not is_asleep()
	if not visible:
		return
	_t += delta * maxf(GameSettings.motion_scale(), 0.3)
	_talk_glow = maxf(0.0, _talk_glow - delta * 0.6)
	_target = spot_for(TimeManager.minute_of_day / 60.0)
	var to := _target - global_position
	if to.length() > 4.0:
		var step := to.normalized() * minf(to.length(), WALK_SPEED * delta * (3.0 if to.length() > 600.0 else 1.0))
		global_position += step
		_hop += delta * 2.0
		if absf(step.x) > 0.2:
			_flip = 1.0 if step.x > 0.0 else -1.0
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	var look: Dictionary = data.get("look", {})
	var body := Color(String(look.get("body", "#c49a6c")))
	var accent := Color(String(look.get("accent", "#fff6e5")))
	var glow := Color(String(look.get("glow", "#ffe8a3")))
	draw_circle(Vector2(0, -24), 30.0 + 4.0 * sin(_t * 1.5), Palette.with_alpha(glow, 0.18 + 0.2 * _talk_glow))
	var shape := String(look.get("shape", "rabbit"))
	if shape == "mushroom":
		_mushroom(body, accent)
	else:
		CreatureArt.draw(self, shape, body, accent, _t, _hop, _flip, Vector2.ZERO, 1.45)
	# A tiny glowing mote above the head marks spirit villagers.
	draw_circle(Vector2(0, -58 + sin(_t * 2.0) * 3.0), 3.0, Palette.with_alpha(glow, 0.9))
	draw_interaction_cues(26.0, Vector2(0, -20))


func _mushroom(body: Color, cap: Color) -> void:
	BiomeDecorArt.shadow(self, 16.0)
	var bob := sin(_hop * 6.0) * 1.5
	draw_rect(Rect2(-9, -24 + bob, 18, 24), body)
	draw_circle(Vector2(-4, -15 + bob), 1.8, Palette.INK)
	draw_circle(Vector2(4, -15 + bob), 1.8, Palette.INK)
	draw_arc(Vector2(0, -11 + bob), 3.0, 0.2, PI - 0.2, 8, Palette.INK, 1.2)
	var capp := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		capp.append(Vector2(cos(a) * 24.0, -24 + bob + sin(a) * 18.0))
	draw_colored_polygon(capp, cap)
	for p: Vector2 in [Vector2(-10, -34), Vector2(6, -38), Vector2(13, -29)]:
		draw_circle(p + Vector2(0, bob), 3.0, Palette.IVORY)
	draw_line(Vector2(9, -14 + bob), Vector2(18, -26 + bob), Palette.BARK, 2.0)
	draw_circle(Vector2(19, -28 + bob), 3.5, Palette.STONE)


## A villager's home: a little tent until it is built, then a house in the
## villager's style (with a lit window and a "Zzz" while they sleep).
class HomeView extends Node2D:
	var villager_id: String = ""
	var _body: StaticBody2D
	var _light: PointLight2D
	var _t: float = 0.0

	func _ready() -> void:
		_body = StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(150, 50)
		col.shape = shape
		col.position = Vector2(0, -60)
		_body.add_child(col)
		add_child(_body)
		_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.4, 0.0)
		_light.position = Vector2(30, -110)
		add_child(_light)
		sync()

	func built() -> bool:
		return VillageDB.home_built(villager_id)

	func sync() -> void:
		visible = VillageDB.has_arrived(villager_id)
		for c in _body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", not built() or not visible)
		queue_redraw()

	func set_night_amount(amount: float) -> void:
		_light.enabled = built() and amount > 0.05
		_light.energy = 0.5 * amount

	func _process(delta: float) -> void:
		_t += delta * GameSettings.motion_scale()
		if visible and ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		var v := VillageDB.villager(villager_id)
		var look: Dictionary = v.get("look", {})
		var body := Color(String(look.get("body", "#c49a6c")))
		var accent := Color(String(look.get("accent", "#fff6e5")))
		if not built():
			# A small tent while the home is being built.
			BiomeDecorArt.shadow(self, 60.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-70, -40), Vector2(70, -40), Vector2(0, -130)]), Palette.with_alpha(accent, 0.95))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -40), Vector2(14, -40), Vector2(0, -90)]), Palette.NIGHT)
			draw_line(Vector2(0, -130), Vector2(0, -146), Palette.BARK, 3.0)
			return
		BiomeDecorArt.shadow(self, 95.0)
		var wall := body.lerp(Palette.CREAM, 0.55)
		draw_rect(Rect2(-80, -130, 160, 95), wall)
		draw_rect(Rect2(-80, -130, 160, 95), body.darkened(0.2), false, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-96, -128), Vector2(96, -128), Vector2(0, -196)]), accent.darkened(0.15))
		draw_rect(Rect2(-16, -86, 32, 51), Palette.BARK)
		draw_circle(Vector2(8, -60), 2.5, Palette.GOLD)
		var lit := 1.0 - TimeManager.daylight()
		draw_rect(Rect2(28, -116, 30, 24), Palette.SKY.lerp(Palette.GOLD_SOFT, lit))
		draw_line(Vector2(43, -116), Vector2(43, -92), wall.darkened(0.3), 2.0)
		var hour := TimeManager.minute_of_day / 60.0
		if hour < 6.0 or hour >= 21.0:
			for i in 3:
				var k := fposmod(_t * 0.4 + i / 3.0, 1.0)
				draw_string(ThemeDB.fallback_font, Vector2(60 + k * 24.0, -150 - k * 40.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14 + i * 3, Palette.with_alpha(Palette.IVORY, 1.0 - k))
