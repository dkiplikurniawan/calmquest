class_name StoragePanel
extends Control
## The cottage storage chest: click a stack in your bag to put it in the chest,
## or a stack in the chest to take it back. Unique tools may be stored too;
## nothing can be lost (a move only happens if there is room).

signal closed

var _bag_grid: GridContainer
var _chest_grid: GridContainer
var _status: Label


func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.overlay(self)
	var box := UiKit.centered_panel(self, 1120)
	box.add_child(UiKit.label("Storage chest", UiTheme.HEADING))
	box.add_child(UiKit.label("Click a stack to move it to the other side.", UiTheme.SUBTLE, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	var left := VBoxContainer.new()
	left.add_child(UiKit.label("Bag", UiTheme.SUBTLE))
	_bag_grid = _grid()
	left.add_child(_bag_grid)
	var right := VBoxContainer.new()
	right.add_child(UiKit.label("Chest", UiTheme.SUBTLE))
	_chest_grid = _grid()
	right.add_child(_chest_grid)
	row.add_child(left)
	row.add_child(right)
	box.add_child(row)
	_status = UiKit.label("", UiTheme.SUBTLE, true)
	box.add_child(_status)
	var close := UiKit.button("Close", close_panel, UiTheme.PRIMARY_BUTTON)
	box.add_child(close)
	_refresh()
	close.call_deferred("grab_focus")


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	return g


func close_panel() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func _refresh() -> void:
	_fill(_bag_grid, GameState.inventory, GameState.storage)
	_fill(_chest_grid, GameState.storage, GameState.inventory)


func _fill(grid: GridContainer, from: Inventory, to: Inventory) -> void:
	for c in grid.get_children():
		c.queue_free()
	for i in from.capacity():
		var s: Dictionary = from.slots[i]
		var slot := ItemSlot.new(48)
		slot.set_item(String(s.get("id", "")), int(s.get("qty", 0)))
		var index := i
		slot.pressed.connect(func() -> void: _move(from, to, index))
		grid.add_child(slot)


static func move_stack(from: Inventory, to: Inventory, index: int) -> int:
	if index >= from.slots.size() or from.slots[index].is_empty():
		return 0
	var id := String(from.slots[index]["id"])
	var qty := int(from.slots[index]["qty"])
	var movable := mini(qty, to.room_for(id))
	if movable <= 0:
		return 0
	from.slots[index]["qty"] = qty - movable
	if int(from.slots[index]["qty"]) == 0:
		from.slots[index] = {}
	from.changed.emit()
	to.add(id, movable)
	return movable


func _move(from: Inventory, to: Inventory, index: int) -> void:
	var moved := move_stack(from, to, index)
	_status.text = L.t("Moved %d.") % moved if moved > 0 else L.t("There's no room on the other side.")
	AudioManager.play(&"ui_click")
	_refresh()
