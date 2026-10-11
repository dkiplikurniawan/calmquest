class_name HomesteadController
extends Node
## The player's home: the cottage (exterior in the meadow, interior as a
## sub-level), its restoration steps, the outdoor homestead build plot and all
## placed decorations. State lives in GameState.systems ("cottage", "decor").

signal cottage_changed
signal sleep_finished

const DATA_PATH := "res://game/data/homestead/cottage.json"
const INTERIOR_ZOOM := 1.15
const SUBLEVEL := "cottage"

var overworld: Overworld
var data: Dictionary = {}
var exterior: CottageExterior
var interior: CottageInterior
var homestead_area: BuildArea
var _decor_nodes: Dictionary = {"interior": [], "homestead": []}


func build(ow: Overworld) -> void:
	overworld = ow
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	if data.is_empty():
		push_error("HomesteadController: could not read %s" % DATA_PATH)
		return
	exterior = CottageExterior.new()
	exterior.interactable_id = "cottage_door"
	exterior.position = MeadowLayout.to_world(MeadowLayout.COTTAGE)
	exterior.interacted.connect(func(_t: Interactable) -> void: enter_cottage())
	ow.entities.add_child(exterior)

	interior = CottageInterior.new()
	interior.setup(data)
	interior.spot_used.connect(try_restore)
	interior.station_used.connect(_on_station)
	interior.exit_requested.connect(exit_cottage)
	ow.entities.add_child(interior)

	var hp := ow.world.poi(String(data["homestead"]["poi"]))
	var size: Vector2 = hp.get("size", Vector2(640, 448))
	var cell := float(data["homestead"]["cell"])
	homestead_area = BuildArea.make("homestead", Vector2(hp["pos"]) - size / 2.0, cell, int(size.x / cell), int(size.y / cell))
	refresh_decor("interior")
	refresh_decor("homestead")


func area_by_id(area_id: String) -> BuildArea:
	return interior.area if area_id == "interior" else homestead_area


## The build area the player is in right now (or null).
func area_here() -> BuildArea:
	if overworld.current_sublevel == SUBLEVEL:
		return interior.area
	if homestead_area != null and homestead_area.rect().grow(96.0).has_point(overworld.player.global_position):
		return homestead_area
	return null


func is_step_done(step_id: String) -> bool:
	return bool(GameState.system_state("cottage").get(step_id, false))


func step_data(step_id: String) -> Dictionary:
	for s: Dictionary in data.get("steps", []):
		if String(s["id"]) == step_id:
			return s
	return {}


## Restores one cottage step if materials and prerequisites are there.
## Returns "" on success or a short, kind explanation.
func try_restore(step_id: String) -> String:
	var step := step_data(step_id)
	if step.is_empty() or is_step_done(step_id):
		return "Already done."
	for req: Variant in step.get("requires", []):
		if not is_step_done(String(req)):
			var msg := L.t("First: %s.") % L.t(String(step_data(String(req)).get("title", req))).to_lower()
			overworld.hud.show_dialogue(msg, 4.0)
			return msg
	var missing := PackedStringArray()
	for part: Dictionary in step.get("inputs", []):
		var have := GameState.inventory.count(String(part["item"])) + GameState.storage.count(String(part["item"]))
		if have < int(part["qty"]):
			missing.append(L.t("%d more %s") % [int(part["qty"]) - have, ItemDB.display_name(String(part["item"]))])
	if not missing.is_empty():
		AudioManager.play(&"soft_deny")
		var msg := L.t("We still need %s.") % ", ".join(missing)
		overworld.hud.show_dialogue(msg, 5.0)
		return msg
	for part: Dictionary in step.get("inputs", []):
		var need := int(part["qty"])
		var from_bag := mini(need, GameState.inventory.count(String(part["item"])))
		GameState.inventory.remove(String(part["item"]), from_bag)
		if need - from_bag > 0:
			GameState.storage.remove(String(part["item"]), need - from_bag)
	GameState.system_state("cottage")[step_id] = true
	GameState.set_flag("cottage_" + step_id)
	GameState.add_counter("cottage_steps")
	if _all_steps_done():
		GameState.set_flag("cottage_restored")
	interior.refresh()
	exterior.refresh()
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_dialogue(L.t(String(step.get("done_text", "Done!"))), 6.0)
	overworld.hud.show_toast(L.t("Done: %s") % L.t(String(step.get("title", "restored"))))
	EventBus.progress_changed.emit()
	cottage_changed.emit()
	return ""


func _all_steps_done() -> bool:
	for s: Dictionary in data.get("steps", []):
		if not is_step_done(String(s["id"])):
			return false
	return true


func _on_station(step_id: String) -> void:
	match step_id:
		"bed":
			sleep()
		"storage_chest":
			overworld.open_storage()
		"bookshelf":
			overworld._open_journal()
		"cooking_pot":
			overworld.open_cooking()
		"hearth":
			overworld.hud.show_dialogue("The fire crackles. Lumi curls up beside it for a moment.", 4.0)
			overworld.lumi.react()


## Sleep until morning: next day, gentle fade, and an autosave.
func sleep() -> void:
	SceneRouter.fade_through(func() -> void:
		TimeManager.sleep_until_morning()
		GameState.add_counter("nights_slept")
		SaveManager.autosave("slept")
		overworld.hud.show_dialogue("Good morning! A new day in Lumeria. (Your journey was saved.)", 5.0)
		sleep_finished.emit())


func enter_cottage() -> void:
	SceneRouter.fade_through(func() -> void:
		overworld.enter_sublevel(SUBLEVEL, interior.entry_point(), interior.camera_rect(), INTERIOR_ZOOM)
		SaveManager.autosave("entered the cottage"))


func exit_cottage() -> void:
	SceneRouter.fade_through(func() -> void:
		overworld.leave_sublevel(exterior.get_interaction_point() + Vector2(0, 50))
		SaveManager.autosave("left the cottage"))


## Rebuilds the decoration nodes of an area from GameState.
func refresh_decor(area_id: String) -> void:
	for n in _decor_nodes[area_id]:
		if is_instance_valid(n):
			n.queue_free()
	_decor_nodes[area_id] = []
	var area := area_by_id(area_id)
	if area == null:
		return
	var parent: Node2D = interior if area_id == "interior" else overworld.entities
	for p: Dictionary in DecorRules.placements(area_id):
		if bool(DecorRules.decor_data(String(p["item"])).get("farm", false)):
			var cell := Vector2i(int(p["x"]), int(p["y"]))
			var r := area.footprint_rect(cell, Vector2i.ONE, 0)
			var plot := FarmPlot.new()
			plot.setup(Farming.plot_key(area_id, cell), Vector2(r.get_center().x, r.end.y), area.cell)
			plot.interacted.connect(func(_t: Interactable) -> void: overworld.use_farm_plot(plot))
			parent.add_child(plot)
			(_decor_nodes[area_id] as Array).append(plot)
			continue
		var node := PlacedDecor.new()
		parent.add_child(node)
		node.setup(area, p)
		if area_id == "interior":
			node.position -= interior.position
		node.set_night_amount(overworld.effective_night)
		(_decor_nodes[area_id] as Array).append(node)


func set_night_amount(amount: float) -> void:
	if exterior != null:
		exterior.set_night_amount(amount)
	for n in _decor_nodes["homestead"]:
		if is_instance_valid(n) and n is PlacedDecor:
			(n as PlacedDecor).set_night_amount(amount)
	for n in _decor_nodes["interior"]:
		if is_instance_valid(n) and n is PlacedDecor:
			(n as PlacedDecor).set_night_amount(1.0 if is_step_done("hearth") else amount)
