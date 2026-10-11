class_name BreathePanel
extends Control
## "Breathe with Lumi" (0.4.0): an optional, quiet breathing pace. Lumi's glow
## slowly grows while breathing in and shrinks while breathing out, with a soft
## "Breathe in..." / "Breathe out..." cue. Paces: Gentle (4 s in, 6 s out),
## Even (4 / 4), Slow (5 / 7); 1, 2 or 3 minutes, or until stopped.
## Any key, click or button stops it at once. There are no counters, scores,
## streaks or judgements, and nothing is stored except the chosen pace and
## length (as preferences). In Study Mode with consent, only "activity
## started / finished: breathing" events are logged.
## Reduce motion: the glow keeps its size and slowly brightens and dims, with
## a thin progress line for each breath.

signal closed

const PACES: Array[Dictionary] = [
	{"name": "Gentle", "in": 4.0, "out": 6.0},
	{"name": "Even", "in": 4.0, "out": 4.0},
	{"name": "Slow", "in": 5.0, "out": 7.0},
]
## Minutes; 0 = until stopped.
const LENGTHS: Array[int] = [1, 2, 3, 0]
const LENGTH_NAMES: PackedStringArray = ["1 minute", "2 minutes", "3 minutes", "Until I stop"]
const NOTE := "Breathe comfortably. If anything feels uncomfortable, simply stop and breathe normally."
const SMALL_RADIUS := 56.0
const LARGE_RADIUS := 150.0
const STILL_RADIUS := 100.0
## A short, quiet moment before the first breath and after the last.
const SETTLE_SECONDS := 1.5

var running: bool = false
var finished: bool = false
var elapsed: float = 0.0
var pace_index: int = 0
var length_index: int = 0
var _setup_box: Control
var _run_root: Control
var _glow: Control
var _cue: Label
var _settle: float = 0.0
var _end_t: float = -1.0


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	pace_index = clampi(GameSettings.breathe_pace, 0, PACES.size() - 1)
	length_index = clampi(GameSettings.breathe_length, 0, LENGTHS.size() - 1)
	UiKit.overlay(self)
	_build_setup()


func _build_setup() -> void:
	var box := UiKit.centered_panel(self, 640)
	_setup_box = box.get_parent().get_parent()
	box.add_child(UiKit.label("Breathe with Lumi", UiTheme.HEADING))
	box.add_child(UiKit.label("Lumi's glow grows as you breathe in and softens as you breathe out. Follow it if you like.", &"", true))
	box.add_child(UiKit.label(NOTE, UiTheme.SUBTLE, true))
	box.add_child(UiKit.label("Pace", UiTheme.SUBTLE))
	var pace_group := ButtonGroup.new()
	var pace_buttons: Array = []
	for i in PACES.size():
		var p: Dictionary = PACES[i]
		var b := UiKit.button(L.t("%s (%d s in, %d s out)") % [L.t(String(p["name"])), int(p["in"]), int(p["out"])], func() -> void: pace_index = i, UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = pace_group
		b.button_pressed = i == pace_index
		pace_buttons.append(b)
	var paces := VBoxContainer.new()
	for b: Button in pace_buttons:
		paces.add_child(b)
	box.add_child(paces)
	box.add_child(UiKit.label("Length", UiTheme.SUBTLE))
	var length_group := ButtonGroup.new()
	var length_buttons: Array = []
	for i in LENGTHS.size():
		var b := UiKit.button(LENGTH_NAMES[i], func() -> void: length_index = i, UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = length_group
		b.button_pressed = i == length_index
		length_buttons.append(b)
	box.add_child(UiKit.hbox(length_buttons))
	var begin := UiKit.button("Begin", begin_breathing, UiTheme.PRIMARY_BUTTON)
	var back := UiKit.button("Back", close_panel)
	box.add_child(UiKit.hbox([back, begin]))
	begin.call_deferred("grab_focus")


## Starts the breathing pace (also used by tests).
func begin_breathing() -> void:
	if running:
		return
	GameSettings.breathe_pace = pace_index
	GameSettings.breathe_length = length_index
	GameSettings.save_settings()
	if _setup_box != null:
		_setup_box.queue_free()
		_setup_box = null
	running = true
	elapsed = 0.0
	_settle = SETTLE_SECONDS
	_build_running()
	StudyMode.log_event("activity_started", "breathing")


func _build_running() -> void:
	_run_root = Control.new()
	_run_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_run_root)
	_glow = Control.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow)
	_run_root.add_child(_glow)
	var lumi := LightIcon.new(LightIcon.Style.LUMI, 56.0)
	lumi.set_anchors_preset(Control.PRESET_CENTER)
	lumi.position -= Vector2(28, 28)
	_run_root.add_child(lumi)
	_cue = UiKit.label("", UiTheme.TITLE)
	_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cue.offset_top = -190
	_cue.offset_bottom = -130
	_cue.custom_minimum_size.x = 600
	_run_root.add_child(_cue)
	var stop := UiKit.label("Press any key to stop", UiTheme.SUBTLE)
	stop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stop.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stop.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stop.offset_top = -70
	stop.offset_bottom = -40
	stop.custom_minimum_size.x = 600
	_run_root.add_child(stop)


