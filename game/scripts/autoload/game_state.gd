extends Node
## Persistent world state (autoload "GameState").
##
## Everything about the *world and the player's progress* lives here: story
## flags and counters, inventory, known recipes, collected world objects,
## garden beds, discoveries, lore, visited regions, waystones, chunk deltas
## (gathered resources with respawn days), puzzles, fog of war and map pins.
## It is serialized by the save system (SaveManager). Research session
## metrics stay in SessionState and are never saved here.

signal changed(key: String)
signal item_gained(item_id: String, qty: int)

const FOG_CELL := 128.0
const WAYSTONE_DISCOVERED := "discovered"
const WAYSTONE_RESTORED := "restored"
const STATE_VERSION := 1
const STARTING_ITEMS := {"lantern": 1}
const STORAGE_CAPACITY := 40

var bound_session_id: String = ""
var flags: Dictionary = {}
var counters: Dictionary = {}
var visited_regions: Dictionary = {}
var waystones: Dictionary = {}
## chunk key -> {object_id: {"day": int, "respawn": int}}
var removed_objects: Dictionary = {}
var puzzles: Dictionary = {}
var seen_landmarks: Dictionary = {}
var pins: Array[Vector2] = []
var fog: PackedByteArray = PackedByteArray()
var fog_size: Vector2i = Vector2i.ZERO
var inventory: Inventory = Inventory.new()
## The cottage storage chest (usable once it is built).
var storage: Inventory = Inventory.new(STORAGE_CAPACITY)
var known_recipes: Dictionary = {}
var collected: Dictionary = {}
var bloomed_beds: Dictionary = {}
var discoveries: Dictionary = {}
var lore_read: Dictionary = {}
## Extra per-system state (cottage, buildings, farm, creatures, villagers...).
## Each system owns one key; values must be JSON-safe.
var systems: Dictionary = {}
var crafting: CraftingBook


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	crafting = CraftingBook.new()
	crafting.load_directory()
	for e in crafting.load_errors:
		push_error("Crafting: " + e)
	inventory.changed.connect(func() -> void: changed.emit("inventory"))
	reset_world(Vector2(10240, 6144))


## Legacy V1/V2-M2 behaviour: a new session without a save slot starts fresh.
func bind_to_session(session_id: String, world_size: Vector2) -> void:
	if session_id != bound_session_id or fog_size == Vector2i.ZERO:
		reset_world(world_size)
		bound_session_id = session_id


func reset_world(world_size: Vector2) -> void:
	flags.clear()
	counters.clear()
	visited_regions.clear()
	waystones.clear()
	removed_objects.clear()
	puzzles.clear()
	seen_landmarks.clear()
	pins.clear()
	collected.clear()
	bloomed_beds.clear()
	discoveries.clear()
	lore_read.clear()
	systems.clear()
	known_recipes.clear()
	fog_size = Vector2i(ceili(world_size.x / FOG_CELL), ceili(world_size.y / FOG_CELL))
	fog = PackedByteArray()
	fog.resize(fog_size.x * fog_size.y)
	fog.fill(0)
	inventory.load_state([])
	storage.load_state([])
	storage.resize(STORAGE_CAPACITY)
	for id: String in STARTING_ITEMS:
		inventory.add(id, int(STARTING_ITEMS[id]))
	learn_recipes_for("start")
	TimeManager.reset_clock()
	changed.emit("reset")


# --- Flags and counters -----------------------------------------------------------

func set_flag(key: String, value: bool = true) -> void:
	if bool(flags.get(key, false)) == value:
		return
	flags[key] = value
	if value:
		learn_recipes_for("flag:" + key)
	changed.emit(key)


func has_flag(key: String) -> bool:
	return bool(flags.get(key, false))


func add_counter(key: String, amount: int = 1) -> int:
	counters[key] = int(counters.get(key, 0)) + amount
	changed.emit(key)
	return counters[key]


func counter(key: String) -> int:
	return int(counters.get(key, 0))


# --- Items and recipes ---------------------------------------------------------------

## Adds items to the inventory and records "obtained:<id>" for quests.
## Returns how many did not fit.
func give_item(item_id: String, qty: int = 1) -> int:
	var left := inventory.add(item_id, qty)
	var added := qty - left
	if added > 0:
		add_counter("obtained:" + item_id, added)
		item_gained.emit(item_id, added)
	return left


