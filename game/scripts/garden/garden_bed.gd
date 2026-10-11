class_name GardenBed
extends Interactable
## Optional garden bed near the Heart Tree. After the tree is restored, the
## player can plant one light here to make it bloom.

var unlocked: bool = false
var has_light: bool = false
var bloomed: bool = false
var _bloom_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	_t = float(hash(interactable_id) % 100) * 0.1


func can_interact() -> bool:
	return unlocked and not bloomed and super.can_interact()


func get_prompt() -> String:
	if has_light:
		return "Plant light in the garden bed (1 light)"
	return "Garden bed: find 1 more light"


func set_bloomed_instant() -> void:
	bloomed = true
	_bloom_t = 1.0
	queue_redraw()


func play_bloom(motion_scale: float) -> void:
	if bloomed:
		return
	bloomed = true
	set_targeted(false)
	var tween := create_tween()
	tween.tween_property(self, "_bloom_t", 1.0, 1.4 * maxf(motion_scale, 0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if _bloom_t > 0.0 or is_targeted:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 46.0, Palette.BARK_DARK)
	draw_circle(Vector2(0, -3), 41.0, Palette.BARK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var spots := [Vector2(-24, -4), Vector2(0, -10), Vector2(24, -4), Vector2(-12, 8), Vector2(12, 8)]
	var colors: Array[Color] = [Palette.LAVENDER, Palette.GOLD, Palette.SKY, Color("#f7b2c4"), Palette.IVORY]
	for i in spots.size():
		var p: Vector2 = spots[i]
		if _bloom_t <= 0.0:
			# Small sprouts waiting for light
			draw_line(p, p + Vector2(0, -7), Palette.SAGE, 2.0, true)
			draw_circle(p + Vector2(-2, -7), 2.5, Palette.SAGE)
			continue
		var k := clampf(_bloom_t * 1.6 - i * 0.12, 0.0, 1.2)
		var sway := sin(_t * 1.4 + i) * 1.5
		draw_line(p, p + Vector2(sway, -16 * k), Palette.SAGE_DARK, 2.0, true)
		for petal in 5:
			var a := petal * TAU / 5.0
			draw_circle(p + Vector2(sway, -18 * k) + Vector2(cos(a), sin(a)) * 4.0 * k, 3.4 * k, colors[i])
		draw_circle(p + Vector2(sway, -18 * k), 2.2 * k, Palette.GOLD_DEEP)
	if unlocked and not bloomed and has_light:
		draw_circle(Vector2(0, -24), 4.0 + sin(_t * 3.0), Palette.with_alpha(Palette.GOLD, 0.8))
	draw_interaction_cues(30.0, Vector2(0, -4))
