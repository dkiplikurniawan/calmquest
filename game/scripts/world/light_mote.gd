class_name LightMote
extends Interactable
## A collectible magical light (or a bonus Prism Mote in Playful mode).
## The mote never counts itself: the world asks SessionState to record it and
## only then calls mark_collected(), so one object can never be counted twice.

const KIND_LIGHT := &"light"
const KIND_PRISM := &"prism"
const FLOAT_HEIGHT := 26.0
const CORE_RADIUS := 7.0

@export var kind: StringName = KIND_LIGHT

## 0 = still, 1 = normal bobbing/drift, >1 livelier (from ModeConfig).
var activity: float = 1.0
var collected: bool = false
var _t: float = 0.0
var _phase: float = 0.0
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_phase = float(hash(interactable_id) % 628) / 100.0
	_t = _phase


func can_interact() -> bool:
	return not collected and super.can_interact()


func get_prompt() -> String:
	return "Collect Prism Mote (bonus)" if kind == KIND_PRISM else "Collect light"


func apply_config(config: ModeConfig, motion_scale: float) -> void:
	activity = config.collectible_activity * motion_scale
	animation_intensity = config.animation_intensity * motion_scale


## Plays the collection effect, then removes the node.
func mark_collected() -> void:
	if collected:
		return
	collected = true
	set_targeted(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y - 24.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	super(delta)
	if collected:
		return
	_t += delta
	# Gentle bob plus a small figure-eight drift; amplitude scales with activity.
	_offset = Vector2(
		sin(_t * 0.7) * 6.0 * activity,
		-FLOAT_HEIGHT + sin(_t * 1.8) * 4.0 * (0.4 + activity * 0.6)
	)
	queue_redraw()


func _draw() -> void:
	# Ground shadow keeps the floating light readable as an object in the world.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_interaction_cues(16.0, _offset)
	var pulse := 0.85 + 0.15 * sin(_t * 2.4)
	if kind == KIND_PRISM:
		_draw_prism(pulse)
	else:
		_draw_light(pulse)


func _draw_light(pulse: float) -> void:
	var c := _offset
	draw_circle(c, 22.0 * pulse, Palette.with_alpha(Palette.GOLD, 0.12))
	draw_circle(c, 15.0 * pulse, Palette.with_alpha(Palette.GOLD, 0.25))
	draw_circle(c, CORE_RADIUS + 2.0, Palette.with_alpha(Palette.GOLD_DEEP, 0.9))
	draw_circle(c, CORE_RADIUS, Palette.GOLD_SOFT)
	draw_circle(c + Vector2(-2, -2), 2.5, Palette.IVORY)
	# Four-point sparkle: a shape cue that does not rely on color alone.
	var s := 11.0 * pulse
	draw_line(c + Vector2(0, -s), c + Vector2(0, s), Palette.with_alpha(Palette.IVORY, 0.7), 1.5, true)
	draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), Palette.with_alpha(Palette.IVORY, 0.7), 1.5, true)


func _draw_prism(pulse: float) -> void:
	var c := _offset
	draw_circle(c, 22.0 * pulse, Palette.with_alpha(Palette.LAVENDER, 0.2))
	var spin := _t * 0.8
	var pts := PackedVector2Array()
	for i in 4:
		var a := spin + i * TAU / 4.0
		var r := 11.0 if i % 2 == 0 else 8.0
		pts.append(c + Vector2(cos(a), sin(a) * 1.3) * r)
	draw_colored_polygon(pts, Palette.SKY)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Palette.VIOLET_DARK, 2.0, true)
	draw_circle(c, 3.0, Palette.IVORY)
