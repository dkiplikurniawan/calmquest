class_name VillageDB
extends RefCounted
## Spirit villagers and the request board (data in game/data/villagers/).
## Friendship is measured in points (10 points = one petal, 5 petals max) and
## never decays. Talking adds a little once a day; a gift once a day adds more
## (loved > liked > anything else). At 5 petals a villager gives a one-time
## thank-you present (a cosmetic and a few items). Requests never expire.
## State: GameState.systems["villagers"] and ["requests"].

const DATA_PATH := "res://game/data/villagers/villagers.json"
const REQUESTS_PATH := "res://game/data/villagers/requests.json"
const POINTS_PER_PETAL := 10
const MAX_PETALS := 5
const TALK_POINTS := 1
const GIFT_POINTS := {"loved": 5, "liked": 3, "neutral": 1}
const BOARD_SLOTS := 3

static var _data: Dictionary = {}
static var _requests: Array = []


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
		else:
			push_error("VillageDB: could not read %s" % DATA_PATH)
		var r: Variant = JSON.parse_string(FileAccess.get_file_as_string(REQUESTS_PATH))
		if typeof(r) == TYPE_DICTIONARY:
			_requests = (r as Dictionary).get("requests", [])
		else:
			push_error("VillageDB: could not read %s" % REQUESTS_PATH)
	return _data


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for v: Dictionary in data().get("villagers", []):
		out.append(String(v["id"]))
	return out


static func villager(id: String) -> Dictionary:
	for v: Dictionary in data().get("villagers", []):
		if v["id"] == id:
			return v
	return {}


static func display_name(id: String) -> String:
	return L.t(String(villager(id).get("name", id)))


static func has_arrived(id: String) -> bool:
	return GameState.has_flag("villager_arrived:" + id)


static func arrived_count() -> int:
	var n := 0
	for id in ids():
		if has_arrived(id):
			n += 1
	return n


static func home_built(id: String) -> bool:
	return GameState.has_flag("home_built:" + id)


static func _state(id: String) -> Dictionary:
	var all := GameState.system_state("villagers")
	if not all.has(id):
		all[id] = {"points": 0, "talked_day": -1, "gifted_day": -1, "rewarded": false, "invited": false}
	return all[id]


static func points(id: String) -> int:
	return int(_state(id)["points"])


static func petals(id: String) -> int:
	return mini(MAX_PETALS, points(id) / POINTS_PER_PETAL)


## Adds friendship points (never more than the maximum, never less than now).
## Returns the best-friend reward ({} unless it was just earned).
static func add_points(id: String, amount: int) -> Dictionary:
	var s := _state(id)
	s["points"] = mini(MAX_PETALS * POINTS_PER_PETAL, int(s["points"]) + maxi(0, amount))
	GameState.changed.emit("villager:" + id)
	if petals(id) >= MAX_PETALS and not bool(s["rewarded"]):
		s["rewarded"] = true
		GameState.add_counter("villager_best_friends")
		var reward: Dictionary = villager(id).get("reward", {})
		var cosmetic := String(reward.get("cosmetic", ""))
		if not cosmetic.is_empty():
			Cosmetics.unlock(cosmetic)
		for r: Dictionary in reward.get("items", []):
			var left := GameState.give_item(String(r["item"]), int(r.get("qty", 1)))
			if left > 0:
				GameState.storage.add(String(r["item"]), left)
		return reward
	return {}


## The line a villager says when you talk (by friendship and time of day).
static func line(id: String, hour: float, nth: int = 0) -> String:
	var lines: Dictionary = villager(id).get("lines", {})
	var greet: Array = lines.get("greet", ["Hello!"])
	if nth % 3 == 1:
		if hour < 11.0:
			return L.t(String(lines.get("morning", greet[0])))
		if hour >= 17.0:
			return L.t(String(lines.get("evening", greet[0])))
	if nth % 3 == 2 and petals(id) >= 3:
		return L.t(String(lines.get("lore", greet[0])))
	var tier := 0 if petals(id) < 2 else (1 if petals(id) < 4 else 2)
	return L.t(String(greet[mini(tier, greet.size() - 1)]))


## Talking once a day adds a little friendship.
static func talk(id: String) -> Dictionary:
	var s := _state(id)
	var reward := {}
	if int(s["talked_day"]) != TimeManager.day:
		s["talked_day"] = TimeManager.day
		GameState.add_counter("villager_talks")
		reward = add_points(id, TALK_POINTS)
	return reward


