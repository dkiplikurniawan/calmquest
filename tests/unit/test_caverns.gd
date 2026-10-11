extends "res://tests/test_case.gd"
## Tests for M8: the Echo Caverns data, room-by-room progression, and every
## puzzle (braziers, blocks, hidden bridge, tuned door, light beams).

const WORLD_SIZE := Vector2(10240, 6144)


func _fresh() -> void:
	GameState.reset_world(WORLD_SIZE)


func _cave(id: String) -> CaveLevel:
	var data := CavesController.load_data()
	for c: Dictionary in data["caves"]:
		if c["id"] == id:
			var cave := CaveLevel.new()
			(Engine.get_main_loop() as SceneTree).root.add_child(cave)
			cave.setup(c, float(data["tile"]), null)
			return cave
	return null


## Grid flood fill from the entrance over cells that are open right now.
func _reachable(cave: CaveLevel) -> Dictionary:
	var start := Vector2i(-1, -1)
	for y in cave.row_count:
		var x := cave.rows[y].find("E")
		if x >= 0:
			start = Vector2i(x, y)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			var blocked := cave.blocks != null and cave.blocks.blocks.has(n)
			if not seen.has(n) and cave.is_open_floor(n) and not blocked:
				seen[n] = true
				queue.append(n)
	return seen