## Breath at time `t` (seconds since the first breath) for a pace:
## {"inhale": bool, "progress": 0..1 within the phase, "amount": 0..1 fullness}.
static func phase_at(t: float, pace: int) -> Dictionary:
	var p: Dictionary = PACES[clampi(pace, 0, PACES.size() - 1)]
	var inhale := float(p["in"])
	var exhale := float(p["out"])
	var c := fposmod(t, inhale + exhale)
	if c < inhale:
		var k := c / inhale
		return {"inhale": true, "progress": k, "amount": smoothstep(0.0, 1.0, k)}
	var k2 := (c - inhale) / exhale
	return {"inhale": false, "progress": k2, "amount": 1.0 - smoothstep(0.0, 1.0, k2)}


## Glow radius for a breath fullness (Reduce motion keeps a steady size).
static func glow_radius(amount: float, reduce_motion: bool) -> float:
	return STILL_RADIUS if reduce_motion else lerpf(SMALL_RADIUS, LARGE_RADIUS, amount)


## Seconds of breathing for the chosen length (0 = until stopped).
func length_seconds() -> float:
	return float(LENGTHS[length_index]) * 60.0


func current_phase() -> Dictionary:
	return phase_at(elapsed, pace_index)


func _process(delta: float) -> void:
	if not running:
		return
	if _end_t >= 0.0:
		_end_t += delta
		_glow.modulate.a = maxf(0.0, 1.0 - _end_t / SETTLE_SECONDS)
		if _end_t >= SETTLE_SECONDS:
			close_panel()
		return
	if _settle > 0.0:
		_settle -= delta
		_cue.text = ""
		_glow.queue_redraw()
		return
	elapsed += delta
	if length_seconds() > 0.0 and elapsed >= length_seconds():
		_finish()
		return
	_cue.text = L.t("Breathe in...") if bool(current_phase()["inhale"]) else L.t("Breathe out...")
	_glow.queue_redraw()


func _finish() -> void:
	finished = true
	_end_t = 0.0
	_cue.text = ""


func _draw_glow() -> void:
	var center := _glow.size / 2.0
	var ph := current_phase() if _settle <= 0.0 else {"inhale": true, "progress": 0.0, "amount": 0.0}
	var amount := float(ph["amount"])
	var reduce := GameSettings.reduce_motion
	var radius := glow_radius(amount, reduce)
	var bright := lerpf(0.35, 1.0, amount) if reduce else 0.8
	var col := Cosmetics.glow_color()
	for i in 6:
		var r := radius * (1.0 + 0.22 * (5 - i))
		_glow.draw_circle(center, r, Palette.with_alpha(col, (0.03 + 0.035 * i) * bright))
	_glow.draw_circle(center, radius * 0.55, Palette.with_alpha(Color("#fff3c4"), 0.22 * bright))
	if reduce and _settle <= 0.0:
		# A thin progress line under the glow for each breath in and out.
		var w := 220.0
		var y := center.y + STILL_RADIUS + 46.0
		_glow.draw_line(Vector2(center.x - w / 2.0, y), Vector2(center.x + w / 2.0, y), Palette.with_alpha(Palette.CREAM, 0.25), 3.0, true)
		_glow.draw_line(Vector2(center.x - w / 2.0, y), Vector2(center.x - w / 2.0 + w * float(ph["progress"]), y), Palette.with_alpha(Palette.GOLD, 0.9), 3.0, true)


## Stops at once (any input while breathing).
func stop() -> void:
	if not running:
		return
	close_panel()


func close_panel() -> void:
	if running:
		running = false
		StudyMode.log_event("activity_finished", "breathing")
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not running:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.is_echo()) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6)
	if pressed:
		get_viewport().set_input_as_handled()
		stop()


func _unhandled_input(event: InputEvent) -> void:
	if not running and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
