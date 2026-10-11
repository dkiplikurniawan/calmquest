class_name Inventory
extends RefCounted
## Slot-based inventory with stacking (pure logic, unit tested).
##
## * add() never creates items from nothing and never loses them: it returns
##   how many items did NOT fit, so callers can leave them in the world.
## * Unique items (tools, quest items) cannot be discarded.
## * The first HOTBAR_SIZE slots form the hotbar shown on the HUD.
## * Capacity grows with crafted bags, never with payment or timers.

signal changed

const BASE_CAPACITY := 30
const BAG_BONUS := 10
const HOTBAR_SIZE := 8
const BAG_ITEMS := ["gathering_bag", "travelers_pack"]

## Each slot is {} (empty) or {"id": String, "qty": int}.
var slots: Array[Dictionary] = []


func _init(capacity: int = BASE_CAPACITY) -> void:
	resize(capacity)


func capacity() -> int:
	return slots.size()


func resize(new_capacity: int) -> void:
	while slots.size() < new_capacity:
		slots.append({})


## Capacity implied by owned bag upgrades.
func refresh_capacity() -> void:
	var target := BASE_CAPACITY
	for bag in BAG_ITEMS:
		if count(bag) > 0:
			target += BAG_BONUS
	resize(target)


func count(id: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			n += int(s["qty"])
	return n


func has(id: String, qty: int = 1) -> bool:
	return count(id) >= qty


## How many of `id` could be added right now.
func room_for(id: String) -> int:
	var stack := ItemDB.max_stack(id)
	var room := 0
	for s in slots:
		if s.is_empty():
			room += stack
		elif s["id"] == id:
			room += stack - int(s["qty"])
	return room


## Adds up to `qty` items. Returns the number that did not fit (0 = all added).
func add(id: String, qty: int = 1) -> int:
	if qty <= 0 or not ItemDB.exists(id):
		if not ItemDB.exists(id):
			push_warning("Inventory: unknown item '%s'." % id)
		return maxi(qty, 0)
	var stack := ItemDB.max_stack(id)
	var left := qty
	for s in slots:
		if left == 0:
			break
		if not s.is_empty() and s["id"] == id and int(s["qty"]) < stack:
			var put := mini(left, stack - int(s["qty"]))
			s["qty"] = int(s["qty"]) + put
			left -= put
	for i in slots.size():
		if left == 0:
			break
		if slots[i].is_empty():
			var put := mini(left, stack)
			slots[i] = {"id": id, "qty": put}
			left -= put
	if left < qty:
		if BAG_ITEMS.has(id):
			refresh_capacity()
		changed.emit()
	return left


## Removes exactly `qty` items, or nothing if there are not enough.
func remove(id: String, qty: int = 1) -> bool:
	if qty <= 0 or count(id) < qty:
		return false
	var left := qty
	for i in range(slots.size() - 1, -1, -1):
		if left == 0:
			break
		var s := slots[i]
		if s.is_empty() or s["id"] != id:
			continue
		var take := mini(left, int(s["qty"]))
		s["qty"] = int(s["qty"]) - take
		left -= take
		if int(s["qty"]) == 0:
			slots[i] = {}
	changed.emit()
	return true


## Discarding is only allowed for ordinary items. Unique items stay safe.
func discard(id: String, qty: int = 1) -> bool:
	if ItemDB.is_unique(id):
		return false
	return remove(id, qty)


func swap(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= slots.size() or b >= slots.size() or a == b:
		return
	var tmp := slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	changed.emit()


## Merges stacks and orders items by category then name. Hotbar tools stay first.
func sort_items() -> void:
	var totals: Dictionary = {}
	for s in slots:
		if not s.is_empty():
			totals[s["id"]] = int(totals.get(s["id"], 0)) + int(s["qty"])
	var ids: Array = totals.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := _category_rank(a)
		var cb := _category_rank(b)
		if ca != cb:
			return ca < cb
		return ItemDB.display_name(a) < ItemDB.display_name(b))
	for i in slots.size():
		slots[i] = {}
	var index := 0
	for id: String in ids:
		var left := int(totals[id])
		var stack := ItemDB.max_stack(id)
		while left > 0 and index < slots.size():
			var put := mini(left, stack)
			slots[index] = {"id": id, "qty": put}
			left -= put
			index += 1
	changed.emit()


static func _category_rank(id: String) -> int:
	var order := ["tool", "magic", "seed", "food", "fish", "resource", "material", "crop", "decor", "upgrade", "quest"]
	var i := order.find(ItemDB.category(id))
	return i if i >= 0 else order.size()


func hotbar() -> Array[Dictionary]:
	return slots.slice(0, HOTBAR_SIZE)


func total_items() -> int:
	var n := 0
	for s in slots:
		if not s.is_empty():
			n += int(s["qty"])
	return n


func to_state() -> Array:
	var out: Array = []
	for s in slots:
		out.append(s.duplicate())
	return out


func load_state(state: Array) -> void:
	slots.clear()
	for s: Variant in state:
		var d: Dictionary = s if s is Dictionary else {}
		if not d.is_empty() and (not ItemDB.exists(String(d.get("id", ""))) or int(d.get("qty", 0)) <= 0):
			push_warning("Inventory: dropping invalid saved slot %s" % str(d))
			d = {}
		slots.append({} if d.is_empty() else {"id": String(d["id"]), "qty": int(d["qty"])})
	refresh_capacity()
	changed.emit()
