extends Node
## Quest progression service (autoload "QuestManager").
## Loads every JSON file in game/data/quests/, re-evaluates quests whenever
## world or session state changes, and tracks the quest shown on the HUD.

signal tracked_changed(quest_id: String)
signal quests_changed

const QUEST_DIR := "res://game/data/quests"

var book: QuestBook = QuestBook.new()
var facts: QuestFacts = QuestFacts.new()
var tracked_id: String = ""
## Returns the world position of a step target id, or Vector2.INF (set by the world).
var target_resolver: Callable = Callable()
var _refresh_queued: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	book.load_directory(QUEST_DIR)
	for e in book.load_errors:
		push_error("QuestManager: " + e)
	book.quest_started.connect(func(id: String) -> void: EventBus.quest_started.emit(id))
	book.step_completed.connect(func(id: String, i: int) -> void: EventBus.quest_step_completed.emit(id, i))
	book.quest_completed.connect(func(id: String) -> void: EventBus.quest_completed.emit(id))
	GameState.changed.connect(_on_state_changed)
	SessionState.progress_changed.connect(request_refresh)
	EventBus.progress_changed.connect(request_refresh)


func _on_state_changed(key: String) -> void:
	if key == "reset":
		book.reset_progress()
		tracked_id = ""
	request_refresh()


## Coalesces many changes in one frame into a single evaluation.
func request_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	var changed := book.evaluate(facts)
	if tracked_id.is_empty() or not book.is_active(tracked_id):
		_auto_track()
	if changed:
		quests_changed.emit()


func _auto_track() -> void:
	var previous := tracked_id
	tracked_id = ""
	for q in book.quests_with_status(QuestBook.ACTIVE):
		if String(q.get("type", "")) == "main":
			tracked_id = String(q["id"])
			break
	if tracked_id.is_empty():
		var active := book.quests_with_status(QuestBook.ACTIVE)
		if not active.is_empty():
			tracked_id = String(active[0]["id"])
	if tracked_id != previous:
		tracked_changed.emit(tracked_id)


## Lets the player choose which active quest the HUD follows.
func track(quest_id: String) -> void:
	if book.is_active(quest_id) and quest_id != tracked_id:
		tracked_id = quest_id
		tracked_changed.emit(tracked_id)


func tracked_title() -> String:
	return L.t(String(book.get_quest(tracked_id).get("title", "")))


func tracked_step_text() -> String:
	return book.step_text(tracked_id, facts)


func tracked_target_id() -> String:
	return String(book.current_step(tracked_id).get("target", ""))


## World position of the tracked step's target, or Vector2.INF if unknown.
func tracked_target_position() -> Vector2:
	var target := tracked_target_id()
	if target.is_empty() or not target_resolver.is_valid():
		return Vector2.INF
	return target_resolver.call(target)


func quest_hint(quest_id: String) -> String:
	var hints: Array = book.get_quest(quest_id).get("hints", [])
	return L.t(String(hints[0])) if not hints.is_empty() else ""


func is_act_complete(act: int) -> bool:
	var any := false
	for q in book.quests:
		if int(q.get("act", 0)) == act:
			any = true
			if not book.is_completed(String(q["id"])):
				return false
	return any
