class_name BiomeDecorArt
extends RefCounted
## Procedural drawings for the V2 biome decorations. Kept separate from
## Decoration so each biome's silhouettes are easy to find and tune.
## All drawing happens in the decoration's local space (origin = base).

const GLOW_TEAL := Color("#7fe3d4")
const GROVE_CANOPY: Array[Color] = [Color("#2f6b5e"), Color("#3f7f6d"), Color("#4f9277")]
const CRYSTAL_COLORS: Array[Color] = [Color("#a7d8f0"), Color("#c3b1e1"), Color("#9fe3d6")]
const SNOW := Color("#f4f8fc")
const FROST := Color("#bfe3f5")
const BOULDER_COLORS: Array[Color] = [Color("#9b98b0"), Color("#8f8ca3"), Color("#a7a3b9")]


static func draw(ci: CanvasItem, kind: int, s: float, variant: int) -> void:
	match kind:
		Decoration.Kind.GROVE_TREE:
			_grove_tree(ci, s, variant)
		Decoration.Kind.GLOWCAP:
			_glowcap(ci, s, variant)
		Decoration.Kind.FERN:
			_fern(ci, s, variant)
		Decoration.Kind.REEDS:
			_reeds(ci, s, variant)
		Decoration.Kind.CRYSTAL:
			_crystal(ci, s, variant)
		Decoration.Kind.MOON_LILY:
			_moon_lily(ci, s, variant)
		Decoration.Kind.PILLAR:
			_pillar(ci, s, variant)
		Decoration.Kind.BEACH_GRASS:
			_beach_grass(ci, s, variant)
		Decoration.Kind.DRIFTWOOD:
			_driftwood(ci, s, variant)
		Decoration.Kind.SHELL:
			_shell(ci, s, variant)
		Decoration.Kind.SNOW_PINE:
			_snow_pine(ci, s, variant)
		Decoration.Kind.FROST_FLOWER:
			_frost_flower(ci, s, variant)
		Decoration.Kind.BOULDER, Decoration.Kind.CLIFF_BOULDER:
			_boulder(ci, s, variant, kind == Decoration.Kind.CLIFF_BOULDER)


static func shadow(ci: CanvasItem, radius: float) -> void:
	ci.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	ci.draw_circle(Vector2.ZERO, radius, Palette.SHADOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _grove_tree(ci: CanvasItem, s: float, v: int) -> void:
	shadow(ci, 44.0 * s)
	var trunk := PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(7, -50), Vector2(-7, -50)])
	for i in trunk.size():
		trunk[i] *= s
	ci.draw_colored_polygon(trunk, Palette.BARK_DARK)
	var shift := float(v % 5) * 2.0
	var blobs := [[Vector2(-24 + shift, -70), 30.0, 0], [Vector2(24, -72 - shift), 29.0, 0], [Vector2(0, -96), 34.0, 1], [Vector2(-16, -112), 22.0, 2], [Vector2(18, -104), 20.0, 2]]
	for b: Array in blobs:
		ci.draw_circle((b[0] as Vector2) * s, float(b[1]) * s, GROVE_CANOPY[int(b[2])])
	# A few resting fireflies: tiny warm dots, a readable "grove" signature.
	for i in 3:
		var p := Vector2(-20 + ((v + i * 37) % 40), -80 - ((v * 3 + i * 23) % 40)) * s
		ci.draw_circle(p, 2.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.9))


static func _glowcap(ci: CanvasItem, s: float, v: int) -> void:
	for m: Array in [[Vector2(0, 0), 1.0], [Vector2(13, 4), 0.7], [Vector2(-11, 3), 0.6]]:
		var p := (m[0] as Vector2) * s
		var k := float(m[1]) * s
		ci.draw_circle(p + Vector2(0, -12) * k, 14.0 * k, Palette.with_alpha(GLOW_TEAL, 0.18))
		ci.draw_rect(Rect2(p + Vector2(-2.5, -10) * k, Vector2(5, 10) * k), Palette.CREAM)
		ci.draw_circle(p + Vector2(0, -12) * k, 8.0 * k, GLOW_TEAL if v % 3 != 0 else Palette.LAVENDER)
		ci.draw_circle(p + Vector2(-2, -14) * k, 2.0 * k, Palette.IVORY)


