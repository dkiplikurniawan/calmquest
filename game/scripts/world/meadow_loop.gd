class_name MeadowLoop
extends Node
## The V1 core loop, now one region of the overworld: light motes, the Heart
## Tree, garden beds, hidden details and Lantern Catch (whose shrine moved to
## Firefly Grove). Spawns its objects at MeadowLayout.ORIGIN and handles their
## interactions. Session metrics stay in SessionState, exactly as in V1.

signal tree_restoration_finished
signal changed

const LIGHT_MOTE_SCENE := preload("res://game/scenes/collectibles/light_mote.tscn")
const HIDDEN_DETAIL_SCENE := preload("res://game/scenes/collectibles/hidden_detail.tscn")
const HEART_TREE_SCENE := preload("res://game/scenes/garden/heart_tree.tscn")
const GARDEN_BED_SCENE := preload("res://game/scenes/garden/garden_bed.tscn")
const SHRINE_SCENE := preload("res://game/scenes/minigames/lantern_shrine.tscn")
const DECORATION_SCENE := preload("res://game/scenes/world/decoration.tscn")
## Clearing kept around hand-placed meadow objects when scenery is generated.
const OBJECT_CLEARING := 60.0

var overworld: Overworld
var heart_tree: HeartTree
var shrine: LanternShrine
var beds: Array[GardenBed] = []
var motes: Array[LightMote] = []
var prisms: Array[LightMote] = []
var details: Array[HiddenDetail] = []


## Spawns the meadow content. Returns clear zones ([pos, radius]) so generated
## scenery never covers these objects.
func build(ow: Overworld) -> Array:
	overworld = ow
	var zones: Array = []
	var entities := ow.entities
	for entry: Array in MeadowLayout.LANDMARKS:
		if int(entry[0]) == Decoration.Kind.COTTAGE:
			# The cottage itself is spawned by HomesteadController (restorable home).
			zones.append([MeadowLayout.to_world(entry[1]), 220.0])
			continue
		var d: Decoration = DECORATION_SCENE.instantiate()
		d.kind = int(entry[0]) as Decoration.Kind
		d.size = float(entry[2])
		d.position = MeadowLayout.to_world(entry[1])
		entities.add_child(d)
		zones.append([d.position, 220.0 if d.kind == Decoration.Kind.COTTAGE else 50.0])

	heart_tree = HEART_TREE_SCENE.instantiate()
	heart_tree.interactable_id = "heart_tree"
	heart_tree.position = MeadowLayout.to_world(MeadowLayout.HEART_TREE)
	heart_tree.required_light = SessionState.LIGHTS_FOR_HEART_TREE
	entities.add_child(heart_tree)
	if SessionState.heart_tree_restored:
		heart_tree.set_restored_instant()
	heart_tree.interacted.connect(_on_tree_interacted)
	heart_tree.restoration_finished.connect(func() -> void: tree_restoration_finished.emit())
	zones.append([heart_tree.position + Vector2(0, 70), 280.0])
	zones.append([MeadowLayout.to_world(MeadowLayout.POND_CENTER), 230.0])

	for bed_id: String in MeadowLayout.GARDEN_BEDS:
		var bed: GardenBed = GARDEN_BED_SCENE.instantiate()
		bed.interactable_id = bed_id
		bed.position = MeadowLayout.to_world(MeadowLayout.GARDEN_BEDS[bed_id])
		entities.add_child(bed)
		if SessionState.is_bed_bloomed(bed_id):
			bed.set_bloomed_instant()
		bed.interacted.connect(_on_bed_interacted)
		beds.append(bed)

	var shrine_poi := ow.world.poi("lantern_shrine")
	shrine = SHRINE_SCENE.instantiate()
	shrine.interactable_id = "lantern_shrine"
	shrine.position = shrine_poi.get("pos", Vector2.ZERO)
	entities.add_child(shrine)
	shrine.set_lit_bowls(SessionState.lantern_nights_this_session)
	shrine.interacted.connect(_on_shrine_interacted)

	for id: String in MeadowLayout.LIGHTS:
		if not SessionState.is_collected(id):
			motes.append(_spawn_mote(id, MeadowLayout.LIGHTS[id], LightMote.KIND_LIGHT))
		zones.append([MeadowLayout.to_world(MeadowLayout.LIGHTS[id]), OBJECT_CLEARING])
	for id: String in MeadowLayout.PRISMS:
		if not SessionState.is_collected(id):
			prisms.append(_spawn_mote(id, MeadowLayout.PRISMS[id], LightMote.KIND_PRISM))
		zones.append([MeadowLayout.to_world(MeadowLayout.PRISMS[id]), OBJECT_CLEARING])
	for id: String in MeadowLayout.DISCOVERIES:
		var entry: Array = MeadowLayout.DISCOVERIES[id]
		var detail: HiddenDetail = HIDDEN_DETAIL_SCENE.instantiate()
		detail.interactable_id = id
		detail.kind = int(entry[0]) as HiddenDetail.Kind
		detail.position = MeadowLayout.to_world(entry[1])
		detail.observer = ow.player
		entities.add_child(detail)
		if SessionState.discoveries_this_session.has(id):
			detail.mark_discovered()
		detail.interacted.connect(_on_detail_interacted)
		details.append(detail)
		zones.append([detail.position, OBJECT_CLEARING + 20.0])

	var lc := ow.lantern_catch
	lc.spawn_parent = entities
	lc.anchor_origin = shrine.position
	lc.lantern_interacted.connect(_on_lantern_interacted)
	lc.progress_changed.connect(func(_c: int, _t: int, _b: int) -> void: changed.emit())
	lc.night_ended.connect(_on_night_ended)
	return zones


