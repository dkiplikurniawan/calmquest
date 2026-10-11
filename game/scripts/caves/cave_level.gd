class_name CaveLevel
extends Node2D
## One handcrafted Echo Cavern, built from game/data/caves/caves.json: an ASCII
## map of walls, floor, chasms, doors and a hidden bridge, plus its puzzles.
## Caves are sub-levels placed outside the world map; the player enters through
## an entrance in the overworld and can always walk back out. All puzzle and
## door progress is saved in GameState (puzzle states and flags).

signal exit_requested(cave: CaveLevel)
signal progress(cave: CaveLevel, what: String)
signal chest_opened(cave: CaveLevel, rewards: Array)
signal hearthstone_taken(cave: CaveLevel, stone_id: String)
signal lore_requested(note_id: String)

const SOLID := ["#", "~"]

var data: Dictionary = {}
var cave_id: String = ""
var tile: float = 64.0
var rows: PackedStringArray = []
var cols: int = 0
var row_count: int = 0
var player: Node2D
var doors: Dictionary = {}
var braziers: CaveParts.BrazierPuzzle
var blocks: CaveParts.BlockPuzzle
var beams: Array[CrystalBeamPuzzle] = []
var pedestal: CaveParts.LanternPedestal
var hearth: CaveParts.HearthPedestal
var chest: CaveParts.CaveChest
var exit_node: CaveParts.CaveExit
var _floor: CaveFloor
var _bridge_body: StaticBody2D


func setup(cave_data: Dictionary, tile_size: float, p: Node2D) -> void:
	data = cave_data
	cave_id = String(data["id"])
	tile = tile_size
	player = p
	rows = PackedStringArray(data["rows"])
	row_count = rows.size()
	cols = rows[0].length()
	var o: Array = data["origin"]
	position = Vector2(float(o[0]), float(o[1]))
	y_sort_enabled = true
	_floor = CaveFloor.new()
	_floor.cave = self
	_floor.z_index = -6
	add_child(_floor)
	_build_collision()
	for y in row_count:
		for x in cols:
			var ch := rows[y][x]
			var door_info: Dictionary = data.get("doors", {}).get(ch, {})
			if not door_info.is_empty():
				var d := CaveParts.CaveDoor.new()
				d.setup(self, ch, door_info, cell_center(Vector2i(x, y)))
				d.interacted.connect(func(_t: Interactable) -> void: _on_door(d))
				add_child(d)
				doors[ch] = d
			elif ch == "E":
				exit_node = CaveParts.CaveExit.new()
				exit_node.cave = self
				exit_node.interactable_id = cave_id + "_exit"
				exit_node.position = cell_center(Vector2i(x, y)) + Vector2(0, tile * 0.3)
				exit_node.interacted.connect(func(_t: Interactable) -> void: exit_requested.emit(self))
				add_child(exit_node)
	if data.has("braziers"):
		braziers = CaveParts.BrazierPuzzle.new()
		add_child(braziers)
		braziers.setup(self, data["braziers"])
		braziers.y_sort_enabled = true
		braziers.solved.connect(_on_puzzle_solved)
	if data.has("blocks"):
		blocks = CaveParts.BlockPuzzle.new()
		add_child(blocks)
		blocks.setup(self, data["blocks"])
		blocks.y_sort_enabled = true
		blocks.solved.connect(_on_puzzle_solved)
	for b: Dictionary in data.get("beams", []):
		var bp := CrystalBeamPuzzle.new()
		bp.puzzle_id = String(b["id"])
		bp.logic = beam_logic(b)
		bp.hints = b.get("hints", CrystalBeamPuzzle.HINTS)
		var c: Array = b["center"]
		bp.position = Vector2(float(c[0]), float(c[1]))
		bp.z_index = -5
		bp.solved.connect(_on_puzzle_solved)
		bp.changed.connect(func() -> void: AudioManager.play(&"ui_click", 1.3))
		add_child(bp)
		beams.append(bp)
	if data.has("pedestal"):
		var info: Dictionary = data["pedestal"]
		pedestal = CaveParts.LanternPedestal.new()
		pedestal.cave = self
		pedestal.puzzle_id = String(info["id"])
		pedestal.hints = info.get("hints", [])
		pedestal.interactable_id = pedestal.puzzle_id
		pedestal.position = cell_center(_cell(info["cell"])) + Vector2(0, 16)
		pedestal.interacted.connect(func(_t: Interactable) -> void: _on_pedestal())
		add_child(pedestal)
	if data.has("hearth"):
		hearth = CaveParts.HearthPedestal.new()
		hearth.cave = self
		hearth.info = data["hearth"]
		hearth.interactable_id = String(hearth.info["id"])
		hearth.position = cell_center(_cell(hearth.info["cell"])) + Vector2(0, 16)
		hearth.interacted.connect(func(_t: Interactable) -> void: _on_hearth())
		add_child(hearth)
	if data.has("chest"):
		chest = CaveParts.CaveChest.new()
		chest.cave = self
		chest.info = data["chest"]
		chest.interactable_id = String(chest.info["id"])
		chest.position = cell_center(_cell(chest.info["cell"])) + Vector2(0, 16)
		chest.interacted.connect(func(_t: Interactable) -> void: _on_chest())
		add_child(chest)
	# Rest spots in this cave (0.4.0, data in game/data/rest_spots.json).
	for s: Dictionary in RestSpots.cave_spots(cave_id):
		var spot := RestSpot.new()
		spot.setup(s)
		spot.position = cell_center(_cell(s["cell"]))
		add_child(spot)
	for n: Dictionary in data.get("notes", []):
		var note := LoreNote.new()
		note.note_id = String(n["id"])
		note.interactable_id = note.note_id
		note.position = cell_center(_cell(n["cell"])) + Vector2(0, 16)
		note.interacted.connect(func(_t: Interactable) -> void: lore_requested.emit(note.note_id))
		add_child(note)
	refresh_doors(true)


