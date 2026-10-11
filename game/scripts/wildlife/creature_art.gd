class_name CreatureArt
extends RefCounted
## Procedural, original drawings for wildlife. Everything is drawn around the
## creature's feet (origin), facing right; `flip` = -1 mirrors it to face left.
## `t` drives idle motion (breathing, wing beats); `hop` is the walk bounce.

const FLYING := ["bird", "moth", "owl"]


static func draw(ci: CanvasItem, shape: String, col: Color, acc: Color, t: float, hop: float, flip: float, origin: Vector2 = Vector2.ZERO, k: float = 1.0) -> void:
	var lift := -absf(sin(hop * 9.0)) * 4.0
	if shape in FLYING:
		lift = -6.0 - absf(sin(t * 2.0)) * 3.0 if shape != "bird" else lift
	ci.draw_set_transform(origin + Vector2(0, 3) * k, 0.0, Vector2(k, 0.35 * k))
	ci.draw_circle(Vector2.ZERO, 16.0 if shape != "deer" else 24.0, Palette.SHADOW)
	ci.draw_set_transform(origin + Vector2(0, lift) * k, 0.0, Vector2(flip * k, k))
	match shape:
		"rabbit":
			_rabbit(ci, col, acc, t)
		"deer":
			_deer(ci, col, acc, t)
		"fox":
			_fox(ci, col, acc, t)
		"owl":
			_owl(ci, col, acc, t)
		"bird":
			_bird(ci, col, acc, t)
		"crab":
			_crab(ci, col, acc, t)
		"frog":
			_frog(ci, col, acc, t)
		"moth":
			_moth(ci, col, acc, t)
		"otter":
			_otter(ci, col, acc, t)
		"hedgehog":
			_hedgehog(ci, col, acc, t)
		"squirrel":
			_squirrel(ci, col, acc, t)
		"turtle":
			_turtle(ci, col, acc, t)
		"snail":
			_snail(ci, col, acc, t)
		_:
			_ellipse(ci, Vector2(0, -10), 12.0, 9.0, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * float(i) / 18.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, color)


static func _eye(ci: CanvasItem, p: Vector2, r: float = 2.0) -> void:
	ci.draw_circle(p, r, Palette.INK)
	ci.draw_circle(p + Vector2(-0.6, -0.7), r * 0.35, Palette.IVORY)


static func _rabbit(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var ear := sin(t * 1.7) * 0.08
	for e: float in [-3.0, 3.0]:
		var base := Vector2(8 + e, -20)
		var tip := base + Vector2(-4 + e * 0.6, -16).rotated(ear)
		ci.draw_line(base, tip, col, 5.0, true)
		ci.draw_line(base + Vector2(0, -2), tip + Vector2(0, 3), acc, 2.0, true)
	_ellipse(ci, Vector2(-2, -9), 12.0, 9.0, col)
	ci.draw_circle(Vector2(9, -17), 7.0, col)
	ci.draw_circle(Vector2(-13, -10), 4.0, Palette.IVORY)
	_eye(ci, Vector2(11, -18))
	ci.draw_circle(Vector2(15, -15), 1.4, acc)


static func _deer(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	for x: float in [-12.0, -6.0, 8.0, 13.0]:
		ci.draw_line(Vector2(x, -14), Vector2(x, 0), col.darkened(0.25), 3.0, true)
	_ellipse(ci, Vector2(0, -19), 17.0, 9.0, col)
	for s: Vector2 in [Vector2(-6, -21), Vector2(0, -17), Vector2(5, -22)]:
		ci.draw_circle(s, 1.6, acc)
	var nod := sin(t * 1.1) * 1.5
	ci.draw_line(Vector2(12, -22), Vector2(17, -34 + nod), col, 6.0, true)
	_ellipse(ci, Vector2(20, -36 + nod), 6.5, 5.0, col)
	ci.draw_line(Vector2(17, -40 + nod), Vector2(13, -50 + nod), Palette.BARK_DARK, 2.0, true)
	ci.draw_line(Vector2(15, -46 + nod), Vector2(10, -48 + nod), Palette.BARK_DARK, 2.0, true)
	ci.draw_line(Vector2(21, -40 + nod), Vector2(24, -50 + nod), Palette.BARK_DARK, 2.0, true)
	_eye(ci, Vector2(22, -37 + nod), 1.7)
	ci.draw_circle(Vector2(-17, -21), 3.0, acc)


static func _fox(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var sway := sin(t * 2.0) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, -12), Vector2(-30, -18 + sway), Vector2(-26, -6 + sway * 0.5)]), col)
	ci.draw_circle(Vector2(-29, -14 + sway * 0.8), 4.0, acc)
	ci.draw_circle(Vector2(-29, -14 + sway * 0.8), 6.0, Palette.with_alpha(Palette.GOLD, 0.25 + 0.15 * sin(t * 3.0)))
	_ellipse(ci, Vector2(-1, -10), 13.0, 7.5, col)
	ci.draw_line(Vector2(-7, -5), Vector2(-7, 0), col.darkened(0.3), 3.0)
	ci.draw_line(Vector2(6, -5), Vector2(6, 0), col.darkened(0.3), 3.0)
	ci.draw_circle(Vector2(12, -16), 7.0, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(7, -21), Vector2(9, -30), Vector2(13, -22)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(13, -22), Vector2(17, -30), Vector2(18, -19)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(14, -14), Vector2(23, -13), Vector2(14, -10)]), acc)
	_eye(ci, Vector2(14, -18), 1.7)


