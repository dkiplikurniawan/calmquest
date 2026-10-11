class_name FoxDen
extends Interactable
## The ember fox den in Misty Pinewood, where a worried mother fox waits for
## her kits. Following kits run home when you come near.

const ARRIVE_DISTANCE := 190.0

var total_kits: int = 3
var _t: float = 0.0


func _ready() -> void:
	reach_bonus = 40.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 46.0
	col.shape = shape
	col.position = Vector2(0, -16)
	body.add_child(col)
	add_child(body)


func get_prompt() -> String:
	return "Visit the fox den"


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 80.0)
	# A mossy mound with a round entrance under pine roots.
	var mound := PackedVector2Array()
	for i in 21:
		var a := PI + PI * float(i) / 20.0
		mound.append(Vector2(cos(a) * 76.0, sin(a) * 52.0))
	draw_colored_polygon(mound, Color("#6f8f6a"))
	draw_set_transform(Vector2(0, -14), 0.0, Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, 26.0, Palette.NIGHT_DEEP)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(Vector2(-60, -30), Vector2(-20, -50), Palette.BARK, 6.0, true)
	draw_line(Vector2(50, -36), Vector2(10, -48), Palette.BARK, 5.0, true)
	# The mother fox sits by the entrance (happier when all kits are home).
	var home := LostKit.kits_home()
	var tail_wag := sin(_t * (4.0 if home >= total_kits else 1.0)) * 0.5
	CreatureArt.draw(self, "fox", Color("#f4a259"), Color("#fff6e5"), _t + tail_wag, 0.0, -1.0, Vector2(58, 4), 1.1)
	draw_interaction_cues(56.0, Vector2(0, -16))