func _spawn_mote(id: String, local_pos: Vector2, kind: StringName) -> LightMote:
	var mote: LightMote = LIGHT_MOTE_SCENE.instantiate()
	mote.interactable_id = id
	mote.kind = kind
	mote.position = MeadowLayout.to_world(local_pos)
	overworld.entities.add_child(mote)
	mote.interacted.connect(_on_mote_interacted)
	return mote


## Mode parameters for the meadow objects (never spawns or removes anything).
func apply_mode(config: ModeConfig, motion: float) -> void:
	for mote in motes:
		if is_instance_valid(mote):
			mote.apply_config(config, motion)
	var shown := 0
	for prism in prisms:
		if not is_instance_valid(prism) or prism.collected:
			continue
		prism.apply_config(config, motion)
		prism.visible = shown < config.bonus_object_count
		if prism.visible:
			shown += 1
	overworld.lantern_catch.apply_config(config, motion)


func refresh_objects() -> void:
	var s := SessionState
	heart_tree.set_available_light(mini(s.light_balance, s.LIGHTS_FOR_HEART_TREE))
	for bed in beds:
		bed.unlocked = s.heart_tree_restored
		bed.has_light = s.light_balance >= s.LIGHT_PER_GARDEN_BED
		bed.queue_redraw()


func set_night_amount(amount: float) -> void:
	heart_tree.set_night_amount(amount)
	shrine.set_night_amount(amount)
	overworld.lantern_catch.set_night_amount(amount)