static func beam_logic(b: Dictionary) -> BeamPuzzle:
	var p := BeamPuzzle.new()
	p.width = int(b["width"])
	p.height = int(b["height"])
	p.source = _cell(b["source"])
	p.source_dir = _cell(b["source_dir"])
	p.target = _cell(b["target"])
	p.initial = {}
	for m: Array in b["mirrors"]:
		p.initial[Vector2i(int(m[0]), int(m[1]))] = int(m[2])
	p.mirrors = p.initial.duplicate()
	return p


static func _cell(a: Variant) -> Vector2i:
	var arr: Array = a
	return Vector2i(int(arr[0]), int(arr[1]))


func tile_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= row_count:
		return "#"
	return rows[c.y][c.x]


func cell_center(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * tile


func local_to_cell(p: Vector2) -> Vector2i:
	return Vector2i((p / tile).floor())


func size_px() -> Vector2:
	return Vector2(cols, row_count) * tile


## World position just inside the entrance (where the player appears).
func entry_point() -> Vector2:
	for y in row_count:
		var x := rows[y].find("E")
		if x >= 0:
			return to_global(cell_center(Vector2i(x, y)) + Vector2(0, -tile * 0.6))
	return to_global(size_px() / 2.0)


func camera_rect() -> Rect2:
	return Rect2(position - Vector2(tile, tile) * 2.0, size_px() + Vector2(tile, tile) * 4.0)


func player_position() -> Vector2:
	return player.global_position if player != null else Vector2.INF


func bridge_revealed() -> bool:
	return pedestal != null and pedestal.is_solved()


## Walkable now (for pushing blocks): floor, entry, open doors, revealed bridge.
func is_open_floor(c: Vector2i) -> bool:
	var ch := tile_at(c)
	if ch == "." or ch == "E":
		return true
	if ch == "=":
		return bridge_revealed()
	if doors.has(ch):
		return (doors[ch] as CaveParts.CaveDoor).is_open
	return false


## "puzzle:<id>", "flag:<flag>", "item:<id>" or "" (always true).
func condition_met(cond: String) -> bool:
	if cond.is_empty():
		return true
	var parts := cond.split(":", true, 1)
	match parts[0]:
		"puzzle":
			return bool(GameState.puzzle_state(parts[1]).get("solved", false))
		"flag":
			return GameState.has_flag(parts[1])
		"item":
			return GameState.inventory.count(parts[1]) > 0
	return false


func door_flag(key: String) -> String:
	return "cave_door_open:%s:%s" % [cave_id, key]


## Opens every door whose condition is met (tuned doors stay open once tuned).
func refresh_doors(instant: bool = false) -> void:
	for key: String in doors:
		var d: CaveParts.CaveDoor = doors[key]
		var open := GameState.has_flag(door_flag(key))
		if not d.is_tuned() and condition_met(String(d.info.get("opens", ""))):
			open = true
		if open and not d.is_open:
			GameState.set_flag(door_flag(key))
		d.set_open(open, instant)
	if _bridge_body != null:
		for c in _bridge_body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", bridge_revealed())
	_floor.queue_redraw()


func _build_collision() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	_bridge_body = StaticBody2D.new()
	_bridge_body.name = "HiddenBridge"
	add_child(_bridge_body)
	for y in row_count:
		var run_start := -1
		var run_kind := ""
		for x in cols + 1:
			var ch := tile_at(Vector2i(x, y)) if x < cols else ""
			var kind := "solid" if ch in SOLID else ("bridge" if ch == "=" else "")
			if kind != run_kind:
				if run_start >= 0 and not run_kind.is_empty():
					_add_box(walls if run_kind == "solid" else _bridge_body, Vector2i(run_start, y), x - run_start)
				run_start = x
				run_kind = kind
	# The cave is closed all around (also beyond the map edge).
	var outer := size_px()
	for r: Rect2 in [Rect2(-tile, -tile, outer.x + tile * 2, tile), Rect2(-tile, outer.y, outer.x + tile * 2, tile), Rect2(-tile, 0, tile, outer.y), Rect2(outer.x, 0, tile, outer.y)]:
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		col.position = r.get_center()
		walls.add_child(col)


func _add_box(body: StaticBody2D, start: Vector2i, length: int) -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length * tile, tile)
	col.shape = shape
	col.position = Vector2(start.x * tile + length * tile / 2.0, start.y * tile + tile / 2.0)
	body.add_child(col)


