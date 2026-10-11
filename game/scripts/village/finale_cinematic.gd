class_name FinaleCinematic
extends CanvasLayer
## The screen layer of the Festival of Light cinematic (0.4.0): soft letterbox
## bars, rising motes of light, a few calm closing lines, the scrolling credits
## and a "hold to skip" hint with a progress ring. Holding Esc (or the gamepad
## B / Start) for SKIP_HOLD seconds skips the rest; it never traps the player.
## With Reduce motion the credits fade page by page instead of scrolling.

signal skip_requested

const SKIP_HOLD := 1.2
const LINE_SECONDS := 3.0
const MOTE_COUNT := 46

var skipped: bool = false
var _hold: float = 0.0
var _root: Control
var _caption: Label
var _credits: VBoxContainer
var _skip_hint: Label
var _ring: Control
var _bars: Array[ColorRect] = []
var _motes: Array = []
var _motes_t: float = -1.0
var _credit_tween: Tween
var _t: float = 0.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiKit.adopt_theme(_root)
	var motes := Control.new()
	motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motes.draw.connect(func() -> void: _draw_motes(motes))
	_root.add_child(motes)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.05, 0.06, 0.12, 0.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size.y = 56
		bar.offset_bottom = 56 if top else 0
		bar.offset_top = 0 if top else -56
		_root.add_child(bar)
		_bars.append(bar)
	_caption = UiKit.label("", UiTheme.TITLE, true)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", int(38 * GameSettings.get_text_scale()))
	_caption.set_anchors_preset(Control.PRESET_CENTER)
	_caption.custom_minimum_size = Vector2(900, 0)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caption.modulate.a = 0.0
	_root.add_child(_caption)
	_credits = VBoxContainer.new()
	_credits.add_theme_constant_override("separation", 16)
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits.visible = false
	_root.add_child(_credits)
	_skip_hint = UiKit.label("", UiTheme.LIGHT)
	_skip_hint.add_theme_font_size_override("font_size", int(16 * GameSettings.get_text_scale()))
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_hint.offset_right = -64
	_skip_hint.offset_bottom = -18
	_skip_hint.text = L.t("Hold %s to skip") % InputSetup.key_name(InputSetup.primary_key(InputSetup.PAUSE))
	_root.add_child(_skip_hint)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(32, 32)
	_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ring.offset_left = -50
	_ring.offset_top = -50
	_ring.offset_right = -18
	_ring.offset_bottom = -18
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	_root.add_child(_ring)
	var tween := create_tween().set_parallel(true)
	for bar in _bars:
		tween.tween_property(bar, "color:a", 0.75, 1.2)


func _process(delta: float) -> void:
	_t += delta
	var holding := Input.is_action_pressed(&"ui_cancel") or Input.is_action_pressed(InputSetup.PAUSE)
	_hold = minf(SKIP_HOLD, _hold + delta) if holding else maxf(0.0, _hold - delta * 2.0)
	_ring.queue_redraw()
	if _hold >= SKIP_HOLD and not skipped:
		request_skip()
	if _motes_t >= 0.0:
		_motes_t += delta * maxf(GameSettings.motion_scale(), 0.4)
		(_root.get_child(0) as Control).queue_redraw()


func request_skip() -> void:
	if skipped:
		return
	skipped = true
	skip_requested.emit()


func hold_progress() -> float:
	return _hold / SKIP_HOLD


func _draw_ring() -> void:
	var c := _ring.size / 2.0
	_ring.draw_arc(c, 13.0, 0.0, TAU, 24, Palette.with_alpha(Palette.CREAM, 0.35), 2.0, true)
	if _hold > 0.0:
		_ring.draw_arc(c, 13.0, -PI / 2.0, -PI / 2.0 + TAU * hold_progress(), 24, Palette.GOLD, 3.0, true)


## Motes of light drifting up across the whole screen as the light spreads.
func start_motes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in MOTE_COUNT:
		_motes.append([rng.randf(), rng.randf_range(0.6, 1.3), rng.randf_range(0.04, 0.1), rng.randf_range(0.0, TAU), rng.randf_range(1.5, 3.5)])
	_motes_t = 0.0


func motes_active() -> bool:
	return _motes_t >= 0.0


func _draw_motes(ci: Control) -> void:
	if _motes_t < 0.0:
		return
	var size := ci.size
	for m: Array in _motes:
		var x := float(m[0]) * size.x + sin(_motes_t * 0.6 + float(m[3])) * 20.0
		var y := size.y * (float(m[1]) - _motes_t * float(m[2]))
		y = fposmod(y, size.y + 40.0) - 20.0
		var a := clampf(_motes_t * 0.5, 0.0, 1.0)
		ci.draw_circle(Vector2(x, y), float(m[4]) * 3.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.15 * a))
		ci.draw_circle(Vector2(x, y), float(m[4]), Palette.with_alpha(Color("#fff3c4"), 0.85 * a))


## Shows a few closing lines one after another (each fades in and out).
func show_lines(lines: PackedStringArray) -> void:
	var tween := create_tween()
	for line in lines:
		tween.tween_callback(func() -> void: _caption.text = line)
		tween.tween_property(_caption, "modulate:a", 1.0, 0.8)
		tween.tween_interval(LINE_SECONDS - 1.6)
		tween.tween_property(_caption, "modulate:a", 0.0, 0.8)


func caption_text() -> String:
	return _caption.text


## Scrolls the credits up over `seconds` (or fades them page by page with
## Reduce motion).
func roll_credits(lines: PackedStringArray, seconds: float) -> void:
	for c in _credits.get_children():
		c.queue_free()
	_credits.add_child(Wordmark.new(int(48 * GameSettings.get_text_scale())))
	for line in lines:
		var l := UiKit.label(line, UiTheme.LIGHT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 760
		_credits.add_child(l)
	var thanks := UiKit.label("Thank you for playing.", UiTheme.LIGHT)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits.add_child(thanks)
	_credits.visible = true
	_credits.reset_size()
	var view := _root.get_viewport_rect().size
	_credits.position = Vector2((view.x - 760.0) / 2.0, view.y + 20.0)
	if _credit_tween != null:
		_credit_tween.kill()
	_credit_tween = create_tween()
	if GameSettings.reduce_motion:
		_credits.position.y = (view.y - _credits.size.y) / 2.0
		_credits.modulate.a = 0.0
		_credit_tween.tween_property(_credits, "modulate:a", 1.0, 1.2)
		_credit_tween.tween_interval(maxf(0.5, seconds - 2.4))
		_credit_tween.tween_property(_credits, "modulate:a", 0.0, 1.2)
	else:
		_credit_tween.tween_property(_credits, "position:y", -_credits.size.y - 20.0, seconds)


func credits_text() -> String:
	var parts := PackedStringArray()
	for c in _credits.get_children():
		if c is Label:
			parts.append((c as Label).text)
	return "\n".join(parts)
