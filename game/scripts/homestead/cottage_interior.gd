class_name CottageInterior
extends Node2D
## Inside the Traveler's Cottage (a sub-level placed outside the overworld
## map). Draws the room and walls, shows a restoration spot for every step not
## yet done and the finished station for every step that is (hearth, bed,
## workbench, cooking pot, chest, bookshelf, window), plus placed decorations.

signal spot_used(step_id: String)
signal station_used(step_id: String)
signal exit_requested

var data: Dictionary = {}
var area: BuildArea
var _t: float = 0.0
var _stations: Node2D
var _warm: float = 0.0


func setup(cottage_data: Dictionary) -> void:
	data = cottage_data
	var info: Dictionary = data["interior"]
	var o: Array = info["origin"]
	position = Vector2(float(o[0]), float(o[1]))
	y_sort_enabled = true
	area = BuildArea.make("interior", position, float(info["cell"]), int(info["cols"]), int(info["rows"]))
	for c: Array in info.get("keep_clear", []):
		area.reserve(Vector2i(int(c[0]), int(c[1])))
	for step: Dictionary in data["steps"]:
		for c: Array in step["cells"]:
			area.reserve(Vector2i(int(c[0]), int(c[1])))
	_build_walls()
	_stations = Node2D.new()
	_stations.y_sort_enabled = true
	add_child(_stations)
	var door := InteriorDoor.new()
	door.interactable_id = "cottage_door_inside"
	var d: Array = info["door"]
	door.position = cell_local_center(Vector2i(int(d[0]), int(d[1]))) + Vector2(0, 20)
	door.interacted.connect(func(_t: Interactable) -> void: exit_requested.emit())
	add_child(door)
	refresh()


func room_size() -> Vector2:
	return Vector2(area.cols, area.rows) * area.cell


func cell_local_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * area.cell


## World position just inside the door (where the player appears).
func entry_point() -> Vector2:
	var d: Array = data["interior"]["door"]
	return area.cell_center(Vector2i(int(d[0]), int(d[1]))) + Vector2(0, -24)


## Camera bounds: the room plus its walls.
func camera_rect() -> Rect2:
	return Rect2(position - Vector2(160, 220), room_size() + Vector2(320, 320))


func is_done(step_id: String) -> bool:
	return bool(GameState.system_state("cottage").get(step_id, false))


## Rebuilds stations and restoration spots from the cottage state.
func refresh() -> void:
	for c in _stations.get_children():
		c.queue_free()
	for step: Dictionary in data["steps"]:
		var id := String(step["id"])
		var cells: Array = step["cells"]
		var first := Vector2i(int(cells[0][0]), int(cells[0][1]))
		var center := Vector2.ZERO
		for c: Array in cells:
			center += cell_local_center(Vector2i(int(c[0]), int(c[1])))
		center /= cells.size()
		if is_done(id):
			var station := _make_station(id)
			if station != null:
				station.position = center + Vector2(0, area.cell * 0.35 * (1 if cells.size() > 2 else 0))
				_stations.add_child(station)
		else:
			var spot := RestoreSpot.new()
			spot.step = step
			spot.interactable_id = "cottage_spot_" + id
			spot.cells_size = Vector2(area.cell, area.cell) * Vector2(_span(cells))
			spot.position = center
			spot.interacted.connect(func(_t: Interactable) -> void: spot_used.emit(id))
			_stations.add_child(spot)
		if first == Vector2i(-1, -1):
			push_warning("CottageInterior: step %s has no cells" % id)
	_warm = 1.0 if is_done("hearth") else 0.0
	queue_redraw()


static func _span(cells: Array) -> Vector2i:
	var xs := []
	var ys := []
	for c: Array in cells:
		xs.append(int(c[0]))
		ys.append(int(c[1]))
	return Vector2i(int(xs.max()) - int(xs.min()) + 1, int(ys.max()) - int(ys.min()) + 1)


