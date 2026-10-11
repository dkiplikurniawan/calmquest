class_name CavesController
extends Node
## The Echo Caverns: builds every cave from game/data/caves/caves.json, places
## their entrances in the overworld, and moves the player in and out (with a
## fade and an autosave). Inside, it answers Lumi's hints and reports puzzle
## progress, chests and the caverns' Hearthstone.

const DATA_PATH := "res://game/data/caves/caves.json"
const ZOOM := 1.0

var overworld: Overworld
var caves: Dictionary = {}
var entrances: Dictionary = {}
var _data: Dictionary = {}


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CavesController: could not read %s" % DATA_PATH)
		return {}
	return parsed


func build(ow: Overworld) -> void:
	overworld = ow
	_data = load_data()
	var tile := float(_data.get("tile", 64))
	for c: Dictionary in _data.get("caves", []):
		var cave := CaveLevel.new()
		cave.name = String(c["id"])
		ow.entities.add_child(cave)
		cave.setup(c, tile, ow.player)
		cave.exit_requested.connect(leave)
		cave.progress.connect(_on_progress)
		cave.chest_opened.connect(_on_chest_opened)
		cave.hearthstone_taken.connect(_on_hearthstone)
		cave.lore_requested.connect(func(id: String) -> void: ow.open_lore(id))
		caves[cave.cave_id] = cave
	for p: Dictionary in ow.world.pois_of_kind("cave"):
		var e := CaveEntrance.new()
		e.interactable_id = String(p["id"])
		e.position = p["pos"]
		e.cave_id = String(p.get("cave", ""))
		var cave: CaveLevel = caves.get(e.cave_id)
		e.cave_name = String(cave.data.get("name", "the cave")) if cave != null else "the cave"
		e.interacted.connect(func(_t: Interactable) -> void: enter(e))
		ow.entities.add_child(e)
		entrances[e.cave_id] = e


func cave_for_sublevel(id: String) -> CaveLevel:
	return caves.get(id)


func is_cave(sublevel: String) -> bool:
	return caves.has(sublevel)


func enter(e: CaveEntrance) -> void:
	var cave: CaveLevel = caves.get(e.cave_id)
	if cave == null:
		return
	var needs := String(cave.data.get("needs", ""))
	if not needs.is_empty() and GameState.inventory.count(needs) == 0:
		AudioManager.play(&"soft_deny")
		overworld.hud.show_dialogue(String(cave.data.get("needs_text", "It's too dark to go in.")), 5.0)
		return
	GameState.set_flag("visited_cave:" + cave.cave_id)
	SceneRouter.fade_through(func() -> void:
		cave.refresh_doors(true)
		overworld.enter_sublevel(cave.cave_id, cave.entry_point(), cave.camera_rect(), ZOOM)
		overworld.hud.show_region_title(L.t(String(cave.data.get("name", ""))), L.t("Echo Caverns"))
		SaveManager.autosave("entered %s" % cave.cave_id))


## Back to the cave's entrance in the overworld (always possible).
func leave(cave: CaveLevel) -> void:
	var e: CaveEntrance = entrances.get(cave.cave_id)
	var out: Vector2 = e.global_position + Vector2(0, 110) if e != null else overworld.world.player_spawn
	SceneRouter.fade_through(func() -> void:
		overworld.leave_sublevel(out)
		SaveManager.autosave("left %s" % cave.cave_id))


## Puts the player back into a cave after loading a save made inside it.
func restore_inside(id: String, pos: Variant) -> void:
	var cave: CaveLevel = caves.get(id)
	if cave == null:
		return
	var at := cave.entry_point()
	if pos is Vector2 and cave.camera_rect().has_point(pos):
		at = pos
	overworld.enter_sublevel(id, at, cave.camera_rect(), ZOOM)


