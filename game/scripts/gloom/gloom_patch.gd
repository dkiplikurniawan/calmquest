class_name GloomPatch
extends Node2D
## A patch of gloom: a dim, colorless, misty circle that can hide a path
## (shadow thorns with collision) or something lost. At its center sits the
## gloom heart. Shining a Bright Lantern into it (or, later, planting a Luma
## Bloom) clears it: color flows back, flowers open and the thorns melt away.
## Cleared patches are stored in GameState.systems["gloom"].
##
## The veil is drawn in a separate canvas layer so its shader can read the
## finished world image; see RegionFeatures.

signal cleared(patch: GloomPatch)

const STATE_KEY := "gloom"
const VEIL_SHADER := preload("res://game/shaders/gloom.gdshader")
const CLEAR_SECONDS := 2.4

var patch_id: String = ""
var radius: float = 260.0
## Thorn segments in world coordinates: [[x1, y1, x2, y2], ...].
var thorns: Array = []
var is_cleared: bool = false
var cleared_silently: bool = false
var heart: GloomHeart
var veil: GloomVeil
var mist: GloomMist
var _thorn_bodies: Array[StaticBody2D] = []
var _bloom: float = 0.0
var _t: float = 0.0


static func is_patch_cleared(id: String) -> bool:
	return bool(GameState.system_state(STATE_KEY).get(id, false))


func setup(data: Dictionary, veil_parent: Node, mist_parent: Node) -> void:
	patch_id = String(data["id"])
	position = data["pos"]
	radius = float(data.get("radius", 260.0))
	thorns = data.get("thorns", [])
	is_cleared = is_patch_cleared(patch_id)
	_bloom = 1.0 if is_cleared else 0.0
	z_index = -4
	heart = GloomHeart.new()
	heart.interactable_id = patch_id + "_heart"
	heart.patch = self
	heart.position = Vector2.ZERO
	add_child(heart)
	veil = GloomVeil.new()
	veil.position = position
	veil.radius = radius
	veil.seed_value = float(hash(patch_id) % 100) * 0.1
	veil.set_strength(0.0 if is_cleared else 1.0)
	veil_parent.add_child(veil)
	mist = GloomMist.new()
	mist.patch = self
	mist.position = position
	mist_parent.add_child(mist)
	for seg: Array in thorns:
		var a := Vector2(float(seg[0]), float(seg[1])) - position
		var b := Vector2(float(seg[2]), float(seg[3])) - position
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := SegmentShape2D.new()
		shape.a = a
		shape.b = b
		col.shape = shape
		body.add_child(col)
		# A thicker capsule body so the player is stopped softly, not snagged.
		var col2 := CollisionShape2D.new()
		var cap := RectangleShape2D.new()
		cap.size = Vector2(a.distance_to(b), 34.0)
		col2.shape = cap
		col2.position = (a + b) / 2.0
		col2.rotation = (b - a).angle()
		body.add_child(col2)
		add_child(body)
		_thorn_bodies.append(body)
	_sync_thorns()


func _exit_tree() -> void:
	if is_instance_valid(veil):
		veil.queue_free()
	if is_instance_valid(mist):
		mist.queue_free()


func contains(pos: Vector2) -> bool:
	return pos.distance_to(global_position) < radius


## Clears the gloom (bright lantern, luma bloom or a quest action).
## `silent`: no message of its own (the finale clears everything at once);
## its small reward is still given.
func clear_gloom(instant: bool = false, silent: bool = false) -> bool:
	if is_cleared:
		return false
	is_cleared = true
	cleared_silently = silent
	GameState.system_state(STATE_KEY)[patch_id] = true
	GameState.set_flag("gloom_cleared:" + patch_id)
	GameState.add_counter("gloom_cleared")
	_sync_thorns()
	if instant:
		_bloom = 1.0
		veil.set_strength(0.0)
	else:
		var seconds := CLEAR_SECONDS * maxf(GameSettings.motion_scale(), 0.5)
		var tween := create_tween()
		tween.tween_method(veil.set_strength, 1.0, 0.0, seconds).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(self, "_bloom", 1.0, seconds)
	cleared.emit(self)
	return true


func _sync_thorns() -> void:
	for b in _thorn_bodies:
		b.process_mode = Node.PROCESS_MODE_DISABLED if is_cleared else Node.PROCESS_MODE_INHERIT
		for c in b.get_children():
			(c as CollisionShape2D).set_deferred("disabled", is_cleared)


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position, radius + 200.0):
		queue_redraw()