func _make_station(id: String) -> Node2D:
	match id:
		"workbench":
			var wb := Workbench.new()
			wb.interactable_id = "cottage_workbench"
			wb.tier = 2
			return wb
		"bed", "cooking_pot", "storage_chest", "bookshelf", "hearth":
			var s := Station.new()
			s.kind = id
			s.interactable_id = "cottage_" + id
			s.interacted.connect(func(_t: Interactable) -> void: station_used.emit(id))
			return s
	return null


func _build_walls() -> void:
	var body := StaticBody2D.new()
	var size := room_size()
	for r: Rect2 in [Rect2(-60, -200, size.x + 120, 200), Rect2(-60, size.y, size.x + 120, 60), Rect2(-60, 0, 60, size.y), Rect2(size.x, 0, 60, size.y)]:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		col.position = r.get_center()
		body.add_child(col)
	add_child(body)


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	queue_redraw()


func _draw() -> void:
	var size := room_size()
	var wood := Color("#c9a27e") if _warm > 0.5 else Color("#a99a8c")
	draw_rect(Rect2(Vector2(-40, -150), Vector2(size.x + 80, size.y + 190)), Color("#3b3550"))
	# Back wall
	draw_rect(Rect2(Vector2(0, -130), Vector2(size.x, 130)), Color("#e9dcc3") if _warm > 0.5 else Color("#c9c0b4"))
	draw_line(Vector2(0, -2), Vector2(size.x, -2), Palette.BARK_DARK, 4.0)
	# Floor planks
	draw_rect(Rect2(Vector2.ZERO, size), wood)
	for y in range(0, int(size.y), 32):
		draw_line(Vector2(0, y), Vector2(size.x, y), Palette.with_alpha(Palette.BARK_DARK, 0.25), 1.5)
	# Window (top wall at the window step's column)
	var window_cell := _step_cell("window")
	var wx := (window_cell.x + 0.5) * area.cell
	var repaired := is_done("window")
	draw_rect(Rect2(Vector2(wx - 34, -112), Vector2(68, 64)), Palette.BARK_DARK)
	draw_rect(Rect2(Vector2(wx - 28, -106), Vector2(56, 52)), Palette.SKY if repaired else Color("#8d96a8"))
	if repaired:
		draw_line(Vector2(wx, -106), Vector2(wx, -54), Palette.BARK_DARK, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(wx - 28, -54), Vector2(wx + 28, -54), Vector2(wx + 70, 120), Vector2(wx - 10, 120)]), Palette.with_alpha(Palette.GOLD_SOFT, 0.12))
	else:
		draw_line(Vector2(wx - 22, -100), Vector2(wx + 18, -62), Palette.INK_SOFT, 2.0)
	# Roof beams (a ladder and a hole until the roof is fixed)
	if not is_done("roof"):
		draw_rect(Rect2(Vector2(size.x * 0.35, -150), Vector2(90, 26)), Color("#22283d"))
	# Hearth on the back wall
	var hearth_cell := _step_cell("hearth")
	var hx := (hearth_cell.x + 0.5) * area.cell
	draw_rect(Rect2(Vector2(hx - 52, -120), Vector2(104, 120)), Palette.STONE_DARK)
	draw_rect(Rect2(Vector2(hx - 34, -60), Vector2(68, 58)), Color("#2a2234"))
	if is_done("hearth"):
		var f := 0.85 + 0.15 * sin(_t * 6.0)
		draw_circle(Vector2(hx, -14), 60.0 * f, Palette.with_alpha(Palette.GOLD_DEEP, 0.18))
		draw_circle(Vector2(hx, -22), 18.0 * f, Palette.GOLD_DEEP)
		draw_circle(Vector2(hx, -26), 10.0 * f, Palette.GOLD_SOFT)
	# Dust before the cottage is cared for
	if _warm < 0.5:
		for i in 14:
			var p := Vector2(fposmod(i * 97.0, size.x), fposmod(i * 53.0, size.y))
			draw_circle(p, 10.0, Palette.with_alpha(Color("#8a8476"), 0.18))


func _step_cell(id: String) -> Vector2i:
	for step: Dictionary in data["steps"]:
		if String(step["id"]) == id:
			var c: Array = step["cells"][0]
			return Vector2i(int(c[0]), int(c[1]))
	return Vector2i.ZERO


