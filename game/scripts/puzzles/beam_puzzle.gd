class_name BeamPuzzle
extends RefCounted
## Pure logic for a light-beam mirror puzzle on a small grid.
##
## A beam enters the grid from `source` travelling in `source_dir`. Mirror
## crystals reflect it: "/" (0) turns east->north, "\" (1) turns east->south.
## The puzzle is solved when the beam reaches `target`. Turning a crystal
## toggles it between the two orientations. No timing, no failure.

const SLASH := 0
const BACKSLASH := 1
const MAX_STEPS := 200

var width: int = 5
var height: int = 4
## Cell just outside the grid where the beam starts.
var source: Vector2i = Vector2i(-1, 0)
var source_dir: Vector2i = Vector2i(1, 0)
var target: Vector2i = Vector2i(3, 3)
var mirrors: Dictionary = {}
var initial: Dictionary = {}


## The Crystal Creek puzzle: three crystals on the beam's way and one decoy.
static func creek_default() -> BeamPuzzle:
	var p := BeamPuzzle.new()
	p.width = 5
	p.height = 4
	p.source = Vector2i(-1, 0)
	p.source_dir = Vector2i(1, 0)
	p.target = Vector2i(3, 3)
	p.initial = {Vector2i(1, 0): SLASH, Vector2i(1, 2): SLASH, Vector2i(3, 2): SLASH, Vector2i(3, 0): BACKSLASH}
	p.mirrors = p.initial.duplicate()
	return p


static func reflect(dir: Vector2i, orientation: int) -> Vector2i:
	if orientation == SLASH:
		return Vector2i(-dir.y, -dir.x)
	return Vector2i(dir.y, dir.x)


func in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Cells the beam passes through, in order (stops at the target, the grid edge,
## or a loop). The last cell may be outside the grid when the beam leaves it.
func trace() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var pos := source
	var dir := source_dir
	var seen := {}
	for i in MAX_STEPS:
		pos += dir
		path.append(pos)
		if not in_grid(pos) or pos == target:
			break
		var key := [pos, dir]
		if seen.has(key):
			break
		seen[key] = true
		if mirrors.has(pos):
			dir = reflect(dir, int(mirrors[pos]))
	return path


func is_solved() -> bool:
	var path := trace()
	return not path.is_empty() and path[path.size() - 1] == target


func toggle(cell: Vector2i) -> bool:
	if not mirrors.has(cell):
		return false
	mirrors[cell] = BACKSLASH if int(mirrors[cell]) == SLASH else SLASH
	return true


func reset() -> void:
	mirrors = initial.duplicate()


## All mirror configurations that solve the puzzle (brute force; tiny grids).
func solutions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cells: Array = mirrors.keys()
	var saved := mirrors.duplicate()
	for mask in 1 << cells.size():
		for i in cells.size():
			mirrors[cells[i]] = BACKSLASH if (mask >> i) & 1 else SLASH
		if is_solved():
			result.append(mirrors.duplicate())
	mirrors = saved
	return result


## The first crystal on the current beam path that differs from a solution,
## or Vector2i(-99, -99) if none (used for Gentle-mode near-solution hints).
func next_hint_cell() -> Vector2i:
	var options := solutions()
	if options.is_empty() or is_solved():
		return Vector2i(-99, -99)
	var goal: Dictionary = options[0]
	for cell in trace():
		if mirrors.has(cell) and int(mirrors[cell]) != int(goal[cell]):
			return cell
	return Vector2i(-99, -99)


func to_state() -> Dictionary:
	var m := {}
	for cell: Vector2i in mirrors:
		m["%d,%d" % [cell.x, cell.y]] = mirrors[cell]
	return {"mirrors": m}


func load_state(state: Dictionary) -> void:
	var m: Dictionary = state.get("mirrors", {})
	for key: String in m:
		var parts := key.split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if mirrors.has(cell):
			mirrors[cell] = int(m[key])
