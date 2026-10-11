class_name BuildArea
extends RefCounted
## A rectangular grid where decorations can be placed (the cottage interior or
## the outdoor homestead). Pure geometry, unit tested.

var id: String = ""
## Top-left of the grid in world pixels.
var origin: Vector2 = Vector2.ZERO
var cell: float = 64.0
var cols: int = 10
var rows: int = 7
## Cells that can never hold decorations (stations, door path...).
var reserved: Dictionary = {}


static func make(area_id: String, top_left: Vector2, cell_size: float, columns: int, row_count: int) -> BuildArea:
	var a := BuildArea.new()
	a.id = area_id
	a.origin = top_left
	a.cell = cell_size
	a.cols = columns
	a.rows = row_count
	return a


func rect() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * cell)


func contains(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori((pos.x - origin.x) / cell), floori((pos.y - origin.y) / cell))


func cell_top_left(c: Vector2i) -> Vector2:
	return origin + Vector2(c) * cell


func cell_center(c: Vector2i) -> Vector2:
	return cell_top_left(c) + Vector2.ONE * cell / 2.0


## Size in cells after rotation (rot 1 swaps width and height).
static func rotated_size(size: Vector2i, rot: int) -> Vector2i:
	return Vector2i(size.y, size.x) if rot % 2 == 1 else size


func footprint(c: Vector2i, size: Vector2i, rot: int) -> Array[Vector2i]:
	var s := rotated_size(size, rot)
	var cells: Array[Vector2i] = []
	for y in s.y:
		for x in s.x:
			cells.append(c + Vector2i(x, y))
	return cells


## World rectangle covered by a footprint.
func footprint_rect(c: Vector2i, size: Vector2i, rot: int) -> Rect2:
	return Rect2(cell_top_left(c), Vector2(rotated_size(size, rot)) * cell)


func reserve(c: Vector2i) -> void:
	reserved[c] = true
