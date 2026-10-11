class_name ItemArt
extends RefCounted
## Procedural item icons, shared by the inventory, hotbar, toasts and the
## gatherable objects in the world. Each item's JSON "icon" picks a shape and
## two colors, so new items need data only.


static func draw(ci: CanvasItem, center: Vector2, size: float, item_id: String) -> void:
	var icon := ItemDB.icon(item_id)
	draw_shape(ci, center, size, String(icon.get("shape", "orb")), Color(String(icon.get("color", "#888888"))), Color(String(icon.get("accent", "#ffffff"))))


static func draw_shape(ci: CanvasItem, c: Vector2, size: float, shape: String, col: Color, acc: Color) -> void:
	var r := size * 0.5
	var ink := Palette.with_alpha(Palette.INK, 0.85)
	match shape:
		"orb":
			ci.draw_circle(c, r, Palette.with_alpha(col, 0.3))
			ci.draw_circle(c, r * 0.62, col)
			ci.draw_circle(c + Vector2(-r, -r) * 0.18, r * 0.22, acc)
		"branch", "plank":
			var w := r * (0.5 if shape == "plank" else 0.28)
			ci.draw_set_transform(c, -0.6, Vector2.ONE)
			ci.draw_rect(Rect2(-r * 0.9, -w / 2.0, r * 1.8, w), col)
			if shape == "branch":
				ci.draw_line(Vector2(r * 0.1, 0), Vector2(r * 0.5, -r * 0.45), col, w * 0.7, true)
				ci.draw_circle(Vector2(r * 0.55, -r * 0.5), r * 0.18, acc)
			else:
				ci.draw_line(Vector2(-r * 0.8, 0), Vector2(r * 0.8, 0), acc, 1.5, true)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stone":
			ci.draw_circle(c + Vector2(0, r * 0.1), r * 0.75, col)
			ci.draw_circle(c + Vector2(-r * 0.25, -r * 0.15), r * 0.25, Palette.with_alpha(acc, 0.6))
		"leaf":
			for i in 3:
				var a := -PI / 2.0 + (i - 1) * 0.5
				var tip := c + Vector2.RIGHT.rotated(a) * r * 0.9
				ci.draw_line(c + Vector2(0, r * 0.6), tip, col, maxf(2.0, r * 0.18), true)
				ci.draw_circle(tip, r * 0.14, acc)
		"flower":
			for i in 5:
				var a := i * TAU / 5.0
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.42, r * 0.3, col)
			ci.draw_circle(c, r * 0.24, acc)
		"berry":
			for p: Vector2 in [Vector2(-0.3, 0.15), Vector2(0.3, 0.15), Vector2(0, -0.25)]:
				ci.draw_circle(c + p * r, r * 0.34, col)
				ci.draw_circle(c + p * r + Vector2(-r * 0.1, -r * 0.1), r * 0.08, Palette.IVORY)
			ci.draw_line(c + Vector2(0, -r * 0.55), c + Vector2(r * 0.25, -r * 0.85), acc, 2.0, true)
		"mushroom":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.05), Vector2(r * 0.36, r * 0.7)), acc)
			ci.draw_circle(c + Vector2(0, -r * 0.1), r * 0.62, col)
			ci.draw_circle(c + Vector2(-r * 0.2, -r * 0.35), r * 0.12, Palette.IVORY)
		"reed":
			for i in 3:
				var x := (i - 1) * r * 0.3
				ci.draw_line(c + Vector2(x, r * 0.8), c + Vector2(x, -r * 0.5), col, maxf(1.5, r * 0.1), true)
			ci.draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, -r * 0.9), acc, maxf(3.0, r * 0.22), true)
		"cone":
			var pts := PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.55, r * 0.1), c + Vector2(0, r * 0.8), c + Vector2(-r * 0.55, r * 0.1)])
			ci.draw_colored_polygon(pts, col)
			for k in 3:
				var y := -r * 0.4 + k * r * 0.4
				ci.draw_line(c + Vector2(-r * 0.4, y), c + Vector2(r * 0.4, y), acc, 1.5, true)
		"drop":
			ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.55, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, 0), c + Vector2(r * 0.5, 0), c + Vector2(0, -r * 0.85)]), col)
			ci.draw_circle(c + Vector2(-r * 0.18, r * 0.05), r * 0.14, acc)
		"shell":
			ci.draw_circle(c, r * 0.7, col)
			for i in 5:
				var a := PI + 0.35 + i * 0.6
				ci.draw_line(c + Vector2(0, r * 0.5), c + Vector2(cos(a), sin(a)) * r * 0.68, Palette.with_alpha(Palette.BARK, 0.5), 1.2, true)
			ci.draw_circle(c + Vector2(0, r * 0.5), r * 0.15, acc)
		"crystal":
			var pts := PackedVector2Array([c + Vector2(0, -r * 0.9), c + Vector2(r * 0.45, -r * 0.2), c + Vector2(r * 0.3, r * 0.8), c + Vector2(-r * 0.3, r * 0.8), c + Vector2(-r * 0.45, -r * 0.2)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, -r * 0.9), c + Vector2(0, r * 0.8), acc, 1.5, true)
		"coil":
			for k in 3:
				ci.draw_arc(c, r * (0.25 + k * 0.22), 0.0, TAU, 24, col if k % 2 == 0 else acc, maxf(2.0, r * 0.14), true)
		"lantern":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.45), Vector2(r * 0.8, r * 1.0)), Palette.with_alpha(col, 0.9))
			ci.draw_circle(c + Vector2(0, r * 0.05), r * 0.25, Palette.IVORY)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.48, -r * 0.6), Vector2(r * 0.96, r * 0.18)), acc)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.48, r * 0.55), Vector2(r * 0.96, r * 0.18)), acc)
			ci.draw_arc(c + Vector2(0, -r * 0.6), r * 0.3, PI, TAU, 12, acc, 2.0, true)
		"can":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.3), Vector2(r * 0.8, r * 0.9)), col)
			ci.draw_line(c + Vector2(r * 0.35, -r * 0.1), c + Vector2(r * 0.9, -r * 0.6), col, maxf(3.0, r * 0.2), true)
			ci.draw_arc(c + Vector2(-r * 0.05, -r * 0.35), r * 0.35, PI, TAU, 12, acc, 2.0, true)
		"rod":
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.7), c + Vector2(r * 0.7, -r * 0.7), col, maxf(2.5, r * 0.16), true)
			ci.draw_line(c + Vector2(r * 0.7, -r * 0.7), c + Vector2(r * 0.7, r * 0.4), acc, 1.2, true)
			ci.draw_circle(c + Vector2(r * 0.7, r * 0.45), r * 0.1, Color("#e9867a"))
		"fork":
			ci.draw_line(c + Vector2(0, r * 0.9), c + Vector2(0, 0), col, maxf(2.5, r * 0.18), true)
			ci.draw_line(c + Vector2(-r * 0.35, -r * 0.8), c + Vector2(-r * 0.35, 0), col, maxf(2.5, r * 0.16), true)
			ci.draw_line(c + Vector2(r * 0.35, -r * 0.8), c + Vector2(r * 0.35, 0), col, maxf(2.5, r * 0.16), true)
			ci.draw_line(c + Vector2(-r * 0.35, 0), c + Vector2(r * 0.35, 0), col, maxf(2.5, r * 0.16), true)
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 0.15, acc)
		"boat":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, 0), c + Vector2(r * 0.9, 0), c + Vector2(r * 0.55, r * 0.5), c + Vector2(-r * 0.55, r * 0.5)]), col)
			ci.draw_line(c + Vector2(0, 0), c + Vector2(0, -r * 0.85), Palette.BARK_DARK, 2.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.8), c + Vector2(r * 0.55, -r * 0.1), c + Vector2(0, -r * 0.1)]), acc)
		"bag":
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.7, col)
			ci.draw_arc(c + Vector2(0, -r * 0.35), r * 0.35, PI, TAU, 12, acc, 2.5, true)
			ci.draw_line(c + Vector2(-r * 0.4, r * 0.05), c + Vector2(r * 0.4, r * 0.05), acc, 2.0, true)
		"note":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.75), Vector2(r * 1.2, r * 1.5)), col)
			for k in 3:
				var y := -r * 0.4 + k * r * 0.35
				ci.draw_line(c + Vector2(-r * 0.4, y), c + Vector2(r * 0.4, y), acc, 1.5, true)
		"chair":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.8), Vector2(r * 0.9, r * 0.55)), acc)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.2), Vector2(r * 1.0, r * 0.3)), col)
			for x: float in [-0.42, 0.32]:
				ci.draw_rect(Rect2(c + Vector2(r * x, r * 0.1), Vector2(r * 0.12, r * 0.7)), acc)
		"table":
			ci.draw_set_transform(c + Vector2(0, -r * 0.2), 0.0, Vector2(1.0, 0.5))
			ci.draw_circle(Vector2.ZERO, r * 0.85, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.15), Vector2(r * 0.2, r * 0.9)), acc)
		"rug":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.5), Vector2(r * 1.9, r * 1.0)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.3), Vector2(r * 1.4, r * 0.6)), acc, false, 2.0)
		"plant":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.35, r * 0.1), Vector2(r * 0.7, r * 0.7)), acc)
			for i in 5:
				var a := -PI / 2.0 + (i - 2) * 0.45
				ci.draw_circle(c + Vector2(0, -r * 0.1) + Vector2.RIGHT.rotated(a) * r * 0.45, r * 0.28, col)
		"vase":
			ci.draw_circle(c + Vector2(0, r * 0.35), r * 0.38, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.1), Vector2(r * 0.3, r * 0.3)), col)
			for i in 3:
				ci.draw_circle(c + Vector2((i - 1) * r * 0.3, -r * 0.45), r * 0.18, acc)
		"lamp":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.06, -r * 0.4), Vector2(r * 0.12, r * 1.2)), acc)
			ci.draw_circle(c + Vector2(0, -r * 0.5), r * 0.5, Palette.with_alpha(col, 0.3))
			ci.draw_circle(c + Vector2(0, -r * 0.5), r * 0.32, col)
		"shelf":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.8), Vector2(r * 1.4, r * 1.6)), col)
			for k in 2:
				ci.draw_line(c + Vector2(-r * 0.7, -r * 0.25 + k * r * 0.55), c + Vector2(r * 0.7, -r * 0.25 + k * r * 0.55), Palette.BARK_DARK, 2.0)
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.45), r * 0.15, acc)
		"cushion":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.7))
			ci.draw_circle(Vector2.ZERO, r * 0.75, col)
			ci.draw_circle(Vector2.ZERO, r * 0.2, acc)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"basket":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.6))
			ci.draw_circle(Vector2.ZERO, r * 0.85, col)
			ci.draw_circle(Vector2.ZERO, r * 0.6, acc)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"fence":
			for x: float in [-0.6, 0.0, 0.6]:
				ci.draw_rect(Rect2(c + Vector2(r * x - r * 0.08, -r * 0.7), Vector2(r * 0.16, r * 1.4)), col)
			ci.draw_line(c + Vector2(-r * 0.8, -r * 0.3), c + Vector2(r * 0.8, -r * 0.3), acc, maxf(2.0, r * 0.12), true)
			ci.draw_line(c + Vector2(-r * 0.8, r * 0.2), c + Vector2(r * 0.8, r * 0.2), acc, maxf(2.0, r * 0.12), true)
		"bench":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.2), Vector2(r * 1.9, r * 0.3)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.6), Vector2(r * 1.9, r * 0.2)), col)
			for x: float in [-0.8, 0.7]:
				ci.draw_rect(Rect2(c + Vector2(r * x, r * 0.1), Vector2(r * 0.12, r * 0.55)), acc)
		"planter":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, 0), Vector2(r * 1.4, r * 0.65)), col)
			for i in 4:
				ci.draw_circle(c + Vector2(-r * 0.5 + i * r * 0.33, -r * 0.1), r * 0.2, acc if i % 2 == 0 else Palette.GOLD)
		"chime":
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.7), c + Vector2(r * 0.6, -r * 0.7), acc, 2.0, true)
			for i in 4:
				var x := -r * 0.45 + i * r * 0.3
				ci.draw_line(c + Vector2(x, -r * 0.7), c + Vector2(x, -r * 0.1 + i % 2 * r * 0.2), acc, 1.0, true)
				ci.draw_circle(c + Vector2(x, -r * 0.05 + i % 2 * r * 0.2), r * 0.14, col)
		"bowl":
			ci.draw_set_transform(c + Vector2(0, -r * 0.1), 0.0, Vector2(1.0, 0.45))
			ci.draw_circle(Vector2.ZERO, r * 0.8, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 0.1), c + Vector2(r * 0.8, -r * 0.1), c + Vector2(r * 0.45, r * 0.55), c + Vector2(-r * 0.45, r * 0.55)]), acc)
			ci.draw_line(c + Vector2(-r * 0.2, -r * 0.5), c + Vector2(-r * 0.1, -r * 0.85), Palette.with_alpha(Palette.IVORY, 0.7), 2.0, true)
		"cup":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.35), Vector2(r * 0.9, r * 0.85)), acc)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.38, -r * 0.3), Vector2(r * 0.76, r * 0.2)), col)
			ci.draw_arc(c + Vector2(r * 0.5, 0), r * 0.22, -PI / 2.0, PI / 2.0, 10, acc, 2.0, true)
		"skewer":
			ci.draw_line(c + Vector2(-r * 0.8, r * 0.8), c + Vector2(r * 0.8, -r * 0.8), Palette.BARK, 2.0, true)
			for i in 3:
				ci.draw_circle(c + Vector2(-0.4 + i * 0.4, 0.4 - i * 0.4) * r, r * 0.25, col if i % 2 == 0 else acc)
		"seeds":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(r * 0.6, -r * 0.5), c + Vector2(r * 0.7, r * 0.75), c + Vector2(-r * 0.7, r * 0.75)]), Color("#e8d6b0"))
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(r * 0.6, -r * 0.5), Palette.BARK, 2.0)
			ci.draw_circle(c + Vector2(0, r * 0.15), r * 0.32, col)
			ci.draw_circle(c + Vector2(r * 0.1, r * 0.05), r * 0.12, acc)
		"carrot":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.4), c + Vector2(r * 0.35, -r * 0.4), c + Vector2(0, r * 0.9)]), col)
			for x: float in [-0.25, 0.0, 0.25]:
				ci.draw_line(c + Vector2(r * x, -r * 0.4), c + Vector2(r * x * 2.0, -r * 0.95), acc, 2.5, true)
		"wheat":
			ci.draw_line(c + Vector2(0, r * 0.9), c + Vector2(0, -r * 0.2), acc, 2.0, true)
			for i in 4:
				var y := -r * 0.85 + i * r * 0.28
				ci.draw_circle(c + Vector2(-r * 0.15, y), r * 0.16, col)
				ci.draw_circle(c + Vector2(r * 0.15, y + r * 0.1), r * 0.16, col)
		"pumpkin":
			for x: float in [-0.35, 0.35, 0.0]:
				ci.draw_circle(c + Vector2(r * x, r * 0.15), r * 0.52, col if x != 0.0 else col.lightened(0.1))
			ci.draw_line(c + Vector2(0, -r * 0.35), c + Vector2(r * 0.15, -r * 0.75), acc, 3.0, true)
		"strawberry":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.3), c + Vector2(r * 0.6, -r * 0.3), c + Vector2(0, r * 0.85)]), col)
			ci.draw_circle(c + Vector2(0, -r * 0.25), r * 0.6, col)
			for p: Vector2 in [Vector2(-0.25, 0.0), Vector2(0.2, 0.15), Vector2(0.0, 0.4), Vector2(0.25, -0.2)]:
				ci.draw_circle(c + p * r, r * 0.06, Palette.GOLD_SOFT)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.4, -r * 0.75), c + Vector2(r * 0.4, -r * 0.75), c + Vector2(0, -r * 0.45)]), acc)
		"bloom":
			ci.draw_circle(c, r, Palette.with_alpha(acc, 0.3))
			for i in 6:
				ci.draw_circle(c + Vector2.RIGHT.rotated(TAU * i / 6.0) * r * 0.45, r * 0.3, col)
			ci.draw_circle(c, r * 0.28, acc)
		"fish":
			ci.draw_set_transform(c, 0.0, Vector2(1.0, 0.55))
			ci.draw_circle(Vector2(-r * 0.1, 0), r * 0.7, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.5, 0), c + Vector2(r * 0.95, -r * 0.4), c + Vector2(r * 0.95, r * 0.4)]), acc)
			ci.draw_circle(c + Vector2(-r * 0.5, -r * 0.08), r * 0.09, Palette.INK)
			ci.draw_line(c + Vector2(-r * 0.1, -r * 0.35), c + Vector2(-r * 0.1, r * 0.35), Palette.with_alpha(acc, 0.8), 1.5)
		"bread", "pie":
			ci.draw_set_transform(c + Vector2(0, r * 0.1), 0.0, Vector2(1.0, 0.6))
			ci.draw_circle(Vector2.ZERO, r * 0.8, col)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 3:
				var x := (-0.4 + i * 0.4) * r
				ci.draw_line(c + Vector2(x - r * 0.1, -r * 0.2), c + Vector2(x + r * 0.1, r * 0.25), acc, 2.0, true)
		"jar":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.4), Vector2(r * 0.9, r * 1.2)), Palette.with_alpha(Palette.SKY, 0.6))
			ci.draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.1), Vector2(r * 0.8, r * 0.85)), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.6), Vector2(r, r * 0.22)), acc)
		"plot":
			ci.draw_rect(Rect2(c - Vector2(r * 0.85, r * 0.7), Vector2(r * 1.7, r * 1.4)), acc)
			ci.draw_rect(Rect2(c - Vector2(r * 0.7, r * 0.55), Vector2(r * 1.4, r * 1.1)), col)
			for i in 3:
				ci.draw_line(c + Vector2(-r * 0.6, -r * 0.3 + i * r * 0.3), c + Vector2(r * 0.6, -r * 0.3 + i * r * 0.3), col.darkened(0.25), 2.0)
		"trophy":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.6), Vector2(r * 1.4, r * 1.0)), acc)
			draw_shape(ci, c + Vector2(0, -r * 0.1), size * 0.75, "fish", col, Palette.GOLD)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, r * 0.4), Vector2(r * 0.4, r * 0.4)), acc.darkened(0.2))
		_:
			ci.draw_circle(c, r * 0.6, col)
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 20, ink, 1.5, true)
