class_name CraftingBook
extends RefCounted
## Recipes and crafting rules (pure logic, unit tested).
## Recipe JSON files live in game/data/recipes/. A recipe is known when its
## id is in `known` (stored in GameState). Discovery keys say how a recipe is
## learned: "start", "note:<note_id>", "flag:<story_flag>", "villager:<id>".

const RECIPE_DIR := "res://game/data/recipes"

var recipes: Dictionary = {}
var order: PackedStringArray = []
## "hearth" (cooking) uses a tier only the cooking pot provides.
const COOKING_TIER := 10
var station_tiers: Dictionary = {"hand": 0, "workbench": 1, "workbench_2": 2, "hearth": COOKING_TIER}
var load_errors: PackedStringArray = []


func load_directory(dir_path: String = RECIPE_DIR) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		load_errors.append("Recipe folder missing: %s" % dir_path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			add_from_json(FileAccess.get_file_as_string(dir_path.path_join(f)), f)


func add_from_json(text: String, source: String = "") -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("Invalid recipe file %s" % source)
		return
	var stations: Dictionary = (parsed as Dictionary).get("stations", {})
	for k: String in stations:
		station_tiers[k] = int(stations[k])
	for r: Dictionary in (parsed as Dictionary).get("recipes", []):
		var id := String(r.get("id", ""))
		if id.is_empty() or recipes.has(id):
			load_errors.append("Missing or duplicate recipe '%s' in %s" % [id, source])
			continue
		for part: Dictionary in r.get("inputs", []) + [r.get("output", {})]:
			if not ItemDB.exists(String(part.get("item", ""))):
				load_errors.append("Recipe %s uses unknown item '%s'" % [id, part.get("item", "")])
		recipes[id] = r
		order.append(id)


func get_recipe(id: String) -> Dictionary:
	return recipes.get(id, {})


## Recipe ids learned through `key` (e.g. "note:note_fisher", "start").
func recipes_for_discovery(key: String) -> PackedStringArray:
	var result := PackedStringArray()
	for id in order:
		if String(recipes[id].get("discover", "")) == key:
			result.append(id)
	return result


func is_cooking(recipe_id: String) -> bool:
	return String(get_recipe(recipe_id).get("station", "")) == "hearth"


## The cooking recipe whose ingredient set is exactly `items` (any amounts),
## among recipes discovered by experimenting. "" if none.
func experiment_match(items: Array) -> String:
	var wanted := {}
	for i: Variant in items:
		wanted[String(i)] = true
	for id in order:
		var r: Dictionary = recipes[id]
		if String(r.get("discover", "")) != "experiment":
			continue
		var have := {}
		for part: Dictionary in r.get("inputs", []):
			have[String(part["item"])] = true
		if have.size() == wanted.size() and have.keys().all(func(k: String) -> bool: return wanted.has(k)):
			return id
	return ""


func station_tier(recipe_id: String) -> int:
	return int(station_tiers.get(String(get_recipe(recipe_id).get("station", "hand")), 0))


## `stock` is an Inventory or an Array of Inventories (e.g. the bag plus a
## nearby storage chest). Inputs are taken from them in order; the result goes
## into the first one with room.
static func _sources(stock: Variant) -> Array:
	return stock if stock is Array else [stock]


static func _count(sources: Array, item: String) -> int:
	var n := 0
	for inv: Inventory in sources:
		n += inv.count(item)
	return n


## Returns {"ok": bool, "missing": Array of {item, have, need}, "reason": String}.
func check(recipe_id: String, stock: Variant, available_tier: int, known: Dictionary, qty: int = 1) -> Dictionary:
	var sources := _sources(stock)
	var r := get_recipe(recipe_id)
	if r.is_empty():
		return {"ok": false, "missing": [], "reason": "Unknown recipe."}
	if not known.has(recipe_id):
		return {"ok": false, "missing": [], "reason": "You haven't learned this recipe yet."}
	if station_tier(recipe_id) > available_tier:
		var station := String(r.get("station", "hand"))
		return {"ok": false, "missing": [], "reason": L.t("Needs a %s nearby.") % (L.t("better workbench") if station == "workbench_2" else L.t(station.replace("_", " ")))}
	var missing: Array = []
	for part: Dictionary in r.get("inputs", []):
		var need := int(part["qty"]) * qty
		var have := _count(sources, String(part["item"]))
		if have < need:
			missing.append({"item": part["item"], "have": have, "need": need})
	if not missing.is_empty():
		return {"ok": false, "missing": missing, "reason": "Missing materials."}
	var out: Dictionary = r["output"]
	if ItemDB.is_unique(String(out["item"])) and _count(sources, String(out["item"])) > 0:
		return {"ok": false, "missing": [], "reason": "You already have one."}
	return {"ok": true, "missing": [], "reason": ""}


## Crafts `qty` times if possible. Consumes inputs only when the output fits.
func craft(recipe_id: String, stock: Variant, available_tier: int, known: Dictionary, qty: int = 1) -> bool:
	var sources := _sources(stock)
	if not check(recipe_id, sources, available_tier, known, qty)["ok"]:
		return false
	var r := get_recipe(recipe_id)
	var out: Dictionary = r["output"]
	var out_id := String(out["item"])
	var out_qty := int(out["qty"]) * qty
	# Simulate on copies so a full inventory never loses the inputs.
	var trials: Array = []
	for inv: Inventory in sources:
		var t := Inventory.new(0)
		t.load_state(inv.to_state())
		trials.append(t)
	_take(trials, r, qty)
	var left := out_qty
	for t: Inventory in trials:
		left = t.add(out_id, left)
	if left > 0:
		return false
	_take(sources, r, qty)
	left = out_qty
	for inv: Inventory in sources:
		left = inv.add(out_id, left)
	return true


static func _take(sources: Array, recipe: Dictionary, qty: int) -> void:
	for part: Dictionary in recipe.get("inputs", []):
		var need := int(part["qty"]) * qty
		for inv: Inventory in sources:
			var take := mini(need, inv.count(String(part["item"])))
			if take > 0:
				inv.remove(String(part["item"]), take)
				need -= take
