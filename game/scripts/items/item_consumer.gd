class_name ItemConsumer
extends RefCounted
## Using consumable items (food). Food gives an optional, gentle, temporary
## buff; nothing ever drains, and not eating has no downside.
## Item JSON: "food": {"buff": "<buff id>", "seconds": 180}.

const BUFFS := {
	"warm_glow": "Your lantern glows wider: more of the map reveals around you.",
	"easy_stroll": "Your steps feel light: you walk a little faster.",
	"lucky_line": "Fish seem friendlier: they bite sooner.",
	"creature_friend": "Shy creatures feel at ease around you.",
	"cozy": "A warm, cozy feeling. (No effect beyond the smile.)",
}


static func can_use(item_id: String) -> bool:
	return ItemDB.category(item_id) == "food" and ItemDB.get_item(item_id).has("food")


## Consumes one item and starts its buff. Returns false if not possible.
static func use(item_id: String, overworld: Node) -> bool:
	if not can_use(item_id) or not GameState.inventory.remove(item_id, 1):
		return false
	var food: Dictionary = ItemDB.get_item(item_id)["food"]
	var buff := String(food.get("buff", "cozy"))
	var seconds := float(food.get("seconds", 120))
	Buffs.start(buff, seconds)
	GameState.add_counter("eaten:" + item_id)
	if overworld != null and overworld.has_method("on_buff_started"):
		overworld.call("on_buff_started", buff, item_id)
	return true


## Active buffs in real seconds (kept in GameState.systems so saves keep them).
class Buffs:
	static func active() -> Dictionary:
		return GameState.system_state("buffs")

	static func start(buff: String, seconds: float) -> void:
		var a := active()
		a[buff] = maxf(float(a.get(buff, 0.0)), seconds)

	static func has(buff: String) -> bool:
		return float(active().get(buff, 0.0)) > 0.0

	static func tick(delta: float) -> void:
		var a := active()
		for k: String in a.keys():
			a[k] = float(a[k]) - delta
			if float(a[k]) <= 0.0:
				a.erase(k)
