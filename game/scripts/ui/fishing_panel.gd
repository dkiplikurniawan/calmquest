class_name FishingPanel
extends Control
## The gentle fishing minigame, shown in the world (0.4.0): the line and the
## bobber are drawn in the water at the fishing spot, and a small, soft bar
## sits just below the player. Nothing covers the world.
##   1. Wait for a nibble (the bobber bobs; a ripple appears).
##   2. When a fish bites, press E / Space / click within a comfortable window.
##   3. Reel: hold E / Space / the mouse button to move the green zone right,
##      let go and it drifts left. Keep the fish inside the zone to fill the bar.
## Nothing is ever lost: a missed bite just swims away, and the bar never
## "fails". Gentle mode catches automatically after the bite; Playful is a
## little livelier. Esc or "Done" leaves at any time. With High contrast or a
## larger text size the bar is bigger and clearer.

signal closed
signal caught(fish_id: String, result: Dictionary)

enum Stage { WAIT, BITE, REEL, CAUGHT, MISSED }

const BITE_WINDOW := {&"gentle": 4.0, &"balanced": 2.4, &"playful": 1.8}
const ZONE_WIDTH := {&"gentle": 0.4, &"balanced": 0.32, &"playful": 0.24}
const REEL_GAIN := 0.24
const REEL_LOSS := 0.05
const BAR_SIZE := Vector2(320, 40)
const LARGE_BAR_SIZE := Vector2(460, 60)
## The bar panel sits beside the player, this far from them.
const BESIDE_PLAYER := 70.0

