class_name Cosmetics
extends RefCounted
## Cosmetic rewards: cloak colors for the Traveler and glow colors for Lumi.
## Purely visual; earned from villager friendships. Chosen in the Journal's
## Collections page. State: GameState.systems["cosmetics"].

const CLOAKS := {
	"sage": {"name": "Sage cloak", "fill": Color("#8fb996"), "edge": Color("#5e8c6a")},
	"moss": {"name": "Moss cloak (from Bramble)", "fill": Color("#7aa36f"), "edge": Color("#4f7d5f")},
	"sailor": {"name": "Sailor's cloak (from Wren)", "fill": Color("#7fb3cf"), "edge": Color("#4f7f9c")},
}
const GLOWS := {
	"gold": {"name": "Golden glow", "color": Color("#ffe8a3")},
	"moonlight": {"name": "Moonlight glow (from Pip)", "color": Color("#cfd9ff")},
	"mint": {"name": "Mint glow (from Mossa)", "color": Color("#b8f0d8")},
	"ember": {"name": "Ember glow (from Fennel)", "color": Color("#ffc08a")},
	"dusk": {"name": "Dusk glow (every quiet place found)", "color": Color("#f5b8c8")},
}


static func _state() -> Dictionary:
	var s := GameState.system_state("cosmetics")
	if not s.has("unlocked"):
		s["unlocked"] = {"cloak:sage": true, "glow:gold": true}
		s["cloak"] = "sage"
		s["glow"] = "gold"
	return s


static func unlock(key: String) -> bool:
	var u: Dictionary = _state()["unlocked"]
	if u.has(key):
		return false
	u[key] = true
	GameState.add_counter("cosmetics_unlocked")
	return true


static func is_unlocked(key: String) -> bool:
	return (_state()["unlocked"] as Dictionary).has(key)


static func select(key: String) -> bool:
	if not is_unlocked(key):
		return false
	var parts := key.split(":")
	_state()[parts[0]] = parts[1]
	GameState.changed.emit("cosmetics")
	return true


static func current(kind: String) -> String:
	return String(_state().get(kind, "sage" if kind == "cloak" else "gold"))


static func cloak_fill() -> Color:
	return (CLOAKS.get(current("cloak"), CLOAKS["sage"]) as Dictionary)["fill"]


static func cloak_edge() -> Color:
	return (CLOAKS.get(current("cloak"), CLOAKS["sage"]) as Dictionary)["edge"]


static func glow_color() -> Color:
	return (GLOWS.get(current("glow"), GLOWS["gold"]) as Dictionary)["color"]
