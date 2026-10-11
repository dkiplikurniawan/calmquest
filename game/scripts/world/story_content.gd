class_name StoryContent
extends Node
## Spawns the authored points of interest from WorldData (waystones,
## landmarks, locked gates, the Crystal Creek puzzle, the moonlit veil and the
## Moon Altar) and handles the Act 1 story beats that happen at them.
## All progress is written to GameState; QuestManager reacts to it.

signal act1_finale_finished

const FLAG_CREEK_AWAKENED := "creek_awakened"
const FLAG_HEART_RESTORED := "heart_of_lumeria_restored"

var overworld: Overworld
var waystones: Dictionary = {}
var landmarks: Array[Landmark] = []
var gates: Array[WorldGate] = []
var puzzle: CrystalBeamPuzzle
var moon_gate: MoonGate
var altar: MoonAltar
var _ground_layer: Node2D


func build(ow: Overworld) -> void:
	overworld = ow
	_ground_layer = Node2D.new()
	_ground_layer.name = "GroundFeatures"
	_ground_layer.z_index = -5
	ow.add_child(_ground_layer)
	ow.move_child(_ground_layer, ow.entities.get_index())
	for p: Dictionary in ow.world.pois:
		match String(p["kind"]):
			"waystone":
				var w := Waystone.new()
				w.interactable_id = p["id"]
				w.position = p["pos"]
				w.region_name = ow.world.region_name(ow.world.region_at(p["pos"]))
				w.set_state(GameState.waystone_state(p["id"]))
				w.interacted.connect(_on_waystone_interacted)
				ow.entities.add_child(w)
				waystones[String(p["id"])] = w
			"landmark":
				var l := Landmark.new()
				l.landmark_id = p["id"]
				l.style = String(p.get("style", "crystal_spire"))
				l.position = p["pos"]
				ow.entities.add_child(l)
				landmarks.append(l)
			"gate":
				var g := WorldGate.new()
				g.interactable_id = p["id"]
				g.style = String(p.get("style", "cave"))
				g.hint = String(p.get("hint", ""))
				g.position = p["pos"]
				g.interacted.connect(func(_t: Interactable) -> void: ow.hud.show_dialogue(g.hint, 5.0))
				ow.entities.add_child(g)
				gates.append(g)
			"beam_puzzle":
				puzzle = CrystalBeamPuzzle.new()
				puzzle.puzzle_id = p["id"]
				puzzle.position = p["pos"]
				puzzle.solved.connect(_on_puzzle_solved)
				puzzle.changed.connect(func() -> void: AudioManager.play(&"ui_click", 1.3))
				_ground_layer.add_child(puzzle)
			"moon_gate":
				moon_gate = MoonGate.new()
				moon_gate.interactable_id = p["id"]
				moon_gate.size = p.get("size", Vector2(1536, 64))
				moon_gate.position = p["pos"]
				moon_gate.interacted.connect(func(_t: Interactable) -> void: ow.hud.show_dialogue(MoonGate.LOCKED_HINT, 5.0))
				ow.entities.add_child(moon_gate)
			"workbench":
				var wb := Workbench.new()
				wb.interactable_id = p["id"]
				wb.tier = int(p.get("tier", 1))
				wb.position = p["pos"]
				wb.interacted.connect(func(_t: Interactable) -> void: ow.open_inventory(ow.station_tier_here()))
				ow.entities.add_child(wb)
			"lore_note":
				var note := LoreNote.new()
				note.interactable_id = p["id"]
				note.note_id = p["id"]
				note.requires_flag = String(p.get("requires", ""))
				note.position = p["pos"]
				note.interacted.connect(func(_t: Interactable) -> void: ow.open_lore(note.note_id))
				ow.entities.add_child(note)
			"moon_altar":
				altar = MoonAltar.new()
				altar.interactable_id = p["id"]
				altar.position = p["pos"]
				altar.interacted.connect(_on_altar_interacted)
				altar.restoration_finished.connect(_on_altar_restored)
				ow.entities.add_child(altar)
	sync_from_state()


## Applies GameState to the spawned objects (e.g. after a scene reload).
func sync_from_state() -> void:
	for id: String in waystones:
		(waystones[id] as Waystone).set_state(GameState.waystone_state(id))
	var awake := GameState.has_flag(FLAG_CREEK_AWAKENED)
	if awake and moon_gate != null:
		moon_gate.open_gate(true)
	if altar != null:
		altar.ready_to_restore = awake
		if GameState.has_flag(FLAG_HEART_RESTORED):
			altar.set_restored_instant()


