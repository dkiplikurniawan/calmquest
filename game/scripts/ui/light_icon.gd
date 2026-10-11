class_name LightIcon
extends Control
## Tiny procedural icon used in the HUD and menus (light orb, lantern or Lumi face).

enum Style { LIGHT, LANTERN, LUMI }

var style: Style = Style.LIGHT


func _init(icon_style: Style = Style.LIGHT, icon_size: float = 28.0) -> void:
	style = icon_style
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	match style:
		Style.LIGHT:
			draw_circle(c, r, Palette.with_alpha(Palette.GOLD, 0.3))
			draw_circle(c, r * 0.6, Palette.GOLD_DEEP)
			draw_circle(c, r * 0.48, Palette.GOLD_SOFT)
		Style.LANTERN:
			draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.55), Vector2(r * 0.8, r * 1.1)), Palette.CREAM)
			draw_circle(c, r * 0.25, Palette.GOLD_DEEP)
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.75), Vector2(r * 0.6, r * 0.2)), Palette.VIOLET_DARK)
			draw_rect(Rect2(c + Vector2(-r * 0.3, r * 0.55), Vector2(r * 0.6, r * 0.2)), Palette.VIOLET_DARK)
		Style.LUMI:
			draw_circle(c, r, Palette.with_alpha(Palette.GOLD_SOFT, 0.45))
			for side: float in [-1.0, 1.0]:
				var base := c + Vector2(r * 0.45 * side, -r * 0.45)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-r * 0.25, r * 0.15), base + Vector2(r * 0.25, r * 0.15), base + Vector2(r * 0.1 * side, -r * 0.45)]), Palette.CREAM)
			draw_circle(c, r * 0.68, Palette.IVORY)
			draw_circle(c + Vector2(-r * 0.25, -r * 0.05), r * 0.1, Palette.INK)
			draw_circle(c + Vector2(r * 0.25, -r * 0.05), r * 0.1, Palette.INK)
			draw_circle(c + Vector2(0, r * 0.18), r * 0.07, Palette.VIOLET_DARK)
