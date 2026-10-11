class_name DecorRules
extends RefCounted
## Placement rules and bookkeeping for decorations (pure logic, unit tested).
## Placements are stored in GameState.systems["decor"][area_id] as
## {"item": id, "x": int, "y": int, "rot": 0|1}. Placing takes the item from the
## bag; storing gives it back. Nothing is ever lost.

const SYSTEM_KEY := "decor"


static func decor_data(item_id: String) -> Dictionary:
	return ItemDB.get_item(item_id).get("decor", {})


static func is_decor(item_id: String) -> bool:
	return not decor_data(item_id).is_empty()


static func size_of(item_id: String) -> Vector2i:
	var s: Array = decor_data(item_id).get("size", [1, 1])
	return Vector2i(int(s[0]), int(s[1]))


static func allowed_in(item_id: String, area_id: String) -> bool:
	return (decor_data(item_id).get("areas", []) as Array).has(area_id)


static func placements(area_id: String) -> Array:
	var all := GameState.system_state(SYSTEM_KEY)
	if not all.has(area_id):
		all[area_id] = []
	return all[area_id]


## Map of occupied cell -> index of the placement covering it.
static func occupied(area: BuildArea) -> Dictionary:
	var map := {}
	var list := placements(area.id)
	for i in list.size():
		var p: Dictionary = list[i]
		for c in area.footprint(Vector2i(int(p["x"]), int(p["y"])), size_of(String(p["item"])), int(p.get("rot", 0))):
			map[c] = i
	return map


## Checks a placement. `blocked` = extra cells that are not free (e.g. physics).
## Returns {"ok": bool, "reason": String}.
static func can_place(area: BuildArea, item_id: String, c: Vector2i, rot: int, blocked: Dictionary = {}) -> Dictionary:
	if not is_decor(item_id):
		return {"ok": false, "reason": "That can't be placed."}
	if not allowed_in(item_id, area.id):
		return {"ok": false, "reason": L.t("%s belongs %s.") % [ItemDB.display_name(item_id), L.t("outdoors") if area.id == "interior" else L.t("indoors")]}
	if not GameState.inventory.has(item_id):
		return {"ok": false, "reason": "You don't have one in your bag."}
	var taken := occupied(area)
	for cell in area.footprint(c, size_of(item_id), rot):
		if not area.contains(cell):
			return {"ok": false, "reason": "It doesn't fit here."}
		if area.reserved.has(cell) or blocked.has(cell):
			return {"ok": false, "reason": "This spot needs to stay clear."}
		if taken.has(cell):
			return {"ok": false, "reason": "Something is already here."}
	return {"ok": true, "reason": ""}


## Places one item from the bag. Returns the new placement or {} if not allowed.
static func place(area: BuildArea, item_id: String, c: Vector2i, rot: int, blocked: Dictionary = {}) -> Dictionary:
	if not can_place(area, item_id, c, rot, blocked)["ok"]:
		return {}
	if not GameState.inventory.remove(item_id, 1):
		return {}
	GameState.add_counter("placed:" + item_id)
	var p := {"item": item_id, "x": c.x, "y": c.y, "rot": rot if bool(decor_data(item_id).get("rotatable", false)) or size_of(item_id) != Vector2i.ONE else 0}
	placements(area.id).append(p)
	GameState.add_counter("placed:" + item_id)
	GameState.changed.emit("decor:" + area.id)
	return p


## Stores the decoration covering `c` back in the bag (full refund).
## Returns the removed placement, or {} if nothing is there or the bag is full.
## Why the last store() was refused ("" if it worked or there was nothing there).
static var last_refusal: String = ""


static func store(area: BuildArea, c: Vector2i) -> Dictionary:
	last_refusal = ""
	var map := occupied(area)
	if not map.has(c):
		return {}
	var list := placements(area.id)
	var index := int(map[c])
	var p: Dictionary = list[index]
	# A garden plot with something growing stays put, so no crop is ever lost.
	if bool(decor_data(String(p["item"])).get("farm", false)) and Farming.has_crop(Farming.plot_key(area.id, Vector2i(int(p["x"]), int(p["y"])))):
		last_refusal = "Something is growing in this plot. Harvest it first, then it can be moved."
		return {}
	if GameState.inventory.room_for(String(p["item"])) < 1:
		last_refusal = "Your bag is full."
		return {}
	list.remove_at(index)
	GameState.inventory.add(String(p["item"]), 1)
	GameState.changed.emit("decor:" + area.id)
	return p


## Puts an exact placement back (used by undo after a store).
static func restore(area: BuildArea, p: Dictionary) -> bool:
	if not GameState.inventory.remove(String(p["item"]), 1):
		return false
	placements(area.id).append(p.duplicate())
	GameState.changed.emit("decor:" + area.id)
	return true
