class_name WorldData
extends RefCounted
## The authored macro layout of the Lumeria overworld, loaded from JSON.
##
## The world is a grid of macro cells (one character per cell in
## game/data/world/overworld.json). Each character maps to a legend entry:
## region, walkability, water, ground palette and decoration profile. Paths,
## rivers and points of interest are authored in world pixels.
## Pure data + queries: no scene-tree dependencies, so it is unit tested.

const DEFAULT_PATH := "res://game/data/world/overworld.json"
const OUTSIDE_CHAR := "~"

var world_seed: int = 0
var cell_size: float = 256.0
var chunk_cells: int = 4
var width_cells: int = 0
var height_cells: int = 0
var rows: PackedStringArray = []
var legend: Dictionary = {}
var regions: Dictionary = {}
var decor_profiles: Dictionary = {}
var gather_profiles: Dictionary = {}
var paths: Array[Dictionary] = []
var rivers: Array[Dictionary] = []
var pois: Array[Dictionary] = []
var player_spawn: Vector2 = Vector2.ZERO
var load_error: String = ""

var _poi_index: Dictionary = {}


static func load_from(path: String = DEFAULT_PATH) -> WorldData:
	var data := WorldData.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		data.load_error = "World data not found or empty: %s" % path
		push_error(data.load_error)
		return data
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		data.load_error = "World data is not valid JSON: %s" % path
		push_error(data.load_error)
		return data
	data._apply(parsed)
	return data


func is_valid() -> bool:
	return load_error.is_empty() and width_cells > 0 and height_cells > 0


func _apply(d: Dictionary) -> void:
	world_seed = int(d.get("seed", 0))
	cell_size = float(d.get("cell_size", 256))
	chunk_cells = int(d.get("chunk_cells", 4))
	rows = PackedStringArray()
	for r: Variant in d.get("rows", []):
		rows.append(String(r))
	height_cells = rows.size()
	width_cells = rows[0].length() if height_cells > 0 else 0
	for r in rows:
		if r.length() != width_cells:
			load_error = "World rows must all have the same length."
	legend = d.get("legend", {})
	regions = d.get("regions", {})
	decor_profiles = d.get("decor_profiles", {})
	gather_profiles = d.get("gather_profiles", {})
	player_spawn = _vec(d.get("player_spawn", [0, 0]))
	for p: Dictionary in d.get("paths", []):
		paths.append({"id": p.get("id", ""), "width": float(p.get("width", 46)), "points": _points(p.get("points", []))})
	for rv: Dictionary in d.get("rivers", []):
		var crossings: Array[Dictionary] = []
		for c: Dictionary in rv.get("crossings", []):
			crossings.append({"pos": _vec(c["pos"]), "radius": float(c.get("radius", 100)), "kind": String(c.get("kind", "bridge"))})
		rivers.append({"id": rv.get("id", ""), "width": float(rv.get("width", 120)), "points": _points(rv.get("points", [])), "crossings": crossings})
	for poi: Dictionary in d.get("pois", []):
		var entry := poi.duplicate(true)
		entry["pos"] = _vec(poi.get("pos", [0, 0]))
		if poi.has("size"):
			entry["size"] = _vec(poi["size"])
		entry["clear"] = float(poi.get("clear", 120))
		pois.append(entry)
		_poi_index[String(entry["id"])] = entry


static func _vec(a: Variant) -> Vector2:
	var arr: Array = a
	return Vector2(float(arr[0]), float(arr[1]))


static func _points(a: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p: Variant in a:
		pts.append(_vec(p))
	return pts


# --- Geometry ------------------------------------------------------------------

func world_size() -> Vector2:
	return Vector2(width_cells, height_cells) * cell_size


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, world_size())


func chunk_size() -> float:
	return cell_size * chunk_cells


func chunk_count() -> Vector2i:
	return Vector2i(ceili(float(width_cells) / chunk_cells), ceili(float(height_cells) / chunk_cells))


func chunk_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / chunk_size()), floori(pos.y / chunk_size()))


func chunk_rect(chunk: Vector2i) -> Rect2:
	return Rect2(Vector2(chunk) * chunk_size(), Vector2.ONE * chunk_size())


func is_chunk_inside(chunk: Vector2i) -> bool:
	var n := chunk_count()
	return chunk.x >= 0 and chunk.y >= 0 and chunk.x < n.x and chunk.y < n.y


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.y / cell_size))


# --- Cell queries -----------------------------------------------------------------

func char_at_cell(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= width_cells or cell.y >= height_cells:
		return OUTSIDE_CHAR
	return rows[cell.y][cell.x]


func char_at(pos: Vector2) -> String:
	return char_at_cell(cell_of(pos))


func legend_at(pos: Vector2) -> Dictionary:
	return legend.get(char_at(pos), {})


func is_blocked_at(pos: Vector2) -> bool:
	return bool(legend_at(pos).get("blocked", true))


func is_water_at(pos: Vector2) -> bool:
	return bool(legend_at(pos).get("water", false)) or distance_to_river(pos) < 0.0


func region_at(pos: Vector2) -> String:
	return String(legend_at(pos).get("region", "open_sea"))


func region_info(region_id: String) -> Dictionary:
	return regions.get(region_id, {"name": region_id.capitalize(), "subtitle": "", "zoom": 1.0, "status": "unknown"})


## The region's name for display, in the current language.
func region_display(region_id: String) -> String:
	return L.t(region_name(region_id))


## The region's English name (stored in saves; translate with L.t to show it).
func region_name(region_id: String) -> String:
	return String(region_info(region_id).get("name", region_id))


## Gatherable resources for the cell: [[item_id, chance, respawn_days], ...].
func gather_profile_at(pos: Vector2) -> Array:
	var profile_id := String(legend_at(pos).get("decor", "none"))
	return gather_profiles.get(profile_id, [])


func decor_profile_at(pos: Vector2) -> Array:
	var profile_id := String(legend_at(pos).get("decor", "none"))
	return decor_profiles.get(profile_id, [])


## Average position of all cells of a region (used for map labels).
func region_center(region_id: String) -> Vector2:
	var total := Vector2.ZERO
	var count := 0
	for y in height_cells:
		for x in width_cells:
			if String(legend.get(rows[y][x], {}).get("region", "")) == region_id:
				total += (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_size
				count += 1
	return total / count if count > 0 else Vector2.ZERO


# --- POIs ------------------------------------------------------------------------

func poi(poi_id: String) -> Dictionary:
	return _poi_index.get(poi_id, {})


func pois_of_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in pois:
		if String(p.get("kind", "")) == kind:
			result.append(p)
	return result


# --- Paths and rivers ----------------------------------------------------------------

## Distance from `pos` to the edge of the nearest path (negative = on the path).
func distance_to_paths(pos: Vector2) -> float:
	var best := INF
	for p in paths:
		best = minf(best, _polyline_distance(pos, p["points"]) - float(p["width"]) * 0.5)
	return best


## Distance to the nearest river bank (negative = in the water). Crossings
## (bridges, stepping stones) count as dry land.
func distance_to_river(pos: Vector2) -> float:
	var best := INF
	for rv in rivers:
		for c: Dictionary in rv["crossings"]:
			if pos.distance_to(c["pos"]) < float(c["radius"]) * 0.6:
				return INF
		best = minf(best, _polyline_distance(pos, rv["points"]) - float(rv["width"]) * 0.5)
	return best


static func _polyline_distance(pos: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var closest := Geometry2D.get_closest_point_to_segment(pos, pts[i], pts[i + 1])
		best = minf(best, pos.distance_to(closest))
	return best
