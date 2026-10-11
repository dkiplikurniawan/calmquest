class_name CaveParts
extends RefCounted
## The pieces of a cave (see CaveLevel): doors, the brazier and block puzzles,
## the lantern pedestal that reveals a hidden bridge, the Hearthstone pedestal,
## chests and the way out. Every puzzle has clear feedback, a reset lever and a
## three-step hint ladder. Nothing here can be failed or lost.


## A door made of stone or crystal. Puzzle doors open by themselves when their
## puzzle is solved; a crystal door is opened with the Crystal Tuner.
class CaveDoor extends Interactable:
	var cave: CaveLevel
	var key: String = ""
	var info: Dictionary = {}
	var is_open: bool = false
	var _body: StaticBody2D
	var _open_t: float = 0.0

	func setup(c: CaveLevel, door_key: String, door_info: Dictionary, local_pos: Vector2) -> void:
		cave = c
		key = door_key
		info = door_info
		interactable_id = "%s_door_%s" % [c.cave_id, door_key]
		position = local_pos
		reach_bonus = 24.0
		_body = StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(c.tile, c.tile)
		col.shape = shape
		_body.add_child(col)
		add_child(_body)

	func is_tuned() -> bool:
		return bool(info.get("tuned", false))

	func set_open(open: bool, instant: bool = false) -> void:
		if open == is_open:
			return
		is_open = open
		for c in _body.get_children():
			(c as CollisionShape2D).set_deferred("disabled", open)
		if instant:
			_open_t = 1.0 if open else 0.0
		else:
			create_tween().tween_property(self, "_open_t", 1.0 if open else 0.0, 0.9 * maxf(GameSettings.motion_scale(), 0.4))
		queue_redraw()

	func can_interact() -> bool:
		return not is_open and super.can_interact()

	func get_prompt() -> String:
		if is_tuned():
			return "Tune the crystal door" if GameState.inventory.count("crystal_tuner") > 0 else "Look at the crystal door"
		return "Look at the door"

	func get_interaction_point() -> Vector2:
		return global_position + Vector2(0, cave.tile * 0.5)

	func _process(delta: float) -> void:
		super(delta)
		if ViewCull.near(global_position) and (is_targeted or (_open_t > 0.0 and _open_t < 1.0) or is_tuned()):
			queue_redraw()

	func _draw() -> void:
		var half := cave.tile * 0.5
		var k := _open_t
		if is_tuned():
			var glow := 0.5 + 0.3 * sin(_ring_time * 2.0)
			var col := Palette.SKY.lerp(Palette.IVORY, k)
			for i in 3:
				var w := half * (0.9 - i * 0.25)
				var pts := PackedVector2Array([Vector2(-w, half), Vector2(w, half), Vector2(w * 0.7, -half - 10.0 + i * 8.0), Vector2(0, -half - 24.0 + i * 8.0), Vector2(-w * 0.7, -half - 10.0 + i * 8.0)])
				draw_colored_polygon(pts, Palette.with_alpha(col, (0.75 - i * 0.15) * (1.0 - k)))
			draw_circle(Vector2(0, -6), 10.0, Palette.with_alpha(Palette.IVORY, glow * (1.0 - k)))
		else:
			var drop := k * cave.tile * 0.9
			draw_rect(Rect2(-half, -half - 12.0 + drop, cave.tile, cave.tile + 12.0 - drop), Color("#6a6580"))
			draw_rect(Rect2(-half + 6, -half - 6.0 + drop, cave.tile - 12, maxf(0.0, cave.tile - drop)), Color("#7d7894"))
			if k < 0.5:
				draw_circle(Vector2(0, -6 + drop), 9.0, Palette.with_alpha(Palette.LAVENDER, 0.8))
		if not is_open:
			draw_interaction_cues(half * 0.8, Vector2(0, half * 0.4))


