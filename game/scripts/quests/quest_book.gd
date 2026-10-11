class_name QuestBook
extends RefCounted
## Data-driven quest progression (pure logic, unit tested).
##
## Quests are defined in JSON (game/data/quests/*.json). Every step has a
## condition that is a *predicate over world facts* (flags, counters, visited
## regions, restored waystones), evaluated whenever something changes. This
## design gives the safety rules for free:
##  * things done before a quest starts still count (no "too early" softlock);
##  * quests never reset on zone change or reload: completed stays completed;
##  * a step completes as soon as its condition holds, several at once if needed.
##
## `facts` must provide: has_flag(String) -> bool, counter(String) -> int,
## region_visited(String) -> bool, waystone_restored(String) -> bool.

signal quest_started(quest_id: String)
signal step_completed(quest_id: String, step_index: int)
signal quest_completed(quest_id: String)

const LOCKED := "locked"
const ACTIVE := "active"
const COMPLETED := "completed"

var quests: Array[Dictionary] = []
var status: Dictionary = {}
var step: Dictionary = {}
var load_errors: PackedStringArray = []
var _index: Dictionary = {}


func add_from_json(text: String, source: String = "") -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("quests"):
		load_errors.append("Invalid quest file %s" % source)
		return
	for q: Dictionary in parsed["quests"]:
		var id := String(q.get("id", ""))
		if id.is_empty() or _index.has(id):
			load_errors.append("Missing or duplicate quest id in %s" % source)
			continue
		if (q.get("steps", []) as Array).is_empty():
			load_errors.append("Quest %s has no steps" % id)
			continue
		quests.append(q)
		_index[id] = q
		status[id] = LOCKED
		step[id] = 0


func load_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		load_errors.append("Quest folder not found: %s" % dir_path)
		return
	var files := dir.get_files()
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			add_from_json(FileAccess.get_file_as_string(dir_path.path_join(f)), f)


func reset_progress() -> void:
	for id: String in _index:
		status[id] = LOCKED
		step[id] = 0


func get_quest(quest_id: String) -> Dictionary:
	return _index.get(quest_id, {})


## Re-evaluates every quest. Returns true if anything changed.
func evaluate(facts: Object) -> bool:
	var any_change := false
	var changed := true
	# Loop until stable: completing one quest can unlock the next.
	while changed:
		changed = false
		for q in quests:
			var id := String(q["id"])
			if status[id] == COMPLETED:
				continue
			if status[id] == LOCKED:
				# "unlock": an optional extra condition (e.g. a villager has arrived).
				if not _prerequisites_done(q) or (q.has("unlock") and not condition_met(q["unlock"], facts)):
					continue
				status[id] = ACTIVE
				quest_started.emit(id)
				changed = true
			var steps: Array = q["steps"]
			while int(step[id]) < steps.size() and condition_met((steps[int(step[id])] as Dictionary).get("condition", {}), facts):
				step_completed.emit(id, int(step[id]))
				step[id] = int(step[id]) + 1
				changed = true
			if int(step[id]) >= steps.size():
				status[id] = COMPLETED
				quest_completed.emit(id)
				changed = true
		any_change = any_change or changed
	return any_change


func _prerequisites_done(q: Dictionary) -> bool:
	for req: Variant in q.get("requires", []):
		if status.get(String(req), "") != COMPLETED:
			return false
	return true


static func condition_met(cond: Dictionary, facts: Object) -> bool:
	if cond.is_empty():
		return false
	if cond.has("all"):
		for c: Dictionary in cond["all"]:
			if not condition_met(c, facts):
				return false
		return true
	if cond.has("any"):
		for c: Dictionary in cond["any"]:
			if condition_met(c, facts):
				return true
		return false
	if cond.has("flag"):
		return bool(facts.call("has_flag", String(cond["flag"])))
	if cond.has("counter"):
		return int(facts.call("counter", String(cond["counter"]))) >= int(cond.get("at_least", 1))
	if cond.has("region"):
		return bool(facts.call("region_visited", String(cond["region"])))
	if cond.has("waystone"):
		return bool(facts.call("waystone_restored", String(cond["waystone"])))
	push_warning("QuestBook: unknown condition %s" % str(cond))
	return false


func is_completed(quest_id: String) -> bool:
	return status.get(quest_id, "") == COMPLETED


func is_active(quest_id: String) -> bool:
	return status.get(quest_id, "") == ACTIVE


func quests_with_status(wanted: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for q in quests:
		if status[String(q["id"])] == wanted:
			result.append(q)
	return result


## The current step dictionary of an active quest (empty if none).
func current_step(quest_id: String) -> Dictionary:
	var q := get_quest(quest_id)
	if q.is_empty() or status[quest_id] != ACTIVE:
		return {}
	var steps: Array = q["steps"]
	var i := int(step[quest_id])
	return steps[i] if i < steps.size() else {}


## Human-readable current step, with numeric progress where defined.
func step_text(quest_id: String, facts: Object) -> String:
	var s := current_step(quest_id)
	if s.is_empty():
		return ""
	var text := L.t(String(s.get("text", "")))
	if s.has("progress"):
		var p: Dictionary = s["progress"]
		var current := mini(int(facts.call("counter", String(p["counter"]))), int(p["target"]))
		text += " (%d/%d)" % [current, int(p["target"])]
	return text


func to_state() -> Dictionary:
	return {"status": status.duplicate(), "step": step.duplicate()}


func load_state(state: Dictionary) -> void:
	var saved_status: Dictionary = state.get("status", {})
	var saved_step: Dictionary = state.get("step", {})
	for id: String in _index:
		if saved_status.has(id):
			status[id] = String(saved_status[id])
			step[id] = int(saved_step.get(id, 0))
