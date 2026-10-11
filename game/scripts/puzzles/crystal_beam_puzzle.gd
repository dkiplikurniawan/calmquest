class_name CrystalBeamPuzzle
extends Node2D
## Crystal Creek's light-beam puzzle in the world. Turn crystals (E) so the
## sun crystal's beam reaches the heart crystal. A lever resets everything.
## Progress is stored in GameState, so it survives leaving and returning.
## Lumi offers a three-step hint ladder (vague -> clearer -> near-solution);
## in Gentle mode the near-solution step also highlights the crystal to turn.

signal solved(puzzle_id: String)
signal changed

const CELL := 84.0
const HINTS := [
	"The sun crystal's light wants to reach the heart crystal. Each standing crystal can be turned with E.",
	"Follow the beam: the first crystal it touches should send it downward, toward the heart crystal.",
	"Every crystal the beam touches should lean the same way, like this: \\  The lever resets them if you'd like a fresh start.",
]

var puzzle_id: String = "creek_puzzle"
## Hint ladder; the Echo Caverns give each of their beam puzzles its own.
var hints: Array = HINTS
var logic: BeamPuzzle = BeamPuzzle.creek_default()
var is_solved: bool = false
var hint_level: int = 0
## Turns since the start or the last reset (Playful bonus challenge).
var moves: int = 0
var highlight_cell: Vector2i = Vector2i(-99, -99)
var mirror_nodes: Dictionary = {}
var lever: PuzzleLever
var _t: float = 0.0
var _solved_glow: float = 0.0


func _ready() -> void:
	var saved := GameState.puzzle_state(puzzle_id)
	if not saved.is_empty():
		logic.load_state(saved)
		is_solved = bool(saved.get("solved", false))
		_solved_glow = 1.0 if is_solved else 0.0
	for cell: Vector2i in logic.mirrors:
		var m := CrystalMirror.new()
		m.cell = cell
		m.interactable_id = "%s_mirror_%d_%d" % [puzzle_id, cell.x, cell.y]
		m.position = cell_center(cell)
		m.puzzle = self
		add_child(m)
		mirror_nodes[cell] = m
	lever = PuzzleLever.new()
	lever.interactable_id = puzzle_id + "_lever"
	lever.position = cell_center(Vector2i(-1, logic.height - 1)) + Vector2(-20, 40)
	lever.puzzle = self
	add_child(lever)
	_sync_mirrors()


## Local position of a grid cell's center (the grid is centered on this node).
func cell_center(cell: Vector2i) -> Vector2:
	var origin := -Vector2(logic.width, logic.height) * CELL / 2.0
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func turn_mirror(cell: Vector2i) -> void:
	if is_solved or not logic.toggle(cell):
		return
	moves += 1
	highlight_cell = Vector2i(-99, -99)
	_after_change()
	if logic.is_solved():
		is_solved = true
		_save()
		var tween := create_tween()
		tween.tween_property(self, "_solved_glow", 1.0, 1.5 * maxf(GameSettings.motion_scale(), 0.5))
		PuzzleBonus.report(puzzle_id, moves, par())
		solved.emit(puzzle_id)


func reset_puzzle() -> void:
	if is_solved:
		return
	logic.reset()
	moves = 0
	hint_level = 0
	highlight_cell = Vector2i(-99, -99)
	_after_change()


## Fewest turns from the starting arrangement to a solution.
func par() -> int:
	var best := 99
	for s: Dictionary in logic.solutions():
		var n := 0
		for cell: Vector2i in s:
			if int(s[cell]) != int(logic.initial.get(cell, s[cell])):
				n += 1
		best = mini(best, n)
	return best


## Next hint text. `gentle` adds a highlight on the crystal to turn at the last step.
func next_hint(gentle: bool) -> String:
	if is_solved:
		return L.t("The creek is awake. The heart crystal is glowing!")
	var text: String = L.t(hints[mini(hint_level, hints.size() - 1)])
	if hint_level >= hints.size() - 1 and gentle:
		highlight_cell = logic.next_hint_cell()
		_sync_mirrors()
		text += L.t(" I've made the next crystal to turn shimmer for you.")
	hint_level = mini(hint_level + 1, hints.size() - 1)
	return text


func _after_change() -> void:
	_save()
	_sync_mirrors()
	changed.emit()
	queue_redraw()


func _save() -> void:
	var state := logic.to_state()
	state["solved"] = is_solved
	GameState.set_puzzle_state(puzzle_id, state)


func _sync_mirrors() -> void:
	for cell: Vector2i in mirror_nodes:
		var m: CrystalMirror = mirror_nodes[cell]
		m.orientation = int(logic.mirrors[cell])
		m.locked = is_solved
		m.hinted = cell == highlight_cell
		m.queue_redraw()


