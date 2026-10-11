class_name Overworld
extends Node2D
## The open world of Lumeria (V2). Builds the world from WorldData, streams
## scenery chunks around the camera, tracks regions, and connects the player,
## Lumi, the HUD, menus, the meadow loop (MeadowLoop) and the Act 1 story
## points (StoryContent). When a journey opens from the menu it shows the
## optional start cards (mode, mood check); leaving from the pause menu shows
## the optional "Before you go..." panel. In Study Mode the session has a fixed
## length with a gentle end, then the research reflection (unchanged from V1).

const TICK_SECONDS := 0.25
const REGION_CONFIRM_SECONDS := 0.6
const FOG_REVEAL_RADIUS := 650.0
const MARKER_RADIUS_FACTOR := 2.2
const NIGHT_FADE_SECONDS := 2.4
const COMPLETION_DELAY := 1.4
const MODAL_INPUT_BLOCK := 0.25
const RESTORATION_SECONDS := 6.0
const TRAVEL_OFFSET := Vector2(0, 90)
## Gentle mode shows soft markers on at most this many objects besides the target.
const MAX_NEARBY_MARKERS := 2
## Seconds without input before an idle key hint (Settings > Interface: Sometimes).
const IDLE_HINT_SECONDS := 45.0
const IDLE_HINTS := ["hint", "journal", "map", "pause"]
const TARGET_NAMES := {
	"heart_tree": "the Heart Tree", "ws_grove": "the grove's waystone", "lantern_shrine": "the Lantern Shrine",
	"ws_creek": "the creek's waystone", "creek_puzzle": "the crystal puzzle", "moon_altar": "the moon altar",
}

@onready var night_tint: CanvasModulate = $NightTint
@onready var terrain: Terrain = $Terrain
@onready var entities: Node2D = $Entities
@onready var player: Player = $Entities/Player
@onready var camera: WorldCamera = $Entities/Player/Camera2D
@onready var lumi: Lumi = $Lumi
@onready var lantern_catch: LanternCatch = $LanternCatch
@onready var streamer: WorldStreamer = $WorldStreamer
@onready var meadow: MeadowLoop = $MeadowLoop
@onready var story: StoryContent = $StoryContent
@onready var homestead: HomesteadController = $Homestead
@onready var features: RegionFeatures = $Features
@onready var caves: CavesController = $Caves
@onready var village: VillageController = $Village
@onready var hud: Hud = $Hud
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var completion_panel: SessionCompletePanel = $SessionComplete

var world: WorldData
var current_region: String = ""
## Night forced by Lantern Catch (0..1). The effective night also follows the clock.
var night_amount: float = 0.0: set = set_night_amount
var effective_night: float = 0.0
const DUSK_TINT := Color(1.0, 0.86, 0.8)

var _modal_open: bool = false
var _overlay: Control = null
var _tick: float = 0.0
var _region_candidate: String = ""
var _region_timer: float = 0.0
var _night_tween: Tween
var _stub_notice_shown: Dictionary = {}
## The language the HUD texts were last built in (rebuilt when it changes).
var _shown_language: String = ""
## Interior or cave the player is in ("" = the open world).
var current_sublevel: String = ""
## Seconds since the last progress, for Lumi's optional nudges (hint frequency).
var idle_progress_seconds: float = 0.0
## Seconds since the last key or button press (for idle key hints).
var idle_input_seconds: float = 0.0
var _idle_hint_index: int = 0
const NUDGE_SECONDS := {1: 600.0, 2: 300.0, 3: 150.0}


func _ready() -> void:
	SessionState.ensure_session()
	world = WorldData.load_from()
	SaveManager.prepare_world(world.world_size())
	Wellbeing.begin_play()
	terrain.build(world)
	var zones := meadow.build(self)
	story.build(self)
	homestead.build(self)
	features.build(self)
	caves.build(self)
	village.build(self)
	for p in world.pois:
		zones.append([p["pos"], float(p["clear"])])
	_restore_sublevel_from_save()
	streamer.setup(world, entities, zones)
	camera.set_bounds(world.world_rect())
	player.position = world.player_spawn
	_apply_pending_player()
	camera.snap()
	lumi.target = player
	lumi.snap_to_target()
	hud.setup_minimap(world)
	QuestManager.target_resolver = story.target_position
	_connect_signals()
	_apply_mode(SessionState.get_config())
	Weather.always_clear = not GameSettings.weather_effects
	set_night_amount(0.0)
	streamer.load_rect_now(camera.visible_world_rect().grow(WorldStreamer.LOAD_MARGIN))
	QuestManager.refresh()
	_tick_world()
	_refresh_hud()
	_update_music()
	TimeManager.running = true
	SaveManager.runtime_provider = _runtime_state
	SaveManager.set_active(true)
	hud.update_hotbar(GameState.inventory)
	_apply_lighting()
	_begin_start_sequence()


# =============================================================================
# Start cards (mode, mood check) and the welcome
# =============================================================================

## Shows the cards the journey screen asked for, then Lumi's welcome. Opening
## the world any other way (tests, the editor, Study Mode) shows no cards.
func _begin_start_sequence() -> void:
	var cards := SessionState.start_cards
	SessionState.start_cards = {}
	if StudyMode.is_active():
		cards = {}
	if bool(cards.get("mode_card", false)):
		var card := ModeChoiceCard.new()
		_open_overlay(card)
		card.chosen.connect(func(mode_id: StringName) -> void:
			_close_overlay()
			SessionState.select_mode(mode_id)
			_show_mood_check(cards))
		return
	_show_mood_check(cards)


func _show_mood_check(cards: Dictionary) -> void:
	if bool(cards.get("mood_check", false)) and GameSettings.mood_check:
		var card := MoodCheckCard.new()
		_open_overlay(card)
		card.finished.connect(_on_mood_answered)
		return
	_show_welcome()