## Nearest light (or visible prism) still to collect, or null.
func nearest_light(from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for m in motes + prisms:
		if not is_instance_valid(m) or m.collected or not m.visible:
			continue
		var d := from.distance_to(m.get_interaction_point())
		if d < best_d:
			best_d = d
			best = m
	return best


func nearest_open_bed(from: Vector2) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for b in beds:
		if b.bloomed:
			continue
		var d := from.distance_to(b.get_interaction_point())
		if d < best_d:
			best_d = d
			best = b
	return best


# --- Interaction handlers (same rules as V1) ------------------------------------------

func _on_mote_interacted(target: Interactable) -> void:
	var mote := target as LightMote
	if mote == null:
		return
	if not SessionState.collect_item(mote.interactable_id, mote.kind):
		if SessionState.last_collect_blocked_by_full_bag:
			overworld.hud.show_dialogue("Your bag is full, so the light waits here. Make a little room and come back.", 4.0)
		return
	mote.mark_collected()
	motes.erase(mote)
	prisms.erase(mote)
	AudioManager.play(&"bonus" if mote.kind == LightMote.KIND_PRISM else &"collect", randf_range(0.97, 1.05))
	var ow := overworld
	ow.lumi.react()
	changed.emit()
	if SessionState.lights_collected == 1 and mote.kind == LightMote.KIND_LIGHT and GameSettings.lumi_chatter:
		ow.hud.show_dialogue(LumiGuide.first_light(), 4.0)
	elif not SessionState.heart_tree_restored and SessionState.light_balance == SessionState.LIGHTS_FOR_HEART_TREE:
		ow.hud.show_dialogue(LumiGuide.enough_light())
		ow.hud.show_toast("Enough light for the Heart Tree")


func _on_tree_interacted(_target: Interactable) -> void:
	var ow := overworld
	if SessionState.heart_tree_restored:
		ow.hud.show_dialogue("The Heart Tree hums softly. It's glad you came back.", 3.0)
		return
	if not SessionState.restore_heart_tree():
		AudioManager.play(&"soft_deny")
		ow.hud.show_dialogue(LumiGuide.tree_needs_more(SessionState.lights_needed_for_tree()), 4.0)
		return
	GameState.set_flag("heart_tree_restored")
	heart_tree.play_restoration(GameSettings.motion_scale())
	heart_tree.set_night_amount(ow.night_amount)
	AudioManager.play(&"restore")
	ow.lumi.react()
	ow.hud.show_toast("The Heart Tree is glowing again!")
	changed.emit()


func _on_bed_interacted(target: Interactable) -> void:
	var bed := target as GardenBed
	if bed == null:
		return
	if not SessionState.bloom_bed(bed.interactable_id):
		AudioManager.play(&"soft_deny")
		overworld.hud.show_dialogue(LumiGuide.bed_needs_light(), 4.0)
		return
	bed.play_bloom(GameSettings.motion_scale())
	AudioManager.play(&"bloom")
	overworld.lumi.react()
	changed.emit()
	if SessionState.bloomed_beds.size() == SessionState.GARDEN_BED_COUNT:
		overworld.hud.show_toast("The whole garden is in bloom")


func _on_detail_interacted(target: Interactable) -> void:
	var detail := target as HiddenDetail
	if detail == null:
		return
	var first_time := SessionState.record_discovery(detail.interactable_id)
	detail.mark_discovered()
	overworld.hud.show_dialogue(detail.get_description(), 5.0)
	if first_time:
		AudioManager.play(&"discover")
		overworld.lumi.react()
		overworld.hud.show_toast(L.t("Journal: %s") % L.t(detail.get_title()))


func _on_shrine_interacted(_target: Interactable) -> void:
	var ow := overworld
	var lc := ow.lantern_catch
	if lc.active:
		lc.end_night(false)
		return
	if lc.start_night(SessionState.get_config(), GameSettings.motion_scale()):
		StudyMode.log_event("activity_started", "lantern_catch")
		shrine.night_active = true
		ow.fade_night(true)
		AudioManager.play(&"night")
		ow.hud.show_dialogue(LumiGuide.lantern_night_start(), 7.0)
		changed.emit()


func _on_lantern_interacted(lantern: Lantern) -> void:
	if not SessionState.collect_item(lantern.interactable_id, SessionState.KIND_LANTERN):
		return
	overworld.lantern_catch.register_catch(lantern)
	AudioManager.play(&"lantern", randf_range(0.95, 1.08))
	overworld.lumi.react()
	changed.emit()


func _on_night_ended(completed: bool) -> void:
	StudyMode.log_event("activity_finished", "lantern_catch")
	var ow := overworld
	shrine.night_active = false
	ow.fade_night(false)
	if completed:
		SessionState.complete_lantern_night()
		shrine.set_lit_bowls(SessionState.lantern_nights_this_session)
		ow.hud.show_dialogue(LumiGuide.lantern_night_complete(), 5.0)
		ow.hud.show_toast("Lantern Night complete")
	else:
		ow.hud.show_dialogue(LumiGuide.lantern_night_ended_early(), 4.0)
	changed.emit()
