class_name ItemDB
extends RefCounted
## Read-only item definitions loaded from every JSON file in game/data/items/.
## New content (fish, dishes, decorations...) is added as data, not code.

const ITEM_DIR := "res://game/data/items"

static var _items: Dictionary = {}
static var _loaded: bool = false
static var load_errors: PackedStringArray = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ITEM_DIR)
	if dir == null:
		load_errors.append("Item folder missing: %s" % ITEM_DIR)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ITEM_DIR.path_join(f)))
		if typeof(parsed) != TYPE_DICTIONARY:
			load_errors.append("Invalid item file %s" % f)
			continue
		for item: Dictionary in (parsed as Dictionary).get("items", []):
			var id := String(item.get("id", ""))
			if id.is_empty() or _items.has(id):
				load_errors.append("Missing or duplicate item id '%s' in %s" % [id, f])
				continue
			_items[id] = item
	for e in load_errors:
		push_error("ItemDB: " + e)


static func exists(id: String) -> bool:
	ensure_loaded()
	return _items.has(id)


static func get_item(id: String) -> Dictionary:
	ensure_loaded()
	return _items.get(id, {})


static func all_ids() -> PackedStringArray:
	ensure_loaded()
	var ids := PackedStringArray(_items.keys())
	ids.sort()
	return ids


static func ids_in_category(category: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id in all_ids():
		if String(_items[id].get("category", "")) == category:
			result.append(id)
	return result


static func display_name(id: String) -> String:
	return L.t(String(get_item(id).get("name", id.capitalize())))


static func description(id: String) -> String:
	return L.t(String(get_item(id).get("desc", "")))


static func uses(id: String) -> String:
	return L.t(String(get_item(id).get("uses", "")))


static func category(id: String) -> String:
	return String(get_item(id).get("category", ""))


static func max_stack(id: String) -> int:
	return maxi(1, int(get_item(id).get("stack", 99)))


## Unique items (tools, quest items) can never be discarded or lost.
static func is_unique(id: String) -> bool:
	return bool(get_item(id).get("unique", false))


static func icon(id: String) -> Dictionary:
	return get_item(id).get("icon", {"shape": "orb", "color": "#888888", "accent": "#ffffff"})
