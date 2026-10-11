extends Node
## Game saves (autoload "SaveManager"): 3 slots in user://saves/.
##
## * Versioned schema (`save_version`) with step-by-step migration.
## * Atomic writes: write slot_N.json.tmp, read it back and verify, keep the
##   previous file as slot_N.bak.json, then rename the temp file into place.
## * Loading falls back to the backup if the main file is missing or corrupt.
## * Completely separate from research data: never touches sessions.csv.
## * Autosaves: sleeping, entering/leaving interiors and caves, completing a
##   quest, and every few minutes (Settings). Manual save from the pause menu.

signal saved(slot: int, reason: String)
signal save_failed(slot: int, message: String)

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 2
const SLOT_COUNT := 3
## Study Mode's temporary journey (saves/study_tmp.json); never one of slots 1-3.
const STUDY_SLOT := 0
const GAME_VERSION := "0.3.1"

## -1 = no slot (e.g. a test or a scene run directly): nothing is written.
var current_slot: int = -1
## Set by the overworld so saves can include the player's position.
var runtime_provider: Callable = Callable()
## Player state to apply when the overworld starts after a load.
var pending_player: Dictionary = {}
## Folder for slot files. Tests point this at a temporary folder.
var save_dir: String = SAVE_DIR
var last_error: String = ""
var playtime_seconds: float = 0.0
var _autosave_timer: float = 0.0
var _active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	EventBus.quest_completed.connect(func(_id: String) -> void: autosave("quest completed"))


## The overworld calls this while it is running.
func set_active(active: bool) -> void:
	_active = active
	_autosave_timer = 0.0


func _process(delta: float) -> void:
	if not _active:
		return
	playtime_seconds += delta
	var minutes := GameSettings.autosave_minutes
	if minutes <= 0:
		return
	_autosave_timer += delta
	if _autosave_timer >= minutes * 60.0:
		_autosave_timer = 0.0
		autosave("periodic")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _active:
		autosave("window closed")


# =============================================================================
# Paths and slot info
# =============================================================================

func slot_path(slot: int) -> String:
	if slot == STUDY_SLOT:
		return "%s/study_tmp.json" % save_dir
	return "%s/slot_%d.json" % [save_dir, slot]


func backup_path(slot: int) -> String:
	if slot == STUDY_SLOT:
		return "%s/study_tmp.bak.json" % save_dir
	return "%s/slot_%d.bak.json" % [save_dir, slot]


func temp_path(slot: int) -> String:
	if slot == STUDY_SLOT:
		return "%s/study_tmp.json.tmp" % save_dir
	return "%s/slot_%d.json.tmp" % [save_dir, slot]


func set_save_dir(dir: String) -> void:
	save_dir = dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(backup_path(slot))


## Short description for the slot screen, or {} if the slot is empty/unreadable.
func slot_summary(slot: int) -> Dictionary:
	var data := _read_valid(slot)
	if data.is_empty():
		return {}
	var summary: Dictionary = data.get("summary", {})
	summary["saved_at"] = data.get("saved_at", "")
	return summary


# =============================================================================
# Building and applying save data
# =============================================================================

## Collects the whole game state into one versioned dictionary.
func build_save_data() -> Dictionary:
	var player: Dictionary = {}
	if runtime_provider.is_valid():
		player = runtime_provider.call()
	elif not pending_player.is_empty():
		player = pending_player.duplicate()
	var act1_done := 0
	for q in QuestManager.book.quests:
		if int(q.get("act", 0)) == 1 and QuestManager.book.is_completed(String(q["id"])):
			act1_done += 1
	return {
		"save_version": SAVE_VERSION,
		"game_version": GAME_VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"summary": {
			"day": TimeManager.day,
			"region": String(player.get("region_name", "Whispering Meadow")),
			"act1_quests": act1_done,
			"explored_percent": int(round(GameState.revealed_fraction() * 100.0)),
			"playtime_minutes": int(playtime_seconds / 60.0),
		},
		"player": player,
		"time": TimeManager.to_state(),
		"world": GameState.to_state(),
		"quests": QuestManager.book.to_state(),
		"mode": String(SessionState.engine.get_mode_id()) if SessionState.engine != null else "balanced",
		"lumi": {"glow_style": "default"},
		"playtime_seconds": playtime_seconds,
	}


## Applies loaded data to GameState, quests, the clock and the pending player.
func apply_save_data(data: Dictionary, world_size: Vector2) -> void:
	GameState.load_state(data.get("world", {}), world_size)
	TimeManager.load_state(data.get("time", {}))
	QuestManager.book.reset_progress()
	QuestManager.book.load_state(data.get("quests", {}))
	QuestManager.tracked_id = ""
	pending_player = (data.get("player", {}) as Dictionary).duplicate()
	playtime_seconds = float(data.get("playtime_seconds", 0.0))
	QuestManager.request_refresh()


## Prepares the world for the overworld: loads the current slot, or starts a
## new journey in it (saving immediately), or, without a slot, a fresh world.
func prepare_world(world_size: Vector2) -> void:
	if current_slot < 0:
		GameState.bind_to_session(SessionState.session_id, world_size)
		return
	if GameState.bound_session_id == "slot:%d" % current_slot:
		return
	var data := load_slot(current_slot)
	if data.is_empty():
		start_new_journey(world_size)
	else:
		apply_save_data(data, world_size)
	GameState.bound_session_id = "slot:%d" % current_slot