func hint_near(world_pos: Vector2, gentle: bool) -> String:
	var cave: CaveLevel = caves.get(overworld.current_sublevel)
	if cave != null:
		var h := cave.hint_near(world_pos, gentle)
		return h if not h.is_empty() else "You can always walk back out the way you came in. Nothing here will be lost."
	for id: String in entrances:
		var e: CaveEntrance = entrances[id]
		if world_pos.distance_to(e.global_position) < 360.0:
			var c: CaveLevel = caves[id]
			var needs := String(c.data.get("needs", ""))
			if not needs.is_empty() and GameState.inventory.count(needs) == 0:
				return String(c.data.get("needs_text", ""))
			return L.t("%s is open. Inside, every puzzle has a reset lever, and I can help if you ask.") % L.t(String(c.data.get("name", "The cave")))
	return ""


func _on_progress(cave: CaveLevel, what: String) -> void:
	var hud := overworld.hud
	if what.begins_with("door_text:"):
		hud.show_dialogue(what.trim_prefix("door_text:"), 5.0)
		return
	overworld.lumi.react()
	match what:
		"bridge":
			hud.show_dialogue("Light pours from the pedestal and settles over the chasm: a bridge of light, solid and safe.", 6.0)
		_:
			if what.begins_with("tuned:"):
				hud.show_dialogue("The tuner hums, the crystal door answers in harmony, and slowly melts open.", 5.0)
			elif what.begins_with("puzzle:"):
				hud.show_toast("Something opened nearby")
	SaveManager.autosave("cave progress")
	EventBus.progress_changed.emit()


func _on_chest_opened(_cave: CaveLevel, rewards: Array) -> void:
	var parts := PackedStringArray()
	for r: Dictionary in rewards:
		parts.append("%d %s" % [int(r.get("qty", 1)), ItemDB.display_name(String(r["item"]))])
	AudioManager.play(&"discover")
	overworld.hud.show_dialogue(L.t("Inside the chest: %s.") % ", ".join(parts), 5.0)
	EventBus.progress_changed.emit()


func _on_hearthstone(cave: CaveLevel, stone: String) -> void:
	overworld.features.grant_hearthstone(stone)
	overworld.hud.show_dialogue("The crystals sing all at once, and the Hearthstone of the Echoes rises warm into your hands.", 6.0)
	cave.hearth.queue_redraw()


## The mouth of a cave in the overworld.
class CaveEntrance extends Interactable:
	var cave_id: String = ""
	var cave_name: String = ""
	var _t: float = 0.0

	func _ready() -> void:
		reach_bonus = 30.0
		var body := StaticBody2D.new()
		for x: float in [-58.0, 58.0]:
			var col := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 28.0
			col.shape = shape
			col.position = Vector2(x, -20)
			body.add_child(col)
		add_child(body)

	func get_prompt() -> String:
		return L.t("Enter %s") % L.t(cave_name)

	func _process(delta: float) -> void:
		super(delta)
		_t += delta * GameSettings.motion_scale()
		if ViewCull.near(global_position):
			queue_redraw()

	func _draw() -> void:
		BiomeDecorArt.shadow(self, 90.0)
		draw_circle(Vector2(0, -34), 80.0, Palette.STONE_DARK)
		draw_circle(Vector2(-48, -10), 34.0, Palette.STONE_DARK.lightened(0.08))
		draw_circle(Vector2(52, -14), 30.0, Palette.STONE_DARK.lightened(0.05))
		draw_set_transform(Vector2(0, -26), 0.0, Vector2(1.0, 1.1))
		draw_circle(Vector2.ZERO, 38.0, Palette.NIGHT_DEEP)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var a := 0.25 + 0.12 * sin(_t * 1.3)
		for i in 3:
			draw_circle(Vector2(-14 + i * 14, -30 + sin(_t + i) * 4.0), 3.0, Palette.with_alpha(Palette.SKY, a + 0.2))
		draw_interaction_cues(44.0, Vector2(0, -16))
