class_name SessionRecord
extends RefCounted
## Versioned schema for one consented, anonymous gameplay session.
## See docs/DATA_DICTIONARY.md for the meaning, type and range of each column.
## Missing answers are stored as empty cells (never as 0, since 0 is a valid score).

const SCHEMA_VERSION := 1

const COLUMNS: PackedStringArray = [
	"schema_version",
	"session_id",
	"session_started_at",
	"pre_stress_score",
	"recommended_mode",
	"selected_mode",
	"final_mode",
	"session_duration_seconds",
	"hints_used",
	"interaction_help_events",
	"items_collected",
	"garden_restored",
	"post_stress_score",
	"score_delta",
	"experience_rating",
	"completed",
]

const RATING_MIN := 1
const RATING_MAX := 5
const SESSION_ID_PREFIX := "cq-"
const SESSION_ID_BYTES := 8
const SESSION_ID_HEX_LENGTH := SESSION_ID_BYTES * 2

var session_id: String = ""
var session_started_at: String = ""
var pre_stress_score: Variant = null
## Empty when the check-in was skipped (Balanced was applied by default, not recommended).
var recommended_mode: String = ""
var selected_mode: String = ""
var final_mode: String = ""
var session_duration_seconds: int = 0
var hints_used: int = 0
var interaction_help_events: int = 0
var items_collected: int = 0
var garden_restored: bool = false
var post_stress_score: Variant = null
var experience_rating: Variant = null
var completed: bool = false


## Random, non-identifying ID such as "cq-3f9a0c71d2b84e65".
static func generate_session_id() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(SESSION_ID_BYTES)
	return SESSION_ID_PREFIX + bytes.hex_encode()


## Local wall-clock time in ISO-8601 form without a timezone, e.g. "2026-10-11T14:05:09".
static func local_timestamp() -> String:
	return Time.get_datetime_string_from_system(false, false)


static func is_valid_rating(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var f := float(value)
	return f == floorf(f) and f >= RATING_MIN and f <= RATING_MAX


func get_score_delta() -> Variant:
	return ScoreComparison.compute_delta(pre_stress_score, post_stress_score)


## Returns a list of human-readable problems. Empty means the record is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not session_id.begins_with(SESSION_ID_PREFIX) or session_id.length() != SESSION_ID_PREFIX.length() + SESSION_ID_HEX_LENGTH:
		errors.append("session_id has an unexpected format")
	if session_started_at.is_empty():
		errors.append("session_started_at is missing")
	if pre_stress_score != null and not AdaptiveComfortEngine.is_valid_score(pre_stress_score):
		errors.append("pre_stress_score must be an integer from 0 to 10 or missing")
	if post_stress_score != null and not AdaptiveComfortEngine.is_valid_score(post_stress_score):
		errors.append("post_stress_score must be an integer from 0 to 10 or missing")
	if experience_rating != null and not is_valid_rating(experience_rating):
		errors.append("experience_rating must be an integer from 1 to 5 or missing")
	if not recommended_mode.is_empty() and not AdaptiveComfortEngine.is_valid_mode(recommended_mode):
		errors.append("recommended_mode is not a known mode")
	if not AdaptiveComfortEngine.is_valid_mode(selected_mode):
		errors.append("selected_mode is not a known mode")
	if not AdaptiveComfortEngine.is_valid_mode(final_mode):
		errors.append("final_mode is not a known mode")
	if session_duration_seconds < 0:
		errors.append("session_duration_seconds must not be negative")
	if hints_used < 0 or interaction_help_events < 0 or items_collected < 0:
		errors.append("counters must not be negative")
	return errors


func to_dictionary() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"session_id": session_id,
		"session_started_at": session_started_at,
		"pre_stress_score": pre_stress_score,
		"recommended_mode": recommended_mode,
		"selected_mode": selected_mode,
		"final_mode": final_mode,
		"session_duration_seconds": session_duration_seconds,
		"hints_used": hints_used,
		"interaction_help_events": interaction_help_events,
		"items_collected": items_collected,
		"garden_restored": garden_restored,
		"post_stress_score": post_stress_score,
		"score_delta": get_score_delta(),
		"experience_rating": experience_rating,
		"completed": completed,
	}


## Values in COLUMNS order, formatted for CSV. null -> empty cell, bool -> true/false.
func to_row() -> PackedStringArray:
	var data := to_dictionary()
	var row := PackedStringArray()
	for column in COLUMNS:
		row.append(_format_value(data[column]))
	return row


static func _format_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return ""
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_FLOAT:
			var f: float = value
			if f == floorf(f):
				return str(int(f))
			return str(f)
		_:
			return str(value)