static func _fern(ci: CanvasItem, s: float, v: int) -> void:
	var color := Palette.SAGE_DARK if v % 2 == 0 else Palette.FOREST
	for i in 5:
		var angle := -PI / 2.0 + (i - 2) * 0.42
		var tip := Vector2.RIGHT.rotated(angle) * 22.0 * s
		ci.draw_line(Vector2.ZERO, tip, color, 2.0, true)
		for k in range(1, 4):
			var p := tip * (k / 4.0)
			var n := tip.orthogonal().normalized() * 5.0 * s
			ci.draw_line(p, p + n, color, 1.5, true)
			ci.draw_line(p, p - n, color, 1.5, true)


static func _reeds(ci: CanvasItem, s: float, v: int) -> void:
	for i in 4:
		var x := (i - 1.5) * 5.0 * s
		var h := (26.0 + float((v + i * 7) % 12)) * s
		ci.draw_line(Vector2(x, 0), Vector2(x + (i - 1.5) * 2.0, -h), Palette.SAGE_DARK, 2.0, true)
		if i % 2 == 0:
			ci.draw_line(Vector2(x + (i - 1.5) * 2.0, -h), Vector2(x + (i - 1.5) * 2.0, -h - 9.0 * s), Palette.BARK, 4.0, true)


static func _crystal(ci: CanvasItem, s: float, v: int) -> void:
	shadow(ci, 18.0 * s)
	var color: Color = CRYSTAL_COLORS[v % CRYSTAL_COLORS.size()]
	ci.draw_circle(Vector2(0, -18) * s, 22.0 * s, Palette.with_alpha(color, 0.18))
	for shard: Array in [[Vector2(0, 0), 1.0, 0.0], [Vector2(-9, 2), 0.65, -0.35], [Vector2(9, 2), 0.7, 0.3]]:
		var base := (shard[0] as Vector2) * s
		var k := float(shard[1]) * s
		var tilt := float(shard[2])
		var pts := PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(5, -26), Vector2(0, -36), Vector2(-5, -26)])
		for i in pts.size():
			pts[i] = base + (pts[i] * k).rotated(tilt)
		ci.draw_colored_polygon(pts, color)
		ci.draw_line(pts[4], pts[3], Palette.with_alpha(Palette.IVORY, 0.8), 1.5, true)


static func _moon_lily(ci: CanvasItem, s: float, v: int) -> void:
	ci.draw_line(Vector2.ZERO, Vector2(0, -12) * s, Palette.SAGE_DARK, 2.0, true)
	ci.draw_circle(Vector2(0, -15) * s, 9.0 * s, Palette.with_alpha(Palette.LAVENDER, 0.25))
	for i in 6:
		var a := i * TAU / 6.0 + float(v % 10) * 0.1
		ci.draw_circle(Vector2(0, -15) * s + Vector2(cos(a), sin(a)) * 4.0 * s, 3.2 * s, Color("#e7defa"))
	ci.draw_circle(Vector2(0, -15) * s, 2.0 * s, Palette.GOLD_SOFT)


static func _pillar(ci: CanvasItem, s: float, v: int) -> void:
	shadow(ci, 22.0 * s)
	var h := (60.0 + float(v % 30)) * s
	ci.draw_rect(Rect2(Vector2(-12, -h), Vector2(24, h) * Vector2(1, 1)), Palette.STONE)
	ci.draw_rect(Rect2(Vector2(-16, -10) * s, Vector2(32, 10) * s), Palette.STONE_DARK)
	ci.draw_line(Vector2(-4, -h + 6), Vector2(-4, -12 * s), Palette.with_alpha(Palette.IVORY, 0.5), 2.0)
	# Broken top
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-12, -h), Vector2(12, -h), Vector2(4, -h - 8 * s), Vector2(-6, -h - 4 * s)]), Palette.STONE)
	ci.draw_circle(Vector2(8, -h * 0.6), 3.0 * s, Palette.with_alpha(Palette.SAGE, 0.8))


