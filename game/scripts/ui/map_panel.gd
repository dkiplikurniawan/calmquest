class_name MapPanel
extends Control
## World map overlay (M). Shows explored areas, region names, discovered places,
## relit waystones and pins. Click a glowing waystone to travel there (free).
## Click anywhere else to place a pin; click a pin to remove it. P pins your
## current position. M or Escape closes the map.

signal closed
signal travel_requested(waystone_id: String)

const CLICK_RADIUS := 16.0

var world: WorldData
var _view: MapView
var _status: Label
var _player_pos: Vector2
var _player_facing: Vector2


func setup(world_data: WorldData, player_pos: Vector2, player_facing: Vector2, quest_target: Vector2) -> void:
	world = world_data
	_player_pos = player_pos
	_player_facing = player_facing
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 940)
	var header := HBoxContainer.new()
	var title := UiKit.label("Map of Lumeria", UiTheme.HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var explored := UiKit.label(L.t("Explored: %d%%") % int(round(GameState.revealed_fraction() * 100.0)), UiTheme.SUBTLE)
	header.add_child(explored)
	box.add_child(header)
	_view = MapView.new()
	var aspect := world.world_size().y / world.world_size().x
	_view.custom_minimum_size = Vector2(880, 880 * aspect)
	_view.setup(world)
	_view.player_pos = player_pos
	_view.player_facing = player_facing
	_view.quest_target = quest_target
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_map_input)
	box.add_child(_view)
	var quest_toggle := CheckBox.new()
	quest_toggle.text = "Show quest marker"
	quest_toggle.button_pressed = true
	quest_toggle.toggled.connect(func(on: bool) -> void:
		_view.show_quest_marker = on
		_view.queue_redraw())
	UiKit.wire_feedback(quest_toggle)
	_status = UiKit.label("Click a glowing waystone to travel. Click elsewhere to place a pin (P pins where you stand).", UiTheme.SUBTLE, true)
	var close := UiKit.button("Close (M)", close_map, UiTheme.PRIMARY_BUTTON)
	box.add_child(UiKit.hbox([quest_toggle, close]))
	box.add_child(_status)
	close.call_deferred("grab_focus")


func close_map() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputSetup.MAP):
		get_viewport().set_input_as_handled()
		close_map()
	elif event.is_action_pressed(InputSetup.PIN):
		get_viewport().set_input_as_handled()
		GameState.add_pin(_player_pos)
		_status.text = "Pin placed where you are standing."
		_view.queue_redraw()


func _on_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	var click := (event as InputEventMouseButton).position
	# Relit waystone: travel.
	for ws in world.pois_of_kind("waystone"):
		var id := String(ws["id"])
		if GameState.waystone_state(id) == GameState.WAYSTONE_RESTORED and _view.world_to_map(ws["pos"]).distance_to(click) <= CLICK_RADIUS:
			travel_requested.emit(id)
			close_map()
			return
	# Existing pin: remove. Otherwise: add a pin.
	var world_pos := _view.map_to_world(click)
	var radius := CLICK_RADIUS / _view.size.x * _view.view_rect.size.x
	if GameState.remove_pin_near(world_pos, radius):
		_status.text = "Pin removed."
	else:
		GameState.add_pin(world_pos)
		_status.text = "Pin placed. Click it again to remove it."
	_view.queue_redraw()
