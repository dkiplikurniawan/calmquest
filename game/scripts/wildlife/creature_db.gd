class_name CreatureDB
extends RefCounted
## Read-only wildlife definitions from game/data/wildlife/creatures.json, plus
## the Creature Journal (what has been seen, sketched and befriended), stored
## in GameState.systems["creatures"] so it persists with the world save.
##
## Friendship never decays. Offering a liked item raises it by one petal, at
## most once per creature kind per in-game day; at MAX_FRIENDSHIP the creature
## leaves a one-time thank-you gift.

const DATA_PATH := "res://game/data/wildlife/creatures.json"
const MAX_FRIENDSHIP := 3
const STATE_KEY := "creatures"

static var _creatures: Dictionary = {}
static var _order: PackedStringArray = []
static var _loaded: bool = false
static var load_errors: PackedStringArray = []


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("Could not read %s" % DATA_PATH)
	else:
		for c: Dictionary in (parsed as Dictionary).get("creatures", []):
			var id := String(c.get("id", ""))
			if id.is_empty() or _creatures.has(id):
				load_errors.append("Missing or duplicate creature id '%s'" % id)
				continue
			_creatures[id] = c
			_order.append(id)
	for e in load_errors:
		push_error("CreatureDB: " + e)


static func all_ids() -> PackedStringArray:
	ensure_loaded()
	return _order


static func get_creature(id: String) -> Dictionary:
	ensure_loaded()
	return _creatures.get(id, {})


static func display_name(id: String) -> String:
	return L.t(String(get_creature(id).get("name", id)))


## True if this creature can appear in `region` at this time of day and weather.
static func matches(id: String, region: String, is_day: bool, weather: String) -> bool:
	var c := get_creature(id)
	if c.is_empty() or not (c.get("regions", []) as Array).has(region):
		return false
	var requires := String(c.get("requires", ""))
	if not requires.is_empty() and not GameState.has_flag(requires):
		return false
	var time := String(c.get("time", "any"))
	if (time == "day" and not is_day) or (time == "night" and is_day):
		return false
	var needs: Array = c.get("weather", [])
	return needs.is_empty() or needs.has(weather)


static func candidates(region: String, is_day: bool, weather: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in all_ids():
		if matches(id, region, is_day, weather):
			out.append(id)
	return out


# --- Creature Journal ------------------------------------------------------------------

static func entry(id: String) -> Dictionary:
	var all := GameState.system_state(STATE_KEY)
	if not all.has(id):
		all[id] = {"seen": false, "sketched": false, "friendship": 0, "gifted": false, "fed_day": -1}
	return all[id]


static func is_seen(id: String) -> bool:
	return GameState.system_state(STATE_KEY).has(id) and bool(entry(id).get("seen", false))


static func is_sketched(id: String) -> bool:
	return GameState.system_state(STATE_KEY).has(id) and bool(entry(id).get("sketched", false))


static func friendship(id: String) -> int:
	if not GameState.system_state(STATE_KEY).has(id):
		return 0
	return int(entry(id).get("friendship", 0))


static func mark_seen(id: String) -> bool:
	var e := entry(id)
	if bool(e["seen"]):
		return false
	e["seen"] = true
	GameState.add_counter("creatures_seen")
	return true


## Adds the journal sketch. Returns true the first time.
static func sketch(id: String) -> bool:
	mark_seen(id)
	var e := entry(id)
	if bool(e["sketched"]):
		return false
	e["sketched"] = true
	GameState.add_counter("creatures_sketched")
	GameState.set_flag("sketched:" + id)
	return true


static func sketched_count() -> int:
	var n := 0
	for id in all_ids():
		if is_sketched(id):
			n += 1
	return n


## First liked item the player carries, or "".
static func liked_item_in_bag(id: String) -> String:
	for item: String in get_creature(id).get("likes", []):
		if GameState.inventory.count(item) > 0:
			return item
	return ""


static func can_offer_today(id: String) -> bool:
	return friendship(id) < MAX_FRIENDSHIP and int(entry(id).get("fed_day", -1)) != TimeManager.day


## Offers one liked item. Result: {"ok", "reason", "item", "friendship", "gift"}.
static func offer(id: String) -> Dictionary:
	var result := {"ok": false, "reason": "", "item": "", "friendship": friendship(id), "gift": {}}
	if friendship(id) >= MAX_FRIENDSHIP:
		result["reason"] = "You are already the best of friends."
		return result
	if not can_offer_today(id):
		result["reason"] = "It's still happily munching on today's treat. Visit again tomorrow."
		return result
	var item := liked_item_in_bag(id)
	if item.is_empty():
		var likes: Array = get_creature(id).get("likes", [])
		var names := PackedStringArray()
		for l: String in likes:
			names.append(ItemDB.display_name(l))
		result["reason"] = L.t("It would love: %s.") % L.t(" or ").join(names)
		return result
	GameState.inventory.remove(item, 1)
	sketch(id)
	var e := entry(id)
	e["fed_day"] = TimeManager.day
	e["friendship"] = int(e["friendship"]) + 1
	result["ok"] = true
	result["item"] = item
	result["friendship"] = int(e["friendship"])
	if int(e["friendship"]) >= MAX_FRIENDSHIP and not bool(e["gifted"]):
		e["gifted"] = true
		GameState.set_flag("creature_friend:" + id)
		GameState.add_counter("creature_friends")
		var gift: Dictionary = get_creature(id).get("gift", {})
		if not gift.is_empty():
			# A full bag never loses the gift: the rest waits in the cottage chest.
			var left := GameState.give_item(String(gift["item"]), int(gift.get("qty", 1)))
			if left > 0:
				GameState.storage.add(String(gift["item"]), left)
			result["gift"] = gift
	return result