## One brazier of the brazier puzzle. The dots on its stone show its order.
class Brazier extends Interactable:
	var puzzle: BrazierPuzzle
	var order: int = 1
	var lit: bool = false
	var hinted: bool = false
	var _light: PointLight2D

	func _ready() -> void:
		reach_bonus = 16.0
		var body := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 18.0
		col.shape = shape
		col.position = Vector2(0, -6)
		body.add_child(col)
		add_child(body)
		_light = GlowTexture.make_light(Palette.GOLD_SOFT, 1.6, 0.9)
		_light.position = Vector2(0, -40)
		add_child(_light)
		_sync()

	func _sync() -> void:
		_light.enabled = lit
		queue_redraw()

	func set_lit(on: bool) -> void:
		lit = on
		_sync()

	func can_interact() -> bool:
		return not lit and not puzzle.is_solved and super.can_interact()

	func get_prompt() -> String:
		return L.t("Light the brazier (1 dot)") if order == 1 else L.t("Light the brazier (%d dots)") % order

	func interact() -> void:
		if can_interact():
			puzzle.light(self)
			interacted.emit(self)

	func _process(delta: float) -> void:
		super(delta)
		if ViewCull.near(global_position) and (lit or hinted or is_targeted):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 22.0)
		draw_rect(Rect2(-10, -26, 20, 26), Color("#6a6580"))
		draw_colored_polygon(PackedVector2Array([Vector2(-22, -30), Vector2(22, -30), Vector2(14, -18), Vector2(-14, -18)]), Color("#8a84a3"))
		for i in order:
			draw_circle(Vector2(-6.0 * (order - 1) / 2.0 + i * 6.0, -10), 2.2, Palette.GOLD_SOFT)
		if lit:
			var f := 1.0 + 0.15 * sin(_ring_time * 9.0)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -30), Vector2(12, -30), Vector2(0, -30 - 26.0 * f)]), Palette.GOLD_DEEP)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -30), Vector2(6, -30), Vector2(0, -30 - 16.0 * f)]), Palette.GOLD_SOFT)
		if hinted:
			draw_arc(Vector2(0, -24), 30.0 + sin(_ring_time * 4.0) * 3.0, 0.0, TAU, 28, Palette.with_alpha(Palette.IVORY, 0.9), 2.0)
		draw_interaction_cues(24.0, Vector2(0, -20))


## Light the braziers in the order of their dots. A wrong one gently puts the
## flames out again (nothing else happens).
class BrazierPuzzle extends Node2D:
	signal solved(puzzle_id: String)
	var puzzle_id: String = ""
	var hints: Array = []
	var braziers: Array[Brazier] = []
	var is_solved: bool = false
	var hint_level: int = 0
	var lever: ResetLever
	var last_message: String = ""
	var moves: int = 0

	func setup(cave: CaveLevel, info: Dictionary) -> void:
		puzzle_id = String(info["id"])
		hints = info.get("hints", [])
		var saved := GameState.puzzle_state(puzzle_id)
		is_solved = bool(saved.get("solved", false))
		var lit: Array = saved.get("lit", [])
		for c: Array in info["cells"]:
			var b := Brazier.new()
			b.puzzle = self
			b.order = int(c[2])
			b.interactable_id = "%s_%d" % [puzzle_id, b.order]
			b.position = cave.cell_center(Vector2i(int(c[0]), int(c[1]))) + Vector2(0, 16)
			b.lit = is_solved or lit.has(b.order)
			add_child(b)
			braziers.append(b)
		var l: Array = info.get("lever", [1, 1])
		lever = ResetLever.new()
		lever.puzzle = self
		lever.prompt = "Put out the braziers and start over"
		lever.interactable_id = puzzle_id + "_lever"
		lever.position = cave.cell_center(Vector2i(int(l[0]), int(l[1]))) + Vector2(0, 16)
		add_child(lever)

	func lit_count() -> int:
		var n := 0
		for b in braziers:
			if b.lit:
				n += 1
		return n

	func light(b: Brazier) -> void:
		if is_solved or b.lit:
			return
		for other in braziers:
			other.hinted = false
		if b.order != lit_count() + 1:
			for other in braziers:
				other.set_lit(false)
			last_message = "The flames flicker out. They want to be lit in the order of their dots."
			moves += 1
			AudioManager.play(&"soft_deny")
			_save()
			return
		b.set_lit(true)
		AudioManager.play(&"lantern", 0.8 + 0.1 * b.order)
		last_message = ""
		moves += 1
		if lit_count() == braziers.size():
			is_solved = true
			_save()
			PuzzleBonus.report(puzzle_id, moves, braziers.size())
			solved.emit(puzzle_id)
		else:
			_save()

	func reset_puzzle() -> void:
		if is_solved:
			return
		for b in braziers:
			b.set_lit(false)
			b.hinted = false
		hint_level = 0
		_save()

	func next_hint(gentle: bool) -> String:
		if is_solved:
			return "All four braziers are burning warmly."
		var text: String = L.t(hints[mini(hint_level, hints.size() - 1)]) if not hints.is_empty() else ""
		if hint_level >= hints.size() - 1 and gentle:
			for b in braziers:
				b.hinted = b.order == lit_count() + 1
			text += L.t(" The next one to light is shimmering.")
		hint_level = mini(hint_level + 1, maxi(0, hints.size() - 1))
		return text

	func _save() -> void:
		var lit := []
		for b in braziers:
			if b.lit:
				lit.append(b.order)
		GameState.set_puzzle_state(puzzle_id, {"lit": lit, "solved": is_solved})