func _draw() -> void:
	# Thorns (fade out as the patch clears).
	var thorn_alpha := 1.0 - _bloom
	if thorn_alpha > 0.01:
		for seg: Array in thorns:
			var a := Vector2(float(seg[0]), float(seg[1])) - position
			var b := Vector2(float(seg[2]), float(seg[3])) - position
			var n := maxi(2, int(a.distance_to(b) / 26.0))
			for i in n + 1:
				var p := a.lerp(b, float(i) / float(n))
				var wiggle := sin(_t * 1.2 + i) * 3.0
				draw_circle(p + Vector2(0, -10), 15.0, Palette.with_alpha(Color("#3b3550"), 0.85 * thorn_alpha))
				for k in 3:
					var ang := float(k) * 2.1 + float(i)
					draw_line(p + Vector2(0, -10), p + Vector2(cos(ang) * 22.0, -10 + sin(ang) * 16.0 + wiggle), Palette.with_alpha(Color("#2a2540"), 0.8 * thorn_alpha), 3.0, true)
	# Restored flowers (grow in as the patch clears).
	if _bloom > 0.01:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(patch_id)
		for i in 26:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * radius * 0.85
			var p := Vector2(cos(a) * r, sin(a) * r * 0.8)
			var col: Color = [Palette.GOLD, Palette.LAVENDER, Color("#f7b2c4"), Palette.SKY][i % 4]
			var s := 4.0 * _bloom
			draw_line(p, p + Vector2(0, -8 * _bloom), Palette.SAGE_DARK, 2.0)
			for k in 5:
				draw_circle(p + Vector2(0, -8 * _bloom) + Vector2.RIGHT.rotated(TAU * k / 5.0) * s * 0.8, s * 0.6, col)
			draw_circle(p + Vector2(0, -8 * _bloom), s * 0.45, Palette.CREAM)


## The knot of shadow at the center of a gloom patch.
class GloomHeart extends Interactable:
	var patch: GloomPatch
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = 30.0

	func can_interact() -> bool:
		return not patch.is_cleared and super.can_interact()

	func get_prompt() -> String:
		if GameState.inventory.count("bright_lantern") > 0:
			return "Shine your Bright Lantern into the gloom"
		return "Look into the gloom"

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		if patch.is_cleared:
			var glow := 0.6 + 0.4 * sin(_t * 1.5)
			draw_circle(Vector2(0, -16), 18.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.35 * glow))
			draw_circle(Vector2(0, -16), 6.0, Palette.with_alpha(Palette.IVORY, 0.9))
			return
		for i in 6:
			var a := _t * 0.7 + float(i) * TAU / 6.0
			draw_circle(Vector2(cos(a) * 16.0, -20 + sin(a) * 9.0), 13.0, Palette.with_alpha(Color("#3b3550"), 0.75))
		draw_circle(Vector2(0, -20), 16.0, Color("#2a2540"))
		draw_circle(Vector2(-5, -22), 2.4, Palette.with_alpha(Palette.LAVENDER, 0.8))
		draw_circle(Vector2(5, -22), 2.4, Palette.with_alpha(Palette.LAVENDER, 0.8))
		draw_interaction_cues(30.0, Vector2(0, -20))


## The desaturating veil plus drifting mist, drawn above the world.
class GloomVeil extends Node2D:
	var radius: float = 260.0
	var seed_value: float = 0.0
	var strength: float = 1.0
	var _material: ShaderMaterial
	var _t: float = 0.0

	func _ready() -> void:
		_material = ShaderMaterial.new()
		_material.shader = VEIL_SHADER
		_material.set_shader_parameter("seed", seed_value)
		_material.set_shader_parameter("strength", strength)
		material = _material

	func set_strength(value: float) -> void:
		strength = clampf(value, 0.0, 1.0)
		visible = strength > 0.005
		if _material != null:
			_material.set_shader_parameter("strength", strength)
			_material.set_shader_parameter("motion", GameSettings.motion_scale())
		queue_redraw()

	# The shader animates itself (TIME), so the veil never needs a per-frame redraw.

	func _draw() -> void:
		var size := Vector2(radius, radius) * 2.3
		draw_texture_rect(GlowTexture.radial(), Rect2(-size / 2.0, size), false)


## Soft drifting mist over gloom patches (not shaded; tinted with the night).
class GloomMist extends Node2D:
	var patch: GloomPatch
	var tint: Color = Color.WHITE
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta * GameSettings.motion_scale()
		if patch != null and patch.veil != null and patch.veil.visible and ViewCull.near(global_position, patch.radius + 200.0):
			queue_redraw()

	func _draw() -> void:
		if patch == null or patch.veil == null or not patch.veil.visible:
			return
		var s := patch.veil.strength
		var r := patch.radius
		var base := Color(0.78, 0.8, 0.88) * tint
		for i in 9:
			var phase := float(i) * 1.7 + float(hash(patch.patch_id) % 7)
			var p := Vector2(cos(phase) * r * 0.55 + sin(_t * 0.15 + phase) * 40.0, sin(phase * 1.3) * r * 0.4 + cos(_t * 0.12 + phase) * 20.0)
			draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, r * 0.33, Color(base.r, base.g, base.b, 0.16 * s))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
