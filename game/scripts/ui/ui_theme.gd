class_name UiTheme
extends RefCounted
## Builds the single shared UI Theme from the Palette.
## Applied to the root Window by GameSettings, so every Control inherits it.
## Text size and high-contrast preferences rebuild the theme at runtime.

const BASE_FONT_SIZE := 20
const TEXT_SCALES: Array[float] = [1.0, 1.2, 1.4]
const TEXT_SCALE_NAMES: PackedStringArray = ["Normal", "Large", "Extra large"]

## Theme type variations used across the UI.
const TITLE := &"TitleLabel"
const HEADING := &"HeadingLabel"
const SUBTLE := &"SubtleLabel"
const LIGHT := &"LightLabel"
const HUD := &"HudLabel"
const PRIMARY_BUTTON := &"PrimaryButton"
const MODE_BUTTON := &"ModeButton"
const DIALOGUE_PANEL := &"DialoguePanel"
const HUD_PANEL := &"HudPanel"
## An open-license (SIL OFL) rounded font, used when its file is present in
## assets/fonts/ (see assets/fonts/README.md). Otherwise Godot's default font
## is used. The first file found wins.
const FONT_CANDIDATES: PackedStringArray = [
	"res://assets/fonts/Nunito-VariableFont_wght.ttf",
	"res://assets/fonts/Nunito-Regular.ttf",
	"res://assets/fonts/Quicksand-VariableFont_wght.ttf",
	"res://assets/fonts/Quicksand-Regular.ttf",
]