func _on_mood_answered(face: Variant, dont_ask: bool) -> void:
	_close_overlay()
	if dont_ask:
		GameSettings.set_setting("mood_check", false)
	if face == null:
		_show_welcome()
		return
	Wellbeing.start_face = face
	lumi.react()
	hud.show_dialogue(L.t(Wellbeing.reply_line()), 4.5)
	if not SessionState.welcome_shown:
		get_tree().create_timer(4.6).timeout.connect(func() -> void:
			if is_inside_tree() and not hud.is_dialogue_visible():
				_show_welcome())


func _show_welcome() -> void:
	if not SessionState.welcome_shown:
		SessionState.welcome_shown = true
		if GameSettings.lumi_chatter:
			hud.show_dialogue(LumiGuide.welcome(SessionState.get_config().mode_id, SessionState.LIGHTS_FOR_HEART_TREE), 8.0)


func _connect_signals() -> void:
	meadow.changed.connect(_refresh_hud)
	meadow.tree_restoration_finished.connect(_on_tree_restoration_finished)
	story.act1_finale_finished.connect(_on_act1_finale_finished)
	player.target_changed.connect(_on_target_changed)
	player.footstep.connect(_on_footstep)
	EventBus.quest_step_completed.connect(func(_id: String, _step: int) -> void: AudioManager.play(&"quest_step"))
	player.interaction_attempted.connect(_on_interaction_attempted)
	hud.hint_requested.connect(_request_hint)
	hud.journal_requested.connect(_open_journal)
	hud.pause_requested.connect(_open_pause)
	hud.map_requested.connect(func() -> void:
		if not _modal_open:
			open_map())
	pause_menu.resume_requested.connect(_close_pause)
	pause_menu.mode_requested.connect(_on_mode_requested)
	pause_menu.guidance_toggled.connect(func(on: bool) -> void: SessionState.engine.set_guidance_enabled(on))
	pause_menu.restart_requested.connect(_restart_session)
	pause_menu.finish_requested.connect(func() -> void:
		pause_menu.close()
		_show_completion())
	pause_menu.main_menu_requested.connect(_leave_to_menu)
	pause_menu.leave_requested.connect(func() -> void: _request_leave("menu"))
	pause_menu.quit_requested.connect(func() -> void: _request_leave("quit"))
	pause_menu.save_requested.connect(_manual_save)
	pause_menu.load_requested.connect(_load_slot)
	completion_panel.continue_requested.connect(_close_completion)
	completion_panel.finish_requested.connect(_finish_session)
	SessionState.mode_changed.connect(_on_mode_changed)
	SessionState.assistance_changed.connect(func(_a: Dictionary) -> void: _update_guidance())
	_shown_language = L.current()
	GameSettings.settings_changed.connect(_on_settings_changed)
	QuestManager.quests_changed.connect(_refresh_hud)
	QuestManager.tracked_changed.connect(func(_id: String) -> void: _refresh_hud())
	EventBus.quest_completed.connect(_on_quest_completed)
	streamer.gatherable_interacted.connect(_on_gather)
	GameState.inventory.changed.connect(func() -> void: hud.update_hotbar(GameState.inventory))
	GameState.item_gained.connect(_on_item_gained)
	TimeManager.day_started.connect(_on_day_started)
	EventBus.progress_changed.connect(func() -> void: idle_progress_seconds = 0.0)
	EventBus.toast_requested.connect(func(text: String) -> void: hud.show_toast(text))
	QuestManager.quests_changed.connect(func() -> void: idle_progress_seconds = 0.0)


func _exit_tree() -> void:
	ViewCull.reset()
	TimeManager.running = false
	SaveManager.set_active(false)
	SaveManager.runtime_provider = Callable()


## Position and context to store in a save.
func _runtime_state() -> Dictionary:
	var pos := player.global_position
	return {
		"pos": [pos.x, pos.y],
		"facing": [player.facing.x, player.facing.y],
		"region": current_region,
		"region_name": world.region_name(current_region) if not current_region.is_empty() else "Whispering Meadow",
		"sublevel": current_sublevel,
	}


func _apply_pending_player() -> void:
	var p := SaveManager.pending_player
	if p.has("pos"):
		var pos := Vector2(float(p["pos"][0]), float(p["pos"][1]))
		if world.world_rect().has_point(pos) and not world.is_blocked_at(pos):
			player.position = pos
	if p.has("facing"):
		player.facing = Vector2(float(p["facing"][0]), float(p["facing"][1]))
	SaveManager.pending_player = {}


# =============================================================================
# Per-frame world upkeep
# =============================================================================

func _process(delta: float) -> void:
	ViewCull.view = camera.screen_world_rect()
	hud.set_moving(player.velocity.length() > 20.0)
	hud.set_player_screen_position(player.get_global_transform_with_canvas().origin)
	_update_idle_hint(delta)
	_update_nudge(delta)
	ItemConsumer.Buffs.tick(delta)
	player.speed_bonus = 1.15 if ItemConsumer.Buffs.has("easy_stroll") else 1.0
	_apply_lighting()
	_tick += delta
	_update_region(delta)
	if StudyMode.session_running:
		_update_study_end()
	if _tick >= TICK_SECONDS:
		_tick = 0.0
		_tick_world()


func _update_music() -> void:
	MusicManager.set_context(current_region, current_sublevel, effective_night, village.finale_running, Weather.world_today() == "rain")


