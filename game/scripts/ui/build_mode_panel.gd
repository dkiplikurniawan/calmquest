class_name BuildModePanel
extends Control
## Build mode for the cottage interior and the homestead plot.
## The game pauses; a grid cursor appears in the world.
##   Move: arrows / WASD or the mouse     Place: E / Enter / left click
##   Rotate: R    Store back (full refund): X / Backspace / right click
##   Undo: Z      Previous / next item: Q / C      Done: Esc or B
## Placement validity is shown with color AND a text reason.

signal closed

const KEY_PREV := KEY_Q
const KEY_NEXT := KEY_C

var overworld: Overworld
var area: BuildArea
var cursor_cell: Vector2i = Vector2i.ZERO
var rot: int = 0
var item_index: int = 0
var items: PackedStringArray = []
var undo_stack: Array[Dictionary] = []
var blocked: Dictionary = {}
var _cursor: BuildCursor
var _list: VBoxContainer
var _status: Label
var _title: Label


func setup(ow: Overworld, build_area: BuildArea) -> void:
	overworld = ow
	area = build_area
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	cursor_cell = area.world_to_cell(ow.player.global_position)
	cursor_cell = Vector2i(clampi(cursor_cell.x, 0, area.cols - 1), clampi(cursor_cell.y, 0, area.rows - 1))
	_compute_blocked()
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 110)
	panel.custom_minimum_size = Vector2(330, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_title = UiKit.label(L.t("Build mode: %s") % (L.t("Cottage") if area.id == "interior" else L.t("Homestead")), UiTheme.HEADING)
	box.add_child(_title)
	box.add_child(UiKit.label("Arrows/WASD or mouse: move\nE/Enter/click: place   R: rotate\nX/right click: store back (full refund)\nZ: undo   Q/C: change item   Esc/B: done", UiTheme.SUBTLE, true))
	_list = VBoxContainer.new()
	box.add_child(_list)
	_status = UiKit.label("", &"", true)
	box.add_child(_status)
	var done := UiKit.button("Done", close_mode, UiTheme.PRIMARY_BUTTON)
	done.focus_mode = Control.FOCUS_NONE
	box.add_child(done)
	_cursor = BuildCursor.new()
	_cursor.z_index = 30
	ow.entities.add_child(_cursor)
	_refresh_items()
	_update_cursor()


func close_mode() -> void:
	if is_instance_valid(_cursor):
		_cursor.queue_free()
	closed.emit()
	queue_free()


## Cells that cannot hold decorations: terrain, trees, rocks, POIs (outdoors).
func _compute_blocked() -> void:
	blocked.clear()
	var space := overworld.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2.ONE * area.cell * 0.7
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	var exclude: Array[RID] = [overworld.player.get_rid()]
	params.exclude = exclude
	for y in area.rows:
		for x in area.cols:
			var c := Vector2i(x, y)
			params.transform = Transform2D(0.0, area.cell_center(c))
			for hit: Dictionary in space.intersect_shape(params, 4):
				var collider: Object = hit.get("collider")
				if collider is Node and not ((collider as Node).get_parent() is PlacedDecor):
					blocked[c] = true
					break
	for node in overworld.get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		var c := area.world_to_cell(it.global_position)
		if area.contains(c) and not (it is Gatherable or it is FarmPlot):
			blocked[c] = true


func _refresh_items() -> void:
	var previous := items[item_index] if item_index < items.size() else ""
	items = PackedStringArray()
	for s in GameState.inventory.slots:
		if s.is_empty():
			continue
		var id := String(s["id"])
		if DecorRules.is_decor(id) and DecorRules.allowed_in(id, area.id) and not items.has(id):
			items.append(id)
	item_index = maxi(0, items.find(previous)) if not previous.is_empty() else 0
	for c in _list.get_children():
		c.queue_free()
	if items.is_empty():
		_list.add_child(UiKit.label("No decorations for here in your bag. Craft some at the workbench!", UiTheme.SUBTLE, true))
	for i in items.size():
		var b := UiKit.button("%s%s  x%d" % ["> " if i == item_index else "", ItemDB.display_name(items[i]), GameState.inventory.count(items[i])], func() -> void: _select(i))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_list.add_child(b)


func _select(i: int) -> void:
	item_index = i
	rot = 0
	_refresh_items()
	_update_cursor()


func current_item() -> String:
	return items[item_index] if item_index < items.size() else ""


func _blocked_for_current() -> Dictionary:
	var b := blocked.duplicate()
	var item := current_item()
	if not item.is_empty() and bool(DecorRules.decor_data(item).get("solid", false)):
		b[area.world_to_cell(overworld.player.global_position)] = true
	return b


func _update_cursor() -> void:
	var item := current_item()
	var size := DecorRules.size_of(item) if not item.is_empty() else Vector2i.ONE
	var check := DecorRules.can_place(area, item, cursor_cell, rot, _blocked_for_current()) if not item.is_empty() else {"ok": false, "reason": "Nothing selected."}
	var occupied := DecorRules.occupied(area)
	_cursor.setup_view(area, cursor_cell, size, rot, item, check["ok"], occupied.has(cursor_cell))
	if occupied.has(cursor_cell):
		_status.text = "X or right click stores this back in your bag."
	elif check["ok"]:
		_status.text = L.t("Ready to place %s.") % ItemDB.display_name(item)
	else:
		_status.text = String(check["reason"])


func _move_cursor(d: Vector2i) -> void:
	cursor_cell = Vector2i(clampi(cursor_cell.x + d.x, 0, area.cols - 1), clampi(cursor_cell.y + d.y, 0, area.rows - 1))
	_update_cursor()


func place_here() -> bool:
	var item := current_item()
	if item.is_empty():
		return false
	var p := DecorRules.place(area, item, cursor_cell, rot, _blocked_for_current())
	if p.is_empty():
		AudioManager.play(&"soft_deny")
		_update_cursor()
		return false
	undo_stack.append({"action": "place", "p": p})
	AudioManager.play(&"bloom", 1.2)
	overworld.lumi.react()
	overworld.homestead.refresh_decor(area.id)
	_refresh_items()
	_update_cursor()
	return true


func store_here() -> bool:
	var p := DecorRules.store(area, cursor_cell)
	if p.is_empty():
		_status.text = DecorRules.last_refusal if not DecorRules.last_refusal.is_empty() else "Nothing to store here."
		return false
	undo_stack.append({"action": "store", "p": p})
	AudioManager.play(&"ui_click")
	overworld.homestead.refresh_decor(area.id)
	_refresh_items()
	_update_cursor()
	return true


func undo() -> void:
	if undo_stack.is_empty():
		_status.text = "Nothing to undo."
		return
	var last: Dictionary = undo_stack.pop_back()
	var p: Dictionary = last["p"]
	if last["action"] == "place":
		DecorRules.store(area, Vector2i(int(p["x"]), int(p["y"])))
	else:
		DecorRules.restore(area, p)
	overworld.homestead.refresh_decor(area.id)
	_refresh_items()
	_update_cursor()


func _unhandled_input(event: InputEvent) -> void:
	var handled := true
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputSetup.BUILD):
		close_mode()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(InputSetup.MOVE_LEFT):
		_move_cursor(Vector2i.LEFT)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(InputSetup.MOVE_RIGHT):
		_move_cursor(Vector2i.RIGHT)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(InputSetup.MOVE_UP):
		_move_cursor(Vector2i.UP)
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(InputSetup.MOVE_DOWN):
		_move_cursor(Vector2i.DOWN)
	elif event.is_action_pressed(InputSetup.INTERACT) or event.is_action_pressed(&"ui_accept"):
		place_here()
	elif event.is_action_pressed(InputSetup.ROTATE):
		rot = (rot + 1) % 2
		_update_cursor()
	elif event.is_action_pressed(InputSetup.STORE):
		store_here()
	elif event.is_action_pressed(InputSetup.UNDO):
		undo()
	elif event.is_action_pressed(InputSetup.HOTBAR_PREV) or event.is_action_pressed(InputSetup.HOTBAR_NEXT):
		if not items.is_empty():
			_select(posmod(item_index + (1 if event.is_action_pressed(InputSetup.HOTBAR_NEXT) else -1), items.size()))
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).physical_keycode in [KEY_PREV, KEY_NEXT]:
		if not items.is_empty():
			var step := -1 if (event as InputEventKey).physical_keycode == KEY_PREV else 1
			_select(posmod(item_index + step, items.size()))
	elif event is InputEventMouseMotion:
		var c := area.world_to_cell(overworld.get_global_mouse_position())
		if area.contains(c) and c != cursor_cell:
			cursor_cell = c
			_update_cursor()
		handled = false
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			place_here()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			store_here()
		else:
			handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Grid cursor drawn in the world while build mode is open.