## A stone block that slides one cell when pushed (E, away from the player).
class PushBlock extends Interactable:
	var puzzle: BlockPuzzle
	var index: int = 0
	var _body: StaticBody2D

	func _ready() -> void:
		reach_bonus = 26.0
		_body = StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(puzzle.cave.tile, puzzle.cave.tile) * 0.86
		col.shape = shape
		col.position = Vector2(0, -puzzle.cave.tile * 0.5)
		_body.add_child(col)
		add_child(_body)

	func can_interact() -> bool:
		return not puzzle.is_solved and super.can_interact()

	func get_prompt() -> String:
		return "Push the stone block"

	func get_interaction_point() -> Vector2:
		return global_position + Vector2(0, -puzzle.cave.tile * 0.5)

	func interact() -> void:
		if can_interact():
			puzzle.push(index, puzzle.cave.player_position())
			interacted.emit(self)

	func _draw() -> void:
		var t := puzzle.cave.tile
		var r := Rect2(Vector2(-t * 0.43, -t * 0.93), Vector2(t * 0.86, t * 0.86))
		draw_rect(r, Color("#8a84a3"))
		draw_rect(r.grow(-6), Color("#9c97b4"))
		draw_line(r.position + Vector2(10, 12), r.position + Vector2(r.size.x - 10, 12), Palette.with_alpha(Palette.IVORY, 0.4), 2.0)
		var on_plate := puzzle.plates.has(puzzle.blocks[index])
		if on_plate:
			draw_rect(r.grow(2), Palette.GOLD, false, 3.0)
		draw_interaction_cues(t * 0.45, Vector2(0, -t * 0.5))