func learn_recipe(recipe_id: String) -> bool:
	if crafting == null or known_recipes.has(recipe_id) or crafting.get_recipe(recipe_id).is_empty():
		return false
	known_recipes[recipe_id] = true
	changed.emit("recipe:" + recipe_id)
	return true


## Cooking experiment: if the chosen ingredient set matches an undiscovered
## dish, it is learned. Nothing is ever used up by experimenting.
func try_experiment(items: Array) -> String:
	var id := crafting.experiment_match(items)
	if id.is_empty():
		return ""
	if learn_recipe(id):
		add_counter("recipes_discovered_by_experiment")
	return id


## Learns every recipe whose discovery key matches (e.g. "note:note_fisher").
func learn_recipes_for(key: String) -> PackedStringArray:
	var learned := PackedStringArray()
	if crafting == null:
		return learned
	for id in crafting.recipes_for_discovery(key):
		if learn_recipe(id):
			learned.append(id)
	return learned


## use_storage: also take materials from the storage chest (when standing near it).
func craft(recipe_id: String, station_tier: int, qty: int = 1, use_storage: bool = false) -> bool:
	var sources: Array = [inventory, storage] if use_storage else [inventory]
	if not crafting.craft(recipe_id, sources, station_tier, known_recipes, qty):
		return false
	var out: Dictionary = crafting.get_recipe(recipe_id)["output"]
	var first_time := counter("crafted:" + String(out["item"])) == 0
	add_counter("crafted:" + String(out["item"]), int(out["qty"]) * qty)
	add_counter("obtained:" + String(out["item"]), int(out["qty"]) * qty)
	if crafting.is_cooking(recipe_id):
		add_counter("dishes_cooked", qty)
		if first_time:
			add_counter("dish_kinds")
	return true


# --- Collected objects, beds, discoveries, lore ---------------------------------------

func mark_collected(object_id: String) -> bool:
	if collected.has(object_id):
		return false
	collected[object_id] = true
	return true


func is_collected(object_id: String) -> bool:
	return collected.has(object_id)


func read_lore(note_id: String) -> bool:
	if lore_read.has(note_id):
		return false
	lore_read[note_id] = true
	learn_recipes_for("note:" + note_id)
	set_flag("read:" + note_id)
	add_counter("notes_read")
	changed.emit("lore:" + note_id)
	return true


func system_state(key: String) -> Dictionary:
	if not systems.has(key):
		systems[key] = {}
	return systems[key]


# --- Regions, landmarks, waystones --------------------------------------------------

func mark_region_visited(region_id: String) -> bool:
	if visited_regions.has(region_id):
		return false
	visited_regions[region_id] = true
	changed.emit("region:" + region_id)
	return true


func has_visited(region_id: String) -> bool:
	return visited_regions.has(region_id)


func mark_landmark_seen(landmark_id: String) -> bool:
	if seen_landmarks.has(landmark_id):
		return false
	seen_landmarks[landmark_id] = true
	return true


func waystone_state(waystone_id: String) -> String:
	return String(waystones.get(waystone_id, ""))


func set_waystone_state(waystone_id: String, state: String) -> bool:
	var current := waystone_state(waystone_id)
	if current == state or current == WAYSTONE_RESTORED:
		return false
	if state == WAYSTONE_DISCOVERED and current != "":
		return false
	waystones[waystone_id] = state
	changed.emit("waystone:" + waystone_id)
	return true


func restored_waystones() -> PackedStringArray:
	var ids := PackedStringArray()
	for id: String in waystones:
		if waystones[id] == WAYSTONE_RESTORED:
			ids.append(id)
	ids.sort()
	return ids


# --- World deltas (objects removed from streamed chunks) ------------------------------

static func chunk_key(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]


## respawn_days <= 0 means gone for good; otherwise it returns after that many days.
func mark_removed(chunk: Vector2i, object_id: String, respawn_days: int = 0) -> void:
	var key := chunk_key(chunk)
	if not removed_objects.has(key):
		removed_objects[key] = {}
	(removed_objects[key] as Dictionary)[object_id] = {"day": TimeManager.day, "respawn": respawn_days}
	changed.emit("delta:" + key)


func is_removed(chunk: Vector2i, object_id: String) -> bool:
	var entries: Dictionary = removed_objects.get(chunk_key(chunk), {})
	if not entries.has(object_id):
		return false
	var e: Dictionary = entries[object_id]
	var respawn := int(e.get("respawn", 0))
	if respawn > 0 and TimeManager.day - int(e.get("day", 0)) >= respawn:
		entries.erase(object_id)
		return false
	return true