func _process(delta: float) -> void:
	_t += delta * GameSettings.motion_scale()
	queue_redraw()


func _draw() -> void:
	var size := Vector2(logic.width, logic.height) * CELL
	var origin := -size / 2.0
	# Stone platform and tiles
	draw_rect(Rect2(origin - Vector2(24, 24), size + Vector2(48, 48)), Palette.with_alpha(Palette.STONE_DARK, 0.85))
	for y in logic.height:
		for x in logic.width:
			draw_rect(Rect2(origin + Vector2(x, y) * CELL + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), Palette.with_alpha(Palette.STONE, 0.9))
	# Sun crystal (source) and heart crystal (target)
	var src := cell_center(logic.source)
	draw_circle(src, 30.0, Palette.with_alpha(Palette.GOLD, 0.3))
	draw_circle(src, 16.0, Palette.GOLD)
	var tgt := cell_center(logic.target)
	var heart_glow := 0.4 + 0.6 * _solved_glow
	draw_circle(tgt, 36.0 * (0.9 + 0.1 * sin(_t * 2.0)), Palette.with_alpha(Palette.SKY, 0.25 * heart_glow + 0.1))
	draw_colored_polygon(PackedVector2Array([tgt + Vector2(0, -26), tgt + Vector2(18, 0), tgt + Vector2(0, 26), tgt + Vector2(-18, 0)]), Palette.SKY.lerp(Palette.IVORY, _solved_glow * 0.4))
	# The beam
	var pts := PackedVector2Array([src])
	for cell in logic.trace():
		pts.append(cell_center(cell))
	var beam_color := Palette.with_alpha(Palette.GOLD_SOFT, 0.85)
	draw_polyline(pts, Palette.with_alpha(Palette.GOLD, 0.25), 14.0, true)
	draw_polyline(pts, beam_color, 5.0, true)
	if is_solved:
		draw_circle(tgt, 60.0 * _solved_glow, Palette.with_alpha(Palette.IVORY, 0.12))


## A standing crystal that reflects the beam. Turned with E.
class CrystalMirror extends Interactable:
	var cell: Vector2i
	var orientation: int = BeamPuzzle.SLASH
	var puzzle: CrystalBeamPuzzle
	var locked: bool = false
	var hinted: bool = false
	var _turn_t: float = 0.0

	func can_interact() -> bool:
		return not locked and super.can_interact()

	func get_prompt() -> String:
		return "Turn the crystal"

	func interact() -> void:
		if can_interact():
			_turn_t = 1.0
			puzzle.turn_mirror(cell)
			interacted.emit(self)

	func _process(delta: float) -> void:
		super(delta)
		_turn_t = maxf(0.0, _turn_t - delta * 4.0)
		if hinted or _turn_t > 0.0:
			queue_redraw()

	func _draw() -> void:
		var half := 24.0
		var a := Vector2(-half, half) if orientation == BeamPuzzle.SLASH else Vector2(-half, -half)
		var b := -a
		if hinted:
			draw_circle(Vector2.ZERO, 34.0 + sin(_ring_time * 4.0) * 3.0, Palette.with_alpha(Palette.GOLD, 0.35))
		draw_circle(Vector2.ZERO, 26.0, Palette.with_alpha(Palette.LAVENDER, 0.35))
		draw_line(a, b, Palette.SKY, 10.0 + _turn_t * 4.0, true)
		draw_line(a, b, Palette.IVORY, 3.0, true)
		draw_circle(a, 5.0, Palette.VIOLET)
		draw_circle(b, 5.0, Palette.VIOLET)
		draw_interaction_cues(28.0)


## Reset lever: restores the starting arrangement. Never needed, always available.
class PuzzleLever extends Interactable:
	var puzzle: CrystalBeamPuzzle
	var _pull: float = 0.0

	func can_interact() -> bool:
		return not puzzle.is_solved and super.can_interact()

	func get_prompt() -> String:
		return "Reset the crystals"

	func interact() -> void:
		if can_interact():
			_pull = 1.0
			puzzle.reset_puzzle()
			interacted.emit(self)

	func _process(delta: float) -> void:
		super(delta)
		if _pull > 0.0:
			_pull = maxf(0.0, _pull - delta * 2.0)
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-14, -8, 28, 10), Palette.STONE_DARK)
		var angle := -0.6 + _pull * 1.2
		var tip := Vector2(0, -6) + Vector2(0, -34).rotated(angle)
		draw_line(Vector2(0, -6), tip, Palette.BARK_DARK, 5.0, true)
		draw_circle(tip, 7.0, Palette.GOLD)
		draw_interaction_cues(20.0, Vector2(0, -14))
