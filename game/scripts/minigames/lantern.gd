class_name Lantern
extends Interactable
## A floating paper lantern for Lantern Catch.
##
## Movement integrates its own phase, so a mode change only eases the speed and
## wander radius toward new values: lanterns never jump, respawn or duplicate.
## Speeds are capped by AdaptiveComfortEngine.LANTERN_SPEED_MAX (far below the
## player's speed), so catching one never needs quick reactions.

const FLOAT_HEIGHT := 30.0
const PARAM_EASE_RATE := 1.5

var anchor: Vector2 = Vector2.ZERO
var is_bonus: bool = false
var collected: bool = false

var _speed: float = 0.0
var _wander: float = 0.0
var _target_speed: float = 18.0
var _target_wander: float = 60.0
var _y_ratio: float = 0.8
var _phase_x: float = 0.0
var _phase_y: float = 0.0
var _t: float = 0.0
var _light: PointLight2D


func setup(anchor_position: Vector2, bonus: bool, seed_value: int) -> void:
	anchor = anchor_position
	position = anchor
	is_bonus = bonus
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_phase_x = rng.randf_range(0.0, TAU)
	_phase_y = rng.randf_range(0.0, TAU)
	_t = rng.randf_range(0.0, 10.0)


func _ready() -> void:
	_light = GlowTexture.make_light(Palette.GOLD if not is_bonus else Palette.GOLD_DEEP, 1.4, 0.0)
	_light.position = Vector2(0, -FLOAT_HEIGHT)
	add_child(_light)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


func can_interact() -> bool:
	return not collected and super.can_interact()


func get_prompt() -> String:
	return "Catch the golden lantern (bonus)" if is_bonus else "Catch the lantern"


func apply_config(config: ModeConfig, motion_scale: float, immediate: bool = false) -> void:
	_target_speed = config.lantern_drift_speed * motion_scale
	_target_wander = config.lantern_wander_radius
	animation_intensity = config.animation_intensity * motion_scale
	# Playful lanterns trace livelier figure-eights; Gentle ones barely sway.
	_y_ratio = 1.6 if config.mode_id == AdaptiveComfortEngine.MODE_PLAYFUL else 0.8
	if immediate:
		_speed = _target_speed
		_wander = _target_wander


func set_night_amount(amount: float) -> void:
	_light.enabled = amount > 0.01 and not collected
	_light.energy = 0.6 * amount


func mark_collected() -> void:
	if collected:
		return
	collected = true
	set_targeted(false)
	_light.enabled = false
	# The lantern floats up into the night sky.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 140.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)


## Gentle fade-out when the night ends early.
func dismiss() -> void:
	collected = true
	set_targeted(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if collected:
		queue_redraw()
		return
	var ease_w := 1.0 - exp(-PARAM_EASE_RATE * delta)
	_speed = lerpf(_speed, _target_speed, ease_w)
	_wander = lerpf(_wander, _target_wander, ease_w)
	# Angular speed chosen so the peak linear speed is about _speed.
	var omega := _speed / maxf(_wander, 1.0)
	_phase_x += omega * delta
	_phase_y += omega * _y_ratio * delta
	position = anchor + Vector2(sin(_phase_x), sin(_phase_y) * 0.6) * _wander
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 1.7) * 3.0 * animation_intensity
	var c := Vector2(0, -FLOAT_HEIGHT + bob)
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 10.0, Palette.with_alpha(Palette.SHADOW, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_interaction_cues(18.0, c)
	var body_color := Palette.GOLD if is_bonus else Palette.CREAM
	var glow := 0.85 + 0.15 * sin(_t * 2.2)
	draw_circle(c, 24.0 * glow, Palette.with_alpha(Palette.GOLD, 0.16))
	# Rounded paper body with ribs, cap and a small warm flame inside.
	var body := Rect2(c + Vector2(-9, -12), Vector2(18, 24))
	draw_rect(body, body_color)
	draw_circle(c + Vector2(0, -12), 9.0, body_color)
	draw_circle(c + Vector2(0, 12), 9.0, body_color)
	draw_circle(c, 5.0 * glow, Palette.GOLD_DEEP)
	draw_circle(c, 2.5, Palette.IVORY)
	draw_line(c + Vector2(-5, -18), c + Vector2(-5, 18), Palette.with_alpha(Palette.GOLD_DEEP, 0.5), 1.0, true)
	draw_line(c + Vector2(5, -18), c + Vector2(5, 18), Palette.with_alpha(Palette.GOLD_DEEP, 0.5), 1.0, true)
	draw_rect(Rect2(c + Vector2(-6, -24), Vector2(12, 4)), Palette.VIOLET_DARK)
	draw_rect(Rect2(c + Vector2(-6, 20), Vector2(12, 4)), Palette.VIOLET_DARK)
	if is_bonus:
		draw_arc(c, 20.0, 0.0, TAU, 24, Palette.with_alpha(Palette.IVORY, 0.8), 1.5, true)