class BuildCursor extends Node2D:
	var area: BuildArea
	var cell: Vector2i
	var size: Vector2i = Vector2i.ONE
	var rot: int = 0
	var item: String = ""
	var valid: bool = false
	var over_existing: bool = false

	func setup_view(a: BuildArea, c: Vector2i, s: Vector2i, r: int, i: String, ok: bool, existing: bool) -> void:
		area = a
		cell = c
		size = s
		rot = r
		item = i
		valid = ok
		over_existing = existing
		queue_redraw()

	func _draw() -> void:
		if area == null:
			return
		var grid := area.rect()
		for x in area.cols + 1:
			draw_line(grid.position + Vector2(x * area.cell, 0), grid.position + Vector2(x * area.cell, grid.size.y), Palette.with_alpha(Palette.IVORY, 0.25), 1.0)
		for y in area.rows + 1:
			draw_line(grid.position + Vector2(0, y * area.cell), grid.position + Vector2(grid.size.x, y * area.cell), Palette.with_alpha(Palette.IVORY, 0.25), 1.0)
		var r := area.footprint_rect(cell, size, rot)
		var color := Palette.MINT if valid else Color("#e9867a")
		if over_existing:
			color = Palette.GOLD
		draw_rect(r, Palette.with_alpha(color, 0.3))
		draw_rect(r, color, false, 3.0)
		if not item.is_empty():
			ItemArt.draw(self, r.get_center(), minf(r.size.x, r.size.y) * 0.8, item)
		# Shape cue in addition to color: a check or a cross in the corner.
		var corner := r.position + Vector2(10, 10)
		if valid:
			draw_line(corner + Vector2(-4, 0), corner + Vector2(0, 4), Palette.INK, 2.5)
			draw_line(corner + Vector2(0, 4), corner + Vector2(7, -5), Palette.INK, 2.5)
		elif not over_existing:
			draw_line(corner + Vector2(-5, -5), corner + Vector2(5, 5), Palette.INK, 2.5)
			draw_line(corner + Vector2(5, -5), corner + Vector2(-5, 5), Palette.INK, 2.5)