# --- Puzzles -------------------------------------------------------------------------

func puzzle_state(puzzle_id: String) -> Dictionary:
	return puzzles.get(puzzle_id, {})


func set_puzzle_state(puzzle_id: String, state: Dictionary) -> void:
	puzzles[puzzle_id] = state.duplicate(true)
	changed.emit("puzzle:" + puzzle_id)


# --- Fog of war and pins ----------------------------------------------------------------

func reveal(pos: Vector2, radius: float) -> bool:
	if fog_size == Vector2i.ZERO:
		return false
	var changed_any := false
	var r_cells := ceili(radius / FOG_CELL)
	var center := Vector2i(floori(pos.x / FOG_CELL), floori(pos.y / FOG_CELL))
	for y in range(center.y - r_cells, center.y + r_cells + 1):
		for x in range(center.x - r_cells, center.x + r_cells + 1):
			if x < 0 or y < 0 or x >= fog_size.x or y >= fog_size.y:
				continue
			var cell_center := (Vector2(x, y) + Vector2(0.5, 0.5)) * FOG_CELL
			if cell_center.distance_to(pos) > radius:
				continue
			var i := y * fog_size.x + x
			if fog[i] == 0:
				fog[i] = 1
				changed_any = true
	return changed_any


func is_revealed(pos: Vector2) -> bool:
	var x := floori(pos.x / FOG_CELL)
	var y := floori(pos.y / FOG_CELL)
	if x < 0 or y < 0 or x >= fog_size.x or y >= fog_size.y:
		return false
	return fog[y * fog_size.x + x] == 1


func revealed_fraction() -> float:
	if fog.is_empty():
		return 0.0
	return float(fog.count(1)) / fog.size()


func add_pin(pos: Vector2) -> void:
	pins.append(pos)
	changed.emit("pins")


func remove_pin_near(pos: Vector2, radius: float) -> bool:
	var best := -1
	var best_d := radius
	for i in pins.size():
		var d := pins[i].distance_to(pos)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	pins.remove_at(best)
	changed.emit("pins")
	return true


# --- Serialization (used by SaveManager) ------------------------------------------------

func to_state() -> Dictionary:
	var pin_list: Array = []
	for p in pins:
		pin_list.append([p.x, p.y])
	return {
		"version": STATE_VERSION,
		"flags": flags.duplicate(true),
		"counters": counters.duplicate(true),
		"visited_regions": visited_regions.keys(),
		"waystones": waystones.duplicate(),
		"removed_objects": removed_objects.duplicate(true),
		"puzzles": puzzles.duplicate(true),
		"seen_landmarks": seen_landmarks.keys(),
		"pins": pin_list,
		"fog_size": [fog_size.x, fog_size.y],
		"fog": Marshalls.raw_to_base64(fog),
		"inventory": inventory.to_state(),
		"storage": storage.to_state(),
		"known_recipes": known_recipes.keys(),
		"collected": collected.keys(),
		"bloomed_beds": bloomed_beds.keys(),
		"discoveries": discoveries.keys(),
		"lore_read": lore_read.keys(),
		"systems": systems.duplicate(true),
	}


func load_state(s: Dictionary, world_size: Vector2) -> void:
	reset_world(world_size)
	flags = (s.get("flags", {}) as Dictionary).duplicate(true)
	counters = (s.get("counters", {}) as Dictionary).duplicate(true)
	waystones = (s.get("waystones", {}) as Dictionary).duplicate()
	removed_objects = (s.get("removed_objects", {}) as Dictionary).duplicate(true)
	puzzles = (s.get("puzzles", {}) as Dictionary).duplicate(true)
	systems = (s.get("systems", {}) as Dictionary).duplicate(true)
	for key in ["visited_regions", "seen_landmarks", "known_recipes", "collected", "bloomed_beds", "discoveries", "lore_read"]:
		var target: Dictionary = get(key)
		target.clear()
		for id: Variant in s.get(key, []):
			target[String(id)] = true
	pins.clear()
	for p: Variant in s.get("pins", []):
		pins.append(Vector2(float(p[0]), float(p[1])))
	var saved_fog := Marshalls.base64_to_raw(String(s.get("fog", "")))
	if saved_fog.size() == fog.size():
		fog = saved_fog
	inventory.load_state(s.get("inventory", []))
	storage.load_state(s.get("storage", []))
	storage.resize(STORAGE_CAPACITY)
	learn_recipes_for("start")
	changed.emit("loaded")
