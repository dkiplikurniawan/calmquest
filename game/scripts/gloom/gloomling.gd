class_name Gloomling
extends Interactable
## A shy, sad little shadow. Gloomlings never attack and never take anything;
## at most one sits in a narrow path (the player is simply stopped, like by a
## bush) or hugs something it found. Calming one is an act of kindness: shine
## your lantern, hum a melody or offer food. It then turns into a small light
## spirit, steps aside and drifts away, leaving what it was keeping safe.
## Calmed Gloomlings are stored in GameState.systems["gloomlings"].

signal calmed(gloomling: Gloomling, how: String)

const STATE_KEY := "gloomlings"
const CALM_SECONDS := 1.8

var gloomling_id: String = ""
## "light", "song" or "food": every way works; its favourite gets a warmer reaction.
var favourite: String = "light"
## What it was keeping safe: {"item": id, "qty": n} or {}.
var keeps: Dictionary = {}
var blocks_path: bool = false
var is_calm: bool = false
var _body: StaticBody2D
var _t: float = 0.0
var _transform: float = 0.0


static func is_calmed(id: String) -> bool:
	return GameState.system_state(STATE_KEY).has(id)


func setup(data: Dictionary) -> void:
	gloomling_id = String(data["id"])
	interactable_id = gloomling_id
	position = data["pos"]
	favourite = String(data.get("favourite", "light"))
	keeps = data.get("keeps", {})
	blocks_path = bool(data.get("blocks", false))
	is_calm = is_calmed(gloomling_id)
	_transform = 1.0 if is_calm else 0.0
	reach_bonus = 24.0


func _ready() -> void:
	if blocks_path:
		_body = StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 34.0
		col.shape = shape
		col.position = Vector2(0, -10)
		_body.add_child(col)
		add_child(_body)
	_sync()


func can_interact() -> bool:
	return not is_calm and super.can_interact()


func get_prompt() -> String:
	return "Comfort the Gloomling"


## Calms it. `how` is "light", "song" or "food". Returns false if already calm.
func calm(how: String, instant: bool = false) -> bool:
	if is_calm:
		return false
	is_calm = true
	GameState.system_state(STATE_KEY)[gloomling_id] = how
	GameState.add_counter("gloomlings_calmed")
	GameState.set_flag("gloomling_calmed:" + gloomling_id)
	if not keeps.is_empty():
		var left := GameState.give_item(String(keeps["item"]), int(keeps.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(keeps["item"]), left)
	if instant:
		_transform = 1.0
	else:
		var tween := create_tween()
		tween.tween_property(self, "_transform", 1.0, CALM_SECONDS * maxf(GameSettings.motion_scale(), 0.5)).set_trans(Tween.TRANS_SINE)
	_sync()
	calmed.emit(self, how)
	return true


func _sync() -> void:
	if _body != null:
		for c in _body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", is_calm)


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	var k := _transform
	if k < 0.999:
		# The sad shadow (fades out as it transforms).
		var a := 1.0 - k
		var wob := sin(_t * 2.0) * 2.0
		draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 26.0, Palette.with_alpha(Palette.SHADOW, Palette.SHADOW.a * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var body := PackedVector2Array()
		for i in 20:
			var ang := PI + PI * float(i) / 19.0
			body.append(Vector2(cos(ang) * 24.0, -4 + sin(ang) * (32.0 + wob)))
		for i in 5:
			body.append(Vector2(24.0 - i * 12.0, -4 + (6.0 if i % 2 == 0 else 0.0)))
		draw_colored_polygon(body, Color(0.2, 0.18, 0.3, 0.88 * a))
		draw_circle(Vector2(-8, -22), 5.0, Palette.with_alpha(Palette.LAVENDER, 0.9 * a))
		draw_circle(Vector2(8, -22), 5.0, Palette.with_alpha(Palette.LAVENDER, 0.9 * a))
		draw_circle(Vector2(-8, -21), 2.4, Palette.with_alpha(Palette.NIGHT_DEEP, a))
		draw_circle(Vector2(8, -21), 2.4, Palette.with_alpha(Palette.NIGHT_DEEP, a))
		# A small worried mouth and a single tear: sad, never scary.
		draw_arc(Vector2(0, -10), 5.0, PI * 1.15, PI * 1.85, 8, Palette.with_alpha(Palette.LAVENDER, 0.8 * a), 2.0)
		draw_circle(Vector2(11, -14 + fposmod(_t * 6.0, 10.0)), 1.6, Palette.with_alpha(Palette.SKY, 0.8 * a))
		if not keeps.is_empty():
			ItemArt.draw(self, Vector2(-20, -4), 16.0, String(keeps["item"]))
		draw_interaction_cues(30.0, Vector2(0, -16))
	if k > 0.001:
		# The light spirit it becomes, drifting up and to the side.
		var p := Vector2(30.0 * k, -26.0 - 30.0 * k + sin(_t * 1.6) * 4.0)
		draw_circle(p, 22.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.25 * k))
		draw_circle(p, 10.0, Palette.with_alpha(Palette.IVORY, 0.95 * k))
		draw_circle(p + Vector2(-3, -1), 1.5, Palette.with_alpha(Palette.INK, k))
		draw_circle(p + Vector2(3, -1), 1.5, Palette.with_alpha(Palette.INK, k))
		draw_arc(p + Vector2(0, 2), 3.0, 0.2, PI - 0.2, 8, Palette.with_alpha(Palette.INK, k), 1.2)