## Push the blocks onto the pressure plates to open the gate.
class BlockPuzzle extends Node2D:
	signal solved(puzzle_id: String)
	var cave: CaveLevel
	var puzzle_id: String = ""
	var hints: Array = []
	var start: Array[Vector2i] = []
	var blocks: Array[Vector2i] = []
	var plates: Array[Vector2i] = []
	var nodes: Array[PushBlock] = []
	var is_solved: bool = false
	var hint_level: int = 0
	var lever: ResetLever
	var _plates_node: Node2D

	func setup(c: CaveLevel, info: Dictionary) -> void:
		cave = c
		puzzle_id = String(info["id"])
		hints = info.get("hints", [])
		var plate_layer := Node2D.new()
		plate_layer.z_index = -5
		plate_layer.draw.connect(func() -> void: _draw_plates(plate_layer))
		add_child(plate_layer)
		_plates_node = plate_layer
		for b: Array in info["blocks"]:
			start.append(Vector2i(int(b[0]), int(b[1])))
		for p: Array in info["plates"]:
			plates.append(Vector2i(int(p[0]), int(p[1])))
		var saved := GameState.puzzle_state(puzzle_id)
		is_solved = bool(saved.get("solved", false))
		var pos: Array = saved.get("blocks", [])
		blocks = start.duplicate()
		if pos.size() == start.size():
			for i in pos.size():
				blocks[i] = Vector2i(int(pos[i][0]), int(pos[i][1]))
		for i in blocks.size():
			var n := PushBlock.new()
			n.puzzle = self
			n.index = i
			n.interactable_id = "%s_block_%d" % [puzzle_id, i]
			add_child(n)
			nodes.append(n)
		var l: Array = info.get("lever", [1, 1])
		lever = ResetLever.new()
		lever.puzzle = self
		lever.prompt = "Slide the blocks back to the start"
		lever.interactable_id = puzzle_id + "_lever"
		lever.position = cave.cell_center(Vector2i(int(l[0]), int(l[1]))) + Vector2(0, 16)
		add_child(lever)
		_place_nodes()

	func _place_nodes() -> void:
		for i in nodes.size():
			nodes[i].position = cave.cell_center(blocks[i]) + Vector2(0, cave.tile * 0.5)
			nodes[i].queue_redraw()
		_plates_node.queue_redraw()

	## Pushes block `i` one cell away from `from` (a world position).
	func push(i: int, from: Vector2) -> bool:
		if is_solved:
			return false
		var center := cave.to_global(cave.cell_center(blocks[i]))
		var d := center - from
		var dir := Vector2i(signi(int(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, signi(int(d.y)))
		if dir == Vector2i.ZERO:
			return false
		var target := blocks[i] + dir
		if not cave.is_open_floor(target) or blocks.has(target):
			AudioManager.play(&"soft_deny")
			return false
		blocks[i] = target
		AudioManager.play(&"ui_click", 0.7)
		_place_nodes()
		var all_on := true
		for p in plates:
			if not blocks.has(p):
				all_on = false
		if all_on:
			is_solved = true
			AudioManager.play(&"restore")
		_save()
		if is_solved:
			solved.emit(puzzle_id)
		return true

	func reset_puzzle() -> void:
		if is_solved:
			return
		blocks = start.duplicate()
		hint_level = 0
		_place_nodes()
		_save()

	func next_hint(_gentle: bool) -> String:
		if is_solved:
			return "Both plates are pressed. The gate is open."
		var text: String = L.t(hints[mini(hint_level, hints.size() - 1)]) if not hints.is_empty() else ""
		hint_level = mini(hint_level + 1, maxi(0, hints.size() - 1))
		return text

	func _save() -> void:
		var pos := []
		for b in blocks:
			pos.append([b.x, b.y])
		GameState.set_puzzle_state(puzzle_id, {"blocks": pos, "solved": is_solved})

	func _draw_plates(ci: Node2D) -> void:
		for p in plates:
			var r := Rect2(cave.cell_center(p) - Vector2(cave.tile, cave.tile) * 0.4, Vector2(cave.tile, cave.tile) * 0.8)
			var pressed := blocks.has(p)
			ci.draw_rect(r, Palette.GOLD if pressed else Color("#5d5874"))
			ci.draw_rect(r, Palette.with_alpha(Palette.GOLD_SOFT, 0.9), false, 3.0)
			ci.draw_circle(r.get_center(), 6.0, Palette.IVORY if pressed else Palette.with_alpha(Palette.IVORY, 0.4))


## A pedestal that holds a lantern; a Bright Lantern reveals the hidden bridge.
class LanternPedestal extends Interactable:
	var cave: CaveLevel
	var puzzle_id: String = ""
	var hints: Array = []
	var hint_level: int = 0

	func is_solved() -> bool:
		return bool(GameState.puzzle_state(puzzle_id).get("solved", false))

	func _ready() -> void:
		reach_bonus = 18.0

	func can_interact() -> bool:
		return not is_solved() and super.can_interact()

	func get_prompt() -> String:
		return "Shine your Bright Lantern from the pedestal" if GameState.inventory.count("bright_lantern") > 0 else "Look at the lantern pedestal"

	func next_hint(_gentle: bool) -> String:
		if is_solved():
			return "The light bridge is shining. It will stay."
		var text: String = L.t(hints[mini(hint_level, hints.size() - 1)]) if not hints.is_empty() else ""
		hint_level = mini(hint_level + 1, maxi(0, hints.size() - 1))
		return text

	func _process(delta: float) -> void:
		super(delta)
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 18.0)
		draw_rect(Rect2(-12, -34, 24, 34), Color("#8a84a3"))
		draw_rect(Rect2(-18, -40, 36, 8), Color("#9c97b4"))
		if is_solved():
			draw_circle(Vector2(0, -52), 14.0 + sin(_ring_time * 2.0) * 2.0, Palette.with_alpha(Palette.SKY, 0.5))
			draw_circle(Vector2(0, -52), 6.0, Palette.IVORY)
		draw_interaction_cues(22.0, Vector2(0, -24))


## Where a Hearthstone rests once the cave's last puzzle is solved.
class HearthPedestal extends Interactable:
	var cave: CaveLevel
	var info: Dictionary = {}

	func _ready() -> void:
		reach_bonus = 20.0

	func ready_to_take() -> bool:
		return cave.condition_met(String(info.get("needs", ""))) and not GameState.has_flag("hearthstone_" + String(info.get("hearthstone", "")))

	func can_interact() -> bool:
		return super.can_interact()

	func get_prompt() -> String:
		if GameState.has_flag("hearthstone_" + String(info.get("hearthstone", ""))):
			return "An empty pedestal, warm to the touch"
		return "Take the Hearthstone" if ready_to_take() else "Look at the dark pedestal"

	func _process(delta: float) -> void:
		super(delta)
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 24.0)
		draw_rect(Rect2(-16, -36, 32, 36), Color("#8a84a3"))
		draw_rect(Rect2(-22, -44, 44, 10), Color("#a7d8f0"))
		if ready_to_take():
			var g := 0.6 + 0.3 * sin(_ring_time * 2.5)
			draw_circle(Vector2(0, -60), 24.0, Palette.with_alpha(Palette.GOLD, 0.3 * g))
			ItemArt.draw(self, Vector2(0, -60), 28.0, "hearthstone_caverns")
		draw_interaction_cues(26.0, Vector2(0, -28))


