class_name FishingPanel
extends Control
## The gentle fishing minigame.
##   1. Wait for a nibble (the line bobs; a ripple appears).
##   2. When a fish bites, press E / Space / click within a comfortable window.
##   3. Reel: hold E / Space / the mouse button to move the green zone right,
##      let go and it drifts left. Keep the fish inside the zone to fill the bar.
## Nothing is ever lost: a missed bite just swims away, and the bar never
## "fails". Gentle mode catches automatically after the bite; Playful is a
## little livelier. Esc or "Done" leaves at any time.

signal closed
signal caught(fish_id: String, result: Dictionary)

enum Stage { WAIT, BITE, REEL, CAUGHT, MISSED }

const BITE_WINDOW := {&"gentle": 4.0, &"balanced": 2.4, &"playful": 1.8}
const ZONE_WIDTH := {&"gentle": 0.4, &"balanced": 0.32, &"playful": 0.24}
const REEL_GAIN := 0.24
const REEL_LOSS := 0.05

var spot: FishingSpot
var region: String = ""
var mode_id: StringName = &"balanced"
var stage: Stage = Stage.WAIT
var fish_id: String = ""
var progress: float = 0.0
var zone: float = 0.3
var fish_pos: float = 0.5
var last_result: Dictionary = {}
var _fish_target: float = 0.5
var _retarget: float = 0.0
var _timer: float = 0.0
var _size: int = 0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _view: Control
var _status: Label
var _again: Button


func setup(s: FishingSpot, region_id: String, mode: StringName) -> void:
	spot = s
	region = region_id
	mode_id = mode if BITE_WINDOW.has(mode) else &"balanced"
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 660)
	box.add_child(UiKit.label("Fishing", UiTheme.HEADING))
	_status = UiKit.label("", &"", true)
	_status.custom_minimum_size = Vector2(600, 56)
	box.add_child(_status)
	_view = Control.new()
	_view.custom_minimum_size = Vector2(600, 170)
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_on_view_input)
	box.add_child(_view)
	# Buttons are for the mouse; on the keyboard E / Space act and Esc leaves,
	# so a focused button can never swallow the reel key.
	_again = UiKit.button("Keep fishing (E)", _start_wait, UiTheme.PRIMARY_BUTTON)
	_again.visible = false
	_again.focus_mode = Control.FOCUS_NONE
	var done := UiKit.button("Done (Esc)", close_panel)
	done.focus_mode = Control.FOCUS_NONE
	box.add_child(UiKit.hbox([_again, done]))
	_start_wait()


func zone_width() -> float:
	return float(ZONE_WIDTH[mode_id])


func _start_wait() -> void:
	stage = Stage.WAIT
	fish_id = ""
	progress = 0.0
	_again.visible = false
	var lucky := 0.5 if ItemConsumer.Buffs.has("lucky_line") else 1.0
	_timer = _rng.randf_range(2.0, 5.0) * lucky
	_status.text = "You cast your line. Waiting for a nibble..."


## Skips the wait (used by tests and tools).
func skip_wait() -> void:
	if stage == Stage.WAIT:
		_timer = 0.0
		_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	match stage:
		Stage.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_bite()
		Stage.BITE:
			_timer -= delta
			if mode_id == &"gentle" and _timer < float(BITE_WINDOW[mode_id]) - 0.7:
				hook()
			elif _timer <= 0.0:
				_missed()
		Stage.REEL:
			_reel(delta)
		Stage.MISSED:
			_timer -= delta
			if _timer <= 0.0:
				_start_wait()
	_view.queue_redraw()


func _bite() -> void:
	fish_id = Fishing.pick(spot.water, region, spot.special, _rng)
	if fish_id.is_empty():
		_timer = 4.0
		_status.text = "Nothing seems hungry here right now. Fish change with the time of day and the weather."
		return
	stage = Stage.BITE
	_timer = float(BITE_WINDOW[mode_id])
	_size = Fishing.random_size(fish_id, _rng)
	AudioManager.play(&"discover", 0.9)
	if mode_id == &"gentle":
		_status.text = "A bite! (Gentle mode reels it in for you.)"
	else:
		_status.text = "A bite! Press E, Space or click."


## Player pressed the action key.
func press() -> void:
	match stage:
		Stage.BITE:
			hook()
		Stage.WAIT:
			_status.text = "Patience... wait for the ripple. (Pressing early is fine, nothing is lost.)"
		Stage.CAUGHT:
			_start_wait()


func hook() -> void:
	if stage != Stage.BITE:
		return
	if mode_id == &"gentle":
		_catch()
		return
	stage = Stage.REEL
	progress = 0.25
	zone = 0.5 - zone_width() / 2.0
	fish_pos = 0.5
	_fish_target = 0.5
	_status.text = "Hold E, Space or the mouse button to move the green zone. Keep the fish inside it."


func _holding() -> bool:
	return Input.is_action_pressed(InputSetup.INTERACT) or Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _reel(delta: float) -> void:
	_reel_step(delta, _holding())


