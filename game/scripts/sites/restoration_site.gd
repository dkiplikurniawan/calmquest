class_name RestorationSite
extends Interactable
## A place in the world that is restored in a few steps with gathered
## materials (the lighthouse; more sites can be added as data in
## game/data/sites/sites.json). Steps may require earlier steps. Nothing is
## ever lost: a step only uses materials when it can be completed.
## Progress lives in GameState.systems["sites"][site_id][step_id].

signal step_restored(site: RestorationSite, step_id: String)
signal completed(site: RestorationSite)

const DATA_PATH := "res://game/data/sites/sites.json"
const STATE_KEY := "sites"

static var _sites: Dictionary = {}

var site_id: String = ""
var data: Dictionary = {}
## Homes hide the checklist sign once they are built (the house is the reward).
var hide_sign_when_complete: bool = false
var _t: float = 0.0


static func site_data(id: String) -> Dictionary:
	if _sites.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			for s: Dictionary in (parsed as Dictionary).get("sites", []):
				_sites[String(s["id"])] = s
		else:
			push_error("RestorationSite: could not read %s" % DATA_PATH)
	return _sites.get(id, {})


static func progress(id: String) -> Dictionary:
	var all := GameState.system_state(STATE_KEY)
	if not all.has(id):
		all[id] = {}
	return all[id]


static func is_step_done(id: String, step_id: String) -> bool:
	return GameState.system_state(STATE_KEY).has(id) and bool(progress(id).get(step_id, false))


static func is_complete(id: String) -> bool:
	for s: Dictionary in site_data(id).get("steps", []):
		if not is_step_done(id, String(s["id"])):
			return false
	return true


func setup(id: String, pos: Vector2) -> void:
	site_id = id
	interactable_id = "site_" + id
	data = site_data(id)
	position = pos
	reach_bonus = 30.0


func get_prompt() -> String:
	if is_complete(site_id):
		return L.t("Admire %s") % L.t(String(data.get("title", "the site"))).to_lower()
	return L.t(String(data.get("prompt", "Look closer")))


func steps() -> Array:
	return data.get("steps", [])


func step(step_id: String) -> Dictionary:
	for s: Dictionary in steps():
		if String(s["id"]) == step_id:
			return s
	return {}


## "" if the step can be restored now, otherwise a friendly reason.
func check_step(step_id: String) -> String:
	var s := step(step_id)
	if s.is_empty():
		return "Unknown step."
	if is_step_done(site_id, step_id):
		return "Already done."
	for req: String in s.get("requires", []):
		if not is_step_done(site_id, req):
			return L.t("First: %s.") % L.t(String(step(req).get("title", req))).to_lower()
	# A tool step needs the tool in the bag; the tool is never used up.
	var tool := String(s.get("tool", ""))
	if not tool.is_empty() and GameState.inventory.count(tool) == 0:
		return L.t("You'll need a %s for this.") % ItemDB.display_name(tool)
	var missing := PackedStringArray()
	for part: Dictionary in s.get("inputs", []):
		var have := GameState.inventory.count(String(part["item"]))
		if have < int(part["qty"]):
			missing.append(L.t("%d more %s") % [int(part["qty"]) - have, ItemDB.display_name(String(part["item"]))])
	if not missing.is_empty():
		return L.t("Still needed: %s.") % ", ".join(missing)
	return ""


## Restores a step. Returns "" on success, otherwise the reason.
func restore_step(step_id: String) -> String:
	var reason := check_step(step_id)
	if not reason.is_empty():
		return reason
	for part: Dictionary in step(step_id).get("inputs", []):
		GameState.inventory.remove(String(part["item"]), int(part["qty"]))
	progress(site_id)[step_id] = true
	GameState.set_flag("site_%s_%s" % [site_id, step_id])
	step_restored.emit(self, step_id)
	if is_complete(site_id):
		var flag := String(data.get("complete_flag", ""))
		if not flag.is_empty():
			GameState.set_flag(flag)
		completed.emit(self)
	else:
		GameState.changed.emit("site:" + site_id)
	return ""


func _process(delta: float) -> void:
	super(delta)
	_t += delta * GameSettings.motion_scale()
	if ViewCull.near(global_position):
		queue_redraw()


func _draw() -> void:
	if hide_sign_when_complete and is_complete(site_id):
		draw_interaction_cues(28.0, Vector2(0, -30))
		return
	# A small signboard with a checklist; finished sites get a lantern instead.
	BiomeDecorArt.shadow(self, 26.0)
	draw_rect(Rect2(-3, -40, 6, 40), Palette.BARK_DARK)
	draw_rect(Rect2(-24, -58, 48, 26), Palette.CREAM)
	draw_rect(Rect2(-24, -58, 48, 26), Palette.BARK, false, 2.0)
	var done := 0
	for s: Dictionary in steps():
		if is_step_done(site_id, String(s["id"])):
			done += 1
	for i in steps().size():
		var c := Palette.SAGE_DARK if i < done else Palette.STONE_DARK
		draw_rect(Rect2(-18 + i * 10, -50, 7, 7), c)
	if done == steps().size() and done > 0:
		draw_circle(Vector2(0, -64), 8.0 + sin(_t * 2.0), Palette.with_alpha(Palette.GOLD, 0.5))
	draw_interaction_cues(28.0, Vector2(0, -30))
