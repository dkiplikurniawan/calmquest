class_name ProgressStore
extends RefCounted
## Small persistent game-progress file (user://progress.cfg).
## It only stores journal-style gameplay progress, never self-reported scores,
## and it works regardless of the session-data consent choice.
## The meadow itself starts fresh every session ("a new dawn"); see docs/ARCHITECTURE.md.

const DEFAULT_PATH := "user://progress.cfg"
const SECTION := "journal"

var path: String
var heart_tree_restorations: int = 0
var lantern_nights_completed: int = 0
var discoveries: PackedStringArray = []
var last_error: String = ""


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


func load_progress() -> bool:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path):
		return true
	var err := cfg.load(path)
	if err != OK:
		last_error = L.t("Could not read saved progress (%s).") % error_string(err)
		return false
	heart_tree_restorations = maxi(0, int(cfg.get_value(SECTION, "heart_tree_restorations", 0)))
	lantern_nights_completed = maxi(0, int(cfg.get_value(SECTION, "lantern_nights_completed", 0)))
	var raw: Variant = cfg.get_value(SECTION, "discoveries", PackedStringArray())
	discoveries = PackedStringArray()
	if raw is PackedStringArray or raw is Array:
		for item: Variant in raw:
			discoveries.append(str(item))
	return true


func save_progress() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "heart_tree_restorations", heart_tree_restorations)
	cfg.set_value(SECTION, "lantern_nights_completed", lantern_nights_completed)
	cfg.set_value(SECTION, "discoveries", discoveries)
	var err := cfg.save(path)
	if err != OK:
		last_error = L.t("Could not save progress (%s).") % error_string(err)
		return false
	return true


func add_discovery(discovery_id: String) -> bool:
	if discoveries.has(discovery_id):
		return false
	discoveries.append(discovery_id)
	return true


func reset() -> bool:
	heart_tree_restorations = 0
	lantern_nights_completed = 0
	discoveries = PackedStringArray()
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err != OK:
			last_error = L.t("Could not delete saved progress (%s).") % error_string(err)
			return false
	return true