func set_night_amount(amount: float) -> void:
	for w: Waystone in waystones.values():
		w.set_night_amount(amount)
	for l in landmarks:
		l.set_night_amount(amount)
	if altar != null:
		altar.set_night_amount(amount)


## Discovery happens by walking near a waystone; landmarks are "seen" from afar.
func update_discovery(player_pos: Vector2) -> void:
	for id: String in waystones:
		var w: Waystone = waystones[id]
		if w.state == "" and player_pos.distance_to(w.position) < Waystone.DISCOVER_DISTANCE:
			if GameState.set_waystone_state(id, GameState.WAYSTONE_DISCOVERED):
				w.set_state(GameState.WAYSTONE_DISCOVERED)
				EventBus.waystone_discovered.emit(id)
				overworld.hud.show_toast("Waystone discovered")
	for l in landmarks:
		if player_pos.distance_to(l.position) < Landmark.SEEN_DISTANCE and GameState.mark_landmark_seen(l.landmark_id):
			EventBus.landmark_seen.emit(l.landmark_id)


## Position of a quest step target id ("heart_tree" or any POI id).
func target_position(target_id: String) -> Vector2:
	if target_id == "heart_tree":
		return overworld.meadow.heart_tree.position
	var poi := overworld.world.poi(target_id)
	return poi.get("pos", Vector2.INF)


func is_near_puzzle(pos: Vector2) -> bool:
	return puzzle != null and pos.distance_to(puzzle.global_position) < 520.0


func nearest_gate_hint(pos: Vector2) -> String:
	for g in gates:
		if pos.distance_to(g.position) < 320.0:
			return g.hint
	if moon_gate != null and not moon_gate.is_open and pos.distance_to(moon_gate.position) < 420.0:
		return MoonGate.LOCKED_HINT
	return ""


# --- Story beats -----------------------------------------------------------------------

func _on_waystone_interacted(target: Interactable) -> void:
	var w := target as Waystone
	if w == null:
		return
	var id := w.interactable_id
	if w.is_restored():
		overworld.open_travel_panel(id)
		return
	var first_ever := GameState.restored_waystones().is_empty()
	GameState.set_waystone_state(id, GameState.WAYSTONE_RESTORED)
	GameState.add_counter("waystones_relit")
	w.set_state(GameState.WAYSTONE_RESTORED)
	w.set_night_amount(overworld.night_amount)
	EventBus.waystone_restored.emit(id)
	AudioManager.play(&"bloom")
	overworld.lumi.react()
	overworld.hud.show_toast("Waystone relit")
	if first_ever:
		overworld.hud.show_dialogue("A relit waystone remembers this place. From any relit waystone, or from the map (M), you can travel back here for free.", 6.0)


func _on_puzzle_solved(puzzle_id: String) -> void:
	GameState.set_flag(FLAG_CREEK_AWAKENED)
	EventBus.puzzle_solved.emit(puzzle_id)
	AudioManager.play(&"restore")
	overworld.lumi.react()
	overworld.hud.show_banner("Crystal Creek is awake!")
	overworld.hud.show_dialogue("The heart crystal is singing! Far to the north-west, the moonlit veil over the sanctuary is fading.", 6.0)
	if moon_gate != null:
		moon_gate.open_gate()
	if altar != null:
		altar.ready_to_restore = true


func _on_altar_interacted(_target: Interactable) -> void:
	var hud := overworld.hud
	if altar.restored:
		hud.show_dialogue("The Heart of Lumeria glows softly. The whole meadow can feel it.", 4.0)
		return
	if not altar.ready_to_restore:
		AudioManager.play(&"soft_deny")
		hud.show_dialogue("The altar is asleep. Crystal Creek's light could wake it.", 4.0)
		return
	altar.play_restoration()
	AudioManager.play(&"restore")
	overworld.lumi.react()
	hud.show_banner("The Heart of Lumeria awakens...")


func _on_altar_restored() -> void:
	GameState.set_flag(FLAG_HEART_RESTORED)
	GameState.set_flag("act1_complete")
	EventBus.story_flag_set.emit(FLAG_HEART_RESTORED)
	overworld.play_world_restoration()
	overworld.hud.show_dialogue("Light is flowing back into Lumeria! The far lands are still misty, but our journey has only begun. Feel free to keep exploring.", 7.0)
	act1_finale_finished.emit()