func _tick_world() -> void:
	var pos := player.global_position
	_update_music()
	streamer.update_view(camera.visible_world_rect())
	hud.set_clock(TimeManager.clock_text(), TimeManager.is_night())
	hud.set_build_hint(homestead.area_here() != null)
	if not current_sublevel.is_empty():
		hud.set_compass(false, 0.0, "")
		hud.update_minimap(false, pos, player.facing, Vector2.INF)
		_update_markers()
		if player.current_target != null:
			hud.set_prompt(player.current_target.get_prompt())
		return
	GameState.reveal(pos, FOG_REVEAL_RADIUS * (1.5 if ItemConsumer.Buffs.has("warm_glow") else 1.0))
	story.update_discovery(pos)
	_update_guidance()
	_update_markers()
	_update_compass()
	hud.update_minimap(GameSettings.show_minimap, pos, player.facing, QuestManager.tracked_target_position())
	if player.current_target != null:
		hud.set_prompt(player.current_target.get_prompt())
	hud.set_clock(TimeManager.clock_text(), TimeManager.is_night())


## Region changes are confirmed after a short delay so walking along a border
## doesn't flicker titles, zoom or music.
func _update_region(delta: float) -> void:
	if not current_sublevel.is_empty():
		return
	var region := world.region_at(player.global_position)
	if world.is_blocked_at(player.global_position) or region == current_region:
		_region_candidate = ""
		return
	if region != _region_candidate:
		_region_candidate = region
		_region_timer = 0.0
		return
	_region_timer += delta
	if _region_timer >= REGION_CONFIRM_SECONDS or current_region.is_empty():
		_enter_region(region)


func _enter_region(region: String) -> void:
	current_region = region
	_region_candidate = ""
	var first := GameState.mark_region_visited(region)
	var info := world.region_info(region)
	camera.set_target_zoom(float(info.get("zoom", WorldCamera.DEFAULT_ZOOM)))
	EventBus.region_entered.emit(region, first)
	if first and not world.is_boundary_region(region):
		Wellbeing.note_new_place(String(info.get("name", region)))
	if GameSettings.region_titles == 1 or (GameSettings.region_titles == 0 and first):
		hud.show_region_title(String(info.get("name", region)), String(info.get("subtitle", "")))
	if first and String(info.get("status", "")) == "stub" and not _stub_notice_shown.has(region):
		_stub_notice_shown[region] = true
		hud.show_dialogue(L.t("%s is still waking up. There will be more to discover here in a future update, but you're welcome to wander.") % L.t(String(info.get("name", region))), 5.0)
	elif first and region != "whispering_meadow":
		lumi.react()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton:
		idle_input_seconds = 0.0
	if _modal_open:
		return
	if event.is_action_pressed(InputSetup.PAUSE):
		get_viewport().set_input_as_handled()
		_open_pause()
	elif event.is_action_pressed(InputSetup.HINT):
		get_viewport().set_input_as_handled()
		_request_hint()
	elif event.is_action_pressed(InputSetup.JOURNAL):
		get_viewport().set_input_as_handled()
		_open_journal()
	elif event.is_action_pressed(InputSetup.MAP):
		get_viewport().set_input_as_handled()
		open_map()
	elif event.is_action_pressed(InputSetup.PIN):
		get_viewport().set_input_as_handled()
		GameState.add_pin(player.global_position)
		hud.show_toast("Pin placed on your map")
	elif event.is_action_pressed(InputSetup.INVENTORY):
		get_viewport().set_input_as_handled()
		open_inventory(station_tier_here())
	elif event.is_action_pressed(InputSetup.BUILD):
		get_viewport().set_input_as_handled()
		open_build_mode()
	elif event.is_action_pressed(InputSetup.USE_ITEM):
		get_viewport().set_input_as_handled()
		use_selected_item()
	elif event.is_action_pressed(InputSetup.HOTBAR_NEXT) or event.is_action_pressed(InputSetup.HOTBAR_PREV):
		get_viewport().set_input_as_handled()
		var step := 1 if event.is_action_pressed(InputSetup.HOTBAR_NEXT) else -1
		hud.select_hotbar(posmod(hud.selected_hotbar + step, Inventory.HOTBAR_SIZE))
	else:
		for i in Inventory.HOTBAR_SIZE:
			if event.is_action_pressed(StringName(InputSetup.HOTBAR_PREFIX + str(i + 1))):
				get_viewport().set_input_as_handled()
				hud.select_hotbar(i)
				break


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree() and not _modal_open:
		_open_pause()


# =============================================================================
# Modes, guidance and HUD
# =============================================================================

func _apply_mode(config: ModeConfig) -> void:
	var motion := GameSettings.motion_scale()
	player.apply_config(config, motion)
	lumi.apply_config(config, motion)
	meadow.apply_mode(config, motion)
	streamer.set_sway_intensity(motion)
	terrain.set_motion(motion)
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		(node as Interactable).animation_intensity = config.animation_intensity * motion
	hud.set_mode(config.display_name)
	_update_guidance()


func _on_mode_changed(config: ModeConfig, _reason: StringName) -> void:
	_apply_mode(config)
	pause_menu.sync(config.mode_id, SessionState.engine.guidance_enabled)
	hud.show_toast(L.t("%s mode") % L.t(config.display_name))


func _on_mode_requested(mode_id: StringName) -> void:
	SessionState.select_mode(mode_id, AdaptiveComfortEngine.REASON_PLAYER_CHOICE)
	pause_menu.sync(SessionState.engine.get_mode_id(), SessionState.engine.guidance_enabled)


func _on_settings_changed() -> void:
	Weather.always_clear = not GameSettings.weather_effects
	SessionState.set_auto_assist(GameSettings.adaptive_assistance)
	_apply_mode(SessionState.get_config())
	_update_compass()
	if L.current() != _shown_language:
		_shown_language = L.current()
		_refresh_hud()
		hud.set_clock(TimeManager.clock_text(), TimeManager.is_night())


