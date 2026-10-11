extends Node
## The current *research session* (autoload "SessionState").
##
## Owns: check-in answers, consent, the AdaptiveComfortEngine (mode + assistance
## counters), the reflection answers and the per-session metrics written to the
## research CSV (lights collected this session, Heart Tree restored this
## session...). Persistent world progress (inventory, collected objects, garden
## beds, flags) lives in GameState and is saved by SaveManager; the meadow
## helpers below keep their V1 API but delegate world facts to GameState.

signal progress_changed
signal mode_changed(config: ModeConfig, reason: StringName)
signal assistance_changed(assistance: Dictionary)
signal session_reset

const KIND_LIGHT := &"light"
const KIND_PRISM := &"prism"
const KIND_LANTERN := &"lantern"

const TOTAL_MEADOW_LIGHTS := 12
const LIGHTS_FOR_HEART_TREE := 8
const LIGHT_PER_GARDEN_BED := 1
const GARDEN_BED_COUNT := 3
## Share of "garden restoration" represented by the tree vs. each garden bed.
const TREE_RESTORATION_WEIGHT := 0.7
const BED_RESTORATION_WEIGHT := 0.1

# --- Check-in, consent and reflection -----------------------------------------
var session_active: bool = false
var consent_to_store: bool = false
var session_id: String = ""
var session_started_at: String = ""
var pre_stress_score: Variant = null
## Empty when the check-in was skipped (Balanced is then applied by default).
var recommended_mode: String = ""
var selected_mode: String = String(AdaptiveComfortEngine.DEFAULT_MODE)
var post_stress_score: Variant = null
var experience_rating: Variant = null

# --- Per-session metrics (research record) ------------------------------------------
var engine: AdaptiveComfortEngine
## Items collected THIS session (by id), so one object never counts twice.
var collected_ids: Dictionary = {}
var lights_collected: int = 0
var bonus_collected: int = 0
var lanterns_collected: int = 0
var discoveries_this_session: PackedStringArray = []
## True if the Heart Tree was restored during THIS session (CSV garden_restored).
var tree_restored_this_session: bool = false
var lantern_nights_this_session: int = 0
var completion_offered: bool = false
var welcome_shown: bool = false
## What the world shows when a journey opens from the menu (set by the journey
## screen): {"mode_card": bool, "mood_check": bool}. Empty when the world is
## opened any other way (tests, the editor, Study Mode).
var start_cards: Dictionary = {}

# --- World facts (delegated to GameState, read-only views kept for the V1 API) -------
const LUMA_LIGHT := "luma_light"
var light_balance: int:
	get:
		return GameState.inventory.count(LUMA_LIGHT)
var heart_tree_restored: bool:
	get:
		return GameState.has_flag("heart_tree_restored")
var bloomed_beds: Dictionary:
	get:
		return GameState.bloomed_beds

var progress: ProgressStore
var storage: SessionStorage
var last_save_result: Dictionary = {}

var _start_msec: int = 0
var _end_msec: int = -1
var _record_written: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	progress = ProgressStore.new()
	if not progress.load_progress():
		push_warning(progress.last_error)
	storage = SessionStorage.new()
	_replace_engine(AdaptiveComfortEngine.DEFAULT_MODE)


# =============================================================================
# Session lifecycle
# =============================================================================

## Starts a new session from the check-in screen.
## pre_score: int 0-10, or null when the player skipped the question.
func begin_session(pre_score: Variant, chosen_mode: StringName, consent: bool) -> void:
	_reset_gameplay()
	session_id = SessionRecord.generate_session_id()
	session_started_at = SessionRecord.local_timestamp()
	pre_stress_score = AdaptiveComfortEngine.parse_score(pre_score)
	if pre_stress_score == null:
		recommended_mode = ""
	else:
		recommended_mode = String(AdaptiveComfortEngine.recommend(pre_stress_score)["mode"])
	if not AdaptiveComfortEngine.is_valid_mode(chosen_mode):
		chosen_mode = AdaptiveComfortEngine.DEFAULT_MODE
	selected_mode = String(chosen_mode)
	consent_to_store = consent
	post_stress_score = null
	experience_rating = null
	last_save_result = {}
	_record_written = false
	_replace_engine(chosen_mode)
	_start_msec = Time.get_ticks_msec()
	_end_msec = -1
	session_active = true
	progress_changed.emit()