var spot: FishingSpot
var region: String = ""
var mode_id: StringName = &"balanced"
var stage: Stage = Stage.WAIT
var fish_id: String = ""
var progress: float = 0.0
var zone: float = 0.3
var fish_pos: float = 0.5
var last_result: Dictionary = {}
## The player (for drawing the line from the rod); set by the world.
var player_node: Node2D
var bobber: Bobber
var bar_panel: PanelContainer
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
	# A transparent layer: a click anywhere acts, like E. The world stays visible.
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_view_input)
	bar_panel = PanelContainer.new()
	bar_panel.theme_type_variation = UiTheme.HUD_PANEL
	add_child(bar_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bar_panel.add_child(box)
	box.add_child(UiKit.label("Fishing", UiTheme.SUBTLE))
	_view = Control.new()
	_view.custom_minimum_size = bar_size()
	_view.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.draw.connect(_draw_view)
	box.add_child(_view)
	_status = UiKit.label("", UiTheme.HUD, true)
	_status.custom_minimum_size = Vector2(bar_size().x, 0)
	box.add_child(_status)
	# Buttons are for the mouse; on the keyboard E / Space act and Esc leaves,
	# so a focused button can never swallow the reel key.
	_again = UiKit.button("Keep fishing (E)", _start_wait, UiTheme.PRIMARY_BUTTON)
	_again.visible = false
	_again.focus_mode = Control.FOCUS_NONE
	_again.custom_minimum_size.y = 40
	var done := UiKit.button("Done (Esc)", close_panel)
	done.focus_mode = Control.FOCUS_NONE
	done.custom_minimum_size.y = 40
	box.add_child(UiKit.hbox([_again, done]))
	if spot != null and spot.is_inside_tree():
		bobber = Bobber.new()
		bobber.panel = self
		spot.get_parent().add_child(bobber)
		bobber.global_position = spot.global_position
	_start_wait()


## The accessibility fallback: a larger, clearer bar with High contrast or a
## larger text size.
func is_large() -> bool:
	return GameSettings.high_contrast or GameSettings.text_scale_index >= 1


func bar_size() -> Vector2:
	return LARGE_BAR_SIZE if is_large() else BAR_SIZE


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
	AudioManager.play(&"splash")


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
	_place_bar()
	_view.queue_redraw()
	if bobber != null:
		bobber.queue_redraw()


## Beside the player (right, or left near the screen edge), never over them.
func _place_bar() -> void:
	var view := get_viewport_rect().size
	bar_panel.reset_size()
	var p := view / 2.0
	if player_node != null and is_instance_valid(player_node) and player_node.is_inside_tree():
		p = player_node.get_global_transform_with_canvas().origin + Vector2(0, -40)
	var x := p.x + BESIDE_PLAYER
	if x + bar_panel.size.x > view.x - 16.0:
		x = p.x - BESIDE_PLAYER - bar_panel.size.x
	var y := clampf(p.y - bar_panel.size.y / 2.0, 16.0, view.y - bar_panel.size.y - 16.0)
	bar_panel.position = Vector2(x, y)


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
	AudioManager.play(&"catch")
	caught.emit(fish_id, last_result)


func _missed() -> void:
	stage = Stage.MISSED
	_timer = 1.6
	_status.text = "It swam away. That's alright, another will come."
	AudioManager.play(&"soft_deny", 1.2)


func close_panel() -> void:
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()


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


## The small tension bar near the player.
func _draw_view() -> void:
	var size := _view.size
	var large := is_large()
	var bar := Rect2(Vector2(0, size.y * 0.35), Vector2(size.x, size.y * 0.65))
	_view.draw_rect(bar, Palette.with_alpha(Palette.NIGHT_DEEP, 0.75 if large else 0.5))
	if large:
		_view.draw_rect(bar, Palette.INK, false, 2.0)
	match stage:
		Stage.REEL:
			var z := Rect2(bar.position + Vector2(bar.size.x * zone, 0), Vector2(bar.size.x * zone_width(), bar.size.y))
			_view.draw_rect(z, Palette.with_alpha(Palette.MINT, 0.9))
			_view.draw_rect(z, Palette.SAGE_DARK, false, 3.0 if large else 2.0)
			var fx := bar.position.x + bar.size.x * fish_pos
			ItemArt.draw(_view, Vector2(fx, bar.get_center().y), bar.size.y * 0.85, fish_id)
			_view.draw_rect(Rect2(Vector2(0, 0), Vector2(size.x * progress, size.y * 0.22)), Palette.GOLD)
			_view.draw_rect(Rect2(Vector2(0, 0), Vector2(size.x, size.y * 0.22)), Palette.with_alpha(Palette.INK, 0.4), false, 1.0)
		Stage.BITE:
			var k := 0.5 + 0.5 * sin(_t * 10.0)
			_view.draw_rect(bar, Palette.with_alpha(Palette.GOLD_SOFT, 0.25 + 0.35 * k))
			_view.draw_string(get_theme_default_font(), bar.get_center() + Vector2(-6, 10), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(bar.size.y * 0.9), Palette.GOLD)
		Stage.CAUGHT:
			ItemArt.draw(_view, bar.get_center(), bar.size.y * 0.9, fish_id)


## The line and the bobber in the water at the fishing spot (world space).
## Keeps animating while the world is paused for the minigame.
class Bobber extends Node2D:
	var panel: FishingPanel

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		z_index = 5

	func _draw() -> void:
		if panel == null or not is_instance_valid(panel):
			return
		var t := panel._t
		var dip := 0.0
		match panel.stage:
			FishingPanel.Stage.WAIT:
				dip = sin(t * 2.0) * 3.0 * GameSettings.motion_scale()
			FishingPanel.Stage.BITE:
				dip = 7.0 + sin(t * 18.0) * 4.0 * maxf(GameSettings.motion_scale(), 0.4)
		var bob := Vector2(0, dip)
		# The line from the rod tip (just above the player's hand) to the bobber.
		var tip := Vector2(0, -160)
		if panel.player_node != null and is_instance_valid(panel.player_node):
			tip = to_local(panel.player_node.global_position + Vector2(16 if panel.player_node.global_position.x < global_position.x else -16, -46))
		var mid := (tip + bob) / 2.0 + Vector2(0, 18)
		draw_polyline(PackedVector2Array([tip, mid, bob]), Palette.with_alpha(Palette.IVORY, 0.85), 1.5, true)
		# Soft ripples around the bobber.
		for i in 2:
			var k := fposmod(t * 0.6 * maxf(GameSettings.motion_scale(), 0.4) + i * 0.5, 1.0)
			draw_arc(bob + Vector2(0, 6), 10.0 + k * 26.0, 0.0, TAU, 24, Palette.with_alpha(Palette.IVORY, 0.45 * (1.0 - k)), 1.5, true)
		draw_circle(bob, 8.0, Color("#e9867a"))
		draw_circle(bob + Vector2(0, -4), 4.5, Palette.IVORY)
		draw_arc(bob, 8.0, 0.0, TAU, 16, Palette.INK, 1.2, true)
		if panel.stage == FishingPanel.Stage.BITE:
			var k := fposmod(t * 2.0, 1.0)
			draw_arc(bob + Vector2(0, 8), 14.0 + k * 30.0, 0.0, TAU, 24, Palette.with_alpha(Palette.IVORY, 1.0 - k), 2.0)
			draw_string(ThemeDB.fallback_font, bob + Vector2(14, -16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.GOLD)
		elif panel.stage == FishingPanel.Stage.CAUGHT:
			ItemArt.draw(self, bob + Vector2(0, -34), 44.0, panel.fish_id)