## Where the guiding glow and Lumi's hints point, in priority order.
func guidance_target() -> Interactable:
	if lantern_catch.active:
		var nearest: Interactable = null
		var best := INF
		for l in lantern_catch.get_remaining():
			var d := player.global_position.distance_to(l.get_interaction_point())
			if d < best:
				best = d
				nearest = l
		return nearest
	var target_id := QuestManager.tracked_target_id()
	if target_id == "heart_tree" and not SessionState.heart_tree_restored:
		return meadow.heart_tree if SessionState.can_restore_heart_tree() else meadow.nearest_light(player.global_position)
	if target_id.is_empty() and SessionState.heart_tree_restored and SessionState.light_balance > 0:
		return meadow.nearest_open_bed(player.global_position)
	return null


func guidance_position() -> Vector2:
	var t := guidance_target()
	if t != null:
		return t.get_interaction_point()
	return QuestManager.tracked_target_position()


func _update_guidance() -> void:
	var arrow := player.get_node("GuidanceArrow") as GuidanceArrow
	arrow.active = SessionState.engine.guidance_enabled
	var pos := guidance_position()
	if pos == Vector2.INF:
		arrow.clear_target()
	else:
		arrow.set_target(pos)


## Gentle mode's soft markers: only on the few nearest objects within reach
## (the golden ring is always only on the one the player would use).
func _update_markers() -> void:
	var config := SessionState.get_config()
	var limit := config.interaction_radius * MARKER_RADIUS_FACTOR
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		var gap := player.global_position.distance_to(it.get_interaction_point()) - it.reach_bonus
		if config.show_nearby_markers and gap < limit and it.can_interact() and it != player.current_target:
			candidates.append([gap, it])
		else:
			it.set_marker_visible(false)
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in candidates.size():
		(candidates[i][1] as Interactable).set_marker_visible(i < MAX_NEARBY_MARKERS)


func _update_compass() -> void:
	var target := guidance_position()
	if not GameSettings.show_compass or target == Vector2.INF:
		hud.set_compass(false, 0.0, "")
		return
	var delta := target - player.global_position
	if delta.length() < 140.0:
		hud.set_compass(false, 0.0, "")
		return
	var what := L.t(String(TARGET_NAMES.get(QuestManager.tracked_target_id(), "your goal")))
	if guidance_target() is LightMote:
		what = L.t("a light")
	elif guidance_target() is Lantern:
		what = L.t("a lantern")
	hud.set_compass(true, delta.angle(), "%s - %s" % [what.capitalize(), LumiGuide.distance_phrase(delta.length())])


func _refresh_hud() -> void:
	meadow.refresh_objects()
	if lantern_catch.active:
		hud.set_objective("Lantern Night: catch the drifting lanterns")
		var text := L.t("Lanterns %d / %d") % [lantern_catch.caught, lantern_catch.target_count]
		if lantern_catch.bonus_caught > 0:
			text += L.t("  (+%d golden)") % lantern_catch.bonus_caught
		hud.set_progress(text, LightIcon.Style.LANTERN)
		return
	if not QuestManager.tracked_id.is_empty():
		hud.set_objective(QuestManager.tracked_title())
		hud.set_progress(QuestManager.tracked_step_text(), LightIcon.Style.LIGHT)
		return
	hud.set_objective("Free exploration")
	if GameState.has_flag("act3_complete"):
		hud.set_progress("Lumeria is bright again. Wander wherever you like.", LightIcon.Style.LIGHT)
	elif QuestManager.is_act_complete(1):
		hud.set_progress("Choose a quest to follow in the Journal (J), or simply wander.", LightIcon.Style.LIGHT)
	else:
		hud.set_progress(L.t("Light carried: %d") % SessionState.light_balance, LightIcon.Style.LIGHT)


# =============================================================================
# Interactions, hints and story beats
# =============================================================================

func _on_footstep() -> void:
	if GameSettings.footsteps:
		AudioManager.play_footstep(Footsteps.surface_at(world, player.global_position, current_sublevel))


func _on_target_changed(target: Interactable) -> void:
	hud.set_prompt("" if target == null else target.get_prompt())
	if target != null:
		maybe_key_hint("interact")


# =============================================================================
# Contextual key hints (Settings > Interface > Show control hints)
# =============================================================================

## Shows a key hint the first time a control becomes useful in this journey
## (only when the setting is "Sometimes"; "Always" shows a strip instead).
func maybe_key_hint(id: String) -> bool:
	if GameSettings.control_hints != GameSettings.HINTS_SOMETIMES:
		return false
	var seen := GameState.system_state("ui_hints")
	if seen.has(id):
		return false
	if hud.show_key_hint(id):
		seen[id] = true
		return true
	return false


## After a while without any input, one gentle reminder (rotating).
func _update_idle_hint(delta: float) -> void:
	idle_input_seconds += delta
	if idle_input_seconds < IDLE_HINT_SECONDS or GameSettings.control_hints != GameSettings.HINTS_SOMETIMES:
		return
	idle_input_seconds = 0.0
	if hud.is_dialogue_visible():
		return
	hud.show_key_hint(IDLE_HINTS[_idle_hint_index % IDLE_HINTS.size()])
	_idle_hint_index += 1


func _on_interaction_attempted(success: bool, nearest_distance: float) -> void:
	var result := SessionState.engine.register_interaction_attempt(success, nearest_distance)
	if result["show_help"]:
		player.show_reach_ring()
		hud.show_dialogue(LumiGuide.reach_help())