func _near(seen: Dictionary, cell: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if seen.has(cell + d):
			return true
	return false


func test_cave_data_is_valid() -> void:
	var data := CavesController.load_data()
	assert_true((data.get("caves", []) as Array).size() >= 2, "at least two cave systems")
	var w := WorldData.load_from()
	for c: Dictionary in data["caves"]:
		var rows: Array = c["rows"]
		var width := String(rows[0]).length()
		var entries := 0
		for r: String in rows:
			assert_eq(r.length(), width, "%s rows have equal width" % c["id"])
			entries += r.count("E")
			for ch in r:
				assert_true(data["legend"].has(ch), "%s uses known tiles (%s)" % [c["id"], ch])
		assert_eq(entries, 1, "%s has one entrance" % c["id"])
		var found := false
		for p in w.pois_of_kind("cave"):
			if String(p.get("cave", "")) == String(c["id"]):
				found = true
		assert_true(found, "%s has an entrance in the world" % c["id"])
		for b: Dictionary in c.get("beams", []):
			var logic := CaveLevel.beam_logic(b)
			assert_false(logic.is_solved(), "%s does not start solved" % b["id"])
			assert_true(logic.solutions().size() > 0, "%s can be solved" % b["id"])
			assert_eq((b.get("hints", []) as Array).size(), 3, "%s has a three-step hint ladder" % b["id"])


func test_hollow_progresses_room_by_room() -> void:
	_fresh()
	var cave := _cave("cave_hollow")
	var seen := _reachable(cave)
	assert_true(_near(seen, Vector2i(2, 2)), "the brazier room is reachable from the entrance")
	assert_false(_near(seen, Vector2i(15, 3)), "the block room waits behind the first door")
	for order in [1, 2, 3, 4]:
		for b in cave.braziers.braziers:
			if b.order == order:
				cave.braziers.light(b)
	assert_true(cave.braziers.is_solved, "lit in order, the braziers solve the first room")
	seen = _reachable(cave)
	assert_true(_near(seen, Vector2i(15, 3)), "the first door opens")
	assert_false(_near(seen, Vector2i(20, 10)), "the chasm waits behind the gate")
	var west := cave.to_global(cave.cell_center(Vector2i(14, 3)))
	for i in 3:
		assert_true(cave.blocks.push(0, cave.to_global(cave.cell_center(cave.blocks.blocks[0] + Vector2i(-1, 0)))), "push east %d" % i)
	assert_eq(cave.blocks.blocks[0], Vector2i(18, 3), "the upper block is on its plate")
	assert_true(west.x > 0.0)
	for i in 6:
		cave.blocks.push(1, cave.to_global(cave.cell_center(cave.blocks.blocks[1] + Vector2i(1, 0))))
	assert_true(cave.blocks.is_solved, "both plates pressed")
	seen = _reachable(cave)
	assert_true(_near(seen, Vector2i(20, 10)), "the gate opens to the chasm")
	assert_false(_near(seen, Vector2i(5, 9)), "the chest waits across the chasm")
	GameState.give_item("bright_lantern", 1)
	cave._on_pedestal()
	assert_true(cave.bridge_revealed(), "the Bright Lantern reveals the bridge")
	seen = _reachable(cave)
	assert_true(_near(seen, Vector2i(5, 9)) and _near(seen, Vector2i(5, 11)), "the chest and the crystal note can be reached")
	cave._on_chest()
	assert_true(GameState.inventory.count("crystal_shard") >= 4, "the chest gives crystal shards for the tuner")
	assert_true((cave.doors["3"] as CaveParts.CaveDoor).is_open, "the shortcut back opens")
	cave.queue_free()


func test_brazier_order_mistakes_are_gentle() -> void:
	_fresh()
	var cave := _cave("cave_hollow")
	var by_order := {}
	for b in cave.braziers.braziers:
		by_order[b.order] = b
	cave.braziers.light(by_order[1])
	cave.braziers.light(by_order[3])
	assert_eq(cave.braziers.lit_count(), 0, "a wrong brazier just puts the flames out")
	assert_true(cave.braziers.last_message.contains("order"), "and explains why")
	cave.braziers.light(by_order[1])
	cave.braziers.light(by_order[2])
	cave.braziers.reset_puzzle()
	assert_eq(cave.braziers.lit_count(), 0, "the lever starts over")
	var h1 := cave.braziers.next_hint(false)
	var h2 := cave.braziers.next_hint(false)
	var h3 := cave.braziers.next_hint(true)
	assert_true(h1 != h2 and h2 != h3, "the hint ladder gets clearer")
	assert_true((by_order[1] as CaveParts.Brazier).hinted, "Gentle hints highlight the next brazier")
	cave.queue_free()


func test_blocks_never_get_lost_and_reset() -> void:
	_fresh()
	var cave := _cave("cave_hollow")
	var b := cave.blocks
	var start := b.blocks[1]
	var from_west := func() -> Vector2: return cave.to_global(cave.cell_center(b.blocks[1] + Vector2i(-1, 0)))
	assert_true(b.push(1, from_west.call()), "a push moves the block")
	assert_eq(b.blocks[1], start + Vector2i(1, 0), "one cell away from you")
	assert_true(b.push(1, from_west.call()))
	assert_eq(b.blocks[1], Vector2i(22, 5), "against the east wall")
	assert_false(b.push(1, from_west.call()), "pushing into a wall does nothing")
	assert_eq(b.blocks[1], Vector2i(22, 5), "the block stays put")
	var saved := GameState.puzzle_state("hollow_blocks")
	assert_eq(int((saved["blocks"] as Array)[1][0]), 22, "block positions are saved")
	b.reset_puzzle()
	assert_eq(b.blocks[1], start, "the lever slides them back")
	cave.queue_free()


func test_grotto_needs_the_tuner_and_beams() -> void:
	_fresh()
	var cave := _cave("cave_grotto")
	var seen := _reachable(cave)
	assert_false(_near(seen, Vector2i(5, 7)), "the crystal door blocks the grotto")
	var door: CaveParts.CaveDoor = cave.doors["T"]
	cave._on_door(door)
	assert_false(door.is_open, "without a tuner it stays closed")
	GameState.give_item("crystal_tuner", 1)
	cave._on_door(door)
	assert_true(door.is_open and GameState.has_flag(cave.door_flag("T")), "the tuner opens it, and it stays open")
	assert_false(cave.hearth.ready_to_take(), "the Hearthstone waits for the light")
	for bp in cave.beams:
		var goal: Dictionary = bp.logic.solutions()[0]
		for cell: Vector2i in goal:
			if int(bp.logic.mirrors[cell]) != int(goal[cell]):
				bp.turn_mirror(cell)
		assert_true(bp.is_solved, "%s solved" % bp.puzzle_id)
	cave.refresh_doors(true)
	seen = _reachable(cave)
	assert_true(_near(seen, Vector2i(23, 7)), "the second room opens after the first beam")
	assert_true(cave.hearth.ready_to_take(), "the Hearthstone is ready")
	cave.queue_free()


func test_tuner_recipe_comes_from_the_hollow() -> void:
	var book := CraftingBook.new()
	book.load_directory()
	assert_true(book.recipes_for_discovery("note:note_crystal").has("crystal_tuner"), "the note in the Hollow teaches the Crystal Tuner")
	var note := LoreNote.note_data("note_crystal")
	assert_false(note.is_empty(), "the note exists")