# --- Interactions -----------------------------------------------------------------------

func _on_puzzle_solved(puzzle_id: String) -> void:
	GameState.set_flag("puzzle_solved:" + puzzle_id)
	refresh_doors()
	progress.emit(self, "puzzle:" + puzzle_id)


func _on_door(d: CaveParts.CaveDoor) -> void:
	if d.is_tuned() and GameState.inventory.count("crystal_tuner") > 0:
		GameState.set_flag(door_flag(d.key))
		d.set_open(true)
		AudioManager.play(&"restore", 1.2)
		progress.emit(self, "tuned:" + d.key)
		return
	progress.emit(self, "door_text:" + L.t(String(d.info.get("text", ""))))


func _on_pedestal() -> void:
	if pedestal.is_solved():
		return
	if GameState.inventory.count("bright_lantern") == 0:
		progress.emit(self, "door_text:" + L.t("The pedestal is shaped for a lantern, but your lantern is too dim. A Bright Lantern might reveal something."))
		return
	GameState.set_puzzle_state(pedestal.puzzle_id, {"solved": true})
	GameState.set_flag("puzzle_solved:" + pedestal.puzzle_id)
	AudioManager.play(&"restore")
	refresh_doors()
	progress.emit(self, "bridge")


func _on_hearth() -> void:
	if not hearth.ready_to_take():
		var taken := GameState.has_flag("hearthstone_" + String(hearth.info.get("hearthstone", "")))
		progress.emit(self, "door_text:" + L.t("The pedestal is still warm where the Hearthstone rested." if taken else "The pedestal is dark. The crystals around it seem to wait for a beam of light."))
		return
	hearthstone_taken.emit(self, String(hearth.info.get("hearthstone", "")))