func _request_hint() -> void:
	var result := SessionState.engine.register_hint_request()
	StudyMode.log_event("hint_requested", current_region)
	var pos := player.global_position
	var gentle := SessionState.get_config().mode_id == AdaptiveComfortEngine.MODE_GENTLE
	var gate_hint := story.nearest_gate_hint(pos)
	var feature_hint := features.hint_near(pos, gentle) if current_sublevel.is_empty() else ""
	if feature_hint.is_empty() and current_sublevel.is_empty():
		feature_hint = village.hint_near(pos)
	var cave_hint := caves.hint_near(pos, gentle)
	if not cave_hint.is_empty() and (caves.is_cave(current_sublevel) or feature_hint.is_empty()):
		feature_hint = cave_hint
	if story.is_near_puzzle(pos) and not story.puzzle.is_solved:
		hud.show_dialogue(story.puzzle.next_hint(gentle), 7.0)
	elif not feature_hint.is_empty():
		hud.show_dialogue(feature_hint, 7.0)
	elif not gate_hint.is_empty():
		hud.show_dialogue(gate_hint, 6.0)
	else:
		var target := guidance_target()
		var target_pos := guidance_position()
		if target_pos == Vector2.INF:
			hud.show_dialogue("There's nothing urgent at all. Wander wherever you like, or open the map with M.")
		else:
			var what := L.t(String(TARGET_NAMES.get(QuestManager.tracked_target_id(), "something special")))
			if target is LightMote:
				what = L.t("a light")
			elif target is Lantern:
				what = L.t("a lantern")
			elif target is GardenBed:
				what = L.t("a garden bed")
			hud.show_dialogue(LumiGuide.hint_for_target(pos, target_pos, what))
	lumi.react()
	if result["guidance_enabled_now"]:
		hud.show_toast("Guiding glow on")
	_update_guidance()


func _on_tree_restoration_finished() -> void:
	hud.show_dialogue(L.t(LumiGuide.tree_restored()) + L.t(" Lumi senses old lantern light to the north-west, in Firefly Grove."))
	meadow.heart_tree.set_night_amount(night_amount)
	# The "Ready to rest for now?" panel no longer appears by itself (0.4.0):
	# players leave from the pause menu, and study sessions have a fixed length.


func _on_act1_finale_finished() -> void:
	pass


func _on_quest_completed(quest_id: String) -> void:
	var title := String(QuestManager.book.get_quest(quest_id).get("title", ""))
	if not title.is_empty():
		hud.show_toast(L.t("Quest complete: %s") % L.t(title))


func play_world_restoration() -> void:
	var tween := create_tween()
	tween.tween_method(terrain.set_restoration, 0.0, 1.0, RESTORATION_SECONDS * maxf(GameSettings.motion_scale(), 0.5))


# =============================================================================
# Day, night and Lantern Night
# =============================================================================

func set_night_amount(value: float) -> void:
	night_amount = clampf(value, 0.0, 1.0)
	if is_node_ready():
		_apply_lighting()


## Combines the clock (dawn/day/dusk/night) with Lantern Night and applies the
## tint and the night lights. Night is purely visual: it is always safe.
func _apply_lighting() -> void:
	if current_sublevel == HomesteadController.SUBLEVEL:
		var warm := homestead.is_step_done("hearth")
		night_tint.color = Color(1.0, 0.94, 0.86) if warm else Color(0.8, 0.8, 0.88)
		homestead.set_night_amount(1.0 - TimeManager.daylight())
		return
	if caves.is_cave(current_sublevel):
		# Caves are always dim; Lumi's glow and lit braziers light the way.
		night_tint.color = Color(0.66, 0.66, 0.8)
		if effective_night < 0.99:
			effective_night = 1.0
			lumi.set_night_amount(1.0)
		return
	var clock_night := 1.0 - TimeManager.daylight()
	var night := maxf(clock_night, night_amount)
	var twilight := TimeManager.twilight() * (1.0 - night_amount)
	night_tint.color = Palette.DAY_TINT.lerp(DUSK_TINT, twilight * 0.8).lerp(Palette.NIGHT_TINT, night)
	if absf(night - effective_night) < 0.004:
		return
	effective_night = night
	lumi.set_night_amount(night)
	meadow.set_night_amount(night)
	story.set_night_amount(night)
	homestead.set_night_amount(night)
	features.set_night_amount(night)
	village.set_night_amount(night)


func fade_night(to_night: bool) -> void:
	if _night_tween != null:
		_night_tween.kill()
	_night_tween = create_tween()
	_night_tween.tween_property(self, "night_amount", 1.0 if to_night else 0.0, NIGHT_FADE_SECONDS * maxf(GameSettings.motion_scale(), 0.5)).set_trans(Tween.TRANS_SINE)


# =============================================================================
# Gathering, items and crafting
# =============================================================================

func _on_gather(g: Gatherable) -> void:
	if g == null or g.gathered:
		return
	if GameState.give_item(g.item_id, 1) > 0:
		AudioManager.play(&"soft_deny")
		hud.show_dialogue(L.t("Your bag is full. You can make room, or craft a bag to carry more. The %s will wait here.") % ItemDB.display_name(g.item_id), 5.0)
		return
	streamer.remove_object(g.chunk, String(g.get_meta(WorldStreamer.OBJECT_ID_META)), g.respawn_days)
	AudioManager.play(&"gather", randf_range(0.95, 1.1))
	EventBus.progress_changed.emit()


func _on_item_gained(item_id: String, qty: int) -> void:
	hud.show_pickup(item_id, qty)
	if item_id != SessionState.LUMA_LIGHT:
		if ItemDB.category(item_id) == "food":
			maybe_key_hint("use")
		else:
			maybe_key_hint("bag")
	if GameState.counter("obtained:" + item_id) == qty and item_id != SessionState.LUMA_LIGHT:
		lumi.react()
		hud.show_toast(L.t("New: %s") % ItemDB.display_name(item_id))


func on_buff_started(buff: String, item_id: String) -> void:
	AudioManager.play(&"bloom")
	lumi.react()
	hud.show_dialogue("%s  %s" % [ItemDB.display_name(item_id), L.t(String(ItemConsumer.BUFFS.get(buff, "")))], 4.0)


