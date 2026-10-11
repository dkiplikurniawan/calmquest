class_name MoonAltar
extends Interactable
## The Heart of Lumeria in Moonlit Sanctuary: the Act 1 finale.
## dormant -> (Crystal Creek awakened) -> ready -> restored.

signal restoration_finished

const RESTORE_SECONDS := 3.6

var ready_to_restore: bool = false
var restored: bool = false
var _t: float = 0.0
var _glow: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	reach_bonus = 50.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	col.position = Vector2(0, -10)
	body.add_child(col)
	add_child(body)
	_light = GlowTexture.make_light(Color("#e7defa"), 4.0, 0.0)
	_light.position = Vector2(0, -120)
	add_child(_light)


func get_prompt() -> String:
	if restored:
		return "Rest by the Heart of Lumeria"
	if ready_to_restore:
		return "Restore the Heart of Lumeria"
	return "Look at the sleeping altar"


func set_restored_instant() -> void:
	restored = true
	_glow = 1.0
	queue_redraw()


func play_restoration() -> void:
	if restored:
		return
	restored = true
	var tween := create_tween()
	tween.tween_property(self, "_glow", 1.0, RESTORE_SECONDS * maxf(GameSettings.motion_scale(), 0.5)).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: restoration_finished.emit())


func set_night_amount(amount: float) -> void:
	_light.enabled = _glow > 0.05
	_light.energy = (0.4 + 0.5 * amount) * _glow


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if _light != null and _glow > 0.05:
		_light.enabled = true
		_light.energy = 0.6 * _glow
	queue_redraw()


func _draw() -> void:
	BiomeDecorArt.shadow(self, 90.0)
	if _glow > 0.0:
		var pulse := 0.9 + 0.1 * sin(_t * 1.4)
		draw_circle(Vector2(0, -120), 220.0 * _glow * pulse, Palette.with_alpha(Color("#e7defa"), 0.16 * _glow))
		draw_line(Vector2(0, -150), Vector2(0, -150 - 600.0 * _glow), Palette.with_alpha(Palette.IVORY, 0.25 * _glow), 16.0, true)
	# Stepped stone base
	draw_rect(Rect2(-80, -18, 160, 18), Palette.STONE_DARK)
	draw_rect(Rect2(-60, -36, 120, 20), Palette.STONE)
	draw_rect(Rect2(-24, -110, 48, 76), Palette.STONE)
	# Crescent moon emblem; it lights up when the altar is ready.
	var emblem := Color("#e7defa") if (ready_to_restore or restored) else Palette.STONE_DARK
	draw_circle(Vector2(0, -150), 34.0, emblem)
	draw_circle(Vector2(14, -160), 30.0, Palette.STONE if _glow < 0.5 else Palette.with_alpha(Palette.NIGHT, 0.6))
	if ready_to_restore and not restored:
		var a := 0.4 + 0.3 * sin(_t * 2.0)
		draw_arc(Vector2(0, -150), 44.0, 0.0, TAU, 32, Palette.with_alpha(Palette.GOLD_SOFT, a), 3.0, true)
	draw_interaction_cues(56.0, Vector2(0, -20))
