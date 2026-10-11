class_name Fishing
extends RefCounted
## Fish rules and the fish journal. Which fish bite depends on the water
## (creek, pond, sea), the region, day or night and the weather. A missed fish
## simply swims away; nothing is ever lost. The legendary Old Whiskers only
## visits the special spot by the creek bridge once five kinds of fish have
## been caught. Journal: GameState.systems["fish"][id] = {"caught", "biggest"}.

const STATE_KEY := "fish"
const LEGENDARY_SPECIES_NEEDED := 5


static func all_fish() -> PackedStringArray:
	return ItemDB.ids_in_category("fish")


static func fish_data(id: String) -> Dictionary:
	return ItemDB.get_item(id).get("fish", {})


static func matches(id: String, water: String, region: String, is_day: bool, weather: String) -> bool:
	var f := fish_data(id)
	if f.is_empty() or bool(f.get("legendary", false)):
		return false
	if not (f.get("waters", []) as Array).has(water):
		return false
	var regions: Array = f.get("regions", [])
	if not regions.is_empty() and not regions.has(region):
		return false
	var time := String(f.get("time", "any"))
	if (time == "day" and not is_day) or (time == "night" and is_day):
		return false
	var needs: Array = f.get("weather", [])
	return needs.is_empty() or needs.has(weather)


static func candidates(water: String, region: String, is_day: bool, weather: String) -> PackedStringArray:
	var out := PackedStringArray()
	for id in all_fish():
		if matches(id, water, region, is_day, weather):
			out.append(id)
	return out


## Picks the fish that bites. `special` is the spot's special id ("" if none).
static func pick(water: String, region: String, special: String, rng: RandomNumberGenerator) -> String:
	if special == "old_whiskers" and legendary_ready():
		return "old_whiskers"
	var options := candidates(water, region, WildlifeSpawner.is_day(), Weather.world_today())
	if options.is_empty():
		return ""
	var total := 0.0
	for id in options:
		total += float(fish_data(id).get("weight", 1))
	var roll := rng.randf() * total
	for id in options:
		roll -= float(fish_data(id).get("weight", 1))
		if roll <= 0.0:
			return id
	return options[options.size() - 1]


static func legendary_ready() -> bool:
	return species_caught() >= LEGENDARY_SPECIES_NEEDED and caught("old_whiskers") == 0


static func random_size(id: String, rng: RandomNumberGenerator) -> int:
	var s: Array = fish_data(id).get("size", [10, 20])
	return rng.randi_range(int(s[0]), int(s[1]))


static func caught(id: String) -> int:
	return int((GameState.system_state(STATE_KEY).get(id, {}) as Dictionary).get("caught", 0))


static func biggest(id: String) -> int:
	return int((GameState.system_state(STATE_KEY).get(id, {}) as Dictionary).get("biggest", 0))


static func species_caught() -> int:
	var n := 0
	for id in all_fish():
		if caught(id) > 0:
			n += 1
	return n


## Records a catch and puts the fish in the bag (or the chest). The legendary
## fish is gently let go: it is recorded and leaves a plaque instead.
## Returns {"first": bool, "stored": "bag"|"chest"|"released", "size": cm}.
static func record_catch(id: String, size: int) -> Dictionary:
	var all := GameState.system_state(STATE_KEY)
	var entry: Dictionary = all.get(id, {"caught": 0, "biggest": 0})
	var first := int(entry["caught"]) == 0
	entry["caught"] = int(entry["caught"]) + 1
	entry["biggest"] = maxi(int(entry["biggest"]), size)
	all[id] = entry
	GameState.add_counter("fish_caught")
	if first:
		GameState.add_counter("fish_species")
	GameState.set_flag("caught:" + id)
	var stored := "released"
	if bool(fish_data(id).get("legendary", false)):
		if first:
			var left := GameState.give_item("fish_trophy", 1)
			if left > 0:
				GameState.storage.add("fish_trophy", left)
	elif GameState.give_item(id, 1) == 0:
		stored = "bag"
	elif GameState.storage.add(id, 1) == 0:
		stored = "chest"
	return {"first": first, "stored": stored, "size": size}