static func build(text_scale: float = 1.0, high_contrast: bool = false) -> Theme:
	var t := Theme.new()
	var ink := Color("#111827") if high_contrast else Palette.INK
	var ink_soft := Color("#1f2937") if high_contrast else Palette.INK_SOFT
	var panel_bg := Color.WHITE if high_contrast else Palette.IVORY
	var border_w := 3 if high_contrast else 2
	var fs := func(px: float) -> int: return int(round(px * text_scale))

	t.default_font_size = fs.call(BASE_FONT_SIZE)
	var font := custom_font()
	if font != null:
		t.default_font = font

	# --- Labels ---------------------------------------------------------------
	t.set_color("font_color", "Label", ink)
	_label_variation(t, TITLE, fs.call(56), Palette.CREAM, Palette.NIGHT_DEEP, 10 if high_contrast else 6)
	_label_variation(t, HEADING, fs.call(32), ink, Color(0, 0, 0, 0), 0)
	_label_variation(t, SUBTLE, fs.call(17), ink_soft, Color(0, 0, 0, 0), 0)
	_label_variation(t, LIGHT, fs.call(20), Palette.CREAM, Palette.NIGHT_DEEP, 5 if high_contrast else 3)
	_label_variation(t, HUD, fs.call(19), ink, Color(0, 0, 0, 0), 0)

	t.set_color("default_color", "RichTextLabel", ink)
	t.set_font_size("normal_font_size", "RichTextLabel", fs.call(BASE_FONT_SIZE))
	t.set_font_size("bold_font_size", "RichTextLabel", fs.call(BASE_FONT_SIZE))

	# --- Panels -----------------------------------------------------------------
	var panel := _box(panel_bg, 22, Palette.LAVENDER if not high_contrast else ink, border_w, 28)
	panel.shadow_color = Color(0.08, 0.1, 0.2, 0.28)
	panel.shadow_size = 14
	panel.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	t.set_type_variation(DIALOGUE_PANEL, "PanelContainer")
	var dialogue := _box(Palette.CREAM if not high_contrast else Color.WHITE, 18, Palette.GOLD_DEEP if not high_contrast else ink, border_w + 1, 18)
	dialogue.shadow_color = Color(0.08, 0.1, 0.2, 0.25)
	dialogue.shadow_size = 10
	t.set_stylebox("panel", DIALOGUE_PANEL, dialogue)

	t.set_type_variation(HUD_PANEL, "PanelContainer")
	var hud_alpha := 1.0 if high_contrast else 0.9
	var hud_box := _box(Palette.with_alpha(panel_bg, hud_alpha), 14, Palette.with_alpha(Palette.SAGE_DARK, 0.6) if not high_contrast else ink, border_w, 12)
	hud_box.content_margin_top = 8
	hud_box.content_margin_bottom = 8
	t.set_stylebox("panel", HUD_PANEL, hud_box)

	# --- Buttons ----------------------------------------------------------------
	_button_styles(t, "Button", Palette.CREAM, Palette.MINT, Palette.SAGE, ink, border_w, high_contrast)
	t.set_type_variation(PRIMARY_BUTTON, "Button")
	_button_styles(t, PRIMARY_BUTTON, Palette.GOLD, Palette.GOLD_SOFT, Palette.GOLD_DEEP, ink, border_w, high_contrast)
	t.set_type_variation(MODE_BUTTON, "Button")
	_button_styles(t, MODE_BUTTON, Palette.CREAM, Palette.MINT, Palette.LAVENDER, ink, border_w, high_contrast)
	var toggled := _box(Palette.LAVENDER, 14, Palette.VIOLET_DARK if not high_contrast else ink, border_w + 2, 18)
	t.set_stylebox("pressed", MODE_BUTTON, toggled)
	t.set_stylebox("hover_pressed", MODE_BUTTON, toggled)

	# --- CheckBox -------------------------------------------------------------------
	t.set_color("font_color", "CheckBox", ink)
	t.set_color("font_hover_color", "CheckBox", ink)
	t.set_color("font_pressed_color", "CheckBox", ink)
	t.set_color("font_focus_color", "CheckBox", ink)
	t.set_color("font_hover_pressed_color", "CheckBox", ink)
	var check_size := int(round(26 * text_scale))
	t.set_icon("checked", "CheckBox", _checkbox_icon(check_size, true, ink))
	t.set_icon("unchecked", "CheckBox", _checkbox_icon(check_size, false, ink))
	var empty := StyleBoxEmpty.new()
	t.set_stylebox("normal", "CheckBox", empty)
	t.set_stylebox("pressed", "CheckBox", empty)
	t.set_stylebox("hover", "CheckBox", _box(Palette.with_alpha(Palette.MINT, 0.5), 10, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("hover_pressed", "CheckBox", _box(Palette.with_alpha(Palette.MINT, 0.5), 10, Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("focus", "CheckBox", _focus_box(high_contrast))
	t.set_constant("h_separation", "CheckBox", 12)

	# --- Slider ---------------------------------------------------------------------
	var track := _box(Palette.LAVENDER if not high_contrast else Color("#9ca3af"), 8, Color(0, 0, 0, 0), 0, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := _box(Palette.VIOLET if not high_contrast else ink, 8, Color(0, 0, 0, 0), 0, 0)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab_size := int(round(30 * text_scale))
	t.set_icon("grabber", "HSlider", _circle_icon(grab_size, Palette.GOLD, ink))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(grab_size, Palette.GOLD_SOFT, ink))
	t.set_icon("grabber_disabled", "HSlider", _circle_icon(grab_size, Palette.STONE, ink_soft))
	t.set_stylebox("focus", "HSlider", _focus_box(high_contrast))

	# --- Separators / scroll -----------------------------------------------------------
	var sep := StyleBoxLine.new()
	sep.color = Palette.with_alpha(Palette.LAVENDER, 0.9)
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 14)
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)

	# --- Tabs (journal) ------------------------------------------------------------------
	var tab_panel := _box(Palette.CREAM if not high_contrast else Color.WHITE, 12, Palette.with_alpha(Palette.SAGE_DARK, 0.6) if not high_contrast else ink, border_w, 14)
	t.set_stylebox("panel", "TabContainer", tab_panel)
	var tab_on := _box(Palette.GOLD if not high_contrast else Color.WHITE, 10, Palette.GOLD_DEEP if not high_contrast else ink, border_w + 1, 10)
	var tab_off := _box(Palette.with_alpha(Palette.MINT, 0.55) if not high_contrast else Color("#e5e7eb"), 10, Palette.with_alpha(Palette.SAGE_DARK, 0.5) if not high_contrast else ink, border_w, 10)
	var tab_hover := _box(Palette.MINT if not high_contrast else Color.WHITE, 10, Palette.TURQUOISE if not high_contrast else ink, border_w, 10)
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("tab_unselected", "TabContainer", tab_off)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_stylebox("tab_focus", "TabContainer", _focus_box(high_contrast))
	t.set_color("font_selected_color", "TabContainer", ink)
	t.set_color("font_unselected_color", "TabContainer", ink_soft)
	t.set_color("font_hovered_color", "TabContainer", ink)
	t.set_constant("side_margin", "TabContainer", 0)
	return t


## The path of the custom font in use, or "" (the default font is used).
static func custom_font_path() -> String:
	for path in FONT_CANDIDATES:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


static func custom_font() -> Font:
	var path := custom_font_path()
	if path.is_empty():
		return null
	var font := load(path) as Font
	if font == null:
		push_warning("UiTheme: %s could not be loaded; using the default font." % path)
	return font


static func _label_variation(t: Theme, type_name: StringName, size: int, color: Color, outline: Color, outline_size: int) -> void:
	t.set_type_variation(type_name, "Label")
	t.set_font_size("font_size", type_name, size)
	t.set_color("font_color", type_name, color)
	if outline_size > 0:
		t.set_color("font_outline_color", type_name, outline)
		t.set_constant("outline_size", type_name, outline_size)


static func _button_styles(t: Theme, type_name: StringName, normal: Color, hover: Color, pressed: Color, ink: Color, border_w: int, high_contrast: bool) -> void:
	var border := ink if high_contrast else Palette.with_alpha(Palette.SAGE_DARK, 0.8)
	t.set_stylebox("normal", type_name, _box(normal, 14, border, border_w, 18))
	t.set_stylebox("hover", type_name, _box(hover, 14, Palette.TURQUOISE if not high_contrast else ink, border_w + 1, 18))
	t.set_stylebox("pressed", type_name, _box(pressed, 14, border, border_w, 18))
	t.set_stylebox("disabled", type_name, _box(Palette.with_alpha(Palette.STONE, 0.5), 14, Palette.with_alpha(border, 0.4), border_w, 18))
	t.set_stylebox("focus", type_name, _focus_box(high_contrast))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, type_name, ink)
	t.set_color("font_disabled_color", type_name, Palette.with_alpha(ink, 0.45))


static func _box(bg: Color, radius: int, border: Color, border_w: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.55
	s.content_margin_bottom = margin * 0.55
	s.anti_aliasing = true
	return s


## Keyboard focus ring: a clearly visible golden outline (shape + color cue).
static func _focus_box(high_contrast: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(16)
	s.border_color = Color("#b45309") if high_contrast else Palette.GOLD_DEEP
	s.set_border_width_all(4 if high_contrast else 3)
	s.expand_margin_left = 4
	s.expand_margin_right = 4
	s.expand_margin_top = 4
	s.expand_margin_bottom = 4
	return s


static func _circle_icon(size: int, fill: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	var r := size / 2.0 - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= r - 2.5:
				col = fill
			elif d <= r:
				col = border
			elif d <= r + 1.0:
				col = Palette.with_alpha(border, r + 1.0 - d)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func _checkbox_icon(size: int, checked: bool, ink: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var radius := size * 0.22
	var inset := 1.0
	var fill := Palette.VIOLET if checked else Color.WHITE
	for y in size:
		for x in size:
			var col := Color(0, 0, 0, 0)
			if _in_rounded_rect(x, y, inset, size - 1 - inset, radius):
				col = ink if not _in_rounded_rect(x, y, inset + 2.5, size - 1 - inset - 2.5, radius - 2.0) else fill
			img.set_pixel(x, y, col)
	if checked:
		var a := Vector2(size * 0.24, size * 0.52)
		var b := Vector2(size * 0.43, size * 0.72)
		var c := Vector2(size * 0.78, size * 0.30)
		_stroke(img, a, b, size * 0.09, Color.WHITE)
		_stroke(img, b, c, size * 0.09, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _in_rounded_rect(x: float, y: float, lo: float, hi: float, radius: float) -> bool:
	if x < lo or y < lo or x > hi or y > hi:
		return false
	var cx := clampf(x, lo + radius, hi - radius)
	var cy := clampf(y, lo + radius, hi - radius)
	return Vector2(x - cx, y - cy).length() <= radius


static func _stroke(img: Image, from: Vector2, to: Vector2, half_width: float, color: Color) -> void:
	var size := img.get_width()
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var seg := to - from
			var t := clampf((p - from).dot(seg) / seg.length_squared(), 0.0, 1.0)
			if p.distance_to(from + seg * t) <= half_width:
				img.set_pixel(x, y, color)