static func _beach_grass(ci: CanvasItem, s: float, v: int) -> void:
	var color := Color("#b9c98f")
	for i in 5:
		var x := (i - 2.0) * 3.0 * s
		var h := (14.0 + float((v + i * 5) % 9)) * s
		ci.draw_line(Vector2(x, 0), Vector2(x + (i - 2.0) * 3.0 * s, -h), color, 1.8, true)


static func _driftwood(ci: CanvasItem, s: float, v: int) -> void:
	shadow(ci, 26.0 * s)
	var angle := float(v % 7 - 3) * 0.08
	ci.draw_set_transform(Vector2(0, -6), angle, Vector2.ONE)
	ci.draw_rect(Rect2(Vector2(-28, -6) * s, Vector2(56, 12) * s), Color("#cdbfa8"))
	ci.draw_circle(Vector2(-28, 0) * s, 6.0 * s, Color("#b9aa92"))
	ci.draw_line(Vector2(-14, -2) * s, Vector2(18, -2) * s, Color("#b9aa92"), 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _shell(ci: CanvasItem, s: float, v: int) -> void:
	var color := Color("#f7d9cf") if v % 2 == 0 else Color("#f3e3c3")
	ci.draw_circle(Vector2(0, -4) * s, 6.0 * s, color)
	for i in 4:
		var a := PI + 0.4 + i * 0.6
		ci.draw_line(Vector2(0, 0), Vector2(cos(a), sin(a)) * 6.0 * s + Vector2(0, -4) * s, Palette.with_alpha(Palette.BARK, 0.5), 1.0, true)


static func _snow_pine(ci: CanvasItem, s: float, v: int) -> void:
	shadow(ci, 30.0 * s)
	ci.draw_rect(Rect2(Vector2(-5, -18) * s, Vector2(10, 18) * s), Palette.BARK)
	for l: Array in [[-18.0, 32.0], [-46.0, 26.0], [-70.0, 19.0]]:
		var y := float(l[0]) * s
		var w := float(l[1]) * s
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, y), Vector2(w, y), Vector2(0, y - w * 1.25)]), Color("#4f7c78"))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-w * 0.45, y - w * 0.7), Vector2(w * 0.45, y - w * 0.7), Vector2(0, y - w * 1.25)]), SNOW)


static func _frost_flower(ci: CanvasItem, s: float, v: int) -> void:
	ci.draw_line(Vector2.ZERO, Vector2(0, -10) * s, Color("#8fb6c8"), 2.0, true)
	for i in 6:
		var a := i * TAU / 6.0 + float(v % 6) * 0.2
		var tip := Vector2(0, -13) * s + Vector2(cos(a), sin(a)) * 6.0 * s
		ci.draw_line(Vector2(0, -13) * s, tip, FROST, 2.0, true)
	ci.draw_circle(Vector2(0, -13) * s, 2.0 * s, SNOW)


static func _boulder(ci: CanvasItem, s: float, v: int, on_cliff: bool) -> void:
	var color: Color = BOULDER_COLORS[v % BOULDER_COLORS.size()]
	if on_cliff:
		color = color.darkened(0.12)
	shadow(ci, 30.0 * s)
	ci.draw_circle(Vector2(-10, -14) * s, 18.0 * s, color)
	ci.draw_circle(Vector2(10, -12) * s, 16.0 * s, color.darkened(0.05))
	ci.draw_circle(Vector2(0, -24) * s, 16.0 * s, color.lightened(0.05))
	ci.draw_circle(Vector2(-4, -30) * s, 5.0 * s, Palette.with_alpha(Palette.IVORY, 0.35))
