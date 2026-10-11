extends Node
## The hidden research layer (autoload "StudyMode"). See docs/STUDY_MODE.md.
##
## * Activation: the command-line user argument `--study` (this run only), or
##   7 clicks on the main menu's version label plus the unlock phrase (kept in
##   settings until "Leave Study Mode" in Data & Privacy).
## * Flow: Study setup -> the existing check-in -> a fresh study journey in its
##   own temporary save (never slots 1-3) -> a fixed duration with a gentle
##   end -> the existing reflection and results -> back to Study setup.
## * Data (only with the participant's consent at the check-in):
##   user://study_sessions.csv (study columns + the 16 schema-v1 columns) and
##   user://study_events.csv (coarse events, no positions or keystrokes).
##   sessions.csv keeps receiving its normal schema-v1 row as before.

signal changed

const UNLOCK_PHRASE := "LUMERIA-STUDY"
const UNLOCK_CLICKS := 7
const DURATIONS: Array[int] = [10, 15, 20]
const DEFAULT_DURATION := 15
const DEFAULT_LANGUAGE := "id"
## After the gentle end line, the player may finish what they are doing.
const GRACE_SECONDS := 60.0
const STUDY_SCHEMA_VERSION := 1
const SESSIONS_PATH := "user://study_sessions.csv"
const EVENTS_PATH := "user://study_events.csv"
## Optional file written by a build script: the git commit of this build.
const BUILD_COMMIT_PATH := "res://build_commit.txt"
const STUDY_COLUMNS: PackedStringArray = ["study_schema_version", "participant_code", "language", "build_version", "git_commit", "target_duration_seconds"]
const EVENT_COLUMNS: PackedStringArray = ["participant_code", "session_id", "t_seconds", "event", "detail"]
const END_LINE := "Our walk is almost done for today. Shall we rest?"

enum EndStage { PLAYING, ANNOUNCED, FINISHED }

## True when this run was started with --study.
var cli_active: bool = false
var participant_code: String = ""
var duration_minutes: int = DEFAULT_DURATION
var language: String = DEFAULT_LANGUAGE
## True from the start of a study journey until it ends (gentle end or leaving).
var session_running: bool = false
var end_stage: EndStage = EndStage.PLAYING
## True from the start of a study journey until its record has been written.
var record_pending: bool = false
var sessions_store: CsvFileStore
var events_store: CsvFileStore
var last_error: String = ""
var _start_msec: int = 0
var _announced_at: float = 0.0
## Test hook: when >= 0, used instead of the real clock (seconds since start).
var fake_elapsed: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cli_active = parse_args(OS.get_cmdline_user_args())
	sessions_store = CsvFileStore.new(SESSIONS_PATH, study_header())
	events_store = CsvFileStore.new(EVENTS_PATH, EVENT_COLUMNS)
	EventBus.region_entered.connect(func(region: String, _first: bool) -> void: log_event("region_entered", region))
	EventBus.puzzle_solved.connect(func(id: String) -> void: log_event("puzzle_solved", id))
	SessionState.mode_changed.connect(func(config: ModeConfig, _reason: StringName) -> void: log_event("mode_changed", String(config.mode_id)))


# =============================================================================
# Activation
# =============================================================================

static func parse_args(args: PackedStringArray) -> bool:
	return args.has("--study")


func is_active() -> bool:
	return cli_active or GameSettings.study_mode


## The hidden unlock. Returns true when the phrase is right (then remembered).
func try_unlock(phrase: String) -> bool:
	if phrase.strip_edges().to_upper() != UNLOCK_PHRASE:
		return false
	GameSettings.set_setting("study_mode", true)
	changed.emit()
	return true


func leave() -> void:
	cli_active = false
	if session_running:
		end_play()
	GameSettings.set_setting("study_mode", false)
	changed.emit()


# =============================================================================
# Setup
# =============================================================================

static func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper()


## P + 2-3 digits: P01 ... P999.
static func is_valid_code(code: String) -> bool:
	var re := RegEx.new()
	re.compile("^P[0-9]{2,3}$")
	return re.search(normalize_code(code)) != null


## Validates and stores the setup. Returns "" or a message for the researcher.
func configure(code: String, minutes: int, lang: String) -> String:
	if not is_valid_code(code):
		return "Participant code must be P followed by 2 or 3 digits (P01 to P999)."
	if not DURATIONS.has(minutes):
		return "Choose a session length of 10, 15 or 20 minutes."
	participant_code = normalize_code(code)
	duration_minutes = minutes
	language = lang if L.LANGUAGES.has(lang) else DEFAULT_LANGUAGE
	GameSettings.set_setting("language", language)
	return ""


func target_seconds() -> int:
	return duration_minutes * 60


# =============================================================================
# The study journey
# =============================================================================