static func _owl(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var flap := sin(t * 6.0) * 4.0
	_ellipse(ci, Vector2(-9, -16 + flap * 0.4), 5.0, 9.0, col.darkened(0.2))
	_ellipse(ci, Vector2(9, -16 - flap * 0.4), 5.0, 9.0, col.darkened(0.2))
	_ellipse(ci, Vector2(0, -17), 10.0, 13.0, col)
	_ellipse(ci, Vector2(0, -12), 6.0, 7.0, acc)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -27), Vector2(-6, -34), Vector2(-3, -27)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(3, -27), Vector2(6, -34), Vector2(8, -27)]), col)
	for x: float in [-4.0, 4.0]:
		ci.draw_circle(Vector2(x, -22), 3.6, Palette.GOLD_SOFT)
		_eye(ci, Vector2(x, -22), 1.8)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -19), Vector2(1.5, -19), Vector2(0, -16)]), Palette.GOLD_DEEP)


static func _bird(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var flap := sin(t * 5.0) * 0.3
	_ellipse(ci, Vector2(0, -9), 8.0, 6.5, col)
	ci.draw_circle(Vector2(6, -13), 5.0, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(10, -14), Vector2(15, -12.5), Vector2(10, -11)]), Palette.GOLD_DEEP)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-3, -11), Vector2(-12, -14 - flap * 10.0), Vector2(-6, -6)]), acc)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(-13, -7), Vector2(-7, -6)]), col.darkened(0.2))
	ci.draw_line(Vector2(-1, -3), Vector2(-1, 0), Palette.BARK_DARK, 1.5)
	ci.draw_line(Vector2(2, -3), Vector2(2, 0), Palette.BARK_DARK, 1.5)
	_eye(ci, Vector2(7, -14), 1.4)


