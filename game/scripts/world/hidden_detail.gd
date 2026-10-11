class_name HiddenDetail
extends Interactable
## A small hidden environmental detail. A faint sparkle appears only when the
## player wanders nearby, rewarding relaxed exploration. Discovering it adds a
## journal entry; it is never required for any objective.

enum Kind { MOSS_SPRITE, STAR_STONE, FAIRY_RING }

const REVEAL_DISTANCE := 170.0
const TITLES := {
	Kind.MOSS_SPRITE: "Sleeping Moss Sprite",
	Kind.STAR_STONE: "Old Star Stone",
	Kind.FAIRY_RING: "Fairy Mushroom Ring",
}
const DESCRIPTIONS := {
	Kind.MOSS_SPRITE: "A tiny moss sprite naps beneath the bush, breathing softly.",
	Kind.STAR_STONE: "A worn stone carved with a star. It feels warm to the touch.",
	Kind.FAIRY_RING: "A perfect ring of little mushrooms, humming quietly.",
}

@export var kind: Kind = Kind.MOSS_SPRITE

var observer: Node2D = null
var discovered: bool = false
var _near: float = 0.0
var _t: float = 0.0


func get_title() -> String:
	return TITLES[kind]


func get_description() -> String:
	return DESCRIPTIONS[kind]


func get_prompt() -> String:
	return "Look closer" if not discovered else L.t("Visit the %s") % L.t(get_title())


func mark_discovered() -> void:
	discovered = true
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	var target := 0.0
	if observer != null and observer.global_position.distance_to(global_position) < REVEAL_DISTANCE:
		target = 1.0
	_near = move_toward(_near, target, delta * 1.5)
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.MOSS_SPRITE:
			draw_circle(Vector2(0, -6), 9.0, Palette.SAGE)
			draw_circle(Vector2(-3, -10), 3.0, Palette.MINT)
			var breath := 1.0 + sin(_t * 1.6) * 0.06
			draw_arc(Vector2(-3, -6), 1.8 * breath, 0.0, PI, 6, Palette.INK, 1.4, true)
			draw_arc(Vector2(3, -6), 1.8 * breath, 0.0, PI, 6, Palette.INK, 1.4, true)
		Kind.STAR_STONE:
			var pts := PackedVector2Array([Vector2(-14, 0), Vector2(-12, -22), Vector2(0, -30), Vector2(12, -22), Vector2(14, 0)])
			draw_colored_polygon(pts, Palette.STONE_DARK)
			var star_alpha := 0.35 + 0.5 * maxf(_near, 1.0 if discovered else 0.0)
			_draw_star(Vector2(0, -15), 7.0, Palette.with_alpha(Palette.GOLD_SOFT, star_alpha))
		Kind.FAIRY_RING:
			for i in 8:
				var a := i * TAU / 8.0
				var p := Vector2(cos(a) * 26.0, sin(a) * 12.0)
				draw_rect(Rect2(p + Vector2(-1.5, -6), Vector2(3, 6)), Palette.CREAM)
				draw_circle(p + Vector2(0, -7), 4.0, Palette.ROOF if i % 2 == 0 else Palette.LAVENDER)
	# Discovery sparkle (only visible when the player is near).
	var sparkle_a := _near * (0.5 + 0.5 * sin(_t * 3.0))
	if discovered:
		sparkle_a *= 0.35
	if sparkle_a > 0.02:
		_draw_star(Vector2(10, -26) + Vector2(0, sin(_t * 2.0) * 3.0), 5.0, Palette.with_alpha(Palette.GOLD, sparkle_a))
	draw_interaction_cues(20.0, Vector2(0, -8))


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI / 2.0 + i * TAU / 8.0
		var r := radius if i % 2 == 0 else radius * 0.4
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
