class_name HeartTree
extends Interactable
## The central magical tree. Dim until the player brings enough light.
## A ring of light slots around the roots shows the requirement visually
## (filled slots = light currently carried), in addition to the HUD counter.

signal restoration_finished

const RESTORE_SECONDS := 2.8

var required_light: int = 8
var available_light: int = 0
var restored: bool = false
var _restore_t: float = 0.0
var _t: float = 0.0
var _light: PointLight2D
var _particles: CPUParticles2D


func _ready() -> void:
	reach_bonus = 46.0
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 30.0
	col.shape = shape
	col.position = Vector2(0, -8)
	body.add_child(col)
	add_child(body)
	_light = GlowTexture.make_light(Palette.GOLD_SOFT, 4.0, 0.0)
	_light.position = Vector2(0, -120)
	add_child(_light)
	_particles = _make_particles()
	add_child(_particles)


func get_prompt() -> String:
	if restored:
		return "Admire the Heart Tree"
	if available_light >= required_light:
		return L.t("Restore the Heart Tree (%d light)") % required_light
	return L.t("Heart Tree needs %d more light") % (required_light - available_light)


func set_available_light(amount: int) -> void:
	available_light = amount
	queue_redraw()


## Immediately shows the restored state (used when the scene reloads mid-session).
func set_restored_instant() -> void:
	restored = true
	_restore_t = 1.0
	_particles.emitting = true
	queue_redraw()


func play_restoration(motion_scale: float) -> void:
	if restored:
		return
	restored = true
	_particles.emitting = true
	var tween := create_tween()
	tween.tween_property(self, "_restore_t", 1.0, RESTORE_SECONDS * maxf(motion_scale, 0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: restoration_finished.emit())


func set_night_amount(amount: float) -> void:
	_light.enabled = amount > 0.01 and _restore_t > 0.0
	_light.energy = 0.8 * amount * _restore_t


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	queue_redraw()


func _make_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 18
	p.lifetime = 4.0
	p.emitting = false
	p.position = Vector2(0, -110)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 70.0
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var ramp := Gradient.new()
	ramp.set_color(0, Palette.with_alpha(Palette.GOLD_SOFT, 0.0))
	ramp.set_color(1, Palette.with_alpha(Palette.GOLD_SOFT, 0.0))
	ramp.add_point(0.3, Palette.with_alpha(Palette.GOLD_SOFT, 0.9))
	p.color_ramp = ramp
	return p


func _draw() -> void:
	var r := _restore_t
	# Soft halo once restored
	if r > 0.0:
		var pulse := 0.9 + 0.1 * sin(_t * 1.5)
		draw_circle(Vector2(0, -120), 150.0 * r * pulse, Palette.with_alpha(Palette.GOLD_SOFT, 0.12 * r))
		draw_circle(Vector2(0, -120), 105.0 * r * pulse, Palette.with_alpha(Palette.GOLD_SOFT, 0.14 * r))
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 95.0, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Light slots around the roots (requirement indicator).
	if not restored:
		for i in required_light:
			var a := PI * 0.15 + (PI * 0.7) * i / maxf(1.0, required_light - 1.0)
			var p := Vector2(cos(a) * 92.0, sin(a) * 34.0 + 6.0)
			draw_circle(p, 7.0, Palette.with_alpha(Palette.BARK_DARK, 0.5))
			if i < available_light:
				draw_circle(p, 5.5, Palette.GOLD)
			else:
				draw_arc(p, 5.0, 0.0, TAU, 12, Palette.CREAM, 1.5, true)

	# Roots and trunk
	var bark := Palette.BARK.lerp(Palette.BARK, r)
	for root: Array in [[Vector2(-34, 2), Vector2(-14, -18)], [Vector2(36, 4), Vector2(14, -18)], [Vector2(-8, 8), Vector2(-2, -12)]]:
		draw_line(root[0] as Vector2, root[1] as Vector2, Palette.BARK_DARK, 10.0, true)
	var trunk := PackedVector2Array([Vector2(-24, 0), Vector2(24, 0), Vector2(16, -90), Vector2(30, -128), Vector2(-28, -128), Vector2(-16, -90)])
	draw_colored_polygon(trunk, bark)
	draw_line(Vector2(-4, -10), Vector2(-6, -110), Palette.BARK_DARK, 3.0, true)
	draw_line(Vector2(8, -30), Vector2(10, -100), Palette.with_alpha(Palette.BARK_DARK, 0.6), 2.0, true)

	# Canopy: desaturated when dim, lush mint/turquoise when restored.
	var dim_a := Color("#8f9a92")
	var dim_b := Color("#a7aea8")
	var col_a := dim_a.lerp(Palette.SAGE, r)
	var col_b := dim_b.lerp(Palette.MINT, r)
	var col_c := dim_b.lerp(Palette.TURQUOISE, r)
	var blobs := [
		[Vector2(-70, -150), 52.0, col_a], [Vector2(70, -150), 52.0, col_a],
		[Vector2(0, -190), 66.0, col_b], [Vector2(-50, -205), 44.0, col_b],
		[Vector2(52, -205), 44.0, col_c], [Vector2(0, -240), 40.0, col_c],
		[Vector2(-20, -150), 40.0, col_b],
	]
	for b: Array in blobs:
		draw_circle(b[0] as Vector2, float(b[1]), b[2] as Color)
	# Golden blossoms appear one by one during the restoration animation.
	var blossoms := [Vector2(-80, -160), Vector2(-30, -215), Vector2(40, -235), Vector2(85, -165), Vector2(10, -175), Vector2(-55, -190), Vector2(60, -195), Vector2(-5, -255), Vector2(30, -150)]
	for i in blossoms.size():
		var appear := clampf(r * blossoms.size() - i, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var bp: Vector2 = blossoms[i]
		var glow := 0.8 + 0.2 * sin(_t * 2.0 + i)
		draw_circle(bp, 12.0 * appear * glow, Palette.with_alpha(Palette.GOLD, 0.3))
		draw_circle(bp, 6.0 * appear, Palette.GOLD_SOFT)
		draw_circle(bp, 3.0 * appear, Palette.IVORY)
	draw_interaction_cues(40.0, Vector2(0, -10))