static func gift_kind(id: String, item: String) -> String:
	var v := villager(id)
	if (v.get("loves", []) as Array).has(item):
		return "loved"
	if (v.get("likes", []) as Array).has(item):
		return "liked"
	return "neutral"


static func can_gift_today(id: String) -> bool:
	return int(_state(id)["gifted_day"]) != TimeManager.day


## Items that can be given away (never keepsakes, tools or quest items).
static func giftable(item: String) -> bool:
	return not ItemDB.is_unique(item) and ItemDB.category(item) in ["resource", "material", "crop", "fish", "food", "magic", "seed", "decor"]


## Gives one item. Result: {"ok", "kind", "text", "reward"}.
static func gift(id: String, item: String) -> Dictionary:
	var result := {"ok": false, "kind": "", "text": "", "reward": {}}
	if not can_gift_today(id):
		result["text"] = L.t("%s smiles. \"You already gave me something today. Come back tomorrow!\"") % display_name(id)
		return result
	if not giftable(item) or not GameState.inventory.remove(item, 1):
		result["text"] = L.t("That one is too precious to give away.")
		return result
	var kind := gift_kind(id, item)
	_state(id)["gifted_day"] = TimeManager.day
	GameState.add_counter("gifts_given")
	result["ok"] = true
	result["kind"] = kind
	result["text"] = L.t(String((villager(id).get("lines", {}) as Dictionary).get(kind, "Thank you!")))
	result["reward"] = add_points(id, int(GIFT_POINTS[kind]))
	return result


## Hands over items for a quest step ("deliver"). Sets "delivered:<id>:<item>".
static func deliver(id: String, item: String, qty: int) -> bool:
	if GameState.inventory.count(item) < qty or not GameState.inventory.remove(item, qty):
		return false
	GameState.set_flag("delivered:%s:%s" % [id, item])
	add_points(id, 3)
	return true


## Active quest steps that ask to bring something to this villager.
static func deliveries_for(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var book := QuestManager.book
	for q in book.quests_with_status(QuestBook.ACTIVE):
		var step := book.current_step(String(q["id"]))
		var d: Dictionary = step.get("deliver", {})
		if not d.is_empty() and String(d.get("villager", "")) == id:
			out.append(d)
	return out


static func invite(id: String) -> bool:
	var s := _state(id)
	if bool(s["invited"]):
		return false
	s["invited"] = true
	GameState.set_flag("festival_invited:" + id)
	GameState.add_counter("festival_invites")
	return true


static func is_invited(id: String) -> bool:
	return bool(_state(id).get("invited", false))


# --- Request board -----------------------------------------------------------------------

static func all_requests() -> Array:
	data()
	return _requests


static func request_done(req_id: String) -> bool:
	return GameState.system_state("requests").has(req_id)


## Up to BOARD_SLOTS open requests from villagers who live here.
static func open_requests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in all_requests():
		if out.size() >= BOARD_SLOTS:
			break
		if not request_done(String(r["id"])) and has_arrived(String(r["from"])):
			out.append(r)
	return out


static func request_ready(r: Dictionary) -> bool:
	if r.has("deliver"):
		var d: Dictionary = r["deliver"]
		return GameState.inventory.count(String(d["item"])) >= int(d["qty"])
	return QuestBook.condition_met(r.get("check", {}), QuestManager.facts)


## Completes a request if it can be. Returns the reward ({} if not).
static func complete_request(r: Dictionary) -> Dictionary:
	if request_done(String(r["id"])) or not request_ready(r):
		return {}
	if r.has("deliver"):
		var d: Dictionary = r["deliver"]
		if not GameState.inventory.remove(String(d["item"]), int(d["qty"])):
			return {}
	GameState.system_state("requests")[String(r["id"])] = TimeManager.day
	GameState.add_counter("requests_done")
	var reward: Dictionary = r.get("reward", {})
	for it: Dictionary in reward.get("items", []):
		var left := GameState.give_item(String(it["item"]), int(it.get("qty", 1)))
		if left > 0:
			GameState.storage.add(String(it["item"]), left)
	add_points(String(r["from"]), int(reward.get("friendship", 0)))
	return reward