## Used when a gameplay scene is opened without a check-in (e.g. run directly
## from the editor): starts a skipped-check-in, no-storage session.
func ensure_session() -> void:
	if not session_active:
		begin_session(null, AdaptiveComfortEngine.DEFAULT_MODE, false)


## Restart Session: restarts the session timer and this session's metrics.
## Check-in answers, consent and mode are kept. World progress is not touched
## here: the overworld reloads it from the player's save slot.
func restart_gameplay() -> void:
	_reset_gameplay()
	engine.reset_session_counters()
	_start_msec = Time.get_ticks_msec()
	_end_msec = -1
	progress_changed.emit()
	session_reset.emit()


## Stops the session timer (called when the player chooses Finish Session).
func end_gameplay() -> void:
	if _end_msec < 0:
		_end_msec = Time.get_ticks_msec()


func set_reflection(post_score: Variant, rating: Variant) -> void:
	post_stress_score = AdaptiveComfortEngine.parse_score(post_score)
	experience_rating = int(rating) if SessionRecord.is_valid_rating(rating) else null


## Writes the session record once, only if the player consented.
## Returns {"ok": bool, "saved": bool, "message": String}.
func finalize_and_save(completed: bool) -> Dictionary:
	if _record_written:
		return last_save_result
	_record_written = true
	end_gameplay()
	session_active = false
	if not consent_to_store:
		last_save_result = {"ok": true, "saved": false, "message": "Not saved: you chose not to store session data. Nothing was written."}
		return last_save_result
	var record := build_record(completed)
	var result := storage.append_record(record)
	result["saved"] = result["ok"]
	# Study Mode also keeps its own file (same record, plus the study columns).
	if StudyMode.record_pending:
		StudyMode.record_pending = false
		result["study_saved"] = StudyMode.store_record(record)["ok"]
	last_save_result = result
	return last_save_result


## Leaving mid-session (main menu or closing the window). A consenting
## player's record is stored with completed = false.
func abandon_session() -> void:
	if session_active:
		finalize_and_save(false)


func build_record(completed: bool) -> SessionRecord:
	var r := SessionRecord.new()
	r.session_id = session_id
	r.session_started_at = session_started_at
	r.pre_stress_score = pre_stress_score
	r.recommended_mode = recommended_mode
	r.selected_mode = selected_mode
	r.final_mode = String(engine.get_mode_id())
	r.session_duration_seconds = get_duration_seconds()
	r.hints_used = engine.hints_used
	r.interaction_help_events = engine.interaction_help_events
	r.items_collected = get_items_collected()
	r.garden_restored = tree_restored_this_session
	r.post_stress_score = post_stress_score
	r.experience_rating = experience_rating
	r.completed = completed
	return r


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		abandon_session()


# =============================================================================
# Mode and assistance (delegated to the engine)
# =============================================================================

func get_config() -> ModeConfig:
	return engine.get_config()


func select_mode(mode_id: StringName, reason: StringName = AdaptiveComfortEngine.REASON_PLAYER_CHOICE) -> bool:
	return engine.select_mode(mode_id, reason)


func set_auto_assist(enabled: bool) -> void:
	engine.set_auto_assist_enabled(enabled)


func _replace_engine(mode_id: StringName) -> void:
	if engine != null:
		if engine.mode_changed.is_connected(_on_engine_mode_changed):
			engine.mode_changed.disconnect(_on_engine_mode_changed)
		if engine.assistance_changed.is_connected(_on_engine_assistance_changed):
			engine.assistance_changed.disconnect(_on_engine_assistance_changed)
	engine = AdaptiveComfortEngine.new(mode_id)
	engine.auto_assist_enabled = GameSettings.adaptive_assistance
	engine.mode_changed.connect(_on_engine_mode_changed)
	engine.assistance_changed.connect(_on_engine_assistance_changed)


func _on_engine_mode_changed(config: ModeConfig, reason: StringName) -> void:
	mode_changed.emit(config, reason)


func _on_engine_assistance_changed(assistance: Dictionary) -> void:
	assistance_changed.emit(assistance)


# =============================================================================
# Collectibles and restoration
# =============================================================================

## True when the last collect_item() failed only because the bag was full.
var last_collect_blocked_by_full_bag: bool = false


