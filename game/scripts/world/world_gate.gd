class_name WorldGate
extends Interactable
## A visibly locked place that a FUTURE update will open (collapsed mountain
## path, sealed cave). It is a STUB on purpose: interacting only explains what
## kind of tool or story step will open it, so the world hints at what lies ahead.

var style: String = "cave"
var hint: String = ""
var _t: float = 0.0


func _ready() -> void:
	reach_bonus = 30.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 40.0
	col.shape = shape
	col.position = Vector2(0, -10)
	body.add_child(col)
	add_child(body)


func get_prompt() -> String:
	return "Look at the collapsed path" if style == "rockfall" else "Listen at the sealed cave"


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 70.0)
	if style == "rockfall":
		for r: Array in [[Vector2(-40, -16), 30.0], [Vector2(20, -12), 34.0], [Vector2(-6, -44), 28.0], [Vector2(46, -40), 20.0]]:
			draw_circle(r[0] as Vector2, float(r[1]), Palette.STONE_DARK)
			draw_circle((r[0] as Vector2) + Vector2(-6, -8), float(r[1]) * 0.35, Palette.with_alpha(Palette.IVORY, 0.25))
		draw_rect(Rect2(64, -60, 6, 60), Palette.BARK)
		draw_rect(Rect2(50, -64, 40, 18), Palette.CREAM)
	else:
		draw_circle(Vector2(0, -30), 70.0, Palette.STONE_DARK)
		draw_set_transform(Vector2(0, -24), 0.0, Vector2(1.0, 1.15))
		draw_circle(Vector2.ZERO, 34.0, Palette.NIGHT_DEEP)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var a := 0.25 + 0.1 * sin(_t * 1.3)
		draw_circle(Vector2(0, -24), 30.0, Palette.with_alpha(Palette.LAVENDER, a))
	draw_interaction_cues(40.0, Vector2(0, -20))