## Exit door inside the cottage.
class InteriorDoor extends Interactable:
	func get_prompt() -> String:
		return "Step outside"

	func _draw() -> void:
		draw_rect(Rect2(-30, -10, 60, 16), Palette.BARK)
		draw_rect(Rect2(-24, -6, 48, 8), Palette.with_alpha(Palette.GOLD_SOFT, 0.6))
		draw_interaction_cues(26.0, Vector2(0, -4))


## A spot waiting to be restored: a soft outline with what it needs.
class RestoreSpot extends Interactable:
	var step: Dictionary = {}
	var cells_size: Vector2 = Vector2(64, 64)
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = maxf(cells_size.x, cells_size.y) * 0.4

	func get_prompt() -> String:
		var parts := PackedStringArray()
		for i: Dictionary in step.get("inputs", []):
			parts.append("%d %s" % [int(i["qty"]), ItemDB.display_name(String(i["item"]))])
		return "%s (%s)" % [L.t(String(step.get("title", "Restore"))), ", ".join(parts)]

	func _process(delta: float) -> void:
		super(delta)
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-cells_size / 2.0, cells_size).grow(-6.0)
		var a := 0.35 + 0.15 * sin(_t * 2.0)
		draw_rect(r, Palette.with_alpha(Palette.CREAM, 0.12))
		draw_rect(r, Palette.with_alpha(Palette.GOLD_SOFT, a), false, 2.0)
		draw_circle(Vector2(0, -6), 5.0, Palette.with_alpha(Palette.GOLD, a + 0.2))
		draw_interaction_cues(maxf(cells_size.x, cells_size.y) * 0.4)


## A finished station: bed, hearth, cooking pot, chest or bookshelf.
class Station extends Interactable:
	var kind: String = "bed"

	func _ready() -> void:
		reach_bonus = 30.0
		if kind != "hearth":
			var body := StaticBody2D.new()
			var col := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(110, 60) if kind == "bed" else Vector2(48, 24)
			col.shape = shape
			col.position = Vector2(0, -12)
			body.add_child(col)
			add_child(body)

	func get_prompt() -> String:
		match kind:
			"bed":
				return "Sleep until morning (saves your journey)"
			"cooking_pot":
				return "Cook at the pot"
			"storage_chest":
				return "Open the storage chest"
			"bookshelf":
				return "Browse the bookshelf (Journal)"
			"hearth":
				return "Warm your hands by the hearth"
		return "Use"

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 40.0)
		match kind:
			"bed":
				draw_rect(Rect2(-60, -70, 120, 76), Palette.BARK)
				draw_rect(Rect2(-54, -64, 108, 60), Color("#f3ead8"))
				draw_rect(Rect2(-54, -30, 108, 26), Palette.LAVENDER)
				draw_rect(Rect2(-46, -60, 36, 20), Palette.IVORY)
			"cooking_pot":
				draw_circle(Vector2(0, -18), 22.0, Palette.INK_SOFT)
				draw_rect(Rect2(-24, -24, 48, 8), Palette.STONE_DARK)
				draw_arc(Vector2(0, -30), 18.0, PI, TAU, 12, Palette.STONE_DARK, 3.0, true)
			"storage_chest":
				draw_rect(Rect2(-28, -38, 56, 38), Palette.BARK)
				draw_rect(Rect2(-28, -38, 56, 12), Palette.BARK_DARK)
				draw_rect(Rect2(-5, -30, 10, 10), Palette.GOLD)
			"bookshelf":
				draw_rect(Rect2(-30, -96, 60, 96), Palette.BARK)
				for k in 3:
					draw_line(Vector2(-30, -66 + k * 30), Vector2(30, -66 + k * 30), Palette.BARK_DARK, 3.0)
					for b in 4:
						draw_rect(Rect2(-24 + b * 12, -88 + k * 30, 9, 20), [Palette.LAVENDER, Palette.SKY, Palette.MINT, Palette.ROOF][b])
			"hearth":
				draw_circle(Vector2(0, -6), 6.0, Palette.with_alpha(Palette.GOLD, 0.0))
		draw_interaction_cues(34.0, Vector2(0, -20))