## Records a collected world object exactly once (world + this session).
## Lights and Prism Motes become Luma Light in the inventory. Returns false for
## duplicates, unknown kinds, or when there is no room for the light (the
## object then simply stays in the world).
func collect_item(item_id: String, kind: StringName) -> bool:
	last_collect_blocked_by_full_bag = false
	if item_id.is_empty() or collected_ids.has(item_id) or GameState.is_collected(item_id):
		return false
	if not [KIND_LIGHT, KIND_PRISM, KIND_LANTERN].has(kind):
		push_warning("SessionState: unknown item kind '%s'." % kind)
		return false
	var gives_light := kind == KIND_LIGHT or kind == KIND_PRISM
	if gives_light and GameState.inventory.room_for(LUMA_LIGHT) < 1:
		last_collect_blocked_by_full_bag = true
		return false
	GameState.mark_collected(item_id)
	match kind:
		KIND_LIGHT:
			lights_collected += 1
			GameState.add_counter("lights_collected")
		KIND_PRISM:
			bonus_collected += 1
		KIND_LANTERN:
			lanterns_collected += 1
	if gives_light:
		GameState.give_item(LUMA_LIGHT, 1)
	collected_ids[item_id] = kind
	progress_changed.emit()
	return true


## Whether a world object has been collected (in this world, any session).
func is_collected(item_id: String) -> bool:
	return GameState.is_collected(item_id)


func get_items_collected() -> int:
	return lights_collected + bonus_collected + lanterns_collected


func can_restore_heart_tree() -> bool:
	return not heart_tree_restored and light_balance >= LIGHTS_FOR_HEART_TREE


func lights_needed_for_tree() -> int:
	return maxi(0, LIGHTS_FOR_HEART_TREE - light_balance)


func restore_heart_tree() -> bool:
	if not can_restore_heart_tree():
		return false
	GameState.inventory.remove(LUMA_LIGHT, LIGHTS_FOR_HEART_TREE)
	GameState.set_flag("heart_tree_restored")
	tree_restored_this_session = true
	progress.heart_tree_restorations += 1
	if not progress.save_progress():
		push_warning(progress.last_error)
	progress_changed.emit()
	return true


func can_bloom_bed(bed_id: String) -> bool:
	return heart_tree_restored and not bloomed_beds.has(bed_id) and light_balance >= LIGHT_PER_GARDEN_BED


func bloom_bed(bed_id: String) -> bool:
	if not can_bloom_bed(bed_id):
		return false
	GameState.inventory.remove(LUMA_LIGHT, LIGHT_PER_GARDEN_BED)
	GameState.bloomed_beds[bed_id] = true
	GameState.changed.emit("bed:" + bed_id)
	progress_changed.emit()
	return true


func is_bed_bloomed(bed_id: String) -> bool:
	return bloomed_beds.has(bed_id)


## 0.0-1.0: the Heart Tree is the main goal; garden beds are optional extras.
func get_restoration_progress() -> float:
	var value := TREE_RESTORATION_WEIGHT if heart_tree_restored else 0.0
	value += BED_RESTORATION_WEIGHT * bloomed_beds.size()
	return clampf(value, 0.0, 1.0)


func record_discovery(discovery_id: String) -> bool:
	if discoveries_this_session.has(discovery_id):
		return false
	discoveries_this_session.append(discovery_id)
	GameState.discoveries[discovery_id] = true
	if progress.add_discovery(discovery_id) and not progress.save_progress():
		push_warning(progress.last_error)
	progress_changed.emit()
	return true


func complete_lantern_night() -> void:
	lantern_nights_this_session += 1
	GameState.add_counter("lantern_nights")
	progress.lantern_nights_completed += 1
	if not progress.save_progress():
		push_warning(progress.last_error)
	progress_changed.emit()


func get_duration_seconds() -> int:
	if _start_msec <= 0 and not session_active:
		return 0
	var end_msec := _end_msec if _end_msec >= 0 else Time.get_ticks_msec()
	return maxi(0, int((end_msec - _start_msec) / 1000.0))


func _reset_gameplay() -> void:
	collected_ids.clear()
	lights_collected = 0
	bonus_collected = 0
	lanterns_collected = 0
	discoveries_this_session = PackedStringArray()
	tree_restored_this_session = false
	lantern_nights_this_session = 0
	completion_offered = false
	welcome_shown = false
