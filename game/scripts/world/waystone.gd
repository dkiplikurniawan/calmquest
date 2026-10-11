class_name Waystone
extends Interactable
## Lantern Waystone: discovered when the player comes near, relit with E, and
## afterwards used to travel freely (no cost) to any other relit waystone.
## State lives in GameState; this node only displays it.

const DISCOVER_DISTANCE := 420.0

var state: String = ""
var region_name: String = ""
var _t: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	col.shape = shape
	col.position = Vector2(0, -6)
	body.add_child(col)
	add_child(body)
	reach_bonus = 14.0
	_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.6, 0.0)
	_light.position = Vector2(0, -70)
	add_child(_light)


func get_prompt() -> String:
	if state == GameState.WAYSTONE_RESTORED:
		return L.t("Travel from the %s waystone") % L.t(region_name)
	return "Relight the waystone"


func set_state(new_state: String) -> void:
	state = new_state
	queue_redraw()


func is_restored() -> bool:
	return state == GameState.WAYSTONE_RESTORED


func set_night_amount(amount: float) -> void:
	_light.enabled = amount > 0.01 and is_restored()
	_light.energy = 0.6 * amount


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 30.0)
	draw_rect(Rect2(-26, -12, 52, 12), Palette.STONE_DARK)
	var stone := PackedVector2Array([Vector2(-16, -10), Vector2(16, -10), Vector2(12, -78), Vector2(0, -92), Vector2(-12, -78)])
	draw_colored_polygon(stone, Palette.STONE)
	draw_line(Vector2(-8, -20), Vector2(-6, -74), Palette.with_alpha(Palette.IVORY, 0.5), 2.0, true)
	var restored := is_restored()
	var glow := 0.8 + 0.2 * sin(_t * 2.0)
	var rune_color := Palette.GOLD if restored else Palette.with_alpha(Palette.VIOLET_DARK, 0.55)
	# Rune ring: shape cue that differs between dim and relit states.
	draw_arc(Vector2(0, -52), 9.0, 0.0, TAU, 20, rune_color, 2.5, true)
	draw_line(Vector2(0, -61), Vector2(0, -43), rune_color, 2.0, true)
	if restored:
		draw_circle(Vector2(0, -98), 16.0 * glow, Palette.with_alpha(Palette.GOLD_SOFT, 0.3))
		draw_circle(Vector2(0, -98), 7.0, Palette.GOLD_SOFT)
		draw_circle(Vector2(0, -98), 3.5, Palette.IVORY)
	else:
		draw_circle(Vector2(0, -98), 6.0, Palette.with_alpha(Palette.STONE_DARK, 0.9))
	draw_interaction_cues(30.0, Vector2(0, -20))
