class_name MoodFace
extends Control
## One of the five mood faces, drawn in the game's soft style. The faces never
## rely on color alone: each has its own brows, eyes and mouth.
## 1 Tense (pinched brows, zigzag mouth), 2 Uneasy (worried brows, wavy mouth),
## 3 Okay (straight mouth), 4 Calm (small smile), 5 Peaceful (closed eyes,
## wide smile and a little sparkle).

const TINTS := [Color("#d9d2ec"), Color("#d6e6f2"), Color("#fff2d6"), Color("#d8f0e0"), Color("#ffe8b0")]

var face: int = 3:
	set(value):
		face = clampi(value, 1, 5)
		queue_redraw()


func _init(which: int = 3, px: float = 64.0) -> void:
	face = which
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - 3.0
	var ink := Palette.INK
	var w := maxf(2.0, r * 0.075)
	draw_circle(c, r, TINTS[face - 1])
	draw_arc(c, r, 0.0, TAU, 40, ink, w, true)
	var eye_l := c + Vector2(-0.32, -0.1) * r
	var eye_r := c + Vector2(0.32, -0.1) * r
	match face:
		1:
			draw_line(c + Vector2(-0.52, -0.46) * r, c + Vector2(-0.14, -0.3) * r, ink, w, true)
			draw_line(c + Vector2(0.52, -0.46) * r, c + Vector2(0.14, -0.3) * r, ink, w, true)
			_dots(eye_l, eye_r, r * 0.07, ink)
			var zig := PackedVector2Array()
			for i in 7:
				zig.append(c + Vector2(-0.36 + 0.12 * i, 0.4 + (0.06 if i % 2 == 0 else -0.06)) * r)
			draw_polyline(zig, ink, w, true)
		2:
			draw_line(c + Vector2(-0.52, -0.3) * r, c + Vector2(-0.14, -0.46) * r, ink, w, true)
			draw_line(c + Vector2(0.52, -0.3) * r, c + Vector2(0.14, -0.46) * r, ink, w, true)
			_dots(eye_l, eye_r, r * 0.08, ink)
			var wave := PackedVector2Array()
			for i in 13:
				var x := -0.34 + 0.68 * i / 12.0
				wave.append(c + Vector2(x, 0.4 + 0.07 * sin(i / 12.0 * TAU)) * r)
			draw_polyline(wave, ink, w, true)
		3:
			_dots(eye_l, eye_r, r * 0.09, ink)
			draw_line(c + Vector2(-0.3, 0.38) * r, c + Vector2(0.3, 0.38) * r, ink, w, true)
		4:
			_dots(eye_l, eye_r, r * 0.09, ink)
			draw_arc(c + Vector2(0, 0.12) * r, 0.34 * r, deg_to_rad(30), deg_to_rad(150), 16, ink, w, true)
		5:
			draw_arc(eye_l + Vector2(0, -0.04) * r, 0.12 * r, deg_to_rad(20), deg_to_rad(160), 10, ink, w, true)
			draw_arc(eye_r + Vector2(0, -0.04) * r, 0.12 * r, deg_to_rad(20), deg_to_rad(160), 10, ink, w, true)
			draw_arc(c + Vector2(0, 0.08) * r, 0.42 * r, deg_to_rad(20), deg_to_rad(160), 18, ink, w, true)
			_sparkle(c + Vector2(0.72, -0.72) * r, r * 0.2, ink)


func _dots(a: Vector2, b: Vector2, radius: float, ink: Color) -> void:
	draw_circle(a, radius, ink)
	draw_circle(b, radius, ink)


func _sparkle(p: Vector2, s: float, ink: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.25, -s * 0.25), p + Vector2(s, 0), p + Vector2(s * 0.25, s * 0.25),
		p + Vector2(0, s), p + Vector2(-s * 0.25, s * 0.25), p + Vector2(-s, 0), p + Vector2(-s * 0.25, -s * 0.25)])
	draw_colored_polygon(pts, Palette.GOLD)
	pts.append(pts[0])
	draw_polyline(pts, ink, 1.5, true)


## A row of the five faces as buttons, each with its text label and an
## accessible name. Emits `chosen(face)` (1-5).
class Row extends HBoxContainer:
	signal chosen(face: int)

	var buttons: Array[Button] = []
	var selected: int = 0

	func _init(face_px: float = 60.0) -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 10)
		var group := ButtonGroup.new()
		for i in Wellbeing.FACES.size():
			var value := i + 1
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = group
			b.custom_minimum_size = Vector2(face_px + 44.0, face_px + 52.0)
			b.tooltip_text = Wellbeing.FACES[i]
			if "accessibility_name" in b:
				b.set("accessibility_name", L.t(Wellbeing.FACES[i]))
			b.set_meta("face", value)
			var box := VBoxContainer.new()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			box.add_theme_constant_override("separation", 2)
			var holder := CenterContainer.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(MoodFace.new(value, face_px))
			box.add_child(holder)
			var name_label := UiKit.label(Wellbeing.FACES[i], UiTheme.SUBTLE)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(name_label)
			b.add_child(box)
			b.pressed.connect(func() -> void:
				selected = value
				chosen.emit(value))
			UiKit.wire_feedback(b)
			add_child(b)
			buttons.append(b)