## Called after the check-in: a fresh world in the study save, never slots 1-3.
func begin_play() -> void:
	SaveManager.delete_slot(SaveManager.STUDY_SLOT)
	SaveManager.current_slot = SaveManager.STUDY_SLOT
	SaveManager.reload_current()
	session_running = true
	record_pending = true
	end_stage = EndStage.PLAYING
	_announced_at = 0.0
	_start_msec = Time.get_ticks_msec()
	fake_elapsed = -1.0
	log_event("session_started", "%d min" % duration_minutes)


## Ends the study journey and deletes its temporary save.
func end_play() -> void:
	if not session_running:
		return
	log_event("session_ended", "")
	session_running = false
	end_stage = EndStage.FINISHED
	if SaveManager.current_slot == SaveManager.STUDY_SLOT:
		SaveManager.current_slot = -1
	SaveManager.delete_slot(SaveManager.STUDY_SLOT)


func elapsed_seconds() -> float:
	if fake_elapsed >= 0.0:
		return fake_elapsed
	if not session_running:
		return 0.0
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


## 1 at the start, 0 when the time is up (for the HUD's fading sun).
func remaining_fraction() -> float:
	if not session_running:
		return 1.0
	return clampf(1.0 - elapsed_seconds() / float(target_seconds()), 0.0, 1.0)


## What the world should do now: "" (keep playing), "announce" (Lumi's gentle
## line) or "finish" (move to the reflection). `busy` is true during dialogue
## or a minigame; then nothing ever happens, so the player is never cut off.
func end_step(busy: bool) -> String:
	if not session_running or busy:
		return ""
	var t := elapsed_seconds()
	match end_stage:
		EndStage.PLAYING:
			if t >= target_seconds():
				end_stage = EndStage.ANNOUNCED
				_announced_at = t
				log_event("gentle_end", "")
				return "announce"
		EndStage.ANNOUNCED:
			if t - _announced_at >= GRACE_SECONDS:
				end_stage = EndStage.FINISHED
				return "finish"
	return ""


# =============================================================================
# Data
# =============================================================================

static func study_header() -> PackedStringArray:
	var h := STUDY_COLUMNS.duplicate()
	h.append_array(SessionRecord.COLUMNS)
	return h


static func build_commit() -> String:
	if not FileAccess.file_exists(BUILD_COMMIT_PATH):
		return ""
	return FileAccess.get_file_as_string(BUILD_COMMIT_PATH).strip_edges().left(40)


func study_row(record: SessionRecord) -> PackedStringArray:
	var row := PackedStringArray([
		str(STUDY_SCHEMA_VERSION), participant_code, L.current(), SaveManager.GAME_VERSION,
		build_commit(), str(target_seconds()),
	])
	row.append_array(record.to_row())
	return row


## Writes the study row. SessionState calls this only with consent.
func store_record(record: SessionRecord) -> Dictionary:
	if participant_code.is_empty():
		return {"ok": false, "message": "No participant code."}
	var problems := record.validate()
	if not problems.is_empty():
		return {"ok": false, "message": L.t("The session record was not saved because it failed validation: %s.") % "; ".join(problems)}
	var result := sessions_store.append_row(study_row(record))
	if not result["ok"]:
		last_error = result["message"]
		push_warning("StudyMode: " + last_error)
	return result


## Coarse, non-identifying events, only during a study session with consent.
func log_event(event: String, detail: String) -> void:
	if not session_running or not SessionState.consent_to_store or participant_code.is_empty():
		return
	var result := events_store.append_row(PackedStringArray([
		participant_code, SessionState.session_id, "%.1f" % elapsed_seconds(), event, detail,
	]))
	if not result["ok"]:
		last_error = result["message"]
		push_warning("StudyMode: " + last_error)


## Exports both study files into a folder the researcher picked.
func export_to_folder(dir: String) -> Dictionary:
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	var any := false
	for pair: Array in [[sessions_store, "study_sessions_"], [events_store, "study_events_"]]:
		var store: CsvFileStore = pair[0]
		if not store.exists():
			continue
		any = true
		var result := store.export_to(dir.path_join(String(pair[1]) + stamp + ".csv"))
		if not result["ok"]:
			return result
	if not any:
		return {"ok": false, "message": "There is no study data to export yet."}
	return {"ok": true, "message": L.t("Study data exported to %s") % ProjectSettings.globalize_path(dir)}


## The activity a panel stands for (for the event log), or "".
static func activity_for(panel: Node) -> String:
	if panel == null or panel.get_script() == null:
		return ""
	match String((panel.get_script() as Script).get_global_name()):
		"FishingPanel":
			return "fishing"
		"CookingPanel":
			return "cooking"
		"InventoryPanel":
			return "crafting"
		"BuildModePanel":
			return "building"
		"VillagerPanel":
			return "talking"
	return ""
