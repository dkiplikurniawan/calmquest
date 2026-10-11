extends "res://tests/test_case.gd"
## Tests for QuestBook (data-driven quests) and BeamPuzzle (Crystal Creek).


class FakeFacts extends RefCounted:
	var flags := {}
	var counters := {}
	var regions := {}
	var waystones := {}

	func has_flag(k: String) -> bool:
		return flags.has(k)

	func counter(k: String) -> int:
		return int(counters.get(k, 0))

	func region_visited(r: String) -> bool:
		return regions.has(r)

	func waystone_restored(w: String) -> bool:
		return waystones.has(w)


func _act1() -> QuestBook:
	var book := QuestBook.new()
	book.load_directory("res://game/data/quests")
	return book


func _act1_ids(book: QuestBook) -> Array:
	var ids := []
	for q in book.quests:
		if int(q.get("act", 0)) == 1:
			ids.append(String(q["id"]))
	return ids


func test_act1_data_loads() -> void:
	var book := _act1()
	assert_eq(book.load_errors.size(), 0, "no load errors: %s" % ", ".join(book.load_errors))
	# The quest folder also holds side quests (added in M3); Act 1 has four.
	assert_eq(_act1_ids(book).size(), 4)


func test_prerequisites_unlock_in_order() -> void:
	var book := _act1()
	var f := FakeFacts.new()
	book.evaluate(f)
	assert_true(book.is_active("act1_lost_lights"))
	assert_false(book.is_active("act1_firefly_grove"), "second quest waits for the first")
	f.counters["lights_collected"] = 8
	book.evaluate(f)
	assert_eq(int(book.step["act1_lost_lights"]), 1, "first step done at 8 lights")
	f.flags["heart_tree_restored"] = true
	book.evaluate(f)
	assert_true(book.is_completed("act1_lost_lights"))
	assert_true(book.is_active("act1_firefly_grove"))


func test_things_done_early_still_count() -> void:
	var book := _act1()
	var f := FakeFacts.new()
	# The player explores and solves things before the quests ask for them.
	f.regions["firefly_grove"] = true
	f.waystones["ws_grove"] = true
	f.counters["lantern_nights"] = 1
	f.regions["crystal_creek"] = true
	f.flags["creek_awakened"] = true
	f.flags["heart_tree_restored"] = true
	book.evaluate(f)
	assert_true(book.is_completed("act1_lost_lights"))
	assert_true(book.is_completed("act1_firefly_grove"), "early grove progress counted")
	assert_true(book.is_completed("act1_crystal_creek"), "early puzzle counted")
	assert_true(book.is_active("act1_heart_of_lumeria"))


func test_progress_never_goes_backwards() -> void:
	var book := _act1()
	var f := FakeFacts.new()
	f.flags["heart_tree_restored"] = true
	book.evaluate(f)
	assert_true(book.is_completed("act1_lost_lights"))
	f.flags.clear()
	book.evaluate(f)
	assert_true(book.is_completed("act1_lost_lights"), "completed stays completed")
	var saved := book.to_state()
	var reloaded := _act1()
	reloaded.load_state(saved)
	reloaded.evaluate(FakeFacts.new())
	assert_true(reloaded.is_completed("act1_lost_lights"), "state survives a reload")


func test_full_act1_chain_is_completable() -> void:
	var book := _act1()
	var f := FakeFacts.new()
	for fact in [["c", "lights_collected", 8], ["f", "heart_tree_restored"], ["r", "firefly_grove"], ["w", "ws_grove"],
			["c", "lantern_nights", 1], ["r", "crystal_creek"], ["f", "creek_awakened"], ["r", "moonlit_sanctuary"], ["f", "heart_of_lumeria_restored"]]:
		match fact[0]:
			"c": f.counters[fact[1]] = fact[2]
			"f": f.flags[fact[1]] = true
			"r": f.regions[fact[1]] = true
			"w": f.waystones[fact[1]] = true
		book.evaluate(f)
	for id in _act1_ids(book):
		assert_true(book.is_completed(id), "%s completed" % id)


func test_step_text_shows_progress() -> void:
	var book := _act1()
	var f := FakeFacts.new()
	f.counters["lights_collected"] = 3
	book.evaluate(f)
	assert_eq(book.step_text("act1_lost_lights", f), "Gather light for the Heart Tree (3/8)")


func test_every_step_target_exists_in_world_or_meadow() -> void:
	var world := WorldData.load_from()
	var meadow_targets := ["heart_tree"]
	for q in _act1().quests:
		for s: Dictionary in q["steps"]:
			var target := String(s.get("target", ""))
			if target.is_empty():
				continue
			assert_true(meadow_targets.has(target) or not world.poi(target).is_empty(), "target %s exists" % target)


# --- Beam puzzle -------------------------------------------------------------------

func test_beam_puzzle_starts_unsolved_and_is_solvable() -> void:
	var p := BeamPuzzle.creek_default()
	assert_false(p.is_solved(), "starts unsolved")
	assert_true(p.solutions().size() > 0, "has at least one solution")
	assert_false(p.is_solved(), "searching solutions does not change the puzzle")


func test_beam_puzzle_solution_path() -> void:
	var p := BeamPuzzle.creek_default()
	for cell in [Vector2i(1, 0), Vector2i(1, 2), Vector2i(3, 2)]:
		assert_true(p.toggle(cell))
	assert_true(p.is_solved(), "turning the three crystals on the path solves it")
	assert_eq(p.trace()[p.trace().size() - 1], p.target)


func test_beam_puzzle_reset_and_hints() -> void:
	var p := BeamPuzzle.creek_default()
	assert_eq(p.next_hint_cell(), Vector2i(1, 0), "hint points at the first wrong crystal on the beam")
	p.toggle(Vector2i(1, 0))
	assert_eq(p.next_hint_cell(), Vector2i(1, 2), "then the next one")
	assert_false(p.toggle(Vector2i(0, 0)), "empty cells cannot be turned")
	p.reset()
	assert_eq(int(p.mirrors[Vector2i(1, 0)]), BeamPuzzle.SLASH, "reset restores the start")


func test_beam_puzzle_state_round_trip() -> void:
	var p := BeamPuzzle.creek_default()
	p.toggle(Vector2i(1, 0))
	var q := BeamPuzzle.creek_default()
	q.load_state(p.to_state())
	assert_true(q.mirrors == p.mirrors, "saved mirror orientations restored")
