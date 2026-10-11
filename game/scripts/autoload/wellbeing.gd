extends Node
## The optional well-being layer for every player (autoload "Wellbeing").
##
## * Mood check: "How are you feeling right now?" with five drawn faces when a
##   journey starts (Settings > Well-being: Ask / Don't ask). Not a measurement.
## * Session closing: "Before you go..." with a short summary built only from
##   what really happened in this play session.
## * Private mood journal (opt-in, off by default): user://wellbeing_journal.json.
##
## Mood answers stay in memory unless the journal is on. Nothing here is ever
## written to the research files, and none of it is used in Study Mode.

const JOURNAL_PATH := "user://wellbeing_journal.json"
const JOURNAL_VERSION := 1
## Face 1-5, from tense to peaceful. Each face also has its own drawn shape.
const FACES: PackedStringArray = ["Tense", "Uneasy", "Okay", "Calm", "Peaceful"]
## Lumi's replies work for every answer: thanks, no judgement, no promises.
const LUMI_REPLIES: PackedStringArray = [
	"Thanks for sharing. Let's take it slow today.",
	"Thank you for telling me. We can go at whatever pace feels right.",
	"Thanks. I'm glad you're here. There's no rush at all.",
]
const MAX_SUMMARY_LINES := 4
const QUIET_LINE := "A quiet walk is time well spent."
## [counter, one, many]: "many" may contain %d. Ordered by how special it is.
const COUNTER_LINES := [
	["hearthstones", "You found a Hearthstone.", "You found %d Hearthstones."],
	["villagers_arrived", "A new neighbour moved into the village.", "%d new neighbours moved into the village."],
	["creature_friends", "You made a new animal friend.", "You made %d new animal friends."],
	["kits_home", "You brought a fox kit home.", "You brought %d fox kits home."],
	["gloomlings_calmed", "You comforted a Gloomling.", "You comforted %d Gloomlings."],
	["gloom_cleared", "You cleared a patch of gloom.", "You cleared %d patches of gloom."],
	["waystones_relit", "You relit a waystone.", "You relit %d waystones."],
	["planted", "You planted a seed.", "You planted %d seeds."],
	["harvested", "You harvested a crop.", "You harvested %d crops."],
	["fish_caught", "You caught a fish.", "You caught %d fish."],
	["dishes_cooked", "You cooked a dish.", "You cooked %d dishes."],
	["creatures_sketched", "You sketched a creature in your journal.", "You sketched %d creatures in your journal."],
	["gifts_given", "You gave a friend a gift.", "You gave %d gifts to friends."],
	["requests_done", "You helped a neighbour with a request.", "You helped your neighbours with %d requests."],
	["lantern_nights", "You watched the lanterns rise.", "You watched the lanterns rise."],
	["boat_trips", "You sailed across the sea.", "You sailed across the sea."],
	["cottage_steps", "You worked on the cottage.", "You worked on the cottage."],
	["villager_talks", "You chatted with a neighbour.", "You chatted with your neighbours."],
	["notes_read", "You read an old note.", "You read %d old notes."],
	["lights_collected", "You gathered a light.", "You gathered %d lights."],
	["nights_slept", "You rested until morning.", "You rested until morning."],
]

var journal_path: String = JOURNAL_PATH
## The faces chosen this play session (1-5), or null.
var start_face: Variant = null
var end_face: Variant = null
var last_error: String = ""
var _start_msec: int = 0
var _counters_before: Dictionary = {}
var _new_places: PackedStringArray = []
var _quests_done: PackedStringArray = []
var _tracking: bool = false
var _journal_written: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.quest_completed.connect(_on_quest_completed)


func _notification(what: int) -> void:
	# Closing the window shows no panel; the journal (if on) still keeps the day.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		record_session_end()


## Starts a play session (the world calls this when it opens).
func begin_play() -> void:
	start_face = null
	end_face = null
	_start_msec = Time.get_ticks_msec()
	_counters_before = GameState.counters.duplicate()
	_new_places = PackedStringArray()
	_quests_done = PackedStringArray()
	_tracking = true
	_journal_written = false


func is_tracking() -> bool:
	return _tracking


## The world reports a first visit (with the region's English name).
func note_new_place(region_name: String) -> void:
	if _tracking and not region_name.is_empty() and not _new_places.has(region_name):
		_new_places.append(region_name)


