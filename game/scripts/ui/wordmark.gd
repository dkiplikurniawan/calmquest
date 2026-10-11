class_name Wordmark
extends Control
## The "CALMQUEST" title, drawn in code: soft warm glow behind the letters, a
## dark outline and a cream fill, with Lumi floating over the word as the light
## motif. Lumi's float respects Reduce motion.

const TEXT := "CALMQUEST"

var font_px: int = 76
var _lumi: LightIcon
var _t: float = 0.0


func _init(px: int = 76) -> void:
	font_px = px
	custom_minimum_size = Vector2(px * 7.6, px * 1.75)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_lumi = LightIcon.new(LightIcon.Style.LUMI, int(font_px * 0.62))
	_lumi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lumi)


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	var bob := sin(_t * 1.4) * font_px * 0.06
	_lumi.position = Vector2(size.x * 0.83, font_px * 0.02 + bob)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
	var base := Vector2((size.x - text_size.x) / 2.0, size.y * 0.5 + font_px * 0.36)
	var glow_center := Vector2(size.x / 2.0, size.y * 0.5)
	for i in 5:
		var k := 1.0 - i / 5.0
		draw_set_transform(glow_center, 0.0, Vector2(1.0, 0.32))
		draw_circle(Vector2.ZERO, text_size.x * (0.35 + 0.14 * i), Palette.with_alpha(Palette.GOLD_SOFT, 0.05 * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string_outline(font, base + Vector2(0, 4), TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, int(font_px * 0.16), Palette.with_alpha(Palette.NIGHT_DEEP, 0.55))
	draw_string_outline(font, base, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, int(font_px * 0.12), Palette.NIGHT_DEEP)
	draw_string(font, base, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Palette.CREAM)
	# A thin warm line under the word, like lantern light on water.
	var y := base.y + font_px * 0.22
	draw_line(Vector2(size.x * 0.3, y), Vector2(size.x * 0.7, y), Palette.with_alpha(Palette.GOLD_SOFT, 0.55), 2.0, true)
	# A few sparkles trailing behind Lumi.
	var lumi_c := _lumi.position + _lumi.size / 2.0 if _lumi != null else Vector2.ZERO
	for i in 4:
		var p := lumi_c + Vector2(-font_px * (0.45 + 0.28 * i), font_px * (0.1 + 0.06 * sin(_t * 2.0 + i)))
		draw_circle(p, 2.6 - i * 0.45, Palette.with_alpha(Palette.GOLD_SOFT, 0.8 - i * 0.17))