func _on_chest() -> void:
	var needs := String(chest.info.get("needs", ""))
	if not condition_met(needs):
		progress.emit(self, "door_text:" + L.t("The chest is sealed with crystal. Solving the room's puzzle might open it."))
		return
	if GameState.has_flag(chest.flag()):
		return
	GameState.set_flag(chest.flag())
	var rewards: Array = chest.info.get("rewards", [])
	for r: Dictionary in rewards:
		var left := GameState.give_item(String(r["item"]), int(r.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(r["item"]), left)
	chest.queue_redraw()
	refresh_doors()
	chest_opened.emit(self, rewards)


## Lumi's hint for the nearest unsolved puzzle in this cave ("" if none).
func hint_near(world_pos: Vector2, gentle: bool) -> String:
	var local := to_local(world_pos)
	var best := ""
	var best_d := INF
	var candidates := []
	if braziers != null and not braziers.is_solved:
		candidates.append([braziers.braziers[0].position, braziers])
	if blocks != null and not blocks.is_solved:
		candidates.append([cell_center(blocks.plates[0]), blocks])
	for b in beams:
		if not b.is_solved:
			candidates.append([b.position, b])
	if pedestal != null and not pedestal.is_solved():
		candidates.append([pedestal.position, pedestal])
	var target: Object = null
	for c: Array in candidates:
		var dist := local.distance_to(c[0] as Vector2)
		if dist < best_d:
			best_d = dist
			target = c[1]
	if target != null and best_d < tile * 9.0:
		best = String(target.call("next_hint", gentle))
	if best.is_empty():
		for key: String in doors:
			var d: CaveParts.CaveDoor = doors[key]
			if d.is_tuned() and not d.is_open and local.distance_to(d.position) < tile * 5.0:
				return "This crystal door is waiting for the right note. A Crystal Tuner would wake it. The Song of the Crystals in Whispering Hollow explains how to make one." if GameState.inventory.count("crystal_tuner") == 0 else "Stand by the crystal door and press E to tune it."
	if best.is_empty() and hearth != null and hearth.ready_to_take():
		return "The Hearthstone is waiting on its pedestal!"
	return best


## Draws the floor, walls, chasms and the (hidden) bridge once; no per-frame cost.
class CaveFloor extends Node2D:
	var cave: CaveLevel

	func _draw() -> void:
		var t := cave.tile
		var revealed := cave.bridge_revealed()
		draw_rect(Rect2(-t * 2.0, -t * 2.0, cave.size_px().x + t * 4.0, cave.size_px().y + t * 4.0), Color("#1b1a2c"))
		for y in cave.row_count:
			for x in cave.cols:
				var ch := cave.rows[y][x]
				var r := Rect2(Vector2(x, y) * t, Vector2(t, t))
				var shade := 0.015 * float((x * 7 + y * 13) % 3)
				match ch:
					"#":
						# Dark rock; where it meets the floor, a lighter rock face gives depth.
						draw_rect(r, Color(0.17, 0.16, 0.25))
						if cave.tile_at(Vector2i(x, y + 1)) not in ["#"]:
							draw_rect(Rect2(r.position + Vector2(0, t - 18), Vector2(t, 18)), Color("#5a5578"))
							draw_line(r.position + Vector2(0, t - 18), r.position + Vector2(t, t - 18), Color("#7a7598"), 2.0)
					"~":
						draw_rect(r, Color("#0d0c18"))
						if (x + y) % 3 == 0:
							draw_circle(r.get_center() + Vector2(8, -6), 1.6, Palette.with_alpha(Palette.SKY, 0.5))
					"=":
						draw_rect(r, Color("#0d0c18"))
						if revealed:
							draw_rect(r.grow(-4), Palette.with_alpha(Palette.SKY, 0.55))
							draw_line(r.position + Vector2(4, t * 0.5), r.position + Vector2(t - 4, t * 0.5), Palette.IVORY, 2.0)
						else:
							draw_rect(r.grow(-10), Palette.with_alpha(Palette.SKY, 0.06), false, 1.0)
					_:
						draw_rect(r, Color(0.6 + shade, 0.58 + shade, 0.68 + shade))
						if (x * 3 + y * 5) % 7 == 0:
							draw_circle(r.position + Vector2(t * 0.3, t * 0.7), 3.0, Palette.with_alpha(Palette.SKY, 0.5))
						elif (x * 5 + y * 3) % 9 == 0:
							draw_circle(r.position + Vector2(t * 0.65, t * 0.35), 4.0, Color(0.5, 0.48, 0.58))
