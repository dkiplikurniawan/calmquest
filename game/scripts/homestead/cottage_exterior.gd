class_name CottageExterior
extends Interactable
## The Traveler's Cottage seen from the meadow. Its look follows the
## restoration steps: a patched roof, warm windows at night once the window is
## repaired, and chimney smoke once the hearth is lit. E at the door enters.

var _t: float = 0.0
var _night: float = 0.0
var _decor: Decoration


func _ready() -> void:
	reach_bonus = 30.0
	_decor = Decoration.new()
	_decor.kind = Decoration.Kind.COTTAGE
	# Drawn behind this node so the roof patches and window glow appear on top.
	_decor.show_behind_parent = true
	add_child(_decor)
	var smoke := CPUParticles2D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 4.0
	smoke.position = Vector2(50, -192)
	smoke.direction = Vector2(0.3, -1)
	smoke.spread = 15.0
	smoke.gravity = Vector2(4, -10)
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 14.0
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.9, 0.95, 0.5))
	ramp.set_color(1, Color(0.9, 0.9, 0.95, 0.0))
	smoke.color_ramp = ramp
	add_child(smoke)
	refresh()


func get_prompt() -> String:
	return "Enter the cottage"


## Door point: in front of the door at the bottom center.
func get_interaction_point() -> Vector2:
	return global_position + Vector2(0, 6)


func refresh() -> void:
	var state := GameState.system_state("cottage")
	(get_node("Smoke") as CPUParticles2D).emitting = bool(state.get("hearth", false)) and GameSettings.motion_scale() > 0.5
	queue_redraw()


func set_night_amount(amount: float) -> void:
	_night = amount
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	_t += delta


func _draw() -> void:
	var state := GameState.system_state("cottage")
	if not bool(state.get("roof", false)):
		# Missing shingles and a patch of bare roof: the roof needs fixing.
		draw_colored_polygon(PackedVector2Array([Vector2(-30, -150), Vector2(10, -150), Vector2(0, -128), Vector2(-24, -126)]), Palette.BARK_DARK)
		draw_line(Vector2(-60, -140), Vector2(-40, -122), Palette.BARK_DARK, 3.0)
	if bool(state.get("window", false)):
		var glow := 0.35 + 0.65 * _night
		for wx: float in [-60.0, 34.0]:
			draw_rect(Rect2(Vector2(wx, -78), Vector2(26, 26)).grow(4.0 * _night), Palette.with_alpha(Palette.GOLD, 0.35 * glow))
	else:
		# A cracked pane on the right window.
		draw_line(Vector2(36, -76), Vector2(58, -54), Palette.INK_SOFT, 2.0)
		draw_line(Vector2(56, -76), Vector2(42, -60), Palette.INK_SOFT, 2.0)
	draw_interaction_cues(30.0, Vector2(0, -20))
