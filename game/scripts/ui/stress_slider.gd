class_name StressSlider
extends VBoxContainer
## 0-10 self-report slider used by both the check-in and the reflection.
## It starts "not answered": the value only counts once the player moves or
## clicks the slider, so an untouched default is never stored as an answer.

signal answered(value: int)

const LABEL_LOW := "0 - Very calm"
const LABEL_MID := "5 - Moderately stressed"
const LABEL_HIGH := "10 - Extremely stressed"
const START_VALUE := 5

var has_answer: bool = false
var _slider: HSlider
var _readout: Label


func _init(question: String = "Right now, how stressed do you feel?") -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiKit.label(question, &"", true))
	_slider = HSlider.new()
	_slider.min_value = 0
	_slider.max_value = 10
	_slider.step = 1
	_slider.tick_count = 11
	_slider.ticks_on_borders = true
	_slider.value = START_VALUE
	_slider.custom_minimum_size = Vector2(420, 36)
	_slider.modulate.a = 0.6
	_slider.value_changed.connect(func(_v: float) -> void: _mark_answered())
	_slider.gui_input.connect(_on_slider_input)
	add_child(_slider)
	var ends := HBoxContainer.new()
	var low := UiKit.label(LABEL_LOW, UiTheme.SUBTLE)
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mid := UiKit.label(LABEL_MID, UiTheme.SUBTLE)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var high := UiKit.label(LABEL_HIGH, UiTheme.SUBTLE)
	high.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	high.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ends.add_child(low)
	ends.add_child(mid)
	ends.add_child(high)
	add_child(ends)
	_readout = UiKit.label("", UiTheme.HEADING)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_readout)
	_update_readout()


func get_slider() -> HSlider:
	return _slider


## The answer as an int 0-10, or null if the player has not answered.
func get_answer() -> Variant:
	return int(_slider.value) if has_answer else null


func _on_slider_input(event: InputEvent) -> void:
	var mouse_press := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var key_press := event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")
	if mouse_press or key_press:
		_mark_answered()


func _mark_answered() -> void:
	has_answer = true
	_slider.modulate.a = 1.0
	_update_readout()
	answered.emit(int(_slider.value))


func _update_readout() -> void:
	if not has_answer:
		_readout.text = "Not answered yet: move the slider, or skip"
		_readout.theme_type_variation = UiTheme.SUBTLE
		return
	var v := int(_slider.value)
	var word := "Very calm" if v <= 1 else ("Calm" if v <= 3 else ("Moderately stressed" if v <= 6 else ("Quite stressed" if v <= 8 else "Extremely stressed")))
	_readout.theme_type_variation = UiTheme.HEADING
	_readout.text = L.t("Your answer: %d / 10 (%s)") % [v, word]