## Starts a fresh world in the current slot and imports the V1 journal.
func start_new_journey(world_size: Vector2) -> void:
	GameState.reset_world(world_size)
	QuestManager.book.reset_progress()
	QuestManager.tracked_id = ""
	pending_player = {}
	playtime_seconds = 0.0
	# A study journey always starts from the same fresh state.
	if current_slot != STUDY_SLOT:
		import_legacy_journal()
	if current_slot >= 0:
		save_slot(current_slot, "new journey")


## Migration from V1: progress.cfg only held journal counters (there was no
## world save in V1 or "World 2.0"). Those counters are copied into the new
## journey's journal so earlier play is remembered; the file itself is kept.
func import_legacy_journal() -> void:
	var legacy := ProgressStore.new()
	if not legacy.load_progress():
		return
	var journal := GameState.system_state("legacy_journal")
	journal["heart_tree_restorations"] = legacy.heart_tree_restorations
	journal["lantern_nights_completed"] = legacy.lantern_nights_completed
	journal["discoveries"] = Array(legacy.discoveries)


## Forget the in-memory world so the next prepare_world() reloads the slot.
func reload_current() -> void:
	GameState.bound_session_id = ""


# =============================================================================
# File operations
# =============================================================================

func autosave(reason: String) -> bool:
	if current_slot < 0:
		return false
	return save_slot(current_slot, reason)


## Atomic save. Returns true only if the new file was written and verified.
func save_slot(slot: int, reason: String = "manual") -> bool:
	if (slot < 1 or slot > SLOT_COUNT) and slot != STUDY_SLOT:
		return _fail(slot, L.t("Invalid save slot %d.") % slot)
	var text := JSON.stringify(build_save_data(), "\t")
	var tmp := temp_path(slot)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail(slot, L.t("Could not write the save file (%s).") % error_string(FileAccess.get_open_error()))
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK or FileAccess.get_file_as_string(tmp) != text:
		return _fail(slot, L.t("The save could not be verified (%s). Your previous save is untouched.") % error_string(err))
	var main_abs := ProjectSettings.globalize_path(slot_path(slot))
	var bak_abs := ProjectSettings.globalize_path(backup_path(slot))
	if FileAccess.file_exists(slot_path(slot)):
		if FileAccess.file_exists(backup_path(slot)):
			DirAccess.remove_absolute(bak_abs)
		var r1 := DirAccess.rename_absolute(main_abs, bak_abs)
		if r1 != OK:
			return _fail(slot, L.t("Could not keep a backup (%s). Nothing was replaced.") % error_string(r1))
	var r2 := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), main_abs)
	if r2 != OK:
		return _fail(slot, L.t("Could not finish saving (%s). The backup is still available.") % error_string(r2))
	last_error = ""
	saved.emit(slot, reason)
	return true


## Reads, validates and migrates a slot. Falls back to the backup if needed.
## Returns {} when neither file is usable.
func load_slot(slot: int) -> Dictionary:
	var data := _read_valid(slot)
	if data.is_empty() and slot_exists(slot):
		last_error = L.t("This save could not be read, and its backup could not be read either.")
	return data


func delete_slot(slot: int) -> bool:
	var ok := true
	for p in [slot_path(slot), backup_path(slot), temp_path(slot)]:
		if FileAccess.file_exists(p):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(p)) == OK and ok
	if GameState.bound_session_id == "slot:%d" % slot:
		GameState.bound_session_id = ""
	return ok


func _read_valid(slot: int) -> Dictionary:
	for p in [slot_path(slot), backup_path(slot)]:
		if not FileAccess.file_exists(p):
			continue
		# A JSON instance reports bad files with an error code instead of an
		# engine error, so a damaged save just falls back to its backup.
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(p)) != OK or typeof(json.data) != TYPE_DICTIONARY:
			push_warning("SaveManager: %s is damaged (%s); trying the backup." % [p, json.get_error_message()])
			continue
		var migrated := migrate(json.data)
		if migrated.is_empty():
			push_warning("SaveManager: %s has an unsupported version." % p)
			continue
		return migrated
	return {}


## Upgrades older save data step by step. Returns {} for unknown/future versions.
static func migrate(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	var version := int(d.get("save_version", 0))
	if version > SAVE_VERSION or version < 1:
		return {}
	if version == 1:
		# v1 (early V2 development format): world state was stored flat at the
		# top level, and time as "day"/"minute" keys.
		var world := {}
		for key in ["flags", "counters", "visited_regions", "waystones", "removed_objects", "puzzles", "seen_landmarks", "pins", "fog", "fog_size", "inventory", "known_recipes", "collected", "bloomed_beds", "discoveries", "lore_read", "systems"]:
			if d.has(key):
				world[key] = d[key]
				d.erase(key)
		d["world"] = world
		d["time"] = {"day": int(d.get("day", 1)), "minute": float(d.get("minute", TimeManager.START_MINUTE))}
		d.erase("day")
		d.erase("minute")
		if not d.has("summary"):
			d["summary"] = {"day": d["time"]["day"], "region": "Whispering Meadow", "act1_quests": 0, "explored_percent": 0, "playtime_minutes": 0}
		d["save_version"] = 2
	return d


func _fail(slot: int, message: String) -> bool:
	last_error = message
	push_warning("SaveManager: " + message)
	save_failed.emit(slot, message)
	return false
