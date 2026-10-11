class_name FishingSpot
extends Interactable
## Ripples near the shore where fish gather. With a fishing rod in the bag,
## E starts the gentle fishing minigame. The spot itself stands on land; the
## ripples are drawn on the water side.

var water: String = "creek"
var special: String = ""
var water_offset: Vector2 = Vector2(0, 80)
var _t: float = 0.0


func setup(data: Dictionary) -> void:
	interactable_id = String(data["id"])
	position = data["pos"]
	water = String(data.get("water", "creek"))
	special = String(data.get("special", ""))
	var o: Array = data.get("ripple", [0, 80])
	water_offset = Vector2(float(o[0]), float(o[1]))
	reach_bonus = 20.0
	z_index = -3
	_t = float(hash(interactable_id) % 100) * 0.1


func get_prompt() -> String:
	if GameState.inventory.count("fishing_rod") == 0:
		return "Ripples in the water"
	if special == "old_whiskers" and Fishing.legendary_ready():
		return "Fish here (something big is waiting...)"
	return "Fish here"


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	var c := water_offset
	for i in 3:
		var k := fposmod(_t * 0.5 + i / 3.0, 1.0)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 8.0 + k * 34.0, 0.0, TAU, 28, Palette.with_alpha(Palette.IVORY, 0.55 * (1.0 - k)), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if special == "old_whiskers" and Fishing.legendary_ready():
		draw_circle(c, 10.0 + sin(_t * 2.0) * 2.0, Palette.with_alpha(Palette.GOLD, 0.35))
	# A small reed marker on the bank so the spot is easy to find.
	draw_line(Vector2(-14, 0), Vector2(-16, -26), Palette.SAGE_DARK, 2.0)
	draw_line(Vector2(-10, 0), Vector2(-8, -20), Palette.SAGE_DARK, 2.0)
	draw_circle(Vector2(-16, -27), 3.0, Palette.BARK)
	draw_interaction_cues(18.0, Vector2(0, -6))
