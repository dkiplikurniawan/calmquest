class_name Farming
extends RefCounted
## Crop rules. A garden plot holds one crop. Each day a crop was watered
## (with the watering can, or by rain) counts as one day of growth. Crops never
## die and never wither: an unwatered crop simply waits. Ripe crops are
## harvested with E; most give seeds back, some (strawberries) regrow.
##
## Plot state lives in GameState.systems["farm"]["<area>:<x>,<y>"]:
##   {"seed": id, "planted": day, "watered": {"<day>": true}}
## Growth is computed from that record and the weather history, so it is
## correct after sleeping, travelling or loading a save.

const STATE_KEY := "farm"


static func plot_key(area_id: String, cell: Vector2i) -> String:
	return "%s:%d,%d" % [area_id, cell.x, cell.y]


static func plots() -> Dictionary:
	return GameState.system_state(STATE_KEY)


static func plot(key: String) -> Dictionary:
	return plots().get(key, {})


static func has_crop(key: String) -> bool:
	return not plot(key).is_empty()


static func crop_data(seed_id: String) -> Dictionary:
	return ItemDB.get_item(seed_id).get("crop", {})


static func seeds_in_bag() -> PackedStringArray:
	var out := PackedStringArray()
	for s in GameState.inventory.slots:
		if not s.is_empty() and ItemDB.category(String(s["id"])) == "seed" and not out.has(String(s["id"])):
			out.append(String(s["id"]))
	return out


static func plant(key: String, seed_id: String) -> bool:
	if has_crop(key) or crop_data(seed_id).is_empty() or not GameState.inventory.remove(seed_id, 1):
		return false
	plots()[key] = {"seed": seed_id, "planted": TimeManager.day, "watered": {}}
	GameState.add_counter("planted")
	GameState.changed.emit("farm:" + key)
	return true


static func is_watered_today(key: String) -> bool:
	var p := plot(key)
	return not p.is_empty() and ((p.get("watered", {}) as Dictionary).has(str(TimeManager.day)) or Weather.is_raining())


static func water(key: String) -> bool:
	var p := plot(key)
	if p.is_empty() or is_ripe(key) or is_watered_today(key):
		return false
	(p["watered"] as Dictionary)[str(TimeManager.day)] = true
	GameState.add_counter("watered")
	return true


## Days of growth so far: every day before today that was watered or rainy.
static func growth_days(key: String) -> int:
	var p := plot(key)
	if p.is_empty():
		return 0
	var watered: Dictionary = p.get("watered", {})
	var n := 0
	for d in range(int(p["planted"]), TimeManager.day):
		if watered.has(str(d)) or Weather.rained_on(d):
			n += 1
	return n


static func days_needed(key: String) -> int:
	var p := plot(key)
	var c := crop_data(String(p.get("seed", "")))
	if bool(p.get("regrown", false)) and int(c.get("regrow", 0)) > 0:
		return int(c["regrow"])
	return int(c.get("days", 3))


static func is_ripe(key: String) -> bool:
	return has_crop(key) and growth_days(key) >= days_needed(key)


## 0 = seed, 1 = sprout, 2 = growing, 3 = ripe.
static func stage(key: String) -> int:
	if not has_crop(key):
		return -1
	if is_ripe(key):
		return 3
	var f := float(growth_days(key)) / float(maxi(1, days_needed(key)))
	return 0 if f <= 0.0 else (1 if f < 0.5 else 2)


## Harvests a ripe crop. Returns {"ok", "items": [[id, qty], ...], "reason"}.
## Whatever doesn't fit in the bag goes to the cottage chest; if neither has
## room, nothing happens and the crop simply waits (nothing is ever lost).
static func harvest(key: String, rng_seed: int = 0) -> Dictionary:
	var result := {"ok": false, "items": [], "reason": ""}
	if not is_ripe(key):
		result["reason"] = "It isn't ripe yet."
		return result
	var p := plot(key)
	var seed_id := String(p["seed"])
	var c := crop_data(seed_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else hash([key, TimeManager.day, GameState.counter("harvested")])
	var y: Array = c.get("yield", [1, 1])
	var sb: Array = c.get("seeds_back", [0, 0])
	var items: Array = [[String(c["grows"]), rng.randi_range(int(y[0]), int(y[1]))]]
	var seeds := rng.randi_range(int(sb[0]), int(sb[1]))
	if seeds > 0:
		items.append([seed_id, seeds])
	var bonus: Dictionary = c.get("bonus", {})
	if not bonus.is_empty():
		items.append([String(bonus["item"]), int(bonus.get("qty", 1))])
	for it: Array in items:
		if GameState.inventory.room_for(String(it[0])) + GameState.storage.room_for(String(it[0])) < int(it[1]):
			result["reason"] = "Your bag and chest are full. The crop will wait for you."
			return result
	for it: Array in items:
		var left := GameState.give_item(String(it[0]), int(it[1]))
		if left > 0:
			GameState.storage.add(String(it[0]), left)
	GameState.add_counter("harvested")
	GameState.add_counter("harvested:" + String(c["grows"]))
	if int(c.get("regrow", 0)) > 0:
		plots()[key] = {"seed": seed_id, "planted": TimeManager.day, "watered": {}, "regrown": true}
	else:
		plots().erase(key)
	GameState.changed.emit("farm:" + key)
	result["ok"] = true
	result["items"] = items
	return result