## A chest with a one-time reward (optionally waiting for a puzzle).
class CaveChest extends Interactable:
	var cave: CaveLevel
	var info: Dictionary = {}

	func _ready() -> void:
		reach_bonus = 14.0

	func flag() -> String:
		return "cave_chest:" + String(info["id"])

	func can_interact() -> bool:
		return not GameState.has_flag(flag()) and super.can_interact()

	func get_prompt() -> String:
		var needs := String(info.get("needs", ""))
		return "Open the chest" if needs.is_empty() or cave.condition_met(needs) else "A sealed chest"

	func _draw() -> void:
		var opened := GameState.has_flag(flag())
		BiomeDecorArt.shadow(self, 24.0)
		draw_rect(Rect2(-22, -26, 44, 26), Color("#7a6a8a"))
		draw_rect(Rect2(-22, -26, 44, 26), Palette.VIOLET_DARK, false, 2.0)
		if opened:
			draw_rect(Rect2(-22, -40, 44, 10), Palette.VIOLET_DARK)
		else:
			draw_rect(Rect2(-22, -34, 44, 10), Color("#8e7ca3"))
			draw_rect(Rect2(-4, -28, 8, 8), Palette.SKY)
		draw_interaction_cues(24.0, Vector2(0, -14))


## The way back out (E at the cave mouth). Leaving is always possible.
class CaveExit extends Interactable:
	var cave: CaveLevel

	func _ready() -> void:
		reach_bonus = 20.0

	func get_prompt() -> String:
		return L.t("Leave %s") % L.t(String(cave.data.get("name", "the cave")))

	func _draw() -> void:
		draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 30.0, Palette.with_alpha(Palette.GOLD_SOFT, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 4), Vector2(8, 4), Vector2(0, 18)]), Palette.with_alpha(Palette.IVORY, 0.8))
		draw_interaction_cues(24.0, Vector2(0, 6))