static func _crab(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var pinch := sin(t * 3.0) * 1.5
	for i in 3:
		var x := -6.0 + i * 6.0
		ci.draw_line(Vector2(x, -6), Vector2(x - 4, 0), col.darkened(0.2), 2.0)
		ci.draw_line(Vector2(x, -6), Vector2(x + 4, 0), col.darkened(0.2), 2.0)
	_ellipse(ci, Vector2(0, -8), 11.0, 6.0, col)
	for side: float in [-1.0, 1.0]:
		ci.draw_line(Vector2(9 * side, -10), Vector2(14 * side, -15), col, 3.0, true)
		ci.draw_circle(Vector2(15 * side, -17 - pinch), 3.5, col)
	ci.draw_line(Vector2(-3, -13), Vector2(-3, -17), col, 1.5)
	ci.draw_line(Vector2(3, -13), Vector2(3, -17), col, 1.5)
	ci.draw_circle(Vector2(-3, -18), 2.0, acc)
	ci.draw_circle(Vector2(3, -18), 2.0, acc)
	ci.draw_circle(Vector2(-3, -18), 1.0, Palette.INK)
	ci.draw_circle(Vector2(3, -18), 1.0, Palette.INK)


static func _frog(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var puff := 1.0 + 0.15 * maxf(0.0, sin(t * 2.5))
	_ellipse(ci, Vector2(0, -7), 11.0, 7.0, col)
	_ellipse(ci, Vector2(3, -4), 6.0 * puff, 4.0 * puff, acc)
	for x: float in [-4.0, 5.0]:
		ci.draw_circle(Vector2(x, -13), 4.0, col)
		_eye(ci, Vector2(x + 0.5, -13.5), 2.0)
	ci.draw_line(Vector2(-9, -3), Vector2(-14, 0), col.darkened(0.2), 3.0)
	ci.draw_line(Vector2(9, -3), Vector2(13, 0), col.darkened(0.2), 3.0)


static func _moth(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var beat := absf(sin(t * 9.0))
	ci.draw_circle(Vector2(0, -12), 14.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.18))
	for side: float in [-1.0, 1.0]:
		var w := 6.0 + 5.0 * beat
		_ellipse(ci, Vector2(w * side, -14), w, 6.0, Palette.with_alpha(col, 0.92))
		_ellipse(ci, Vector2(w * 0.7 * side, -8), w * 0.7, 4.0, Palette.with_alpha(acc, 0.9))
	_ellipse(ci, Vector2(0, -11), 2.0, 6.0, Palette.BARK)
	ci.draw_line(Vector2(0, -17), Vector2(-3, -22), Palette.BARK, 1.0)
	ci.draw_line(Vector2(0, -17), Vector2(3, -22), Palette.BARK, 1.0)


static func _otter(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var sway := sin(t * 2.0) * 2.0
	ci.draw_line(Vector2(-14, -6), Vector2(-24, -3 + sway), col, 5.0, true)
	_ellipse(ci, Vector2(-2, -8), 14.0, 6.5, col)
	_ellipse(ci, Vector2(2, -6), 8.0, 3.5, acc)
	ci.draw_circle(Vector2(12, -13), 6.5, col)
	ci.draw_circle(Vector2(15, -11), 3.5, acc)
	ci.draw_circle(Vector2(17, -12), 1.3, Palette.INK)
	_eye(ci, Vector2(13, -15), 1.5)
	ci.draw_circle(Vector2(9, -18), 2.0, col.darkened(0.2))


static func _hedgehog(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var breathe := 1.0 + 0.04 * sin(t * 2.0)
	var spikes := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		var r := (13.0 if i % 2 == 0 else 9.0) * breathe
		spikes.append(Vector2(-2, -4) + Vector2(cos(a) * r * 1.2, sin(a) * r))
	ci.draw_colored_polygon(spikes, col)
	for p: Vector2 in [Vector2(-8, -10), Vector2(-2, -13), Vector2(5, -11)]:
		ci.draw_circle(p, 2.6, acc)
	_ellipse(ci, Vector2(10, -5), 6.0, 4.5, Palette.PATH_EDGE)
	ci.draw_circle(Vector2(15, -5), 1.6, Palette.INK)
	_eye(ci, Vector2(10, -7), 1.4)


static func _squirrel(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var sway := sin(t * 2.4) * 2.0
	var tail := PackedVector2Array([Vector2(-6, -6), Vector2(-18, -10 + sway), Vector2(-20, -24 + sway), Vector2(-12, -30 + sway), Vector2(-8, -22), Vector2(-4, -12)])
	ci.draw_colored_polygon(tail, col.lightened(0.1))
	_ellipse(ci, Vector2(1, -9), 7.0, 8.0, col)
	_ellipse(ci, Vector2(3, -7), 4.0, 5.0, acc)
	ci.draw_circle(Vector2(6, -18), 5.5, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(3, -22), Vector2(4, -27), Vector2(7, -22)]), col)
	_eye(ci, Vector2(8, -19), 1.5)
	ci.draw_circle(Vector2(5, -10), 3.0, Palette.BARK)


static func _turtle(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var peek := 2.0 + sin(t * 0.8) * 2.0
	ci.draw_circle(Vector2(16 + peek, -7), 5.0, acc.darkened(0.1))
	_eye(ci, Vector2(18 + peek, -8), 1.4)
	for x: float in [-10.0, 10.0]:
		_ellipse(ci, Vector2(x, -2), 5.0, 3.0, acc.darkened(0.1))
	var shell := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		shell.append(Vector2(cos(a) * 17.0, -3 + sin(a) * 13.0))
	ci.draw_colored_polygon(shell, col)
	for p: Vector2 in [Vector2(-7, -8), Vector2(0, -12), Vector2(7, -8)]:
		ci.draw_circle(p, 3.2, col.lightened(0.18))
	ci.draw_line(Vector2(-17, -3), Vector2(17, -3), acc, 2.0)


static func _snail(ci: CanvasItem, col: Color, acc: Color, t: float) -> void:
	var stretch := sin(t * 1.4) * 1.5
	_ellipse(ci, Vector2(2 + stretch * 0.5, -3), 12.0 + stretch, 3.5, acc)
	ci.draw_line(Vector2(11 + stretch, -5), Vector2(14 + stretch, -13), acc, 2.0)
	ci.draw_line(Vector2(9 + stretch, -5), Vector2(10 + stretch, -12), acc, 2.0)
	ci.draw_circle(Vector2(14 + stretch, -13), 1.4, Palette.INK)
	ci.draw_circle(Vector2(-1, -11), 9.0, col)
	ci.draw_arc(Vector2(-1, -11), 6.0, 0.0, TAU * 0.8, 16, col.lightened(0.25), 2.0)
	ci.draw_arc(Vector2(-1, -11), 3.0, 0.0, TAU * 0.8, 12, col.lightened(0.25), 2.0)