## One reel step; `holding` moves the zone right. Public for tests.
func _reel_step(delta: float, holding: bool) -> void:
	var legendary := bool(Fishing.fish_data(fish_id).get("legendary", false))
	var liveliness := 0.18 if mode_id == &"balanced" else 0.26
	if legendary:
		liveliness *= 1.2
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = _rng.randf_range(1.2, 2.6)
		_fish_target = _rng.randf_range(0.08, 0.92)
	fish_pos = move_toward(fish_pos, _fish_target, liveliness * delta)
	zone = clampf(zone + (0.55 if holding else -0.45) * delta, 0.0, 1.0 - zone_width())
	var inside := fish_pos >= zone and fish_pos <= zone + zone_width()
	var gain := REEL_GAIN * (0.7 if legendary else 1.0)
	progress = clampf(progress + (gain if inside else -REEL_LOSS) * delta, 0.0, 1.0)
	if progress >= 1.0:
		_catch()


func _catch() -> void:
	stage = Stage.CAUGHT
	last_result = Fishing.record_catch(fish_id, _size)
	var name_ := ItemDB.display_name(fish_id)
	var text := L.t("You caught a %s! (%d cm)") % [name_, _size]
	if bool(last_result["first"]):
		text += L.t(" New in your fish journal!")
	match String(last_result["stored"]):
		"chest":
			text += L.t(" Your bag was full, so it went to the cottage chest.")
		"released":
			if bool(Fishing.fish_data(fish_id).get("legendary", false)):
				text = "Old Whiskers! The legendary catfish looks at you kindly. You say hello and let it swim home. It leaves you a carved plaque to remember the day."
			else:
				text += L.t(" Your bag and chest are full, so you let it swim away (it's in your journal).")
	_status.text = text
	_again.visible = true
	AudioManager.play(&"bloom")
	caught.emit(fish_id, last_result)


func _missed() -> void:
	stage = Stage.MISSED
	_timer = 1.6
	_status.text = "It swam away. That's alright, another will come."
	AudioManager.play(&"soft_deny", 1.2)


func close_panel() -> void:
	closed.emit()
	queue_free()


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()
	elif event.is_action_pressed(InputSetup.INTERACT) or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		press()


func _draw_view() -> void:
	var size := _view.size
	var water := Rect2(Vector2.ZERO, Vector2(size.x, size.y - 50))
	_view.draw_rect(water, Palette.WATER_DEEP)
	for i in 4:
		var y := 18.0 + i * 26.0
		var x := fposmod(_t * 20.0 * GameSettings.motion_scale() + i * 90.0, size.x + 80.0) - 40.0
		_view.draw_line(Vector2(x, y), Vector2(x + 40, y), Palette.with_alpha(Palette.IVORY, 0.35), 2.0)
	# Line and bobber.
	var bob := Vector2(size.x * 0.5, water.size.y * 0.5)
	var dip := 0.0
	if stage == Stage.WAIT:
		dip = sin(_t * 2.0) * 3.0
	elif stage == Stage.BITE:
		dip = 8.0 + sin(_t * 18.0) * 4.0
	_view.draw_line(Vector2(size.x * 0.5, 0), bob + Vector2(0, dip), Palette.with_alpha(Palette.IVORY, 0.8), 1.5)
	_view.draw_circle(bob + Vector2(0, dip), 9.0, Color("#e9867a"))
	_view.draw_circle(bob + Vector2(0, dip - 4), 5.0, Palette.IVORY)
	if stage == Stage.BITE:
		var k := fposmod(_t * 2.0, 1.0)
		_view.draw_arc(bob + Vector2(0, 8), 14.0 + k * 30.0, 0.0, TAU, 24, Palette.with_alpha(Palette.IVORY, 1.0 - k), 2.0)
		_view.draw_string(get_theme_default_font(), bob + Vector2(18, -14), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.GOLD)
	# Reel bar.
	var bar := Rect2(Vector2(20, size.y - 40), Vector2(size.x - 40, 26))
	_view.draw_rect(bar, Palette.with_alpha(Palette.NIGHT_DEEP, 0.5))
	if stage == Stage.REEL:
		var z := Rect2(bar.position + Vector2(bar.size.x * zone, 0), Vector2(bar.size.x * zone_width(), bar.size.y))
		_view.draw_rect(z, Palette.with_alpha(Palette.MINT, 0.85))
		_view.draw_rect(z, Palette.SAGE_DARK, false, 2.0)
		var fx := bar.position.x + bar.size.x * fish_pos
		ItemArt.draw(_view, Vector2(fx, bar.get_center().y), 24.0, fish_id)
		var p := Rect2(Vector2(bar.position.x, bar.position.y - 12), Vector2(bar.size.x * progress, 6))
		_view.draw_rect(p, Palette.GOLD)
	elif stage == Stage.CAUGHT:
		ItemArt.draw(_view, bob + Vector2(0, -10), 56.0, fish_id)
