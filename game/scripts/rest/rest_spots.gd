class_name RestSpots
extends RefCounted
## Rest spots (0.4.0): quiet places to sit and simply be there for a while.
## Data: game/data/rest_spots.json. State (which places were found) lives in
## GameState.systems["rest_spots"], so it is saved with the journey.
## There is nothing to earn by resting; finding every quiet place unlocks one
## cosmetic (Lumi's dusk glow) and nothing else.

const DATA_PATH := "res://game/data/rest_spots.json"
const STATE_KEY := "rest_spots"
const ALL_FOUND_COSMETIC := "glow:dusk"

static var _spots: Array = []


static func all() -> Array:
	if _spots.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			_spots = (data as Dictionary).get("spots", [])
		else:
			push_warning("RestSpots: could not read %s." % DATA_PATH)
	return _spots


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for s: Dictionary in all():
		out.append(String(s["id"]))
	return out


static func spot(id: String) -> Dictionary:
	for s: Dictionary in all():
		if String(s["id"]) == id:
			return s
	return {}


static func display_name(id: String) -> String:
	return L.t(String(spot(id).get("name", id)))


static func line(id: String) -> String:
	return L.t(String(spot(id).get("text", "")))


## Spots in the overworld (with a world position).
static func overworld_spots() -> Array:
	return all().filter(func(s: Dictionary) -> bool: return s.has("pos"))


## Spots inside one cave (with a cell).
static func cave_spots(cave_id: String) -> Array:
	return all().filter(func(s: Dictionary) -> bool: return String(s.get("cave", "")) == cave_id)


static func world_pos(s: Dictionary) -> Vector2:
	var p: Array = s.get("pos", [0, 0])
	return Vector2(float(p[0]), float(p[1]))


static func _found() -> Dictionary:
	var st := GameState.system_state(STATE_KEY)
	if not st.has("found"):
		st["found"] = {}
	return st["found"]


static func is_found(id: String) -> bool:
	return _found().has(id)


static func found_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids():
		if is_found(id):
			out.append(id)
	return out


static func all_found() -> bool:
	return found_ids().size() == ids().size()


## Marks a quiet place as found. Returns true the first time.
static func mark_found(id: String) -> bool:
	if id.is_empty() or is_found(id) or spot(id).is_empty():
		return false
	_found()[id] = true
	if all_found():
		Cosmetics.unlock(ALL_FOUND_COSMETIC)
	GameState.changed.emit(STATE_KEY)
	return true