func _on_quest_completed(quest_id: String) -> void:
	if _tracking and not _quests_done.has(quest_id):
		_quests_done.append(quest_id)


func minutes_played() -> int:
	if not _tracking:
		return 0
	return int((Time.get_ticks_msec() - _start_msec) / 60000.0)


static func face_name(face: Variant) -> String:
	if not is_valid_face(face):
		return ""
	return FACES[int(face) - 1]


static func is_valid_face(face: Variant) -> bool:
	return (typeof(face) == TYPE_INT or typeof(face) == TYPE_FLOAT) and int(face) >= 1 and int(face) <= FACES.size()


static func reply_line() -> String:
	return LUMI_REPLIES[randi() % LUMI_REPLIES.size()]


## Whether leaving from the pause menu should show "Before you go...".
func wants_closing() -> bool:
	return not StudyMode.is_active() and (GameSettings.session_summary or GameSettings.mood_check)


# =============================================================================
# Session summary (real events only)
# =============================================================================

## 2-4 warm lines about this play session, in the current language.
func summary_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if not _tracking:
		return PackedStringArray([L.t(QUIET_LINE)])
	for id in _quests_done:
		var title := String(QuestManager.book.get_quest(id).get("title", ""))
		if not title.is_empty():
			lines.append(L.t("You finished a quest: %s.") % L.t(title))
	for place in _new_places:
		lines.append(L.t("You found a new place: %s.") % L.t(place))
	for entry: Array in COUNTER_LINES:
		var gained := GameState.counter(String(entry[0])) - int(_counters_before.get(entry[0], 0))
		if gained <= 0:
			continue
		var template := L.t(String(entry[1])) if gained == 1 else L.t(String(entry[2]))
		lines.append(template % gained if template.contains("%d") else template)
	if lines.is_empty():
		lines.append(L.t(QUIET_LINE))
	return lines.slice(0, MAX_SUMMARY_LINES)


# =============================================================================
# Private mood journal (opt-in)
# =============================================================================

## Writes this play session to the journal, once, only when the journal is on.
## Returns true if an entry was written.
func record_session_end() -> bool:
	if _journal_written or not _tracking or not GameSettings.mood_journal or StudyMode.is_active():
		return false
	_journal_written = true
	var entry := {
		"local_time": Time.get_datetime_string_from_system(false, true),
		"start_face": int(start_face) if is_valid_face(start_face) else null,
		"end_face": int(end_face) if is_valid_face(end_face) else null,
		"minutes": minutes_played(),
		"summary": Array(summary_lines()),
	}
	var data := _read_journal()
	if data.has("unreadable"):
		return false
	(data["entries"] as Array).append(entry)
	return _write_journal(data)


func journal_entries() -> Array:
	return _read_journal()["entries"]


func journal_exists() -> bool:
	return FileAccess.file_exists(journal_path)


func delete_journal() -> bool:
	if not journal_exists():
		return true
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(journal_path))
	if err != OK:
		last_error = L.t("Could not delete the mood journal (%s).") % error_string(err)
		return false
	return true


## Copies the journal to a file the player chose. Returns {"ok", "message"}.
func export_journal(destination: String) -> Dictionary:
	if not journal_exists():
		return {"ok": false, "message": "There is no mood journal to export yet."}
	var text := FileAccess.get_file_as_string(journal_path)
	var out := FileAccess.open(destination, FileAccess.WRITE)
	if out == null:
		return {"ok": false, "message": L.t("Could not write to the chosen location (%s).") % error_string(FileAccess.get_open_error())}
	out.store_string(text)
	out.close()
	return {"ok": true, "message": L.t("Exported to %s") % ProjectSettings.globalize_path(destination)}


func _read_journal() -> Dictionary:
	var empty := {"journal_version": JOURNAL_VERSION, "entries": []}
	if not journal_exists():
		return empty
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(journal_path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		last_error = "The mood journal could not be read; it was left untouched."
		push_warning("Wellbeing: " + last_error)
		empty["unreadable"] = true
		return empty
	var data: Dictionary = json.data
	if typeof(data.get("entries")) != TYPE_ARRAY:
		data["entries"] = []
	return data


func _write_journal(data: Dictionary) -> bool:
	var dir := journal_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(journal_path, FileAccess.WRITE)
	if f == null:
		last_error = L.t("Could not save the mood journal (%s).") % error_string(FileAccess.get_open_error())
		push_warning("Wellbeing: " + last_error)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true