## Highest crafting tier available here (0 = by hand).
func station_tier_here() -> int:
	var tier := 0
	for node in get_tree().get_nodes_in_group(&"crafting_stations"):
		var station := node as Workbench
		if station != null and player.global_position.distance_to(station.global_position) < Workbench.NEAR_DISTANCE:
			tier = maxi(tier, station.tier)
	return tier


func storage_nearby() -> bool:
	return current_sublevel == HomesteadController.SUBLEVEL and homestead.is_step_done("storage_chest")


func open_inventory(tier: int) -> void:
	if _modal_open:
		return
	var panel := InventoryPanel.new()
	_open_overlay(panel)
	panel.use_storage = storage_nearby()
	panel.setup(tier)
	panel.closed.connect(_close_overlay)
	panel.crafted.connect(func(_id: String) -> void: EventBus.progress_changed.emit())


func open_storage() -> void:
	if _modal_open:
		return
	var panel := StoragePanel.new()
	_open_overlay(panel)
	panel.setup()
	panel.closed.connect(_close_overlay)


func open_cooking() -> void:
	if _modal_open:
		return
	var panel := CookingPanel.new()
	_open_overlay(panel)
	panel.setup(storage_nearby())
	panel.closed.connect(_close_overlay)


func open_build_mode() -> void:
	if _modal_open:
		return
	var area := homestead.area_here()
	if area == null:
		hud.show_dialogue("Build mode (B) works inside your cottage and on the homestead plot south-west of the meadow waystone.", 5.0)
		return
	var panel := BuildModePanel.new()
	_open_overlay(panel)
	panel.setup(self, area)
	panel.closed.connect(func() -> void:
		_close_overlay()
		homestead.refresh_decor(area.id))


## Enters an interior or cave sub-level (positioned outside the world map).
func enter_sublevel(id: String, pos: Vector2, bounds: Rect2, zoom: float) -> void:
	current_sublevel = id
	camera.set_bounds(bounds)
	camera.set_target_zoom(zoom)
	player.global_position = pos
	player.velocity = Vector2.ZERO
	camera.snap()
	lumi.snap_to_target()
	features.on_player_teleported()
	hud.set_compass(false, 0.0, "")
	_tick_world()


func leave_sublevel(pos: Vector2) -> void:
	current_sublevel = ""
	camera.set_bounds(world.world_rect())
	teleport_to(pos)


func _restore_sublevel_from_save() -> void:
	var saved_sub := String(SaveManager.pending_player.get("sublevel", ""))
	if caves.is_cave(saved_sub):
		var p: Array = SaveManager.pending_player.get("pos", [])
		var pos: Variant = Vector2(float(p[0]), float(p[1])) if p.size() == 2 else null
		SaveManager.pending_player.erase("pos")
		caves.call_deferred("restore_inside", saved_sub, pos)
		return
	if saved_sub == HomesteadController.SUBLEVEL:
		SaveManager.pending_player.erase("pos")
		call_deferred("enter_sublevel", HomesteadController.SUBLEVEL, homestead.interior.entry_point(), homestead.interior.camera_rect(), HomesteadController.INTERIOR_ZOOM)


## A small modal choice; `on_choice` receives the chosen id.
func open_choice(title: String, text: String, options: Array, on_choice: Callable) -> void:
	if _modal_open:
		return
	var panel := ChoicePanel.new()
	_open_overlay(panel)
	panel.setup(title, text, options)
	panel.chosen.connect(func(id: String) -> void: on_choice.call_deferred(id))
	panel.closed.connect(_close_overlay)


func open_site_panel(site: RestorationSite) -> void:
	if _modal_open:
		return
	var panel := SitePanel.new()
	_open_overlay(panel)
	panel.setup(site)
	panel.closed.connect(func() -> void:
		_close_overlay()
		EventBus.progress_changed.emit())


func open_villager_panel(id: String) -> void:
	if _modal_open:
		return
	var panel := VillagerPanel.new()
	_open_overlay(panel)
	panel.setup(id)
	(village.villagers[id] as Villager).cheer()
	panel.closed.connect(func() -> void:
		_close_overlay()
		QuestManager.request_refresh())


func open_request_board() -> void:
	if _modal_open:
		return
	var panel := RequestBoardPanel.new()
	_open_overlay(panel)
	panel.setup()
	panel.closed.connect(_close_overlay)


func show_finale_panel() -> void:
	if _modal_open:
		return
	var panel := FinalePanel.new()
	_open_overlay(panel)
	panel.setup()
	panel.closed.connect(_close_overlay)


func open_lore(note_id: String) -> void:
	if _modal_open:
		return
	var first_read := not GameState.lore_read.has(note_id)
	var learned := GameState.learn_recipes_for("note:" + note_id) if first_read else PackedStringArray()
	GameState.read_lore(note_id)
	if first_read:
		# Some notes have something tucked inside (e.g. the gardener's seeds).
		for g: Dictionary in LoreNote.note_data(note_id).get("gives", []):
			var left := GameState.give_item(String(g["item"]), int(g.get("qty", 1)))
			if left > 0:
				GameState.storage.add(String(g["item"]), left)
	var panel := LorePanel.new()
	_open_overlay(panel)
	panel.setup(note_id, learned)
	panel.closed.connect(_close_overlay)
	AudioManager.play(&"discover")
	EventBus.progress_changed.emit()


## Lumi's optional nudge toward the followed quest after a long while without
## progress (Settings: hint frequency; by default Helpful in Gentle mode, Rare
## in Playful). Never during menus or dialogue, never more than once per wait,
## and only with the quest's own hint lines, so no secrets are spoiled.
func _update_nudge(delta: float) -> void:
	if _modal_open or not current_sublevel.is_empty():
		return
	idle_progress_seconds += delta
	var freq := GameSettings.effective_hint_frequency(SessionState.get_config().mode_id)
	if freq <= 0 or idle_progress_seconds < float(NUDGE_SECONDS.get(freq, 300.0)):
		return
	idle_progress_seconds = 0.0
	if QuestManager.tracked_id.is_empty() or hud.is_dialogue_visible():
		return
	var hint := QuestManager.quest_hint(QuestManager.tracked_id)
	if hint.is_empty():
		return
	lumi.react()
	hud.show_dialogue("(%s) %s" % [QuestManager.tracked_step_text(), hint], 7.0)
	# Lumi has a hint: remind the player which key asks for more.
	if GameSettings.control_hints == GameSettings.HINTS_SOMETIMES:
		hud.show_key_hint("hint")


