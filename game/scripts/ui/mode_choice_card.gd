class_name ModeChoiceCard
extends Control
## Shown once, when a new journey starts: the three comfort modes with a short
## description, Balanced pre-selected. The mode can be changed any time from
## the pause menu afterwards.

signal chosen(mode_id: StringName)

var selected: StringName = AdaptiveComfortEngine.DEFAULT_MODE
var mode_buttons: Dictionary = {}
var _description: Label
var _begin: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := UiKit.overlay(self)
	dim.color = Color(UiKit.OVERLAY_COLOR, 0.28)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -36
	card.custom_minimum_size.x = 640
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	box.add_child(UiKit.label("How should Lumeria feel?", UiTheme.HEADING, true))
	box.add_child(UiKit.label("You can change this any time from the pause menu.", UiTheme.SUBTLE, true))
	var group := ButtonGroup.new()
	var row := HBoxContainer.new()
	for mode_id in AdaptiveComfortEngine.ALL_MODES:
		var preset := AdaptiveComfortEngine.build_preset(mode_id)
		var b := UiKit.button(preset.display_name, func() -> void: select(mode_id), UiTheme.MODE_BUTTON)
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		mode_buttons[mode_id] = b
	box.add_child(row)
	_description = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_description)
	_begin = UiKit.button("Begin", func() -> void:
		chosen.emit(selected)
		queue_free(), UiTheme.PRIMARY_BUTTON)
	box.add_child(_begin)
	select(AdaptiveComfortEngine.DEFAULT_MODE)
	_begin.call_deferred("grab_focus")


func select(mode_id: StringName) -> void:
	selected = mode_id
	for id: StringName in mode_buttons:
		(mode_buttons[id] as Button).set_pressed_no_signal(id == mode_id)
	_description.text = AdaptiveComfortEngine.build_preset(mode_id).description