## A new morning: announce the weather once (rain waters every crop).
func _on_day_started(_day: int) -> void:
	var kind := Weather.today()
	if not current_sublevel.is_empty() and kind != "rain":
		return
	if kind == "rain":
		hud.show_toast("Gentle rain today: your crops are watered")
	elif kind != "clear":
		hud.show_toast(L.t(Weather.describe(kind)))


## E on a garden plot: plant, water or harvest.
func use_farm_plot(plot: FarmPlot) -> void:
	var key := plot.plot_key
	if not Farming.has_crop(key):
		var seeds := Farming.seeds_in_bag()
		if seeds.is_empty():
			hud.show_dialogue("No seeds in your bag. The gardener's note near the cottage had some, and seeds sometimes grow wild in the meadow, grove, pinewood and sanctuary.", 6.0)
			return
		if seeds.size() == 1:
			_plant(plot, seeds[0])
			return
		var options := []
		for s in seeds:
			options.append([s, "%s (x%d)" % [ItemDB.display_name(s), GameState.inventory.count(s)]])
		open_choice("Plant seeds", "What would you like to grow here?", options, func(seed_id: String) -> void: _plant(plot, seed_id))
		return
	if Farming.is_ripe(key):
		var r := Farming.harvest(key)
		if not bool(r["ok"]):
			hud.show_dialogue(String(r["reason"]), 4.0)
			return
		var parts := PackedStringArray()
		for it: Array in r["items"]:
			parts.append("%d %s" % [int(it[1]), ItemDB.display_name(String(it[0]))])
		AudioManager.play(&"bloom")
		lumi.react()
		hud.show_dialogue(L.t("Harvested: %s.") % ", ".join(parts), 4.0)
		plot.queue_redraw()
		EventBus.progress_changed.emit()
		return
	if Farming.is_watered_today(key):
		var why := L.t("the rain watered it") if Weather.is_raining() else L.t("it's watered")
		hud.show_dialogue(L.t("Growing nicely (%d of %d days), and %s for today. Crops never wilt, so take your time.") % [Farming.growth_days(key), Farming.days_needed(key), why], 4.0)
		return
	if GameState.inventory.count("watering_can") == 0:
		hud.show_dialogue("It would like some water. A watering can (the gardener's note explains it) or a rainy day will do.", 5.0)
		return
	Farming.water(key)
	AudioManager.play(&"collect", 0.8, -4.0)
	hud.show_toast("Watered")
	plot.queue_redraw()
	EventBus.progress_changed.emit()


func _plant(plot: FarmPlot, seed_id: String) -> void:
	if Farming.plant(plot.plot_key, seed_id):
		AudioManager.play(&"bloom", 1.3)
		var c := Farming.crop_data(seed_id)
		hud.show_dialogue(L.t("You plant the %s. Water it each day; it will be ready after %d watered days.") % [ItemDB.display_name(seed_id), int(c.get("days", 3))], 5.0)
		plot.queue_redraw()
		EventBus.progress_changed.emit()


## E at fishing ripples.
func open_fishing(spot: FishingSpot) -> void:
	if _modal_open:
		return
	if GameState.inventory.count("fishing_rod") == 0:
		hud.show_dialogue("Fish are rising here. A fishing rod (the fisher's notes by the creek explain how) would let you try.", 5.0)
		return
	var panel := FishingPanel.new()
	panel.player_node = player
	_open_overlay(panel)
	panel.setup(spot, world.region_at(spot.global_position), SessionState.get_config().mode_id)
	panel.closed.connect(func() -> void:
		_close_overlay()
		QuestManager.refresh())
	panel.caught.connect(func(id: String, result: Dictionary) -> void:
		if bool(result.get("first", false)):
			lumi.react()
		EventBus.progress_changed.emit())


## Uses the selected hotbar item. Food arrives with cooking (M7); tools are
## used automatically where they matter, so here they only explain themselves.
func use_selected_item() -> void:
	var slots := GameState.inventory.hotbar()
	var s: Dictionary = slots[hud.selected_hotbar]
	if s.is_empty():
		hud.show_toast("Nothing in this slot")
		return
	var id := String(s["id"])
	if ItemConsumer.can_use(id):
		ItemConsumer.use(id, self)
	else:
		hud.show_dialogue("%s: %s" % [ItemDB.display_name(id), ItemDB.uses(id)], 4.0)


# =============================================================================
# Travel, map and menus
# =============================================================================

## Moves the player to a relit waystone behind a fade. Always free.
func travel_to(waystone_id: String) -> void:
	if GameState.waystone_state(waystone_id) != GameState.WAYSTONE_RESTORED:
		return
	var destination: Vector2 = world.poi(waystone_id).get("pos", player.global_position)
	SceneRouter.fade_through(func() -> void: teleport_to(destination + TRAVEL_OFFSET))
	EventBus.player_traveled.emit(waystone_id)


## Instant move (used by travel and tests): builds nearby chunks first.
func teleport_to(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	camera.snap()
	lumi.snap_to_target()
	streamer.load_rect_now(Rect2(pos - Vector2(1100, 700), Vector2(2200, 1400)))
	_region_candidate = ""
	_enter_region(world.region_at(pos))
	features.on_player_teleported()
	_tick_world()


func open_travel_panel(from_id: String) -> void:
	if _modal_open:
		return
	var panel := TravelPanel.new()
	_open_overlay(panel)
	panel.setup(world, from_id)
	panel.travel_requested.connect(travel_to)
	panel.closed.connect(_close_overlay)


func open_map() -> void:
	if _modal_open:
		return
	var panel := MapPanel.new()
	_open_overlay(panel)
	panel.setup(world, player.global_position, player.facing, QuestManager.tracked_target_position())
	panel.travel_requested.connect(func(id: String) -> void: travel_to.call_deferred(id))
	panel.closed.connect(_close_overlay)


func _open_overlay(panel: Control) -> void:
	_set_modal(true)
	_overlay = panel
	hud.add_overlay(panel)
	hud.set_prompt("")
	var activity := StudyMode.activity_for(panel)
	if not activity.is_empty():
		StudyMode.log_event("activity_started", activity)
		panel.tree_exited.connect(func() -> void: StudyMode.log_event("activity_finished", activity))


func _close_overlay() -> void:
	_overlay = null
	_set_modal(false)
	_on_target_changed(player.current_target if is_instance_valid(player.current_target) else null)


func _set_modal(open: bool) -> void:
	_modal_open = open
	get_tree().paused = open
	if not open:
		player.block_input(MODAL_INPUT_BLOCK)


func _open_pause() -> void:
	if _modal_open or SceneRouter.is_busy():
		return
	_set_modal(true)
	pause_menu.open(SessionState.engine.get_mode_id(), SessionState.engine.guidance_enabled)


func _close_pause() -> void:
	pause_menu.close()
	_set_modal(false)


func _open_journal() -> void:
	if _modal_open:
		return
	var journal := JournalPanel.new()
	_open_overlay(journal)
	journal.closed.connect(_close_overlay)


func _show_completion() -> void:
	_set_modal(true)
	var s := SessionState
	var extra := PackedStringArray()
	var done := 0
	for q in QuestManager.book.quests:
		if int(q.get("act", 0)) == 1 and QuestManager.book.is_completed(String(q["id"])):
			done += 1
	extra.append(L.t("Act 1 quests completed: %d of 4") % done)
	extra.append(L.t("Map explored: %d%%") % int(round(GameState.revealed_fraction() * 100.0)))
	completion_panel.open({
		"objective_done": s.heart_tree_restored,
		"lights": s.lights_collected,
		"bonus": s.bonus_collected,
		"lanterns": s.lanterns_collected,
		"tree_restored": s.heart_tree_restored,
		"beds": s.bloomed_beds.size(),
		"bed_total": s.GARDEN_BED_COUNT,
		"restoration_percent": int(round(s.get_restoration_progress() * 100.0)),
		"discoveries": s.discoveries_this_session.size(),
		"duration_text": format_duration(s.get_duration_seconds()),
		"extra": extra,
	})


func _close_completion() -> void:
	completion_panel.close()
	_set_modal(false)


func _manual_save() -> void:
	if SaveManager.current_slot < 0:
		pause_menu.set_status("This world isn't linked to a save slot (started without choosing a journey).")
		return
	if SaveManager.save_slot(SaveManager.current_slot, "manual"):
		pause_menu.set_status(L.t("Saved to Journey %d.") % SaveManager.current_slot)
	else:
		pause_menu.set_status(L.t("Saving failed: %s") % SaveManager.last_error)


func _load_slot(slot: int) -> void:
	SaveManager.autosave("before loading another journey")
	SaveManager.current_slot = slot
	SaveManager.reload_current()
	SceneRouter.go_to(SceneRouter.OVERWORLD)


func _finish_session() -> void:
	SaveManager.autosave("session finished")
	SessionState.end_gameplay()
	StudyMode.end_play()
	SceneRouter.go_to(SceneRouter.REFLECTION)


## Restart Session: a new session timer, and the world as it was last saved
## (without a save slot: a fresh world, like V1).
func _restart_session() -> void:
	SessionState.restart_gameplay()
	if SaveManager.current_slot < 0:
		GameState.reset_world(world.world_size())
	SaveManager.reload_current()
	SceneRouter.go_to(SceneRouter.OVERWORLD)


func _leave_to_menu() -> void:
	SaveManager.autosave("returned to the main menu")
	SessionState.abandon_session()
	StudyMode.end_play()
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


## Return to menu / Quit from the pause menu: "Before you go..." first, when
## the player has it turned on. Autosaves exactly as before.
func _request_leave(to: String) -> void:
	pause_menu.close()
	if not Wellbeing.wants_closing():
		_leave(to)
		return
	var panel := SessionClosingPanel.new()
	panel.leaving_to = to
	_overlay = panel
	hud.add_overlay(panel)
	panel.keep_playing.connect(_close_overlay)
	panel.leave.connect(func(face: Variant) -> void:
		Wellbeing.end_face = face
		_leave(to))


func _leave(to: String) -> void:
	Wellbeing.record_session_end()
	if to == "quit":
		SaveManager.autosave("quit")
		SessionState.abandon_session()
		get_tree().quit()
	else:
		_leave_to_menu()


## Study Mode: after the set time, Lumi's gentle line, then (after the player
## had time to finish) the reflection. Never during dialogue or a minigame:
## overlays pause the world, so this does not even run while one is open.
func _update_study_end() -> void:
	hud.set_study_light(StudyMode.remaining_fraction())
	var busy := hud.is_dialogue_visible() or lantern_catch.active or SceneRouter.is_busy()
	match StudyMode.end_step(busy):
		"announce":
			lumi.react()
			hud.show_dialogue(L.t(StudyMode.END_LINE), 8.0)
		"finish":
			_finish_session()


static func format_duration(seconds: int) -> String:
	return L.t("%d min %02d s") % [seconds / 60, seconds % 60]
